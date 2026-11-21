class_name GameUI
extends CanvasLayer
## Корень интерфейса в игре: HUD, сенсорное управление, экраны (инвентарь, журнал, диалоги…), пауза.

signal to_main_menu
signal load_slot(slot: String)

const INVENTORY := preload("res://scripts/ui/inventory_screen.gd")
const JOURNAL := preload("res://scripts/ui/screens/journal_screen.gd")
const DIALOGUE := preload("res://scripts/ui/screens/dialogue_screen.gd")
const SETTINGS := preload("res://scripts/ui/screens/settings_screen.gd")
const SAVELOAD := preload("res://scripts/ui/screens/saveload_screen.gd")
const HUD := preload("res://scripts/ui/hud.gd")
const TOUCH := preload("res://scripts/ui/touch_controls.gd")

var hud: Control
var touch: Control
var screen: Control
var screen_name := ""
var _sub: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud = HUD.new()
	add_child(hud)
	touch = TOUCH.new()
	add_child(touch)
	touch.open_requested.connect(func(s): open(s, null))
	Events.open_screen.connect(open)
	Events.close_screens.connect(close)
	Events.player_died.connect(_on_died)
	Events.settings_changed.connect(_update_touch)
	_update_touch()


func _update_touch() -> void:
	touch.visible = not Settings.is_pc() and (screen == null or screen_name == "placement")


func _process(_d: float) -> void:
	var p = GameState.player
	if p and screen_name != "placement":
		touch.set_mode("vehicle" if p.in_vehicle else "walk")


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey or e is InputEventMouseButton) or not e.is_pressed():
		return
	if screen_name == "placement":
		return
	if screen != null:
		if e.is_action_pressed("pause") or (e.is_action_pressed("inventory") and screen_name in ["inventory", "container", "crafting"]) \
				or (e.is_action_pressed("journal") and screen_name in ["journal", "map"]) or (e.is_action_pressed("map") and screen_name in ["journal", "map"]):
			if _sub:
				return
			close()
			get_viewport().set_input_as_handled()
		return
	var p = GameState.player
	if p == null or p.dead:
		return
	for a in [["pause", "pause"], ["inventory", "inventory"], ["journal", "journal"], ["map", "map"], ["crafting", "crafting"], ["radio", "radio"]]:
		if e.is_action_pressed(a[0]):
			open(a[1], null)
			get_viewport().set_input_as_handled()
			return


func open(name: String, payload: Variant) -> void:
	var p = GameState.player
	if p == null:
		return
	if screen:
		_free_screen()
	screen_name = name
	var s: Control = null
	match name:
		"inventory", "crafting", "container":
			s = INVENTORY.new()
			s.player = p
			if name == "crafting":
				s.start_tab = 1
				s.craft_context = str(payload) if payload else ""
			if name == "container":
				s.container = payload
				payload.ensure_inventory()
		"journal", "map":
			s = JOURNAL.new()
			s.start_tab = 3 if name == "map" else 0
		"dialogue":
			s = DIALOGUE.new()
			s.npc = payload
		"note":
			s = SmallScreens.note(payload)
		"radio":
			if not p.inventory.has("radio"):
				Events.notify.emit("Радиоприёмника пока нет", "warn")
				screen_name = ""
				return
			s = SmallScreens.RadioScreen.new()
		"sleep":
			var sl := SmallScreens.SleepScreen.new()
			sl.quality = float(payload.quality)
			sl.title = str(payload.title)
			s = sl
		"hide":
			s = SmallScreens.HideScreen.new()
		"chalk":
			s = SmallScreens.chalk(payload)
		"car":
			s = SmallScreens.car(payload)
		"pause":
			s = _pause_menu()
		"placement":
			screen = Control.new()
			screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(screen)
			touch.set_mode("placement")
			_update_touch()
			return
	if s == null:
		screen_name = ""
		return
	screen = s
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(screen)
	AudioLib.ui("open")
	InputRouter.set_gameplay_active(false)
	get_tree().paused = name != "hide"
	_update_touch()


func close() -> void:
	if screen == null:
		return
	if screen_name == "placement":
		var w = GameState.world_node
		if w and w.placement.active:
			w.placement.cancel()
	_free_screen()
	screen_name = ""
	get_tree().paused = false
	var p = GameState.player
	if p and not p.dead:
		InputRouter.set_gameplay_active(true)
	touch.set_mode("walk")
	_update_touch()
	AudioLib.ui("close")


func _free_screen() -> void:
	if _sub:
		_sub.queue_free()
		_sub = null
	if screen:
		screen.queue_free()
		screen = null


func _pause_menu() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	var m := UIKit.modal(Vector2(460, 560))
	root.add_child(m[0])
	var v: VBoxContainer = m[1]
	v.add_child(UIKit.title("Пауза", 34))
	v.add_child(UIKit.label(GameState.clock_text(), 18, UIKit.DIM))
	v.add_child(UIKit.button("Продолжить", func(): close(), 400))
	v.add_child(UIKit.button("Сохранить", func(): _open_sub(_saveload("save")), 400))
	v.add_child(UIKit.button("Загрузить", func(): _open_sub(_saveload("load")), 400))
	v.add_child(UIKit.button("Журнал и задания", func(): open("journal", null), 400))
	v.add_child(UIKit.button("Карта", func(): open("map", null), 400))
	v.add_child(UIKit.button("Настройки", func():
		var st := SETTINGS.new()
		st.closed.connect(func(): _sub = null)
		_open_sub(st), 400))
	v.add_child(UIKit.button("Выйти в главное меню", func():
		SaveSystem.save_game("auto")
		to_main_menu.emit(), 400))
	return root


func _saveload(mode: String) -> Control:
	var s := SAVELOAD.new()
	s.mode = mode
	s.closed.connect(func(): _sub = null)
	s.load_requested.connect(func(slot): load_slot.emit(slot))
	return s


func _open_sub(c: Control) -> void:
	if _sub:
		_sub.queue_free()
	_sub = c
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(c)


func _on_died(cause: String) -> void:
	_free_screen()
	InputRouter.set_gameplay_active(false)
	screen_name = "death"
	screen = SmallScreens.death(cause, func():
		var s := SaveSystem.latest_slot()
		if s != "":
			load_slot.emit(s)
		else:
			to_main_menu.emit(), func(): to_main_menu.emit())
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(screen)
	_update_touch()
