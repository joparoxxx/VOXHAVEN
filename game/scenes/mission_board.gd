extends Window
## The player explicitly submits each mission task. No automatic network calls.
const UI = preload("res://ui/mobile_theme.gd")
const Tools = preload("res://core/tool_registry.gd")
const Writer = preload("res://core/artifact_writer.gd")
var progress
var roster
var robot_id := ""
var heading: Label
var xp_bar: ProgressBar
var mission_label: Label
var mission_bar: ProgressBar
var payload_editor: TextEdit
var run_button: Button
var equipment_picker: OptionButton
var equipment_label: Label
var status: Label
signal mission_requested(robot_id: String, tool: String, payload: String)
signal equipment_changed(robot_id: String)

func _ready() -> void:
	UI.configure_modal(self)
	var column := UI.scroll_column(self)
	column.add_child(UI.button("Close", hide))
	heading = UI.label("Cubot missions", 24)
	column.add_child(heading)
	xp_bar = ProgressBar.new()
	xp_bar.max_value = 50
	xp_bar.custom_minimum_size.y = 26
	xp_bar.show_percentage = false
	column.add_child(xp_bar)
	column.add_child(UI.label("Current mission", 20))
	mission_label = UI.label("", 18)
	column.add_child(mission_label)
	mission_bar = ProgressBar.new()
	mission_bar.custom_minimum_size.y = 26
	column.add_child(mission_bar)
	payload_editor = TextEdit.new()
	payload_editor.custom_minimum_size.y = 120
	payload_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	column.add_child(payload_editor)
	run_button = UI.button("Start mission task", _run, true)
	column.add_child(run_button)
	column.add_child(UI.label("Equipment inventory", 20))
	equipment_picker = OptionButton.new()
	equipment_picker.custom_minimum_size.y = 52
	column.add_child(equipment_picker)
	column.add_child(UI.button("Equip selected", _equip))
	equipment_label = UI.label("", 17, UI.MUTED)
	column.add_child(equipment_label)
	status = UI.label("", 17, UI.MUTED)
	column.add_child(status)
	column.add_child(UI.label("Successful file tasks earn XP. Mission rewards are counted once per task. Equipment improves movement speed only; tool permissions and Gemini quota do not change.", 16, UI.MUTED))
	close_requested.connect(hide)

func show_for(id: String, source: Object, profiles: Object) -> void:
	robot_id = id
	progress = source
	roster = profiles
	status.text = ""
	_refresh(true)
	UI.show_modal(self)

func _refresh(reset_payload: bool) -> void:
	var data: Dictionary = progress.snapshot(robot_id)
	var level: int = progress.level(robot_id)
	var xp := int(data.get("xp", 0))
	heading.text = robot_id.to_upper() + " · Level " + str(level) + "\n" + str(xp) + " total XP · " + str(int(data.get("jobs", 0))) + " jobs"
	xp_bar.value = 50 if level == 100 else xp % 50
	var mission: Dictionary = progress.current_mission(robot_id)
	mission_bar.visible = not mission.is_empty()
	payload_editor.visible = not mission.is_empty() and mission.get("tool") != "png"
	run_button.visible = not mission.is_empty()
	run_button.disabled = mission.is_empty() or not progress.ready or not roster.is_active(robot_id)
	if mission.is_empty():
		mission_label.text = "All three career missions completed. Keep working to earn XP."
	else:
		var tool: String = mission["tool"]
		var allowed: bool = roster.can_use(robot_id, tool)
		mission_bar.max_value = int(mission["target"])
		mission_bar.value = int(data["progress"])
		mission_label.text = str(mission["title"]) + "\nCreate " + str(mission["target"]) + " " + str(Tools.describe(tool)["label"]) + " files · " + str(int(data["progress"])) + "/" + str(mission["target"]) + "\nReward: +" + str(mission["bonus"]) + " XP and " + str(mission["equipment"])
		if not allowed:
			mission_label.text += "\nEnable this tool in the Cubot profile first."
			run_button.disabled = true
		if reset_payload:
			payload_editor.text = str(mission["sample"])
	equipment_picker.clear()
	equipment_picker.add_item("No equipment", 0)
	var current := 0
	for item in progress.equipment(robot_id):
		var index := int(item["index"])
		equipment_picker.add_item(str(item["name"]) + " (+" + str(item["speed_percent"]) + "% speed)", index + 1)
		if item["equipped"]:
			current = equipment_picker.item_count - 1
	equipment_picker.select(current)
	equipment_label.text = "Current movement bonus: +" + str(roundi((progress.speed_multiplier(robot_id) - 1.0) * 100)) + "%"
	if not progress.ready:
		status.text = "Progress storage unavailable."

func _run() -> void:
	var mission: Dictionary = progress.current_mission(robot_id)
	if mission.is_empty() or not progress.ready or not roster.is_active(robot_id):
		return
	var tool: String = mission["tool"]
	if not roster.can_use(robot_id, tool):
		status.text = "Tool permission required in Profile."
		return
	var payload := "" if tool == "png" else payload_editor.text
	if not Writer.valid(tool, payload):
		status.text = "Invalid payload for this mission."
		return
	hide()
	mission_requested.emit(robot_id, tool, payload)

func _equip() -> void:
	if not roster.is_active(robot_id) or equipment_picker.selected < 0:
		return
	var index := equipment_picker.get_selected_id() - 1
	if progress.equip(robot_id, index):
		_refresh(false)
		status.text = "Equipment updated."
		equipment_changed.emit(robot_id)
	else:
		status.text = "Equipment unavailable or storage error."
