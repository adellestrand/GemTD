extends SceneTree

# Rendered regression check: fractional UI scaling must not make every fifth
# grid boundary thicker. Run with a real renderer, not --headless.
const COLUMNS = 24
const ROWS = 12
var cases = 0
var failures = 0

class Ground extends Control:
	var terrain = preload("res://game/presentation/terrain_art.gd").new()
	var unit = 26.0
	var origin = Vector2(80.37,80.41)
	func _ready() -> void:
		resized.connect(queue_redraw)
	func _draw() -> void:
		terrain.draw(self,origin,unit,COLUMNS,ROWS,GemArt.config().terrain)

func _initialize() -> void:
	call_deferred("run_checks")

func line_widths(image: Image, first: Vector2i, last: Vector2i) -> Array[int]:
	var result: Array[int] = []
	var direction = Vector2i(1,0) if first.y == last.y else Vector2i(0,1)
	var distance = absi(last.x-first.x)+absi(last.y-first.y)
	var run = 0
	for i in range(distance):
		var pixel = image.get_pixelv(first+direction*i)
		# The grass's darkest flecks have G >= 78; boundaries have G = 61.
		var dark = pixel.g < 70.0/255.0 and pixel.r < 50.0/255.0
		if dark:
			run += 1
		elif run > 0:
			result.append(run)
			run = 0
	if run: result.append(run)
	return result

func run_checks() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Terrain grid checks require a rendered window; omit --headless.")
		quit(2)
		return
	root.title = "GemTD - grid pixel regression check"
	root.content_scale_size = Vector2i(1600,900)
	var ground = Ground.new()
	root.add_child(ground)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		for unit in [15.0,26.0,39.0,57.2]:
			ground.unit = unit
			ground.queue_redraw()
			await process_frame
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var image = root.get_texture().get_image()
			var transform = ground.get_viewport_transform()
			# Scan strictly inside the outer cells, avoiding the background and border.
			var a = transform*(ground.origin+Vector2(unit*.5,unit*.5))
			var b = transform*(ground.origin+Vector2(unit*(COLUMNS-.5),unit*.5))
			var c = transform*(ground.origin+Vector2(unit*.5,unit*(ROWS-.5)))
			var vertical = line_widths(image,Vector2i(a.round()),Vector2i(b.round()))
			var horizontal = line_widths(image,Vector2i(a.round()),Vector2i(c.round()))
			var ok = vertical.size() == COLUMNS-1 and horizontal.size() == ROWS-1
			for width in vertical+horizontal: ok = ok and width == 1
			cases += 1
			if not ok:
				failures += 1
				printerr("Uneven grid at %s, unit=%s: vertical=%s horizontal=%s" % [resolution,unit,vertical,horizontal])
			else:
				print("GRID_PIXEL_OK resolution=%s unit=%s scale=%s boundaries=%d width=1" % [image.get_size(),unit,transform.x.length(),vertical.size()+horizontal.size()])
			if resolution == Vector2i(1920,1080) and unit == 26.0:
				DirAccess.make_dir_recursive_absolute("res://output/pixellab-v1")
				image.save_png("res://output/pixellab-v1/grid-pixel-1080p.png")
	print("TERRAIN_GRID_CHECK_%s cases=%d failures=%d" % ["OK" if failures == 0 else "FAILED",cases,failures])
	quit(1 if failures else 0)
