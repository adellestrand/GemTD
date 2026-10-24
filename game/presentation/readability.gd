class_name GemReadability
extends RefCounted

# Presentation-only overlays. Asset identities and colors remain replaceable.
const DATA: Dictionary = preload("res://assets/graphics/readability.json").data

static func tower_label(gem: Dictionary) -> String:
	if DATA.special_codes.has(gem.kind): return str(DATA.special_codes[gem.kind])
	return str(DATA.quality_labels[clampi(int(gem.tier)-1,0,5)])

static func badge(canvas: CanvasItem, center: Vector2, text: String, color: Color, pixels: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size = clampi(roundi(pixels*.3),8,13)
	var extent = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var rect = Rect2(center-Vector2(extent.x+4,font_size+3)/2,Vector2(extent.x+4,font_size+3))
	canvas.draw_rect(rect,Color("122129"))
	canvas.draw_line(Vector2(rect.position.x,rect.end.y),rect.end,color,2)
	canvas.draw_string(font,Vector2(rect.position.x+2,rect.position.y+font_size),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("f1eddd"))

static func tower(canvas: CanvasItem, center: Vector2, pixels: float, gem: Dictionary, selected: bool = false, disabled: bool = false) -> void:
	if gem.kind == "stone": return
	var special = DATA.special_codes.has(gem.kind)
	if not special or pixels >= float(DATA.special_min_cell_size) or selected:
		# keep the badge inside the tower's own cell: its bottom edge sits on the cell's bottom edge
		var badge_height = float(clampi(roundi(pixels*.3),8,13)+3)
		badge(canvas,center+Vector2(0,pixels*.5-badge_height*.5),tower_label(gem),Color("edd17d") if special else Color(DATA.quality_colors[clampi(int(gem.tier)-1,0,5)]),pixels)
	elif special:
		canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(0,.23)*pixels,center+Vector2(.18,.4)*pixels,center+Vector2(0,.57)*pixels,center+Vector2(-.18,.4)*pixels]),Color("e1c787"))
	if int(gem.get("mvp",0)) > 0:
		var point = center+Vector2(.37,-.38)*pixels
		canvas.draw_circle(point,maxf(2,pixels*.07),Color("172225"))
		canvas.draw_line(point-Vector2(2,0),point+Vector2(2,0),Color("f4d778"),1)
		canvas.draw_line(point-Vector2(0,2),point+Vector2(0,2),Color("f4d778"),1)
	if disabled: symbol(canvas,center+Vector2(0,-.6)*pixels,"stun",maxf(4,pixels*.15),Color("f0a277"))

static func trap_style(kind: String) -> Dictionary:
	var tier = 3 if kind.ends_with("_jin") else 2 if kind.ends_with("_yin") else 1
	var base = kind.trim_suffix("_jin").trim_suffix("_yin")
	return {"tier":tier,"symbol":DATA.trap_families.get(base,"ethereal"),"color":Color(DATA.trap_colors[tier-1])}

static func trap(canvas: CanvasItem, center: Vector2, pixels: float, kind: String) -> void:
	var style = trap_style(kind)
	canvas.draw_rect(Rect2(center-Vector2.ONE*pixels*.4,Vector2.ONE*pixels*.8),Color("233431"))
	canvas.draw_rect(Rect2(center-Vector2.ONE*pixels*.36,Vector2.ONE*pixels*.72),style.color,false,maxf(1,pixels*.04))
	symbol(canvas,center,str(style.symbol),pixels*.2,style.color)
	for i in range(int(style.tier)):
		var p = center+Vector2((i-(int(style.tier)-1)*.5)*.17,.31)*pixels
		canvas.draw_line(p-Vector2(0,1),p+Vector2(0,1),style.color,1)

static func enemy_states(enemy: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var properties: Dictionary = enemy.get("current_properties",{})
	if properties.get("stone_gaze",false): result.append("stone")
	if properties.get("stunned",false): result.append("stun")
	if int(enemy.get("refraction",0)) > 0: result.append("refraction")
	if enemy.get("invisible",false): result.append("invisible")
	var poisoned = not enemy.get("poisons",{}).is_empty()
	for mod in enemy.get("mods",{}).values(): poisoned = poisoned or mod.has("damage")
	if poisoned: result.append("poison")
	if float(enemy.get("slow",0)) > 0 or float(properties.get("move_constant",0)) < 0 or float(properties.get("move_percent",0)) < 0: result.append("slow")
	if float(enemy.get("armor_debuff",0)) > 0 or float(properties.get("armor",0)) < 0: result.append("armor")
	if enemy.get("magic_immune",false): result.append("immune")
	return result

static func enemy(canvas: CanvasItem, center: Vector2, pixels: float, value: Dictionary) -> void:
	var states = enemy_states(value)
	var count = mini(states.size(),int(DATA.max_status_icons))
	var radius = clampf(pixels*.11,2,5)
	for i in range(count):
		var pos = center+Vector2((i-(count-1)*.5)*(radius*2+2),-pixels*.65)
		canvas.draw_rect(Rect2(pos-Vector2.ONE*(radius+1),Vector2.ONE*(radius+1)*2),Color("14232a"))
		symbol(canvas,pos,states[i],radius,Color(DATA.status_colors[states[i]]))

static func symbol(canvas: CanvasItem, p: Vector2, id: String, r: float, color: Color) -> void:
	var width = maxf(1,r*.22)
	match id:
		"poison","field":
			canvas.draw_circle(p,r*.7,color)
			canvas.draw_line(p+Vector2(-r,r),p+Vector2(r,r),color,width)
		"slow","line_slow":
			canvas.draw_polyline(PackedVector2Array([p+Vector2(-r,-r),p+Vector2(0,-r*.2),p+Vector2(-r*.5,r*.3),p+Vector2(r,r)]),color,width)
		"stone","ethereal":
			canvas.draw_polyline(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r,0),p+Vector2(0,r),p+Vector2(-r,0),p+Vector2(0,-r)]),color,width)
		"stun","stun_root":
			canvas.draw_line(p-Vector2(r,0),p+Vector2(r,0),color,width)
			canvas.draw_line(p-Vector2(0,r),p+Vector2(0,r),color,width)
		"refraction","immune":
			canvas.draw_rect(Rect2(p-Vector2.ONE*r,Vector2.ONE*r*2),color,false,width)
			if id == "immune": canvas.draw_line(p-Vector2(r,r),p+Vector2(r,r),color,width)
		"invisible","dread":
			canvas.draw_arc(p,r,0,TAU,8,color,width)
			canvas.draw_circle(p,maxf(1,r*.25),color)
		"armor":
			canvas.draw_polyline(PackedVector2Array([p+Vector2(-r,-r),p+Vector2(0,r),p+Vector2(r,-r)]),color,width)
		"torrent":
			canvas.draw_line(p+Vector2(-r,-r*.4),p+Vector2(r,-r*.4),color,width)
			canvas.draw_line(p+Vector2(-r,r*.4),p+Vector2(r,r*.4),color,width)
		"support":
			canvas.draw_polyline(PackedVector2Array([p+Vector2(-r,r),p+Vector2(0,-r),p+Vector2(r,r)]),color,width)
		"cask":
			canvas.draw_rect(Rect2(p-Vector2(r*.7,r),Vector2(r*1.4,r*2)),color,false,width)
			canvas.draw_line(p-Vector2(r,0),p+Vector2(r,0),color,width)
