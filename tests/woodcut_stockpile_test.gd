extends SceneTree
const World = preload("res://world/voxel_world.gd")
const Decor = preload("res://world/terrain_decor.gd")
const Nav = preload("res://colony/navigation.gd")
const Colony = preload("res://colony/colony_simulation.gd")
const Resources = preload("res://colony/resource_types.gd")
const Save = preload("res://world/world_save.gd")

func _initialize() -> void:
	var world := World.new(123)
	var tree := Vector3i.ZERO
	var starting_cell := Vector3i.ZERO
	var found := false
	var next_tree := Vector3i.ZERO
	for cz in range(-5,6):
		if found:
			break
		for cx in range(-5,6):
			if found:
				break
			for p in Decor.tree_positions(world,Vector2i(cx,cz)):
				for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.BACK,Vector3i.FORWARD]:
					if Nav.standable(world,p+d):
						tree = p
						starting_cell = p+d
						found = true
						break
				if found:
					break
	if not found:
		push_error("Fixture: could not find reachable seeded tree")
		quit(1)
		return
	var colony := Colony.new()
	colony.initialize(starting_cell)
	colony.terrain = world
	colony.woodcut.terrain = world
	colony.logistics.terrain = world
	colony.mining.terrain = world
	colony.colonists[1].health = 0.0
	colony.colonists[2].health = 0.0
	var signals: Array = []
	colony.woodcut.chopped.connect(func(p: Vector3i, count: int) -> void: signals.append([p,count]))
	var ok := colony.woodcut.designate(tree)
	ok = ok and not colony.woodcut.designate(tree)
	for tick in range(100):
		colony.advance(Colony.STEP)
		if signals.size() > 0:
			break
	ok = ok and signals.size() == 1
	ok = ok and signals[0][0] == tree and signals[0][1] == 3
	ok = ok and colony.woodcut.harvested.has(tree)
	ok = ok and not colony.woodcut.tree_exists(tree)
	ok = ok and not Decor.tree_positions(world,world.chunk_of(tree),colony.woodcut.harvested).has(tree)
	ok = ok and colony.woodcut.designations.is_empty()
	ok = ok and not colony.woodcut.designate(tree)
	# Hauling is autonomous and must deliver WOOD (not substitute a terrain block).
	for tick in range(140):
		if colony.logistics.stored_units() >= 3:
			break
		colony.advance(Colony.STEP)
	ok = ok and colony.logistics.inventory.get(Resources.WOOD,0) == 3
	ok = ok and colony.logistics.unhauled_units() == 0
	ok = ok and colony.logistics.carried.is_empty()
	ok = ok and colony.logistics.depot == starting_cell
	# Relocate the physical destination while preserving the recorded inventory.
	var new_depot := starting_cell
	for direction in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		if Nav.standable(world,starting_cell+direction):
			new_depot = starting_cell + direction
			break
	ok = ok and new_depot != starting_cell
	ok = ok and colony.logistics.set_depot(new_depot)
	ok = ok and not colony.logistics.set_depot(Vector3i(0,World.HEIGHT-1,0))
	ok = ok and colony.logistics.inventory.get(Resources.WOOD,0) == 3
	# Save format 1 remains compatible with optional harvested tree state.
	for cz in range(-5,6):
		if next_tree != Vector3i.ZERO:
			break
		for cx in range(-5,6):
			for p in Decor.tree_positions(world,Vector2i(cx,cz),colony.woodcut.harvested):
				if p != tree:
					next_tree = p
					break
			if next_tree != Vector3i.ZERO:
				break
	ok = ok and next_tree != Vector3i.ZERO and colony.woodcut.designate(next_tree)
	var path := "user://voxhaven-woodcut-stockpile-test.json"
	ok = ok and Save.save(world,path,colony.mining.jobs_snapshot(),colony.logistics.snapshot(),colony.woodcut.snapshot())
	var restored_world := Save.restore(path)
	if restored_world == null:
		push_error("Could not restore saved world")
		quit(1)
		return
	var restored := Colony.new()
	restored.initialize(starting_cell)
	restored.terrain = restored_world
	restored.logistics.terrain = restored_world
	restored.woodcut.terrain = restored_world
	restored.logistics.restore(Save.restore_logistics(path))
	restored.woodcut.restore(Save.restore_woodcut(path))
	ok = ok and restored.woodcut.harvested.has(tree)
	ok = ok and not restored.woodcut.tree_exists(tree)
	ok = ok and restored.woodcut.designations.has(next_tree)
	ok = ok and restored.logistics.inventory.get(Resources.WOOD,0) == 3
	ok = ok and restored.logistics.depot == new_depot
	DirAccess.remove_absolute(path)
	if not ok:
		print("Woodcut diagnostic: chopped=",signals," harvested=",colony.woodcut.harvested.size()," stock=",colony.logistics.inventory," drops=",colony.logistics.unhauled_units()," depot=",colony.logistics.depot," expected=",new_depot," restored_tree=",restored.woodcut.harvested.has(tree)," restored_jobs=",restored.woodcut.designations)
	print("Woodcut, hauling, stockpile and persistence: ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
