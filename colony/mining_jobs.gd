extends RefCounted
## Offline mining designations, exclusive colonist reservations and unhauled drops.
const World = preload("res://world/voxel_world.gd")
const Nav = preload("res://colony/navigation.gd")
const Decor = preload("res://world/terrain_decor.gd")
const Colonist = preload("res://colony/colonist_state.gd")
const MAX_JOBS := 256
const MAX_JOB_SCAN := 6
const ADJACENT := [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]

signal mined(position: Vector3i, block: int)

var terrain: World
var harvested_trees: Dictionary = {} # Shared live set of already-felled trees
var designations: Dictionary = {} # Vector3i -> worker id (0 = available)
var assignments: Dictionary = {} # worker id -> Vector3i
var work_positions: Dictionary = {} # worker id -> safe adjacent standing cell
var drops: Dictionary = {} # Vector3i -> {block, count}; awaiting hauling

func reset() -> void:
 designations.clear()
 assignments.clear()
 work_positions.clear()
 drops.clear()

func is_tree_base(p: Vector3i) -> bool:
 # Real trees are deterministic decorations above their supporting grass.
 # Never uproot a standing tree by mining or by a queued excavation.
 if terrain == null or p.y != terrain.surface_at(p.x,p.z):
  return false
 return Decor.tree_positions(terrain,terrain.chunk_of(p),harvested_trees).has(p+Vector3i.UP)

func designate(p: Vector3i) -> bool:
 if terrain == null or designations.has(p) or designations.size() >= MAX_JOBS or is_tree_base(p):
  return false
 if terrain.block_at(p) == World.Block.AIR:
  return false
 designations[p] = 0
 return true

func cancel(p: Vector3i) -> bool:
 if not designations.has(p):
  return false
 var worker := int(designations[p])
 if worker != 0:
  release(worker)
 designations.erase(p)
 return true

func release(worker: int) -> void:
 if assignments.has(worker):
  var p: Vector3i = assignments[worker]
  if designations.has(p):
   designations[p] = 0
  assignments.erase(worker)
 work_positions.erase(worker)

func jobs_snapshot() -> Array[Vector3i]:
 var result: Array[Vector3i] = []
 for p in designations:
  result.append(p)
 return result

func restore_jobs(positions: Array[Vector3i]) -> void:
 designations.clear()
 assignments.clear()
 work_positions.clear()
 for p in positions:
  designate(p)

func has_assignment(worker: int) -> bool:
 return assignments.has(worker)

func reserve(c: Colonist) -> bool:
 if terrain == null or assignments.has(c.id) or not Nav.standable(terrain, c.position):
  return false
 var inspected := 0
 for key in designations.keys():
  if inspected >= MAX_JOB_SCAN:
   break
  var p: Vector3i = key
  if int(designations[p]) != 0:
   continue
  inspected += 1
  if terrain.block_at(p) == World.Block.AIR or is_tree_base(p):
   cancel(p)
   continue
  var chosen := Vector3i.ZERO
  var route: Array[Vector3i] = []
  var found := false
  var shortest := 1000000
  for direction in ADJACENT:
   for height_offset in [2, 1, 0, -1]:
    var stand: Vector3i = p + direction + Vector3i.UP * height_offset
    if not Nav.standable(terrain, stand):
     continue
    var candidate: Array[Vector3i] = Nav.route(terrain, c.position, stand)
    if stand != c.position and candidate.is_empty():
     continue
    if candidate.size() < shortest:
     chosen = stand
     route = candidate
     shortest = candidate.size()
     found = true
    if shortest == 0:
     break
   if shortest == 0:
    break
  if found:
   designations[p] = c.id
   assignments[c.id] = p
   work_positions[c.id] = chosen
   c.route = route
   c.actions.clear()
   return true
 return false

func complete(c: Colonist) -> bool:
 if terrain == null or not assignments.has(c.id):
  return false
 var p: Vector3i = assignments[c.id]
 if not designations.has(p) or c.position != work_positions[c.id] or not Nav.standable(terrain, c.position):
  release(c.id)
  return false
 var block := terrain.block_at(p)
 if block == World.Block.AIR or is_tree_base(p):
  cancel(p)
  return false
 if not terrain.set_block(p, World.Block.AIR):
  release(c.id)
  return false
 var dropped: Dictionary = drops.get(p, {"block": block, "count": 0})
 dropped["count"] = int(dropped["count"]) + 1
 drops[p] = dropped
 cancel(p)
 c.stamina = maxf(0.0, c.stamina - 4.0)
 c.activity = "Mining"
 mined.emit(p, block)
 return true
