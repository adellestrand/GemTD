extends SceneTree

const FULL: Dictionary = preload("res://data/full_reference.json").data
var checks = 0
var failures = 0
var at = Vector2i(10,10)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)
	else:
		print("PASS: "+description)

func gem(kind: String, tier: int, fresh: bool = false) -> Dictionary:
	return {"kind":kind,"tier":tier,"fresh":fresh,"priority":"First"}

func fixture(kind: String, tier: int) -> GemCombat:
	var state = GemRun.new(42)
	state.phase = "combat"
	state.board.cells[at] = gem(kind,tier)
	var combat = GemCombat.new(state)
	combat.start()
	combat.spawn_enemy()
	combat.spawned = int(combat.wave_data.count)
	combat.enemies[0].hp = 1000000.0
	combat.enemies[0].armor = 0.0
	combat.enemies[0].magic_resist = 0.0
	combat.enemies[0].pos = Vector2(at)+Vector2(.5,.5)
	return combat

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	check(GemCatalog.expanded_gems() and GemRelease.version() == "1.1.0-dev","expanded profile has a separate development identity")
	for fact in FULL.base_towers:
		var data = GemCatalog.stats(gem(fact.kind,int(fact.tier)))
		check(is_equal_approx(data.damage,fact.values.AttackDamageMin) and is_equal_approx(data.interval,fact.values.AttackRate) and is_equal_approx(data.range,fact.values.AttackRange/128.0),"original attack facts "+fact.source_id)
	var combat = fixture("sapphire",6)
	combat.attack(at,gem("sapphire",6),GemCatalog.stats(gem("sapphire",6)),combat.enemies[0])
	check(combat.enemies[0].slow == 480.0,"sapphire VI applies its original 480 constant slow")
	combat = fixture("amethyst",6)
	combat.attack(at,gem("amethyst",6),GemCatalog.stats(gem("amethyst",6)),combat.enemies[0])
	check(combat.enemies[0].armor_debuff == 64.0 and combat.enemies[0].armor_debuffs[5].until == 5.0,"amethyst VI uses 64 armor reduction for five seconds")
	combat = fixture("emerald",6)
	combat.attack(at,gem("emerald",6),GemCatalog.stats(gem("emerald",6)),combat.enemies[0])
	check(combat.enemies[0].poisons[0].damage == 128.0 and combat.enemies[0].poisons[0].until == 10.0,"emerald VI poison is 128 per tick for ten seconds")
	combat = fixture("ruby",6)
	var before = float(combat.enemies[0].hp)
	var ruby = gem("ruby",6)
	combat.attack(at,ruby,GemCatalog.stats(ruby),combat.enemies[0])
	check(is_equal_approx(before-float(combat.enemies[0].hp),GemCatalog.stats(ruby).damage*2.0) and is_equal_approx(GemCatalog.DATA.effects.ruby.radius[5],700.0/128.0),"ruby VI adds full pure splash in its original 700-unit radius")
	var aqua = gem("aquamarine",6)
	var opal = gem("opal",6)
	var timing = GemCatalog.attack_timing(aqua,at,{at:aqua,at+Vector2i.ONE:opal})
	check(timing.innate == 500.0 and timing.bonus == 570.0,"aquamarine VI innate 500 and opal VI aura 70 coexist")
	var state = GemRun.new(42)
	state.gold = 1000
	for i in range(4):
		check(state.buy_quality(),"expanded odds purchase %d" % (i+1))
	check(not state.buy_quality() and state.gold == 730,"provisional four-price economy has a strict upper bound")
	var counts = [0,0,0,0,0,0]
	for roll in range(1,101):
		counts[GemCatalog.roll_tier(GemCatalog.DATA.quality_odds[4],roll)-1] += 1
	check(counts == [10,30,30,20,10,0],"maximum source roll produces I-V; VI requires combining")
	state = GemRun.new(42)
	for i in range(5):
		state.board.cells[at+Vector2i(i,0)] = gem("diamond",5,true)
	state.placed = 5
	check(state.upgrade(at,2) and state.board.cells[at].tier == 6 and state.phase == "combat","two new quality-V gems produce VI and start combat")
	state.phase = "build"
	state.wave = 2
	state.board.rebuild()
	var snapshot = state.snapshot()
	check(GemRun.new(1).restore(snapshot),"quality VI survives a build checkpoint round trip")
	snapshot.content_version = 1
	check(not GemRun.new(1).restore(snapshot),"development profile rejects 1.0 checkpoints instead of reinterpreting them")
	state = GemRun.new(42)
	state.board.cells[at] = gem("emerald",3)
	state.board.cells[at+Vector2i(1,0)] = gem("opal",3)
	state.board.cells[at+Vector2i(2,0)] = gem("sapphire",2)
	check(state.combine("jade",at,true) and state.phase == "build" and state.placed == 0 and state.board.cells[at].kind == "jade","Jade combines exact older ingredients without consuming the new round choice")
	check(state.board.cells[at+Vector2i(1,0)].kind == "stone" and state.board.cells[at+Vector2i(2,0)].kind == "stone","Jade consumes both other material positions exactly once")
	combat = fixture("jade",1)
	combat.attack(at,gem("jade",1),GemCatalog.stats(gem("jade",1)),combat.enemies[0])
	check(combat.enemies[0].poisons[0].damage == 16.0 and combat.enemies[0].poisons[0].until == 10.0,"Jade reuses its original fourth-tier poison, not a tier-one effect")
	check(GemTowerInfo.effect_text(gem("jade",1)).contains("16 magic"),"Jade information and simulation share the same effect tier")
	check(GemArt.texture(GemArt.sprite_id("gems","jade")) != null,"Jade has an explicit replaceable placeholder portrait")
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	game.run.board.cells[at] = aqua
	game.on_cell_clicked(at)
	await process_frame
	check(game.footer_label.text.contains("1.1.0-dev") and game.footer_label.text.contains("6 qualities") and game.odds_label.text.contains("VI"),"UI shows development identity and all six quality columns")
	check(game.detail_label.text.contains("500"),"selected higher-quality tower info renders without array errors")
	game.recipe_book.open_for(game.run,"")
	await process_frame
	check(game.recipe_book.track_buttons.has("jade"),"recipe book exposes Jade alongside the three review recipes")
	game.queue_free()
	await process_frame
	print("EXPANDED_GEMS_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
