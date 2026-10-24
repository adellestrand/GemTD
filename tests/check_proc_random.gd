extends "res://tests/check_campaign.gd"

func run_checks() -> void:
	var models: Dictionary = GemCatalog.DATA.random_models
	var distributions: Array = []
	for id in models:
		var model: Dictionary = models[id]
		var rng = RandomNumberGenerator.new()
		rng.seed = 87283
		var owner: Dictionary = {}
		var successes = 0
		var maximum_streak = 0
		for i in range(200000):
			if GemProcRandom.roll(rng,owner,id): successes+=1
			maximum_streak = maxi(maximum_streak,int(owner.proc_failures[id]))
		check(absf(successes/200000.0-float(model.chance)) < .002,"long-run frequency stays near the source nominal rate: "+id)
		check(maximum_streak < ceili(1.0/float(model.coefficient)),"failure streak cannot outlast the model's guaranteed next trigger: "+id)
		var uniform = RandomNumberGenerator.new()
		uniform.seed = 87283
		var streak = 0
		var uniform_max = 0
		for i in range(200000):
			streak = 0 if uniform.randf() < float(model.chance) else streak+1
			uniform_max = maxi(uniform_max,streak)
		distributions.append({"event":id,"nominal_rate":model.chance,"observed_rate":successes/200000.0,"coefficient":model.coefficient,"max_smoothed_failure_streak":maximum_streak,"max_uniform_failure_streak":uniform_max})
		owner.proc_failures[id] = ceili(1.0/float(model.coefficient))-1
		check(GemProcRandom.roll(rng,owner,id) and owner.proc_failures[id] == 0,"guaranteed trigger resets only this event's counter: "+id)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var tower: Dictionary = {}
	GemProcRandom.roll(rng,tower,"tower_baoji1")
	var first = int(tower.proc_failures.tower_baoji1)
	GemProcRandom.roll(rng,tower,"tower_aojiao")
	check(first == tower.proc_failures.tower_baoji1,"independent events on the same unit do not reset each other's history")
	var other: Dictionary = {}
	GemProcRandom.roll(rng,other,"tower_baoji1")
	check(other.proc_failures != tower.proc_failures,"distinct units keep distinct failure dictionaries")
	var combat = fixture("fenhongzuanshi")
	combat.run.board.cells[at].proc_failures = {"tower_baoji1":17}
	combat.start()
	check(combat.run.board.cells[at].proc_failures.tower_baoji1 == 17,"starting the next wave preserves a kept tower's smoothed history")
	var state = combat.run
	state.phase = "build"
	var checkpoint = JSON.parse_string(JSON.stringify(state.snapshot()))
	var restored = GemRun.new(1)
	check(restored.restore(checkpoint) and restored.board.cells[at].proc_failures.tower_baoji1 == 17,"JSON build checkpoint restores the failure counter")
	var clone_rng = RandomNumberGenerator.new()
	clone_rng.state = state.combat_rng.state
	var matched = true
	for i in range(500):
		var left = GemProcRandom.roll(state.combat_rng,state.board.cells[at],"tower_baoji1")
		var right = GemProcRandom.roll(clone_rng,restored.board.cells[at],"tower_baoji1")
		matched = matched and left == right
	check(matched and state.combat_rng.state == clone_rng.state and state.board.cells[at].proc_failures == restored.board.cells[at].proc_failures,"restored state reproduces 500 subsequent rolls without extra draws")
	for bad in [-1,1.5,99999,"17",true]:
		var altered = checkpoint.duplicate(true)
		altered.cells[0].gem.proc_failures.tower_baoji1 = bad
		check(not GemRun.new(1).restore(altered),"invalid or impossible saved counter is rejected: "+str(bad))
	var altered = checkpoint.duplicate(true)
	altered.cells[0].gem.proc_failures = {"enemy_bukeqinfan":0}
	check(not GemRun.new(1).restore(altered),"a tower cannot restore a defender ability it does not own")
	combat = fixture("fenhongzuanshi")
	combat.run.board.cells[at].proc_failures = {"tower_baoji1":ceili(1.0/float(models.tower_baoji1.coefficient))-1}
	combat.enemies[0].evasion = 1.0
	var hp = float(combat.enemies[0].hp)
	combat.attack(at,gem("fenhongzuanshi"),GemCatalog.stats(gem("fenhongzuanshi")),combat.enemies[0])
	check(combat.enemies[0].hp == hp and combat.run.board.cells[at].proc_failures.tower_baoji1 == 0,"attack-start critical counter rolls even if the later primary attack misses")
	var rng_before = combat.run.combat_rng.state
	combat.on_hit(at,GemCatalog.DATA.ability_effects.tower_baoji1[0],combat.enemies[0],1)
	check(rng_before == combat.run.combat_rng.state,"attack-start definitions do not burn an unused second roll on hit")
	combat = fixture("diamond")
	var enemy: Dictionary = combat.enemies[0]
	enemy.abilities.append("enemy_bukeqinfan")
	enemy.proc_failures = {"enemy_bukeqinfan":ceili(1.0/float(models.enemy_bukeqinfan.coefficient))-1}
	combat.attack(at,gem("diamond"),GemCatalog.stats(gem("diamond")),enemy)
	check(combat.towers[at].disabled == combat.elapsed+1 and enemy.proc_failures.enemy_bukeqinfan == 0,"defender PRD belongs to the attacked enemy and triggers its source disarm")
	var journal = GemReviewJournal.new()
	state = GemRun.new(123)
	state.board.cells.clear()
	state.board.cells[at] = gem("fenhongzuanshi")
	state.board.cells[at].proc_failures = {"tower_baoji1":19}
	state.board.rebuild()
	combat = GemCampaignCombat.new(state)
	journal.reset(state,true)
	var start = func():
		combat.start()
		journal.begin_wave(state)
	state.combat_started.connect(start)
	var record = journal.record.bind(combat)
	state.action_recorded.connect(record)
	for p in [Vector2i(8,12),Vector2i(9,12),Vector2i(10,12),Vector2i(11,12),Vector2i(12,12)]: state.place(p)
	state.keep(Vector2i(8,12))
	for i in range(300): combat.tick(1.0/30.0)
	if state.phase != "combat": journal.complete_wave(state,combat)
	var report = JSON.parse_string(JSON.stringify(journal.export_report(state,combat)))
	var result = GemReviewReplay.replay(report)
	check(result.ok,"JSON action report independently replays a tower with existing PRD history: "+str(result.error))
	state.action_recorded.disconnect(record)
	state.combat_started.disconnect(start)
	state = GemRun.new(42)
	state.board.cells.clear()
	var recipe = GemCatalog.recipe("standard:gemtd_juxingfenhongzuanshi")
	for i in range(recipe.ingredients.size()):
		var item = gem(recipe.ingredients[i][0],int(recipe.ingredients[i][1]))
		if item.kind == "fenhongzuanshi": item.proc_failures = {"tower_baoji1":17}
		state.board.cells[at+Vector2i(i*3,0)] = item
	state.board.rebuild()
	check(state.combine("standard:gemtd_juxingfenhongzuanshi",at,true) and not state.board.cells[at].has("proc_failures"),"crafting a new tower resets consumed entities' PRD history")
	var natural = gem("tianranzumulv")
	natural.stolen_abilities = ["tower_baoji1"]
	natural.proc_failures = {"tower_baoji1":17}
	check(GemProcRandom.valid_counters(natural),"Natural Emerald can save a counter for its copied critical ability")
	DirAccess.make_dir_recursive_absolute("res://output")
	var file = FileAccess.open("res://output/prd-distribution.json",FileAccess.WRITE)
	if file == null:
		check(false,"distribution report can be written")
		quit(1)
		return
	file.store_string(JSON.stringify({"game_version":GemRelease.version(),"seed":87283,"attempts_per_event":200000,"events":distributions,"limits":"Reproducible standalone sampling, not a measurement of Valve's implementation."},"  "))
	file.close()
	print("PROC_RANDOM_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
