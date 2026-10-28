class_name GemBoardView
extends Control

signal cell_clicked(cell: Vector2i)
signal hover_changed(cell: Vector2i)
var run: GemRun
var combat: GemCombat
var selected = Vector2i(-1, -1)
var hovered = Vector2i(-1, -1)
var show_routes = true
var zoom = 1.0
var pan = Vector2.ZERO
var dragging = false
var effects = GemEffects.new()
var known_cells: Dictionary = {}
var guide = GemBuildGuide.new()
var action_plan: Dictionary = {}
var tracked_recipe = ""
var tracking_progress: Dictionary = {}
# Maze tip shown over the board (GemMazeTips id); empty when hidden.
var maze_tip = ""
var maze_progress: Dictionary = {}
var cell_size = 16.0
var origin = Vector2.ZERO
var clock = 0.0
var font: Font = ThemeDB.fallback_font
# Screen area the grid must fit in (between the overlays). The terrain fills the rest of the view.
var safe_rect = Rect2()
const DECOR = ["pine","fern","rocks","flowers","dry_grass"]
const VISIBLE_ROWS = 34.0
const PAN_SPEED = 900.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_exited.connect(func(): set_hover(Vector2i(-1,-1)))

const TowerMotion = preload("res://game/presentation/tower_motion.gd")
var tower_motion = TowerMotion.new()
const TerrainArt = preload("res://game/presentation/terrain_art.gd")
var terrain_art = TerrainArt.new()
var enemy_looks: Dictionary = {}
# Presentation-only smoothing: positions from the previous 30 Hz simulation step,
# eased facing (-1 left .. 1 right) and the time of the last hit for a small recoil.
var previous_positions: Dictionary = {}
var tick_alpha = 1.0
var facing: Dictionary = {}
var hit_times: Dictionary = {}

func board_area() -> Rect2:
	return safe_rect if safe_rect.size.x > 80 and safe_rect.size.y > 80 else Rect2(Vector2.ZERO,size)

func layout_board() -> void:
	var area = board_area()
	zoom = maxf(zoom,1.0)
	# Large map: at the widest zoom about 31 rows fill the window height; edges are reached by panning.
	cell_size = maxf(8.0,floorf(size.y/VISIBLE_ROWS))*zoom
	var span = 37.0*cell_size
	var base = area.position+(area.size-Vector2.ONE*span)/2.0
	var o = base+pan
	# Zoomed in: the board can be panned but never leaves the play area. At full size it is fixed.
	o.x = clampf(o.x,area.end.x-span,area.position.x) if span > area.size.x else base.x
	o.y = clampf(o.y,area.end.y-span,area.position.y) if span > area.size.y else base.y
	pan = o-base
	origin = o
	# Sprites are ~45-60 art pixels; below ~2 art px per screen px use mipmaps, above keep pixels crisp.
	var wanted = CanvasItem.TEXTURE_FILTER_NEAREST if cell_size >= 40.0 else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if texture_filter != wanted:
		texture_filter = wanted

func _process(dt: float) -> void:
	var focus = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or not is_visible_in_tree():
		return
	var direction = Vector2(
		float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S))-float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
	if direction != Vector2.ZERO:
		pan -= direction.normalized()*PAN_SPEED*dt
		layout_board()
		queue_redraw()

func board_to_screen(p: Vector2) -> Vector2:
	return origin+p*cell_size

func screen_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(((p-origin)/cell_size).floor())

func capture_positions() -> void:
	if combat == null:
		return
	for enemy in combat.enemies:
		previous_positions[int(enemy.id)] = enemy.pos

func render_position(enemy: Dictionary) -> Vector2:
	var before: Vector2 = previous_positions.get(int(enemy.id),enemy.pos)
	# Blinks and spawns jump; only interpolate ordinary movement.
	if before.distance_to(enemy.pos) > 1.5:
		return enemy.pos
	return before.lerp(enemy.pos,clampf(tick_alpha,0.0,1.0))

func update_facing(dt: float) -> void:
	if combat == null:
		return
	for enemy in combat.enemies:
		var id = int(enemy.id)
		var route: PackedVector2Array = combat.air if enemy.air else combat.ground
		var target = float(facing.get(id,1.0))
		if int(enemy.segment) < route.size():
			var dx = route[int(enemy.segment)].x-enemy.pos.x
			if absf(dx) > .01:
				target = -1.0 if dx < 0 else 1.0
		facing[id] = move_toward(float(facing.get(id,target)),target,dt*7.0)

func advance_visuals(dt: float) -> void:
	clock += dt
	update_facing(dt)
	effects.advance(dt)
	queue_redraw()

func reset_visuals() -> void:
	effects.clear()
	tower_motion.clear()
	enemy_looks.clear()
	previous_positions.clear()
	facing.clear()
	hit_times.clear()
	tick_alpha = 1.0
	clock = 0
	known_cells = run.board.cells.duplicate(true) if run != null else {}
	guide.bind(run)
	action_plan.clear()
	set_tracked_recipe("")
	# A chosen maze tip is a plan for the map, so it survives a new run.
	update_maze_tip()

func sync_board() -> void:
	if run == null:
		return
	guide.invalidate()
	for p in run.board.cells:
		var gem: Dictionary = run.board.cells[p]
		var old: Dictionary = known_cells.get(p,{})
		if old.is_empty() or old.kind != gem.kind or old.tier != gem.tier:
			var color = GemArt.gem_color(gem) if gem.kind != "stone" else Color("b3ac8d")
			effects.add("ring",Vector2(p)+Vector2(.5,.5),color,.55,{"radius":.9})
			if gem.kind != "stone":
				tower_motion.placed(p,clock)
	for p in known_cells:
		if not run.board.cells.has(p):
			effects.add("death",Vector2(p)+Vector2(.5,.5),Color("b3ac8d"),.35)
			tower_motion.forget(p)
	known_cells = run.board.cells.duplicate(true)
	update_tracking()
	update_maze_tip()

func set_tracked_recipe(recipe: String) -> void:
	tracked_recipe = recipe if not GemCatalog.recipe(recipe).is_empty() else ""
	update_tracking()

func set_maze_tip(id: String) -> void:
	maze_tip = id if not GemMazeTips.tip(id).is_empty() else ""
	update_maze_tip()

func update_maze_tip() -> void:
	maze_progress = GemMazeTips.progress(run,maze_tip) if not maze_tip.is_empty() and run != null else {}
	queue_redraw()

func update_tracking() -> void:
	tracking_progress = GemRecipeGuide.progress(run,tracked_recipe)
	queue_redraw()

func focus_cell(p: Vector2i) -> void:
	zoom = maxf(zoom,1.5)
	pan = Vector2.ZERO
	layout_board()
	pan += size*.5-board_to_screen(Vector2(p)+Vector2(.5,.5))
	layout_board()
	set_hover(Vector2i(-1,-1))
	queue_redraw()

func add_shot(from: Vector2, to: Vector2, color: Color) -> void:
	if combat is GemCampaignCombat: return # Resolved shock/chain events supply their own links.
	var kind = ""
	if run != null:
		var cell = Vector2i((from-Vector2(.5,.5)).round())
		if run.board.cells.has(cell):
			color = GemArt.gem_color(run.board.cells[cell])
			kind = run.board.cells[cell].kind
			tower_motion.fired(cell,clock)
	effects.shot(from,to,color,kind)

func add_projectile_launch(from: Vector2, _to: Vector2, color: Color) -> void:
	var settings: Dictionary = GemArt.config().get("effects",{})
	var height = float(settings.get("muzzle_height",.35))
	effects.add("muzzle",from-Vector2(0,height),color,.16)
	tower_motion.fired(Vector2i((from-Vector2(.5,.5)).round()),clock)

func enemy_damaged(enemy_id: int, position: Vector2, amount: float, damage_type: String, lethal: bool) -> void:
	effects.damaged(enemy_id,position,amount,damage_type,lethal)
	hit_times[enemy_id] = clock
	if lethal and enemy_looks.has(enemy_id):
		var look: Dictionary = enemy_looks[enemy_id]
		effects.add("ghost",position,Color.WHITE,.42,look)
		enemy_looks.erase(enemy_id)

func ability_happened(event: Dictionary) -> void:
	GemAbilityArt.receive(effects,event,run.board.cells)
	if run.board.cells.has(event.source): tower_motion.fired(event.source,clock)

func add_area_attack(position: Vector2, radius: float) -> void:
	if not combat is GemCampaignCombat: effects.area(position,radius)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if dragging:
			pan += event.relative
			layout_board()
		set_hover(screen_to_cell(event.position))
		queue_redraw()
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]:
			dragging = event.pressed
		if not event.pressed:
			return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before = (event.position-origin)/cell_size
			zoom = clampf(zoom*(1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.15), 1.0, 3.0)
			layout_board()
			pan += event.position-board_to_screen(before)
			layout_board()
			set_hover(screen_to_cell(event.position))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var p = screen_to_cell(event.position)
			if run != null and run.board.inside(p):
				cell_clicked.emit(p)

func fit_board() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()

func set_hover(p: Vector2i) -> void:
	if hovered == p:
		return
	hovered = p
	hover_changed.emit(p)
	queue_redraw()

func _draw() -> void:
	layout_board()
	draw_rect(Rect2(Vector2.ZERO, size), GemArt.color("grass").darkened(.3))
	if run == null:
		return
	var rect = Rect2(origin, Vector2.ONE*37*cell_size)
	draw_surroundings()
	draw_rect(rect.grow(5), Color("081315"))
	var terrain: Dictionary = GemArt.config().get("terrain",{})
	if not terrain_art.draw(self,origin,cell_size,37,37,terrain):
		for y in range(37):
			for x in range(37):
				var p = Vector2i(x,y)
				var shade = (x*17+y*31+x*y*7)%9
				var c = GemArt.color("grass").lightened(float(shade)*float(terrain.get("variation",.02))/8.0)
				if x == 0 or y == 0 or x == 36 or y == 36:
					c = c.darkened(float(terrain.get("edge_shade",.12)))
				draw_rect(Rect2(board_to_screen(Vector2(p)), Vector2.ONE*cell_size), c)
				if (x*13+y*7)%int(terrain.get("detail_stride",11)) == 0:
					var tuft = board_to_screen(Vector2(p)+Vector2(.25,.65))
					draw_line(tuft,tuft+Vector2(0,-.12)*cell_size,c.lightened(.09),1)
					draw_line(tuft+Vector2(.13,0)*cell_size,tuft+Vector2(.18,-.1)*cell_size,c.darkened(.08),1)
		for i in range(38):
			draw_line(origin+Vector2(i,0)*cell_size, origin+Vector2(i,37)*cell_size, Color(GemArt.color("grid"),.25))
			draw_line(origin+Vector2(0,i)*cell_size, origin+Vector2(37,i)*cell_size, Color(GemArt.color("grid"),.25))
	# Route lines only when the player ticks "Show routes" (main.gd); the placement preview stays.
	if show_routes:
			draw_route(run.board.ground_route, Color(GemArt.color("route_ground"),.62), false)
			draw_route(run.board.air_route, Color(GemArt.color("route_air"),.72), true)
	var placement = guide.placement(hovered)
	if placement.status == "place":
		draw_route(placement.route,Color(GemArt.color("route_preview"),.8),false)
	for i in range(run.board.checkpoints.size()):
		var pos = board_to_screen(Vector2(run.board.checkpoints[i])+Vector2(0.5,0.5))
		GemArt.draw(self,"checkpoint",pos,cell_size)
		draw_circle(pos,cell_size*.3,Color("293732"))
		draw_string(font, pos+Vector2(-4,4), str(i+1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f3dcaa"))
	if run.board.cells.has(selected):
		var range_cells = float(GemTowerInfo.profile(run.board.cells[selected],selected,run.board.cells,combat).get("range",0)) if GemCatalog.campaign() else GemCatalog.effective_range(run.board.cells[selected])
		if range_cells > 0:
			var center = board_to_screen(Vector2(selected)+Vector2(0.5,0.5))
			draw_circle(center, range_cells*cell_size, Color(0.75,0.85,0.6,0.045))
			draw_arc(center, range_cells*cell_size, 0,TAU,64,Color(0.85,0.85,0.55,0.45),1)
	for p in run.board.slabs:
		var center = board_to_screen(Vector2(p)+Vector2(.5,.5))
		GemReadability.trap(self,center,cell_size,run.board.slabs[p])
	draw_maze_guide()
	draw_recipe_guides()
	draw_material_guides()
	var actors: Array[Dictionary] = []
	if bool(effects.settings().get("enabled",true)):
		GemAbilityArt.draw_mvp_fields(self,run.board.cells,selected,origin,cell_size,clock)
	if combat is GemCampaignCombat and run.phase == "combat" and bool(effects.settings().get("enabled",true)):
		GemAbilityArt.draw_fields(self,combat as GemCampaignCombat,selected,origin,cell_size,clock)
	effects.begin_frame()
	for p in run.board.cells:
		actors.append({"y":float(p.y)+.5,"order":p.x,"cell":p})
	if combat != null and run.phase in ["combat", "lost"]:
		for enemy in combat.enemies:
			actors.append({"y":float(enemy.pos.y),"order":100+int(enemy.id),"enemy":enemy})
	actors.sort_custom(func(a,b): return a.y < b.y if a.y != b.y else a.order < b.order)
	for actor in actors:
		if actor.has("cell"):
			draw_gem(actor.cell,run.board.cells[actor.cell])
		else:
			draw_enemy(actor.enemy)
	draw_maze_removals()
	if run.phase == "build" and action_plan.get("valid",false):
		for p in action_plan.removed:
			var position = board_to_screen(Vector2(p)+Vector2(.5,.5))
			draw_line(position-Vector2.ONE*cell_size*.4,position+Vector2.ONE*cell_size*.4,GemArt.color("placement_blocked"),2)
			draw_line(position+Vector2(-.4,.4)*cell_size,position+Vector2(.4,-.4)*cell_size,GemArt.color("placement_blocked"),2)
	if run.board.inside(hovered):
		var tint = Color(0.9,0.9,0.73,0.7)
		if placement.status in ["place","blocked"]:
			tint = GemArt.color("placement_ok" if placement.status == "place" else "placement_blocked")
			var center = board_to_screen(Vector2(hovered)+Vector2(.5,.5))
			if placement.status == "place":
				var r = cell_size*.22
				draw_polyline(PackedVector2Array([center+Vector2(0,-r),center+Vector2(r,0),center+Vector2(0,r),center+Vector2(-r,0),center+Vector2(0,-r)]),Color(tint,.6),1)
			else:
				draw_line(center-Vector2.ONE*cell_size*.3,center+Vector2.ONE*cell_size*.3,tint,2)
				draw_line(center+Vector2(-.3,.3)*cell_size,center+Vector2(.3,-.3)*cell_size,tint,2)
		draw_rect(Rect2(board_to_screen(Vector2(hovered)),Vector2.ONE*cell_size),tint,false,1.5)
	if run.board.inside(selected):
		draw_rect(Rect2(board_to_screen(Vector2(selected)),Vector2.ONE*cell_size).grow(2),GemArt.color("selection"),false,2)
	GemFreshGems.draw(self,run,origin,cell_size)
	effects.draw(self,origin,cell_size,font)
	if combat is GemCampaignCombat and run.phase == "combat":
		effects.draw_projectiles(self,(combat as GemCampaignCombat).projectiles,origin,cell_size)
	draw_rect(rect,GemArt.color("border"),false,2)
	for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		draw_rect(Rect2(corner-Vector2(3,3),Vector2(6,6)),Color("c9b77c"))
	if run.phase in ["won", "lost"]:
		var area = board_area()
		var banner = Rect2(Vector2(area.position.x+20,area.get_center().y-60),Vector2(area.size.x-40,120))
		draw_rect(banner,Color(0.035,0.07,0.09,.94))
		draw_string(font,Vector2(banner.position.x,banner.position.y+52),"VICTORY" if run.phase == "won" else "DEFEAT",HORIZONTAL_ALIGNMENT_CENTER,banner.size.x,34,Color("e4d4a4"))
		draw_string(font,Vector2(banner.position.x,banner.position.y+83),"Use the Run menu or the result controls to play again.",HORIZONTAL_ALIGNMENT_CENTER,banner.size.x,15,Color("c3d1c8"))

# Decorative meadow around the play grid, aligned to the same cells so it reads as one map.
func draw_surroundings() -> void:
	var x0 = int(floor(-origin.x/cell_size))-1
	var y0 = int(floor(-origin.y/cell_size))-1
	var x1 = int(ceil((size.x-origin.x)/cell_size))+1
	var y1 = int(ceil((size.y-origin.y)/cell_size))+1
	var base = GemArt.color("grass").darkened(.2)
	var decor: Array = []
	for y in range(y0,y1):
		for x in range(x0,x1):
			if x >= 0 and x < 37 and y >= 0 and y < 37:
				continue
			var h = posmod(x*73856093^y*19349663,1009)
			var gap = maxi(maxi(-x,x-36),maxi(-y,y-36))
			var c = base.lightened(float(h%9)*.004).darkened(.12 if gap == 1 else 0.0)
			draw_rect(Rect2(board_to_screen(Vector2(x,y)),Vector2.ONE*cell_size),c)
			if gap >= 2:
				var pick = h%37
				if pick < 3: decor.append([DECOR[0],Vector2(x,y),1.7])
				elif pick < 5: decor.append([DECOR[1],Vector2(x,y),1.0])
				elif pick == 5: decor.append([DECOR[2],Vector2(x,y),1.0])
				elif pick == 6: decor.append([DECOR[3],Vector2(x,y),.9])
				elif pick < 10: decor.append([DECOR[4],Vector2(x,y),.8])
	for d in decor:
		GemArt.draw(self,d[0],board_to_screen(d[1]+Vector2(.5,.5)),cell_size*float(d[2]))

# Maze tip: cells still to build get a tinted fill and outline (fainter during combat);
# starting stones the tip needs gone get a dashed box and cross on top of the stone.
func draw_maze_guide() -> void:
	if maze_progress.is_empty():
		return
	var color = GemMazeBook.guide_color()
	var building = run.phase == "build"
	for p in maze_progress.build:
		var r = Rect2(board_to_screen(Vector2(p)),Vector2.ONE*cell_size)
		draw_rect(r.grow(-cell_size*.08),Color(color,(.2+.06*sin(clock*2.5)) if building else .08))
		draw_rect(r.grow(-cell_size*.08),Color(color,.85 if building else .35),false,1.5)

func draw_maze_removals() -> void:
	if maze_progress.is_empty() or run.phase != "build":
		return
	for p in maze_progress.remove:
		var r = Rect2(board_to_screen(Vector2(p)),Vector2.ONE*cell_size).grow(-1)
		var c = r.get_center()
		var d = cell_size*.3
		for edge in [[r.position,Vector2(r.end.x,r.position.y)],[Vector2(r.end.x,r.position.y),r.end],[r.end,Vector2(r.position.x,r.end.y)],[Vector2(r.position.x,r.end.y),r.position]]:
			draw_dashed_line(edge[0],edge[1],GemMazeBook.REMOVE,1.5,4)
		draw_line(c-Vector2(d,d),c+Vector2(d,d),GemMazeBook.REMOVE,2)
		draw_line(c+Vector2(-d,d),c+Vector2(d,-d),GemMazeBook.REMOVE,2)

func draw_recipe_guides() -> void:
	if tracking_progress.is_empty() or action_plan.get("valid",false):
		return
	for group in tracking_progress.groups:
		for p in group.owned:
			draw_rect(Rect2(board_to_screen(Vector2(p)),Vector2.ONE*cell_size).grow(1),GemArt.color("recipe_tracking"),false,2)

func draw_material_guides() -> void:
	if run.phase != "build":
		return
	if not action_plan.get("valid",false):
		var matching = run.matching_new(selected)
		if matching.size() > 1 and int(run.board.cells[selected].tier) < GemCatalog.quality_limit(run.board.cells[selected].kind):
			for p in matching:
				draw_rect(Rect2(board_to_screen(Vector2(p)),Vector2.ONE*cell_size).grow(2),Color(GemArt.color("material"),.7),false,1)
		return
	var at: Vector2i = action_plan.result_at
	var center = board_to_screen(Vector2(at)+Vector2(.5,.5))
	for p in action_plan.stones:
		draw_rect(Rect2(board_to_screen(Vector2(p)),Vector2.ONE*cell_size),Color(GemArt.color("will_be_stone"),.3))
	for p in action_plan.materials:
		var position = board_to_screen(Vector2(p)+Vector2(.5,.5))
		if p != at:
			draw_dashed_line(position,center,Color(GemArt.color("material"),.55),1,5)
		draw_rect(Rect2(board_to_screen(Vector2(p)),Vector2.ONE*cell_size).grow(3),GemArt.color("material"),false,2)
	if not action_plan.result.is_empty():
		draw_rect(Rect2(board_to_screen(Vector2(at)),Vector2.ONE*cell_size).grow(5),GemArt.color("selection"),false,2)

func draw_route(route: PackedVector2Array, color: Color, dashed: bool) -> void:
	for i in range(1, route.size()):
		var a = board_to_screen(route[i-1])
		var b = board_to_screen(route[i])
		if dashed:
			draw_dashed_line(a,b,color,1.2,6.0)
		else:
			draw_line(a,b,color,1.5)

func draw_gem(p: Vector2i, gem: Dictionary) -> void:
	var center = board_to_screen(Vector2(p)+Vector2(0.5,0.5))
	var s = cell_size
	var art_id = GemArt.sprite_id("gems",gem.kind,int(gem.tier))
	if GemArt.texture(art_id) != null:
		if gem.fresh:
			draw_circle(center,s*.5,Color(GemArt.gem_color(gem),.16+.04*sin(clock*3)))
		var pose = tower_motion.pose(p,clock)
		var bounds = GemArt.sprite_rect(art_id,center,s)
		var base_shift = Vector2(0,(1.0-pose.scale.y)*(bounds.end.y-center.y))
		var flash = 1.0+.55*float(pose.flash)
		GemArt.draw(self,art_id,center+base_shift,s,false,Color(flash,flash,flash*.95),pose.scale,0.0,GemArt.idle_frame(art_id,clock))
		if float(pose.glow) > .01:
			var crystal = Vector2(center.x,bounds.position.y+bounds.size.y*.2)+base_shift
			var glow_color = GemArt.gem_color(gem).lightened(.35)
			draw_circle(crystal,s*.30,Color(glow_color,float(pose.glow)*.45))
			draw_circle(crystal,s*.17,Color(glow_color,float(pose.glow)*.8))
		var disabled = false
		if combat is GemCampaignCombat and run.phase == "combat" and combat.towers.has(p):
			disabled = float(combat.towers[p].disabled) > combat.elapsed or float(combat.towers[p].get("hostile_disarm_until",0)) > combat.elapsed
		GemReadability.tower(self,center,s,gem,selected == p,disabled)
		if bool(effects.settings().get("enabled",true)):
			GemAbilityArt.draw_mvp_crown(self,center,cell_size,gem)
		return
	if gem.kind == "stone":
		var stone_points = PackedVector2Array([center+Vector2(-.35,.29)*s,center+Vector2(-.4,-.05)*s,center+Vector2(-.17,-.3)*s,center+Vector2(.25,-.25)*s,center+Vector2(.39,.12)*s,center+Vector2(.21,.34)*s])
		draw_colored_polygon(stone_points,Color("1d2b2c"))
		draw_rect(Rect2(center+Vector2(-.22,-.19)*s,Vector2(.42,.3)*s),Color("78837b"))
		draw_line(center+Vector2(-.22,-.19)*s,center+Vector2(.15,-.19)*s,Color("a2ab91"),maxf(1,s*.07))
		return
	var color = GemCatalog.color_of(gem)
	var special = GemCatalog.DATA.specials.has(gem.kind)
	if gem.fresh:
		draw_circle(center,s*.64,Color(color,0.14+0.05*sin(clock*3)))
	# A compact roof/front pedestal gives a useful silhouette before final pixel art.
	draw_rect(Rect2(center+Vector2(-.4,.13)*s,Vector2(.8,.36)*s),Color("0b171e"))
	draw_rect(Rect2(center+Vector2(-.31,.15)*s,Vector2(.62,.23)*s),Color("929687") if not special else Color("b6a979"))
	draw_line(center+Vector2(-.31,.15)*s,center+Vector2(.31,.15)*s,Color("d6cfad"),maxf(1,s*.06))
	var r = s*(.42 if special else .31)
	var points = PackedVector2Array([center+Vector2(0,-1.05)*r,center+Vector2(.75,-.4)*r,center+Vector2(.5,.65)*r,center+Vector2(-.5,.65)*r,center+Vector2(-.75,-.4)*r])
	draw_colored_polygon(points,Color("0c1825"))
	var inner = PackedVector2Array()
	for v in points:
		inner.append(center+(v-center)*.77)
	draw_colored_polygon(inner,color)
	draw_line(center+Vector2(-.31,-.27)*r,center+Vector2(0,-.73)*r,color.lightened(.55),maxf(1,s*.08))
	draw_line(center+Vector2(0,-.65)*r,center+Vector2(0,.4)*r,color.lightened(.25),maxf(1,s*.06))
	for i in range(int(gem.tier)):
		draw_rect(Rect2(center+Vector2((float(i)-(float(gem.tier)-1)/2.0)*.18,.43)*s,Vector2(.1,.1)*s),Color("f3d48d"))
	if special:
		draw_arc(center,s*.52,0,TAU,16,Color(color,.7),1)

func draw_enemy(enemy: Dictionary) -> void:
	if enemy.dead or enemy.escaped:
		return
	var center = board_to_screen(render_position(enemy))
	var clip_fx = combat is GemCampaignCombat and bool(effects.settings().get("enabled",true))
	var s = cell_size*(1.7 if enemy.boss else 1.0)
	var art_id = GemArt.sprite_id("enemies",enemy.source_id)
	if GemArt.texture(art_id) != null:
		var animation_time = combat.elapsed if combat != null else 0.0
		var motion = GemArt.enemy_motion(art_id,float(enemy.travelled),animation_time,int(enemy.id),bool(enemy.air))
		# Shadow stays on the ground and shrinks a little while the body is up.
		var height = clampf(-float(motion.offset.y),0.0,1.0)
		draw_ellipse_shadow(center,cell_size*(.65 if enemy.boss else .4)*(1.0-height*.35))
		var face = float(facing.get(int(enemy.id),1.0))
		var flip = face < 0.0
		var deformation: Vector2 = motion.scale
		# Turning: the sprite narrows through its edge instead of snapping round.
		deformation.x *= maxf(.18,absf(face))
		var rotation = float(motion.rotation)+float(motion.get("lean",0.0))*signf(face if face != 0.0 else 1.0)
		var since_hit = clock-float(hit_times.get(int(enemy.id),-10.0))
		var offset: Vector2 = motion.offset
		if since_hit < .16:
			var punch = 1.0-since_hit/.16
			deformation *= Vector2(1.0-.1*punch,1.0+.08*punch)
			offset.x -= .06*punch*signf(face if face != 0.0 else 1.0)
		var tint = Color(1.45,1.35,1.15) if effects.flashes.has(int(enemy.id)) else Color.WHITE
		if combat is GemCampaignCombat and enemy.get("invisible",false) and not combat.detected(enemy): tint.a = .38
		tint.a *= clampf(.2+float(enemy.travelled)*2.0,.2,1.0)
		enemy_looks[int(enemy.id)] = {"art":art_id,"flip":flip,"boss":bool(enemy.boss)}
		var frame = GemArt.enemy_frame(art_id,float(enemy.travelled),animation_time,int(enemy.id),bool(enemy.air))
		# PixelLab status/hit clips wrap the sprite: behind layers, sprite, front layers.
		var looks: Array[String] = GemAbilityArt.statuses(enemy,combat.elapsed,effects) if clip_fx else []
		var status_tint = GemAbilityArt.status_tint(looks)
		tint = Color(tint.r*status_tint.r,tint.g*status_tint.g,tint.b*status_tint.b,tint.a)
		var body = GemArt.sprite_rect(art_id,center+offset*cell_size,cell_size)
		if clip_fx: GemAbilityArt.draw_enemy_layer(self,enemy,body,flip,combat.elapsed,effects,"behind",looks,tint.a)
		var sprite_rect = GemArt.draw(self,art_id,center+offset*cell_size,cell_size,flip,tint,deformation,rotation,frame)
		var overlay = GemAbilityArt.status_overlay(looks)
		if overlay.a > 0:
			overlay.a *= tint.a
			GemArt.draw(self,art_id,center+offset*cell_size,cell_size,flip,overlay,deformation,rotation,frame,GemArt.grey_frame(art_id,frame))
		if clip_fx: GemAbilityArt.draw_enemy_layer(self,enemy,body,flip,combat.elapsed,effects,"front",looks,tint.a)
		var bar_pos = Vector2(center.x-cell_size*.43,sprite_rect.position.y-4)
		draw_rect(Rect2(bar_pos-Vector2.ONE,Vector2(cell_size*.86+2,4)),Color("142221"))
		draw_rect(Rect2(bar_pos,Vector2(cell_size*.86*clampf(enemy.hp/enemy.hp_max,0,1),2)),GemArt.color("health"))
		GemReadability.enemy(self,Vector2(center.x,sprite_rect.position.y-12+cell_size*.65),cell_size,enemy)
		if clip_fx: return
		if enemy.slow > 0:
			draw_arc(center,cell_size*.5,0,TAU,12,GemArt.color("slow"),1)
		if not enemy.poisons.is_empty():
			draw_circle(center+Vector2(cell_size*.4,-cell_size*.5),2,GemArt.color("poison"))
		if enemy.armor_debuff > 0:
			draw_line(center+Vector2(-.25,.2)*cell_size,center+Vector2(.25,.55)*cell_size,GemArt.color("armor"),maxf(1,cell_size*.07))
		return
	var c = Color("c8a97c") if not enemy.air else Color("91bde5")
	if enemy.boss:
		c = Color("ef8977")
	draw_circle(center+Vector2(1,3),s*.33,Color(0,0,0,.25))
	if enemy.air:
		draw_colored_polygon(PackedVector2Array([center+Vector2(-.65,-.25)*s,center+Vector2(0,.1)*s,center+Vector2(.65,-.25)*s,center+Vector2(0,.45)*s]),c.darkened(.2))
	draw_rect(Rect2(center-Vector2(.24,.3)*s,Vector2(.48,.55)*s),Color("15222a"))
	draw_rect(Rect2(center-Vector2(.18,.24)*s,Vector2(.36,.43)*s),c)
	draw_rect(Rect2(center+Vector2(-.1,-.16)*s,Vector2(.09,.08)*s),Color("fff0cd"))
	draw_rect(Rect2(center+Vector2(-.4,-.52)*s,Vector2(.8,.1)*s),Color("172328"))
	draw_rect(Rect2(center+Vector2(-.4,-.52)*s,Vector2(.8*maxf(0,enemy.hp/enemy.hp_max),.1)*s),Color("9bd98c"))
	if enemy.slow > 0:
		draw_arc(center,s*.4,0,TAU,10,Color("77ccff"),1)

func draw_ellipse_shadow(center: Vector2, radius: float) -> void:
	draw_set_transform(center,0,Vector2(1,.4))
	draw_circle(Vector2.ZERO,radius,Color(0.02,.08,.05,.3))
	draw_set_transform(Vector2.ZERO)
