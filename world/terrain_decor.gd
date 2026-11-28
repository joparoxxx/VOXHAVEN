extends RefCounted
const World = preload("res://world/voxel_world.gd")
# Imported Cube World trees stand about 6–8 source units high; resize to
# balance their silhouettes against 0.65-scaled, ~1.8-unit humanoids.
const TREE_SCALE := 0.56
const TREES = [preload("res://assets/library/Quaternius_Cube_World/Environment/Tree_1.gltf"), preload("res://assets/library/Quaternius_Cube_World/Environment/Tree_2.gltf"), preload("res://assets/library/Quaternius_Cube_World/Environment/Tree_3.gltf")]

static func tree_positions(world: World, key: Vector2i, harvested: Dictionary = {}) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(2,16,4):
		for x in range(2,16,4):
			var gx := key.x*16+x
			var gz := key.y*16+z
			if world.biome_at(gx,gz) != World.Biome.FOREST: continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector3i(gx,world.world_seed,gz))
			if rng.randf()>0.45: continue
			var p := Vector3i(gx,world.surface_at(gx,gz),gz)
			if world.block_at(p)==World.Block.GRASS and world.block_at(p+Vector3i.UP)==World.Block.AIR and not harvested.has(p+Vector3i.UP):
				result.append(p+Vector3i.UP)
	return result

static func populate(world: World, key: Vector2i, parent: Node3D, harvested: Dictionary = {}) -> void:
	for p in tree_positions(world,key,harvested):
		var tree := TREES[posmod(hash(p), TREES.size())].instantiate() as Node3D
		if tree == null: continue
		tree.scale = Vector3.ONE * TREE_SCALE
		parent.add_child(tree)
		tree.position = Vector3(p)-parent.position+Vector3(0.5,0,0.5)
