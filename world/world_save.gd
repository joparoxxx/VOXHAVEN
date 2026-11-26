extends RefCounted
const World = preload("res://world/voxel_world.gd")
const VERSION := 1

static func save(world: World, path: String) -> bool:
	var records: Array = []
	for p in world.edits:
		records.append([p.x,p.y,p.z,world.edits[p]])
	var file := FileAccess.open(path + ".tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version":VERSION,"seed":world.world_seed,"edits":records}))
	file.close()
	return DirAccess.rename_absolute(path+".tmp",path) == OK

static func restore(path: String) -> World:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return null
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary: return null
	if data.get("version") != VERSION or not data.get("edits") is Array: return null
	if not data.get("seed") is float and not data.get("seed") is int: return null
	var world := World.new(int(data.seed))
	for row in data.edits:
		if not row is Array or row.size()!=4: return null
		for value in row:
			if not value is float and not value is int: return null
			if float(value)!=floor(float(value)): return null
		if not world.set_block(Vector3i(int(row[0]),int(row[1]),int(row[2])),int(row[3])): return null
	return world
