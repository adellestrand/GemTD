extends SceneTree

# Maze tips: the Dota 2 maze-guide layouts sit on the real map (checkpoints clear, route open),
# the tips view opens and lists them, and the chosen tip is marked on the board until hidden.
# Presentation only: the run itself must not change.

var checks = 0
var failures = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)
	else:
		print("PASS: "+description)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	if not "--smoke" in OS.get_cmdline_user_args():
		printerr("Maze tip checks require --smoke")
		quit(1)
		return
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	await process_frame
	var board: GemBoard = game.run.board
	var stones = GemMazeTips.starting_stones()
	var ids: Array = GemMazeTips.tips().map(func(t): return t.id)
	check(ids.size() == 8 and ids.all(func(id): return GemMazeTips.Layouts.LAYOUTS.has(id)),"all eight non-empty Dota maze_coop layouts are offered")
	check(GemMazeTips.tips().filter(func(t): return (t.players as Array).has(1)).map(func(t): return t.id) == ["maze_coop1","maze_coop2","maze_coop4"],"the solo set matches show_maze_guide for one player (coop1, coop2, coop4)")
	var base = GemMazeTips.base_route_length(board)
	for id in ids:
		var cells = GemMazeTips.cells(id)
		check(cells.size() >= 100 and cells.all(func(p): return board.inside(p) and not board.checkpoints.has(p)),"%s: %d cells, all inside the 37×37 board and off the checkpoints" % [id,cells.size()])
		check(GemMazeTips.removals(id).all(func(p): return stones.has(p) and not cells.has(p)),"%s: only starting stones outside the layout are marked for demolition" % id)
		var length = GemMazeTips.route_length(board,id)
		check(length > base*4.0,"%s: the finished maze keeps every checkpoint reachable and lengthens the route (%.0f vs %.0f)" % [id,length,base])
	# Removals are needed only where this engine's stricter pathing blocks the original layout.
	var blocked_without = {}
	for p in stones: blocked_without[p] = true
	for p in GemMazeTips.cells("maze_coop4"): blocked_without[p] = true
	check(board.path_for(blocked_without).is_empty() and not GemMazeTips.removals("maze_coop4").is_empty(),"coop4 with every starting stone kept would block, so demolitions are listed")
	check(GemMazeTips.removals("maze_coop1").is_empty(),"coop1 fits the starting map as it is")

	game.run.board.cells[Vector2i(13,15)] = {"kind":"stone","tier":1,"fresh":false,"priority":"First"}
	game.board_view.sync_board()
	var before = game.run.snapshot()
	var color = GemMazeBook.guide_color()
	for key in ["route_ground","route_air","route_preview","material","recipe_tracking","selection","placement_ok","placement_blocked"]:
		var other = GemArt.color(key)
		check(absf(color.h-other.h)+absf(color.s-other.s)+absf(color.v-other.v) > .25,"guide colour is distinct from the '%s' mark" % key)

	game.show_mazes()
	await process_frame
	var book: GemMazeBook = game.maze_book
	check(book.visible and book.title == "Maze tips","the Mazes button opens the maze tips view")
	check(book.show_buttons.size() == 8 and book.list.get_child_count() == 8,"the view lists one card per tip")
	check(not book.hide_button.visible,"nothing to hide before a tip is chosen")
	var standing = GemMazeTips.cells("maze_coop1").filter(func(p): return game.run.board.cells.has(p)).size()
	check(book.preview_title.text == "Diagonal Spiral" and standing == 16 and ("%d built" % standing) in book.preview_stats.text,"the preview starts on the first tip and counts starting stones plus the new stone as built")
	book.list.get_child(2).mouse_entered.emit()
	check(book.previewed == "maze_coop4" and "Demolish 5 starting stones" in book.preview_stats.text,"pointing at a card previews it, with the stones to demolish")

	(book.show_buttons["maze_coop1"] as Button).pressed.emit()
	await process_frame
	var view = game.board_view
	var cells = GemMazeTips.cells("maze_coop1")
	check(not book.visible and view.maze_tip == "maze_coop1","Show on board closes the view and selects the tip")
	check(view.maze_progress.total == cells.size() and view.maze_progress.done.size() == cells.filter(func(p): return game.run.board.cells.has(p)).size(),"the overlay splits the tip into built and still-to-build cells")
	check(view.maze_progress.build.all(func(p): return not game.run.board.cells.has(p)),"only empty cells are marked to build")
	check(game.maze_button.visible and game.maze_button.text.begins_with("Maze: Diagonal Spiral"),"the board shows which tip is active and how to hide it")
	var target: Vector2i = view.maze_progress.build[0]
	game.run.board.cells[target] = {"kind":"stone","tier":1,"fresh":false,"priority":"First"}
	game.board_view.sync_board()
	check(view.maze_progress.done.has(target) and not view.maze_progress.build.has(target),"building on a marked cell moves it to built")
	game.run.board.cells.erase(target)
	game.board_view.sync_board()
	await process_frame

	game.choose_maze_tip("maze_coop4")
	check(view.maze_progress.remove.size() == GemMazeTips.removals("maze_coop4").size(),"stones to demolish are marked while they stand")
	await process_frame
	game.show_mazes()
	await process_frame
	check(book.hide_button.visible and (book.show_buttons["maze_coop4"] as Button).text == "Showing","the view marks the active tip and offers to hide it")
	book.hide_button.pressed.emit()
	await process_frame
	check(view.maze_tip.is_empty() and view.maze_progress.is_empty() and not game.maze_button.visible,"the guide can be switched off")
	var key = InputEventKey.new()
	key.keycode = KEY_G
	key.pressed = true
	game._unhandled_key_input(key)
	check(view.maze_tip == "maze_coop4","G brings the last tip back")
	game._unhandled_key_input(key)
	check(view.maze_tip.is_empty(),"G hides it again")
	game.choose_maze_tip("maze_coop2")
	game.maze_button.pressed.emit()
	check(view.maze_tip.is_empty(),"the board link hides the guide")
	check(before == game.run.snapshot(),"browsing and showing maze tips changes nothing in the run")
	print("MAZE_TIPS_CHECK_%s checks=%d failures=%d" % ["OK" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
