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
var meeting_room: Window
var meeting_button: Button
var meeting_active := false
var meeting_arrivals: Array[int] = []
var meeting_walker := -1
var meeting_route: Array[Vector3] = []
var meeting_plan_pending := false
var meeting_speaker := -1
var meeting_line_until := 0.0
var team_task_id := ""
const Workspace = preload("res://scenes/workspace.gd")
var workspace: Window
const Company = preload("res://core/company.gd")
const CompanyHQ = preload("res://scenes/company_hq.gd")
var company = Company.new()
var company_hq: Window
const Progression = preload("res://core/cubot_progression.gd")
const MissionBoard = preload("res://scenes/mission_board.gd")
var progression = Progression.new()
var mission_board: Window
var equipment_markers: Array[MeshInstance3D] = []
var movement_bonus := 1.0
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
var ambient_enabled := true
var sound_enabled := true
const CubotVoice = preload("res://core/cubot_voice.gd")
var voice_synth = CubotVoice.new()
var voice_player: AudioStreamPlayer
var voice_enabled := true
var voice_check: CheckBox
var low_power := false
var power_check: CheckBox
var box_meshes := {}
const Geometry = preload("res://core/rounded_geometry.gd")
const HQ = preload("res://core/hq_layout.gd")
var manager_partitions: Array[Node3D] = []
var wall_details: Node3D
var front_wall: Node3D
var right_wall: Node3D
var blueprint_meshes := {}
var sound_player: AudioStreamPlayer
var tones := {}
var decoration_slot := 0
var idle_check: CheckBox
var sound_check: CheckBox
const Social = preload("res://core/robot_social.gd")
var body_pivots: Array[Node3D] = []
var speech_labels: Array[Label3D] = []
var interaction_ids: Array[int] = []
var dialogue_lines: Array[String] = []
var dialogue_turn := 0
var dialogue_elapsed := 0.0
var ambient_partner := -1
const CHARGE_IDLE_DELAY := 40.0
const CHARGE_THRESHOLD := 75.0
var charge_idle := 0.0
var charge_retry := 0.0
var charge_walker := -1
var charge_departing := false
var charge_route: Array[Vector3] = []
var charge_docked := [false,false,false,false]
var charge_percent := [70.0,70.0,70.0,70.0]
var charge_docks: Array[Node3D] = []
var charge_lights: Array[MeshInstance3D] = []
var charge_labels: Array[Label3D] = []
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
const CameraMath = preload("res://core/office_camera.gd")
var camera_target := Vector3(0, 1, 0)
var orbit_angles := Vector2.ZERO
var orbit_distance := 16.5
var back_wall: MeshInstance3D
var left_wall: MeshInstance3D
var touch_origin := Vector2.ZERO

func _ready() -> void:
	roster.set_nova_unlocked("nova" in company.snapshot()["hires"])
	engine.set_permission_checker(Callable(roster, "can_use"))
	_build_office()
	_build_ui()
	_init_audio()
	for id in ROBOT_IDS:
		_refresh_equipment(id)
	Engine.max_fps = 30 if low_power else 60
	engine.task_changed.connect(_on_task_changed)
	if not engine.is_ready() or not roster.is_ready():
		status.text = "Local storage unavailable. Tasks disabled."
		run_text.disabled = true
		run_png.disabled = true

func _box(parent: Node3D, size: Vector3, position_: Vector3, color: Color) -> MeshInstance3D:
	var mesh: Mesh = box_meshes.get(size)
	if mesh == null:
		var radius := minf(0.15, minf(size.x, minf(size.y, size.z)) * 0.24)
		mesh = Geometry.rounded_box(size, radius)
		box_meshes[size] = mesh
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position_
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	node.material_override = mat
	parent.add_child(node)
	return node

func _build_office() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#203740")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#e7f2ed")
	env.ambient_light_energy = 0.78
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -35, 0)
	light.light_color = Color("#fff1d9")
	light.light_energy = 1.12
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 140, 0)
	fill.light_color = Color("#b5e3ec")
	fill.light_energy = 0.28
	add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(camera)
	camera.current = true
	office_camera = camera
	_slab(self, Vector3(18.3,0.42,12.3), Vector3(0,-0.27,0), Color("#36535d"),0.65)
	_slab(self, Vector3(18,0.12,12), Vector3(0,-0.06,0), Color("#e7e5df"),0.60)
	# Recessed zone floors remain walkable.
	_slab(self,Vector3(5.7,0.035,4.3),Vector3(-4,0.012,-3.75),Color("#c9b58d"),0.45)
	_slab(self,Vector3(6.4,0.035,4.3),Vector3(3.3,0.012,-3.75),Color("#a9c6cb"),0.45)
	_slab(self,Vector3(11.8,0.035,3.0),Vector3(0,0.012,3.65),Color("#a1c8c4"),0.45)
	_slab(self,Vector3(12.0,0.025,2.0),Vector3(0,0.012,0),Color("#b8ceca"),0.45)
	_slab(self,Vector3(2.5,0.035,3.0),HQ.LOUNGE+Vector3(0,0.018,0),Color("#d6bb91"),0.5)
	_slab(self,Vector3(2.5,0.035,2.1),HQ.LAB+Vector3(0,0.018,0),Color("#9bb7bb"),0.4)
	_slab(self,Vector3(2.6,0.035,6.0),Vector3(7.5,0.018,1),Color("#cfbd97"),0.45)
	back_wall = _box(self, Vector3(18, 1.55, 0.20), Vector3(0, 0.775, -6), Color("#c5d6d4"))
	left_wall = _box(self, Vector3(0.20, 1.55, 12), Vector3(-9, 0.775, 0), Color("#bccdcb"))
	front_wall = Node3D.new()
	add_child(front_wall)
	_box(front_wall,Vector3(7.65,0.75,0.20),Vector3(-5.15,0.375,6),Color("#b8cdca"))
	_box(front_wall,Vector3(7.65,0.75,0.20),Vector3(5.15,0.375,6),Color("#b8cdca"))
	right_wall = Node3D.new()
	add_child(right_wall)
	_box(right_wall,Vector3(0.20,0.85,12),Vector3(9,0.425,0),Color("#b8cdca"))
	_slab(self,Vector3(2.4,0.045,0.85),Vector3(0,0.035,5.55),Color("#76bdb5"),0.24)
	_zone_label("HQ ENTRANCE",Vector3(0,0.085,5.55),Color("#244954"))
	wall_details = Node3D.new()
	add_child(wall_details)
	_box(wall_details, Vector3(17.8, 0.09, 0.10), Vector3(0, 1.52, -5.89), Color("#70d7b1"))
	_build_wall_display(wall_details,Vector3(3.5,1.12,-5.84),Color("#70d7b1"))
	_build_wall_display(wall_details,Vector3(-4,1.12,-5.84),Color("#eac678"))
	for x in [-8.2,-6.8,1.0,6.6,8.2]:
		_box(wall_details,Vector3(0.68,0.70,0.045),Vector3(x,0.98,-5.87),Color("#85b4bf"))
		_box(wall_details,Vector3(0.74,0.055,0.09),Vector3(x,1.36,-5.85),Color("#e4eee5"))
	# Manager's private suite. Glass-style tinted low partitions leave a real doorway.
	for part in HQ.PARTITIONS:
		var center: Vector3 = part["center"]
		var half: Vector2 = part["half"]
		var panel := _box(self, Vector3(half.x * 2, 0.78, half.y * 2), center + Vector3(0,0.39,0), Color("#a5c9c5"))
		manager_partitions.append(panel)
		var rail := _box(self, Vector3(half.x * 2, 0.07, half.y * 2 + 0.02), center + Vector3(0,0.82,0), Color("#526f76"))
		manager_partitions.append(rail)
	_zone_label("ATLAS  /  MANAGEMENT", Vector3(-4,0.045,-5.55), Color("#6c5d42"))
	_zone_label("MEETING ROOM", Vector3(3.5,0.045,-5.7), Color("#36535d"))
	_zone_label("PRODUCTION", Vector3(0,0.045,4.85), Color("#36535d"))
	_zone_label("SOCIAL CORRIDOR", Vector3(0,0.045,0.65), Color("#36535d"))
	for i in range(4):
		var desk := Node3D.new()
		add_child(desk)
		desk.position = HQ.DESKS[i]
		if i > 0:
			desk.rotation.y = PI
		desks.append(desk)
		_build_desk(desk, ROBOT_COLORS[i], i == 0)
		_build_robot(HQ.SPAWNS[i], ROBOT_COLORS[i])
	# Conference table with four clear docking positions and a shared project display.
	_slab(self, Vector3(1.7,0.70,0.95), HQ.MEETING_CENTER + Vector3(0,0.40,0), Color("#36535d"),0.38)
	_slab(self, Vector3(1.95,0.16,1.1), HQ.MEETING_CENTER + Vector3(0,0.83,0), Color("#e7e5df"),0.45)
	var screen := _box(self, Vector3(0.95,0.07,0.48), HQ.MEETING_CENTER + Vector3(0,0.95,0), Color("#213e48"))
	screen.material_override.emission_enabled = true
	screen.material_override.emission = Color("#70d7b1")
	screen.material_override.emission_energy_multiplier = 0.25
	for i in range(HQ.SEATS.size()):
		_slab(self, Vector3(0.9,0.025,0.9), HQ.SEATS[i] + Vector3(0,0.04,0), ROBOT_COLORS[i].darkened(0.25),0.30)
	_build_blueprint_lounge()
	_build_blueprint_lab()
	_plant(self,HQ.PLANTER,0.80)
	for point in [Vector3(-8.35,0,-5.3),Vector3(8.35,0,-5.3),Vector3(-8.6,0,5.4),Vector3(8.6,0,5.4)]:
		_plant(self,point,0.48)
	_zone_label("UPGRADE LAB", HQ.LAB + Vector3(0,0.045,0.9), Color("#36535d"))
	_build_charging_docks()
	_refresh_hired_robot()
	_restore_layout()
	decorations = Node3D.new()
	add_child(decorations)
	_refresh_decorations()
	_rebuild_navigation()
	_reset_camera()

func _zone_label(value: String, pos: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = value
	label.font_size = 36
	label.pixel_size = 0.006
	label.position = pos
	label.rotation.x = -PI / 2.0
	label.modulate = color
	label.outline_size = 0
	add_child(label)

func _build_desk(desk: Node3D, accent: Color, executive: bool) -> void:
	var width := 2.05 if executive else 1.8
	_slab(desk,Vector3(width,0.15,0.9),Vector3(0,0.85,0),Color("#f0ede5"),0.38)
	_slab(desk,Vector3(width-0.10,0.18,0.78),Vector3(0,0.69,0),Color("#b69c6c") if executive else Color("#456d72"),0.30)
	_glow(desk,Vector3(width-0.32,0.035,0.05),Vector3(0,0.72,0.39),Color("#f1ca77") if executive else Color("#70d7b1"))
	for side in [-1,1]:
		_box(desk, Vector3(0.32,0.74,0.74), Vector3(side * (width / 2.0 - 0.23),0.38,0), Color("#526e75"))
	_box(desk, Vector3(width - 0.18,0.08,0.08), Vector3(0,0.77,0.43), accent)
	_box(desk, Vector3(0.93,0.54,0.15), Vector3(0,1.23,-0.18), Color("#263e47"))
	var screen := _box(desk, Vector3(0.82,0.44,0.035), Vector3(0,1.23,-0.09), accent.darkened(0.35))
	screen.material_override.emission_enabled = true
	screen.material_override.emission = accent
	screen.material_override.emission_energy_multiplier = 0.16
	_box(desk, Vector3(0.15,0.22,0.15), Vector3(0,0.99,-0.18), Color("#526e75"))
	_box(desk, Vector3(0.52,0.055,0.18), Vector3(0,0.96,0.20), Color("#839da0"))

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
	var pivot := Node3D.new()
	robot.add_child(pivot)
	body_pivots.append(pivot)
	var bubble := Label3D.new()
	bubble.position.y = 2.05
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 34
	bubble.pixel_size = 0.006
	bubble.outline_size = 12
	bubble.modulate = Color("#f8f5e9")
	bubble.no_depth_test = true
	bubble.hide()
	robot.add_child(bubble)
	speech_labels.append(bubble)
	if _try_edited_cubot(robot, pivot, color):
		var badge := _box(pivot, Vector3(0.16,0.12,0.08), Vector3(0.28,1.16,0.28), Color("#f5d998"))
		badge.hide()
		equipment_markers.append(badge)
		return
	var roller := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.23
	sphere.height = 0.46
	sphere.radial_segments = 16
	sphere.rings = 8
	roller.mesh = sphere
	roller.position.y = 0.23
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#20252e")
	roller.material_override = mat
	robot.add_child(roller)
	wheels.append(roller)
	robot_bodies.append(_box(pivot, Vector3(0.82, 0.82, 0.82), Vector3(0, 0.79, 0), color))
	var marker := _box(pivot, Vector3(0.16, 0.12, 0.08), Vector3(0.28, 1.26, 0.28), Color("#f5d998"))
	marker.hide()
	equipment_markers.append(marker)
	_box(pivot, Vector3(0.7, 0.09, 0.7), Vector3(0, 1.245, 0), color.lightened(0.25))
	_box(pivot, Vector3(0.62, 0.10, 0.62), Vector3(0, 0.34, 0), Color("#263544"))
	for side in [-1, 1]:
		_box(pivot, Vector3(0.035, 0.35, 0.26), Vector3(side * 0.43, 0.82, -0.14), Color("#304154"))
		for slit in range(3):
			_box(pivot, Vector3(0.038, 0.025, 0.17), Vector3(side * 0.45, 0.72 + slit * 0.075, -0.14), Color("#8ba9b6"))
	_box(pivot, Vector3(0.14, 0.12, 0.06), Vector3(-0.22, 1.08, -0.43), Color("#a7e7cb"))
	_box(pivot, Vector3(0.65, 0.56, 0.04), Vector3(0, 0.82, 0.43), Color("#101b29"))
	var pair: Array[MeshInstance3D] = []
	for side in [-1, 1]:
		pair.append(_box(pivot, Vector3(0.10, 0.17, 0.035), Vector3(side * 0.15, 0.88, 0.46), Color("#83f5df")))
		_box(pivot, Vector3(0.18, 0.13, 0.14), Vector3(side * 0.49, 0.84, 0), Color("#b9c5d0"))
		_box(pivot, Vector3(0.13, 0.37, 0.13), Vector3(side * 0.59, 0.67, 0), Color("#7b8b9d"))
		_box(pivot, Vector3(0.19, 0.13, 0.18), Vector3(side * 0.59, 0.48, 0.04), color)
	eyes.append(pair)
	mouths.append(_box(pivot, Vector3(0.16, 0.045, 0.035), Vector3(0, 0.69, 0.46), Color("#83f5df")))

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
	meeting_button = UI.button("Meeting", _call_meeting, true)
	meeting_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_row.add_child(meeting_button)
	var workspace_button := UI.button("Tasks & files", _show_workspace)
	workspace_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_row.add_child(workspace_button)
	var build_button := UI.button("Build", _show_build)
	var company_row := HBoxContainer.new()
	top_column.add_child(company_row)
	company_label = UI.label("", 16, UI.MUTED)
	company_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	company_row.add_child(company_label)
	company_row.add_child(UI.button("Company", _show_company))
	company_row.add_child(UI.button("Workflow", _show_workflow_builder))
	company_row.add_child(build_button)
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
	ai_console.voice_reply.connect(_play_voice_reply)
	team_chat = TeamChat.new()
	team_chat.hide()
	add_child(team_chat)
	team_chat.connect("proposal_approved", _team_task)
	team_chat.connect("voice_reply", _play_voice_reply)
	meeting_room = TeamChat.new()
	meeting_room.set("meeting_mode", true)
	meeting_room.hide()
	add_child(meeting_room)
	meeting_room.call("set_project_engine", engine)
	meeting_room.connect("project_plan_ready", _review_meeting_plan)
	meeting_room.connect("speaker_changed", _meeting_speaker_changed)
	meeting_room.connect("meeting_ended", _end_meeting)
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
	mission_board = MissionBoard.new()
	mission_board.hide()
	add_child(mission_board)
	mission_board.connect("mission_requested", _start_mission)
	mission_board.connect("equipment_changed", _refresh_equipment)
	_build_layout_dialog()
	_select_cubot(-1)

func _select_cubot(index: int) -> void:
	if busy or meeting_active or index < -1 or index >= ROBOT_IDS.size() or (index >= 0 and not roster.is_active(ROBOT_IDS[index])):
		return
	_interrupt_charging()
	if index >= 0:
		_wake_cubot(index)
	_end_conversation()
	_stop_ambient()
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
	if meeting_active:
		return
	if selected < 0:
		return
	tools_panel.visible = not tools_panel.visible

func _show_ai_settings() -> void:
	if meeting_active:
		return
	if not busy:
		ai_console.show_settings_for(ROBOT_IDS[selected] if selected >= 0 else "")

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(office_camera) or _modal_open():
		touch_points.clear()
		return
	var point := Vector2.ZERO
	if event is InputEventScreenTouch:
		last_touch = Time.get_ticks_msec()
		if event.pressed:
			if touch_points.is_empty():
				touch_moved = false
				touch_origin = event.position
			touch_points[event.index] = event.position
			if touch_points.size() > 1:
				touch_moved = true
			return
		if not touch_points.has(event.index):
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
			var old_center := (first + second) * 0.5
			var old_distance := first.distance_to(second)
			touch_points[event.index] = event.position
			first = touch_points[keys[0]]
			second = touch_points[keys[1]]
			office_camera.size = CameraMath.pinch_size(office_camera.size, old_distance, first.distance_to(second))
			_pan_camera((first + second) * 0.5 - old_center)
			touch_moved = true
		elif touch_points.size() == 1:
			touch_points[event.index] = event.position
			if touch_moved or event.position.distance_to(touch_origin) > 8.0:
				touch_moved = true
				_orbit_camera(event.relative)
		else:
			touch_points[event.index] = event.position
			touch_moved = true
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventMouseMotion:
		if Time.get_ticks_msec() - last_touch < 350:
			return
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_orbit_camera(event.relative)
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			_pan_camera(event.relative)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventMouseButton and event.pressed:
		if Time.get_ticks_msec() - last_touch < 350:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			office_camera.size = maxf(CameraMath.MIN_ZOOM, office_camera.size - 1.0)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			office_camera.size = minf(CameraMath.MAX_ZOOM, office_camera.size + 1.0)
			get_viewport().set_input_as_handled()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		point = event.position
	else:
		return
	if busy or meeting_active:
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
	if busy or meeting_active or selected < 0:
		return
	pending_id = engine.enqueue(ROBOT_IDS[selected], tool, payload, requested_by)
	if pending_id.is_empty():
		status.text = "Task rejected: permission, input or storage error."
		return
	_start_queued()

func _start_queued() -> void:
	_interrupt_charging()
	_wake_cubot(selected)
	_end_conversation()
	_stop_ambient()
	var station: int = workstation_ids[selected]
	var target := HQ.work_target(station, desks[station].position)
	route = navigator.route(robots[selected].position, target)
	if route.is_empty():
		status.text = "No clear route to workstation. Task remains queued."
		workflow_queue.clear()
		return
	movement_bonus = progression.speed_multiplier(ROBOT_IDS[selected])
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
	charge_idle = 0.0
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
	_update_charge_indicators(delta)
	if face_update_wait >= 0.08:
		face_update_wait = 0.0
		_update_faces()
	if meeting_active:
		_update_meeting(delta)
		return
	if not busy:
		if _update_charging(delta):
			return
		_update_ambient(delta)
		if selected >= 0 and not charge_docked[selected] and not _modal_open():
			_face_target(selected, office_camera.position, delta)
		return
	var robot := robots[selected]
	if not route.is_empty():
		var waypoint: Vector3 = route[0]
		var before := robot.position
		_face_target(selected, waypoint, delta)
		robot.position = before.move_toward(waypoint, delta * 3.0 * movement_bonus)
		if robot.position.distance_to(before) > 0.001:
			wheels[selected].rotate_x(-delta * 8.0 * movement_bonus)
		if robot.position.distance_to(waypoint) < 0.01:
			route.pop_front()
		return
	_face_target(selected, desks[workstation_ids[selected]].position, delta)
	progress_timer += delta
	if progress_timer >= 0.15:
		cancel_button.disabled = true
		var current := pending_id
		engine.run_task(current)
		var completed: Dictionary = engine.get_task(current)
		var succeeded: bool = completed.get("status") == "succeeded"
		if succeeded:
			if company.reward(completed):
				_refresh_company_label()
			var earned: Dictionary = progression.reward(completed)
			if not earned.is_empty():
				_refresh_equipment(str(completed["robot_id"]))
				status.text += "\n+" + str(earned["xp"]) + " XP · Lv " + str(earned["level"])
				if not str(earned["equipment"]).is_empty():
					status.text += " · Unlocked " + str(earned["equipment"])
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
		if charge_docked[i]:
			state = "charging"
		if meeting_active and meeting_walker < 0 and meeting_arrivals.is_empty():
			state = "talking" if i == meeting_speaker and face_clock < meeting_line_until else "listening"
		if i in interaction_ids and not dialogue_lines.is_empty() and state == "idle":
			state = "talking" if i == interaction_ids[Social.speaker(dialogue_turn)] else "listening"
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
		elif state == "charging":
			scale_y = 0.12
			color = Color("#70d7b1").lerp(Color("#36535d"), 0.25 + 0.20 * sin(face_clock * 2.2))
		elif state == "sleeping":
			scale_y = 0.12
		elif state == "talking":
			scale_y = 0.75
			color = Color("#f5d998")
		elif state == "listening":
			scale_y = 0.85 if not blink else 0.12
			color = Color("#b6e9df")
		for eye in eyes[i]:
			eye.scale.y = scale_y
			eye.material_override.albedo_color = color
		mouths[i].scale.x = 1.5 if state == "success" else (1.0 + 0.2 * sin(face_clock * 19.0) if state == "talking" else 1.0)
		mouths[i].scale.y = 1.0 + 1.4 * absf(sin(face_clock * 14.0)) if state == "talking" else 1.0
		mouths[i].material_override.albedo_color = color

func _on_task_changed(task: Dictionary) -> void:
	var requester := str(task.get("requested_by", ""))
	var route := str(task["robot_id"]).to_upper()
	if not requester.is_empty():
		route = requester.to_upper() + " → " + route
	status.text = route + ": " + str(task["status"])
	if is_instance_valid(meeting_room) and meeting_room.call("tracks_task", str(task["id"])) and task["status"] in ["succeeded","failed","cancelled","interrupted"]:
		meeting_room.call("record_task_result", task)
	if str(task["id"]) == team_task_id and task["status"] in ["succeeded", "failed", "cancelled", "interrupted"]:
		team_chat.call("record_task_result", task)
		team_task_id = ""
	var worker := ROBOT_IDS.find(str(task["robot_id"]))
	if worker >= 0 and task["status"] in ["succeeded", "failed", "cancelled", "interrupted"]:
		face_states[worker] = "success" if task["status"] == "succeeded" else ("idle" if task["status"] == "cancelled" else "error")
		face_until[worker] = face_clock + 3.0
		_play_tone("success" if task["status"] == "succeeded" else ("cancel" if task["status"] == "cancelled" else "error"))
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
	if meeting_active:
		return
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
	if meeting_active:
		return
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
	column.add_child(UI.button("Missions & equipment", _show_missions))
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
	if meeting_active:
		return
	if busy or selected < 0:
		return
	var id: String = ROBOT_IDS[selected]
	var profile: Dictionary = roster.get_profile(id)
	if profile.is_empty():
		status.text = "Robot profile unavailable."
		return
	profile_label.text = id.to_upper() + " | " + str(profile["role"]) + " | " + str(profile["specialization"]) + "\nLevel " + str(progression.level(id)) + " · " + str(int(progression.snapshot(id).get("xp", 0))) + " XP\nSkills: " + str(skills.inventory(id))
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
	if meeting_active:
		return
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
	if meeting_active:
		return
	if not busy and selected >= 0:
		ai_console.show_for(ROBOT_IDS[selected])

func _ai_task(robot_id: String, tool: String, payload: String, worker_id: String) -> void:
	if meeting_active:
		return
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
	if meeting_active:
		return
	if not busy and not ai_console.online_busy:
		team_chat.call("show_team", ai_console)

func _create_selected_file() -> void:
	if meeting_active:
		return
	if selected < 0 or busy or local_tool.selected < 0:
		return
	var tool: String = Tools.IDS[local_tool.selected]
	_queue(tool, "" if tool == "png" else local_payload.text)

func _show_workspace() -> void:
	if meeting_active:
		return
	if not busy and not ai_console.online_busy:
		workspace.call("show_workspace", engine)

func _run_queued(id: String) -> void:
	if busy or meeting_active:
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
	HQ.block_fixed(navigator)

func _restore_layout() -> void:
	var saved: Dictionary = layout_store.read("layout", "", 16384)
	if not saved.get("ok", false) or not saved.get("found", false):
		return
	var raw: Variant = JSON.parse_string(str(saved.get("value", "")))
	if not raw is Dictionary or raw.get("version") not in [1,2]:
		return
	var colors: Variant = raw.get("colors", [])
	if colors is Array:
		for i in range(mini(colors.size(), robots.size())):
			if colors[i] is String and Color.html_is_valid(colors[i]):
				robot_bodies[i].material_override.albedo_color = Color.html(colors[i])
	decoration_slot = clampi(int(raw.get("decor_slot", 0)), 0, 1)
	ambient_enabled = raw.get("ambient", true) == true
	sound_enabled = raw.get("sound", true) == true
	voice_enabled = raw.get("voice", true) == true
	low_power = raw.get("low_power", false) == true
	# v1 graybox coordinates are intentionally reset, but colors/preferences survive.
	if raw.get("version") != 2:
		return
	var offsets: Variant = raw.get("offsets", [])
	if offsets is Array and offsets.size() == 4:
		for i in range(1,4):
			var pair: Variant = offsets[i]
			if pair is Array and pair.size() == 2 and (pair[0] is int or pair[0] is float) and (pair[1] is int or pair[1] is float):
				desks[i].position = HQ.DESKS[i] + Vector3(clampf(float(pair[0]),-0.25,0.25),0,clampf(float(pair[1]),-0.25,0.25))
	var stations: Variant = raw.get("stations", [])
	if stations is Array and stations.size() == 4 and stations[0] == 0:
		var valid := true
		var seen := [0]
		for i in range(1,4):
			if stations[i] not in [1,2,3] or stations[i] in seen:
				valid = false
			seen.append(stations[i])
		if valid and (roster.is_active("nova") or stations[3] == 3):
			for i in range(4):
				workstation_ids[i] = int(stations[i])

func _save_layout() -> bool:
	var offsets := []
	var colors := []
	for i in range(4):
		var delta: Vector3 = desks[i].position - HQ.DESKS[i]
		offsets.append([delta.x,delta.z])
		colors.append(robot_bodies[i].material_override.albedo_color.to_html(false))
	return layout_store.write("layout", JSON.stringify({"version":2,"offsets":offsets,"stations":workstation_ids,"colors":colors,"decor_slot":decoration_slot,"ambient":ambient_enabled,"sound":sound_enabled,"voice":voice_enabled,"low_power":low_power}))

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
	for i in range(4):
		desk_picker.add_item(ROBOT_IDS[i].to_upper() + " desk")
	column.add_child(desk_picker)
	column.add_child(UI.button("Move desk toward wall", func(): _move_desk(-1)))
	column.add_child(UI.button("Move desk toward center", func(): _move_desk(1)))
	column.add_child(UI.button("Nudge desk left", func(): _move_desk_x(-1)))
	column.add_child(UI.button("Nudge desk right", func(): _move_desk_x(1)))
	robot_picker = OptionButton.new()
	station_picker = OptionButton.new()
	for i in range(4):
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
	column.add_child(UI.button("Swap wall decoration layout", _swap_decorations))
	idle_check = CheckBox.new()
	idle_check.text = "Autonomous robot patrols"
	idle_check.button_pressed = ambient_enabled
	idle_check.toggled.connect(_set_ambient)
	column.add_child(idle_check)
	sound_check = CheckBox.new()
	sound_check.text = "Task sound effects"
	sound_check.button_pressed = sound_enabled
	sound_check.toggled.connect(_set_sound)
	column.add_child(sound_check)
	voice_check = CheckBox.new()
	voice_check.text = "Expressive Cubot chirps"
	voice_check.button_pressed = voice_enabled
	voice_check.toggled.connect(_set_voice)
	column.add_child(voice_check)
	power_check = CheckBox.new()
	power_check.text = "Battery saver (30 FPS)"
	power_check.button_pressed = low_power
	power_check.toggled.connect(_set_power_mode)
	column.add_child(power_check)
	column.add_child(UI.button("Zoom in", func(): office_camera.size = maxf(6.0, office_camera.size - 1.5)))
	column.add_child(UI.button("Zoom out", func(): office_camera.size = minf(CameraMath.MAX_ZOOM, office_camera.size + 1.5)))
	column.add_child(UI.label("Camera: one finger rotates, two fingers pan or pinch to zoom.", 16, UI.MUTED))
	var camera_row := HBoxContainer.new()
	column.add_child(camera_row)
	var left := UI.button("Rotate left", func(): _rotate_camera_quarter(-1.0))
	var right := UI.button("Rotate right", func(): _rotate_camera_quarter(1.0))
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera_row.add_child(left)
	camera_row.add_child(right)
	column.add_child(UI.button("Reset camera", func(): _reset_camera()))
	layout_status = UI.label("", 16, UI.MUTED)
	column.add_child(layout_status)

func _show_build() -> void:
	if meeting_active:
		return
	if busy or ai_console.online_busy:
		return
	for picker in [desk_picker, robot_picker, station_picker]:
		picker.set_item_disabled(3, not roster.is_active("nova"))
		if picker.selected == 3 and not roster.is_active("nova"):
			picker.select(0)
	_layout_robot_selected(robot_picker.selected)
	UI.show_modal(build_dialog)

func _layout_robot_selected(index: int) -> void:
	if index < 0:
		return
	station_picker.select(workstation_ids[index])
	color_picker.color = robot_bodies[index].material_override.albedo_color

func _move_desk(direction: int) -> void:
	var index := desk_picker.selected
	if index < 0 or busy or not roster.is_active(ROBOT_IDS[index]):
		return
	if index == 0:
		layout_status.text = "ATLAS has a dedicated executive desk."
		return
	var base: float = HQ.DESKS[index].z
	var positions := [base - 0.25, base, base + 0.25]
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
	if robot < 0 or station < 0 or busy or not roster.is_active(ROBOT_IDS[robot]) or not roster.is_active(ROBOT_IDS[station]):
		return
	if robot == 0 or station == 0:
		layout_status.text = "ATLAS keeps the executive workstation."
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
	if meeting_active:
		return
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
	elif meeting_active:
		meeting_room.call("_close")
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
	elif is_instance_valid(mission_board) and mission_board.visible:
		mission_board.hide()
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
	target.x = clampf(target.x, -8.0, 8.0)
	target.z = clampf(target.z, -5.0, 5.0)
	camera_target = target
	_apply_camera_pose()

func _reset_camera() -> void:
	office_camera.size = 22.0
	camera_target = Vector3(0, 1, 0)
	var original := Vector3(12, 12, 18)
	orbit_angles = CameraMath.angles(original)
	orbit_distance = original.length()
	_apply_camera_pose()

func _orbit_camera(relative: Vector2) -> void:
	orbit_angles = CameraMath.orbit_angles(orbit_angles, relative)
	_apply_camera_pose()

func _rotate_camera_quarter(direction: float) -> void:
	orbit_angles.x = wrapf(orbit_angles.x + direction * PI / 2.0, -PI, PI)
	_apply_camera_pose()

func _apply_camera_pose() -> void:
	var offset := CameraMath.offset(orbit_angles.x, orbit_angles.y, orbit_distance)
	office_camera.position = camera_target + offset
	office_camera.look_at(camera_target)
	# Cut away the wall on the camera-facing side so the office stays visible.
	if is_instance_valid(back_wall):
		back_wall.visible = offset.z >= -0.5
	if is_instance_valid(wall_details):
		wall_details.visible = offset.z >= -0.5
	for panel in manager_partitions:
		panel.visible = offset.z >= -0.5 and offset.x >= -0.5
	if is_instance_valid(left_wall):
		left_wall.visible = offset.x >= -0.5
	if is_instance_valid(front_wall):
		front_wall.visible = offset.z <= 0.5
	if is_instance_valid(right_wall):
		right_wall.visible = offset.x <= 0.5

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
	if meeting_active:
		return
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
	var plant_x := -8.1 if decoration_slot == 0 else 8.1
	var lamp_x := -plant_x
	if "plant" in upgrades:
		_box(decorations, Vector3(0.45, 0.45, 0.45), Vector3(plant_x, 0.225, -5.6), Color("#ad7952"))
		_box(decorations, Vector3(0.65, 0.65, 0.65), Vector3(plant_x, 0.75, -5.6), Color("#468b58"))
	if "lounge" in upgrades:
		_slab(decorations,Vector3(0.55,0.32,0.55),HQ.LOUNGE+Vector3(0.65,0.19,0.64),Color("#d3ba85"),0.22)
		_slab(decorations,Vector3(0.55,0.32,0.55),HQ.LOUNGE+Vector3(-0.65,0.19,0.64),Color("#d3ba85"),0.22)
	if "lamp" in upgrades:
		_box(decorations, Vector3(0.2, 0.2, 0.2), Vector3(lamp_x, 0.1, -5.6), Color("#586475"))
		_box(decorations, Vector3(0.08, 1.5, 0.08), Vector3(lamp_x, 0.85, -5.6), Color("#738297"))
		_box(decorations, Vector3(0.4, 0.18, 0.4), Vector3(lamp_x, 1.7, -5.6), Color("#f5d998"))
	if "bookshelf" in upgrades:
		_box(decorations, Vector3(0.25, 1.5, 1.25), Vector3(-8.75, 0.75, 4.3), Color("#66574e"))
		for row in range(3):
			_box(decorations, Vector3(0.28, 0.055, 1.2), Vector3(-8.61, 0.25 + row * 0.45, 4.3), Color("#d1a97d"))
			for book in range(4):
				_box(decorations, Vector3(0.16, 0.32, 0.19), Vector3(-8.57, 0.42 + row * 0.45, 3.88 + book * 0.23), Color.from_hsv(float(book + row) / 7.0, 0.45, 0.75))
	if "whiteboard" in upgrades:
		_box(decorations, Vector3(2.2, 0.75, 0.06), Vector3(5.8, 0.72, -5.84), Color("#e5edef"))
		for line in range(3):
			_box(decorations, Vector3(1.25 - line * 0.15, 0.035, 0.015), Vector3(5.65, 0.93 - line * 0.17, -5.80), Color("#6d8e99"))

func _show_workflow_builder() -> void:
	if not busy and not meeting_active and not ai_console.online_busy:
		meeting_plan_pending = false
		workflow_builder.call("show_builder", engine, roster)

func _start_team_workflow(ids: Array) -> void:
	if busy or meeting_active or ids.is_empty():
		return
	if meeting_plan_pending:
		meeting_room.call("register_project_tasks", ids)
		meeting_plan_pending = false
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
	if charge_docks.size() == 4:
		charge_docks[3].visible = hired

func _stop_ambient() -> void:
	ambient_robot = -1
	ambient_partner = -1
	ambient_route.clear()
	ambient_wait = 4.0

func _modal_open() -> bool:
	for window in [ai_console, team_chat, workspace, build_dialog, robot_dialog, skill_dialog, company_hq, workflow_builder, mission_board, meeting_room]:
		if is_instance_valid(window) and window.visible:
			return true
	return false

func _face_target(index: int, target: Vector3, delta: float) -> void:
	var pivot := body_pivots[index]
	var yaw := Social.heading(robots[index].position, target, pivot.rotation.y)
	pivot.rotation.y = rotate_toward(pivot.rotation.y, yaw, delta * 5.5)

func _update_ambient(delta: float) -> void:
	if not ambient_enabled or _modal_open():
		_end_conversation()
		_stop_ambient()
		return
	if not dialogue_lines.is_empty():
		_update_conversation(delta)
		return
	if ambient_robot >= 0:
		if ambient_robot == selected or ambient_route.is_empty():
			var first := ambient_robot
			var second := ambient_partner
			_stop_ambient()
			if first != selected and second >= 0 and second != selected:
				_begin_conversation(first, second)
			return
		var robot := robots[ambient_robot]
		var point: Vector3 = ambient_route[0]
		var before := robot.position
		_face_target(ambient_robot, point, delta)
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
		if i == selected or charge_docked[i] or not roster.is_active(ROBOT_IDS[i]) or face_states[i] != "idle":
			continue
		var plan := Navigation.new()
		for j in range(desks.size()):
			if desks[j].visible:
				plan.block_box(desks[j].position, Vector2(1.35, 0.85))
		HQ.block_fixed(plan)
		for j in range(robots.size()):
			if i != j and robots[j].visible:
				plan.block_box(robots[j].position, Vector2(0.85, 0.85))
		# Approach one available colleague from a reachable side.
		for offset in range(1, ROBOT_IDS.size()):
			var j := (i + offset) % ROBOT_IDS.size()
			if j == selected or charge_docked[j] or not robots[j].visible or face_states[j] != "idle":
				continue
			var best: Array[Vector3] = []
			for direction in [Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0), Vector3(0, 0, 1.5), Vector3(0, 0, -1.5)]:
				var target: Vector3 = robots[j].position + direction
				if absf(target.x) > 8.5 or absf(target.z) > 5.5:
					continue
				var candidate: Array[Vector3] = plan.route(robots[i].position, target)
				if not candidate.is_empty() and (best.is_empty() or candidate.size() < best.size()):
					best = candidate
			if not best.is_empty():
				ambient_route = best
				ambient_robot = i
				ambient_partner = j
				return
		# Fall back to a normal patrol if no social approach is reachable.
		var fallback := Vector3(float(i - 1) * 1.5, 0, 0.5 if fmod(face_clock, 20.0) < 10.0 else 1.5)
		ambient_route = plan.route(robots[i].position, fallback)
		if ambient_route.size() > 1:
			ambient_robot = i
			return

func _begin_conversation(first: int, second: int) -> void:
	if first == second or first < 0 or second < 0 or robots[first].position.distance_to(robots[second].position) > 2.0:
		return
	dialogue_lines = Social.dialogue(ROBOT_IDS[first], ROBOT_IDS[second])
	if dialogue_lines.is_empty():
		return
	interaction_ids = [first, second]
	dialogue_turn = 0
	dialogue_elapsed = 0.0
	_show_dialogue_line()

func _show_dialogue_line() -> void:
	for i in interaction_ids:
		speech_labels[i].hide()
	var speaker: int = interaction_ids[Social.speaker(dialogue_turn)]
	speech_labels[speaker].text = dialogue_lines[dialogue_turn]
	speech_labels[speaker].show()
	_play_voice_reply(ROBOT_IDS[speaker], dialogue_lines[dialogue_turn])

func _update_conversation(delta: float) -> void:
	var first: int = interaction_ids[0]
	var second: int = interaction_ids[1]
	_face_target(first, robots[second].position, delta)
	_face_target(second, robots[first].position, delta)
	dialogue_elapsed += delta
	var speaker: int = interaction_ids[Social.speaker(dialogue_turn)]
	var listener: int = interaction_ids[1 - Social.speaker(dialogue_turn)]
	body_pivots[speaker].rotation.x = 0.025 * sin(dialogue_elapsed * 8.0)
	body_pivots[listener].rotation.x = 0.045 * sin(dialogue_elapsed * 3.0)
	if dialogue_elapsed >= Social.duration(dialogue_lines[dialogue_turn]):
		body_pivots[speaker].rotation.x = 0.0
		body_pivots[listener].rotation.x = 0.0
		dialogue_turn += 1
		dialogue_elapsed = 0.0
		if dialogue_turn >= dialogue_lines.size():
			_end_conversation()
			ambient_wait = 5.0
		else:
			_show_dialogue_line()

func _end_conversation() -> void:
	if not interaction_ids.is_empty() and is_instance_valid(voice_player):
		voice_player.stop()
	for i in interaction_ids:
		speech_labels[i].hide()
		body_pivots[i].rotation.x = 0.0
		mouths[i].scale = Vector3.ONE
	interaction_ids.clear()
	dialogue_lines.clear()
	dialogue_turn = 0
	dialogue_elapsed = 0.0

func _swap_decorations() -> void:
	var old := decoration_slot
	decoration_slot = 1 - decoration_slot
	if not _save_layout():
		decoration_slot = old
		layout_status.text = "Could not save decoration layout."
		return
	_refresh_decorations()
	layout_status.text = "Wall decorations rearranged."

func _set_ambient(value: bool) -> void:
	var old := ambient_enabled
	ambient_enabled = value
	if not _save_layout():
		ambient_enabled = old
		idle_check.set_pressed_no_signal(old)
	_end_conversation()
	_stop_ambient()

func _set_sound(value: bool) -> void:
	var old := sound_enabled
	sound_enabled = value
	if not _save_layout():
		sound_enabled = old
		sound_check.set_pressed_no_signal(old)

func _init_audio() -> void:
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = -17.0
	add_child(voice_player)
	sound_player = AudioStreamPlayer.new()
	sound_player.volume_db = -18.0
	add_child(sound_player)
	for entry in [["success", 660.0], ["error", 180.0], ["cancel", 330.0]]:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var samples := PackedByteArray()
		var count := 3307
		samples.resize(count * 2)
		for i in range(count):
			var fade := minf(1.0, float(i) / 220.0) * (1.0 - float(i) / float(count))
			var value := int(sin(TAU * float(entry[1]) * float(i) / 22050.0) * fade * 10000.0)
			samples.encode_s16(i * 2, value)
		wav.data = samples
		tones[entry[0]] = wav

func _play_tone(id: String) -> void:
	if sound_enabled and is_instance_valid(sound_player) and tones.has(id):
		sound_player.stream = tones[id]
		sound_player.play()

func _move_desk_x(direction: int) -> void:
	var index := desk_picker.selected
	if index <= 0 or index >= 4 or busy or not roster.is_active(ROBOT_IDS[index]):
		return
	var center: float = HQ.DESKS[index].x
	var old := desks[index].position.x
	desks[index].position.x = clampf(old + direction * 0.25, center - 0.25, center + 0.25)
	for robot in robots:
		if robot.visible and absf(robot.position.x - desks[index].position.x) <= 1.35 and absf(robot.position.z - desks[index].position.z) <= 0.85:
			desks[index].position.x = old
			layout_status.text = "A robot occupies that space."
			return
	if not _save_layout():
		desks[index].position.x = old
		layout_status.text = "Storage failure; desk movement reverted."
		return
	_rebuild_navigation()
	layout_status.text = "Desk position saved."

func _set_power_mode(value: bool) -> void:
	var old := low_power
	low_power = value
	if not _save_layout():
		low_power = old
		power_check.set_pressed_no_signal(old)
	Engine.max_fps = 30 if low_power else 60

func _show_missions() -> void:
	if meeting_active:
		return
	if busy or selected < 0 or not roster.is_active(ROBOT_IDS[selected]):
		return
	robot_dialog.hide()
	mission_board.call("show_for", ROBOT_IDS[selected], progression, roster)

func _start_mission(robot_id: String, tool: String, payload: String) -> void:
	if meeting_active:
		return
	if busy or not progression.ready or not roster.is_active(robot_id) or not roster.can_use(robot_id, tool):
		return
	var mission: Dictionary = progression.current_mission(robot_id)
	if mission.get("tool") != tool:
		return
	_select_cubot(ROBOT_IDS.find(robot_id))
	_queue(tool, payload)

func _refresh_equipment(robot_id: String) -> void:
	var i := ROBOT_IDS.find(robot_id)
	if i < 0 or i >= equipment_markers.size():
		return
	var entry: Dictionary = progression.snapshot(robot_id)
	var tier := int(entry.get("equipped", -1))
	equipment_markers[i].visible = tier >= 0
	if tier >= 0:
		equipment_markers[i].material_override.albedo_color = [Color("#a8c4d8"), Color("#70d7b1"), Color("#f5d998")][tier]
	cubot_labels[i].text = robot_id.to_upper() + " · Lv " + str(progression.level(robot_id))

func _call_meeting() -> void:
	if busy or ai_console.online_busy or team_chat.get("busy") == true:
		return
	if meeting_active:
		if meeting_walker >= 0 or not meeting_arrivals.is_empty():
			_end_meeting()
			return
		meeting_room.call("show_team", ai_console)
		return
	if _modal_open():
		return
	_select_cubot(-1)
	_end_conversation()
	_stop_ambient()
	tools_panel.hide()
	_interrupt_charging()
	for i in range(robots.size()):
		_wake_cubot(i)
	meeting_active = true
	meeting_button.text = "Cancel meeting"
	meeting_arrivals.clear()
	for i in range(robots.size()):
		if roster.is_active(ROBOT_IDS[i]):
			meeting_arrivals.append(i)
	status.text = "Cubots are walking to the meeting room."
	_next_meeting_arrival()

func _next_meeting_arrival() -> void:
	meeting_walker = -1
	meeting_route.clear()
	if meeting_arrivals.is_empty():
		meeting_button.text = "Meeting"
		status.text = "Team assembled. Enter the project briefing."
		meeting_room.call("show_team", ai_console)
		return
	meeting_walker = meeting_arrivals.pop_front()
	var plan := Navigation.new()
	for i in range(desks.size()):
		if desks[i].visible:
			plan.block_box(desks[i].position, Vector2(1.35,0.85))
	HQ.block_fixed(plan)
	for i in range(robots.size()):
		if i != meeting_walker and robots[i].visible:
			plan.block_box(robots[i].position, Vector2(0.65,0.65))
	meeting_route = plan.route(robots[meeting_walker].position, HQ.SEATS[meeting_walker])
	if meeting_route.is_empty():
		# A blocked seat must not teleport a robot or silently pretend attendance.
		_end_meeting()
		status.text = "Meeting blocked by an occupied route. Try again after the Cubots move."

func _update_meeting(delta: float) -> void:
	if meeting_walker >= 0:
		var index := meeting_walker
		if meeting_route.is_empty():
			_next_meeting_arrival()
			return
		var point: Vector3 = meeting_route[0]
		var robot := robots[index]
		var before := robot.position
		_face_target(index, point, delta)
		robot.position = before.move_toward(point, delta * 3.0 * progression.speed_multiplier(ROBOT_IDS[index]))
		if before.distance_to(robot.position) > 0.001:
			wheels[index].rotate_x(-delta * 7.0)
		if robot.position.distance_to(point) < 0.01:
			meeting_route.pop_front()
		return
	for i in range(robots.size()):
		if not robots[i].visible:
			continue
		var target: Vector3 = HQ.MEETING_CENTER
		if meeting_speaker >= 0 and meeting_speaker != i and face_clock < meeting_line_until:
			target = robots[meeting_speaker].position
		_face_target(i, target, delta)
		if i == meeting_speaker and face_clock < meeting_line_until:
			body_pivots[i].rotation.x = 0.025 * sin(face_clock * 8.0)
		else:
			body_pivots[i].rotation.x = 0.0
			speech_labels[i].hide()
	if meeting_speaker >= 0 and face_clock >= meeting_line_until:
		speech_labels[meeting_speaker].hide()
		meeting_speaker = -1

func _meeting_speaker_changed(id: String, line: String) -> void:
	if not meeting_active:
		return
	for label in speech_labels:
		label.hide()
	meeting_speaker = ROBOT_IDS.find(id)
	if meeting_speaker >= 0:
		speech_labels[meeting_speaker].text = line
		speech_labels[meeting_speaker].show()
		_play_voice_reply(id, line)
		meeting_line_until = face_clock + (20.0 if line == "Thinking…" else 4.0)
		status.text = id.to_upper() + ": " + line.left(85)

func _end_meeting() -> void:
	if is_instance_valid(voice_player):
		voice_player.stop()
	meeting_active = false
	charge_idle = 0.0
	meeting_arrivals.clear()
	meeting_route.clear()
	meeting_walker = -1
	meeting_speaker = -1
	for i in range(speech_labels.size()):
		speech_labels[i].hide()
		body_pivots[i].rotation.x = 0.0
		mouths[i].scale = Vector3.ONE
	meeting_button.text = "Meeting"
	status.text = "Meeting ended. Cubots are available."
	_stop_ambient()

func _review_meeting_plan(plan: Array) -> void:
	if busy or plan.is_empty():
		return
	_end_meeting()
	meeting_plan_pending = true
	workflow_builder.call("review_project", engine, roster, plan)

func _set_voice(value: bool) -> void:
	var old := voice_enabled
	voice_enabled = value
	if not _save_layout():
		voice_enabled = old
		voice_check.set_pressed_no_signal(old)
	if not voice_enabled and is_instance_valid(voice_player):
		voice_player.stop()

func _play_voice_reply(id: String, line: String) -> void:
	if not voice_enabled or not is_instance_valid(voice_player) or not roster.is_active(id) or line.strip_edges().is_empty():
		return
	voice_player.stream = voice_synth.clip(id, CubotVoice.mood(line), line.length())
	voice_player.play()

func _build_charging_docks() -> void:
	for i in range(HQ.DOCKS.size()):
		var dock := Node3D.new()
		add_child(dock)
		dock.position = HQ.DOCKS[i]
		charge_docks.append(dock)
		_slab(dock,Vector3(1.25,0.045,1.25),Vector3(0,0.025,0),Color("#36535d"),0.42)
		_slab(dock,Vector3(1.08,0.022,1.08),Vector3(0,0.055,0),Color("#91b6ae"),0.40)
		_glow(dock,Vector3(0.12,0.018,0.75),Vector3(-0.42,0.076,0),Color("#70d7b1"))
		_glow(dock,Vector3(0.12,0.018,0.75),Vector3(0.42,0.076,0),Color("#70d7b1"))
		var light := _box(dock, Vector3(0.9,0.035,0.10), Vector3(0,0.077,-0.51), Color("#70d7b1"))
		var material: StandardMaterial3D = light.material_override
		material.emission_enabled = true
		material.emission = Color("#70d7b1")
		material.emission_energy_multiplier = 0.05
		charge_lights.append(light)
		var label := Label3D.new()
		label.text = ROBOT_IDS[i].to_upper() + " · DOCK"
		label.position = Vector3(0,0.09,0.50)
		label.rotation.x = -PI / 2.0
		label.font_size = 28
		label.pixel_size = 0.004
		label.outline_size = 0
		label.modulate = Color("#243a43")
		dock.add_child(label)
		charge_labels.append(label)
	_zone_label("CHARGING BAY", Vector3(7.5,0.085,4.35), Color("#36535d"))

func _interrupt_charging() -> void:
	charge_idle = 0.0
	charge_retry = 0.0
	charge_walker = -1
	charge_departing = false
	charge_route.clear()

func _wake_cubot(index: int) -> void:
	if index < 0 or index >= charge_docked.size():
		return
	charge_docked[index] = false
	last_active[index] = face_clock

func _update_charge_indicators(delta: float) -> void:
	for i in range(charge_docks.size()):
		if not roster.is_active(ROBOT_IDS[i]):
			continue
		if charge_docked[i]:
			charge_percent[i] = minf(100.0, float(charge_percent[i]) + delta * 6.0)
		else:
			var active: bool = (busy and selected == i) or meeting_active or ambient_robot == i or charge_walker == i or i in interaction_ids
			var drain := 0.6 if active else 0.16
			charge_percent[i] = maxf(10.0, float(charge_percent[i]) - delta * drain)
		if face_update_wait < 0.08:
			continue
		var material: StandardMaterial3D = charge_lights[i].material_override
		material.emission_energy_multiplier = (0.35 if charge_percent[i] >= 100.0 else 0.3 + 0.25 * sin(face_clock * 3.0)) if charge_docked[i] else 0.05
		var dock_text: String = ("FULL · READY" if charge_percent[i] >= 100.0 else "CHARGING " + str(roundi(float(charge_percent[i]))) + "%") if charge_docked[i] else ROBOT_IDS[i].to_upper() + " · DOCK"
		if charge_labels[i].text != dock_text:
			charge_labels[i].text = dock_text
		var robot_text: String = ROBOT_IDS[i].to_upper() + " · Lv " + str(progression.level(ROBOT_IDS[i])) + (" · " + str(roundi(float(charge_percent[i]))) + "%" if charge_docked[i] else "")
		if cubot_labels[i].text != robot_text:
			cubot_labels[i].text = robot_text

func _charge_path(index: int, target: Vector3) -> Array[Vector3]:
	var plan := Navigation.new()
	for j in range(desks.size()):
		if desks[j].visible:
			plan.block_box(desks[j].position, Vector2(1.35,0.85))
	HQ.block_fixed(plan)
	for j in range(robots.size()):
		if j != index and robots[j].visible:
			plan.block_box(robots[j].position, Vector2(0.65,0.65))
	return plan.route(robots[index].position, target)

func _start_charge_walk(index: int, departing: bool, next_route: Array[Vector3]) -> void:
	_end_conversation()
	_stop_ambient()
	charge_walker = index
	charge_departing = departing
	charge_route = next_route
	if departing:
		_wake_cubot(index)

func _update_charging(delta: float) -> bool:
	if _modal_open() or ai_console.online_busy or team_chat.get("busy") == true:
		_interrupt_charging()
		return false
	charge_idle += delta
	if charge_walker >= 0:
		var i := charge_walker
		if charge_route.is_empty():
			if not charge_departing:
				charge_docked[i] = true
			charge_walker = -1
			charge_departing = false
			ambient_wait = 0.5
			return true
		var target: Vector3 = charge_route[0]
		var robot := robots[i]
		var before := robot.position
		_face_target(i, target, delta)
		robot.position = before.move_toward(target, delta * 2.1)
		if robot.position.distance_to(before) > 0.001:
			wheels[i].rotate_x(-delta * 5.5)
		if robot.position.distance_to(target) < 0.01:
			charge_route.pop_front()
		return true
	charge_retry -= delta
	if charge_retry > 0.0:
		return false
	charge_retry = 2.0
	# Full robots leave their docks and return to the social activity pool.
	# Wait until the current social exchange has ended so bonding stays natural.
	if not dialogue_lines.is_empty():
		return false
	for i in range(robots.size()):
		if not roster.is_active(ROBOT_IDS[i]) or not charge_docked[i] or charge_percent[i] < 100.0:
			continue
		var exit_route := _charge_path(i, HQ.SPAWNS[i])
		if not exit_route.is_empty():
			_start_charge_walk(i, true, exit_route)
			return true
	if charge_idle < CHARGE_IDLE_DELAY:
		return false
	for i in range(robots.size()):
		if i == selected or not roster.is_active(ROBOT_IDS[i]) or charge_docked[i] or charge_percent[i] > CHARGE_THRESHOLD:
			continue
		if robots[i].position.distance_to(HQ.DOCKS[i]) < 0.05:
			charge_docked[i] = true
			continue
		var next_route := _charge_path(i, HQ.DOCKS[i])
		if not next_route.is_empty():
			_start_charge_walk(i, false, next_route)
			return true
	return false

# Flatten the bevelled source mesh after generation, keeping generous plan-view corners.
func _slab(parent: Node3D, size_: Vector3, pos: Vector3, color: Color, radius: float) -> MeshInstance3D:
	var source_height := maxf(size_.y, radius * 2.1)
	var source := Vector3(size_.x,source_height,size_.z)
	var key := str(source) + ":" + str(radius)
	var mesh: ArrayMesh
	if blueprint_meshes.has(key):
		mesh = blueprint_meshes[key]
	else:
		mesh = Geometry.rounded_box(source,radius)
		blueprint_meshes[key] = mesh
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.scale.y = size_.y / source_height
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.74
	node.material_override = mat
	parent.add_child(node)
	return node

func _glow(parent: Node3D, size_: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := _box(parent,size_,pos,color)
	var mat: StandardMaterial3D = node.material_override
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.45
	return node

func _build_wall_display(parent: Node3D, center: Vector3, accent: Color) -> void:
	_slab(parent,Vector3(2.5,0.92,0.12),center,Color("#254955"),0.045)
	_glow(parent,Vector3(2.22,0.065,0.035),center+Vector3(0,0.34,0.085),accent)
	for i in range(4):
		var height := 0.11+0.09*i
		_glow(parent,Vector3(0.18,height,0.035),center+Vector3(0.27+i*0.32,-0.28+height*0.5,0.085),accent)
	for i in range(3):
		_box(parent,Vector3(0.63-i*0.13,0.035,0.025),center+Vector3(-0.63,0.12-i*0.16,0.085),Color("#b8d7d2"))

func _plant(parent: Node3D, center: Vector3, size_: float) -> void:
	_slab(parent,Vector3(size_*1.22,size_*0.42,size_*1.22),center+Vector3(0,size_*0.21,0),Color("#607b78"),size_*0.30)
	_slab(parent,Vector3(size_,0.08,size_),center+Vector3(0,size_*0.43,0),Color("#594c3d"),size_*0.28)
	for i in range(5):
		var angle := TAU*float(i)/5.0
		var leaf := _slab(parent,Vector3(size_*0.35,size_*0.48,size_*0.28),center+Vector3(cos(angle)*size_*0.23,size_*0.69,sin(angle)*size_*0.23),Color("#4f8d66").lightened(float(i)*0.045),size_*0.12)
		leaf.rotation.z = 0.38*cos(angle)
		leaf.rotation.x = 0.38*sin(angle)

func _build_blueprint_lounge() -> void:
	var p: Vector3 = HQ.LOUNGE
	_slab(self,Vector3(1.95,0.03,1.95),p+Vector3(0,0.055,0),Color("#bda37b"),0.65)
	_slab(self,Vector3(1.65,0.29,0.62),p+Vector3(0,0.20,-0.55),Color("#667c7a"),0.22)
	_slab(self,Vector3(1.65,0.18,0.62),p+Vector3(0,0.42,-0.55),Color("#e5d8b8"),0.22)
	_slab(self,Vector3(1.65,0.48,0.17),p+Vector3(0,0.58,-0.83),Color("#80918c"),0.075)
	for side in [-1,1]:
		_slab(self,Vector3(0.19,0.37,0.61),p+Vector3(side*0.76,0.44,-0.53),Color("#80918c"),0.08)
	_slab(self,Vector3(0.68,0.28,0.68),p+Vector3(0,0.20,0.30),Color("#657c7b"),0.29)
	_slab(self,Vector3(0.80,0.11,0.80),p+Vector3(0,0.39,0.30),Color("#eee4d0"),0.34)
	_zone_label("LOUNGE",p+Vector3(0,0.09,1.22),Color("#36535d"))

func _build_blueprint_lab() -> void:
	var p: Vector3 = HQ.LAB
	_slab(self,Vector3(1.35,0.50,0.95),p+Vector3(0,0.30,0),Color("#36535d"),0.28)
	_slab(self,Vector3(1.45,0.14,1.05),p+Vector3(0,0.62,0),Color("#b9d2ca"),0.32)
	_glow(self,Vector3(0.72,0.04,0.72),p+Vector3(0,0.71,0),Color("#70d7b1"))
	var core := _glow(self,Vector3(0.33,0.33,0.33),p+Vector3(0,1.04,0),Color("#8de7dd"))
	core.rotation.y = PI/4.0
	core.rotation.z = PI/6.0

# Use the approved edited GLB when present; keep the procedural model as a safe fallback.
const EDITED_CUBOT_PATH := "res://assets/models/Cubot-update.glb"

func _try_edited_cubot(robot: Node3D, pivot: Node3D, color: Color) -> bool:
	if not ResourceLoader.exists(EDITED_CUBOT_PATH, "PackedScene"):
		return false
	var asset := load(EDITED_CUBOT_PATH) as PackedScene
	if asset == null:
		return false
	var model := asset.instantiate() as Node3D
	if model == null:
		return false
	var body := model.find_child("*_BodyPivot_Body", true, false) as MeshInstance3D
	var roller := model.find_child("*_Roller", true, false) as MeshInstance3D
	var left := model.find_child("*_Eye_L", true, false) as MeshInstance3D
	var right := model.find_child("*_Eye_R", true, false) as MeshInstance3D
	var mouth := model.find_child("*_Mouth", true, false) as MeshInstance3D
	if body == null or roller == null or left == null or right == null or mouth == null:
		push_warning("Edited Cubot GLB is missing named animation parts; using original model.")
		model.free()
		return false
	for face_part in [body,left,right,mouth]:
		if face_part.mesh == null or face_part.mesh.get_surface_count() != 1:
			model.free()
			return false
	# Individual materials keep each Cubot's tint and expressions independent.
	var body_mat := _cubot_local_material(body)
	body_mat.albedo_color = color
	for part in [left,right,mouth]:
		_cubot_local_material(part)
	for part in model.find_children("*Hand_R*", "MeshInstance3D", true, false):
		var hand := part as MeshInstance3D
		if hand.mesh == null:
			continue
		for surface in range(hand.mesh.get_surface_count()):
			var original := hand.get_active_material(surface)
			if original != null and (String(original.resource_name).contains("Hand_R_material") or (hand.mesh.get_surface_count() == 2 and surface == 1)):
				hand.set_surface_override_material(surface,body_mat)
	pivot.add_child(model)
	# Separate the roller from the yaw/nod pivot, retaining the source transform.
	roller.reparent(robot, true)
	robot_bodies.append(body)
	wheels.append(roller)
	var pair: Array[MeshInstance3D] = [left,right]
	eyes.append(pair)
	mouths.append(mouth)
	return true

func _cubot_local_material(part: MeshInstance3D) -> StandardMaterial3D:
	var source := part.get_active_material(0) as StandardMaterial3D
	var mat := source.duplicate() as StandardMaterial3D if source != null else StandardMaterial3D.new()
	part.material_override = mat
	return mat
