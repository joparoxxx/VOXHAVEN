extends RefCounted
## Local-only bounded conversation history. No network calls.
const IDS := ["atlas", "pixel", "mesh"]
const MAX_TURNS := 12
const MAX_FILE_BYTES := 524288
var _root: String

func _init(root: String = "user://cubyte/chats") -> void:
	_root = root

func load_all() -> Dictionary:
	var result := {}
	for id in IDS:
		var path: String = _root + "/" + str(id) + ".json"
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		if file.get_length() > MAX_FILE_BYTES:
			file.close()
			continue
		var raw: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if raw is Dictionary and raw.get("version") == 1 and raw.get("turns") is Array:
			result[id] = _validated(raw["turns"])
	return result

func save(id: String, turns: Array) -> bool:
	if id not in IDS or DirAccess.make_dir_recursive_absolute(_root) != OK:
		return false
	var path: String = _root + "/" + str(id) + ".json"
	var encoded := JSON.stringify({"version": 1, "turns": _validated(turns)})
	if encoded.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(encoded)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(path + ".tmp", path) == OK

func clear(id: String) -> bool:
	if id not in IDS:
		return false
	var path: String = _root + "/" + str(id) + ".json"
	for suffix in [".tmp", ""]:
		if FileAccess.file_exists(path + suffix) and DirAccess.remove_absolute(path + suffix) != OK:
			return false
	return true

func _validated(turns: Array) -> Array:
	var result := []
	for turn in turns.slice(maxi(0, turns.size() - MAX_TURNS)):
		if not turn is Dictionary or not turn.get("user") is String or not turn.get("assistant") is String:
			continue
		var user: String = turn["user"].left(2048)
		var assistant: String = turn["assistant"].left(4096)
		if not user.strip_edges().is_empty() and not assistant.strip_edges().is_empty():
			result.append({"user": user, "assistant": assistant})
	return result
