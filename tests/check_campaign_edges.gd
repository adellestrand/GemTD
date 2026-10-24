extends "res://tests/check_campaign.gd"

func run_checks() -> void:
	var combat = fixture("palayibabixi")
	var enemy: Dictionary = combat.enemies[0]
	enemy.base_armor = 10.0
	combat.update_enemy(enemy,0)
	check(enemy.armor == 0.0,"Paraiba armor aura applies its exact -10 armor")
	combat = fixture("furongshi")
	enemy = combat.enemies[0]
	enemy.base_armor = 10.0
	combat.update_enemy(enemy,0)
	check(enemy.armor == 10.0,"Quartz aura honors the original Ancient exclusion")
	enemy.ancient = false
	combat.update_enemy(enemy,0)
	check(enemy.armor == 0.0 and enemy.current_properties.move_constant == -250.0,"Quartz applies both armor and movement effects to eligible enemies")
	combat = fixture("opal")
	combat.run.board.cells[at+Vector2i(1,0)] = gem("opal")
	var timing = GemCampaignRules.timing(gem("diamond"),at,combat.run.board.cells)
	check(timing.bonus == 20.0,"equal-quality Opal supports do not stack")
	combat.run.board.cells[at+Vector2i(2,0)] = gem("opal",2)
	timing = GemCampaignRules.timing(gem("diamond"),at,combat.run.board.cells)
	check(timing.bonus == 50.0,"different Opal quality modifiers do stack")
	combat = fixture("malachite")
	combat.spawn_enemy()
	for e in combat.enemies:
		e.pos = Vector2(at)+Vector2(.5,.5)
		e.hp = 1000.0
		e.armor = 0.0
		e.evasion = 1.0
	combat.attack(at,gem("malachite"),GemCatalog.stats(gem("malachite")),combat.enemies[0])
	check(combat.enemies[0].hp == 1000.0 and combat.enemies[1].hp < 1000.0,"split damage still hits a secondary enemy when the primary evades")
	combat = fixture("diamond",1,14)
	enemy = combat.enemies[0]
	enemy.refraction = 7
	var health = enemy.hp
	for i in range(7): combat.deal(enemy,100,"pure")
	check(enemy.hp == health and enemy.refraction == 0,"refraction consumes exactly seven blocking charges")
	combat.deal(enemy,100,"pure")
	check(enemy.hp == health-100,"the following hit passes through exhausted refraction")
	combat = fixture("diamond")
	combat.run.board.cells[at].mvp = 10
	combat.start()
	combat.spawn_enemy()
	enemy = combat.enemies[0]
	enemy.hp = 1000000.0
	enemy.pos = Vector2(at)+Vector2(.5,.5)
	combat.attacker = at
	health = enemy.hp
	combat.deal(enemy,100,"pure")
	check(enemy.hp == health-200,"MVP level 10 doubles all source damage types")
	combat.wave_damage[at] = 1000.0
	combat.run.board.cells[at+Vector2i.ONE] = gem("ruby")
	combat.wave_damage[at+Vector2i.ONE] = 100.0
	combat.award_mvp()
	check(combat.run.board.cells[at+Vector2i.ONE].mvp == 1,"a max-level tower leaves the next MVP award to an eligible tower")
	var supports: Dictionary = {}
	for i in range(6):
		var p = at+Vector2i((i%3)-1,(i/3)-1)
		supports[p] = gem("opal")
		supports[p].mvp = 10
	check(GemCampaignRules.mvp_bonus(gem("ruby"),at,supports) == 500.0,"multiple max-level MVP auras respect the original +500 percent cap")
	var merge_state = GemRun.new(42)
	merge_state.board.cells[at] = gem("sapphire")
	merge_state.board.cells[at].mvp = 7
	merge_state.board.cells[at+Vector2i(3,0)] = gem("topaz")
	merge_state.board.cells[at+Vector2i(3,0)].mvp = 6
	merge_state.board.cells[at+Vector2i(6,0)] = gem("diamond")
	check(merge_state.combine("standard:gemtd_baiyin",at,true) and merge_state.board.cells[at].mvp == 10,"combining older towers carries their MVP levels into the result, capped at ten")
	var guardian_state = GemRun.new(1234)
	var guardian_recipe = GemCatalog.recipe("standard:gemtd_huguoshenyishi")
	for i in range(guardian_recipe.ingredients.size()): guardian_state.board.cells[at+Vector2i(i*3,0)] = gem(guardian_recipe.ingredients[i][0],int(guardian_recipe.ingredients[i][1]))
	guardian_state.board.rebuild()
	var guardian_journal = GemReviewJournal.new()
	guardian_journal.reset(guardian_state,true)
	var guardian_combat = GemCampaignCombat.new(guardian_state)
	var guardian_record = guardian_journal.record.bind(guardian_combat)
	guardian_state.action_recorded.connect(guardian_record)
	check(guardian_state.combine("standard:gemtd_huguoshenyishi",at,true) and int(guardian_state.board.cells[at].rolled_damage) in range(30,1025),"Guardian Stone rolls source-bounded attack damage during creation")
	var guardian_report = JSON.parse_string(JSON.stringify(guardian_journal.export_report(guardian_state,guardian_combat)))
	check(GemReviewReplay.replay(guardian_report).ok,"Guardian's creation RNG and rolled attack survive JSON report replay")
	check(GemRun.new(1).restore(JSON.parse_string(JSON.stringify(guardian_state.snapshot()))),"a rolled Guardian attack survives a build checkpoint")
	guardian_state.action_recorded.disconnect(guardian_record)
	merge_state.wave = 51
	combat = GemCampaignCombat.new(merge_state)
	combat.wave_damage[at+Vector2i(6,0)] = 1000.0
	combat.award_mvp()
	check(not merge_state.board.cells[at+Vector2i(6,0)].has("mvp"),"trial waves do not award further MVP levels")
	combat = fixture("diamond",1,32)
	enemy = combat.enemies[0]
	enemy.hp = enemy.hp_max*.5
	var before = float(enemy.hp)
	combat.update_enemy(enemy,1)
	check(is_equal_approx(float(enemy.hp)-before,float(enemy.hp_max)*.003),"regeneration heals 0.3 percent maximum health per second")
	combat.add_modifier(enemy,{"id":"test_no_heal","duration":10,"properties":{"no_healing":true}},at)
	before = float(enemy.hp)
	combat.update_enemy(enemy,1)
	check(enemy.hp == before,"anti-healing blocks regeneration")
	combat = fixture("diamond")
	enemy = combat.enemies[0]
	var origin: Vector2 = enemy.pos
	combat.blink_forward(enemy,PackedVector2Array([origin,origin+Vector2(100,0)]))
	check(is_equal_approx(origin.distance_to(enemy.pos),925.0/128.0) and is_equal_approx(enemy.travelled,925.0/128.0),"blink respects its source world-distance limit on sparse air-style routes and advances target priority distance")
	combat = fixture("diamond",1,40)
	enemy = combat.enemies[0]
	combat.add_modifier(enemy,{"id":"test_slow","duration":10,"properties":{"move_constant":-100}},at)
	combat.deal(enemy,80000,"pure")
	check(enemy.mods.is_empty(),"Kraken-style cleanse removes debuffs at the source damage threshold")
	combat = fixture("diamond")
	combat.spawn_enemy()
	for e in combat.enemies:
		e.hp = 1000.0
		e.base_magic = 0.0
		e.magic_resist = 0.0
		e.pos = Vector2(at)+Vector2(.5,.5)
	var cask = {"id":"test_cask","type":"slab","mode":"cask","duration":1,"radius":0.0,"jump_radius":10,"interval":.2}
	combat.delayed.append({"at":0.0,"type":"chain","source":at,"target":combat.enemies[0],"effect":cask,"left":4,"visited":[]})
	combat.towers.clear()
	for i in range(30): combat.tick(1.0/30.0)
	check(combat.delayed.is_empty() and combat.enemies.all(func(e): return e.mods.has("test_cask")),"cask can revisit two living targets until its finite bounce budget ends")
	var state = GemRun.new(42)
	state.board.cells.clear()
	state.board.rebuild()
	state.board.slabs[at] = "youbushiban"
	var rng_before = state.rng.state
	check(not state.move_slab(at,Vector2i(4,4)) and state.board.slabs.has(at) and state.rng.state == rng_before,"protected start corner rejects trap movement atomically")
	for source in GemCatalog.DATA.slab_upgrades:
		state.board.slabs = {at-Vector2i(1,1):source,at:source,at+Vector2i(1,1):source}
		state.upgrade_slabs()
		check(state.board.slabs.size() == 1 and state.board.slabs[at] == GemCatalog.DATA.slab_upgrades[source],"diagonal automatic trap upgrade: "+source)
	state = GemRun.new(42)
	state.board.cells[at] = gem("emerald",3)
	state.board.cells[at+Vector2i(3,0)] = gem("opal",3)
	state.board.cells[at+Vector2i(6,0)] = gem("sapphire",2)
	state.board.slabs[Vector2i(20,20)] = "youbushiban"
	state.board.rebuild()
	var journal = GemReviewJournal.new()
	journal.reset(state,true)
	combat = GemCampaignCombat.new(state)
	var record = journal.record.bind(combat)
	var start = func():
		combat.start()
		journal.begin_wave(state)
	state.action_recorded.connect(record)
	state.combat_started.connect(start)
	state.move_slab(Vector2i(20,20),Vector2i(21,20))
	state.combine("standard:gemtd_yu",at,true)
	for x in range(10,15): state.place(Vector2i(x,14))
	state.keep(Vector2i(10,14))
	for i in range(90): combat.tick(1.0/30.0)
	var report = JSON.parse_string(JSON.stringify(journal.export_report(state,combat)))
	var result = GemReviewReplay.replay(report)
	check(result.ok,"campaign report replays crafting, trap movement and partial combat: "+str(result.error))
	state.action_recorded.disconnect(record)
	state.combat_started.disconnect(start)
	# Phase/progression fixture only: one spawned enemy per wave and a synthetic
	# omnipresent tower. This is not a natural run or evidence of game balance.
	GemCatalog.DATA.ability_effects["test_detection"] = [{"type":"support","id":"test_detection","radius":10000.0,"properties":{"true_sight":true}}]
	GemCatalog.DATA.specials["phase_fixture"] = {"name":"Phase fixture","color":"#ffffff","damage":10000000000.0,"range":10000.0,"interval":.01,"projectile_speed":1000000.0,"targets":"both","abilities":["test_detection"],"effect":"test only"}
	state = GemRun.new(42)
	state.board.cells.clear()
	state.board.cells[at] = gem("phase_fixture")
	state.board.rebuild()
	combat = GemCampaignCombat.new(state)
	var passed = 0
	var counts: Array = []
	for wave in range(1,101):
		state.phase = "combat"
		combat.start()
		counts.append(combat.wave_data.count)
		combat.wave_data.count = 1
		for i in range(900):
			combat.tick(1.0/30.0)
			if state.phase != "combat": break
		if state.phase == "combat" or state.phase == "lost": break
		passed += 1
	check(passed == 100 and state.phase == "won" and state.wave == 100,"all 100 wave completions advance to the next build or final victory in a phase fixture")
	check(counts.size() == 100 and counts[9] == 1 and counts[49] == 1 and counts[99] == 1,"boss waves retain one boss despite adaptive encounter size")
	print("CAMPAIGN_EDGES_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
