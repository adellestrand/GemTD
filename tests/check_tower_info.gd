extends SceneTree

var checks = 0
var failures = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)
	else:
		print("PASS: "+description)

func gem(kind: String, tier: int = 1, fresh: bool = false) -> Dictionary:
	return {"kind":kind,"tier":tier,"fresh":fresh,"priority":"First"}

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var p = Vector2i(10,10)
	var aqua = gem("aquamarine")
	var cells = {p:aqua,Vector2i(11,10):gem("opal"),Vector2i(12,10):gem("opal"),Vector2i(13,10):gem("opal",2),Vector2i(30,30):gem("opal",3)}
	var before = cells.duplicate(true)
	var info = GemTowerInfo.profile(aqua,p,cells)
	check(is_equal_approx(info.interval,1.0/3.5) and is_equal_approx(info.dps,7.0),"displayed Aquamarine timing includes innate speed and distinct nearby Opal qualities")
	check(info.timing.auras.size() == 2 and info.timing.bonus == 250,"same-quality Opals do not stack and out-of-range Opal contributes nothing")
	check(GemTowerInfo.describe(info).contains("Opal I +20") and GemTowerInfo.describe(info).contains("Opal II +30"),"speed explanation lists the contributing qualities")
	check(is_equal_approx(GemTowerInfo.profile(gem("opal"),p,{p:gem("opal")}).interval,float(GemCatalog.stats(gem("opal")).interval)/1.2),"Opal's own support aura is included")
	check(GemTowerInfo.profile({},p,cells).is_empty() and GemTowerInfo.profile(gem("stone"),p,cells).is_empty(),"empty selection and stone have no invented attack statistics")
	var aura = GemTowerInfo.profile(gem("asteriated_ruby"),p,cells)
	check(aura.aura and aura.damage == 20 and aura.interval == .25 and aura.dps == 80 and aura.timing.bonus == 0,"burning aura shows its true tick damage and ignores attack speed")
	check(aura.range == float(GemCatalog.DATA.effects.asteriated_ruby.radius) and aura.targets == "Ground + air","burning aura uses effect radius rather than unused base attack range")
	check(GemTowerInfo.effect_text(gem("ruby",2)).contains("40%") and not GemTowerInfo.effect_text(gem("ruby",2)).contains("30%"),"effect description shows only the selected quality's splash")
	check(GemTowerInfo.effect_text(gem("emerald",3)).contains("8 magic") and GemTowerInfo.effect_text(gem("amethyst",2)).contains("−4 armor"),"poison and armor text use the selected quality's actual values")
	check(GemTowerInfo.profile(gem("diamond"),p,cells).targets == "Ground only" and GemTowerInfo.effect_text(gem("topaz")).contains("3 extra targets"),"target restriction and extra-target count remain explicit")
	check(cells == before,"reading and formatting tower details never mutates the inventory")
	var state = GemRun.new(42)
	state.board.cells[p] = gem("aquamarine",1,true)
	state.board.cells[Vector2i(11,10)] = gem("aquamarine",1,true)
	state.board.cells[Vector2i(12,10)] = gem("opal",1,true)
	state.board.cells[Vector2i(13,10)] = gem("topaz",1,true)
	state.board.cells[Vector2i(14,10)] = gem("ruby",1,true)
	state.board.cells[Vector2i(10,11)] = gem("opal",2)
	state.placed = 5
	var guide = GemBuildGuide.new()
	guide.bind(state)
	var plan = guide.action({"type":"upgrade","count":2},p)
	var snapshot = state.snapshot()
	var result = GemTowerInfo.result_profile(plan,state.board.cells)
	check(result.timing.bonus == 230 and not result.timing.auras.has(1),"upgrade preview removes fresh Opal support that will become stone")
	check(GemTowerInfo.action_tooltip(plan,state.board.cells).contains("AFTER THIS CHOICE") and state.snapshot() == snapshot,"comparison tooltip leaves RNG, materials and pending tower choice untouched")
	state.upgrade(p,2)
	check(result == GemTowerInfo.profile(state.board.cells[p],p,state.board.cells),"previewed upgrade statistics equal the real result after starting combat")
	var old = GemRun.new(7)
	old.board.cells[p] = gem("opal")
	old.board.cells[Vector2i(11,10)] = gem("aquamarine")
	old.board.cells[Vector2i(12,10)] = gem("emerald")
	old.board.cells[Vector2i(13,10)] = gem("opal",2,true)
	guide.bind(old)
	plan = guide.action({"type":"recipe","recipe":"malachite","old_only":true},p)
	result = GemTowerInfo.result_profile(plan,old.board.cells)
	check(result.timing.bonus == 30 and not plan.starts,"old-only recipe consumes its Opal ingredient while preserving unrelated fresh support")
	old.combine("malachite",p,true)
	check(result == GemTowerInfo.profile(old.board.cells[p],p,old.board.cells) and old.phase == "build","old-only special preview equals actual post-combination timing")
	check(GemTowerInfo.result_profile(guide.denied("locked"),cells).is_empty(),"unavailable actions have no hypothetical result statistics")
	print("TOWER_INFO_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
