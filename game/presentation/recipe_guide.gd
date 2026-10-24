class_name GemRecipeGuide
extends RefCounted

# Inventory information only; the run model still selects/consumes materials.
static func progress(state: GemRun, recipe: String) -> Dictionary:
	if state == null or GemCatalog.recipe(recipe).is_empty():
		return {}
	var data = requirements_progress(state,GemCatalog.recipe(recipe).ingredients)
	data.recipe = recipe
	if state.phase != "build":
		data.message = "Combine during the build phase. You can still locate ingredients."
	elif not data.complete:
		data.message = "%d of %d ingredients found. Missing gems must match the exact quality." % [data.collected,data.total]
	elif data.old_only:
		data.message = "Ready with older gems. Your new tower choice remains available."
	elif state.placed < 5:
		data.message = "All ingredients found. Place all five gems before using new materials."
	else:
		data.message = "Ready with new materials. Combining is your final choice and starts the wave."
	return data

static func requirements_progress(state: GemRun, requirements: Array) -> Dictionary:
	var groups: Array[Dictionary] = []
	var by_key: Dictionary = {}
	for requirement in requirements:
		var key = "%s:%d" % [requirement[0],int(requirement[1])]
		if by_key.has(key):
			groups[int(by_key[key])].needed += 1
		else:
			by_key[key] = groups.size()
			groups.append({"key":key,"kind":str(requirement[0]),"tier":int(requirement[1]),"needed":1,"owned":[],"older":0,"new":0})
	var collected = 0
	var total = 0
	var old_only = not groups.is_empty()
	for group in groups:
		for p in state.board.cells:
			var gem: Dictionary = state.board.cells[p]
			if gem.kind == group.kind and int(gem.tier) == group.tier:
				group.owned.append(p)
				group["new" if gem.fresh else "older"] += 1
		group.owned.sort_custom(func(a,b):
			if state.board.cells[a].fresh != state.board.cells[b].fresh:
				return not state.board.cells[a].fresh
			return a.y*37+a.x < b.y*37+b.x
		)
		collected += mini(group.needed,group.owned.size())
		total += int(group.needed)
		old_only = old_only and int(group.older) >= int(group.needed)
	return {"groups":groups,"collected":collected,"total":total,"complete":total > 0 and collected == total,"old_only":old_only}
