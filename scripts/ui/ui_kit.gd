class_name UIKit
extends RefCounted
## Общий стиль интерфейса: тёмные полупрозрачные панели, янтарный акцент, шрифты PT Sans / Oswald.
## Всё строится кодом и масштабируется вместе с canvas (stretch: canvas_items, aspect: expand).

const ACCENT := Color(0.85, 0.64, 0.26)
const TEXT := Color(0.91, 0.89, 0.84)
const DIM := Color(0.6, 0.58, 0.54)
const BAD := Color(0.82, 0.33, 0.26)
const GOOD := Color(0.5, 0.72, 0.42)
const PANEL := Color(0.055, 0.058, 0.062, 0.94)
const PANEL_LIGHT := Color(0.11, 0.11, 0.115, 0.95)

static var _theme: Theme
static var font_regular: Font
static var font_bold: Font
static var font_title: Font


static func theme() -> Theme:
	if _theme:
		return _theme
	font_regular = load("res://assets/fonts/PT_Sans-Web-Regular.ttf")
	font_bold = load("res://assets/fonts/PT_Sans-Web-Bold.ttf")
	var osw: FontFile = load("res://assets/fonts/Oswald.ttf")
	var fv := FontVariation.new()
	fv.base_font = osw
	fv.variation_opentype = {"wght": 500}
	font_title = fv
	var t := Theme.new()
	t.default_font = font_regular
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 1, Color(0.28, 0.26, 0.22), 8))
	t.set_stylebox("panel", "Panel", box(PANEL, 1, Color(0.28, 0.26, 0.22), 8))
	# кнопки
	t.set_stylebox("normal", "Button", box(Color(0.14, 0.14, 0.145, 0.96), 1, Color(0.3, 0.28, 0.24), 6, 14, 8))
	t.set_stylebox("hover", "Button", box(Color(0.2, 0.19, 0.17, 0.98), 1, ACCENT.darkened(0.2), 6, 14, 8))
	t.set_stylebox("pressed", "Button", box(Color(0.3, 0.24, 0.14, 1.0), 1, ACCENT, 6, 14, 8))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 1, ACCENT.darkened(0.3), 6, 14, 8))
	t.set_stylebox("disabled", "Button", box(Color(0.09, 0.09, 0.09, 0.9), 1, Color(0.18, 0.18, 0.18), 6, 14, 8))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.85))
	t.set_color("font_pressed_color", "Button", ACCENT.lightened(0.3))
	t.set_color("font_disabled_color", "Button", Color(0.42, 0.41, 0.39))
	t.set_font_size("font_size", "Button", 22)
	# прочее
	t.set_stylebox("normal", "LineEdit", box(Color(0.1, 0.1, 0.1), 1, Color(0.3, 0.3, 0.3), 4, 8, 6))
	t.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0), 0, Color.BLACK, 0))
	t.set_stylebox("tab_selected", "TabContainer", box(Color(0.22, 0.18, 0.11, 1.0), 1, ACCENT, 6, 16, 8))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.12, 0.12, 0.12, 0.95), 1, Color(0.25, 0.25, 0.25), 6, 16, 8))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.17, 0.16, 0.14, 0.95), 1, Color(0.4, 0.35, 0.25), 6, 16, 8))
	t.set_color("font_selected_color", "TabContainer", ACCENT.lightened(0.25))
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_font_size("font_size", "TabContainer", 21)
	t.set_stylebox("slider", "HSlider", box(Color(0.2, 0.2, 0.2), 0, Color.BLACK, 3, 0, 3))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT.darkened(0.35), 0, Color.BLACK, 3, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT.darkened(0.2), 0, Color.BLACK, 3, 0, 3))
	t.set_stylebox("background", "ProgressBar", box(Color(0.12, 0.12, 0.12, 0.8), 0, Color.BLACK, 3))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 0, Color.BLACK, 3))
	t.set_stylebox("normal", "OptionButton", box(Color(0.14, 0.14, 0.145, 0.96), 1, Color(0.3, 0.28, 0.24), 6, 14, 8))
	t.set_stylebox("hover", "OptionButton", box(Color(0.2, 0.19, 0.17, 0.98), 1, ACCENT.darkened(0.2), 6, 14, 8))
	t.set_stylebox("pressed", "OptionButton", box(Color(0.3, 0.24, 0.14, 1.0), 1, ACCENT, 6, 14, 8))
	t.set_stylebox("panel", "PopupMenu", box(PANEL_LIGHT, 1, Color(0.3, 0.28, 0.24), 6, 8, 8))
	t.set_font_size("font_size", "PopupMenu", 22)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 21)
	t.set_font("bold_font", "RichTextLabel", font_bold)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	var scroll_grab := box(Color(0.35, 0.32, 0.26, 0.9), 0, Color.BLACK, 4)
	t.set_stylebox("grabber", "VScrollBar", scroll_grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(ACCENT.darkened(0.2), 0, Color.BLACK, 4))
	t.set_stylebox("scroll", "VScrollBar", box(Color(0.1, 0.1, 0.1, 0.5), 0, Color.BLACK, 4))
	_theme = t
	return t


static func box(bg: Color, border: int = 0, border_col: Color = Color.BLACK, radius: int = 6, pad_x: int = 10, pad_y: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(border)
	s.border_color = border_col
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


static func label(text: String, size: int = 22, color: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func title(text: String, size: int = 34) -> Label:
	var l := label(text, size, ACCENT)
	theme()
	l.add_theme_font_override("font", font_title)
	return l


static func button(text: String, cb: Callable, min_w: float = 0.0, font_size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 52)
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		AudioLib.ui("click")
		cb.call())
	return b


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func panel() -> PanelContainer:
	return PanelContainer.new()


static func spacer(expand: bool = true) -> Control:
	var c := Control.new()
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func rich(bbcode: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


## Полноэкранная «шторка» со скругленной панелью по центру.
static func modal(min_size: Vector2) -> Array:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var p := panel()
	p.custom_minimum_size = min_size
	center.add_child(p)
	var v := vbox(10)
	p.add_child(v)
	return [bg, v, p]


## Иконка предмета: цвет категории + сокращённое название (+ число).
static func item_icon(id: String, n: int = 1, size: float = 72.0) -> Control:
	var c := Panel.new()
	c.custom_minimum_size = Vector2(size, size)
	var col: Color = ItemDB.CATEGORY_COLORS.get(ItemDB.category(id), Color(0.4, 0.4, 0.4))
	c.add_theme_stylebox_override("panel", box(col.darkened(0.55), 1, col.darkened(0.1), 6))
	var icon_path := "res://assets/icons/%s.png" % id
	if ResourceLoader.exists(icon_path):
		var tr := TextureRect.new()
		tr.texture = load(icon_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 4
		tr.offset_top = 4
		tr.offset_right = -4
		tr.offset_bottom = -4
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(tr)
	else:
		var l := label(_short(ItemDB.item_name(id)), int(size * 0.2), TEXT.darkened(0.05), true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(l)
	if n > 1:
		var cnt := label("×%d" % n, int(size * 0.22), ACCENT.lightened(0.3))
		cnt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		cnt.position = Vector2(size - 34, size - 26)
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(cnt)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func _short(name: String) -> String:
	var words := name.split(" ")
	if name.length() <= 12:
		return name
	var out := ""
	for w in words:
		if out.length() + w.length() > 18:
			break
		out += w + " "
	return out.strip_edges()
