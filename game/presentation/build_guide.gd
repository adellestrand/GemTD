class_name GemBuildGuide
extends RefCounted

# Read-only planning information. Never reveal RNG or apply a player action.
var run: GemRun
var cached_cell = Vector2i(-99,-99)
var cached_placement: Dictionary = {}

func bind(state: GemRun) -> void:
	run = state
	invalidate()

func invalidate() -> void:
	cached_placement.clear()
	cached_cell = Vector2i(-99,-99)

func placement(p: Vector2i) -> Dictionary:
	var result = {"status":"idle","message":"","route":PackedVector2Array()}
	if run == null or not run.board.inside(p):
		return result
	if run.board.cells.has(p):
		result.message = "Select "+GemCatalog.title(run.board.cells[p])
		return result
	if run.phase != "build":
		result.message = "Board locked during combat." if run.phase == "combat" else "Use Restart for a new run."
		return result
	if run.placed >= 5:
		result.message = "Five placed. Select a new gem for your final choice."
		return result
	if cached_placement.is_empty() or cached_cell != p:
		cached_placement = run.board.placement_preview(p)
		cached_cell = p
	result.status = "place" if str(cached_placement.error).is_empty() else "blocked"
	result.message = "Place gem %d / 5 · type revealed on click" % (run.placed+1) if result.status == "place" else str(cached_placement.error)
	result.route = cached_placement.route
	return result

func action(request: Dictionary, p: Vector2i) -> Dictionary:
	if run == null or run.phase != "build":
		return denied("Building actions are available during the build phase.")
	var kind = str(request.get("type",""))
	var gem: Dictionary = run.board.cells.get(p,{})
	if kind in ["keep","upgrade"]:
		if gem.is_empty() or not gem.get("fresh",false):
			return denied("Select a new gem from this round.")
		if run.placed != 5:
			return denied("Place all five gems before your final tower choice.")
		if kind == "keep":
			return plan([p],p,gem.duplicate(true),true)
		var count = int(request.get("count",2))
		if count not in [2,4]:
			return denied("Choose two or four identical new gems.")
		var tier = int(gem.tier)+(1 if count == 2 else 2)
		if tier > GemCatalog.quality_limit(gem.kind):
			return denied("This combination would exceed quality %s." % GemCatalog.quality_name(GemCatalog.quality_limit(gem.kind)))
		var matching = run.matching_new(p)
		if matching.size() < count:
			return denied("Need %d identical new gems; have %d." % [count,matching.size()])
		var upgraded = gem.duplicate(true)
		upgraded.tier = tier
		return plan(matching.slice(0,count),p,upgraded,true)
	if kind == "recipe":
		var recipe = str(request.get("recipe",""))
		if GemCatalog.stats({"kind":GemCatalog.recipe_result(recipe),"tier":1}).get("slab",false):
			var error = run.slab_error(p,true)
			if not error.is_empty(): return denied(error)
		var materials = run.recipe_materials(recipe,p,bool(request.get("old_only",false)))
		if materials.is_empty():
			return denied("Missing recipe materials. Select one of its material cells.")
		var starts = materials.any(func(q): return run.board.cells[q].fresh)
		if starts and run.placed != 5:
			return denied("Place all five gems before combining new materials.")
		var result = {"kind":GemCatalog.recipe_result(recipe),"tier":1,"fresh":false,"priority":"First"}
		if GemCatalog.campaign() and not GemCatalog.stats(result).get("slab",false):
			var mvp = 0
			for q in materials: mvp += int(run.board.cells[q].get("mvp",0))
			if mvp > 0: result.mvp = mini(10,mvp)
		return plan(materials,p,result,starts)
	if kind == "demolish":
		if run.board.slabs.has(p):
			return {"valid":true,"materials":[],"stones":[],"removed":[],"result_at":p,"result":{},"starts":false,"message":"Demolish this path trap. The ground route stays open."}
		if gem.is_empty():
			return denied("Select an older tower or stone to demolish.")
		if gem.fresh:
			return denied("New placements are binding until your final choice.")
		return {"valid":true,"materials":[p],"stones":[],"removed":[p],"result_at":p,"result":{},"starts":false,"message":"Demolish "+GemCatalog.title(gem)+". No refund; the cell becomes empty."}
	return denied("")

func denied(message: String) -> Dictionary:
	return {"valid":false,"materials":[],"stones":[],"removed":[],"result":{},"message":message}

func plan(materials: Array, p: Vector2i, result: Dictionary, starts: bool) -> Dictionary:
	var stones: Array[Vector2i] = []
	for q in materials:
		if q != p:
			stones.append(q)
	if starts:
		for q in run.fresh_cells():
			if q != p and not stones.has(q):
				stones.append(q)
	var message = "Result: "+GemCatalog.title(result)+" at the selected cell. "
	message += "Other new gems become stones; wave starts immediately." if starts else "Only older materials used; your new tower choice remains."
	return {"valid":true,"materials":materials,"stones":stones,"removed":[],"result_at":p,"result":result,"starts":starts,"message":message}
