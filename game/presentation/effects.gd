class_name GemEffects
extends RefCounted

# Short-lived visual events only. No RNG, damage, targeting or saved state.
var events: Array[Dictionary] = []
var flashes: Dictionary = {}
var clock = 0.0

func settings() -> Dictionary:
	return GemArt.config().get("effects",{})

func clear() -> void:
	events.clear()
	flashes.clear()
	clock = 0.0

func advance(dt: float) -> void:
	clock += maxf(0,dt)
	events = events.filter(func(e): return clock-e.start < e.duration)
	for id in flashes.keys():
		if clock >= float(flashes[id]):
			flashes.erase(id)

func add(kind: String, position: Vector2, color: Color, duration: float, extra: Dictionary = {}) -> void:
	if not bool(settings().get("enabled",true)):
		return
	var event = {"kind":kind,"pos":position,"color":color,"duration":maxf(.01,duration),"start":clock}
	event.merge(extra)
	events.append(event)
	var limit = maxi(1,int(settings().get("max_events",240)))
	while events.size() > limit:
		events.pop_front()

func shot(from: Vector2, to: Vector2, color: Color, gem_kind: String) -> void:
	var profile: Dictionary = settings().get("shots",{}).get(gem_kind,{})
	var height = float(profile.get("muzzle_height",settings().get("muzzle_height",.35)))
	add("shot",from,color,float(profile.get("duration",.13)),{"to":to,"style":str(profile.get("style","bolt")),"height":height})
	add("muzzle",from-Vector2(0,height),color,.16)

func damaged(enemy_id: int, position: Vector2, amount: float, damage_type: String, lethal: bool) -> void:
	if not bool(settings().get("enabled",true)):
		return
	flashes[enemy_id] = clock+float(settings().get("hit_flash",.08))
	var color = Color(settings().get("damage_colors",{}).get(damage_type,"#f8e3b4"))
	add("death" if lethal else "hit",position,color,.32 if lethal else .16)
	if bool(settings().get("damage_numbers",false)):
		add("text",position,color,.55,{"text":str(snappedf(amount,.1))})

func evaded(_enemy_id: int, position: Vector2) -> void:
	add("text",position,Color("d4dbd4"),.45,{"text":"MISS"})

func escaped(position: Vector2, _boss: bool) -> void:
	add("ring",position,Color("ff8875"),.65,{"radius":1.0})
	add("text",position,Color("ffb294"),.7,{"text":"LEAK"})

func area(from: Vector2, radius: float) -> void:
	add("ring",from,Color(settings().get("area_color","#ef8775")),.28,{"radius":radius})

func draw_projectiles(canvas: CanvasItem, projectiles: Array[Dictionary], origin: Vector2, unit: float) -> void:
	# Presentation reads the real flight positions. Disabling or limiting the
	# renderer never removes a logical projectile or consumes combat RNG.
	if not bool(settings().get("enabled",true)): return
	var limit = maxi(1,int(settings().get("max_events",240)))
	for projectile in projectiles.slice(0,limit):
		var profile: Dictionary = settings().get("shots",{}).get(projectile.kind,{})
		var style = str(profile.get("style","bolt"))
		var color: Color = projectile.color
		var position: Vector2 = origin+projectile.pos*unit-Vector2(0,unit*.3)
		var direction: Vector2 = (projectile.pos-projectile.previous).normalized()
		if direction == Vector2.ZERO: direction = (projectile.target.pos-projectile.pos).normalized()
		var width = maxf(1,unit*.055)
		var length = unit*(.55 if style == "beam" else .28)
		canvas.draw_line(position-direction*length,position,Color(color,.7),width*(2 if style == "ember" else 1))
		canvas.draw_rect(Rect2(position-Vector2.ONE*width,Vector2.ONE*width*2),color.lightened(.4))

func draw(canvas: CanvasItem, origin: Vector2, unit: float, font: Font) -> void:
	for event in events:
		var t = clampf((clock-float(event.start))/float(event.duration),0,1)
		var color: Color = event.color
		color.a *= 1.0-t
		var p: Vector2 = origin+event.pos*unit
		match event.kind:
			"shot":
				var start = p-Vector2(0,unit*float(event.height))
				var end: Vector2 = origin+event.to*unit-Vector2(0,unit*.3)
				var width = maxf(1,unit*.055)
				match event.style:
					"beam":
						canvas.draw_line(start,end,Color(color,.13*(1-t)),width*4)
						canvas.draw_line(start,end,color,width)
					"shard":
						canvas.draw_dashed_line(start,end,color,width,maxf(2,unit*.16))
					"ember":
						canvas.draw_line(start,end,color,width*2)
						canvas.draw_circle(end,unit*.14*(1-t),color)
					_:
						canvas.draw_line(start,end,color,width)
						canvas.draw_rect(Rect2(end-Vector2.ONE*width,Vector2.ONE*width*2),color.lightened(.4))
			"muzzle", "hit", "death":
				p.y -= unit*(0 if event.kind == "muzzle" else .3)
				var radius = unit*(.12+.22*t) if event.kind != "death" else unit*(.2+.5*t)
				for i in range(4):
					var direction = Vector2.RIGHT.rotated(i*TAU/4+.25)
					var spark = p+direction*radius
					canvas.draw_rect(Rect2(spark,Vector2.ONE*maxf(1,unit*.07)),color)
			"ring":
				canvas.draw_arc(p,unit*float(event.get("radius",.7))*(.3+.7*t),0,TAU,32,color,maxf(1,unit*.04))
			"text":
				p.y -= unit*(.6+t*.8)
				canvas.draw_string(font,p-Vector2(24,0),str(event.text),HORIZONTAL_ALIGNMENT_CENTER,48,12,color)
