extends SceneTree

var checks = 0
var failures = 0
var at = Vector2i(10,10)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)
	else: print("PASS: "+description)

func gem(kind: String, tier: int = 1) -> Dictionary:
	return {"kind":kind,"tier":tier,"fresh":false,"priority":"First"}

func fixture(kind: String = "diamond", tier: int = 1, wave: int = 1) -> GemCampaignCombat:
	var state = GemRun.new(42)
	state.board.cells.clear()
	state.board.cells[at] = gem(kind,tier)
	state.board.rebuild()
	state.phase = "combat"
	state.wave = wave
	var combat = GemCampaignCombat.new(state)
	combat.start()
	combat.spawn_enemy()
	combat.spawned = int(combat.wave_data.count)
	combat.enemies[0].hp = 1000000000.0
	combat.enemies[0].hp_max = 1000000000.0
	combat.enemies[0].pos = Vector2(at)+Vector2(.5,.5)
	combat.ground = PackedVector2Array([Vector2(at)+Vector2(.5,.5),Vector2(at)+Vector2(1000,.5)])
	return combat

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	check(GemCatalog.campaign() and GemCatalog.wave_count() == 100 and GemRun.new().lives == 100,"campaign has 100 waves and original 100 starting lives")
	check(GemCatalog.recipes().size() == 59 and GemCatalog.DATA.specials.size() == 67,"all recipe alternatives and upgraded trap units are present")
	var counts = {"standard":0,"secret":0,"slab":0}
	for id in GemCatalog.recipes():
		var definition: Dictionary = GemCatalog.recipe(id)
		counts[definition.family] += 1
		var state = GemRun.new(42)
		state.board.cells.clear()
		var positions: Array[Vector2i] = []
		for i in range(definition.ingredients.size()):
			var p = at+Vector2i(i*3,0)
			positions.append(p)
			state.board.cells[p] = gem(definition.ingredients[i][0],int(definition.ingredients[i][1]))
		state.board.rebuild()
		var accepted = state.combine(id,positions[0],true)
		var result = GemCatalog.recipe_result(id)
		check(accepted and state.phase == "build" and state.placed == 0 and (state.board.slabs.get(positions[0],"") == result if definition.family == "slab" else state.board.cells[positions[0]].kind == result),"exact recipe consumes older materials: "+id)
	check(counts.standard == 38 and counts.secret == 13 and counts.slab == 8,"recipe families remain separate including shared super-tower results")
	for kind in GemCatalog.DATA.specials:
		if GemCatalog.DATA.specials[kind].slab: continue
		var combat = fixture(kind)
		for i in range(60):
			combat.enemies[0].pos = Vector2(at)+Vector2(.5,.5)
			combat.tick(1.0/30.0)
		check(combat.run.phase == "combat" and is_finite(float(combat.enemies[0].hp)),"special tower mechanics execute: "+kind)
	for kind in GemCatalog.DATA.specials:
		if not GemCatalog.DATA.specials[kind].slab: continue
		var combat = fixture()
		combat.run.board.slabs[at+Vector2i(1,0)] = kind
		combat.enemies[0].pos = Vector2(at)+Vector2(1.5,.5)
		combat.tick(1.0/30.0)
		check(combat.aura_clocks.has("slab/"+str(at+Vector2i(1,0))),"trap tier triggers its real effect: "+kind)
	for wave in range(1,101):
		var state = GemRun.new(42)
		state.wave = wave
		state.phase = "combat"
		var combat = GemCampaignCombat.new(state)
		combat.start()
		combat.spawn_enemy()
		combat.tick(1.0/30.0)
		check(combat.enemies.size() >= 1 and float(combat.enemies[0].hp) > 0 and is_finite(float(combat.enemies[0].hp)),"wave spawns with valid abilities and stats: %d" % wave)
	var state = GemRun.new(42)
	state.board.cells.clear()
	state.board.rebuild()
	state.board.slabs = {at-Vector2i(1,0):"youbushiban",at:"youbushiban",at+Vector2i(1,0):"youbushiban"}
	var route = state.board.ground_route.duplicate()
	state.upgrade_slabs()
	check(state.board.slabs.size() == 1 and state.board.slabs[at] == "youbushiban_yin" and route == state.board.ground_route,"three equal path traps upgrade at the center without blocking the route")
	check(state.move_slab(at,at+Vector2i(0,2)) and not state.place(at+Vector2i(0,2)),"moving a trap preserves the build phase and prevents a gem overlapping it")
	state.adjust_streak(101)
	check(state.enemy_count == 12 and state.streak == 1,"success streak raises enemy count one per 50 points")
	state.adjust_streak(-501)
	check(state.enemy_count == 5 and state.streak == 0,"negative streak reduces enemy count with an original minimum of five")
	var snapshot = JSON.parse_string(JSON.stringify(state.snapshot()))
	var restored = GemRun.new(99)
	check(restored.restore(snapshot) and restored.board.slabs == state.board.slabs and restored.enemy_count == 5,"JSON checkpoint retains traps, streak and encounter size")
	var combat = fixture("jade")
	combat.attack(at,gem("jade"),GemCatalog.stats(gem("jade")),combat.enemies[0])
	check(not combat.enemies[0].mods.is_empty(),"Jade applies a campaign poison instance")
	var before = float(combat.enemies[0].hp)
	combat.towers.clear()
	for i in range(300): combat.tick(1.0/30.0)
	check(is_equal_approx(before-float(combat.enemies[0].hp),176.0),"poison includes its scheduled final tick at expiry and the enemy's -10 percent magic resistance")
	combat = fixture("diamond",1,16)
	var health = float(combat.enemies[0].hp)
	combat.deal(combat.enemies[0],100,"magical")
	check(combat.enemies[0].magic_immune and combat.enemies[0].hp == health,"wave 16 innate magic immunity blocks magic damage")
	combat = fixture("diamond",1,8)
	check(combat.targets_for(at,gem("diamond"),GemCatalog.stats(gem("diamond"))).is_empty(),"invisible wave cannot be selected without detection")
	combat.run.board.cells[at+Vector2i.ONE] = gem("opal")
	combat.start()
	combat.spawn_enemy()
	combat.enemies[0].pos = Vector2(at)+Vector2(.5,.5)
	check(not combat.targets_for(at,gem("diamond"),GemCatalog.stats(gem("diamond"))).is_empty(),"Opal reveals invisible enemies within its detection aura")
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	game.show_recipes()
	await process_frame
	check(game.recipe_book.track_buttons.size() == 59,"campaign recipe book exposes every standard, secret and trap recipe")
	game.recipe_book.search.text = "secret"
	game.recipe_book.search.text_changed.emit("secret")
	await process_frame
	check(game.recipe_book.track_buttons.size() == 13,"recipe search selects all secret alternatives")
	game.recipe_book.hide()
	game.run.board.slabs[at] = "youbushiban"
	game.on_cell_clicked(at)
	check(game.move_trap_button.visible and not game.move_trap_button.disabled and game.selected_label.text.contains("Trap"),"selected path trap exposes its move control and readable identity")
	var placement_rng = game.run.rng.state
	game.move_trap_button.pressed.emit()
	game.on_cell_clicked(at+Vector2i(0,2))
	check(game.run.board.slabs.has(at+Vector2i(0,2)) and game.run.placed == 0 and game.run.rng.state == placement_rng,"UI move mode moves a trap without placing a new gem or consuming RNG")
	game.demolish_button.pressed.emit()
	check(game.run.board.slabs.is_empty() and not game.move_trap_button.visible,"demolishing a selected trap clears its move controls")
	game.queue_free()
	await process_frame
	print("CAMPAIGN_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
