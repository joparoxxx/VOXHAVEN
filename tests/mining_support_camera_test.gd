extends SceneTree
## Mining is forbidden under living colonists / standing trees. Grid gravity
## is restored for legacy save holes and terrain changes outside the Mine tool.
const World = preload("res://world/voxel_world.gd")
const Colony = preload("res://colony/colony_simulation.gd")
const Mining = preload("res://colony/mining_jobs.gd")
const Decor = preload("res://world/terrain_decor.gd")
const WorkOrders = preload("res://colony/work_orders.gd")
const CameraRig = preload("res://world/camera_rig.gd")

func _initialize() -> void:
	var world := World.new(378)
	for x in range(-2,3):
		for z in range(-2,3):
			for y in [48,49]:
				world.set_block(Vector3i(x,y,z),World.Block.STONE)
			for y in [50,51]:
				world.set_block(Vector3i(x,y,z),World.Block.AIR)
	var support := Vector3i(0,49,0)
	var deep := Vector3i(0,48,0)
	var feet := Vector3i(0,50,0)
	var nearby := Vector3i(1,50,0)
	var colony := Colony.new()
	colony.initialize(feet)
	colony.terrain = world
	colony.mining.terrain = world
	colony.dig.terrain = world
	colony.woodcut.terrain = world
	colony.logistics.terrain = world
	var failures: Array[String] = []
	var ok := _check(colony.mining.workers.size() == 3,"live worker registration",failures)
	for i in colony.colonists.size():
		colony.set_role(colony.colonists[i].id,["Miner","Woodcutter","Hauler"][i])
	ok = _check(colony.mining.is_worker_above(support),"colonist protects support",failures) and ok
	ok = _check(colony.mining.is_worker_above(deep),"colonist protects deeper block",failures) and ok
	ok = _check(not colony.mining.designate(support),"cannot designate occupied support",failures) and ok
	ok = _check(not colony.mining.designate(deep),"cannot designate below occupied support",failures) and ok
	var command: Dictionary = WorkOrders.single(world,colony.mining,colony.woodcut,colony.dig,support,1)
	ok = _check(str(command["job"]) == "none","unified Mine refuses protected block",failures) and ok
	ok = _check(colony.dig.request_area(support,support,2) == 0,"area dig skips worker column",failures) and ok
	for tick in range(8):
		colony.advance(Colony.STEP)
	ok = _check(colony.colonists[0].position == feet,"worker stays at original feet with gravity removed",failures) and ok
	ok = _check(world.block_at(support) == World.Block.STONE,"support remains solid",failures) and ok
	# A previous mining assignment is not enough: the completion phase checks
	# the current occupants after the work animation, just before set_block.
	for c in colony.colonists:
		c.position = nearby
	var miner = colony.colonists[0]
	ok = _check(colony.mining.designate(support),"safe block may be designated",failures) and ok
	ok = _check(colony.mining.reserve(miner),"miner reserves reachable safe block",failures) and ok
	colony.colonists[1].position = feet
	ok = _check(not colony.mining.complete(miner),"occupied target cannot complete mining",failures) and ok
	ok = _check(world.block_at(support) == World.Block.STONE,"completion guard preserves block",failures) and ok
	ok = _check(colony.mining.designations.has(support),"blocked job stays pending",failures) and ok
	ok = _check(not colony.mining.has_assignment(miner.id),"blocked reservation released",failures) and ok
	colony.colonists[1].position = nearby
	ok = _check(colony.mining.reserve(miner),"job can restart when occupant leaves",failures) and ok
	ok = _check(colony.mining.complete(miner),"safe unoccupied target can be mined",failures) and ok
	ok = _check(world.block_at(support) == World.Block.AIR,"successful mine removes only safe target",failures) and ok
	# Old saves or direct terrain changes can still remove support outside Mine.
	# The restored gravity must land the character on the next solid floor.
	var same_pos: Vector3i = miner.position
	world.set_block(same_pos+Vector3i.DOWN,World.Block.AIR)
	colony.advance(Colony.STEP)
	ok = _check(miner.position == same_pos+Vector3i.DOWN,"gravity restored for unsafe legacy edit",failures) and ok
	# Trees protect their grass root block and deeper voxels, until chopped.
	var forest := World.new(123)
	var tree := Vector3i.ZERO
	var found := false
	for cz in range(-5,6):
		if found:
			break
		for cx in range(-5,6):
			var candidates := Decor.tree_positions(forest,Vector2i(cx,cz))
			if not candidates.is_empty():
				tree = candidates[0]
				found = true
				break
	ok = _check(found,"forest tree fixture exists",failures) and ok
	if found:
		var tree_mine := Mining.new()
		tree_mine.terrain = forest
		var root := tree+Vector3i.DOWN
		ok = _check(tree_mine.is_tree_base(root),"tree root recognized",failures) and ok
		ok = _check(tree_mine.is_tree_above(root+Vector3i.DOWN),"tree protects deep block",failures) and ok
		ok = _check(not tree_mine.designate(root),"cannot mine tree root",failures) and ok
		ok = _check(not tree_mine.designate(root+Vector3i.DOWN),"cannot mine below tree",failures) and ok
		tree_mine.harvested_trees[tree] = true
		ok = _check(not tree_mine.is_tree_above(root),"chopped tree no longer protects root",failures) and ok
		ok = _check(tree_mine.designate(root),"root may be mined only after tree is cut",failures) and ok
	# The camera's existing orbital math is retained without changes.
	var anchor := Vector3(2,5,7)
	var pose := CameraRig.position_for(anchor,1.1,0.8,40.0)
	ok = _check(absf(pose.distance_to(anchor)-40.0)<0.001,"camera orbit remains unchanged",failures) and ok
	var angles := CameraRig.orbit_angles(0.0,1.0,Vector2(0,10000))
	ok = _check(angles.y <= CameraRig.MAX_PITCH+0.0001,"camera pitch remains bounded",failures) and ok
	if not ok:
		print("Mining protection diagnostics: ",failures," target=",world.block_at(support)," roles=",colony.worker_roles()," tree=",tree)
	print("Protected mining / restored gravity / camera regression: ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _check(condition: bool,description: String,failures: Array[String]) -> bool:
	if not condition:
		failures.append(description)
	return condition
