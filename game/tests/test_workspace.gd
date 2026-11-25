extends SceneTree
const Writer = preload("res://core/artifact_writer.gd")
const Core = preload("res://core/task_engine.gd")
const Roster = preload("res://core/robot_roster.gd")
const Skills = preload("res://core/skill_registry.gd")
const Nav = preload("res://core/office_navigation.gd")
const History = preload("res://core/chat_history.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_ := "user://workspace_test_" + str(Time.get_ticks_usec())
	var engine = Core.new(root_)
	var payloads := {"text": "hello", "md": "# Notes", "json": '{"ok":true}', "csv": '[["name","value"],["item","=1+2"]]', "xlsx": '[["name","value"],["item","example"]]', "docx": "Hello\nWorld", "pdf": "Hello (CUBYTE)", "svg": '{"color":"#42aaff"}', "code": "print(123)", "obj": "cube", "png": ""}
	for tool in payloads:
		var id: String = engine.enqueue("atlas", tool, payloads[tool])
		check(not id.is_empty(), "queued " + tool)
		if id.is_empty():
			continue
		check(engine.run_task(id), "run " + tool)
		check(engine.get_task(id).get("status") == "succeeded", "generated " + tool)
		var path: String = engine.artifact_path(id)
		check(not path.is_empty(), "artifact exists " + tool)
		if path.is_empty():
			continue
		if tool == "csv":
			check(FileAccess.get_file_as_string(path).contains("'=1+2"), "CSV formula neutralized")
		if tool == "pdf":
			check(FileAccess.get_file_as_string(path).begins_with("%PDF-1.4"), "PDF signature")
		if tool in ["docx", "xlsx"]:
			var zip := ZIPReader.new()
			check(zip.open(path) == OK, "open OOXML archive")
			check(zip.file_exists("[Content_Types].xml"), "OOXML content types")
			zip.close()
		if tool == "md":
			check(engine.rename_artifact(id, "notes"), "safe rename")
			check(not engine.rename_artifact(id, "../escape"), "unsafe rename blocked")
			check(not engine.export_artifact(id).is_empty(), "export copy")
			check(engine.delete_artifact(id), "delete artifact")
			check(engine.artifact_path(id).is_empty(), "deleted not visible")
	check(not Writer.valid("svg", '{"color":"<script>"}'), "constrained SVG")
	check(not Writer.valid("obj", "../mesh"), "constrained OBJ")
	check(not Writer.valid("xlsx", '["not a row"]'), "invalid spreadsheet rejected")
	var before: int = engine.list_tasks().size()
	check(engine.enqueue_workflow("atlas", [{"tool":"text","payload":"first"},{"tool":"json","payload":"invalid"}]).is_empty(), "atomic workflow rejection")
	check(engine.list_tasks().size() == before, "no partial workflow")
	var ids: Array[String] = engine.enqueue_workflow("atlas", [{"tool":"text","payload":"one"},{"tool":"md","payload":"two"}])
	check(ids.size() == 2, "valid workflow queued")
	for id in ids:
		check(engine.run_task(id), "workflow step executes")
	var reopened = Core.new(root_)
	check(reopened.is_ready(), "expanded task schema restores")
	var legacy := root_ + "/robots"
	DirAccess.make_dir_recursive_absolute(legacy)
	var profiles := {}
	for id in ["atlas", "pixel", "mesh"]:
		profiles[id] = {"memory":"legacy", "personality":"Calm", "permissions":{"text":true,"png":true}}
	var file := FileAccess.open(legacy + "/profiles.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"profiles":profiles}))
	file.close()
	var roster = Roster.new(legacy)
	check(roster.is_ready() and roster.get_profile("atlas").get("memory") == "legacy", "old profiles migrate")
	check(not roster.can_use("atlas", "pdf"), "new tools default denied")
	check(roster.set_permission("atlas", "pdf", true), "grant new tool")
	check(Roster.new(legacy).can_use("atlas", "pdf"), "new permission persists")
	var skills = Skills.new(root_ + "/skills")
	var doc := "---\nname: workflow-test\ndescription: Native files\nallowed-tools: text md\nsteps: text md\n---\n# Workflow"
	check(skills.import_markdown(doc) == "workflow-test", "workflow metadata imported")
	check(skills.workflow_plan("workflow-test", ["one","two"]).size() == 2, "workflow steps validated")
	check(not skills.dependency_report("workflow-test", "png").get("ok", false), "undeclared tool rejected")
	check(not skills.export_file("workflow-test").is_empty(), "skill export")
	var chats = History.new(root_ + "/chats")
	check(chats.save("atlas", [{"user":"hello","assistant":"hi"}]), "save chat")
	check(History.new(root_ + "/chats").load_all().has("atlas"), "restore chat")
	check(chats.clear("atlas"), "clear chat")
	check(not History.new(root_ + "/chats").load_all().has("atlas"), "clear persists")
	var nav = Nav.new()
	nav.block_box(Vector3(0,0,0), Vector2(0.5,0.5))
	var route: Array[Vector3] = nav.route(Vector3(-2,0,0), Vector3(2,0,0))
	check(not route.is_empty(), "path found around furniture")
	for point in route:
		check(not nav.grid.is_point_solid(nav.cell(point)), "path avoids blocked cell")
	print("CUBYTE workspace tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
