extends "res://tests/check_campaign.gd"

func run_checks() -> void:
	var combat = fixture("diamond",1,10)
	var enemy: Dictionary = combat.enemies[0]
	enemy.hp = 17.0
	combat.attacker = at
	combat.deal(enemy,100,"pure")
	var report = combat.audit.snapshot()
	check(report.totals.pure == 17 and report.totals.overkill == 83,"audit separates effective HP damage from overkill")
	check(report.top_sources[0].at == [10,10],"damage attribution retains a stable source cell")
	combat = fixture("diamond",1,10)
	enemy = combat.enemies[0]
	enemy.refraction = 1
	combat.attacker = at
	combat.deal(enemy,10,"physical")
	check(combat.audit.snapshot().totals.blocked == 1 and combat.audit.snapshot().totals.physical == 0,"refraction records one blocked event without invented damage")
	enemy.evasion = 1.0
	combat.attack(at,gem("diamond"),GemCatalog.stats(gem("diamond")),enemy)
	check(combat.audit.snapshot().totals.missed == 1 and combat.audit.snapshot().totals.launched == 1,"missed primary attack is distinct from a blocked damage event")
	combat.audit.observe(combat,1.0)
	check(combat.audit.snapshot().top_sources[0].boss_targetable_seconds == 1,"boss exposure counts targetable time in range")
	combat.towers[at].disabled = 10
	combat.audit.observe(combat,1.0)
	check(combat.audit.snapshot().top_sources[0].boss_disabled_seconds == 1,"time disabled inside targetable boss range is explicit")
	enemy.invisible = true
	combat.audit.observe(combat,1.0)
	check(combat.audit.snapshot().top_sources[0].boss_range_seconds == 3 and combat.audit.snapshot().top_sources[0].boss_targetable_seconds == 2,"invisible boss in range does not count as targetable without detection")
	combat = fixture("diamond",1,10)
	combat.enemies[0].abilities.append("guai_jiaoxieguanghuan")
	var tower_state = combat.towers.duplicate(true)
	combat.audit.observe(combat,1.0/30.0)
	check(combat.towers == tower_state,"diagnostic exposure sampling never refreshes hostile aura state on towers")
	var observed = fixture("diamond",3)
	var silent = fixture("diamond",3)
	silent.audit.enabled = false
	for i in range(300):
		observed.tick(1.0/30.0)
		silent.tick(1.0/30.0)
	check(observed.run.combat_rng.state == silent.run.combat_rng.state and observed.enemies[0].hp == silent.enemies[0].hp and observed.enemies[0].pos == silent.enemies[0].pos,"diagnostics preserve RNG, damage and movement over 300 real steps")
	check(silent.audit.snapshot().is_empty(),"audit can be disabled for comparison and profiling")
	combat = fixture("diamond",1,10)
	enemy = combat.enemies[0]
	enemy.pos = combat.ground[combat.ground.size()-1]-Vector2(.01,0)
	enemy.segment = combat.ground.size()-1
	combat.launch_projectile(at,gem("diamond"),GemCatalog.stats(gem("diamond")),enemy,1,1,true,false)
	var during_callback: Dictionary = {}
	var on_changed = func():
		if combat.run.phase == "lost": during_callback.merge(combat.audit.snapshot(),true)
	combat.run.changed.connect(on_changed)
	combat.tick(1.0/30.0)
	check(during_callback == combat.audit.snapshot() and during_callback.totals.discarded == 1,"UI defeat callbacks see final discarded-shot counters, identical to independent replay")
	combat.run.changed.disconnect(on_changed)
	var cached = preload("res://tools/late_fixture.gd").setup(99,64)
	var uncached = preload("res://tools/late_fixture.gd").setup(99,64)
	uncached.cache_aura_queries = false
	for model in [cached,uncached]:
		model.wave_data.count = 32
		for i in range(32): model.spawn_enemy()
	for i in range(120):
		cached.tick(1.0/30.0)
		uncached.tick(1.0/30.0)
	check(cached.run.combat_rng.state == uncached.run.combat_rng.state and cached.audit.snapshot() == uncached.audit.snapshot(),"within-step aura cache preserves dense combat RNG and every diagnostic counter")
	print("COMBAT_AUDIT_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
