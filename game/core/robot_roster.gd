extends RefCounted
const Bus = preload("res://core/event_bus.gd")
## Local profiles and explicit permissions. No model inference.
const IDS := ["atlas", "pixel", "mesh"]
const ToolRegistry = preload("res://core/tool_registry.gd")
const TOOLS = ToolRegistry.IDS
const DEFAULTS := {
	"atlas": {"role": "Manager", "personality": "Organized", "specialization": "Coordination"},
	"pixel": {"role": "Designer", "personality": "Creative", "specialization": "PNG"},
	"mesh": {"role": "3D Artist", "personality": "Methodical", "specialization": "Geometry (future)"}
}
const Snapshot = preload("res://core/snapshot_store.gd")
var _storage: RefCounted
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
	_storage = Snapshot.new(root, "profiles.json")
	_ready = _storage.ready
	if _ready:
		var saved: Dictionary = _storage.read("profiles", "", 65536)
		_ready = saved.get("ok", false)
		if _ready and saved.get("found", false):
			_ready = _load()
			if _ready and _storage.native and saved.get("legacy", false):
				_ready = _save()


func is_ready() -> bool:
	return _ready

func get_profile(id: String) -> Dictionary:
	var profile: Dictionary = _profiles.get(id, {})
	return profile.duplicate(true)

func set_memory(id: String, value: String) -> bool:
	if value.to_utf8_buffer().size() > 4096:
		return false
	return _set_profile_field(id, "memory", value)

func set_personality(id: String, value: String) -> bool:
	if value.strip_edges().is_empty() or value.to_utf8_buffer().size() > 128:
		return false
	return _set_profile_field(id, "personality", value.strip_edges())

func set_permission(id: String, tool: String, allowed: bool) -> bool:
	if not _ready or not _profiles.has(id) or tool not in TOOLS:
		return false
	var permissions: Dictionary = _profiles[id]["permissions"].duplicate()
	permissions[tool] = allowed
	return _set_profile_field(id, "permissions", permissions)

func can_use(id: String, tool: String) -> bool:
	return _ready and _profiles.has(id) and tool in TOOLS and _profiles[id]["permissions"].get(tool, false) == true

func delegate(tool: String) -> String:
	var candidates := ["pixel", "mesh"] if tool == "png" else ["mesh", "pixel"]
	for id in candidates:
		if can_use(id, tool):
			return id
	return ""

func _set_profile_field(id: String, key: String, value: Variant) -> bool:
	if not _ready or not _profiles.has(id):
		return false
	var previous: Variant = _profiles[id][key]
	_profiles[id][key] = value
	if not _save():
		_profiles[id][key] = previous
		return false
	Bus.publish("robot.profile_changed", {"robot_id": id, "field": key})
	return true

func _save() -> bool:
	return _storage.write("profiles", JSON.stringify({"version": 1, "profiles": _profiles}))

func _load() -> bool:
	var saved_data: Dictionary = _storage.read("profiles", "", 65536)
	if not saved_data.get("ok", false) or not saved_data.get("found", false):
		return false
	var raw: Variant = JSON.parse_string(str(saved_data.get("value", "")))
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
