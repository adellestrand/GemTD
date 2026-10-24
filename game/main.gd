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
var selected_portrait: TextureRect
var enemy_portrait: TextureRect
var odds_label: Label
var save_label: Label
var keep_button: Button
var upgrade_two: Button
var upgrade_four: Button
var demolish_button: Button
var move_trap_button: Button
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
var smoke = false
var recipe_book: GemRecipeBook
var wave_book: GemWaveBook
var summary_dialog: GemRunSummary
var seed_dialog: GemSeedDialog
var journal: GemReviewJournal
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
	build_theme()
	build_ui()
	audio = GemAudio.new()
	add_child(audio)
	load_settings()
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

func build_ui() -> void:
	var background = ColorRect.new()
	background.color = GemArt.color("ui_background")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	add_child(margin)
	var root = VBoxContainer.new()
	margin.add_child(root)
	var header = HBoxContainer.new()
	root.add_child(header)
	var brand = VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	label_in(brand,"G E M T D",30).add_theme_color_override("font_color",GemArt.color("ui_accent"))
	label_in(brand,"SOLO  /  THE SEVEN CHECKPOINTS",12).add_theme_color_override("font_color",GemArt.color("ui_muted"))
	status_label = label_in(header,"",18)
	button_in(header,"Waves",show_waves)
	button_in(header,"Recipes",show_recipes)
	button_in(header,"Help",show_help)
	var restart = MenuButton.new()
	restart.text = "Run"
	restart.get_popup().add_item("Same seed",0)
	restart.get_popup().add_item("New seed",1)
	restart.get_popup().add_item("Resume build checkpoint",2)
	restart.get_popup().add_separator()
	restart.get_popup().add_item("Run summary / test report",3)
	restart.get_popup().add_item("Enter seed...",4)
	restart.get_popup().add_separator()
	restart.get_popup().add_item("Solo campaign · 100 waves",10)
	restart.get_popup().add_item("Review 1.0 · 10 waves",11)
	restart.get_popup().add_item("Expanded gems · 10 waves",12)
	restart.get_popup().id_pressed.connect(func(id):
		if id in [10,11,12]:
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
		elif id == 2:
			new_run(run.initial_seed,last_snapshot)
		else:
			new_run(run.initial_seed if id == 0 else int(Time.get_unix_time_from_system()*1000.0))
	)
	header.add_child(restart)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var field_panel = PanelContainer.new()
	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(field_panel)
	var field_box = VBoxContainer.new()
	field_panel.add_child(field_box)
	var field_header = HBoxContainer.new()
	field_box.add_child(field_header)
	phase_label = label_in(field_header,"",16)
	phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	round_tray = HBoxContainer.new()
	round_tray.add_theme_constant_override("separation",3)
	field_header.add_child(round_tray)
	for i in range(5):
		var slot = Button.new()
		slot.custom_minimum_size = Vector2(36,36)
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_constant_override("icon_max_width",24)
		slot.toggle_mode = true
		slot.focus_mode = Control.FOCUS_NONE
		slot.pressed.connect(func():
			if i < round_cells.size():
				on_cell_clicked(round_cells[i])
		)
		round_slots.append(slot)
		round_tray.add_child(slot)
	pause_button = button_in(field_header,"Pause [Space]",toggle_pause)
	speed_button = button_in(field_header,"1×",toggle_speed)
	button_in(field_header,"Routes",func(): board_view.show_routes = not board_view.show_routes)
	button_in(field_header,"Fit [F]",func(): board_view.fit_board())
	board_view = GemBoardView.new()
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.custom_minimum_size = Vector2(400,400)
	board_view.cell_clicked.connect(on_cell_clicked)
	board_view.hover_changed.connect(func(_p): refresh_hover_hint())
	field_box.add_child(board_view)
	var legend = HBoxContainer.new()
	field_box.add_child(legend)
	label_in(legend,"— Ground",13).add_theme_color_override("font_color",Color("95d7ad"))
	label_in(legend,"- - Air",13).add_theme_color_override("font_color",Color("9bc6ec"))
	label_in(legend,"— Preview",12).add_theme_color_override("font_color",GemArt.color("route_preview"))
	hover_hint = label_in(legend,"",12)
	hover_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hover_hint.clip_text = true
	tracking_button = LinkButton.new()
	tracking_button.add_theme_font_size_override("font_size",12)
	tracking_button.pressed.connect(func(): track_recipe(""))
	tracking_button.tooltip_text = "Stop highlighting this recipe's ingredients."
	legend.add_child(tracking_button)
	var camera_hint = label_in(legend,"Wheel: zoom  ·  Middle drag: pan",12)
	camera_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var sidebar = PanelContainer.new()
	sidebar.custom_minimum_size.x = 330
	body.add_child(sidebar)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(info)
	result_box = VBoxContainer.new()
	info.add_child(result_box)
	result_title = label_in(result_box,"",24)
	result_stats = label_in(result_box,"",14)
	result_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button_in(result_box,"Retry same seed",func(): new_run(run.initial_seed))
	button_in(result_box,"New run",func(): new_run(int(Time.get_unix_time_from_system()*1000.0)))
	button_in(result_box,"Run summary & test report",show_summary)
	result_box.add_child(HSeparator.new())
	wave_heading = label_in(info,"THE NEXT WAVE",12)
	wave_heading.add_theme_color_override("font_color",GemArt.color("ui_section"))
	var enemy_card = HBoxContainer.new()
	info.add_child(enemy_card)
	enemy_portrait = portrait_in(enemy_card,Vector2(70,82))
	wave_label = label_in(enemy_card,"",14)
	wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_progress = label_in(info,"",12)
	wave_progress = ProgressBar.new()
	wave_progress.show_percentage = false
	wave_progress.custom_minimum_size.y = 8
	info.add_child(wave_progress)
	boss_label = label_in(info,"",14)
	boss_health = ProgressBar.new()
	boss_health.theme_type_variation = "BossHealth"
	boss_health.show_percentage = false
	boss_health.custom_minimum_size.y = 16
	info.add_child(boss_health)
	info.add_child(HSeparator.new())
	label_in(info,"GEM QUALITY",12).add_theme_color_override("font_color",GemArt.color("ui_section"))
	odds_label = label_in(info,"")
	quality_button = button_in(info,"",func(): run.buy_quality())
	info.add_child(HSeparator.new())
	var selected_card = HBoxContainer.new()
	info.add_child(selected_card)
	selected_portrait = portrait_in(selected_card,Vector2(78,88))
	selected_label = label_in(selected_card,"Select a gem",20)
	selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label = GemTooltips.InfoLabel.new()
	detail_label.add_theme_font_size_override("font_size",14)
	info.add_child(detail_label)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.mouse_filter = Control.MOUSE_FILTER_PASS
	priority = OptionButton.new()
	for mode in GemCatalog.PRIORITIES:
		priority.add_item("Target: "+mode)
	priority.item_selected.connect(func(index):
		run.set_priority(selection,GemCatalog.PRIORITIES[index])
	)
	info.add_child(priority)
	keep_button = button_in(info,"Keep selected & start wave",func(): run.keep(selection))
	upgrade_two = button_in(info,"Combine 2: +1 quality & start",func(): run.upgrade(selection,2))
	upgrade_four = button_in(info,"Combine 4: +2 quality & start",func(): run.upgrade(selection,4))
	demolish_button = button_in(info,"Demolish selected",func(): run.demolish(selection))
	move_trap_button = button_in(info,"Move path trap",func():
		moving_trap = selection
		run.message = "Click an empty cell to move this path trap. Click the same trap to cancel."
		refresh_ui()
	)
	wire_preview(keep_button,{"type":"keep"})
	wire_preview(upgrade_two,{"type":"upgrade","count":2})
	wire_preview(upgrade_four,{"type":"upgrade","count":4})
	wire_preview(demolish_button,{"type":"demolish"})
	recipes_box = VBoxContainer.new()
	info.add_child(recipes_box)
	for recipe in GemCatalog.recipes():
		var old_button = button_in(recipes_box,"Create "+GemCatalog.recipe_title(recipe)+" · old only",func(): run.combine(recipe,selection,true))
		var final_button = button_in(recipes_box,"Create "+GemCatalog.recipe_title(recipe)+" & start",func(): run.combine(recipe,selection))
		old_button.visible = false
		final_button.visible = false
		wire_preview(old_button,{"type":"recipe","recipe":recipe,"old_only":true})
		wire_preview(final_button,{"type":"recipe","recipe":recipe,"old_only":false})
		recipe_buttons[recipe] = {"old": old_button,"final": final_button}
	info.add_child(HSeparator.new())
	label_in(info,"SOUND",12).add_theme_color_override("font_color",GemArt.color("ui_section"))
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 1
	volume_slider.step = .05
	volume_slider.value = .35
	volume_slider.custom_minimum_size.x = 120
	volume_slider.tooltip_text = "Sound effects volume"
	volume_slider.value_changed.connect(func(value):
		if audio != null:
			audio.volume = value
			saved_volume = value
			muted = false
			save_settings()
	)
	info.add_child(volume_slider)
	button_in(info,"Mute / unmute [M]",toggle_mute)
	save_label = label_in(info,"",11)
	save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_label.add_theme_color_override("font_color",Color("819a95"))
	message_label = label_in(root,"",15)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size.y = 36
	footer_label = label_in(root,"",11)
	footer_label.add_theme_color_override("font_color",GemArt.color("ui_footer"))
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
	wave_book = GemWaveBook.new()
	add_child(wave_book)
	connect_modal_pause(wave_book)
	summary_dialog = GemRunSummary.new()
	add_child(summary_dialog)
	connect_modal_pause(summary_dialog)
	seed_dialog = GemSeedDialog.new()
	add_child(seed_dialog)
	connect_modal_pause(seed_dialog)
	seed_dialog.seed_requested.connect(func(value): new_run(value))

func connect_modal_pause(dialog: Window) -> void:
	var restore = {"paused":false}
	dialog.about_to_popup.connect(func():
		restore.paused = paused
		paused = true
		refresh_ui()
	)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			paused = bool(restore.paused)
			refresh_ui()
	)

func new_run(seed_value: int, restore_data: Dictionary = {}) -> void:
	if journal != null and not journal.actions.is_empty():
		persist_review()
	hide_other_dialogs()
	recipe_popup.hide()
	recipe_book.reset()
	wave_book.reset()
	paused = false
	accumulator = 0
	selection = Vector2i(-1,-1)
	moving_trap = Vector2i(-1,-1)
	active_preview = {}
	started_wave = {}
	last_wave_report = ""
	run = GemRun.new(seed_value)
	var did_restore = not restore_data.is_empty() and run.restore(restore_data)
	if not restore_data.is_empty() and not did_restore:
		run.message = "Saved checkpoint was incompatible or damaged. Started a new run."
	combat = GemCampaignCombat.new(run) if GemCatalog.campaign() else GemCombat.new(run)
	journal = GemReviewJournal.new()
	journal.reset(run,did_restore)
	run.action_recorded.connect(func(entry): journal.record(entry,combat))
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
	combat.damaged.connect(board_view.effects.damaged)
	combat.evaded.connect(board_view.effects.evaded)
	combat.escaped.connect(board_view.effects.escaped)
	combat.area_attack.connect(board_view.effects.area)
	board_view.run = run
	board_view.combat = combat
	board_view.selected = selection
	board_view.reset_visuals()
	board_view.fit_board()
	save_checkpoint()
	refresh_ui()

func on_cell_clicked(p: Vector2i) -> void:
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
	if run.phase != "build":
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
	update_wave_report()
	status_label.text = "Lives %d    Gold %d    Wave %d / %d" % [run.lives,run.gold,run.wave,GemCatalog.wave_count()]
	footer_label.text = "GEMTD SOLO %s   ·   %d gem types / %d qualities / %d waves   ·   Seed %d" % [GemRelease.version(),GemCatalog.TYPES.size(),GemCatalog.quality_limit(GemCatalog.TYPES[0]),GemCatalog.wave_count(),run.initial_seed]
	var terminal = run.phase in ["won","lost"]
	result_box.visible = terminal
	if terminal:
		result_title.text = "VICTORY" if run.phase == "won" else "DEFEAT"
		result_title.add_theme_color_override("font_color",GemArt.color("ui_accent"))
		result_stats.text = "Wave %d / %d · %d lives\n%d defeated · %d leaked\nSeed %d" % [run.wave,GemCatalog.wave_count(),run.lives,run.kills,run.leaks,run.initial_seed]
	var tracking = board_view.tracking_progress
	tracking_button.visible = not tracking.is_empty()
	if not tracking.is_empty():
		tracking_button.text = "%s %d/%d · Unpin" % [GemCatalog.recipe_title(board_view.tracked_recipe),tracking.collected,tracking.total]
	phase_label.text = {"build":"BUILD  ·  %d / 5 placed" % run.placed,"combat":"COMBAT","won":"VICTORY","lost":"DEFEAT"}[run.phase]
	if run.phase == "combat":
		phase_label.text += "  ·  PAUSED" if paused else "  ·  %d×" % speed
	var w = combat.wave_data if GemCatalog.campaign() and run.phase == "combat" else GemCatalog.wave(run.wave)
	if GemCatalog.campaign() and run.phase == "build" and not w.boss:
		w = w.duplicate(true)
		w.count = run.enemy_count
	wave_heading.text = {"build":"THE NEXT WAVE","combat":"CURRENT WAVE","won":"FINAL WAVE","lost":"LAST WAVE"}[run.phase]
	enemy_portrait.texture = GemArt.texture(GemArt.sprite_id("enemies",w.source_id))
	wave_label.text = GemWaveGuide.brief(w,run.wave)
	refresh_combat_progress(w)
	var odds: Array = GemCatalog.DATA.quality_odds[run.quality]
	odds_label.text = GemCatalog.odds_text(odds)
	var odds_maxed = run.quality >= GemCatalog.max_quality_upgrade()
	quality_button.text = "Improve odds · %d gold" % run.quality_price() if not odds_maxed else "Quality odds maximized"
	quality_button.disabled = odds_maxed or run.phase in ["won","lost"] or (not odds_maxed and run.gold < run.quality_price())
	quality_button.tooltip_text = "All available odds upgrades purchased." if odds_maxed else "Affects future placements only. Need %d gold; have %d." % [run.quality_price(),run.gold]
	if GemCatalog.campaign() and not odds_maxed:
		odds_label.text += "\nBoss discount saved: %d gold" % run.quality_discount
		quality_button.tooltip_text += "\nBase price %d; saved discount %d. Defeat bosses 10/20/30/40/50 for +150 discount. Unused discount carries to the next purchase." % [int(GemCatalog.DATA.quality_costs[run.quality]),run.quality_discount]
	message_label.text = run.message
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
	priority.visible = not terminal and not gem.is_empty() and not run.board.slabs.has(selection) and gem.get("kind", "stone") not in ["stone","asteriated_ruby"]
	selected_label.text = GemCatalog.title(gem) if not gem.is_empty() else "Place a gem" if run.phase == "build" and run.placed < 5 else "Select a gem"
	if not gem.is_empty() and GemReadability.DATA.special_codes.has(gem.kind): selected_label.tooltip_text = "Map badge: "+GemReadability.tower_label(gem)
	else: selected_label.tooltip_text = ""
	if gem.is_empty():
		if run.phase == "combat":
			detail_label.text = "Select a tower to inspect its effects and targeting.\n\nBoard changes are available in the next build phase."
		elif terminal:
			detail_label.text = "Use the result controls to play again, or open the run summary to review this session."
		else:
			detail_label.text = "Select a new gem for your final choice. Keep / Combine starts combat immediately." if run.placed == 5 else "Click an empty cell to place. New gems glow until your final choice.\n\nThe final Keep / Combine starts combat immediately."
	else:
		detail_label.text = str(GemCatalog.stats(gem).effect) if gem.kind == "stone" else ("NEW THIS ROUND\n" if gem.fresh else "")+GemTowerInfo.describe(GemTowerInfo.profile(gem,selection,run.board.cells))
		priority.select(maxi(0,GemCatalog.PRIORITIES.find(gem.priority)))
	update_action_button(keep_button,{"type":"keep"})
	update_action_button(upgrade_two,{"type":"upgrade","count":2})
	update_action_button(upgrade_four,{"type":"upgrade","count":4})
	update_action_button(demolish_button,{"type":"demolish"})
	round_tray.visible = run.phase == "build"
	round_cells = run.fresh_cells()
	for i in range(5):
		var slot = round_slots[i]
		slot.disabled = i >= round_cells.size()
		slot.icon = null
		slot.text = str(i+1) if slot.disabled else ""
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
	refresh_hover_hint()
	refresh_action_preview()
	board_view.queue_redraw()

func _process(dt: float) -> void:
	if run == null:
		return
	var was_combat = run.phase == "combat"
	if was_combat and not paused:
		accumulator += minf(dt,.25)*speed
		while accumulator >= 1.0/30.0 and run.phase == "combat":
			board_view.advance_visuals(1.0/30.0)
			combat.tick(1.0/30.0)
			accumulator -= 1.0/30.0
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
	if boss_label.visible:
		boss_health.max_value = float(wave.hp)
		boss_health.value = float(wave.hp) if alive.is_empty() else float(alive[0].hp)
		boss_label.text = "Boss health: %.0f / %.0f" % [boss_health.value,boss_health.max_value]

func hide_other_dialogs(except: Window = null) -> void:
	for dialog in [recipe_popup,recipe_book,wave_book,summary_dialog,seed_dialog]:
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

func show_seed_dialog() -> void:
	if seed_dialog.visible:
		return
	hide_other_dialogs(seed_dialog)
	seed_dialog.open_for(run.initial_seed)

func _input(event: InputEvent) -> void:
	# Space belongs to pause before a focused Button can also activate on
	# key release. Text fields and modal windows retain their own keyboard UI.
	if not event is InputEventKey or event.keycode != KEY_SPACE: return
	if run == null or run.phase not in ["build","combat"]: return
	for dialog in [recipe_popup,recipe_book,wave_book,summary_dialog,seed_dialog]:
		if dialog != null and dialog.visible: return
	var focus = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo: toggle_pause()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F: board_view.fit_board()
			KEY_M: toggle_mute()
			KEY_R: board_view.show_routes = not board_view.show_routes
			KEY_1: speed = 1
			KEY_2: speed = 2
		refresh_ui()

func toggle_pause() -> void:
	paused = not paused
	refresh_ui()

func toggle_speed() -> void:
	speed = 2 if speed == 1 else 1
	refresh_ui()

func toggle_mute() -> void:
	muted = not muted
	audio.volume = 0 if muted else saved_volume
	save_settings()

func save_checkpoint() -> void:
	last_snapshot = run.snapshot().duplicate(true)
	var error = OK if smoke else GemSave.write_snapshot(last_snapshot)
	save_label.text = "Seed %d\nBuild checkpoint saved locally." % run.initial_seed if error == OK else "Checkpoint could not be saved: "+error_string(error)

func save_settings() -> void:
	if smoke:
		return
	var config = ConfigFile.new()
	config.set_value("audio","volume",saved_volume)
	config.set_value("audio","muted",muted)
	config.save("user://settings.cfg")

func load_settings() -> void:
	var config = ConfigFile.new()
	if not smoke and config.load("user://settings.cfg") == OK:
		saved_volume = clampf(float(config.get_value("audio","volume",.35)),0,1)
		muted = bool(config.get_value("audio","muted",false))
	volume_slider.set_value_no_signal(saved_volume)
	audio.volume = 0 if muted else saved_volume

func show_recipes() -> void:
	if recipe_book.visible:
		return
	hide_other_dialogs(recipe_book)
	recipe_book.open_for(run,board_view.tracked_recipe)

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
	recipe_text.text = "[font_size=24][color=#e4d4a4]Build a maze. Keep one gem.[/color][/font_size]\n\n1. Click five empty cells. Each placement reveals a random gem. Invalid placements consume nothing.\n\n2. Select one new gem and Keep, combine two/four identical new gems, or use a special recipe. This final choice starts combat immediately.\n\n3. The other new gems become stones. During the next build phase, demolish stones or older towers freely. New placements cannot be undone.\n\nGround enemies follow all seven checkpoints and cannot cut diagonal corners. Flying enemies follow straight lines between the same checkpoints.\n\nBuy better gem odds with gold at any time. Changes affect future placements. Diamond and Ruby attack ground only in this solo version.\n\n[b]Controls[/b]\nWheel: zoom · Middle drag: pan · F: fit · R: routes\nSpace: pause · 1 / 2: speed · M: mute\nSelect any tower to change First / Last / Strongest / Nearest targeting.\n\n[font_size=18][color=#e4d4a4]Win condition[/color][/font_size]\nSurvive ten waves and kill the final boss. A boss leak is an immediate defeat. Ordinary leak costs are shown in wave information.\n\nThe beginning of each build phase is saved locally. Reload resumes that checkpoint, not a battle in progress. The Run menu offers the same seed, a new seed or a seed you enter. Run summary provides a test report.\n\nVersion 1.0 is ready for local review. Tower and enemy base values follow the reviewed Dota 2 snapshot; the ten-wave economy is adapted. See the reference notes for remaining engine differences."
	if GemCatalog.expanded_gems():
		recipe_text.text = recipe_text.text.replace("Version 1.0 is ready for local review.","Version 1.1.0-dev is a development profile. It currently adds six gem qualities and Jade to the ten-wave review game.")
		recipe_text.text += "\n\n"+str(GemCatalog.DATA.balance_note)
	if GemCatalog.campaign():
		recipe_text.text = recipe_text.text.replace("Survive ten waves","Survive 50 base waves and 50 trial waves").replace("Version 1.0 is ready for local review.","Solo campaign development build.")
		recipe_text.text += "\n\n[b]Map marks[/b]\nRoman badges identify gem quality. Special tower abbreviations appear when zoomed in or selected. A gold cross marks MVP progress. Trap symbols identify their effect; one/two/three edge marks mean bronze/silver/gold. Enemy marks show petrification (diamond), stun (cross), refraction (box), invisibility (eye), damage over time (dot and bar), slow (zigzag), armor reduction (V), or magic immunity (crossed box). Undetected invisible enemies are faint and cannot be targeted.\n\n[b]Gem purchases[/b]\nDefeating a base boss (waves 10/20/30/40/50) grants 150 saved discount for future odds purchases. Gold rewards stay the same. Purchases are manual; unused discount carries to the next purchase. Trial bosses grant no discount.\n\n[b]Path traps[/b]\nTrap recipes consume their listed gems and open the selected material cell. Traps do not block enemies. Select a trap and Move path trap during building. Three equal traps in a straight line upgrade automatically at the center. Traps trigger when an enemy comes within one cell, with a 10s cooldown.\n\n"+str(GemCatalog.DATA.balance_note)
	recipe_popup.popup_centered(Vector2i(730,690))
