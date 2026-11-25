extends SceneTree

const EngineScript = preload("res://core/task_engine.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
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
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root + "/tasks.json"))
	saved["tasks"][interrupted]["status"] = "running"
	var f := FileAccess.open(root + "/tasks.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(saved))
	f.close()
	var restarted = EngineScript.new(root)
	check(restarted.load_state(), "reload after interruption")
	check(restarted.get_task(interrupted).get("status") == "interrupted", "recover running task")
	print("CUBYTE task tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
