extends RefCounted
## Half-meter walk grid for the zoned HQ; furniture occupies cells.
var grid := AStarGrid2D.new()
const MIN_X := -17
const MAX_X := 17
const MIN_Z := -11
const MAX_Z := 11
func _init() -> void:
	grid.region = Rect2i(MIN_X, MIN_Z, MAX_X - MIN_X + 1, MAX_Z - MIN_Z + 1)
	grid.cell_size = Vector2(0.5, 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
func cell(position: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(position.x * 2), MIN_X, MAX_X), clampi(roundi(position.z * 2), MIN_Z, MAX_Z))
func block_box(center: Vector3, half_size: Vector2) -> void:
	for x in range(MIN_X, MAX_X + 1):
		for z in range(MIN_Z, MAX_Z + 1):
			if absf(x * 0.5 - center.x) <= half_size.x and absf(z * 0.5 - center.z) <= half_size.y:
				grid.set_point_solid(Vector2i(x, z))
func route(start: Vector3, target: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var a := cell(start)
	var b := cell(target)
	if grid.is_point_solid(a) or grid.is_point_solid(b):
		return result
	for p in grid.get_id_path(a, b):
		result.append(Vector3(p.x * 0.5, 0, p.y * 0.5))
	return result
