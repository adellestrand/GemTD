extends SceneTree

func _initialize() -> void:
	call_deferred("audit")


func run_case(index: int, steps: int, tower_count: int = 32, enemy_count: int = 20, dense: bool = false) -> Dictionary:
	var combat = preload("res://tools/late_fixture.gd").setup(index,tower_count)
	combat.run.enemy_count = enemy_count
	if not combat.wave_data.boss: combat.wave_data.count = enemy_count
	if dense:
		for i in range(enemy_count): combat.spawn_enemy()
	var timings: Array[float] = []
	var peak = {"enemies":0,"projectiles":0,"delayed":0,"fields":0,"modifiers":0}
	for i in range(steps):
		var start = Time.get_ticks_usec()
		combat.tick(1.0/30.0)
		timings.append((Time.get_ticks_usec()-start)/1000.0)
		peak.enemies = maxi(peak.enemies,combat.enemies.size())
		peak.projectiles = maxi(peak.projectiles,combat.projectiles.size())
		peak.delayed = maxi(peak.delayed,combat.delayed.size())
		peak.fields = maxi(peak.fields,combat.fields.size())
		var modifiers = 0
		for enemy in combat.enemies: modifiers += enemy.mods.size()+enemy.get("aura_memory",{}).size()
		peak.modifiers = maxi(peak.modifiers,modifiers)
		if combat.run.phase != "combat": break
	timings.sort()
	var result = {"wave":index,"towers":tower_count,"enemy_count":enemy_count,"ticks":timings.size(),"phase":combat.run.phase,"simulation_seconds":snappedf(combat.elapsed,.01),"tick_ms_p50":timings[timings.size()/2],"tick_ms_p95":timings[mini(timings.size()-1,int(timings.size()*.95))],"tick_ms_max":timings.back(),"peak":peak,"diagnostics":combat.audit.snapshot()}
	print("LATE_CASE wave=%d phase=%s p95=%.3fms enemies=%d" % [index,result.phase,result.tick_ms_p95,peak.enemies])
	return result

func audit() -> void:
	var cases: Array = []
	if "--heavy-only" not in OS.get_cmdline_user_args():
		for index in [20,30,50,51,60,75,100]: cases.append(run_case(index,9000))
	var smoke: Array = []
	if "--heavy-only" not in OS.get_cmdline_user_args():
		for index in range(51,101): smoke.append(run_case(index,300))
	var heavy = run_case(99,900,64,96,true)
	var report = {"game_version":GemRelease.version(),"engine":Engine.get_version_info().string,"platform":OS.get_name(),"cases":cases,"all_trial_openings":smoke,"heavy":heavy,"limits":"Dense stress case spawns 96 enemies together, overriding only spawn scheduling. Headless debug CPU timings, excludes rendering and browser overhead. Prebuilt legal maze with source-valid units and explicit MVP values, not earned through recipes, RNG or economy. Outcomes do not establish a natural campaign win or human difficulty. Timings are hardware-specific."}
	DirAccess.make_dir_recursive_absolute("res://output")
	var file = FileAccess.open("res://output/late-game-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("LATE_GAME_AUDIT_OK cases=%d trials=%d" % [cases.size(),smoke.size()])
	quit()
