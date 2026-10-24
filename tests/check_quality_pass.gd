extends "res://tests/check_campaign.gd"

func run_checks() -> void:
	var combat = fixture("silver")
	combat.run.board.cells[at+Vector2i.RIGHT] = gem("heisemaoyanshi")
	combat.run.board.cells[at].mvp = 3
	combat.sync_towers()
	var info = GemTowerInfo.profile(combat.run.board.cells[at],at,combat.run.board.cells,combat)
	var raw = float(GemCatalog.stats(gem("silver")).damage)*1.3
	check(info.damage == floorf(raw*1.3) and is_equal_approx(info.dps,info.damage/combat.towers[at].interval),"damage aura, own MVP, rounding and supported attack interval included")
	var enemy: Dictionary = combat.enemies[0]
	enemy.base_armor = 0.0
	enemy.evasion = 0.0
	enemy.defense_dirty = true
	var before = float(enemy.hp)
	combat.launch_projectile(at,gem("silver"),GemCatalog.stats(gem("silver")),enemy,raw,raw,true,true)
	check(is_equal_approx(before-float(enemy.hp),info.damage),"displayed physical hit equals a real unmitigated projectile impact")
	combat.towers[at].buffs["test"] = {"until":2.0,"properties":{"outgoing_percent":50}}
	info = GemTowerInfo.profile(combat.run.board.cells[at],at,combat.run.board.cells,combat)
	check(info.damage == floorf(float(GemCatalog.stats(gem("silver")).damage)*1.8*1.3),"active temporary damage buff included in the same order as combat")
	combat.elapsed = 3
	info = GemTowerInfo.profile(combat.run.board.cells[at],at,combat.run.board.cells,combat)
	check(info.damage == floorf(raw*1.3) and combat.towers[at].buffs.has("test"),"expired bonus excluded without mutating combat state")
	combat = fixture("opal")
	combat.run.board.cells[at+Vector2i.RIGHT] = gem("heisemaoyanshi")
	combat.sync_towers()
	info = GemTowerInfo.profile(gem("opal"),at,combat.run.board.cells,combat)
	check(is_equal_approx(info.damage,1.3),"fractional damage is preserved when MVP rounding does not apply")
	for kind in ["asteriated_ruby","xuehonghuoshan","ranshaozhishi"]:
		combat = fixture(kind)
		combat.run.board.cells[at+Vector2i.RIGHT] = gem("heisemaoyanshi")
		combat.run.board.cells[at+Vector2i.DOWN] = gem("opal",6)
		combat.sync_towers()
		var action: Dictionary = GemCampaignRules.actions(gem(kind)).filter(func(a): return a.type == "enemy_aura" and a.has("damage"))[0]
		info = GemTowerInfo.profile(gem(kind),at,combat.run.board.cells,combat)
		check(info.aura and info.damage == action.damage and info.interval == action.interval and info.range == action.radius and info.dps == float(action.damage)/float(action.interval),"real aura tick, DPS and radius ignore attack-only support: "+kind)
		check(not GemTowerInfo.describe(info).contains("physical") and info.timing.bonus == 0,"aura display has no invented attack or attack-speed DPS: "+kind)
	combat = fixture("asteriated_ruby")
	combat.run.board.cells[at].mvp = 4
	combat.sync_towers()
	info = GemTowerInfo.profile(combat.run.board.cells[at],at,combat.run.board.cells,combat)
	enemy = combat.enemies[0]
	enemy.base_magic = 0
	enemy.defense_dirty = true
	combat.refresh_defenses(enemy)
	combat.elapsed = .25
	before = float(enemy.hp)
	combat.update_enemy(enemy,0)
	check(info.damage == 28 and info.dps == 112 and is_equal_approx(before-float(enemy.hp),info.damage),"Ruby's MVP-adjusted displayed tick equals actual aura damage")
	info = GemTowerInfo.profile(gem("gudaidejixueshi"),at,{at:gem("gudaidejixueshi")})
	check(not info.aura and info.aura_components.size() == 1 and GemTowerInfo.describe(info).contains("500.0 DPS per enemy"),"hybrid tower separates primary attacks from periodic aura DPS")
	var cells = {at:gem("diamond"),at+Vector2i(2,0):gem("silver"),at+Vector2i(2,2):gem("silver"),at+Vector2i(0,1):gem("stone")}
	cells[at+Vector2i(2,0)].mvp = 10
	cells[at+Vector2i(2,2)].mvp = 10
	cells[at+Vector2i(0,1)].mvp = 10
	check(GemAbilityArt.mvp_sources(cells,at) == [at+Vector2i(2,0)],"MVP highlight uses exact circular range and excludes stones")
	check(GemAbilityArt.mvp_sources(cells,at+Vector2i(2,0)).size() == 1,"MVP emitter does not count its own aura")
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	game.run.board.cells[at] = gem("asteriated_ruby")
	game.on_cell_clicked(at)
	check(game.gem_tiles.damage.caption.text == "MAGIC" and game.gem_tiles.speed.caption.text == "TICK" and game.gem_tiles.range.caption.text == "AURA RADIUS" and game.gem_tiles.dps.value.text == "80.0" and not game.priority.visible,"real Ruby panel shows magic, tick, aura DPS and aura radius")
	game.run.board.cells[at] = gem("silver")
	game.refresh_ui()
	check(game.gem_tiles.speed.caption.text == "ATTACK" and game.gem_tiles.range.caption.text == "RANGE" and game.priority.visible,"ordinary selection restores attack labels and targeting")
	game.free()
	print("QUALITY_PASS_CHECK_%s checks=%d failures=%d" % ["OK" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
