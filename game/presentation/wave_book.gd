class_name GemWaveBook
extends AcceptDialog

var state: GemRun
var selected_wave = 1
var wave_buttons: Array[Button] = []
var list: VBoxContainer
var list_scroll: ScrollContainer
var detail_scroll: ScrollContainer
var details: VBoxContainer
var selected_info: Dictionary = {}
var content_margin: MarginContainer

func _ready() -> void:
	title = "Wave overview"
	# Both columns scroll. Their initial wrapped-label sizes must not enlarge
	# the window before containers have assigned their final widths.
	wrap_controls = false
	min_size = Vector2i(800,540)
	get_ok_button().text = "Close"
	content_margin = MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		content_margin.add_theme_constant_override("margin_"+side,12)
	add_child(content_margin)
	var layout = VBoxContainer.new()
	content_margin.add_child(layout)
	text_label(layout,"Plan ahead across all %d waves. Inspecting a wave never starts it or changes your tower choice." % GemCatalog.wave_count(),14)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	list_scroll = ScrollContainer.new()
	list_scroll.custom_minimum_size.x = 325
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(list_scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",4)
	list_scroll.add_child(list)
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	detail_scroll = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(detail_scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",8)
	detail_scroll.add_child(details)
	size_changed.connect(func(): fit_content.call_deferred())
	content_margin.resized.connect(func(): fit_content.call_deferred())
	content_margin.minimum_size_changed.connect(func(): fit_content.call_deferred())

func fit_content() -> void:
	# Explicit bounds prevent the initial height of wrapped labels from being
	# retained as anchor offsets. Leave the dialog's Close row outside scrolling.
	content_margin.position = Vector2(8,8)
	content_margin.size = Vector2(size.x-16,maxi(0,size.y-64))

func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func reset() -> void:
	hide()
	state = null
	selected_wave = 1
	selected_info = {}
	wave_buttons.clear()
	clear_children(list)
	clear_children(details)

func open_for(run: GemRun) -> void:
	state = run
	wave_buttons.clear()
	clear_children(list)
	var group = ButtonGroup.new()
	for i in range(1,GemCatalog.DATA.waves.size()+1):
		var wave: Dictionary = GemCatalog.DATA.waves[i-1]
		var button = Button.new()
		button.text = "%d · %s\n%s · %s" % [i,wave.name,"BOSS" if wave.boss else "Air" if wave.air else "Ground",GemWaveGuide.status(state,i)]
		button.icon = GemArt.texture(GemArt.sprite_id("enemies",wave.source_id))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",32)
		button.add_theme_font_size_override("font_size",14)
		button.custom_minimum_size.y = 52
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(func(): select_wave(i))
		list.add_child(button)
		wave_buttons.append(button)
	select_wave(state.wave)
	popup_centered(Vector2i(880,750))
	fit_content.call_deferred()
	scroll_to_current.call_deferred()

func scroll_to_current() -> void:
	if visible and state != null and selected_wave >= 1 and selected_wave <= wave_buttons.size():
		list_scroll.ensure_control_visible(wave_buttons[selected_wave-1])

func select_wave(index: int) -> void:
	var info = GemWaveGuide.inspect(state,index)
	if info.is_empty():
		return
	selected_wave = index
	selected_info = info
	for i in range(wave_buttons.size()):
		wave_buttons[i].set_pressed_no_signal(i == index-1)
	clear_children(details)
	detail_scroll.scroll_vertical = 0
	var wave: Dictionary = info.wave
	var header = HBoxContainer.new()
	details.add_child(header)
	var portrait = TextureRect.new()
	portrait.texture = GemArt.texture(GemArt.sprite_id("enemies",wave.source_id))
	portrait.custom_minimum_size = Vector2(80,84)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header.add_child(portrait)
	var names = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(names)
	text_label(names,"WAVE %d · %s" % [index,info.status],12).add_theme_color_override("font_color",GemArt.color("ui_section"))
	text_label(names,str(wave.name),22).add_theme_color_override("font_color",GemArt.color("ui_accent"))
	text_label(details,"%d × %s · %.2f HP each\nSpeed %.2f cells/s · Spawn every %.2fs" % [int(wave.count),"Air" if wave.air else "Ground",float(wave.hp),float(wave.speed),float(wave.spawn_interval)],14)
	text_label(details,str(info.route),14)
	if GemCatalog.campaign():
		if GemCatalog.boss_discount_for_wave(index) > 0: text_label(details,"Boss defeat: +150 saved discount for manual gem odds purchases.",13)
		text_label(details,GemWaveGuide.campaign_traits(wave),13)
		text_label(details,"Enemy count adapts to the run's streak. Trial HP shown above is the base before trial scaling and random abilities." if wave.trial else "Enemy count adapts to the run's streak.",12)
	text_label(details,str(info.leak),14).add_theme_color_override("font_color",GemArt.color("placement_blocked") if wave.boss else GemArt.color("ui_text"))
	text_label(details,"Kills +%d gold each · Clear +%d gold\nLeaked enemies give no kill reward. Clear reward requires survival." % [int(wave.reward),int(wave.completion)],13)
	details.add_child(HSeparator.new())
	text_label(details,"DEFENSES",12).add_theme_color_override("font_color",GemArt.color("ui_section"))
	text_label(details,"Armor %.0f · Magic resistance %+.0f%%\nEvasion %.0f%% (attack rolls only)" % [float(wave.armor),float(wave.magic_resist)*100,float(wave.evasion)*100],14)
	text_label(details,"From 100 raw damage, a landed hit deals:\nPhysical %.1f · Magic %.1f · Pure %.1f" % [info.damage.physical,info.damage.magical,info.damage.pure],14)
	text_label(details,"Initial defenses, before temporary debuffs. Evasion is separate from these damage values.",12).add_theme_color_override("font_color",GemArt.color("ui_muted"))
	details.add_child(HSeparator.new())
	var coverage: Dictionary = info.coverage
	text_label(details,"YOUR CURRENT TOWERS",12).add_theme_color_override("font_color",GemArt.color("ui_section"))
	text_label(details,"Kept towers able to target %s: %d / %d\nNew gems able to target %s: %d / %d" % ["air" if wave.air else "ground",coverage.kept,coverage.kept_total,"air" if wave.air else "ground",coverage.fresh,coverage.fresh_total],14)
	text_label(details,"New gems are not kept yet. Target eligibility alone does not guarantee coverage: position, range, damage and your final choice still matter.",12).add_theme_color_override("font_color",GemArt.color("ui_muted"))

func text_label(parent: Node, value: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label
