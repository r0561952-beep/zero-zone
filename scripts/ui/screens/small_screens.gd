class_name SmallScreens
extends RefCounted
## Небольшие экраны: записка, радио, сон, укрытие в подполе, мел, машина, смерть.


static func _frame(title: String, min_size: Vector2) -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	var m := UIKit.modal(min_size)
	root.add_child(m[0])
	var v: VBoxContainer = m[1]
	var head := UIKit.hbox()
	head.add_child(UIKit.title(title, 28))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.button("✕", func(): Events.close_screens.emit(), 56))
	v.add_child(head)
	return [root, v]


# ============================================================================ ЗАПИСКА
static func note(payload: Dictionary) -> Control:
	var n: Dictionary = ItemDB.notes.get(str(payload.note), {})
	var f := _frame(str(n.get("title", "Документ")), Vector2(820, 560))
	var v: VBoxContainer = f[1]
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UIKit.box(Color(0.82, 0.78, 0.68), 0, Color.BLACK, 4, 24, 18))
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var txt := UIKit.rich("[color=#2a241c]%s[/color]" % str(n.get("text", "")))
	txt.add_theme_font_size_override("normal_font_size", 21)
	var sc := UIKit.scroll(txt)
	sc.custom_minimum_size.y = 400
	paper.add_child(sc)
	v.add_child(paper)
	if str(payload.note) == "tape":
		AudioLib.play_2d("radio_static_loop", -16.0)
	var hint := UIKit.label("Сохранено в журнале → Документы", 16, UIKit.DIM)
	v.add_child(hint)
	return f[0]


# ============================================================================== РАДИО
class RadioScreen:
	extends Control
	var freq := 98.6
	var _lbl: Label
	var _station_lbl: Label
	var _text: RichTextLabel
	var _static: AudioStreamPlayer
	var _line_t := 0.0
	var _line_i := 0
	var _cur := ""

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		theme = UIKit.theme()
		var f := SmallScreens._frame("Радиоприёмник «Альпинист»", Vector2(820, 460))
		add_child(f[0])
		var v: VBoxContainer = f[1]
		freq = float(GameState.flags.get("radio_freq", 98.6))
		_lbl = UIKit.title("%.1f МГц" % freq, 44)
		_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(_lbl)
		var sl := HSlider.new()
		var rng: Array = ItemDB.radio.get("range", [76.0, 108.0])
		sl.min_value = rng[0]
		sl.max_value = rng[1]
		sl.step = 0.1
		sl.value = freq
		sl.custom_minimum_size = Vector2(700, 40)
		sl.value_changed.connect(func(x): freq = x; _on_tune())
		v.add_child(sl)
		var row := UIKit.hbox()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for d in [-1.0, -0.1, 0.1, 1.0]:
			var dd: float = d
			row.add_child(UIKit.button(("%+.1f" % d), func(): sl.value = clampf(sl.value + dd, rng[0], rng[1]), 90))
		v.add_child(row)
		_station_lbl = UIKit.label("", 20, UIKit.ACCENT)
		v.add_child(_station_lbl)
		_text = UIKit.rich("")
		_text.custom_minimum_size.y = 120
		v.add_child(_text)
		_static = AudioStreamPlayer.new()
		_static.stream = AudioLib.stream("radio_static_loop")
		_static.bus = "SFX"
		_static.volume_db = -14.0
		add_child(_static)
		_static.play()
		_on_tune()

	func _station() -> Dictionary:
		var h := GameState.hour()
		for s in ItemDB.radio.get("stations", []):
			if absf(float(s.freq) - freq) < 0.25:
				var a: float = s.hours[0]
				var b: float = s.hours[1]
				var hh := h if h >= a else h + 24.0
				if hh >= a and hh < b and Conditions.check_all(s.get("cond", [])):
					return s
		return {}

	func _on_tune() -> void:
		_lbl.text = "%.1f МГц" % freq
		GameState.flags["radio_freq"] = freq
		var s := _station()
		if s.is_empty():
			_station_lbl.text = "…шипение…"
			_text.text = "[color=#777]Здесь только помехи. Попробуйте другие частоты — и в другое время суток.[/color]"
			_static.volume_db = -10.0
			_cur = ""
			return
		_static.volume_db = -24.0
		if s.name != _cur:
			_cur = str(s.name)
			_line_i = 0
			_line_t = 0.0
			AudioLib.play_2d("radio_tune", -10.0)
			if str(s.get("flag", "")) != "":
				GameState.set_flag(str(s.flag))
		_station_lbl.text = "Станция: " + str(s.name)
		_show_line(s)

	func _show_line(s: Dictionary) -> void:
		var lines: Array = s.get("lines", [])
		if lines.is_empty():
			return
		var l: String = lines[_line_i % lines.size()]
		if l == "@weather":
			var w = GameState.world_node
			l = "Автоматическая сводка. Погода: %s. Температура воздуха %+d°C. Ветер %s." % [w.sky.weather_name(), int(w.air_temperature()), "сильный" if w.wind_strength() > 0.6 else "умеренный"]
			if GameState.next_hum_at - GameState.time_min < 240.0:
				l += "  …[помехи]… сейсмическая активность… повышенная…"
		_text.text = l

	func _process(delta: float) -> void:
		if _cur == "":
			return
		_line_t += delta
		if _line_t > 7.0:
			_line_t = 0.0
			_line_i += 1
			var s := _station()
			if not s.is_empty():
				_show_line(s)


# ================================================================================ СОН
class SleepScreen:
	extends Control
	var quality := 1.0
	var title := "Кровать"
	var _info: Label

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		theme = UIKit.theme()
		var f := SmallScreens._frame(title, Vector2(640, 360))
		add_child(f[0])
		var v: VBoxContainer = f[1]
		var p = GameState.player
		var s: Survival = p.survival
		_info = UIKit.label("Бодрость: %d%%. Сколько спать?" % int(s.sleep), 20, UIKit.TEXT, true)
		v.add_child(_info)
		var row := UIKit.hbox()
		for h in [1, 2, 4, 8]:
			var hh: int = h
			row.add_child(UIKit.button("%d ч" % h, func(): _sleep(hh), 110))
		var till := int(ceil(fposmod(7.0 - GameState.hour(), 24.0)))
		row.add_child(UIKit.button("До утра (%d ч)" % till, func(): _sleep(till), 190))
		v.add_child(row)
		var warn := ""
		if not p.is_indoors() and not p.near_fire and GameState.world_node.air_temperature() < 3.0:
			warn = "Снаружи холодно — без огня сон будет беспокойным и опасным."
		if s.hunger < 15.0 or s.thirst < 15.0:
			warn += " Вы голодны или хотите пить — сон восстановит меньше."
		if warn != "":
			v.add_child(UIKit.label(warn, 18, UIKit.ACCENT, true))

	func _sleep(hours: int) -> void:
		var p = GameState.player
		var s: Survival = p.survival
		var slept := 0.0
		var interrupted := ""
		for i in hours * 6:
			var mins := 10.0
			if GameState.time_min + mins >= GameState.next_hum_at - 30.0 and GameState.time_min < GameState.next_hum_at:
				interrupted = "Вы проснулись от звона в ушах — скоро Гул!"
				break
			for npc in p.get_tree().get_nodes_in_group("npc"):
				if npc.hostile and npc.state != NPC.S.DEAD and npc.global_position.distance_to(p.global_position) < 25.0 and GameState.is_night():
					interrupted = "Шаги снаружи! Вы проснулись."
					break
			if interrupted != "":
				break
			GameState.advance(mins)
			var ctx := {"indoors": p.is_indoors(), "near_fire": p.near_fire, "air_temp": GameState.world_node.air_temperature(),
				"insulation": p.insulation() + 0.3, "sleeping": true, "wind": GameState.world_node.wind_strength(), "rain_protect": 1.0}
			s.tick(0.0, mins, ctx)
			s.hunger += 1.25 * mins / 60.0 * 0.4
			s.thirst += 2.0 * mins / 60.0 * 0.4
			var gain := 12.5 * quality * (0.6 if s.hunger < 15.0 or s.thirst < 15.0 else 1.0)
			s.sleep = minf(100.0, s.sleep + gain * mins / 60.0)
			s.stamina = 100.0
			slept += mins / 60.0
			if s.health <= 5.0:
				interrupted = "Вам слишком плохо, чтобы спать."
				break
		Events.player_slept.emit(slept)
		Events.close_screens.emit()
		Events.notify.emit("Вы проспали %.1f ч. %s" % [slept, interrupted], "info" if interrupted == "" else "warn")


# ================================================================ УКРЫТИЕ (ПОДПОЛ)
class HideScreen:
	extends Control
	var title := "Подпол"
	var _lbl: Label

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		theme = UIKit.theme()
		var dark := ColorRect.new()
		dark.color = Color(0.01, 0.01, 0.012, 0.97)
		dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dark)
		var c := CenterContainer.new()
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(c)
		var v := UIKit.vbox(16)
		c.add_child(v)
		v.add_child(UIKit.title("Вы в подполе", 36))
		_lbl = UIKit.label("", 20, UIKit.TEXT, true)
		_lbl.custom_minimum_size.x = 600
		v.add_child(_lbl)
		v.add_child(UIKit.button("Переждать", func(): _wait(), 260))
		v.add_child(UIKit.button("Выбраться наверх", func(): Events.close_screens.emit(), 260))
		GameState.player.shelter_depth += 1
		tree_exiting.connect(func(): GameState.player.shelter_depth = maxi(0, GameState.player.shelter_depth - 1))

	func _process(_d: float) -> void:
		var t := "Темно, пахнет картошкой и сырой землёй. "
		if GameState.is_hum_active():
			t += "Сверху едва различим низкий гул. Здесь он не страшен."
		else:
			t += "Гул ещё не пришёл. Можно переждать здесь."
		_lbl.text = t

	func _wait() -> void:
		var target := GameState.hum_active_until if GameState.is_hum_active() else GameState.next_hum_at + 26.0
		var mins := maxf(0.0, target - GameState.time_min) + 2.0
		GameState.advance(mins)
		var s: Survival = GameState.player.survival
		s.hunger = maxf(0.0, s.hunger - 1.25 * mins / 60.0)
		s.thirst = maxf(0.0, s.thirst - 2.0 * mins / 60.0)
		Events.notify.emit("Прошло %d мин. Наверху тихо." % int(mins), "info")


# ================================================================================ МЕЛ
static func chalk(ap: Dictionary) -> Control:
	var f := _frame("Знак мелом", Vector2(560, 260))
	var v: VBoxContainer = f[1]
	v.add_child(UIKit.label("Какой знак оставить? Его увидят и другие.", 19, UIKit.DIM, true))
	var row := UIKit.hbox()
	for pair in [["✓", "пусто"], ["✗", "опасно"], ["~", "вода"], ["□", "тайник"], ["→", "туда"], ["Г.Л.", "подпись"]]:
		var sym: String = pair[0]
		row.add_child(UIKit.button("%s\n%s" % [pair[0], pair[1]], func():
			GameState.world_node.add_chalk(ap.pos, ap.normal, sym)
			Events.close_screens.emit(), 80, 18))
	v.add_child(row)
	return f[0]


# ============================================================================= МАШИНА
static func car(c: Car) -> Control:
	var f := _frame(c.display_name().capitalize(), Vector2(700, 480))
	var v: VBoxContainer = f[1]
	var p = GameState.player
	for r in c.report():
		v.add_child(UIKit.label(("✓ " if r[1] else "✗ ") + str(r[0]), 19, UIKit.GOOD if r[1] else UIKit.DIM))
	v.add_child(HSeparator.new())
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	v.add_child(flow)
	for a in c.actions(p):
		var aid: String = a[0]
		var b := UIKit.button(str(a[1]), func(): c.do_action(aid, p), 0, 19)
		b.disabled = not a[2]
		flow.add_child(b)
	if not p.has_tool("wrench") and c.state in ["donor", "repairable"]:
		v.add_child(UIKit.label("Для работы с деталями нужен разводной ключ.", 17, UIKit.ACCENT, true))
	return f[0]


# ============================================================================= СМЕРТЬ
static func death(cause: String, on_load: Callable, on_menu: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.0, 0.0, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var v := UIKit.vbox(16)
	c.add_child(v)
	v.add_child(UIKit.title("Глеб погиб", 52))
	v.add_child(UIKit.label("Причина: %s.  %s" % [cause, GameState.clock_text()], 22, UIKit.TEXT))
	v.add_child(UIKit.label("Нулевая зона не прощает ошибок. Но она и не торопит.", 18, UIKit.DIM))
	v.add_child(UIKit.button("Загрузить последнее сохранение", on_load, 380))
	v.add_child(UIKit.button("Главное меню", on_menu, 380))
	return root
