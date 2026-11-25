extends Node3D
const TaskEngine = preload("res://core/task_engine.gd")
const Skills = preload("res://core/skill_registry.gd")
const Roster = preload("res://core/robot_roster.gd")
var roster = Roster.new()
var robot_dialog: Window
var memory_editor: TextEdit
var personality_editor: LineEdit
var allow_text: CheckBox
var allow_png: CheckBox
var profile_label: Label
var history_label: RichTextLabel
var manager_tool: OptionButton
var robot_dialog_status: Label
var profile_button: Button
var skills = Skills.new()
var skill_dialog: Window
var skill_source: TextEdit
var skill_picker: OptionButton
var tool_picker: OptionButton
var skill_status: Label
var skill_summary: Label
var skill_button: Button
const ROBOT_IDS := ["atlas", "pixel", "mesh"]
const ROBOT_COLORS := [Color("#d7b56d"), Color("#a48bdf"), Color("#62a9d9")]
var engine = TaskEngine.new()
var robots: Array[Node3D] = []
var wheels: Array[MeshInstance3D] = []
var selected := 0
var status: Label
var input: LineEdit
var preview: TextureRect
var selection: OptionButton
var run_text: Button
var run_png: Button
var cancel_button: Button
var pending_id := ""
var busy := false
var progress_timer := 0.0

func _ready() -> void:
	engine.set_permission_checker(Callable(roster, "can_use"))
	_build_office()
	_build_ui()
	engine.task_changed.connect(_on_task_changed)
	if not engine.is_ready() or not roster.is_ready():
		status.text = "Local storage unavailable. Tasks disabled."
		run_text.disabled = true
		run_png.disabled = true

func _box(parent: Node3D, size: Vector3, position_: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position_
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	node.material_override = mat
	parent.add_child(node)
	return node

func _build_office() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#25313c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.2
	add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(8, 9, 12)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13
	add_child(camera)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	_box(self, Vector3(10, 0.15, 8), Vector3(0, -0.075, 0), Color("#727b85"))
	_box(self, Vector3(10, 2, 0.15), Vector3(0, 1, -4), Color("#aab3bd"))
	_box(self, Vector3(0.15, 2, 8), Vector3(-5, 1, 0), Color("#909ba6"))
	for i in range(3):
		var x := float(i - 1) * 2.7
		_box(self, Vector3(1.8, 0.9, 0.85), Vector3(x, 0.45, -2.6), Color("#b8bec7"))
		_box(self, Vector3(0.85, 0.55, 0.12), Vector3(x, 1.22, -2.75), Color("#263749"))
		_build_robot(Vector3(x, 0, 0.5), ROBOT_COLORS[i])
	_box(self, Vector3(1.8, 0.15, 1.3), Vector3(3.5, 0.08, 2.4), Color("#4a6b72"))

func _build_robot(position_: Vector3, color: Color) -> void:
	var robot := Node3D.new()
	add_child(robot)
	robot.position = position_
	robots.append(robot)
	var roller := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.23
	sphere.height = 0.46
	roller.mesh = sphere
	roller.position.y = 0.23
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#20252e")
	roller.material_override = mat
	robot.add_child(roller)
	wheels.append(roller)
	_box(robot, Vector3(0.82, 0.82, 0.82), Vector3(0, 0.79, 0), color)
	_box(robot, Vector3(0.65, 0.56, 0.04), Vector3(0, 0.82, 0.43), Color("#101b29"))
	for side in [-1, 1]:
		_box(robot, Vector3(0.10, 0.17, 0.035), Vector3(side * 0.15, 0.88, 0.46), Color("#83f5df"))
		_box(robot, Vector3(0.18, 0.13, 0.14), Vector3(side * 0.49, 0.84, 0), Color("#b9c5d0"))
		_box(robot, Vector3(0.13, 0.37, 0.13), Vector3(side * 0.59, 0.67, 0), Color("#7b8b9d"))
		_box(robot, Vector3(0.19, 0.13, 0.18), Vector3(side * 0.59, 0.48, 0.04), color)
	_box(robot, Vector3(0.16, 0.045, 0.035), Vector3(0, 0.69, 0.46), Color("#83f5df"))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(280, 0)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "CUBYTE | Robot system v0.2"
	column.add_child(title)
	selection = OptionButton.new()
	for id in ROBOT_IDS:
		selection.add_item(id.to_upper())
	selection.item_selected.connect(func(index: int):
		selected = index
		_refresh_binding()
	)
	column.add_child(selection)
	input = LineEdit.new()
	input.placeholder_text = "Text to save"
	input.text = "Hello from CUBYTE"
	input.max_length = 2048
	column.add_child(input)
	run_text = Button.new()
	run_text.text = "Create real TXT"
	run_text.pressed.connect(func(): _queue("text", input.text))
	column.add_child(run_text)
	run_png = Button.new()
	run_png.text = "Create real PNG"
	run_png.pressed.connect(func(): _queue("png", ""))
	column.add_child(run_png)
	cancel_button = Button.new()
	cancel_button.text = "Cancel queued task"
	cancel_button.disabled = true
	cancel_button.pressed.connect(_cancel)
	column.add_child(cancel_button)
	status = Label.new()
	status.custom_minimum_size.x = 260
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Offline | No AI model required"
	column.add_child(status)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(96, 96)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(preview)
	skill_summary = Label.new()
	skill_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(skill_summary)
	skill_button = Button.new()
	skill_button.text = "Skills / equip"
	skill_button.pressed.connect(_show_skills)
	column.add_child(skill_button)
	var use_skill := Button.new()
	use_skill.text = "Run equipped skill"
	use_skill.pressed.connect(_run_skill)
	column.add_child(use_skill)
	profile_button = Button.new()
	profile_button.text = "Robot profile / Manager"
	profile_button.pressed.connect(_show_robot_profile)
	column.add_child(profile_button)
	_build_skill_dialog()
	_build_robot_dialog()
	_refresh_binding()

func _queue(tool: String, payload: String) -> void:
	if busy:
		return
	pending_id = engine.enqueue(ROBOT_IDS[selected], tool, payload)
	if pending_id.is_empty():
		status.text = "Task rejected: permission, input or storage error."
		return
	busy = true
	progress_timer = 0.0
	selection.disabled = true
	skill_button.disabled = true
	profile_button.disabled = true
	run_text.disabled = true
	run_png.disabled = true
	cancel_button.disabled = false
	preview.texture = null

func _cancel() -> void:
	if busy and engine.cancel(pending_id):
		_reset()

func _reset() -> void:
	busy = false
	selection.disabled = false
	skill_button.disabled = false
	profile_button.disabled = false
	run_text.disabled = not engine.is_ready() or not roster.can_use(ROBOT_IDS[selected], "text")
	run_png.disabled = not engine.is_ready() or not roster.can_use(ROBOT_IDS[selected], "png")
	cancel_button.disabled = true

func _process(delta: float) -> void:
	if not busy:
		return
	var robot := robots[selected]
	if robot.position.z > -1.2:
		robot.position.z = move_toward(robot.position.z, -1.2, delta * 3.0)
		wheels[selected].rotate_x(-delta * 8.0)
		return
	progress_timer += delta
	if progress_timer >= 0.15:
		cancel_button.disabled = true
		var current := pending_id
		# The visual delay is a robot walk-up; execution itself is real.
		while engine.get_task(current).get("status") == "queued":
			if not engine.run_next():
				break
		_reset()

func _on_task_changed(task: Dictionary) -> void:
	status.text = str(task["robot_id"]).to_upper() + ": " + str(task["status"])
	if task["status"] == "succeeded":
		status.text += "\n" + str(task["artifact"])
		if task["tool"] == "png":
			var image := Image.new()
			if image.load(task["artifact"]) == OK:
				preview.texture = ImageTexture.create_from_image(image)
	elif not str(task.get("error", "")).is_empty():
		status.text += "\n" + str(task["error"])

func _build_skill_dialog() -> void:
	skill_dialog = Window.new()
	skill_dialog.title = "Local Skill Library"
	skill_dialog.size = Vector2i(520, 430)
	skill_dialog.exclusive = true
	skill_dialog.transient = true
	skill_dialog.visible = false
	add_child(skill_dialog)
	skill_dialog.close_requested.connect(func(): skill_dialog.hide())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	skill_dialog.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var explanation := Label.new()
	explanation.text = "Paste SKILL.md. Instructions are stored, never executed."
	column.add_child(explanation)
	skill_source = TextEdit.new()
	skill_source.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_source.text = "---\nname: write-note\ndescription: Creates a local text note.\n---\n# Workflow\nSave the requested text."
	column.add_child(skill_source)
	var import_button := Button.new()
	import_button.text = "Import pasted SKILL.md"
	import_button.pressed.connect(_import_skill)
	column.add_child(import_button)
	skill_picker = OptionButton.new()
	column.add_child(skill_picker)
	tool_picker = OptionButton.new()
	tool_picker.add_item("TXT (native text)")
	tool_picker.add_item("PNG (native sample image)")
	column.add_child(tool_picker)
	var equip_button := Button.new()
	equip_button.text = "Equip selected skill and tool"
	equip_button.pressed.connect(_equip_skill)
	column.add_child(equip_button)
	skill_status = Label.new()
	skill_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(skill_status)

func _show_skills() -> void:
	if busy:
		return
	_refresh_skill_picker()
	skill_status.text = "Assign to " + ROBOT_IDS[selected].to_upper()
	skill_dialog.popup_centered()

func _refresh_skill_picker() -> void:
	skill_picker.clear()
	for name_ in skills.list_names():
		skill_picker.add_item(name_)
	if skill_picker.item_count > 0:
		skill_picker.select(0)

func _import_skill() -> void:
	var name_: String = skills.import_markdown(skill_source.text)
	if name_.is_empty():
		skill_status.text = "Rejected: invalid, duplicate, unsupported metadata or storage error."
		return
	_refresh_skill_picker()
	skill_picker.select(skills.list_names().find(name_))
	skill_status.text = "Imported: " + name_

func _equip_skill() -> void:
	if busy or skill_picker.selected < 0:
		return
	var name_ := skill_picker.get_item_text(skill_picker.selected)
	var tool := "text" if tool_picker.selected == 0 else "png"
	if roster.can_use(ROBOT_IDS[selected], tool) and skills.equip(ROBOT_IDS[selected], name_, tool):
		skill_status.text = "Equipped " + name_ + " with " + tool
		_refresh_binding()
	else:
		skill_status.text = "Assignment rejected."

func _refresh_binding() -> void:
	var binding: Dictionary = skills.get_binding(ROBOT_IDS[selected])
	skill_summary.text = "Skill: none" if binding.is_empty() else "Skill: " + str(binding["skill"]) + " / " + str(binding["tool"])
	if not busy:
		run_text.disabled = not engine.is_ready() or not roster.can_use(ROBOT_IDS[selected], "text")
		run_png.disabled = not engine.is_ready() or not roster.can_use(ROBOT_IDS[selected], "png")

func _run_skill() -> void:
	if busy:
		return
	var binding: Dictionary = skills.get_binding(ROBOT_IDS[selected])
	if binding.is_empty():
		status.text = "Equip a skill first."
		return
	var tool: String = binding["tool"]
	_queue(tool, input.text if tool == "text" else "")

func _build_robot_dialog() -> void:
	robot_dialog = Window.new()
	robot_dialog.title = "Robot management"
	robot_dialog.size = Vector2i(570, 500)
	robot_dialog.exclusive = true
	robot_dialog.transient = true
	robot_dialog.visible = false
	add_child(robot_dialog)
	robot_dialog.close_requested.connect(func(): robot_dialog.hide())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	robot_dialog.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	profile_label = Label.new()
	profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(profile_label)
	personality_editor = LineEdit.new()
	personality_editor.placeholder_text = "Personality"
	personality_editor.max_length = 128
	column.add_child(personality_editor)
	memory_editor = TextEdit.new()
	memory_editor.placeholder_text = "Private robot notes / memory"
	memory_editor.custom_minimum_size.y = 70
	column.add_child(memory_editor)
	var permissions := HBoxContainer.new()
	column.add_child(permissions)
	allow_text = CheckBox.new()
	allow_text.text = "Allow TXT"
	permissions.add_child(allow_text)
	allow_png = CheckBox.new()
	allow_png.text = "Allow PNG"
	permissions.add_child(allow_png)
	var save := Button.new()
	save.text = "Save profile and permissions"
	save.pressed.connect(_save_robot_profile)
	column.add_child(save)
	var history_title := Label.new()
	history_title.text = "Recent tasks (local, actual results)"
	column.add_child(history_title)
	history_label = RichTextLabel.new()
	history_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_label.custom_minimum_size.y = 75
	column.add_child(history_label)
	manager_tool = OptionButton.new()
	manager_tool.add_item("TXT")
	manager_tool.add_item("PNG")
	column.add_child(manager_tool)
	var delegate_button := Button.new()
	delegate_button.text = "ATLAS: assign task to eligible worker"
	delegate_button.pressed.connect(_delegate_task)
	column.add_child(delegate_button)
	robot_dialog_status = Label.new()
	robot_dialog_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(robot_dialog_status)

func _show_robot_profile() -> void:
	if busy:
		return
	var id: String = ROBOT_IDS[selected]
	var profile: Dictionary = roster.get_profile(id)
	if profile.is_empty():
		status.text = "Robot profile unavailable."
		return
	profile_label.text = id.to_upper() + " | " + str(profile["role"]) + " | " + str(profile["specialization"]) + "\nSkills: " + str(skills.inventory(id))
	personality_editor.text = profile["personality"]
	memory_editor.text = profile["memory"]
	allow_text.button_pressed = roster.can_use(id, "text")
	allow_png.button_pressed = roster.can_use(id, "png")
	history_label.clear()
	var tasks: Array = engine.history(id)
	if tasks.is_empty():
		history_label.add_text("No recorded tasks.")
	for task in tasks:
		history_label.add_text("#" + str(task["id"]) + "  " + str(task["tool"]) + "  " + str(task["status"]) + "\n")
	robot_dialog_status.text = "Rule-based routing; no AI model yet."
	robot_dialog.popup_centered()

func _save_robot_profile() -> void:
	var id: String = ROBOT_IDS[selected]
	if personality_editor.text.strip_edges().is_empty() or personality_editor.text.to_utf8_buffer().size() > 128 or memory_editor.text.to_utf8_buffer().size() > 4096:
		robot_dialog_status.text = "Invalid personality or memory exceeds 4096 bytes."
		return
	var ok: bool = roster.set_personality(id, personality_editor.text)
	ok = roster.set_memory(id, memory_editor.text) and ok
	ok = roster.set_permission(id, "text", allow_text.button_pressed) and ok
	ok = roster.set_permission(id, "png", allow_png.button_pressed) and ok
	_refresh_binding()
	robot_dialog_status.text = "Saved locally." if ok else "One or more settings failed to save. Reopen to check."

func _delegate_task() -> void:
	if busy:
		return
	var tool := "text" if manager_tool.selected == 0 else "png"
	var worker: String = roster.delegate(tool)
	if worker.is_empty():
		robot_dialog_status.text = "No worker has permission for this tool."
		return
	var worker_index := ROBOT_IDS.find(worker)
	if worker_index < 0:
		return
	robot_dialog.hide()
	selected = worker_index
	selection.select(selected)
	_refresh_binding()
	_queue(tool, input.text if tool == "text" else "")
