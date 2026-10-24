extends "res://tools/audit_runs.gd"

# Two limited deterministic strategies, never a human win-rate estimate.
var policy = "coverage"
var output_dir = "res://output/v1-playtest"

func audit() -> void:
	var runs = 10
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			runs = clampi(int(argument.trim_prefix("--runs=")),1,30)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var results: Array[Dictionary] = []
	for selected_policy in ["coverage","maze"]:
		policy = selected_policy
		for seed_value in range(1,runs+1):
			var report = play_review(seed_value)
			var path = "%s/%s-%02d.json" % [output_dir,policy,seed_value]
			var file = FileAccess.open(path,FileAccess.WRITE)
			file.store_string(JSON.stringify(report,"  "))
			file.close()
			results.append({"seed":seed_value,"policy":policy,"outcome":report.outcome,"wave":report.wave,"lives":report.lives,"kills":report.kills,"leaks":report.leaks,"waves":report.waves,"route_length":report.route_length,"error":report.get("error","")})
			print("V1_AUDIT policy=%s seed=%d result=%s wave=%d lives=%d" % [policy,seed_value,report.outcome,report.wave,report.lives])
	var sources: Dictionary = {}
	for path in ["data/catalog.json","game/core/combat.gd","game/core/run_state.gd","tools/audit_v1.gd","tools/audit_runs.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	var result = {"game_version":GemRelease.version(),"balance_profile":GemRelease.DATA.balance_profile,"source_sha256":sources,"runs_per_policy":runs,"results":results,"limitations":"Greedy upgrades and recipe use, no demolition, no long-term recipe planning. Maze policy greedily rewards route length and current tower exposure; it is not an optimized player."}
	var file = FileAccess.open(output_dir+"/index.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("V1_AUDIT_COMPLETE runs=%d wins=%d" % [results.size(),results.filter(func(r): return r.outcome == "won").size()])
	quit(1 if results.any(func(r): return not str(r.error).is_empty()) else 0)

func play_review(seed_value: int) -> Dictionary:
	var state = GemRun.new(seed_value)
	var combat = GemCombat.new(state)
	var journal = GemReviewJournal.new()
	journal.reset(state,false)
	var record_action = journal.record.bind(combat)
	var start_wave = func():
		combat.start()
		journal.begin_wave(state)
	state.action_recorded.connect(record_action)
	state.combat_started.connect(start_wave)
	var error = ""
	while state.phase == "build":
		while state.quality < 2 and state.gold >= state.quality_price():
			state.buy_quality()
		combine_old(state)
		while state.placed < 5:
			var placed = false
			for candidate in positions(state):
				if state.place(candidate.p):
					placed = true
					break
			if not placed:
				error = "No valid placement found"
				break
		if not error.is_empty():
			break
		var choice = choose(state)
		var p: Vector2i = choice.p
		var accepted = state.combine(choice.recipe,p) if choice.has("recipe") else state.upgrade(p,int(choice.count)) if int(choice.get("count",1)) > 1 else state.keep(p)
		if not accepted:
			error = state.message
			break
		for tick in range(36000):
			combat.tick(1.0/30.0)
			if state.phase != "combat":
				break
		if state.phase == "combat":
			error = "Wave exceeded 1200 seconds"
			break
		journal.complete_wave(state,combat)
	var report = journal.export_report(state,combat)
	report.policy = policy
	report.route_length = route_length(state.board.ground_route)
	if not error.is_empty():
		report.error = error
	state.action_recorded.disconnect(record_action)
	state.combat_started.disconnect(start_wave)
	return report

func positions(state: GemRun) -> Array[Dictionary]:
	var ranked = super.positions(state)
	if policy != "maze" or GemCatalog.wave(state.wave).air:
		return ranked
	var candidates: Dictionary = {}
	for row in ranked.slice(0,20):
		candidates[row.p] = true
	for i in range(0,state.board.ground_route.size(),3):
		var p = Vector2i(state.board.ground_route[i].floor())
		if not state.board.cells.has(p) and not state.board.checkpoints.has(p):
			candidates[p] = true
	var evaluated: Array[Dictionary] = []
	var previous = route_length(state.board.ground_route)
	for p in candidates:
		var preview = state.board.placement_preview(p)
		if not str(preview.error).is_empty():
			continue
		var exposure = 0.0
		for q in state.board.cells:
			if state.board.cells[q].kind != "stone":
				exposure += coverage(q,preview.route)
		var score = (route_length(preview.route)-previous)*8.0+coverage(p,preview.route)+exposure*.25
		evaluated.append({"p":p,"score":score})
	evaluated.sort_custom(func(a,b): return a.score > b.score if a.score != b.score else (a.p.y*37+a.p.x) < (b.p.y*37+b.p.x))
	return evaluated+ranked

func route_length(route: PackedVector2Array) -> float:
	var length = 0.0
	for i in range(1,route.size()):
		length += route[i-1].distance_to(route[i])
	return snappedf(length,.001)
