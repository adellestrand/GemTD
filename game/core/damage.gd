class_name GemDamage
extends RefCounted

# Dota's armor multiplier supports negative armor (damage amplification).
static func armor_multiplier(armor: float) -> float:
	return 1.0 - 0.06 * armor / (1.0 + 0.06 * absf(armor))

static func resolve(raw: float, damage_type: String, victim: Dictionary, is_attack: bool = false, roll: float = 1.0) -> float:
	if victim.get("invulnerable", false):
		return 0.0
	if is_attack and roll < float(victim.get("evasion", 0.0)):
		return 0.0
	var result = maxf(0.0, raw)
	match damage_type:
		"physical":
			if victim.get("physical_immune", false):
				return 0.0
			result *= armor_multiplier(float(victim.get("armor", 0.0)) - float(victim.get("armor_debuff", 0.0)))
			if victim.get("stone_gaze", false):
				result *= 2.0
		"magical":
			if victim.get("magic_immune", false):
				return 0.0
			result *= maxf(0.0, 1.0-float(victim.get("magic_resist", 0.0)))
		"pure":
			pass
		_:
			push_error("Unknown damage type: " + damage_type)
			return 0.0
	if victim.get("inspired", false):
		result *= 0.5
	return result * float(victim.get("incoming_multiplier", 1.0))
