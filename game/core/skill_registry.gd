extends RefCounted
## Safe, deliberately restricted SKILL.md metadata registry.
## Imported text is data; no scripts, shell commands or network access.
const MAX_BYTES := 65536
const TOOLS := ["text", "png"]
var _root: String
var _skills: Dictionary = {}
var _bindings: Dictionary = {}
var _ready := false

func _init(root: String = "user://cubyte/skills") -> void:
	_root = root
	_ready = DirAccess.make_dir_recursive_absolute(root) == OK
	if _ready and FileAccess.file_exists(root + "/registry.json"):
		_ready = _load()

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
		if key not in ["name", "description", "license", "compatibility", "allowed-tools"] or metadata.has(key):
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
	return {"name": metadata["name"], "description": description, "markdown": markdown}

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

func equip(robot_id: String, name_: String, tool: String) -> bool:
	if not _ready or robot_id.is_empty() or robot_id.length() > 64 or not _skills.has(name_) or tool not in TOOLS or (_bindings.size() >= 128 and not _bindings.has(robot_id)):
		return false
	var previous := get_binding(robot_id)
	_bindings[robot_id] = {"skill": name_, "tool": tool}
	if not _save():
		if previous.is_empty():
			_bindings.erase(robot_id)
		else:
			_bindings[robot_id] = previous
		return false
	return true

func _save() -> bool:
	var temp := _root + "/registry.json.tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": 1, "skills": _skills, "bindings": _bindings}))
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	return ok and DirAccess.rename_absolute(temp, _root + "/registry.json") == OK

func _load() -> bool:
	var f := FileAccess.open(_root + "/registry.json", FileAccess.READ)
	if f == null or f.get_length() > 16 * 1024 * 1024:
		return false
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
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
	_skills = validated
	_bindings = bindings
	return true
