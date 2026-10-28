class_name GemFreshGems
extends RefCounted

const DATA: Dictionary = preload("res://assets/graphics/fresh_gems.json").data

static func markers(state: GemRun) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DATA.get("enabled",true) or state.phase != "build" or state.awaiting_trap_placement: return result
	var cells = state.fresh_cells()
	for index in range(cells.size()): result.append({"cell":cells[index],"number":index+1})
	return result

static func badge_rect(center: Vector2, pixels: float) -> Rect2:
	var side = clampf(pixels*.42,10.0,18.0)
	return Rect2(center-Vector2.ONE*pixels*.44,Vector2.ONE*side)

static func draw(canvas: CanvasItem, state: GemRun, origin: Vector2, pixels: float) -> void:
	var tint = Color(DATA.color)
	var font = ThemeDB.fallback_font
	for marker in markers(state):
		var center = origin+(Vector2(marker.cell)+Vector2(.5,.5))*pixels
		var rect = Rect2(center-Vector2.ONE*pixels*.45,Vector2.ONE*pixels*.90)
		var length = pixels*float(DATA.corner_length)
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var p = center+corner*pixels*.45
			canvas.draw_line(p,p-Vector2(corner.x*length,0),Color(DATA.background),4)
			canvas.draw_line(p,p-Vector2(0,corner.y*length),Color(DATA.background),4)
			canvas.draw_line(p,p-Vector2(corner.x*length,0),tint,2)
			canvas.draw_line(p,p-Vector2(0,corner.y*length),tint,2)
		canvas.draw_rect(rect,Color(tint,.05))
		var badge = badge_rect(center,pixels)
		canvas.draw_rect(badge,Color(DATA.background))
		canvas.draw_rect(badge,tint,false,1)
		var font_size = mini(int(DATA.badge_max_font_size),maxi(7,int(badge.size.y)-3))
		canvas.draw_string(font,badge.position+Vector2(0,badge.size.y-3),str(marker.number),HORIZONTAL_ALIGNMENT_CENTER,badge.size.x,font_size,Color(DATA.text_color))
