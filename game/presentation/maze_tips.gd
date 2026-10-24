class_name GemMazeTips
extends RefCounted

# Maze tips: the Dota 2 GemTD maze guide layouts (mode.lua, _G.maze_coop1..8) with our own names
# and summaries. Presentation only – reading the board never changes it. See docs/maze-tips.md.
const Layouts = preload("res://game/presentation/maze_tip_layouts.gd")

# "players": which player counts the Dota version offers the layout to (show_maze_guide).
# Names and summaries are ours; the source only shows the layouts as numbered pictures.
const TIPS = [
	{"id":"maze_coop1","name":"Diagonal Spiral","players":[1],
		"summary":"A double diagonal corridor from checkpoint 4 feeds a compact spiral round the centre. The smallest guide – a good first maze."},
	{"id":"maze_coop2","name":"Twin Spirals","players":[1,2],
		"summary":"Two spirals beside the centre and a long V-funnel down to checkpoint 6. A wall through checkpoint 4 stretches the 3 → 4 leg."},
	{"id":"maze_coop4","name":"Diamond","players":[1],
		"summary":"A centre spiral plus a big diamond around checkpoint 6. Short walls beside checkpoints 2 and 4 make enemies turn back on themselves."},
	{"id":"maze_coop3","name":"Spiral Corridor","players":[2],
		"summary":"A wider centre spiral with the diagonal corridor from checkpoint 4. Enemies circle the middle on every pass."},
	{"id":"maze_coop6","name":"Square Spiral","players":[2,3],
		"summary":"Square rings stacked round the centre and a diagonal corridor from checkpoint 4. Long straight lanes for line and splash towers."},
	{"id":"maze_coop5","name":"Nested Rings","players":[3,4],
		"summary":"Concentric rings fill the middle of the map; every leg through the centre walks the full ring."},
	{"id":"maze_coop8","name":"Twin Diamonds","players":[3,4],
		"summary":"Two diamond coils above and below the centre with a diagonal tail towards checkpoint 6. The longest route of all guides."},
	{"id":"maze_coop7","name":"Grand Labyrinth","players":[4],
		"summary":"Rings cover almost the whole middle of the map. The most stones of any guide – a late-game target."},
]
const PLACEMENTS_PER_ROUND = 5

static func tips() -> Array:
	return TIPS

static func tip(id: String) -> Dictionary:
	for entry in TIPS:
		if entry.id == id: return entry
	return {}

static func players_text(id: String) -> String:
	var players: Array = tip(id).get("players",[])
	if players == [1]: return "Dota solo guide"
	var parts: PackedStringArray = []
	for count in players: parts.append(str(count))
	return ("Dota solo + %s-player guide" % "/".join(parts.slice(1))) if players.has(1) else ("Dota %s-player guide" % "/".join(parts))

static func cells(id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var rows: Array = Layouts.LAYOUTS.get(id,{}).get("rows",[])
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			if row[x] == "#": result.append(Vector2i(x,y))
	return result

# Starting stones the layout needs gone in this engine (no diagonal corner passage).
static func removals(id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p in Layouts.LAYOUTS.get(id,{}).get("remove",[]):
		result.append(Vector2i(int(p[0]),int(p[1])))
	return result

static func starting_stones() -> Dictionary:
	var stones = {}
	for p in GemCatalog.DATA.map.stones: stones[Vector2i(int(p[0]),int(p[1]))] = true
	return stones

# Board state against a tip: cells still to build, cells already blocked, stones to demolish.
static func progress(run: GemRun, id: String) -> Dictionary:
	var build: Array[Vector2i] = []
	var done: Array[Vector2i] = []
	var remove: Array[Vector2i] = []
	for p in cells(id):
		if run != null and run.board.cells.has(p): done.append(p)
		else: build.append(p)
	for p in removals(id):
		if run == null or run.board.cells.has(p): remove.append(p)
	return {"build":build,"done":done,"remove":remove,"total":build.size()+done.size(),
		"rounds":ceili(float(build.size())/PLACEMENTS_PER_ROUND)}

# Ground route length in cells with the finished layout on the starting map (empty for no tip).
static func route_length(board: GemBoard, id: String) -> float:
	var obstacles = starting_stones()
	for p in removals(id): obstacles.erase(p)
	for p in cells(id): obstacles[p] = true
	return length_of(board.path_for(obstacles))

static func base_route_length(board: GemBoard) -> float:
	return length_of(board.path_for(starting_stones()))

static func length_of(route: PackedVector2Array) -> float:
	var total = 0.0
	for i in range(1,route.size()): total += route[i-1].distance_to(route[i])
	return total
