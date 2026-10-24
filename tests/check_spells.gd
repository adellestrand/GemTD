extends SceneTree

var checks = 0
var failures = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)

var cells: Array[Vector2i] = []

func open_cell(state: GemRun) -> Vector2i:
	for q in cells:
		if not state.board.cells.has(q): return q
	return Vector2i(-1,-1)

# One shared board: each sample reseeds the RNG and clears the previous gem.
func sample(state: GemRun, seed_value: int, id: String) -> Dictionary:
	state.board.cells.erase(cells[0])
	state.placed = 0
	state.quality_pray_hit = false
	state.rng.seed = seed_value
	state.gold = 1000
	state.cast_spell(id)
	state.place(cells[0])
	return state.board.cells[cells[0]]

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var probe = GemRun.new(1)
	for x in range(12,22,2):
		if probe.board.placement_error(Vector2i(x,12)).is_empty(): cells.append(Vector2i(x,12))
	check(cells.size() == 5,"five open test cells")
	var spells: Dictionary = GemCatalog.DATA.get("spells",{})
	check(spells.size() == 12 and spells.pray_ruby.cost == 200 and spells.pray_ruby.chance == 40 and spells.pray_perfect.cost == 400 and spells.heal.max_heal == 10,"campaign data carries twelve level-1 source spells")
	# Without a pray, placement draws exactly the two original rolls.
	var state = GemRun.new(7)
	var mirror = RandomNumberGenerator.new()
	mirror.seed = 7
	var p = open_cell(state)
	state.place(p)
	var tier = GemCatalog.roll_tier(GemCatalog.DATA.quality_odds[0],mirror.randi_range(1,100))
	check(state.board.cells[p].tier == tier and state.board.cells[p].kind == GemCatalog.TYPES[mirror.randi_range(0,7)] and state.rng.state == mirror.state,"placement without prays keeps the unchanged RNG sequence")
	state = GemRun.new(1)
	var before = state.snapshot()
	check(not state.cast_spell("pray_ruby") and state.snapshot() == before and state.type_pray == "","pray without gold changes nothing")
	check(not state.cast_spell("missing") and state.snapshot() == before,"unknown spell is rejected")
	state.gold = 1000
	check(state.cast_spell("pray_ruby") and state.gold == 800 and state.type_pray == "pray_ruby","type pray charges 200 gold and waits for the next gem")
	check(not state.cast_spell("pray_topaz") and state.gold == 800 and state.type_pray == "pray_ruby","second type pray is refused while one waits")
	check(state.cast_spell("pray_common") and state.gold == 600 and state.quality_pray == "pray_common","quality pray can wait together with a type pray")
	state.place(open_cell(state))
	check(state.type_pray == "" and state.quality_pray == "","the next gem consumes both prays")
	# Long-run frequencies follow RandomInt(1,100) < chance.
	var ruby = 0
	var common = 0
	var perfect = 0
	var shared = GemRun.new(1)
	for seed_value in range(1,2001):
		if sample(shared,seed_value,"pray_ruby").kind == "ruby": ruby += 1
		if int(sample(shared,seed_value,"pray_common").tier) == 3: common += 1
		if int(sample(shared,seed_value,"pray_perfect").tier) == 5: perfect += 1
	check(absf(ruby/2000.0-(.39+.61/8.0)) < .03,"Ruby pray gives about 39%% plus the normal 1/8: %d of 2000" % ruby)
	check(absf(common/2000.0-.49) < .03,"Common pray gives quality III about 49%% of the time: %d of 2000" % common)
	check(absf(perfect/2000.0-.05) < .015,"Perfect pray gives quality V about 5%% of the time: %d of 2000" % perfect)
	# A successful quality pray replaces the roll, and only one succeeds per round.
	state = GemRun.new(1)
	state.quality = 4
	var seed_hit = 1
	while not state.quality_pray_hit:
		sample(state,seed_hit,"pray_common")
		seed_hit += 1
	state.gold = 1000
	p = cells[0]
	check(int(state.board.cells[p].tier) == 3,"successful quality pray sets quality III even at high odds")
	check(not state.cast_spell("pray_flawless") and state.gold == 1000,"a second quality pray is refused after a success this round")
	state.begin_combat()
	check(not state.quality_pray_hit and state.type_pray == "" and state.quality_pray == "","combat start clears pray state")
	check(not state.cast_spell("pray_ruby"),"prays are closed during combat")
	state = GemRun.new(3)
	state.gold = 1000
	for i in range(5): state.place(open_cell(state))
	check(not state.cast_spell("pray_ruby") and state.gold == 1000,"prays are refused once all five gems are placed")
	state = GemRun.new(3)
	state.gold = 1000
	state.wave = 51
	check(not state.cast_spell("pray_ruby") and state.gold == 1000,"prays are closed in the trials")
	# Heal: 1-10 lives, capped at the starting 100, between waves only.
	state = GemRun.new(5)
	state.gold = 1000
	check(not state.cast_spell("heal") and state.gold == 1000,"heal is refused at full lives")
	state.lives = 50
	check(state.cast_spell("heal") and state.gold == 700 and state.last_heal in range(1,11) and state.lives == 50+state.last_heal,"heal restores 1-10 lives for 300 gold")
	state.lives = 99
	check(state.cast_spell("heal") and state.lives == 100,"heal stops at 100 lives")
	state.lives = 40
	state.phase = "intermission"
	check(state.cast_spell("heal"),"heal works in the trial interval")
	state.phase = "combat"
	check(not state.cast_spell("heal"),"heal is closed during combat")
	var rolls: Dictionary = {}
	for seed_value in range(1,400):
		state.phase = "build"
		state.rng.seed = seed_value
		state.lives = 10
		state.gold = 300
		state.cast_spell("heal")
		rolls[state.last_heal] = true
	check(rolls.keys().size() == 10 and rolls.keys().min() == 1 and rolls.keys().max() == 10,"heal rolls cover exactly 1-10")
	# Independent replay of prays, placements and a heal.
	state = GemRun.new(11)
	state.gold = 1200
	state.lives = 60
	var journal = GemReviewJournal.new()
	journal.reset(state,true)
	var combat = GemCampaignCombat.new(state)
	var record = journal.record.bind(combat)
	state.action_recorded.connect(record)
	state.cast_spell("heal")
	state.cast_spell("pray_emerald")
	state.cast_spell("pray_flawless")
	state.place(open_cell(state))
	state.cast_spell("pray_opal")
	state.place(open_cell(state))
	var report = JSON.parse_string(JSON.stringify(journal.export_report(state,combat)))
	check(GemReviewReplay.replay(report).ok,"spells replay independently: "+str(GemReviewReplay.replay(report).get("error","")))
	for row in report.actions:
		if row.get("spell","") == "heal": row.heal = int(row.heal)%10+1
	check(not GemReviewReplay.replay(report).ok,"replay rejects a falsified heal roll")
	state.action_recorded.disconnect(record)
	# Sidebar card.
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	game.refresh_ui()
	check(game.spells_card.visible and game.spell_buttons.size() == 12,"campaign sidebar shows the gold spells card")
	check(game.spell_buttons.pray_ruby.disabled and game.spell_buttons.pray_ruby.tooltip_text.contains("200 gold"),"unaffordable pray is disabled with its price")
	game.run.gold = 300
	game.refresh_ui()
	check(not game.spell_buttons.pray_ruby.disabled and game.spell_buttons.heal.disabled,"affordable pray is enabled; heal stays closed at full lives")
	game.spell_buttons.pray_ruby.pressed.emit()
	game.refresh_ui()
	check(game.run.type_pray == "pray_ruby" and game.run.gold == 100 and game.spell_status.text.contains("Ruby Pray"),"pressing a pray casts it and shows it as waiting")
	game.queue_free()
	print("SPELLS_CHECK %s checks=%d failures=%d" % ["OK" if failures == 0 else "FAILED",checks,failures])
	if failures == 0: print("SPELLS_CHECK_OK")
	quit(1 if failures else 0)
