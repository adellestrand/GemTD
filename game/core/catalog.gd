class_name GemCatalog
extends RefCounted

const BASE: Dictionary = preload("res://data/catalog.json").data
const EXPANDED: Dictionary = preload("res://data/expanded_gems.json").data
const CAMPAIGN: Dictionary = preload("res://data/campaign.json").data
static var profile_override = ""
static var DATA: Dictionary = load_profile()
const TYPES = ["sapphire", "diamond", "aquamarine", "opal", "emerald", "topaz", "ruby", "amethyst"]
const PRIORITIES = ["First", "Last", "Strongest", "Nearest"]
const QUALITIES = ["I", "II", "III", "IV", "V", "VI"]

static func expanded_gems() -> bool:
	if not profile_override.is_empty(): return profile_override == "expanded-gems"
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		return bool(Engine.get_singleton("JavaScriptBridge").eval("new URLSearchParams(window.location.search).get('profile') === 'expanded-gems'"))
	return "--expanded-gems" in OS.get_cmdline_user_args()

static func campaign() -> bool:
	if not profile_override.is_empty(): return profile_override == "campaign"
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		return bool(Engine.get_singleton("JavaScriptBridge").eval("new URLSearchParams(window.location.search).get('profile') === 'campaign'"))
	return "--campaign" in OS.get_cmdline_user_args()

static func select_profile(profile: String) -> void:
	if profile not in ["campaign","review-v1","expanded-gems"]: return
	profile_override = profile
	DATA = load_profile()

static func boss_discount_for_wave(index: int) -> int:
	if not campaign() or index < 1 or index > int(DATA.economy.boss_discount_last_wave) or index % 10 != 0: return 0
	return int(DATA.economy.boss_odds_discount)

static func starting_lives() -> int:
	return int(DATA.get("starting_lives",30))

static func load_profile() -> Dictionary:
	var result = BASE.duplicate(true)
	if expanded_gems():
		result.merge(EXPANDED.duplicate(true),true)
	if campaign():
		result.merge(CAMPAIGN.duplicate(true),true)
	return result

static func content_sha256() -> String:
	if campaign():
		return (FileAccess.get_file_as_string("res://data/catalog.json")+"\n"+FileAccess.get_file_as_string("res://data/campaign.json")).sha256_text()
	if not expanded_gems():
		return FileAccess.get_sha256("res://data/catalog.json")
	return (FileAccess.get_file_as_string("res://data/catalog.json")+"\n"+FileAccess.get_file_as_string("res://data/expanded_gems.json")).sha256_text()

static func effect_value(effect: Dictionary, field: String, tier: int) -> float:
	var value: Variant = effect[field]
	return float(value[tier-1]) if value is Array else float(value)

static func quality_name(tier: int) -> String:
	return QUALITIES[tier-1] if tier >= 1 and tier <= QUALITIES.size() else str(tier)

static func quality_limit(kind: String) -> int:
	return DATA.gems[kind].levels.size() if DATA.gems.has(kind) else 1

static func wave_count() -> int:
	return DATA.waves.size()

static func max_quality_upgrade() -> int:
	return DATA.quality_costs.size()

static func recipes() -> Dictionary:
	return DATA.get("recipes",DATA.specials)

static func recipe(recipe_id: String) -> Dictionary:
	return recipes().get(recipe_id,{})

static func recipe_result(recipe_id: String) -> String:
	return str(recipe(recipe_id).get("result",recipe_id))

static func recipe_title(recipe_id: String) -> String:
	return str(stats({"kind":recipe_result(recipe_id),"tier":1}).name)

static func roll_tier(weights: Array, roll: int) -> int:
	var cumulative = 0
	for i in range(weights.size()):
		cumulative += int(weights[i])
		if roll <= cumulative:
			return i+1
	return weights.size()

static func odds_text(weights: Array) -> String:
	var parts: PackedStringArray = []
	for i in range(weights.size()):
		parts.append("%s  %d%%" % [quality_name(i+1),int(weights[i])])
	if parts.size() > 3:
		return "     ".join(parts.slice(0,3))+"\n"+"     ".join(parts.slice(3))
	return "     ".join(parts)

static func stats(gem: Dictionary) -> Dictionary:
	var kind: String = gem.get("kind", "stone")
	if DATA.specials.has(kind):
		var special: Dictionary = DATA.specials[kind]
		if gem.has("rolled_damage"):
			special = special.duplicate(true)
			special.damage = int(gem.rolled_damage)
		if gem.has("stolen_abilities"):
			special = special.duplicate(true)
			for id in gem.stolen_abilities:
				for effect in DATA.get("ability_effects",{}).get(id,[]):
					if effect.type == "passive": special.damage += float(effect.properties.get("damage_bonus",0))
		return special
	if DATA.gems.has(kind):
		var result: Dictionary = DATA.gems[kind].duplicate(true)
		result.merge(result.levels[int(gem.tier)-1], true)
		return result
	return {"name": "Stone", "color": "#7d8988", "damage": 0.0, "range": 0.0, "interval": 1.0, "targets": "none", "effect": "An obstacle. Demolish freely during the build phase."}

static func title(gem: Dictionary) -> String:
	var data = stats(gem)
	return data.name + ("  ·  " + quality_name(int(gem.get("tier", 1))) if DATA.gems.has(gem.get("kind", "")) else "")

static func color_of(gem: Dictionary) -> Color:
	return Color(stats(gem).color)

static func effective_range(gem: Dictionary) -> float:
	return float(DATA.effects.asteriated_ruby.radius) if gem.get("kind", "") == "asteriated_ruby" else float(stats(gem).range)

# Shared by the simulation and read-only tower information. Equal-quality
# Opals supply one named aura; distinct qualities coexist, including self-aura.
static func attack_timing(gem: Dictionary, p: Vector2i, cells: Dictionary) -> Dictionary:
	if campaign():
		return GemCampaignRules.timing(gem,p,cells)
	if gem.get("kind", "stone") == "asteriated_ruby":
		return {"interval":float(DATA.effects.asteriated_ruby.interval),"innate":0.0,"auras":{},"bonus":0.0}
	var innate = effect_value(DATA.effects.aquamarine,"attack_speed",int(gem.tier)) if gem.get("kind", "") == "aquamarine" else 0.0
	var auras: Dictionary = {}
	for q in cells:
		var support: Dictionary = cells[q]
		if support.kind == "opal" and Vector2(p).distance_to(Vector2(q)) <= float(DATA.effects.opal.radius):
			auras[int(support.tier)] = float(DATA.effects.opal.attack_speed[int(support.tier)-1])
	var bonus = innate
	for amount in auras.values():
		bonus += float(amount)
	return {"interval":float(stats(gem).interval)/(1.0+bonus/100.0),"innate":innate,"auras":auras,"bonus":bonus}

static func wave(index: int) -> Dictionary:
	return DATA.waves[clampi(index-1, 0, wave_count()-1)]
