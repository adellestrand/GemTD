class_name GemTowerInfo
extends RefCounted

# Derived, read-only values. Attack DPS is raw primary damage only; no claim
# about final damage against a particular enemy or time actually spent firing.
const QUALITIES = GemCatalog.QUALITIES
const DPS_NOTE = "Attack DPS assumes continuous attacks on one target before armor and evasion. Poison, splash, extra targets and support effects are separate. Aura DPS is per enemy before magic resistance. These are theoretical values, not measured wave damage. Intervals use simulation seconds, independent of 1× / 2×."

static func profile(gem: Dictionary, p: Vector2i, cells: Dictionary, combat: GemCombat = null) -> Dictionary:
	if gem.is_empty() or gem.get("kind","stone") == "stone":
		return {}
	var stats = GemCatalog.stats(gem)
	var timing = GemCatalog.attack_timing(gem,p,cells)
	var aura = gem.kind == "asteriated_ruby" and not GemCatalog.campaign()
	var damage = float(GemCatalog.DATA.effects.asteriated_ruby.damage) if aura else float(stats.damage)
	var radius = GemCatalog.effective_range(gem)
	var aura_components: Array[Dictionary] = []
	if GemCatalog.campaign():
		var support = GemCampaignRules.support(p,cells)
		var mvp = GemCampaignRules.mvp_bonus(gem,p,cells)
		var actions = GemCampaignRules.actions(gem)
		var live = combat as GemCampaignCombat
		if live != null and live.run.phase == "combat" and live.towers.has(p):
			var tower: Dictionary = live.towers[p]
			support = tower.support.duplicate()
			mvp = float(tower.mvp_bonus)
			actions = tower.actions
			timing = timing.duplicate(true)
			timing.interval = tower.interval
			for buff in tower.buffs.values():
				if float(buff.until) > live.elapsed: GemCampaignRules.merge_properties(support,buff.properties)
		radius = float(stats.range)+float(support.get("range_bonus",0))/128.0
		damage *= 1.0+float(support.get("outgoing_percent",0))/100.0
		if mvp > 0: damage = floorf(damage*(1.0+mvp/100.0))
		for action in actions:
			if action.type != "enemy_aura" or not action.has("damage"): continue
			var tick_damage = float(action.damage)
			if mvp > 0: tick_damage = floorf(tick_damage*(1.0+mvp/100.0))
			aura_components.append({"damage":tick_damage,"interval":float(action.interval),"range":float(action.radius),"dps":tick_damage/float(action.interval)})
		aura = float(stats.damage) <= 0 and not aura_components.is_empty()
		if aura:
			damage = aura_components[0].damage
			radius = aura_components[0].range
			timing = {"interval":aura_components[0].interval,"bonus":0.0,"innate":0.0,"auras":{}}
	elif aura:
		radius = float(GemCatalog.DATA.effects.asteriated_ruby.radius)
	return {"name":GemCatalog.title(gem),"damage":damage,"interval":timing.interval,
		"dps":damage/float(timing.interval),"range":radius,"aura_components":aura_components,
		"targets":"Ground + air" if stats.targets == "both" else "Ground only",
		"aura":aura,"timing":timing,"effect":effect_text(gem),"projectile_speed":float(stats.get("projectile_speed",0))}

static func effect_text(gem: Dictionary) -> String:
	if GemCatalog.campaign(): return GemCampaignRules.describe(gem)
	var stats = GemCatalog.stats(gem)
	var kind = str(stats.get("effect_kind",gem.get("kind","stone")))
	var tier = int(stats.get("effect_tier",gem.get("tier",1)))-1
	var effects: Dictionary = GemCatalog.DATA.effects
	match kind:
		"sapphire", "silver":
			var e: Dictionary = effects[kind]
			return "On hit: −%d movement speed for %.0fs." % [e.slow[0 if kind == "silver" else tier],GemCatalog.effect_value(e,"duration",tier+1)]
		"amethyst":
			return "On hit: −%d armor for %.0fs." % [effects.amethyst.armor_reduction[tier],GemCatalog.effect_value(effects.amethyst,"duration",tier+1)]
		"emerald":
			var e: Dictionary = effects.emerald
			return "On hit: %.0f magic damage / %.0fs for %.0fs. Each hit adds a poison instance." % [e.damage[tier],e.interval,GemCatalog.effect_value(e,"duration",tier+1)]
		"aquamarine":
			return "Rapid attacks: +%.0f innate attack speed (included above)." % GemCatalog.effect_value(effects.aquamarine,"attack_speed",tier+1)
		"opal":
			return "Support: +%.0f attack speed within %.2f cells, including itself. Same quality does not stack." % [effects.opal.attack_speed[tier],effects.opal.radius]
		"ruby":
			return "On hit: %.0f%% pure splash within %.2f cells, including the primary target." % [float(effects.ruby.fraction[tier])*100,effects.ruby.radius[tier]]
		"topaz", "malachite":
			return "Hits up to %d extra targets for full physical damage. Secondary hits bypass evasion." % effects[kind].secondary_count
		"asteriated_ruby":
			return "Burning aura hits every enemy in range. Attack speed bonuses and target priority do not affect its ticks."
	return str(GemCatalog.stats(gem).effect)

static func describe(info: Dictionary) -> String:
	if info.is_empty():
		return ""
	if info.aura:
		return "%.0f magic / %.2fs · %.1f aura DPS\nAura %.2f cells · %s\n\n%s\n%s" % [info.damage,info.interval,info.dps,info.range,info.targets,aura_text(info),info.effect]
	var text = "%s physical · %.2fs / attack\n%.1f attack DPS · Range %.2f cells\n%s" % [str(snappedf(info.damage,.01)),info.interval,info.dps,info.range,info.targets]
	var timing: Dictionary = info.timing
	if float(timing.bonus) > 0:
		var sources: PackedStringArray = []
		if float(timing.innate) > 0:
			sources.append("innate +%.0f" % timing.innate)
		var tiers: Array = timing.auras.keys()
		tiers.sort()
		for tier in tiers:
			sources.append("%s +%.0f" % ["Opal "+QUALITIES[int(tier)-1] if not tier is String else tier,timing.auras[tier]])
		text += "\nAttack speed: "+", ".join(sources)
	if timing.get("capped",false):
		text += "\nSpeed cap reached: %.0f / %.0f; excess +%.0f has no effect." % [timing.total,timing.maximum,maxf(0,float(timing.uncapped_total)-float(timing.maximum))]
	if float(info.get("projectile_speed",0)) > 0:
		text += "\nDamage and hit effects apply when the projectile arrives."
	return text+"\n\n"+aura_text(info)+str(info.effect)

static func aura_text(info: Dictionary) -> String:
	var text = ""
	for component in info.get("aura_components",[]):
		text += "Damage aura: %.0f magic / %.2fs · %.1f DPS per enemy · Radius %.2f cells.\n" % [component.damage,component.interval,component.dps,component.range]
	if info.aura: text += "Aura ticks ignore attack speed and attack-range bonuses.\n"
	return text

static func result_profile(plan: Dictionary, cells: Dictionary) -> Dictionary:
	if not plan.get("valid",false) or plan.get("result",{}).is_empty():
		return {}
	# Material positions and unkept fresh gems lose their support effects.
	# A shallow copy suffices: existing gem Dictionaries are never modified.
	var after = cells.duplicate()
	for p in plan.stones:
		after.erase(p)
	for p in plan.removed:
		after.erase(p)
	after[plan.result_at] = plan.result
	return profile(plan.result,plan.result_at,after)

static func action_tooltip(plan: Dictionary, cells: Dictionary) -> String:
	var result = result_profile(plan,cells)
	if result.is_empty():
		return str(plan.get("message",""))
	var before = profile(cells.get(plan.result_at,{}),plan.result_at,cells)
	var text = str(plan.get("message",result.name))
	text += "\n\nAFTER THIS CHOICE\n"+describe(result)
	if not before.is_empty() and not before.aura and not result.aura:
		text += "\n\nChange: %+.1f attack DPS · %+.2f cells" % [float(result.dps)-float(before.dps),float(result.range)-float(before.range)]
	return text+"\n\nRaw DPS before defenses; extra effects are separate."
