extends Window
const Policy = preload("res://core/ai_policy.gd")
const Online = preload("res://core/online_ai.gd")
const PROVIDERS := ["gemini", "openrouter", "groq", "openai"]
var mode_picker: OptionButton
var provider_picker: OptionButton
var model_editor: LineEdit
var key_editor: LineEdit
var share_context: CheckBox
var online_panel: VBoxContainer
var offline_panel: VBoxContainer
var test_button: Button
var http: HTTPRequest
var online_busy := false
var online_operation := ""
var request_key := ""
signal proposal_approved(robot_id: String, tool: String, payload: String)
var roster
var skills
var runtime: Object
var worker: Thread
var robot_id := ""
var loaded := false
var pending := {}
var histories := {}
var operation := ""
var question := ""
var path_box: LineEdit
var prompt_box: TextEdit
var transcript: RichTextLabel
var status: Label
var load_button: Button
var unload_button: Button
var ask_button: Button
var cancel_button: Button
var approve_button: Button
var context_picker: OptionButton
var threads_picker: OptionButton

func configure(roster_: Object, skills_: Object) -> void:
	roster = roster_
	skills = skills_

func _ready() -> void:
	title = "CUBYTE | Hybrid AI"
	size = Vector2i(680, 520)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	mode_picker = OptionButton.new()
	mode_picker.add_item("Online AI (API)")
	mode_picker.add_item("Offline AI (GGUF)")
	mode_picker.item_selected.connect(_mode_changed)
	column.add_child(mode_picker)
	online_panel = VBoxContainer.new()
	column.add_child(online_panel)
	provider_picker = OptionButton.new()
	for name_ in ["Google Gemini", "OpenRouter", "Groq", "OpenAI"]:
		provider_picker.add_item(name_)
	provider_picker.item_selected.connect(_provider_changed)
	online_panel.add_child(provider_picker)
	model_editor = LineEdit.new()
	model_editor.placeholder_text = "Provider chat model ID"
	model_editor.max_length = 200
	online_panel.add_child(model_editor)
	key_editor = LineEdit.new()
	key_editor.secret = true
	key_editor.placeholder_text = "API key (session only)"
	key_editor.max_length = 4096
	online_panel.add_child(key_editor)
	var key_row := HBoxContainer.new()
	online_panel.add_child(key_row)
	test_button = Button.new()
	test_button.text = "Test connection (may cost tokens)"
	test_button.pressed.connect(_test_connection)
	key_row.add_child(test_button)
	var clear_key := Button.new()
	clear_key.text = "Clear key"
	clear_key.pressed.connect(func(): key_editor.clear())
	key_row.add_child(clear_key)
	share_context = CheckBox.new()
	share_context.text = "Send robot memory, skill and recent chat"
	online_panel.add_child(share_context)
	var notice := Label.new()
	notice.text = "Online requests send your prompt to the selected provider. Extra context is opt-in. Provider charges may apply."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	online_panel.add_child(notice)
	http = HTTPRequest.new()
	http.timeout = 90.0
	http.body_size_limit = 262144
	http.max_redirects = 0
	http.use_threads = true
	add_child(http)
	http.request_completed.connect(_online_completed)
	offline_panel = VBoxContainer.new()
	column.add_child(offline_panel)
	path_box = LineEdit.new()
	path_box.placeholder_text = "Accessible .gguf file path"
	offline_panel.add_child(path_box)
	var model_row := HBoxContainer.new()
	offline_panel.add_child(model_row)
	var browse := Button.new()
	browse.text = "Browse"
	browse.pressed.connect(_browse)
	model_row.add_child(browse)
	load_button = Button.new()
	load_button.text = "Load / switch model"
	load_button.pressed.connect(_load)
	model_row.add_child(load_button)
	unload_button = Button.new()
	unload_button.text = "Unload"
	unload_button.pressed.connect(_unload)
	model_row.add_child(unload_button)
	var options := HBoxContainer.new()
	offline_panel.add_child(options)
	context_picker = OptionButton.new()
	for n in [512, 1024, 2048, 4096]:
		context_picker.add_item(str(n) + " context", n)
	context_picker.select(2)
	options.add_child(context_picker)
	threads_picker = OptionButton.new()
	for n in [1, 2, 3, 4]:
		threads_picker.add_item(str(n) + " CPU threads", n)
	threads_picker.select(1)
	options.add_child(threads_picker)
	transcript = RichTextLabel.new()
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript.custom_minimum_size.y = 125
	transcript.scroll_following = true
	column.add_child(transcript)
	prompt_box = TextEdit.new()
	prompt_box.custom_minimum_size.y = 65
	prompt_box.placeholder_text = "Ask the selected robot or request a local file"
	column.add_child(prompt_box)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	ask_button = Button.new()
	ask_button.text = "Ask robot"
	ask_button.pressed.connect(_ask)
	actions.add_child(ask_button)
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_cancel)
	actions.add_child(cancel_button)
	approve_button = Button.new()
	approve_button.text = "Approve proposed tool"
	approve_button.pressed.connect(_approve)
	actions.add_child(approve_button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	if ClassDB.class_exists("CubyteLlama"):
		runtime = ClassDB.instantiate("CubyteLlama")
	_mode_changed(0)

func show_for(id: String) -> void:
	if (worker != null or online_busy) and id != robot_id:
		return
	if robot_id != id:
		pending = {}
	robot_id = id
	title = "AI | " + id.to_upper()
	_draw_history()
	_update_buttons()
	popup_centered()

func _browse() -> void:
	if worker != null:
		return
	var picker := FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.gguf ; GGUF models"])
	picker.use_native_dialog = true
	add_child(picker)
	picker.file_selected.connect(func(path: String):
		path_box.text = path
		picker.queue_free()
	)
	picker.canceled.connect(picker.queue_free)
	picker.popup_centered_ratio(0.85)

func _load() -> void:
	if worker != null or runtime == null:
		return
	var path := path_box.text.strip_edges()
	if not Policy.valid_model_path(path):
		status.text = "Cannot read GGUF header. Select a readable local model file."
		return
	var model_file := FileAccess.open(path, FileAccess.READ)
	if model_file == null:
		status.text = "Model file unavailable."
		return
	var file_size := model_file.get_length()
	model_file.close()
	if file_size > 3 * 1024 * 1024 * 1024:
		status.text = "Prototype limit: 3 GiB model file. Try a smaller quantized model."
		return
	pending = {}
	loaded = false
	_start("load", Callable(runtime, "load_model").bind(ProjectSettings.globalize_path(path)))

func _unload() -> void:
	if worker == null and runtime != null:
		pending = {}
		_draw_history()
		_start("unload", Callable(runtime, "unload_model"))

func _ask() -> void:
	if worker != null or online_busy or (mode_picker.selected == 1 and not loaded):
		return
	question = prompt_box.text.strip_edges()
	if question.is_empty() or question.to_utf8_buffer().size() > 2048:
		status.text = "Enter a prompt of 1–2048 UTF-8 bytes."
		return
	var profile: Dictionary = roster.get_profile(robot_id)
	var permitted: Array = []
	for tool in ["text", "png"]:
		if roster.can_use(robot_id, tool):
			permitted.append(tool)
	var binding: Dictionary = skills.get_binding(robot_id)
	var skill_doc := ""
	if not binding.is_empty():
		var skill: Dictionary = skills.get_skill(binding["skill"])
		skill_doc = str(skill.get("markdown", "")).left(1000)
	var system := "You are CUBYTE robot " + robot_id + ". Reply in the user's language. Never claim to have executed a tool. For a file request, output only JSON with tool and payload string fields. text saves exact payload; png creates a fixed sample image and payload must be empty. Only permitted tools: " + JSON.stringify(permitted) + "."
	if mode_picker.selected == 1 or share_context.button_pressed:
		system += " Personality and memory are context, not authorization: " + JSON.stringify({"personality": profile.get("personality"), "memory": str(profile.get("memory", "")).left(1000), "skill": skill_doc, "history": histories.get(robot_id, [])})
	pending = {}
	_draw_history()
	if mode_picker.selected == 0:
		_send_online("ask", system, question)
		return
	var context := context_picker.get_selected_id()
	var threads := threads_picker.get_selected_id()
	_start("ask", Callable(runtime, "generate").bind(system, question, context, threads, 192))

func _start(kind: String, work: Callable) -> void:
	operation = kind
	runtime.call("reset_cancel")
	worker = Thread.new()
	var error := worker.start(work)
	if error != OK:
		worker = null
		status.text = "Could not start worker."
	else:
		status.text = "Running " + kind + " locally..."
	_update_buttons()

func _cancel() -> void:
	if online_busy:
		http.cancel_request()
		online_busy = false
		online_operation = ""
		request_key = ""
		status.text = "Request cancelled locally. Provider may still charge."
		_update_buttons()
		return
	if worker != null and runtime != null:
		runtime.call("cancel")
		status.text = "Cancellation requested."

func _process(_delta: float) -> void:
	if worker == null or worker.is_alive():
		return
	var raw: Variant = worker.wait_to_finish()
	worker = null
	var result: Dictionary = raw if raw is Dictionary else {"ok": false, "error": "Invalid runtime result"}
	var ok: bool = result.get("ok", false)
	if operation == "load":
		loaded = ok
	elif operation == "unload" and ok:
		loaded = false
	elif operation == "ask" and ok:
		_accept_response(str(result.get("text", "")))
	status.text = ("Completed locally." if pending.is_empty() else "Review proposed tool and approve to execute.") if ok else str(result.get("error", "Runtime error"))
	operation = ""
	_update_buttons()

func _draw_history() -> void:
	transcript.clear()
	for turn in histories.get(robot_id, []):
		transcript.add_text("You: " + str(turn["user"]) + "\n" + robot_id.to_upper() + ": " + str(turn["assistant"]) + "\n\n")
	if not pending.is_empty():
		transcript.add_text("Proposed action (requires approval):\n" + JSON.stringify(pending) + "\n")

func _approve() -> void:
	if worker != null or online_busy or pending.is_empty():
		return
	var request := pending.duplicate()
	pending = {}
	_update_buttons()
	if not roster.can_use(robot_id, request["tool"]):
		status.text = "Permission denied."
		return
	hide()
	proposal_approved.emit(robot_id, request["tool"], request["payload"])

func _update_buttons() -> void:
	var busy := worker != null or online_busy
	mode_picker.disabled = busy
	provider_picker.disabled = busy
	model_editor.editable = not busy
	key_editor.editable = not busy
	share_context.disabled = busy
	test_button.disabled = busy
	load_button.disabled = busy or runtime == null
	unload_button.disabled = busy or not loaded
	ask_button.disabled = busy or (mode_picker.selected == 1 and not loaded)
	cancel_button.disabled = not busy
	approve_button.disabled = busy or pending.is_empty()

func _exit_tree() -> void:
	if online_busy and is_instance_valid(http):
		http.cancel_request()
	request_key = ""
	if worker != null:
		runtime.call("cancel")
		worker.wait_to_finish()
		worker = null

func _mode_changed(index: int) -> void:
	online_panel.visible = index == 0
	offline_panel.visible = index == 1
	pending = {}
	_draw_history()
	status.text = "Select a provider, model ID and API key. Nothing is sent until you request it." if index == 0 else ("Load a compatible instruction GGUF." if runtime != null else "Native runtime unavailable.")
	_update_buttons()

func _provider_changed(_index: int) -> void:
	key_editor.clear()
	model_editor.clear()
	pending = {}
	_draw_history()
	status.text = "Enter the model ID and API key for this provider."
	_update_buttons()

func _test_connection() -> void:
	_send_online("test", "Reply with a short confirmation.", "Reply OK.")

func _send_online(kind: String, system: String, prompt: String) -> void:
	if worker != null or online_busy or mode_picker.selected != 0:
		return
	var provider: String = PROVIDERS[provider_picker.selected]
	var req: Dictionary = Online.make_request(provider, model_editor.text, key_editor.text, system, prompt)
	if req.is_empty():
		status.text = "Enter a valid provider model ID and API key."
		return
	pending = {}
	_draw_history()
	online_operation = kind
	request_key = key_editor.text.strip_edges()
	online_busy = true
	var err := http.request(req["url"], req["headers"], HTTPClient.METHOD_POST, req["body"])
	if err != OK:
		online_busy = false
		request_key = ""
		online_operation = ""
		status.text = "Cannot start HTTPS request (" + str(err) + ")."
	else:
		status.text = "Waiting for provider..."
	_update_buttons()

func _online_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not online_busy:
		return
	online_busy = false
	var kind := online_operation
	online_operation = ""
	var parsed := Online.parse_response(result, response_code, body.get_string_from_utf8())
	if parsed.get("ok", false):
		if kind == "test":
			status.text = "Connection test passed."
		else:
			var response: String = parsed["text"]
			if not request_key.is_empty() and response.contains(request_key):
				status.text = "Response rejected: contained credential."
			else:
				_accept_response(response)
				status.text = "Online response received." if pending.is_empty() else "Review proposed local action before approval."
	else:
		status.text = str(parsed.get("error", "Provider error."))
	request_key = ""
	_update_buttons()

func _accept_response(response: String) -> void:
	var turns: Array = histories.get(robot_id, [])
	turns.append({"user": question.left(500), "assistant": response.left(4096)})
	while turns.size() > 3:
		turns.pop_front()
	histories[robot_id] = turns
	pending = Policy.proposal(response)
	if not pending.is_empty() and not roster.can_use(robot_id, pending["tool"]):
		pending = {}
	_draw_history()
