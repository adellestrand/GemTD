class_name GemCombatAudit
extends RefCounted

# Observes resolved combat only. Never draws RNG or changes game rules.
var enabled = true
var rows: Dictionary = {}
var boss: Dictionary = {}
var seconds = 0.0
var route_cells = 0.0

func reset(state: GemRun, route: PackedVector2Array) -> void:
	rows.clear()
	boss = {}
	seconds = 0.0
	route_cells = 0.0
	for i in range(1,route.size()): route_cells += route[i-1].distance_to(route[i])
	for p in state.board.cells:
		if state.board.cells[p].kind != "stone": add_source(p,GemCatalog.title(state.board.cells[p]))
	for p in state.board.slabs: add_source(p,GemCatalog.title({"kind":state.board.slabs[p],"tier":1}))

func add_source(p: Vector2i, title: String) -> void:
	rows[p] = {"at":[p.x,p.y],"name":title,"launched":0,"secondary_launched":0,"landed":0,"missed":0,"discarded":0,"blocked":0,"physical":0.0,"magical":0.0,"pure":0.0,"overkill":0.0,"boss_effect_seconds":0.0,"boss_range_seconds":0.0,"boss_targetable_seconds":0.0,"boss_disabled_seconds":0.0}

func launched(p: Vector2i, primary: bool) -> void:
	if enabled and rows.has(p): rows[p]["launched" if primary else "secondary_launched"] += 1

func impact(p: Vector2i, outcome: String) -> void:
	if enabled and rows.has(p): rows[p][outcome] += 1

func damage(p: Vector2i, kind: String, before: float, after: float) -> void:
	if not enabled or not rows.has(p): return
	rows[p][kind] += maxf(0,before-maxf(0,after))
	rows[p].overkill += maxf(0,-after)

func observe(combat: GemCampaignCombat, dt: float) -> void:
	if not enabled: return
	seconds += dt
	for enemy in combat.enemies:
		if enemy.boss: boss = enemy
	if boss.is_empty() or not GemCombat.alive(boss): return
	var affected: Dictionary = {}
	for aura in boss.get("aura_memory",{}).values():
		if aura.effect.has("damage") and float(aura.until) > combat.elapsed: affected[aura.source] = true
	for p in affected:
		if rows.has(p): rows[p].boss_effect_seconds += dt
	for p in combat.towers:
		var tower: Dictionary = combat.towers[p]
		if tower.stats.get("slab",false) or float(tower.stats.damage) <= 0: continue
		if (Vector2(p)+Vector2(.5,.5)).distance_to(boss.pos) > float(tower.range): continue
		rows[p].boss_range_seconds += dt
		if boss.air and tower.stats.targets != "both": continue
		if boss.invisible and not combat.detected(boss): continue
		rows[p].boss_targetable_seconds += dt
		if float(tower.disabled) > combat.elapsed or ((combat.disarm_in_range(p) or combat.elapsed < float(tower.get("hostile_disarm_until",0))) and not tower.support.get("magic_immune",false)):
			rows[p].boss_disabled_seconds += dt

func snapshot() -> Dictionary:
	if not enabled: return {}
	var sources: Array = []
	var totals = {"physical":0.0,"magical":0.0,"pure":0.0,"overkill":0.0,"launched":0,"secondary_launched":0,"landed":0,"missed":0,"discarded":0,"blocked":0}
	for row in rows.values():
		var copy: Dictionary = row.duplicate(true)
		copy.damage = float(row.physical)+float(row.magical)+float(row.pure)
		for key in totals: totals[key] += row[key]
		for key in copy:
			if copy[key] is float: copy[key] = snappedf(copy[key],.001)
		sources.append(copy)
	sources.sort_custom(func(a,b): return a.damage > b.damage if a.damage != b.damage else a.at[1]*37+a.at[0] < b.at[1]*37+b.at[0])
	for key in totals:
		if totals[key] is float: totals[key] = snappedf(totals[key],.001)
	var result = {"schema":1,"seconds":snappedf(seconds,.001),"route_cells":snappedf(route_cells,.001),"source_count":sources.size(),"top_sources":sources.slice(0,12),"totals":totals}
	if not boss.is_empty():
		result.boss = {"name":boss.name,"hp_max":boss.hp_max,"hp_remaining":maxf(0,float(boss.hp)),"remaining_percent":snappedf(100*maxf(0,float(boss.hp))/float(boss.hp_max),.01),"escaped":boss.escaped,"defeated":boss.dead}
	return result
