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

# PixelLab clips ("clips" in ability-effects.json, imported by tools/art/import_pixellab_vfx.py).
# Each layer is a horizontal strip authored around a reference subject; offsets
# count from the subject's feet, so a clip fits any enemy or tower body rect.
static var _clip_frames: Dictionary = {}

static func clip(id: String) -> Dictionary:
	return profiles.get("clips",{}).get(id,{})

static func clip_duration(id: String) -> float:
	var entry = clip(id)
	return float(entry.get("frames",1))/maxf(1.0,float(entry.get("fps",12)))

static func clip_layer_frames(id: String, depth: String) -> Array:
	var key = id+"/"+depth
	if _clip_frames.has(key): return _clip_frames[key]
	var frames: Array = []
	var layer: Dictionary = clip(id).get("layers",{}).get(depth,{})
	var path = str(layer.get("texture",""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var sheet = load(path) as Texture2D
		var count = int(clip(id).get("frames",1))
		if sheet != null and count > 0:
			var width = sheet.get_width()/count
			for i in range(count):
				var frame = AtlasTexture.new()
				frame.atlas = sheet
				frame.region = Rect2(i*width,0,width,sheet.get_height())
				frame.filter_clip = true
				frames.append(frame)
	_clip_frames[key] = frames
	return frames

static func draw_clip(canvas: CanvasItem, id: String, depth: String, body: Rect2, frame_index: int, flip: bool = false, alpha: float = 1.0) -> void:
	var frames = clip_layer_frames(id,depth)
	if frames.is_empty(): return
	var entry = clip(id)
	var layer: Dictionary = entry.layers[depth]
	var subject: Array = entry.get("subject",[32,28])
	var k = (body.size.x/float(subject[0])+body.size.y/float(subject[1]))*.5
	var feet = Vector2(body.get_center().x,body.end.y)
	var size = Vector2(float(layer.size[0]),float(layer.size[1]))*k
	var offset = Vector2(float(layer.offset[0]),float(layer.offset[1]))*k
	var rect = Rect2(feet+offset,size)
	if flip: rect = Rect2(Vector2(2*feet.x-rect.position.x,rect.position.y),Vector2(-size.x,size.y))
	canvas.draw_texture_rect(frames[clampi(frame_index,0,frames.size()-1)],rect,false,Color(1,1,1,alpha))

static func loop_frame(id: String, time: float) -> int:
	var entry = clip(id)
	return posmod(floori(time*float(entry.get("fps",12))),maxi(1,int(entry.get("frames",1))))

# Stand-in body for a hit whose target is not drawn this frame (dead, escaped, demo).
static func nominal_body(p: Vector2, unit: float) -> Rect2:
	return Rect2(p-Vector2(unit*.45,unit*.62),Vector2(unit*.9,unit*.79))

# Active looks on one enemy, read from real modifiers/aura memory plus the
# presentation-only burn/shock memory. Priority decides which survive the cap.
static func statuses(enemy: Dictionary, elapsed: float, fx: GemEffects = null) -> Array[String]:
	var found: Array[String] = []
	for aura in enemy.get("aura_memory",{}).values():
		if float(aura.until) <= elapsed or aura.effect.has("damage"): continue
		found.append(style(aura.effect))
	for mod in enemy.get("mods",{}).values():
		if float(mod.until) <= elapsed: continue
		found.append("poison" if mod.has("damage") else style(mod))
	var properties: Dictionary = enemy.get("current_properties",{})
	if properties.get("stunned",false): found.append("stun")
	if properties.get("stone_gaze",false): found.append("stone")
	if not enemy.get("poisons",{}).is_empty(): found.append("poison")
	if float(enemy.get("slow",0)) > 0: found.append("frost")
	if float(enemy.get("armor_debuff",0)) > 0: found.append("fracture")
	if fx != null: found.append_array(fx.marks.get(int(enemy.get("id",-1)),{}).keys())
	var result: Array[String] = []
	for look in profiles.get("status_priority",[]):
		if look in found and result.size() < int(profiles.get("max_statuses",4)): result.append(look)
	return result

static func status_tint(looks: Array[String]) -> Color:
	var tints: Dictionary = profiles.get("status_tints",{})
	for look in ["stone","frost"]:
		if look in looks and tints.has(look): return Color(tints[look])
	return Color.WHITE

# Modulate for a second pass with the sprite's greyscale copy (GemArt.grey_frame),
# which turns a petrified enemy to stone; alpha 0 means no overlay.
static func status_overlay(looks: Array[String]) -> Color:
	var overlays: Dictionary = profiles.get("status_overlays",{})
	for look in looks:
		if overlays.has(look): return Color(overlays[look][0],overlays[look][1],overlays[look][2],overlays[look][3])
	return Color(1,1,1,0)

# One depth ("behind" or "front") of everything clipped to this enemy: status loops
# in layer order, then hit clips aimed at it. The host draws the sprite in between.
static func draw_enemy_layer(canvas: CanvasItem, enemy: Dictionary, body: Rect2, flip: bool, elapsed: float, fx: GemEffects, depth: String, looks: Array[String], alpha: float = 1.0) -> void:
	if not bool(fx.settings().get("enabled",true)): return
	var id = int(enemy.get("id",-1))
	fx.bodies[id] = body
	var clips: Dictionary = profiles.get("status_clips",{})
	for look in profiles.get("status_layer_order",[]):
		if look in looks and clips.has(look):
			draw_clip(canvas,clips[look],depth,body,loop_frame(clips[look],elapsed+id*.37),flip,alpha)
	for event in fx.hits.get(id,[]):
		var t = clampf((fx.clock-float(event.start))/float(event.duration),0,1)
		draw_clip(canvas,event.clip,depth,body,floori(t*int(clip(event.clip).get("frames",1))),flip,alpha)

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
	# Aura and dot ticks repeat several times a second; their look lives in the
	# status loops (burn memory, poison modifier) instead of a fresh hit clip.
	var target = int(event.get("target",-1))
	var tick = kind in ["aura","dot"]
	var hit_clip = "" if tick else str(profiles.get("hit_clips",{}).get(look,""))
	if not hit_clip.is_empty() and clip(hit_clip).is_empty(): hit_clip = ""
	fx.add("ability_hit",event.pos,color,clip_duration(hit_clip) if not hit_clip.is_empty() else .42,{"style":look,"target":target,"clip":hit_clip,"tick":tick})
	var memory: Dictionary = profiles.get("status_memory",{})
	var mark = "burn" if look == "fire" else "shock" if look == "lightning" else ""
	if target >= 0 and memory.has(mark):
		if not fx.marks.has(target): fx.marks[target] = {}
		fx.marks[target][mark] = fx.clock+float(memory[mark])
	if kind == "critical": fx.add("text",event.pos,color,.5,{"text":"CRIT"})
	if kind == "aura" or kind == "splash":
		var center: Vector2 = Vector2(event.source)+Vector2(.5,.5) if kind == "aura" else event.pos
		var key = "%s/%s/%s" % [event.source,effect.get("id",""),kind]
		if float(fx.ability_pulses.get(key,-1)) <= fx.clock:
			fx.ability_pulses[key] = fx.clock+.18
			fx.add("ability_wave",center,color,.32,{"radius":float(effect.get("radius",.5)),"style":look})
	if cells.has(event.source):
		fx.add("muzzle",Vector2(event.source)+Vector2(.5,.15),color,.12)

static func draw_event(canvas: CanvasItem, event: Dictionary, t: float, origin: Vector2, unit: float, fx: GemEffects = null) -> void:
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
			var hit_clip = str(event.get("clip",""))
			if not hit_clip.is_empty():
				# A drawn target already showed this clip around its own sprite.
				if fx != null and fx.bodies.has(int(event.get("target",-1))): return
				var body = nominal_body(p,unit)
				var frame = floori(t*int(clip(hit_clip).get("frames",1)))
				draw_clip(canvas,hit_clip,"behind",body,frame)
				draw_clip(canvas,hit_clip,"front",body,frame)
				return
			if event.get("tick",false) and not clip(str(profiles.get("status_clips",{}).get("burn",""))).is_empty(): return
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
		var support_clip = str(profiles.get("support_clip",""))
		if clip(support_clip).is_empty():
			canvas.draw_arc(center,unit*.43,PI*.12,PI*.88,12,Color(color,.55),maxf(1,unit*.04))
		else:
			# Fields are drawn before towers, so both layers rise up behind the tower.
			var body = Rect2(center-Vector2(unit*.42,unit*.4),Vector2(unit*.84,unit*.74))
			var frame = loop_frame(support_clip,clock+(p.x*7+p.y*3)*.11)
			for depth in ["behind","front"]:
				draw_clip(canvas,support_clip,depth,body,frame,false,float(profiles.get("support_clip_alpha",.8)))
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
