extends SceneTree

# Recipe book: pointing at an ingredient chip names the required tower in the detail panel
# (owned or missing), so the gem icon is never the only clue. Presentation only.

var checks = 0
var failures = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)
	else:
		print("PASS: "+description)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	if not "--smoke" in OS.get_cmdline_user_args():
		quit(1)
		return
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	game.run.board.cells[Vector2i(10,10)] = {"kind":"sapphire","tier":1,"fresh":false,"priority":"First"}
	game.run.placed = 1
	game.board_view.sync_board()
	await process_frame
	var before = game.run.snapshot()
	game.show_recipes()
	await process_frame
	var book = game.recipe_book
	check(book.detail_panel.visible,"compact recipe list shows the detail panel")
	var owned_chip: Button = null
	var missing_chip: Button = null
	var owned_recipe = ""
	var missing_recipe = ""
	for recipe in book.find_buttons:
		for chip in book.find_buttons[recipe]:
			if owned_chip == null and not chip.disabled:
				owned_chip = chip
				owned_recipe = recipe
			if missing_chip == null and chip.disabled:
				missing_chip = chip
				missing_recipe = recipe
	check(owned_chip != null and missing_chip != null,"the list has owned and missing ingredient chips")
	if owned_chip != null:
		owned_chip.mouse_entered.emit()
		check(book.detail_ingredient.visible and book.detail_ingredient.text.begins_with("Ingredient: ") and "have 1 /" in book.detail_ingredient.text,"hovering an owned chip names the tower and the count")
		check(book.detail_title.text == str(GemCatalog.stats({"kind":GemCatalog.recipe_result(owned_recipe),"tier":1}).name),"the panel still shows the recipe the chip belongs to")
		owned_chip.mouse_exited.emit()
		check(not book.detail_ingredient.visible,"leaving the chip hides the ingredient line")
	if missing_chip != null:
		missing_chip.mouse_entered.emit()
		check(book.detail_ingredient.visible and book.detail_ingredient.text.ends_with("(missing)"),"hovering a missing (disabled) chip still names the tower")
		var named = false
		for ingredient in GemCatalog.recipe(missing_recipe).ingredients:
			if GemCatalog.title({"kind":ingredient[0],"tier":int(ingredient[1])}) in book.detail_ingredient.text:
				named = true
		check(named,"the named tower is one of the recipe's ingredients")
	check(before == game.run.snapshot(),"hovering ingredients changes nothing in the run")
	print("RECIPE_HOVER_CHECK_%s checks=%d failures=%d" % ["OK" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
