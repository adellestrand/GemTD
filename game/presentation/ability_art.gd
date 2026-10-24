class_name GemAbilityArt
extends RefCounted

# Visual vocabulary derives from executed abilities, including stolen abilities.
# The editable catalogue chooses projectile appearance, never damage or timing.
static var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/ability-effects.json"))

static func style(effect: Dictionary) -> String:
	var properties: Dictionary = effect.get("properties",{})
	if effect.has("damage") or effect.get("type","") == "dot": return "poison" if effect.get("type","") != "enemy_aura" else "fire"
	if properties.get("stunned",false): return "stun"
	if properties.get("stone_gaze",false): return "stone"
	if properties.get("magic_immune",false): return "shield"
	if float(properties.get("move_percent",0)) < 0 or float(properties.get("move_constant",0)) < 0: return "frost"
	if float(properties.get("armor",0)) < 0 or float(properties.get("magic_resist",0)) < 0: return "fracture"
	return "support"

static func tint(kind: String) -> Color:
	return Color(profiles.colors.get(kind,"#e6cc7f"))

static func mvp_sources(cells: Dictionary, target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not cells.has(target) or cells[target].kind == "stone": return result
	for source in cells:
		if source != target and cells[source].kind != "stone" and int(cells[source].get("mvp",0)) == 10 and Vector2(source).distance_to(Vector2(target)) <= float(GemCatalog.DATA.mvp.max_level_aura_radius):
			result.append(source)
	return result

static func draw_mvp_fields(canvas: CanvasItem, cells: Dictionary, selected: Vector2i, origin: Vector2, unit: float, clock: float) -> void:
	if not GemCatalog.campaign(): return
	var gold = Color("ffd36b")
	var sources = mvp_sources(cells,selected)
	var selected_emitter = cells.has(selected) and int(cells[selected].get("mvp",0)) == 10
	for p in cells:
		if cells[p].kind == "stone" or int(cells[p].get("mvp",0)) != 10: continue
		var center: Vector2 = origin+(Vector2(p)+Vector2(.5,.5))*unit
		var radius = float(GemCatalog.DATA.mvp.max_level_aura_radius)*unit
		var emphasized = p == selected or p in sources
		for i in range(8):
			var angle = TAU*i/8.0+clock*.18
			canvas.draw_arc(center,radius,angle,angle+.30,6,Color(gold,.72 if emphasized else .22),maxf(1,unit*.045))
		if emphasized:
			canvas.draw_arc(center,radius,0,TAU,64,Color(gold,.42),1)
			for target in cells:
				if not selected_emitter and target != selected: continue
				if p == target or cells[target].kind == "stone" or Vector2(p).distance_to(Vector2(target)) > float(GemCatalog.DATA.mvp.max_level_aura_radius): continue
				var receiver: Vector2 = origin+(Vector2(target)+Vector2(.5,.5))*unit
				canvas.draw_arc(receiver,unit*.47,0,TAU,16,Color(gold,.8),maxf(1,unit*.05))

static func draw_mvp_crown(canvas: CanvasItem, center: Vector2, unit: float, gem: Dictionary) -> void:
	if int(gem.get("mvp",0)) != 10: return
	var p = center-Vector2(0,unit*.30)
	var r = unit*.15
	var points = PackedVector2Array([p+Vector2(-r,r*.4),p+Vector2(-r,-r*.6),p+Vector2(-r*.45,-r*.1),p+Vector2(0,-r*.85),p+Vector2(r*.45,-r*.1),p+Vector2(r,-r*.6),p+Vector2(r,r*.4)])
	canvas.draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[4],points[5],points[6],points[0]]),Color("332312"),maxf(2,unit*.09))
	canvas.draw_colored_polygon(points,Color("ffd36b"))

static func receive(fx: GemEffects, event: Dictionary, cells: Dictionary) -> void:
	if not bool(fx.settings().get("enabled",true)): return
	var effect: Dictionary = event.get("effect",{})
	var kind = str(event.type)
	var look = style(effect)
	if kind == "dot": look = "poison"
	if kind in ["chain","shock"]: look = "lightning"
	if kind == "critical": look = "critical"
	if kind == "impact": return # The ordinary damaged signal already supplies hit/death sparks.
	if kind == "splash": look = "fire" if effect.get("type","") == "burst" else "blast"
	var color = tint(look)
	if kind in ["chain","shock"]:
		fx.add("ability_link",event.from,color,.22,{"to":event.pos,"style":look})
	fx.add("ability_hit",event.pos,color,.42,{"style":look})
	if kind == "critical": fx.add("text",event.pos,color,.5,{"text":"CRIT"})
	if kind == "aura" or kind == "splash":
		var center: Vector2 = Vector2(event.source)+Vector2(.5,.5) if kind == "aura" else event.pos
		var key = "%s/%s/%s" % [event.source,effect.get("id",""),kind]
		if float(fx.ability_pulses.get(key,-1)) <= fx.clock:
			fx.ability_pulses[key] = fx.clock+.18
			fx.add("ability_wave",center,color,.32,{"radius":float(effect.get("radius",.5)),"style":look})
	if cells.has(event.source):
		fx.add("muzzle",Vector2(event.source)+Vector2(.5,.15),color,.12)

static func draw_event(canvas: CanvasItem, event: Dictionary, t: float, origin: Vector2, unit: float) -> void:
	var color: Color = event.color
	color.a *= 1.0-t
	var p: Vector2 = origin+event.pos*unit
	var width = maxf(1,unit*.045)
	match event.kind:
		"ability_link":
			var end: Vector2 = origin+event.to*unit-Vector2(0,unit*.2)
			var start = p-Vector2(0,unit*.25)
			var normal = (end-start).orthogonal().normalized()*unit*.12
			var points = PackedVector2Array([start,start.lerp(end,.3)+normal,start.lerp(end,.55)-normal,start.lerp(end,.8)+normal,end])
			canvas.draw_polyline(points,Color(color,.18*(1-t)),width*4)
			canvas.draw_polyline(points,color,width)
		"ability_wave":
			var radius = unit*float(event.radius)
			canvas.draw_arc(p,radius*(.85+.15*t),0,TAU,64,Color(color,.32*(1-t)),width)
			# Dashed inner front keeps large fields readable over a crowded maze.
			for i in range(12):
				var a = TAU*i/12.0
				canvas.draw_arc(p,radius*(.25+.7*t),a,a+.10,3,Color(color,.4*(1-t)),width)
		"ability_hit":
			var look = str(event.style)
			p.y -= unit*.18
			match look:
				"fire":
					for i in range(3):
						var flame = p+Vector2((i-1)*unit*.15,-unit*t*.5)
						canvas.draw_colored_polygon(PackedVector2Array([flame+Vector2(-unit*.10,unit*.1),flame+Vector2(unit*.02,-unit*(.3+.08*i)),flame+Vector2(unit*.1,unit*.1)]),color)
						canvas.draw_rect(Rect2(flame-Vector2.ONE*width,Vector2.ONE*width*2),Color(Color("fff0a0"),color.a))
				"poison":
					for i in range(3):
						canvas.draw_arc(p+Vector2((i-1)*unit*.18,-unit*t*(.25+i*.1)),unit*.08,0,TAU,8,color,width)
				"frost":
					for i in range(6):
						var ray = Vector2.RIGHT.rotated(i*TAU/6)*unit*(.25+.12*t)
						canvas.draw_line(p,p+ray,color,width)
				"stone", "shield", "fracture":
					var r = unit*(.25+.1*t)
					canvas.draw_polyline(PackedVector2Array([p+Vector2(-r,-r),p+Vector2(0,r),p+Vector2(r,-r),p+Vector2(-r,-r)]),color,width)
				_:
					for i in range(5):
						var ray = Vector2.RIGHT.rotated(i*TAU/5)*unit*(.15+.4*t)
						canvas.draw_line(p+ray*.5,p+ray,color,width)

static func draw_fields(canvas: CanvasItem, combat: GemCampaignCombat, selected: Vector2i, origin: Vector2, unit: float, clock: float) -> void:
	var drawn = 0
	for p in combat.towers:
		for action in combat.towers[p].actions:
			if action.type not in ["enemy_aura","support"]: continue
			if drawn >= int(profiles.get("max_fields",48)) and p != selected: continue
			drawn += 1
			var center: Vector2 = origin+(Vector2(p)+Vector2(.5,.5))*unit
			var color = tint(style(action) if action.type == "enemy_aura" else "support")
			var radius = float(action.radius)*unit
			var emphasis = 1.0 if p == selected else .22
			for i in range(12):
				var angle = TAU*i/12.0+clock*.12
				canvas.draw_arc(center,radius,angle,angle+.12,4,Color(color,.5*emphasis),maxf(1,unit*.035))
			if p == selected: canvas.draw_arc(center,radius,0,TAU,64,Color(color,.28),1)
	# Support badges use the combat roster's actually applied (non-stacking) bonus.
	for p in combat.towers:
		var support: Dictionary = combat.towers[p].support
		if support.is_empty(): continue
		var center: Vector2 = origin+(Vector2(p)+Vector2(.5,.5))*unit
		var look = "shield" if support.get("magic_immune",false) else "support"
		var color = tint(look)
		canvas.draw_arc(center,unit*.43,PI*.12,PI*.88,12,Color(color,.55),maxf(1,unit*.04))
		var marks: Array[String] = []
		if float(support.get("attack_speed",0)) > 0: marks.append("haste")
		if float(support.get("outgoing_percent",0)) > 0: marks.append("power")
		if float(support.get("range_bonus",0)) > 0: marks.append("range")
		if support.get("true_sight",false): marks.append("sight")
		if support.get("cannot_miss",false): marks.append("accuracy")
		if support.get("greed",false): marks.append("gold")
		if support.get("rejuvenation",false): marks.append("heal")
		for i in range(mini(3,marks.size())):
			var point = center+Vector2((i-1)*unit*.22,unit*.36)
			var r = maxf(1.5,unit*.075)
			match marks[i]:
				"sight", "gold": canvas.draw_arc(point,r,0,TAU,8,color,1)
				"range": canvas.draw_rect(Rect2(point-Vector2.ONE*r,Vector2.ONE*r*2),color,false,1)
				"accuracy", "heal":
					canvas.draw_line(point-Vector2(r,0),point+Vector2(r,0),color,1)
					canvas.draw_line(point-Vector2(0,r),point+Vector2(0,r),color,1)
				_: canvas.draw_polyline(PackedVector2Array([point+Vector2(-r,r),point+Vector2(0,-r),point+Vector2(r,r)]),color,1)

static func draw_status(canvas: CanvasItem, enemy: Dictionary, center: Vector2, unit: float, elapsed: float) -> void:
	var looks: Array[String] = []
	for aura in enemy.get("aura_memory",{}).values():
		if float(aura.until) <= elapsed: continue
		# Damage flames come only from confirmed ticks, not mere proximity.
		if aura.effect.has("damage"): continue
		var look = style(aura.effect)
		if look not in looks: looks.append(look)
	for mod in enemy.get("mods",{}).values():
		if float(mod.until) <= elapsed: continue
		var look = "poison" if mod.has("damage") else style(mod)
		if look not in looks: looks.append(look)
	for i in range(mini(3,looks.size())):
		var look = looks[i]
		var color = tint(look)
		var radius = unit*(.32+.08*i)
		if look == "stun":
			var star = center+Vector2(cos(elapsed*4)*unit*.2,-unit*.65)
			canvas.draw_rect(Rect2(star-Vector2.ONE*1.5,Vector2.ONE*3),color)
		elif look == "poison":
			var bubble = center+Vector2(unit*.25,-unit*(.2+fmod(elapsed*.65, .4)))
			canvas.draw_arc(bubble,maxf(1,unit*.055),0,TAU,6,color,1)
		else:
			canvas.draw_arc(center,radius,elapsed+i*2,elapsed+i*2+PI*.8,12,Color(color,.8),maxf(1,unit*.04))
