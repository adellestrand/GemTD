extends "res://tests/check_campaign.gd"

func run_checks() -> void:
	var combat = fixture("palayibabixi")
	var enemy: Dictionary = combat.enemies[0]
	enemy.base_armor = 10
	combat.refresh_defenses(enemy)
	check(enemy.armor == 0,"aura applies immediately on entry")
	enemy.pos += Vector2(50,0)
	combat.elapsed = .49
	combat.refresh_defenses(enemy)
	check(enemy.armor == 0,"aura properties linger for the documented half second after exit")
	combat.elapsed = .5
	combat.refresh_defenses(enemy)
	check(enemy.armor == 10,"aura expires exactly at its deadline")
	enemy.pos = Vector2(at)+Vector2(.5,.5)
	combat.elapsed = .6
	combat.refresh_defenses(enemy)
	check(enemy.armor == 0,"re-entry reapplies the same named aura without stacking it")
	combat = fixture("asteriated_ruby")
	enemy = combat.enemies[0]
	enemy.magic_resist = 0
	enemy.base_magic = 0
	var hp = float(enemy.hp)
	combat.update_enemy(enemy,0)
	combat.elapsed = .25
	combat.update_enemy(enemy,0)
	check(enemy.hp == hp-20,"damage aura starts after its first interval")
	enemy.pos += Vector2(50,0)
	combat.elapsed = .75
	combat.update_enemy(enemy,0)
	check(enemy.hp == hp-60,"due damage ticks include the final linger deadline even when a step crosses it")
	combat.elapsed = 2
	combat.update_enemy(enemy,0)
	check(enemy.hp == hp-60 and enemy.aura_memory.is_empty(),"expired aura stops ticking and releases its cached instance")
	enemy.pos = Vector2(at)+Vector2(.5,.5)
	combat.update_enemy(enemy,0)
	combat.elapsed = 2.1
	combat.update_enemy(enemy,0)
	check(enemy.hp == hp-60,"fresh aura entry cannot replay old timer debt")
	combat.elapsed = 2.25
	combat.update_enemy(enemy,0)
	check(enemy.hp == hp-80,"fresh aura begins a fresh damage interval")
	combat = fixture("diamond")
	enemy = combat.enemies[0]
	enemy.abilities.append("guai_jiaoxieguanghuan")
	check(combat.disarmed(at),"hostile disarm aura applies in range")
	enemy.pos += Vector2(50,0)
	combat.elapsed = .49
	check(combat.disarmed(at),"hostile disarm also retains a half-second exit window")
	combat.elapsed = .5
	check(not combat.disarmed(at),"hostile disarm expires after the exit window")
	combat = fixture("diamond",1,10)
	enemy = combat.enemies[0]
	enemy.abilities.append("guai_jiaoxieguanghuan")
	combat.towers[at].disabled = 5
	combat.elapsed = 4.7
	combat.tick(1.0/30.0)
	enemy.pos += Vector2(50,0)
	combat.elapsed = 5
	combat.tick(1.0/30.0)
	check(combat.disarmed(at),"hostile aura refreshes during an overlapping independent disarm, preserving its exit window")
	combat = fixture("diamond")
	enemy = combat.enemies[0]
	enemy.base_armor = 10
	combat.add_modifier(enemy,{"id":"vulnerability","duration":2,"properties":{"incoming_percent":20,"stone_gaze":true}},at)
	combat.attacker = at
	var before = float(enemy.hp)
	combat.deal(enemy,100,"physical")
	check(is_equal_approx(before-float(enemy.hp),150),"armor, physical petrification bonus and incoming amplification compose in the declared order")
	combat = fixture("diamond")
	enemy = combat.enemies[0]
	enemy.magic_immune = true
	before = float(enemy.hp)
	combat.deal(enemy,100,"magical")
	combat.deal(enemy,100,"pure")
	check(enemy.hp == before-100,"magic immunity blocks magical damage while pure damage remains valid")
	print("AURA_LIFECYCLE_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
