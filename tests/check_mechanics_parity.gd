extends SceneTree

var checks = 0
var failures = 0
const AT = Vector2i(18,18)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)

func gem(kind: String, tier: int = 1, fresh: bool = false) -> Dictionary:
	return {"kind":kind,"tier":tier,"fresh":fresh,"priority":"First"}

func material_run(recipe: String) -> GemRun:
	var state = GemRun.new(42)
	state.board.cells.clear()
	var i = 0
	for requirement in GemCatalog.recipe(recipe).ingredients:
		state.board.cells[AT+Vector2i(i*3,0)] = gem(requirement[0],int(requirement[1]))
		i += 1
	state.board.rebuild()
	return state

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var state = GemRun.new(2)
	state.streak = -49
	state.leaked(1,false)
	check(state.enemy_count == 9 and state.streak == -2 and state.lives == 99,"leak applies triple actual life damage and crosses negative streak threshold")
	state.enemy_count = 5
	state.streak = -49
	state.leaked(25,false)
	check(state.enemy_count == 5 and state.streak == -24,"multiple negative thresholds retain minimum encounter count")
	var recipe = "standard:gemtd_tianranzumulv"
	state = material_run(recipe)
	state.board.cells[AT+Vector2i(0,1)] = gem("opal")
	state.board.cells[AT+Vector2i(1,0)] = gem("opal")
	state.board.cells[AT+Vector2i(0,-1)] = gem("opal",2)
	var pool = GemCampaignRules.steal_pool(AT,state.board.cells)
	var opal_id = GemCatalog.stats(gem("opal")).abilities.filter(func(id): return id in GemCatalog.DATA.mechanics.stealable_abilities)[0]
	check(pool.count(opal_id) == 2 and "tower_true_sight" not in pool,"Emerald draw pool preserves donor weighting and excludes true sight")
	check(state.combine(recipe,AT,true) and state.board.cells[AT].stolen_abilities.size() <= 3,"Emerald copies at most three unique allowed abilities")
	check(state.board.cells[AT].stolen_abilities.all(func(id): return id in GemCatalog.DATA.mechanics.stealable_abilities),"crafted Emerald uses source allowlist")
	state = GemRun.new(111)
	state.board.cells.clear()
	var rng_before = state.rng.state
	check(not state.downgrade(AT) and state.rng.state == rng_before,"invalid downgrade does not consume RNG")
	var guide = GemBuildGuide.new()
	guide.bind(state)
	for tier in range(2,7):
		var seen: Dictionary = {}
		for i in range(300):
			state.phase = "build"
			state.placed = 5
			state.board.cells = {AT:gem("diamond",tier,true),AT+Vector2i(0,2):gem("ruby",1,true)}
			var plan = guide.action({"type":"downgrade"},AT)
			if i == 0: check(plan.valid and plan.message.contains("random lower quality"),"downgrade previews odds without rolling quality "+str(tier))
			var accepted = state.downgrade(AT)
			var result = int(state.board.cells[AT].tier)
			if not accepted or result < 1 or result >= tier: failures += 1
			seen[result] = true
		check(seen.size() == tier-1 and state.phase == "combat" and state.board.cells[AT+Vector2i(0,2)].kind == "stone","all lower qualities reachable; downgrade consumes final choice: "+str(tier))
	state = material_run("standard:gemtd_kongqueshi")
	state.board.cells[AT+Vector2i(0,2)] = gem("diamond",2)
	state.phase = "combat"
	var combat = GemCampaignCombat.new(state)
	combat.start()
	combat.spawn_enemy()
	combat.spawned = int(combat.wave_data.count)
	var enemy: Dictionary = combat.enemies[0]
	enemy.hp = 1e9
	enemy.hp_max = 1e9
	enemy.pos = Vector2(AT)+Vector2(.5,.5)
	combat.ground = PackedVector2Array([enemy.pos,enemy.pos+Vector2(1000,0)])
	combat.elapsed = 7
	combat.cooldowns[AT+Vector2i(0,2)] = .7
	var enemy_id = enemy.id
	check(state.combine("standard:gemtd_kongqueshi",AT,true),"older tower recipe is accepted during combat")
	combat.tick(1.0/30)
	check(combat.elapsed > 7 and combat.enemies[0].id == enemy_id and combat.spawned > 0,"combat combination preserves enemies, time and spawn progress")
	check(combat.towers[AT].gem_ref.kind == "malachite" and combat.towers.size() == 2,"runtime combat roster removes materials and adds resulting tower")
	check(is_equal_approx(combat.cooldowns[AT+Vector2i(0,2)],.7-1.0/30),"unconsumed tower retains attack cooldown")
	check(not state.place(Vector2i(15,15)) and not state.demolish(AT),"combat combinations do not unlock placements or demolition")
	# Berserk follows simulated time and affects existing and later spawns.
	state = GemRun.new(2)
	state.board.cells.clear()
	state.board.rebuild()
	state.phase = "combat"
	combat = GemCampaignCombat.new(state)
	combat.start()
	combat.spawn_enemy()
	enemy = combat.enemies[0]
	enemy.pos = Vector2(AT)+Vector2(.5,.5)
	combat.ground = PackedVector2Array([enemy.pos,enemy.pos+Vector2(1000,0)])
	combat.elapsed = 180-1.0/30
	combat.tick(1.0/30)
	check(not combat.berserk,"berserk does not trigger before source threshold is exceeded")
	var before: Vector2 = enemy.pos
	combat.tick(1.0/30)
	check(combat.berserk and enemy.magic_immune and enemy.pos.distance_to(before) > float(enemy.speed)/30*1.9,"berserk doubles base movement and grants magic immunity")
	combat.spawn_enemy()
	check(combat.enemies.back().magic_immune,"late spawns inherit berserk")
	combat.attacker = AT
	var hp = float(enemy.hp)
	combat.deal(enemy,1,"magical")
	check(enemy.hp == hp,"berserk immunity blocks magic damage")
	combat.start()
	check(not combat.berserk,"new wave clears berserk")
	# Calendar and selected alternatives persist across saves and trial repeats.
	state = GemRun.new(42)
	state.reference_calendar = {"month":10,"day":22}
	state.wave = 20
	state.phase = "combat"
	combat = GemCampaignCombat.new(state)
	combat.start()
	check(combat.wave_data.source_id == "gemtd_yuediyang_boss","calendar boss is selected under source day rules")
	state.wave = 70
	combat.start()
	check(combat.wave_data.source_id == "gemtd_yuediyang_boss" and combat.wave_data.reward == 5 and combat.wave_data.trial,"trial reuses chosen boss with trial rewards and scaling flag")
	var restored = GemRun.new(1)
	var snapshot = JSON.parse_string(JSON.stringify(state.snapshot()))
	var did_restore = restored.restore(snapshot)
	check(did_restore and int(restored.reference_calendar.month) == int(state.reference_calendar.month) and int(restored.reference_calendar.day) == int(state.reference_calendar.day) and restored.wave_choices == state.wave_choices and restored.phase == "intermission","trial checkpoint restores calendar and choices without granting gems: restored=%s phase=%s choices=%s" % [did_restore,restored.phase,restored.wave_choices])
	check(not restored.place(AT),"resumed trial has no gem placement")
	restored.gold = 10000
	check(not restored.buy_quality() and restored.gold == 10000,"trials prevent spending gold on odds for unavailable gems")
	var altered = snapshot.duplicate(true)
	altered.wave_choices["20"] = "not_a_source_unit"
	check(not GemRun.new(1).restore(altered),"saved wave choice rejects unknown enemy identity")
	for bad in [null,"October",1.5,true,13]:
		altered = snapshot.duplicate(true)
		altered.reference_calendar.month = bad
		check(not GemRun.new(1).restore(altered),"malformed saved calendar is rejected atomically: "+str(bad))
	for key in GemCatalog.DATA.wave_alternatives:
		for alternate in GemCatalog.DATA.wave_alternatives[key]:
			var variant_state = GemRun.new(9)
			variant_state.wave = int(key)
			variant_state.wave_choices[key] = alternate.source_id
			var variant_combat = GemCampaignCombat.new(variant_state)
			variant_combat.start()
			variant_combat.spawn_enemy()
			var variant_enemy: Dictionary = variant_combat.enemies[0]
			check(variant_enemy.source_id == alternate.source_id and variant_enemy.air == alternate.air and is_equal_approx(float(variant_enemy.hp),float(alternate.hp)),"alternative wave spawns its real source values: "+str(alternate.source_id))
			check(GemArt.texture(GemArt.sprite_id("enemies",alternate.source_id)) != null,"alternative has a replaceable family sprite binding: "+str(alternate.source_id))
	state = GemRun.new(42)
	state.reference_calendar = {"month":10,"day":31}
	state.wave = 20
	combat = GemCampaignCombat.new(state)
	combat.start()
	check(combat.wave_data.source_id == GemCatalog.wave(20).source_id,"last calendar day excludes month-end boss per source condition")
	# Full trial transition fixture: legal content plus an explicitly synthetic attack tower.
	GemCatalog.DATA.specials["trial_phase_fixture"] = {"name":"Phase fixture","color":"#ffffff","damage":1e12,"range":10000.0,"interval":.01,"projectile_speed":1e9,"targets":"both","abilities":[],"effect":"test fixture"}
	state = GemRun.new(2)
	state.board.cells.clear()
	state.board.cells[AT] = gem("trial_phase_fixture")
	state.board.rebuild()
	state.wave = 50
	state.phase = "combat"
	combat = GemCampaignCombat.new(state)
	var starts: Array[int] = []
	var next_trial = func():
		combat.start()
		combat.wave_data.count = 1
		starts.append(state.wave)
	state.combat_started.connect(next_trial)
	next_trial.call()
	for i in range(60000):
		if state.phase in ["won","lost","build"]: break
		combat.tick(1.0/30)
	check(state.phase == "won" and state.wave == 100 and starts.size() == 51 and state.placed == 0,"wave 50 through 100 automatically finish without any new gems in a synthetic phase fixture")
	state.combat_started.disconnect(next_trial)
	# A resumed natural trial checkpoint can be replayed during countdown and combat.
	state = GemRun.new(4)
	state.wave = 51
	var trial_snapshot = JSON.parse_string(JSON.stringify(state.snapshot()))
	state.restore(trial_snapshot)
	var trial_journal = GemReviewJournal.new()
	trial_journal.reset(state,true)
	combat = GemCampaignCombat.new(state)
	var trial_start = func():
		combat.start()
		trial_journal.begin_wave(state)
	state.combat_started.connect(trial_start)
	for i in range(20): combat.tick(1.0/30)
	var trial_report = JSON.parse_string(JSON.stringify(trial_journal.export_report(state,combat)))
	check(GemReviewReplay.replay(trial_report).ok,"report independently replays a partially elapsed trial countdown")
	for i in range(100): combat.tick(1.0/30)
	trial_report = JSON.parse_string(JSON.stringify(trial_journal.export_report(state,combat)))
	check(GemReviewReplay.replay(trial_report).ok,"report independently replays automatic transition into a trial")
	state.combat_started.disconnect(trial_start)
	# Natural action log: downgrade followed by a combat recipe, independently replayed.
	state = material_run("standard:gemtd_baiyin")
	state.quality = 4
	var journal = GemReviewJournal.new()
	journal.reset(state,true)
	combat = GemCampaignCombat.new(state)
	var record = journal.record.bind(combat)
	var start = func():
		combat.start()
		journal.begin_wave(state)
	state.action_recorded.connect(record)
	state.combat_started.connect(start)
	for p in [Vector2i(10,10),Vector2i(10,12),Vector2i(10,14),Vector2i(10,16),Vector2i(10,18)]: state.place(p)
	var selected = state.fresh_cells().filter(func(p): return int(state.board.cells[p].tier)>1)
	check(not selected.is_empty() and state.downgrade(selected[0]),"actual reveal can use downgrade for replay")
	for i in range(30): combat.tick(1.0/30)
	state.combine("standard:gemtd_baiyin",AT,true)
	for i in range(10): combat.tick(1.0/30)
	var report = JSON.parse_string(JSON.stringify(journal.export_report(state,combat)))
	var replayed = GemReviewReplay.replay(report)
	check(replayed.ok,"independent replay reproduces downgrade, runtime recipe and combat: "+str(replayed.error))
	state.action_recorded.disconnect(record)
	state.combat_started.disconnect(start)
	# Real controller: buildless trial countdown respects pause and starts automatically.
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	game.set_process(false)
	game.run.board.cells.clear()
	game.run.board.cells[AT] = gem("diamond",3,true)
	for y in [10,12,14,16]: game.run.board.cells[Vector2i(10,y)] = gem("ruby",1,true)
	game.run.placed = 5
	game.on_cell_clicked(AT)
	game.downgrade_button.mouse_entered.emit()
	check(game.board_view.action_plan.valid and game.downgrade_button.tooltip_text.contains("66%"),"real downgrade button displays source quality probabilities")
	game.downgrade_button.pressed.emit()
	check(game.run.phase == "combat" and int(game.run.board.cells[AT].tier)<3 and not game.downgrade_button.visible,"UI downgrade consumes final choice and starts combat")
	game.run.wave = 50
	game.run.phase = "combat"
	game.run.finish_wave()
	check(game.run.wave == 51 and game.run.phase == "intermission" and game.run.placed == 0,"wave 50 transitions to trial wait without a building round")
	var wait = game.run.trial_wait
	game.paused = true
	game._process(.2)
	check(game.run.trial_wait == wait,"pause freezes trial countdown")
	game.paused = false
	for i in range(100): game._process(1.0/30)
	check(game.run.phase == "combat" and game.run.wave == 51 and not game.round_tray.visible,"trial countdown starts wave automatically and hides new gem tray")
	game.audio.player.stop()
	game.audio.attack_player.stop()
	game.queue_free()
	await process_frame
	print("MECHANICS_PARITY_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
