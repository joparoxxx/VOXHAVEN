extends Node3D
const Tools = preload("res://core/tool_registry.gd")
var extra_permissions := {}
var local_tool: OptionButton
var local_payload: TextEdit
const TaskEngine = preload("res://core/task_engine.gd")
const Skills = preload("res://core/skill_registry.gd")
const Roster = preload("res://core/robot_roster.gd")
const AIConsole = preload("res://scenes/ai_console.gd")
const TeamChat = preload("res://scenes/team_chat.gd")
var team_chat: Window
var team_task_id := ""
const Workspace = preload("res://scenes/workspace.gd")
var workspace: Window
const Company = preload("res://core/company.gd")
const CompanyHQ = preload("res://scenes/company_hq.gd")
var company = Company.new()
var company_hq: Window
const WorkflowBuilder = preload("res://scenes/workflow_builder.gd")
var workflow_builder: Window
var company_label: Label
var decorations: Node3D
const UI = preload("res://ui/mobile_theme.gd")
var ai_console
var roster = Roster.new()
var robot_dialog: Window
var memory_editor: TextEdit
var personality_editor: LineEdit
var allow_text: CheckBox
var allow_png: CheckBox
var profile_label: Label
var history_label: RichTextLabel
var manager_tool: OptionButton
var delegate_button: Button
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
const ROBOT_IDS := ["atlas", "pixel", "mesh", "nova"]
const ROBOT_COLORS := [Color("#d7b56d"), Color("#a48bdf"), Color("#62a9d9"), Color("#70d7b1")]
var engine = TaskEngine.new()
var robots: Array[Node3D] = []
var wheels: Array[MeshInstance3D] = []
var selected := -1
var cubot_actions: PanelContainer
var tools_button: Button
var status: Label
var input: LineEdit
var preview: TextureRect
var selection_rings: Array[MeshInstance3D] = []
var cubot_labels: Array[Label3D] = []
var chat_button: Button
var settings_button: Button
var tools_panel: PanelContainer
var selected_label: Label
var office_camera: Camera3D
var run_text: Button
var run_png: Button
var cancel_button: Button
var pending_id := ""
var busy := false
var progress_timer := 0.0
const Navigation = preload("res://core/office_navigation.gd")
var navigator = Navigation.new()
var route: Array[Vector3] = []
var eyes: Array = []
var mouths: Array[MeshInstance3D] = []
var face_clock := 0.0
var face_states := ["idle", "idle", "idle", "idle"]
var face_until := [0.0, 0.0, 0.0, 0.0]
var last_active := [0.0, 0.0, 0.0, 0.0]
var robot_bodies: Array[MeshInstance3D] = []
var desks: Array[Node3D] = []
var workstation_ids := [0, 1, 2, 3]
var ambient_robot := -1
var ambient_route: Array[Vector3] = []
var ambient_wait := 5.0
var ambient_cursor := 0
var face_update_wait := 0.0
const Snapshot = preload("res://core/snapshot_store.gd")
var layout_store = Snapshot.new("user://cubyte/office", "layout.json")
var build_dialog: Window
var layout_status: Label
var workflow_payloads: TextEdit
var workflow_queue: Array[String] = []
var touch_points := {}
var touch_moved := false
var last_touch := -1000
var desk_picker: OptionButton
var robot_picker: OptionButton
var station_picker: OptionButton
var color_picker: ColorPickerButton
var camera_target := Vector3(0, 1, 0)

func _ready() -> void:
	roster.set_nova_unlocked("nova" in company.snapshot()["hires"])
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
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 13.8
	add_child(camera)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	office_camera = camera
	_box(self, Vector3(10, 0.15, 8), Vector3(0, -0.075, 0), Color("#727b85"))
	_box(self, Vector3(10, 2, 0.15), Vector3(0, 1, -4), Color("#aab3bd"))
	_box(self, Vector3(0.15, 2, 8), Vector3(-5, 1, 0), Color("#909ba6"))
	for i in range(3):
		var x := float(i - 1) * 2.7
		var desk := Node3D.new()
		add_child(desk)
		desk.position = Vector3(x, 0, -2.6)
		desks.append(desk)
		_box(desk, Vector3(1.8, 0.9, 0.85), Vector3(0, 0.45, 0), Color("#b8bec7"))
		_box(desk, Vector3(0.85, 0.55, 0.12), Vector3(0, 1.22, -0.15), Color("#263749"))
		_build_robot(Vector3(x, 0, 0.5), ROBOT_COLORS[i])
	_box(self, Vector3(1.8, 0.15, 1.3), Vector3(3.5, 0.08, 2.4), Color("#4a6b72"))
	var nova_desk := Node3D.new()
	add_child(nova_desk)
	nova_desk.position = Vector3(-2.5, 0, 2.8)
	nova_desk.rotation.y = PI
	desks.append(nova_desk)
	_box(nova_desk, Vector3(1.8, 0.9, 0.85), Vector3(0, 0.45, 0), Color("#b8bec7"))
	_box(nova_desk, Vector3(0.85, 0.55, 0.12), Vector3(0, 1.22, -0.15), Color("#263749"))
	_build_robot(Vector3(0, 0, 2.0), ROBOT_COLORS[3])
	_refresh_hired_robot()
	_restore_layout()
	decorations = Node3D.new()
	add_child(decorations)
	_refresh_decorations()
	_rebuild_navigation()

func _build_robot(position_: Vector3, color: Color) -> void:
	var robot := Node3D.new()
	add_child(robot)
	robot.position = position_
	robots.append(robot)
	var index := robots.size() - 1
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.63
	ring_mesh.outer_radius = 0.71
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 8
	ring.mesh = ring_mesh
	ring.position.y = 0.055
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = color.lightened(0.2)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	ring.visible = false
	robot.add_child(ring)
	selection_rings.append(ring)
	var nameplate := Label3D.new()
	nameplate.text = ROBOT_IDS[index].to_upper()
	nameplate.position.y = 1.65
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.font_size = 38
	nameplate.pixel_size = 0.009
	nameplate.outline_size = 8
	nameplate.modulate = color.lightened(0.25)
	robot.add_child(nameplate)
	cubot_labels.append(nameplate)
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
	robot_bodies.append(_box(robot, Vector3(0.82, 0.82, 0.82), Vector3(0, 0.79, 0), color))
	_box(robot, Vector3(0.65, 0.56, 0.04), Vector3(0, 0.82, 0.43), Color("#101b29"))
	var pair: Array[MeshInstance3D] = []
	for side in [-1, 1]:
		pair.append(_box(robot, Vector3(0.10, 0.17, 0.035), Vector3(side * 0.15, 0.88, 0.46), Color("#83f5df")))
		_box(robot, Vector3(0.18, 0.13, 0.14), Vector3(side * 0.49, 0.84, 0), Color("#b9c5d0"))
		_box(robot, Vector3(0.13, 0.37, 0.13), Vector3(side * 0.59, 0.67, 0), Color("#7b8b9d"))
		_box(robot, Vector3(0.19, 0.13, 0.18), Vector3(side * 0.59, 0.48, 0.04), color)
	eyes.append(pair)
	mouths.append(_box(robot, Vector3(0.16, 0.045, 0.035), Vector3(0, 0.69, 0.46), Color("#83f5df")))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.theme = UI.make_theme()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := PanelContainer.new()
	hud.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 10
	top.offset_bottom = 134
	var top_column := VBoxContainer.new()
	top.add_child(top_column)
	var header := HBoxContainer.new()
	top_column.add_child(header)
	var branding := VBoxContainer.new()
	branding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(branding)
	branding.add_child(UI.label("CUBYTE", 25))
	selected_label = UI.label("No Cubot selected", 16, UI.MUTED)
	branding.add_child(selected_label)
	settings_button = UI.button("AI settings", _show_ai_settings)
	header.add_child(settings_button)
	tools_button = UI.button("Tools", _toggle_tools)
	header.add_child(tools_button)
	status = UI.label("Tap a Cubot to select.", 16, UI.MUTED)
	status.max_lines_visible = 2
	top_column.add_child(status)
	var workspace_row := HBoxContainer.new()
	top_column.add_child(workspace_row)
	var team_button := UI.button("Team Chat", _show_team, true)
	team_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_row.add_child(team_button)
	var workspace_button := UI.button("Tasks & files", _show_workspace)
	workspace_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_row.add_child(workspace_button)
	workspace_row.add_child(UI.button("Build", _show_build))
	var company_row := HBoxContainer.new()
	top_column.add_child(company_row)
	company_label = UI.label("", 16, UI.MUTED)
	company_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	company_row.add_child(company_label)
	company_row.add_child(UI.button("Company", _show_company))
	company_row.add_child(UI.button("Workflow", _show_workflow_builder))
	_refresh_company_label()

	var bottom := PanelContainer.new()
	cubot_actions = bottom
	hud.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_top = -92
	bottom.offset_bottom = -10
	var actions := HBoxContainer.new()
	bottom.add_child(actions)
	chat_button = UI.button("Chat", _show_ai, true)
	profile_button = UI.button("Profile", _show_robot_profile)
	skill_button = UI.button("Skills", _show_skills)
	for button in [chat_button, profile_button, skill_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)

	tools_panel = PanelContainer.new()
	hud.add_child(tools_panel)
	tools_panel.anchor_top = 0.35
	tools_panel.anchor_right = 1
	tools_panel.anchor_bottom = 1
	tools_panel.offset_left = 12
	tools_panel.offset_right = -12
	tools_panel.offset_top = 0
	tools_panel.offset_bottom = -102
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tools_panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var tools_header := HBoxContainer.new()
	column.add_child(tools_header)
	var tools_title := UI.label("Local tools", 22)
	tools_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_header.add_child(tools_title)
	tools_header.add_child(UI.button("Close", _toggle_tools))
	column.add_child(UI.label("Create files without AI.", 16, UI.MUTED))
	input = LineEdit.new()
	input.custom_minimum_size.y = 60
	input.placeholder_text = "Text to save"
	input.max_length = 2048
	column.add_child(input)
	run_text = UI.button("Create TXT", func(): _queue("text", input.text))
	column.add_child(run_text)
	run_png = UI.button("Create sample PNG", func(): _queue("png", ""))
	column.add_child(run_png)
	local_tool = OptionButton.new()
	for id in Tools.IDS:
		local_tool.add_item(Tools.describe(id)["label"])
	column.add_child(local_tool)
	local_payload = TextEdit.new()
	local_payload.custom_minimum_size.y = 100
	local_payload.placeholder_text = "Payload (CSV/XLSX: JSON rows; SVG: color JSON; OBJ: cube/pyramid)"
	local_payload.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	column.add_child(local_payload)
	column.add_child(UI.button("Create selected file", _create_selected_file))
	cancel_button = UI.button("Cancel task", _cancel)
	cancel_button.disabled = true
	column.add_child(cancel_button)
	skill_summary = UI.label("", 16, UI.MUTED)
	column.add_child(skill_summary)
	column.add_child(UI.button("Run equipped skill", _run_skill))
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(96, 96)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(preview)
	tools_panel.hide()
	ai_console = AIConsole.new()
	ai_console.configure(roster, skills)
	ai_console.visible = false
	add_child(ai_console)
	ai_console.proposal_approved.connect(_ai_task)
	team_chat = TeamChat.new()
	team_chat.hide()
	add_child(team_chat)
	team_chat.connect("proposal_approved", _team_task)
	workspace = Workspace.new()
	workspace.hide()
	add_child(workspace)
	workspace.connect("run_requested", _run_queued)
	company_hq = CompanyHQ.new()
	company_hq.hide()
	add_child(company_hq)
	company_hq.connect("changed", _company_changed)
	workflow_builder = WorkflowBuilder.new()
	workflow_builder.hide()
	add_child(workflow_builder)
	workflow_builder.connect("approved", _start_team_workflow)
	_build_skill_dialog()
	_build_robot_dialog()
	_build_layout_dialog()
	_select_cubot(-1)

func _select_cubot(index: int) -> void:
	if busy or index < -1 or index >= ROBOT_IDS.size() or (index >= 0 and not roster.is_active(ROBOT_IDS[index])):
		return
	selected = index
	for i in range(selection_rings.size()):
		selection_rings[i].visible = i == index
		cubot_labels[i].modulate = Color.WHITE if i == index else ROBOT_COLORS[i].lightened(0.25)
	cubot_actions.visible = index >= 0
	tools_button.disabled = index < 0
	if index < 0:
		selected_label.text = "No Cubot selected"
		tools_panel.hide()
		status.text = "Tap a Cubot to select."
	else:
		var profile: Dictionary = roster.get_profile(ROBOT_IDS[index])
		selected_label.text = ROBOT_IDS[index].to_upper() + " · " + str(profile.get("role", ""))
		status.text = "Selected " + ROBOT_IDS[index].to_upper()
	_refresh_binding()

func _toggle_tools() -> void:
	if selected < 0:
		return
	tools_panel.visible = not tools_panel.visible

func _show_ai_settings() -> void:
	if not busy:
		ai_console.show_settings_for(ROBOT_IDS[selected] if selected >= 0 else "")

func _unhandled_input(event: InputEvent) -> void:
	if busy or not is_instance_valid(office_camera):
		return
	var point := Vector2.ZERO
	if event is InputEventScreenTouch:
		last_touch = Time.get_ticks_msec()
		if event.pressed:
			if touch_points.is_empty():
				touch_moved = false
			touch_points[event.index] = event.position
			if touch_points.size() > 1:
				touch_moved = true
			return
		point = event.position
		touch_points.erase(event.index)
		if touch_moved or not touch_points.is_empty():
			return
	elif event is InputEventScreenDrag:
		last_touch = Time.get_ticks_msec()
		if not touch_points.has(event.index):
			return
		if touch_points.size() == 2:
			var keys := touch_points.keys()
			var first: Vector2 = touch_points[keys[0]]
			var second: Vector2 = touch_points[keys[1]]
			var previous_distance := first.distance_to(second)
			touch_points[event.index] = event.position
			first = touch_points[keys[0]]
			second = touch_points[keys[1]]
			var next_distance := first.distance_to(second)
			if previous_distance > 5.0 and next_distance > 5.0:
				office_camera.size = clampf(office_camera.size * previous_distance / next_distance, 6.0, 18.0)
			touch_moved = true
		else:
			touch_points[event.index] = event.position
			if event.relative.length() > 2.0 or touch_moved:
				touch_moved = true
				_pan_camera(event.relative)
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventMouseButton and event.pressed:
		if Time.get_ticks_msec() - last_touch < 350:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			office_camera.size = maxf(6.0, office_camera.size - 1.0)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			office_camera.size = minf(18.0, office_camera.size + 1.0)
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		point = event.position
	else:
		return
	var nearest := -1
	var distance := 42.0
	for i in range(robots.size()):
		if not roster.is_active(ROBOT_IDS[i]):
			continue
		var projected := office_camera.unproject_position(robots[i].global_position + Vector3(0, 0.8, 0))
		var d := point.distance_to(projected)
		if d < distance:
			nearest = i
			distance = d
	_select_cubot(nearest)
	get_viewport().set_input_as_handled()

func _queue(tool: String, payload: String, requested_by: String = "") -> void:
	if busy or selected < 0:
		return
	pending_id = engine.enqueue(ROBOT_IDS[selected], tool, payload, requested_by)
	if pending_id.is_empty():
		status.text = "Task rejected: permission, input or storage error."
		return
	_start_queued()

func _start_queued() -> void:
	_stop_ambient()
	var station: int = workstation_ids[selected]
	var target := desks[station].position + Vector3(0, 0, -1.6 if station == 3 else 1.6)
	route = navigator.route(robots[selected].position, target)
	if route.is_empty():
		status.text = "No clear route to workstation. Task remains queued."
		workflow_queue.clear()
		return
	busy = true
	face_states[selected] = "working"
	progress_timer = 0.0
	chat_button.disabled = true
	settings_button.disabled = true
	tools_panel.show()
	skill_button.disabled = true
	profile_button.disabled = true
	run_text.disabled = true
	run_png.disabled = true
	cancel_button.disabled = false
	preview.texture = null

func _cancel() -> void:
	if busy and engine.cancel(pending_id):
		workflow_queue.clear()
		_reset()

func _reset() -> void:
	busy = false
	route.clear()
	chat_button.disabled = false
	settings_button.disabled = false
	skill_button.disabled = false
	profile_button.disabled = false
	_refresh_binding()
	cancel_button.disabled = true

func _process(delta: float) -> void:
	face_clock += delta
	face_update_wait += delta
	if face_update_wait >= 0.08:
		face_update_wait = 0.0
		_update_faces()
	if not busy:
		_update_ambient(delta)
		return
	var robot := robots[selected]
	if not route.is_empty():
		var waypoint: Vector3 = route[0]
		var before := robot.position
		robot.position = before.move_toward(waypoint, delta * 3.0)
		if robot.position.distance_to(before) > 0.001:
			wheels[selected].rotate_x(-delta * 8.0)
		if robot.position.distance_to(waypoint) < 0.01:
			route.pop_front()
		return
	progress_timer += delta
	if progress_timer >= 0.15:
		cancel_button.disabled = true
		var current := pending_id
		engine.run_task(current)
		var completed: Dictionary = engine.get_task(current)
		var succeeded: bool = completed.get("status") == "succeeded"
		if succeeded and company.reward(completed):
			_refresh_company_label()
		_reset()
		if succeeded and not workflow_queue.is_empty():
			var next_id: String = workflow_queue.pop_front()
			_run_queued(next_id)
		else:
			workflow_queue.clear()

func _update_faces() -> void:
	for i in range(eyes.size()):
		if not roster.is_active(ROBOT_IDS[i]):
			continue
		if face_until[i] > 0 and face_clock > face_until[i]:
			face_states[i] = "idle"
			face_until[i] = 0.0
		var state: String = face_states[i]
		if i == selected or state != "idle":
			last_active[i] = face_clock
		elif face_clock - last_active[i] > 60.0:
			state = "sleeping"
		if is_instance_valid(team_chat) and team_chat.get("busy") == true and team_chat.get("current") == ROBOT_IDS[i]:
			state = "thinking"
			last_active[i] = face_clock
		if is_instance_valid(ai_console) and ai_console.online_busy and ai_console.robot_id == ROBOT_IDS[i] and ai_console.online_operation == "ask":
			state = "thinking"
			last_active[i] = face_clock
		var blink := fmod(face_clock + i * 0.8, 4.1) < 0.13
		var scale_y := 0.12 if blink else 1.0
		var color := Color("#83f5df")
		if state == "working":
			scale_y = 0.45 + 0.2 * sin(face_clock * 7)
		elif state == "thinking":
			scale_y = 0.55 + 0.3 * sin(face_clock * 5 + i)
		elif state == "success":
			scale_y = 0.42
		elif state == "error":
			color = Color("#ff7777")
		elif state == "sleeping":
			scale_y = 0.12
		for eye in eyes[i]:
			eye.scale.y = scale_y
			eye.material_override.albedo_color = color
		mouths[i].scale.x = 1.5 if state == "success" else 1.0
		mouths[i].material_override.albedo_color = color

func _on_task_changed(task: Dictionary) -> void:
	var requester := str(task.get("requested_by", ""))
	var route := str(task["robot_id"]).to_upper()
	if not requester.is_empty():
		route = requester.to_upper() + " → " + route
	status.text = route + ": " + str(task["status"])
	if str(task["id"]) == team_task_id and task["status"] in ["succeeded", "failed", "cancelled", "interrupted"]:
		team_chat.call("record_task_result", task)
		team_task_id = ""
	var worker := ROBOT_IDS.find(str(task["robot_id"]))
	if worker >= 0 and task["status"] in ["succeeded", "failed", "cancelled", "interrupted"]:
		face_states[worker] = "success" if task["status"] == "succeeded" else ("idle" if task["status"] == "cancelled" else "error")
		face_until[worker] = face_clock + 3.0
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
	skill_dialog.title = "Cubot skills"
	UI.configure_modal(skill_dialog)
	skill_dialog.size = Vector2i(450, 820)
	skill_dialog.exclusive = true
	skill_dialog.transient = true
	skill_dialog.visible = false
	add_child(skill_dialog)
	skill_dialog.close_requested.connect(func(): skill_dialog.hide())
	var margin := MarginContainer.new()
	margin.theme = UI.make_theme()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	skill_dialog.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	column.add_child(UI.button("Close", skill_dialog.hide))
	var explanation := UI.label("Paste SKILL.md. Instructions are stored, never executed.", 17)
	column.add_child(explanation)
	skill_source = TextEdit.new()
	skill_source.custom_minimum_size.y = 200
	skill_source.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	skill_source.text = "---\nname: write-note\ndescription: Creates a local text note.\n---\n# Workflow\nSave the requested text."
	column.add_child(skill_source)
	var import_button := Button.new()
	import_button.custom_minimum_size.y = 60
	import_button.text = "Import pasted SKILL.md"
	import_button.pressed.connect(_import_skill)
	column.add_child(import_button)
	skill_picker = OptionButton.new()
	skill_picker.custom_minimum_size.y = 60
	column.add_child(skill_picker)
	column.add_child(UI.button("Check requirements", _check_skill))
	column.add_child(UI.button("Export SKILL.md", _export_skill))
	tool_picker = OptionButton.new()
	for id in Tools.IDS:
		tool_picker.add_item(Tools.describe(id)["label"])
	tool_picker.custom_minimum_size.y = 60
	column.add_child(tool_picker)
	var equip_button := Button.new()
	equip_button.custom_minimum_size.y = 60
	equip_button.text = "Equip selected skill and tool"
	equip_button.pressed.connect(_equip_skill)
	column.add_child(equip_button)
	column.add_child(UI.label("Optional workflow: declare steps in SKILL.md, then enter a JSON array of string payloads.", 16, UI.MUTED))
	workflow_payloads = TextEdit.new()
	workflow_payloads.custom_minimum_size.y = 90
	workflow_payloads.placeholder_text = "[\"first payload\", \"second payload\"]"
	column.add_child(workflow_payloads)
	column.add_child(UI.button("Approve & run workflow", _run_workflow))
	skill_status = Label.new()
	skill_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(skill_status)

func _show_skills() -> void:
	if busy or selected < 0:
		return
	_refresh_skill_picker()
	skill_status.text = "Assign to " + ROBOT_IDS[selected].to_upper()
	UI.show_modal(skill_dialog)

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
	if busy or selected < 0 or skill_picker.selected < 0:
		return
	var name_ := skill_picker.get_item_text(skill_picker.selected)
	var tool: String = Tools.IDS[tool_picker.selected]
	if roster.can_use(ROBOT_IDS[selected], tool) and skills.equip(ROBOT_IDS[selected], name_, tool):
		skill_status.text = "Equipped " + name_ + " with " + tool
		_refresh_binding()
	else:
		skill_status.text = "Assignment rejected."

func _refresh_binding() -> void:
	if selected < 0:
		skill_summary.text = "Select a Cubot first."
		run_text.disabled = true
		run_png.disabled = true
		return
	var binding: Dictionary = skills.get_binding(ROBOT_IDS[selected])
	skill_summary.text = "Skill: none" if binding.is_empty() else "Skill: " + str(binding["skill"]) + " / " + str(binding["tool"])
	if not busy:
		run_text.disabled = not engine.is_ready() or not roster.can_use(ROBOT_IDS[selected], "text")
		run_png.disabled = not engine.is_ready() or not roster.can_use(ROBOT_IDS[selected], "png")

func _run_skill() -> void:
	if busy or selected < 0:
		return
	var binding: Dictionary = skills.get_binding(ROBOT_IDS[selected])
	if binding.is_empty():
		status.text = "Equip a skill first."
		return
	var tool: String = binding["tool"]
	_queue(tool, ("" if tool == "png" else (input.text if tool == "text" else local_payload.text)))

func _build_robot_dialog() -> void:
	robot_dialog = Window.new()
	robot_dialog.title = "Cubot profile"
	UI.configure_modal(robot_dialog)
	robot_dialog.size = Vector2i(450, 820)
	robot_dialog.exclusive = true
	robot_dialog.transient = true
	robot_dialog.visible = false
	add_child(robot_dialog)
	robot_dialog.close_requested.connect(func(): robot_dialog.hide())
	var margin := MarginContainer.new()
	margin.theme = UI.make_theme()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	robot_dialog.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	column.add_child(UI.button("Close", robot_dialog.hide))
	profile_label = Label.new()
	profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(profile_label)
	personality_editor = LineEdit.new()
	personality_editor.placeholder_text = "Personality"
	personality_editor.custom_minimum_size.y = 60
	personality_editor.max_length = 128
	column.add_child(personality_editor)
	memory_editor = TextEdit.new()
	memory_editor.placeholder_text = "Private robot notes / memory"
	memory_editor.custom_minimum_size.y = 130
	memory_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	column.add_child(memory_editor)
	var permissions := HBoxContainer.new()
	column.add_child(permissions)
	allow_text = CheckBox.new()
	allow_text.text = "Allow TXT"
	permissions.add_child(allow_text)
	allow_png = CheckBox.new()
	allow_png.text = "Allow PNG"
	permissions.add_child(allow_png)
	for id in Tools.IDS:
		if id in ["text", "png"]:
			continue
		var check := CheckBox.new()
		check.text = "Allow " + str(Tools.describe(id)["label"])
		column.add_child(check)
		extra_permissions[id] = check
	var save := Button.new()
	save.custom_minimum_size.y = 60
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
	for id in Tools.IDS:
		manager_tool.add_item(Tools.describe(id)["label"])
	manager_tool.custom_minimum_size.y = 60
	column.add_child(manager_tool)
	delegate_button = Button.new()
	delegate_button.custom_minimum_size.y = 60
	delegate_button.text = "ATLAS: delegate task"
	delegate_button.pressed.connect(_delegate_task)
	column.add_child(delegate_button)
	robot_dialog_status = Label.new()
	robot_dialog_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(robot_dialog_status)

func _show_robot_profile() -> void:
	if busy or selected < 0:
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
	for tool in extra_permissions:
		extra_permissions[tool].button_pressed = roster.can_use(id, tool)
	history_label.clear()
	manager_tool.visible = id == "atlas"
	delegate_button.visible = id == "atlas"
	var tasks: Array = engine.history(id)
	if tasks.is_empty():
		history_label.add_text("No recorded tasks.")
	for task in tasks:
		var requester := str(task.get("requested_by", ""))
		var route := str(task["robot_id"]).to_upper()
		if not requester.is_empty():
			route = requester.to_upper() + " → " + route
		history_label.add_text("#" + str(task["id"]) + "  " + route + "  " + str(task["tool"]) + "  " + str(task["status"]) + "\n")
	robot_dialog_status.text = "Local profile and rule-based task routing."
	UI.show_modal(robot_dialog)

func _save_robot_profile() -> void:
	if selected < 0 or busy:
		return
	var id: String = ROBOT_IDS[selected]
	if personality_editor.text.strip_edges().is_empty() or personality_editor.text.to_utf8_buffer().size() > 128 or memory_editor.text.to_utf8_buffer().size() > 4096:
		robot_dialog_status.text = "Invalid personality or memory exceeds 4096 bytes."
		return
	var ok: bool = roster.set_personality(id, personality_editor.text)
	ok = roster.set_memory(id, memory_editor.text) and ok
	ok = roster.set_permission(id, "text", allow_text.button_pressed) and ok
	ok = roster.set_permission(id, "png", allow_png.button_pressed) and ok
	for tool in extra_permissions:
		ok = roster.set_permission(id, tool, extra_permissions[tool].button_pressed) and ok
	_refresh_binding()
	robot_dialog_status.text = "Saved locally." if ok else "One or more settings failed to save. Reopen to check."

func _delegate_task() -> void:
	if busy or selected != 0:
		return
	var tool: String = Tools.IDS[manager_tool.selected]
	if not roster.can_use("atlas", tool):
		robot_dialog_status.text = "ATLAS lacks permission for this tool."
		return
	var worker: String = roster.delegate(tool)
	if worker.is_empty():
		robot_dialog_status.text = "No worker has permission for this tool."
		return
	var worker_index := ROBOT_IDS.find(worker)
	if worker_index < 0:
		return
	robot_dialog.hide()
	_select_cubot(worker_index)
	_queue(tool, ("" if tool == "png" else (input.text if tool == "text" else local_payload.text)), "atlas")

func _show_ai() -> void:
	if not busy and selected >= 0:
		ai_console.show_for(ROBOT_IDS[selected])

func _ai_task(robot_id: String, tool: String, payload: String, worker_id: String) -> void:
	if busy or not roster.can_use(robot_id, tool) or not roster.can_use(worker_id, tool):
		status.text = "AI tool request denied or worker busy."
		return
	if robot_id == "atlas":
		if worker_id != roster.delegate(tool):
			status.text = "Worker route changed. Request a new approval."
			return
	elif worker_id != robot_id:
		status.text = "Only ATLAS can delegate."
		return
	var index := ROBOT_IDS.find(worker_id)
	if index < 0:
		return
	_select_cubot(index)
	_queue(tool, payload, robot_id if worker_id != robot_id else "")

func _show_team() -> void:
	if not busy and not ai_console.online_busy:
		team_chat.call("show_team", ai_console)

func _create_selected_file() -> void:
	if selected < 0 or busy or local_tool.selected < 0:
		return
	var tool: String = Tools.IDS[local_tool.selected]
	_queue(tool, "" if tool == "png" else local_payload.text)

func _show_workspace() -> void:
	if not busy and not ai_console.online_busy:
		workspace.call("show_workspace", engine)

func _run_queued(id: String) -> void:
	if busy:
		return
	var task: Dictionary = engine.get_task(id)
	if task.get("status") != "queued":
		return
	var index := ROBOT_IDS.find(task.get("robot_id", ""))
	if index < 0 or not roster.is_active(ROBOT_IDS[index]):
		return
	_select_cubot(index)
	pending_id = id
	_start_queued()

func _check_skill() -> void:
	if skill_picker.selected < 0 or tool_picker.selected < 0:
		return
	var report: Dictionary = skills.dependency_report(skill_picker.get_item_text(skill_picker.selected), Tools.IDS[tool_picker.selected])
	skill_status.text = str(report.get("reason", ""))

func _export_skill() -> void:
	if skill_picker.selected < 0:
		return
	var name_: String = skill_picker.get_item_text(skill_picker.selected)
	var path: String = skills.export_file(name_)
	if path.is_empty():
		skill_status.text = "Export failed."
	else:
		DisplayServer.clipboard_set(skills.export_markdown(name_))
		skill_status.text = "Saved to " + path + " and copied SKILL.md to clipboard."

func _rebuild_navigation() -> void:
	navigator = Navigation.new()
	for i in range(desks.size()):
		if i == 3 and not roster.is_active("nova"):
			continue
		navigator.block_box(desks[i].position, Vector2(1.35, 0.85))
	navigator.block_box(Vector3(3.5, 0, 2.4), Vector2(1.35, 1.1))

func _restore_layout() -> void:
	var saved: Dictionary = layout_store.read("layout", "", 16384)
	if not saved.get("ok", false) or not saved.get("found", false):
		return
	var raw: Variant = JSON.parse_string(str(saved.get("value", "")))
	if not raw is Dictionary or raw.get("version") != 1:
		return
	var offsets: Variant = raw.get("desks")
	var stations: Variant = raw.get("stations")
	var colors: Variant = raw.get("colors")
	if not offsets is Array or offsets.size() != 3 or not stations is Array or stations.size() != 3 or not colors is Array or colors.size() != 3:
		return
	var assigned: Array[int] = []
	for i in range(3):
		if not (offsets[i] is float or offsets[i] is int) or not (is_equal_approx(float(offsets[i]), -3.0) or is_equal_approx(float(offsets[i]), -2.6) or is_equal_approx(float(offsets[i]), -2.1)):
			return
		if not (stations[i] is float or stations[i] is int) or float(stations[i]) != int(stations[i]) or int(stations[i]) not in [0, 1, 2] or int(stations[i]) in assigned:
			return
		assigned.append(int(stations[i]))
		if not colors[i] is String or not Color.html_is_valid(colors[i]):
			return
	for i in range(3):
		desks[i].position.z = float(offsets[i])
		workstation_ids[i] = assigned[i]
		robot_bodies[i].material_override.albedo_color = Color.html(colors[i])

func _save_layout() -> bool:
	var offsets := []
	var colors := []
	for i in range(3):
		offsets.append(desks[i].position.z)
		colors.append(robot_bodies[i].material_override.albedo_color.to_html(false))
	return layout_store.write("layout", JSON.stringify({"version": 1, "desks": offsets, "stations": workstation_ids.slice(0, 3), "colors": colors}))

func _build_layout_dialog() -> void:
	build_dialog = Window.new()
	UI.configure_modal(build_dialog)
	build_dialog.hide()
	add_child(build_dialog)
	build_dialog.close_requested.connect(build_dialog.hide)
	var column := UI.scroll_column(build_dialog)
	column.add_child(UI.label("Office build mode", 24))
	column.add_child(UI.button("Close", build_dialog.hide))
	column.add_child(UI.label("Move desks within their lanes, assign stations and customize robot body color.", 16, UI.MUTED))
	desk_picker = OptionButton.new()
	for i in range(3):
		desk_picker.add_item("Desk " + str(i + 1))
	column.add_child(desk_picker)
	column.add_child(UI.button("Move desk toward wall", func(): _move_desk(-1)))
	column.add_child(UI.button("Move desk toward center", func(): _move_desk(1)))
	robot_picker = OptionButton.new()
	station_picker = OptionButton.new()
	for i in range(3):
		robot_picker.add_item(ROBOT_IDS[i].to_upper())
		station_picker.add_item("Station " + str(i + 1))
	column.add_child(robot_picker)
	column.add_child(station_picker)
	column.add_child(UI.button("Assign workstation (swap)", _assign_station))
	color_picker = ColorPickerButton.new()
	color_picker.custom_minimum_size.y = 60
	color_picker.edit_alpha = false
	column.add_child(color_picker)
	robot_picker.item_selected.connect(_layout_robot_selected)
	column.add_child(UI.button("Apply robot color", _apply_robot_color))
	column.add_child(UI.button("Zoom in", func(): office_camera.size = maxf(6.0, office_camera.size - 1.5)))
	column.add_child(UI.button("Zoom out", func(): office_camera.size = minf(18.0, office_camera.size + 1.5)))
	column.add_child(UI.button("Reset camera", func(): _reset_camera()))
	layout_status = UI.label("", 16, UI.MUTED)
	column.add_child(layout_status)

func _show_build() -> void:
	if busy or ai_console.online_busy:
		return
	_layout_robot_selected(robot_picker.selected)
	UI.show_modal(build_dialog)

func _layout_robot_selected(index: int) -> void:
	if index < 0:
		return
	station_picker.select(workstation_ids[index])
	color_picker.color = robot_bodies[index].material_override.albedo_color

func _move_desk(direction: int) -> void:
	var index := desk_picker.selected
	if index < 0 or busy:
		return
	var positions := [-3.0, -2.6, -2.1]
	var old := desks[index].position.z
	var nearest := 0
	for i in range(positions.size()):
		if absf(old - positions[i]) < absf(old - positions[nearest]):
			nearest = i
	desks[index].position.z = positions[clampi(nearest + direction, 0, 2)]
	for robot in robots:
		if not robot.visible:
			continue
		if absf(robot.position.x - desks[index].position.x) <= 1.35 and absf(robot.position.z - desks[index].position.z) <= 0.85:
			desks[index].position.z = old
			layout_status.text = "A robot occupies that space."
			return
	if not _save_layout():
		desks[index].position.z = old
		layout_status.text = "Storage failure; desk movement reverted."
		return
	_rebuild_navigation()
	layout_status.text = "Desk layout saved."

func _assign_station() -> void:
	var robot := robot_picker.selected
	var station := station_picker.selected
	if robot < 0 or station < 0 or busy:
		return
	var old: Array = workstation_ids.duplicate()
	var other := workstation_ids.find(station)
	workstation_ids[other] = workstation_ids[robot]
	workstation_ids[robot] = station
	if not _save_layout():
		workstation_ids = old
		layout_status.text = "Assignment could not be saved."
	else:
		layout_status.text = "Workstation assignment saved."

func _apply_robot_color() -> void:
	var index := robot_picker.selected
	if index < 0 or busy:
		return
	var old: Color = robot_bodies[index].material_override.albedo_color
	robot_bodies[index].material_override.albedo_color = color_picker.color
	if not _save_layout():
		robot_bodies[index].material_override.albedo_color = old
		layout_status.text = "Color could not be saved."
	else:
		layout_status.text = "Robot color saved."

func _run_workflow() -> void:
	if busy or selected < 0 or skill_picker.selected < 0:
		return
	var payloads: Variant = JSON.parse_string(workflow_payloads.text)
	if not payloads is Array:
		skill_status.text = "Enter a JSON array of string payloads."
		return
	var name_: String = skill_picker.get_item_text(skill_picker.selected)
	var plan: Array = skills.workflow_plan(name_, payloads)
	if plan.is_empty():
		skill_status.text = "Invalid workflow, dependencies or payload count."
		return
	workflow_queue = engine.enqueue_workflow(ROBOT_IDS[selected], plan)
	if workflow_queue.is_empty():
		skill_status.text = "Workflow rejected: check permissions, inputs and storage."
		return
	skill_dialog.hide()
	pending_id = workflow_queue.pop_front()
	_start_queued()

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or not is_instance_valid(ai_console):
		return
	if ai_console.visible:
		ai_console.handle_back()
	elif is_instance_valid(team_chat) and team_chat.visible:
		team_chat.call("_close")
	elif is_instance_valid(workspace) and workspace.visible:
		var confirm: Window = workspace.get("delete_confirm")
		if is_instance_valid(confirm) and confirm.visible:
			confirm.hide()
		else:
			workspace.hide()
	elif is_instance_valid(workflow_builder) and workflow_builder.visible:
		workflow_builder.hide()
	elif is_instance_valid(company_hq) and company_hq.visible:
		company_hq.hide()
	elif is_instance_valid(build_dialog) and build_dialog.visible:
		build_dialog.hide()
	elif skill_dialog.visible:
		skill_dialog.hide()
	elif robot_dialog.visible:
		robot_dialog.hide()
	elif tools_panel.visible:
		tools_panel.hide()
	elif not busy:
		_select_cubot(-1)

func _pan_camera(relative: Vector2) -> void:
	var scale_ := office_camera.size / maxf(1.0, get_viewport().get_visible_rect().size.x)
	var right := office_camera.global_basis.x
	right.y = 0
	var forward := office_camera.global_basis.z
	forward.y = 0
	var target := camera_target - right.normalized() * relative.x * scale_ - forward.normalized() * relative.y * scale_
	target.x = clampf(target.x, -4.0, 4.0)
	target.z = clampf(target.z, -3.0, 3.0)
	office_camera.position += target - camera_target
	camera_target = target

func _reset_camera() -> void:
	office_camera.size = 13.8
	office_camera.position = Vector3(8, 9, 12)
	camera_target = Vector3(0, 1, 0)
	office_camera.look_at(camera_target)

func _team_task(robot_id: String, tool: String, payload: String, worker_id: String) -> void:
	var previous := pending_id
	_ai_task(robot_id, tool, payload, worker_id)
	if not pending_id.is_empty() and pending_id != previous:
		team_task_id = pending_id

func _refresh_company_label() -> void:
	if is_instance_valid(company_label):
		var data: Dictionary = company.snapshot()
		company_label.text = "Lv " + str(company.level()) + " · " + str(int(data["credits"])) + " credits"

func _show_company() -> void:
	if not busy and not ai_console.online_busy:
		company_hq.call("show_company", company)

func _company_changed() -> void:
	_refresh_company_label()
	_refresh_hired_robot()
	_refresh_decorations()
	_rebuild_navigation()

func _refresh_decorations() -> void:
	if not is_instance_valid(decorations):
		return
	for child in decorations.get_children():
		decorations.remove_child(child)
		child.queue_free()
	var upgrades: Array = company.snapshot()["upgrades"]
	if "plant" in upgrades:
		_box(decorations, Vector3(0.45, 0.45, 0.45), Vector3(-4.3, 0.225, -3.35), Color("#ad7952"))
		_box(decorations, Vector3(0.65, 0.65, 0.65), Vector3(-4.3, 0.75, -3.35), Color("#468b58"))
	if "lounge" in upgrades:
		_box(decorations, Vector3(1.2, 0.4, 0.8), Vector3(3.5, 0.35, 2.4), Color("#527d82"))
		_box(decorations, Vector3(1.2, 0.65, 0.18), Vector3(3.5, 0.65, 2.75), Color("#36585d"))
	if "lamp" in upgrades:
		_box(decorations, Vector3(0.2, 0.2, 0.2), Vector3(4.3, 0.1, -3.3), Color("#586475"))
		_box(decorations, Vector3(0.08, 1.5, 0.08), Vector3(4.3, 0.85, -3.3), Color("#738297"))
		_box(decorations, Vector3(0.4, 0.18, 0.4), Vector3(4.3, 1.7, -3.3), Color("#f5d998"))

func _show_workflow_builder() -> void:
	if not busy and not ai_console.online_busy:
		workflow_builder.call("show_builder", engine, roster)

func _start_team_workflow(ids: Array) -> void:
	if busy or ids.is_empty():
		return
	workflow_queue.clear()
	for id in ids:
		workflow_queue.append(str(id))
	var first: String = workflow_queue.pop_front()
	_run_queued(first)

func _refresh_hired_robot() -> void:
	var hired: bool = "nova" in company.snapshot()["hires"]
	roster.set_nova_unlocked(hired)
	robots[3].visible = hired
	desks[3].visible = hired

func _stop_ambient() -> void:
	ambient_robot = -1
	ambient_route.clear()
	ambient_wait = 4.0

func _modal_open() -> bool:
	for window in [ai_console, team_chat, workspace, build_dialog, robot_dialog, skill_dialog, company_hq, workflow_builder]:
		if is_instance_valid(window) and window.visible:
			return true
	return false

func _update_ambient(delta: float) -> void:
	if _modal_open():
		_stop_ambient()
		return
	if ambient_robot >= 0:
		if ambient_robot == selected or ambient_route.is_empty():
			_stop_ambient()
			return
		var robot := robots[ambient_robot]
		var point: Vector3 = ambient_route[0]
		var before := robot.position
		robot.position = before.move_toward(point, delta * 1.25)
		if before.distance_to(robot.position) > 0.001:
			wheels[ambient_robot].rotate_x(-delta * 4.0)
		if robot.position.distance_to(point) < 0.01:
			ambient_route.pop_front()
		return
	ambient_wait -= delta
	if ambient_wait > 0:
		return
	ambient_wait = 5.0
	for attempt in range(ROBOT_IDS.size()):
		var i := ambient_cursor % ROBOT_IDS.size()
		ambient_cursor += 1
		if i == selected or not roster.is_active(ROBOT_IDS[i]):
			continue
		var target := Vector3(float(i - 1) * 1.5, 0, 0.5 if fmod(face_clock, 20.0) < 10.0 else 1.5)
		var plan := Navigation.new()
		for j in range(desks.size()):
			if desks[j].visible:
				plan.block_box(desks[j].position, Vector2(1.35, 0.85))
		plan.block_box(Vector3(3.5, 0, 2.4), Vector2(1.35, 1.1))
		for j in range(robots.size()):
			if i != j and robots[j].visible:
				plan.block_box(robots[j].position, Vector2(0.85, 0.85))
		ambient_route = plan.route(robots[i].position, target)
		if ambient_route.size() > 1:
			ambient_robot = i
			return

