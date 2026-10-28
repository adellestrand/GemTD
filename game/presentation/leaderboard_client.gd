class_name GemLeaderboardClient
extends Node

const CONFIG = "res://assets/online/leaderboard.json"
const SESSION = "user://leaderboard_session.json"
var config: Dictionary = {}
var session: Dictionary = {}
var busy = false

func _ready() -> void:
	config = read_json(CONFIG)
	session = read_json(SESSION)
	if session.get("project_url","") != config.get("project_url",""): session.clear()

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func configured() -> bool:
	return config.get("enabled",false) and str(config.get("project_url","")).begins_with("https://") and not str(config.get("publishable_key","")).is_empty()

static func eligibility(report: Dictionary) -> String:
	if report.get("balance_profile","") != "full-solo-dev": return "Only the solo campaign has a leaderboard."
	if report.get("debug_build",true): return "Scores require a release build."
	if report.get("outcome","") not in ["won","lost"]: return "Finish this run to submit a score."
	if report.get("resumed_from_checkpoint",true): return "Resumed checkpoints cannot submit. Start a fresh run."
	if report.get("actions_truncated",true) or report.get("starting_checkpoint",{}).get("wave",0) != 1: return "A complete run report from wave 1 is required."
	if str(report.get("run_id","")).is_empty(): return "Start a fresh run to create an online run identity."
	return ""

static func completed_waves(report: Dictionary) -> int:
	return 100 if report.get("outcome","") == "won" else maxi(0,int(report.get("wave",1))-1)

func load_scores(rules_hash: String) -> Dictionary:
	if busy: return {"error":"A request is already in progress."}
	if not configured(): return {"error":"Leaderboard is not available yet. You can keep playing offline."}
	busy = true
	var response = await _request("/rest/v1/rpc/leaderboard_top",{"p_rules_hash":rules_hash,"p_limit":20})
	busy = false
	if response.has("error"): return response
	return {"scores":response.data} if response.data is Array else {"error":"The leaderboard returned an invalid response."}

func submit_score(report: Dictionary, display_name: String) -> Dictionary:
	if busy: return {"error":"A request is already in progress."}
	if not configured(): return {"error":"Leaderboard is not available yet. You can keep playing offline."}
	var reason = eligibility(report)
	if not reason.is_empty(): return {"error":reason}
	var expression = RegEx.new()
	expression.compile("^[\\p{L}\\p{N} ._-]{2,24}$")
	var cleaned = display_name.strip_edges()
	if expression.search(cleaned) == null: return {"error":"Use 2–24 letters, numbers, spaces, . _ or -."}
	busy = true
	var auth = await authenticate()
	if auth.has("error"):
		busy = false
		return auth
	var response = await _request("/functions/v1/submit-run",{"nickname":cleaned,"report":report},str(session.access_token))
	# A rejected/expired session is cleared; retry stays an explicit user action.
	if response.get("code",0) == 401:
		session.clear()
		save_session()
	busy = false
	return response

func authenticate() -> Dictionary:
	if not str(session.get("access_token","")).is_empty() and float(session.get("expires_at",0)) > Time.get_unix_time_from_system()+60: return {}
	var refreshing = not str(session.get("refresh_token","")).is_empty()
	var path = "/auth/v1/token?grant_type=refresh_token" if refreshing else "/auth/v1/signup"
	var payload = {"refresh_token":session.refresh_token} if refreshing else {"data":{}}
	var response = await _request(path,payload)
	if response.has("error"):
		if refreshing and response.get("code",0) in [400,401,403]:
			session.clear()
			save_session()
		return {"error":"Could not sign in. Please try submitting again later."}
	var data = response.get("data",{})
	if not data is Dictionary or str(data.get("access_token","")).is_empty() or str(data.get("refresh_token","")).is_empty(): return {"error":"Could not create a player session."}
	session = {"project_url":config.project_url,"access_token":data.access_token,"refresh_token":data.refresh_token,"expires_at":Time.get_unix_time_from_system()+float(data.get("expires_in",3600))}
	save_session()
	return {}

func save_session() -> void:
	var file = FileAccess.open(SESSION,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(session))

func _request(path: String, payload: Dictionary, token: String = "") -> Dictionary:
	var http = HTTPRequest.new()
	# Browser Fetch already decodes Content-Encoding, but keeps the header.
	# A second Godot decompression fails once the scoreboard is large enough
	# for Supabase to compress it. Native HTTP still needs Godot decompression.
	http.accept_gzip = not OS.has_feature("web")
	http.timeout = 15
	add_child(http)
	var headers = PackedStringArray(["Content-Type: application/json","apikey: "+str(config.publishable_key)])
	if not token.is_empty(): headers.append("Authorization: Bearer "+token)
	var error = http.request(str(config.project_url).trim_suffix("/")+path,headers,HTTPClient.METHOD_POST,JSON.stringify(payload))
	if error != OK:
		http.queue_free()
		return {"error":"Cannot reach the leaderboard. Please try again later."}
	var result = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS: return {"error":"Cannot reach the leaderboard. Your game is unaffected."}
	var code = int(result[1])
	var data = JSON.parse_string(result[3].get_string_from_utf8())
	if code < 200 or code >= 300:
		var message = "Leaderboard request failed. Please try again later."
		if code == 429: message = "Too many submissions. Please try again later."
		elif code == 409: message = "This rules version is no longer accepting scores."
		elif code == 401: message = "Player session expired. Please submit again to sign in."
		elif code == 400: message = "This run could not be accepted. Check the name and run eligibility."
		return {"error":message,"code":code}
	return {"data":data}
