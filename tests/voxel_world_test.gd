extends SceneTree
const World = preload("res://world/voxel_world.gd")
func _initialize() -> void:
	var a := World.new(123)
	var b := World.new(123)
	# Regression: a chunk is always 16x16 horizontal block columns,
	# regardless of the loading radius or viewport.
	var ok: bool = World.CHUNK_SIZE == 16
	ok = ok and a.generate_chunk(Vector2i(-1, 0)) == b.generate_chunk(Vector2i(-1, 0))
	ok = ok and a.generate_chunk(Vector2i.ZERO).size() == World.CHUNK_SIZE * World.CHUNK_SIZE * World.HEIGHT
	ok = ok and a.chunk_of(Vector3i(15,0,15)) == Vector2i.ZERO
	ok = ok and a.chunk_of(Vector3i(16,0,16)) == Vector2i.ONE
	ok = ok and a.chunk_of(Vector3i(-16,0,-16)) == Vector2i(-1,-1)
	ok = ok and a.chunk_of(Vector3i(-1, 0, -17)) == Vector2i(-1, -2)
	var p := Vector3i(-1, a.surface_at(-1, 0), 0)
	ok = ok and a.set_block(p, World.Block.AIR)
	ok = ok and a.block_at(p) == World.Block.AIR
	ok = ok and not a.set_block(Vector3i(0, -1, 0), World.Block.STONE)
	var data := a.generate_chunk(Vector2i(-1, 0))
	ok = ok and data[(p.y * 16) * 16 + 15] == World.Block.AIR
	print("Voxel data test: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
