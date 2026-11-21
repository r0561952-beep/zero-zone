extends Node
## Единая точка ввода. Игрок читает только отсюда — источник может быть тач‑интерфейсом
## или клавиатурой/мышью. Сенсорные кнопки нажимают те же действия через Input.action_press().

const DEFAULT_BINDINGS := {
	"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
	"jump": KEY_SPACE, "sprint": KEY_SHIFT, "crouch": KEY_C, "interact": KEY_E,
	"inventory": KEY_TAB, "flashlight": KEY_F, "pause": KEY_ESCAPE,
	"slot_1": KEY_1, "slot_2": KEY_2, "slot_3": KEY_3, "slot_4": KEY_4,
	"map": KEY_M, "journal": KEY_J, "radio": KEY_R, "tuning_fork": KEY_Q,
	"attack": -MOUSE_BUTTON_LEFT, "chalk": KEY_G, "crafting": KEY_K,
}
const ACTION_NAMES := {
	"move_forward": "Вперёд", "move_back": "Назад", "move_left": "Влево", "move_right": "Вправо",
	"jump": "Прыжок", "sprint": "Бег", "crouch": "Присесть", "interact": "Действие",
	"inventory": "Инвентарь", "flashlight": "Фонарик", "pause": "Пауза",
	"slot_1": "Быстрый слот 1", "slot_2": "Быстрый слот 2", "slot_3": "Быстрый слот 3", "slot_4": "Быстрый слот 4",
	"map": "Карта", "journal": "Журнал", "radio": "Радио", "tuning_fork": "Камертон",
	"attack": "Удар", "chalk": "Мел", "crafting": "Крафт",
}

var touch_move := Vector2.ZERO
var _look := Vector2.ZERO
var gameplay_active := false      ## true — игрок управляет персонажем (нет открытых экранов)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rebuild_input_map()


func rebuild_input_map() -> void:
	for action in DEFAULT_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		var code: int = int(Settings.bindings.get(action, DEFAULT_BINDINGS[action]))
		InputMap.action_add_event(action, _make_event(code))
	# Дополнительные клавиши по умолчанию
	_add_extra("crouch", KEY_CTRL)
	_add_extra("inventory", KEY_I)
	_add_extra("move_forward", KEY_UP)
	_add_extra("move_back", KEY_DOWN)
	_add_extra("move_left", KEY_LEFT)
	_add_extra("move_right", KEY_RIGHT)


func _add_extra(action: String, key: int) -> void:
	if not Settings.bindings.has(action):
		InputMap.action_add_event(action, _make_event(key))


func _make_event(code: int) -> InputEvent:
	if code < 0:
		var mb := InputEventMouseButton.new()
		mb.button_index = -code as MouseButton
		return mb
	var k := InputEventKey.new()
	k.physical_keycode = code as Key
	return k


static func binding_text(code: int) -> String:
	if code < 0:
		return {1: "ЛКМ", 2: "ПКМ", 3: "СКМ"}.get(-code, "Мышь %d" % -code)
	return OS.get_keycode_string(code as Key)


func set_binding(action: String, code: int) -> void:
	Settings.bindings[action] = code
	rebuild_input_map()
	Settings.save_settings()


func reset_bindings() -> void:
	Settings.bindings = {}
	rebuild_input_map()
	Settings.save_settings()


func add_look(delta: Vector2) -> void:
	_look += delta


func consume_look() -> Vector2:
	var l := _look
	_look = Vector2.ZERO
	return l


func move_vector() -> Vector2:
	if touch_move.length() > 0.05:
		return touch_move.limit_length(1.0)
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func set_gameplay_active(active: bool) -> void:
	gameplay_active = active
	if not active:
		touch_move = Vector2.ZERO
		for a in ["sprint", "crouch", "attack", "jump", "interact"]:
			Input.action_release(a)
	_update_mouse_mode()


func _update_mouse_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if Settings.is_pc() and gameplay_active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not gameplay_active or not Settings.is_pc():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look(event.relative * Settings.mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_update_mouse_mode()
