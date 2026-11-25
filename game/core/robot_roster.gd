extends RefCounted
## Local profiles and explicit permissions. No model inference.
const IDS := ["atlas", "pixel", "mesh"]
const TOOLS := ["text", "png"]
const DEFAULTS := {
	"atlas": {"role": "Manager", "personality": "Organized", "specialization": "Coordination"},
	"pixel": {"role": "Designer", "personality": "Creative", "specialization": "PNG"},
	"mesh": {"role": "3D Artist", "personality": "Methodical", "specialization": "Geometry (future)"}
}
var _root: String
var _profiles := {}
var _ready := false

func _init(root: String = "user://cubyte/robots") -> void:
	_root = root
	for id in IDS:
		var profile: Dictionary = DEFAULTS[id].duplicate(true)
		profile["id"] = id
		profile["memory"] = ""
		profile["permissions"] = {"text": true, "png": true}
		_profiles[id] = profile
	_ready = DirAccess.make_dir_recursive_absolute(root) == OK
	if _ready and FileAccess.file_exists(root + "/profiles.json"):
		_ready = _load()

func is_ready() -> bool:
	return _ready

func get_profile(id: String) -> Dictionary:
	var profile: Dictionary = _profiles.get(id, {})
	return profile.duplicate(true)

func set_memory(id: String, value: String) -> bool:
	if value.to_utf8_buffer().size() > 4096:
		return false
	return _set(id, "memory", value)

func set_personality(id: String, value: String) -> bool:
	if value.strip_edges().is_empty() or value.to_utf8_buffer().size() > 128:
		return false
	return _set(id, "personality", value.strip_edges())

func set_permission(id: String, tool: String, allowed: bool) -> bool:
	if not _ready or not _profiles.has(id) or tool not in TOOLS:
		return false
	var permissions: Dictionary = _profiles[id]["permissions"].duplicate()
	permissions[tool] = allowed
	return _set(id, "permissions", permissions)

func can_use(id: String, tool: String) -> bool:
	return _ready and _profiles.has(id) and tool in TOOLS and _profiles[id]["permissions"].get(tool, false) == true

func delegate(tool: String) -> String:
	var candidates := ["pixel", "mesh"] if tool == "png" else ["mesh", "pixel"]
	for id in candidates:
		if can_use(id, tool):
			return id
	return ""

func _set(id: String, key: String, value: Variant) -> bool:
	if not _ready or not _profiles.has(id):
		return false
	var previous: Variant = _profiles[id][key]
	_profiles[id][key] = value
	if not _save():
		_profiles[id][key] = previous
		return false
	return true

func _save() -> bool:
	var temp := _root + "/profiles.json.tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": 1, "profiles": _profiles}))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(temp, _root + "/profiles.json") == OK

func _load() -> bool:
	var file := FileAccess.open(_root + "/profiles.json", FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return false
	var raw: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not raw is Dictionary or raw.get("version") != 1 or not raw.get("profiles") is Dictionary:
		return false
	var saved: Dictionary = raw["profiles"]
	var validated := {}
	for id in IDS:
		var p: Variant = saved.get(id)
		if not p is Dictionary or not p.get("memory") is String or not p.get("personality") is String or not p.get("permissions") is Dictionary:
			return false
		if p["memory"].to_utf8_buffer().size() > 4096 or p["personality"].strip_edges().is_empty() or p["personality"].to_utf8_buffer().size() > 128:
			return false
		var profile: Dictionary = _profiles[id].duplicate(true)
		profile["memory"] = p["memory"]
		profile["personality"] = p["personality"]
		for tool in TOOLS:
			if not p["permissions"].get(tool) is bool:
				return false
			profile["permissions"][tool] = p["permissions"][tool]
		validated[id] = profile
	_profiles = validated
	return true
