extends SceneTree

# Exploratory baseline, not a player model or a balance pass/fail test.
# Uses real placement RNG/economy, no fixtures, no prebuilt towers, no stat edits.
var completed: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("audit")

func audit() -> void:
	var count = 20
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			count = clampi(int(argument.trim_prefix("--runs=")),1,100)
	for seed_value in range(1,count+1):
		var result = play(seed_value)
		completed.append(result)
		print("AUDIT seed=%d phase=%s wave=%d lives=%d" % [seed_value,result.phase,result.wave,result.lives])
	var wins = completed.filter(func(r): return r.phase == "won").size()
	DirAccess.make_dir_recursive_absolute("res://output")
	var file = FileAccess.open("res://output/balance-audit.json",FileAccess.WRITE)
	if file == null:
		printerr("Could not write audit report")
		quit(1)
		return
	file.store_string(JSON.stringify({"content_version":GemCatalog.DATA.version,"policy":"route coverage, greedy tower upgrades/recipes, early odds purchases; no deliberate maze construction","runs":completed,"wins":wins,"total":count},"  "))
	file.close()
	print("AUDIT_COMPLETE wins=%d/%d; exploratory baseline only" % [wins,count])
	quit(1 if completed.any(func(r): return r.has("error")) else 0)

func play(seed_value: int) -> Dictionary:
	var state = GemRun.new(seed_value)
	var combat = GemCombat.new(state)
	state.combat_started.connect(combat.start)
	var rounds: Array[Dictionary] = []
	while state.phase == "build":
		while state.quality < GemCatalog.max_quality_upgrade() and state.gold >= state.quality_price():
			state.buy_quality()
		combine_old(state)
		var ranked = positions(state)
		for candidate in ranked:
			if state.place(candidate.p) and state.placed == 5:
				break
		if state.placed != 5:
			return {"seed":seed_value,"phase":state.phase,"wave":state.wave,"lives":state.lives,"error":"Could not find five placements"}
		var choice = choose(state)
		var result_at: Vector2i = choice.p
		var accepted = state.combine(choice.recipe,result_at) if choice.has("recipe") else state.upgrade(result_at,int(choice.count)) if int(choice.get("count",1)) > 1 else state.keep(result_at)
		if not accepted:
			return {"seed":seed_value,"phase":state.phase,"wave":state.wave,"lives":state.lives,"error":state.message}
		var round_result = {"wave":state.wave,"tower":GemCatalog.title(state.board.cells[result_at]),"lives_before":state.lives,"kills_before":state.kills,"quality_odds_level":state.quality}
		for tick in range(36000):
			combat.tick(1.0/30.0)
			if state.phase != "combat":
				break
		if state.phase == "combat":
			return {"seed":seed_value,"phase":state.phase,"wave":state.wave,"lives":state.lives,"error":"Wave exceeded 1200 seconds"}
		round_result.merge({"lives_after":state.lives,"kills":state.kills-int(round_result.kills_before),"seconds":snappedf(combat.elapsed,.1)})
		rounds.append(round_result)
	return {"seed":seed_value,"phase":state.phase,"wave":state.wave,"lives":state.lives,"gold":state.gold,"kills":state.kills,"leaks":state.leaks,"rounds":rounds}

func positions(state: GemRun) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	var route = state.board.air_route if GemCatalog.wave(state.wave).air else state.board.ground_route
	# Sample line segments too: air routes only contain checkpoint vertices.
	var samples = PackedVector2Array()
	for i in range(1,route.size()):
		var distance = route[i-1].distance_to(route[i])
		for step in range(maxi(1,ceili(distance))):
			samples.append(route[i-1].lerp(route[i],float(step)/maxf(1,ceilf(distance))))
	for y in range(1,36):
		for x in range(1,36):
			var p = Vector2i(x,y)
			if state.board.cells.has(p) or state.board.slabs.has(p) or state.board.checkpoints.has(p):
				continue
			var score = coverage(p,samples)
			# Spreading towers keeps the baseline from clustering on one checkpoint.
			for q in state.board.cells:
				if state.board.cells[q].kind != "stone" and p.distance_to(q) < 2.5:
					score *= .75
			ranked.append({"p":p,"score":score})
	ranked.sort_custom(func(a,b): return a.score > b.score if a.score != b.score else (a.p.y*37+a.p.x) < (b.p.y*37+b.p.x))
	return ranked

func coverage(p: Vector2i, route: PackedVector2Array) -> float:
	var score = 0.0
	for point in route:
		var distance = (Vector2(p)+Vector2(.5,.5)).distance_to(point)
		if distance <= 4:
			score += 1.0-distance/8.0
	return maxf(.1,score)

func value(gem: Dictionary, wave: Dictionary) -> float:
	var stats = GemCatalog.stats(gem)
	if GemCatalog.campaign():
		var timing = GemCatalog.attack_timing(gem,Vector2i.ZERO,{Vector2i.ZERO:gem})
		var estimate = float(stats.damage)/float(timing.interval)
		for effect in GemCampaignRules.actions(gem):
			match effect.type:
				"enemy_aura": estimate += float(effect.get("damage",0))/maxf(.1,float(effect.get("interval",1)))*(1 if wave.boss else 2)+10
				"on_hit": estimate += (0 if "enemy_momian" in wave.abilities else float(effect.get("damage",0))*3)+(20 if wave.boss and effect.properties.has("move_constant") else 5)
				"split": estimate *= 1.0 if wave.boss else 1.0+minf(3,float(effect.count))*.5
				"support": estimate += 20+(200 if effect.properties.get("true_sight",false) and "riki_permanent_invisibility" in wave.abilities else 0)
				"slab": estimate += 60
		return estimate*(.2 if wave.air and stats.targets != "both" else 1.0)
	var dps = float(stats.damage)/float(stats.interval)
	if wave.air and stats.targets != "both":
		dps *= .2
	match gem.kind:
		"emerald": dps += float(GemCatalog.DATA.effects.emerald.damage[int(gem.tier)-1])*3
		"aquamarine": dps *= 3
		"topaz", "malachite": dps *= 1 if wave.boss else 2.5
		"sapphire", "silver": dps *= 1.3
		"amethyst": dps *= 1.2
		"opal": dps *= 1.3
		"ruby": dps *= 1.0+float(GemCatalog.DATA.effects.ruby.fraction[int(gem.tier)-1])*(1 if wave.boss else 2)
		"asteriated_ruby": dps = 80
	return dps

func combine_old(state: GemRun) -> void:
	for recipe in GemCatalog.recipes():
		for p in state.board.cells.keys():
			var materials = state.recipe_materials(recipe,p,true)
			if materials.is_empty():
				continue
			var previous = 0.0
			for q in materials:
				previous += value(state.board.cells[q],GemCatalog.wave(state.wave))
			if value({"kind":GemCatalog.recipe_result(recipe),"tier":1},GemCatalog.wave(state.wave)) > previous:
				state.combine(recipe,p,true)
				break

func choose(state: GemRun) -> Dictionary:
	var best = {"p":state.fresh_cells()[0],"count":1,"score":-INF}
	var wave = GemCatalog.wave(state.wave)
	for p in state.fresh_cells():
		var gem: Dictionary = state.board.cells[p]
		for count in [1,2,4]:
			var tier = int(gem.tier)+(0 if count == 1 else 1 if count == 2 else 2)
			if tier > GemCatalog.quality_limit(gem.kind) or state.matching_new(p).size() < count:
				continue
			var score = value({"kind":gem.kind,"tier":tier},wave)*coverage(p,state.board.ground_route)
			if score > best.score:
				best = {"p":p,"count":count,"score":score}
	for recipe in GemCatalog.recipes():
		for p in state.board.cells:
			var materials = state.recipe_materials(recipe,p)
			if materials.is_empty() or not materials.any(func(q): return state.board.cells[q].fresh):
				continue
			var score = value({"kind":GemCatalog.recipe_result(recipe),"tier":1},wave)*coverage(p,state.board.ground_route)
			for q in materials:
				if not state.board.cells[q].fresh:
					score -= value(state.board.cells[q],wave)*coverage(q,state.board.ground_route)
			if score > best.score:
				best = {"p":p,"recipe":recipe,"score":score}
	return best
