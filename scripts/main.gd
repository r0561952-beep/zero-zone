extends Node
## Точка входа: главное меню → вступление → мир; загрузка/сохранение; возврат в меню.

const SETTINGS := preload("res://scripts/ui/screens/settings_screen.gd")
const SAVELOAD := preload("res://scripts/ui/screens/saveload_screen.gd")

var world: World
var ui: GameUI
var menu: CanvasLayer
var _overlay: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = UIKit.theme()
	# Автотест/скриншот режимы (CI, разработка)
	var args := OS.get_cmdline_user_args()
	if "--autostart" in args:
		start_game(true)
		return
	show_menu()


# ===================================================================== ГЛАВНОЕ МЕНЮ
func show_menu() -> void:
	end_game()
	menu = CanvasLayer.new()
	menu.layer = 5
	add_child(menu)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	menu.add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
void fragment(){
	vec2 uv = UV * vec2(3.0, 1.7);
	float f = n(uv + vec2(TIME * 0.03, 0.0)) * 0.6 + n(uv * 2.3 - vec2(TIME * 0.05, 0.0)) * 0.3 + n(uv * 5.0) * 0.1;
	float horizon = smoothstep(0.9, 0.45, UV.y);
	vec3 col = mix(vec3(0.02, 0.022, 0.025), vec3(0.16, 0.16, 0.15), f * horizon);
	// силуэт леса
	float trees = step(UV.y, 0.72 + n(vec2(UV.x * 40.0, 0.0)) * 0.08 + n(vec2(UV.x * 7.0, 3.0)) * 0.06);
	col = mix(col, vec3(0.012, 0.013, 0.015), 1.0 - trees);
	float vig = smoothstep(1.1, 0.3, length(UV - vec2(0.5, 0.45)));
	COLOR = vec4(col * vig, 1.0);
}
"""
	sm.shader = sh
	bg.material = sm
	root.add_child(bg)
	var v := UIKit.vbox(10)
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = 90
	v.offset_top = -260
	v.offset_right = 600
	root.add_child(v)
	v.add_child(UIKit.title("ZERO ZONE", 86))
	var sub := UIKit.label("НУЛЕВАЯ ЗОНА", 26, UIKit.DIM)
	sub.add_theme_font_override("font", UIKit.font_title)
	v.add_child(sub)
	v.add_child(UIKit.spacer(false))
	var latest := SaveSystem.latest_slot()
	if latest != "":
		v.add_child(UIKit.button("Продолжить", func(): load_game(latest), 360))
	v.add_child(UIKit.button("Новая игра", func(): _intro(), 360))
	v.add_child(UIKit.button("Загрузить", func():
		var s := SAVELOAD.new()
		s.mode = "load"
		s.load_requested.connect(func(slot): load_game(slot))
		root.add_child(s), 360))
	v.add_child(UIKit.button("Настройки", func(): root.add_child(SETTINGS.new()), 360))
	v.add_child(UIKit.button("Об игре", func(): _about(root), 360))
	if Settings.is_desktop_os():
		v.add_child(UIKit.button("Выход", func(): get_tree().quit(), 360))
	var ver := UIKit.label("v%s  •  Godot %s  •  ранний доступ: Сосновка, лес, трасса Р‑17, заправка «Луч»" % [ProjectSettings.get_setting("application/config/version"), Engine.get_version_info().string], 15, UIKit.DIM)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 20
	ver.offset_top = -34
	root.add_child(ver)
	InputRouter.set_gameplay_active(false)


func _about(root: Control) -> void:
	var m := UIKit.modal(Vector2(860, 560))
	root.add_child(m[0])
	var v: VBoxContainer = m[1]
	v.add_child(UIKit.title("Об игре", 30))
	var t := UIKit.rich("""[b]ZERO ZONE / НУЛЕВАЯ ЗОНА[/b] — атмосферный survival от первого лица.
Ночью 3 октября жители Каменского района ушли из своих домов. Вы — Глеб Ланской, настройщик фортепиано. Вы ищете сестру.

[b]Движок:[/b] Godot Engine (MIT).
[b]Модели и текстуры:[/b] Poly Haven (CC0), Kenney (CC0).
[b]Шрифты:[/b] PT Sans (ParaType, OFL), Oswald (OFL).
[b]Звук:[/b] процедурный синтез (собственные ассеты, CC0), интерфейсные звуки Kenney (CC0).
Полный каталог источников — docs/ASSETS.md в репозитории.""")
	v.add_child(UIKit.scroll(t))
	v.add_child(UIKit.button("Закрыть", func(): m[0].queue_free(), 200))


func _intro() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := ColorRect.new()
	root.color = Color(0.01, 0.01, 0.012)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	layer.add_child(root)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var v := UIKit.vbox(18)
	v.custom_minimum_size.x = 860
	c.add_child(v)
	var lines := [
		"3 октября. 03:17.",
		"За одну ночь из Каменского района исчезли сорок тысяч человек. Без следов борьбы. Без тел.",
		"Официально — авария на химкомбинате. Эвакуация завершена. Район закрыт. «Нулевая зона».",
		"Через год мне пришла открытка. Почерк моей сестры Веры. Штемпель — через месяц после той ночи.",
		"«Не верь им. Мы живы. Ищи под школой».",
		"Я настройщик фортепиано. Я не солдат. Но я нашёл дыру в заборе.",
	]
	var labels: Array = []
	for l in lines:
		var lb := UIKit.label(l, 24 if l != lines[4] else 28, UIKit.TEXT if l != lines[4] else UIKit.ACCENT, true)
		lb.modulate.a = 0.0
		v.add_child(lb)
		labels.append(lb)
	var btn := UIKit.button("Начать", func():
		layer.queue_free()
		start_game(true), 260)
	btn.modulate.a = 0.0
	v.add_child(btn)
	var tw := create_tween()
	for lb in labels:
		tw.tween_property(lb, "modulate:a", 1.0, 1.2)
		tw.tween_interval(0.6)
	tw.tween_property(btn, "modulate:a", 1.0, 0.6)


# ============================================================================ ИГРА
func start_game(new_game: bool, slot: String = "") -> void:
	end_game()
	if new_game:
		GameState.new_game()
	elif not SaveSystem.prepare_load(slot):
		show_menu()
		return
	_overlay = _loading()
	await get_tree().process_frame
	await get_tree().process_frame
	world = World.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.build(new_game)
	ui = GameUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.to_main_menu.connect(show_menu)
	ui.load_slot.connect(load_game)
	if is_instance_valid(_overlay):
		_overlay.get_parent().queue_free()
	GameState.running = true
	InputRouter.set_gameplay_active(true)
	if new_game:
		get_tree().create_timer(0.8).timeout.connect(func():
			Events.notify.emit("Цель: добраться до Сосновки. Дорога — на восток.", "info")
			if not Settings.is_pc():
				Events.notify.emit("Слева — ходьба, справа — обзор. «Вещи» — инвентарь.", "info")
			else:
				Events.notify.emit("WASD, мышь, E — действие, Tab — инвентарь, J — журнал, M — карта", "info"))


func _loading() -> Control:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var r := ColorRect.new()
	r.color = Color(0.02, 0.02, 0.025)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(r)
	var l := UIKit.title("Загрузка Нулевой зоны…", 34)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.offset_left = -300
	l.offset_right = 300
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_child(l)
	return r


func load_game(slot: String) -> void:
	get_tree().paused = false
	start_game(false, slot)


func end_game() -> void:
	GameState.running = false
	get_tree().paused = false
	if menu:
		menu.queue_free()
		menu = null
	if ui:
		ui.queue_free()
		ui = null
	if world:
		world.queue_free()
		world = null
	GameState.player = null
	GameState.world_node = null


func _notification(what: int) -> void:
	# Сохранение при сворачивании/закрытии приложения (Android)
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameState.running and GameState.player and not GameState.player.dead:
			SaveSystem.save_game("auto")
