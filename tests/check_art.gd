extends SceneTree

func _initialize() -> void:
	call_deferred("validate_art")

func validate_art() -> void:
	var errors = GemArt.validation_errors()
	for error in errors:
		printerr(error)
	if not errors.is_empty():
		quit(1)
		return
	for id in GemArt.config().sprites:
		var frame = GemArt.texture(id)
		if frame.get_width() <= 1 or frame.get_height() <= 1 or frame.get_image().get_used_rect().size == Vector2i.ZERO:
			printerr("Empty sprite: "+id)
			quit(1)
			return
	var centered_cases = 0
	for kind in GemCatalog.TYPES+GemCatalog.DATA.specials.keys():
		if GemCatalog.DATA.specials.get(kind,{}).get("slab",false): continue
		for tier in range(1,GemCatalog.quality_limit(kind)+1):
			for unit in [15.0,32.0,45.0]:
				var at = Vector2(137,72)
				var rect = GemArt.sprite_rect(GemArt.sprite_id("gems",kind,tier),at,unit)
				if not rect.get_center().is_equal_approx(at):
					printerr("Tower displaced from cell center: %s / %d / %s" % [kind,tier,unit])
					quit(1)
					return
				centered_cases += 1
	# Replacing one quality with a standalone image must not require a new atlas.
	var config = GemArt.config()
	var original_one = GemArt.sprite_id("gems","sapphire",1)
	var original_three = GemArt.sprite_id("gems","sapphire",3)
	config.sprites["_direct_check"] = {"texture":config.sheets.towers.texture,"trim_alpha":false,"size":[1,1],"anchor":[.5,.85]}
	config.bindings.gems.sapphire["2"] = "_direct_check"
	if GemArt.sprite_id("gems","sapphire",2) != "_direct_check" or GemArt.texture("_direct_check") == null or GemArt.sprite_id("gems","sapphire",1) != original_one or GemArt.sprite_id("gems","sapphire",3) != original_three:
		printerr("Standalone image / per-quality replacement failed")
		quit(1)
		return
	GemArt.reload()
	print("ART_CHECK_OK sprites=%d; centered tower layouts=%d; all gem qualities and wave enemies resolved" % [GemArt.config().sprites.size(),centered_cases])
	quit(0)
