extends Control
## Настройки: управление (Android/PC, чувствительность, раскладка клавиш), графика (пресеты, разрешение
## рендера, тени, дальность, растительность), экран (PC), звук, игра. Применяются сразу и сохраняются.

signal closed

var _tabs: TabContainer
var _rebind_action := ""
var _rebind_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := UIKit.panel()
	margin.add_child(root)
	var v := UIKit.vbox(8)
	root.add_child(v)
	var head := UIKit.hbox()
	head.add_child(UIKit.title("Настройки", 30))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.button("Готово", func(): _close(), 160))
	v.add_child(head)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_tabs)
	_build()


func _close() -> void:
	Settings.save_settings()
	closed.emit()
	queue_free()


func _build() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	var cur := _tabs.current_tab
	# --- Управление
	var c := _page("Управление")
	_option(c, "Режим управления", ["Android (сенсорный)", "PC (клавиатура и мышь)"], 0 if Settings.control_mode == "touch" else 1, func(i):
		Settings.control_mode = "touch" if i == 0 else "pc"
		Settings.apply()
		InputRouter.set_gameplay_active(InputRouter.gameplay_active))
	_slider(c, "Чувствительность (сенсор)", 0.05, 0.6, 0.01, Settings.touch_sensitivity, func(x): Settings.touch_sensitivity = x)
	_slider(c, "Чувствительность (мышь)", 0.03, 0.4, 0.01, Settings.mouse_sensitivity, func(x): Settings.mouse_sensitivity = x)
	_check(c, "Инвертировать ось Y", Settings.invert_y, func(b): Settings.invert_y = b)
	_slider(c, "Размер джойстика и кнопок", 0.7, 1.4, 0.05, Settings.joystick_size, func(x): Settings.joystick_size = x; Settings.apply())
	_slider(c, "Прозрачность кнопок", 0.2, 1.0, 0.05, Settings.touch_opacity, func(x): Settings.touch_opacity = x; Settings.apply())
	_check(c, "Раскладка для левши", Settings.left_handed, func(b): Settings.left_handed = b; Settings.apply())
	c.add_child(UIKit.label("Клавиши (PC) — нажмите кнопку и затем клавишу:", 19, UIKit.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	c.add_child(grid)
	for action in InputRouter.DEFAULT_BINDINGS:
		var code := int(Settings.bindings.get(action, InputRouter.DEFAULT_BINDINGS[action]))
		grid.add_child(UIKit.label(InputRouter.ACTION_NAMES.get(action, action), 18, UIKit.DIM))
		var a: String = action
		var b := UIKit.button(InputRouter.binding_text(code), func(): pass, 140, 18)
		b.pressed.connect(func():
			_rebind_action = a
			_rebind_btn = b
			b.text = "…")
		grid.add_child(b)
	c.add_child(UIKit.button("Сбросить клавиши", func(): InputRouter.reset_bindings(); _build(), 260))
	# --- Графика
	var g := _page("Графика")
	_option(g, "Качество", Settings.PRESET_NAMES, Settings.quality, func(i):
		if i < 3:
			Settings.apply_preset(i)
			_build())
	_slider(g, "Разрешение рендера (%)", 40, 100, 5, Settings.render_scale * 100.0, func(x): Settings.render_scale = x / 100.0; _custom())
	_option(g, "Тени", ["Выкл", "Низкие", "Средние", "Высокие"], Settings.shadows, func(i): Settings.shadows = i; _custom())
	_slider(g, "Дальность прорисовки (м)", 120, 450, 10, Settings.view_distance, func(x): Settings.view_distance = x; _custom())
	_slider(g, "Плотность растительности", 0.3, 1.0, 0.05, Settings.vegetation, func(x): Settings.vegetation = x; _custom())
	_option(g, "Сглаживание (MSAA)", ["Выкл", "2x", "4x"], Settings.msaa, func(i): Settings.msaa = i; _custom())
	_check(g, "Свечение (glow)", Settings.glow, func(b): Settings.glow = b; _custom())
	_option(g, "Ограничение FPS", ["30", "45", "60", "90", "Без ограничения"], [30, 45, 60, 90, 0].find(Settings.fps_limit), func(i): Settings.fps_limit = [30, 45, 60, 90, 0][i]; Settings.apply())
	_slider(g, "Поле зрения (FOV)", 60, 95, 1, Settings.fov, func(x): Settings.fov = x; Settings.apply())
	_check(g, "Покачивание камеры при ходьбе", Settings.head_bob, func(b): Settings.head_bob = b)
	_check(g, "Показывать FPS", Settings.show_fps, func(b): Settings.show_fps = b)
	g.add_child(UIKit.label("Растительность и дальность применяются к новым участкам мира по мере движения.", 16, UIKit.DIM, true))
	# --- Экран (PC)
	var s := _page("Экран")
	var res_list := [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
	var names: Array = []
	for r in res_list:
		names.append("%d × %d" % [r.x, r.y])
	_option(s, "Разрешение окна (PC)", names, maxi(0, res_list.find(Settings.resolution)), func(i): Settings.resolution = res_list[i]; Settings.apply())
	_check(s, "Полноэкранный режим (PC)", Settings.fullscreen, func(b): Settings.fullscreen = b; Settings.apply())
	_check(s, "Вертикальная синхронизация", Settings.vsync, func(b): Settings.vsync = b; Settings.apply())
	_slider(s, "Масштаб интерфейса", 0.75, 1.5, 0.05, Settings.ui_scale, func(x): Settings.ui_scale = x; Settings.apply())
	# --- Звук
	var a2 := _page("Звук")
	_slider(a2, "Общая громкость", 0, 1, 0.05, Settings.vol_master, func(x): Settings.vol_master = x; Settings.apply())
	_slider(a2, "Окружение (ветер, дождь, лес)", 0, 1, 0.05, Settings.vol_ambient, func(x): Settings.vol_ambient = x; Settings.apply())
	_slider(a2, "Эффекты", 0, 1, 0.05, Settings.vol_sfx, func(x): Settings.vol_sfx = x; Settings.apply())
	_slider(a2, "Музыка", 0, 1, 0.05, Settings.vol_music, func(x): Settings.vol_music = x; Settings.apply())
	_slider(a2, "Интерфейс", 0, 1, 0.05, Settings.vol_ui, func(x): Settings.vol_ui = x; Settings.apply())
	# --- Игра
	var gm := _page("Игра")
	_option(gm, "Сложность выживания", ["Лёгкая", "Обычная", "Суровая"], Settings.difficulty, func(i): Settings.difficulty = i)
	_slider(gm, "Длина игровых суток (мин)", 20, 120, 4, Settings.day_length_min, func(x): Settings.day_length_min = x)
	_check(gm, "Субтитры радио и диалогов", Settings.subtitles, func(b): Settings.subtitles = b)
	if cur >= 0:
		_tabs.current_tab = clampi(cur, 0, _tabs.get_tab_count() - 1)


func _custom() -> void:
	Settings.quality = 3
	Settings.apply()


func _page(name: String) -> VBoxContainer:
	var v := UIKit.vbox(10)
	var sc := UIKit.scroll(v)
	sc.name = name
	_tabs.add_child(sc)
	return v


func _row(parent: Control, text: String) -> HBoxContainer:
	var h := UIKit.hbox(12)
	var l := UIKit.label(text, 19)
	l.custom_minimum_size.x = 360
	h.add_child(l)
	parent.add_child(h)
	return h


func _slider(parent: Control, text: String, mn: float, mx: float, step: float, val: float, cb: Callable) -> void:
	var h := _row(parent, text)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = step
	sl.value = val
	sl.custom_minimum_size = Vector2(360, 36)
	var vl := UIKit.label(_fmt(val, step), 18, UIKit.ACCENT)
	vl.custom_minimum_size.x = 70
	sl.value_changed.connect(func(x): vl.text = _fmt(x, step); cb.call(x))
	h.add_child(sl)
	h.add_child(vl)


func _fmt(v: float, step: float) -> String:
	return ("%d" % int(v)) if step >= 1.0 else ("%.2f" % v)


func _check(parent: Control, text: String, val: bool, cb: Callable) -> void:
	var h := _row(parent, text)
	var b := CheckButton.new()
	b.button_pressed = val
	b.toggled.connect(func(x): cb.call(x))
	h.add_child(b)


func _option(parent: Control, text: String, items: Array, sel: int, cb: Callable) -> void:
	var h := _row(parent, text)
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.selected = sel
	o.custom_minimum_size = Vector2(320, 46)
	o.item_selected.connect(func(i): cb.call(i))
	h.add_child(o)


func _input(e: InputEvent) -> void:
	if _rebind_action == "":
		return
	var code := 0
	if e is InputEventKey and e.pressed:
		code = (e as InputEventKey).physical_keycode
	elif e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		code = -(e as InputEventMouseButton).button_index
	if code != 0:
		InputRouter.set_binding(_rebind_action, code)
		_rebind_btn.text = InputRouter.binding_text(code)
		_rebind_action = ""
		get_viewport().set_input_as_handled()
