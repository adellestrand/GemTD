class_name GemMazeBook
extends AcceptDialog

# Maze tips: named layouts from the Dota 2 version's maze guide. Point at a tip to preview it
# on a mini map; "Show on board" draws it over the real board until hidden. Presentation only.
signal tip_chosen(id: String)

const GUIDE = Color("ff7ad9")
const REMOVE = Color("ffb347")
const LIST_WIDTH = 520.0
# Autowrapped labels need a width up front, or a transient one-word-per-line height sticks to the window.
const CARD_TEXT_WIDTH = 330.0
const SIDE_TEXT_WIDTH = 300.0

var margin: MarginContainer
var list: VBoxContainer
var preview: Control
var preview_title: Label
var preview_text: Label
var preview_stats: Label
var hide_button: Button
var summary: Label
var show_buttons: Dictionary = {}
var bound_state: GemRun
var active_tip = ""
var previewed = ""
var base_length = 0.0
var lengths: Dictionary = {}

static func guide_color() -> Color:
	return GemArt.color("maze_guide",GUIDE)

func _ready() -> void:
	title = "Maze tips"
	wrap_controls = false
	min_size = Vector2i(680,540)
	get_ok_button().text = "Close"
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_bottom = -48
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,12)
	add_child(margin)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation",10)
	margin.add_child(layout)
	summary = Label.new()
	summary.add_theme_font_size_override("font_size",13)
	summary.add_theme_color_override("font_color",Color("8e9aa3"))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size.x = 600
	summary.text = "Layouts from the Dota 2 version's maze guide. Point at a tip to preview it; Show on board marks the cells while you build. Names are ours – the original only shows pictures."
	layout.add_child(summary)
	var columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",14)
	layout.add_child(columns)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = LIST_WIDTH
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",6)
	scroll.add_child(list)
	var side_panel = PanelContainer.new()
	var side_style = StyleBoxFlat.new()
	side_style.bg_color = Color("18222b")
	side_style.border_color = Color("33414d")
	side_style.set_border_width_all(1)
	side_style.set_corner_radius_all(8)
	side_style.set_content_margin_all(12)
	side_panel.add_theme_stylebox_override("panel",side_style)
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(side_panel)
	var side = VBoxContainer.new()
	side.add_theme_constant_override("separation",8)
	side_panel.add_child(side)
	preview_title = Label.new()
	preview_title.theme_type_variation = "SectionLabel"
	preview_title.add_theme_color_override("font_color",Color("e8c46a"))
	side.add_child(preview_title)
	preview_text = text_label(side,"",13)
	preview_text.custom_minimum_size.x = SIDE_TEXT_WIDTH
	preview_text.add_theme_color_override("font_color",Color("d9d6c8"))
	preview = Control.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(220,220)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.draw.connect(draw_preview)
	side.add_child(preview)
	var legend = HFlowContainer.new()
	legend.add_theme_constant_override("h_separation",12)
	side.add_child(legend)
	legend_item(legend,guide_color(),"build here")
	legend_item(legend,Color("78837b"),"stone / tower")
	legend_item(legend,REMOVE,"demolish this starting stone")
	legend_item(legend,Color("f3dcaa"),"checkpoint")
	preview_stats = text_label(side,"",12)
	preview_stats.custom_minimum_size.x = SIDE_TEXT_WIDTH
	preview_stats.add_theme_color_override("font_color",Color("8e9aa3"))
	hide_button = Button.new()
	hide_button.text = "Hide maze guide on board  (G)"
	hide_button.theme_type_variation = "DangerButton"
	hide_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hide_button.pressed.connect(func(): tip_chosen.emit(""))
	side.add_child(hide_button)

func reset() -> void:
	hide()
	bound_state = null

func open_for(state: GemRun, active: String) -> void:
	bound_state = state
	active_tip = active
	base_length = GemMazeTips.base_route_length(state.board)
	for entry in GemMazeTips.tips():
		lengths[entry.id] = GemMazeTips.route_length(state.board,entry.id)
	var screen = (get_parent() as Control).size if get_parent() is Control else Vector2(1360,900)
	var wanted = Vector2i(mini(int(screen.x)-24,1400),int(screen.y)-34-24)
	var fitted = Vector2i(maxi(wanted.x,min_size.x),maxi(wanted.y,min_size.y))
	popup_centered(fitted)
	size = fitted
	position = Vector2i((Vector2(screen)-Vector2(fitted))/2.0)+Vector2i(0,17)
	rebuild()
	show_preview(active if not active.is_empty() else str(GemMazeTips.tips()[0].id))

func rebuild() -> void:
	show_buttons.clear()
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for entry in GemMazeTips.tips():
		add_tip(entry)
	hide_button.visible = not active_tip.is_empty()

func add_tip(entry: Dictionary) -> void:
	var id: String = entry.id
	var progress = GemMazeTips.progress(bound_state,id)
	var active = id == active_tip
	var panel = PanelContainer.new()
	var box = StyleBoxFlat.new()
	box.bg_color = Color("1d2832") if not active else Color("2a1f2e")
	box.border_color = guide_color() if active else Color("2c3a46")
	box.set_border_width_all(2 if active else 1)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel",box)
	panel.mouse_entered.connect(func(): show_preview(id))
	list.add_child(panel)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	panel.add_child(row)
	var stripe = ColorRect.new()
	stripe.color = guide_color() if (entry.players as Array).has(1) else Color("6a5a70")
	stripe.custom_minimum_size.x = 3
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)
	var texts = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation",1)
	texts.custom_minimum_size.x = CARD_TEXT_WIDTH
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var name_label = text_label(texts,entry.name,17)
	name_label.add_theme_color_override("font_color",GemArt.color("ui_accent"))
	var tag = text_label(texts,GemMazeTips.players_text(id)+"  ·  %d cells · %d built" % [progress.total,progress.done.size()],11)
	tag.add_theme_color_override("font_color",Color("a89878"))
	var line = text_label(texts,entry.summary,12)
	line.add_theme_color_override("font_color",Color("9aa5ad"))
	var button = Button.new()
	button.text = "Showing" if active else "Show on board"
	button.theme_type_variation = "AccentButton" if not active else "ToolButton"
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = "Mark this layout's cells on the board until you hide it."
	button.pressed.connect(func(): tip_chosen.emit(id))
	button.mouse_entered.connect(func(): show_preview(id))
	row.add_child(button)
	show_buttons[id] = button

func show_preview(id: String) -> void:
	previewed = id
	var entry = GemMazeTips.tip(id)
	if entry.is_empty() or bound_state == null:
		return
	var progress = GemMazeTips.progress(bound_state,id)
	preview_title.text = entry.name
	preview_text.text = entry.summary
	var stats = "%d cells · %d built · %d to build (about %d build rounds)" % [progress.total,progress.done.size(),progress.build.size(),progress.rounds]
	if not progress.remove.is_empty():
		stats += "\nDemolish %d starting stone%s first – with every starting stone kept, this layout would block the route (enemies cannot cut diagonal corners here)." % [progress.remove.size(),"" if progress.remove.size() == 1 else "s"]
	var length = float(lengths.get(id,0.0))
	if length > 0.0:
		stats += "\nGround route when finished: %.0f cells (empty map: %.0f)." % [length,base_length]
	stats += "\nLayout: "+GemMazeTips.players_text(id)+" ("+id.replace("maze_","")+")."
	preview_stats.text = stats
	preview.queue_redraw()

func draw_preview() -> void:
	if bound_state == null or previewed.is_empty():
		return
	var side = minf(preview.size.x,preview.size.y)
	var cell = floorf(side/37.0)
	var origin = ((preview.size-Vector2.ONE*cell*37.0)/2.0).floor()
	preview.draw_rect(Rect2(origin-Vector2.ONE*2,Vector2.ONE*(cell*37.0+4)),Color("081315"))
	preview.draw_rect(Rect2(origin,Vector2.ONE*cell*37.0),GemArt.color("grass").darkened(.25))
	var marked = {}
	for p in GemMazeTips.cells(previewed): marked[p] = true
	var removals = {}
	for p in GemMazeTips.removals(previewed): removals[p] = true
	for p in bound_state.board.cells:
		var tint = Color("8e8f86") if bound_state.board.cells[p].kind == "stone" else GemArt.gem_color(bound_state.board.cells[p])
		preview.draw_rect(Rect2(origin+Vector2(p)*cell,Vector2.ONE*cell).grow(-.5),tint if not removals.has(p) else REMOVE)
	for p in marked:
		var r = Rect2(origin+Vector2(p)*cell,Vector2.ONE*cell).grow(-.5)
		if bound_state.board.cells.has(p):
			preview.draw_rect(r,guide_color(),false,1)
		else:
			preview.draw_rect(r,Color(guide_color(),.85))
	for i in range(bound_state.board.checkpoints.size()):
		var center = origin+(Vector2(bound_state.board.checkpoints[i])+Vector2(.5,.5))*cell
		preview.draw_circle(center,maxf(2.0,cell*.75),Color("293732"))
		preview.draw_circle(center,maxf(1.5,cell*.5),Color("f3dcaa"))
		preview.draw_string(ThemeDB.fallback_font,center+Vector2(cell*.8,-cell*.6),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f3dcaa"))

func legend_item(parent: Node, color: Color, text: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	parent.add_child(row)
	var swatch = ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(10,10)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	var label = text_label(row,text,11)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color",Color("b9c0c6"))

func text_label(parent: Node, text: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
