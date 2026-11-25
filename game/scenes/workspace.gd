extends Window
const UI = preload("res://ui/mobile_theme.gd")
var engine
var list: ItemList
var detail: RichTextLabel
var image: TextureRect
var status: Label
var ids: Array[String] = []
var selected_id := ""
signal run_requested(id: String)

func _ready() -> void:
	UI.configure_modal(self)
	var column := UI.scroll_column(self)
	column.add_child(UI.label("Workspace · Tasks & files", 23))
	column.add_child(UI.button("Close", hide))
	status = UI.label("", 16, UI.MUTED)
	column.add_child(status)
	list = ItemList.new()
	list.custom_minimum_size.y = 260
	list.item_selected.connect(_selected)
	column.add_child(list)
	detail = RichTextLabel.new()
	detail.selection_enabled = true
	detail.custom_minimum_size.y = 200
	column.add_child(detail)
	image = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size.y = 180
	column.add_child(image)
	column.add_child(UI.button("Run queued / retry failed", _run))
	column.add_child(UI.button("Cancel queued task", _cancel))
	column.add_child(UI.button("Copy text preview", _copy))
	column.add_child(UI.button("Refresh", refresh))
	close_requested.connect(hide)

func show_workspace(source: Object) -> void:
	engine = source
	refresh()
	UI.show_modal(self)

func refresh() -> void:
	if not is_instance_valid(engine):
		return
	var previous := selected_id
	list.clear()
	ids.clear()
	selected_id = ""
	detail.clear()
	image.texture = null
	status.text = "Latest 100 tasks · Free storage %.0f MB · Static RAM %.0f MB" % [float(DirAccess.open("user://").get_space_left()) / 1048576.0, float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0]
	for task in engine.list_tasks():
		var id := str(task["id"])
		ids.append(id)
		list.add_item("#" + id + " " + str(task["robot_id"]).to_upper() + " · " + str(task["tool"]) + " · " + str(task["status"]))
		if id == previous:
			list.select(ids.size() - 1)
			_selected(ids.size() - 1)

func _selected(index: int) -> void:
	if index < 0 or index >= ids.size():
		return
	selected_id = ids[index]
	var task: Dictionary = engine.get_task(selected_id)
	detail.clear()
	image.texture = null
	detail.add_text("Task #" + selected_id + "\n" + str(task.get("status")) + "\n" + str(task.get("error", "")) + "\n")
	var path: String = engine.artifact_path(selected_id)
	if path.is_empty():
		return
	detail.add_text(path + "\n")
	if task["tool"] in ["png", "svg"]:
		var preview := Image.new()
		if preview.load(path) == OK:
			image.texture = ImageTexture.create_from_image(preview)
	elif task["tool"] in ["text", "md", "json", "csv", "code", "obj"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			detail.add_text(file.get_buffer(mini(file.get_length(), 16384)).get_string_from_utf8())
	else:
		detail.add_text("Binary document generated. In-app document rendering is not supported yet.")

func _copy() -> void:
	if selected_id.is_empty():
		return
	var task: Dictionary = engine.get_task(selected_id)
	var path: String = engine.artifact_path(selected_id)
	if not path.is_empty() and task.get("tool") in ["text", "md", "json", "csv", "code", "obj"]:
		DisplayServer.clipboard_set(FileAccess.get_file_as_string(path))
		status.text = "Text copied."

func _cancel() -> void:
	if not selected_id.is_empty() and engine.cancel(selected_id):
		refresh()

func _run() -> void:
	if selected_id.is_empty():
		return
	var task: Dictionary = engine.get_task(selected_id)
	var id := selected_id
	if task.get("status") in ["failed", "interrupted"]:
		id = engine.retry_task(id)
	if id.is_empty() or engine.get_task(id).get("status") != "queued":
		status.text = "Task cannot be run or retried."
		return
	hide()
	run_requested.emit(id)
