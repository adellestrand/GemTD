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

func gem(kind: String, tier: int = 1, fresh: bool = true) -> Dictionary:
	return {"kind":kind,"tier":tier,"fresh":fresh,"priority":"First"}

func five(tier: int = 1) -> GemRun:
	var state = GemRun.new(42)
	for x in range(10,15):
		state.board.cells[Vector2i(x,10)] = gem("ruby",tier)
	state.placed = 5
	state.board.rebuild()
	return state

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var state = GemRun.new(42)
	var guide = GemBuildGuide.new()
	guide.bind(state)
	var before = state.snapshot()
	var hint = guide.placement(Vector2i(5,4))
	check(hint.status == "place" and not hint.route.is_empty(),"empty valid cell supplies a complete route preview")
	for i in range(20):
		guide.placement(Vector2i(5,4))
		guide.placement(state.board.checkpoints[0])
	check(before == state.snapshot() and state.placed == 0,"repeated hover previews neither reveal nor mutate RNG, board or run")
	check(guide.placement(state.board.checkpoints[0]).status == "blocked","checkpoint hover is rejected before clicking")
	state.place(Vector2i(5,4))
	check(state.board.ground_route == hint.route,"real placement produces exactly the previewed ground route")
	check(guide.placement(Vector2i(5,4)).status == "idle","occupied cell offers selection rather than placement")
	check_route_invalidation()
	state = five()
	guide.bind(state)
	before = state.snapshot()
	var selected = Vector2i(12,10)
	var plan = guide.action({"type":"upgrade","count":4},selected)
	check(plan.valid and plan.result_at == selected and plan.result.tier == 3 and plan.materials[0] == selected,"upgrade preview places quality III at the chosen ingredient")
	check(before == state.snapshot(),"combination previews do not consume gems or RNG")
	state.upgrade(selected,4)
	check(matches_plan(state,plan) and state.phase == "combat","real four-gem upgrade matches result and every previewed stone")
	state = five(3)
	guide.bind(state)
	check(not guide.action({"type":"upgrade","count":2},selected).valid,"over-cap upgrades show no actionable preview")
	state.placed = 4
	check(not guide.action({"type":"keep"},selected).valid,"final-choice preview stays locked before five placements")
	check(not guide.action({"type":"demolish"},selected).valid,"fresh gems never offer a demolition preview")
	check_recipes()
	state = five()
	guide.bind(state)
	plan = guide.action({"type":"keep"},selected)
	state.keep(selected)
	check(matches_plan(state,plan) and state.phase == "combat","Keep preview matches conversion of all other new gems")
	check(not guide.action({"type":"keep"},selected).valid,"combat clears availability of building previews")
	print("BUILD_GUIDE_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func matches_plan(state: GemRun, plan: Dictionary) -> bool:
	var result: Dictionary = state.board.cells[plan.result_at]
	if result.kind != plan.result.kind or int(result.tier) != int(plan.result.tier):
		return false
	for p in plan.stones:
		if state.board.cells[p].kind != "stone":
			return false
	return true

func check_route_invalidation() -> void:
	var state = GemRun.new(42)
	var checkpoint = state.board.checkpoints[0]
	var last_exit = checkpoint+Vector2i.RIGHT
	for dx in range(-1,2):
		for dy in range(-1,2):
			var p = checkpoint+Vector2i(dx,dy)
			if p != checkpoint and p != last_exit:
				state.board.cells[p] = GemRun.stone()
	state.board.rebuild()
	var view = GemBoardView.new()
	view.run = state
	view.reset_visuals()
	state.changed.connect(view.sync_board)
	var before = state.snapshot()
	check(view.guide.placement(last_exit).status == "blocked" and not state.board.ground_route.is_empty(),"hover detects closing the final checkpoint exit")
	check(not state.place(last_exit) and before == state.snapshot(),"blocked hover agrees with rejected action and preserves RNG")
	state.demolish(checkpoint+Vector2i.DOWN)
	check(view.guide.placement(last_exit).status == "place","board changes invalidate cached blocked-route previews")
	view.free()

func check_recipes() -> void:
	var state = GemRun.new(42)
	var p = Vector2i(10,10)
	state.board.cells[p] = gem("sapphire",1,false)
	state.board.cells[Vector2i(11,10)] = gem("topaz",1,false)
	state.board.cells[Vector2i(12,10)] = gem("diamond",1,false)
	var guide = GemBuildGuide.new()
	guide.bind(state)
	var plan = guide.action({"type":"recipe","recipe":"silver","old_only":true},p)
	check(plan.valid and not plan.starts and plan.stones.size() == 2,"old-only recipe preview preserves the pending tower choice")
	state.combine("silver",p,true)
	check(matches_plan(state,plan) and state.phase == "build" and state.placed == 0,"old-only recipe outcome matches its preview without starting combat")
	state = GemRun.new(42)
	state.board.cells[p] = gem("sapphire",1,false)
	state.board.cells[Vector2i(12,10)] = gem("diamond",1,false)
	for pair in [[11,"topaz"],[13,"ruby"],[14,"opal"],[15,"sapphire"],[16,"emerald"]]:
		state.board.cells[Vector2i(pair[0],10)] = gem(pair[1])
	guide.bind(state)
	state.placed = 4
	check(not guide.action({"type":"recipe","recipe":"silver"},p).valid,"mixed recipe preview requires all five new placements")
	state.placed = 5
	plan = guide.action({"type":"recipe","recipe":"silver"},p)
	check(plan.valid and plan.starts and plan.stones.size() == 6,"mixed recipe preview includes old consumed material and all discarded fresh gems")
	state.combine("silver",p)
	check(matches_plan(state,plan) and state.phase == "combat","mixed recipe matches every previewed conversion and starts immediately")
