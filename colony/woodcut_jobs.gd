extends RefCounted
## Exclusive offline woodcutting jobs over deterministic Cube World tree decorations.
const World = preload("res://world/voxel_world.gd")
const Decor = preload("res://world/terrain_decor.gd")
const Nav = preload("res://colony/navigation.gd")
const Colonist = preload("res://colony/colonist_state.gd")
const Resources = preload("res://colony/resource_types.gd")
const Logistics = preload("res://colony/resource_logistics.gd")

const MAX_JOBS := 128
const MAX_SCAN := 8
const WOOD_YIELD := 3
const OFFSETS := [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]

signal chopped(position: Vector3i, amount: int)

var terrain: World
var logistics: Logistics
var harvested: Dictionary = {} # tree foot cell -> true
var designations: Dictionary = {} # tree foot cell -> reserved worker id (0=free)
var assignments: Dictionary = {} # colonist id -> tree cell
var work_positions: Dictionary = {} # colonist id -> standable neighboring cell

func reset() -> void:
	harvested.clear()
	designations.clear()
	assignments.clear()
	work_positions.clear()

func tree_exists(p: Vector3i) -> bool:
	if terrain == null or harvested.has(p):
		return false
	if p.y <= 0 or p.y >= World.HEIGHT - 1:
		return false
	return Decor.tree_positions(terrain, terrain.chunk_of(p)).has(p)

func designate(p: Vector3i) -> bool:
	if designations.size() >= MAX_JOBS or designations.has(p) or not tree_exists(p):
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

func has_assignment(worker: int) -> bool:
	return assignments.has(worker)

func reserve(c: Colonist) -> bool:
	if terrain == null or assignments.has(c.id) or not Nav.standable(terrain,c.position):
		return false
	var scanned := 0
	for key in designations.keys():
		if scanned >= MAX_SCAN:
			break
		scanned += 1
		var p: Vector3i = key
		if int(designations[p]) != 0:
			continue
		if not tree_exists(p):
			cancel(p)
			continue
		var best_route: Array[Vector3i] = []
		var stand := Vector3i.ZERO
		var shortest := 100000
		var found := false
		for d in OFFSETS:
			for dy in [0,1,-1]:
				var candidate: Vector3i = p + d + Vector3i.UP * dy
				if not Nav.standable(terrain,candidate):
					continue
				var route: Array[Vector3i] = Nav.route(terrain,c.position,candidate)
				if candidate != c.position and route.is_empty():
					continue
				if route.size() < shortest:
					shortest = route.size()
					stand = candidate
					best_route = route
					found = true
				if shortest == 0:
					break
			if shortest == 0:
				break
		if found:
			designations[p] = c.id
			assignments[c.id] = p
			work_positions[c.id] = stand
			c.route = best_route
			c.actions.clear()
			c.activity = "Going to chop"
			return true
	return false

func complete(c: Colonist) -> bool:
	if not assignments.has(c.id) or terrain == null or logistics == null:
		return false
	var p: Vector3i = assignments[c.id]
	if not designations.has(p) or c.position != work_positions[c.id] or not tree_exists(p) or not Nav.standable(terrain,c.position):
		cancel(p)
		return false
	# Do not remove the tree if the resource registry has no room for the drop.
	if not logistics.add_drop(p, Resources.WOOD, WOOD_YIELD):
		release(c.id)
		return false
	harvested[p] = true
	cancel(p)
	c.stamina = maxf(0.0,c.stamina - 5.0)
	c.activity = "Chopping"
	chopped.emit(p, WOOD_YIELD)
	return true

func snapshot() -> Dictionary:
	var gone: Array = []
	for p in harvested:
		gone.append([p.x,p.y,p.z])
	var pending: Array = []
	for p in designations:
		pending.append([p.x,p.y,p.z])
	return {"harvested":gone,"designations":pending}

func _coordinate(row: Variant) -> Vector3i:
	if not row is Array or row.size() != 3:
		return Vector3i(0,-1,0)
	for value in row:
		if not (value is int or value is float) or float(value) != floor(float(value)):
			return Vector3i(0,-1,0)
	var p := Vector3i(int(row[0]),int(row[1]),int(row[2]))
	if p.y <= 0 or p.y >= World.HEIGHT-1:
		return Vector3i(0,-1,0)
	return p

func restore(data: Dictionary) -> void:
	reset()
	if terrain == null:
		return
	var gone = data.get("harvested",[])
	if gone is Array:
		for row in gone:
			if harvested.size() >= 4096:
				break
			var p := _coordinate(row)
			if p.y >= 0 and tree_exists(p):
				harvested[p] = true
	var pending = data.get("designations",[])
	if pending is Array:
		for row in pending:
			var p := _coordinate(row)
			if p.y >= 0:
				designate(p)
