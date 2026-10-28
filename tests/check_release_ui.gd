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
	check(game.footer_label.text.contains("1.0.0") and not game.result_box.visible and not game.wave_progress.visible,"release starts with one version identity and no stale combat or end controls")
	var menu = game.quality_button.get_parent().get_node("RunMenu").get_popup()
	check(menu.get_item_index(0) == -1 and menu.get_item_index(4) == -1 and menu.get_item_text(menu.get_item_index(1)) == "New run","player menu offers New run without same-seed or manual-seed choices")
	var previous_seed = game.run.initial_seed
	menu.id_pressed.emit(1)
	check(game.run.initial_seed > 0 and game.run.initial_seed != previous_seed,"menu restart creates a fresh seed")
	previous_seed = game.run.initial_seed
	menu.id_pressed.emit(1)
	check(game.run.initial_seed != previous_seed,"two immediate restarts cannot reuse the current seed")
	previous_seed = game.run.initial_seed
	game.run.phase = "lost"
	game.refresh_ui()
	var restart_button: Button
	var same_seed_button = false
	for child in game.result_box.get_children():
		if child is Button:
			if child.text == "New run": restart_button = child
			if child.text.to_lower().contains("same seed"): same_seed_button = true
	check(restart_button != null and not same_seed_button,"result screen has a single new-run action without same-seed retry")
	restart_button.pressed.emit()
	check(game.run.initial_seed != previous_seed and game.run.wave == 1 and game.run.gold == 0 and game.run.lives == GemCatalog.starting_lives(),"result restart also changes seed and resets the run")
	previous_seed = game.run.initial_seed
	game.last_snapshot = {"bad":"checkpoint"}
	menu.id_pressed.emit(2)
	check(game.run.initial_seed != previous_seed and not game.journal.resumed,"failed resume starts fresh rather than reusing the old seed")
	# Explicit seeds remain an internal diagnostic helper, absent from player menus.
	game.show_seed_dialog()
	game.seed_dialog.input.text = "bad-seed"
	check(not game.seed_dialog.validate() and game.seed_dialog.get_ok_button().disabled,"manual seed rejects invalid input without starting a run")
	game.seed_dialog.input.text = "1234567890123"
	game.seed_dialog.submit()
	check(game.run.initial_seed == 1234567890123 and game.run.wave == 1 and not game.seed_dialog.visible and not game.paused,"manual seed starts a fresh run and restores normal pause state")
	for x in range(10,15):
		game.run.place(Vector2i(x,10))
	game.run.keep(Vector2i(10,10))
	game.refresh_ui()
	check(game.wave_progress.visible and game.wave_progress.max_value == 8 and game.combat_progress.text.contains("Incoming 8"),"combat progress starts from the actual wave's spawn count")
	game.run.killed(2)
	game.refresh_ui()
	check(game.wave_progress.value == 1,"wave progress advances on resolved enemies")
	var before = game.run.snapshot()
	game.show_summary()
	await process_frame
	await process_frame
	await process_frame
	var decoded = JSON.parse_string(game.summary_dialog.report_text.text)
	check(game.summary_dialog.visible and game.paused and decoded.actions.size() == 6 and before == game.run.snapshot(),"summary pauses combat and exposes accepted actions without changing the run")
	check(game.summary_dialog.report_text.editable == false and game.summary_dialog.tabs.get_tab_count() == 2 and game.summary_dialog.report_text.get_global_rect().end.y < game.summary_dialog.get_ok_button().get_global_rect().position.y,"summary and read-only report fit above the Close row")
	game.show_waves()
	game.show_recipes()
	game.show_help()
	game.recipe_popup.hide()
	check(not game.paused and not game.summary_dialog.visible,"new summary dialog participates in the existing modal pause handoff")
	game.new_run(7)
	game.run.wave = 10
	game.run.phase = "combat"
	game.combat.start()
	game.combat.spawn_enemy()
	game.combat.enemies[0].hp = 700
	game.refresh_ui()
	check(game.boss_health.visible and game.boss_health.value == 700 and game.boss_health.max_value == 1449,"boss health reads the real enemy and its maximum health")
	game.run.phase = "lost"
	game.run.message = "The boss reached the goal."
	game.refresh_ui()
	check(game.result_box.visible and game.result_title.text == "DEFEAT" and not game.boss_health.visible,"defeat exposes restart/report controls and clears combat bars")
	game.run.phase = "won"
	game.refresh_ui()
	check(game.result_title.text == "VICTORY" and not game.priority.visible,"victory has a clear result and no unused targeting controls")
	game.new_run(99)
	check(not game.result_box.visible and game.journal.actions.is_empty() and game.journal.waves.is_empty(),"restart clears result controls and creates a new report journal")
	game.new_run(99,{"bad":"checkpoint"})
	check(not game.journal.resumed,"rejected checkpoint never labels a fresh run as resumed")
	game.free()
	await process_frame
	print("RELEASE_UI_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
