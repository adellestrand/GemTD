class_name GemCampaignRules
extends RefCounted

static func steal_pool(at: Vector2i, cells: Dictionary) -> Array:
	var result: Array = []
	var allowed: Array = GemCatalog.DATA.mechanics.stealable_abilities
	for p in cells:
		var gem: Dictionary = cells[p]
		if p == at or gem.kind in ["stone","tianranzumulv"] or Vector2(p).distance_to(Vector2(at)) > 220.0/128.0: continue
		var stats: Dictionary = GemCatalog.stats(gem)
		if not stats.get("ranged",false): continue
		var ids: Array = stats.get("abilities",[]).duplicate()
		ids.append_array(gem.get("stolen_abilities",[]))
		for id in allowed:
			if id in ids: result.append(id)
	return result

# Pure content queries shared by the campaign simulation and inspection UI.
static func actions(gem: Dictionary) -> Array:
	var result: Array = []
	var ids: Array = GemCatalog.stats(gem).get("abilities",[]).duplicate()
	ids.append_array(gem.get("stolen_abilities",[]))
	for id in ids:
		result.append_array(GemCatalog.DATA.ability_effects.get(id,[]))
	return result

static func support(p: Vector2i, cells: Dictionary) -> Dictionary:
	var named: Dictionary = {}
	for q in cells:
		if cells[q].kind == "stone":
			continue
		for action in actions(cells[q]):
			if action.type == "support" and Vector2(p).distance_to(Vector2(q)) <= float(action.radius):
				var key = str(action.id)+(str(q) if action.get("stacks",false) else "")
				named[key] = action.properties
	var result: Dictionary = {}
	for properties in named.values():
		merge_properties(result,properties)
	return result

static func merge_properties(into: Dictionary, properties: Dictionary) -> void:
	for key in properties:
		if properties[key] is bool:
			into[key] = into.get(key,false) or properties[key]
		else:
			into[key] = float(into.get(key,0))+float(properties[key])
			# Dota stacks magic resistance sources multiplicatively: 1 - prod(1 - r).
			if key == "magic_resist": into.magic_factor = float(into.get("magic_factor",1.0))*(1.0-float(properties[key])/100.0)

static func passive(gem: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for action in actions(gem):
		if action.type == "passive":
			merge_properties(result,action.properties)
	return result

static func timing(gem: Dictionary, p: Vector2i, cells: Dictionary) -> Dictionary:
	var innate = float(passive(gem).get("attack_speed",0))
	var nearby = support(p,cells)
	var bonus = innate+float(nearby.get("attack_speed",0))
	var result = timing_from_bonus(float(GemCatalog.stats(gem).interval),bonus)
	result.merge({"innate":innate,"auras":{"Support":float(nearby.get("attack_speed",0))},"bonus":bonus})
	return result

static func timing_from_bonus(base_interval: float, bonus: float) -> Dictionary:
	var rules: Dictionary = GemCatalog.DATA.combat
	var base = float(rules.base_attack_speed)
	var uncapped = base+bonus
	var total = clampf(uncapped,float(rules.minimum_attack_speed),float(rules.maximum_attack_speed))
	return {"interval":base_interval*base/total,"total":total,"uncapped_total":uncapped,
		"maximum":float(rules.maximum_attack_speed),"capped":uncapped >= float(rules.maximum_attack_speed)}

static func movement_speed(base: float, properties: Dictionary, wind: float = 0.0) -> float:
	return maxf(float(GemCatalog.DATA.combat.minimum_movement_speed)/128.0,(base+float(properties.get("move_constant",0))/128.0)*(1.0+(float(properties.get("move_percent",0))+wind)/100.0))

static func range_for(gem: Dictionary, p: Vector2i, cells: Dictionary) -> float:
	return float(GemCatalog.stats(gem).range)+float(support(p,cells).get("range_bonus",0))/128.0

static func mvp_bonus(gem: Dictionary, p: Vector2i, cells: Dictionary) -> float:
	var bonus = int(gem.get("mvp",0))*10.0
	for q in cells:
		if q != p and int(cells[q].get("mvp",0)) == 10 and Vector2(p).distance_to(Vector2(q)) <= 290.0/128.0: bonus += 100.0
	return minf(500,bonus)

static func describe(gem: Dictionary) -> String:
	var lines: PackedStringArray = []
	for effect in actions(gem):
		if effect.type == "cosmetic":
			continue
		match effect.type:
			"split": lines.append("Hits up to %d extra physical targets." % effect.count)
			"crit": lines.append("%.0f%% average critical rate with smoothed streaks; %.0f× attack damage." % [effect.chance*100,effect.multiplier])
			"splash": lines.append("%.0f%% pure splash within %.2f cells." % [effect.fraction*100,effect.radius])
			"stun": lines.append("%.0f%% chance to stun for %.1fs." % [effect.chance*100,effect.duration])
			"chain","shock": lines.append("%.0f%% chance: %.0f magic damage to up to %d targets within %.2f cells." % [effect.chance*100,effect.damage,effect.count,effect.radius])
			"petrify": lines.append("%.0f%% chance to petrify the %d closest enemies (+1 per 2 MVP levels) for %.1fs; %.0fs cooldown." % [effect.chance*100,effect.count,effect.duration,effect.cooldown])
			"self_disarm": lines.append("%.0f%% average self-disarm rate with smoothed streaks; %.1fs duration." % [effect.chance*100,effect.duration])
			"burst": lines.append("%.0f%% chance of %.0f× magic burst within %.2f cells." % [effect.chance*100,effect.multiplier,effect.radius])
			"on_hit":
				lines.append("On hit: %s for %.1fs%s." % [properties_text(effect.properties),float(effect.duration),"; %.0f %s every %.2fs" % [effect.damage,effect.damage_type,effect.interval] if effect.has("damage") else ""])
			"support","enemy_aura":
				lines.append("%s: %s within %.2f cells%s%s." % ["Nearby towers" if effect.type == "support" else "Nearby enemies",properties_text(effect.properties),effect.radius,"; %.0f %s / %.2fs" % [effect.damage,effect.damage_type,effect.interval] if effect.has("damage") else "","; excludes Ancient enemies" if effect.get("not_ancient",false) else ""])
			"passive": lines.append(properties_text(effect.properties))
			"slab":
				var modes = {"stun":"Entangle","line_slow":"Venomous trail","torrent":"Torrent","support":"Howl","field":"Acid cloud","cask":"Bouncing stun","modifier":"Dread" if effect.get("properties",{}).has("incoming_percent") else "Ethereal slow"}
				lines.append("Path trap: %s, 1-cell trigger, %.0fs cooldown." % [modes.get(effect.mode,"Special effect"),effect.cooldown])
				if effect.has("duration"): lines.append("Duration %.1fs; %s." % [effect.duration,properties_text(effect.get("properties",{}))])
				if effect.has("count"): lines.append("Up to %d initial targets." % effect.count)
			"slab_echo": lines.append("Nearby trap activations may release frost: %.0f magic damage per bounce, up to %d bounces." % [effect.damage,effect.bounces])
	if GemCatalog.stats(gem).get("steal_abilities",0) > 0:
		lines.append("Copies up to three distinct nearby tower abilities when created.")
	if GemCatalog.stats(gem).has("random_damage") and not gem.has("rolled_damage"):
		lines.append("Attack damage is rolled when created: mean 512, deviation 128, minimum 30. The displayed attack uses the mean.")
	if int(gem.get("mvp",0)) > 0:
		lines.append("MVP level %d: +%d%% damage. Level 10 also grants +100%% to other towers within %.2f cells." % [int(gem.mvp),int(gem.mvp)*10,290.0/128.0])
	return "\n".join(lines)

static func properties_text(properties: Dictionary) -> String:
	var parts: PackedStringArray = []
	var labels = {"armor":"Armor","magic_resist":"Magic resistance","move_constant":"Movement speed","move_percent":"Movement speed","attack_speed":"Attack speed","damage_bonus":"Attack damage","range_bonus":"Attack range","outgoing_percent":"Attack damage","incoming_percent":"Damage received"}
	var states = {"no_healing":"Prevents healing","true_sight":"Reveals invisible enemies","magic_immune":"Protects towers from hostile spells","cannot_miss":"Attacks cannot miss","rejuvenation":"3% kill chance to gain lives","greed":"5% kill chance for 10× gold","stunned":"Stunned","stone_gaze":"Petrified; takes double physical damage"}
	for key in properties:
		if properties[key] is bool:
			parts.append(states.get(key,str(key).replace("_"," ")))
		elif key == "range_bonus": parts.append("Attack range %+.2f cells" % (float(properties[key])/128.0))
		else: parts.append(str(labels.get(key,key))+" %+.0f" % float(properties[key])+("%" if key in ["magic_resist","move_percent","outgoing_percent","incoming_percent"] else ""))
	return ", ".join(parts) if not parts.is_empty() else "special effect"
