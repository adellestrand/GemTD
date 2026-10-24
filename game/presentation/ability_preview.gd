class_name GemAbilityPreview
extends Control

# Isolated, unsaved combat demonstration. Durable stationary targets make damage
# and aura ticks visible; real campaign ability code determines every proc.
var kind = "asteriated_ruby"
var playing = true
var combat: GemCampaignCombat
var fx = GemEffects.new()
var accumulator = 0.0
var total = 0.0
const AT = Vector2i(3,3)
const UNIT = 36.0

func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reset()

func reset() -> void:
	fx.clear()
	total = 0
	var run = GemRun.new(42)
	run.board.cells.clear()
	run.board.cells[AT] = {"kind":kind,"tier":1,"fresh":false,"priority":"First"}
	for p in [Vector2i(2,4),Vector2i(4,4)]:
		run.board.cells[p] = {"kind":"diamond","tier":1,"fresh":false,"priority":"First"}
	if kind == "tianranzumulv":
		run.board.cells[AT].stolen_abilities = ["tower_huiyao","tower_shandianlian","tower_10jiyun"].filter(func(id): return id in GemCatalog.DATA.mechanics.stealable_abilities)
	run.board.rebuild()
	run.phase = "combat"
	combat = GemCampaignCombat.new(run)
	combat.start()
	# Neighbours demonstrate received support, without adding their own attacks.
	for p in combat.towers:
		if p != AT: combat.towers[p].disabled = INF
	for pos in [Vector2(5,3.5),Vector2(6,4.5),Vector2(5,5),Vector2(7,3),Vector2(7,5)]:
		combat.spawn_enemy()
		var enemy: Dictionary = combat.enemies.back()
		enemy.pos = pos
		enemy.hp = 1000000000.0
		enemy.hp_max = enemy.hp
		enemy.speed = 0.0
	combat.spawned = int(combat.wave_data.count)
	combat.ability_visual.connect(happened)
	combat.damaged.connect(fx.damaged)
	combat.evaded.connect(fx.evaded)

func happened(event: Dictionary) -> void:
	GemAbilityArt.receive(fx,event,combat.run.board.cells)
	total += float(event.get("amount",0))

func _process(dt: float) -> void:
	if not playing or not is_visible_in_tree() or not get_global_rect().intersects(Rect2(Vector2.ZERO,get_viewport_rect().size)): return
	accumulator += minf(dt,.1)
	while accumulator >= 1.0/30:
		accumulator -= 1.0/30
		combat.tick(1.0/30)
		fx.advance(1.0/30)
	if combat.elapsed > 12: reset()
	queue_redraw()

func _draw() -> void:
	if combat == null: return
	var origin = Vector2(maxf(0,(size.x-260)*.5)-30,-54)
	GemAbilityArt.draw_fields(self,combat,AT,origin,UNIT,fx.clock)
	for p in combat.run.board.cells:
		GemArt.draw(self,GemArt.sprite_id("gems",combat.run.board.cells[p].kind,1),origin+(Vector2(p)+Vector2(.5,.5))*UNIT,UNIT)
	for enemy in combat.enemies:
		var center: Vector2 = origin+enemy.pos*UNIT
		GemAbilityArt.draw_status(self,enemy,center,UNIT,combat.elapsed)
		GemArt.draw(self,GemArt.sprite_id("enemies",enemy.source_id),center,UNIT,false,Color(1.5,1.2,1.0) if fx.flashes.has(int(enemy.id)) else Color.WHITE)
	fx.draw_projectiles(self,combat.projectiles,origin,UNIT)
	fx.draw(self,origin,UNIT,ThemeDB.fallback_font)
	draw_string(ThemeDB.fallback_font,Vector2(8,size.y-8),"Damage: %d · %s" % [total,"example stolen abilities" if kind == "tianranzumulv" else "durable demo targets"],HORIZONTAL_ALIGNMENT_LEFT,size.x-16,11,Color("e1d6b3"))
