extends Control

var run: GemRun
var combat: GemCombat
var board_view: GemBoardView
var audio: GemAudio
var status_label: Label
var wave_label: Label
var wave_heading: Label
var phase_label: Label
var message_label: Label
var selected_label: Label
var detail_label: Label
var affecting_effects: RichTextLabel
var effects_selection = Vector2i(-1,-1)
var selected_portrait: TextureRect
var enemy_portrait: TextureRect
var odds_label: Label
var save_label: Label
var keep_button: Button
var upgrade_two: Button
var upgrade_four: Button
var demolish_button: Button
var move_trap_button: Button
var move_tower_button: Button
var start_trap_wave_button: Button
var downgrade_button: Button
var moving_trap = Vector2i(-1,-1)
var quality_button: Button
var priority: OptionButton
var recipes_box: VBoxContainer
var recipe_buttons: Dictionary = {}
var speed_button: Button
var pause_button: Button
var selection = Vector2i(-1,-1)
var speed = 1
var paused = false
var accumulator = 0.0
var ui_clock = 0.0
var last_snapshot: Dictionary = {}
var recipe_popup: AcceptDialog
var recipe_text: RichTextLabel
var muted = false
var saved_volume = 0.35
var volume_slider: HSlider
var routes_check: CheckBox
var smoke = false
var recipe_book: GemRecipeBook
var maze_book: GemMazeBook
var maze_button: LinkButton
# Last maze tip shown, so G can bring it back after hiding.
var last_maze_tip = ""
var wave_book: GemWaveBook
var summary_dialog: GemRunSummary
var leaderboard_dialog: GemLeaderboardDialog
var seed_dialog: GemSeedDialog
var journal: GemReviewJournal
var score_prompt_run_id = ""
var result_box: VBoxContainer
var result_title: Label
var result_stats: Label
var combat_progress: Label
var wave_progress: ProgressBar
var boss_health: ProgressBar
var boss_label: Label
var tracking_button: LinkButton
var round_tray: HBoxContainer
var round_slots: Array[Button] = []
var round_cells: Array[Vector2i] = []
var hover_hint: Label
var active_preview: Dictionary = {}
var footer_label: Label
var lives_value: Label
var gold_value: Label
var wave_value: Label
var started_wave: Dictionary = {}
var last_wave_report = ""

func _ready() -> void:
	# Keep the historical application name for existing user:// checkpoints.
	get_window().title = "GemTD Solo "+GemRelease.version()
	var preview_requested = "--art" in OS.get_cmdline_user_args()
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var bridge = Engine.get_singleton("JavaScriptBridge")
		preview_requested = preview_requested or bool(bridge.eval("new URLSearchParams(window.location.search).get('view') === 'art'"))
	if preview_requested:
		get_tree().change_scene_to_file.call_deferred("res://game/art_gallery.tscn")
		return
	smoke = "--smoke" in OS.get_cmdline_user_args()
	# Fill any screen shape instead of letterboxing the 1360x900 design size.
	# One 16:9 design space (1600x900) scaled sharply to 1080p (1.2x), 1440p (1.6x) and 4K (2.4x).
	get_tree().root.content_scale_size = Vector2i(1600,900)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	build_theme()
	build_ui()
	update_map_area.call_deferred()
	audio = GemAudio.new()
	add_child(audio)
	load_settings()
	if not smoke and not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		apply_display("1080p" if "--windowed" in OS.get_cmdline_user_args() else display_mode)
	var restored = GemSave.read_snapshot() if not smoke else {}
	new_run(20261023 if smoke else int(Time.get_unix_time_from_system()), restored)
	if smoke:
		print("SMOKE_READY platform=%s build=%s board=%d checkpoints=%d" % [OS.get_name(),"debug" if OS.is_debug_build() else "release",run.board.cells.size(),run.board.checkpoints.size()])
		if "--smoke-attack" in OS.get_cmdline_user_args():
			audio.call_deferred("play_attack")
		elif "--smoke-audio" in OS.get_cmdline_user_args():
			audio.call_deferred("play_cue","place")

func build_theme() -> void:
	theme = load(str(GemArt.config().get("theme","res://assets/graphics/ui_theme.tres"))) as Theme

func label_in(parent: Node, text: String, font_size: int = 15) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",font_size)
	parent.add_child(l)
	return l

func button_in(parent: Node, text: String, action: Callable) -> Button:
	var b = GemTooltips.InfoButton.new()
	b.text = text
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func portrait_in(parent: Node, minimum: Vector2) -> TextureRect:
	var image = TextureRect.new()
	image.custom_minimum_size = minimum
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

const ICON_HEART = [".oo.oo.","orRorro","orrrrro",".orrro.","..oro..","...o..."]
const ICON_COIN = [".ooo.","oyYyo","oyyyo","oyyDo",".ooo."]
const ICON_WAVE = ["o......","oggg...","ogggggo","oggggg.","oggg...","o......","o......"]

func pixel_icon(rows: Array, palette: Dictionary, scale: int = 3) -> TextureRect:
	var img = Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var ch: String = rows[y][x]
			if palette.has(ch):
				img.set_pixel(x, y, Color(palette[ch]))
	var rect = TextureRect.new()
	rect.texture = ImageTexture.create_from_image(img)
	rect.custom_minimum_size = Vector2(img.get_width(), img.get_height())*scale
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect

func styled(node: Control, variation: String) -> Control:
	node.theme_type_variation = variation
	return node

func card_in(parent: Node) -> VBoxContainer:
	var card = PanelContainer.new()
	card.theme_type_variation = "Card"
	parent.add_child(card)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	card.add_child(box)
	return box

func stat_in(parent: Node, icon: TextureRect, caption: String) -> Label:
	var group = HBoxContainer.new()
	group.add_theme_constant_override("separation",8)
	parent.add_child(group)
	if icon != null:
		group.add_child(icon)
	var texts = VBoxContainer.new()
	texts.add_theme_constant_override("separation",-2)
	group.add_child(texts)
	var value = styled(label_in(texts,"",19),"StatValue") as Label
	value.remove_theme_font_size_override("font_size")
	styled(label_in(texts,caption,11),"MutedLabel")
	return value

const ICON_PAUSE = ["xx.xx","xx.xx","xx.xx","xx.xx","xx.xx"]
const ICON_PLAY = ["x....","xxx..","xxxxx","xxx..","x...."]
const QUALITY_TINTS = ["b9c2c9","7fd08c","6aaee8","b58cf0","f0a64e","ef6a5a"]

var wave_chips: HFlowContainer
var wave_name: Label
var wave_rewards: Label
var wave_traits: Label
var gem_chips: HFlowContainer
var gem_tiles: Dictionary = {}
var gem_tile_grid: GridContainer
var gem_effect: Label
var odds_bar: HBoxContainer
var odds_legend: HFlowContainer
var odds_discount: Label
var tray_hint: Label
var chip_cache: Dictionary = {}
var dim: ColorRect
var display_mode = "fullscreen"
var last_window_mode = "1080p"
const WINDOW_SIZES = {"1080p":Vector2i(1920,1080),"1440p":Vector2i(2560,1440),"2160p":Vector2i(3840,2160)}
var action_panel: Control
var spells_card: Control
var spell_buttons: Dictionary = {}
var spell_status: Label
var sidebar: VBoxContainer
var sidebar_tabs: TabContainer
var recipe_choice: OptionButton
var chosen_recipe = ""
var tower_effects_button: Button
var tower_effects_hint: Label

func glyph(rows: Array, color: Color, scale: int = 2) -> ImageTexture:
	var img = Image.create(rows[0].length()*scale,rows.size()*scale,false,Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			if rows[y][x] == "x":
				for dy in range(scale):
					for dx in range(scale):
						img.set_pixel(x*scale+dx,y*scale+dy,color)
	return ImageTexture.create_from_image(img)

func chip_in(parent: Node, text: String, tint: Color = Color("cfd3c8")) -> Label:
	var chip = PanelContainer.new()
	chip.theme_type_variation = "Chip"
	parent.add_child(chip)
	var l = styled(Label.new(),"ChipLabel") as Label
	l.text = text
	l.add_theme_color_override("font_color",tint)
	chip.add_child(l)
	return l

# Rebuild a chip row only when its content changed (refresh_ui runs five times a second).
func set_chips(row: Control, entries: Array) -> void:
	var key = JSON.stringify(entries)
	if chip_cache.get(row.get_instance_id(),"") == key:
		return
	chip_cache[row.get_instance_id()] = key
	for child in row.get_children():
		child.queue_free()
	for entry in entries:
		chip_in(row,str(entry[0]),Color(str(entry[1])) if entry.size() > 1 else Color("cfd3c8"))

func tile_in(parent: Node, caption: String) -> Dictionary:
	var tile = PanelContainer.new()
	tile.theme_type_variation = "Tile"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(tile)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",-1)
	tile.add_child(box)
	var cap = styled(label_in(box,caption.to_upper(),10),"MutedLabel") as Label
	cap.add_theme_font_size_override("font_size",10)
	var value = styled(label_in(box,"–",18),"TileValue") as Label
	value.remove_theme_font_size_override("font_size")
	return {"tile":tile,"caption":cap,"value":value}

func framed_portrait(parent: Node, minimum: Vector2) -> TextureRect:
	var frame = PanelContainer.new()
	frame.theme_type_variation = "Portrait"
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(frame)
	return portrait_in(frame,minimum)

func divider(parent: Node) -> void:
	var line = ColorRect.new()
	line.color = Color("2b3843")
	line.custom_minimum_size = Vector2(1,30)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(line)

func build_ui() -> void:
	# The map fills the whole window; every panel below is an overlay on top of it.
	board_view = GemBoardView.new()
	board_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_view.cell_clicked.connect(on_cell_clicked)
	board_view.hover_changed.connect(func(_p): refresh_hover_hint())
	add_child(board_view)
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation",0)
	add_child(root)
	# --- top bar: identity, the numbers that matter, time controls, books and menu
	var bar = PanelContainer.new()
	bar.theme_type_variation = "Bar"
	root.add_child(bar)
	var header = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation",8)
	bar.add_child(header)
	var brand = VBoxContainer.new()
	brand.add_theme_constant_override("separation",-4)
	header.add_child(brand)
	var title = styled(label_in(brand,"GemTD",24),"BrandLabel") as Label
	title.remove_theme_font_size_override("font_size")
	styled(label_in(brand,"Solo · the seven checkpoints",11),"MutedLabel")
	var spacer_left = Control.new()
	spacer_left.custom_minimum_size.x = 12
	header.add_child(spacer_left)
	var hud = PanelContainer.new()
	hud.theme_type_variation = "Hud"
	hud.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(hud)
	var hud_row = HBoxContainer.new()
	hud_row.add_theme_constant_override("separation",18)
	hud.add_child(hud_row)
	lives_value = stat_in(hud_row,pixel_icon(ICON_HEART,{"o":"3a0a10","r":"e0384a","R":"ff9a9a"}),"lives")
	divider(hud_row)
	gold_value = stat_in(hud_row,pixel_icon(ICON_COIN,{"o":"4a3008","y":"e8b62c","Y":"fff088","D":"ad7810"},4),"gold")
	divider(hud_row)
	wave_value = stat_in(hud_row,pixel_icon(ICON_WAVE,{"o":"8e9aa3","g":"b8863b"}),"wave")
	var badge = PanelContainer.new()
	badge.theme_type_variation = "Badge"
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(badge)
	phase_label = styled(label_in(badge,"",15),"BadgeLabel") as Label
	phase_label.remove_theme_font_size_override("font_size")
	status_label = label_in(header,"",12)
	status_label.visible = false
	quality_button = styled(button_in(header,"",func(): run.buy_quality()),"AccentButton") as Button
	quality_button.name = "GemOddsUpgrade"
	quality_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quality_button.add_theme_font_size_override("font_size",14)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var sound_row = HBoxContainer.new()
	sound_row.add_theme_constant_override("separation",6)
	sound_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(sound_row)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 1
	volume_slider.step = .05
	volume_slider.value = .35
	volume_slider.custom_minimum_size.x = 84
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.tooltip_text = "Sound effects volume"
	volume_slider.value_changed.connect(func(value):
		if audio != null:
			audio.volume = value
			saved_volume = value
			muted = false
			save_settings()
	)
	sound_row.add_child(volume_slider)
	styled(button_in(sound_row,"Mute  M",toggle_mute),"ToolButton")
	var time_group = HBoxContainer.new()
	time_group.add_theme_constant_override("separation",4)
	header.add_child(time_group)
	pause_button = styled(button_in(time_group,"Pause [Space]",toggle_pause),"ToolButton") as Button
	pause_button.icon = glyph(ICON_PAUSE,Color("e8c46a"))
	pause_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	speed_button = styled(button_in(time_group,"1×",toggle_speed),"ToolButton") as Button
	speed_button.custom_minimum_size.x = 44
	var nav = HBoxContainer.new()
	nav.add_theme_constant_override("separation",4)
	header.add_child(nav)
	styled(button_in(nav,"Waves",show_waves),"ToolButton")
	styled(button_in(nav,"Recipes",show_recipes),"ToolButton")
	styled(button_in(nav,"Mazes",show_mazes),"ToolButton").tooltip_text = "Maze tips: named layouts to follow while building (G shows/hides the guide)."
	styled(button_in(nav,"Help",show_help),"ToolButton")
	var full_button = styled(button_in(nav,"",toggle_fullscreen),"ToolButton") as Button
	full_button.icon = glyph(["xx.xx","x...x",".....","x...x","xx.xx"],Color("e8c46a"),3)
	full_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	full_button.tooltip_text = "Full screen on/off (F11)"
	var restart = MenuButton.new()
	restart.text = "Run  ▾"
	restart.get_popup().add_item("Same seed",0)
	restart.get_popup().add_item("New seed",1)
	restart.get_popup().add_item("Resume build checkpoint",2)
	restart.get_popup().add_separator()
	restart.get_popup().add_item("Run summary / test report",3)
	restart.get_popup().add_item("Enter seed...",4)
	restart.get_popup().add_item("Leaderboard",5)
	restart.get_popup().add_separator()
	restart.get_popup().add_item("Solo campaign · 100 waves",10)
	restart.get_popup().add_item("Review 1.0 · 10 waves",11)
	restart.get_popup().add_item("Expanded gems · 10 waves",12)
	if not OS.has_feature("web"):
		restart.get_popup().add_separator("Display")
		restart.get_popup().add_item("Full screen (native resolution)   F11",20)
		restart.get_popup().add_item("Window 1920 × 1080 (1080p)",21)
		restart.get_popup().add_item("Window 2560 × 1440 (1440p)",22)
		restart.get_popup().add_item("Window 3840 × 2160 (4K)",23)
	restart.get_popup().id_pressed.connect(func(id):
		if id in [20,21,22,23]:
			apply_display({20:"fullscreen",21:"1080p",22:"1440p",23:"2160p"}[id])
			save_settings()
		elif id in [10,11,12]:
			persist_review()
			var profile = {10:"campaign",11:"review-v1",12:"expanded-gems"}[id]
			if OS.has_feature("web"):
				Engine.get_singleton("JavaScriptBridge").eval("window.location.search = '?profile="+profile+"'")
			else:
				GemCatalog.select_profile(profile)
				get_tree().reload_current_scene()
		elif id == 3:
			show_summary()
		elif id == 4:
			show_seed_dialog()
		elif id == 5:
			show_leaderboard()
		elif id == 2:
			new_run(run.initial_seed,last_snapshot)
		else:
			new_run(run.initial_seed if id == 0 else int(Time.get_unix_time_from_system()*1000.0))
	)
	header.add_child(restart)
	# --- body: the board gets all remaining height; the sidebar is a fixed column
	var body_margin = MarginContainer.new()
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left","right","top","bottom"]:
		body_margin.add_theme_constant_override("margin_"+side,10)
	root.add_child(body_margin)
	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_margin.add_child(body)
	var field_box = VBoxContainer.new()
	field_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_box.add_theme_constant_override("separation",8)
	field_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(field_box)
	var field_row = HBoxContainer.new()
	field_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field_row.add_theme_constant_override("separation",8)
	field_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_box.add_child(field_row)
	# left of the board: the jeweller's tray holding this round's five gems
	var left_dock = VBoxContainer.new()
	left_dock.custom_minimum_size.x = 84
	left_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_row.add_child(left_dock)
	var tray_panel = PanelContainer.new()
	tray_panel.theme_type_variation = "Tray"
	tray_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left_dock.add_child(tray_panel)
	round_tray = HBoxContainer.new()
	tray_panel.add_child(round_tray)
	var tray_column = VBoxContainer.new()
	tray_column.add_theme_constant_override("separation",6)
	round_tray.add_child(tray_column)
	tray_hint = styled(label_in(tray_column,"THIS ROUND",10),"MutedLabel") as Label
	tray_hint.add_theme_font_size_override("font_size",10)
	tray_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in range(5):
		var slot = Button.new()
		slot.theme_type_variation = "SlotButton"
		slot.custom_minimum_size = Vector2(62,62)
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_constant_override("icon_max_width",46)
		slot.toggle_mode = true
		slot.focus_mode = Control.FOCUS_NONE
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.pressed.connect(func():
			if i < round_cells.size():
				on_cell_clicked(round_cells[i])
		)
		round_slots.append(slot)
		tray_column.add_child(slot)
		var number = Label.new()
		number.name = "RoundNumber"
		number.text = str(i+1)
		number.position = Vector2(4,2)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.add_theme_font_size_override("font_size",12)
		number.add_theme_color_override("font_color",Color("ffd76a"))
		number.add_theme_color_override("font_outline_color",Color("15272b"))
		number.add_theme_constant_override("outline_size",4)
		slot.add_child(number)
	round_tray.visibility_changed.connect(func():
		tray_panel.visible = round_tray.visible
		left_dock.visible = round_tray.visible
	)
	var field = Control.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.custom_minimum_size = Vector2(300,300)
	field_row.add_child(field)
	# The clear map area depends only on the window size and the fixed overlay widths,
	# never on text inside the panels, so hovering or new messages cannot move the map.
	get_viewport().size_changed.connect(update_map_area)
	bar.resized.connect(update_map_area)
	# under the board: what just happened (log strip) and the map controls
	var info_row = HBoxContainer.new()
	info_row.add_theme_constant_override("separation",10)
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_box.add_child(info_row)
	var log_panel = PanelContainer.new()
	log_panel.theme_type_variation = "Log"
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.custom_minimum_size.y = 46
	log_panel.clip_contents = true
	info_row.add_child(log_panel)
	var log_row = HBoxContainer.new()
	log_row.add_theme_constant_override("separation",14)
	log_panel.add_child(log_row)
	message_label = label_in(log_row,"",14)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.max_lines_visible = 2
	hover_hint = label_in(log_row,"",12)
	hover_hint.custom_minimum_size.x = 170
	hover_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hover_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hover_hint.clip_text = true
	hover_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tracking_button = LinkButton.new()
	tracking_button.add_theme_font_size_override("font_size",12)
	tracking_button.pressed.connect(func(): track_recipe(""))
	tracking_button.tooltip_text = "Stop highlighting this recipe's ingredients."
	log_row.add_child(tracking_button)
	maze_button = LinkButton.new()
	maze_button.add_theme_font_size_override("font_size",12)
	maze_button.add_theme_color_override("font_color",GemMazeBook.guide_color())
	maze_button.pressed.connect(func(): choose_maze_tip(""))
	maze_button.tooltip_text = "Hide the maze guide on the board (G)."
	log_row.add_child(maze_button)
	var map_panel = PanelContainer.new()
	map_panel.theme_type_variation = "Log"
	info_row.add_child(map_panel)
	var map_tools = HBoxContainer.new()
	map_tools.add_theme_constant_override("separation",8)
	map_panel.add_child(map_tools)
	var legend = HBoxContainer.new()
	legend.add_theme_constant_override("separation",8)
	legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_tools.add_child(legend)
	label_in(legend,"— Ground",12).add_theme_color_override("font_color",Color("95d7ad"))
	label_in(legend,"- - Air",12).add_theme_color_override("font_color",Color("9bc6ec"))
	label_in(legend,"— Preview",12).add_theme_color_override("font_color",GemArt.color("route_preview"))
	# Enemy route lines are opt-in with a checkbox (R toggles it too); remembered in settings.cfg.
	routes_check = CheckBox.new()
	routes_check.text = "Show routes  R"
	routes_check.focus_mode = Control.FOCUS_NONE
	routes_check.button_pressed = board_view.show_routes
	routes_check.tooltip_text = "Show the ground and air routes the enemies will walk and fly."
	routes_check.toggled.connect(set_routes)
	map_tools.add_child(routes_check)
	var fit_button = styled(button_in(map_tools,"Fit  F",func(): board_view.fit_board()),"ToolButton") as Button
	fit_button.tooltip_text = "Centre the map at the closest zoom-out. Wheel zooms; right- or middle-drag, arrow keys or WASD pan."
	# --- sidebar: wave, selection, decisions, odds, settings
	sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 372
	sidebar.add_theme_constant_override("separation",6)
	body.add_child(sidebar)
	result_box = card_in(sidebar)
	result_title = styled(label_in(result_box,"",24),"TitleLabel") as Label
	result_stats = label_in(result_box,"",14)
	result_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	styled(button_in(result_box,"Retry same seed",func(): new_run(run.initial_seed)),"HeroButton")
	button_in(result_box,"New run",func(): new_run(int(Time.get_unix_time_from_system()*1000.0)))
	button_in(result_box,"Run summary & test report",show_summary)
	result_box.visibility_changed.connect(func(): result_box.get_parent().visible = result_box.visible)
	sidebar_tabs = TabContainer.new()
	sidebar_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(sidebar_tabs)
	var pages: Dictionary = {}
	for page_name in ["Tower","Wave","Upgrades","Effects"]:
		var page = VBoxContainer.new()
		page.name = page_name
		page.add_theme_constant_override("separation",6)
		sidebar_tabs.add_child(page)
		pages[page_name] = page
	# wave card: portrait, name, property chips, rewards
	var wave_card = card_in(pages.Wave)
	wave_card.add_theme_constant_override("separation",6)
	wave_heading = styled(label_in(wave_card,"THE NEXT WAVE",15),"SectionLabel") as Label
	wave_heading.remove_theme_font_size_override("font_size")
	var enemy_card = HBoxContainer.new()
	enemy_card.add_theme_constant_override("separation",12)
	wave_card.add_child(enemy_card)
	enemy_portrait = framed_portrait(enemy_card,Vector2(64,64))
	var enemy_text = VBoxContainer.new()
	enemy_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_text.add_theme_constant_override("separation",4)
	enemy_card.add_child(enemy_text)
	wave_name = styled(label_in(enemy_text,"",20),"TitleLabel") as Label
	wave_name.remove_theme_font_size_override("font_size")
	wave_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave_rewards = label_in(enemy_text,"",13)
	wave_rewards.add_theme_color_override("font_color",Color("e8c46a"))
	wave_chips = HFlowContainer.new()
	wave_chips.add_theme_constant_override("h_separation",5)
	wave_chips.add_theme_constant_override("v_separation",5)
	wave_card.add_child(wave_chips)
	wave_traits = styled(label_in(wave_card,"",12),"MutedLabel") as Label
	wave_traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave_label = label_in(wave_card,"",13)
	wave_label.visible = false
	combat_progress = styled(label_in(wave_card,"",12),"MutedLabel") as Label
	wave_progress = ProgressBar.new()
	wave_progress.show_percentage = false
	wave_progress.custom_minimum_size.y = 10
	wave_card.add_child(wave_progress)
	boss_label = label_in(wave_card,"",14)
	boss_health = ProgressBar.new()
	boss_health.theme_type_variation = "BossHealth"
	boss_health.show_percentage = false
	boss_health.custom_minimum_size.y = 14
	wave_card.add_child(boss_health)
	# selected gem card: portrait + identity, four stat tiles, effect text, targeting
	var gem_card = card_in(pages.Tower)
	gem_card.add_theme_constant_override("separation",8)
	var selected_card = HBoxContainer.new()
	selected_card.add_theme_constant_override("separation",12)
	gem_card.add_child(selected_card)
	selected_portrait = framed_portrait(selected_card,Vector2(64,72))
	var gem_text = VBoxContainer.new()
	gem_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gem_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gem_text.add_theme_constant_override("separation",5)
	selected_card.add_child(gem_text)
	selected_label = styled(label_in(gem_text,"Select a gem",22),"TitleLabel") as Label
	selected_label.remove_theme_font_size_override("font_size")
	selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gem_chips = HFlowContainer.new()
	gem_chips.add_theme_constant_override("h_separation",5)
	gem_chips.add_theme_constant_override("v_separation",5)
	gem_text.add_child(gem_chips)
	gem_tile_grid = GridContainer.new()
	gem_tile_grid.columns = 4
	gem_tile_grid.add_theme_constant_override("h_separation",6)
	gem_card.add_child(gem_tile_grid)
	for key in [["damage","Damage"],["speed","Attack"],["dps","DPS"],["range","Range"]]:
		gem_tiles[key[0]] = tile_in(gem_tile_grid,key[1])
	gem_effect = label_in(gem_card,"",13)
	gem_effect.add_theme_color_override("font_color",Color("c6cabd"))
	gem_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gem_effect.max_lines_visible = 4
	gem_effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	affecting_effects = RichTextLabel.new()
	affecting_effects.size_flags_vertical = Control.SIZE_EXPAND_FILL
	affecting_effects.add_theme_font_size_override("normal_font_size",12)
	affecting_effects.scroll_active = true
	affecting_effects.selection_enabled = true
	affecting_effects.visible = false
	var effects_title = label_in(pages.Effects,"AFFECTING THIS TOWER",14)
	effects_title.add_theme_color_override("font_color",GemArt.color("ui_accent"))
	pages.Effects.add_child(affecting_effects)
	tower_effects_hint = label_in(pages.Effects,"Select a tower to inspect its active effects.",14)
	tower_effects_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The full text stays available (tooltips, accessibility, tests); the tiles show the same values.
	detail_label = GemTooltips.InfoLabel.new()
	detail_label.add_theme_font_size_override("font_size",13)
	gem_card.add_child(detail_label)
	detail_label.visible = false
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.mouse_filter = Control.MOUSE_FILTER_PASS
	priority = OptionButton.new()
	for mode in GemCatalog.PRIORITIES:
		priority.add_item("Target: "+mode)
	priority.item_selected.connect(func(index):
		run.set_priority(selection,GemCatalog.PRIORITIES[index])
	)
	gem_card.add_child(priority)
	tower_effects_button = button_in(gem_card,"Effects & support →",func(): sidebar_tabs.current_tab = 3)
	# decisions: one clear primary action, combinations beneath it
	var action_card = card_in(sidebar)
	action_panel = action_card.get_parent()
	action_card.add_theme_constant_override("separation",6)
	styled(label_in(action_card,"YOUR TOWER CHOICE",11),"MutedLabel")
	keep_button = styled(button_in(action_card,"Keep selected & start wave",func(): run.keep(selection)),"HeroButton") as Button
	start_trap_wave_button = styled(button_in(action_card,"Start wave",func():
		moving_trap = Vector2i(-1,-1)
		run.start_wave()
	),"HeroButton") as Button
	var combine_row = HBoxContainer.new()
	combine_row.add_theme_constant_override("separation",6)
	action_card.add_child(combine_row)
	upgrade_two = styled(button_in(combine_row,"Combine 2 · +1 quality",func(): run.upgrade(selection,2)),"AccentButton") as Button
	upgrade_four = styled(button_in(combine_row,"Combine 4 · +2 quality",func(): run.upgrade(selection,4)),"AccentButton") as Button
	upgrade_two.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_four.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	downgrade_button = styled(button_in(action_card,"Downgrade randomly & start",func(): run.downgrade(selection)),"AccentButton") as Button
	wire_preview(downgrade_button,{"type":"downgrade"})
	recipes_box = VBoxContainer.new()
	recipes_box.add_theme_constant_override("separation",6)
	action_card.add_child(recipes_box)
	recipe_choice = OptionButton.new()
	recipe_choice.item_selected.connect(func(index):
		chosen_recipe = recipe_choice.get_item_metadata(index)
		refresh_ui()
	)
	recipes_box.add_child(recipe_choice)
	for recipe in GemCatalog.recipes():
		var old_button = styled(button_in(recipes_box,"Create "+GemCatalog.recipe_title(recipe)+" · old only",func(): run.combine(recipe,selection,true)),"AccentButton") as Button
		var is_trap = GemCatalog.stats({"kind":GemCatalog.recipe_result(recipe),"tier":1}).get("slab",false)
		var final_button = styled(button_in(recipes_box,"Create "+GemCatalog.recipe_title(recipe)+(" & position" if is_trap else " & start"),func(): run.combine(recipe,selection)),"HeroButton") as Button
		old_button.visible = false
		final_button.visible = false
		wire_preview(old_button,{"type":"recipe","recipe":recipe,"old_only":true})
		wire_preview(final_button,{"type":"recipe","recipe":recipe,"old_only":false})
		recipe_buttons[recipe] = {"old": old_button,"final": final_button}
	var minor_actions = HBoxContainer.new()
	minor_actions.add_theme_constant_override("separation",6)
	action_card.add_child(minor_actions)
	demolish_button = styled(button_in(minor_actions,"Demolish selected  X",func(): run.demolish(selection)),"DangerButton") as Button
	demolish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_trap_button = button_in(minor_actions,"Move path trap",func():
		cancel_tower_move()
		moving_trap = selection
		run.message = "Click an empty cell to move this path trap. Click the same trap to cancel."
		refresh_ui()
	)
	move_trap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_tower_button = styled(button_in(minor_actions,"Move tower",func():
		if board_view.guide.moving_tower != Vector2i(-1,-1):
			cancel_tower_move()
			run.message = "Tower move cancelled. No move used."
		elif run.tower_move_source_error(selection).is_empty():
			moving_trap = Vector2i(-1,-1)
			board_view.guide.moving_tower = selection
			board_view.guide.invalidate()
			run.message = "Click an empty cell or a stone. Stone swaps to the old cell. Escape or click this tower to cancel."
		refresh_ui()
	),"AccentButton") as Button
	move_tower_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wire_preview(keep_button,{"type":"keep"})
	wire_preview(upgrade_two,{"type":"upgrade","count":2})
	wire_preview(upgrade_four,{"type":"upgrade","count":4})
	wire_preview(demolish_button,{"type":"demolish"})
	# quality odds as a stacked bar with a legend
	var odds_card = card_in(pages.Upgrades)
	odds_card.add_theme_constant_override("separation",6)
	styled(label_in(odds_card,"Gem quality odds",15),"SectionLabel").remove_theme_font_size_override("font_size")
	odds_bar = HBoxContainer.new()
	odds_bar.add_theme_constant_override("separation",2)
	odds_bar.custom_minimum_size.y = 8
	odds_card.add_child(odds_bar)
	odds_legend = HFlowContainer.new()
	odds_legend.add_theme_constant_override("h_separation",5)
	odds_legend.add_theme_constant_override("v_separation",5)
	odds_card.add_child(odds_legend)
	odds_label = label_in(odds_card,"",13)
	odds_label.visible = false
	odds_discount = styled(label_in(odds_card,"",12),"MutedLabel") as Label
	odds_discount.visible = false
	# gold spells: source hero prays (next gem) and castle heal, campaign only
	var spell_box = card_in(pages.Upgrades)
	spells_card = spell_box.get_parent()
	spell_box.add_theme_constant_override("separation",6)
	styled(label_in(spell_box,"Gold spells",15),"SectionLabel").remove_theme_font_size_override("font_size")
	var type_row = GridContainer.new()
	type_row.columns = 8
	type_row.add_theme_constant_override("h_separation",3)
	spell_box.add_child(type_row)
	var quality_row = HBoxContainer.new()
	quality_row.add_theme_constant_override("separation",4)
	spell_box.add_child(quality_row)
	for id in GemCatalog.DATA.get("spells",{}):
		var data: Dictionary = GemCatalog.DATA.spells[id]
		var button: Button
		if data.group == "type":
			button = styled(button_in(type_row,"",func(): run.cast_spell(id)),"ToolButton") as Button
			button.icon = GemArt.texture(GemArt.sprite_id("gems",data.kind,1))
			button.expand_icon = true
			button.custom_minimum_size = Vector2(38,38)
			button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		elif data.group == "quality":
			button = styled(button_in(quality_row,"%s · %dg" % [GemCatalog.quality_name(int(data.tier)),int(data.cost)],func(): run.cast_spell(id)),"ToolButton") as Button
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			button = styled(button_in(spell_box,"Heal %d–%d lives · %d gold" % [int(data.min_heal),int(data.max_heal),int(data.cost)],func(): run.cast_spell(id)),"AccentButton") as Button
		button.focus_mode = Control.FOCUS_NONE
		spell_buttons[id] = button
	spell_status = styled(label_in(spell_box,"",12),"MutedLabel") as Label
	spell_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var settings_panel = PanelContainer.new()
	settings_panel.theme_type_variation = "Log"
	sidebar.add_child(settings_panel)
	var settings = VBoxContainer.new()
	settings.add_theme_constant_override("separation",2)
	settings_panel.add_child(settings)
	save_label = styled(label_in(settings,"",11),"MutedLabel") as Label
	save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_label.max_lines_visible = 1
	save_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer_label = styled(label_in(settings,"",11),"MutedLabel") as Label
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.max_lines_visible = 1
	footer_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer_label.add_theme_color_override("font_color",Color("5d6a73"))
	dim = ColorRect.new()
	dim.color = Color(0.03,0.05,0.07,0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.visible = false
	add_child(dim)
	recipe_popup = AcceptDialog.new()
	recipe_popup.title = "Recipe book"
	recipe_popup.min_size = Vector2i(660,570)
	recipe_text = RichTextLabel.new()
	recipe_text.bbcode_enabled = true
	recipe_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	recipe_text.offset_bottom = -45
	recipe_popup.add_child(recipe_text)
	add_child(recipe_popup)
	connect_modal_pause(recipe_popup)
	recipe_book = GemRecipeBook.new()
	add_child(recipe_book)
	connect_modal_pause(recipe_book)
	recipe_book.locate_requested.connect(locate_ingredient)
	recipe_book.track_requested.connect(track_recipe)
	maze_book = GemMazeBook.new()
	add_child(maze_book)
	connect_modal_pause(maze_book)
	maze_book.tip_chosen.connect(choose_maze_tip)
	wave_book = GemWaveBook.new()
	add_child(wave_book)
	connect_modal_pause(wave_book)
	summary_dialog = GemRunSummary.new()
	add_child(summary_dialog)
	connect_modal_pause(summary_dialog)
	summary_dialog.leaderboard_requested.connect(show_leaderboard)
	leaderboard_dialog = GemLeaderboardDialog.new()
	add_child(leaderboard_dialog)
	connect_modal_pause(leaderboard_dialog)
	seed_dialog = GemSeedDialog.new()
	add_child(seed_dialog)
	connect_modal_pause(seed_dialog)
	seed_dialog.seed_requested.connect(func(value): new_run(value))

func update_map_area() -> void:
	if board_view == null:
		return
	var top = 62.0
	for child in get_children():
		if child is VBoxContainer and child.get_child_count() > 0 and child.get_child(0) is PanelContainer:
			top = maxf(top,(child.get_child(0) as Control).size.y+10.0)
	var left = 10.0+84.0+8.0
	var right = 10.0+372.0+12.0
	var bottom = 10.0+46.0+8.0
	board_view.safe_rect = Rect2(Vector2(left,top),Vector2(maxf(200,size.x-left-right),maxf(200,size.y-top-bottom)))
	board_view.queue_redraw()

func connect_modal_pause(dialog: Window) -> void:
	var restore = {"paused":false}
	dialog.about_to_popup.connect(func():
		if dim != null: dim.visible = true
		restore.paused = paused
		paused = true
		refresh_ui()
	)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			if dim != null: dim.visible = [recipe_popup,recipe_book,maze_book,wave_book,summary_dialog,seed_dialog,leaderboard_dialog].any(func(d): return d != null and d != dialog and d.visible)
			paused = bool(restore.paused)
			refresh_ui()
	)

func new_run(seed_value: int, restore_data: Dictionary = {}) -> void:
	if journal != null and not journal.actions.is_empty():
		persist_review()
	hide_other_dialogs()
	recipe_popup.hide()
	recipe_book.reset()
	maze_book.reset()
	wave_book.reset()
	paused = false
	accumulator = 0
	selection = Vector2i(-1,-1)
	moving_trap = Vector2i(-1,-1)
	active_preview = {}
	started_wave = {}
	last_wave_report = ""
	score_prompt_run_id = ""
	chosen_recipe = ""
	sidebar_tabs.current_tab = 0
	run = GemRun.new(seed_value)
	var did_restore = not restore_data.is_empty() and run.restore(restore_data)
	if not restore_data.is_empty() and not did_restore:
		run.message = "Saved checkpoint was incompatible or damaged. Started a new run."
	combat = GemCampaignCombat.new(run) if GemCatalog.campaign() else GemCombat.new(run)
	journal = GemReviewJournal.new()
	journal.reset(run,did_restore)
	run.action_recorded.connect(func(entry):
		journal.record(entry,combat)
		if entry.action in ["keep","upgrade","downgrade","recipe"]: active_preview = {}
	)
	run.changed.connect(func():
		board_view.sync_board()
		refresh_ui()
	)
	run.combat_started.connect(func():
		started_wave = {"wave":run.wave,"kills":run.kills,"leaks":run.leaks,"lives":run.lives}
		combat.start()
		journal.begin_wave(run)
		accumulator = 0.0
	)
	run.build_started.connect(save_checkpoint)
	run.sound_requested.connect(audio.play_cue)
	combat.shot.connect(board_view.add_shot)
	combat.shot.connect(audio.play_attack)
	if combat is GemCampaignCombat:
		var campaign = combat as GemCampaignCombat
		campaign.projectile_launched.connect(board_view.add_projectile_launch)
		campaign.projectile_launched.connect(audio.play_attack)
		campaign.ability_visual.connect(board_view.ability_happened)
	combat.damaged.connect(board_view.enemy_damaged)
	combat.evaded.connect(board_view.effects.evaded)
	combat.escaped.connect(board_view.effects.escaped)
	combat.area_attack.connect(board_view.add_area_attack)
	board_view.run = run
	board_view.combat = combat
	board_view.selected = selection
	board_view.reset_visuals()
	board_view.fit_board()
	save_checkpoint()
	refresh_ui()

func on_cell_clicked(p: Vector2i) -> void:
	if sidebar_tabs.current_tab != 3: sidebar_tabs.current_tab = 0
	var from = board_view.guide.moving_tower
	if from != Vector2i(-1,-1):
		if p == from:
			cancel_tower_move()
			run.message = "Tower move cancelled. No move used."
		elif run.move_tower(from,p):
			cancel_tower_move()
			selection = p
			board_view.selected = p
		refresh_ui()
		return
	if moving_trap != Vector2i(-1,-1):
		if p == moving_trap or run.move_slab(moving_trap,p):
			moving_trap = Vector2i(-1,-1)
			selection = p
			board_view.selected = p
		refresh_ui()
		return
	selection = p
	board_view.selected = p
	if not run.board.cells.has(p) and not run.board.slabs.has(p) and run.phase == "build" and run.placed < 5:
		if not run.place(p):
			board_view.effects.add("ring",Vector2(p)+Vector2(.5,.5),GemArt.color("placement_blocked"),.45,{"radius":.65})
	refresh_ui()

func cancel_tower_move() -> void:
	board_view.guide.moving_tower = Vector2i(-1,-1)
	board_view.guide.invalidate()

func wire_preview(button: Button, request: Dictionary) -> void:
	button.mouse_entered.connect(func():
		active_preview = request
		refresh_action_preview()
	)
	button.mouse_exited.connect(func():
		if active_preview == request:
			active_preview = {}
			refresh_action_preview()
	)
	button.focus_entered.connect(func():
		active_preview = request
		refresh_action_preview()
	)
	button.focus_exited.connect(func():
		if active_preview == request:
			active_preview = {}
			refresh_action_preview()
	)

func refresh_action_preview() -> void:
	if run == null:
		return
	if run.phase != "build" and not (GemCatalog.campaign() and run.phase == "combat" and active_preview.get("type","") == "recipe"):
		active_preview = {}
	board_view.action_plan = {} if active_preview.is_empty() else board_view.guide.action(active_preview,selection)
	message_label.text = base_message() if active_preview.is_empty() else str(board_view.action_plan.message)
	message_label.add_theme_color_override("font_color",GemArt.color("ui_accent") if board_view.action_plan.get("valid",false) else GemArt.color("ui_text"))
	board_view.queue_redraw()

func base_message() -> String:
	return run.message+("\n"+last_wave_report if not last_wave_report.is_empty() and run.phase != "combat" else "")

func update_wave_report() -> void:
	if started_wave.is_empty() or run.phase == "combat":
		return
	journal.complete_wave(run,combat)
	persist_review()
	last_wave_report = "Wave %d: %d defeated · %d leaked · %d lives lost." % [int(started_wave.wave),run.kills-int(started_wave.kills),run.leaks-int(started_wave.leaks),int(started_wave.lives)-run.lives]
	if GemCatalog.campaign() and not str(combat.last_mvp).is_empty(): last_wave_report += "\n"+str(combat.last_mvp)
	started_wave = {}

func refresh_hover_hint() -> void:
	if run == null or hover_hint == null:
		return
	var info = board_view.guide.placement(board_view.hovered)
	hover_hint.text = info.message
	hover_hint.tooltip_text = info.message
	hover_hint.add_theme_color_override("font_color",GemArt.color("placement_blocked" if info.status == "blocked" else "ui_muted"))

func update_action_button(button: Button, request: Dictionary) -> void:
	var info = board_view.guide.action(request,selection)
	button.disabled = not info.valid
	button.tooltip_text = info.message
	if info.valid and not info.result.is_empty():
		button.tooltip_text = GemTowerInfo.action_tooltip(info,run.board.cells)

func refresh_ui() -> void:
	if run == null:
		return
	if board_view.guide.moving_tower != Vector2i(-1,-1) and not run.tower_move_source_error(board_view.guide.moving_tower).is_empty(): cancel_tower_move()
	if run.awaiting_trap_placement and not run.board.slabs.has(selection):
		selection = run.pending_trap
		board_view.selected = selection
	update_wave_report()
	status_label.text = "Lives %d    Gold %d    Wave %d / %d" % [run.lives,run.gold,run.wave,GemCatalog.wave_count()]
	lives_value.text = str(run.lives)
	gold_value.text = str(run.gold)
	wave_value.text = "%d / %d" % [run.wave,GemCatalog.wave_count()]
	footer_label.text = "GemTD Solo %s  ·  %d gem types, %d qualities, %d waves  ·  seed %d" % [GemRelease.version(),GemCatalog.TYPES.size(),GemCatalog.quality_limit(GemCatalog.TYPES[0]),GemCatalog.wave_count(),run.initial_seed]
	var terminal = run.phase in ["won","lost"]
	if terminal and GemCatalog.campaign() and score_prompt_run_id != journal.run_id:
		# Defer until the final combat tick and wave journal have finished.
		score_prompt_run_id = journal.run_id
		show_finished_run_score.call_deferred(journal.run_id)
	result_box.visible = terminal
	if terminal:
		result_title.text = "VICTORY" if run.phase == "won" else "DEFEAT"
		result_title.add_theme_color_override("font_color",GemArt.color("ui_accent"))
		result_stats.text = "Wave %d / %d · %d lives\n%d defeated · %d leaked\nSeed %d" % [run.wave,GemCatalog.wave_count(),run.lives,run.kills,run.leaks,run.initial_seed]
	var maze = board_view.maze_progress
	maze_button.visible = not maze.is_empty()
	if not maze.is_empty():
		maze_button.text = "Maze: %s %d/%d · Hide (G)" % [GemMazeTips.tip(board_view.maze_tip).name,maze.done.size(),maze.total]
	var tracking = board_view.tracking_progress
	tracking_button.visible = not tracking.is_empty()
	if not tracking.is_empty():
		tracking_button.text = "%s %d/%d · Unpin" % [GemCatalog.recipe_title(board_view.tracked_recipe),tracking.collected,tracking.total]
	phase_label.text = {"build":"Build  %d of 5" % run.placed,"intermission":"Next trial in %.1fs" % run.trial_wait,"combat":"Combat","won":"Victory","lost":"Defeat"}[run.phase]
	if run.awaiting_trap_placement: phase_label.text = "Position trap"
	if run.phase in ["combat","intermission"]:
		phase_label.text += "  paused" if paused else "  %d×" % speed
	var w = combat.wave_data if GemCatalog.campaign() and run.phase == "combat" else GemCatalog.wave(run.wave)
	if GemCatalog.campaign() and run.phase == "build" and not w.boss:
		w = w.duplicate(true)
		w.count = run.enemy_count
	wave_heading.text = {"build":"THE NEXT WAVE","intermission":"NEXT TRIAL · NO NEW GEMS","combat":"CURRENT WAVE","won":"FINAL WAVE","lost":"LAST WAVE"}[run.phase]
	enemy_portrait.texture = GemArt.texture(GemArt.sprite_id("enemies",w.source_id))
	wave_label.text = GemWaveGuide.brief(w,run.wave)
	refresh_wave_card(w)
	refresh_combat_progress(w)
	var odds: Array = GemCatalog.DATA.quality_odds[run.quality]
	odds_label.text = GemCatalog.odds_text(odds)
	var odds_maxed = run.quality >= GemCatalog.max_quality_upgrade()
	quality_button.text = "Gem odds ↑ %d gold" % run.quality_price() if not odds_maxed else "Gem odds · MAX"
	quality_button.disabled = odds_maxed or run.phase in ["won","lost"] or (not odds_maxed and run.gold < run.quality_price())
	if GemCatalog.campaign() and run.wave > 50:
		quality_button.text = "Gem odds · locked"
		quality_button.disabled = true
	quality_button.tooltip_text = "All available odds upgrades purchased." if odds_maxed else "Affects future placements only. Need %d gold; have %d." % [run.quality_price(),run.gold]
	quality_button.tooltip_text = "Gem quality upgrade\n"+GemCatalog.odds_text(odds)+"\n"+quality_button.tooltip_text
	if GemCatalog.campaign() and run.wave > 50: quality_button.tooltip_text += "\nTrials grant no new gems."
	if GemCatalog.campaign() and not odds_maxed:
		odds_label.text += "\nBoss discount saved: %d gold" % run.quality_discount
		quality_button.tooltip_text += "\nBase price %d; saved discount %d. Defeat bosses 10/20/30/40/50 for +150 discount. Unused discount carries to the next purchase." % [int(GemCatalog.DATA.quality_costs[run.quality]),run.quality_discount]
	refresh_odds(odds)
	save_label.visible = not save_label.text.is_empty()
	odds_discount.text = "Boss discount saved: %d gold" % run.quality_discount
	odds_discount.visible = GemCatalog.campaign() and not odds_maxed
	refresh_spells()
	message_label.text = run.message
	pause_button.icon = glyph(ICON_PLAY if paused else ICON_PAUSE,Color("e8c46a"))
	pause_button.text = "Resume [Space]" if paused else "Pause [Space]"
	pause_button.disabled = terminal
	speed_button.disabled = terminal
	speed_button.text = "%d×" % speed
	var gem: Dictionary = run.board.cells.get(selection,{})
	if run.board.slabs.has(selection): gem = {"kind":run.board.slabs[selection],"tier":1,"fresh":false,"priority":"First"}
	move_trap_button.visible = run.board.slabs.has(selection)
	move_trap_button.disabled = run.phase != "build"
	detail_label.tooltip_text = GemTowerInfo.DPS_NOTE if not gem.is_empty() and gem.get("kind","stone") != "stone" else ""
	selected_portrait.texture = GemArt.texture("checkpoint") if gem.is_empty() else GemArt.texture(GemArt.sprite_id("gems",gem.kind,int(gem.tier)))
	priority.visible = not terminal and not gem.is_empty() and not run.board.slabs.has(selection) and gem.get("kind", "stone") != "stone" and not GemTowerInfo.profile(gem,selection,run.board.cells,combat).get("aura",false)
	selected_label.text = GemCatalog.title(gem) if not gem.is_empty() else "Place a gem" if run.phase == "build" and run.placed < 5 else "Select a gem"
	if not gem.is_empty() and GemReadability.DATA.special_codes.has(gem.kind): selected_label.tooltip_text = "Map badge: "+GemReadability.tower_label(gem)
	else: selected_label.tooltip_text = ""
	if gem.is_empty():
		if run.phase == "combat":
			detail_label.text = "Select an older tower to inspect its effects or combine an available recipe.\n\nNew gems and demolition are locked during combat." if GemCatalog.campaign() else "Select a tower to inspect its effects and targeting.\n\nBoard changes are available in the next build phase."
		elif terminal:
			detail_label.text = "Use the result controls to play again, or open the run summary to review this session."
		else:
			detail_label.text = "Select a new gem for your final choice. Tower choices start combat; traps can be positioned first." if run.placed == 5 else "Click an empty cell to place. New gems glow until your final choice.\n\nTower choices start combat. Traps can be positioned first."
	else:
		detail_label.text = str(GemCatalog.stats(gem).effect) if gem.kind == "stone" else ("NEW THIS ROUND\n" if gem.fresh else "")+GemTowerInfo.describe(GemTowerInfo.profile(gem,selection,run.board.cells,combat))
		priority.select(maxi(0,GemCatalog.PRIORITIES.find(gem.priority)))
	refresh_gem_card(gem,terminal)
	action_panel.visible = run.phase == "build" or (GemCatalog.campaign() and run.phase == "combat")
	start_trap_wave_button.visible = run.awaiting_trap_placement
	keep_button.visible = run.phase == "build" and not run.awaiting_trap_placement
	upgrade_two.visible = keep_button.visible
	upgrade_four.visible = keep_button.visible
	demolish_button.visible = keep_button.visible
	if GemCatalog.campaign() and not gem.is_empty() and not gem.get("fresh",false):
		keep_button.visible = false
		upgrade_two.visible = false
		upgrade_four.visible = false
	downgrade_button.visible = GemCatalog.campaign() and keep_button.visible
	update_action_button(downgrade_button,{"type":"downgrade"})
	update_action_button(keep_button,{"type":"keep"})
	update_action_button(upgrade_two,{"type":"upgrade","count":2})
	update_action_button(upgrade_four,{"type":"upgrade","count":4})
	update_action_button(demolish_button,{"type":"demolish"})
	move_tower_button.visible = GemCatalog.campaign() and run.phase == "build" and not gem.is_empty() and gem.kind != "stone" and not run.board.slabs.has(selection)
	var move_error = run.tower_move_source_error(selection) if GemCatalog.campaign() else ""
	move_tower_button.disabled = not move_error.is_empty()
	if board_view.guide.moving_tower != Vector2i(-1,-1): move_tower_button.text = "Cancel move"
	elif run.tower_moves_left > 0: move_tower_button.text = "Move tower · %d / %d free" % [run.tower_moves_left,int(GemCatalog.DATA.get("mechanics",{}).get("tower_moves_per_run",5))]
	else: move_tower_button.text = "Move tower · %dg" % run.tower_move_price()
	move_tower_button.tooltip_text = move_error if not move_error.is_empty() else "Move to an empty cell or swap with a stone. Five free moves per run, then %d gold per successful move. Invalid moves and cancellation are free. Tower quality, MVP, abilities and targeting are preserved." % int(GemCatalog.DATA.get("mechanics",{}).get("tower_move_cost_after_free",100))
	round_tray.visible = run.phase == "build" and not run.awaiting_trap_placement
	round_cells = run.fresh_cells()
	for i in range(5):
		var slot = round_slots[i]
		slot.disabled = i >= round_cells.size()
		slot.icon = null
		slot.text = str(i+1) if slot.disabled else ""
		slot.get_node("RoundNumber").visible = not slot.disabled
		slot.set_pressed_no_signal(not slot.disabled and round_cells[i] == selection)
		slot.tooltip_text = "Not placed yet. Click an empty board cell."
		if not slot.disabled:
			var revealed: Dictionary = run.board.cells[round_cells[i]]
			slot.icon = GemArt.texture(GemArt.sprite_id("gems",revealed.kind,int(revealed.tier)))
			slot.tooltip_text = "Gem %d: %s\nClick to select on the board." % [i+1,GemCatalog.title(revealed)]
	for recipe in GemCatalog.recipes():
		var old_materials = run.recipe_materials(recipe,selection,true)
		var any_materials = run.recipe_materials(recipe,selection)
		var actions: Dictionary = recipe_buttons[recipe]
		actions.old.visible = not old_materials.is_empty()
		update_action_button(actions.old,{"type":"recipe","recipe":recipe,"old_only":true})
		actions.final.visible = not any_materials.is_empty() and any_materials != old_materials
		update_action_button(actions.final,{"type":"recipe","recipe":recipe,"old_only":false})
	refresh_recipe_choices()
	save_label.tooltip_text = save_label.text
	footer_label.tooltip_text = footer_label.text
	refresh_hover_hint()
	refresh_action_preview()
	board_view.queue_redraw()

func refresh_recipe_choices() -> void:
	var available: Array[String] = []
	for recipe in GemCatalog.recipes():
		var actions: Dictionary = recipe_buttons[recipe]
		if actions.old.visible or actions.final.visible: available.append(recipe)
	if chosen_recipe not in available: chosen_recipe = "" if available.is_empty() else available[0]
	# Bound the action panel even when a late-game inventory offers many recipes.
	var previous: Array[String] = []
	for index in range(recipe_choice.item_count): previous.append(str(recipe_choice.get_item_metadata(index)))
	if previous != available:
		recipe_choice.clear()
		for recipe in available:
			recipe_choice.add_item("Recipe: "+GemCatalog.recipe_title(recipe))
			recipe_choice.set_item_metadata(recipe_choice.item_count-1,recipe)
	if not available.is_empty(): recipe_choice.select(available.find(chosen_recipe))
	recipe_choice.visible = available.size() > 1
	for recipe in available:
		if recipe != chosen_recipe:
			recipe_buttons[recipe].old.visible = false
			recipe_buttons[recipe].final.visible = false

func spell_summary(id: String) -> String:
	var data = GemRun.spell(id)
	if data.group == "heal": return "Heal · %d gold
Restore %d–%d lives at random, up to %d. Between waves only." % [int(data.cost),int(data.min_heal),int(data.max_heal),GemCatalog.starting_lives()]
	if data.group == "type": return "%s Pray · %d gold
%d%% chance that your next gem is %s. Quality is rolled as usual." % [str(data.kind).capitalize(),int(data.cost),int(data.chance)-1,str(data.kind).capitalize()]
	return "Quality %s Pray · %d gold
%d%% chance that your next gem becomes quality %s, replacing the rolled quality (even a higher one). One success per round." % [GemCatalog.quality_name(int(data.tier)),int(data.cost),int(data.chance)-1,GemCatalog.quality_name(int(data.tier))]

func refresh_spells() -> void:
	spells_card.visible = GemCatalog.campaign() and not GemCatalog.DATA.get("spells",{}).is_empty() and run.phase not in ["won","lost"]
	if not spells_card.visible: return
	for id in spell_buttons:
		var error = run.spell_error(id)
		var button: Button = spell_buttons[id]
		button.disabled = not error.is_empty()
		button.modulate = Color(1.3,1.15,.6) if id in [run.type_pray,run.quality_pray] else Color.WHITE
		button.tooltip_text = spell_summary(id)+("" if error.is_empty() else "
"+error)
	var waiting: Array = []
	for id in [run.type_pray,run.quality_pray]:
		if not id.is_empty(): waiting.append(spell_summary(id).get_slice(" ·",0))
	spell_status.text = "Waiting for your next gem: "+", ".join(waiting) if not waiting.is_empty() else "Trials: heal only." if run.wave > 50 else "Prays apply to your next gem. Hover for odds."

func refresh_wave_card(w: Dictionary) -> void:
	wave_name.text = str(w.name).left(1).to_upper()+str(w.name).substr(1)
	wave_rewards.text = "Kills +%d gold · Clear +%d" % [int(w.reward),int(w.completion)]
	var leak = "instant defeat" if w.boss else "%d life%s" % [int(w.leak),"" if int(w.leak) == 1 else "s"]
	if GemCatalog.campaign() and not w.boss and w.has("leak_max"):
		leak = "%d–%d lives" % [int(w.leak),int(w.leak_max)]
	var entries = [
		["%d × %s" % [int(w.count),"Air" if w.air else "Ground"],"9bc6ec" if w.air else "95d7ad"],
		["HP %s" % String.num(float(w.hp),2)],
		["Armor %.0f" % float(w.armor)],
		["Magic %+.0f%%" % (float(w.magic_resist)*100)],
		["Leak: "+leak,"ef9a8a" if w.boss else "cfd3c8"],
	]
	if float(w.get("evasion",0)) > 0:
		entries.append(["Evasion %.0f%%" % (float(w.evasion)*100),"e8c46a"])
	set_chips(wave_chips,entries)
	var traits = GemWaveGuide.campaign_traits(w) if GemCatalog.campaign() else ""
	if GemCatalog.campaign() and GemCatalog.boss_discount_for_wave(run.wave) > 0:
		traits = ("Boss defeat: +150 saved gem discount\n"+traits).strip_edges()
	wave_traits.text = traits
	wave_traits.visible = not traits.is_empty()

func refresh_odds(odds: Array) -> void:
	var key = JSON.stringify(odds)
	if chip_cache.get("odds","") == key:
		return
	chip_cache["odds"] = key
	for child in odds_bar.get_children():
		child.queue_free()
	for child in odds_legend.get_children():
		child.queue_free()
	for i in range(odds.size()):
		var weight = float(odds[i])
		if weight <= 0:
			continue
		var segment = ColorRect.new()
		segment.color = Color(QUALITY_TINTS[mini(i,QUALITY_TINTS.size()-1)])
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.size_flags_stretch_ratio = weight
		odds_bar.add_child(segment)
		chip_in(odds_legend,"%s  %d%%" % [GemCatalog.quality_name(i+1),int(weight)],Color(QUALITY_TINTS[mini(i,QUALITY_TINTS.size()-1)]))

func refresh_gem_card(gem: Dictionary, terminal: bool) -> void:
	var is_stone = gem.is_empty() or gem.get("kind","stone") == "stone" or run.board.slabs.has(selection)
	affecting_effects.visible = not is_stone
	tower_effects_button.visible = not is_stone
	tower_effects_hint.visible = is_stone
	gem_effect.tooltip_text = ""
	if not is_stone:
		var effects_text = GemTowerEffects.text(gem,selection,run.board.cells,combat)
		if affecting_effects.text != effects_text or effects_selection != selection:
			var scroll = affecting_effects.get_v_scroll_bar().value if effects_selection == selection else 0.0
			affecting_effects.text = effects_text
			affecting_effects.get_v_scroll_bar().set_deferred("value",scroll)
		effects_selection = selection
	else:
		effects_selection = Vector2i(-1,-1)
	var info = {} if gem.is_empty() or run.board.slabs.has(selection) else GemTowerInfo.profile(gem,selection,run.board.cells,combat)
	gem_tile_grid.visible = not info.is_empty()
	var entries = []
	if not gem.is_empty() and not terminal:
		if gem.get("fresh",false) and not run.board.slabs.has(selection):
			entries.append(["NEW THIS ROUND","e8c46a"])
		if not info.is_empty():
			entries.append([str(info.targets),"95d7ad" if str(info.targets) == "Ground only" else "9bc6ec"])
			if gem.has("tier") and gem.kind != "asteriated_ruby":
				entries.append(["Quality "+GemCatalog.quality_name(int(gem.tier)),QUALITY_TINTS[mini(int(gem.tier)-1,QUALITY_TINTS.size()-1)]])
	set_chips(gem_chips,entries)
	if info.is_empty():
		gem_effect.text = ""
		if not gem.is_empty() and not run.board.slabs.has(selection):
			gem_effect.text = str(GemCatalog.stats(gem).effect) if gem.kind == "stone" else ""
		else:
			gem_effect.text = detail_label.text
		gem_effect.visible = not gem_effect.text.is_empty()
		return
	gem_tiles.damage.caption.text = ("MAGIC" if info.aura else "PHYSICAL")
	gem_tiles.damage.value.text = str(snappedf(info.damage,.01))
	gem_tiles.speed.caption.text = "TICK" if info.aura else "ATTACK"
	gem_tiles.range.caption.text = "AURA RADIUS" if info.aura else "RANGE"
	gem_tiles.speed.value.text = "%.2fs" % float(info.interval)
	gem_tiles.dps.caption.text = "AURA DPS" if info.aura else "ATTACK DPS"
	gem_tiles.dps.value.text = "%.1f" % info.dps
	gem_tiles.range.value.text = "%.1f" % info.range
	var blocks = GemTowerInfo.describe(info).split("\n\n")
	var lines = blocks[0].split("\n")
	var notes: PackedStringArray = lines.slice(2 if info.aura else 3)
	var tail: PackedStringArray = blocks.slice(1)
	gem_effect.text = "\n".join(notes)+("\n" if not notes.is_empty() and not tail.is_empty() else "")+"\n\n".join(tail)
	gem_effect.text = gem_effect.text.strip_edges()
	gem_effect.tooltip_text = gem_effect.text
	gem_effect.visible = not gem_effect.text.is_empty()

func _process(dt: float) -> void:
	if run == null:
		return
	var was_combat = run.phase in ["combat","intermission"]
	if was_combat and not paused:
		accumulator += minf(dt,.25)*speed
		while accumulator >= 1.0/30.0 and run.phase in ["combat","intermission"]:
			board_view.capture_positions()
			board_view.advance_visuals(1.0/30.0)
			combat.tick(1.0/30.0)
			accumulator = maxf(0,accumulator-1.0/30.0)
		# Draw enemies between the last two simulation steps for smooth 60+ fps movement.
		board_view.tick_alpha = clampf(accumulator*30.0,0.0,1.0)
		board_view.queue_redraw()
	if not was_combat and not paused:
		board_view.advance_visuals(dt)
	ui_clock += dt
	if ui_clock >= .2:
		ui_clock = 0
		refresh_ui()

func refresh_combat_progress(wave: Dictionary) -> void:
	var fighting = run.phase == "combat"
	combat_progress.visible = fighting
	wave_progress.visible = fighting
	boss_label.visible = fighting and bool(wave.boss)
	boss_health.visible = boss_label.visible
	if not fighting:
		return
	var resolved = run.kills-int(started_wave.get("kills",run.kills))+run.leaks-int(started_wave.get("leaks",run.leaks))
	wave_progress.max_value = int(wave.count)
	wave_progress.value = clampi(resolved,0,int(wave.count))
	var alive = combat.enemies.filter(func(enemy): return GemCombat.alive(enemy))
	combat_progress.text = "Resolved %d / %d · Alive %d · Incoming %d" % [resolved,int(wave.count),alive.size(),maxi(0,int(wave.count)-combat.spawned)]
	if GemCatalog.campaign():
		combat_progress.text += "\nBERSERK · +100% speed · magic immune" if combat.berserk else "\nBerserk in %.0fs · +100%% speed and magic immunity" % maxf(0,float(GemCatalog.DATA.mechanics.berserk_seconds)-combat.elapsed)
	if boss_label.visible:
		boss_health.max_value = float(wave.hp) if alive.is_empty() else float(alive[0].hp_max)
		boss_health.value = float(wave.hp) if alive.is_empty() else float(alive[0].hp)
		boss_label.text = "Boss health: %.0f / %.0f" % [boss_health.value,boss_health.max_value]

func hide_other_dialogs(except: Window = null) -> void:
	for dialog in [recipe_popup,recipe_book,maze_book,wave_book,summary_dialog,seed_dialog,leaderboard_dialog]:
		if dialog != null and dialog != except:
			dialog.hide()

func persist_review() -> void:
	if not smoke and journal != null:
		var error = GemSave.write_snapshot(journal.export_report(run,combat),("user://last_review_campaign_v%d.json" % int(GemCatalog.DATA.version)) if GemCatalog.campaign() else "user://last_review_expanded_gems_dev.json" if GemCatalog.expanded_gems() else "user://last_review_v1.json")
		if error != OK:
			push_warning("Could not save local review report: "+error_string(error))

func show_summary() -> void:
	if summary_dialog.visible:
		return
	hide_other_dialogs(summary_dialog)
	var report = journal.export_report(run,combat)
	persist_review()
	summary_dialog.open_report(report)

func show_leaderboard() -> void:
	if leaderboard_dialog.visible: return
	hide_other_dialogs(leaderboard_dialog)
	leaderboard_dialog.open_report(journal.export_report(run,combat))

func show_finished_run_score(expected_run_id: String) -> void:
	# A restart may happen before this deferred callback gets its turn.
	if journal.run_id != expected_run_id or run.phase not in ["won","lost"]: return
	show_leaderboard()

func show_seed_dialog() -> void:
	if seed_dialog.visible:
		return
	hide_other_dialogs(seed_dialog)
	seed_dialog.open_for(run.initial_seed)

func _input(event: InputEvent) -> void:
	# Space belongs to pause before a focused Button can also activate on
	# key release. Text fields and modal windows retain their own keyboard UI.
	if not event is InputEventKey or event.keycode != KEY_SPACE: return
	if run == null or run.phase not in ["build","combat","intermission"]: return
	for dialog in [recipe_popup,recipe_book,maze_book,wave_book,summary_dialog,seed_dialog,leaderboard_dialog]:
		if dialog != null and dialog.visible: return
	var focus = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo: toggle_pause()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if board_view.guide.moving_tower != Vector2i(-1,-1):
					cancel_tower_move()
					run.message = "Tower move cancelled. No move used."
			KEY_X, KEY_DELETE:
				if demolish_button.is_visible_in_tree() and not demolish_button.disabled: demolish_button.pressed.emit()
			KEY_F: board_view.fit_board()
			KEY_F11: toggle_fullscreen()
			KEY_M: toggle_mute()
			KEY_R: set_routes(not board_view.show_routes)
			KEY_G: choose_maze_tip("" if not board_view.maze_tip.is_empty() else last_maze_tip)
			KEY_1: speed = 1
			KEY_2: speed = 2
			KEY_3: speed = 3
			KEY_5: speed = 5
		refresh_ui()

func toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		var full = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	apply_display(last_window_mode if display_mode == "fullscreen" else "fullscreen")
	save_settings()

# Full screen uses the monitor's own resolution; windows use exact 1080p / 1440p / 4K sizes
# (shrunk to fit if the monitor is smaller). The UI scales with the window either way.
func apply_display(mode: String) -> void:
	display_mode = mode if mode == "fullscreen" or WINDOW_SIZES.has(mode) else "fullscreen"
	if display_mode == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	last_window_mode = display_mode
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var usable = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var wanted: Vector2i = WINDOW_SIZES[display_mode]
	if usable.size.x > 0 and (wanted.x > usable.size.x or wanted.y > usable.size.y):
		var fit = minf(float(usable.size.x)/wanted.x,float(usable.size.y-40)/wanted.y)
		wanted = Vector2i(Vector2(wanted)*fit)
	DisplayServer.window_set_size(wanted)
	if usable.size.x > 0:
		DisplayServer.window_set_position(usable.position+(usable.size-wanted)/2)

func set_routes(on: bool) -> void:
	board_view.show_routes = on
	routes_check.set_pressed_no_signal(on)
	board_view.queue_redraw()
	save_settings()

func toggle_pause() -> void:
	paused = not paused
	refresh_ui()

func toggle_speed() -> void:
	speed = {1:2,2:3,3:5}.get(speed,1)
	refresh_ui()

func toggle_mute() -> void:
	muted = not muted
	audio.volume = 0 if muted else saved_volume
	save_settings()

func save_checkpoint() -> void:
	last_snapshot = run.snapshot().duplicate(true)
	var error = OK if smoke else GemSave.write_snapshot(last_snapshot)
	save_label.text = "Seed %d\n%s checkpoint saved locally." % [run.initial_seed,"Trial" if run.wave > 50 and GemCatalog.campaign() else "Build"] if error == OK else "Checkpoint could not be saved: "+error_string(error)

func save_settings() -> void:
	if smoke:
		return
	var config = ConfigFile.new()
	config.set_value("audio","volume",saved_volume)
	config.set_value("audio","muted",muted)
	config.set_value("display","mode",display_mode)
	config.set_value("display","window",last_window_mode)
	config.set_value("map","routes",board_view.show_routes)
	config.save("user://settings.cfg")

func load_settings() -> void:
	var config = ConfigFile.new()
	if not smoke and config.load("user://settings.cfg") == OK:
		saved_volume = clampf(float(config.get_value("audio","volume",.35)),0,1)
		muted = bool(config.get_value("audio","muted",false))
		display_mode = str(config.get_value("display","mode","fullscreen"))
		last_window_mode = str(config.get_value("display","window","1080p"))
		board_view.show_routes = bool(config.get_value("map","routes",true))
	routes_check.set_pressed_no_signal(board_view.show_routes)
	volume_slider.set_value_no_signal(saved_volume)
	audio.volume = 0 if muted else saved_volume

func show_recipes() -> void:
	if recipe_book.visible:
		return
	hide_other_dialogs(recipe_book)
	recipe_book.open_for(run,board_view.tracked_recipe)

func show_mazes() -> void:
	if maze_book.visible:
		return
	hide_other_dialogs(maze_book)
	maze_book.open_for(run,board_view.maze_tip)

func choose_maze_tip(id: String) -> void:
	if not id.is_empty():
		last_maze_tip = id
	board_view.set_maze_tip(id)
	maze_book.hide()
	refresh_ui()

func show_waves() -> void:
	if wave_book.visible:
		return
	hide_other_dialogs(wave_book)
	wave_book.open_for(run)

func locate_ingredient(p: Vector2i) -> void:
	if not run.board.cells.has(p):
		return
	recipe_book.hide()
	selection = p
	board_view.selected = p
	board_view.focus_cell(p)
	refresh_ui()

func track_recipe(recipe: String) -> void:
	board_view.set_tracked_recipe(recipe)
	recipe_book.hide()
	refresh_ui()

func show_help() -> void:
	if recipe_popup.visible:
		return
	hide_other_dialogs(recipe_popup)
	recipe_popup.title = "How to play"
	recipe_text.text = "[font_size=24][color=#e4d4a4]Build a maze. Keep one gem.[/color][/font_size]\n\n1. Click five empty cells. Each placement reveals a random gem. Invalid placements consume nothing.\n\n2. Select one new gem and Keep, combine two/four identical new gems, or use a special recipe. This final choice starts combat immediately.\n\n3. The other new gems become stones. During the next build phase, demolish stones or older towers freely. New placements cannot be undone.\n\nGround enemies follow all seven checkpoints and cannot cut diagonal corners. Flying enemies follow straight lines between the same checkpoints.\n\nBuy better gem odds with gold at any time. Changes affect future placements. Every tower attacks both ground and flying enemies.\n\n[b]Controls[/b]\nWheel: zoom · Middle drag: pan · F: fit · R: routes · G: maze guide\nSpace: pause · 1 / 2: speed · M: mute\nSelect any tower to change First / Last / Strongest / Nearest targeting.\n\n[font_size=18][color=#e4d4a4]Win condition[/color][/font_size]\nSurvive ten waves and kill the final boss. A boss leak is an immediate defeat. Ordinary leak costs are shown in wave information.\n\nThe beginning of each build phase is saved locally. Reload resumes that checkpoint, not a battle in progress. The Run menu offers the same seed, a new seed or a seed you enter. Run summary provides a test report.\n\nVersion 1.0 is ready for local review. Tower and enemy base values follow the reviewed Dota 2 snapshot; the ten-wave economy is adapted. See the reference notes for remaining engine differences."
	if GemCatalog.expanded_gems():
		recipe_text.text = recipe_text.text.replace("Version 1.0 is ready for local review.","Version 1.1.0-dev is a development profile. It currently adds six gem qualities and Jade to the ten-wave review game.")
		recipe_text.text += "\n\n"+str(GemCatalog.DATA.balance_note)
	if GemCatalog.campaign():
		recipe_text.text = recipe_text.text.replace("Survive ten waves","Survive 50 base waves and 50 trial waves").replace("Version 1.0 is ready for local review.","Solo campaign development build.")
		recipe_text.text += "\n\n[b]Tower relocation[/b]\nYou have five free tower moves for the entire run, shared by all towers. After those, every successful move costs 100 gold. During building, select an older tower and Move tower, then click an empty cell or a stone. A stone swaps to the old tower cell; an empty destination leaves the old cell empty. The whole checkpoint route must stay open. New unselected gems, combat, trial intervals and the final trap-placement step cannot use tower moves. Escape or clicking the source cancels for free. Invalid moves consume nothing. Paid moves charge only on a valid placement. Tower quality, MVP, copied abilities, rolled attack and targeting stay with the tower. Trap movement does not spend free tower moves or charge tower relocation gold."
		recipe_text.text = recipe_text.text.replace("Board changes are available in the next build phase.","Older tower recipes remain available during combat.")
		recipe_text.text += "\n\n[b]Campaign rules[/b]\nAfter five placements, a new gem of quality II or higher may be downgraded randomly as your final choice. The button shows its odds. This starts combat and turns other new gems into stones. Older tower recipes can also be combined during combat; no new placements or demolition are allowed then. Create and move path traps before combat. A trap recipe using new gems lets you position the trap before clicking Start wave.\n\nAfter wave 50 there are no new gems or building rounds. Trials start automatically after a 3-second interval; pause to review. Trial kills give 5 base gold; odds purchases close because no future gems are placed.\n\nAfter 180 seconds of simulated combat, berserk grants enemies +100% movement speed and magic immunity. The wave panel shows the countdown. Lanes may have alternate enemies and bosses, with calendar choices saved for this run."
		recipe_text.text += "\n\n[b]Map marks[/b]\nRoman badges identify gem quality. Special tower abbreviations appear when zoomed in or selected. A gold cross marks MVP progress. Trap symbols identify their effect; one/two/three edge marks mean bronze/silver/gold. Enemy marks show petrification (diamond), stun (cross), refraction (box), invisibility (eye), damage over time (dot and bar), slow (zigzag), armor reduction (V), or magic immunity (crossed box). Undetected invisible enemies are faint and cannot be targeted.\n\n[b]Gem purchases[/b]\nDefeating a base boss (waves 10/20/30/40/50) grants 150 saved discount for future odds purchases. Gold rewards stay the same. Purchases are manual; unused discount carries to the next purchase. Trial bosses grant no discount.\n\n[b]Gold spells[/b]\nThe Dota hero spells at level 1, bought with gold. A gem pray (200 gold) gives a 39% chance that your next gem is that type. Quality prays give your next gem a chance to become quality III (49%, 200 gold), IV (28%, 200 gold) or V (5%, 400 gold); a success replaces the rolled quality, even a higher one, and only one can succeed per round. Prays are cast before a placement, one of each kind at a time, and close in the trials. Heal (300 gold) restores 1–10 lives at random, up to the starting 100, between waves.\n\n[b]Path traps[/b]\nTrap recipes consume their listed gems and open the selected material cell. Traps do not block enemies. Select a trap and Move path trap during building. Two equal traps anywhere on the board merge automatically into the next grade (bronze to silver to gold) at the newest trap. Traps trigger when an enemy comes within one cell, with a 10s cooldown.\n\n"+str(GemCatalog.DATA.balance_note)
	recipe_popup.popup_centered(Vector2i(730,690))
