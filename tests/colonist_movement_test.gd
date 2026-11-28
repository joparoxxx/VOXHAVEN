extends SceneTree
const World = preload("res://world/voxel_world.gd")
const Colony = preload("res://colony/colony_simulation.gd")
const Nav = preload("res://colony/navigation.gd")
const View = preload("res://colony/colonist_view.gd")

func _initialize() -> void:
	var world := World.new(731)
	for x in range(9):
		for z in range(-1,2):
			world.set_block(Vector3i(x,49,z),World.Block.STONE)
			world.set_block(Vector3i(x,50,z),World.Block.AIR)
			world.set_block(Vector3i(x,51,z),World.Block.AIR)
	var colony := Colony.new()
	colony.initialize(Vector3i(0,50,0))
	colony.terrain = world
	colony.mining.terrain = world
	colony.colonists[1].health = 0.0
	colony.colonists[2].health = 0.0
	var c = colony.colonists[0]
	var visual := View.new()
	get_root().add_child(visual)
	visual.setup(c)
	var route: Array[Vector3i] = Nav.route(world,c.position,Vector3i(6,50,0))
	var ok := route.size()==6
	c.route = route
	for i in range(6):
		colony.advance(Colony.STEP)
		var previous: float = visual.position.x
		# Simulate four frames between successive logical waypoints.
		visual.sync_state(c,Colony.STEP*0.25)
		ok = ok and visual.position.x>previous and visual.position.x<float(i+1)+0.5
		for frame in range(3):
			visual.sync_state(c,Colony.STEP*0.25)
		ok = ok and visual.position.x>=float(i+1)+0.49
		ok = ok and c.position==Vector3i(i+1,50,0)
		ok = ok and c.activity=="Walking"
	ok = ok and absf(colony.elapsed-1.5)<0.0001
	ok = ok and visual.position.distance_to(Vector3(6.5,50.0,0.5))<0.01

	# Mining now takes a sustained work phase; arriving does not delete a block.
	var target := Vector3i(7,49,0)
	ok = ok and colony.mining.designate(target)
	colony.advance(Colony.STEP) # reserve the adjacent mining position
	ok = ok and colony.mining.has_assignment(c.id)
	colony.advance(Colony.STEP) # 0.25 seconds of work
	visual.sync_state(c,Colony.STEP)
	ok = ok and c.activity=="Mining"
	ok = ok and c.work_progress > 0.0
	ok = ok and world.block_at(target)==World.Block.STONE
	colony.advance(Colony.STEP * 2.0) # finish the next 0.5 seconds
	ok = ok and world.block_at(target)==World.Block.AIR
	ok = ok and c.work_progress==0.0
	ok = ok and colony.mining.drops.has(target)
	print("Continuous movement and timed mining: ", "PASS" if ok else "FAIL")
	visual.free()
	quit(0 if ok else 1)
