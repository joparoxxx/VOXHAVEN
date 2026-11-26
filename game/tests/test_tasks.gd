extends SceneTree

const EngineScript = preload("res://core/task_engine.gd")
var failures := 0
var events: Array = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("_run")

func _on_event(topic: String, details: Dictionary) -> void:
	if topic == "task.changed":
		events.append(details.duplicate())

func _run() -> void:
	var bus := self.root.get_node_or_null("Events")
	check(bus != null, "global event bus registered")
	if bus != null:
		bus.connect("published", _on_event)
	var root := "user://test_" + str(Time.get_ticks_usec()) + "_" + str(randi())
	var engine = EngineScript.new(root)
	var id: String = engine.enqueue("atlas", "text", "CUBYTE test")
	check(not id.is_empty(), "queued ID")
	check(engine.run_next(), "run text")
	var task: Dictionary = engine.get_task(id)
	check(task.get("status") == "succeeded", "text succeeded")
	check(FileAccess.get_file_as_string(task.get("artifact", "")) == "CUBYTE test", "real text bytes")
	var png: String = engine.enqueue("pixel", "png", "")
	check(engine.run_next(), "run png")
	var image := Image.new()
	check(image.load(engine.get_task(png).get("artifact", "")) == OK, "valid png")
	check(image.get_width() == 128 and image.get_height() == 128, "png dimensions")
	var invalid: String = engine.enqueue("atlas", "../shell", "")
	check(invalid.is_empty(), "unknown tool rejected")
	check(engine.enqueue("atlas", "text", "x".repeat(65537)).is_empty(), "oversized input rejected")
	var cancelled: String = engine.enqueue("atlas", "text", "never")
	check(engine.cancel(cancelled), "cancel queued")
	check(not engine.run_next(), "cancelled not run")
	check(engine.get_task(cancelled).get("artifact", "").is_empty(), "cancelled has no output")
	var restored = EngineScript.new(root)
	check(restored.load_state(), "load persisted state")
	check(restored.get_task(id).get("status") == "succeeded", "restore success")
	check(restored.get_task(cancelled).get("status") == "cancelled", "restore cancelled")
	var interrupted: String = restored.enqueue("atlas", "text", "interrupted")
	check(ClassDB.class_exists("CubyteStore"), "native SQLite class present")
	if not ClassDB.class_exists("CubyteStore"):
		quit(1)
		return
	var db: Object = ClassDB.instantiate("CubyteStore")
	check(db.call("open", ProjectSettings.globalize_path(root + "/tasks.sqlite3")) == true, "open SQLite database")
	var stored: Dictionary = db.call("read", "tasks")
	check(stored.get("ok", false) and stored.get("found", false), "task state stored in SQLite")
	var saved: Dictionary = JSON.parse_string(str(stored.get("value", "{}")))
	saved["tasks"][interrupted]["status"] = "running"
	check(db.call("write", "tasks", JSON.stringify(saved)) == true, "simulate interrupted task")
	check(not FileAccess.file_exists(root + "/tasks.json"), "new database does not create legacy JSON")
	var restarted = EngineScript.new(root)
	check(restarted.load_state(), "reload after interruption")
	check(restarted.get_task(interrupted).get("status") == "interrupted", "recover running task")
	check(events.size() > 0, "task events published")
	for details in events:
		check(not details.has("payload") and not details.has("artifact"), "events omit file data")
	var legacy_root := root + "/migration"
	DirAccess.make_dir_recursive_absolute(legacy_root + "/artifacts")
	var legacy := {"version": 1, "next_id": 2, "tasks": {"1": {"id": "1", "robot_id": "atlas", "tool": "text", "payload": "legacy note", "status": "queued", "artifact": "", "error": ""}}}
	var old := FileAccess.open(legacy_root + "/tasks.json", FileAccess.WRITE)
	old.store_string(JSON.stringify(legacy))
	old.close()
	var migrated = EngineScript.new(legacy_root)
	check(migrated.is_ready(), "legacy task state migrated")
	check(migrated.get_task("1").get("status") == "queued", "legacy task preserved")
	check(migrated.run_task("1"), "migrated task executes")
	var reloaded = EngineScript.new(legacy_root)
	check(reloaded.get_task("1").get("status") == "succeeded", "database takes precedence over stale backup")
	check(FileAccess.file_exists(legacy_root + "/tasks.json"), "legacy backup retained")
	if bus != null:
		bus.disconnect("published", _on_event)
	print("CUBYTE task tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
