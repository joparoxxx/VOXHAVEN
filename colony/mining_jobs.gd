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
var workers: Array[Colonist] = [] # Live colonist positions; owned by colony simulation
var designations: Dictionary = {} # Vector3i -> worker id (0 = available)
var assignments: Dictionary = {} # worker id -> Vector3i
var work_positions: Dictionary = {} # worker id -> safe adjacent standing cell
var drops: Dictionary = {} # Vector3i -> {block, count}; awaiting hauling

func reset() -> void:
 designations.clear()
 assignments.clear()
 work_positions.clear()
 drops.clear()

## A standing Cube World tree protects its entire vertical column below
## the tree, not just the surface grass block. The grid precheck avoids
## scanning decorative trees for most ordinary mining coordinates.
func is_tree_above(p: Vector3i) -> bool:
 if terrain == null:
  return false
 if posmod(p.x,World.CHUNK_SIZE) % 4 != 2 or posmod(p.z,World.CHUNK_SIZE) % 4 != 2:
  return false
 var top := terrain.surface_at(p.x,p.z)
 if p.y > top:
  return false
 var support := Vector3i(p.x,top,p.z)
 return Decor.tree_positions(terrain,terrain.chunk_of(support),harvested_trees).has(support+Vector3i.UP)

func is_tree_base(p: Vector3i) -> bool:
 return terrain != null and p.y == terrain.surface_at(p.x,p.z) and is_tree_above(p)

## Never remove a voxel at any depth below a living colonist. Include
## deep mining: cutting beneath the worker's feet can strand them later.
func is_worker_above(p: Vector3i) -> bool:
 for c in workers:
  if c.health > 0.0 and c.position.x == p.x and c.position.z == p.z and c.position.y > p.y:
   return true
 return false

func is_protected(p: Vector3i) -> bool:
 return is_worker_above(p) or is_tree_above(p)

func designate(p: Vector3i) -> bool:
 if terrain == null or designations.has(p) or designations.size() >= MAX_JOBS or is_protected(p):
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
  if terrain.block_at(p) == World.Block.AIR:
   cancel(p)
   continue
  # Keep saved/pending jobs, but do not reserve them while occupied.
  if is_protected(p):
   continue
  inspected += 1
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
 if block == World.Block.AIR:
  cancel(p)
  return false
 # Last-moment guard: an occupant may have walked onto the block
 # after this mining job was reserved or while the mining animation ran.
 if is_protected(p):
  release(c.id)
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
