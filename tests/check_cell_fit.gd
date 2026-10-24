extends SceneTree

# Every sprite that stands on a board cell (all gem types and qualities, specials,
# stones and checkpoints) must stay inside its own cell and be centred in it.

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var failures = 0
	var cases = 0
	var ids: Array[String] = []
	for kind in GemCatalog.TYPES+GemCatalog.DATA.specials.keys():
		if GemCatalog.DATA.specials.get(kind,{}).get("slab",false): continue
		for tier in range(1,GemCatalog.quality_limit(kind)+1):
			ids.append(GemArt.sprite_id("gems",kind,tier))
	ids.append(GemArt.sprite_id("gems","stone",1))
	ids.append("checkpoint")
	for id in ids:
		for unit in [15.0,21.0,32.0,45.0]:
			var cell = Rect2(Vector2(200,120),Vector2.ONE*unit)
			var rect = GemArt.sprite_rect(id,cell.get_center(),unit)
			cases += 1
			if not cell.grow(0.01).encloses(rect):
				failures += 1
				printerr("Sprite leaves its cell: %s at %s px/cell (%s)" % [id,unit,rect])
			elif not rect.get_center().is_equal_approx(cell.get_center()):
				failures += 1
				printerr("Sprite not centred in its cell: %s at %s px/cell" % [id,unit])
	print("CELL_FIT_CHECK_%s cases=%d failures=%d" % ["OK" if failures == 0 else "FAILED",cases,failures])
	quit(1 if failures else 0)
