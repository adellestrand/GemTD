extends SceneTree

var checks = 0
var failures = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)
	else:
		print("PASS: "+description)

func gem(kind: String, fresh: bool = false) -> Dictionary:
	return {"kind":kind,"tier":1,"fresh":fresh,"priority":"First"}

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	if not "--smoke" in OS.get_cmdline_user_args():
		quit(1)
		return
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	game.run.board.cells[Vector2i(10,10)] = gem("sapphire")
	game.run.board.cells[Vector2i(11,10)] = gem("topaz")
	game.run.board.cells[Vector2i(12,10)] = gem("diamond")
	game.run.board.cells[Vector2i(20,10)] = gem("sapphire",true)
	game.run.placed = 1
	game.board_view.sync_board()
	await process_frame
	var before = game.run.snapshot()
	game.show_recipes()
	check(game.recipe_book.visible and game.paused and game.recipe_book.track_buttons.size() == 3,"recipe book opens three cards and pauses gameplay")
	check(game.recipe_book.find_buttons.silver.size() == 3 and not game.recipe_book.find_buttons.silver[0].disabled,"owned ingredients expose locate controls")
	game.recipe_book.track_buttons.silver.pressed.emit()
	check(not game.recipe_book.visible and not game.paused and game.board_view.tracked_recipe == "silver" and game.board_view.tracking_progress.collected == 3,"tracking closes the book, restores pause and pins correct progress")
	check(before == game.run.snapshot(),"pinning a complete recipe does not combine, spend or reveal anything")
	game.show_recipes()
	game.recipe_book.find_buttons.silver[0].pressed.emit()
	check(game.selection == Vector2i(10,10) and game.board_view.zoom >= 1.5 and not game.recipe_book.visible,"locate selects and focuses the owned material without placing")
	game.show_recipes()
	game.recipe_book.find_buttons.silver[0].pressed.emit()
	check(game.selection == Vector2i(20,10) and before == game.run.snapshot(),"repeated locate cycles to the next matching gem without mutation")
	game.locate_ingredient(Vector2i(0,0))
	check(before == game.run.snapshot(),"stale or missing ingredient coordinates cannot place a new gem")
	game.run.demolish(Vector2i(11,10))
	check(game.board_view.tracking_progress.collected == 2,"pinned progress updates when an ingredient is demolished")
	game.tracking_button.pressed.emit()
	check(game.board_view.tracked_recipe.is_empty() and game.board_view.tracking_progress.is_empty() and not game.tracking_button.visible,"unpin clears ingredient highlights and tracking control")
	game.run.placed = 5
	game.run.keep(Vector2i(20,10))
	game.paused = false
	game.show_recipes()
	game.recipe_book.hide()
	check(not game.paused and game.run.phase == "combat","closing the book resumes a previously running battle")
	game.paused = true
	game.show_recipes()
	game.show_recipes()
	game.recipe_book.find_buttons.silver[0].pressed.emit()
	check(game.paused and game.run.phase == "combat","locate and repeated open preserve an already paused battle")
	game.track_recipe("silver")
	game.new_run(7)
	check(game.board_view.tracked_recipe.is_empty() and not game.recipe_book.visible and not game.paused,"new run clears tracking, dialog and old pause state")
	game.free()
	await process_frame
	print("RECIPE_UI_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
