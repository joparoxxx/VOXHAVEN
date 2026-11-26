extends SceneTree
const Company = preload("res://core/company.gd")
const EngineCore = preload("res://core/task_engine.gd")
const Roster = preload("res://core/robot_roster.gd")
const Progression = preload("res://core/cubot_progression.gd")
const Social = preload("res://core/robot_social.gd")
const CameraMath = preload("res://core/office_camera.gd")
const Geometry = preload("res://core/rounded_geometry.gd")
const CubotVoice = preload("res://core/cubot_voice.gd")
const HQ = preload("res://core/hq_layout.gd")
const Navigation = preload("res://core/office_navigation.gd")
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
	_test_missions(root_, engine, roster)
	_test_social()
	_test_camera()
	_test_hq()
	_test_voice()
	print("CUBYTE gameplay tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _test_missions(root_: String, engine: Object, roster: Object) -> void:
	var path := root_ + "/progression"
	var progression = Progression.new(path)
	check(progression.ready, "mission store available")
	check(progression.level("atlas") == 1, "starting Cubot level")
	check(not progression.equip("atlas", 0), "locked equipment rejected")
	var task_id: String = engine.enqueue("atlas", "text", "mission brief")
	check(not task_id.is_empty(), "mission task queued")
	check(progression.reward(engine.get_task(task_id)).is_empty(), "queued task has no XP")
	check(engine.run_task(task_id), "mission file executed")
	var result: Dictionary = progression.reward(engine.get_task(task_id))
	check(result.get("xp") == 50 and result.get("mission") == "First Brief", "first mission reward")
	check(progression.level("atlas") == 2, "mission levels Cubot")
	check(progression.level("pixel") == 1, "XP isolated per Cubot")
	check(progression.reward(engine.get_task(task_id)).is_empty(), "duplicate XP rejected")
	check(progression.equip("atlas", 0), "equip unlocked badge")
	check(is_equal_approx(progression.speed_multiplier("atlas"), 1.1), "movement buff")
	check(not progression.equip("atlas", 1), "higher tier locked")
	check(roster.set_permission("atlas", "md", true), "permit planning mission")
	for i in range(2):
		var next_id: String = engine.enqueue("atlas", "md", "# Plan " + str(i))
		check(engine.run_task(next_id), "planning file created")
		progression.reward(engine.get_task(next_id))
	check(progression.snapshot("atlas")["mission"] == 2, "planning mission completed")
	check(progression.equipment("atlas").size() == 2, "two equipment rewards")
	check(progression.equip("atlas", 1), "equip planner module")
	var restored = Progression.new(path)
	check(restored.ready, "progress reload")
	check(restored.snapshot("atlas")["xp"] == 130, "XP persisted")
	check(is_equal_approx(restored.speed_multiplier("atlas"), 1.2), "loadout persisted")
	check(restored.reward(engine.get_task(task_id)).is_empty(), "dedup persisted")
	check(restored.equip("atlas", -1), "unequip")
	check(is_equal_approx(restored.speed_multiplier("atlas"), 1.0), "base speed restored")

func _test_social() -> void:
	check(is_equal_approx(Social.heading(Vector3.ZERO, Vector3(0, 0, 1), 1.0), 0.0), "forward faces positive Z")
	check(is_equal_approx(Social.heading(Vector3.ZERO, Vector3(1, 0, 0), 0.0), PI / 2.0), "turn toward right")
	check(is_equal_approx(Social.heading(Vector3.ZERO, Vector3(-1, 0, 0), 0.0), -PI / 2.0), "turn toward left")
	check(is_equal_approx(Social.heading(Vector3.ZERO, Vector3(0, 2, 0), 0.4), 0.4), "unchanged yaw without planar direction")
	for first in Social.IDS:
		for second in Social.IDS:
			var lines := Social.dialogue(first, second)
			if first == second:
				check(lines.is_empty(), "no self conversation")
			else:
				check(lines.size() == 3, "three-turn conversation")
				for line in lines:
					check(not line.is_empty() and Social.duration(line) >= 2.4, "readable dialogue")
	check(Social.speaker(0) == 0 and Social.speaker(1) == 1 and Social.speaker(2) == 0, "alternate speakers")

func _test_camera() -> void:
	var original := Vector3(8, 8, 12)
	var initial := CameraMath.angles(original)
	check(CameraMath.offset(initial.x, initial.y, original.length()).is_equal_approx(original), "camera reset reconstructs original angle")
	var right := CameraMath.orbit_angles(initial, Vector2(100, 0))
	check(not is_equal_approx(initial.x, right.x), "horizontal drag rotates camera")
	var upper := CameraMath.orbit_angles(initial, Vector2(0, 10000))
	check(is_equal_approx(upper.y, CameraMath.MAX_PITCH), "upper elevation bounded")
	var lower := CameraMath.orbit_angles(initial, Vector2(0, -10000))
	check(is_equal_approx(lower.y, CameraMath.MIN_PITCH), "lower elevation bounded")
	var full_turn := CameraMath.orbit_angles(initial, Vector2(TAU / CameraMath.DRAG_SENSITIVITY, 0))
	check(is_equal_approx(full_turn.x, initial.x), "full orbit returns to start")
	check(is_equal_approx(CameraMath.pinch_size(12, 100, 200), 6.0), "pinch zoom in")
	check(is_equal_approx(CameraMath.pinch_size(12, 200, 100), 18.0), "pinch zoom out bounded")
	check(is_equal_approx(CameraMath.pinch_size(12, 0, 100), 12.0), "degenerate pinch ignored")

func _test_hq() -> void:
	var size_ := Vector3(0.82,0.82,0.82)
	var mesh := Geometry.rounded_box(size_,0.15)
	check(mesh.get_surface_count() == 1, "rounded body mesh generated")
	check(mesh.get_aabb().size.is_equal_approx(size_), "rounded geometry retains collision bounds")
	var arrays := mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_VERTEX].size() == arrays[Mesh.ARRAY_NORMAL].size(), "rounded normals present")
	for count in [3,4]:
		var positions: Array = HQ.SPAWNS.slice(0,count)
		for i in range(count):
			var nav := Navigation.new()
			for j in range(count):
				nav.block_box(HQ.DESKS[j], Vector2(1.35,0.85))
			HQ.block_fixed(nav)
			for j in range(count):
				if i != j:
					nav.block_box(positions[j],Vector2(0.65,0.65))
			check(not nav.route(positions[i],HQ.SEATS[i]).is_empty(), "meeting seat reachable " + str(i))
			positions[i] = HQ.SEATS[i]
		var nav := Navigation.new()
		for i in range(count):
			nav.block_box(HQ.DESKS[i],Vector2(1.35,0.85))
		HQ.block_fixed(nav)
		for i in range(count):
			check(not nav.route(HQ.SEATS[i], HQ.work_target(i,HQ.DESKS[i])).is_empty(), "return to assigned workstation " + str(i))

func _test_voice() -> void:
	var synth = CubotVoice.new()
	check(CubotVoice.mood("Are you ready?") == "curious", "question chirp rises")
	check(CubotVoice.mood("Task completed!") == "happy", "success chirp")
	check(CubotVoice.mood("There is a problem. Task failed.") == "concerned", "concern chirp")
	check(CubotVoice.mood("Thinking…") == "thinking", "thinking chirp")
	var atlas: AudioStreamWAV = synth.clip("atlas", "neutral", 36)
	var pixel: AudioStreamWAV = synth.clip("pixel", "neutral", 36)
	check(atlas.mix_rate == 22050 and not atlas.stereo, "lightweight mono voice")
	check(atlas.data.size() > 0 and atlas.data != pixel.data, "distinct robot voices")
	check(atlas == synth.clip("atlas", "neutral", 36), "bounded cached clip reused")
	check(synth.clip("mesh", "concerned", 10000).get_length() < 1.2, "long replies have bounded chirps")
