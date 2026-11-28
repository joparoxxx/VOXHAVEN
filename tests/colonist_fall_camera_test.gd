extends SceneTree
## Regression: a worker physically drops to the first available supported
## voxel after the floor is removed; orbital camera math stays bounded.
const World = preload("res://world/voxel_world.gd")
const Colony = preload("res://colony/colony_simulation.gd")
const CameraRig = preload("res://world/camera_rig.gd")
const View = preload("res://colony/colonist_view.gd")

func _initialize() -> void:
	var world := World.new(378)
	var original := Vector3i(0,31,0)
	for y in range(27,33):
		world.set_block(Vector3i(0,y,0),World.Block.AIR)
	world.set_block(Vector3i(0,27,0),World.Block.STONE)
	world.set_block(Vector3i(0,30,0),World.Block.STONE)
	var colony := Colony.new()
	colony.initialize(original)
	colony.terrain = world
	colony.mining.terrain = world
	colony.woodcut.terrain = world
	colony.logistics.terrain = world
	colony.dig.terrain = world
	colony.colonists[1].health = 0.0
	colony.colonists[2].health = 0.0
	var c = colony.colonists[0]
	c.route.append(Vector3i(1,31,0))
	var visual := View.new()
	get_root().add_child(visual)
	visual.setup(c)
	var ok := c.position == original
	ok = ok and world.set_block(Vector3i(0,30,0),World.Block.AIR)
	colony.advance(Colony.STEP)
	var landed := Vector3i(0,28,0)
	ok = ok and c.position == landed
	ok = ok and c.activity == "Falling"
	ok = ok and c.route.is_empty()
	ok = ok and colony.active_job_count(c.id) == 0
	visual.sync_state(c,0.05)
	ok = ok and visual.position.y < float(original.y)
	ok = ok and visual.position.y > float(landed.y)
	for frame in range(20):
		visual.sync_state(c,0.05)
	ok = ok and absf(visual.position.y-float(landed.y)) < 0.02
	colony.advance(Colony.STEP)
	ok = ok and c.position == landed and c.activity != "Blocked"
	var anchor := Vector3(2,5,7)
	var camera_position := CameraRig.position_for(anchor,1.1,0.8,40.0)
	ok = ok and absf(camera_position.distance_to(anchor)-40.0)<0.001
	var top := CameraRig.orbit_angles(0.0,1.0,Vector2(0,10000))
	var bottom := CameraRig.orbit_angles(0.0,1.0,Vector2(0,-10000))
	ok = ok and top.y <= CameraRig.MAX_PITCH and bottom.y >= CameraRig.MIN_PITCH
	ok = ok and absf(CameraRig.orbit_angles(0.0,0.8,Vector2(100,0)).x) > 0.1
	var pan := CameraRig.pan_delta(Vector2(40,20),0.0,30.0,300.0)
	ok = ok and pan.x < 0.0 and pan.z < 0.0
	print("Gravity, falling animation and free-orbit camera: ", "PASS" if ok else "FAIL")
	if not ok:
		print("Gravity diagnostic: cell=",c.position," visual_y=",visual.position.y," orbit=",camera_position," angles=",top," / ",bottom)
	visual.free()
	quit(0 if ok else 1)
