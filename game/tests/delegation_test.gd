extends SceneTree
const EngineCore = preload("res://core/task_engine.gd")
const Roster = preload("res://core/robot_roster.gd")

func _initialize() -> void:
	var root := "user://cubyte-delegation-test-" + str(Time.get_ticks_usec())
	var roster = Roster.new(root + "/robots")
	var engine = EngineCore.new(root)
	engine.set_permission_checker(Callable(roster, "can_use"))
	var ok: bool = roster.delegate("png") == "pixel" and roster.delegate("text") == "mesh"
	var old: String = engine.enqueue("mesh", "text", "older task")
	var task: String = engine.enqueue("mesh", "text", "delegated note", "atlas")
	ok = ok and not task.is_empty()
	ok = engine.run_task(task) and ok
	ok = ok and engine.get_task(old).get("status") == "queued"
	ok = ok and engine.get_task(task).get("status") == "succeeded"
	var reopened = EngineCore.new(root)
	reopened.set_permission_checker(Callable(roster, "can_use"))
	var history: Array = reopened.history("atlas")
	ok = ok and history.size() == 1
	if history.size() == 1:
		ok = ok and history[0].get("requested_by") == "atlas"
		ok = ok and history[0].get("robot_id") == "mesh"
	ok = roster.set_permission("atlas", "text", false) and ok
	ok = ok and reopened.enqueue("mesh", "text", "denied", "atlas").is_empty()
	ok = ok and reopened.enqueue("mesh", "text", "invalid requester", "pixel").is_empty()
	print("Delegation smoke test: " + ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
