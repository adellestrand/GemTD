class_name GemAudio
extends Node

var player: AudioStreamPlayer
var attack_player: AudioStreamPlayer
var sounds: Dictionary = {}
var volume = 0.35
var last_attack_ms = -1000

func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)
	attack_player = AudioStreamPlayer.new()
	attack_player.max_polyphony = 3
	add_child(attack_player)
	for cue in ["place", "combine", "wave", "leak", "demolish", "win", "attack"]:
		var frequency = {"place": 660.0, "combine": 880.0, "wave": 330.0, "leak": 120.0, "demolish": 180.0, "win": 1046.5, "attack": 520.0}[cue]
		var wav = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var samples = 1103 if cue == "attack" else 4410
		var bytes = PackedByteArray()
		bytes.resize(samples*2)
		for i in range(samples):
			var t = float(i)/22050.0
			var envelope = pow(1.0-float(i)/samples,2.0)*minf(1.0,float(i)/80.0)
			var sample = sin(TAU*frequency*t)*envelope*.22
			bytes.encode_s16(i*2,int(sample*32767))
		wav.data = bytes
		sounds[cue] = wav

func play_cue(cue: String) -> void:
	if volume <= 0 or not sounds.has(cue):
		return
	player.volume_db = linear_to_db(volume)
	player.stream = sounds[cue]
	player.play()

func play_attack(_from: Vector2 = Vector2.ZERO, _to: Vector2 = Vector2.ZERO, _color: Color = Color.WHITE) -> void:
	var now = Time.get_ticks_msec()
	if volume <= 0 or now-last_attack_ms < 100:
		return
	last_attack_ms = now
	attack_player.volume_db = linear_to_db(volume*.35)
	attack_player.stream = sounds.attack
	attack_player.play()
