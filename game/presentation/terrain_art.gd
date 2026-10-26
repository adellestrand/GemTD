extends RefCounted

# Ground material and cell boundaries are independent of board rules and zoom.
# Texture variants use deterministic flips; they never consume gameplay RNG.
var cached_path = ""
var textures: Array[Texture2D] = []

func draw(canvas: CanvasItem, origin: Vector2, unit: float, columns: int, rows: int, settings: Dictionary) -> bool:
	var path = str(settings.get("texture",""))
	if path.is_empty(): return false
	if path != cached_path:
		textures.clear()
		cached_path = path
		if not ResourceLoader.exists(path): return false
		var resource = load(path) as Texture2D
		if resource == null: return false
		var source = resource.get_image()
		if source == null: return false
		if source.is_compressed(): source.decompress()
		for i in range(4):
			var image = source.duplicate() as Image
			if i&1: image.flip_x()
			if i&2: image.flip_y()
			image.generate_mipmaps()
			textures.append(ImageTexture.create_from_image(image))
	if textures.size() != 4: return false
	for y in range(rows):
		for x in range(columns):
			canvas.draw_texture_rect(textures[(x*13+y*7)%4],Rect2(origin+Vector2(x,y)*unit,Vector2.ONE*unit),false)
	# One shared line per boundary: no bevel, inner frame or checkerboard tint.
	var grid = Color(str(settings.get("grid_color","#263d2d")))
	var width = float(columns)*unit
	var height = float(rows)*unit
	# Window stretch (e.g. 1600 -> 1920) also scales line widths. Snap after
	# that transform and compensate its scale, keeping every boundary one
	# output pixel wide instead of periodically growing to two pixels.
	var to_pixels = canvas.get_viewport_transform()
	var from_pixels = to_pixels.affine_inverse()
	var start = to_pixels*origin
	var end = to_pixels*(origin+Vector2(width,height))
	var vertical_width = 1.0/maxf(.001,to_pixels.x.length())
	var horizontal_width = 1.0/maxf(.001,to_pixels.y.length())
	for x in range(columns+1):
		var at = roundf((to_pixels*(origin+Vector2(float(x)*unit,0))).x)+.5
		canvas.draw_line(from_pixels*Vector2(at,start.y),from_pixels*Vector2(at,end.y),grid,vertical_width)
	for y in range(rows+1):
		var at = roundf((to_pixels*(origin+Vector2(0,float(y)*unit))).y)+.5
		canvas.draw_line(from_pixels*Vector2(start.x,at),from_pixels*Vector2(end.x,at),grid,horizontal_width)
	return true
