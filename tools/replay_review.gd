extends SceneTree

func _initialize() -> void:
	var path = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			path = argument.trim_prefix("--report=")
	var decoded = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not decoded is Dictionary:
		printerr("Provide a readable report with --report=path.json")
		quit(1)
		return
	var result = GemReviewReplay.replay(decoded)
	print("REVIEW_REPLAY "+JSON.stringify(result))
	quit(0 if result.ok else 1)
