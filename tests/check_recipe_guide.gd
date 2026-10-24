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
	var state = GemRun.new(42)
	var before = state.snapshot()
	var empty = GemRecipeGuide.progress(state,"silver")
	check(empty.collected == 0 and empty.total == 3 and not empty.complete,"empty inventory reports all three missing Silver ingredients")
	check(GemRecipeGuide.progress(state,"unknown").is_empty(),"unknown recipe has no progress or board highlights")
	check(before == state.snapshot(),"reading empty recipe progress consumes no RNG or run state")
	state.board.cells[Vector2i(10,10)] = gem("sapphire")
	state.board.cells[Vector2i(11,10)] = gem("topaz",1,true)
	state.board.cells[Vector2i(12,10)] = gem("diamond")
	state.board.cells[Vector2i(13,10)] = gem("sapphire",2)
	state.board.cells[Vector2i(14,10)] = gem("sapphire",1,true)
	var progress = GemRecipeGuide.progress(state,"silver")
	check(progress.complete and progress.collected == 3 and not progress.old_only,"mixed kept/new ingredients complete the recipe without overstating readiness")
	check(progress.groups[0].owned.size() == 2 and progress.groups[0].older == 1 and progress.groups[0]["new"] == 1,"owned counts distinguish kept/new gems and exclude wrong qualities")
	check(progress.groups[0].owned[0] == Vector2i(10,10),"locate order prefers kept material over fresh material")
	check(progress.message.contains("all five"),"mixed recipe explains the placement requirement before final choice")
	state.placed = 5
	check(GemRecipeGuide.progress(state,"silver").message.contains("starts the wave"),"ready mixed recipe explicitly warns of immediate wave start")
	state.board.cells[Vector2i(11,10)].fresh = false
	check(GemRecipeGuide.progress(state,"silver").old_only,"all kept ingredients allow an old-only combination")
	state.phase = "combat"
	check(GemRecipeGuide.progress(state,"silver").message.contains("build phase"),"combat recipe status never offers a combination")
	state = GemRun.new(42)
	state.board.cells[Vector2i(10,10)] = gem("ruby",2)
	state.board.cells[Vector2i(11,10)] = gem("ruby",3)
	state.board.cells[Vector2i(12,10)] = gem("amethyst")
	check(GemRecipeGuide.progress(state,"asteriated_ruby").collected == 2,"Ruby III cannot stand in for required Ruby I")
	state.board.cells[Vector2i(13,10)] = gem("ruby")
	before = state.snapshot()
	var repeated = GemRecipeGuide.requirements_progress(state,[["ruby",1],["ruby",1],["amethyst",1]])
	check(repeated.collected == 2 and repeated.total == 3 and not repeated.complete and repeated.groups[0].needed == 2,"duplicate requirements cannot reuse one gem twice")
	state.board.cells[Vector2i(14,10)] = gem("ruby")
	check(GemRecipeGuide.requirements_progress(state,[["ruby",1],["ruby",1],["amethyst",1]]).complete,"two physical copies satisfy two identical requirements")
	state.board.cells.erase(Vector2i(14,10))
	check(before == state.snapshot(),"progress and sorting leave cells, inventory and RNG unchanged")
	print("RECIPE_GUIDE_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
