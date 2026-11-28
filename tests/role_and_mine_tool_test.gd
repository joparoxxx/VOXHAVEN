extends SceneTree
## Single Mine dispatcher, protected tree base and one occupation per worker.
const World = preload("res://world/voxel_world.gd")
const Decor = preload("res://world/terrain_decor.gd")
const Nav = preload("res://colony/navigation.gd")
const Colony = preload("res://colony/colony_simulation.gd")
const WorkOrders = preload("res://colony/work_orders.gd")
const Save = preload("res://world/world_save.gd")

func _initialize() -> void:
 var world := World.new(123)
 var tree := Vector3i.ZERO
 var start := Vector3i.ZERO
 var found := false
 for cz in range(-5,6):
  if found:
   break
  for cx in range(-5,6):
   if found:
    break
   for p in Decor.tree_positions(world,Vector2i(cx,cz)):
    for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
     if Nav.standable(world,p+d):
      tree = p
      start = p+d
      found = true
      break
    if found:
     break
 if not found:
  push_error("Could not find reachable forest tree fixture")
  quit(1)
  return
 var base: Vector3i = tree+Vector3i.DOWN
 var colony := Colony.new()
 colony.initialize(start)
 colony.terrain = world
 colony.mining.terrain = world
 colony.woodcut.terrain = world
 colony.dig.terrain = world
 colony.logistics.terrain = world
 var ok := colony.mining.is_tree_base(base)
 ok = ok and world.block_at(base) == World.Block.GRASS
 ok = ok and not colony.mining.designate(base)
 var direct: Dictionary = WorkOrders.single(world,colony.mining,colony.woodcut,colony.dig,base,1)
 ok = ok and str(direct["job"]) == "tree"
 ok = ok and colony.woodcut.designations.has(tree)
 ok = ok and colony.mining.designations.is_empty()
 var cancel: Dictionary = WorkOrders.single(world,colony.mining,colony.woodcut,colony.dig,base,1)
 ok = ok and str(cancel["job"]) == "cancel_tree"
 ok = ok and not colony.woodcut.designations.has(tree)
 var area: Dictionary = WorkOrders.area(world,colony.mining,colony.woodcut,colony.dig,base,base,3)
 ok = ok and area["trees"].size() == 1
 ok = ok and int(area["columns"]) == 0
 ok = ok and colony.woodcut.designations.has(tree)
 ok = ok and not colony.dig.columns.has(Vector2i(base.x,base.z))
 ok = ok and not colony.mining.designations.has(base)
 # A worker's role is exclusive and survives save/load.
 ok = ok and colony.set_role(1,"Miner")
 ok = ok and colony.set_role(2,"Woodcutter")
 ok = ok and colony.set_role(3,"Hauler")
 ok = ok and not colony.set_role(1,"Builder")
 colony.colonists[0].position = start
 colony.colonists[1].position = start
 colony.colonists[2].position = start
 for tick in range(120):
  colony.advance(Colony.STEP)
  for c in colony.colonists:
   ok = ok and colony.active_job_count(c.id) <= 1
  if colony.woodcut.harvested.has(tree):
   break
 ok = ok and colony.woodcut.harvested.has(tree)
 ok = ok and world.block_at(base) == World.Block.GRASS
 ok = ok and not colony.mining.is_tree_base(base)
 # After a tree has been cut, its base can only be mined by a new explicit order.
 ok = ok and colony.mining.designate(base)
 var save_path := "user://voxhaven-unified-mine-test.json"
 ok = ok and Save.save(world,save_path,colony.mining.jobs_snapshot(),colony.logistics.snapshot(),colony.woodcut.snapshot(),colony.dig.snapshot(),colony.worker_roles())
 var saved_roles: Array[String] = Save.restore_worker_roles(save_path)
 ok = ok and saved_roles == ["Miner","Woodcutter","Hauler"]
 var reloaded := Save.restore(save_path)
 ok = ok and reloaded != null and reloaded.block_at(base) == World.Block.GRASS
 DirAccess.remove_absolute(save_path)
 if not ok:
  print("Mine/worker diagnostics: base=",base," tree=",tree," harvested=",colony.woodcut.harvested.has(tree)," mine=",colony.mining.designations," chop=",colony.woodcut.designations," roles=",saved_roles)
 print("Unified Mine, protected tree roots and exclusive worker roles: ","PASS" if ok else "FAIL")
 quit(0 if ok else 1)
