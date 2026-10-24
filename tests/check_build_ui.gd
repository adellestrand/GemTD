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

func gem(kind: String, tier: int = 1, fresh: bool = true) -> Dictionary:
	return {"kind":kind,"tier":tier,"fresh":fresh,"priority":"First"}

func _initialize() -> void:
	call_deferred("run_checks")

func prepare_five(game: Control) -> void:
	game.new_run(42)
	for x in range(10,15):
		game.run.board.cells[Vector2i(x,10)] = gem("ruby")
	game.run.placed = 5
	game.run.board.rebuild()
	game.board_view.sync_board()
	game.on_cell_clicked(Vector2i(12,10))

func run_checks() -> void:
	# The UI must not write test fixtures into the user's saved checkpoint.
	if not "--smoke" in OS.get_cmdline_user_args():
		printerr("UI checks require --smoke")
		quit(1)
		return
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	# Audio is verified by exported WAV rendering; this instant headless exit
	# must not leave queued mixer playback commands from synthetic button clicks.
	game.audio.volume = 0
	prepare_five(game)
	game.round_slots[0].pressed.emit()
	check(game.selection == Vector2i(10,10) and game.run.placed == 5,"round tray signal selects its own cell without placing")
	game.round_slots[2].pressed.emit()
	game.upgrade_four.mouse_entered.emit()
	check(game.board_view.action_plan.valid and game.board_view.action_plan.result.tier == 3 and game.board_view.action_plan.result_at == Vector2i(12,10),"real upgrade button previews quality III at the tray selection")
	game.upgrade_four.pressed.emit()
	check(game.run.phase == "combat" and game.run.board.cells[Vector2i(12,10)].tier == 3 and not game.round_tray.visible and game.board_view.action_plan.is_empty(),"upgrade button starts combat and clears tray/preview without confirmation")
	for i in range(7):
		game.run.killed(2)
	game.run.leaked(1,false)
	game.run.finish_wave()
	check(game.last_wave_report == "Wave 1: 7 defeated · 1 leaked · 1 lives lost." and game.message_label.text.contains(game.last_wave_report),"completed wave reports that wave's kills, leaks and life loss")
	for x in range(20,25):
		game.run.place(Vector2i(x,10))
	game.on_cell_clicked(Vector2i(20,10))
	game.keep_button.pressed.emit()
	for i in range(3):
		game.run.killed(2)
	for i in range(2):
		game.run.leaked(1,false)
	game.run.finish_wave()
	check(game.last_wave_report == "Wave 2: 3 defeated · 2 leaked · 2 lives lost.","next wave summary uses deltas rather than accumulated run totals")
	prepare_five(game)
	check(game.last_wave_report.is_empty() and not game.message_label.text.contains("defeated"),"restart clears the previous run's wave summary")
	game.upgrade_four.mouse_entered.emit()
	check(game.board_view.action_plan.valid and game.board_view.action_plan.result.tier == 3,"restart preserves captured button requests and restores previews")
	var p = Vector2i(7,7)
	game.run.board.cells[p] = gem("sapphire",1,false)
	game.run.board.cells[Vector2i(8,7)] = gem("topaz",1,false)
	game.run.board.cells[Vector2i(9,7)] = gem("diamond",1,false)
	game.on_cell_clicked(p)
	game.recipe_buttons.silver.old.pressed.emit()
	check(game.run.board.cells[p].kind == "silver" and game.run.phase == "build" and game.run.placed == 5 and game.round_tray.visible,"Silver old-only button uses its own recipe and preserves all five new gems")
	game.new_run(42)
	game.run.board.cells[p] = gem("ruby",2,false)
	for row in [[11,"ruby"],[12,"amethyst"],[13,"opal"],[14,"topaz"],[15,"diamond"]]:
		game.run.board.cells[Vector2i(row[0],10)] = gem(row[1])
	game.run.placed = 5
	game.on_cell_clicked(p)
	game.recipe_buttons.asteriated_ruby.final.mouse_entered.emit()
	check(game.board_view.action_plan.valid and game.board_view.action_plan.result.kind == "asteriated_ruby" and game.board_view.action_plan.starts,"mixed special button previews the correct special tower")
	game.recipe_buttons.asteriated_ruby.final.pressed.emit()
	check(game.run.phase == "combat" and game.run.board.cells[p].kind == "asteriated_ruby" and not game.round_tray.visible,"mixed special button atomically creates the previewed result and starts combat")
	game.free()
	print("BUILD_UI_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
