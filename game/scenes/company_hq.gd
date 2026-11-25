extends Window
const UI = preload("res://ui/mobile_theme.gd")
const Company = preload("res://core/company.gd")
var company
var summary: Label
var name_editor: LineEdit
var status: Label
var purchase_buttons := {}
signal changed

func _ready() -> void:
	UI.configure_modal(self)
	var column := UI.scroll_column(self)
	column.add_child(UI.label("Company HQ", 24))
	column.add_child(UI.button("Close", hide))
	summary = UI.label("", 19)
	column.add_child(summary)
	column.add_child(UI.label("Credits are in-game rewards, not money or Gemini API quota.", 16, UI.MUTED))
	name_editor = LineEdit.new()
	name_editor.max_length = 40
	name_editor.placeholder_text = "Company name"
	column.add_child(name_editor)
	column.add_child(UI.button("Save name", _rename))
	column.add_child(UI.label("Office upgrades", 20))
	for id in Company.UPGRADES:
		var item: Dictionary = Company.UPGRADES[id]
		var button := UI.button(str(item["name"]) + " · " + str(item["cost"]) + " credits", _buy.bind(id))
		purchase_buttons[id] = button
		column.add_child(button)
	status = UI.label("", 16, UI.MUTED)
	column.add_child(status)
	close_requested.connect(hide)

func show_company(source: Object) -> void:
	company = source
	refresh()
	UI.show_modal(self)

func refresh() -> void:
	if not is_instance_valid(company):
		return
	var data: Dictionary = company.snapshot()
	summary.text = str(data["company"]) + "\nCredits: " + str(int(data["credits"])) + "\nCompleted jobs: " + str(int(data["completed"]))
	name_editor.text = str(data["company"])
	for id in purchase_buttons:
		var item: Dictionary = Company.UPGRADES[id]
		var owned: bool = id in data["upgrades"]
		purchase_buttons[id].disabled = owned or int(data["credits"]) < int(item["cost"]) or not company.ready
		purchase_buttons[id].text = str(item["name"]) + (" · Owned" if owned else " · " + str(item["cost"]) + " credits")
	if not company.ready:
		status.text = "Company storage unavailable."

func _rename() -> void:
	if company.rename_company(name_editor.text):
		refresh()
		status.text = "Company name saved."
		changed.emit()
	else:
		status.text = "Could not save company name."

func _buy(id: String) -> void:
	if company.purchase(id):
		refresh()
		status.text = "Upgrade installed in your office."
		changed.emit()
	else:
		status.text = "Purchase rejected."
