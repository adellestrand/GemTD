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
	var state = GemRun.new(1234567890123)
	var combat = GemCombat.new(state)
	var journal = GemReviewJournal.new()
	journal.reset(state,false)
	var record = journal.record.bind(combat)
	state.action_recorded.connect(record)
	var before = state.snapshot()
	state.place(state.board.checkpoints[0])
	check(journal.actions.is_empty() and before == state.snapshot(),"rejected placement never enters the accepted-action journal or consumes RNG")
	for x in range(10,15):
		state.place(Vector2i(x,10))
	check(journal.actions.size() == 5 and journal.actions[0].at == [10,10] and journal.actions[4].order == 5,"journal records each real placement and reveal in order")
	var p = Vector2i(10,10)
	state.keep(p)
	combat.start()
	journal.begin_wave(state)
	combat.elapsed = 2.0
	state.set_priority(p,"Last")
	check(journal.actions.back().action == "priority" and journal.actions.back().tick == 60,"target changes carry simulation ticks for reproducible feedback")
	var count = journal.actions.size()
	check(not state.set_priority(p,"Invalid") and not state.set_priority(Vector2i(11,10),"Last") and journal.actions.size() == count,"invalid priorities and stone targeting cannot create report actions")
	var running = journal.export_report(state,combat)
	check(running.waves.size() == 1 and running.waves[0].status == "in_progress" and journal.waves.is_empty(),"reading a partial battle report never completes its wave")
	# Use a fresh real simulation for replay equivalence, without synthetic kills.
	var replay_state = GemRun.new(7)
	var replay_combat = GemCombat.new(replay_state)
	var replay_journal = GemReviewJournal.new()
	replay_journal.reset(replay_state,false)
	var replay_record = replay_journal.record.bind(replay_combat)
	replay_state.action_recorded.connect(replay_record)
	for y in range(4,9):
		replay_state.place(Vector2i(5,y))
	replay_state.keep(Vector2i(5,4))
	replay_combat.start()
	replay_journal.begin_wave(replay_state)
	for tick in range(15):
		replay_combat.tick(1.0/30.0)
	replay_state.set_priority(Vector2i(5,4),"Nearest")
	var partial_report = JSON.parse_string(JSON.stringify(replay_journal.export_report(replay_state,replay_combat)))
	var partial_result = GemReviewReplay.replay(partial_report)
	check(partial_result.ok,"partial battle report replays accepted actions and their simulation ticks")
	for tick in range(6000):
		replay_combat.tick(1.0/30.0)
		if replay_state.phase != "combat":
			break
	replay_journal.complete_wave(replay_state,replay_combat)
	var complete_report = JSON.parse_string(JSON.stringify(replay_journal.export_report(replay_state,replay_combat)))
	check(GemReviewReplay.replay(complete_report).ok,"completed-wave report replays to the same board, lives, gold and next build phase")
	complete_report.actions[0].kind = "not_the_revealed_gem"
	check(not GemReviewReplay.replay(complete_report).ok,"replay rejects altered reveals rather than accepting a different run")
	replay_state.action_recorded.disconnect(replay_record)
	for i in range(8):
		state.killed(2)
	combat.elapsed = 12.5
	state.finish_wave()
	check(journal.complete_wave(state,combat) and not journal.complete_wave(state,combat),"wave completion is recorded exactly once")
	var report = journal.export_report(state,combat)
	check(report.waves[0].wave == 1 and report.waves[0].kills == 8 and report.waves[0].seconds == 12.5 and report.wave == 2,"report separates a completed wave from the following build phase")
	var decoded = JSON.parse_string(JSON.stringify(report))
	check(decoded.seed == "1234567890123" and decoded.starting_checkpoint.rng is String and decoded.game_version == GemRelease.version(),"JSON report preserves large seeds, RNG strings and release identity")
	report.actions[0].kind = "changed"
	report.starting_checkpoint.gold = 999
	check(journal.actions[0].kind != "changed" and journal.starting_checkpoint.gold == 0,"exported report data cannot mutate the journal or its initial checkpoint")
	state.action_recorded.disconnect(record)
	journal.reset(state,true)
	check(journal.actions.is_empty() and journal.waves.is_empty() and journal.resumed and journal.starting_checkpoint.wave == 2,"resumed report explicitly starts at its build checkpoint without old-session actions")
	for i in range(GemReviewJournal.MAX_ACTIONS+2):
		journal.record({"phase":"build","action":"test","wave":2},combat)
	check(journal.actions.size() == GemReviewJournal.MAX_ACTIONS and journal.truncated,"long sessions have bounded report storage and an explicit truncation flag")
	var baseline: Dictionary = load("res://data/balance_baseline.json").data
	check(GemRun.new(1).lives == int(baseline.prototype.starting_lives) and GemRun.new(1).gold == int(baseline.prototype.starting_gold),"starting economy matches the documented compressed-mode balance profile")
	check(str(ProjectSettings.get_setting("application/config/version")) == GemRelease.version(),"project and report version match the release manifest")
	print("REVIEW_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
