extends SceneTree

var checks = 0
var failures = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+description)
	else:
		print("PASS: "+description)

func gem(kind: String, tier: int = 1, fresh: bool = true) -> Dictionary:
	return {"kind":kind,"tier":tier,"fresh":fresh,"priority":"First"}

func five(kind: String = "ruby", tier: int = 1) -> GemRun:
	var state = GemRun.new(42)
	for x in range(5):
		state.board.cells[Vector2i(10+x,10)] = gem(kind,tier)
	state.placed = 5
	state.board.rebuild()
	return state

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var state = GemRun.new(123456789)
	check(state.board.cells.size() == 32 and state.board.checkpoints.size() == 7,"reference map contains 32 stones and 7 checkpoints")
	check(not state.board.ground_route.is_empty(),"initial full ground route exists")
	check(state.board.air_route.size() == 7,"air route uses the same seven checkpoints")
	var rng_before = state.rng.state
	check(not state.place(state.board.checkpoints[0]) and state.rng.state == rng_before and state.placed == 0,"invalid placement consumes neither RNG nor placement")
	check(state.place(Vector2i(10,10)),"valid placement succeeds")
	var duplicate = GemRun.new(123456789)
	duplicate.place(Vector2i(10,10))
	check(state.board.cells[Vector2i(10,10)] == duplicate.board.cells[Vector2i(10,10)],"same seed and actions reproduce reveal")
	check(not state.demolish(Vector2i(10,10)),"fresh placements cannot be demolished")
	check(not state.keep(Vector2i(10,10)),"cannot finalize before all five placements")
	var walls = state.board.cells.duplicate(true)
	var start: Vector2i = state.board.checkpoints[0]
	for dx in [-1,0,1]:
		for dy in [-1,0,1]:
			if dx != 0 or dy != 0:
				walls[start+Vector2i(dx,dy)] = {}
	check(state.board.path_for(walls).is_empty(),"isolating any checkpoint invalidates the entire route")
	var grid = AStarGrid2D.new()
	grid.region = Rect2i(0,0,2,2)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	grid.set_point_solid(Vector2i(1,0))
	grid.set_point_solid(Vector2i(0,1))
	check(grid.get_id_path(Vector2i.ZERO,Vector2i.ONE).is_empty(),"diagonal corner cutting is forbidden")
	state = five()
	check(state.keep(Vector2i(10,10)) and state.phase == "combat" and state.fresh_cells().is_empty(),"keep atomically locks the board and starts combat")
	check(state.board.cells[Vector2i(11,10)].kind == "stone","unkept gems become stones")
	check(not state.demolish(Vector2i(10,10)) and not state.place(Vector2i(10,11)),"placement and demolition are locked in combat")
	state = five()
	check(state.upgrade(Vector2i(12,10),4) and state.board.cells[Vector2i(12,10)].tier == 3,"four identical gems produce quality III at the chosen material")
	check(state.board.cells[Vector2i(10,10)].kind == "stone" and state.phase == "combat","upgrade consumes materials and is the final choice")
	state = five("ruby",3)
	rng_before = state.rng.state
	check(not state.upgrade(Vector2i(10,10),2) and state.phase == "build" and state.board.cells[Vector2i(10,10)].kind == "ruby" and state.rng.state == rng_before,"over-cap upgrade is rejected without mutation")
	state = five("ruby",1)
	state.board.cells[Vector2i(10,10)].fresh = false
	check(state.matching_new(Vector2i(10,10)).is_empty(),"quality upgrades never accept older towers")
	state = GemRun.new(42)
	var positions = [Vector2i(10,10),Vector2i(11,10),Vector2i(12,10)]
	for i in range(3):
		state.board.cells[positions[i]] = gem(["sapphire","topaz","diamond"][i],1,false)
	check(state.combine("silver",positions[1],true) and state.phase == "build" and state.placed == 0,"old-only special recipe preserves the new tower choice")
	check(state.board.cells[positions[1]].kind == "silver" and state.board.cells[positions[0]].kind == "stone","special result uses selected material; consumed cells become stones")
	state = five("ruby")
	for i in range(3):
		state.board.cells[Vector2i(10+i,10)] = gem(["sapphire","topaz","diamond"][i],1,i==0)
	check(state.combine("silver",Vector2i(11,10)) and state.phase == "combat" and state.fresh_cells().is_empty(),"mixed old/new recipe consumes the round choice and starts combat")
	state = GemRun.new(17)
	state.gold = 100
	check(state.buy_quality() and state.gold == 80 and state.quality == 1,"quality purchase charges the configured cost")
	state.phase = "combat"
	check(state.buy_quality() and state.quality == 2 and state.gold == 35,"quality purchases are available during combat")
	check(not state.buy_quality() and state.gold == 35,"quality odds cannot exceed configured cap")
	state = GemRun.new(123)
	state.place(Vector2i(10,10))
	# Saving is orchestrated only at build-start; round-trip a genuine start snapshot.
	state = GemRun.new(123)
	state.gold = 44
	var saved = JSON.parse_string(JSON.stringify(state.snapshot()))
	duplicate = GemRun.new(999)
	check(duplicate.restore(saved) and duplicate.gold == 44 and duplicate.rng.state == state.rng.state,"versioned JSON round-trip preserves 64-bit RNG state")
	state.place(Vector2i(10,10))
	duplicate.place(Vector2i(10,10))
	check(state.board.cells[Vector2i(10,10)] == duplicate.board.cells[Vector2i(10,10)],"resume preserves the next revealed gem")
	saved.version = 999
	check(not duplicate.restore(saved),"incompatible save version is rejected")
	check(not duplicate.restore({}),"malformed save is rejected")
	check(is_equal_approx(GemDamage.resolve(100,"physical",{"armor":10}),62.5),"positive armor reduces physical damage")
	check(GemDamage.resolve(100,"physical",{"armor":-10}) > 100,"negative armor amplifies physical damage")
	check(is_equal_approx(GemDamage.resolve(100,"magical",{"magic_resist":.4}),60),"magic resistance applies to magical damage")
	check(is_equal_approx(GemDamage.resolve(100,"magical",{"magic_resist":-1.5}),250),"negative magic resistance can amplify beyond double damage")
	check(is_equal_approx(GemDamage.resolve(100,"pure",{"armor":100,"magic_resist":.9}),100),"pure damage bypasses armor and resistance")
	check(GemDamage.resolve(100,"magical",{"magic_immune":true}) == 0 and GemDamage.resolve(100,"physical",{"physical_immune":true}) == 0,"type immunities prevent their damage type")
	check(GemDamage.resolve(100,"pure",{"invulnerable":true}) == 0,"invulnerability blocks pure damage too")
	check(GemDamage.resolve(100,"physical",{"evasion":.5},true,.1) == 0,"evasion only affects attack rolls")
	check(GemDamage.resolve(100,"pure",{"inspired":true}) == 50 and GemDamage.resolve(100,"physical",{"stone_gaze":true}) == 200,"reference incoming modifiers apply")
	state = GemRun.new(1)
	state.phase = "combat"
	var before_gold = state.gold
	state.leaked(2,false)
	check(state.lives == 28 and state.gold == before_gold,"ordinary leak costs lives and awards no kill gold")
	state.leaked(1,true)
	check(state.phase == "lost" and state.lives > 0,"boss leak immediately loses even with lives remaining")
	state = GemRun.new(1)
	state.phase = "combat"
	state.wave = 10
	state.finish_wave()
	check(state.phase == "won","resolved final wave with lives remaining wins")
	state = GemRun.new(1)
	state.phase = "combat"
	state.finish_wave()
	check(state.wave == 2 and state.phase == "build" and state.placed == 0 and state.gold == 14,"completed wave awards income and enters next build phase")
	# Exercise the actual simulation from spawn to completion without UI dependencies.
	state = GemRun.new(1)
	state.board.cells[Vector2i(5,3)] = gem("silver",1,false)
	state.board.rebuild()
	state.phase = "combat"
	var sim = GemCombat.new(state)
	sim.start()
	for i in range(9000):
		sim.tick(1.0/30.0)
		if state.phase != "combat":
			break
	check(state.phase == "build" and state.wave == 2 and state.kills > 0,"real combat simulation spawns, attacks, rewards and completes a wave")
	# Every tower can hit air, as in the Dota 2 version (Diamond was ground-only before 2026-10-24).
	state = GemRun.new(5)
	state.phase = "combat"
	state.wave = 5
	sim = GemCombat.new(state)
	sim.start()
	sim.spawn_enemy()
	var target_pos = state.board.checkpoints[0]+Vector2i(1,0)
	check(sim.targets_for(target_pos,gem("diamond"),GemCatalog.stats(gem("diamond"))).size() == 1,"diamond acquires flying targets like every other tower")
	check(sim.targets_for(target_pos,gem("sapphire"),GemCatalog.stats(gem("sapphire"))).size() == 1,"dual-target tower can acquire flying targets")
	# Source-derived effects have observable outcomes, not just valid definitions.
	state = GemRun.new(8)
	state.phase = "combat"
	sim = GemCombat.new(state)
	sim.start()
	sim.spawn_enemy()
	var enemy: Dictionary = sim.enemies[0]
	enemy.hp = 1000.0
	enemy.hp_max = 1000.0
	enemy.evasion = 0.0
	enemy.armor = 0.0
	enemy.magic_resist = 0.0
	sim.attack(Vector2i(5,3),gem("ruby"),GemCatalog.stats(gem("ruby")),enemy)
	check(is_equal_approx(enemy.hp,994.8),"Ruby I hits for 4 physical plus 1.2 pure splash including primary target")
	sim.attack(Vector2i(5,3),gem("sapphire"),GemCatalog.stats(gem("sapphire")),enemy)
	sim.attack(Vector2i(6,3),gem("sapphire"),GemCatalog.stats(gem("sapphire")),enemy)
	check(enemy.slow == 60,"same named slow refreshes without stacking")
	sim.attack(Vector2i(5,3),gem("sapphire",2),GemCatalog.stats(gem("sapphire",2)),enemy)
	check(enemy.slow == 150,"different slow modifier names coexist")
	sim.elapsed = 3.1
	check(sim.sum_modifiers(enemy.slows) == 0,"expired slow modifiers are removed")
	sim.attack(Vector2i(5,3),gem("amethyst"),GemCatalog.stats(gem("amethyst")),enemy)
	sim.attack(Vector2i(5,3),gem("amethyst",2),GemCatalog.stats(gem("amethyst",2)),enemy)
	check(enemy.armor_debuff == 6,"different quality armor debuffs coexist")
	sim.attack(Vector2i(5,3),gem("emerald"),GemCatalog.stats(gem("emerald")),enemy)
	sim.attack(Vector2i(5,3),gem("emerald"),GemCatalog.stats(gem("emerald")),enemy)
	check(enemy.poisons.size() == 2,"MULTIPLE poison creates independent timed instances")
	var before_poison = float(enemy.hp)
	sim.elapsed = 4.09
	sim.spawn_clock = 1000
	sim.spawned = int(sim.wave_data.count)
	sim.tick(1.0/30.0)
	check(is_equal_approx(before_poison-float(enemy.hp),4.0),"two poison instances deal two magic ticks")
	for i in range(300):
		sim.tick(1.0/30.0)
	check(is_equal_approx(before_poison-float(enemy.hp),40.0) and enemy.poisons.is_empty(),"poison includes all ten scheduled ticks across floating-point expiry")
	# Split-shot side projectiles are ApplyDamage and bypass attack evasion.
	state = GemRun.new(9)
	state.phase = "combat"
	state.board.cells[Vector2i(5,3)] = gem("topaz",1,false)
	sim = GemCombat.new(state)
	sim.start()
	for i in range(4):
		sim.spawn_enemy()
		sim.enemies[i].hp = 100.0
		sim.enemies[i].evasion = 1.0
		sim.enemies[i].armor = 0.0
	sim.spawned = int(sim.wave_data.count)
	sim.tick(1.0/30.0)
	var damaged = 0
	for e in sim.enemies:
		if is_equal_approx(e.hp,97.0):
			damaged += 1
	check(damaged == 3 and sim.enemies[0].hp == 100,"split shot hits three secondary enemies despite 100% attack evasion")
	# Aura names stack across qualities but not between identical quality towers.
	state = GemRun.new(10)
	state.phase = "combat"
	state.board.cells[Vector2i(5,3)] = gem("aquamarine",1,false)
	state.board.cells[Vector2i(6,3)] = gem("opal",1,false)
	state.board.cells[Vector2i(7,3)] = gem("opal",1,false)
	state.board.cells[Vector2i(8,3)] = gem("opal",2,false)
	sim = GemCombat.new(state)
	sim.start()
	sim.spawn_enemy()
	sim.enemies[0].hp = 1000
	sim.spawned = int(sim.wave_data.count)
	sim.tick(1.0/30.0)
	check(is_equal_approx(sim.cooldowns[Vector2i(5,3)],1.0/3.5),"Aquamarine +200 and distinct Opal auras +20/+30 set the attack interval")
	# Priorities operate on live state, including tie-breaks stable across platforms.
	sim.spawn_enemy()
	sim.enemies[0].travelled = 1.0
	sim.enemies[0].hp = 200
	sim.enemies[1].travelled = 2.0
	sim.enemies[1].hp = 100
	var targeting_gem = gem("sapphire")
	check(sim.targets_for(Vector2i(5,3),targeting_gem,GemCatalog.stats(targeting_gem))[0].id == sim.enemies[1].id,"First targets the most advanced enemy")
	targeting_gem.priority = "Last"
	check(sim.targets_for(Vector2i(5,3),targeting_gem,GemCatalog.stats(targeting_gem))[0].id == sim.enemies[0].id,"Last targets the least advanced enemy")
	targeting_gem.priority = "Strongest"
	check(sim.targets_for(Vector2i(5,3),targeting_gem,GemCatalog.stats(targeting_gem))[0].hp == 200,"Strongest targets the most current HP")
	sim.enemies[0].pos = Vector2(5.5,3.5)
	sim.enemies[1].pos = Vector2(7.5,3.5)
	targeting_gem.priority = "Nearest"
	check(sim.targets_for(Vector2i(5,3),targeting_gem,GemCatalog.stats(targeting_gem))[0].id == sim.enemies[0].id,"Nearest targets by distance independently of route progress")
	state = GemRun.new(11)
	var disk_path = "res://output/test_checkpoint.json"
	DirAccess.make_dir_recursive_absolute("res://output")
	check(GemSave.write_snapshot(state.snapshot(),disk_path) == OK,"checkpoint is written to disk")
	state.gold = 12
	check(GemSave.write_snapshot(state.snapshot(),disk_path) == OK and GemSave.read_snapshot(disk_path).gold == 12,"atomic checkpoint replacement preserves the newer save")
	var bad_save = state.snapshot().duplicate(true)
	bad_save.cells[0].gem.erase("priority")
	check(not duplicate.restore(bad_save),"incomplete saved cell metadata is rejected")
	state = GemRun.new(12)
	# A controlled defense fixture exercises every wave and checkpoint transition.
	for p in [Vector2i(5,4),Vector2i(5,8),Vector2i(5,12),Vector2i(10,17),Vector2i(25,17),Vector2i(31,10),Vector2i(25,5),Vector2i(17,10),Vector2i(17,16),Vector2i(17,24),Vector2i(17,30),Vector2i(25,31),Vector2i(30,31)]:
		state.board.cells[p] = gem("asteriated_ruby",1,false)
	state.board.rebuild()
	var snapshots = 0
	for wave_index in range(1,11):
		state.phase = "combat"
		sim = GemCombat.new(state)
		sim.start()
		for i in range(12000):
			sim.tick(1.0/30.0)
			if state.phase != "combat":
				break
		if state.phase == "build":
			snapshots += 1
		if state.phase == "lost":
			break
	check(state.phase == "won" and snapshots == 9 and state.lives > 0,"all ten waves simulate through nine build checkpoints to boss victory")
	print("TEST_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures > 0 else 0)
