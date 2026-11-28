extends SceneTree
const World = preload("res://world/voxel_world.gd")
const Colony = preload("res://colony/colony_simulation.gd")
const Save = preload("res://world/world_save.gd")

func _initialize() -> void:
 var world := World.new(912)
 for x in range(1,5):
  for z in range(1,5):
   for y in range(45,50):
    world.set_block(Vector3i(x,y,z),World.Block.STONE)
   world.set_block(Vector3i(x,50,z),World.Block.AIR)
   world.set_block(Vector3i(x,51,z),World.Block.AIR)
 var colony := Colony.new()
 colony.initialize(Vector3i(0,50,0))
 colony.terrain = world
 colony.mining.terrain = world
 colony.dig.terrain = world
 var ok := colony.dig.request_area(Vector3i(2,49,2),Vector3i(3,49,3),3) == 4
 ok = ok and colony.dig.columns.size() == 4 and colony.mining.designations.size() == 4
 ok = ok and colony.dig.request_area(Vector3i(0,49,0),Vector3i(20,49,20),2) == 0
 ok = ok and colony.dig.request_area(Vector3i(2,49,2),Vector3i(2,49,2),9) == 0
 # Mimic a completed mining layer to verify jobs reveal the next layer.
 var top := Vector3i(2,49,2)
 ok = ok and colony.mining.designations.has(top)
 colony.mining.cancel(top)
 world.set_block(top,World.Block.AIR)
 colony.dig.schedule()
 var second := Vector3i(2,48,2)
 ok = ok and colony.mining.designations.has(second)
 ok = ok and not colony.mining.designations.has(Vector3i(2,47,2))
 colony.mining.cancel(second)
 world.set_block(second,World.Block.AIR)
 colony.dig.schedule()
 ok = ok and colony.mining.designations.has(Vector3i(2,47,2))
 # Planner must keep the request bounded and preserve lower tiers for later.
 ok = ok and colony.dig.active.size() <= colony.dig.MAX_ACTIVE
 var path := "user://voxhaven-depth-test.json"
 ok = ok and Save.save(world,path,colony.mining.jobs_snapshot(),{}, {},colony.dig.snapshot())
 var restored := Save.restore(path)
 var restored_jobs := Save.restore_mining_jobs(path)
 var saved_dig := Save.restore_dig(path)
 var another := Colony.new()
 another.initialize(Vector3i(0,50,0))
 another.terrain = restored
 another.mining.terrain = restored
 another.dig.terrain = restored
 another.mining.restore_jobs(restored_jobs)
 another.dig.restore(saved_dig)
 ok = ok and restored != null and another.dig.columns.size() == 4
 ok = ok and another.mining.designations.has(Vector3i(2,47,2))
 var removed := another.dig.cancel_area(Vector3i(2,49,2),Vector3i(3,49,3))
 ok = ok and removed == 4 and another.dig.columns.is_empty()
 DirAccess.remove_absolute(path)
 if not ok:
  print("Dig diagnostic: columns=",colony.dig.columns," jobs=",colony.mining.designations," restored=",another.dig.columns," removed=",removed)
 print("Area selection excavation depth and persistence: ","PASS" if ok else "FAIL")
 quit(0 if ok else 1)
