class_name GemTowerEffects
extends RefCounted

# Read-only inspection. Mirrors support's named-effect replacement/stacking;
# never calls combat refresh functions (which can expire live modifiers).
static func lines(gem: Dictionary, at: Vector2i, cells: Dictionary, combat: GemCombat = null) -> PackedStringArray:
	var result: PackedStringArray = []
	if gem.is_empty() or gem.get("kind","stone") == "stone": return result
	if not GemCatalog.campaign():
		var timing = GemCatalog.attack_timing(gem,at,cells)
		if float(timing.innate) > 0: result.append("Innate: +%.0f attack speed" % timing.innate)
		for tier in timing.auras: result.append("Opal %s: +%.0f attack speed" % [GemCatalog.quality_name(int(tier)),timing.auras[tier]])
		return result
	var live = combat as GemCampaignCombat
	var active = live != null and live.run.phase == "combat" and live.towers.has(at)
	var passive = GemCampaignRules.passive(gem)
	if not passive.is_empty(): result.append("Innate: "+GemCampaignRules.properties_text(passive))
	var level = int(gem.get("mvp",0))
	if level > 0: result.append("Own MVP %d/10: +%d%% damage" % [level,level*10])
	var named: Dictionary = {}
	for source in cells:
		if cells[source].kind == "stone": continue
		var title = "%s (%d, %d)" % [GemCatalog.title(cells[source]),source.x+1,source.y+1]
		if source != at and int(cells[source].get("mvp",0)) == 10 and Vector2(source).distance_to(Vector2(at)) <= float(GemCatalog.DATA.mvp.max_level_aura_radius):
			result.append("MVP aura: +100% damage — "+title)
		var actions: Array = live.towers[source].actions if active and live.towers.has(source) else GemCampaignRules.actions(cells[source])
		if active and not live.towers.has(source): continue
		for action in actions:
			if action.type != "support" or Vector2(source).distance_to(Vector2(at)) > float(action.radius): continue
			var key = str(action.id)+(str(source) if action.get("stacks",false) else "")
			named[key] = GemCampaignRules.properties_text(action.properties)+" — "+title
	for value in named.values(): result.append("Aura: "+str(value))
	var bonus = GemCampaignRules.mvp_bonus(gem,at,cells)
	if bonus > 0: result.append("Total MVP damage bonus: +%.0f%% (cap +500%%)" % bonus)
	if active:
		for buff in live.towers[at].buffs.values():
			var remaining = float(buff.until)-live.elapsed
			if remaining > 0: result.append("Temporary: %s · %.1fs left" % [GemCampaignRules.properties_text(buff.properties),remaining])
		var disabled = float(live.towers[at].disabled)-live.elapsed
		if disabled > 0: result.append("Cannot attack: %.1fs left" % disabled)
		var hostile = float(live.towers[at].get("hostile_disarm_until",0))-live.elapsed
		if hostile > 0: result.append("Enemy disarm: %.1fs left" % hostile)
	var timing = GemCatalog.attack_timing(gem,at,cells)
	if timing.get("capped",false): result.append("Attack speed cap reached; excess speed has no effect.")
	return result

static func text(gem: Dictionary, at: Vector2i, cells: Dictionary, combat: GemCombat = null) -> String:
	var values = lines(gem,at,cells,combat)
	return "AFFECTING THIS TOWER\n"+("\n".join(values) if not values.is_empty() else "No active bonuses or restrictions.")
