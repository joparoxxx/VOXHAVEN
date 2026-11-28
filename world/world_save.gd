extends RefCounted
const World = preload("res://world/voxel_world.gd")
const VERSION := 1

static func save(world: World, path: String, mining_jobs: Array = [], logistics_state: Dictionary = {}, woodcut_state: Dictionary = {}, dig_state: Dictionary = {}, worker_roles: Array = []) -> bool:
	var records: Array = []
	for p in world.edits:
		records.append([p.x,p.y,p.z,world.edits[p]])
	var designations: Array = []
	for p in mining_jobs:
		if p is Vector3i:
			designations.append([p.x,p.y,p.z])
	var file := FileAccess.open(path + ".tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version":VERSION,"seed":world.world_seed,"edits":records,"mining_designations":designations,"logistics":logistics_state,"woodcut":woodcut_state,"dig":dig_state,"worker_roles":worker_roles}))
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

## Optional in version 1 saves. Missing/invalid entries are ignored.
static func restore_mining_jobs(path: String) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if not FileAccess.file_exists(path):
		return result
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != VERSION:
		return result
	var rows = data.get("mining_designations", [])
	if not rows is Array:
		return result
	for row in rows:
		if not row is Array or row.size() != 3:
			continue
		var valid := true
		for value in row:
			if (not value is float and not value is int) or float(value) != floor(float(value)):
				valid = false
		if not valid:
			continue
		var p := Vector3i(int(row[0]),int(row[1]),int(row[2]))
		if p.y >= 0 and p.y < World.HEIGHT and not result.has(p):
			result.append(p)
	return result

## Older world files omit this optional resource state.
static func restore_logistics(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and data.get("version") == VERSION and data.get("logistics", {}) is Dictionary:
		return data.get("logistics", {})
	return {}

## Optional tree harvesting and pending woodcut jobs in version-1 saves.
static func restore_woodcut(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and data.get("version") == VERSION and data.get("woodcut", {}) is Dictionary:
		return data.get("woodcut", {})
	return {}

## Optional staged excavation plans (version 1 format, older worlds load as usual).
static func restore_dig(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and data.get("version") == VERSION and data.get("dig", {}) is Dictionary:
		return data.get("dig", {})
	return {}

## Optional per-colonist occupation; older save files keep default assignments.
static func restore_worker_roles(path: String) -> Array[String]:
	var result: Array[String] = []
	if not FileAccess.file_exists(path):
		return result
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != VERSION:
		return result
	var roles = data.get("worker_roles",[])
	if not roles is Array or roles.size() > 3:
		return result
	for role in roles:
		if role is String and role in ["Miner","Woodcutter","Hauler"]:
			result.append(role)
		else:
			return []
	return result

## Non-destructive recovery for incompatible/oversized old saved worlds.
## Rename only after choosing New World; backups remain readable with restore().
static func archive(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var base := path + ".backup-" + str(int(Time.get_unix_time_from_system()))
	var destination := base
	var serial := 1
	while FileAccess.file_exists(destination):
		destination = base + "-" + str(serial)
		serial += 1
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(destination)) != OK:
		return ""
	return destination
