extends "res://tests/check_campaign.gd"

func run_checks() -> void:
	for index in [10,20,30,40,50]:
		var combat = fixture("diamond",1,index)
		combat.deal(combat.enemies[0],1e15,"pure")
		check(combat.run.gold == 150 and combat.run.quality_discount == 150 and combat.run.discounted_bosses == [index],"defeated base boss grants unchanged gold plus separate discount: "+str(index))
		combat.deal(combat.enemies[0],1e15,"pure")
		check(not combat.run.award_boss_discount() and combat.run.quality_discount == 150 and combat.run.gold == 150,"dead boss and repeated award cannot pay twice: "+str(index))
	var combat = fixture("diamond",1,60)
	combat.deal(combat.enemies[0],1e15,"pure")
	check(combat.run.gold == 150 and combat.run.quality_discount == 0,"trial boss keeps gold but grants no base-boss discount")
	combat = fixture("diamond",1,10)
	combat.run.leaked(100,true)
	check(combat.run.quality_discount == 0 and combat.run.discounted_bosses.is_empty(),"escaped boss grants no discount")
	var state = GemRun.new(42)
	state.phase = "combat"
	state.wave = 10
	state.award_boss_discount()
	state.quality = 1
	state.gold = 249
	var rng_before = state.rng.state
	check(state.quality_price() == 250 and not state.buy_quality() and state.quality_discount == 150 and state.gold == 249 and state.rng.state == rng_before,"unaffordable reduced price preserves gold, credit, quality and placement RNG")
	state.gold = 250
	check(state.buy_quality() and state.gold == 0 and state.quality == 2 and state.quality_discount == 0,"manual purchase spends reduced price and consumes the applied discount")
	state = GemRun.new(42)
	state.phase = "combat"
	for index in [10,20,30]:
		state.wave = index
		state.award_boss_discount()
	state.wave = 31
	state.phase = "build"
	check(state.quality == 0 and state.quality_discount == 450 and state.gold == 0,"awarding several bosses never auto-buys gem odds or adds spendable gold")
	check(state.quality_price() == 0 and state.buy_quality() and state.quality_discount == 200 and state.gold == 0,"free purchase consumes only its base cost and carries unused credit")
	check(state.quality_price() == 200,"carried credit reduces the following purchase")
	state.gold = 200
	state.place(Vector2i(12,12))
	var revealed = state.board.cells[Vector2i(12,12)].duplicate(true)
	check(state.buy_quality() and state.quality_discount == 0 and state.gold == 0 and state.board.cells[Vector2i(12,12)] == revealed,"purchase affects future odds and leaves already revealed gems unchanged")
	state.board.cells.clear()
	state.placed = 0
	state.phase = "combat"
	state.wave = 40
	state.award_boss_discount()
	state.phase = "build"
	state.wave = 41
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(state.snapshot()))
	var restored = GemRun.new(1)
	check(restored.restore(snapshot) and restored.quality_discount == 150 and restored.discounted_bosses == [10,20,30,40] and restored.quality_price() == 400,"JSON checkpoint restores banked credit, paid bosses and next purchase price")
	for bad in [-1,1.5,751,"150",true]:
		var altered = snapshot.duplicate(true)
		altered.quality_discount = bad
		check(not GemRun.new(1).restore(altered),"invalid saved discount rejected: "+str(bad))
	for bad in [[10,10],[20,10],[60],[40,50],[1],[10.5],[true],"10"]:
		var altered = snapshot.duplicate(true)
		altered.discounted_bosses = bad
		check(not GemRun.new(1).restore(altered),"invalid saved boss history rejected: "+str(bad))
	var altered = snapshot.duplicate(true)
	altered.discounted_bosses = []
	check(not restored.restore(altered) and restored.quality_discount == 150,"unearned credit rejected without mutating an existing run")
	for kills_per_wave in [5,8,10,12,15]:
		state = GemRun.new(1)
		var xp = 0
		var xp_level = 0
		var thresholds = [0,250,650,1200,1900]
		var matches = true
		for index in range(1,51):
			state.wave = index
			state.phase = "combat"
			var boss = index%10 == 0
			var reward = 5+5*((index-1)/10)
			for kill in range(1 if boss else kills_per_wave):
				state.killed(150 if boss else reward)
				xp += 300 if boss else reward
				if boss: state.award_boss_discount()
				while xp_level < 4 and xp >= thresholds[xp_level+1]: xp_level+=1
				while state.quality < 4 and state.gold >= state.quality_price(): state.buy_quality()
				matches = matches and state.quality == xp_level
		check(matches,"production economy matches source XP affordability in synthetic kill case: "+str(kills_per_wave))
	# Replay a real base-boss death from a deliberately strong test checkpoint.
	state = GemRun.new(42)
	state.wave = 10
	state.board.cells.clear()
	for x in range(3,10): state.board.cells[Vector2i(x,3)] = gem("jingangshikulinan")
	state.board.rebuild()
	var journal = GemReviewJournal.new()
	combat = GemCampaignCombat.new(state)
	journal.reset(state,true)
	var start = func():
		combat.start()
		journal.begin_wave(state)
	state.combat_started.connect(start)
	var record = journal.record.bind(combat)
	state.action_recorded.connect(record)
	for x in range(12,17): state.place(Vector2i(x,12))
	state.keep(Vector2i(12,12))
	for i in range(10000):
		if state.phase != "combat": break
		combat.tick(1.0/30.0)
	journal.complete_wave(state,combat)
	check(state.wave == 11 and state.quality_discount == 150 and state.gold == 150,"strong fixture kills boss through normal combat and banks its discount")
	check(state.buy_quality() and state.gold == 50,"post-boss manual purchase costs 100 gold after discount")
	var report: Dictionary = JSON.parse_string(JSON.stringify(journal.export_report(state,combat)))
	var result = GemReviewReplay.replay(report)
	check(result.ok,"independent replay reproduces boss award and discounted purchase: "+str(result.error))
	altered = report.duplicate(true)
	altered.quality_discount = 1
	check(not GemReviewReplay.replay(altered).ok,"replay rejects tampered final credit")
	altered = report.duplicate(true)
	altered.discounted_bosses = []
	check(not GemReviewReplay.replay(altered).ok,"replay rejects tampered paid-boss history")
	altered = report.duplicate(true)
	altered.actions.back().cost = 250
	check(not GemReviewReplay.replay(altered).ok,"replay rejects purchase history claiming the wrong paid price")
	state.action_recorded.disconnect(record)
	state.combat_started.disconnect(start)
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	game.run.quality = 1
	game.run.quality_discount = 150
	game.run.gold = 250
	game.refresh_ui()
	check(game.quality_button.text.contains("250 gold") and not game.quality_button.disabled and game.odds_label.text.contains("150 gold") and game.quality_button.tooltip_text.contains("Base price 400"),"UI shows actual price, banked credit and base-price explanation")
	game.run.quality_discount = 450
	game.run.gold = 0
	game.refresh_ui()
	check(game.quality_button.text.contains("0 gold") and not game.quality_button.disabled,"free manual purchase is enabled with zero gold")
	game.run.quality = 4
	game.refresh_ui()
	check(game.quality_button.disabled and not game.odds_label.text.contains("Boss discount"),"maximum quality hides unused discount and disables buying")
	check(GemWaveGuide.brief(GemCatalog.wave(10),10).contains("+150 saved") and not GemWaveGuide.brief(GemCatalog.wave(60),60).contains("+150 saved"),"wave guide distinguishes base boss discount from trial gold")
	game.free()
	await process_frame
	GemCatalog.select_profile("review-v1")
	state = GemRun.new(1)
	state.gold = 20
	state.quality_discount = 150
	check(state.quality_price() == 20 and state.buy_quality() and state.gold == 0 and not state.snapshot().has("quality_discount"),"version 1.0 profile retains its original purchase and save rules")
	print("BOSS_DISCOUNT_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
