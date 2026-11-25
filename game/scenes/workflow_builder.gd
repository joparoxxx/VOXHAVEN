extends Window
const UI = preload("res://ui/mobile_theme.gd")
const Tools = preload("res://core/tool_registry.gd")
const Writer = preload("res://core/artifact_writer.gd")
const Snapshot = preload("res://core/snapshot_store.gd")
const ROBOTS := ["atlas", "pixel", "mesh", "nova"]
var engine
var roster
var rows: Array = []
var container: VBoxContainer
var status: Label
var template_name: LineEdit
var templates_picker: OptionButton
var templates := {}
var store = Snapshot.new("user://cubyte/workflows", "templates.json")
signal approved(ids: Array)

func _ready() -> void:
	UI.configure_modal(self)
	var column := UI.scroll_column(self)
	column.add_child(UI.label("Workflow builder", 24))
	column.add_child(UI.button("Close", hide))
	column.add_child(UI.label("Assign up to eight native file tasks. Steps run in order; a failure stops the automatic sequence. No AI calls or arbitrary code execution.", 16, UI.MUTED))
	container = VBoxContainer.new()
	column.add_child(container)
	column.add_child(UI.button("Add step", _add_empty))
	column.add_child(UI.button("Remove last step", _remove_last))
	template_name = LineEdit.new()
	template_name.placeholder_text = "Template name (local)"
	template_name.max_length = 40
	column.add_child(template_name)
	column.add_child(UI.button("Save template", _save_template))
	templates_picker = OptionButton.new()
	column.add_child(templates_picker)
	column.add_child(UI.button("Load selected template", _load_template))
	column.add_child(UI.button("Delete selected template", _delete_template))
	column.add_child(UI.button("Approve & run workflow", _run, true))
	status = UI.label("", 16, UI.MUTED)
	column.add_child(status)
	close_requested.connect(hide)
	_restore_templates()
	_add_empty()

func show_builder(source: Object, profiles: Object) -> void:
	engine = source
	roster = profiles
	for row in rows:
		row["robot"].set_item_disabled(3, not roster.is_active("nova"))
	UI.show_modal(self)

func _add_empty() -> void:
	_add_step({"robot_id":"atlas","tool":"text","payload":""})

func _add_step(data: Dictionary) -> void:
	if rows.size() >= 8:
		return
	var panel := PanelContainer.new()
	container.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(UI.label("Step " + str(rows.size() + 1), 19))
	var robot := OptionButton.new()
	for id in ROBOTS:
		robot.add_item(id.to_upper())
	robot.set_item_disabled(3, not is_instance_valid(roster) or not roster.is_active("nova"))
	robot.select(maxi(0, ROBOTS.find(data.get("robot_id", "atlas"))))
	column.add_child(robot)
	var tool := OptionButton.new()
	for id in Tools.IDS:
		tool.add_item(Tools.describe(id)["label"])
	tool.select(maxi(0, Tools.IDS.find(data.get("tool", "text"))))
	column.add_child(tool)
	var payload := TextEdit.new()
	payload.custom_minimum_size.y = 100
	payload.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	payload.placeholder_text = "Payload for this tool"
	payload.text = str(data.get("payload", ""))
	column.add_child(payload)
	rows.append({"panel":panel,"robot":robot,"tool":tool,"payload":payload})

func _remove_last() -> void:
	if rows.size() <= 1:
		return
	var row: Dictionary = rows.pop_back()
	container.remove_child(row["panel"])
	row["panel"].queue_free()

func _plan() -> Array:
	var result := []
	for row in rows:
		var robot: String = ROBOTS[row["robot"].selected]
		var tool: String = Tools.IDS[row["tool"].selected]
		var payload: String = row["payload"].text
		if not Writer.valid(tool, payload):
			return []
		result.append({"robot_id":robot,"tool":tool,"payload":payload})
	return result

func _run() -> void:
	if not is_instance_valid(engine) or not is_instance_valid(roster):
		return
	var plan := _plan()
	if plan.is_empty():
		status.text = "Invalid step payload."
		return
	for step in plan:
		if not roster.can_use(step["robot_id"], step["tool"]):
			status.text = str(step["robot_id"]).to_upper() + " lacks permission for " + str(step["tool"])
			return
	var ids: Array[String] = engine.enqueue_team_workflow(plan)
	if ids.is_empty():
		status.text = "Workflow rejected."
		return
	hide()
	approved.emit(ids)

func _restore_templates() -> void:
	var saved: Dictionary = store.read("templates", "", 4194304)
	if saved.get("ok", false) and saved.get("found", false):
		var raw: Variant = JSON.parse_string(str(saved.get("value","")))
		if raw is Dictionary and raw.get("version") == 1 and raw.get("items") is Dictionary and raw["items"].size() <= 12:
			for name_ in raw["items"]:
				var plan: Variant = raw["items"][name_]
				if not name_ is String or name_.length() > 40 or not plan is Array or plan.is_empty() or plan.size() > 8:
					continue
				var valid := true
				for step in plan:
					if not step is Dictionary or step.get("robot_id") not in ROBOTS or step.get("tool") not in Tools.IDS or not step.get("payload") is String or not Writer.valid(step["tool"], step["payload"]):
						valid = false
						break
				if valid:
					templates[name_] = plan
	_refresh_templates()

func _refresh_templates() -> void:
	templates_picker.clear()
	var names := templates.keys()
	names.sort()
	for name_ in names:
		templates_picker.add_item(name_)

func _persist(next: Dictionary) -> bool:
	var encoded := JSON.stringify({"version":1,"items":next})
	if encoded.to_utf8_buffer().size() > 4194304 or not store.write("templates", encoded):
		return false
	templates = next
	_refresh_templates()
	return true

func _save_template() -> void:
	var name_ := template_name.text.strip_edges()
	var plan := _plan()
	if name_.is_empty() or plan.is_empty() or (templates.size() >= 12 and not templates.has(name_)):
		status.text = "Enter a name and valid steps (maximum 12 templates)."
		return
	var next := templates.duplicate(true)
	next[name_] = plan
	status.text = "Template saved locally." if _persist(next) else "Could not save template."

func _load_template() -> void:
	if templates_picker.selected < 0:
		return
	var name_ := templates_picker.get_item_text(templates_picker.selected)
	for row in rows:
		container.remove_child(row["panel"])
		row["panel"].queue_free()
	rows.clear()
	for step in templates[name_]:
		_add_step(step)
	template_name.text = name_
	status.text = "Template loaded."

func _delete_template() -> void:
	if templates_picker.selected < 0:
		return
	var next := templates.duplicate(true)
	next.erase(templates_picker.get_item_text(templates_picker.selected))
	status.text = "Template removed." if _persist(next) else "Could not remove template."
