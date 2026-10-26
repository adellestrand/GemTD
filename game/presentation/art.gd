class_name GemArt
extends RefCounted

# All filenames, atlas coordinates, sizes and anchors live in the manifest.
# Art can be replaced without touching simulation, balance data or save files.
const MANIFEST_PATH = "res://assets/graphics/manifest.json"
const DEFAULT_MANIFEST: JSON = preload(MANIFEST_PATH)
static var _config: Dictionary = {}
static var _textures: Dictionary = {}
static var _sheets: Dictionary = {}
static var _images: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		_config = DEFAULT_MANIFEST.data.duplicate(true)
	return _config

static func reload() -> bool:
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(MANIFEST_PATH)) != OK or not parser.data is Dictionary:
		return false
	_config = parser.data
	_textures.clear()
	_sheets.clear()
	_images.clear()
	_grey.clear()
	return true

static func sprite_id(category: String, kind: String, tier: int = 1) -> String:
	var binding = config().get("bindings",{}).get(category,{}).get(kind,"")
	if binding is Dictionary:
		return str(binding.get(str(tier),binding.get("default","")))
	return str(binding)

static func definition(id: String) -> Dictionary:
	return config().get("sprites",{}).get(id,{})

static func texture(id: String) -> Texture2D:
	return frame_texture(id,0)

# Animated sprites ("frames": n) are horizontal strips of n equal frames.
static func frame_count(id: String) -> int:
	return maxi(1,int(definition(id).get("frames",1)))

# Idle artwork follows the board's visual clock, including pause and speed changes.
# Portraits still use texture(), which always returns the original first frame.
static func idle_frame(id: String, time: float) -> int:
	if not bool(config().get("motion",{}).get("enabled",true)): return 0
	var fps = maxf(0.0,float(definition(id).get("idle_fps",0.0)))
	return posmod(floori(time*fps),frame_count(id))

static func frame_texture(id: String, index: int) -> Texture2D:
	var frames: Array = _frames(id)
	if frames.is_empty():
		return null
	return frames[posmod(index,frames.size())]

static func _frames(id: String) -> Array:
	if _textures.has(id):
		return _textures[id]
	var entry = definition(id)
	if entry.is_empty():
		return []
	var built = _build_frames(id,entry)
	if not built.is_empty():
		_textures[id] = built
	return built

static func _build_frames(id: String, entry: Dictionary) -> Array:
	for field in ["size","anchor","offset"]:
		if entry.has(field) and not valid_pair(entry[field]):
			return []
	var path: String = str(entry.get("texture",""))
	var sheet: Dictionary = {}
	if entry.has("sheet"):
		sheet = config().get("sheets",{}).get(entry.sheet,{})
		path = str(sheet.get("texture",""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return []
	if not _sheets.has(path):
		var resource = ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_REPLACE)
		if not resource is Texture2D:
			return []
		_sheets[path] = resource
	var source: Texture2D = _sheets[path]
	if source == null:
		return []
	var region = Rect2i(Vector2i.ZERO,Vector2i(source.get_size()))
	if not sheet.is_empty():
		var columns = int(sheet.get("columns",1))
		var rows = int(sheet.get("rows",1))
		if columns < 1 or rows < 1:
			return []
		var index = int(entry.get("index",0))
		if index < 0 or index >= columns*rows:
			return []
		var column = index%columns
		var row = index/columns
		var start = Vector2i(roundi(float(column)*source.get_width()/columns),roundi(float(row)*source.get_height()/rows))
		var end = Vector2i(roundi(float(column+1)*source.get_width()/columns),roundi(float(row+1)*source.get_height()/rows))
		region = Rect2i(start,end-start)
	if entry.has("region"):
		if not entry.region is Array or entry.region.size() != 4:
			return []
		var r: Array = entry.region
		region = Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
	if not region.has_area() or not Rect2i(Vector2i.ZERO,Vector2i(source.get_size())).encloses(region):
		return []
	var count = int(entry.get("frames",1))
	if count < 1 or region.size.x%count != 0:
		return []
	var cell = Vector2i(region.size.x/count,region.size.y)
	var trim = Rect2i(Vector2i.ZERO,cell)
	# Transparent margins from a new artist's image need no hand-cropping.
	# Animation frames share one trim (the union of their used rects) so they never jitter.
	if entry.get("trim_alpha",true):
		if not _images.has(path):
			var pixels = source.get_image()
			if pixels.is_compressed():
				pixels.decompress()
			_images[path] = pixels
		var image: Image = _images[path]
		var union = Rect2i()
		for i in range(count):
			var used = image.get_region(Rect2i(region.position+Vector2i(cell.x*i,0),cell)).get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				union = used if not union.has_area() else union.merge(used)
		if union.has_area():
			trim = union
	var frames: Array = []
	for i in range(count):
		var frame = AtlasTexture.new()
		frame.atlas = source
		frame.region = Rect2(Rect2i(region.position+Vector2i(cell.x*i,0)+trim.position,trim.size))
		frame.filter_clip = true
		frames.append(frame)
	return frames

static func valid_pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float)

static func fitted_size(id: String, unit: float) -> Vector2:
	var frame = texture(id)
	if frame == null:
		return Vector2.ZERO
	var entry = definition(id)
	var box: Array = entry.get("size",[1.0,1.0])
	var scale_factor = minf(float(box[0])*unit/frame.get_width(),float(box[1])*unit/frame.get_height())
	return frame.get_size()*scale_factor

static func sprite_rect(id: String, center: Vector2, unit: float) -> Rect2:
	var size = fitted_size(id,unit)
	var entry = definition(id)
	var anchor: Array = entry.get("anchor",[0.5,0.5])
	var offset: Array = entry.get("offset",[0.0,0.0])
	return Rect2(center+Vector2(offset[0],offset[1])*unit-Vector2(anchor[0],anchor[1])*size,size)

# Greyscale copy of one frame, built on first use (petrified enemies).
static var _grey: Dictionary = {}

static func grey_frame(id: String, index: int) -> Texture2D:
	var source = frame_texture(id,index)
	if source == null: return null
	var key = "%s/%d" % [id,posmod(index,frame_count(id))]
	if not _grey.has(key):
		var image: Image = source.get_image()
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var c = image.get_pixel(x,y)
				var v = c.r*.3+c.g*.59+c.b*.11
				image.set_pixel(x,y,Color(v,v,v,c.a))
		_grey[key] = ImageTexture.create_from_image(image)
	return _grey[key]

static func draw(canvas: CanvasItem, id: String, center: Vector2, unit: float, flip: bool = false, tint: Color = Color.WHITE, deformation: Vector2 = Vector2.ONE, rotation: float = 0.0, frame_index: int = 0, texture_override: Texture2D = null) -> Rect2:
	var frame = texture_override if texture_override != null else frame_texture(id,frame_index)
	if frame == null:
		return Rect2()
	var entry = definition(id)
	var offset: Array = entry.get("offset",[0.0,0.0])
	var position = center+Vector2(offset[0],offset[1])*unit
	var bounds = sprite_rect(id,center,unit)
	var rect = Rect2(bounds.position-position,bounds.size)
	canvas.draw_set_transform(position,rotation,Vector2(-1 if flip else 1,1)*deformation)
	canvas.draw_texture_rect(frame,rect,false,tint)
	canvas.draw_set_transform(Vector2.ZERO)
	return bounds

static func enemy_motion(id: String, travelled: float, time: float, phase: int, air: bool) -> Dictionary:
	var config_motion: Dictionary = config().get("motion",{})
	var profile: Dictionary = config_motion.get("air" if air else "ground",{}).duplicate()
	profile.merge(definition(id).get("motion",{}),true)
	var lift = float(profile.get("lift",.25 if air else 0))
	if not bool(config_motion.get("enabled",true)):
		return {"offset":Vector2(0,-lift),"scale":Vector2.ONE,"rotation":0.0,"lean":0.0}
	var squash = float(profile.get("squash",.025))
	var bounce = float(profile.get("bounce",.045))
	var sway = float(profile.get("sway",.025))
	if air:
		# Wing beat: the body rises on the down-stroke and stretches/compresses with it,
		# plus a slow figure-eight drift so flyers never move on rails.
		var beat = time*float(profile.get("frequency",6.0))+phase*1.7
		var flap = sin(beat)
		var drift = time*1.3+phase*.9
		return {"offset":Vector2(sin(drift)*.035,-lift-(flap*.5+.5)*bounce+sin(drift*2.0)*.02),
			"scale":Vector2(1.0+flap*squash*.6,1.0-flap*squash),"rotation":sin(drift)*sway,"lean":.05}
	# Ground strides follow travelled distance, so slows also slow the gait.
	# Each step: push off (stretch), airborne arc, then a short squash on landing.
	var cycle = travelled*float(profile.get("frequency",6.0))+phase*1.7
	var step = sin(cycle)
	var hop = absf(step)
	var land = pow(1.0-hop,3.0)
	return {"offset":Vector2(0,-lift-hop*bounce),
		"scale":Vector2(1.0+land*squash*1.6-hop*squash*.4,1.0-land*squash*1.6+hop*squash*.6),
		"rotation":step*sway,"lean":.035}

# Animation frame on the same gait clock as enemy_motion: ground frames follow travelled
# distance (slows slow the legs too) and frame 0 lands with the hop, flyers follow time.
static func enemy_frame(id: String, travelled: float, time: float, phase: int, air: bool) -> int:
	var count = frame_count(id)
	var config_motion: Dictionary = config().get("motion",{})
	if count <= 1 or not bool(config_motion.get("enabled",true)):
		return 0
	var profile: Dictionary = config_motion.get("air" if air else "ground",{}).duplicate()
	profile.merge(definition(id).get("motion",{}),true)
	var cycle = (time if air else travelled)*float(profile.get("frequency",6.0))+phase*1.7
	return posmod(floori(cycle/TAU*count+.5),count)

static func color(key: String, fallback: Color = Color.WHITE) -> Color:
	return Color(config().get("palette",{}).get(key,fallback.to_html()))

static func gem_color(gem: Dictionary) -> Color:
	var id = sprite_id("gems",str(gem.get("kind","stone")),int(gem.get("tier",1)))
	return Color(definition(id).get("effect_color",GemCatalog.color_of(gem).to_html()))

static func validation_errors() -> PackedStringArray:
	var errors = PackedStringArray()
	if int(config().get("version",0)) != 1:
		errors.append("Unsupported graphics manifest version")
	var theme_path = str(config().get("theme",""))
	if theme_path.is_empty() or not ResourceLoader.exists(theme_path) or not load(theme_path) is Theme:
		errors.append("Missing or invalid UI theme")
	for id in config().get("sprites",{}):
		if texture(id) == null:
			errors.append("Missing or invalid sprite: "+id)
	for kind in GemCatalog.TYPES+GemCatalog.DATA.specials.keys()+["stone"]:
		for tier in range(1,GemCatalog.quality_limit(kind)+1):
			var id = sprite_id("gems",kind,tier)
			if id.is_empty() or texture(id) == null:
				errors.append("Missing gem binding: %s / %d" % [kind,tier])
	for wave in GemCatalog.DATA.waves:
		if texture(sprite_id("enemies",wave.source_id)) == null:
			errors.append("Missing enemy binding: "+str(wave.source_id))
	return errors
