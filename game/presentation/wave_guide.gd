class_name GemWaveGuide
extends RefCounted

# Read-only planning data for the prototype's fixed wave sequence.
static func status(state: GemRun, index: int) -> String:
	if index < state.wave:
		return "Cleared"
	if index > state.wave:
		return "Not reached" if state.phase == "lost" else "Upcoming"
	return {"build":"Next","combat":"Fighting","won":"Victory","lost":"Defeat"}.get(state.phase,"")

static func coverage(state: GemRun, air: bool) -> Dictionary:
	var result = {"kept":0,"kept_total":0,"fresh":0,"fresh_total":0}
	for gem in state.board.cells.values():
		if gem.kind == "stone":
			continue
		var bucket = "fresh" if gem.fresh else "kept"
		result[bucket+"_total"] += 1
		if not air or GemCatalog.stats(gem).targets == "both":
			result[bucket] += 1
	return result

static func damage_preview(wave: Dictionary) -> Dictionary:
	# A landed hit against the wave's initial defenses, without temporary debuffs.
	# Evasion is displayed separately, never silently averaged into the result.
	return {"physical":GemDamage.resolve(100*float(wave.get("physical_multiplier",1)),"physical",wave),
		"magical":GemDamage.resolve(100,"magical",wave),"pure":GemDamage.resolve(100,"pure",wave)}

static func inspect(state: GemRun, index: int) -> Dictionary:
	if state == null or index < 1 or index > GemCatalog.DATA.waves.size():
		return {}
	var wave: Dictionary = GemCatalog.DATA.waves[index-1].duplicate(true)
	if GemCatalog.campaign():
		wave.magic_immune = "enemy_momian" in wave.abilities
		wave.physical_multiplier = .25 if "enemy_wumian" in wave.abilities else 1.0
		wave.evasion = .5 if "guai_shanbi" in wave.abilities else 0.0
		if not wave.boss: wave.count = state.enemy_count
	var life_word = "life" if int(wave.leak) == 1 else "lives"
	return {"index":index,"status":status(state,index),"wave":wave,
		"coverage":coverage(state,bool(wave.air)),"damage":damage_preview(wave),
		"route":"Air: flies straight between checkpoints, over obstacles." if wave.air else "Ground: follows your maze through all seven checkpoints.",
		"leak":"Any boss leak ends the run, regardless of remaining lives." if wave.boss else "%d–%d lives lost per enemy that reaches the exit." % [int(wave.leak),int(wave.leak_max)] if wave.has("leak_max") else "%d %s lost per enemy that reaches the exit." % [int(wave.leak),life_word]}

static func campaign_traits(wave: Dictionary) -> String:
	var names = {"riki_permanent_invisibility":"Invisible: reveal with Opal / true sight", "enemy_jili":"Heals at checkpoints", "enemy_thief":"Steals 1% gold at checkpoints", "enemy_momian":"Magic immune", "enemy_wumian":"75% physical damage reduction", "guai_shanbi":"50% attack evasion", "guai_jiaoxieguanghuan":"Nearby towers are disarmed; magic protection counters it", "enemy_zheguang":"Refraction: seven damage-blocking charges", "enemy_bukeqinfan":"50% average disarm rate with smoothed streaks; attacking tower disabled for 1s", "runrunrun":"Windrun: +50% movement for 20s", "enemy_high_armor":"Stacking +4 armor aura", "mars_bulwark":"Directional physical defense", "enemy_recharge":"Regenerates 0.3% max health per second", "enemy_shanshuo":"Blink: skips part of the path, 12s cooldown", "tidehunter_blubber":"Cleanses debuffs after 80,000 damage"}
	var lines: PackedStringArray = []
	for ability in wave.get("abilities",[]):
		if names.has(ability): lines.append(names[ability])
	if wave.get("trial",false): lines.append("Trial: two seeded random abilities; ×1.8 speed. Health varies with the rolled abilities.")
	if not wave.get("variants",[]).is_empty(): lines.append("50% alternate courier variant per spawn.")
	return "\n".join(lines)

static func brief(wave: Dictionary, index: int = 0) -> String:
	var life_word = "life" if int(wave.leak) == 1 else "lives"
	var text = "%s\n%d × %s · %.2f HP\nArmor %.0f · Magic %+.0f%%\nLeak: %s\nKills +%d gold · Clear +%d" % [wave.name,int(wave.count),"Air" if wave.air else "Ground",float(wave.hp),float(wave.armor),float(wave.magic_resist)*100,"instant defeat" if wave.boss else "%d %s each" % [int(wave.leak),life_word],int(wave.reward),int(wave.completion)]
	if float(wave.get("evasion",0)) > 0:
		text += "\nEvasion: %.0f%% (attacks only)" % (float(wave.evasion)*100)
	if GemCatalog.campaign():
		if not wave.boss: text = text.replace("Leak: %d %s each" % [int(wave.leak),life_word],"Leak: %d–%d lives each" % [int(wave.leak),int(wave.leak_max)])
		if GemCatalog.boss_discount_for_wave(index) > 0: text += "\nBoss defeat: +150 saved gem discount"
		text += "\n"+campaign_traits(wave)
		if wave.trial: text = text.replace("HP","base HP before trial scaling")
	return text
