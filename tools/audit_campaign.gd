extends "res://tools/audit_v1.gd"

var planning_state: GemRun
var spells = false
var spells_first = false
# Control for the spell comparison: no odds purchases before wave 11.
var late_odds = false

func value(gem_data: Dictionary, wave: Dictionary) -> float:
	var planning_wave = wave.duplicate()
	if planning_state != null and planning_state.wave%10 >= 7: planning_wave.boss = true
	var estimate = super.value(gem_data,planning_wave)
	# A second kept Opal of the same quality supplies no extra aura. This is
	# public inventory information, not a future RNG reveal or a stat edit.
	if planning_state != null and gem_data.kind == "opal" and not gem_data.has("fresh"):
		for owned in planning_state.board.cells.values():
			if owned.kind == "opal" and not owned.fresh and int(owned.tier) == int(gem_data.tier):
				return float(GemCatalog.stats(gem_data).damage)/float(GemCatalog.stats(gem_data).interval)
	return estimate*(1.0+float(gem_data.get("mvp",0))*.1)

func audit() -> void:
	output_dir = "res://output/campaign-playtest"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output=res://output/") and ".." not in argument: output_dir = argument.trim_prefix("--output=")
	policy = "maze"
	spells_first = "--spells-first" in OS.get_cmdline_user_args()
	late_odds = "--late-odds" in OS.get_cmdline_user_args()
	spells = spells_first or "--spells" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var runs = 3
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="): runs = clampi(int(argument.trim_prefix("--runs=")),1,30)
	var index: Array = []
	for seed_value in range(1,runs+1):
		var report = campaign_run(seed_value)
		var file = FileAccess.open("%s/maze-%02d.json" % [output_dir,seed_value],FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
		file.close()
		index.append({"seed":seed_value,"outcome":report.outcome,"wave":report.wave,"lives":report.lives,"kills":report.kills,"error":report.get("error","")})
		print("CAMPAIGN_AUDIT seed=%d wave=%d outcome=%s" % [seed_value,report.wave,report.outcome])
	var file = FileAccess.open(output_dir+"/index.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"profile":GemCatalog.DATA.profile,"policy":"greedy route maze, no long-term recipe planning; real RNG and economy, no fixtures or stat buffs"+("; casts a Flawless pray every round before odds purchases, then heals at lives <= 90" if spells_first else "; spends gold above the next odds price on heal (lives <= 90) and a Flawless pray before the first gem" if spells else "")+("; no odds purchases before wave 11" if late_odds else ""),"results":index},"  "))
	file.close()
	print("CAMPAIGN_AUDIT_OK runs=%d" % runs)
	quit(1 if index.any(func(r): return not str(r.error).is_empty()) else 0)

func campaign_run(seed_value: int) -> Dictionary:
	var state = GemRun.new(seed_value)
	planning_state = state
	var combat = GemCampaignCombat.new(state)
	var journal = GemReviewJournal.new()
	journal.reset(state,false)
	var record = journal.record.bind(combat)
	var start = func():
		combat.start()
		journal.begin_wave(state)
	state.action_recorded.connect(record)
	state.combat_started.connect(start)
	var error = ""
	while state.phase in ["build","combat","intermission"]:
		if state.phase != "build":
			var before = state.wave
			for tick in range(90000):
				combat.tick(1.0/30.0)
				if state.wave != before or state.phase in ["won","lost"]: break
			journal.complete_wave(state,combat)
			if state.wave == before and state.phase not in ["won","lost"]:
				error = "Trial exceeded 3000 simulation seconds"
				break
			if spells and state.phase == "intermission": cast_spells(state)
			continue
		if spells_first: state.cast_spell("pray_flawless")
		while state.quality < GemCatalog.max_quality_upgrade() and state.gold >= state.quality_price() and not (late_odds and state.wave <= 10): state.buy_quality()
		if spells: cast_spells(state)
		combine_old(state)
		for p in state.board.slabs.keys():
			for point in state.board.ground_route:
				var q = Vector2i(point-Vector2(.5,.5))
				if state.slab_error(q).is_empty():
					state.move_slab(p,q)
					break
		if spells and state.placed == 0 and state.gold-reserve(state) >= int(GemRun.spell("pray_flawless").cost): state.cast_spell("pray_flawless")
		while state.placed < 5:
			var placed = false
			for candidate in positions(state):
				if state.place(candidate.p):
					placed = true
					break
			if not placed:
				error = "No legal placement"
				break
		if not error.is_empty(): break
		var choice = choose(state)
		var p: Vector2i = choice.p
		var accepted = state.combine(choice.recipe,p) if choice.has("recipe") else state.upgrade(p,int(choice.count)) if int(choice.get("count",1)) > 1 else state.keep(p)
		if not accepted:
			error = state.message
			break
		if state.awaiting_trap_placement: state.start_wave()
		for tick in range(90000):
			combat.tick(1.0/30.0)
			if state.phase != "combat": break
		if state.phase == "combat":
			error = "Wave exceeded 3000 simulation seconds"
			break
		journal.complete_wave(state,combat)
	var report = journal.export_report(state,combat)
	if not error.is_empty(): report.error = error
	state.action_recorded.disconnect(record)
	state.combat_started.disconnect(start)
	return report

func reserve(state: GemRun) -> int:
	return state.quality_price() if state.quality < GemCatalog.max_quality_upgrade() and state.wave <= 50 else 0

func cast_spells(state: GemRun) -> void:
	while state.lives <= 90 and state.gold-reserve(state) >= int(GemRun.spell("heal").cost) and state.cast_spell("heal"): pass
