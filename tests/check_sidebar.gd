extends SceneTree

var failures = 0
var checks = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+message)
	else: print("PASS: "+message)

func settle() -> void:
	for i in range(4): await process_frame

func _initialize() -> void: run_checks.call_deferred()

func run_checks() -> void:
	GemCatalog.select_profile("campaign")
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	check(not game.sidebar is ScrollContainer and game.sidebar_tabs.get_tab_count() == 4,"sidebar has fixed controls and four detail tabs instead of a scrolling menu")
	game.new_run(71)
	var before = game.run.snapshot()
	check(GemFreshGems.markers(game.run).is_empty(),"existing board and empty build have no new-gem markers")
	for x in range(10,15): game.run.place(Vector2i(x,10))
	var markers = GemFreshGems.markers(game.run)
	check(markers.size() == 5 and markers[0].cell == game.run.fresh_cells()[0] and markers[4].number == 5,"all five fresh gems map to the round-tray numbers")
	before = game.run.snapshot()
	for pixels in [16.0,26.0,39.0,64.0]:
		check(Rect2(Vector2.ZERO,Vector2.ONE*pixels).encloses(GemFreshGems.badge_rect(Vector2.ONE*pixels*.5,pixels)),"fresh number remains inside its cell at scale "+str(pixels))
	check(before == game.run.snapshot(),"marker inspection never changes the board, actions or RNG")
	game.on_cell_clicked(Vector2i(10,10))
	check(game.quality_button.get_parent().name == "Header","manual gem-odds upgrade lives in the header")
	for resolution in [Vector2i(1280,720),Vector2i(1360,900),Vector2i(1920,1080)]:
		root.size = resolution
		for level in range(GemCatalog.max_quality_upgrade()+1):
			game.run.quality = level
			game.refresh_ui()
			await settle()
			var screen = Rect2(Vector2.ZERO,root.get_visible_rect().size)
			var all_fit = true
			for control in game.quality_button.get_parent().get_children():
				if control is Control and control.visible: all_fit = all_fit and screen.encloses(control.get_global_rect())
			check(all_fit,"header including upgrade price and navigation fits at %s, level %d" % [resolution,level])
	game.run.quality = GemCatalog.max_quality_upgrade()
	game.run.gold = 99999
	game.refresh_ui()
	before = game.run.snapshot()
	for resolution in [Vector2i(1280,720),Vector2i(1360,900),Vector2i(1920,1080)]:
		root.size = resolution
		for tab in range(4):
			game.sidebar_tabs.current_tab = tab
			await settle()
			var viewport = Rect2(Vector2.ZERO,root.get_visible_rect().size)
			check(viewport.encloses(game.sidebar.get_global_rect()) and game.action_panel.get_global_rect().end.y <= viewport.end.y and game.footer_label.get_global_rect().end.y <= viewport.end.y,"all sidebar controls fit at %s, tab %d" % [resolution,tab])
			if tab == 2:
				var all_spells_fit = true
				for button in game.spell_buttons.values(): all_spells_fit = all_spells_fit and viewport.encloses(button.get_global_rect())
				check(all_spells_fit,"all twelve spell buttons remain on screen at "+str(resolution))
	check(before == game.run.snapshot(),"changing tabs and resizing preserve the run")
	game.tower_effects_button.pressed.emit()
	check(game.sidebar_tabs.current_tab == 3 and game.affecting_effects.is_visible_in_tree(),"tower effects link opens the current tower's full effects")
	for recipe in game.recipe_buttons:
		game.recipe_buttons[recipe].old.visible = true
		game.recipe_buttons[recipe].final.visible = true
	game.refresh_recipe_choices()
	var visible_buttons = 0
	for pair in game.recipe_buttons.values():
		visible_buttons += int(pair.old.visible)+int(pair.final.visible)
	check(game.recipe_choice.item_count == GemCatalog.recipes().size() and visible_buttons == 2,"many available recipes stay accessible through a selector without growing the action panel")
	await settle()
	check(game.sidebar.get_global_rect().end.y <= root.get_visible_rect().size.y,"maximum recipe choice area also stays on screen")
	game.run.keep(Vector2i(10,10))
	check(GemFreshGems.markers(game.run).is_empty(),"final tower choice removes all fresh markers immediately")
	game.free()
	await process_frame
	print("SIDEBAR_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
