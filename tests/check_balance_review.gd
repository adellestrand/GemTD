extends "res://tests/check_campaign.gd"

# Balance review probe (docs/balance-review-2026-10-28.md). Read-only: it never
# changes rules or data. PASS lines confirm source behaviour that the engine
# already matches. DEVIATION lines measure the current engine against the
# Dota 2 GemTD source (.tools/reference, snapshot 2026-08-01) and are reported,
# not failed, because rule changes need the user's explicit approval.
var deviations = 0

func deviation(description: String, ours, source) -> void:
	deviations += 1
	print("DEVIATION: %s | ours=%s source=%s" % [description,str(ours),str(source)])

func lone_enemy(kind: String, tier: int = 1) -> GemCampaignCombat:
	var combat = fixture(kind,tier)
	var e: Dictionary = combat.enemies[0]
	e.base_magic = 0.0
	e.base_armor = 0.0
	e.magic_immune = false
	e.abilities = []
	e.defense_dirty = true
	return combat

func extra_enemies(combat: GemCampaignCombat, count: int) -> void:
	for i in range(count):
		combat.spawn_enemy()
		var e: Dictionary = combat.enemies.back()
		e.hp = 1000000000.0
		e.hp_max = 1000000000.0
		e.pos = Vector2(at)+Vector2(1.5+i*.2,.5)
		e.magic_immune = false
		e.abilities = []

# Advance delayed events and trap projectiles without moving enemies.
func step(combat: GemCampaignCombat, seconds: float) -> void:
	for i in range(int(round(seconds*30))):
		combat.elapsed += 1.0/30.0
		for e in combat.enemies: combat.update_enemy(e,1.0/30.0)
		var pending: Array[Dictionary] = combat.delayed.duplicate()
		combat.delayed.clear()
		for event in pending:
			if float(event.at) <= combat.elapsed+.000001: combat.execute_delayed(event)
			else: combat.delayed.append(event)
		combat.advance_sweeps(1.0/30.0)

func effect_of(kind: String, type: String) -> Dictionary:
	for effect in GemCampaignRules.actions({"kind":kind,"tier":1}):
		if effect.type == type: return effect.duplicate(true)
	return {}

func run_checks() -> void:
	var data: Dictionary = GemCatalog.DATA

	# Traps: source start_shiban_timer polls 128 units, cooldown 10 and casts at
	# level 5-players = 4 in solo; level-4 AbilityValues are used for every tier.
	var trap_ok = true
	for kind in data.specials:
		if not data.specials[kind].slab: continue
		var effect: Dictionary = GemCampaignRules.actions({"kind":kind,"tier":1})[0]
		trap_ok = trap_ok and float(effect.cooldown) == 10.0 and float(effect.trigger_radius) == 1.0
	check(trap_ok,"all 24 traps: 1-cell trigger and 10 s cooldown as start_shiban_timer")
	check(float(effect_of("youbushiban","slab").duration) == 6.0 and int(effect_of("youbushiban_jin","slab").count) == 64,"Entangle uses new_youbu_sub level 4 (6 s) and 1/8/64 targets")
	check(float(effect_of("suanwushiban_jin","slab").properties.armor) == -126.0,"Gold Acid uses level-4 armor reduction -126")
	check(int(effect_of("mabishiban_yin","slab").count) == 3 and float(effect_of("mabishiban_jin","slab").duration) == 3.0 and int(effect_of("mabishiban","slab").bounces) == 12,"Paralysis Cask2/Cask3 counts and sub-ability durations; 12 bounces at level 4")

	# Splash (jianshe1-6) hits every enemy in radius including the primary target.
	var combat = lone_enemy("baiyinqishi")
	extra_enemies(combat,1)
	var before = [float(combat.enemies[0].hp),float(combat.enemies[1].hp)]
	combat.on_hit(at,effect_of("baiyinqishi","splash"),combat.enemies[0],100.0)
	check(is_equal_approx(before[0]-float(combat.enemies[0].hp),50.0) and is_equal_approx(before[1]-float(combat.enemies[1].hp),50.0),"Silver Knight splash: 50% pure to primary and neighbour as jianshe3")

	# Poison with MODIFIER_ATTRIBUTE_MULTIPLE stacks per landed attack.
	combat = lone_enemy("jade")
	var poison = effect_of("jade","on_hit")
	combat.on_hit(at,poison,combat.enemies[0],10.0)
	combat.on_hit(at,poison,combat.enemies[0],10.0)
	check(combat.enemies[0].mods.size() == 2,"Jade poison stacks per attack (MULTIPLE)")

	# Non-MULTIPLE on-hit debuffs refresh instead of stacking.
	combat = lone_enemy("silver")
	var slow = effect_of("silver","on_hit")
	combat.on_hit(at,slow,combat.enemies[0],10.0)
	combat.on_hit(at,slow,combat.enemies[0],10.0)
	check(combat.enemies[0].mods.size() == 1,"Silver slow refreshes (no MULTIPLE)")

	# MVP: +10%/level, level 10 aura +100% to others within 290, cap +500.
	var cells = {at:{"kind":"diamond","tier":1,"mvp":10}}
	for i in range(1,7): cells[at+Vector2i(i%2,i/2)] = {"kind":"diamond","tier":1,"mvp":10}
	check(GemCampaignRules.mvp_bonus(cells[at],at,cells) == 500.0,"MVP bonus capped at +500% as DamageFilter")

	# --- Measured deviations ---------------------------------------------------
	# 1. Trial leak bands. Source spawn code: 51-59 -> 1+RandomInt(0,26), then +8
	#    per band up to 91-99 -> 1+RandomInt(0,58).
	var source_trial_max = {51:27,61:35,71:43,81:51,91:59}
	for wave in source_trial_max:
		var ours = int(data.waves[wave-1].leak_max)
		if ours != source_trial_max[wave]: deviation("trial wave %d max leak damage" % wave,ours,source_trial_max[wave])
		else: check(true,"trial leak band %d" % wave)

	# 2. Bloodstone chain against a lone target. chain.lua's repeat loop keeps the
	#    last popped (already hit) unit when no new one exists, so the source chain
	#    always performs Count=5 hits, ping-ponging on a single boss.
	combat = lone_enemy("jixueshi")
	var hits = [0]
	combat.ability_visual.connect(func(event): if event.type == "chain": hits[0] += 1)
	var chain = effect_of("jixueshi","chain")
	chain.erase("chance")
	combat.on_hit(at,chain,combat.enemies[0],10.0)
	for i in range(60):
		combat.enemies[0].pos = Vector2(at)+Vector2(.5,.5)
		combat.update_enemy(combat.enemies[0],1.0/30.0)
		combat.elapsed += 1.0/30.0
		var pending: Array[Dictionary] = combat.delayed.duplicate()
		combat.delayed.clear()
		for event in pending:
			if float(event.at) <= combat.elapsed+.000001: combat.execute_delayed(event)
			else: combat.delayed.append(event)
	if hits[0] != 5: deviation("Bloodstone/Sunstone chain hits on a lone target",hits[0],5)
	else: check(true,"Bloodstone chain lands 5 hits on a lone target like chain.lua")

	# 3. Torrent trap damage: source DelayedAction deals %AbilityDamage/2 magical
	#    (level 4: 300/2 = 150) together with the knock-up stun and slow.
	combat = lone_enemy("diamond")
	combat.run.board.cells.erase(at)
	combat.sync_towers()
	combat.run.board.slabs[at+Vector2i(1,0)] = "hongliushiban_jin"
	var hp = float(combat.enemies[0].hp)
	for i in range(75):
		combat.enemies[0].pos = Vector2(at)+Vector2(1.5,.5)
		combat.tick(1.0/30.0)
	var stunned = combat.enemies[0].get("current_properties",{}).get("stunned",false)
	check(stunned,"Gold Torrent stuns after the 1.6 s delay")
	var torrent_damage = hp-float(combat.enemies[0].hp)
	if not is_equal_approx(torrent_damage,150.0): deviation("Torrent trap magic damage per hit",torrent_damage,150)
	else: check(true,"Gold Torrent deals 150 magic impact damage once")

	# 4. Emerald Golem petrify count: gazeNew uses 5 + floor(MVP level / 2).
	combat = lone_enemy("feicuimoxiang")
	combat.run.board.cells[at].mvp = 10
	combat.sync_towers()
	extra_enemies(combat,11)
	var gaze = effect_of("feicuimoxiang","petrify")
	gaze.erase("chance")
	combat.on_hit(at,gaze,combat.enemies[0],10.0)
	var stoned = combat.enemies.filter(func(e): return e.mods.has("tower_shihua_new")).size()
	if stoned != 10: deviation("Emerald Golem petrified targets at MVP 10",stoned,10)
	else: check(true,"Emerald Golem petrifies 5 + MVP/2 = 10 targets at MVP 10")
	var nearest = combat.enemies.filter(func(e): return e.mods.has("tower_shihua_new"))
	check(nearest.all(func(e): return e.pos.x <= Vector2(at).x+1.5+8*.2+.001),"petrify picks the closest enemies first")

	# 5. Magic resistance stacking. Dota stacks magic resistance sources
	#    multiplicatively (1 - prod(1 - r)); the engine sums them.
	combat = lone_enemy("diamond")
	var e: Dictionary = combat.enemies[0]
	e.base_magic = .25
	e.mods["a"] = {"properties":{"magic_resist":-80.0},"until":1000.0,"source":at}
	e.mods["b"] = {"properties":{"magic_resist":-100.0},"until":1000.0,"source":at}
	combat.refresh_defenses(e)
	var multiplicative = 1.0-(1.0-.25)*(1.0+.8)*(1.0+1.0)
	if not is_equal_approx(float(e.magic_resist),multiplicative): deviation("magic resistance 25% base with -80% and -100% (damage factor)",snappedf(1.0-float(e.magic_resist),.01),snappedf(1.0-multiplicative,.01))
	else: check(true,"magic resistance stacks multiplicatively (damage factor 2.7)")

	# 6. Success streak: WinStreakAdjust moves the encounter size one step per
	#    call; the engine applies every 50-point step at once.
	var state = GemRun.new(1)
	state.adjust_streak(-177.0)
	if state.enemy_count != 9: deviation("enemy count right after a -177 streak leak (from 10)",state.enemy_count,9)
	else: check(true,"streak moves the encounter size one step per adjustment")

	# 7. Several Sea Jewels: TriggerShiban rolls RandomInt(1,100*count) <= p, so
	#    with two Sea Jewels and a bronze trap: 15% + 85% * 15/200 = 21.375%.
	combat = lone_enemy("haibao")
	combat.run.board.cells[at+Vector2i(0,1)] = gem("haibao")
	combat.sync_towers()
	var slab = at+Vector2i(1,0)
	combat.run.board.slabs[slab] = "youbushiban"
	combat.enemies[0].pos = Vector2(slab)+Vector2(.5,.5)
	var echoes = 0
	for i in range(4000):
		combat.aura_clocks.erase("slab/"+str(slab))
		combat.delayed.clear()
		combat.process_slab(slab,"youbushiban")
		for event in combat.delayed:
			if event.type == "chain" and event.effect.type == "slab_echo": echoes += 1
	var rate = echoes/4000.0
	if absf(rate-.21375) > .03: deviation("chain frost rate with two Sea Jewels and a bronze trap",rate,.21375)
	else: check(true,"two Sea Jewels: p then p/2 (measured %.3f)" % rate)

	# 8. Chain frost mini-stun only on the first target; bounces reach magic-immune enemies.
	combat = lone_enemy("haibao")
	extra_enemies(combat,1)
	combat.enemies[1].magic_immune = true
	var frost = effect_of("haibao","slab_echo")
	combat.delayed.append({"at":combat.elapsed,"type":"chain","source":at,"target":combat.enemies[0],"effect":frost,"left":2,"visited":[]})
	step(combat,.5)
	check(not combat.enemies[1].mods.has("tower_chain_frost_stun") and combat.enemies[1].mods.has("tower_chain_frost"),"chain frost bounce slows a magic-immune enemy without a second mini-stun")

	# 9. Venom is a moving LinearProjectile: an enemy ahead on the line is hit
	#    when the projectile arrives, not at the trigger.
	combat = lone_enemy("diamond")
	combat.run.board.cells.erase(at)
	combat.sync_towers()
	combat.run.board.slabs[slab] = "zhangqishiban_jin"
	combat.enemies[0].pos = Vector2(slab)+Vector2(1.0,.5)
	combat.process_slab(slab,"zhangqishiban_jin")
	extra_enemies(combat,1)
	combat.enemies[1].pos = Vector2(slab)+Vector2(6.5,.5)
	step(combat,1.0)
	var early = combat.enemies[1].mods.has("modifier_venomous_gale_debuff_datadriven")
	step(combat,3.0)
	check(not early and combat.enemies[1].mods.has("modifier_venomous_gale_debuff_datadriven"),"Gold Venom reaches an enemy 6 cells ahead after about 3.9 s")

	# 10. Entangle: dummy cast after 0.05 s plus RandomInt(1,50)/100 s per target.
	combat = lone_enemy("diamond")
	combat.run.board.cells.erase(at)
	combat.sync_towers()
	combat.run.board.slabs[slab] = "youbushiban"
	combat.enemies[0].pos = Vector2(slab)+Vector2(.5,.5)
	combat.process_slab(slab,"youbushiban")
	step(combat,.08)
	var stunned_early = combat.enemies[0].mods.has("new_youbu1")
	step(combat,.6)
	check(not stunned_early and combat.enemies[0].mods.has("new_youbu1"),"Entangle stun lands after the source cast and timer delays")

	# 11. chain.lua stops when the previous target died.
	combat = lone_enemy("jixueshi")
	extra_enemies(combat,1)
	combat.enemies[0].hp = 1.0
	var bolt = effect_of("jixueshi","chain")
	bolt.erase("chance")
	var survivor = float(combat.enemies[1].hp)
	combat.on_hit(at,bolt,combat.enemies[0],10.0)
	step(combat,1.5)
	check(combat.enemies[0].dead and float(combat.enemies[1].hp) == survivor,"a kill ends the Bloodstone chain like ShanDian")

	print("BALANCE_REVIEW_CHECK_%s checks=%d failures=%d deviations=%d" % ["OK" if failures == 0 else "FAILED",checks,failures,deviations])
	quit(1 if failures else 0)
