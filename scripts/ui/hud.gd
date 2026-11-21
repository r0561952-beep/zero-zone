extends Control
## HUD: время/погода, показатели выживания, задание, подсказка взаимодействия, уведомления,
## быстрые слоты (PC), эффекты (Гул, урон, низкое здоровье), информация о машине.

var clock_lbl: Label
var temp_lbl: Label
var objective_lbl: Label
var prompt_lbl: Label
var crosshair: Control
var feed: VBoxContainer
var bars: Dictionary = {}
var warn_box: HBoxContainer
var quickbar: HBoxContainer
var location_lbl: Label
var vehicle_lbl: Label
var fps_lbl: Label
var fx: ColorRect
var fx_mat: ShaderMaterial
var flash: ColorRect
var _flash_a := 0.0
var _loc_t := 0.0
var _warn_t := 0.0
var _hum_warn := 0.0
var _heartbeat_t := 0.0
var _stats_panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIKit.theme()
	# эффекты (снизу)
	fx = ColorRect.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = _fx_shader()
	fx.material = fx_mat
	add_child(fx)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0, 0, 0, 0)
	add_child(flash)

	# статус (слева сверху)
	_stats_panel = PanelContainer.new()
	_stats_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.03, 0.03, 0.035, 0.55), 0, Color.BLACK, 8, 12, 8))
	_stats_panel.position = Vector2(16, 12)
	add_child(_stats_panel)
	var sv := UIKit.vbox(3)
	_stats_panel.add_child(sv)
	clock_lbl = UIKit.label("", 20, UIKit.TEXT)
	sv.add_child(clock_lbl)
	temp_lbl = UIKit.label("", 17, UIKit.DIM)
	sv.add_child(temp_lbl)
	for k in [["health", "Здоровье", Color(0.75, 0.25, 0.22)], ["hunger", "Сытость", Color(0.78, 0.55, 0.25)],
			["thirst", "Вода", Color(0.3, 0.55, 0.8)], ["sleep", "Бодрость", Color(0.55, 0.5, 0.75)],
			["temp", "Тепло", Color(0.85, 0.45, 0.3)], ["stamina", "Силы", Color(0.6, 0.7, 0.5)]]:
		var row := UIKit.hbox(6)
		var l := UIKit.label(k[1], 15, UIKit.DIM)
		l.custom_minimum_size.x = 74
		row.add_child(l)
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(150, 10)
		pb.show_percentage = false
		pb.max_value = 100
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := UIKit.box(k[2], 0, Color.BLACK, 3, 0, 0)
		pb.add_theme_stylebox_override("fill", fill)
		row.add_child(pb)
		sv.add_child(row)
		bars[k[0]] = pb
	warn_box = UIKit.hbox(6)
	sv.add_child(warn_box)

	# задание (справа сверху)
	objective_lbl = UIKit.label("", 18, UIKit.TEXT, true)
	objective_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	objective_lbl.anchor_left = 1.0
	objective_lbl.offset_left = -470
	objective_lbl.offset_right = -110
	objective_lbl.offset_top = 14
	objective_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	objective_lbl.add_theme_constant_override("outline_size", 4)
	add_child(objective_lbl)

	# прицел и подсказка
	crosshair = Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.draw.connect(func(): crosshair.draw_circle(Vector2.ZERO, 2.5, Color(1, 1, 1, 0.75)))
	add_child(crosshair)
	prompt_lbl = UIKit.label("", 22, UIKit.TEXT)
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_lbl.anchor_left = 0.5
	prompt_lbl.anchor_right = 0.5
	prompt_lbl.offset_left = -400
	prompt_lbl.offset_right = 400
	prompt_lbl.offset_top = 34
	prompt_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	prompt_lbl.add_theme_constant_override("outline_size", 6)
	add_child(prompt_lbl)

	# локация
	location_lbl = UIKit.title("", 46)
	location_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	location_lbl.anchor_left = 0.5
	location_lbl.anchor_right = 0.5
	location_lbl.offset_left = -500
	location_lbl.offset_right = 500
	location_lbl.offset_top = 120
	location_lbl.modulate.a = 0.0
	location_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	location_lbl.add_theme_constant_override("outline_size", 8)
	add_child(location_lbl)

	# уведомления
	feed = UIKit.vbox(4)
	feed.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	feed.anchor_left = 1.0
	feed.anchor_right = 1.0
	feed.offset_left = -470
	feed.offset_right = -18
	feed.offset_top = -60
	feed.alignment = BoxContainer.ALIGNMENT_END
	add_child(feed)

	# быстрые слоты (PC)
	quickbar = UIKit.hbox(6)
	quickbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	quickbar.anchor_left = 0.5
	quickbar.anchor_right = 0.5
	quickbar.offset_left = -160
	quickbar.offset_top = -86
	quickbar.offset_bottom = -12
	add_child(quickbar)

	vehicle_lbl = UIKit.label("", 22, UIKit.ACCENT)
	vehicle_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	vehicle_lbl.anchor_left = 0.5
	vehicle_lbl.anchor_right = 0.5
	vehicle_lbl.offset_left = -200
	vehicle_lbl.offset_right = 200
	vehicle_lbl.offset_top = -130
	vehicle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(vehicle_lbl)

	fps_lbl = UIKit.label("", 16, UIKit.DIM)
	fps_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	fps_lbl.position = Vector2(12, -30)
	fps_lbl.anchor_top = 1.0
	fps_lbl.anchor_bottom = 1.0
	add_child(fps_lbl)

	Events.notify.connect(_on_notify)
	Events.prompt_changed.connect(func(t): prompt_lbl.text = t)
	Events.hud_flash.connect(func(c): flash.color = c; _flash_a = c.a)
	Events.hum_warning.connect(func(_s): _hum_warn = 6.0)
	Events.inventory_changed.connect(_refresh_quickbar)
	Events.equipment_changed.connect(_refresh_quickbar)
	Events.settings_changed.connect(_layout)
	_refresh_quickbar()
	_layout()


func _layout() -> void:
	quickbar.visible = Settings.is_pc()
	var touch := not Settings.is_pc()
	_stats_panel.scale = Vector2.ONE * (0.92 if touch else 1.0)


func _fx_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float hum = 0.0;
uniform float low_hp = 0.0;
uniform float cold = 0.0;
uniform float tired = 0.0;
void fragment(){
	vec2 uv = SCREEN_UV;
	float t = TIME;
	vec2 c = uv - 0.5;
	float r = length(c);
	vec2 wob = vec2(sin(uv.y * 14.0 + t * 2.3), cos(uv.x * 11.0 + t * 1.7)) * 0.004 * hum;
	vec2 ca = c * 0.012 * hum;
	vec3 col;
	if (hum > 0.01) {
		col.r = texture(screen_tex, uv + wob + ca).r;
		col.g = texture(screen_tex, uv + wob).g;
		col.b = texture(screen_tex, uv + wob - ca).b;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	float vig = smoothstep(0.35, 0.85, r);
	col = mix(col, col * vec3(0.4, 0.05, 0.05), vig * low_hp * (0.7 + 0.3 * sin(t * 4.0)));
	float l = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(l) * vec3(0.8, 0.9, 1.1), cold * 0.6);
	col = mix(col, col * 0.15, vig * tired * 0.9);
	col = mix(col, col * 0.6, vig * hum * 0.8);
	COLOR = vec4(col, 1.0);
}
"""
	return s


func _process(delta: float) -> void:
	var p = GameState.player
	if p == null:
		return
	var s: Survival = p.survival
	clock_lbl.text = GameState.clock_text()
	var w = GameState.world_node
	var wname: String = w.sky.weather_name() if w and w.sky else ""
	var air: float = w.air_temperature() if w else 5.0
	temp_lbl.text = "%s, %+d°C  •  тело %.1f°" % [wname, int(round(air)), s.body_temp]
	bars.health.value = s.health
	bars.hunger.value = s.hunger
	bars.thirst.value = s.thirst
	bars.sleep.value = s.sleep
	bars.temp.value = clampf((s.body_temp - 34.0) / (37.0 - 34.0) * 100.0, 0, 100)
	bars.stamina.value = s.stamina
	objective_lbl.text = QuestSystem.current_objective()
	if GameState.is_hum_active():
		objective_lbl.text = "ГУЛ! Укройтесь в помещении или подполе."
	elif _hum_warn > 0.0 or (GameState.time_min > GameState.next_hum_at - 30.0):
		objective_lbl.text = "Звенит в ушах — скоро Гул. Найдите укрытие."
	# предупреждения
	_warn_t -= delta
	if _warn_t <= 0.0:
		_warn_t = 1.0
		for c in warn_box.get_children():
			c.queue_free()
		for wr in s.warnings():
			var col: Color = [UIKit.DIM, UIKit.ACCENT, UIKit.ACCENT, UIKit.BAD][wr[1]]
			var l := UIKit.label(wr[0], 15, col)
			warn_box.add_child(l)
	# эффекты
	var e_hum := clampf(s.hum_exposure / 70.0, 0.0, 1.0)
	var e_hp := clampf((30.0 - s.health) / 30.0, 0.0, 1.0)
	var e_cold := clampf((35.8 - s.body_temp) / 1.5, 0.0, 1.0)
	var e_tired := clampf((15.0 - s.sleep) / 15.0, 0.0, 1.0)
	fx.visible = e_hum + e_hp + e_cold + e_tired > 0.01   # экранный эффект только когда нужен (экономия на мобильных)
	if fx.visible:
		fx_mat.set_shader_parameter("hum", e_hum)
		fx_mat.set_shader_parameter("low_hp", e_hp)
		fx_mat.set_shader_parameter("cold", e_cold)
		fx_mat.set_shader_parameter("tired", e_tired)
	if s.health < 25.0:
		_heartbeat_t -= delta
		if _heartbeat_t <= 0.0:
			_heartbeat_t = 1.1
			AudioLib.play_2d("heartbeat", -6.0)
	_flash_a = maxf(0.0, _flash_a - delta * 1.2)
	flash.color.a = _flash_a
	_hum_warn = maxf(0.0, _hum_warn - delta)
	if _loc_t > 0.0:
		_loc_t -= delta
		location_lbl.modulate.a = clampf(minf(_loc_t, 4.0 - _loc_t + 0.01) * 1.5, 0.0, 1.0)
	crosshair.visible = InputRouter.gameplay_active
	prompt_lbl.visible = InputRouter.gameplay_active
	if p.in_vehicle:
		vehicle_lbl.text = "%d км/ч  •  бензин %.1f л" % [int(p.in_vehicle.speed_kmh()), float(p.in_vehicle.parts.fuel)]
	else:
		vehicle_lbl.text = ""
	fps_lbl.visible = Settings.show_fps
	if Settings.show_fps:
		fps_lbl.text = "FPS %d  •  draw %d" % [Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]


func _on_notify(text: String, kind: String) -> void:
	if kind == "location":
		location_lbl.text = text
		_loc_t = 4.0
		AudioLib.play_2d("theme_discovery", -12.0, 1.0, "Music")
		return
	var col: Color = {"good": UIKit.GOOD, "warn": UIKit.ACCENT, "bad": UIKit.BAD, "lore": Color(0.75, 0.7, 0.85)}.get(kind, UIKit.TEXT)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(Color(0.03, 0.03, 0.035, 0.7), 0, Color.BLACK, 6, 12, 6))
	var l := UIKit.label(text, 18, col, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pc.add_child(l)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.add_child(pc)
	while feed.get_child_count() > 6:
		feed.get_child(0).free()
	var tw := pc.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(pc, "modulate:a", 0.0, 1.0)
	tw.tween_callback(pc.queue_free)
	if kind == "bad":
		AudioLib.ui("error")


func _refresh_quickbar() -> void:
	for c in quickbar.get_children():
		c.queue_free()
	var p = GameState.player
	if p == null:
		return
	for i in 4:
		var id: String = p.quickbar[i]
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(72, 72)
		var eq: bool = p.equipment.has("hand") and p.equipment.hand.id == id and id != ""
		slot.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.05, 0.05, 0.6), 2 if eq else 1, UIKit.ACCENT if eq else Color(0.3, 0.3, 0.3), 6))
		if id != "":
			var n: int = p.count_item(id) + (1 if eq else 0)
			var ic := UIKit.item_icon(id, n, 64)
			ic.position = Vector2(4, 4)
			if n == 0:
				ic.modulate.a = 0.35
			slot.add_child(ic)
		var num := UIKit.label(str(i + 1), 14, UIKit.DIM)
		num.position = Vector2(5, 2)
		slot.add_child(num)
		quickbar.add_child(slot)
