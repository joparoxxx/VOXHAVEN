extends Node3D
const World = preload("res://world/voxel_world.gd")
const Mesher = preload("res://world/chunk_mesh.gd")
const RADIUS := 1
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
	if not pending.is_empty():
		var key: Vector2i = pending.pop_front()
		build_chunk(key)
	if "--world-smoke" in OS.get_cmdline_user_args() and pending.is_empty():
		get_tree().quit(0 if chunks.size() == 9 else 1)

func build_chunk(key: Vector2i) -> void:
	if chunks.has(key):
		chunks[key].queue_free()
		chunks.erase(key)
	var mesh := Mesher.build(world,key)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = Vector3(key.x*16,0,key.y*16)
	add_child(node)
	if mesh.get_surface_count()>0: node.create_trimesh_collision()
	chunks[key] = node

func edit_block(p: Vector3i, block: int) -> bool:
	if not world.set_block(p,block): return false
	var key := world.chunk_of(p)
	for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var affected: Vector2i = key+offset
		if chunks.has(affected) and not pending.has(affected): pending.append(affected)
	return true

func _unhandled_input(event: InputEvent) -> void:
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
