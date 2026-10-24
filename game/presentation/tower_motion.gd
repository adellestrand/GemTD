
extends RefCounted

# Presentation-only tower animation: idle crystal glow, a short flash when a tower
# fires and a small landing when a gem is placed or upgraded. Reads timestamps that
# the board view records from existing events. No RNG, no game state, nothing saved.
# The pedestal never leaves its cell: scaling is anchored at the sprite's base.

var placed_at: Dictionary = {}
var fired_at: Dictionary = {}

static func settings() -> Dictionary:
	var motion: Dictionary = GemArt.config().get("motion",{})
	return motion.get("towers",{}) if bool(motion.get("enabled",true)) else {"enabled":false}

func clear() -> void:
	placed_at.clear()
	fired_at.clear()

func placed(cell: Vector2i, time: float) -> void:
	placed_at[cell] = time

func fired(cell: Vector2i, time: float) -> void:
	fired_at[cell] = time

func forget(cell: Vector2i) -> void:
	placed_at.erase(cell)
	fired_at.erase(cell)

# Returns scale (applied around the sprite base), brightness flash 0..1 and glow alpha.
func pose(cell: Vector2i, time: float) -> Dictionary:
	var config = settings()
	var result = {"scale":Vector2.ONE,"flash":0.0,"glow":0.0}
	if not bool(config.get("enabled",true)):
		return result
	var pop_time = float(config.get("pop_time",.26))
	if placed_at.has(cell):
		var t = (time-float(placed_at[cell]))/pop_time
		if t >= 1.0 or t < 0.0:
			placed_at.erase(cell)
		else:
			# ease-out-back: grows from 60 % with a small overshoot, then settles
			var c = 1.70158
			var k = 1.0+(c+1.0)*pow(t-1.0,3)+c*pow(t-1.0,2)
			var s = lerpf(.6,1.0,k)
			result.scale = Vector2(lerpf(1.03,1.0,k)*s,s)
	var flash_time = float(config.get("fire_flash",.14))
	if fired_at.has(cell):
		var f = (time-float(fired_at[cell]))/flash_time
		if f >= 1.0 or f < 0.0:
			fired_at.erase(cell)
		else:
			result.flash = 1.0-f
	var idle = float(config.get("idle_glow",.12))
	var phase = float((cell.x*7+cell.y*13)%17)/17.0*TAU
	result.glow = idle*(.65+.35*sin(time*float(config.get("glow_speed",2.2))+phase))+result.flash*float(config.get("fire_glow",.35))
	return result
