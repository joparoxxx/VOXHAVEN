extends SceneTree
const World = preload("res://world/voxel_world.gd")
func _initialize() -> void:
	var a := World.new(123)
	var b := World.new(123)
	var ok := a.generate_chunk(Vector2i(-1, 0)) == b.generate_chunk(Vector2i(-1, 0))
	ok = ok and a.chunk_of(Vector3i(-1, 0, -17)) == Vector2i(-1, -2)
	var p := Vector3i(-1, a.surface_at(-1, 0), 0)
	ok = ok and a.set_block(p, World.Block.AIR)
	ok = ok and a.block_at(p) == World.Block.AIR
	ok = ok and not a.set_block(Vector3i(0, -1, 0), World.Block.STONE)
	var data := a.generate_chunk(Vector2i(-1, 0))
	ok = ok and data[(p.y * 16) * 16 + 15] == World.Block.AIR
	print("Voxel data test: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
