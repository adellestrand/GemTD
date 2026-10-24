extends SceneTree

var checks = 0
var failures = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)
	else:
		print("PASS: "+description)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var effects = GemEffects.new()
	var config = GemArt.config()
	var original = config.get("effects",{}).duplicate(true)
	config.effects = {"enabled":true,"max_events":6,"damage_numbers":false}
	for i in range(20):
		effects.shot(Vector2.ZERO,Vector2.ONE,Color.WHITE,"sapphire")
	check(effects.events.size() == 6,"effect storage stays bounded under rapid multishot")
	var frozen = effects.events.duplicate(true)
	effects.advance(0)
	check(effects.events == frozen and effects.clock == 0,"zero visual time preserves paused effects")
	effects.damaged(4,Vector2.ONE,2,"physical",false)
	effects.advance(1)
	check(effects.events.is_empty() and effects.flashes.is_empty(),"effects and enemy flashes expire without retaining dead IDs")
	config.effects.enabled = false
	effects.shot(Vector2.ZERO,Vector2.ONE,Color.WHITE,"ruby")
	effects.damaged(4,Vector2.ONE,2,"physical",false)
	check(effects.events.is_empty() and effects.flashes.is_empty(),"disabled effects allocate no events or hit flashes")
	config.effects.enabled = true
	effects.shot(Vector2.ZERO,Vector2.ONE,Color.WHITE,"ruby")
	effects.clear()
	check(effects.clock == 0 and effects.events.is_empty(),"restarting clears visual history")
	config.effects = original
	var motion = GemArt.enemy_motion("boar",2.0,1.0,0,false)
	check(motion == GemArt.enemy_motion("boar",2.0,20.0,0,false),"ground gait follows travelled distance rather than elapsed time")
	var old_motion = config.motion.duplicate(true)
	config.motion.enabled = false
	var still = GemArt.enemy_motion("blue_courier",10,10,0,true)
	check(still.scale == Vector2.ONE and still.rotation == 0 and still.offset.y < 0,"motion can be disabled while preserving flying height")
	config.motion = old_motion
	check_combat_events()
	check_observer_independence()
	print("PRESENTATION_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func check_combat_events() -> void:
	var state = GemRun.new(42)
	var combat = GemCombat.new(state)
	var reports: Array[Dictionary] = []
	combat.damaged.connect(func(id,pos,amount,type,lethal): reports.append({"id":id,"pos":pos,"amount":amount,"type":type,"lethal":lethal}))
	var enemy = GemCatalog.wave(1).duplicate(true)
	enemy.merge({"id":7,"pos":Vector2(3,4),"hp":3.0,"hp_max":3.0,"dead":false,"escaped":false,"armor":0.0})
	combat.deal(enemy,2,"physical")
	check(reports.size() == 1 and reports[0].amount == 2 and not reports[0].lethal,"hit event reports resolved damage and target position")
	combat.deal(enemy,2,"physical")
	combat.deal(enemy,2,"physical")
	check(reports.size() == 2 and reports[1].lethal and state.kills == 1,"lethal event occurs once and cannot award extra kills")
	var immune = enemy.duplicate(true)
	immune.merge({"dead":false,"hp":3.0,"magic_immune":true},true)
	combat.deal(immune,2,"magical")
	check(reports.size() == 2,"immune targets produce no damage flash event")
	var misses: Array[int] = []
	combat.evaded.connect(func(id,_pos): misses.append(id))
	immune.evasion = 1.0
	combat.attack(Vector2i.ZERO,{"kind":"sapphire","tier":1}, {"damage":2},immune)
	check(misses == [7] and reports.size() == 2,"evaded attack reports MISS without a damage event")

func check_observer_independence() -> void:
	var outcomes: Array[Dictionary] = []
	for observed in [false,true]:
		var state = GemRun.new(617)
		for p in [Vector2i(5,4),Vector2i(5,8),Vector2i(5,12),Vector2i(5,16),Vector2i(10,17)]:
			state.place(p)
		var combat = GemCombat.new(state)
		var effects = GemEffects.new()
		if observed:
			combat.damaged.connect(effects.damaged)
			combat.evaded.connect(effects.evaded)
			combat.escaped.connect(effects.escaped)
			combat.area_attack.connect(effects.area)
			combat.shot.connect(func(a,b,c): effects.shot(a,b,c,"sapphire"))
		state.combat_started.connect(combat.start)
		state.keep(Vector2i(5,4))
		for tick in range(18000):
			combat.tick(1.0/30.0)
			if observed:
				effects.advance(1.0/30.0)
			if state.phase != "combat":
				break
		check(state.phase != "combat","observed/unobserved combat completes")
		outcomes.append(state.snapshot())
	check(outcomes[0] == outcomes[1],"visual observers preserve combat outcome, rewards, RNG and next build snapshot")
