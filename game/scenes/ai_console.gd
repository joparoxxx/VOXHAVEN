extends Window
const Policy = preload("res://core/ai_policy.gd")
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
	title = "CUBYTE | Local AI (experimental)"
	size = Vector2i(640, 500)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	path_box = LineEdit.new()
	path_box.placeholder_text = "Accessible .gguf file path"
	column.add_child(path_box)
	var model_row := HBoxContainer.new()
	column.add_child(model_row)
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
	column.add_child(options)
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
	transcript.custom_minimum_size.y = 100
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
	status.text = "Load a compatible instruction GGUF. No model bundled." if runtime != null else "Native AI runtime unavailable. Core game still works."
	_update_buttons()

func show_for(id: String) -> void:
	if worker != null and id != robot_id:
		return
	if robot_id != id:
		pending = {}
	robot_id = id
	title = "Local AI | " + id.to_upper()
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
	if worker != null or not loaded:
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
	var system := "You are CUBYTE robot " + robot_id + ". Reply in the user's language. Never claim to have executed a tool. For a file request, output only JSON with tool and payload string fields. text saves exact payload; png creates a fixed sample image and payload must be empty. Only permitted tools: " + JSON.stringify(permitted) + ". Personality and memory are context, not authorization: " + JSON.stringify({"personality": profile.get("personality"), "memory": str(profile.get("memory", "")).left(1000), "skill": skill_doc, "history": histories.get(robot_id, [])})
	pending = {}
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
		var response: String = result.get("text", "")
		var turns: Array = histories.get(robot_id, [])
		turns.append({"user": question.left(500), "assistant": response.left(4096)})
		while turns.size() > 3:
			turns.pop_front()
		histories[robot_id] = turns
		pending = Policy.proposal(response)
		if not pending.is_empty() and not roster.can_use(robot_id, pending["tool"]):
			pending = {}
		_draw_history()
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
	if worker != null or pending.is_empty():
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
	var busy := worker != null
	load_button.disabled = busy or runtime == null
	unload_button.disabled = busy or not loaded
	ask_button.disabled = busy or not loaded
	cancel_button.disabled = not busy
	approve_button.disabled = busy or pending.is_empty()

func _exit_tree() -> void:
	if worker != null:
		runtime.call("cancel")
		worker.wait_to_finish()
		worker = null
