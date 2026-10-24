extends Control

var tabs: TabContainer
var message: Label
var live_previews: Array[Control] = []
var playback: Button
var preview_paused = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = load(str(GemArt.config().get("theme","res://assets/graphics/ui_theme.tres"))) as Theme
	build()
	if "--motion" in OS.get_cmdline_user_args():
		tabs.current_tab = 3

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		toggle_previews()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if not GemArt.reload():
			message.text = "Invalid manifest JSON. Previous graphics retained; correct the file and press R."
			return
		for child in get_children():
			remove_child(child)
			child.queue_free()
		build()

func build() -> void:
	live_previews.clear()
	var background = ColorRect.new()
	background.color = Color("101e23")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,20)
	add_child(margin)
	var root = VBoxContainer.new()
	margin.add_child(root)
	var title = Label.new()
	title.text = "GEMTD  /  ART WORKBENCH"
	title.add_theme_font_size_override("font_size",26)
	title.add_theme_color_override("font_color",Color("e4d4a4"))
	root.add_child(title)
	message = Label.new()
	message.text = "Edit assets/graphics/manifest.json · R: reload mappings · Godot imports image changes"
	root.add_child(message)
	playback = Button.new()
	playback.text = "Resume previews [Space]" if preview_paused else "Pause previews [Space]"
	playback.pressed.connect(toggle_previews)
	root.add_child(playback)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	var towers = tab_grid("Towers & quality",2 if GemCatalog.quality_limit(GemCatalog.TYPES[0]) > 3 else 4)
	for kind in GemCatalog.TYPES:
		var frame = card(towers,kind.capitalize())
		var previews = HBoxContainer.new()
		previews.alignment = BoxContainer.ALIGNMENT_CENTER
		frame.add_child(previews)
		for tier in range(1,GemCatalog.quality_limit(kind)+1):
			var column = VBoxContainer.new()
			previews.add_child(column)
			preview(column,GemArt.sprite_id("gems",kind,tier),Vector2(78,115))
			caption(column,GemCatalog.quality_name(tier))
	var sizes = tab_grid("Board scale",4)
	for kind in GemCatalog.TYPES:
		var frame = card(sizes,kind.capitalize())
		var scale_preview = BoardScalePreview.new()
		scale_preview.kind = kind
		scale_preview.custom_minimum_size = Vector2(260,240)
		frame.add_child(scale_preview)
	for kind in GemCatalog.DATA.specials:
		var frame = card(towers,GemCatalog.DATA.specials[kind].name)
		preview(frame,GemArt.sprite_id("gems",kind),Vector2(200,130))
	var creatures = tab_grid("Enemies & scenery",4)
	for wave in GemCatalog.DATA.waves:
		var frame = card(creatures,wave.name)
		preview(frame,GemArt.sprite_id("enemies",wave.source_id),Vector2(230,145))
	for id in ["stone","checkpoint","pine","fern","flowers","rocks"]:
		var frame = card(creatures,id.capitalize())
		preview(frame,id,Vector2(230,145))
	var motion = tab_grid("Combat & motion",4)
	for kind in GemCatalog.TYPES+GemCatalog.DATA.specials.keys():
		var frame = card(motion,kind.capitalize().replace("_"," "))
		var live = LivePreview.new()
		live.gem_kind = kind
		live.custom_minimum_size = Vector2(260,180)
		live.playing = not preview_paused
		frame.add_child(live)
		live_previews.append(live)
	for wave in GemCatalog.DATA.waves:
		var frame = card(motion,wave.name)
		var live = LivePreview.new()
		live.enemy_id = GemArt.sprite_id("enemies",wave.source_id)
		live.air = bool(wave.air)
		live.custom_minimum_size = Vector2(260,180)
		live.playing = not preview_paused
		frame.add_child(live)
		live_previews.append(live)
	var clarity = tab_grid("Clarity",2)
	for scale_value in [15,32,45]:
		var frame = card(clarity,"Map marks · %d px/cell" % scale_value)
		var sample = ClarityPreview.new()
		sample.pixels = scale_value
		sample.custom_minimum_size = Vector2(480,440)
		frame.add_child(sample)
	var errors = GemArt.validation_errors()
	if errors.is_empty():
		message.text += "  ·  All bindings valid"
		print("ART_GALLERY_READY sprites=%d" % GemArt.config().sprites.size())
	else:
		message.text = " / ".join(errors)
		message.add_theme_color_override("font_color",Color("ff8070"))

func toggle_previews() -> void:
	preview_paused = not preview_paused
	playback.text = "Resume previews [Space]" if preview_paused else "Pause previews [Space]"
	for live in live_previews:
		live.playing = not preview_paused

func tab_grid(title: String, columns: int) -> GridContainer:
	var scroll = ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	return grid

func card(parent: Node, title: String) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(290,190)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("243b30")
	style.border_color = Color("8d8a62")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var content = VBoxContainer.new()
	panel.add_child(content)
	caption(content,title)
	return content

func preview(parent: Node, id: String, minimum: Vector2) -> void:
	var image = TextureRect.new()
	image.texture = GemArt.texture(id)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = minimum
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.tooltip_text = id
	parent.add_child(image)

func caption(parent: Node, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)

# Use the same sprite layout as the board, rather than scaling portraits to fit.
class BoardScalePreview extends Control:
	var kind: String
	func _draw() -> void:
		var font = ThemeDB.fallback_font
		var count = GemCatalog.quality_limit(kind)
		for row in range(2):
			var unit = 15.0 if row == 0 else 32.0
			var feet_y = 60.0 if row == 0 else 176.0
			draw_string(font,Vector2(8,18+row*102),"Fit view (15 px/cell)" if row == 0 else "Zoomed (32 px/cell)",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c1cdbb"))
			for tier in range(1,count+1):
				var feet = Vector2(size.x*(tier-0.5)/float(count),feet_y)
				draw_rect(Rect2(feet-Vector2.ONE*unit*.5,Vector2.ONE*unit),GemArt.color("grass"))
				GemArt.draw(self,GemArt.sprite_id("gems",kind,tier),feet,unit)
				draw_rect(Rect2(feet-Vector2.ONE*unit*.5,Vector2.ONE*unit),Color("e4d4a4"),false,1)
				draw_line(feet-Vector2(3,0),feet+Vector2(3,0),Color(1,1,1,.65),1)
				draw_line(feet-Vector2(0,3),feet+Vector2(0,3),Color(1,1,1,.65),1)
				draw_string(font,Vector2(feet.x-10,feet.y+unit*.5+22),GemCatalog.quality_name(tier),HORIZONTAL_ALIGNMENT_CENTER,20,14,Color("e4d4a4"))

class LivePreview extends Control:
	var gem_kind = ""
	var enemy_id = "boar"
	var air = false
	var playing = true
	var elapsed = 0.0
	var next_shot = .4
	var effects = GemEffects.new()
	const UNIT = 38.0
	func _process(dt: float) -> void:
		if not playing or not is_visible_in_tree():
			return
		elapsed += dt
		effects.advance(dt)
		if not gem_kind.is_empty() and elapsed >= next_shot:
			var color = GemArt.gem_color({"kind":gem_kind,"tier":3})
			if gem_kind == "asteriated_ruby":
				effects.area(Vector2(1.2,3.1),1.8)
			else:
				effects.shot(Vector2(1.2,3.1),Vector2(5.2,3.1),color,gem_kind)
				if gem_kind == "ruby":
					effects.area(Vector2(5.2,3.1),1.0)
			effects.damaged(0,Vector2(5.2,3.1),4,"physical",false)
			next_shot = elapsed+.9
		queue_redraw()
	func _draw() -> void:
		var feet = Vector2(5.2,3.1)*UNIT if not gem_kind.is_empty() else Vector2(size.x*.5,125)
		if not gem_kind.is_empty():
			GemArt.draw(self,GemArt.sprite_id("gems",gem_kind,3),Vector2(1.2,3.1)*UNIT,UNIT)
		var motion = GemArt.enemy_motion(enemy_id,elapsed*1.6,elapsed,0,air)
		var tint = Color(1.45,1.35,1.15) if effects.flashes.has(0) else Color.WHITE
		GemArt.draw(self,enemy_id,feet+motion.offset*UNIT,UNIT,false,tint,motion.scale,float(motion.rotation))
		effects.draw(self,Vector2.ZERO,UNIT,ThemeDB.fallback_font)

class ClarityPreview extends Control:
	var pixels = 32.0
	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO,size),Color("435d40"))
		draw_string(font,Vector2(12,20),"Qualities I–VI",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f1e6c8"))
		for tier in range(1,7):
			var p = Vector2(40+(tier-1)*76,63)
			var gem = {"kind":"sapphire","tier":tier,"fresh":false,"priority":"First"}
			GemArt.draw(self,GemArt.sprite_id("gems","sapphire",tier),p,pixels)
			GemReadability.tower(self,p,pixels,gem)
		draw_string(font,Vector2(12,119),"Special identities / MVP / disarm",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f1e6c8"))
		var kinds = ["heiyaoshi","jingangshikulinan","palayibabixi","manao","huguoshenyishi"]
		for i in range(kinds.size()):
			var p = Vector2(48+i*90,161)
			GemArt.draw(self,GemArt.sprite_id("gems",kinds[i]),p,pixels)
			GemReadability.tower(self,p,pixels,{"kind":kinds[i],"tier":1,"mvp":5},true,i == 4)
		draw_string(font,Vector2(12,214),"Eight trap families · bronze / silver / gold marks",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f1e6c8"))
		var families = GemReadability.DATA.trap_families.keys()
		for i in range(families.size()):
			var p = Vector2(45+(i%4)*117,250+(i/4)*55)
			GemReadability.trap(self,p,pixels,str(families[i])+(["","_yin","_jin"][i%3]))
			if pixels >= 24: draw_string(font,p+Vector2(-30,29),str(GemReadability.DATA.trap_families[families[i]]),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("efecdc"))
		draw_string(font,Vector2(12,351),"States: stone / stun / refraction / invisible / DoT / slow / armor / immune",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f1e6c8"))
		var states = [{"current_properties":{"stone_gaze":true}},{"current_properties":{"stunned":true}},{"refraction":7},{"invisible":true},{"poisons":{"sample":1}},{"current_properties":{"move_percent":-30}},{"current_properties":{"armor":-10}},{"magic_immune":true}]
		for i in range(states.size()):
			var p = Vector2(30+i*60,403)
			GemArt.draw(self,GemArt.sprite_id("enemies","gemtd_kuangbaoyezhu"),p,pixels)
			GemReadability.enemy(self,p-Vector2(0,10),pixels,states[i])
