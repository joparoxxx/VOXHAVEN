extends Node3D
const World = preload("res://world/voxel_world.gd")
const Mesher = preload("res://world/chunk_mesh.gd")
const Save = preload("res://world/world_save.gd")
const SAVE_PATH := "user://world.json"
const RADIUS := 1
var worker := Thread.new()
var active_key := Vector2i.ZERO
var revision := 0
var active_revision := 0
var place_mode := false
var status: Label
var world := World.new(123)
var chunks: Dictionary = {}
var pending: Array[Vector2i] = []
var focus := Vector3(8,28,8)
var camera: Camera3D
var material := StandardMaterial3D.new()
var yaw := 0.7
var zoom := 32.0
var center_chunk := Vector2i(999999,999999)

func _ready() -> void:
	if not "--world-smoke" in OS.get_cmdline_user_args():
		var restored := Save.restore(SAVE_PATH)
		if restored != null: world = restored
	var spawn := world.find_spawn()
	focus = Vector3(spawn)+Vector3(0.5,1.0,0.5)
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-35,0)
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("91b7d0")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.make_current()
	update_camera()
	refresh_chunks()
	var layer := CanvasLayer.new()
	add_child(layer)
	var bar := HBoxContainer.new()
	bar.position = Vector2(16,16)
	layer.add_child(bar)
	for title in ["Mine","Place","Save"]:
		var button := Button.new()
		button.text = title
		button.custom_minimum_size = Vector2(90,48)
		bar.add_child(button)
		button.pressed.connect(select_action.bind(title))
	status = Label.new()
	status.text = "Mine: right click or tap terrain"
	bar.add_child(status)

func select_action(action: String) -> void:
	if action == "Save":
		status.text = "Saved" if Save.save(world,SAVE_PATH) else "Save failed"
	else:
		place_mode = action == "Place"
		status.text = action + ": right click or tap terrain"

func pick_block(screen: Vector2) -> void:
	var start := camera.project_ray_origin(screen)
	var end := start + camera.project_ray_normal(screen)*200.0
	var query := PhysicsRayQueryParameters3D.create(start,end)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var point: Vector3 = hit.position + hit.normal*(0.01 if place_mode else -0.01)
	var p := Vector3i(point.floor())
	if edit_block(p,World.Block.DIRT if place_mode else World.Block.AIR):
		status.text = "Block placed" if place_mode else "Block mined"

func update_camera() -> void:
	camera.size = zoom
	camera.position = focus + Vector3(sin(yaw)*40,40,cos(yaw)*40)
	camera.look_at(focus)

func refresh_chunks() -> void:
	var next := world.chunk_of(Vector3i(focus.floor()))
	if next == center_chunk: return
	center_chunk = next
	pending.clear()
	for key in chunks.keys():
		if absi(key.x-next.x)>RADIUS or absi(key.y-next.y)>RADIUS:
			chunks[key].queue_free()
			chunks.erase(key)
	for z in range(-RADIUS,RADIUS+1):
		for x in range(-RADIUS,RADIUS+1):
			var key := next+Vector2i(x,z)
			if not chunks.has(key): pending.append(key)

func _process(_delta: float) -> void:
	if worker.is_started() and not worker.is_alive():
		var arrays: Array = worker.wait_to_finish()
		if active_revision == revision and in_window(active_key):
			build_chunk(active_key,Mesher.upload(arrays))
		elif in_window(active_key) and not pending.has(active_key):
			pending.append(active_key)
	if not worker.is_started() and not pending.is_empty():
		active_key = pending.pop_front()
		active_revision = revision
		var snapshot := World.new(world.world_seed)
		snapshot.edits = world.edits.duplicate()
		if worker.start(Mesher.generate.bind(snapshot,active_key)) != OK:
			build_chunk(active_key,Mesher.build(snapshot,active_key))
	if "--world-smoke" in OS.get_cmdline_user_args() and pending.is_empty() and not worker.is_started():
		get_tree().quit(0 if chunks.size() == 9 else 1)

func in_window(key: Vector2i) -> bool:
	return absi(key.x-center_chunk.x)<=RADIUS and absi(key.y-center_chunk.y)<=RADIUS

func _exit_tree() -> void:
	if worker.is_started(): worker.wait_to_finish()

func build_chunk(key: Vector2i, mesh: ArrayMesh) -> void:
	if chunks.has(key):
		chunks[key].queue_free()
		chunks.erase(key)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = Vector3(key.x*16,0,key.y*16)
	add_child(node)
	if mesh.get_surface_count()>0: node.create_trimesh_collision()
	chunks[key] = node

func edit_block(p: Vector3i, block: int) -> bool:
	if not world.set_block(p,block): return false
	revision += 1
	var key := world.chunk_of(p)
	for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var affected: Vector2i = key+offset
		if chunks.has(affected) and not pending.has(affected): pending.append(affected)
	return true

var touch_start := Vector2.ZERO
var touch_dragged := false
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
			touch_dragged = false
		elif not touch_dragged:
			pick_block(event.position)
	if event is InputEventScreenDrag and event.position.distance_to(touch_start)>12:
		touch_dragged = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		pick_block(event.position)
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		var movement: Vector2 = event.relative
		focus += Vector3(-movement.x,0,-movement.y).rotated(Vector3.UP,yaw)*zoom/720.0
	elif event is InputEventMagnifyGesture:
		zoom = clampf(zoom/maxf(event.factor,0.01),12,64)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(12,zoom-2)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(64,zoom+2)
	update_camera()
	refresh_chunks()
