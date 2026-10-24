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

func gem(kind: String, tier: int = 1, fresh: bool = false) -> Dictionary:
	return {"kind":kind,"tier":tier,"fresh":fresh,"priority":"First"}

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	if not "--smoke" in OS.get_cmdline_user_args():
		quit(1)
		return
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	var p = Vector2i(10,10)
	game.run.board.cells[p] = gem("aquamarine",1,true)
	game.run.board.cells[Vector2i(11,10)] = gem("opal")
	game.run.board.cells[Vector2i(12,10)] = gem("aquamarine",1,true)
	game.run.placed = 5
	game.on_cell_clicked(p)
	await process_frame
	check(game.detail_label.text.contains("0.31s / attack") and game.detail_label.text.contains("Opal I +20"),"selected tower panel uses live supported attack interval")
	check(game.priority.visible and game.detail_label.mouse_filter != Control.MOUSE_FILTER_IGNORE and game.detail_label.tooltip_text.contains("before armor and evasion"),"ordinary tower retains targeting and enables hover explanation of raw DPS limits")
	var before = game.run.snapshot()
	check(game.upgrade_two.tooltip_text.contains("Aquamarine  ·  II") and game.upgrade_two.tooltip_text.contains("Change:"),"real combination button shows the result and numeric comparison")
	game.upgrade_two.mouse_entered.emit()
	check(game.run.snapshot() == before and game.board_view.action_plan.result.tier == 2,"hover comparison preserves the existing read-only board preview")
	game.run.demolish(Vector2i(11,10))
	check(game.detail_label.text.contains("0.33s / attack") and not game.detail_label.text.contains("Opal I +20"),"demolishing support immediately updates selected tower details")
	game.run.board.cells[p] = gem("asteriated_ruby")
	game.refresh_ui()
	check(not game.priority.visible and game.detail_label.text.contains("80.0 aura DPS") and not game.detail_label.text.contains("physical"),"aura tower hides unused targeting and displays magic tick DPS")
	game.run.board.cells[p] = gem("stone")
	game.refresh_ui()
	check(not game.priority.visible and not game.detail_label.text.contains("DPS"),"stone selection clears all attack and aura statistics")
	game.new_run(7)
	check(game.selected_label.text == "Place a gem" and not game.detail_label.text.contains("aura DPS"),"restart clears stale tower statistics and comparisons")
	game.free()
	await process_frame
	print("TOWER_UI_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
