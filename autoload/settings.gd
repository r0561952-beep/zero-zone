extends Node
## Настройки игры. Хранятся в user://settings.cfg. apply() применяет их к движку,
## а системы мира (свет, тени, растительность) реагируют на Events.settings_changed.

const PATH := "user://settings.cfg"
const PRESETS := {
	0: {"render_scale": 0.7, "shadows": 1, "view_distance": 170.0, "vegetation": 0.45, "msaa": 0, "glow": false, "ssao": false},
	1: {"render_scale": 0.85, "shadows": 2, "view_distance": 250.0, "vegetation": 0.75, "msaa": 0, "glow": true, "ssao": false},
	2: {"render_scale": 1.0, "shadows": 3, "view_distance": 380.0, "vegetation": 1.0, "msaa": 1, "glow": true, "ssao": true},
}
const PRESET_NAMES := ["Низкое", "Среднее", "Высокое", "Своё"]
const BUSES := ["Music", "SFX", "Ambient", "UI"]

# --- управление
var control_mode := "touch"         ## "touch" (Android) или "pc"
var touch_sensitivity := 0.22
var mouse_sensitivity := 0.12
var invert_y := false
var joystick_size := 1.0
var touch_opacity := 0.55
var left_handed := false
var bindings: Dictionary = {}        ## action -> physical keycode / mouse button (отрицательное)

# --- графика
var quality := 1                     ## 0..2 пресеты, 3 — своё
var render_scale := 0.85
var shadows := 2                     ## 0 выкл, 1 низк, 2 сред, 3 выс
var view_distance := 250.0
var vegetation := 0.75
var msaa := 0
var glow := true
var ssao := false
var fps_limit := 60
var show_fps := false
var fov := 72.0
var head_bob := true

# --- экран (PC)
var fullscreen := false
var resolution := Vector2i(1280, 720)
var vsync := true
var ui_scale := 1.0

# --- звук
var vol_master := 0.9
var vol_music := 0.6
var vol_sfx := 0.9
var vol_ambient := 0.85
var vol_ui := 0.7

# --- игра
var day_length_min := 48.0
var subtitles := true
var difficulty := 1                  ## 0 — лёгкая (медленнее голод), 1 — обычная, 2 — суровая


func _ready() -> void:
	_ensure_buses()
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		control_mode = "touch"
		quality = 1
	else:
		control_mode = "pc"
		quality = 2
	_apply_preset_values(quality)
	load_settings()
	apply()


func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	# Глушение высоких частот для «приглушённого» звука в помещении/во время Гула
	var amb := AudioServer.get_bus_index("Ambient")
	if AudioServer.get_bus_effect_count(amb) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(amb, lp)


func set_ambient_muffle(cutoff_hz: float) -> void:
	var amb := AudioServer.get_bus_index("Ambient")
	if amb >= 0 and AudioServer.get_bus_effect_count(amb) > 0:
		var lp := AudioServer.get_bus_effect(amb, 0) as AudioEffectLowPassFilter
		if lp:
			lp.cutoff_hz = cutoff_hz


func apply_preset(q: int) -> void:
	quality = q
	if q in PRESETS:
		_apply_preset_values(q)
	apply()


func _apply_preset_values(q: int) -> void:
	var p: Dictionary = PRESETS.get(q, PRESETS[1])
	render_scale = p.render_scale
	shadows = p.shadows
	view_distance = p.view_distance
	vegetation = p.vegetation
	msaa = p.msaa
	glow = p.glow
	ssao = p.ssao


func is_pc() -> bool:
	return control_mode == "pc"


func is_desktop_os() -> bool:
	return not (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web"))


func apply() -> void:
	# Звук
	_set_bus("Master", vol_master)
	_set_bus("Music", vol_music)
	_set_bus("SFX", vol_sfx)
	_set_bus("Ambient", vol_ambient)
	_set_bus("UI", vol_ui)
	# Производительность
	Engine.max_fps = fps_limit
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = clampf(render_scale, 0.4, 1.0)
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(msaa, 0, 2)]
	var shadow_sizes := [512, 1024, 2048, 4096]
	RenderingServer.directional_shadow_atlas_set_size(shadow_sizes[clampi(shadows, 0, 3)], true)
	# Окно (только PC‑платформы)
	if is_desktop_os() and not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolution)
	if get_tree() and get_tree().root:
		get_tree().root.content_scale_factor = ui_scale
	Events.settings_changed.emit()


func _set_bus(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)


func save_settings() -> void:
	var c := ConfigFile.new()
	for k in _keys():
		c.set_value("settings", k, get(k))
	c.save(PATH)


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	for k in _keys():
		if c.has_section_key("settings", k):
			var v: Variant = c.get_value("settings", k)
			if typeof(v) == typeof(get(k)) or (typeof(get(k)) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				set(k, v)


func _keys() -> Array:
	return ["control_mode", "touch_sensitivity", "mouse_sensitivity", "invert_y", "joystick_size", "touch_opacity",
		"left_handed", "bindings", "quality", "render_scale", "shadows", "view_distance", "vegetation", "msaa",
		"glow", "ssao", "fps_limit", "show_fps", "fov", "head_bob", "fullscreen", "resolution", "vsync", "ui_scale",
		"vol_master", "vol_music", "vol_sfx", "vol_ambient", "vol_ui", "day_length_min", "subtitles", "difficulty"]


func drain_mult() -> float:
	return [0.65, 1.0, 1.35][clampi(difficulty, 0, 2)]
