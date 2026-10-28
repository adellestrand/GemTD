extends SceneTree

# Trap art (assets/graphics/pixellab-traps-v1): every trap kind has a loadable manifest
# binding, and an unbound kind still falls back to the drawn box. Presentation only.

var checks = 0
var failures = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)
	else: print("PASS: "+description)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var kinds: Array = GemCatalog.DATA.specials.keys().filter(func(k): return GemCatalog.DATA.specials[k].get("slab",false))
	check(kinds.size() == 24,"campaign has 24 trap kinds")
	for kind in kinds:
		var art = GemArt.sprite_id("traps",kind)
		check(not art.is_empty() and GemArt.texture(art) != null,"trap has art: "+kind)
	check(GemArt.sprite_id("traps","no_such_trap").is_empty(),"unknown trap kinds have no binding and use the drawn box")
	check(GemArt.validation_errors().is_empty(),"manifest validates with trap bindings")
	print("TRAP_ART_CHECK_%s checks=%d failures=%d" % ["OK" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
