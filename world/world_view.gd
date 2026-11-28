extends Node3D
const World = preload("res://world/voxel_world.gd")
const Mesher = preload("res://world/chunk_mesh.gd")
const Save = preload("res://world/world_save.gd")
const Decor = preload("res://world/terrain_decor.gd")
const Atlas = preload("res://world/terrain_atlas.gd")
const Colony = preload("res://colony/colony_simulation.gd")
const ColonistView = preload("res://colony/colonist_view.gd")
const StockpileView = preload("res://world/stockpile_view.gd")
const Nav = preload("res://colony/navigation.gd")
const ResourceTypes = preload("res://colony/resource_types.gd")
const WorkOrders = preload("res://colony/work_orders.gd")
const TOOL_OPTIONS := ["Pan","Place","Stockpile","Inspect","Cancel","Reset Camera"]
const CameraRig = preload("res://world/camera_rig.gd")
const ROLES := ["Miner","Woodcutter","Hauler"]
var colony := Colony.new()
var colonist_views: Dictionary = {}
var atlas: Dictionary = {}
const SAVE_PATH := "user://world.json"
# CHUNK_SIZE in voxel_world.gd is fixed at 16x16. Keep the original
# zoom-based loading/unloading radius; do not conflate it with chunk dimensions.
const MIN_RADIUS := 2
const MAX_RADIUS := 4
const HUD_UPDATE_INTERVAL := 0.25
const UNLOAD_BUFFER := 1
var render_radius := MIN_RADIUS
var worker := Thread.new()
var active_key := Vector2i.ZERO
var revision := 0
var active_revision := 0
var action_mode := "Mine"
var dig_depth := 2
var depth_label: Label
var selection_first := Vector3i.ZERO
var selection_last := Vector3i.ZERO
var selection_stage := 0
var selection_preview: MeshInstance3D
var select_drag_active := false
var stockpile_view: StockpileView
var woodcut_markers: Dictionary = {}
var designation_markers: Dictionary = {}
var status: Label
var world := World.new(123)
var chunks: Dictionary = {}
var pending: Array[Vector2i] = []
var focus := Vector3(8,28,8)
var camera: Camera3D
var material := ShaderMaterial.new()
var yaw := 0.7
var pitch := 0.785398
var camera_control_enabled := false
var camera_switch: Button
var home_focus := Vector3.ZERO
var simulation_speed := 1.0
var selected_index := 0
var worker_button: Button
var job_menu: MenuButton
var info: Label
var speed_button: Button
var autosave_elapsed := 0.0
var hud_elapsed := 0.0
# Match the pre-orbit range; extra-wide zoom revealed much more terrain
# and caused expensive render/input spikes on Android.
const MIN_ZOOM := 12.0
const MAX_ZOOM := 48.0
var zoom := 32.0
# Touch input can deliver multiple events during one rendered frame. Apply
# only the latest camera transform and a single streaming check per frame.
var camera_dirty := false
var chunk_check_dirty := false
var pinch_reference_distance := 0.0
var pinch_reference_zoom := 32.0
var center_chunk := Vector2i(999999,999999)

func _ready() -> void:
	if not "--world-smoke" in OS.get_cmdline_user_args():
		var restored := Save.restore(SAVE_PATH)
		if restored != null: world = restored
	var spawn := world.find_spawn()
	focus = Vector3(spawn)+Vector3(0.5,1.0,0.5)
	home_focus = focus
	atlas = Atlas.build_lookup()
	# Keep the user's Cube World pixel texture, but soften high-frequency detail
	# and mute strong greens/browns without changing source assets or block data.
	material.shader = preload("res://world/terrain_soft_palette.gdshader")
	material.set_shader_parameter("terrain_texture", load(Atlas.TEXTURE_PATH) as Texture2D)
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
	colony.mining.terrain = world
	colony.woodcut.terrain = world
	colony.dig.terrain = world
	colony.dig.queued.connect(show_mining_marker)
	colony.mining.mined.connect(_on_block_mined)
	colony.woodcut.chopped.connect(_on_tree_chopped)
	colony.logistics.delivered.connect(_on_resources_delivered)
	if not "--world-smoke" in OS.get_cmdline_user_args():
		colony.mining.restore_jobs(Save.restore_mining_jobs(SAVE_PATH))
		colony.logistics.restore(Save.restore_logistics(SAVE_PATH))
		colony.woodcut.restore(Save.restore_woodcut(SAVE_PATH))
		colony.dig.restore(Save.restore_dig(SAVE_PATH))
		var saved_roles := Save.restore_worker_roles(SAVE_PATH)
		for i in mini(saved_roles.size(),colony.colonists.size()):
			colony.set_role(colony.colonists[i].id,saved_roles[i])
		for p in colony.mining.designations:
			show_mining_marker(p)
		for p in colony.woodcut.designations:
			show_woodcut_marker(p)
	stockpile_view = StockpileView.new()
	add_child(stockpile_view)
	refresh_stockpile()
	selection_preview = MeshInstance3D.new()
	selection_preview.mesh = BoxMesh.new()
	var selection_material := StandardMaterial3D.new()
	selection_material.albedo_color = Color(0.2,0.72,1.0,0.35)
	selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_preview.material_override = selection_material
	selection_preview.visible = false
	add_child(selection_preview)
	var layer := CanvasLayer.new()
	add_child(layer)
	# Compact two-row mobile toolbar; secondary actions are in popup menus.
	# Flow containers wrap gracefully on smaller Android viewports.
	var panel := PanelContainer.new()
	panel.position = Vector2(10,10)
	panel.custom_minimum_size.x = minf(720.0,maxf(280.0,get_viewport().get_visible_rect().size.x-20.0))
	layer.add_child(panel)
	var controls := VBoxContainer.new()
	panel.add_child(controls)
	var main_bar := HFlowContainer.new()
	controls.add_child(main_bar)
	for label in ["Mine","Select"]:
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(78,44)
		main_bar.add_child(button)
		button.pressed.connect(select_action.bind(label))
	var tools := MenuButton.new()
	tools.text = "Tools"
	tools.custom_minimum_size = Vector2(76,44)
	main_bar.add_child(tools)
	for i in TOOL_OPTIONS.size():
		tools.get_popup().add_item(TOOL_OPTIONS[i],i)
	tools.get_popup().id_pressed.connect(_on_tool_selected)
	worker_button = Button.new()
	worker_button.custom_minimum_size = Vector2(78,44)
	main_bar.add_child(worker_button)
	worker_button.pressed.connect(test_control.bind("Worker"))
	job_menu = MenuButton.new()
	job_menu.custom_minimum_size = Vector2(100,44)
	main_bar.add_child(job_menu)
	for i in ROLES.size():
		job_menu.get_popup().add_item(ROLES[i],i)
	job_menu.get_popup().id_pressed.connect(_on_role_selected)
	# One switch replaces fixed 45-degree rotate buttons; touch gestures
	# always provide full orbital rotation, pitch, pan and pinch zoom.
	camera_switch = Button.new()
	camera_switch.text = "Camera OFF"
	camera_switch.toggle_mode = true
	camera_switch.custom_minimum_size = Vector2(106,44)
	main_bar.add_child(camera_switch)
	camera_switch.toggled.connect(_on_camera_control_toggled)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.custom_minimum_size = Vector2(65,44)
	main_bar.add_child(save_button)
	save_button.pressed.connect(select_action.bind("Save"))
	var quick_bar := HFlowContainer.new()
	controls.add_child(quick_bar)
	for step in [-1,1]:
		var depth_button := Button.new()
		depth_button.text = "-" if step < 0 else "+"
		depth_button.custom_minimum_size = Vector2(44,40)
		quick_bar.add_child(depth_button)
		depth_button.pressed.connect(adjust_depth.bind(step))
		if step < 0:
			depth_label = Label.new()
			depth_label.text = "Depth: %d" % dig_depth
			depth_label.custom_minimum_size = Vector2(88,40)
			depth_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			quick_bar.add_child(depth_label)
	for direction in [-1,1]:
		var zoom_button := Button.new()
		zoom_button.text = "Zoom +" if direction < 0 else "Zoom -"
		zoom_button.custom_minimum_size = Vector2(86,40)
		quick_bar.add_child(zoom_button)
		zoom_button.pressed.connect(step_zoom.bind(direction))
	speed_button = Button.new()
	speed_button.text = "1x"
	speed_button.custom_minimum_size = Vector2(55,40)
	quick_bar.add_child(speed_button)
	speed_button.pressed.connect(test_control.bind("1x"))
	status = Label.new()
	status.text = "Mine: tap a tree's ground or a block; Select for an area"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(status)
	info = Label.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(info)
	_refresh_worker_buttons()

func _on_tool_selected(index: int) -> void:
	if index < 0 or index >= TOOL_OPTIONS.size():
		return
	if TOOL_OPTIONS[index] == "Reset Camera":
		reset_camera()
	else:
		select_action(TOOL_OPTIONS[index])

func _on_camera_control_toggled(enabled: bool) -> void:
	# Camera ON behaves like a 3D object viewer: orbit around a fixed pivot.
	# No automatic follow or camera motion while the user is idle.
	camera_control_enabled = enabled
	if camera_switch != null:
		camera_switch.text = "Camera ON" if enabled else "Camera OFF"
	if status != null:
		status.text = "Camera ON: drag orbit, tap to set pivot, pinch zoom, two-finger pan" if enabled else "Camera OFF: use Mine/Select tools, drag to pan"

func reset_camera() -> void:
	camera_control_enabled = false
	focus = home_focus
	yaw = 0.7
	pitch = 0.785398
	zoom = 32.0
	if camera_switch != null:
		camera_switch.set_pressed_no_signal(false)
		camera_switch.text = "Camera OFF"
	camera_dirty = true
	chunk_check_dirty = true

func _on_role_selected(index: int) -> void:
	if index < 0 or index >= ROLES.size() or selected_index >= colony.colonists.size():
		return
	var selected = colony.colonists[selected_index]
	if colony.set_role(selected.id,ROLES[index]):
		_refresh_worker_buttons()
		status.text = "%s assigned: %s" % [selected.display_name,selected.job_role]

func _refresh_worker_buttons() -> void:
	if colony.colonists.is_empty() or selected_index < 0:
		return
	if worker_button != null:
		worker_button.text = "Worker %d" % (selected_index+1)
	if job_menu != null:
		job_menu.text = colony.colonists[selected_index].job_role

func test_control(action: String) -> void:
	match action:
		"Reset": reset_camera()
		"Colonist", "Worker":
			if not colony.colonists.is_empty():
				selected_index = (selected_index+1)%colony.colonists.size()
				_refresh_worker_buttons()
		"1x":
			simulation_speed = fmod(simulation_speed+1.0,4.0)
			speed_button.text = "Pause" if simulation_speed == 0.0 else "%dx" % int(simulation_speed)

func update_info() -> void:
	if info == null: return
	info.text = "FPS: %d | Chunks: %d | Colony time: %ds | Mining: %d | Excavations: %d | Trees: %d | Drops: %d | Stock: %d" % [Engine.get_frames_per_second(),chunks.size(),int(colony.elapsed),colony.mining.designations.size(),colony.dig.columns.size(),colony.woodcut.designations.size(),colony.logistics.unhauled_units(),colony.logistics.stored_units()]
	if selected_index >= 0 and selected_index < colony.colonists.size():
		var c = colony.colonists[selected_index]
		info.text += "\n%s / %s / %s | HP %d | Stamina %d" % [c.display_name,c.job_role,c.activity,int(c.health),int(c.stamina)]

func save_colony() -> bool:
	return Save.save(world,SAVE_PATH,colony.mining.jobs_snapshot(),colony.logistics.snapshot(),colony.woodcut.snapshot(),colony.dig.snapshot(),colony.worker_roles())

func adjust_depth(direction: int) -> void:
	dig_depth = clampi(dig_depth+direction,1,colony.dig.MAX_DEPTH)
	depth_label.text = "Dig depth: %d" % dig_depth

func clear_selection() -> void:
	selection_stage = 0
	if selection_preview != null:
		selection_preview.visible = false

func selection_count() -> int:
	if selection_stage == 0:
		return 0
	return (absi(selection_first.x-selection_last.x)+1)*(absi(selection_first.z-selection_last.z)+1)

func update_selection_preview() -> void:
	if selection_preview == null:
		return
	selection_preview.visible = selection_stage != 0
	if selection_stage == 0:
		return
	var x0 := mini(selection_first.x,selection_last.x)
	var x1 := maxi(selection_first.x,selection_last.x)
	var z0 := mini(selection_first.z,selection_last.z)
	var z1 := maxi(selection_first.z,selection_last.z)
	var mesh := selection_preview.mesh as BoxMesh
	mesh.size = Vector3(float(x1-x0+1),0.055,float(z1-z0+1))
	selection_preview.position = Vector3(float(x0+x1+1)*0.5,float(maxi(selection_first.y,selection_last.y))+1.08,float(z0+z1+1)*0.5)
	var paint := selection_preview.material_override as StandardMaterial3D
	paint.albedo_color = Color(1.0,0.42,0.1,0.4) if selection_count()>colony.dig.MAX_COLUMNS else Color(0.2,0.72,1.0,0.35)

func _record_selection(p: Vector3i) -> void:
	if selection_stage != 1:
		selection_first = p
		selection_last = p
		selection_stage = 1
	else:
		selection_last = p
		selection_stage = 2
	update_selection_preview()
	status.text = "Selected: %d columns | Press Mine (depth %d)" % [selection_count(),dig_depth]

func _ray_hit(screen: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(screen)
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(screen)*200.0))

func _select_screen(screen: Vector2) -> void:
	var hit := _ray_hit(screen)
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"]
	if normal.y < 0.8:
		status.text = "Select the top face of ground blocks"
		return
	var point: Vector3 = hit["position"]
	_record_selection(Vector3i((point-normal*0.01).floor()))

func _mine_selected() -> void:
	var result := WorkOrders.area(world,colony.mining,colony.woodcut,colony.dig,selection_first,selection_last,dig_depth)
	for tree in result["trees"]:
		show_woodcut_marker(tree)
	status.text = str(result["message"])
	if int(result["columns"]) > 0 or not result["trees"].is_empty():
		clear_selection()
		action_mode = "Select"

func _cancel_area() -> void:
	if selection_stage == 0:
		action_mode = "Cancel"
		status.text = "Cancel: tap a mining designation or tree base"
		return
	# The planner removes owned jobs, so clear their marker nodes first.
	var x0_pending := mini(selection_first.x,selection_last.x)
	var x1_pending := maxi(selection_first.x,selection_last.x)
	var z0_pending := mini(selection_first.z,selection_last.z)
	var z1_pending := maxi(selection_first.z,selection_last.z)
	for key in colony.dig.owned.keys():
		var p: Vector3i = key
		if p.x>=x0_pending and p.x<=x1_pending and p.z>=z0_pending and p.z<=z1_pending:
			remove_mining_marker(p)
	var count := colony.dig.cancel_area(selection_first,selection_last)
	var x0 := mini(selection_first.x,selection_last.x)
	var x1 := maxi(selection_first.x,selection_last.x)
	var z0 := mini(selection_first.z,selection_last.z)
	var z1 := maxi(selection_first.z,selection_last.z)
	for key in colony.mining.designations.keys():
		var p: Vector3i = key
		if p.x>=x0 and p.x<=x1 and p.z>=z0 and p.z<=z1:
			colony.mining.cancel(p)
			remove_mining_marker(p)
	for key in colony.woodcut.designations.keys():
		var p: Vector3i = key
		if p.x>=x0 and p.x<=x1 and p.z>=z0 and p.z<=z1:
			colony.woodcut.cancel(p)
			remove_woodcut_marker(p)
	status.text = "Cancelled %d excavation columns and work in area" % count
	clear_selection()
	action_mode = "Select"

func select_action(action: String) -> void:
	match action:
		"Save":
			status.text = "Saved" if save_colony() else "Save failed"
			return
		"Mine":
			if selection_stage > 0:
				_mine_selected()
				return
		"Cancel":
			if selection_stage > 0:
				_cancel_area()
				return
	action_mode = action
	match action:
		"Mine": status.text = "Mine: tap terrain to dig or a tree to cut; Depth %d" % dig_depth
		"Select": status.text = "Select: tap two corners or drag, then press Mine"
		"Pan": status.text = "Pan: drag to move the camera"
		"Stockpile": status.text = "Stockpile: tap walkable ground"
		"Place": status.text = "Place: tap a surface"
		"Inspect": status.text = "Inspect: tap any block"
		"Cancel": status.text = "Cancel: tap a designation to remove"

func pick_block(screen: Vector2) -> void:
	if action_mode == "Pan":
		return
	if action_mode == "Select":
		_select_screen(screen)
		return
	var hit := _ray_hit(screen)
	if hit.is_empty():
		return
	var placing := action_mode == "Place" or action_mode == "Stockpile"
	var point: Vector3 = hit.position + hit.normal * (0.01 if placing else -0.01)
	var p := Vector3i(point.floor())
	match action_mode:
		"Inspect":
			var block := world.block_at(p)
			status.text = "%s at %s | Surface y=%d" % [str(World.Block.keys()[block]),str(p),world.surface_at(p.x,p.z)]
		"Cancel":
			for key in colony.dig.owned.keys():
				var target: Vector3i = key
				if target.x == p.x and target.z == p.z:
					remove_mining_marker(target)
			var count := colony.dig.cancel_area(p,p)
			var mined := colony.mining.cancel(p)
			var tree := p + Vector3i.UP
			var chopped := colony.woodcut.cancel(tree)
			remove_mining_marker(p)
			if chopped:
				remove_woodcut_marker(tree)
			status.text = "Cancelled %d dig columns; mining %s, tree %s" % [count,str(mined),str(chopped)]
		"Place":
			if edit_block(p,World.Block.DIRT):
				status.text = "Block placed"
		"Stockpile":
			if hit.normal.y < 0.9:
				status.text = "Choose a flat top surface for storage"
			elif not Nav.standable(world,p):
				status.text = "Stockpile requires walkable ground"
			elif not _workers_can_reach(p):
				status.text = "No colonist can reach this stockpile"
			elif colony.logistics.set_depot(p):
				# A carrier headed to the previous depot must select a new route.
				for c in colony.colonists:
					if colony.logistics.carried.has(c.id):
						c.route.clear()
				refresh_stockpile()
				status.text = "Stockpile moved to %s" % str(p)
		"Mine":
			var result := WorkOrders.single(world,colony.mining,colony.woodcut,colony.dig,p,dig_depth)
			match str(result["job"]):
				"tree": show_woodcut_marker(p+Vector3i.UP)
				"cancel_tree": remove_woodcut_marker(p+Vector3i.UP)
				"mine": show_mining_marker(p)
				"cancel_mine": remove_mining_marker(p)
			status.text = str(result["message"])

func _workers_can_reach(p: Vector3i) -> bool:
	for c in colony.colonists:
		if c.health <= 0.0:
			continue
		if c.position == p or not Nav.route(world,c.position,p).is_empty():
			return true
	return false

func show_mining_marker(p: Vector3i) -> void:
	if designation_markers.has(p):
		return
	var marker := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 1.025
	marker.mesh = cube
	var overlay := StandardMaterial3D.new()
	overlay.albedo_color = Color(1.0, 0.65, 0.1, 0.27)
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	marker.material_override = overlay
	marker.position = Vector3(p) + Vector3.ONE * 0.5
	add_child(marker)
	designation_markers[p] = marker

func remove_mining_marker(p: Vector3i) -> void:
	if designation_markers.has(p):
		designation_markers[p].queue_free()
		designation_markers.erase(p)

func show_woodcut_marker(p: Vector3i) -> void:
	if woodcut_markers.has(p):
		return
	var marker := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(0.85,0.08,0.85)
	marker.mesh = slab
	marker.position = Vector3(p) + Vector3(0.5,0.08,0.5)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.93,0.47,0.12,0.6)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = paint
	add_child(marker)
	woodcut_markers[p] = marker

func remove_woodcut_marker(p: Vector3i) -> void:
	if woodcut_markers.has(p):
		woodcut_markers[p].queue_free()
		woodcut_markers.erase(p)

func refresh_stockpile() -> void:
	if stockpile_view != null:
		stockpile_view.update_stock(colony.logistics.depot,colony.logistics.stored_units(),int(colony.logistics.inventory.get(ResourceTypes.WOOD,0)))

func _on_tree_chopped(p: Vector3i, amount: int) -> void:
	remove_woodcut_marker(p)
	queue_chunk_rebuild(p)
	if status != null:
		status.text = "Tree chopped: %d wood ready to haul" % amount

func _on_block_mined(p: Vector3i, _block: int) -> void:
	remove_mining_marker(p)
	queue_chunk_rebuild(p)
	if status != null:
		status.text = "Colonist mined %s" % str(p)

func _on_resources_delivered(block: int, amount: int) -> void:
	refresh_stockpile()
	if status != null:
		status.text = "Stockpiled %d %s" % [amount,ResourceTypes.display_name(block)]

func step_zoom(direction: int) -> void:
	set_zoom(zoom * pow(1.2,direction))

func set_zoom(value: float) -> void:
	var clamped := clampf(value,MIN_ZOOM,MAX_ZOOM)
	if absf(clamped-zoom) < 0.01:
		return
	zoom = clamped
	camera_dirty = true
	chunk_check_dirty = true

func update_camera() -> void:
	camera.size = zoom
	camera.position = CameraRig.position_for(focus,yaw,pitch,40.0)
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
	# Gesture events are batched here, not applied separately at touch rate.
	if camera_dirty:
		camera_dirty = false
		update_camera()
	if chunk_check_dirty:
		chunk_check_dirty = false
		refresh_chunks()
	if simulation_speed > 0.0: colony.advance(_delta*simulation_speed)
	hud_elapsed += _delta
	if hud_elapsed >= HUD_UPDATE_INTERVAL:
		hud_elapsed = 0.0
		update_info()
	if not "--world-smoke" in OS.get_cmdline_user_args():
		autosave_elapsed += _delta
		if autosave_elapsed >= 60.0:
			autosave_elapsed = 0.0
			if not save_colony(): status.text = "Autosave failed"
	for colonist in colony.colonists:
		if colonist_views.has(colonist.id):
			var view = colonist_views[colonist.id]
			view.visible = chunks.has(world.chunk_of(colonist.position)) and colonist.health > 0.0
			view.sync_state(colonist,_delta*simulation_speed)
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
	Decor.populate(world,key,node,colony.woodcut.harvested)
	chunks[key] = node

func edit_block(p: Vector3i, block: int) -> bool:
	if not world.set_block(p,block): return false
	if colony.mining.cancel(p):
		remove_mining_marker(p)
	var tree := p + Vector3i.UP
	if colony.woodcut.cancel(tree):
		remove_woodcut_marker(tree)
	queue_chunk_rebuild(p)
	return true

func queue_chunk_rebuild(p: Vector3i) -> void:
	revision += 1
	var key := world.chunk_of(p)
	for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var affected: Vector2i = key+offset
		if chunks.has(affected) and not pending.has(affected): pending.append(affected)

var touch_points: Dictionary = {}
var touch_start := Vector2.ZERO
var touch_dragged := false
var multi_touch := false
var mouse_start := Vector2.ZERO
var mouse_dragged := false

func pan_camera(movement: Vector2) -> void:
	if movement.length_squared() < 0.01:
		return
	var height := get_viewport().get_visible_rect().size.y
	focus += CameraRig.pan_delta(movement,yaw,zoom,height)
	camera_dirty = true
	chunk_check_dirty = true

func orbit_camera(movement: Vector2) -> void:
	if movement.length_squared() < 0.01:
		return
	var angles := CameraRig.orbit_angles(yaw,pitch,movement)
	yaw = angles.x
	pitch = angles.y
	camera_dirty = true

func _tap_world(screen: Vector2) -> void:
	if camera_control_enabled:
		var hit := _ray_hit(screen)
		if not hit.is_empty():
			# Object-viewer pivot: tap the surface to orbit around it.
			focus = Vector3(hit["position"])+Vector3(0,0.5,0)
			camera_dirty = true
			chunk_check_dirty = true
		return
	if action_mode != "Pan":
		pick_block(screen)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_points.is_empty():
				touch_start = event.position
				touch_dragged = false
				multi_touch = false
				select_drag_active = false
			touch_points[event.index] = event.position
			if touch_points.size() == 2:
				multi_touch = true
				select_drag_active = false
				var fingers := touch_points.values()
				pinch_reference_distance = (fingers[0] as Vector2).distance_to(fingers[1] as Vector2)
				pinch_reference_zoom = zoom
			elif touch_points.size() > 2:
				multi_touch = true
		elif touch_points.has(event.index):
			touch_points.erase(event.index)
			if touch_points.size() < 2:
				pinch_reference_distance = 0.0
			if touch_points.is_empty() and not multi_touch and not event.canceled:
				if action_mode == "Select" and touch_dragged and select_drag_active:
					selection_stage = 2
					status.text = "Selected: %d columns | Press Mine (depth %d)" % [selection_count(),dig_depth]
				elif not touch_dragged:
					_tap_world(event.position)
			select_drag_active = false
		return
	if event is InputEventScreenDrag:
		if not touch_points.has(event.index):
			return
		if touch_points.size() == 2:
			var other := Vector2.ZERO
			for index in touch_points:
				if index != event.index:
					other = touch_points[index]
			var previous: Vector2 = touch_points[event.index]
			var new_distance: float = event.position.distance_to(other)
			# Absolute pinch reference prevents drift when two fingers translate.
			# Small temporary distance jitter does not start a chunk reload.
			if pinch_reference_distance > 12.0 and new_distance > 12.0:
				var target_zoom := pinch_reference_zoom*pinch_reference_distance/new_distance
				if absf(target_zoom-zoom) >= 0.08:
					set_zoom(target_zoom)
			# Two-finger translation always pans, regardless of orbit mode.
			pan_camera((event.position-previous)*0.5)
		elif touch_points.size() == 1 and not multi_touch:
			if event.position.distance_to(touch_start) > 12.0:
				touch_dragged = true
			if touch_dragged and action_mode == "Select" and not camera_control_enabled:
				if not select_drag_active:
					var first_hit := _ray_hit(touch_start)
					if not first_hit.is_empty():
						var n: Vector3 = first_hit["normal"]
						if n.y > 0.8:
							var location: Vector3 = first_hit["position"]
							selection_first = Vector3i((location-n*0.01).floor())
							selection_last = selection_first
							selection_stage = 1
							select_drag_active = true
				if select_drag_active:
					var hit := _ray_hit(event.position)
					if not hit.is_empty():
						var n: Vector3 = hit["normal"]
						if n.y > 0.8:
							var location: Vector3 = hit["position"]
							selection_last = Vector3i((location-n*0.01).floor())
							update_selection_preview()
			elif touch_dragged and camera_control_enabled:
				orbit_camera(event.relative)
			elif touch_dragged:
				pan_camera(event.relative)
		touch_points[event.index] = event.position
		return
	if event is InputEventMagnifyGesture:
		if touch_points.is_empty():
			set_zoom(zoom/maxf(event.factor,0.01))
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			step_zoom(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			step_zoom(1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_start = event.position
				mouse_dragged = false
			elif not mouse_dragged:
				_tap_world(event.position)
	elif event is InputEventMouseMotion and touch_points.is_empty():
		if (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			orbit_camera(event.relative)
		elif (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if event.position.distance_to(mouse_start) > 8.0:
				mouse_dragged = true
			if mouse_dragged and action_mode == "Select" and selection_stage > 0 and not camera_control_enabled:
				var hit := _ray_hit(event.position)
				if not hit.is_empty():
					var n: Vector3 = hit["normal"]
					if n.y > 0.8:
						var location: Vector3 = hit["position"]
						selection_last = Vector3i((location-n*0.01).floor())
						update_selection_preview()
			elif mouse_dragged and camera_control_enabled:
				orbit_camera(event.relative)
			elif mouse_dragged:
				pan_camera(event.relative)

func spawn_colony(spawn: Vector3i) -> void:
	colony.initialize(spawn+Vector3i.UP)
	colony.terrain = world
	for i in colony.colonists.size():
		colony.set_role(colony.colonists[i].id,ROLES[i])
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
