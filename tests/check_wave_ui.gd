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

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	if not "--smoke" in OS.get_cmdline_user_args():
		quit(1)
		return
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	var before = game.run.snapshot()
	game.show_waves()
	await process_frame
	await process_frame
	await process_frame
	check(game.wave_book.visible and game.paused and game.wave_book.wave_buttons.size() == 10 and game.wave_book.selected_wave == game.run.wave,"overview opens all ten waves with current selection and pauses gameplay")
	check(game.wave_book.size.y <= 750 and game.wave_book.detail_scroll.get_global_rect().end.y < game.wave_book.get_ok_button().get_global_rect().position.y,"wrapped wave details stay inside the window and above the Close row")
	game.wave_book.size = Vector2i(800,540)
	await process_frame
	await process_frame
	await process_frame
	check(game.wave_book.detail_scroll.get_global_rect().end.y < game.wave_book.get_ok_button().get_global_rect().position.y,"minimum-size overview keeps both scrolling and Close accessible")
	game.wave_book.wave_buttons[4].pressed.emit()
	check(game.wave_book.selected_wave == 5 and game.wave_book.selected_info.wave.air and game.run.snapshot() == before,"air-wave button changes only inspected wave, preserving the run")
	game.wave_book.wave_buttons[9].pressed.emit()
	check(game.wave_book.selected_wave == 10 and game.wave_book.selected_info.wave.boss and game.wave_book.wave_buttons[9].button_pressed and not game.wave_book.wave_buttons[0].button_pressed and not game.wave_book.wave_buttons[4].button_pressed,"boss button selects only the final wave with its boss rules and pressed state")
	game.show_waves()
	game.wave_book.hide()
	check(not game.paused and game.run.phase == "build","repeated open does not overwrite the original pause state")
	var p = Vector2i(10,10)
	game.run.board.cells[p] = {"kind":"sapphire","tier":1,"fresh":true,"priority":"First"}
	game.run.placed = 5
	game.run.keep(p)
	game.show_waves()
	await process_frame
	var elapsed = game.combat.elapsed
	await process_frame
	check(game.run.phase == "combat" and game.paused and game.combat.elapsed == elapsed and game.wave_heading.text == "CURRENT WAVE","live combat stays frozen under the overview and sidebar describes the current wave")
	game.show_recipes()
	check(not game.wave_book.visible and game.recipe_book.visible and game.paused,"switching from waves to recipes keeps combat paused")
	game.show_help()
	game.show_waves()
	game.wave_book.hide()
	check(not game.paused and not game.recipe_book.visible and not game.recipe_popup.visible,"switching among all three dialogs restores the original running state on close")
	game.paused = true
	game.show_waves()
	game.wave_book.hide()
	check(game.paused,"overview preserves an already paused battle")
	game.run.board.cells[Vector2i(11,10)] = {"kind":"diamond","tier":1,"fresh":false,"priority":"First"}
	game.show_waves()
	game.wave_book.wave_buttons[4].pressed.emit()
	check(game.wave_book.selected_info.coverage.kept == 2 and game.wave_book.selected_info.coverage.kept_total == 2,"reopening reads the current board rather than a stale coverage snapshot (the new Diamond also covers air)")
	game.new_run(7)
	await process_frame
	check(not game.wave_book.visible and game.wave_book.state == null and game.wave_book.wave_buttons.is_empty() and not game.paused,"restart clears the inspected run, dialog and pause state safely")
	game.show_waves()
	await process_frame
	check(game.wave_book.selected_wave == 1 and game.wave_book.selected_info.coverage.kept_total == 0 and game.wave_heading.text == "THE NEXT WAVE","new run opens with fresh wave progress and no old defense counts")
	game.free()
	await process_frame
	print("WAVE_UI_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
