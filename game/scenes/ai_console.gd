extends Window
const Policy = preload("res://core/ai_policy.gd")
const Online = preload("res://core/online_ai.gd")
const Guest = preload("res://core/guest_ai.gd")
var guest = Guest.new()
var personal_mode: CheckBox
var personal_fields: VBoxContainer
var guest_system := ""
var guest_prompt := ""
var auth_pending := false
const Identity = preload("res://core/cubot_identity.gd")
const UI = preload("res://ui/mobile_theme.gd")
signal proposal_approved(robot_id: String, tool: String, payload: String, worker_id: String)
var roster
var skills
var robot_id := ""
var pending := {}
var proposed_worker := ""
const ChatHistory = preload("res://core/chat_history.gd")
var history_store = ChatHistory.new()
var histories := {}
var clear_history_button: Button
var clear_history_confirm: ConfirmationDialog
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
var guest_wait_until := 0
var auth_wait_until := 0
var guest_remaining := -1
var quota_label: Label

func configure(roster_: Object, skills_: Object) -> void:
	roster = roster_
	skills = skills_

func _ready() -> void:
	histories = history_store.load_all()
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
	quota_label = UI.label("", 16, UI.MUTED)
	chat_page.add_child(quota_label)
	var quota_timer := Timer.new()
	quota_timer.wait_time = 0.25
	quota_timer.timeout.connect(_update_quota_display)
	add_child(quota_timer)
	quota_timer.start()
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
	fields.add_child(UI.label("AI access", 23))
	fields.add_child(UI.label("Guest mode needs no registration or API key. Your guest account is created when you first connect.", 17, UI.MUTED))
	personal_mode = CheckBox.new()
	personal_mode.text = "Use my own OpenAI key"
	personal_mode.custom_minimum_size.y = 60
	fields.add_child(personal_mode)
	personal_fields = VBoxContainer.new()
	fields.add_child(personal_fields)
	personal_fields.add_child(UI.label("Model ID", 17))
	model_editor = LineEdit.new()
	model_editor.custom_minimum_size.y = 60
	model_editor.placeholder_text = "OpenAI model ID"
	model_editor.max_length = 200
	personal_fields.add_child(model_editor)
	personal_fields.add_child(UI.label("API key", 17))
	key_editor = LineEdit.new()
	key_editor.secret = true
	key_editor.custom_minimum_size.y = 60
	key_editor.placeholder_text = "Paste API key"
	key_editor.max_length = 4096
	personal_fields.add_child(key_editor)
	var key_row := HBoxContainer.new()
	fields.add_child(key_row)
	test_button = UI.button("Test connection", _test_connection, true)
	test_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(test_button)
	clear_key_button = UI.button("Clear key", _clear_key)
	key_row.add_child(clear_key_button)
	personal_mode.toggled.connect(_access_changed)
	personal_fields.hide()
	clear_key_button.hide()
	test_button.text = "Connect as guest"
	share_context = CheckBox.new()
	share_context.custom_minimum_size.y = 60
	share_context.text = "Share extra context"
	fields.add_child(share_context)
	fields.add_child(UI.label("Allows sending this Cubot’s memory, skills and recent chat to the selected AI provider.", 16, UI.MUTED))
	fields.add_child(UI.label("Guest AI uses CUBYTE’s server and shared daily limits. Messages may go to Google Gemini. Free-tier providers may use submitted content for improvement. Personal OpenAI requests use your own credits. Extra context is optional.", 16, UI.MUTED))
	connection = UI.label("Not tested", 18)
	fields.add_child(connection)
	fields.add_child(UI.label("Chat history is saved locally on this device (last 12 exchanges per Cubot). Enable Share extra context only if you want to send recent chat and memory to the AI provider. Avoid entering sensitive information.", 16, UI.MUTED))
	clear_history_button = UI.button("Clear this Cubot’s history", _confirm_clear_history)
	fields.add_child(clear_history_button)
	clear_history_confirm = ConfirmationDialog.new()
	clear_history_confirm.title = "Clear chat history?"
	clear_history_confirm.confirmed.connect(_clear_history)
	add_child(clear_history_confirm)
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
		subtitle.text = "AI access · Shared by all Cubots"
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

func _access_changed(enabled: bool) -> void:
	personal_fields.visible = enabled
	clear_key_button.visible = enabled
	test_button.text = "Test personal key" if enabled else "Connect as guest"
	_credentials_changed("")
	settings_status.text = "Guest mode: no key needed." if not enabled else "Enter your personal API details."

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
	if online_busy or robot_id.is_empty() or (not personal_mode.button_pressed and (Time.get_ticks_msec() < guest_wait_until or (not guest.has_session() and Time.get_ticks_msec() < auth_wait_until))):
		return
	question = prompt_box.text.strip_edges()
	if question.is_empty() or question.to_utf8_buffer().size() > 2048:
		status.text = "Enter a message up to 2048 UTF-8 bytes."
		return
	var permitted: Array = []
	for tool in ["text", "png"]:
		if roster.can_use(robot_id, tool):
			permitted.append(tool)
	var profile: Dictionary = roster.get_profile(robot_id)
	var context := {}
	if share_context.button_pressed:
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
	if not personal_mode.button_pressed:
		_send_guest(kind, system, prompt)
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

func _send_guest(kind: String, system: String, prompt: String) -> void:
	if not guest.has_session() and Time.get_ticks_msec() < auth_wait_until:
		settings_status.text = "Guest sign-in is temporarily limited. Try after the retry time."
		return
	if not guest.configured():
		status.text = "Guest AI server is not configured yet. Local gameplay is available."
		settings_status.text = status.text
		return
	pending = {}
	online_operation = kind
	guest_system = system
	guest_prompt = prompt
	request_key = ""
	online_busy = true
	if kind == "test" and guest.has_session():
		online_busy = false
		online_operation = ""
		connection.text = "Guest connected"
		settings_status.text = "Guest session ready."
		_update_buttons()
		return
	auth_pending = not guest.has_session()
	var req: Dictionary = guest.auth_request() if auth_pending else guest.chat_request(robot_id, system, prompt)
	_guest_http(req)

func _guest_http(req: Dictionary) -> void:
	var err := ERR_INVALID_PARAMETER
	if not req.is_empty():
		err = http.request(req["url"], req["headers"], HTTPClient.METHOD_POST, req["body"])
	if err != OK:
		online_busy = false
		online_operation = ""
		auth_pending = false
		status.text = "Could not connect to guest AI."
	else:
		status.text = "Connecting guest..." if auth_pending else robot_id.to_upper() + " is thinking..."
	settings_status.text = status.text
	_draw_history()
	_update_buttons()

func _cancel() -> void:
	if not online_busy:
		return
	http.cancel_request()
	auth_pending = false
	guest_system = ""
	guest_prompt = ""
	online_busy = false
	online_operation = ""
	request_key = ""
	status.text = "Stopped locally. Request may still count toward quota."
	settings_status.text = status.text
	_draw_history()
	_update_buttons()

func _online_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not online_busy:
		return
	if auth_pending:
		auth_pending = false
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and guest.accept_session(body.get_string_from_utf8()):
			if online_operation == "test":
				online_busy = false
				online_operation = ""
				connection.text = "Guest connected"
				settings_status.text = "Guest session ready."
				_update_buttons()
			else:
				_guest_http(guest.chat_request(robot_id, guest_system, guest_prompt))
			return
		online_busy = false
		online_operation = ""
		if code == 429:
			var detail: Variant = JSON.parse_string(body.get_string_from_utf8())
			var retry := 60
			status.text = "Guest sign-in limit reached. Chat quota is separate."
			if detail is Dictionary:
				retry = clampi(int(detail.get("retry_after", 60)), 1, 86400)
				match str(detail.get("scope", "")):
					"firebase":
						status.text = "Firebase temporarily limits sign-ins."
					"guest_ip":
						status.text = "Guest registrations from this network reached the daily limit."
					"guest_global":
						status.text = "Office guest registration limit reached."
					"refresh_ip", "refresh_global":
						status.text = "Guest session refresh limit reached."
			auth_wait_until = Time.get_ticks_msec() + retry * 1000
		elif code == 401:
			status.text = "Guest session rejected. Contact support."
		else:
			status.text = "Guest sign-in unavailable (HTTP %d)." % code
		connection.text = "Guest not connected"
		settings_status.text = status.text
		_draw_history()
		_update_buttons()
		return
	if not personal_mode.button_pressed:
		_read_guest_quota(code, _headers, body)
	if not personal_mode.button_pressed and code == 401:
		guest.id_token = ""
	online_busy = false
	var kind := online_operation
	online_operation = ""
	var parsed := Online.parse_response(result, code, body.get_string_from_utf8())
	if parsed.get("ok", false):
		verified = true
		connection.text = "Connected" if personal_mode.button_pressed else "Guest connected"
		if kind == "test":
			settings_status.text = "Connection test passed."
		else:
			var response: String = parsed["text"]
			if not request_key.is_empty() and response.contains(request_key):
				status.text = "Response rejected: contained credential."
			else:
				var saved := _accept_response(response)
				prompt_box.clear()
				status.text = "Response received." if pending.is_empty() else "Approve or reject the proposed action."
				if not saved:
					status.text += " Local history could not be saved."
	else:
		verified = false
		connection.text = "Not verified"
		if personal_mode.button_pressed:
			status.text = str(parsed.get("error", "OpenAI error."))
		else:
			status.text = _guest_error(code, body) + "\n" + _guest_diagnostic(result, code, body)
		settings_status.text = status.text
	request_key = ""
	_draw_history()
	_update_buttons()

func _accept_response(response: String) -> bool:
	var turns: Array = histories.get(robot_id, [])
	turns.append({"user": question.left(2048), "assistant": response.left(4096)})
	while turns.size() > 12:
		turns.pop_front()
	histories[robot_id] = turns
	pending = Policy.proposal(response)
	proposed_worker = ""
	if not pending.is_empty():
		if roster.can_use(robot_id, pending["tool"]):
			proposed_worker = roster.delegate(pending["tool"]) if robot_id == "atlas" else robot_id
		if proposed_worker.is_empty():
			pending = {}
	return history_store.save(robot_id, turns)

func _confirm_clear_history() -> void:
	if online_busy or robot_id.is_empty():
		return
	clear_history_confirm.dialog_text = "Delete saved conversation with " + robot_id.to_upper() + " on this device? Profile notes and skills are not affected."
	clear_history_confirm.popup_centered()

func _clear_history() -> void:
	if online_busy or robot_id.is_empty():
		return
	if history_store.clear(robot_id):
		histories.erase(robot_id)
		pending = {}
		prompt_box.clear()
		settings_status.text = "Local conversation cleared."
		_draw_history()
	else:
		settings_status.text = "Could not clear local conversation."
	_update_buttons()

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
		var route := robot_id.to_upper() if proposed_worker == robot_id else robot_id.to_upper() + " → " + proposed_worker.to_upper()
		proposal_text.add_text(route + "\n" + str(pending["tool"]).to_upper() + "\n" + str(pending["payload"]))

func _reject() -> void:
	pending = {}
	status.text = "Action rejected. No file created."
	_draw_history()
	_update_buttons()

func _approve() -> void:
	if online_busy or pending.is_empty():
		return
	var request := pending.duplicate()
	var worker := proposed_worker
	pending = {}
	proposed_worker = ""
	_draw_history()
	_update_buttons()
	if worker.is_empty() or not roster.can_use(robot_id, request["tool"]) or not roster.can_use(worker, request["tool"]):
		status.text = "Permission denied."
		return
	hide()
	proposal_approved.emit(robot_id, request["tool"], request["payload"], worker)

func _update_buttons() -> void:
	settings_button.disabled = online_busy
	personal_mode.disabled = online_busy
	model_editor.editable = not online_busy
	key_editor.editable = not online_busy
	share_context.disabled = online_busy
	test_button.disabled = online_busy or (not personal_mode.button_pressed and Time.get_ticks_msec() < guest_wait_until)
	clear_key_button.disabled = online_busy
	clear_history_button.disabled = online_busy or robot_id.is_empty()
	back_button.disabled = online_busy
	prompt_box.editable = not online_busy
	_update_quota_display()
	cancel_button.visible = online_busy and online_operation == "ask"
	approve_button.disabled = online_busy or pending.is_empty()
	reject_button.disabled = online_busy

func _read_guest_quota(code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var wait := 0
	for header in headers:
		var pair := header.split(":", false, 1)
		if pair.size() != 2:
			continue
		match pair[0].strip_edges().to_lower():
			"x-cubyte-cooldown":
				wait = maxi(wait, clampi(int(pair[1]), 0, 300))
			"x-cubyte-remaining":
				guest_remaining = maxi(0, int(pair[1]))
	if code == 429:
		var data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if data is Dictionary:
			wait = maxi(wait, clampi(int(data.get("retry_after", 1)), 1, 86400))
	guest_wait_until = maxi(guest_wait_until, Time.get_ticks_msec() + wait * 1000)

func _guest_error(code: int, body: PackedByteArray) -> String:
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if code != 429:
		if data is Dictionary:
			match str(data.get("error", "")):
				"AI_REGION_UNAVAILABLE":
					return "Gemini rejected the gateway region. Local tools still work."
				"AI_UPSTREAM_UNAVAILABLE":
					return "Gemini service is temporarily unavailable."
				"GEMINI_UNAVAILABLE":
					return "Gateway could not complete the Gemini request."
				"AI_RATE_OR_QUOTA":
					return "The AI provider is at its limit. Try again later."
				"AI_RESPONSE_BLOCKED":
					return "The AI could not answer this message. Try rephrasing it."
				"AI_NOT_CONFIGURED":
					return "Guest AI is currently offline. Local office tools still work."
		return "Guest AI unavailable. Try again later."
	if data is Dictionary:
		match str(data.get("error", "")):
			"CHAT_COOLDOWN":
				return "Wait before sending another message."
			"CHAT_IN_PROGRESS":
				return "A Cubot is still working on your last message."
			"GLOBAL_RATE_LIMIT":
				return "The office is busy. Try again shortly."
			"DAILY_LIMIT":
				match str(data.get("scope", "")):
					"chat_global":
						return "Office shared daily AI allowance reached."
					"chat_ip":
						return "Daily AI allowance for this network reached."
					"chat_user_attempts":
						return "Your daily AI attempt limit reached."
					"chat_user_messages":
						return "Your daily message allowance reached."
	return "Daily guest AI limit reached."

# Show only a bounded machine-readable error code, never raw provider data.
func _guest_diagnostic(transport: int, code: int, body: PackedByteArray) -> String:
	if transport != HTTPRequest.RESULT_SUCCESS:
		return "Network diagnostic: %d (HTTP %d)" % [transport, code]
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	var reason := ""
	if data is Dictionary:
		reason = str(data.get("error", ""))
	var valid := not reason.is_empty() and reason.length() <= 80
	for ch in reason:
		if not ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_":
			valid = false
			break
	return "HTTP %d · %s" % [code, reason if valid else "NO_ERROR_CODE"]

func _update_quota_display() -> void:
	if not is_instance_valid(quota_label) or not is_instance_valid(test_button):
		return
	var is_guest := not personal_mode.button_pressed
	var seconds := maxi(0, ceili(float(guest_wait_until - Time.get_ticks_msec()) / 1000.0))
	var auth_seconds := maxi(0, ceili(float(auth_wait_until - Time.get_ticks_msec()) / 1000.0)) if not guest.has_session() else 0
	var auth_waiting := is_guest and auth_seconds > 0
	var waiting := is_guest and seconds > 0
	ask_button.disabled = online_busy or waiting or auth_waiting
	test_button.disabled = online_busy or auth_waiting
	if auth_waiting:
		seconds = maxi(seconds, auth_seconds)
		waiting = true
	ask_button.text = ("Wait %ds" % seconds) if waiting and seconds < 120 else ("Wait" if waiting else "Send")
	quota_label.visible = is_guest
	var remaining_text := "Daily messages left: %d" % guest_remaining if guest_remaining >= 0 else "Guest AI · shared daily quota"
	if waiting:
		remaining_text += "  |  Retry in %ds" % seconds if seconds < 120 else "  |  Temporarily limited"
	quota_label.text = remaining_text
	if is_guest:
		test_button.text = "Sign-in wait %ds" % auth_seconds if auth_waiting else "Connect as guest"

func _exit_tree() -> void:
	if online_busy and is_instance_valid(http):
		http.cancel_request()
	request_key = ""
