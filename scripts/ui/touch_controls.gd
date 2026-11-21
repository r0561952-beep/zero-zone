extends Control
## Сенсорное управление (Android): плавающий джойстик слева, обзор свайпом справа, кнопки действий.
## Полная мультитач‑обработка: каждый палец закрепляется за своей зоной/кнопкой.
## Кнопки нажимают те же действия ввода (Input.action_press), что и клавиатура на PC.

signal open_requested(screen: String)

const BTN_R := 46.0

var _joy_touch := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_touch := -1
var _look_last := Vector2.ZERO
var _btn_touch: Dictionary = {}      ## touch index -> button id
var _toggles := {"sprint": false, "crouch": false}
var buttons: Array = []
var mode := "walk"                   ## walk | vehicle | placement
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UIKit.theme().default_font
	resized.connect(_layout)
	Events.settings_changed.connect(_layout)
	Events.equipment_changed.connect(queue_redraw)
	Events.inventory_changed.connect(queue_redraw)
	_layout()


func _layout() -> void:
	var s := size
	var right := s.x if not Settings.left_handed else 0.0
	var sgn := -1.0 if not Settings.left_handed else 1.0
	var r := BTN_R * Settings.joystick_size
	buttons = []
	var ax := right + sgn * (r * 1.6)
	var ay := s.y - r * 1.8
	if mode == "walk":
		_add("interact", "Действие", Vector2(ax, ay), r * 1.15, "action")
		_add("jump", "Прыжок", Vector2(ax + sgn * r * 2.3, ay + r * 0.6), r * 0.85, "action")
		_add("attack", "Удар", Vector2(ax, ay - r * 2.4), r, "action")
		_add("sprint", "Бег", Vector2(ax + sgn * r * 2.5, ay - r * 1.7), r * 0.8, "toggle")
		_add("crouch", "Присесть", Vector2(ax + sgn * r * 4.4, ay + r * 0.6), r * 0.8, "toggle")
		_add("flashlight", "Свет", Vector2(ax + sgn * r * 4.6, ay - r * 1.5), r * 0.7, "action")
		_add("tuning_fork", "Камертон", Vector2(ax + sgn * r * 0.2, ay - r * 4.4), r * 0.7, "action")
		# верхний ряд
		var tx := right + sgn * 50.0
		_add("pause", "≡", Vector2(tx, 46), 30.0, "screen")
		_add("inventory", "Вещи", Vector2(tx + sgn * 80.0, 46), 34.0, "screen")
		_add("journal", "Журнал", Vector2(tx + sgn * 165.0, 46), 34.0, "screen")
		_add("map", "Карта", Vector2(tx + sgn * 250.0, 46), 34.0, "screen")
		# быстрые слоты — снизу по центру
		for i in 4:
			_add("slot_%d" % i, "", Vector2(s.x * 0.5 + (i - 1.5) * 84.0, s.y - 48.0), 36.0, "slot")
	elif mode == "vehicle":
		_add("interact", "Выйти", Vector2(ax, ay - r * 2.2), r, "action")
		_add("jump", "Тормоз", Vector2(ax, ay), r * 1.2, "action")
		_add("pause", "≡", Vector2(right + sgn * 50.0, 46), 30.0, "screen")
	elif mode == "placement":
		_add("place_ok", "Поставить", Vector2(ax, ay), r * 1.2, "place")
		_add("place_rot", "Повернуть", Vector2(ax + sgn * r * 2.5, ay), r, "place")
		_add("place_cancel", "Отмена", Vector2(ax, ay - r * 2.4), r * 0.9, "place")
	queue_redraw()


func set_mode(m: String) -> void:
	if m == mode:
		return
	mode = m
	_release_all()
	_layout()


func _add(id: String, text: String, pos: Vector2, r: float, kind: String) -> void:
	buttons.append({"id": id, "text": text, "pos": pos, "r": r, "kind": kind})


func _button_visible(b: Dictionary) -> bool:
	var p = GameState.player
	if b.id == "attack":
		return p != null and p.equipment.has("hand") and ItemDB.item(p.equipment.hand.id).has("weapon")
	if b.id == "tuning_fork":
		return p != null and p.inventory.has("tuning_fork")
	return true


func _hit(pos: Vector2) -> Dictionary:
	for b in buttons:
		if _button_visible(b) and pos.distance_to(b.pos) <= b.r * 1.15:
			return b
	return {}


func _input(event: InputEvent) -> void:
	if not visible or Settings.is_pc():
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var pos := e.position
		if e.pressed:
			var b := _hit(pos)
			if not b.is_empty():
				_btn_touch[e.index] = b.id
				_press(b)
				get_viewport().set_input_as_handled()
			elif _is_joy_side(pos) and _joy_touch == -1 and mode != "placement":
				_joy_touch = e.index
				_joy_origin = pos
				_joy_pos = pos
			elif _look_touch == -1:
				_look_touch = e.index
				_look_last = pos
		else:
			if _btn_touch.has(e.index):
				_release(_btn_touch[e.index])
				_btn_touch.erase(e.index)
			if e.index == _joy_touch:
				_joy_touch = -1
				InputRouter.touch_move = Vector2.ZERO
				if _toggles.sprint:
					_toggles.sprint = false
					Input.action_release("sprint")
			if e.index == _look_touch:
				_look_touch = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_touch:
			_joy_pos = d.position
			var radius := 70.0 * Settings.joystick_size
			var v := (_joy_pos - _joy_origin)
			if v.length() > radius:
				_joy_origin = _joy_pos - v.normalized() * radius   # «плавающий» центр
				v = v.normalized() * radius
			InputRouter.touch_move = v / radius
			queue_redraw()
		elif d.index == _look_touch:
			InputRouter.add_look(d.relative * Settings.touch_sensitivity)


func _is_joy_side(pos: Vector2) -> bool:
	return (pos.x < size.x * 0.45) if not Settings.left_handed else (pos.x > size.x * 0.55)


func _press(b: Dictionary) -> void:
	match b.kind:
		"action":
			Input.action_press(b.id)
		"toggle":
			_toggles[b.id] = not _toggles[b.id]
			if _toggles[b.id]:
				Input.action_press(b.id)
			else:
				Input.action_release(b.id)
		"screen":
			open_requested.emit(b.id)
		"slot":
			var p = GameState.player
			if p:
				p.use_quickbar(int(str(b.id).substr(5)))
		"place":
			var w = GameState.world_node
			if w:
				match b.id:
					"place_ok": w.placement.confirm()
					"place_rot": w.placement.rotate_ghost()
					"place_cancel": w.placement.cancel()
	AudioLib.ui("click")


func _release(id: String) -> void:
	for b in buttons:
		if b.id == id and b.kind == "action":
			Input.action_release(id)


func _release_all() -> void:
	for id in ["interact", "jump", "attack", "flashlight", "tuning_fork", "sprint", "crouch"]:
		Input.action_release(id)
	_toggles = {"sprint": false, "crouch": false}
	_btn_touch.clear()
	_joy_touch = -1
	_look_touch = -1
	InputRouter.touch_move = Vector2.ZERO


func _process(_delta: float) -> void:
	if visible and not Settings.is_pc():
		queue_redraw()


func _draw() -> void:
	if Settings.is_pc():
		return
	var a := Settings.touch_opacity
	# джойстик
	if _joy_touch != -1:
		var radius := 70.0 * Settings.joystick_size
		draw_circle(_joy_origin, radius, Color(1, 1, 1, 0.08 * a * 2.0))
		draw_arc(_joy_origin, radius, 0, TAU, 40, Color(1, 1, 1, 0.3 * a), 2.0, true)
		draw_circle(_joy_pos, 30.0 * Settings.joystick_size, Color(1, 1, 1, 0.35 * a))
	elif mode != "placement":
		var hint := Vector2(size.x * 0.16 if not Settings.left_handed else size.x * 0.84, size.y * 0.72)
		draw_arc(hint, 60.0 * Settings.joystick_size, 0, TAU, 40, Color(1, 1, 1, 0.12 * a), 2.0, true)
	var p = GameState.player
	var prompt_active := p != null and p.current_target() != null
	for b in buttons:
		if not _button_visible(b):
			continue
		var pressed: bool = _btn_touch.values().has(b.id) or _toggles.get(b.id, false)
		var col := Color(0.05, 0.05, 0.05, 0.45 * a + 0.1)
		if pressed:
			col = Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.55)
		elif b.id == "interact" and prompt_active:
			col = Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.35)
		draw_circle(b.pos, b.r, col)
		draw_arc(b.pos, b.r, 0, TAU, 36, Color(1, 1, 1, 0.35 * a + 0.1), 2.0, true)
		if b.kind == "slot" and p:
			var i := int(str(b.id).substr(5))
			var id: String = p.quickbar[i]
			if id != "":
				var name := ItemDB.item_name(id).split(" ")[0]
				if name.length() > 9:
					name = name.substr(0, 8) + "…"
				var n: int = p.count_item(id)
				var eq: bool = p.equipment.has("hand") and p.equipment.hand.id == id
				_text(b.pos + Vector2(0, -4), name, 13, Color(1, 1, 1, 0.9 if (n > 0 or eq) else 0.35), b.r * 2.0)
				if eq:
					draw_arc(b.pos, b.r - 4, 0, TAU, 36, UIKit.ACCENT, 3.0, true)
				elif n > 1:
					_text(b.pos + Vector2(0, 16), "×%d" % n, 13, UIKit.ACCENT, b.r * 2.0)
			continue
		_text(b.pos + Vector2(0, 6), b.text, 16 if b.r > 40 else 14, Color(1, 1, 1, 0.9), b.r * 2.2)


func _text(center: Vector2, t: String, fs: int, col: Color, width: float) -> void:
	var sz := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, width, fs)
	draw_string(_font, center - Vector2(width * 0.5, -sz.y * 0.25 + 6), t, HORIZONTAL_ALIGNMENT_CENTER, width, fs, col)
