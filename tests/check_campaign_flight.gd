extends "res://tests/check_campaign.gd"

func fire(combat: GemCampaignCombat) -> Dictionary:
	var target: Dictionary = combat.enemies[0]
	target.pos = Vector2(at)+Vector2(3.5,.5)
	target.base_armor = 0.0
	target.base_magic = 0.0
	combat.attack(at,combat.run.board.cells[at],GemCatalog.stats(combat.run.board.cells[at]),target)
	return target

func space_key() -> void:
	for pressed in [true,false]:
		var event = InputEventKey.new()
		event.keycode = KEY_SPACE
		event.physical_keycode = KEY_SPACE
		event.unicode = 32
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func run_checks() -> void:
	var combat = fixture("sapphire")
	var enemy = fire(combat)
	var hp = float(enemy.hp)
	check(enemy.hp == 1000000000.0 and enemy.mods.is_empty() and combat.projectiles.size() == 1,"launch has no damage or on-hit effect before a distant target is reached")
	combat.advance_projectiles(.1)
	check(enemy.hp == hp and enemy.mods.is_empty() and combat.projectiles.size() == 1,"a 3000-world-unit projectile remains airborne after 0.1 seconds over three cells")
	combat.elapsed = .13
	combat.advance_projectiles(.03)
	check(enemy.hp < hp and not enemy.mods.is_empty() and combat.projectiles.is_empty(),"damage and slow start together at the actual impact")
	check(is_equal_approx(float(enemy.mods.values()[0].until),combat.elapsed+3),"slow duration starts on impact, not at launch")
	combat = fixture("diamond")
	enemy = fire(combat)
	var origin: Vector2 = combat.projectiles[0].pos
	enemy.pos += Vector2(0,4)
	combat.advance_projectiles(.01)
	check(combat.projectiles[0].pos.y > origin.y,"tracking flight follows the target's new position")
	var moved: float = combat.projectiles[0].pos.distance_to(origin)
	check(is_equal_approx(moved,3000.0/128*.01),"tracking displacement uses source world speed converted once to cells")
	enemy.pos = Vector2(at)+Vector2(30,.5)
	combat.advance_projectiles(.1)
	check(combat.projectiles.size() == 1,"a launched projectile continues after its target leaves acquisition range")
	enemy.dead = true
	var health = float(enemy.hp)
	combat.advance_projectiles(10)
	check(combat.projectiles.is_empty() and enemy.hp == health,"dead target discards the projectile without damage or retargeting")
	combat = fixture("diamond")
	enemy = fire(combat)
	enemy.escaped = true
	combat.advance_projectiles(10)
	check(combat.projectiles.is_empty(),"escaped target discards a projectile")
	combat = fixture("malachite")
	combat.spawn_enemy()
	for e in combat.enemies:
		e.pos = Vector2(at)+Vector2(2.5,.5)
		e.hp = 1000.0
		e.base_armor = 0.0
		e.evasion = 1.0
	combat.attack(at,gem("malachite"),GemCatalog.stats(gem("malachite")),combat.enemies[0])
	check(combat.projectiles.size() == 2 and combat.enemies[1].hp == 1000,"multishot extras also wait for real projectile travel")
	combat.advance_projectiles(1)
	check(combat.enemies[0].hp == 1000 and combat.enemies[1].hp < 1000,"primary evasion and non-dodgeable split damage resolve separately at impact")
	combat = fixture("ruby")
	enemy = fire(combat)
	enemy.evasion = 1.0
	combat.advance_projectiles(1)
	check(enemy.hp == 1000000000.0,"a missed primary hit does not trigger pure splash")
	combat = fixture("diamond")
	enemy = fire(combat)
	var projectile_position: Vector2 = combat.projectiles[0].pos
	combat.run.phase = "build"
	combat.tick(1)
	check(combat.projectiles[0].pos == projectile_position,"combat flight cannot advance while simulation is inactive")
	combat.start()
	check(combat.projectiles.is_empty(),"starting a new wave clears every previous flight")
	var speed = GemCampaignRules.timing_from_bonus(.5,500)
	check(is_equal_approx(speed.interval,.5/6) and speed.total == 600 and not speed.capped,"Aquamarine VI's +500 means total speed 600, not 500")
	speed = GemCampaignRules.timing_from_bonus(.5,600)
	check(is_equal_approx(speed.interval,.5/7) and speed.capped,"exactly 700 total reaches the documented Dota standard cap")
	speed = GemCampaignRules.timing_from_bonus(.5,930)
	check(is_equal_approx(speed.interval,.5/7) and speed.uncapped_total == 1030,"excess support attack speed no longer increases attack frequency")
	var cells: Dictionary = {at:gem("aquamarine",6)}
	for i in range(6): cells[at+Vector2i(i%3-1,i/3+1)] = gem("opal",i+1)
	combat = fixture("aquamarine",6)
	combat.run.board.cells = cells
	combat.start()
	var info = GemTowerInfo.profile(cells[at],at,cells)
	check(info.timing.capped and is_equal_approx(info.interval,combat.towers[at].interval),"inspection and actual cached combat use the same cap with real Opal supports")
	check(GemTowerInfo.describe(info).contains("Speed cap reached") and GemTowerInfo.describe(info).contains("projectile arrives"),"tower inspection explains both wasted speed and impact timing")
	check(is_equal_approx(GemDamage.resolve(100,"physical",{"armor":5}),100/1.3),"physical hit with armor five remains unboosted by any guessed legacy class multiplier")
	check(is_equal_approx(GemDamage.resolve(100,"physical",{"armor":-5}),100*(1+.3/1.3)),"negative armor preserves the campaign's explicit amplification formula")
	check(is_equal_approx(GemCatalog.stats(gem("aijijin")).projectile_speed,2000.0/128),"Egyptian Gold retains its slower source projectile")
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	game.speed = 2
	game.paused = true
	game.refresh_ui()
	game.speed_button.grab_focus()
	await space_key()
	check(not game.paused and game.speed == 2,"real Space press resumes without reactivating a focused speed button")
	game.pause_button.grab_focus()
	await space_key()
	check(game.paused and game.speed == 2,"real Space press pauses exactly once with the pause button focused")
	game.show_seed_dialog()
	await space_key()
	check(game.paused,"Space inside a modal does not toggle the underlying simulation")
	game.free()
	print("CAMPAIGN_FLIGHT_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
