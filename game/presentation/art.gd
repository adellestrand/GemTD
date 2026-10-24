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
	return true

static func sprite_id(category: String, kind: String, tier: int = 1) -> String:
	var binding = config().get("bindings",{}).get(category,{}).get(kind,"")
	if binding is Dictionary:
		return str(binding.get(str(tier),binding.get("default","")))
	return str(binding)

static func definition(id: String) -> Dictionary:
	return config().get("sprites",{}).get(id,{})

static func texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var entry = definition(id)
	if entry.is_empty():
		return null
	for field in ["size","anchor","offset"]:
		if entry.has(field) and not valid_pair(entry[field]):
			return null
	var path: String = str(entry.get("texture",""))
	var sheet: Dictionary = {}
	if entry.has("sheet"):
		sheet = config().get("sheets",{}).get(entry.sheet,{})
		path = str(sheet.get("texture",""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if not _sheets.has(path):
		var resource = ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_REPLACE)
		if not resource is Texture2D:
			return null
		_sheets[path] = resource
	var source: Texture2D = _sheets[path]
	if source == null:
		return null
	var region = Rect2i(Vector2i.ZERO,Vector2i(source.get_size()))
	if not sheet.is_empty():
		var columns = int(sheet.get("columns",1))
		var rows = int(sheet.get("rows",1))
		if columns < 1 or rows < 1:
			return null
		var index = int(entry.get("index",0))
		if index < 0 or index >= columns*rows:
			return null
		var column = index%columns
		var row = index/columns
		var start = Vector2i(roundi(float(column)*source.get_width()/columns),roundi(float(row)*source.get_height()/rows))
		var end = Vector2i(roundi(float(column+1)*source.get_width()/columns),roundi(float(row+1)*source.get_height()/rows))
		region = Rect2i(start,end-start)
	if entry.has("region"):
		if not entry.region is Array or entry.region.size() != 4:
			return null
		var r: Array = entry.region
		region = Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
	if not region.has_area() or not Rect2i(Vector2i.ZERO,Vector2i(source.get_size())).encloses(region):
		return null
	# Transparent margins from a new artist's image need no hand-cropping.
	if entry.get("trim_alpha",true):
		if not _images.has(path):
			var pixels = source.get_image()
			if pixels.is_compressed():
				pixels.decompress()
			_images[path] = pixels
		var image: Image = _images[path]
		var used = image.get_region(region).get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			region = Rect2i(region.position+used.position,used.size)
	var frame = AtlasTexture.new()
	frame.atlas = source
	frame.region = Rect2(region)
	frame.filter_clip = true
	_textures[id] = frame
	return frame

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

static func draw(canvas: CanvasItem, id: String, center: Vector2, unit: float, flip: bool = false, tint: Color = Color.WHITE, deformation: Vector2 = Vector2.ONE, rotation: float = 0.0) -> Rect2:
	var frame = texture(id)
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
		return {"offset":Vector2(0,-lift),"scale":Vector2.ONE,"rotation":0.0}
	# Ground strides follow travelled distance, so slows also slow the gait.
	var cycle = (time if air else travelled)*float(profile.get("frequency",6.0))+phase*1.7
	var wave = sin(cycle)
	var squash = float(profile.get("squash",.025))
	return {"offset":Vector2(0,-lift-absf(wave)*float(profile.get("bounce",.045))),"scale":Vector2(1+wave*squash,1-wave*squash),"rotation":wave*float(profile.get("sway",.025))}

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
