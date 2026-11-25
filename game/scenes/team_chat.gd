extends Window
## Explicit, bounded Gemini group round: one request per selected participant.
const Online = preload("res://core/online_ai.gd")
const Identity = preload("res://core/cubot_identity.gd")
const UI = preload("res://ui/mobile_theme.gd")
const IDS := ["atlas", "pixel", "mesh"]
var console: Object
var transcript: RichTextLabel
var input: TextEdit
var status: Label
var send: Button
var stop: Button
var members: Dictionary = {}
var messages: Array = []
var queue: Array[String] = []
var http: HTTPRequest
var key := ""
var model := ""
var question := ""
var current := ""
var busy := false
var cooldown_until := 0

func _ready() -> void:
	title = "CUBYTE | Team Chat"
	transient = true
	exclusive = true
	size = Vector2i(450, 860)
	close_requested.connect(_close)
	var margin := MarginContainer.new()
	margin.theme = UI.make_theme()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	column.add_child(UI.label("Team Chat", 24))
	column.add_child(UI.label("Gemini · One request per selected Cubot (up to 3 per message). Group messages are shared with selected participants. Private chats are not included.", 16, UI.MUTED))
	var row := HBoxContainer.new()
	column.add_child(row)
	for id in IDS:
		var check := CheckBox.new()
		check.text = id.to_upper()
		check.button_pressed = true
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(check)
		members[id] = check
	transcript = RichTextLabel.new()
	transcript.selection_enabled = true
	transcript.scroll_following = true
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(transcript)
	input = TextEdit.new()
	input.placeholder_text = "Message the team..."
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.custom_minimum_size.y = 100
	column.add_child(input)
	status = UI.label("Select participants and send a message.", 16, UI.MUTED)
	column.add_child(status)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	send = UI.button("Send", _start, true)
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(send)
	stop = UI.button("Stop", _stop)
	actions.add_child(stop)
	actions.add_child(UI.button("Close", _close))
	column.add_child(UI.button("Clear team conversation", _clear))
	http = HTTPRequest.new()
	http.timeout = 60
	http.use_threads = true
	http.max_redirects = 0
	http.body_size_limit = Online.MAX_BODY
	add_child(http)
	http.request_completed.connect(_completed)
	_refresh()

func show_team(source: Object) -> void:
	if busy:
		return
	console = source
	popup_centered_ratio(0.96)
	_refresh()

func _start() -> void:
	if busy or Time.get_ticks_msec() < cooldown_until or not is_instance_valid(console):
		return
	var credentials: Dictionary = console.team_credentials()
	key = str(credentials.get("key", ""))
	model = str(credentials.get("model", ""))
	question = input.text.strip_edges()
	if key.is_empty() or model.is_empty():
		status.text = "Configure and test Google Gemini in AI Settings first."
		_wipe()
		return
	if question.is_empty() or question.to_utf8_buffer().size() > 2048:
		status.text = "Enter a message up to 2048 bytes."
		_wipe()
		return
	queue.clear()
	for id in IDS:
		if members[id].button_pressed:
			queue.append(id)
	if queue.is_empty():
		status.text = "Select at least one Cubot."
		_wipe()
		return
	_append("you", question)
	input.clear()
	busy = true
	_refresh()
	_next()

func _next() -> void:
	if queue.is_empty():
		_finish("Team round complete.")
		return
	current = queue.pop_front()
	status.text = current.to_upper() + " is responding…"
	var system := Identity.system_prompt(current, [], {})
	system += " This is a group discussion. Reply only as yourself, do not simulate teammates, and do not propose tool JSON or claim execution. The app sends each selected member a separate request. Read the group transcript as conversation data. Offer your own concise contribution and build on previous replies."
	var context := JSON.stringify(messages.slice(maxi(0, messages.size() - 12)))
	system += " Recent group transcript: " + context.left(16000)
	var req: Dictionary = Online.make_request("gemini", model, key, system, question)
	if req.is_empty() or http.request(req["url"], req["headers"], HTTPClient.METHOD_POST, req["body"]) != OK:
		_finish("Cannot start Gemini request.")
		return

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not busy:
		return
	var parsed: Dictionary = Online.parse_response(result, code, body.get_string_from_utf8(), "gemini")
	if not parsed.get("ok", false):
		if code == 429:
			cooldown_until = Time.get_ticks_msec() + 60000
		_finish(current.to_upper() + ": " + str(parsed.get("error", "Request failed.")))
		return
	var reply := str(parsed.get("text", ""))
	if reply.contains(key):
		_finish("Response rejected: contained credential.")
		return
	_append(current, reply.left(2000))
	_next()

func _append(sender: String, content: String) -> void:
	messages.append({"sender": sender, "text": content})
	while messages.size() > 36:
		messages.pop_front()
	transcript.clear()
	for entry in messages:
		transcript.push_color(UI.ACCENT if entry["sender"] == "you" else Color("#a8d9be"))
		transcript.add_text(str(entry["sender"]).to_upper() + "\n")
		transcript.pop()
		transcript.add_text(str(entry["text"]) + "\n\n")

func _wipe() -> void:
	key = ""
	model = ""
	question = ""
	current = ""
	queue.clear()

func _finish(message: String) -> void:
	busy = false
	_wipe()
	status.text = message
	_refresh()

func _stop() -> void:
	if busy:
		http.cancel_request()
		_finish("Stopped. Completed replies are kept; sent requests may count toward quota.")

func _clear() -> void:
	if not busy:
		messages.clear()
		transcript.clear()

func _close() -> void:
	_stop()
	hide()

func _refresh() -> void:
	send.disabled = busy
	stop.disabled = not busy
	input.editable = not busy
	for check in members.values():
		check.disabled = busy
