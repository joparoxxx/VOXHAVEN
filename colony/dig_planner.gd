extends RefCounted
## Bounded, surface-first excavation planning. One mining designation per column.
## Deeper layers become jobs only after the higher block has been removed.
const World = preload("res://world/voxel_world.gd")
const MiningJobs = preload("res://colony/mining_jobs.gd")

const MAX_DEPTH := 8
const MAX_COLUMNS := 64
const MAX_ACTIVE := 12

signal queued(position: Vector3i)

var terrain: World
var mining: MiningJobs
var columns: Dictionary = {} # Vector2i(x,z) -> {top:int,bottom:int}
var active: Dictionary = {} # Vector2i(x,z) -> currently designated Vector3i
var owned: Dictionary = {} # only jobs inserted by this planner

func reset() -> void:
 columns.clear()
 active.clear()
 owned.clear()

func request_area(first: Vector3i, last: Vector3i, depth: int) -> int:
 if terrain == null or mining == null or depth < 1 or depth > MAX_DEPTH:
  return 0
 var min_x := mini(first.x,last.x)
 var max_x := maxi(first.x,last.x)
 var min_z := mini(first.z,last.z)
 var max_z := maxi(first.z,last.z)
 var width := max_x-min_x+1
 var height := max_z-min_z+1
 if width*height > MAX_COLUMNS:
  return 0
 var extra := 0
 for z in range(min_z,max_z+1):
  for x in range(min_x,max_x+1):
   if not columns.has(Vector2i(x,z)):
    extra += 1
 if columns.size()+extra > MAX_COLUMNS:
  return 0
 var planned := 0
 for z in range(min_z,max_z+1):
  for x in range(min_x,max_x+1):
   var key := Vector2i(x,z)
   # Each column uses its own exposed surface height; slopes should not
   # become empty goals just because the second selection corner is higher.
   var surface := mini(maxi(terrain.surface_at(x,z),maxi(first.y,last.y)),World.HEIGHT-2)
   while surface > 0 and terrain.block_at(Vector3i(x,surface,z)) == World.Block.AIR:
    surface -= 1
   if surface <= 0 or mining.is_tree_base(Vector3i(x,surface,z)):
    # Do not put an excavation plan underneath a living tree.
    # Woodcutting is ordered separately by the unified Mine tool.
    continue
   var floor_y := maxi(1,surface-depth+1)
   if columns.has(key):
    var existing: Dictionary = columns[key]
    floor_y = mini(int(existing["bottom"]),floor_y)
    surface = maxi(int(existing["top"]),surface)
   columns[key] = {"top":surface,"bottom":floor_y}
   planned += 1
 schedule()
 return planned

func _next_solid(key: Vector2i) -> Vector3i:
 if not columns.has(key) or terrain == null:
  return Vector3i(key.x,-1,key.y)
 var limits: Dictionary = columns[key]
 for y in range(int(limits["top"]),int(limits["bottom"])-1,-1):
  var p := Vector3i(key.x,y,key.y)
  if terrain.block_at(p) != World.Block.AIR:
   return p
 return Vector3i(key.x,-1,key.y)

func schedule() -> void:
 if terrain == null or mining == null:
  return
 # Remove fulfilled or externally cancelled active designations.
 for key in active.keys():
  var p: Vector3i = active[key]
  if not mining.designations.has(p):
   active.erase(key)
   owned.erase(p)
 # Strict upper-layer barrier across the entire selected area:
 # do not issue deeper mining jobs while any shallow block remains.
 var pending: Array[Dictionary] = []
 var highest_remaining := -1
 for key in columns.keys():
  var next := _next_solid(key)
  if next.y < 0 or mining.is_tree_base(next):
   if active.has(key):
    var job: Vector3i = active[key]
    if owned.has(job):
     mining.cancel(job)
     owned.erase(job)
    active.erase(key)
   columns.erase(key)
   continue
  var limits: Dictionary = columns[key]
  highest_remaining = maxi(highest_remaining,next.y)
  pending.append({"key":key,"next":next})
 # Cancel planner-owned deeper reservations if the upper layer still exists.
 for key in active.keys():
  if not columns.has(key):
   active.erase(key)
   continue
  var target: Vector3i = active[key]
  if target.y < highest_remaining and owned.has(target):
   mining.cancel(target)
   owned.erase(target)
   active.erase(key)
 for entry in pending:
  if active.size() >= MAX_ACTIVE:
   break
  if Vector3i(entry["next"]).y != highest_remaining:
   continue
  var key: Vector2i = entry["key"]
  var next: Vector3i = entry["next"]
  if active.has(key):
   continue
  if mining.designations.has(next):
   active[key] = next
   continue
  if mining.designate(next):
   active[key] = next
   owned[next] = true
   queued.emit(next)

func cancel_area(first: Vector3i,last: Vector3i) -> int:
 var count := 0
 for key in columns.keys():
  if key.x < mini(first.x,last.x) or key.x > maxi(first.x,last.x):
   continue
  if key.y < mini(first.z,last.z) or key.y > maxi(first.z,last.z):
   continue
  if active.has(key):
   var p: Vector3i = active[key]
   if owned.has(p):
    mining.cancel(p)
    owned.erase(p)
   active.erase(key)
  columns.erase(key)
  count += 1
 return count

func snapshot() -> Dictionary:
 var records: Array = []
 for key in columns:
  var limits: Dictionary = columns[key]
  records.append([key.x,key.y,int(limits["top"]),int(limits["bottom"])])
 return {"columns":records}

func restore(data: Dictionary) -> void:
 reset()
 if terrain == null:
  return
 var records = data.get("columns",[])
 if not records is Array:
  return
 for row in records:
  if columns.size() >= MAX_COLUMNS:
   break
  if not row is Array or row.size() != 4:
   continue
  var valid := true
  for item in row:
   if not (item is int or item is float) or float(item) != floor(float(item)):
    valid = false
  if not valid:
   continue
  var top := int(row[2])
  var bottom := int(row[3])
  if top < 1 or top > World.HEIGHT-2 or bottom < 1 or bottom > top or top-bottom+1 > MAX_DEPTH:
   continue
  var key := Vector2i(int(row[0]),int(row[1]))
  if mining != null and mining.is_tree_base(Vector3i(key.x,top,key.y)):
   continue
  columns[key] = {"top":top,"bottom":bottom}
 schedule()
