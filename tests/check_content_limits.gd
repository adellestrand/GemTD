extends SceneTree

const FULL: Dictionary = preload("res://data/full_reference.json").data
var checks = 0
var failures = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)
	else:
		print("PASS: "+description)

func _initialize() -> void:
	check(GemCatalog.quality_name(4) == "IV" and GemCatalog.quality_name(6) == "VI","higher qualities have consistent labels")
	check(GemCatalog.quality_limit("sapphire") == 3 and GemCatalog.quality_limit("silver") == 1,"active profile still limits base and special tiers correctly")
	check(GemCatalog.wave_count() == 10 and GemCatalog.wave(100).boss,"wave lookup clamps to the active profile final wave")
	for profile in FULL.quality_odds:
		var counts = [0,0,0,0,0,0]
		for roll in range(1,101):
			counts[GemCatalog.roll_tier(profile.weights,roll)-1] += 1
		var same = true
		for i in range(counts.size()):
			same = same and counts[i] == int(profile.weights[i])
		check(same,"all 100 roll boundaries match original quality level %d" % profile.level)
	check(GemCatalog.roll_tier([0,0,0,0,0,100],1) == 6 and GemCatalog.roll_tier([0,0,0,0,0,100],100) == 6,"quality sampler supports six columns without a third-tier fallback")
	check(GemCatalog.odds_text([10,30,30,20,10,0]).contains("VI  0%"),"odds labels can display the full six-quality source profile")
	check(GemCatalog.title({"kind":"silver","tier":1}) == "Silver","special ingredients have titles without indexing the base-gem table")
	var state = GemRun.new(42)
	state.gold = 1000
	check(state.buy_quality() and state.buy_quality() and not state.buy_quality(),"new data-driven odds limit preserves the 1.0 purchase cap")
	var snapshot = state.snapshot()
	snapshot.cells[0].gem.tier = 4
	check(not GemRun.new(1).restore(snapshot),"staging library cannot introduce unimplemented qualities through a checkpoint")
	print("CONTENT_LIMITS_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
