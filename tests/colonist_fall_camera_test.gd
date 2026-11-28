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
	var failures: Array[String] = []
	var ok: bool = _check(c.position == original, "initial worker cell", failures)
	world.set_block(Vector3i(0,30,0),World.Block.AIR)
	colony.advance(Colony.STEP)
	var landed := Vector3i(0,28,0)
	ok = _check(c.position == landed, "worker lands on floor below removed block", failures) and ok
	ok = _check(c.activity == "Falling", "worker enters falling state", failures) and ok
	ok = _check(c.route.is_empty(), "old path cleared on fall", failures) and ok
	ok = _check(colony.active_job_count(c.id) == 0, "old job assignments cleared on fall", failures) and ok
	visual.sync_state(c,0.05)
	ok = _check(visual.position.y < float(original.y), "visual descends instead of snapping or floating", failures) and ok
	ok = _check(visual.position.y > float(landed.y), "visual remains above landing after one short frame", failures) and ok
	for frame in range(20):
		visual.sync_state(c,0.05)
	ok = _check(absf(visual.position.y-float(landed.y)) < 0.02, "visual settles at landing after frames", failures) and ok
	colony.advance(Colony.STEP)
	ok = _check(c.position == landed and c.activity != "Blocked", "worker remains grounded and navigable after next step", failures) and ok
	var anchor := Vector3(2,5,7)
	var camera_position := CameraRig.position_for(anchor,1.1,0.8,40.0)
	ok = _check(absf(camera_position.distance_to(anchor)-40.0)<0.001, "orbit camera radius preserved", failures) and ok
	var top := CameraRig.orbit_angles(0.0,1.0,Vector2(0,10000))
	var bottom := CameraRig.orbit_angles(0.0,1.0,Vector2(0,-10000))
	ok = _check(top.y <= CameraRig.MAX_PITCH and bottom.y >= CameraRig.MIN_PITCH, "vertical pitch clamps", failures) and ok
	ok = _check(absf(CameraRig.orbit_angles(0.0,0.8,Vector2(100,0)).x) > 0.1, "horizontal yaw drag", failures) and ok
	var pan := CameraRig.pan_delta(Vector2(40,20),0.0,30.0,300.0)
	ok = _check(pan.x < 0.0 and pan.z < 0.0, "camera free pan direction", failures) and ok
	print("Gravity, falling animation and free-orbit camera: ", "PASS" if ok else "FAIL")
	if not ok:
		print("Gravity diagnostic: failures=", failures, " cell=",c.position," state=",c.activity," route=",c.route," visual_y=",visual.position.y," orbit=",camera_position," angles=",top," / ",bottom)
	visual.free()
	quit(0 if ok else 1)

func _check(condition: bool, description: String, failures: Array[String]) -> bool:
	if not condition:
		failures.append(description)
	return condition
