extends SceneTree

var checks = 0
var failures = 0
var at = Vector2i(10,10)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)
	else:
		print("PASS: "+description)

func fixture(kind: String) -> GemCombat:
	var state = GemRun.new(42)
	state.phase = "combat"
	state.board.cells[at] = {"kind":kind,"tier":1,"fresh":false,"priority":"First"}
	var combat = GemCombat.new(state)
	combat.start()
	combat.spawn_enemy()
	combat.spawned = int(combat.wave_data.count)
	combat.ground = PackedVector2Array([Vector2(at)+Vector2(.5,.5),Vector2(at)+Vector2(1000,.5)])
	combat.enemies[0].hp = 1000000.0
	combat.enemies[0].magic_resist = 0.0
	combat.enemies[0].armor = 0.0
	return combat

func _initialize() -> void:
	var combat = fixture("asteriated_ruby")
	for i in range(300):
		combat.enemies[0].pos = Vector2(at)+Vector2(.5,.5)
		combat.tick(1.0/30.0)
	check(is_equal_approx(1000000.0-float(combat.enemies[0].hp),800.0),"0.25-second aura delivers forty ticks in ten seconds at 30 Hz")
	combat = fixture("aquamarine")
	var count = {"shots":0}
	combat.shot.connect(func(_a,_b,_c): count.shots += 1)
	for i in range(900):
		combat.enemies[0].pos = Vector2(at)+Vector2(.5,.5)
		combat.tick(1.0/30.0)
	check(count.shots == 90,"Aquamarine's one-third-second attack rate stays accurate over thirty seconds")
	combat = fixture("aquamarine")
	combat.run.board.cells[Vector2i(11,10)] = {"kind":"opal","tier":1,"fresh":false,"priority":"First"}
	count = {"shots":0}
	combat.shot.connect(func(from,_b,_c):
		if from == Vector2(at)+Vector2(.5,.5):
			count.shots += 1
	)
	for i in range(900):
		combat.enemies[0].pos = Vector2(at)+Vector2(.5,.5)
		combat.tick(1.0/30.0)
	check(count.shots == 96,"Opal-supported interval that is not divisible by the fixed step retains its true frequency")
	combat = fixture("sapphire")
	for i in range(900):
		combat.enemies[0].pos = Vector2(100,100)
		combat.tick(1.0/30.0)
	var hp = float(combat.enemies[0].hp)
	combat.enemies[0].pos = Vector2(at)+Vector2(.5,.5)
	combat.tick(1.0/30.0)
	combat.enemies[0].pos = Vector2(at)+Vector2(.5,.5)
	combat.tick(1.0/30.0)
	check(is_equal_approx(hp-float(combat.enemies[0].hp),2.0),"thirty seconds without a target never creates an accumulated burst")
	check(float(combat.cooldowns[at]) > .9,"a first attack after idle starts a full interval")
	var frozen = combat.cooldowns.duplicate(true)
	combat.run.phase = "build"
	combat.tick(1.0)
	check(frozen == combat.cooldowns,"non-combat ticks cannot advance tower timers")
	print("CADENCE_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
