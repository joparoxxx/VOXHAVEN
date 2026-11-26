extends ScrollContainer
## Mobile chat timeline with real selectable plain-text message bubbles.
const UI = preload("res://ui/mobile_theme.gd")
const COLORS := {"atlas":Color("#eac678"),"pixel":Color("#bc9ff1"),"mesh":Color("#8bc4ed"),"nova":Color("#70d7b1"),"office":Color("#a5b7bf"),"you":Color("#b7e7d7")}
var messages: VBoxContainer

static func chat_theme() -> Theme:
	var theme := UI.make_theme()
	theme.default_font_size = 18
	theme.set_stylebox("panel","PanelContainer",UI.surface(Color("#15252c"),12,Color("#2d454c")))
	theme.set_stylebox("normal","Button",UI.surface(Color("#243b42"),10,Color("#3b555b")))
	theme.set_stylebox("hover","Button",UI.surface(Color("#34565c"),10,Color("#70d7b1")))
	theme.set_stylebox("pressed","Button",UI.surface(Color("#416c67"),10,Color("#70d7b1")))
	theme.set_stylebox("normal","TextEdit",UI.surface(Color("#192b32"),12,Color("#39575d")))
	theme.set_stylebox("normal","LineEdit",UI.surface(Color("#192b32"),10,Color("#39575d")))
	return theme

static func compact_button(title_: String, action: Callable, primary: bool = false) -> Button:
	var button := UI.button(title_,action)
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size",17)
	if primary:
		button.add_theme_stylebox_override("normal",UI.surface(Color("#285b50"),10,Color("#70d7b1")))
	return button

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 100
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["top","bottom","left","right"]:
		margin.add_theme_constant_override("margin_" + side,8)
	add_child(margin)
	messages = VBoxContainer.new()
	messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages.add_theme_constant_override("separation",10)
	margin.add_child(messages)

func clear() -> void:
	if not is_instance_valid(messages):
		return
	for child in messages.get_children():
		messages.remove_child(child)
		child.queue_free()

func add_message(sender: String, content: String, label_: String = "") -> void:
	if not is_instance_valid(messages):
		return
	var own := sender == "you"
	var system := sender == "office"
	var accent: Color = COLORS.get(sender,UI.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	messages.add_child(row)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 38 if not system else 8
	if own:
		row.add_child(spacer)
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := Color("#274b43") if own else (Color("#20343b") if not system else Color("#263238"))
	bubble.add_theme_stylebox_override("panel",UI.surface(fill,12,accent.darkened(0.65)))
	row.add_child(bubble)
	if not own:
		row.add_child(spacer)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",4)
	bubble.add_child(stack)
	var title_ := label_ if not label_.is_empty() else ("You" if own else ("Office" if system else sender.to_upper()))
	stack.add_child(UI.label(title_,15,accent))
	var body := RichTextLabel.new()
	body.bbcode_enabled = false
	body.fit_content = true
	body.scroll_active = false
	body.selection_enabled = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("normal_font_size",19)
	body.add_theme_color_override("default_color",UI.INK)
	body.add_text(content)
	stack.add_child(body)

func to_bottom() -> void:
	call_deferred("_scroll_end")

func _scroll_end() -> void:
	if is_inside_tree():
		scroll_vertical = int(get_v_scroll_bar().max_value)
