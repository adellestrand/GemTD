extends "res://tests/check_campaign.gd"

func run_checks() -> void:
	check(is_equal_approx(GemCampaignRules.movement_speed(400.0/128,{"move_constant":-100,"move_percent":-50}),150.0/128),"flat movement changes apply before summed percentages")
	check(GemCampaignRules.movement_speed(400.0/128,{"move_constant":-1000,"move_percent":-80}) == 100.0/128,"movement cannot fall below the explicit 100-unit floor")
	check(is_equal_approx(GemCampaignRules.movement_speed(400.0/128,{},50),600.0/128),"Windrun adds its percentage without an invented maximum cap")
	var combat = fixture("diamond")
	var enemy: Dictionary = combat.enemies[0]
	enemy.speed = 128.0/128
	enemy.pos = Vector2(.5,.5)
	enemy.segment = 1
	enemy.current_properties = {}
	combat.ground = PackedVector2Array([Vector2(.5,.5),Vector2(1.5,.5),Vector2(1.5,1.5),Vector2(10.5,1.5)])
	combat.move_enemy(enemy,2.5)
	check(enemy.pos.is_equal_approx(Vector2(2,1.5)) and enemy.segment == 3,"distance budget preserves corners and remaining movement across multiple route segments")
	check(is_equal_approx(enemy.travelled,2.5),"travelled distance includes each crossed segment exactly once")
	enemy.current_properties = {"stunned":true}
	var before: Vector2 = enemy.pos
	combat.move_enemy(enemy,1)
	check(enemy.pos == before,"stun stops movement instead of falling back to the minimum speed")
	enemy.current_properties = {"stone_gaze":true}
	combat.move_enemy(enemy,1)
	check(enemy.pos == before,"petrification also stops movement completely")
	combat = fixture("opal")
	enemy = combat.enemies[0]
	enemy.invisible = true
	var radius = float(GemCatalog.DATA.combat.detection_radius_fallback)
	enemy.pos = Vector2(at)+Vector2(.5,.5)+Vector2(radius,0)
	check(combat.detected(enemy),"configured provisional detection radius includes its exact boundary")
	enemy.pos.x += .001
	check(not combat.detected(enemy),"invisible enemy beyond detection radius remains hidden")
	combat = fixture("diamond")
	enemy = combat.enemies[0]
	var stats = GemCatalog.stats(gem("diamond"))
	enemy.pos = Vector2(at)+Vector2(.5,.5)+Vector2(float(stats.range),0)
	check(combat.targets_for(at,gem("diamond"),stats).size() == 1,"attack range uses cell centers and includes the boundary")
	enemy.pos.x += .001
	check(combat.targets_for(at,gem("diamond"),stats).is_empty(),"range does not silently include sprite size or an extra cell")
	var state = GemRun.new(1)
	var last = -1
	var ordered = true
	for point in state.board.checkpoints:
		var index = state.board.ground_route.find(Vector2(point)+Vector2(.5,.5))
		ordered = ordered and index > last
		last = index
	check(ordered,"all seven ground checkpoints occur in order")
	check(state.board.air_route.size() == 7,"air route preserves the seven checkpoints without inheriting ground maze length")
	print("MOVEMENT_DETECTION_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
