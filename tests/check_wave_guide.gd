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

func gem(kind: String, fresh: bool = false) -> Dictionary:
	return {"kind":kind,"tier":1,"fresh":fresh,"priority":"First"}

func _initialize() -> void:
	var state = GemRun.new(42)
	var before = state.snapshot()
	var all_match = true
	for i in range(1,11):
		var info = GemWaveGuide.inspect(state,i)
		all_match = all_match and info.wave == GemCatalog.DATA.waves[i-1] and info.index == i
	check(all_match,"all ten inspected waves preserve the catalog's exact values and order")
	check(before == state.snapshot(),"inspecting future waves does not advance RNG, wave, economy or tower choice")
	check(GemWaveGuide.inspect(state,0).is_empty() and GemWaveGuide.inspect(state,11).is_empty() and GemWaveGuide.inspect(null,1).is_empty(),"invalid wave selections are rejected rather than silently clamped")
	var info = GemWaveGuide.inspect(state,1)
	info.wave.hp = 999
	check(GemCatalog.wave(1).hp != 999,"inspection returns independent wave data, protecting the catalog")
	state.wave = 5
	check(GemWaveGuide.status(state,4) == "Cleared" and GemWaveGuide.status(state,5) == "Next" and GemWaveGuide.status(state,6) == "Upcoming","build progress distinguishes cleared, next and upcoming waves")
	state.phase = "combat"
	check(GemWaveGuide.status(state,5) == "Fighting","combat marks the current wave as fighting")
	state.phase = "lost"
	check(GemWaveGuide.status(state,5) == "Defeat" and GemWaveGuide.status(state,6) == "Not reached","defeat never marks the failed wave as cleared")
	state.wave = 10
	state.phase = "won"
	check(GemWaveGuide.status(state,10) == "Victory" and GemWaveGuide.status(state,9) == "Cleared","victory distinguishes the final boss from previously cleared waves")
	state.board.cells[Vector2i(10,10)] = gem("diamond")
	state.board.cells[Vector2i(11,10)] = gem("sapphire")
	state.board.cells[Vector2i(12,10)] = gem("asteriated_ruby")
	state.board.cells[Vector2i(13,10)] = gem("ruby",true)
	state.board.cells[Vector2i(14,10)] = gem("opal",true)
	var air = GemWaveGuide.coverage(state,true)
	var ground = GemWaveGuide.coverage(state,false)
	check(air.kept == 2 and air.kept_total == 3 and air.fresh == 1 and air.fresh_total == 2,"air eligibility excludes ground-only towers and separates fresh candidates from kept defense")
	check(ground.kept == 3 and ground.fresh == 2 and ground.kept_total == 3,"ground eligibility includes aura/support towers but never counts stones")
	info = GemWaveGuide.inspect(state,5)
	check(info.route.contains("over obstacles") and not GemWaveGuide.inspect(state,4).route.contains("over obstacles"),"route descriptions distinguish air paths from the ground maze")
	check(GemWaveGuide.inspect(state,10).leak.contains("regardless of remaining lives") and GemWaveGuide.inspect(state,9).leak.contains("4 lives"),"boss leak is immediate defeat rather than an ordinary fixed life cost")
	var damage = GemWaveGuide.damage_preview(GemCatalog.wave(9))
	check(is_equal_approx(damage.physical,100.0/1.3) and is_equal_approx(damage.magical,110) and damage.pure == 100,"damage preview uses the actual armor, negative magic resistance and pure damage rules")
	check(is_equal_approx(damage.physical,GemWaveGuide.damage_preview(GemCatalog.wave(6)).physical),"evasion is not silently averaged into landed-hit damage")
	var custom = GemCatalog.wave(9).duplicate(true)
	custom.evasion = .25
	check(GemWaveGuide.brief(custom).contains("25%") and not GemWaveGuide.brief(custom).contains("50%"),"sidebar evasion percentage comes from data rather than a fixed string")
	print("WAVE_GUIDE_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
