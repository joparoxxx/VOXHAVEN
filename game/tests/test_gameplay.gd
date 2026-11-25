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
	check(not restored.can_hire(), "hire locked at level one")
	check(not roster.can_use("nova", "text"), "locked specialist cannot execute")
	check(engine.enqueue_team_workflow([{"robot_id":"nova","tool":"text","payload":"locked"}]).is_empty(), "locked specialist workflow rejected")
	for i in range(2):
		var task_id: String = engine.enqueue("atlas", "text", "level progress")
		check(engine.run_task(task_id), "execute progression task")
		check(restored.reward(engine.get_task(task_id)), "credit progression task")
	check(restored.level() == 2, "level two reached")
	check(restored.can_hire(), "hire available")
	check(restored.hire_nova(), "hire nova")
	check(not restored.hire_nova(), "duplicate hire blocked")
	var company_again = Company.new(root_ + "/company")
	check("nova" in company_again.snapshot()["hires"], "hire persisted")
	roster.set_nova_unlocked("nova" in company_again.snapshot()["hires"])
	check(roster.can_use("nova", "text"), "hired specialist can execute")
	check(not roster.can_use("nova", "xlsx"), "advanced tool still requires permission")
	check(roster.set_permission("nova", "xlsx", true), "grant spreadsheet permission")
	check(roster.delegate("xlsx") == "nova", "analyst routing")
	var nova_task: String = engine.enqueue("nova", "xlsx", '[["Report"]]')
	check(not nova_task.is_empty() and engine.run_task(nova_task), "analyst spreadsheet execution")
	check(engine.get_task(nova_task).get("status") == "succeeded", "analyst artifact")
	check(int(company_again.snapshot()["credits"]) == 25, "hire cost deducted once")
	print("CUBYTE gameplay tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
