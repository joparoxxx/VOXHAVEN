extends Window
const Policy = preload("res://core/ai_policy.gd")
const Online = preload("res://core/online_ai.gd")
const LocalAI = preload("res://core/local_ai.gd")
var local_ai = LocalAI.new()
var offline_mode: CheckBox
var download_button: Button
var remove_model_button: Button
var offline_status: Label
var offline_progress: ProgressBar
var local_running := false
var auto_select_local := false
var provider_picker: OptionButton
var model_picker: OptionButton
var fetch_models_button: Button
var fallback_mode: CheckBox
var active_provider := "offline"
var request_provider := ""
var provider_waits := {}
var request_prompt := ""
var session_profiles := {}
var personal_fields: VBoxContainer
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
var include_recent: CheckBox
var session_turns := {}
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
	fields.add_child(UI.label("Choose on-device AI or your own provider. Cloud requests go directly to that provider; your account pays any charges.", 17, UI.MUTED))
	provider_picker = OptionButton.new()
	provider_picker.custom_minimum_size.y = 60
	for name_ in ["Offline AI", "OpenAI", "Google Gemini", "Groq", "OpenRouter", "DeepSeek"]:
		provider_picker.add_item(name_)
	fields.add_child(provider_picker)
	offline_mode = CheckBox.new()
	offline_mode.set_pressed_no_signal(true)
	fields.add_child(offline_mode)
	offline_mode.hide()
	fields.add_child(UI.label("Qwen2.5 0.5B Q4_K_M · 491 MB one-time download. No API key or daily cloud quota. Smaller model; answers may be limited.", 16, UI.MUTED))
	download_button = UI.button("Download & set offline model", _download_local, true)
	fields.add_child(download_button)
	remove_model_button = UI.button("Delete downloaded model", _remove_local)
	fields.add_child(remove_model_button)
	offline_progress = ProgressBar.new()
	offline_progress.max_value = 100
	fields.add_child(offline_progress)
	offline_progress.hide()
	offline_status = UI.label("", 16, UI.MUTED)
	fields.add_child(offline_status)
	add_child(local_ai)
	local_ai.changed.connect(_local_changed)
	local_ai.completed.connect(_local_completed)
	offline_mode.set_pressed_no_signal(true)
	offline_status.text = "Model installed." if local_ai.installed() else ("Model not downloaded." if local_ai.available() else "Native runtime missing in this build.")
	personal_fields = VBoxContainer.new()
	fields.add_child(personal_fields)
	personal_fields.add_child(UI.label("Model ID", 17))
	model_editor = LineEdit.new()
	model_editor.custom_minimum_size.y = 60
	model_editor.placeholder_text = "Enter model ID manually"
	model_editor.max_length = 200
	personal_fields.add_child(model_editor)
	fetch_models_button = UI.button("Fetch available models", _fetch_models)
	personal_fields.add_child(fetch_models_button)
	model_picker = OptionButton.new()
	model_picker.custom_minimum_size.y = 60
	model_picker.add_item("Select a fetched model")
	personal_fields.add_child(model_picker)
	model_picker.item_selected.connect(_select_model)
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
	provider_picker.item_selected.connect(_provider_changed)
	personal_fields.hide()
	clear_key_button.hide()
	test_button.text = "Check offline model"
	fallback_mode = CheckBox.new()
	fallback_mode.text = "Use installed offline AI if cloud fails"
	fallback_mode.custom_minimum_size.y = 60
	fields.add_child(fallback_mode)
	fallback_mode.hide()
	include_recent = CheckBox.new()
	include_recent.text = "Continue recent conversation"
	include_recent.button_pressed = true
	include_recent.custom_minimum_size.y = 60
	fields.add_child(include_recent)
	fields.add_child(UI.label("Cloud chat includes up to 3 recent exchanges from this session with the same Cubot and provider. Turn this off for independent messages. Saved history and private notes are optional below.", 16, UI.MUTED))
	share_context = CheckBox.new()
	share_context.custom_minimum_size.y = 60
	share_context.text = "Share saved history, notes and skills"
	fields.add_child(share_context)
	fields.add_child(UI.label("Allows sending this Cubot’s memory, skills and recent chat to the selected AI provider.", 16, UI.MUTED))
	fields.add_child(UI.label("API keys remain in memory for this app session only. Use a restricted personal key; do not enter a shared production key. Cloud providers may charge or retain submitted content. Model tests can consume quota. Extra context is optional.", 16, UI.MUTED))
	connection = UI.label("Not tested", 18)
	fields.add_child(connection)
	fields.add_child(UI.label("Chat history is saved locally on this device (last 12 exchanges per Cubot). Enable sharing saved history only if you want to send previous sessions and private notes to the AI provider. Avoid entering sensitive information.", 16, UI.MUTED))
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
	http.body_size_limit = Online.MAX_BODY
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

func _provider_changed(index: int) -> void:
	if online_busy or local_ai.busy:
		return
	if active_provider != "offline":
		session_profiles[active_provider] = {"key": key_editor.text, "model": model_editor.text}
	active_provider = "offline" if index == 0 else Online.PROVIDERS[index - 1]
	var local := active_provider == "offline"
	offline_mode.set_pressed_no_signal(local)
	var saved: Dictionary = session_profiles.get(active_provider, {})
	key_editor.text = str(saved.get("key", ""))
	model_editor.text = str(saved.get("model", ""))
	model_picker.clear()
	model_picker.add_item("Select a fetched model")
	personal_fields.visible = not local
	clear_key_button.visible = not local
	fallback_mode.visible = not local
	_credentials_changed("")
	settings_status.text = "Download the model or select a cloud provider." if local else "Enter your personal key and model."

func _fetch_models() -> void:
	if online_busy or local_ai.busy or active_provider == "offline":
		return
	var req: Dictionary = Online.models_request(active_provider, key_editor.text)
	if req.is_empty():
		settings_status.text = "Enter a valid provider API key."
		return
	request_provider = active_provider
	request_key = key_editor.text.strip_edges()
	online_operation = "models"
	online_busy = true
	var err := http.request(req["url"], req["headers"], HTTPClient.METHOD_GET)
	if err != OK:
		online_busy = false
		online_operation = ""
		request_key = ""
		settings_status.text = "Could not request model list."
	else:
		settings_status.text = "Fetching available models…"
	_update_buttons()

func _select_model(index: int) -> void:
	if index > 0:
		model_editor.text = model_picker.get_item_text(index)
		_credentials_changed("")

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
	session_profiles.erase(active_provider)
	for id in ["atlas", "pixel", "mesh"]:
		session_turns.erase(active_provider + ":" + id)
	_credentials_changed("")
	settings_status.text = "Key cleared."

func _session_id() -> String:
	return active_provider + ":" + robot_id

func _recent_history() -> Array:
	if share_context.button_pressed or active_provider == "offline":
		return Online.conversation_turns(histories.get(robot_id, []))
	if include_recent.button_pressed:
		return Online.conversation_turns(session_turns.get(_session_id(), []))
	return []

func _ask() -> void:
	if online_busy or local_ai.busy or robot_id.is_empty() or _provider_wait() > 0:

		return
	if not pending.is_empty():
		status.text = "Review the proposed action using Approve & run or Reject first."
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
	if share_context.button_pressed or offline_mode.button_pressed:
		var binding: Dictionary = skills.get_binding(robot_id)
		var skill_doc := ""
		if not binding.is_empty():
			var skill: Dictionary = skills.get_skill(binding["skill"])
			skill_doc = str(skill.get("markdown", "")).left(1000)
		var recent: Array = histories.get(robot_id, [])
		context = {"personality": profile.get("personality"), "memory": str(profile.get("memory", "")).left(1000), "skill": skill_doc}
		if offline_mode.button_pressed:
			context = {"personality": str(profile.get("personality", "")).left(128), "memory": str(profile.get("memory", "")).left(250)}
			if not recent.is_empty():
				context["last_user"] = str(recent[-1].get("user", "")).left(200)
				context["last_reply"] = str(recent[-1].get("assistant", "")).left(200)
	var system := Identity.system_prompt(robot_id, permitted, context)
	if system.is_empty():
		status.text = "Unknown Cubot."
		return
	_send_online("ask", system, question)

func _test_connection() -> void:
	_send_online("test", "Reply with a short confirmation.", "Reply OK.")

func _send_online(kind: String, system: String, prompt: String) -> void:
	if online_busy or local_ai.busy:
		return
	if offline_mode.button_pressed:
		if kind == "test":
			connection.text = "Offline model installed" if local_ai.installed() else "Download the local model first"
			return
		pending = {}
		if local_ai.generate(system, prompt):
			local_running = true
			online_busy = true
			online_operation = "ask"
			status.text = "Running on-device AI…"
			_draw_history()
			_update_buttons()
		else:
			status.text = "Offline model unavailable. Check AI settings."
		return
	if _provider_wait() > 0:
		return
	var req: Dictionary = Online.make_request(active_provider, model_editor.text, key_editor.text, system, prompt, _recent_history() if kind == "ask" else [])
	if req.is_empty():
		status.text = "Enter a valid provider model ID and API key in AI settings."
		settings_status.text = status.text
		return
	pending = {}
	online_operation = kind
	request_provider = active_provider
	request_prompt = prompt
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
		status.text = robot_id.to_upper() + " is thinking..." if kind == "ask" else "Testing provider..."
		settings_status.text = status.text
	_draw_history()
	_update_buttons()

func _cancel() -> void:
	if local_running:
		local_ai.cancel()
		status.text = "Stopping local inference…"
		return
	if online_busy:
		http.cancel_request()
		online_busy = false
		online_operation = ""
		request_key = ""
		status.text = "Cancelled. The provider may still count this request."
		_draw_history()
		_update_buttons()

func _provider_wait() -> int:
	if active_provider == "offline":
		return 0
	return maxi(0, ceili(float(int(provider_waits.get(active_provider, 0)) - Time.get_ticks_msec()) / 1000.0))

func _online_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if not online_busy or local_running:
		return
	online_busy = false
	var kind := online_operation
	online_operation = ""
	var raw := body.get_string_from_utf8()
	if code == 429:
		var seconds := 30
		for header in headers:
			var pair := header.split(":", false, 1)
			if pair.size() == 2 and pair[0].to_lower() == "retry-after":
				seconds = clampi(int(pair[1]), 1, 86400) if pair[1].strip_edges().is_valid_int() else 30
		provider_waits[request_provider] = Time.get_ticks_msec() + seconds * 1000
	if kind == "models":
		var models: Dictionary = Online.parse_models(request_provider, result, code, raw)
		if models.get("ok", false):
			model_picker.clear()
			model_picker.add_item("Select a fetched model")
			for id in models.get("models", []):
				if not str(id).contains(request_key):
					model_picker.add_item(str(id))
			settings_status.text = "Found %d models. Select a text chat model or enter an ID." % (model_picker.item_count - 1)
		else:
			settings_status.text = str(models.get("error", "Model discovery failed."))
		request_key = ""
		_update_buttons()
		return
	var parsed: Dictionary = Online.parse_response(result, code, raw, request_provider)
	if parsed.get("ok", false) and str(parsed.get("text", "")).contains(request_key):
		parsed = {"ok": false, "error": "Response rejected: contained credential."}
	request_key = ""
	if parsed.get("ok", false):
		verified = true
		connection.text = "Connected: " + request_provider
		if kind == "test":
			settings_status.text = "Provider returned a valid response."
		else:
			var saved := _accept_response(str(parsed["text"]))
			prompt_box.clear()
			status.text = "Response received." if pending.is_empty() else "Approve or reject the proposed action."
			if not saved:
				status.text += " Local history could not be saved."
	else:
		verified = false
		connection.text = "Not verified"
		status.text = str(parsed.get("error", "Provider failed."))
		settings_status.text = status.text
		if kind == "ask" and fallback_mode.button_pressed and local_ai.available() and local_ai.installed() and (result != HTTPRequest.RESULT_SUCCESS or code in [429, 500, 502, 503, 504]):
			# No extra cloud call and no automatic switch to a paid provider.
			if local_ai.generate(Identity.system_prompt(robot_id, [], {}), request_prompt):
				local_running = true
				online_busy = true
				online_operation = "ask"
				status.text = "Cloud unavailable; using your opted-in local fallback…"
	_draw_history()
	_update_buttons()

func _accept_response(response: String) -> bool:
	pending = Policy.proposal(response)
	proposed_worker = ""
	var visible_reply := response
	if not pending.is_empty():
		if roster.can_use(robot_id, pending["tool"]):
			proposed_worker = roster.delegate(pending["tool"]) if robot_id == "atlas" else robot_id
		if proposed_worker.is_empty():
			pending = {}
			visible_reply = "This action is not permitted."
		else:
			visible_reply = "A local file action is proposed. Review it below before approving."
			if pending["tool"] == "png":
				visible_reply = "I can create a fixed sample PNG, not a custom AI-generated image. Review the sample action below."
	var entry := {"user": question.left(2048), "assistant": visible_reply.left(4096)}
	var turns: Array = histories.get(robot_id, [])
	turns.append(entry)
	while turns.size() > 12:
		turns.pop_front()
	histories[robot_id] = turns
	var session: Array = session_turns.get(_session_id(), [])
	session.append(entry.duplicate())
	while session.size() > 3:
		session.pop_front()
	session_turns[_session_id()] = session
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
		for provider in ["offline"] + Online.PROVIDERS:
			session_turns.erase(provider + ":" + robot_id)
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
	provider_picker.disabled = online_busy or local_ai.busy
	model_editor.editable = not online_busy
	key_editor.editable = not online_busy
	share_context.disabled = online_busy
	include_recent.disabled = online_busy
	fallback_mode.disabled = online_busy or local_ai.busy
	clear_key_button.disabled = online_busy
	clear_history_button.disabled = online_busy or robot_id.is_empty()
	back_button.disabled = online_busy
	prompt_box.editable = not online_busy
	cancel_button.visible = online_busy and online_operation == "ask"
	approve_button.disabled = online_busy or pending.is_empty()
	reject_button.disabled = online_busy
	_update_quota_display()

func _update_quota_display() -> void:
	if not is_instance_valid(test_button) or not is_instance_valid(offline_progress):
		return
	var local := active_provider == "offline"
	var wait := _provider_wait()
	ask_button.disabled = online_busy or local_ai.busy or wait > 0 or not pending.is_empty()
	test_button.disabled = online_busy or local_ai.busy or wait > 0
	fetch_models_button.disabled = online_busy or local_ai.busy or wait > 0
	model_picker.disabled = online_busy or local_ai.busy
	ask_button.text = "Wait %ds" % wait if wait > 0 else "Send"
	test_button.text = "Check offline model" if local else "Test connection"
	quota_label.visible = true
	quota_label.text = "Offline · no cloud quota" if local else ("Personal " + active_provider + " · provider billing and limits")
	download_button.disabled = online_busy or (local_ai.busy and not local_ai.downloading) or not local_ai.available() or local_ai.installed()
	download_button.text = "Cancel download" if local_ai.downloading else ("Model installed" if local_ai.installed() else "Download & set offline model")
	remove_model_button.disabled = online_busy or local_ai.busy or not local_ai.installed()
	offline_progress.visible = local_ai.downloading
	if local_ai.downloading:
		offline_progress.value = local_ai.progress() * 100.0

func _download_local() -> void:
	if local_ai.downloading:
		auto_select_local = false
		local_ai.cancel()
		return
	auto_select_local = true
	local_ai.start_download()

func _remove_local() -> void:
	local_ai.remove_model()
	_update_buttons()

func _local_changed(message: String) -> void:
	offline_status.text = message
	if auto_select_local and not local_ai.busy and local_ai.installed():
		auto_select_local = false
		provider_picker.select(0)
		_provider_changed(0)
	_update_buttons()

func _local_completed(result: Dictionary) -> void:
	local_running = false
	online_busy = false
	online_operation = ""
	var reply := str(result.get("text", ""))
	if result.get("ok", false) and not reply.strip_edges().is_empty():
		var saved := _accept_response(reply)
		prompt_box.clear()
		status.text = "Offline response received." if pending.is_empty() else "Approve or reject the proposed action."
		if not saved:
			status.text += " Local history could not be saved."
	else:
		status.text = "Offline AI: " + str(result.get("error", "No response"))
	_draw_history()
	_update_buttons()

func _exit_tree() -> void:
	if online_busy and is_instance_valid(http):
		http.cancel_request()
	request_key = ""

# Team chat borrows only the explicitly configured Gemini session credentials.
func team_credentials() -> Dictionary:
	if online_busy or local_ai.busy:
		return {}
	if active_provider == "gemini":
		return {"key": key_editor.text.strip_edges(), "model": model_editor.text.strip_edges()}
	var saved: Dictionary = session_profiles.get("gemini", {})
	return {"key": str(saved.get("key", "")).strip_edges(), "model": str(saved.get("model", "")).strip_edges()}
