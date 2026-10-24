extends "res://tests/check_campaign.gd"

func collect(event: Dictionary, events: Array, fx: GemEffects, cells: Dictionary) -> void:
	events.append(event)
	GemAbilityArt.receive(fx,event,cells)

func render_event(event: Dictionary, fx: GemEffects, cells: Dictionary) -> void:
	GemAbilityArt.receive(fx,event,cells)

func run_checks() -> void:
	var config = GemArt.config()
	var old = config.effects.duplicate(true)
	config.effects.enabled = true
	var supported = ["enemy_aura","support","on_hit","stun","petrify","crit","split","chain","shock","splash","burst","passive","cosmetic","self_disarm","slab_echo"]
	var count = 0
	for kind in GemCatalog.DATA.specials:
		if GemCatalog.DATA.specials[kind].get("slab",false): continue
		count += 1
		var profile: Dictionary = GemAbilityArt.profiles.towers.get(kind,{})
		check(not profile.is_empty() and profile.abilities == GemCatalog.stats(gem(kind)).abilities,"projectile profile matches actual abilities: "+kind)
		for action in GemCampaignRules.actions(gem(kind)):
			check(action.type in supported,"visual vocabulary covers "+kind+" / "+action.type)
	check(count == 43,"all 43 special towers covered")
	var combat = fixture("asteriated_ruby")
	var fx = GemEffects.new()
	var events: Array = []
	combat.ability_visual.connect(collect.bind(events,fx,combat.run.board.cells))
	var enemy: Dictionary = combat.enemies[0]
	combat.refresh_defenses(enemy)
	combat.elapsed = .24
	combat.update_enemy(enemy,0)
	check(events.is_empty(),"aura does not invent a hit before its first damage tick")
	combat.elapsed = .25
	combat.update_enemy(enemy,0)
	check(events.size() == 1 and events[0].type == "aura" and events[0].amount > 0,"Ruby emits real resolved aura damage at 0.25 seconds")
	check(fx.events.any(func(e): return e.kind == "ability_hit" and e.style == "fire") and fx.events.any(func(e): return e.kind == "ability_wave" and is_equal_approx(e.radius,3.90625)),"Ruby has victim flames and the correct aura radius")
	var frozen = fx.events.duplicate(true)
	fx.advance(0)
	check(fx.events == frozen,"pause freezes ability animations")
	enemy.magic_immune = true
	combat.elapsed = .5
	combat.update_enemy(enemy,0)
	check(events.size() == 1,"immune target has no false aura damage effect")
	combat = fixture("silver")
	events.clear()
	combat.ability_visual.connect(func(e): events.append(e))
	enemy = combat.enemies[0]
	enemy.pos += Vector2(2,0)
	combat.attack(at,gem("silver"),GemCatalog.stats(gem("silver")),enemy)
	check(events.is_empty(),"no slow animation before the projectile arrives")
	combat.advance_projectiles(5)
	check(events.any(func(e): return e.type == "modifier" and GemAbilityArt.style(e.effect) == "frost"),"slow effect follows real impact modifier")
	combat = fixture("jixueshi")
	combat.spawn_enemy()
	combat.enemies[1].pos = combat.enemies[0].pos+Vector2(1,0)
	combat.enemies[1].hp = 1000000000.0
	events.clear()
	combat.ability_visual.connect(func(e): events.append(e))
	var effect: Dictionary = GemCampaignRules.actions(gem("jixueshi"))[0]
	var chain = {"type":"chain","source":at,"target":combat.enemies[0],"effect":effect,"left":2,"visited":[]}
	combat.execute_delayed(chain)
	combat.execute_delayed(combat.delayed.pop_back())
	check(events.size() == 2 and events[1].from == combat.enemies[0].pos and events[1].pos == combat.enemies[1].pos,"chain links use the previous actual victim and the real next victim")
	combat = fixture("fenhongzuanshi")
	events.clear()
	combat.ability_visual.connect(func(e): events.append(e))
	enemy = combat.enemies[0]
	combat.launch_projectile(at,gem("fenhongzuanshi"),GemCatalog.stats(gem("fenhongzuanshi")),enemy,100,20,true,true)
	check(events.any(func(e): return e.type == "critical"),"crit burst comes from an actually amplified impact")
	events.clear()
	enemy.refraction = 1
	combat.launch_projectile(at,gem("fenhongzuanshi"),GemCatalog.stats(gem("fenhongzuanshi")),enemy,100,20,true,true)
	check(events.is_empty(),"blocked critical impact does not produce a false crit")
	fx.clear()
	config.effects.enabled = false
	GemAbilityArt.receive(fx,{"type":"aura","source":at,"pos":Vector2.ONE,"effect":{"type":"enemy_aura","damage":20,"radius":3}}, {})
	check(fx.events.is_empty() and fx.ability_pulses.is_empty(),"disabled effects allocate no ability particles or pulse history")
	config.effects = old
	# Same real simulation and RNG, with and without the full visual observer.
	for kind in GemAbilityArt.profiles.towers:
		var results: Array = []
		for observed in [false,true]:
			combat = fixture(kind)
			fx = GemEffects.new()
			if observed: combat.ability_visual.connect(render_event.bind(fx,combat.run.board.cells))
			for tick in range(120):
				combat.tick(1.0/30)
				fx.advance(1.0/30)
			results.append({"rng":combat.run.combat_rng.state,"hp":combat.enemies[0].hp,"damage":combat.wave_damage.duplicate(),"kills":combat.run.kills})
		check(results[0] == results[1],"visuals preserve combat outcome and RNG: "+kind)
	print("ABILITY_ART_CHECK_%s checks=%d failures=%d" % ["OK" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
