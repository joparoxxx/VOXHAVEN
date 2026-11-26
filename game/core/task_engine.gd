extends RefCounted
## Deterministic, single-worker native runtime. No shell or network access.
signal task_changed(task: Dictionary)
const Bus = preload("res://core/event_bus.gd")
const Writer = preload("res://core/artifact_writer.gd")
const ToolRegistry = preload("res://core/tool_registry.gd")
const TOOLS = ToolRegistry.IDS
const MAX_TEXT_BYTES := 65536
var _root: String
var _tasks: Dictionary = {}
var _next_id: int = 1
var _ready: bool = false
var _permission_checker: Callable
var _store: Object

func _init(root: String = "user://cubyte") -> void:
	_root = root
	_ready = DirAccess.make_dir_recursive_absolute(_root + "/artifacts") == OK
	if not _ready:
		return
	if ClassDB.class_exists("CubyteStore"):
		_store = ClassDB.instantiate("CubyteStore")
		if _store == null or not _store.call("open", ProjectSettings.globalize_path(_root + "/tasks.sqlite3")):
			_ready = false
			return
		var saved: Dictionary = _store.call("read", "tasks")
		if not saved.get("ok", false):
			_ready = false
			return
		if saved.get("found", false) or FileAccess.file_exists(_root + "/tasks.json"):
			_ready = load_state()
		else:
			_ready = _save()
	elif FileAccess.file_exists(_root + "/tasks.sqlite3"):
		# Never fall back to stale legacy JSON once the native database exists.
		_ready = false
	elif FileAccess.file_exists(_root + "/tasks.json"):
		_ready = load_state()

func is_ready() -> bool:
	return _ready

func set_permission_checker(checker: Callable) -> void:
	_permission_checker = checker

func _allowed(robot_id: String, tool: String) -> bool:
	return not _permission_checker.is_valid() or _permission_checker.call(robot_id, tool) == true

func history(robot_id: String, limit: int = 30) -> Array:
	var result := []
	if limit <= 0:
		return result
	for n in range(_next_id - 1, 0, -1):
		var id := str(n)
		if _tasks.has(id) and (_tasks[id]["robot_id"] == robot_id or _tasks[id].get("requested_by", "") == robot_id):
			var item: Dictionary = get_task(id)
			item.erase("payload")
			result.append(item)
			if result.size() >= mini(limit, 100):
				break
	return result

func enqueue(robot_id: String, tool: String, payload: String, requested_by: String = "") -> String:
	if not _ready or robot_id.is_empty() or robot_id.length() > 64 or not tool in TOOLS or payload.to_utf8_buffer().size() > MAX_TEXT_BYTES:
		return ""
	if not Writer.valid(tool, payload) or not _allowed(robot_id, tool):
		return ""
	if not requested_by.is_empty() and (requested_by != "atlas" or robot_id not in ["pixel", "mesh", "nova"] or not _allowed(requested_by, tool)):
		return ""
	var id := str(_next_id)
	_next_id += 1
	_tasks[id] = {"id": id, "robot_id": robot_id, "requested_by": requested_by, "tool": tool, "payload": payload, "status": "queued", "artifact": "", "error": ""}
	if not _save():
		_tasks.erase(id)
		_ready = false
		return ""
	_notify(id)
	return id

func get_task(id: String) -> Dictionary:
	var item: Dictionary = _tasks.get(id, {})
	return item.duplicate(true)

func cancel(id: String) -> bool:
	if not _ready or not _tasks.has(id) or _tasks[id]["status"] != "queued":
		return false
	return _transition(id, "cancelled")

func run_next() -> bool:
	if not _ready:
		return false
	for n in range(1, _next_id):
		var id := str(n)
		if _tasks.has(id) and _tasks[id]["status"] == "queued":
			if not _transition(id, "running"):
				return false
			_execute(id)
			return true
	return false

func run_task(id: String) -> bool:
	if not _ready or not _tasks.has(id) or _tasks[id]["status"] != "queued":
		return false
	if not _transition(id, "running"):
		return false
	_execute(id)
	return true

func _execute(id: String) -> void:
	var task: Dictionary = _tasks[id]
	var tool: String = task["tool"]
	if not _allowed(task["robot_id"], tool) or (not str(task.get("requested_by", "")).is_empty() and not _allowed(task["requested_by"], tool)):
		task["error"] = "Tool permission denied."
		_transition(id, "failed")
		return
	var path := _root + "/artifacts/" + id + ("." + str(ToolRegistry.describe(tool)["extension"]))
	var valid := false
	if tool == "text":
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(task["payload"])
			file.flush()
			var write_ok := file.get_error() == OK
			file.close()
			valid = write_ok and FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == task["payload"]
	elif tool == "png":
		var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		image.fill(Color("#182737"))
		image.fill_rect(Rect2i(12, 12, 104, 104), Color("#537fcc"))
		image.fill_rect(Rect2i(22, 24, 84, 78), Color("#101c2a"))
		image.fill_rect(Rect2i(38, 46, 12, 22), Color("#81f4df"))
		image.fill_rect(Rect2i(78, 46, 12, 22), Color("#81f4df"))
		image.fill_rect(Rect2i(52, 78, 24, 5), Color("#81f4df"))
		if image.save_png(path) == OK:
			var decoded := Image.new()
			valid = decoded.load(path) == OK and decoded.get_width() == 128 and decoded.get_height() == 128
	else:
		valid = Writer.create(tool, task["payload"], path)
	if valid:
		task["artifact"] = path
		task["payload"] = ""
		if not _transition(id, "succeeded"):
			DirAccess.remove_absolute(path)
			task["artifact"] = ""
	else:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		task["error"] = "Local tool could not write or validate output."
		_transition(id, "failed")

func _transition(id: String, status: String) -> bool:
	_tasks[id]["status"] = status
	if not _save():
		_ready = false
		_tasks[id]["status"] = "interrupted"
		_tasks[id]["artifact"] = ""
		_tasks[id]["error"] = "Could not persist task state."
		_notify(id)
		return false
	_notify(id)
	return true

func _notify(id: String) -> void:
	var snapshot := get_task(id)
	Bus.publish("task.changed", {"id": id, "robot_id": snapshot.get("robot_id", ""), "status": snapshot.get("status", "")})
	task_changed.emit(snapshot)

func _save() -> bool:
	var encoded := JSON.stringify({"version": 1, "next_id": _next_id, "tasks": _tasks})
	if _store != null:
		return _store.call("write", "tasks", encoded) == true
	var temp := _root + "/tasks.json.tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(encoded)
	file.flush()
	var success := file.get_error() == OK
	file.close()
	return success and DirAccess.rename_absolute(temp, _root + "/tasks.json") == OK

func load_state() -> bool:
	var encoded := ""
	if _store != null:
		var saved: Dictionary = _store.call("read", "tasks")
		if not saved.get("ok", false):
			return false
		if saved.get("found", false):
			encoded = str(saved.get("value", ""))
		else:
			encoded = FileAccess.get_file_as_string(_root + "/tasks.json")
	else:
		encoded = FileAccess.get_file_as_string(_root + "/tasks.json")
	if encoded.to_utf8_buffer().size() > 32 * 1024 * 1024:
		return false
	var raw: Variant = JSON.parse_string(encoded)
	if not raw is Dictionary or raw.get("version") != 1 or not raw.get("tasks") is Dictionary:
		return false
	var restored: Dictionary = raw["tasks"]
	var next: int = int(raw.get("next_id", 0))
	if next < 1 or next > 1000000:
		return false
	var states := ["queued", "running", "succeeded", "failed", "cancelled", "interrupted"]
	for key in restored:
		var id: String = str(key)
		var item: Variant = restored[key]
		if not id.is_valid_int() or str(int(id)) != id or int(id) < 1 or int(id) >= next or not item is Dictionary:
			return false
		if item.get("id") != id or not item.get("tool") in TOOLS or not item.get("status") in states or not item.get("payload") is String or not item.get("robot_id") is String:
			return false
		var requester: Variant = item.get("requested_by", "")
		if not requester is String or (requester != "" and (requester != "atlas" or item["robot_id"] not in ["pixel", "mesh", "nova"])):
			return false
		item["requested_by"] = requester
		if item["payload"].to_utf8_buffer().size() > MAX_TEXT_BYTES:
			return false
		var expected := _root + "/artifacts/" + id + ("." + str(ToolRegistry.describe(item["tool"])["extension"]))
		if item["status"] == "running":
			item["status"] = "interrupted"
			item["artifact"] = ""
			item["error"] = "Previous session stopped during execution."
		elif item["status"] == "succeeded":
			if item.get("artifact_deleted", false) == true:
				item["artifact"] = ""
			elif item.get("artifact") != expected or not FileAccess.file_exists(expected):
				item["status"] = "failed"
				item["artifact"] = ""
				item["error"] = "Saved artifact missing or invalid."
		else:
			item["artifact"] = ""
	_tasks = restored
	_next_id = next
	return _save()

# Read-only dashboard snapshots; no raw task payloads in the listing.
func list_tasks(limit: int = 100) -> Array:
	var result: Array = []
	for n in range(_next_id - 1, 0, -1):
		if result.size() >= clampi(limit, 1, 200):
			break
		var item := get_task(str(n))
		if not item.is_empty():
			item.erase("payload")
			result.append(item)
	return result

func retry_task(id: String) -> String:
	var task := get_task(id)
	if task.get("status", "") not in ["failed", "interrupted"]:
		return ""
	return enqueue(str(task["robot_id"]), str(task["tool"]), str(task["payload"]), str(task.get("requested_by", "")))

func artifact_path(id: String) -> String:
	var task := get_task(id)
	if task.get("status") != "succeeded" or task.get("artifact_deleted", false) == true:
		return ""
	var definition: Dictionary = ToolRegistry.describe(str(task.get("tool", "")))
	if definition.is_empty():
		return ""
	var expected := _root + "/artifacts/" + id + "." + str(definition["extension"])
	if task.get("artifact") != expected or not FileAccess.file_exists(expected):
		return ""
	return expected

func _safe_name(name_: String) -> bool:
	if name_.is_empty() or name_.length() > 64 or name_.begins_with("."):
		return false
	for ch in name_:
		if not ch in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_":
			return false
	return true

# Rename the displayed file without breaking the canonical on-disk task identifier.
func rename_artifact(id: String, name_: String) -> bool:
	if not _ready or not _safe_name(name_) or artifact_path(id).is_empty():
		return false
	var old: Dictionary = _tasks[id].duplicate(true)
	_tasks[id]["display_name"] = name_
	if not _save():
		_tasks[id] = old
		return false
	_notify(id)
	return true

func export_artifact(id: String) -> String:
	var source := artifact_path(id)
	if source.is_empty():
		return ""
	var task := get_task(id)
	var name_ := str(task.get("display_name", "task-" + id))
	if not _safe_name(name_):
		return ""
	var folder := _root + "/exports"
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return ""
	var target := folder + "/" + name_ + "." + str(ToolRegistry.describe(task["tool"])["extension"])
	if FileAccess.file_exists(target):
		return ""
	return target if DirAccess.copy_absolute(source, target) == OK else ""

func delete_artifact(id: String) -> bool:
	var path := artifact_path(id)
	if not _ready or path.is_empty():
		return false
	# Persist the tombstone first. Never delete a noncanonical path.
	var old: Dictionary = _tasks[id].duplicate(true)
	_tasks[id]["artifact"] = ""
	_tasks[id]["artifact_deleted"] = true
	if not _save():
		_tasks[id] = old
		return false
	if DirAccess.remove_absolute(path) != OK:
		_tasks[id] = old
		if not _save():
			_ready = false
		return false
	_notify(id)
	return true

# Atomically enqueue a user-approved native workflow. All permissions and payloads
# must pass before allocating any task. The runner stops on the first failure.
func enqueue_workflow(robot_id: String, steps: Array) -> Array[String]:
	var assigned: Array = []
	for step in steps:
		if not step is Dictionary:
			return []
		var entry: Dictionary = step.duplicate()
		entry["robot_id"] = robot_id
		assigned.append(entry)
	return enqueue_team_workflow(assigned)

func enqueue_team_workflow(steps: Array) -> Array[String]:
	var ids: Array[String] = []
	if not _ready or steps.is_empty() or steps.size() > 8 or _next_id + steps.size() >= 1000000:
		return ids
	for step in steps:
		if not step is Dictionary or not step.get("tool") is String or not step.get("payload") is String or step.get("robot_id") not in ["atlas", "pixel", "mesh", "nova"]:
			return ids
		if not _allowed(step["robot_id"], step["tool"]) or not Writer.valid(step["tool"], step["payload"]):
			return ids
	var previous := _next_id
	for step in steps:
		var id := str(_next_id)
		_next_id += 1
		_tasks[id] = {"id": id, "robot_id": step["robot_id"], "requested_by": "", "tool": step["tool"], "payload": step["payload"], "status": "queued", "artifact": "", "error": "", "workflow": str(previous)}
		ids.append(id)
	if not _save():
		for id in ids:
			_tasks.erase(id)
		_next_id = previous
		ids.clear()
		_ready = false
		return ids
	for id in ids:
		_notify(id)
	return ids
