class_name GemRecipeBook
extends AcceptDialog

signal locate_requested(cell: Vector2i)
signal track_requested(recipe: String)

var content: VBoxContainer
var track_buttons: Dictionary = {}
var find_buttons: Dictionary = {}
var locate_cursor: Dictionary = {}
var search: LineEdit
var bound_state: GemRun
var bound_tracking = ""

func _ready() -> void:
	title = "Recipe book"
	min_size = Vector2i(680,540)
	get_ok_button().text = "Close"
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_bottom = -48
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,12)
	add_child(margin)
	var layout = VBoxContainer.new()
	margin.add_child(layout)
	search = LineEdit.new()
	search.placeholder_text = "Search tower, ingredient or recipe family..."
	search.text_changed.connect(func(_text): rebuild_cards())
	layout.add_child(search)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)

func clear_cards() -> void:
	track_buttons.clear()
	find_buttons.clear()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func reset() -> void:
	hide()
	bound_state = null
	search.text = ""
	locate_cursor.clear()
	clear_cards()

func open_for(state: GemRun, tracked: String) -> void:
	bound_state = state
	bound_tracking = tracked
	rebuild_cards()
	popup_centered(Vector2i(760,750))

func rebuild_cards() -> void:
	if bound_state == null: return
	clear_cards()
	text_label(content,"Locate an ingredient or track a recipe on the board. Combine from the selected tower's controls.",14)
	for recipe in GemCatalog.recipes():
		var haystack = GemCatalog.recipe_title(recipe)+" "+str(GemCatalog.recipe(recipe).get("family",""))
		for ingredient in GemCatalog.recipe(recipe).ingredients: haystack += " "+GemCatalog.title({"kind":ingredient[0],"tier":int(ingredient[1])})
		if search.text.is_empty() or haystack.to_lower().contains(search.text.to_lower()): add_recipe(bound_state,recipe,bound_tracking)
	if track_buttons.is_empty(): text_label(content,"No matching recipes.",15)

func add_recipe(state: GemRun, recipe: String, tracked: String) -> void:
	var progress = GemRecipeGuide.progress(state,recipe)
	var data: Dictionary = GemCatalog.stats({"kind":GemCatalog.recipe_result(recipe),"tier":1})
	var panel = PanelContainer.new()
	content.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",6)
	panel.add_child(box)
	var header = HBoxContainer.new()
	box.add_child(header)
	portrait(header,GemArt.sprite_id("gems",GemCatalog.recipe_result(recipe)),Vector2(48,52))
	var names = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(names)
	text_label(names,data.name,20).add_theme_color_override("font_color",GemArt.color("ui_accent"))
	if GemCatalog.recipe(recipe).has("family"): text_label(names,str(GemCatalog.recipe(recipe).family).capitalize()+" recipe",12)
	text_label(names,"%d / %d ingredients found" % [progress.collected,progress.total],13)
	var track = Button.new()
	track.text = "Track on board" if tracked != recipe else "Tracking"
	track.pressed.connect(func(): track_requested.emit(recipe))
	header.add_child(track)
	track_buttons[recipe] = track
	text_label(box,GemCampaignRules.describe({"kind":GemCatalog.recipe_result(recipe),"tier":1}) if GemCatalog.campaign() else str(data.effect),12)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",12)
	box.add_child(grid)
	find_buttons[recipe] = []
	for group in progress.groups:
		var column = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.custom_minimum_size.x = 195
		grid.add_child(column)
		var row = HBoxContainer.new()
		column.add_child(row)
		portrait(row,GemArt.sprite_id("gems",group.kind,int(group.tier)),Vector2(32,36))
		text_label(row,GemCatalog.title({"kind":group.kind,"tier":int(group.tier)}),14)
		var count = text_label(column,"Have %d / %d · %d kept, %d new" % [group.owned.size(),group.needed,group.older,group["new"]],12)
		count.add_theme_color_override("font_color",GemArt.color("placement_ok") if group.owned.size() >= int(group.needed) else GemArt.color("ui_muted"))
		var find = LinkButton.new()
		find.text = "Locate on board" if not group.owned.is_empty() else "Missing ingredient"
		find.disabled = group.owned.is_empty()
		find.tooltip_text = "Cycles through %d matching gems, kept gems first." % group.owned.size()
		find.pressed.connect(func():
			if group.owned.is_empty():
				return
			var key = recipe+"/"+str(group.key)
			var index = int(locate_cursor.get(key,0))%group.owned.size()
			locate_cursor[key] = index+1
			locate_requested.emit(group.owned[index])
		)
		column.add_child(find)
		find_buttons[recipe].append(find)
	text_label(box,progress.message,13)

func portrait(parent: Node, id: String, minimum: Vector2) -> void:
	var image = TextureRect.new()
	image.texture = GemArt.texture(id)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.custom_minimum_size = minimum
	parent.add_child(image)

func text_label(parent: Node, text: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label
