extends SceneTree

var checks = 0
var failures = 0
const RECIPE = "slab:gemtd_youbushiban"
const AT = Vector2i(18,18)
const DEST = Vector2i(22,20)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)

func gem(kind: String, tier: int, fresh: bool = false) -> Dictionary:
	return {"kind":kind,"tier":tier,"fresh":fresh,"priority":"First"}

func prepare(state: GemRun) -> void:
	state.board.cells.clear()
	state.board.slabs.clear()
	state.board.cells[AT] = gem("topaz",3)
	state.board.cells[Vector2i(10,10)] = gem("diamond",2,true)
	for y in [12,14,16,18]: state.board.cells[Vector2i(10,y)] = gem("ruby",1,true)
	state.placed = 5
	state.board.rebuild()

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var state = GemRun.new(42)
	prepare(state)
	var guide = GemBuildGuide.new()
	guide.bind(state)
	var plan = guide.action({"type":"recipe","recipe":RECIPE},AT)
	check(plan.valid and plan.message.contains("Position your trap"),"recipe preview explains placement before combat")
	var rng_before = state.rng.state
	check(state.combine(RECIPE,AT) and state.phase == "build" and state.awaiting_trap_placement,"mixed old/new recipe waits for trap placement")
	check(state.fresh_cells().is_empty() and state.board.cells[Vector2i(10,12)].kind == "stone","new tower choice is consumed immediately")
	check(not state.keep(Vector2i(10,12)) and not state.upgrade(Vector2i(10,12),2) and not state.place(DEST),"placement step grants no extra gem or keep/upgrade")
	check(not state.demolish(Vector2i(10,12)) and not state.demolish(AT) and not state.combine(RECIPE,AT),"placement step blocks demolition and further recipes")
	check(not guide.action({"type":"demolish"},AT).valid,"preview also locks building choices")
	check(not state.move_slab(AT,Vector2i(4,4)) and state.board.slabs.has(AT),"invalid move keeps trap and placement step intact")
	check(state.move_slab(AT,DEST) and state.pending_trap == DEST and state.awaiting_trap_placement and state.rng.state == rng_before,"new trap moves in same round without RNG or combat")
	check(state.start_wave() and state.phase == "combat" and not state.awaiting_trap_placement,"explicit start begins combat after movement")
	check(not state.start_wave() and not state.move_slab(DEST,AT),"combat prevents further movement and repeated start")
	state = GemRun.new(42)
	prepare(state)
	check(state.combine(RECIPE,AT) and state.start_wave() and state.board.slabs.has(AT),"player may keep the original trap position")
	state = GemRun.new(42)
	prepare(state)
	state.board.slabs[Vector2i(25,12)] = "youbushiban"
	check(state.combine(RECIPE,AT) and state.pending_trap == AT and state.board.slabs[AT] == "youbushiban_yin" and not state.board.slabs.has(Vector2i(25,12)),"new trap merges with an equal trap elsewhere and keeps its own cell")
	check(state.move_slab(state.pending_trap,DEST),"automatically upgraded new trap can also move immediately")
	state = GemRun.new(42)
	prepare(state)
	state.board.cells[Vector2i(10,10)].fresh = false
	check(state.combine(RECIPE,AT,true) and not state.awaiting_trap_placement and state.phase == "build" and state.move_slab(AT,DEST),"old-only trap recipe preserves normal building and immediate movement")
	state = GemRun.new(42)
	prepare(state)
	state.placed = 4
	check(not state.combine(RECIPE,AT),"new materials still require all five placements")
	# Use actual deterministic reveals for independent report replay.
	var seed_value = 0
	for candidate in range(1,1000):
		var rng = RandomNumberGenerator.new()
		rng.seed = candidate
		var tier = GemCatalog.roll_tier(GemCatalog.DATA.quality_odds[1],rng.randi_range(1,100))
		var kind = GemCatalog.TYPES[rng.randi_range(0,7)]
		if tier == 2 and kind == "diamond":
			seed_value = candidate
			break
	check(seed_value > 0,"found natural reveal for replay fixture")
	state = GemRun.new(seed_value)
	state.quality = 1
	state.board.cells.clear()
	state.board.cells[AT] = gem("topaz",3)
	state.board.rebuild()
	var journal = GemReviewJournal.new()
	journal.reset(state,true)
	var combat = GemCampaignCombat.new(state)
	var record = func(entry): journal.record(entry,combat)
	var start = func():
		combat.start()
		journal.begin_wave(state)
	state.action_recorded.connect(record)
	state.combat_started.connect(start)
	for y in [10,12,14,16,18]: state.place(Vector2i(10,y))
	state.combine(RECIPE,AT)
	state.move_slab(AT,DEST)
	var report = JSON.parse_string(JSON.stringify(journal.export_report(state,combat)))
	check(GemReviewReplay.replay(report).ok,"pending placement report independently replays")
	state.start_wave()
	report = JSON.parse_string(JSON.stringify(journal.export_report(state,combat)))
	check(GemReviewReplay.replay(report).ok,"move and explicit start independently replay")
	state.action_recorded.disconnect(record)
	state.combat_started.disconnect(start)
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	await process_frame
	prepare(game.run)
	game.on_cell_clicked(AT)
	game.recipe_buttons[RECIPE].final.pressed.emit()
	check(game.start_trap_wave_button.visible and game.move_trap_button.visible and not game.move_trap_button.disabled,"UI offers start and movement immediately after creating trap")
	game.move_trap_button.pressed.emit()
	game.on_cell_clicked(DEST)
	check(game.run.board.slabs.has(DEST) and game.run.awaiting_trap_placement and not game.keep_button.visible,"UI moves trap without an extra tower choice")
	game.start_trap_wave_button.pressed.emit()
	check(game.run.phase == "combat" and not game.start_trap_wave_button.visible and game.moving_trap == Vector2i(-1,-1),"UI starts combat and clears move mode")
	game.audio.player.stop()
	game.audio.attack_player.stop()
	await create_timer(.1).timeout
	game.queue_free()
	await process_frame
	print("TRAP_PLACEMENT_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
