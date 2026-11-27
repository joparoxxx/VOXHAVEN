extends Node3D
const World = preload("res://world/voxel_world.gd")
const Mesher = preload("res://world/chunk_mesh.gd")
const Save = preload("res://world/world_save.gd")
const Decor = preload("res://world/terrain_decor.gd")
const Atlas = preload("res://world/terrain_atlas.gd")
const Colony = preload("res://colony/colony_simulation.gd")
const ColonistView = preload("res://colony/colonist_view.gd")
var colony := Colony.new()
var colonist_views: Dictionary = {}
var atlas: Dictionary = {}
const SAVE_PATH := "user://world.json"
const MIN_RADIUS := 2
const MAX_RADIUS := 4
const UNLOAD_BUFFER := 1
var render_radius := MIN_RADIUS
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
const MIN_ZOOM := 12.0
const MAX_ZOOM := 48.0
var zoom := 32.0
var center_chunk := Vector2i(999999,999999)

func _ready() -> void:
	if not "--world-smoke" in OS.get_cmdline_user_args():
		var restored := Save.restore(SAVE_PATH)
		if restored != null: world = restored
	var spawn := world.find_spawn()
	focus = Vector3(spawn)+Vector3(0.5,1.0,0.5)
	atlas = Atlas.build_lookup()
	material.albedo_texture = load(Atlas.ROOT+"block_bits_texture.png")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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
	spawn_colony(spawn)
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
	for direction in [-1,1]:
		var zoom_button := Button.new()
		zoom_button.text = "+" if direction < 0 else "-"
		zoom_button.custom_minimum_size = Vector2(56,48)
		bar.add_child(zoom_button)
		zoom_button.pressed.connect(step_zoom.bind(direction))
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

func step_zoom(direction: int) -> void:
	set_zoom(zoom * pow(1.2,direction))

func set_zoom(value: float) -> void:
	zoom = clampf(value,MIN_ZOOM,MAX_ZOOM)
	update_camera()
	refresh_chunks()

func update_camera() -> void:
	camera.size = zoom
	camera.position = focus + Vector3(sin(yaw)*40,40,cos(yaw)*40)
	camera.look_at(focus)

func refresh_chunks() -> void:
	var next := world.chunk_of(Vector3i(focus.floor()))
	var viewport_size := get_viewport().get_visible_rect().size
	var desired := clampi(ceili(zoom * maxf(1.0,viewport_size.x/maxf(1.0,viewport_size.y)) / 32.0)+1,MIN_RADIUS,MAX_RADIUS)
	if "--world-smoke" in OS.get_cmdline_user_args(): desired = MIN_RADIUS
	if next == center_chunk and desired == render_radius: return
	center_chunk = next
	render_radius = desired
	pending.clear()
	for key in chunks.keys():
		if absi(key.x-next.x)>render_radius+UNLOAD_BUFFER or absi(key.y-next.y)>render_radius+UNLOAD_BUFFER:
			chunks[key].queue_free()
			chunks.erase(key)
	for z in range(-render_radius,render_radius+1):
		for x in range(-render_radius,render_radius+1):
			var key := next+Vector2i(x,z)
			if not chunks.has(key) and not (worker.is_started() and key == active_key and active_revision == revision): pending.append(key)
	pending.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.distance_squared_to(center_chunk) < b.distance_squared_to(center_chunk))

func _process(_delta: float) -> void:
	colony.advance(_delta)
	for colonist in colony.colonists:
		if colonist_views.has(colonist.id):
			var view = colonist_views[colonist.id]
			view.visible = chunks.has(world.chunk_of(colonist.position)) and colonist.health > 0.0
			view.sync_state(colonist,_delta)
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
		if worker.start(Mesher.generate.bind(snapshot,active_key,atlas)) != OK:
			build_chunk(active_key,Mesher.upload(Mesher.generate(snapshot,active_key,atlas)))
	if "--world-smoke" in OS.get_cmdline_user_args() and pending.is_empty() and not worker.is_started():
		get_tree().quit(0 if chunks.size() == (MIN_RADIUS*2+1)*(MIN_RADIUS*2+1) else 1)

func in_window(key: Vector2i) -> bool:
	return absi(key.x-center_chunk.x)<=render_radius and absi(key.y-center_chunk.y)<=render_radius

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
	Decor.populate(world,key,node)
	chunks[key] = node

func edit_block(p: Vector3i, block: int) -> bool:
	if not world.set_block(p,block): return false
	revision += 1
	var key := world.chunk_of(p)
	for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var affected: Vector2i = key+offset
		if chunks.has(affected) and not pending.has(affected): pending.append(affected)
	return true

var touch_points: Dictionary = {}
var touch_start := Vector2.ZERO
var touch_dragged := false
var multi_touch := false

func pan_camera(movement: Vector2) -> void:
	var height := maxf(1.0,get_viewport().get_visible_rect().size.y)
	focus += Vector3(-movement.x,0,-movement.y).rotated(Vector3.UP,yaw)*zoom/height
	update_camera()
	refresh_chunks()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_points.is_empty():
				touch_start = event.position
				touch_dragged = false
				multi_touch = false
			touch_points[event.index] = event.position
			if touch_points.size() > 1: multi_touch = true
		elif touch_points.has(event.index):
			touch_points.erase(event.index)
			if touch_points.is_empty() and not multi_touch and not touch_dragged and not event.canceled:
				pick_block(event.position)
		return
	if event is InputEventScreenDrag:
		if not touch_points.has(event.index): return
		if touch_points.size() == 2:
			var other := Vector2.ZERO
			for index in touch_points:
				if index != event.index: other = touch_points[index]
			var previous: Vector2 = touch_points[event.index]
			var old_distance := previous.distance_to(other)
			var new_distance := event.position.distance_to(other)
			if old_distance > 8.0 and new_distance > 8.0:
				set_zoom(zoom * old_distance / new_distance)
		elif touch_points.size() == 1 and not multi_touch:
			if event.position.distance_to(touch_start) > 12: touch_dragged = true
			if touch_dragged: pan_camera(event.relative)
		touch_points[event.index] = event.position
		return
	if event is InputEventMagnifyGesture:
		if touch_points.is_empty(): set_zoom(zoom/maxf(event.factor,0.01))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT: pick_block(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: step_zoom(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: step_zoom(1)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and touch_points.is_empty():
		pan_camera(event.relative)

func spawn_colony(spawn: Vector3i) -> void:
	colony.initialize(spawn+Vector3i.UP)
	colony.terrain = world
	var candidates: Array[Vector3i] = []
	for radius in range(0,9):
		for z in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				if maxi(absi(x),absi(z)) != radius: continue
				for y in range(World.HEIGHT-2,0,-1):
					var p := Vector3i(spawn.x+x,y,spawn.z+z)
					if world.block_at(p-Vector3i.UP) != World.Block.AIR and world.block_at(p) == World.Block.AIR and world.block_at(p+Vector3i.UP) == World.Block.AIR:
						candidates.append(p)
						break
				if candidates.size() >= 3: break
			if candidates.size() >= 3: break
		if candidates.size() >= 3: break
	for i in mini(candidates.size(),colony.colonists.size()):
		var colonist = colony.colonists[i]
		colonist.position = candidates[i]
		var view := ColonistView.new()
		add_child(view)
		view.setup(colonist)
		view.visible = false
		colonist_views[colonist.id] = view
