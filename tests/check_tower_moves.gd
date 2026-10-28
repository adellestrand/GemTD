extends SceneTree

var checks = 0
var failures = 0
const AT = Vector2i(10,10)
const DEST = Vector2i(12,10)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)

func gem(kind: String, tier: int = 1, fresh: bool = false) -> Dictionary:
	return {"kind":kind,"tier":tier,"fresh":fresh,"priority":"First"}

func fixture() -> GemRun:
	var state = GemRun.new(42)
	state.board.cells.clear()
	state.board.cells[AT] = gem("diamond",3)
	state.board.rebuild()
	return state

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var state = fixture()
	state.board.cells[AT].merge({"mvp":7,"priority":"Last","proc_failures":{"tower_baoji1":2}},true)
	var tower: Dictionary = state.board.cells[AT]
	var rng_before = state.rng.state
	var combat_rng_before = state.combat_rng.state
	var before = state.snapshot()
	var preview = state.tower_move_preview(AT,DEST)
	check(preview.error.is_empty() and state.snapshot() == before,"legal move preview is read-only")
	check(state.move_tower(AT,DEST) and not state.board.cells.has(AT) and is_same(state.board.cells[DEST],tower),"empty-cell relocation moves the original tower without leaving a new stone")
	check(state.board.cells[DEST].mvp == 7 and state.board.cells[DEST].priority == "Last" and state.board.cells[DEST].proc_failures.tower_baoji1 == 2 and state.board.cells[DEST].tier == 3,"move preserves quality, MVP, targeting and proc counters")
	check(state.tower_moves_left == 4 and state.placed == 0 and state.phase == "build" and state.gold == 0 and state.rng.state == rng_before and state.combat_rng.state == combat_rng_before,"move consumes only one relocation, no gold, placements or RNG")
	state = fixture()
	state.board.cells[AT] = gem("huguoshenyishi")
	state.board.cells[AT].rolled_damage = 800
	check(state.move_tower(AT,DEST) and state.board.cells[DEST].rolled_damage == 800,"Guardian Stone keeps its rolled attack")
	state = fixture()
	state.board.cells[AT] = gem("tianranzumulv")
	state.board.cells[AT].stolen_abilities = ["tower_baoji1"]
	check(state.move_tower(AT,DEST) and state.board.cells[DEST].stolen_abilities == ["tower_baoji1"],"Natural Emerald keeps copied abilities instead of rolling again")
	state = fixture()
	state.board.cells[DEST] = GemRun.stone()
	state.board.rebuild()
	var route = state.board.ground_route.duplicate()
	check(state.move_tower(AT,DEST) and state.board.cells[AT].kind == "stone" and state.board.cells[DEST].kind == "diamond" and state.board.ground_route == route,"moving onto a stone swaps positions and preserves maze occupancy and route")
	state = fixture()
	state.board.cells[DEST] = gem("ruby",1,true)
	state.board.slabs[Vector2i(14,10)] = "youbushiban"
	for target in [AT,DEST,Vector2i(-1,10),Vector2i(37,10),state.board.checkpoints[1],Vector2i(14,10)]:
		before = state.snapshot()
		check(not state.move_tower(AT,target) and state.snapshot() == before,"invalid destination costs nothing and changes no board state: "+str(target))
	state.board.cells[DEST].fresh = false
	check(not state.move_tower(AT,DEST) and state.tower_moves_left == 5,"another kept tower cannot be overwritten")
	state.board.cells[AT].fresh = true
	check(not state.move_tower(AT,Vector2i(13,10)) and state.tower_moves_left == 5,"unselected new gem cannot be moved")
	state = fixture()
	state.awaiting_trap_placement = true
	check(not state.move_tower(AT,DEST),"final trap-placement step does not unlock tower relocation")
	state.awaiting_trap_placement = false
	for phase in ["combat","intermission","won","lost"]:
		state.phase = phase
		check(not state.move_tower(AT,DEST) and state.tower_moves_left == 5,"relocation is blocked outside building: "+phase)
	state = fixture()
	for y in range(37):
		if y != 10: state.board.cells[Vector2i(15,y)] = GemRun.stone()
	state.board.rebuild()
	check(not state.board.ground_route.is_empty(),"blocking-route fixture begins with an open checkpoint path")
	before = state.snapshot()
	check(not state.move_tower(AT,Vector2i(15,10)) and state.snapshot() == before and not state.board.ground_route.is_empty(),"moving into the only corridor is rejected atomically")
	state.tower_moves_left = 0
	state.gold = 100
	before = state.snapshot()
	check(not state.move_tower(AT,Vector2i(15,10)) and state.snapshot() == before,"blocked-route paid move cannot charge gold")
	state = fixture()
	var at = AT
	for i in range(5):
		var target = DEST if at == AT else AT
		check(state.move_tower(at,target),"valid relocation uses budget slot "+str(i+1))
		at = target
	before = state.snapshot()
	check(not state.move_tower(at,AT) and state.snapshot() == before and state.tower_moves_left == 0,"sixth relocation requires gold after five free moves")
	state.gold = 99
	before = state.snapshot()
	check(not state.move_tower(at,AT) and state.snapshot() == before,"insufficient gold changes no state or free quota")
	state.gold = 200
	before = state.snapshot()
	check(not state.move_tower(at,state.board.checkpoints[0]) and state.snapshot() == before,"invalid paid destination never charges gold")
	preview = state.tower_move_preview(at,AT)
	check(preview.error.is_empty() and preview.cost == 100 and state.snapshot() == before,"paid preview shows the exact cost without charging")
	check(state.move_tower(at,AT) and state.gold == 100 and state.tower_moves_left == 0,"sixth successful move charges 100 gold and never makes free quota negative")
	state.board.cells[DEST] = GemRun.stone()
	state.board.rebuild()
	check(state.move_tower(AT,DEST) and state.board.cells[AT].kind == "stone" and state.gold == 0 and state.tower_moves_left == 0,"paid stone swap also costs exactly 100 gold")
	state.phase = "combat"
	state.finish_wave()
	check(state.tower_moves_left == 0 and state.wave == 2,"starting another wave does not refill relocation budget")
	check(GemRun.new(42).tower_moves_left == 5,"new run restores five relocations")
	var saved = JSON.parse_string(JSON.stringify(state.snapshot()))
	var restored = GemRun.new(1)
	check(restored.restore(saved) and restored.tower_moves_left == 0,"JSON save keeps exhausted relocation budget")
	check(restored.gold == state.gold and restored.tower_move_price() == 100,"JSON save restores the paid balance and next-move price")
	for bad in [-1,6,1.5,"5",true,null,INF]:
		var altered = saved.duplicate(true)
		altered.tower_moves_left = bad
		check(not restored.restore(altered) and restored.tower_moves_left == 0,"malformed budget rejected without mutating restored state: "+str(bad))
	state = fixture()
	state.board.slabs[Vector2i(10,20)] = "youbushiban"
	check(state.move_slab(Vector2i(10,20),Vector2i(11,20)) and state.tower_moves_left == 5,"path trap movement does not consume tower relocation budget")
	state = fixture()
	var guide = GemBuildGuide.new()
	guide.bind(state)
	guide.moving_tower = AT
	check(guide.placement(DEST).message.contains("free"),"free move hint shows remaining free moves")
	state.tower_moves_left = 0
	state.gold = 100
	check(guide.placement(DEST).message.contains("100 gold"),"cached hint changes to paid price when free moves run out")
	state.gold = 99
	check(guide.placement(DEST).status == "blocked","cached hint notices insufficient gold at the same destination")
	# Independent replay includes both empty-cell and stone-swap actions.
	state = fixture()
	state.board.cells[Vector2i(14,10)] = GemRun.stone()
	state.board.rebuild()
	state.tower_moves_left = 1
	state.gold = 100
	var journal = GemReviewJournal.new()
	journal.reset(state,true)
	var combat = GemCampaignCombat.new(state)
	var record = journal.record.bind(combat)
	state.action_recorded.connect(record)
	state.move_tower(AT,DEST)
	state.move_tower(DEST,Vector2i(14,10))
	var report = JSON.parse_string(JSON.stringify(journal.export_report(state,combat)))
	check(GemReviewReplay.replay(report).ok,"move and stone swap independently replay with remaining budget")
	check(report.actions[0].cost == 0 and report.actions[1].cost == 100 and state.gold == 0,"journal records the free-to-paid transition with exact charges")
	var forged = report.duplicate(true)
	forged.actions[1].cost = 0
	check(not GemReviewReplay.replay(forged).ok,"replay rejects a falsified paid-move charge")
	report.tower_moves_left += 1
	check(not GemReviewReplay.replay(report).ok,"replay rejects falsified remaining budget")
	state.action_recorded.disconnect(record)
	# Controller: cancellation, invalid destination, selection and no accidental placement.
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	game.run.board.cells.clear()
	game.run.board.cells[AT] = gem("diamond",3)
	game.run.board.cells[DEST] = GemRun.stone()
	game.run.board.rebuild()
	game.on_cell_clicked(AT)
	check(game.move_tower_button.visible and not game.move_tower_button.disabled and game.move_tower_button.text.contains("5 / 5"),"selected kept tower offers relocation and visible run budget")
	game.move_tower_button.pressed.emit()
	game.on_cell_clicked(AT)
	check(game.board_view.guide.moving_tower == Vector2i(-1,-1) and game.run.tower_moves_left == 5,"clicking source cancels move without charging")
	game.move_tower_button.pressed.emit()
	game.on_cell_clicked(game.run.board.checkpoints[0])
	check(game.board_view.guide.moving_tower == AT and game.run.tower_moves_left == 5,"invalid UI destination keeps move mode for retry")
	game.on_cell_clicked(DEST)
	check(game.run.board.cells[DEST].kind == "diamond" and game.run.board.cells[AT].kind == "stone" and game.selection == DEST and game.run.placed == 0 and game.run.tower_moves_left == 4,"UI swaps with stone and selects result without placing a new gem")
	game.move_tower_button.pressed.emit()
	var escape = InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	game._unhandled_key_input(escape)
	check(game.board_view.guide.moving_tower == Vector2i(-1,-1) and game.run.tower_moves_left == 4,"Escape cancels without using a relocation")
	game.run.tower_moves_left = 0
	game.run.gold = 200
	game.refresh_ui()
	check(not game.move_tower_button.disabled and game.move_tower_button.text.contains("100g"),"exhausted free quota offers a paid move in the real UI")
	game.move_tower_button.pressed.emit()
	game._unhandled_key_input(escape)
	check(game.run.gold == 200 and game.run.tower_moves_left == 0,"cancelling a paid UI move costs nothing")
	game.move_tower_button.pressed.emit()
	game.on_cell_clicked(AT)
	check(game.run.gold == 100 and game.run.tower_moves_left == 0 and game.selection == AT,"paid UI stone swap charges only on completion")
	if "--capture" in OS.get_cmdline_user_args():
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://output/paid-move-ui.png")
	game.run.gold = 99
	game.refresh_ui()
	check(game.move_tower_button.disabled and game.move_tower_button.tooltip_text.contains("100 gold"),"unaffordable paid move is disabled with the required price")
	game.new_run(42)
	check(game.board_view.guide.moving_tower == Vector2i(-1,-1) and game.run.tower_moves_left == 5,"restart clears move mode and resets budget")
	game.queue_free()
	await process_frame
	print("TOWER_MOVES_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
