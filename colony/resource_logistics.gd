extends RefCounted
## Deterministic colony resources: recoverable drops, hauling reservations and depot stock.
## Stores block-type item counts; no cloud, physics pickup nodes or unbounded job scans.
const World = preload("res://world/voxel_world.gd")
const Nav = preload("res://colony/navigation.gd")
const Colonist = preload("res://colony/colonist_state.gd")
const MiningJobs = preload("res://colony/mining_jobs.gd")
const Resources = preload("res://colony/resource_types.gd")

const MAX_DROPS_SCAN := 8
const MAX_DROPS := 512
const PICKUP_OFFSETS := [
 Vector3i.UP, Vector3i.LEFT + Vector3i.UP, Vector3i.RIGHT + Vector3i.UP,
 Vector3i.FORWARD + Vector3i.UP, Vector3i.BACK + Vector3i.UP,
 Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK
]

signal delivered(block: int, count: int)

var terrain: World
var mining: MiningJobs
var depot := Vector3i.ZERO
var inventory: Dictionary = {} # block ID -> number of stored units
var reservations: Dictionary = {} # drop cell -> assigned colonist ID
var assignments: Dictionary = {} # colonist ID -> drop cell
var carried: Dictionary = {} # colonist ID -> {block, count}

func reset(spawn: Vector3i) -> void:
 depot = spawn
 inventory.clear()
 reservations.clear()
 assignments.clear()
 carried.clear()

# Stockpile cell is always traversable; inventory stays in place on relocation.
func set_depot(p: Vector3i) -> bool:
 if terrain == null or not Nav.standable(terrain,p):
  return false
 depot = p
 return true

# Generic item drop API for mining and woodcutting; never silently overwrite
# another resource type at the same position.
func add_drop(p: Vector3i, item_id: int, amount: int) -> bool:
 if mining == null or terrain == null or not Resources.is_valid(item_id) or amount <= 0:
  return false
 if p.y < 0 or p.y >= World.HEIGHT:
  return false
 if mining.drops.size() >= MAX_DROPS and not mining.drops.has(p):
  return false
 var chosen := p
 if mining.drops.has(chosen) and int(mining.drops[chosen].get("block",-1)) != item_id:
  var found := false
  for offset in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK,Vector3i.UP]:
   var nearby: Vector3i = p + offset
   if not mining.drops.has(nearby) and nearby.y >= 0 and nearby.y < World.HEIGHT:
    chosen = nearby
    found = true
    break
  if not found or mining.drops.size() >= MAX_DROPS:
   return false
 _add_drop(chosen,item_id,amount)
 return true

func stored_units() -> int:
 var result := 0
 for block in inventory:
  result += int(inventory[block])
 return result

func unhauled_units() -> int:
 var result := 0
 if mining == null:
  return 0
 for item in mining.drops.values():
  if item is Dictionary:
   result += int(item.get("count", 0))
 return result

func has_job(worker: int) -> bool:
 return assignments.has(worker) or carried.has(worker)

func release(worker: int, position: Vector3i) -> void:
 if assignments.has(worker):
  var drop: Vector3i = assignments[worker]
  reservations.erase(drop)
  assignments.erase(worker)
 if carried.has(worker):
  var item: Dictionary = carried[worker]
  carried.erase(worker)
  _add_drop(position, int(item["block"]), int(item["count"]))

func _add_drop(p: Vector3i, block: int, amount: int) -> void:
 if mining == null or amount <= 0:
  return
 if mining.drops.has(p) and int(mining.drops[p].get("block", -1)) != block:
  # Never discard a different resource if multiple drops share a cell.
  var previous: Dictionary = mining.drops[p]
  inventory[int(previous["block"])] = int(inventory.get(int(previous["block"]), 0)) + int(previous["count"])
  mining.drops.erase(p)
 var entry: Dictionary = mining.drops.get(p, {"block": block, "count": 0})
 entry["count"] = int(entry["count"]) + amount
 mining.drops[p] = entry

func reserve(c: Colonist) -> bool:
 if mining == null or terrain == null or has_job(c.id) or not Nav.standable(terrain, c.position):
  return false
 var checked := 0
 var best_length := 1000000
 var best_drop := Vector3i.ZERO
 var best_route: Array[Vector3i] = []
 var found := false
 for key in mining.drops.keys():
  if checked >= MAX_DROPS_SCAN:
   break
  checked += 1
  var p: Vector3i = key
  if reservations.has(p):
   continue
  var item: Dictionary = mining.drops[p]
  if int(item.get("count", 0)) <= 0:
   continue
  for offset in PICKUP_OFFSETS:
   var target: Vector3i = p + offset
   if not Nav.standable(terrain, target):
    continue
   var path: Array[Vector3i] = Nav.route(terrain, c.position, target)
   if target != c.position and path.is_empty():
    continue
   if path.size() < best_length:
    best_length = path.size()
    best_drop = p
    best_route = path
    found = true
   if best_length == 0:
    break
  if best_length == 0:
   break
 if not found:
  return false
 reservations[best_drop] = c.id
 assignments[c.id] = best_drop
 c.actions.clear()
 c.route = best_route
 c.activity = "Collecting resources"
 return true

func _near_depot(p: Vector3i) -> bool:
 return absi(p.x - depot.x) + absi(p.z - depot.z) <= 1 and absi(p.y - depot.y) <= 1

func _depot_route(start: Vector3i) -> Array[Vector3i]:
 var nearest: Array[Vector3i] = []
 var best_length := 1000000
 var found := false
 for offset in [Vector3i.ZERO, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
  var target: Vector3i = depot + offset
  if not Nav.standable(terrain, target):
   continue
  var path: Array[Vector3i] = Nav.route(terrain, start, target)
  if target != start and path.is_empty():
   continue
  if path.size() < best_length:
   nearest = path
   best_length = path.size()
   found = true
 if found:
  return nearest
 return []

func progress(c: Colonist) -> bool:
 if mining == null or terrain == null or not has_job(c.id):
  return false
 if carried.has(c.id):
  if _near_depot(c.position):
   var item: Dictionary = carried[c.id]
   var block := int(item["block"])
   var count := int(item["count"])
   inventory[block] = int(inventory.get(block, 0)) + count
   carried.erase(c.id)
   c.activity = "Delivered resources"
   delivered.emit(block, count)
   return true
  c.route = _depot_route(c.position)
  c.activity = "Carrying resources"
  return true
 var p: Vector3i = assignments[c.id]
 if not mining.drops.has(p):
  release(c.id, c.position)
  return false
 if absi(c.position.x - p.x) + absi(c.position.z - p.z) > 1 or absi(c.position.y - p.y) > 1:
  release(c.id, c.position)
  return false
 var entry: Dictionary = mining.drops[p]
 carried[c.id] = {"block": int(entry["block"]), "count": int(entry["count"])}
 mining.drops.erase(p)
 reservations.erase(p)
 assignments.erase(c.id)
 c.activity = "Picked up resources"
 return true

func snapshot() -> Dictionary:
 var stock: Array = []
 for block in inventory:
  stock.append([int(block), int(inventory[block])])
 var remaining: Array = []
 if mining != null:
  for p in mining.drops:
   var entry: Dictionary = mining.drops[p]
   remaining.append([p.x, p.y, p.z, int(entry["block"]), int(entry["count"])])
 # Carried resources have no restored colonist positions; recover into depot stock.
 for item in carried.values():
  var entry: Dictionary = item
  stock.append([int(entry["block"]), int(entry["count"])])
 return {"depot": [depot.x, depot.y, depot.z], "inventory": stock, "drops": remaining}

func _integer(value: Variant) -> bool:
 return (value is int or value is float) and float(value) == floor(float(value))

func restore(data: Dictionary) -> void:
 inventory.clear()
 reservations.clear()
 assignments.clear()
 carried.clear()
 if mining == null:
  return
 mining.drops.clear()
 var coord = data.get("depot", [])
 if coord is Array and coord.size() == 3 and _integer(coord[0]) and _integer(coord[1]) and _integer(coord[2]):
  var p := Vector3i(int(coord[0]), int(coord[1]), int(coord[2]))
  if p.y > 0 and p.y < World.HEIGHT - 1:
   depot = p
 var stock = data.get("inventory", [])
 if stock is Array:
  for entry in stock:
   if not entry is Array or entry.size() != 2:
    continue
   if not _integer(entry[0]) or not _integer(entry[1]):
    continue
   var block := int(entry[0])
   var count := int(entry[1])
   if not Resources.is_valid(block) or count <= 0:
    continue
   inventory[block] = int(inventory.get(block, 0)) + count
 var rows = data.get("drops", [])
 if rows is Array:
  for entry in rows:
   if mining.drops.size() >= MAX_DROPS:
    break
   if not entry is Array or entry.size() != 5:
    continue
   var valid := true
   for value in entry:
    if not _integer(value):
     valid = false
   if not valid:
    continue
   var p := Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))
   var block := int(entry[3])
   var count := int(entry[4])
   if p.y < 0 or p.y >= World.HEIGHT or not Resources.is_valid(block) or count <= 0:
    continue
   _add_drop(p, block, count)
