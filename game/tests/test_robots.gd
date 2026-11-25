extends SceneTree

const Roster = preload("res://core/robot_roster.gd")
const EngineScript = preload("res://core/task_engine.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	var root := "user://robot_test_" + str(Time.get_ticks_usec()) + "_" + str(randi())
	var roster = Roster.new(root + "/robots")
	check(roster.is_ready(), "roster ready")
	check(roster.get_profile("atlas").get("role") == "Manager", "manager profile")
	check(roster.set_memory("pixel", "Use blue."), "save memory")
	check(roster.get_profile("atlas").get("memory") == "", "memory isolated")
	check(roster.set_personality("pixel", "Patient"), "save personality")
	check(not roster.set_memory("unknown", "no"), "unknown robot denied")
	check(not roster.set_memory("pixel", "x".repeat(5000)), "bounded memory")
	check(not roster.can_use("pixel", "shell"), "unknown tool denied")
	check(roster.delegate("png") == "pixel", "prefer specialist")
	check(roster.set_permission("pixel", "png", false), "revoke")
	check(roster.delegate("png") == "mesh", "fallback to permitted worker")
	check(roster.set_permission("mesh", "png", false), "revoke fallback")
	check(roster.delegate("png").is_empty(), "no eligible worker")
	var restored = Roster.new(root + "/robots")
	check(restored.get_profile("pixel").get("memory") == "Use blue.", "memory persisted")
	check(restored.get_profile("pixel").get("personality") == "Patient", "personality persisted")
	check(not restored.can_use("pixel", "png"), "permission persisted")
	var engine = EngineScript.new(root + "/tasks")
	engine.set_permission_checker(Callable(restored, "can_use"))
	check(engine.enqueue("pixel", "png", "").is_empty(), "enqueue permission enforced")
	var id: String = engine.enqueue("atlas", "text", "hello")
	check(not id.is_empty(), "permitted task queued")
	check(restored.set_permission("atlas", "text", false), "revoke queued permission")
	check(engine.run_next(), "consume denied queued task")
	check(engine.get_task(id).get("status") == "failed", "execution permission rechecked")
	check(engine.get_task(id).get("artifact") == "", "denied task has no artifact")
	check(engine.history("atlas").size() == 1, "history recorded")
	check(engine.history("pixel").is_empty(), "history isolated")
	print("CUBYTE robot tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
