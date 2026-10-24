class_name GemBoard
extends RefCounted

var slabs: Dictionary = {}

const SIZE = 37
var cells: Dictionary = {}
var checkpoints: Array[Vector2i] = []
var ground_route: PackedVector2Array
var air_route: PackedVector2Array

func _init() -> void:
	for p in GemCatalog.DATA.map.checkpoints:
		checkpoints.append(Vector2i(p[0], p[1]))
	for p in GemCatalog.DATA.map.stones:
		cells[Vector2i(p[0], p[1])] = {"kind": "stone", "tier": 1, "fresh": false, "priority": "First"}
	for p in checkpoints:
		air_route.append(Vector2(p)+Vector2(0.5, 0.5))
	rebuild()

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < SIZE and p.y < SIZE

func path_for(obstacles: Dictionary) -> PackedVector2Array:
	var grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, SIZE, SIZE)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for p in obstacles:
		grid.set_point_solid(p)
	var result = PackedVector2Array()
	for i in range(checkpoints.size()-1):
		if obstacles.has(checkpoints[i]) or obstacles.has(checkpoints[i+1]):
			return PackedVector2Array()
		var leg = grid.get_id_path(checkpoints[i], checkpoints[i+1])
		if leg.is_empty():
			return PackedVector2Array()
		for j in range(leg.size()):
			if i == 0 or j > 0:
				result.append(Vector2(leg[j])+Vector2(0.5, 0.5))
	return result

func placement_error(p: Vector2i) -> String:
	return placement_preview(p).error

func placement_preview(p: Vector2i) -> Dictionary:
	if slabs.has(p):
		return {"error":"A path trap occupies that cell.","route":PackedVector2Array()}
	if not inside(p):
		return {"error":"Choose a cell inside the board.","route":PackedVector2Array()}
	if cells.has(p):
		return {"error":"That cell is occupied.","route":PackedVector2Array()}
	if checkpoints.has(p):
		return {"error":"Checkpoints must stay clear.","route":PackedVector2Array()}
	var candidate = cells.duplicate()
	candidate[p] = {}
	var route = path_for(candidate)
	return {"error":"That placement would block a checkpoint route." if route.is_empty() else "","route":route}

func rebuild() -> void:
	ground_route = path_for(cells)

func serialize() -> Array:
	var result: Array = []
	for p in cells:
		result.append({"x": p.x, "y": p.y, "gem": cells[p].duplicate(true)})
	return result

func deserialize(data: Array) -> bool:
	var candidate: Dictionary = {}
	for row in data:
		if not row is Dictionary or not row.has_all(["x", "y", "gem"]):
			return false
		var p = Vector2i(int(row.x), int(row.y))
		if not inside(p) or candidate.has(p) or not row.gem is Dictionary:
			return false
		var gem: Dictionary = row.gem
		if not gem.has_all(["kind", "tier", "fresh", "priority"]) or not gem.kind is String or not gem.fresh is bool or not gem.priority is String:
			return false
		if not (gem.tier is int or gem.tier is float) or gem.priority not in GemCatalog.PRIORITIES:
			return false
		if not gem.get("kind", "") in GemCatalog.TYPES + ["stone"] + GemCatalog.DATA.specials.keys():
			return false
		if int(gem.get("tier", 0)) < 1 or int(gem.get("tier", 0)) > GemCatalog.quality_limit(gem.kind):
			return false
		if float(gem.tier) != float(int(gem.tier)) or (not GemCatalog.DATA.gems.has(gem.kind) and int(gem.tier) != 1):
			return false
		if gem.has("stolen_abilities"):
			if not GemCatalog.campaign() or not gem.stolen_abilities is Array or gem.stolen_abilities.size() > 3: return false
			for ability in gem.stolen_abilities:
				if not ability is String or not GemCatalog.DATA.ability_effects.has(ability): return false
		if gem.has("mvp"):
			if not GemCatalog.campaign() or not (gem.mvp is int or gem.mvp is float) or not is_finite(float(gem.mvp)) or float(gem.mvp) != float(int(gem.mvp)) or int(gem.mvp) not in range(11): return false
		if gem.has("rolled_damage"):
			if not GemCatalog.campaign() or not (gem.rolled_damage is int or gem.rolled_damage is float) or not is_finite(float(gem.rolled_damage)) or not GemCatalog.stats({"kind":gem.kind,"tier":1}).has("random_damage") or int(gem.rolled_damage) not in range(30,1025) or float(gem.rolled_damage) != float(int(gem.rolled_damage)): return false
		if gem.has("proc_failures") and not GemProcRandom.valid_counters(gem): return false
		candidate[p] = gem.duplicate(true)
	if path_for(candidate).is_empty():
		return false
	cells = candidate
	rebuild()
	return true
