extends RefCounted
## Deterministic, single-worker native runtime. No shell or network access.
signal task_changed(task: Dictionary)
const ToolRegistry = preload("res://core/tool_registry.gd")
const TOOLS = ToolRegistry.IDS
const MAX_TEXT_BYTES := 65536
var _root: String
var _tasks: Dictionary = {}
var _next_id: int = 1
var _ready: bool = false
var _permission_checker: Callable

func _init(root: String = "user://cubyte") -> void:
	_root = root
	_ready = DirAccess.make_dir_recursive_absolute(_root + "/artifacts") == OK
	if _ready and FileAccess.file_exists(_root + "/tasks.json"):
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
		if _tasks.has(id) and _tasks[id]["robot_id"] == robot_id:
			var item: Dictionary = get_task(id)
			item.erase("payload")
			result.append(item)
			if result.size() >= mini(limit, 100):
				break
	return result

func enqueue(robot_id: String, tool: String, payload: String) -> String:
	if not _ready or robot_id.is_empty() or robot_id.length() > 64 or not tool in TOOLS or payload.to_utf8_buffer().size() > MAX_TEXT_BYTES:
		return ""
	if not _allowed(robot_id, tool):
		return ""
	var id := str(_next_id)
	_next_id += 1
	_tasks[id] = {"id": id, "robot_id": robot_id, "tool": tool, "payload": payload, "status": "queued", "artifact": "", "error": ""}
	if not _save():
		_tasks.erase(id)
		_ready = false
		return ""
	task_changed.emit(get_task(id))
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

func _execute(id: String) -> void:
	var task: Dictionary = _tasks[id]
	var tool: String = task["tool"]
	if not _allowed(task["robot_id"], tool):
		task["error"] = "Tool permission denied."
		task["payload"] = ""
		_transition(id, "failed")
		return
	var path := _root + "/artifacts/" + id + (".txt" if tool == "text" else ".png")
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
		task_changed.emit(get_task(id))
		return false
	task_changed.emit(get_task(id))
	return true

func _save() -> bool:
	var temp := _root + "/tasks.json.tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": 1, "next_id": _next_id, "tasks": _tasks}))
	file.flush()
	var success := file.get_error() == OK
	file.close()
	return success and DirAccess.rename_absolute(temp, _root + "/tasks.json") == OK

func load_state() -> bool:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(_root + "/tasks.json"))
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
		if item["payload"].to_utf8_buffer().size() > MAX_TEXT_BYTES:
			return false
		var expected := _root + "/artifacts/" + id + (".txt" if item["tool"] == "text" else ".png")
		if item["status"] == "running":
			item["status"] = "interrupted"
			item["artifact"] = ""
			item["error"] = "Previous session stopped during execution."
		elif item["status"] == "succeeded":
			if item.get("artifact") != expected or not FileAccess.file_exists(expected):
				item["status"] = "failed"
				item["artifact"] = ""
				item["error"] = "Saved artifact missing or invalid."
		else:
			item["artifact"] = ""
	_tasks = restored
	_next_id = next
	return _save()
