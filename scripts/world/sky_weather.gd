class_name SkyWeather
extends Node3D
## Цикл дня и ночи + погода. Солнце/луна, небо, туман, дождь/снег, гроза, температура воздуха.
## Конец ноября, средняя полоса: солнце низкое, дни короткие, ночи холодные.

const WEATHERS := {
	#            облач. туман   свет   дождь  снег   ветер  темп.
	"clear":    [0.15,  0.006,  1.0,   0.0,   0.0,   0.25,  1.5],
	"overcast": [0.75,  0.009,  0.55,  0.0,   0.0,   0.45,  0.0],
	"fog":      [0.6,   0.045,  0.45,  0.0,   0.0,   0.1,   0.5],
	"rain":     [0.9,   0.016,  0.38,  0.8,   0.0,   0.6,  -2.0],
	"storm":    [1.0,   0.02,   0.28,  1.0,   0.0,   1.0,  -3.0],
	"snow":     [0.85,  0.022,  0.5,   0.0,   0.8,   0.5,  -6.0],
}
const WEATHER_NAMES := {"clear": "Ясно", "overcast": "Пасмурно", "fog": "Туман", "rain": "Дождь", "storm": "Гроза", "snow": "Снег"}
const NEXT := {
	"clear": [["clear", 2], ["overcast", 4], ["fog", 1]],
	"overcast": [["clear", 2], ["overcast", 2], ["rain", 3], ["fog", 1], ["snow", 1]],
	"fog": [["overcast", 3], ["clear", 2], ["fog", 1]],
	"rain": [["overcast", 3], ["rain", 1], ["storm", 1]],
	"storm": [["rain", 3], ["overcast", 1]],
	"snow": [["overcast", 3], ["snow", 1], ["clear", 1]],
}

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var world_env: WorldEnvironment
var rain_fx: MeshInstance3D
var snow_fx: MeshInstance3D
var rain_mat: ShaderMaterial
var snow_mat: ShaderMaterial

## текущие (плавно интерполируемые) параметры погоды
var p_cloud := 0.6
var p_fog := 0.03
var p_light := 0.5
var p_rain := 0.0
var p_snow := 0.0
var p_wind := 0.2
var p_temp := 0.0
var _flash := 0.0
var _next_lightning := 10.0
var _rng := RandomNumberGenerator.new()
var _amb_players: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_sky_affect = 0.85
	env.fog_aerial_perspective = 0.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.12
	env.glow_enabled = false
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_blend_splits = false
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.shadow_enabled = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)

	rain_mat = _precip_material(false)
	snow_mat = _precip_material(true)
	rain_fx = _precip_mesh(rain_mat)
	snow_fx = _precip_mesh(snow_mat)

	var w: Array = WEATHERS.get(GameState.weather, WEATHERS.clear)
	_set_params_instant(w)
	Events.settings_changed.connect(_apply_settings)
	_apply_settings()
	_start_ambience()


func _apply_settings() -> void:
	var sh := Settings.shadows
	sun.shadow_enabled = sh > 0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if sh <= 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = [0.0, 35.0, 60.0, 90.0][clampi(sh, 0, 3)]
	env.glow_enabled = Settings.glow
	env.ssao_enabled = Settings.ssao and RenderingServer.get_current_rendering_method() == "forward_plus"


func _set_params_instant(w: Array) -> void:
	p_cloud = w[0]
	p_fog = w[1]
	p_light = w[2]
	p_rain = w[3]
	p_snow = w[4]
	p_wind = w[5]
	p_temp = w[6]


func _precip_material(snow: bool) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform float intensity = 0.0;
uniform float speed = 9.0;
uniform float density = 60.0;
uniform float snow = 0.0;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment(){
	vec2 uv = UV * vec2(density, 6.0);
	float col = floor(uv.x);
	float off = hash(vec2(col, 3.1));
	float spd = speed * (0.7 + off * 0.6);
	float y = fract(uv.y + TIME * spd * 0.1 + off * 7.0);
	float fx = fract(uv.x);
	float a;
	if (snow > 0.5) {
		float sx = fract(uv.x + sin(TIME * 0.7 + off * 9.0) * 0.15);
		a = smoothstep(0.12, 0.0, length(vec2(sx - 0.5, (y - 0.5) * 3.0)));
	} else {
		a = smoothstep(0.08, 0.0, abs(fx - 0.5)) * smoothstep(0.0, 0.25, y) * smoothstep(0.55, 0.25, y);
	}
	a *= step(0.45, hash(vec2(col, floor(uv.y + TIME * spd * 0.1 + off * 7.0))));
	ALBEDO = snow > 0.5 ? vec3(0.9) : vec3(0.65, 0.7, 0.75);
	ALPHA = a * intensity * (snow > 0.5 ? 0.9 : 0.35);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("snow", 1.0 if snow else 0.0)
	m.set_shader_parameter("speed", 1.2 if snow else 9.0)
	m.set_shader_parameter("density", 90.0 if snow else 140.0)
	return m


func _precip_mesh(mat: ShaderMaterial) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 7.0
	cyl.bottom_radius = 7.0
	cyl.height = 18.0
	cyl.radial_segments = 16
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


func _start_ambience() -> void:
	for n in ["wind_loop", "rain_loop", "rain_roof_loop", "leaves_loop", "crickets_loop"]:
		var p := AudioStreamPlayer.new()
		p.stream = AudioLib.stream(n)
		p.bus = "Ambient"
		p.volume_db = -60.0
		p.autoplay = true
		add_child(p)
		_amb_players[n] = p


# =========================================================================== ЦИКЛ
func _process(delta: float) -> void:
	var minutes := delta * GameState.minutes_per_second() if GameState.running and not get_tree().paused else 0.0
	_update_weather_state(minutes)
	var target: Array = WEATHERS.get(GameState.weather, WEATHERS.clear)
	var k := clampf(minutes / 45.0, 0.0, 1.0) if minutes > 0.0 else 0.0
	p_cloud = lerpf(p_cloud, target[0], k)
	p_fog = lerpf(p_fog, target[1], k)
	p_light = lerpf(p_light, target[2], k)
	p_rain = lerpf(p_rain, target[3], k)
	p_snow = lerpf(p_snow, target[4], k)
	p_wind = lerpf(p_wind, target[5], k)
	p_temp = lerpf(p_temp, target[6], k)
	_update_sky(delta)
	_update_precip()
	_update_ambience(delta)


func _update_weather_state(minutes: float) -> void:
	if minutes <= 0.0:
		return
	if GameState.time_min >= GameState.weather_until:
		var opts: Array = NEXT.get(GameState.weather, NEXT.clear)
		var total := 0.0
		for o in opts:
			total += float(o[1])
		var r := _rng.randf() * total
		var pick := "clear"
		for o in opts:
			r -= float(o[1])
			if r <= 0.0:
				pick = o[0]
				break
		GameState.weather = pick
		GameState.weather_until = GameState.time_min + _rng.randf_range(150.0, 420.0)
		Events.weather_changed.emit(pick)


func sun_elevation_deg() -> float:
	var h := GameState.hour()
	var t := (h - 6.6) / (18.6 - 6.6)
	return sin(t * PI) * 24.0 if t >= 0.0 and t <= 1.0 else -sin(clampf(absf(t - 0.5) - 0.5, 0.0, 0.5) * PI) * 30.0


func _update_sky(delta: float) -> void:
	var h := GameState.hour()
	var t := (h - 6.6) / (18.6 - 6.6)
	var elev := sun_elevation_deg()
	var az := lerpf(-105.0, 105.0, clampf(t, 0.0, 1.0))
	var dir_h := Vector3(-sin(deg_to_rad(az)), 0, cos(deg_to_rad(az)))
	var sun_pos := dir_h * cos(deg_to_rad(elev)) + Vector3.UP * sin(deg_to_rad(elev))
	if sun_pos.length() > 0.01:
		sun.look_at_from_position(sun_pos * 100.0, Vector3.ZERO, Vector3.UP if absf(sun_pos.y) < 0.99 else Vector3.FORWARD)
	var day := clampf((elev + 4.0) / 14.0, 0.0, 1.0)            # 0 ночь … 1 день
	var golden := clampf(1.0 - absf(elev - 4.0) / 10.0, 0.0, 1.0) * (1.0 - p_cloud * 0.7)
	var cloud := p_cloud

	# Молния
	if GameState.weather == "storm":
		_next_lightning -= delta
		if _next_lightning <= 0.0:
			_next_lightning = _rng.randf_range(8.0, 25.0)
			_flash = 1.0
			get_tree().create_timer(_rng.randf_range(0.6, 3.0)).timeout.connect(func(): AudioLib.play_2d("thunder", -2.0, _rng.randf_range(0.8, 1.1), "Ambient"))
	_flash = maxf(0.0, _flash - delta * 3.5)

	var sun_col := Color(1.0, 0.93, 0.82).lerp(Color(1.0, 0.62, 0.35), golden)
	sun.light_color = sun_col
	sun.light_energy = day * p_light * 1.6 + _flash * 2.0
	sun.visible = elev > -2.0 or _flash > 0.0
	sun.shadow_opacity = clampf(1.0 - cloud * 0.6, 0.35, 1.0)

	moon.visible = day < 0.6
	moon.light_energy = (1.0 - day) * 0.16 * (1.0 - cloud * 0.5)
	moon.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30 + h * 5.0), 0)

	var top_day := Color(0.3, 0.38, 0.5).lerp(Color(0.33, 0.35, 0.37), cloud)
	var hor_day := Color(0.58, 0.6, 0.6).lerp(Color(0.44, 0.45, 0.45), cloud)
	var top_night := Color(0.018, 0.022, 0.04)
	var hor_night := Color(0.045, 0.05, 0.065)
	var hor_gold := Color(0.85, 0.55, 0.35)
	var top := top_night.lerp(top_day, day)
	var hor := hor_night.lerp(hor_day, day).lerp(hor_gold, golden * 0.6)
	top = top.lerp(Color(0.8, 0.8, 0.9), _flash * 0.6)
	hor = hor.lerp(Color(0.8, 0.8, 0.9), _flash * 0.6)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor * 0.8
	sky_mat.ground_bottom_color = hor * 0.25
	sky_mat.sun_angle_max = 25.0 if cloud < 0.6 else 8.0
	sky_mat.sky_energy_multiplier = 0.6 + day * 0.5

	env.ambient_light_energy = lerpf(0.28, 0.6, day) * (1.0 - cloud * 0.2) + _flash
	env.ambient_light_sky_contribution = 0.85
	var fog_col := hor.lerp(Color(0.42, 0.44, 0.44) * (0.12 + day * 0.88), 0.55)
	env.fog_light_color = fog_col
	env.fog_light_energy = 1.0
	var min_fog := 2.6 / maxf(Settings.view_distance, 60.0)
	env.fog_density = maxf(p_fog, min_fog) * (1.0 + (1.0 - day) * 0.35)
	env.tonemap_exposure = lerpf(1.5, 1.05, day)


func _update_precip() -> void:
	var cam := get_viewport().get_camera_3d()
	var player := GameState.player as Node3D
	var indoors = player != null and player.has_method("is_indoors") and player.is_indoors()
	var show_rain = p_rain > 0.05 and not indoors
	var show_snow = p_snow > 0.05 and not indoors
	rain_fx.visible = show_rain
	snow_fx.visible = show_snow
	if cam:
		rain_fx.global_position = cam.global_position
		snow_fx.global_position = cam.global_position
	rain_mat.set_shader_parameter("intensity", p_rain)
	snow_mat.set_shader_parameter("intensity", p_snow)


func _update_ambience(delta: float) -> void:
	var player := GameState.player as Node3D
	var indoors = player != null and player.has_method("is_indoors") and player.is_indoors()
	var night := GameState.is_night()
	var forest := 0.0
	if player:
		forest = RegionData.mask_at(player.global_position.x, player.global_position.z).g
	var targets := {
		"wind_loop": linear_to_db(clampf(0.15 + p_wind * 0.7, 0.0, 1.0) * (0.35 if indoors else 1.0)),
		"rain_loop": linear_to_db(maxf(p_rain * (0.0 if indoors else 1.0), 0.0001)),
		"rain_roof_loop": linear_to_db(maxf(p_rain * (0.9 if indoors else 0.0), 0.0001)),
		"leaves_loop": linear_to_db(maxf(forest * (0.3 + p_wind * 0.6) * (0.2 if indoors else 1.0), 0.0001)),
		"crickets_loop": linear_to_db(maxf((0.35 if night and p_rain < 0.2 and p_snow < 0.1 else 0.0) * (0.2 if indoors else 1.0), 0.0001)),
	}
	for n in targets:
		var p: AudioStreamPlayer = _amb_players[n]
		p.volume_db = lerpf(p.volume_db, maxf(targets[n], -60.0), clampf(delta * 1.5, 0.0, 1.0))
	# редкие птицы днём / ворона
	if not night and p_rain < 0.3 and _rng.randf() < delta * 0.06 and player:
		var off := Vector3(_rng.randf_range(-30, 30), _rng.randf_range(6, 14), _rng.randf_range(-30, 30))
		AudioLib.play_3d("crow" if _rng.randf() < 0.3 else "bird", player.global_position + off, -6.0, 1.0, 80.0)


# ======================================================================== ЗАПРОСЫ
func air_temperature() -> float:
	var h := GameState.hour()
	var daily := -cos((h - 3.0) / 24.0 * TAU) * 3.5     # минимум ~03:00, максимум ~15:00
	return 2.0 + daily + p_temp


func wind_strength() -> float:
	return p_wind


func is_raining() -> bool:
	return p_rain > 0.15 or p_snow > 0.2


func rain_intensity() -> float:
	return maxf(p_rain, p_snow * 0.5)


func weather_name() -> String:
	return WEATHER_NAMES.get(GameState.weather, "")


func force_weather(kind: String) -> void:
	GameState.weather = kind
	GameState.weather_until = GameState.time_min + 240.0
	_set_params_instant(WEATHERS[kind])
	Events.weather_changed.emit(kind)
