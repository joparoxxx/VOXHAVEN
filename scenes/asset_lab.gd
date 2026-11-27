extends Node3D
const SAMPLES = [
	"assets/library/KayKit_BlockBits_1.0_FREE/Assets/gltf/grass.gltf",
	"assets/library/KayKit_Adventurers_2.0_FREE/KayKit_Adventurers_2.0_FREE/Characters/gltf/Knight.glb",
	"assets/library/KayKit_RPGToolsBits_1.0_FREE/Assets/gltf/pickaxe.gltf",
	"assets/library/kenney_fantasy-town-kit_2.0/Models/GLB format/cart.glb",
	"assets/library/Quaternius_Cube_World/Environment/Tree_1.gltf",
	"assets/library/Quaternius_Cube_World/Environment/Tree_2.gltf",
	"assets/library/Quaternius_Cube_World/Environment/Tree_3.gltf",
	"assets/library/Quaternius_Cube_World/Tools/Axe_Diamond.gltf",
	"assets/library/Quaternius_Cube_World/Tools/Axe_Gold.gltf",
	"assets/library/Quaternius_Cube_World/Tools/Axe_Stone.gltf",
	"assets/library/Quaternius_Cube_World/Tools/Shovel_Diamond.gltf",
	"assets/library/Quaternius_Cube_World/Tools/Shovel_Gold.gltf",
	"assets/library/Quaternius_Cube_World/Tools/Shovel_Stone.gltf",
	"assets/library/Quaternius_Cube_World/Tools/Shovel_Wood.gltf",
	"assets/library/KayKit_ResourceBits_1.0_FREE/Assets/gltf/Copper_Bar.gltf",
	"assets/library/KayKit_ResourceBits_1.0_FREE/Assets/gltf/Copper_Bars.gltf",
	"assets/library/KayKit_ResourceBits_1.0_FREE/Assets/gltf/Copper_Bars_Stack_Large.gltf",
	"assets/library/KayKit_Furniture_Bits_1.0_FREE/KayKit_Furniture_Bits_1.0_FREE/Assets/gltf/armchair.gltf",
	"assets/library/KayKit_Furniture_Bits_1.0_FREE/KayKit_Furniture_Bits_1.0_FREE/Assets/gltf/armchair_pillows.gltf",
	"assets/library/KayKit_Furniture_Bits_1.0_FREE/KayKit_Furniture_Bits_1.0_FREE/Assets/gltf/bed_double_A.gltf",
	"assets/library/kenney_fantasy-town-kit_2.0/Models/GLB format/balcony-wall-fence.glb",
	"assets/library/kenney_fantasy-town-kit_2.0/Models/GLB format/balcony-wall.glb",
	"assets/library/kenney_fantasy-town-kit_2.0/Models/GLB format/banner-green.glb"
]
var camera: Camera3D
var yaw := 0.7
var distance := 24.0
var failures := 0

func _ready() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.make_current()
	update_camera()
	for i in SAMPLES.size():
		var model := Assets.instantiate_asset(SAMPLES[i])
		if model == null:
			failures += 1
			push_error("Missing sample: " + SAMPLES[i])
			continue
		add_child(model)
		model.position = Vector3((i % 5 - 2) * 4.0, 0.05, (floori(float(i) / 5.0) - 2) * 4.0)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var valid_meshes := 0
		for child in meshes:
			var mesh_node := child as MeshInstance3D
			if mesh_node.mesh == null:
				continue
			var bounds := mesh_node.get_aabb()
			if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.length() <= 0.0001:
				continue
			valid_meshes += 1
			print("Mesh bounds: ", SAMPLES[i], " ", bounds, " pivot: ", mesh_node.position)
			for surface in mesh_node.mesh.get_surface_count():
				print("Surface material: ", mesh_node.get_active_material(surface))
		if valid_meshes == 0:
			failures += 1
			push_error("No valid mesh geometry: " + SAMPLES[i])
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if SAMPLES[i].ends_with("/Knight.glb"):
			var skeletons := model.find_children("*", "Skeleton3D", true, false)
			var has_rig := false
			for child in skeletons:
				var skeleton := child as Skeleton3D
				if skeleton.get_bone_count() > 0:
					has_rig = true
			if not has_rig:
				failures += 1
				push_error("Knight has no populated skeleton")
		for player in players:
			for clip in player.get_animation_list():
				print("Animation: ", clip)
				if "idle" in clip.to_lower():
					player.play(clip)
					break
	print("Asset lab: ", SAMPLES.size() - failures, "/", SAMPLES.size())
	if "--smoke" in OS.get_cmdline_user_args():
		get_tree().quit(1 if failures > 0 else 0)

func update_camera() -> void:
	camera.size = distance
	camera.position = Vector3(sin(yaw) * 12, 10, cos(yaw) * 12)
	camera.look_at(Vector3.ZERO)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		yaw -= event.relative.x * 0.006
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * 0.006
	elif event is InputEventMagnifyGesture:
		distance = clampf(distance / event.factor, 4, 24)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(4, distance - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(24, distance + 1)
	update_camera()
