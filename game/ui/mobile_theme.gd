extends RefCounted
## Mobile-first UI primitives. No external assets required.
const INK := Color("#edf2fa")
const MUTED := Color("#9aaac0")
const ACCENT := Color("#86b7ff")

static func surface(color: Color, radius: int = 12, outline: Color = Color("#34445b")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = outline
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.35))
	theme.set_stylebox("normal", "Button", surface(Color("#233147")))
	theme.set_stylebox("hover", "Button", surface(Color("#304767"), 12, ACCENT))
	theme.set_stylebox("pressed", "Button", surface(Color("#375b89"), 12, ACCENT))
	theme.set_stylebox("disabled", "Button", surface(Color("#182233")))
	theme.set_stylebox("focus", "Button", surface(Color(0, 0, 0, 0), 12, ACCENT))
	theme.set_stylebox("panel", "PanelContainer", surface(Color("#151e2c")))
	theme.set_stylebox("normal", "LineEdit", surface(Color("#101827")))
	theme.set_stylebox("normal", "TextEdit", surface(Color("#101827")))
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 8)
	return theme

static func button(label: String, action: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = label
	node.custom_minimum_size.y = 60
	if primary:
		node.add_theme_stylebox_override("normal", surface(Color("#315b91"), 12, ACCENT))
	node.pressed.connect(action)
	return node

static func label(value: String, size: int = 19, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

# Use embedded borderless modal windows. No OS title bar or drag handle.
static func configure_modal(window: Window) -> void:
	window.borderless = true
	window.unresizable = true
	window.transient = true
	window.exclusive = true
	window.wrap_controls = false
	window.min_size = Vector2i.ZERO

static func show_modal(window: Window, ratio: float = 0.96) -> void:
	configure_modal(window)
	window.popup_centered_ratio(ratio)

static func scroll_column(window: Window) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.theme = make_theme()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	window.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column
