extends "res://tests/check_campaign.gd"

func run_checks() -> void:
	var labels: Array = []
	for tier in range(1,7): labels.append(GemReadability.tower_label(gem("sapphire",tier)))
	check(labels == ["I","II","III","IV","V","VI"],"all six qualities have distinct compact world badges")
	var codes: Array = []
	var mapped = true
	for kind in GemCatalog.DATA.specials:
		if GemCatalog.DATA.specials[kind].slab: continue
		var code = GemReadability.tower_label(gem(kind))
		mapped = mapped and GemReadability.DATA.special_codes.has(kind) and code not in codes and code.length() <= 4
		codes.append(code)
	check(mapped and codes.size() == 43,"all 43 special towers have unique short identities independent of shared sprite art")
	var families: Dictionary = {}
	var styles = true
	for kind in GemCatalog.DATA.specials:
		if not GemCatalog.DATA.specials[kind].slab: continue
		var style = GemReadability.trap_style(kind)
		families[style.symbol] = true
		var tier = 3 if kind.ends_with("_jin") else 2 if kind.ends_with("_yin") else 1
		styles = styles and int(style.tier) == tier
	check(styles and families.size() == 8,"24 traps preserve eight distinct family symbols and three grade marks")
	var enemy = {"current_properties":{"stone_gaze":true,"stunned":true,"move_percent":-50,"armor":-10},"refraction":7,"invisible":true,"mods":{"poison":{"damage":10}},"magic_immune":true}
	var before = enemy.duplicate(true)
	var states = GemReadability.enemy_states(enemy)
	check(states == ["stone","stun","refraction","invisible","poison","slow","armor","immune"],"campaign states use stable priority and include modifier-based poison and slow")
	check(enemy == before,"presentation queries never add fields or change combat modifiers")
	check(GemReadability.enemy_states({}).is_empty(),"healthy enemies receive no misleading state icons")
	check(int(GemReadability.DATA.max_status_icons) == 3,"dense enemies have a bounded number of visible state marks")
	var all_colors = true
	for id in states: all_colors = all_colors and GemReadability.DATA.status_colors.has(id)
	check(all_colors,"every displayed state has a replaceable palette entry")
	print("READABILITY_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
