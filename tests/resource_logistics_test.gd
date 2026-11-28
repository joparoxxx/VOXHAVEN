extends SceneTree
const World = preload("res://world/voxel_world.gd")
const Colony = preload("res://colony/colony_simulation.gd")
const Save = preload("res://world/world_save.gd")

func _initialize() -> void:
 var world := World.new(208)
 for x in range(7):
  for z in range(-1, 2):
   world.set_block(Vector3i(x, 49, z), World.Block.STONE)
   world.set_block(Vector3i(x, 50, z), World.Block.AIR)
   world.set_block(Vector3i(x, 51, z), World.Block.AIR)
 var colony := Colony.new()
 colony.initialize(Vector3i(0, 50, 0))
 colony.terrain = world
 colony.mining.terrain = world
 colony.logistics.terrain = world
 colony.colonists[1].health = 0.0
 colony.colonists[2].health = 0.0
 var target := Vector3i(3, 49, 0)
 var ok := colony.mining.designate(target)
 for tick in 30:
  colony.advance(1.0)
 ok = ok and world.block_at(target) == World.Block.AIR
 ok = ok and colony.logistics.stored_units() == 1
 ok = ok and colony.logistics.unhauled_units() == 0
 ok = ok and colony.logistics.inventory.get(World.Block.STONE, 0) == 1
 ok = ok and colony.logistics.reservations.is_empty()
 ok = ok and colony.logistics.carried.is_empty()

 var later := Vector3i(5, 49, 0)
 ok = ok and colony.mining.designate(later)
 var pending := Vector3i(6, 49, 0)
 colony.mining.drops[pending] = {"block": World.Block.GOLD, "count": 2}
 var path := "user://voxhaven-logistics-test.json"
 ok = ok and Save.save(world, path, colony.mining.jobs_snapshot(), colony.logistics.snapshot())
 var loaded_world := Save.restore(path)
 var loaded_jobs := Save.restore_mining_jobs(path)
 var restored := Colony.new()
 restored.initialize(Vector3i(0, 50, 0))
 restored.terrain = loaded_world
 restored.mining.terrain = loaded_world
 restored.logistics.terrain = loaded_world
 restored.mining.restore_jobs(loaded_jobs)
 restored.logistics.restore(Save.restore_logistics(path))
 ok = ok and loaded_world != null and restored.mining.designations.has(later)
 ok = ok and restored.logistics.inventory.get(World.Block.STONE, 0) == 1
 ok = ok and restored.logistics.unhauled_units() == 2
 ok = ok and restored.mining.drops.has(pending)
 DirAccess.remove_absolute(path)

 # Releasing a dead carrier must not delete the item.
 restored.logistics.carried[1] = {"block": World.Block.COPPER, "count": 3}
 restored.logistics.release(1, Vector3i(0, 50, 0))
 ok = ok and restored.logistics.unhauled_units() == 5
 print("Resource haul, storage and save round trip: ", "PASS" if ok else "FAIL")
 quit(0 if ok else 1)
