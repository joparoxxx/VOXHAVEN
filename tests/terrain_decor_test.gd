extends SceneTree
const World = preload("res://world/voxel_world.gd")
const Decor = preload("res://world/terrain_decor.gd")
func _initialize() -> void:
	var a := World.new(123)
	var b := World.new(123)
	var ok := true
	var count := 0
	for z in range(-8,9):
		for x in range(-8,9):
			var key := Vector2i(x,z)
			var positions := Decor.tree_positions(a,key)
			ok = ok and positions == Decor.tree_positions(b,key)
			for p in positions:
				count += 1
				ok = ok and a.chunk_of(p)==key and a.block_at(p)==World.Block.AIR
				ok = ok and a.block_at(p-Vector3i.UP)==World.Block.GRASS
	ok = ok and count>0
	print("Decoration test: ", "PASS" if ok else "FAIL", " trees=",count)
	quit(0 if ok else 1)
