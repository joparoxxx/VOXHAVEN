extends SceneTree
const World = preload("res://world/voxel_world.gd")
const Save = preload("res://world/world_save.gd")
func _initialize() -> void:
	var world := World.new(987)
	var p := Vector3i(-17,20,5)
	world.set_block(p,World.Block.GOLD)
	var path := "user://world-test.json"
	var ok := Save.save(world,path)
	var restored := Save.restore(path)
	ok = ok and restored != null
	if restored != null:
		ok = ok and restored.world_seed == 987 and restored.block_at(p) == World.Block.GOLD
		ok = ok and restored.generate_chunk(Vector2i(-2,0)) == world.generate_chunk(Vector2i(-2,0))
	DirAccess.remove_absolute(path)
	print("World persistence: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
