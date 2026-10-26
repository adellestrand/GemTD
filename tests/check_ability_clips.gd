extends "res://tests/check_campaign.gd"

# PixelLab ability clips (assets/graphics/pixellab-vfx-v1): every mapped clip loads,
# stacked statuses follow priority and cap, and hits/memory stay presentation only.

func run_checks() -> void:
	var config = GemArt.config()
	var old = config.effects.duplicate(true)
	config.effects.enabled = true
	var profiles = GemAbilityArt.profiles
	var mapped: Array = profiles.hit_clips.values()+profiles.status_clips.values()+[profiles.support_clip]
	for id in mapped:
		var entry = GemAbilityArt.clip(id)
		check(not entry.is_empty() and not entry.layers.is_empty(),"clip exists with a layer: "+id)
		for depth in entry.get("layers",{}):
			var frames = GemAbilityArt.clip_layer_frames(id,depth)
			check(frames.size() == int(entry.frames) and frames[0].get_width() == int(entry.layers[depth].size[0]),"clip strip splits into its frames: %s/%s" % [id,depth])
	for look in ["fire","poison","frost","stone","shield","fracture","stun","lightning","critical","blast","support"]:
		check(profiles.hit_clips.has(look),"all eleven looks have a hit clip: "+look)
	# Stacking: priority order and the configured cap.
	var enemy = {"id":7,"current_properties":{"stunned":true,"stone_gaze":true},"poisons":{"a":1},"slow":.3,"armor_debuff":2,"mods":{},"aura_memory":{}}
	var fx = GemEffects.new()
	fx.marks[7] = {"burn":1.0,"shock":1.0}
	var looks = GemAbilityArt.statuses(enemy,0,fx)
	check(looks.size() == int(profiles.max_statuses),"stacked statuses are capped at max_statuses")
	check(looks == ["stun","stone","frost","burn"],"cap keeps the highest priority looks")
	check(GemAbilityArt.status_overlay(looks).a > 0 and GemAbilityArt.status_tint(looks) == Color(profiles.status_tints.stone),"stone turns the sprite grey")
	check(GemAbilityArt.statuses({"id":1},0,fx).is_empty(),"an unaffected enemy has no status clips")
	# Hits: clip and duration for real hits, no clip for repeating aura ticks.
	fx = GemEffects.new()
	GemAbilityArt.receive(fx,{"type":"shock","source":at,"pos":Vector2.ONE,"from":Vector2.ZERO,"target":3,"effect":{}},{})
	var hit = fx.events.filter(func(e): return e.kind == "ability_hit")[0]
	check(hit.clip == "hit_lightning" and is_equal_approx(hit.duration,GemAbilityArt.clip_duration("hit_lightning")),"a shock hit plays the lightning clip for its full length")
	check(fx.marks.get(3,{}).has("shock"),"a shock leaves a short shocked status")
	GemAbilityArt.receive(fx,{"type":"aura","source":at,"pos":Vector2.ONE,"target":4,"effect":{"type":"enemy_aura","damage":20,"radius":3}},{})
	hit = fx.events.filter(func(e): return e.kind == "ability_hit" and e.target == 4)[0]
	check(hit.clip == "" and hit.style == "fire" and fx.marks[4].has("burn"),"aura ticks mark burning instead of spawning a hit clip")
	fx.begin_frame()
	check(fx.hits.has(3) and not fx.hits.has(4),"begin_frame indexes clip hits by target")
	fx.advance(5)
	check(fx.marks.is_empty(),"burn/shock memory expires")
	config.effects.enabled = false
	fx = GemEffects.new()
	GemAbilityArt.receive(fx,{"type":"shock","source":at,"pos":Vector2.ONE,"from":Vector2.ZERO,"target":3,"effect":{}},{})
	check(fx.events.is_empty() and fx.marks.is_empty(),"disabled effects keep no hit or status memory")
	config.effects = old
	print("ABILITY_CLIPS_CHECK_%s checks=%d failures=%d" % ["OK" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
