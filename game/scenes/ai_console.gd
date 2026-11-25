extends Window
const Policy = preload("res://core/ai_policy.gd")
const Online = preload("res://core/online_ai.gd")
const Identity = preload("res://core/cubot_identity.gd")
const UI = preload("res://ui/mobile_theme.gd")
signal proposal_approved(robot_id: String, tool: String, payload: String)
var roster
var skills
var robot_id := ""
var pending := {}
var histories := {}
var question := ""
var online_busy := false
var online_operation := ""
var request_key := ""
var http: HTTPRequest
var chat_page: VBoxContainer
var settings_page: VBoxContainer
var heading: Label
var subtitle: Label
var connection: Label
var status: Label
var settings_status: Label
var transcript: RichTextLabel
var prompt_box: TextEdit
var model_editor: LineEdit
var key_editor: LineEdit
var share_context: CheckBox
var ask_button: Button
var cancel_button: Button
var approve_button: Button
var reject_button: Button
var test_button: Button
var clear_key_button: Button
var settings_button: Button
var back_button: Button
var proposal_panel: PanelContainer
var proposal_text: RichTextLabel
var verified := false

func configure(roster_: Object, skills_: Object) -> void:
	roster = roster_
	skills = skills_

func _ready() -> void:
	title = "CUBYTE | Cubot chat"
	size = Vector2i(450, 880)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	margin.theme = UI.make_theme()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var identity_column := VBoxContainer.new()
	identity_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity_column)
	heading = UI.label("Cubot", 25)
	identity_column.add_child(heading)
	subtitle = UI.label("OpenAI", 17, UI.MUTED)
	identity_column.add_child(subtitle)
	settings_button = UI.button("Settings", _show_settings)
	header.add_child(settings_button)
	header.add_child(UI.button("Close", hide))
	chat_page = VBoxContainer.new()
	chat_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(chat_page)
	var chat_surface := PanelContainer.new()
	chat_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_page.add_child(chat_surface)
	transcript = RichTextLabel.new()
	transcript.add_theme_font_size_override("normal_font_size", 20)
	transcript.scroll_following = true
	transcript.selection_enabled = true
	transcript.custom_minimum_size.y = 75
	chat_surface.add_child(transcript)
	proposal_panel = PanelContainer.new()
	chat_page.add_child(proposal_panel)
	var proposal_column := VBoxContainer.new()
	proposal_panel.add_child(proposal_column)
	proposal_column.add_child(UI.label("Review local action", 19))
	proposal_text = RichTextLabel.new()
	proposal_text.custom_minimum_size.y = 65
	proposal_text.selection_enabled = true
	proposal_column.add_child(proposal_text)
	var proposal_row := HBoxContainer.new()
	proposal_column.add_child(proposal_row)
	reject_button = UI.button("Reject", _reject)
	approve_button = UI.button("Approve & run", _approve, true)
	approve_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	proposal_row.add_child(reject_button)
	proposal_row.add_child(approve_button)
	proposal_panel.hide()
	var composer := HBoxContainer.new()
	chat_page.add_child(composer)
	prompt_box = TextEdit.new()
	prompt_box.placeholder_text = "Message this Cubot..."
	prompt_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	prompt_box.custom_minimum_size.y = 92
	prompt_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	composer.add_child(prompt_box)
	ask_button = UI.button("Send", _ask, true)
	composer.add_child(ask_button)
	cancel_button = UI.button("Stop", _cancel)
	composer.add_child(cancel_button)
	status = UI.label("", 16, UI.MUTED)
	chat_page.add_child(status)
	settings_page = VBoxContainer.new()
	settings_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(settings_page)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_page.add_child(scroll)
	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(fields)
	fields.add_child(UI.label("OpenAI connection", 23))
	fields.add_child(UI.label("One API key and model for all Cubots.", 17, UI.MUTED))
	fields.add_child(UI.label("Model ID", 17))
	model_editor = LineEdit.new()
	model_editor.custom_minimum_size.y = 60
	model_editor.placeholder_text = "OpenAI model ID"
	model_editor.max_length = 200
	fields.add_child(model_editor)
	fields.add_child(UI.label("API key", 17))
	key_editor = LineEdit.new()
	key_editor.secret = true
	key_editor.custom_minimum_size.y = 60
	key_editor.placeholder_text = "Paste API key"
	key_editor.max_length = 4096
	fields.add_child(key_editor)
	var key_row := HBoxContainer.new()
	fields.add_child(key_row)
	test_button = UI.button("Test connection", _test_connection, true)
	test_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(test_button)
	clear_key_button = UI.button("Clear key", _clear_key)
	key_row.add_child(clear_key_button)
	share_context = CheckBox.new()
	share_context.custom_minimum_size.y = 60
	share_context.text = "Share extra context"
	fields.add_child(share_context)
	fields.add_child(UI.label("Allows sending this Cubot’s memory, skills and recent chat to OpenAI.", 16, UI.MUTED))
	fields.add_child(UI.label("Messages go to OpenAI. Extra context is optional. Requests may use paid API credits. The key is not saved to disk.", 16, UI.MUTED))
	connection = UI.label("Not tested", 18)
	fields.add_child(connection)
	settings_status = UI.label("", 16, UI.MUTED)
	fields.add_child(settings_status)
	back_button = UI.button("Back to chat", _show_chat, true)
	settings_page.add_child(back_button)
	model_editor.text_changed.connect(_credentials_changed)
	key_editor.text_changed.connect(_credentials_changed)
	http = HTTPRequest.new()
	http.timeout = 90.0
	http.body_size_limit = 262144
	http.max_redirects = 0
	http.use_threads = true
	add_child(http)
	http.request_completed.connect(_online_completed)
	settings_page.hide()
	_update_buttons()

func show_for(id: String) -> void:
	if online_busy and id != robot_id:
		return
	if id != robot_id:
		pending = {}
		prompt_box.clear()
	robot_id = id
	var profile: Dictionary = roster.get_profile(id)
	heading.text = id.to_upper()
	subtitle.text = "Cubot  /  " + str(profile.get("role", ""))
	title = "Chat | " + id.to_upper()
	status.text = "Ask your Cubot a question."
	_draw_history()
	if key_editor.text.strip_edges().is_empty() or model_editor.text.strip_edges().is_empty():
		_show_settings()
	else:
		_show_chat()
	popup_centered_ratio(0.96)

func show_settings_for(id: String) -> void:
	if online_busy:
		return
	if not id.is_empty():
		show_for(id)
	else:
		robot_id = ""
		pending = {}
		prompt_box.clear()
		heading.text = "AI settings"
		subtitle.text = "OpenAI · Shared by all Cubots"
		title = "CUBYTE | AI settings"
		popup_centered_ratio(0.96)
	_show_settings()

func _show_settings() -> void:
	if online_busy:
		return
	chat_page.hide()
	settings_page.show()
	settings_button.hide()
	back_button.text = "Done" if robot_id.is_empty() else "Back to chat"
	_update_buttons()

func _show_chat() -> void:
	if robot_id.is_empty():
		hide()
		return
	settings_page.hide()
	chat_page.show()
	settings_button.show()
	_update_buttons()

func _credentials_changed(_value: String) -> void:
	verified = false
	connection.text = "Not tested"
	pending = {}
	_draw_history()
	_update_buttons()

func _clear_key() -> void:
	if online_busy:
		return
	key_editor.clear()
	_credentials_changed("")
	settings_status.text = "Key cleared."

func _ask() -> void:
	if online_busy or robot_id.is_empty():
		return
	question = prompt_box.text.strip_edges()
	if question.is_empty() or question.to_utf8_buffer().size() > 2048:
		status.text = "Enter a message up to 2048 UTF-8 bytes."
		return
	var permitted: Array = []
	for tool in ["text", "png"]:
		if roster.can_use(robot_id, tool):
			permitted.append(tool)
	var context := {}
	if share_context.button_pressed:
		var profile: Dictionary = roster.get_profile(robot_id)
		var binding: Dictionary = skills.get_binding(robot_id)
		var skill_doc := ""
		if not binding.is_empty():
			var skill: Dictionary = skills.get_skill(binding["skill"])
			skill_doc = str(skill.get("markdown", "")).left(1000)
		var recent: Array = histories.get(robot_id, [])
		context = {"personality": profile.get("personality"), "memory": str(profile.get("memory", "")).left(1000), "skill": skill_doc, "history": recent.slice(maxi(0, recent.size() - 3))}
	var system := Identity.system_prompt(robot_id, permitted, context)
	if system.is_empty():
		status.text = "Unknown Cubot."
		return
	_send_online("ask", system, question)

func _test_connection() -> void:
	_send_online("test", "Reply with a short confirmation.", "Reply OK.")

func _send_online(kind: String, system: String, prompt: String) -> void:
	if online_busy:
		return
	var req: Dictionary = Online.make_request("openai", model_editor.text, key_editor.text, system, prompt)
	if req.is_empty():
		status.text = "Enter a valid OpenAI model ID and API key in AI settings."
		settings_status.text = status.text
		return
	pending = {}
	online_operation = kind
	request_key = key_editor.text.strip_edges()
	online_busy = true
	var err := http.request(req["url"], req["headers"], HTTPClient.METHOD_POST, req["body"])
	if err != OK:
		online_busy = false
		request_key = ""
		online_operation = ""
		status.text = "Cannot start HTTPS request (" + str(err) + ")."
		settings_status.text = status.text
	else:
		status.text = robot_id.to_upper() + " is thinking..." if kind == "ask" else "Testing OpenAI..."
		settings_status.text = status.text
	_draw_history()
	_update_buttons()

func _cancel() -> void:
	if not online_busy:
		return
	http.cancel_request()
	online_busy = false
	online_operation = ""
	request_key = ""
	status.text = "Stopped locally. Provider may still charge."
	settings_status.text = status.text
	_draw_history()
	_update_buttons()

func _online_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not online_busy:
		return
	online_busy = false
	var kind := online_operation
	online_operation = ""
	var parsed := Online.parse_response(result, code, body.get_string_from_utf8())
	if parsed.get("ok", false):
		verified = true
		connection.text = "Connected"
		if kind == "test":
			settings_status.text = "Connection test passed."
		else:
			var response: String = parsed["text"]
			if not request_key.is_empty() and response.contains(request_key):
				status.text = "Response rejected: contained credential."
			else:
				_accept_response(response)
				prompt_box.clear()
				status.text = "Response received." if pending.is_empty() else "Approve or reject the proposed action."
	else:
		verified = false
		connection.text = "Not verified"
		status.text = str(parsed.get("error", "OpenAI error."))
		settings_status.text = status.text
	request_key = ""
	_draw_history()
	_update_buttons()

func _accept_response(response: String) -> void:
	var turns: Array = histories.get(robot_id, [])
	turns.append({"user": question.left(2048), "assistant": response.left(4096)})
	while turns.size() > 12:
		turns.pop_front()
	histories[robot_id] = turns
	pending = Policy.proposal(response)
	if not pending.is_empty() and not roster.can_use(robot_id, pending["tool"]):
		pending = {}

func _draw_history() -> void:
	if not is_instance_valid(transcript):
		return
	transcript.clear()
	var turns: Array = histories.get(robot_id, [])
	if turns.is_empty() and not online_busy:
		transcript.add_text("Start a conversation with " + robot_id.to_upper() + ".\n")
	for turn in turns:
		transcript.push_color(UI.ACCENT)
		transcript.add_text("YOU\n")
		transcript.pop()
		transcript.add_text(str(turn["user"]) + "\n\n")
		transcript.push_color(Color("#a8d9be"))
		transcript.add_text(robot_id.to_upper() + "\n")
		transcript.pop()
		transcript.add_text(str(turn["assistant"]) + "\n\n")
	if online_busy and online_operation == "ask":
		transcript.add_text("YOU\n" + question + "\n\n" + robot_id.to_upper() + " is thinking...")
	proposal_panel.visible = not pending.is_empty()
	proposal_text.clear()
	if not pending.is_empty():
		proposal_text.add_text(str(pending["tool"]).to_upper() + "\n" + str(pending["payload"]))

func _reject() -> void:
	pending = {}
	status.text = "Action rejected. No file created."
	_draw_history()
	_update_buttons()

func _approve() -> void:
	if online_busy or pending.is_empty():
		return
	var request := pending.duplicate()
	pending = {}
	_draw_history()
	_update_buttons()
	if not roster.can_use(robot_id, request["tool"]):
		status.text = "Permission denied."
		return
	hide()
	proposal_approved.emit(robot_id, request["tool"], request["payload"])

func _update_buttons() -> void:
	settings_button.disabled = online_busy
	model_editor.editable = not online_busy
	key_editor.editable = not online_busy
	share_context.disabled = online_busy
	test_button.disabled = online_busy
	clear_key_button.disabled = online_busy
	back_button.disabled = online_busy
	prompt_box.editable = not online_busy
	ask_button.disabled = online_busy
	cancel_button.visible = online_busy and online_operation == "ask"
	approve_button.disabled = online_busy or pending.is_empty()
	reject_button.disabled = online_busy

func _exit_tree() -> void:
	if online_busy and is_instance_valid(http):
		http.cancel_request()
	request_key = ""
