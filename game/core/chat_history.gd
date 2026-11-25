extends RefCounted
## Local-only bounded conversation history. No network calls.
const IDS := ["atlas", "pixel", "mesh"]
const MAX_TURNS := 12
const MAX_FILE_BYTES := 524288
const Snapshot = preload("res://core/snapshot_store.gd")
var _storage: RefCounted
var _root: String

func _init(root: String = "user://cubyte/chats") -> void:
	_root = root
	_storage = Snapshot.new(root, "unused.json")

func load_all() -> Dictionary:
	var result := {}
	for id in IDS:
		var path: String = _root + "/" + str(id) + ".json"
		var stored: Dictionary = _storage.read("chat:" + id, path, MAX_FILE_BYTES)
		if not stored.get("ok", false) or not stored.get("found", false):
			continue
		var raw: Variant = JSON.parse_string(str(stored.get("value", "")))
		if raw is Dictionary and raw.get("version") == 1 and raw.get("turns") is Array:
			var turns := _validated(raw["turns"])
			if not turns.is_empty():
				result[id] = turns
			if _storage.native and stored.get("legacy", false):
				save(id, turns)
	return result

func save(id: String, turns: Array) -> bool:
	if id not in IDS:
		return false
	var path: String = _root + "/" + str(id) + ".json"
	var encoded := JSON.stringify({"version": 1, "turns": _validated(turns)})
	if encoded.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return false
	return _storage.write("chat:" + id, encoded, path)

func clear(id: String) -> bool:
	if id not in IDS or not _storage.ready:
		return false
	# An empty database snapshot prevents old backups from restoring cleared history.
	if _storage.native and not save(id, []):
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
