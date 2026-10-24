class_name GemProcRandom
extends RefCounted

# A separate failure counter per unit and named source event. One combat RNG
# draw per attempt; failed attempts raise the next hazard, success resets it.
# Source nominal rates are preserved. Valve's internal PRNG is not replicated.
static func roll(rng: RandomNumberGenerator, owner: Dictionary, model_id: String) -> bool:
	var model: Dictionary = GemCatalog.DATA.random_models[model_id]
	var failures: Dictionary = owner.get("proc_failures",{})
	var attempt = int(failures.get(model_id,0))+1
	var chance = minf(1.0,float(model.coefficient)*attempt)
	var draw = rng.randf()
	var success = chance >= 1.0 or draw < chance
	failures[model_id] = 0 if success else attempt
	owner.proc_failures = failures
	return success

static func valid_counters(gem: Dictionary) -> bool:
	if not GemCatalog.campaign() or not gem.proc_failures is Dictionary: return false
	var abilities: Array = GemCatalog.stats(gem).get("abilities",[]).duplicate()
	abilities.append_array(gem.get("stolen_abilities",[]))
	for id in gem.proc_failures:
		if not id is String or id not in abilities or not GemCatalog.DATA.random_models.has(id): return false
		var value: Variant = gem.proc_failures[id]
		if not (value is int or value is float) or not is_finite(float(value)): return false
		var maximum = ceili(1.0/float(GemCatalog.DATA.random_models[id].coefficient))-1
		if float(value) < 0 or float(value) > maximum or float(value) != floorf(float(value)): return false
	return true
