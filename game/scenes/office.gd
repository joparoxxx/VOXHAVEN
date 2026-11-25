extends Node3D
const TaskEngine = preload("res://core/task_engine.gd")
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
	_build_office()
	_build_ui()
	engine.task_changed.connect(_on_task_changed)
	if not engine.is_ready():
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
	title.text = "CUBYTE | Local prototype"
	column.add_child(title)
	selection = OptionButton.new()
	for id in ROBOT_IDS:
		selection.add_item(id.to_upper())
	selection.item_selected.connect(func(index: int): selected = index)
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
	preview.custom_minimum_size = Vector2(128, 128)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(preview)

func _queue(tool: String, payload: String) -> void:
	if busy:
		return
	pending_id = engine.enqueue(ROBOT_IDS[selected], tool, payload)
	if pending_id.is_empty():
		status.text = "Task rejected."
		return
	busy = true
	progress_timer = 0.0
	selection.disabled = true
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
	run_text.disabled = not engine.is_ready()
	run_png.disabled = not engine.is_ready()
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
