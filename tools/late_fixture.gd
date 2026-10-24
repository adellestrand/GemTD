extends RefCounted

static func setup(index: int, count: int = 32) -> GemCampaignCombat:
	var state = GemRun.new(8000+index)
	state.wave = index
	state.phase = "combat"
	state.enemy_count = 20
	# Source-valid units and legal maze geometry, deliberately prebuilt.
	# This is a load/composition fixture, never a naturally earned run.
	for y in [7,11,15,23,27,31]:
		var candidate = state.board.cells.duplicate(true)
		for x in range(3,34):
			if x != (4 if y%8 == 7 else 32): candidate[Vector2i(x,y)] = GemRun.stone()
		if not state.board.path_for(candidate).is_empty(): state.board.cells = candidate
	state.board.rebuild()
	var pool = ["diamond","sapphire","opal","amethyst","emerald","aquamarine","topaz","ruby","heiyaoshi","manao","jingangshikulinan","keyinuoerguangmingzhishan","palayibabixi","asteriated_ruby","silver","malachite"]
	var stones = state.board.cells.keys()
	stones.sort_custom(func(a,b): return a.y*37+a.x < b.y*37+b.x)
	for i in range(mini(count,stones.size())):
		var p: Vector2i = stones[int(i*stones.size()/float(count))]
		var kind: String = pool[i%pool.size()]
		state.board.cells[p] = {"kind":kind,"tier":mini(6,GemCatalog.quality_limit(kind)),"fresh":false,"priority":"First","mvp":mini(10,i%11)}
	var combat = GemCampaignCombat.new(state)
	combat.start()
	return combat
