class_name GemReviewReplay
extends RefCounted

# Reports are data, never code. Only known game actions are accepted.
static func replay(report: Dictionary) -> Dictionary:
	if report.get("report_schema",0) != 1 or report.get("game_version","") != GemRelease.version() or report.get("catalog_sha256","") != GemCatalog.content_sha256():
		return {"ok":false,"error":"Report version or balance data do not match."}
	if report.get("actions_truncated",true) or not report.get("actions") is Array or report.actions.size() > GemReviewJournal.MAX_ACTIONS:
		return {"ok":false,"error":"Report actions are missing or truncated."}
	var state = GemRun.new(1)
	if not report.get("starting_checkpoint") is Dictionary or not state.restore(report.starting_checkpoint):
		return {"ok":false,"error":"Invalid starting checkpoint."}
	var combat = GemCampaignCombat.new(state) if GemCatalog.campaign() else GemCombat.new(state)
	state.combat_started.connect(combat.start)
	var error = ""
	var ticks = 0
	var tick_limit = 900000 if GemCatalog.campaign() else 300000
	for entry in report.actions:
		if not entry is Dictionary or not entry.has_all(["action","wave","phase","tick"]):
			error = "Malformed action."
			break
		while state.phase == "combat" and (entry.phase == "build" or roundi(combat.elapsed*30) < int(entry.tick)) and ticks < tick_limit:
			combat.tick(1.0/30.0)
			ticks += 1
		if ticks >= tick_limit or state.phase != entry.phase or state.wave != int(entry.wave):
			error = "Action phase, wave or tick does not match."
			break
		var p = Vector2i(-1,-1)
		if entry.has("at"):
			if not entry.at is Array or entry.at.size() != 2 or not (entry.at[0] is int or entry.at[0] is float) or not (entry.at[1] is int or entry.at[1] is float):
				error = "Invalid action coordinates."
				break
			p = Vector2i(int(entry.at[0]),int(entry.at[1]))
		var accepted = false
		match str(entry.action):
			"place":
				accepted = state.place(p)
				if accepted:
					accepted = state.board.cells[p].kind == entry.get("kind","") and int(state.board.cells[p].tier) == int(entry.get("tier",0))
			"demolish": accepted = state.demolish(p)
			"move_slab":
				if entry.get("to") is Array and entry.to.size() == 2:
					accepted = state.move_slab(p,Vector2i(int(entry.to[0]),int(entry.to[1])))
			"keep": accepted = state.keep(p)
			"upgrade": accepted = state.upgrade(p,int(entry.get("count",0)))
			"recipe": accepted = state.combine(str(entry.get("recipe","")),p,bool(entry.get("old_only",false)))
			"quality":
				var cost = state.quality_price()
				accepted = state.buy_quality()
				if accepted: accepted = cost == int(entry.get("cost",-1)) and state.quality == int(entry.get("level",-1))
			"priority": accepted = state.set_priority(p,str(entry.get("priority","")))
		if not accepted:
			error = "Rejected action or mismatched reveal: "+str(entry.action)
			break
	if error.is_empty():
		var target_tick = -1
		if report.get("outcome","") == "combat" and report.get("waves",[]) is Array and not report.waves.is_empty():
			target_tick = roundi(float(report.waves.back().seconds)*30)
		while state.phase == "combat" and (target_tick < 0 or roundi(combat.elapsed*30) < target_tick) and ticks < tick_limit:
			combat.tick(1.0/30.0)
			ticks += 1
		for key in ["wave","lives","gold","kills","leaks"]:
			if int(state.get(key)) != int(report.get(key,-1)):
				error = "Final value mismatch: "+key
		if state.phase != report.get("outcome","") or not same_board(state.board,report.get("board",[])):
			error = "Final phase or board does not match."
		if GemCatalog.campaign() and not same_slabs(state.board.slabs,report.get("slabs",[])):
			error = "Final traps do not match."
		if GemCatalog.campaign() and (int(report.get("enemy_count",0)) != state.enemy_count or not is_equal_approx(float(report.get("streak",999)),state.streak)): error = "Final campaign streak does not match."
		if GemCatalog.campaign():
			var discount = report.get("quality_discount",null)
			if not (discount is int or discount is float) or float(discount) != float(state.quality_discount) or not same_bosses(state.discounted_bosses,report.get("discounted_bosses",null)): error = "Final boss discount does not match."
		if GemCatalog.campaign():
			for row in report.get("waves",[]):
				if not row.has("diagnostics"): continue
				var actual: Dictionary = combat.audit_history.get(int(row.wave),combat.audit.snapshot() if int(row.wave) == state.wave else {})
				if JSON.parse_string(JSON.stringify(actual)) != row.diagnostics: error = "Combat diagnostics do not match."
	state.combat_started.disconnect(combat.start)
	return {"ok":error.is_empty(),"error":error,"ticks":ticks,"outcome":state.phase,"wave":state.wave,"lives":state.lives}

static func same_bosses(actual: Array[int], expected: Variant) -> bool:
	if not expected is Array or expected.size() != actual.size(): return false
	for i in range(actual.size()):
		if not (expected[i] is int or expected[i] is float) or float(expected[i]) != float(actual[i]): return false
	return true

static func same_slabs(actual: Dictionary, rows: Variant) -> bool:
	if not rows is Array: return false
	var expected: Dictionary = {}
	for row in rows:
		if not row is Dictionary or not row.has_all(["x","y","kind"]): return false
		expected[Vector2i(int(row.x),int(row.y))] = row.kind
	return expected == actual

static func same_board(actual: GemBoard, rows: Variant) -> bool:
	if not rows is Array:
		return false
	var expected = GemBoard.new()
	if not expected.deserialize(rows):
		return false
	var left = actual.cells.duplicate(true)
	var right = expected.cells.duplicate(true)
	# JSON decodes numeric fields as floats; compare semantic gem qualities.
	for gem in left.values():
		gem.tier = int(gem.tier)
		for key in ["mvp","rolled_damage"]:
			if gem.has(key): gem[key] = int(gem[key])
		for id in gem.get("proc_failures",{}): gem.proc_failures[id] = int(gem.proc_failures[id])
	for gem in right.values():
		gem.tier = int(gem.tier)
		for key in ["mvp","rolled_damage"]:
			if gem.has(key): gem[key] = int(gem[key])
		for id in gem.get("proc_failures",{}): gem.proc_failures[id] = int(gem.proc_failures[id])
	return left == right
