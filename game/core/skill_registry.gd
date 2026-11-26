extends RefCounted
const Bus = preload("res://core/event_bus.gd")
## Safe, deliberately restricted SKILL.md metadata registry.
## Imported text is data; no scripts, shell commands or network access.
const MAX_BYTES := 65536
const ToolRegistry = preload("res://core/tool_registry.gd")
const TOOLS = ToolRegistry.IDS
const Snapshot = preload("res://core/snapshot_store.gd")
var _storage
var _root: String
var _skills: Dictionary = {}
var _bindings: Dictionary = {}
var _inventory: Dictionary = {}
var _ready := false

func _init(root: String = "user://cubyte/skills") -> void:
	_root = root
	_storage = Snapshot.new(root, "registry.json")
	_ready = _storage.ready
	if _ready:
		var saved: Dictionary = _storage.read("registry", "", 16777216)
		_ready = saved.get("ok", false)
		if _ready and saved.get("found", false):
			_ready = _load()
			if _ready and _storage.native and saved.get("legacy", false):
				_ready = _save()


func _valid_name(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value.begins_with("-") or value.ends_with("-") or value.contains("--"):
		return false
	for ch in value:
		if not "abcdefghijklmnopqrstuvwxyz0123456789-".contains(ch):
			return false
	return true

func _parse(markdown: String) -> Dictionary:
	if markdown.to_utf8_buffer().size() > MAX_BYTES:
		return {}
	var lines := markdown.replace("\r\n", "\n").split("\n")
	if lines.size() < 4 or lines[0] != "---":
		return {}
	var metadata := {}
	var closed := false
	for i in range(1, lines.size()):
		var line: String = lines[i]
		if line == "---":
			closed = true
			break
		if line.strip_edges().is_empty() or line.begins_with("#"):
			continue
		# Only unindented scalar keys; nested YAML and block scalars are unsupported.
		var colon := line.find(":")
		if colon < 1 or line.begins_with(" ") or line.begins_with("\t"):
			return {}
		var key := line.substr(0, colon).strip_edges()
		if key not in ["name", "description", "license", "compatibility", "allowed-tools", "steps"] or metadata.has(key):
			return {}
		var value := line.substr(colon + 1).strip_edges()
		if value.begins_with("'") and value.ends_with("'") and value.length() >= 2:
			value = value.substr(1, value.length() - 2)
		elif value.begins_with('"') and value.ends_with('"') and value.length() >= 2:
			value = value.substr(1, value.length() - 2)
		elif value.begins_with("|") or value.begins_with(">") or value.begins_with("[") or value.begins_with("{") or value.begins_with("&") or value.begins_with("*") or value.begins_with("!"):
			return {}
		metadata[key] = value
	if not closed or not _valid_name(metadata.get("name", "")):
		return {}
	var description: String = metadata.get("description", "")
	if description.is_empty() or description.length() > 1024:
		return {}
	return {"name": metadata["name"], "description": description, "markdown": markdown, "allowed_tools": str(metadata.get("allowed-tools", "")), "compatibility": str(metadata.get("compatibility", "")), "steps": str(metadata.get("steps", ""))}

func import_markdown(markdown: String) -> String:
	if not _ready or _skills.size() >= 128:
		return ""
	var skill := _parse(markdown)
	if skill.is_empty() or _skills.has(skill["name"]):
		return ""
	var name_: String = skill["name"]
	_skills[name_] = skill
	if not _save():
		_skills.erase(name_)
		return ""
	Bus.publish("skill.imported", {"skill": name_})
	return name_

func list_names() -> Array:
	var names := _skills.keys()
	names.sort()
	return names

func get_skill(name_: String) -> Dictionary:
	var skill: Dictionary = _skills.get(name_, {})
	return skill.duplicate(true)

func get_binding(robot_id: String) -> Dictionary:
	var binding: Dictionary = _bindings.get(robot_id, {})
	return binding.duplicate(true)

func inventory(robot_id: String) -> Array:
	var owned: Array = _inventory.get(robot_id, [])
	return owned.duplicate()

func equip(robot_id: String, name_: String, tool: String) -> bool:
	if not _ready or robot_id.is_empty() or robot_id.length() > 64 or not _skills.has(name_) or tool not in TOOLS or (_bindings.size() >= 128 and not _bindings.has(robot_id)):
		return false
	if not dependency_report(name_, tool).get("ok", false):
		return false
	var previous := get_binding(robot_id)
	var previous_inventory := inventory(robot_id)
	var owned := previous_inventory.duplicate()
	if name_ not in owned:
		owned.append(name_)
	_inventory[robot_id] = owned
	_bindings[robot_id] = {"skill": name_, "tool": tool}
	if not _save():
		if previous_inventory.is_empty():
			_inventory.erase(robot_id)
		else:
			_inventory[robot_id] = previous_inventory
		if previous.is_empty():
			_bindings.erase(robot_id)
		else:
			_bindings[robot_id] = previous
		return false
	Bus.publish("skill.assigned", {"robot_id": robot_id, "skill": name_, "tool": tool})
	return true

func _save() -> bool:
	return _storage.write("registry", JSON.stringify({"version": 1, "skills": _skills, "bindings": _bindings, "inventory": _inventory}))

func _load() -> bool:
	var saved_data: Dictionary = _storage.read("registry", "", 16777216)
	if not saved_data.get("ok", false) or not saved_data.get("found", false):
		return false
	var raw: Variant = JSON.parse_string(str(saved_data.get("value", "")))
	if not raw is Dictionary or raw.get("version") != 1 or not raw.get("skills") is Dictionary or not raw.get("bindings") is Dictionary:
		return false
	var skills: Dictionary = raw["skills"]
	var bindings: Dictionary = raw["bindings"]
	if skills.size() > 128 or bindings.size() > 128:
		return false
	var validated := {}
	for key in skills:
		var item: Variant = skills[key]
		if not item is Dictionary or not item.get("markdown") is String:
			return false
		var parsed := _parse(item["markdown"])
		if parsed.is_empty() or parsed["name"] != key:
			return false
		validated[key] = parsed
	for robot in bindings:
		var binding: Variant = bindings[robot]
		if not robot is String or robot.is_empty() or robot.length() > 64 or not binding is Dictionary:
			return false
		if not validated.has(binding.get("skill")) or binding.get("tool") not in TOOLS:
			return false
	var owned: Variant = raw.get("inventory", {})
	if not owned is Dictionary or owned.size() > 128:
		return false
	for robot in owned:
		if not robot is String or robot.is_empty() or robot.length() > 64 or not owned[robot] is Array or owned[robot].size() > 128:
			return false
		for name_ in owned[robot]:
			if not name_ is String or not validated.has(name_):
				return false
	for robot in bindings:
		var names: Array = owned.get(robot, [])
		if bindings[robot]["skill"] not in names:
			names.append(bindings[robot]["skill"])
		owned[robot] = names
	_skills = validated
	_bindings = bindings
	_inventory = owned
	return true

# Metadata constraints are declarative; unsupported external dependencies fail closed.
func dependency_report(name_: String, tool: String) -> Dictionary:
	var skill := get_skill(name_)
	if skill.is_empty() or tool not in TOOLS:
		return {"ok": false, "reason": "Unknown skill or tool."}
	var compatibility := str(skill.get("compatibility", "")).strip_edges().to_lower()
	if not compatibility.is_empty() and compatibility not in ["native", "android", "cubyte"]:
		return {"ok": false, "reason": "External compatibility requirement is unsupported."}
	var allowed := str(skill.get("allowed_tools", "")).strip_edges()
	if not allowed.is_empty():
		var ids := allowed.replace(",", " ").split(" ", false)
		for required in ids:
			if required not in TOOLS:
				return {"ok": false, "reason": "Unsupported tool: " + required}
		if tool not in ids:
			return {"ok": false, "reason": "Selected tool is not declared."}
	return {"ok": true, "reason": "Native requirements supported."}

func export_markdown(name_: String) -> String:
	return str(get_skill(name_).get("markdown", ""))

func export_file(name_: String) -> String:
	if not _valid_name(name_):
		return ""
	var markdown := export_markdown(name_)
	if markdown.is_empty():
		return ""
	var directory := _root + "/exports/" + name_
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return ""
	var path := directory + "/SKILL.md"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(markdown)
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	return path if ok else ""

# Optional native-only sequence: steps: md, json, pdf
# Payloads are entered by the player as a JSON array of strings, not executable skill code.
func workflow_plan(name_: String, payloads: Array) -> Array:
	var skill := get_skill(name_)
	var steps := str(skill.get("steps", "")).replace(",", " ").split(" ", false)
	if steps.is_empty() or steps.size() > 8 or payloads.size() != steps.size():
		return []
	var result: Array = []
	for i in range(steps.size()):
		if not payloads[i] is String or not dependency_report(name_, steps[i]).get("ok", false):
			return []
		result.append({"tool": steps[i], "payload": payloads[i]})
	return result
