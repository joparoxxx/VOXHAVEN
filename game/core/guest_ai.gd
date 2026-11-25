extends RefCounted
## Public deployment URL only; never put OpenAI credentials here.
const BASE_URL := ""
const SESSION_PATH := "user://cubyte_guest_session.json"
var id_token := ""
var refresh_token := ""
var expires_at := 0

func _init() -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if f == null or f.get_length() > 16384:
		return
	var saved: Variant = JSON.parse_string(f.get_as_text())
	if saved is Dictionary and saved.get("gateway") == BASE_URL and saved.get("refresh_token") is String:
		refresh_token = saved["refresh_token"].left(8192)

func configured() -> bool:
	return BASE_URL.begins_with("https://") and not BASE_URL.ends_with("/")

func has_session() -> bool:
	return not id_token.is_empty() and expires_at > int(Time.get_unix_time_from_system()) + 60

func auth_request() -> Dictionary:
	if not configured():
		return {}
	var refresh := not refresh_token.is_empty()
	return {"url": BASE_URL + ("/refresh" if refresh else "/guest"),
		"headers": PackedStringArray(["Content-Type: application/json"]),
		"body": JSON.stringify({"refresh_token": refresh_token} if refresh else {})}

func accept_session(raw: String) -> bool:
	var data: Variant = JSON.parse_string(raw)
	if not data is Dictionary or not data.get("id_token") is String or not data.get("refresh_token") is String:
		return false
	if data["id_token"].is_empty() or data["id_token"].length() > 8192 or data["refresh_token"].is_empty() or data["refresh_token"].length() > 8192:
		return false
	id_token = data["id_token"]
	refresh_token = data["refresh_token"]
	expires_at = int(Time.get_unix_time_from_system()) + clampi(int(data.get("expires_in", 3600)), 60, 3600)
	# App-private sandbox only; Android Keystore integration is a production prerequisite.
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"gateway": BASE_URL, "refresh_token": refresh_token}))
		f.close()
	return true

func chat_request(cubot: String, system: String, prompt: String) -> Dictionary:
	if not configured() or not has_session() or cubot not in ["atlas", "pixel", "mesh"]:
		return {}
	if system.to_utf8_buffer().size() > 24576 or prompt.to_utf8_buffer().size() > 2048:
		return {}
	return {"url": BASE_URL + "/chat", "headers": PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + id_token]),
		"body": JSON.stringify({"cubot": cubot, "system": system, "prompt": prompt})}
