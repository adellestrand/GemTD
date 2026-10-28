extends SceneTree

func _initialize() -> void: run_check.call_deferred()

func run_check() -> void:
	var endpoint = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--endpoint="): endpoint = argument.trim_prefix("--endpoint=")
	if not endpoint.begins_with("http://127.0.0.1:"):
		printerr("Local transport fixture endpoint required")
		quit(1)
		return
	var client = GemLeaderboardClient.new()
	root.add_child(client)
	client.config = {"project_url":endpoint,"publishable_key":"test-only"}
	for path in ["/gzip","/plain"]:
		var response = await client._request(path,{"p_limit":20})
		if response.has("error") or not response.get("data") is Array or response.data.size() != 20 or response.data[0].display_name != "Åke transport test":
			printerr("Transport could not read scoreboard fixture: "+path)
			client.queue_free()
			quit(1)
			return
	client.queue_free()
	await process_frame
	print("LEADERBOARD_TRANSPORT_CHECK_OK compressed and plain JSON, 20 rows, Unicode")
	quit(0)
