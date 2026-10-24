class_name GemCombat
extends RefCounted

signal shot(from: Vector2, to: Vector2, color: Color)
signal damaged(enemy_id: int, position: Vector2, amount: float, damage_type: String, lethal: bool)
signal evaded(enemy_id: int, position: Vector2)
signal escaped(position: Vector2, boss: bool)
signal area_attack(position: Vector2, radius: float)
var run: GemRun
var enemies: Array[Dictionary] = []
var cooldowns: Dictionary = {}
var spawned = 0
var spawn_clock = 0.0
var elapsed = 0.0
var next_id = 0
var poison_id = 0
var ground: PackedVector2Array
var air: PackedVector2Array
var wave_data: Dictionary

func _init(state: GemRun) -> void:
	run = state

func start() -> void:
	enemies.clear()
	cooldowns.clear()
	spawned = 0
	spawn_clock = 0.0
	elapsed = 0.0
	ground = run.board.ground_route.duplicate()
	air = run.board.air_route.duplicate()
	wave_data = GemCatalog.wave(run.wave)

func spawn_enemy() -> void:
	var e: Dictionary = wave_data.duplicate(true)
	e.merge({"id": next_id, "hp_max": e.hp, "pos": air[0] if e.air else ground[0], "segment": 1, "travelled": 0.0, "slow": 0.0, "slows": {}, "armor_debuff": 0.0, "armor_debuffs": {}, "poisons": {}, "dead": false, "escaped": false})
	next_id += 1
	enemies.append(e)
	spawned += 1

func tick(dt: float) -> void:
	if run.phase != "combat":
		return
	elapsed += dt
	spawn_clock -= dt
	if spawned < int(wave_data.count) and spawn_clock <= 0:
		spawn_enemy()
		spawn_clock += float(wave_data.spawn_interval)
	for enemy in enemies:
		if enemy.dead or enemy.escaped:
			continue
		enemy.slow = sum_modifiers(enemy.slows)
		enemy.armor_debuff = sum_modifiers(enemy.armor_debuffs)
		for source in enemy.poisons.keys():
			var poison: Dictionary = enemy.poisons[source]
			# Include scheduled final ticks even when a fixed step crosses expiry.
			while float(poison.next) <= minf(elapsed,float(poison.until))+0.000001:
				deal(enemy, poison.damage, "magical")
				poison.next += float(poison.interval)
			if elapsed >= float(poison.until):
				enemy.poisons.erase(source)
		if enemy.dead:
			continue
		move_enemy(enemy, dt)
		if run.phase != "combat":
			return
	for p in run.board.cells:
		var gem: Dictionary = run.board.cells[p]
		if gem.kind == "stone":
			continue
		var stats = GemCatalog.stats(gem)
		cooldowns[p] = float(cooldowns.get(p, dt))-dt
		if cooldowns[p] > 0.000001:
			continue
		if gem.kind == "asteriated_ruby":
			var affected = false
			for enemy in enemies:
				if alive(enemy) and Vector2(p).distance_to(enemy.pos-Vector2(0.5,0.5)) <= float(GemCatalog.DATA.effects.asteriated_ruby.radius):
					deal(enemy, GemCatalog.DATA.effects.asteriated_ruby.damage, "magical")
					affected = true
			if affected:
				area_attack.emit(Vector2(p)+Vector2(.5,.5),float(GemCatalog.DATA.effects.asteriated_ruby.radius))
			cooldowns[p] += float(GemCatalog.DATA.effects.asteriated_ruby.interval)
			continue
		var targets = targets_for(p, gem, stats)
		if targets.is_empty():
			# Idle towers have no accumulated firing debt when a target arrives.
			cooldowns.erase(p)
			continue
		attack(p, gem, stats, targets[0])
		if gem.kind in ["topaz", "malachite"]:
			var secondary = targets.duplicate()
			secondary.erase(targets[0])
			var center = Vector2(p)+Vector2(0.5,0.5)
			secondary.sort_custom(func(a,b): return center.distance_squared_to(a.pos) < center.distance_squared_to(b.pos) if center.distance_squared_to(a.pos) != center.distance_squared_to(b.pos) else a.id < b.id)
			for other in secondary.slice(0,int(GemCatalog.DATA.effects[gem.kind].secondary_count)):
				# Reference split projectiles call ApplyDamage, not PerformAttack.
				shot.emit(center,other.pos,GemCatalog.color_of(gem))
				deal(other,float(stats.damage),"physical")
		# Keep the sub-step remainder instead of rounding every attack upward.
		cooldowns[p] += float(GemCatalog.attack_timing(gem,p,run.board.cells).interval)
	enemies = enemies.filter(func(e): return not e.dead and not e.escaped)
	if spawned == int(wave_data.count) and enemies.is_empty():
		run.finish_wave()

static func alive(e: Dictionary) -> bool:
	return not e.dead and not e.escaped

func move_enemy(e: Dictionary, dt: float) -> void:
	var route = air if e.air else ground
	var budget = maxf(float(e.speed)-float(e.slow)/128.0, 100.0/128.0)*dt
	while budget > 0 and int(e.segment) < route.size():
		var target = route[int(e.segment)]
		var distance: float = e.pos.distance_to(target)
		if distance <= budget:
			e.pos = target
			e.segment += 1
			e.travelled += distance
			budget -= distance
		else:
			e.pos = e.pos.move_toward(target, budget)
			e.travelled += budget
			budget = 0
	if int(e.segment) >= route.size():
		e.escaped = true
		prepare_escape(e)
		escaped.emit(e.pos,bool(e.boss))
		run.leaked(int(e.leak), bool(e.boss))

func prepare_escape(_enemy: Dictionary) -> void:
	pass

func targets_for(p: Vector2i, gem: Dictionary, stats: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var center = Vector2(p)+Vector2(0.5,0.5)
	for e in enemies:
		if alive(e) and (not e.air or stats.targets == "both") and center.distance_to(e.pos) <= float(stats.range):
			result.append(e)
	var priority: String = gem.priority
	result.sort_custom(func(a, b):
		match priority:
			"Last": return a.travelled < b.travelled if a.travelled != b.travelled else a.id < b.id
			"Strongest": return a.hp > b.hp if a.hp != b.hp else a.id < b.id
			"Nearest": return center.distance_squared_to(a.pos) < center.distance_squared_to(b.pos) if center.distance_squared_to(a.pos) != center.distance_squared_to(b.pos) else a.id < b.id
			_: return a.travelled > b.travelled if a.travelled != b.travelled else a.id < b.id
	)
	return result

func attack(p: Vector2i, gem: Dictionary, stats: Dictionary, enemy: Dictionary) -> void:
	var raw = float(stats.damage)
	var tier = int(stats.get("effect_tier",gem.tier))-1
	var hit = run.combat_rng.randf() >= float(enemy.evasion)
	shot.emit(Vector2(p)+Vector2(0.5,0.5), enemy.pos, GemCatalog.color_of(gem))
	if not hit:
		evaded.emit(int(enemy.id),enemy.pos)
		return
	deal(enemy, raw, "physical")
	match str(stats.get("effect_kind",gem.kind)):
		"sapphire", "silver":
			var effect: Dictionary = GemCatalog.DATA.effects[gem.kind]
			var slow = float(effect.slow[0 if gem.kind == "silver" else tier])
			if not enemy.get("magic_immune", false):
				# Same modifier refreshes; different reference modifier names coexist.
				var key = "slow_%d" % (1 if gem.kind == "silver" else tier)
				enemy.slows[key] = {"value": slow,"until":elapsed+GemCatalog.effect_value(effect,"duration",tier+1)}
				enemy.slow = sum_modifiers(enemy.slows)
		"amethyst":
			var effect: Dictionary = GemCatalog.DATA.effects.amethyst
			enemy.armor_debuffs[tier] = {"value":float(effect.armor_reduction[tier]),"until":elapsed+GemCatalog.effect_value(effect,"duration",tier+1)}
			enemy.armor_debuff = sum_modifiers(enemy.armor_debuffs)
		"emerald":
			if not enemy.get("magic_immune", false):
				var effect: Dictionary = GemCatalog.DATA.effects.emerald
				# The reference poison declares MODIFIER_ATTRIBUTE_MULTIPLE.
				enemy.poisons[poison_id] = {"damage": effect.damage[tier], "until": elapsed+GemCatalog.effect_value(effect,"duration",tier+1), "next": elapsed+float(effect.interval), "interval": float(effect.interval)}
				poison_id += 1
		"ruby":
			var effect: Dictionary = GemCatalog.DATA.effects.ruby
			area_attack.emit(enemy.pos,float(effect.radius[tier]))
			for other in enemies:
				if alive(other) and enemy.pos.distance_to(other.pos) <= float(effect.radius[tier]):
					deal(other, raw*float(effect.fraction[tier]), "pure")

func sum_modifiers(modifiers: Dictionary) -> float:
	var total = 0.0
	for key in modifiers.keys():
		if elapsed >= float(modifiers[key].until):
			modifiers.erase(key)
		else:
			total += float(modifiers[key].value)
	return total

func deal(enemy: Dictionary, raw: float, damage_type: String) -> void:
	if not alive(enemy):
		return
	var amount = GemDamage.resolve(raw, damage_type, enemy)
	enemy.hp -= amount
	if enemy.hp <= 0:
		enemy.dead = true
		run.killed(int(enemy.reward))
	if amount > 0:
		damaged.emit(int(enemy.id),enemy.pos,amount,damage_type,bool(enemy.dead))
