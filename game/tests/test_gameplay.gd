extends SceneTree
const Company = preload("res://core/company.gd")
const EngineCore = preload("res://core/task_engine.gd")
const Roster = preload("res://core/robot_roster.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_ := "user://gameplay_test_" + str(Time.get_ticks_usec())
	var company = Company.new(root_ + "/company")
	check(company.ready, "company store")
	check(int(company.snapshot()["credits"]) == 100, "starting credits")
	check(company.purchase("plant"), "purchase plant")
	check(not company.purchase("plant"), "duplicate purchase refused")
	check(not company.purchase("unknown"), "unknown purchase refused")
	check(company.rename_company("Studio Test"), "rename company")
	var roster = Roster.new(root_ + "/robots")
	var engine = EngineCore.new(root_ + "/tasks")
	engine.set_permission_checker(Callable(roster,"can_use"))
	var steps := [{"robot_id":"atlas","tool":"text","payload":"brief"},{"robot_id":"pixel","tool":"png","payload":""},{"robot_id":"mesh","tool":"text","payload":"report"}]
	var ids: Array[String] = engine.enqueue_team_workflow(steps)
	check(ids.size() == 3, "team workflow created")
	for i in range(ids.size()):
		check(engine.get_task(ids[i]).get("robot_id") == steps[i]["robot_id"], "worker assigned")
		check(engine.run_task(ids[i]), "execute task")
		var task: Dictionary = engine.get_task(ids[i])
		check(task.get("status") == "succeeded", "task completed")
		check(company.reward(task), "task reward")
		check(not company.reward(task), "duplicate reward blocked")
	var restored = Company.new(root_ + "/company")
	check(restored.snapshot()["company"] == "Studio Test", "company name persisted")
	check(int(restored.snapshot()["credits"]) == 105, "credits persisted")
	check(int(restored.snapshot()["completed"]) == 3, "completed persisted")
	check("plant" in restored.snapshot()["upgrades"], "upgrade persisted")
	var before: int = engine.list_tasks().size()
	steps[1]["tool"] = "pdf"
	check(engine.enqueue_team_workflow(steps).is_empty(), "denied workflow rejected")
	check(engine.list_tasks().size() == before, "no partial queue")
	print("CUBYTE gameplay tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
