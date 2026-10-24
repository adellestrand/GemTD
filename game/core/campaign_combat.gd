class_name GemCampaignCombat
extends GemCombat

signal projectile_launched(from: Vector2, to: Vector2, color: Color)
# Resolved presentation notifications; listeners never determine combat outcomes.
signal ability_visual(event: Dictionary)
var projectiles: Array[Dictionary] = []
var towers: Dictionary = {}
var statuses: Dictionary = {}
var aura_clocks: Dictionary = {}
var delayed: Array[Dictionary] = []
var fields: Array[Dictionary] = []
var attacker = Vector2i(-1,-1)
var serial = 0
var wave_damage: Dictionary = {}
var last_mvp = ""
var audit = GemCombatAudit.new()
var audit_history: Dictionary = {}
var enemy_aura_sources: Array[Dictionary] = []
var armor_sources: Array[Dictionary] = []
var disarm_sources: Array[Dictionary] = []
var detection_sources: Array[Dictionary] = []
var stepping = false
var cache_aura_queries = true
var aura_revision = 0
var known_tower_revision = -1
var berserk = false

func start() -> void:
	super.start()
	towers.clear()
	enemy_aura_sources.clear()
	detection_sources.clear()
	projectiles.clear()
	statuses.clear()
	aura_clocks.clear()
	delayed.clear()
	fields.clear()
	wave_damage.clear()
	last_mvp = ""
	berserk = false
	wave_data = wave_data.duplicate(true)
	select_wave_variant()
	audit.reset(run,air if wave_data.air else ground)
	if not wave_data.boss: wave_data.count = run.enemy_count
	sync_towers()

func select_wave_variant() -> void:
	var base = (run.wave-1)%50+1
	var options: Array = GemCatalog.DATA.wave_alternatives.get(str(base),[])
	if not run.wave_choices.has(str(base)):
		var chosen: String = wave_data.source_id
		if not options.is_empty() and run.wave <= 50:
			if base % 10 != 0:
				if run.combat_rng.randi_range(1,2) == 1: chosen = options[0].source_id
			elif base == 20:
				var day = int(run.reference_calendar.day)
				var days = [31,28,31,30,31,30,31,31,30,31,30,31][int(run.reference_calendar.month)-1]
				if day < days and (run.combat_rng.randi_range(1,100) > 90 or day > 20): chosen = options[0].source_id
			elif base in [30,40]:
				if run.combat_rng.randi_range(1,100) > 90: chosen = options[0].source_id
			elif base == 50:
				if run.combat_rng.randi_range(1,100) > 80: chosen = options[0].source_id
				if run.combat_rng.randi_range(1,100) > 90: chosen = options[1].source_id
		run.wave_choices[str(base)] = chosen
	for option in options:
		if option.source_id == run.wave_choices[str(base)]:
			for key in ["name","source_id","hp","speed","armor","magic_resist","air","ancient","abilities","variants"]: wave_data[key] = option[key].duplicate(true) if option[key] is Array else option[key]

func sync_towers() -> void:
	var previous = towers
	towers = {}
	enemy_aura_sources.clear()
	detection_sources.clear()
	var replaced: Array = []
	for p in previous:
		if not run.board.cells.has(p) or not is_same(previous[p].get("gem_ref",{}),run.board.cells[p]):
			replaced.append(p)
			cooldowns.erase(p)
			wave_damage.erase(p)
	for projectile in projectiles.duplicate():
		if projectile.source in replaced:
			audit.impact(projectile.source,"discarded")
			projectiles.erase(projectile)
	for p in run.board.cells:
		var gem: Dictionary = run.board.cells[p]
		if gem.kind != "stone":
			var support = GemCampaignRules.support(p,run.board.cells)
			var innate = float(GemCampaignRules.passive(gem).get("attack_speed",0))
			towers[p] = {"actions":GemCampaignRules.actions(gem),"stats":GemCatalog.stats(gem),"support":support,"disabled":0.0,"buffs":{},"range":float(GemCatalog.stats(gem).range)+float(support.get("range_bonus",0))/128.0,"interval":float(GemCampaignRules.timing_from_bonus(float(GemCatalog.stats(gem).interval),innate+float(support.get("attack_speed",0))).interval)}
			towers[p].gem_ref = gem
			if previous.has(p) and p not in replaced:
				for key in ["disabled","buffs","hostile_disarm_until"]:
					if previous[p].has(key): towers[p][key] = previous[p][key]
			if not audit.rows.has(p): audit.add_source(p,GemCatalog.title(gem))
			elif p in replaced: audit.rows[p].name += " → "+GemCatalog.title(gem)
			for action in towers[p].actions:
				if action.type == "enemy_aura": enemy_aura_sources.append({"source":p,"effect":action})
				if action.type == "support" and action.properties.get("true_sight",false): detection_sources.append({"pos":Vector2(p)+Vector2(.5,.5),"radius":action.radius})
			towers[p].mvp_bonus = GemCampaignRules.mvp_bonus(gem,p,run.board.cells)
	known_tower_revision = run.tower_revision
	aura_revision += 1
	for e in enemies: e.defense_dirty = true

func spawn_enemy() -> void:
	super.spawn_enemy()
	var e: Dictionary = enemies.back()
	if not e.variants.is_empty() and run.combat_rng.randi_range(1,100) > 50:
		var variant: Dictionary = e.variants[0]
		for key in ["source_id","name","hp","speed","armor","magic_resist","air","abilities","ancient"]:
			e[key] = variant[key]
	var hp = float(e.hp)
	if e.trial:
		if e.air: hp /= 3.0
		for i in range(2):
			var ability: String = GemCatalog.DATA.trial_pool[run.combat_rng.randi_range(0,GemCatalog.DATA.trial_pool.size()-1)]
			if ability == "enemy_momian": hp /= 5.0
			if ability == "enemy_wumian": hp /= 3.0
			if ability not in e.abilities: e.abilities.append(ability)
		hp = 999999999.0 if hp > 10000 else hp*100000.0
		e.speed *= 1.8
	e.hp = hp
	e.hp_max = hp
	if e.boss and audit.enabled: audit.boss = e
	e.leak = run.combat_rng.randi_range(int(e.leak),int(e.leak_max))
	e.merge({"base_armor":e.armor,"base_magic":e.magic_resist,"mods":{},"ability_clock":0.0,"refraction":0,"refraction_until":0.0,"refraction_ready":0.0,"blink_ready":0.0,"wind_until":0.0,"checkpoint":1,"cleanse_damage":0.0,"last_damage":0.0,"defense_dirty":true})
	e.evasion = .5 if "guai_shanbi" in e.abilities else 0.0
	e.magic_immune = berserk or "enemy_momian" in e.abilities
	e.physical_multiplier = .25 if "enemy_wumian" in e.abilities else 1.0
	e.invisible = "riki_permanent_invisibility" in e.abilities

func tick(dt: float) -> void:
	if run.phase == "intermission":
		run.trial_wait = maxf(0,run.trial_wait-dt)
		if run.trial_wait <= .000001:
			run.trial_wait = 0.0
			run.begin_combat()
		return
	if run.phase != "combat": return
	if run.tower_revision != known_tower_revision: sync_towers()
	stepping = true
	aura_revision += 1
	elapsed += dt
	if not berserk and elapsed > float(GemCatalog.DATA.mechanics.berserk_seconds)+.000001:
		berserk = true
		for e in enemies:
			e.magic_immune = true
			e.defense_dirty = true
		run.message = "BERSERK: enemies gain +100% movement speed and magic immunity."
		run.changed.emit()
	spawn_clock -= dt
	if spawned < int(wave_data.count) and spawn_clock <= 0:
		spawn_enemy()
		spawn_clock += float(wave_data.spawn_interval)
	armor_sources.assign(enemies.filter(func(e): return "enemy_high_armor" in e.abilities))
	disarm_sources.assign(enemies.filter(func(e): return "guai_jiaoxieguanghuan" in e.abilities))
	var pending = delayed
	delayed = []
	for event in pending:
		if float(event.at) <= elapsed+0.000001: execute_delayed(event)
		else: delayed.append(event)
	fields = fields.filter(func(f): return float(f.until) > elapsed)
	for e in enemies:
		if not alive(e): continue
		update_enemy(e,dt)
		if not alive(e): continue
		move_enemy(e,dt)
		if run.phase != "combat":
			discard_projectiles()
			audit_history[run.wave] = audit.snapshot()
			stepping = false
			return
	aura_revision += 1
	audit.observe(self,dt)
	advance_projectiles(dt)
	for p in towers:
		var tower: Dictionary = towers[p]
		var gem: Dictionary = run.board.cells[p]
		var hostile_disabled = disarmed(p)
		attacker = p
		if tower.stats.get("slab",false): continue
		if float(tower.stats.damage) <= 0 or float(tower.disabled) > elapsed: continue
		if hostile_disabled and not tower.support.get("magic_immune",false): continue
		cooldowns[p] = float(cooldowns.get(p,dt))-dt
		if float(cooldowns[p]) > .000001: continue
		var stats: Dictionary = tower.stats.duplicate()
		stats.range = tower.range
		var targets = targets_for(p,gem,stats)
		if targets.is_empty():
			cooldowns.erase(p)
			continue
		attack(p,gem,stats,targets[0],targets)
		cooldowns[p] += float(tower.interval)
	for p in run.board.slabs:
		process_slab(p,run.board.slabs[p])
	enemies = enemies.filter(func(e): return alive(e))
	if spawned == int(wave_data.count) and enemies.is_empty():
		discard_projectiles()
		audit_history[run.wave] = audit.snapshot()
		award_mvp()
		run.finish_wave()
	stepping = false

func prepare_escape(enemy: Dictionary) -> void:
	# Finalize counters before run.leaked emits UI/save/report callbacks.
	if enemy.boss or run.lives <= int(enemy.leak): discard_projectiles()

func discard_projectiles() -> void:
	for projectile in projectiles: audit.impact(projectile.source,"discarded")
	projectiles.clear()

func award_mvp() -> void:
	if run.wave > 50: return
	var best = Vector2i(-1,-1)
	var most_damage = 0.0
	for p in wave_damage:
		if run.board.cells.has(p) and int(run.board.cells[p].get("mvp",0)) < 10 and float(wave_damage[p]) > most_damage:
			best = p
			most_damage = float(wave_damage[p])
	if best != Vector2i(-1,-1):
		run.board.cells[best].mvp = mini(10,int(run.board.cells[best].get("mvp",0))+1)
		last_mvp = "%s · MVP %d" % [GemCatalog.title(run.board.cells[best]),int(run.board.cells[best].mvp)]

func aura_matches(effect: Dictionary, p: Vector2i, e: Dictionary) -> bool:
	return alive(e) and Vector2(p).distance_to(e.pos-Vector2(.5,.5)) <= float(effect.radius) and (not effect.get("not_ancient",false) or not e.ancient) and (not e.magic_immune or effect.get("magic_targets",false))

func refresh_aura_memory(e: Dictionary) -> void:
	if stepping and cache_aura_queries and int(e.get("aura_revision",-1)) == aura_revision and e.get("aura_position",Vector2.INF) == e.pos: return
	e.aura_revision = aura_revision
	e.aura_position = e.pos
	var memory: Dictionary = e.get("aura_memory",{})
	for emitter in enemy_aura_sources:
		var p: Vector2i = emitter.source
		var effect: Dictionary = emitter.effect
		if not aura_matches(effect,p,e): continue
		var key = str(effect.id)+(str(p) if effect.get("stacks",false) else "")
		if not memory.has(key) or float(memory[key].until) < elapsed-.000001:
			memory[key] = {"source":p,"effect":effect,"next":elapsed+float(effect.get("interval",1))}
		memory[key].until = elapsed+float(effect.get("linger",GemCatalog.DATA.combat.default_aura_linger))
	for other in (armor_sources if stepping else enemies):
		if alive(other) and "enemy_high_armor" in other.abilities and e.pos.distance_to(other.pos) <= 500.0/128.0:
			memory["enemy_armor/"+str(other.id)] = {"source":Vector2i(-1,-1),"effect":{"properties":{"armor":4}},"until":elapsed+float(GemCatalog.DATA.combat.default_aura_linger)}
	e.aura_memory = memory
	var properties: Dictionary = {}
	for aura in memory.values():
		if float(aura.until) > elapsed: GemCampaignRules.merge_properties(properties,aura.effect.properties)
	e.aura_properties = properties

func enemy_properties(e: Dictionary) -> Dictionary:
	refresh_aura_memory(e)
	var result: Dictionary = e.aura_properties.duplicate()
	if berserk: result.move_percent = float(result.get("move_percent",0))+float(GemCatalog.DATA.mechanics.berserk_move_percent)
	for key in e.mods.keys():
		var mod: Dictionary = e.mods[key]
		if float(mod.until) <= elapsed:
			e.mods.erase(key)
		else:
			GemCampaignRules.merge_properties(result,mod.properties)
	var named_fields: Dictionary = {}
	for field in fields:
		if e.pos.distance_to(field.pos) <= float(field.radius) and (not e.magic_immune or field.get("magic_targets",false)):
			named_fields[field.id] = field.properties
	for properties in named_fields.values(): GemCampaignRules.merge_properties(result,properties)
	return result

func update_enemy(e: Dictionary, dt: float) -> void:
	# Resolve due final ticks before expiring a modifier on this fixed step.
	for key in e.mods.keys():
		if not e.mods.has(key): continue
		var mod: Dictionary = e.mods[key]
		if mod.has("damage"):
			while e.mods.has(key) and float(mod.next) <= minf(elapsed,float(mod.until))+.000001:
				attacker = mod.source
				deal_visual(e,float(mod.damage),mod.damage_type,"dot",mod)
				mod.next += float(mod.interval)
	refresh_defenses(e)
	for key in e.aura_memory.keys():
		var aura: Dictionary = e.aura_memory[key]
		var effect: Dictionary = aura.effect
		if effect.has("damage"):
			while alive(e) and float(aura.next) <= minf(elapsed,float(aura.until))+.000001:
				attacker = aura.source
				deal_visual(e,float(effect.damage),effect.damage_type,"aura",effect)
				aura.next += float(effect.interval)
		if float(aura.until) <= elapsed: e.aura_memory.erase(key)
	var properties: Dictionary = e.current_properties
	if not alive(e): return
	if "enemy_recharge" in e.abilities and not properties.get("no_healing",false): e.hp = minf(e.hp_max,float(e.hp)+float(e.hp_max)*.003*dt)
	if elapsed-float(e.last_damage) > 10: e.cleanse_damage = 0.0
	if elapsed >= float(e.refraction_until): e.refraction = 0

func refresh_defenses(e: Dictionary) -> void:
	var properties = enemy_properties(e)
	e.current_properties = properties
	e.armor = float(e.base_armor)+float(properties.get("armor",0))
	e.magic_resist = float(e.base_magic)+float(properties.get("magic_resist",0))/100.0
	e.armor_debuff = 0.0
	e.incoming_multiplier = maxf(0,1.0+float(properties.get("incoming_percent",0))/100.0)
	e.stone_gaze = properties.get("stone_gaze",false)
	e.defense_dirty = false

func move_enemy(e: Dictionary, dt: float) -> void:
	var props: Dictionary = e.get("current_properties",{})
	if props.get("stunned",false) or props.get("stone_gaze",false): return
	var original = float(e.speed)
	var wind = 50.0 if float(e.wind_until) > elapsed else 0.0
	e.speed = GemCampaignRules.movement_speed(original,props,wind)
	e.slow = 0.0
	super.move_enemy(e,dt)
	e.speed = original
	e.defense_dirty = true
	if not alive(e): return
	var checkpoint_index = int(e.checkpoint)
	if checkpoint_index < run.board.checkpoints.size() and e.pos.distance_to(Vector2(run.board.checkpoints[checkpoint_index])+Vector2(.5,.5)) < float(GemCatalog.DATA.combat.checkpoint_radius):
		e.checkpoint += 1
		if int(e.checkpoint) <= 6: run.adjust_streak(-float(e.leak)*[.02,0,.05,.10,.20,.40][int(e.checkpoint)-1])
		if "enemy_thief" in e.abilities: run.gold = floori(run.gold*.99)
		if "enemy_jili" in e.abilities and not props.get("no_healing",false): e.hp = minf(e.hp_max,float(e.hp)+floorf(float(e.hp_max)*(.1 if e.air else .2)))
	e.ability_clock = float(e.ability_clock)-dt
	if float(e.ability_clock) > 0 or int(e.segment) < 2: return
	e.ability_clock += .1
	if "enemy_zheguang" in e.abilities and int(e.refraction) == 0 and elapsed >= float(e.refraction_ready) and run.combat_rng.randf() < .2:
		e.refraction = 7
		e.refraction_until = elapsed+60
		e.refraction_ready = elapsed+5
	elif "enemy_shanshuo" in e.abilities and elapsed >= float(e.blink_ready) and run.combat_rng.randf() < .1:
		var route = air if e.air else ground
		blink_forward(e,route)
		e.blink_ready = elapsed+12
	elif "runrunrun" in e.abilities and elapsed >= float(e.wind_until) and run.combat_rng.randf() < .2:
		e.wind_until = elapsed+20

func blink_forward(e: Dictionary, route: PackedVector2Array) -> void:
	# Bound travel in world distance even on an air route with only seven
	# vertices; one air vertex must never mean a whole checkpoint leg blink.
	var budget = 925.0/128.0
	while budget > 0 and int(e.segment) < route.size():
		var target = route[int(e.segment)]
		var distance: float = e.pos.distance_to(target)
		var step = minf(budget,distance)
		e.pos = e.pos.move_toward(target,step)
		e.travelled += step
		budget -= step
		if step < distance: break
		e.segment += 1
		if run.board.checkpoints.has(Vector2i(target-Vector2(.5,.5))): break

func disarm_in_range(p: Vector2i) -> bool:
	for e in (disarm_sources if stepping else enemies):
		if alive(e) and "guai_jiaoxieguanghuan" in e.abilities and e.pos.distance_to(Vector2(p)+Vector2(.5,.5)) <= 150.0/128.0: return true
	return false

func disarmed(p: Vector2i) -> bool:
	if not towers.has(p): return false
	if disarm_in_range(p): towers[p].hostile_disarm_until = elapsed+float(GemCatalog.DATA.combat.default_aura_linger)
	return elapsed < float(towers[p].get("hostile_disarm_until",0))

func targets_for(p: Vector2i, gem: Dictionary, stats: Dictionary) -> Array[Dictionary]:
	var result = super.targets_for(p,gem,stats)
	return result.filter(func(e): return not e.get("invisible",false) or detected(e))

func detected(e: Dictionary) -> bool:
	for source in detection_sources:
		if e.pos.distance_squared_to(source.pos) <= float(source.radius)*float(source.radius): return true
	return false

func attack(p: Vector2i, gem: Dictionary, stats: Dictionary, enemy: Dictionary, candidates: Array = []) -> void:
	attacker = p
	var support: Dictionary = towers[p].support.duplicate()
	for key in towers[p].buffs.keys():
		var buff: Dictionary = towers[p].buffs[key]
		if float(buff.until) <= elapsed: towers[p].buffs.erase(key)
		else: GemCampaignRules.merge_properties(support,buff.properties)
	var raw = float(stats.damage)*(1.0+float(support.get("outgoing_percent",0))/100.0)
	var critical = raw
	for effect in towers[p].actions:
		if effect.type == "crit" and GemProcRandom.roll(run.combat_rng,run.board.cells[p],effect.random_model): critical *= float(effect.multiplier)
		if effect.type == "self_disarm" and GemProcRandom.roll(run.combat_rng,run.board.cells[p],effect.random_model): towers[p].disabled = elapsed+float(effect.duration)
	if "enemy_bukeqinfan" in enemy.abilities:
		var triggered = GemProcRandom.roll(run.combat_rng,enemy,"enemy_bukeqinfan")
		if triggered and not support.get("magic_immune",false): towers[p].disabled = elapsed+1
	launch_projectile(p,gem,stats,enemy,critical,raw,true,support.get("cannot_miss",false))
	for effect in towers[p].actions:
		if effect.type == "split":
			var nearby: Array = candidates.filter(func(e): return alive(e)) if not candidates.is_empty() else targets_for(p,gem,stats)
			nearby.erase(enemy)
			var center = Vector2(p)+Vector2(.5,.5)
			nearby.sort_custom(func(a,b): return a.pos.distance_squared_to(center) < b.pos.distance_squared_to(center))
			for other in nearby.slice(0,int(effect.count)):
				# The source split script uses non-dodgeable tracking projectiles
				# and ApplyDamage at impact; no primary attack procs on extras.
				launch_projectile(p,gem,stats,other,raw,raw,false,true)

func launch_projectile(p: Vector2i, gem: Dictionary, stats: Dictionary, enemy: Dictionary, damage: float, raw: float, primary: bool, cannot_miss: bool) -> void:
	var origin = Vector2(p)+Vector2(.5,.5)
	var projectile = {"source":p,"target":enemy,"pos":origin,"previous":origin,"origin":origin,
		"speed":float(stats.projectile_speed),"damage":damage,"raw":raw,"primary":primary,
		"cannot_miss":cannot_miss,"color":GemCatalog.color_of(gem),"kind":str(gem.kind)}
	audit.launched(p,primary)
	projectile_launched.emit(origin,enemy.pos,projectile.color)
	# Zero travel distance really is an immediate impact (also useful for
	# isolated on-hit fixtures). No off-board projectile advances on launch.
	if origin.is_equal_approx(enemy.pos): impact_projectile(projectile)
	else: projectiles.append(projectile)

func advance_projectiles(dt: float) -> void:
	var flying = projectiles
	projectiles = []
	for projectile in flying:
		var enemy: Dictionary = projectile.target
		if not alive(enemy):
			audit.impact(projectile.source,"discarded")
			continue
		projectile.previous = projectile.pos
		var distance: float = projectile.pos.distance_to(enemy.pos)
		var step = float(projectile.speed)*dt
		projectile.pos = projectile.pos.move_toward(enemy.pos,step)
		if distance <= step+0.000001: impact_projectile(projectile)
		else: projectiles.append(projectile)

func impact_projectile(projectile: Dictionary) -> void:
	var enemy: Dictionary = projectile.target
	if not alive(enemy): return
	attacker = projectile.source
	if not projectile.primary:
		audit.impact(attacker,"landed")
		deal_visual(enemy,float(projectile.damage),"physical","impact",{})
		return
	var hit = projectile.cannot_miss or run.combat_rng.randf() >= float(enemy.evasion)
	if hit:
		audit.impact(attacker,"landed")
		deal_visual(enemy,float(projectile.damage),"physical","critical" if float(projectile.damage) > float(projectile.raw) else "impact",{})
		# Landing effects may still splash nearby enemies after a lethal hit.
		for effect in towers[attacker].actions: on_hit(attacker,effect,enemy,float(projectile.raw))
	else:
		audit.impact(attacker,"missed")
		evaded.emit(int(enemy.id),enemy.pos)

func on_hit(p: Vector2i, effect: Dictionary, enemy: Dictionary, raw: float) -> void:
	# Attack-start PRD has already rolled at launch. Passive/support/split
	# definitions must not consume an unused second random draw at impact.
	if effect.type not in ["on_hit","stun","splash","burst","chain","shock","petrify"]: return
	if effect.has("chance") and run.combat_rng.randf() >= float(effect.chance): return
	match effect.type:
		"on_hit":
			for other in area(enemy.pos,float(effect.get("radius",0)),enemy):
				if not other.magic_immune or effect.get("magic_targets",false): add_modifier(other,effect,p)
		"stun":
			if not enemy.magic_immune: add_modifier(enemy,{"id":effect.id,"duration":effect.duration,"properties":{"stunned":true}},p)
		"splash","burst":
			for other in area(enemy.pos,float(effect.radius)):
				deal_visual(other,raw*float(effect.get("fraction",effect.get("multiplier",1))),effect.get("damage_type","pure"),"splash",effect)
			area_attack.emit(enemy.pos,float(effect.radius))
		"chain":
			delayed.append({"at":elapsed,"type":"chain","source":p,"target":enemy,"effect":effect,"left":int(effect.count),"visited":[]})
		"shock":
			deal_visual(enemy,float(effect.damage),"magical","shock",effect)
			var targets = area(enemy.pos,float(effect.radius))
			targets = targets.filter(func(e): return e.id != enemy.id and not e.magic_immune and (not e.invisible or detected(e)))
			targets.sort_custom(func(a,b): return a.pos.distance_squared_to(enemy.pos) > b.pos.distance_squared_to(enemy.pos))
			for other in targets.slice(0,int(effect.count)-1):
				shot.emit(Vector2(p)+Vector2(.5,.5),other.pos,GemCatalog.color_of(run.board.cells[p]))
				deal_visual(other,float(effect.damage),"magical","shock",effect)
		"petrify":
			var key = str(p)+"/gaze"
			if elapsed >= float(aura_clocks.get(key,0)):
				aura_clocks[key] = elapsed+float(effect.cooldown)
				var count = 0
				for other in area(Vector2(p)+Vector2(.5,.5),float(effect.radius)):
					add_modifier(other,{"id":effect.id,"duration":effect.duration,"properties":{"stone_gaze":true}},p)
					count += 1
					if count >= int(effect.count): break

func area(center: Vector2, radius: float, primary: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e in enemies:
		if alive(e) and (e == primary or (radius > 0 and center.distance_to(e.pos) <= radius)): result.append(e)
	return result

func add_modifier(e: Dictionary, effect: Dictionary, p: Vector2i) -> void:
	var key = str(effect.get("modifier_id",effect.id))
	if effect.get("multiple",false):
		serial += 1
		key += str(serial)
	var value = {"properties":effect.get("properties",{}).duplicate(),"until":elapsed+float(effect.duration),"source":p}
	if effect.has("damage"): value.merge({"damage":effect.damage,"damage_type":effect.damage_type,"interval":effect.interval,"next":elapsed+float(effect.interval)})
	e.mods[key] = value
	e.defense_dirty = true
	ability_visual.emit({"type":"modifier","source":p,"pos":e.pos,"target":int(e.id),"effect":effect.duplicate(true)})

func execute_delayed(event: Dictionary) -> void:
	attacker = event.source
	if event.type == "modifier":
		for e in area(event.pos,float(event.effect.radius)):
			if not e.magic_immune or event.effect.get("magic_targets",false):
				add_modifier(e,event.effect,event.source)
				if event.effect.has("stun"): add_modifier(e,{"id":event.effect.id+"_stun","duration":event.effect.stun,"properties":{"stunned":true}},event.source)
		return
	if event.type != "chain": return
	var target: Dictionary = event.target
	var effect: Dictionary = event.effect
	if alive(target):
		deal_visual(target,float(effect.get("damage",0)),"magical","chain",effect,event.get("visual_from",Vector2(event.source)+Vector2(.5,.5)))
		if effect.get("mode","") == "cask": add_modifier(target,{"id":effect.id,"duration":effect.duration,"properties":{"stunned":true}},event.source)
		if effect.type == "slab_echo":
			add_modifier(target,{"id":effect.id,"duration":effect.duration,"properties":effect.properties},event.source)
			add_modifier(target,{"id":effect.id+"_stun","duration":effect.stun,"properties":{"stunned":true}},event.source)
		event.visited.append(target.id)
	event.left -= 1
	if int(event.left) <= 0: return
	var candidates = area(target.pos,float(effect.get("jump_radius",effect.get("radius",0))))
	var repeating = effect.type == "slab_echo" or effect.get("mode","") == "cask"
	candidates = candidates.filter(func(e): return (e.id != target.id if repeating else e.id not in event.visited) and not e.magic_immune and (not e.invisible or detected(e)))
	if candidates.is_empty(): return
	candidates.sort_custom(func(a,b): return a.pos.distance_squared_to(target.pos) < b.pos.distance_squared_to(target.pos))
	event.target = candidates[0]
	event.visual_from = target.pos
	event.at = elapsed+float(effect.get("interval",.2))
	delayed.append(event)

func process_slab(p: Vector2i, kind: String) -> void:
	var key = "slab/"+str(p)
	if elapsed < float(aura_clocks.get(key,0)): return
	var trigger = area(Vector2(p)+Vector2(.5,.5),1.0)
	if trigger.is_empty(): return
	var effect: Dictionary = GemCampaignRules.actions({"kind":kind,"tier":1})[0]
	aura_clocks[key] = elapsed+float(effect.cooldown)
	attacker = p
	var center: Vector2 = trigger[0].pos
	match effect.mode:
		"support":
			for q in towers:
				if Vector2(p).distance_to(Vector2(q)) <= float(effect.radius): towers[q].buffs[effect.get("modifier_id",effect.id)] = {"until":elapsed+float(effect.duration),"properties":effect.properties}
		"field": fields.append({"id":effect.get("modifier_id",effect.id),"pos":center,"radius":effect.radius,"properties":effect.properties,"until":elapsed+float(effect.duration),"magic_targets":effect.get("magic_targets",false)})
		"stun":
			var targets = area(center,float(effect.radius))
			for e in targets.slice(0,int(effect.count)): add_modifier(e,{"id":effect.id,"duration":effect.duration,"properties":{"stunned":true}},p)
		"cask":
			for e in area(center,float(effect.radius),trigger[0]).slice(0,int(effect.count)):
				delayed.append({"at":elapsed,"type":"chain","source":p,"target":e,"effect":effect,"left":int(effect.bounces),"visited":[]})
		"torrent","modifier": delayed.append({"at":elapsed+float(effect.get("delay",0)),"type":"modifier","source":p,"pos":center,"effect":effect})
		"line_slow":
			var direction = (center-(Vector2(p)+Vector2(.5,.5))).normalized()
			if direction == Vector2.ZERO: direction = Vector2.RIGHT
			for e in enemies:
				var delta: Vector2 = e.pos-(Vector2(p)+Vector2(.5,.5))
				if alive(e) and not e.magic_immune and delta.dot(direction) >= 0 and delta.dot(direction) <= float(effect.distance) and absf(delta.cross(direction)) <= float(effect.radius): add_modifier(e,effect,p)
	for q in towers:
		for echo in towers[q].actions:
			if echo.type == "slab_echo" and Vector2(q).distance_to(center-Vector2(.5,.5)) <= float(echo.radius) and run.combat_rng.randf() < [.15,.30,.60][int(effect.stage)-1]:
				delayed.append({"at":elapsed,"type":"chain","source":q,"target":trigger[0],"effect":echo,"left":int(echo.bounces),"visited":[]})
				return

func deal_visual(enemy: Dictionary, raw: float, damage_type: String, kind: String, effect: Dictionary, from: Vector2 = Vector2.INF) -> void:
	var before = float(enemy.hp)
	deal(enemy,raw,damage_type)
	var amount = before-float(enemy.hp)
	if amount > 0:
		ability_visual.emit({"type":kind,"source":attacker,"pos":enemy.pos,"target":int(enemy.id),"amount":amount,"effect":effect.duplicate(true),"from":Vector2(attacker)+Vector2(.5,.5) if from == Vector2.INF else from})

func deal(enemy: Dictionary, raw: float, damage_type: String) -> void:
	if not alive(enemy): return
	if enemy.get("defense_dirty",true): refresh_defenses(enemy)
	if towers.has(attacker) and float(towers[attacker].mvp_bonus) > 0:
		raw = floorf(raw*(1.0+float(towers[attacker].mvp_bonus)/100.0))
	if int(enemy.get("refraction",0)) > 0 and raw > 0:
		audit.impact(attacker,"blocked")
		enemy.refraction -= 1
		return
	var before = float(enemy.hp)
	var multiplier = float(enemy.get("physical_multiplier",1)) if damage_type == "physical" else 1.0
	if damage_type == "physical" and "mars_bulwark" in enemy.abilities and run.board.inside(attacker):
		var route = air if enemy.air else ground
		var heading = (route[mini(int(enemy.segment),route.size()-1)]-enemy.pos).normalized()
		var incoming = (Vector2(attacker)+Vector2(.5,.5)-enemy.pos).normalized()
		var dot = heading.dot(incoming)
		multiplier *= .3 if dot >= cos(PI/4) else .7 if dot >= 0 else 1.0
	super.deal(enemy,raw*multiplier,damage_type)
	if enemy.dead and enemy.boss: run.award_boss_discount()
	audit.damage(attacker,damage_type,before,float(enemy.hp))
	var amount = before-float(enemy.hp)
	if amount > 0 and towers.has(attacker): wave_damage[attacker] = float(wave_damage.get(attacker,0))+ceilf(amount)
	if amount > 0:
		enemy.last_damage = elapsed
		enemy.cleanse_damage = float(enemy.get("cleanse_damage",0))+amount
		if "tidehunter_blubber" in enemy.abilities and float(enemy.cleanse_damage) >= 80000:
			enemy.mods.clear()
			enemy.cleanse_damage = 0.0
			enemy.defense_dirty = true
	if enemy.dead and towers.has(attacker):
		if towers[attacker].support.get("greed",false) and run.combat_rng.randf() < .05:
			var total = int(enemy.reward)*10
			run.gold += total-int(enemy.reward)
		if towers[attacker].support.get("rejuvenation",false) and run.combat_rng.randf() < .03: run.lives += int(enemy.leak)
	if enemy.dead: run.adjust_streak(10.0 if enemy.boss else .75)
