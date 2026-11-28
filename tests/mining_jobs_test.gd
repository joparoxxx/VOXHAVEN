extends SceneTree
const World = preload("res://world/voxel_world.gd")
const Colony = preload("res://colony/colony_simulation.gd")
const Save = preload("res://world/world_save.gd")

func _initialize() -> void:
 var world := World.new(42)
 for x in range(6):
  for z in range(-1, 2):
   world.set_block(Vector3i(x, 49, z), World.Block.STONE)
   world.set_block(Vector3i(x, 50, z), World.Block.AIR)
   world.set_block(Vector3i(x, 51, z), World.Block.AIR)
 var colony := Colony.new()
 colony.initialize(Vector3i(0, 50, 0))
 colony.terrain = world
 colony.mining.terrain = world
 # Keep the test deterministic by disabling the other two simulated workers.
 colony.colonists[1].health = 0.0
 colony.colonists[2].health = 0.0
 var target := Vector3i(3, 49, 0)
 var events: Array = []
 colony.mining.mined.connect(func(p: Vector3i, block: int) -> void: events.append([p, block]))
 var ok := colony.mining.designate(target)
 ok = ok and not colony.mining.designate(target)
 ok = ok and not colony.mining.designate(Vector3i(0, 55, 0))
 for step in range(16):
  colony.advance(1.0)
 ok = ok and world.block_at(target) == World.Block.AIR
 ok = ok and colony.mining.designations.is_empty()
 ok = ok and colony.mining.assignments.is_empty()
 ok = ok and events.size() == 1
 ok = ok and colony.mining.drops.has(target)
 if colony.mining.drops.has(target):
  ok = ok and int(colony.mining.drops[target]["block"]) == World.Block.STONE
  ok = ok and int(colony.mining.drops[target]["count"]) == 1

 var pending := Vector3i(4, 49, 0)
 ok = ok and colony.mining.designate(pending)
 var path := "user://voxhaven-mining-test.json"
 ok = ok and Save.save(world, path, colony.mining.jobs_snapshot())
 var restored := Save.restore(path)
 var pending_jobs := Save.restore_mining_jobs(path)
 ok = ok and restored != null and pending_jobs.size() == 1 and pending_jobs.has(pending)
 ok = ok and colony.mining.cancel(pending)
 ok = ok and colony.mining.designations.is_empty()
 DirAccess.remove_absolute(path)
 print("Mining jobs, resources and persistence: ", "PASS" if ok else "FAIL")
 quit(0 if ok else 1)
