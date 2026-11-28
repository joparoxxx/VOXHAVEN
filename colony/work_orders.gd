extends RefCounted
## Unified Mine command: chopping standing trees, mining blocks and excavation.
## UI uses this one dispatcher. No terrain model or asset substitution occurs.
const World = preload("res://world/voxel_world.gd")
const Mining = preload("res://colony/mining_jobs.gd")
const Woodcut = preload("res://colony/woodcut_jobs.gd")
const Dig = preload("res://colony/dig_planner.gd")

static func single(world: World, mining: Mining, woodcut: Woodcut, dig: Dig, p: Vector3i, depth: int) -> Dictionary:
	if mining.is_tree_base(p):
		var tree := p + Vector3i.UP
		if woodcut.designations.has(tree):
			woodcut.cancel(tree)
			return {"job":"cancel_tree","message":"Tree cutting cancelled"}
		if woodcut.designate(tree):
			return {"job":"tree","message":"Tree marked for woodcutting"}
		return {"job":"none","message":"Cannot assign this tree"}
	if mining.is_worker_above(p):
		return {"job":"none","message":"Cannot mine below a colonist"}
	if mining.is_tree_above(p):
		return {"job":"none","message":"Tree above: cut the tree first"}
	if depth == 1:
		if mining.designations.has(p):
			mining.cancel(p)
			return {"job":"cancel_mine","message":"Block mining cancelled"}
		if mining.designate(p):
			return {"job":"mine","message":"Block marked for mining"}
		return {"job":"none","message":"Cannot mine this block"}
	var count := dig.request_area(p,p,depth)
	if count > 0:
		return {"job":"dig","message":"Excavation queued: %d layers" % depth}
	return {"job":"none","message":"No valid excavation here"}

static func area(world: World, mining: Mining, woodcut: Woodcut, dig: Dig, first: Vector3i, last: Vector3i, depth: int) -> Dictionary:
	var x0 := mini(first.x,last.x)
	var x1 := maxi(first.x,last.x)
	var z0 := mini(first.z,last.z)
	var z1 := maxi(first.z,last.z)
	if (x1-x0+1)*(z1-z0+1) > Dig.MAX_COLUMNS:
		return {"columns":0,"trees":[],"message":"Select up to 64 ground cells"}
	var marked_trees: Array[Vector3i] = []
	for z in range(z0,z1+1):
		for x in range(x0,x1+1):
			var surface := mini(world.surface_at(x,z),World.HEIGHT-2)
			while surface > 0 and world.block_at(Vector3i(x,surface,z)) == World.Block.AIR:
				surface -= 1
			var ground := Vector3i(x,surface,z)
			if mining.is_tree_base(ground):
				var tree := ground + Vector3i.UP
				if woodcut.designate(tree):
					marked_trees.append(tree)
	var columns := dig.request_area(first,last,depth)
	return {"columns":columns,"trees":marked_trees,"message":"Mine queued: %d columns, %d trees, %d layers deep" % [columns,marked_trees.size(),depth]}
