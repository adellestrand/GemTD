extends SceneTree

# Enemy route lines are switched with the "Show routes" checkbox (and R). Presentation only.

var checks = 0
var failures = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)
	else:
		print("PASS: "+description)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	if not "--smoke" in OS.get_cmdline_user_args():
		quit(1)
		return
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	await process_frame
	var before = game.run.snapshot()
	check(game.routes_check is CheckBox and game.routes_check.is_inside_tree(),"the map tools have a Show routes checkbox")
	check(game.routes_check.button_pressed and game.board_view.show_routes,"routes start shown and the checkbox agrees")
	game.routes_check.button_pressed = false
	check(not game.board_view.show_routes,"unticking the checkbox hides the route lines")
	game.routes_check.button_pressed = true
	check(game.board_view.show_routes,"ticking it shows them again")
	var key = InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	game._unhandled_key_input(key)
	check(not game.board_view.show_routes and not game.routes_check.button_pressed,"R toggles the routes and keeps the checkbox in step")
	check(game.run.phase == "build" and not game.board_view.show_routes,"routes stay hidden in the build phase when unticked")
	check(before == game.run.snapshot(),"toggling routes changes nothing in the run")
	print("ROUTE_TOGGLE_CHECK_%s checks=%d failures=%d" % ["OK" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
