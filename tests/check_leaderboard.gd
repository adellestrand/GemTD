extends SceneTree

var checks = 0
var failures = 0

class MockClient extends GemLeaderboardClient:
	var replies: Array = []
	var calls: Array[Dictionary] = []
	func _ready() -> void:
		config = {"enabled":true,"project_url":"https://example.supabase.co","publishable_key":"public-test"}
	func save_session() -> void: pass
	func _request(path: String, payload: Dictionary, token: String = "") -> Dictionary:
		calls.append({"path":path,"payload":payload.duplicate(true),"token":token})
		await get_tree().process_frame
		return replies.pop_front()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+description)
	else: print("PASS: "+description)

func _initialize() -> void: run_checks.call_deferred()

func run_checks() -> void:
	GemCatalog.select_profile("campaign")
	var state = GemRun.new(71)
	var combat = GemCampaignCombat.new(state)
	var journal = GemReviewJournal.new()
	var before = state.snapshot()
	journal.reset(state,false)
	var first = journal.export_report(state,combat)
	check(before == state.snapshot(),"online run identity does not change model or RNG")
	check(first.run_id.length() == 36 and journal.export_report(state,combat).run_id == first.run_id,"stable UUID across exports")
	journal.reset(state,false)
	check(journal.run_id != first.run_id,"new run gets a separate identity")
	var report = first.duplicate(true)
	report.debug_build = false
	report.outcome = "lost"
	report.wave = 3
	report.lives = 0
	check(GemLeaderboardClient.eligibility(report).is_empty() and GemLeaderboardClient.completed_waves(report) == 2,"losing wave excluded from completed-wave score")
	for field in ["debug_build","resumed_from_checkpoint","actions_truncated"]:
		var invalid = report.duplicate(true)
		invalid[field] = true
		check(not GemLeaderboardClient.eligibility(invalid).is_empty(),"ineligible run blocked: "+field)
	var client = MockClient.new()
	root.add_child(client)
	client.replies = [{"data":[]}]
	var response = await client.load_scores(first.catalog_sha256)
	check(response.has("scores") and client.calls.size() == 1 and client.session.is_empty(),"reading top scores never signs up a player")
	client.replies = [{"data":{"access_token":"ACCESS","refresh_token":"REFRESH","expires_in":3600}},{"data":{"submitted":true}}]
	response = await client.submit_score(report,"Åke 2")
	check(not response.has("error") and client.calls[1].path == "/auth/v1/signup" and client.calls[2].token == "ACCESS","explicit submission signs up anonymously then uses user JWT")
	check(not client.busy and client.calls[2].payload.report == report,"submission sends the report unchanged and releases request lock")
	client.session.expires_at = 0
	client.replies = [{"data":{"access_token":"NEW","refresh_token":"NEXT","expires_in":3600}},{"data":{"submitted":true}}]
	response = await client.submit_score(report,"Åke")
	check(client.calls[3].path.ends_with("refresh_token") and client.calls[3].payload.refresh_token == "REFRESH" and client.calls[4].token == "NEW","expired session refreshes before submission")
	client.replies = [{"error":"offline"}]
	response = await client.submit_score(report,"Åke")
	check(response.has("error") and not client.busy and state.snapshot() == before,"service outage cannot mutate or block local gameplay")
	var count = client.calls.size()
	response = await client.submit_score(report,"[url]bad")
	check(response.has("error") and client.calls.size() == count,"invalid display names never make requests")
	client.config.enabled = false
	response = await client.load_scores(first.catalog_sha256)
	check(response.has("error") and client.calls.size() == count,"unconfigured service fails softly without network")
	client.free()
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	game.show_leaderboard()
	await process_frame
	check(game.leaderboard_dialog.visible and not game.leaderboard_dialog.scores.bbcode_enabled,"scoreboard modal opens with safe plain-text names")
	check(game.leaderboard_dialog.submit_button.disabled and not game.leaderboard_dialog.scores.text.is_empty(),"disabled deployment explains availability and prevents submission")
	game.show_summary()
	check(not game.leaderboard_dialog.visible and game.summary_dialog.visible,"summary and leaderboard follow the shared modal rules")
	game.free()
	print("LEADERBOARD_CHECK_OK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
