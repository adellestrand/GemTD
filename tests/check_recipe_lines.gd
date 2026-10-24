extends SceneTree

# Recipe book: towers are grouped by upgrade line (Dota's recipe tree, base first, top last), and
# ingredient chips are green for gems from earlier rounds, yellow when only this round's new gems
# provide them. Presentation only.

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

func gem(kind: String, fresh: bool) -> Dictionary:
	return {"kind":kind,"tier":1,"fresh":fresh,"priority":"First"}

func line_with(groups: Array, result: String) -> Dictionary:
	for group in groups:
		if group.recipes.any(func(r): return GemCatalog.recipe_result(r) == result and str(GemCatalog.recipe(r).get("family","")) != "secret"):
			return group
	return {}

func run_checks() -> void:
	if not "--smoke" in OS.get_cmdline_user_args() or not GemCatalog.campaign():
		printerr("Recipe line checks require --campaign --smoke")
		quit(1)
		return
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	var groups: Array = GemRecipeBook.chain_groups()
	var listed: Array = []
	for group in groups: listed.append_array(group.recipes)
	var towers = GemCatalog.recipes().keys().filter(func(r): return not GemRecipeBook.is_trap(r))
	check(listed.size() == towers.size() and towers.all(func(r): return listed.count(r) == 1),"every tower recipe appears in exactly one group")
	var lines = groups.filter(func(g): return not str(g.title).begins_with("SECRET"))
	check(lines.size() == 8 and lines.all(func(g): return GemRecipeBook.grade_of(g.recipes.back()) == "top"),"eight upgrade lines, each ending in its top tower")
	var koh = line_with(groups,"keyinuoerguangmingzhishan")
	check(koh.recipes.map(func(r): return GemCatalog.recipe_result(r)) == ["silver","fenhongzuanshi","baiyinqishi","juxingfenhongzuanshi","keyinuoerguangmingzhishan"],"Koh-i-Noor line: Silver and Pink Diamond, then Silver Knight, Huge Pink Diamond, Koh-i-Noor")
	check(line_with(groups,"haibao") == line_with(groups,"xingguanglanbaoshi"),"side tower Sea Jewel joins the Yellow Sapphire line")
	check(line_with(groups,"aijijin") == line_with(groups,"sililankazhixing") and line_with(groups,"jin") == line_with(groups,"sililankazhixing"),"Gold and Egypt Gold follow Emerald Golem into the Dark Emerald line")
	for group in lines:
		var ok = true
		for recipe in group.recipes:
			for ingredient in GemCatalog.recipe(recipe).ingredients:
				var index = group.recipes.map(func(r): return GemCatalog.recipe_result(r)).find(str(ingredient[0]))
				if index > group.recipes.find(recipe): ok = false
		check(ok,"%s: every combined ingredient comes before the tower it upgrades" % group.title)

	# Silver: sapphire and topaz from earlier rounds, diamond only among this round's gems.
	var cells = game.run.board.cells
	cells[Vector2i(10,10)] = gem("sapphire",false)
	cells[Vector2i(11,10)] = gem("topaz",false)
	cells[Vector2i(12,10)] = gem("diamond",true)
	game.run.placed = 1
	game.board_view.sync_board()
	await process_frame
	var before = game.run.snapshot()
	game.show_recipes()
	await process_frame
	var book: GemRecipeBook = game.recipe_book
	check(book.chains.visible and book.chains.get_child_count() >= 2,"the full campaign book shows the line columns")
	var titles: Array = []
	for column in book.chains.get_children():
		for child in column.get_children():
			if child is Label: titles.append(child.text)
	check(titles.size() == groups.size() and titles.has("KOH-I-NOOR LINE"),"each group has a visible line heading")
	var silver = ""
	for recipe in GemCatalog.recipes():
		if GemCatalog.recipe_result(recipe) == "silver" and str(GemCatalog.recipe(recipe).get("family","")) != "secret": silver = recipe
	var chips: Array = book.find_buttons[silver]
	var border = func(chip: Button) -> Color: return (chip.get_theme_stylebox("normal") as StyleBoxFlat).border_color
	check(chips.size() == 3 and border.call(chips[0]) == GemRecipeBook.READY and border.call(chips[1]) == GemRecipeBook.READY,"ingredients placed in earlier rounds are green")
	check(border.call(chips[2]) == GemRecipeBook.FRESH,"an ingredient that is new this round is yellow")
	chips[2].mouse_entered.emit()
	check(book.detail_ingredient.text.ends_with("(new this round)"),"the detail line says the gem is new this round")
	chips[0].mouse_entered.emit()
	check(book.detail_ingredient.text.ends_with("(earlier rounds)"),"the detail line says the gem is from earlier rounds")
	var missing = book.find_buttons.values().map(func(list): return list.filter(func(c): return c.disabled)).filter(func(list): return not list.is_empty())
	check(not missing.is_empty() and border.call(missing[0][0]) == GemRecipeBook.MISSING,"missing ingredients stay grey")
	check(before == game.run.snapshot(),"opening the grouped book changes nothing in the run")
	print("RECIPE_LINES_CHECK_%s checks=%d failures=%d" % ["OK" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
