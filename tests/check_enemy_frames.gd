extends SceneTree

# Animated enemy strips ("frames": n in the manifest): every frame shares one trimmed size,
# frame 0 is what texture() returns, frame choice follows the gait clock only, and sprites
# without frames resolve exactly as before.

var failures = 0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)

func validate() -> void:
	var animated = 0
	for id in GemArt.config().sprites:
		var count = GemArt.frame_count(id)
		var first = GemArt.texture(id)
		check(first != null,"Missing sprite: "+id)
		if first == null:
			continue
		check(GemArt.frame_texture(id,0) == first,"Frame 0 differs from texture(): "+id)
		if count == 1:
			check(GemArt.frame_texture(id,3) == first,"Static sprite returns another frame: "+id)
			check(GemArt.enemy_frame(id,1.7,4.2,3,false) == 0,"Static sprite picks a frame: "+id)
			continue
		animated += 1
		for i in range(count):
			var frame: AtlasTexture = GemArt.frame_texture(id,i)
			check(frame != null and frame.region.size == first.region.size,"Frame %d of %s has another size" % [i,id])
			check(frame != null and frame.region.position.y == first.region.position.y,"Frame %d of %s is not aligned" % [i,id])
		check(GemArt.frame_texture(id,count) == first,"Frame index does not wrap: "+id)
		# Shared trim keeps every opaque pixel of every frame inside the region.
		var image: Image = first.atlas.get_image()
		if image.is_compressed():
			image.decompress()
		var cell = image.get_width()/count
		for i in range(count):
			var used = image.get_region(Rect2i(cell*i,0,cell,image.get_height())).get_used_rect()
			var region = Rect2i(GemArt.frame_texture(id,i).region)
			check(region.encloses(Rect2i(used.position+Vector2i(cell*i,0),used.size)),"Frame %d of %s is cut by the trim" % [i,id])
		# Ground frames follow travelled distance only, cover every frame and land on frame 0.
		var seen = {}
		var frequency = float(GemArt.definition(id).get("motion",{}).get("frequency",GemArt.config().motion.ground.get("frequency",6.0)))
		for step in range(64):
			var travelled = TAU/frequency*step/64.0
			var frame_index = GemArt.enemy_frame(id,travelled,0.0,0,false)
			seen[frame_index] = true
			check(frame_index == GemArt.enemy_frame(id,travelled,123.0,0,false),"Ground frame depends on time: "+id)
		check(seen.size() == count,"Gait cycle skips frames: %s saw %s" % [id,seen.keys()])
		check(GemArt.enemy_frame(id,0.0,0.0,0,false) == 0,"Gait does not start on frame 0: "+id)
		var landing = GemArt.enemy_motion(id,PI/frequency,0.0,0,false)
		check(GemArt.enemy_frame(id,PI/frequency,0.0,0,false) == count/2 and absf(landing.offset.y+float(GemArt.config().motion.ground.get("lift",0.0))) < .001,"Second contact frame is not on a hop landing: "+id)
	check(animated > 0,"No animated sprites in the manifest")
	# A strip that does not split into equal frames is rejected instead of drawn wrong.
	var sprites: Dictionary = GemArt.config().sprites
	var strip = str(sprites.get(GemArt.sprite_id("enemies","gemtd_kuangbaoyezhu"),{}).get("texture",""))
	sprites["_uneven_strip"] = {"texture":strip,"frames":3}
	check(GemArt.texture("_uneven_strip") == null,"Uneven strip accepted")
	GemArt.reload()
	print("ENEMY_FRAMES_CHECK_%s animated=%d failures=%d" % ["OK" if failures == 0 else "FAILED",animated,failures])
	quit(1 if failures else 0)
