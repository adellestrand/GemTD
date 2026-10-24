class_name GemRun
extends RefCounted

signal changed
signal build_started
signal combat_started
signal sound_requested(cue: String)
signal action_recorded(entry: Dictionary)

const SAVE_VERSION = 1
var board: GemBoard
var rng = RandomNumberGenerator.new()
var combat_rng = RandomNumberGenerator.new()
var initial_seed: int = 1
var wave = 1
var lives = 30
var gold = 0
var quality = 0
var quality_discount = 0
var discounted_bosses: Array[int] = []
var placed = 0
var phase = "build"
var message = "Place five gems. Their type is revealed after placement."
var kills = 0
var leaks = 0
var streak = 0.0
var enemy_count = 10

func _init(seed_value: int = 1) -> void:
	lives = GemCatalog.starting_lives()
	initial_seed = seed_value
	rng.seed = seed_value
	combat_rng.seed = seed_value ^ 0x47454d
	board = GemBoard.new()

func fail(reason: String) -> bool:
	message = reason
	changed.emit()
	return false

func place(p: Vector2i) -> bool:
	if phase != "build" or placed >= 5:
		return fail("Select a new gem and make your final tower choice.")
	var error = board.placement_error(p)
	if not error.is_empty():
		return fail(error)
	var roll = rng.randi_range(1, 100)
	var odds: Array = GemCatalog.DATA.quality_odds[quality]
	var tier = GemCatalog.roll_tier(odds,roll)
	var kind: String = GemCatalog.TYPES[rng.randi_range(0, 7)]
	board.cells[p] = {"kind": kind, "tier": tier, "fresh": true, "priority": "First"}
	placed += 1
	record_action({"action":"place","at":[p.x,p.y],"kind":kind,"tier":tier})
	board.rebuild()
	message = "Revealed " + GemCatalog.title(board.cells[p]) + ". " + ("Choose what to keep — this starts combat." if placed == 5 else "Place %d more." % (5-placed))
	sound_requested.emit("place")
	changed.emit()
	return true

func demolish(p: Vector2i) -> bool:
	if phase == "build" and board.slabs.has(p):
		record_action({"action":"demolish","at":[p.x,p.y]})
		board.slabs.erase(p)
		message = "Path trap demolished."
		changed.emit()
		return true
	if phase != "build" or not board.cells.has(p):
		return fail("Demolition is available during the build phase.")
	if board.cells[p].fresh:
		return fail("New placements are binding until your final choice.")
	record_action({"action":"demolish","at":[p.x,p.y]})
	board.cells.erase(p)
	board.rebuild()
	message = "Demolished. No refund."
	sound_requested.emit("demolish")
	changed.emit()
	return true

func fresh_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p in board.cells:
		if board.cells[p].fresh:
			result.append(p)
	return result

func keep(p: Vector2i) -> bool:
	if phase != "build" or placed != 5 or not board.cells.has(p) or not board.cells[p].fresh:
		return fail("Place all five gems, then select a new gem to keep.")
	record_action({"action":"keep","at":[p.x,p.y]})
	finalize(p)
	return true

func matching_new(p: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not board.cells.has(p) or not board.cells[p].fresh:
		return result
	var gem: Dictionary = board.cells[p]
	for q in fresh_cells():
		if board.cells[q].kind == gem.kind and board.cells[q].tier == gem.tier:
			result.append(q)
	# The chosen position is always part of the materials and receives the result.
	result.erase(p)
	result.push_front(p)
	return result

func upgrade(p: Vector2i, count: int) -> bool:
	if phase != "build" or placed != 5 or count not in [2, 4] or not board.cells.has(p):
		return fail("Upgrades require two or four identical new gems after all five placements.")
	var matching = matching_new(p)
	var gain = 1 if count == 2 else 2
	if matching.size() < count or int(board.cells[p].tier)+gain > GemCatalog.quality_limit(board.cells[p].kind):
		return fail("Not enough identical new gems, or result exceeds quality %s." % GemCatalog.quality_name(GemCatalog.quality_limit(board.cells[p].kind)))
	record_action({"action":"upgrade","at":[p.x,p.y],"count":count})
	for q in matching.slice(0, count):
		if q != p:
			board.cells[q] = stone()
	board.cells[p].tier += gain
	sound_requested.emit("combine")
	finalize(p)
	return true

func recipe_materials(recipe: String, result_at: Vector2i, old_only: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if GemCatalog.recipe(recipe).is_empty() or not board.cells.has(result_at):
		return result
	var candidates: Array = board.cells.keys()
	candidates.erase(result_at)
	candidates.push_front(result_at)
	# Prefer old material when the chosen result position is old; new when it is new.
	var prefer_new: bool = board.cells[result_at].fresh
	var ordered: Array = [result_at]
	for preference in [prefer_new, not prefer_new]:
		for p in candidates:
			if p != result_at and board.cells[p].fresh == preference:
				ordered.append(p)
	for requirement in GemCatalog.recipe(recipe).ingredients:
		var found = false
		for p in ordered:
			var gem: Dictionary = board.cells[p]
			if not result.has(p) and (not old_only or not gem.fresh) and gem.kind == requirement[0] and int(gem.tier) == int(requirement[1]):
				result.append(p)
				found = true
				break
		if not found:
			return []
	if not result.has(result_at):
		return []
	return result

func combine(recipe: String, result_at: Vector2i, old_only: bool = false) -> bool:
	if phase != "build":
		return fail("Combinations are available during the build phase.")
	if GemCatalog.stats({"kind":GemCatalog.recipe_result(recipe),"tier":1}).get("slab",false):
		var error = slab_error(result_at,true)
		if not error.is_empty(): return fail(error)
	var materials = recipe_materials(recipe, result_at, old_only)
	if materials.is_empty():
		return fail("Missing recipe materials. Select a material cell for the result.")
	var uses_new = false
	for p in materials:
		uses_new = uses_new or board.cells[p].fresh
	if uses_new and placed != 5:
		return fail("Place all five gems before combining new materials.")
	record_action({"action":"recipe","at":[result_at.x,result_at.y],"recipe":recipe,"old_only":old_only})
	var mvp = 0
	for p in materials: mvp += int(board.cells[p].get("mvp",0))
	for p in materials:
		board.cells[p] = stone()
	var result = GemCatalog.recipe_result(recipe)
	if GemCatalog.stats({"kind":result,"tier":1}).get("slab",false):
		board.cells.erase(result_at)
		board.slabs[result_at] = result
		upgrade_slabs()
		board.rebuild()
	else:
		board.cells[result_at] = {"kind":result,"tier":1,"fresh":false,"priority":"First"}
		if mvp > 0: board.cells[result_at].mvp = mini(10,mvp)
		if GemCatalog.stats(board.cells[result_at]).has("random_damage"):
			var z = 9999.0
			while absf(z) > 4.0:
				var u = rng.randi_range(1,10000)/10000.0
				var v = rng.randi_range(1,10000)/10000.0
				z = sqrt(-2.0*log(u))*cos(TAU*v)
			board.cells[result_at].rolled_damage = maxi(30,ceili(z*128.0+512.0))
		if GemCatalog.stats(board.cells[result_at]).get("steal_abilities",0) > 0:
			var pool: Array = []
			for p in board.cells:
				if p != result_at and Vector2(p).distance_to(Vector2(result_at)) <= 220.0/128.0 and board.cells[p].kind != result:
					for id in GemCatalog.stats(board.cells[p]).get("abilities",[]):
						if not str(id).begins_with("e") and id not in pool: pool.append(id)
			var stolen: Array = []
			while not pool.is_empty() and stolen.size() < 3:
				var index = rng.randi_range(0,pool.size()-1)
				stolen.append(pool.pop_at(index))
			board.cells[result_at].stolen_abilities = stolen
	sound_requested.emit("combine")
	if uses_new:
		finalize(result_at)
	else:
		message = "Combined older towers. Your new tower choice is still available."
		changed.emit()
	return true

static func stone() -> Dictionary:
	return {"kind": "stone", "tier": 1, "fresh": false, "priority": "First"}

func finalize(result_at: Vector2i) -> void:
	for p in fresh_cells():
		if p != result_at:
			board.cells[p] = stone()
	if board.cells.has(result_at): board.cells[result_at].fresh = false
	phase = "combat"
	message = "Wave %d: %s" % [wave, GemCatalog.wave(wave).name]
	combat_started.emit()
	sound_requested.emit("wave")
	changed.emit()

func quality_price() -> int:
	if quality >= GemCatalog.max_quality_upgrade(): return 0
	return maxi(0,int(GemCatalog.DATA.quality_costs[quality])-(quality_discount if GemCatalog.campaign() else 0))

func award_boss_discount() -> bool:
	var award = GemCatalog.boss_discount_for_wave(wave)
	if phase != "combat" or award == 0 or wave in discounted_bosses: return false
	quality_discount += award
	discounted_bosses.append(wave)
	changed.emit()
	return true

static func valid_discount(data: Dictionary) -> bool:
	var credit: Variant = data.get("quality_discount",null)
	var bosses: Variant = data.get("discounted_bosses",null)
	if not (credit is int or credit is float) or not is_finite(float(credit)) or float(credit) != floorf(float(credit)) or float(credit) < 0: return false
	if not bosses is Array or bosses.size() > int(GemCatalog.DATA.economy.boss_discount_last_wave)/10: return false
	var previous = 0
	for index in bosses:
		if not (index is int or index is float) or not is_finite(float(index)) or float(index) != floorf(float(index)): return false
		if int(index) <= previous or int(index) >= int(data.wave) or GemCatalog.boss_discount_for_wave(int(index)) == 0: return false
		previous = int(index)
	return float(credit) <= bosses.size()*int(GemCatalog.DATA.economy.boss_odds_discount)

func buy_quality() -> bool:
	if phase in ["won", "lost"] or quality >= GemCatalog.max_quality_upgrade():
		return fail("Quality odds are at the current content maximum.")
	var cost = quality_price()
	if gold < cost:
		return fail("You need %d gold." % cost)
	gold -= cost
	if GemCatalog.campaign(): quality_discount = maxi(0,quality_discount-int(GemCatalog.DATA.quality_costs[quality]))
	quality += 1
	record_action({"action":"quality","cost":cost,"level":quality})
	message = "Gem odds improved. Only future placements are affected."
	sound_requested.emit("combine")
	changed.emit()
	return true

func killed(reward: int) -> void:
	gold += reward
	kills += 1

func record_action(entry: Dictionary) -> void:
	entry.wave = wave
	entry.phase = phase
	action_recorded.emit(entry.duplicate(true))

func set_priority(p: Vector2i, mode: String) -> bool:
	if phase not in ["build","combat"] or mode not in GemCatalog.PRIORITIES or not board.cells.has(p) or board.cells[p].kind in ["stone","asteriated_ruby"]:
		return false
	if board.cells[p].priority != mode:
		board.cells[p].priority = mode
		record_action({"action":"priority","at":[p.x,p.y],"priority":mode})
		changed.emit()
	return true

func leaked(cost: int, boss: bool) -> void:
	leaks += 1
	lives = maxi(0, lives-cost)
	sound_requested.emit("leak")
	if boss or lives == 0:
		phase = "lost"
		message = "The boss reached the goal." if boss else "No lives remaining."
	changed.emit()

func finish_wave() -> void:
	if phase != "combat":
		return
	gold += int(GemCatalog.wave(wave).completion)
	if wave == GemCatalog.wave_count():
		phase = "won"
		message = "Victory! The final boss has been defeated."
		sound_requested.emit("win")
	else:
		wave += 1
		placed = 0
		phase = "build"
		message = "Wave cleared. Place five new gems."
		build_started.emit()
	changed.emit()

func snapshot() -> Dictionary:
	var result = {"version": SAVE_VERSION, "content_version": GemCatalog.DATA.version, "seed": str(initial_seed), "rng": str(rng.state), "combat_rng": str(combat_rng.state), "wave": wave, "lives": lives, "gold": gold, "quality": quality, "kills": kills, "leaks": leaks, "cells": board.serialize()}
	if GemCatalog.campaign():
		result.merge({"slabs":serialize_slabs(),"streak":streak,"enemy_count":enemy_count,"quality_discount":quality_discount,"discounted_bosses":discounted_bosses.duplicate()})
	return result

func serialize_slabs() -> Array:
	var result: Array = []
	for p in board.slabs: result.append({"x":p.x,"y":p.y,"kind":board.slabs[p]})
	return result

func adjust_streak(amount: float) -> void:
	streak += amount
	while streak >= 50:
		streak -= 50
		enemy_count += 1
	while streak <= -50:
		streak += 50
		enemy_count = maxi(5,enemy_count-1)

func upgrade_slabs() -> void:
	var again = true
	while again:
		again = false
		var positions = board.slabs.keys()
		positions.sort_custom(func(a,b): return a.y*37+a.x < b.y*37+b.x)
		for p in positions:
			var kind: String = board.slabs[p]
			if not GemCatalog.DATA.get("slab_upgrades",{}).has(kind): continue
			for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,-1)]:
				if board.slabs.get(p+delta,"") == kind and board.slabs.get(p-delta,"") == kind:
					board.slabs.erase(p+delta)
					board.slabs.erase(p-delta)
					board.slabs[p] = GemCatalog.DATA.slab_upgrades[kind]
					again = true
					break
			if again: break

func move_slab(from: Vector2i, to: Vector2i) -> bool:
	if phase != "build" or not board.slabs.has(from): return fail("Move path traps during building.")
	var error = slab_error(to)
	if not error.is_empty(): return fail(error)
	record_action({"action":"move_slab","at":[from.x,from.y],"to":[to.x,to.y]})
	board.slabs[to] = board.slabs[from]
	board.slabs.erase(from)
	upgrade_slabs()
	message = "Path trap moved. Three equal traps in a line upgrade automatically."
	changed.emit()
	return true

func slab_error(p: Vector2i, allow_material: bool = false) -> String:
	if not board.inside(p) or board.slabs.has(p) or board.checkpoints.has(p) or (not allow_material and board.cells.has(p)): return "A path trap needs a free, non-checkpoint cell."
	if (p.x <= 8 and p.y <= 8) or (p.x >= 28 and p.y >= 28): return "Path traps cannot be placed in the protected start or exit corners."
	return ""

func restore(data: Dictionary) -> bool:
	if not data.has_all(["version", "content_version", "seed", "rng", "combat_rng", "wave", "lives", "gold", "quality", "cells"]):
		return false
	if int(data.version) != SAVE_VERSION or int(data.content_version) != int(GemCatalog.DATA.version):
		return false
	if int(data.wave) not in range(1, GemCatalog.wave_count()+1) or int(data.lives) < 1 or int(data.lives) > (1000000 if GemCatalog.campaign() else GemCatalog.starting_lives()) or int(data.quality) not in range(GemCatalog.max_quality_upgrade()+1) or int(data.gold) < 0:
		return false
	var candidate = GemBoard.new()
	if not data.cells is Array or not candidate.deserialize(data.cells):
		return false
	if GemCatalog.campaign():
		if not valid_discount(data): return false
		if not (data.get("streak",0) is int or data.get("streak",0) is float) or not is_finite(float(data.get("streak",0))) or absf(float(data.get("streak",0))) >= 50: return false
		if int(data.get("enemy_count",10)) < 5 or int(data.get("enemy_count",10)) > 1000: return false
		if not data.get("slabs",[]) is Array: return false
		for row in data.get("slabs",[]):
			if not row is Dictionary or not row.has_all(["x","y","kind"]) or not row.kind is String: return false
			var p = Vector2i(int(row.x),int(row.y))
			if (p.x <= 8 and p.y <= 8) or (p.x >= 28 and p.y >= 28): return false
			if not candidate.inside(p) or candidate.cells.has(p) or candidate.slabs.has(p) or candidate.checkpoints.has(p) or not GemCatalog.DATA.specials.has(row.kind) or not GemCatalog.DATA.specials[row.kind].get("slab",false): return false
			candidate.slabs[p] = row.kind
	for p in candidate.cells:
		if candidate.cells[p].get("fresh", true):
			return false
	board = candidate
	initial_seed = int(data.seed)
	rng.state = int(data.rng)
	combat_rng.state = int(data.combat_rng)
	wave = int(data.wave)
	lives = int(data.lives)
	gold = int(data.gold)
	quality = int(data.quality)
	quality_discount = int(data.get("quality_discount",0)) if GemCatalog.campaign() else 0
	discounted_bosses.clear()
	if GemCatalog.campaign():
		for index in data.discounted_bosses: discounted_bosses.append(int(index))
	kills = int(data.get("kills", 0))
	leaks = int(data.get("leaks", 0))
	streak = float(data.get("streak",0))
	enemy_count = int(data.get("enemy_count",10))
	phase = "build"
	placed = 0
	message = "Resumed at the beginning of build phase %d." % wave
	changed.emit()
	return true
