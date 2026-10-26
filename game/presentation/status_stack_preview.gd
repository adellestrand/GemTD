class_name GemStatusStackPreview
extends Control

# Art workbench sample: PixelLab status clips stacked on real enemy sprites, and
# every hit clip on a loop. Pure presentation; no combat, RNG or save data.
var unit = 26.0
var mode = "stack"  # stack | capped | hits
var playing = true
var clock = 0.0
var fx = GemEffects.new()
const STACK: Array[String] = ["stun","frost","burn","poison","shock","fracture","shield"]

func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(dt: float) -> void:
	if not playing or not is_visible_in_tree(): return
	clock += minf(dt,.1)
	queue_redraw()

func samples() -> Array:
	if mode == "hits":
		return GemAbilityArt.profiles.get("hit_clips",{}).keys().map(func(look): return {"label":look,"looks":[] as Array[String],"hit":GemAbilityArt.profiles.hit_clips[look]})
	var result: Array = []
	for count in range(1,STACK.size()+1):
		var looks: Array[String] = []
		looks.assign(STACK.slice(0,count))
		if mode == "capped":
			# Same priority and cap as the board (GemAbilityArt.statuses).
			var kept: Array[String] = []
			for look in GemAbilityArt.profiles.get("status_priority",[]):
				if look in looks and kept.size() < int(GemAbilityArt.profiles.get("max_statuses",4)): kept.append(look)
			result.append({"label":"%d → %d" % [count,kept.size()],"looks":kept})
		else:
			result.append({"label":str(count),"looks":looks})
	var stone: Array[String] = ["stone"]
	var mixed: Array[String] = ["stone","poison","fracture"]
	result.append({"label":"stone","looks":stone})
	result.append({"label":"stone+2","looks":mixed})
	return result

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),GemArt.color("grass").darkened(.15))
	var enemies: Array[String] = []
	for wave in GemCatalog.DATA.waves:
		var id = GemArt.sprite_id("enemies",wave.source_id)
		if GemArt.texture(id) != null and id not in enemies: enemies.append(id)
	if enemies.is_empty(): return
	var list = samples()
	var spacing = maxf(unit*1.9,40)
	var columns = maxi(1,floori((size.x-16)/spacing))
	var font = ThemeDB.fallback_font
	fx.begin_frame()
	for i in range(list.size()):
		var sample: Dictionary = list[i]
		var center = Vector2(16+spacing*(.5+i%columns),unit*1.6+(i/columns)*(unit*2.2+18))
		var art = enemies[(i*3)%enemies.size()] if mode != "hits" else enemies[0]
		var body = GemArt.sprite_rect(art,center,unit)
		var enemy = {"id":i}
		var looks: Array[String] = sample.looks
		var tint = GemAbilityArt.status_tint(looks)
		if sample.has("hit"):
			var duration = GemAbilityArt.clip_duration(sample.hit)
			var frame = floori(fmod(clock,duration+.35)/duration*int(GemAbilityArt.clip(sample.hit).get("frames",1)))
			GemAbilityArt.draw_clip(self,sample.hit,"behind",body,frame)
			GemArt.draw(self,art,center,unit)
			GemAbilityArt.draw_clip(self,sample.hit,"front",body,frame)
		else:
			GemAbilityArt.draw_enemy_layer(self,enemy,body,false,clock,fx,"behind",looks)
			GemArt.draw(self,art,center,unit,false,tint)
			if GemAbilityArt.status_overlay(looks).a > 0: GemArt.draw(self,art,center,unit,false,GemAbilityArt.status_overlay(looks),Vector2.ONE,0.0,0,GemArt.grey_frame(art,0))
			GemAbilityArt.draw_enemy_layer(self,enemy,body,false,clock,fx,"front",looks)
		draw_string(font,Vector2(center.x-spacing*.5,center.y+unit*.55+12),str(sample.label),HORIZONTAL_ALIGNMENT_CENTER,spacing,10,Color("e1d6b3"))
