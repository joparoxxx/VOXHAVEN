extends SceneTree
const Decision = preload("res://colony/decision.gd")
const Nav = preload("res://colony/navigation.gd")
const World = preload("res://world/voxel_world.gd")
func _initialize() -> void:
	var world := World.new(123)
	var start := Vector3i(0,50,0)
	for x in range(5):
		world.set_block(Vector3i(x,49,0),World.Block.STONE)
		world.set_block(Vector3i(x,50,0),World.Block.AIR)
		world.set_block(Vector3i(x,51,0),World.Block.AIR)
	var path := Nav.route(world,start,start+Vector3i(4,0,0))
	if path.size()!=4 or Decision.plan("explored")!=["observe","wander"] or Decision.plan("rested")!=["rest"]:
		quit(1)
		return
	print("Colony AI passed")
	quit(0)
