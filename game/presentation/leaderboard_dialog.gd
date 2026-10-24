class_name GemLeaderboardDialog
extends AcceptDialog

var client: GemLeaderboardClient
var report: Dictionary = {}
var content: VBoxContainer
var description: Label
var scores: RichTextLabel
var player_name: LineEdit
var submit_button: Button
var refresh_button: Button
var status: Label
var generation = 0

func _ready() -> void:
	title = "Leaderboard · solo campaign"
	wrap_controls = false
	min_size = Vector2i(720,540)
	get_ok_button().text = "Close"
	client = GemLeaderboardClient.new()
	add_child(client)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	add_child(content)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	scores = RichTextLabel.new()
	scores.bbcode_enabled = false
	scores.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scores.add_theme_font_size_override("normal_font_size",16)
	content.add_child(scores)
	var row = HBoxContainer.new()
	content.add_child(row)
	player_name = LineEdit.new()
	player_name.placeholder_text = "Display name (2–24 characters)"
	player_name.max_length = 24
	player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name.text = str(GemLeaderboardClient.read_json("user://leaderboard_name.json").get("name",""))
	row.add_child(player_name)
	submit_button = Button.new()
	submit_button.text = "Submit this run"
	submit_button.pressed.connect(submit_current)
	row.add_child(submit_button)
	refresh_button = Button.new()
	refresh_button.text = "Refresh scores"
	refresh_button.pressed.connect(refresh_scores)
	content.add_child(refresh_button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	size_changed.connect(func(): fit_content.call_deferred())
	content.resized.connect(func(): fit_content.call_deferred())
	content.minimum_size_changed.connect(func(): fit_content.call_deferred())

func fit_content() -> void:
	content.position = Vector2(16,12)
	content.size = Vector2(size.x-32,maxi(0,size.y-76))

func open_report(value: Dictionary) -> void:
	generation += 1
	report = value.duplicate(true)
	description.text = "Best result per player · cleared waves, then lives.\nUnverified beta scores · rules %s · %s\nSubmitting shares your name and run report. No email required. Your player identity stays in this browser/device; clearing storage creates a new identity." % [str(report.get("catalog_sha256","")).left(8),str(report.get("game_version",""))]
	scores.text = "Loading scores..."
	status.text = GemLeaderboardClient.eligibility(report)
	update_buttons()
	popup_centered(Vector2i(720,540))
	fit_content()
	refresh_scores()

func update_buttons() -> void:
	submit_button.disabled = client.busy or not client.configured() or not GemLeaderboardClient.eligibility(report).is_empty()
	refresh_button.disabled = client.busy or not client.configured()
	player_name.editable = not client.busy

func refresh_scores() -> void:
	if client.busy: return
	var current = generation
	refresh_button.disabled = true
	submit_button.disabled = true
	var response = await client.load_scores(str(report.get("catalog_sha256","")))
	if current != generation:
		refresh_scores()
		return
	update_buttons()
	if response.has("error"):
		scores.text = str(response.error)
		return
	scores.text = "Rank    Cleared    Lives    Player\n\n"
	var rank = 0
	for item in response.scores:
		if not item is Dictionary: continue
		rank += 1
		scores.text += "%d.    %d / 100    %d    %s%s\n" % [rank,int(item.get("completed_waves",0)),int(item.get("lives",0)),str(item.get("display_name","Player")),"" if item.get("verified",false) else " (unverified)"]
	if rank == 0: scores.text += "No scores for these rules yet. Be the first!"

func submit_current() -> void:
	if client.busy: return
	var current = generation
	status.text = "Submitting..."
	submit_button.disabled = true
	refresh_button.disabled = true
	player_name.editable = false
	var response = await client.submit_score(report,player_name.text)
	if current != generation:
		refresh_scores()
		return
	update_buttons()
	if response.has("error"):
		status.text = str(response.error)
		return
	var file = FileAccess.open("user://leaderboard_name.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"name":player_name.text.strip_edges()}))
	status.text = "Score submitted (unverified). Repeating this submission will not create a duplicate."
	refresh_scores()
