class_name Car
extends VehicleBody3D
## Заброшенная машина. Можно осмотреть (состояние узлов), обыскать багажник и бардачок,
## снять детали (доноры) и починить «Ниву» почтальона: аккумулятор, свечи, колесо, бензин.
## Отремонтированная машина управляется физикой VehicleBody3D; без водителя — «заморожена».

const SCALE := 1.6
const STATE_NAMES := {"wreck": "Разбитая", "donor": "Брошенная", "burned": "Сгоревшая", "repairable": "Брошенная"}
const PART_NAMES := {"battery": "Аккумулятор", "plugs": "Свечи зажигания", "wheel": "Колесо", "fuel": "Бензин"}

var car_id := ""
var model := "sedan"
var state := "donor"
var title := ""
var parts: Dictionary = {}      ## battery/plugs/wheel: bool (исправно/есть), fuel: литры
var driver: Node = null
var trunk: LootContainer
var glove: LootContainer
var cam: Camera3D
var engine_snd: AudioStreamPlayer3D
var _wheels: Array[VehicleWheel3D] = []
var _cam_yaw := 0.0
var _cam_pitch := 0.0
var _rng := RandomNumberGenerator.new()


func setup(def: Dictionary) -> void:
	car_id = str(def.id)
	model = str(def.get("model", "sedan"))
	state = str(def.get("state", "donor"))
	title = str(def.get("name", ""))
	_rng.seed = hash(car_id)


func _ready() -> void:
	add_to_group("saveable")
	collision_layer = 16
	collision_mask = 1 | 16
	mass = 950.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.35, 0.25)
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	can_sleep = true
	# детали по умолчанию
	if state == "repairable":
		parts = {"battery": false, "plugs": false, "wheel": false, "fuel": 0.0}
	else:
		parts = {"battery": _rng.randf() < 0.45, "plugs": _rng.randf() < 0.5, "wheel": _rng.randf() < 0.6, "fuel": 0.0}
		if state != "donor":
			parts = {"battery": false, "plugs": false, "wheel": false, "fuel": 0.0}
	var saved: Dictionary = GameState.world.get("car:" + car_id, {})
	if not saved.is_empty():
		_apply_saved(saved)
	_build_visual()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.5, 1.05, 2.55) * SCALE
	cs.shape = b
	cs.position = Vector3(0, 0.72 * SCALE, 0)
	add_child(cs)
	trunk = _make_container("trunk", "Багажник", "car_trunk", Vector3(0, 0.8, -2.0))
	glove = _make_container("glove", "Бардачок", "car_glove", Vector3(0.3, 1.0, 0.6))
	if car_id == "car_r17_1":
		trunk.fixed_items = [["spare_wheel", 1]]
	if state == "repairable":
		engine_snd = AudioLib.make_loop_3d(self, "engine_loop", -60.0, 60.0, "SFX")
		engine_snd.autoplay = false
		cam = Camera3D.new()
		cam.position = Vector3(0.38, 1.38, 0.15)
		cam.rotation.y = PI
		cam.near = 0.05
		cam.far = Settings.view_distance + 40.0
		cam.current = false
		add_child(cam)


func _apply_saved(s: Dictionary) -> void:
	parts = s.get("parts", parts)
	if s.has("pos"):
		global_position = SaveSystem.to_v3(s.pos, global_position)
		rotation.y = float(s.get("rot", rotation.y))


func _make_container(sub: String, t: String, table: String, pos: Vector3) -> LootContainer:
	var c := LootContainer.new()
	c.container_id = car_id + "/" + sub
	c.title = t
	c.loot_table = table
	c.slots_count = 8
	c.position = pos
	c.box_size = Vector3(0.2, 0.2, 0.2)
	c.blocking = false
	add_child(c)
	c.collision_layer = 0
	return c


func _build_visual() -> void:
	var inst := Models.instance("k:car-kit/" + model)
	if inst == null:
		var kit := MeshKit.new()
		kit.add_box(Mats.get_mat("metal_rust"), Transform3D(Basis(), Vector3(0, 0.7, 0)), Vector3(1.6, 0.9, 4.0))
		add_child(kit.build_instance("Car"))
		return
	inst.scale = Vector3.ONE * SCALE
	add_child(inst)
	var mat := _car_material()
	Models.override_material(inst, mat)
	# колёса → VehicleWheel3D (крутятся при езде)
	for wn in ["wheel-front-left", "wheel-front-right", "wheel-back-left", "wheel-back-right"]:
		var w := inst.get_node_or_null(wn) as Node3D
		if w == null:
			continue
		if state == "repairable":
			var vw := VehicleWheel3D.new()
			vw.name = wn
			vw.position = w.position * SCALE + Vector3(0, 0.05, 0)
			vw.wheel_radius = 0.3 * SCALE
			vw.wheel_rest_length = 0.12
			vw.suspension_travel = 0.18
			vw.suspension_stiffness = 45.0
			vw.suspension_max_force = 12000.0
			vw.damping_compression = 0.6
			vw.damping_relaxation = 0.9
			vw.wheel_friction_slip = 2.8
			vw.use_as_traction = true
			vw.use_as_steering = wn.begins_with("wheel-front")
			add_child(vw)
			w.reparent(vw, false)
			w.position = Vector3.ZERO
			w.scale = Vector3.ONE * SCALE
			_wheels.append(vw)
		elif state in ["wreck", "burned"] and _rng.randf() < 0.5:
			w.visible = false
	if state == "repairable" and not parts.wheel:
		var fl := get_node_or_null("wheel-front-left")
		if fl:
			fl.get_child(0).scale = Vector3(SCALE, SCALE * 0.85, SCALE * 0.85)
	if state == "wreck":
		inst.rotation = Vector3(_rng.randf_range(-0.05, 0.05), 0, _rng.randf_range(-0.12, 0.12))
		inst.position.y = -0.15


func _car_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D colormap : source_color, filter_nearest;
uniform sampler2D rust_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float rust = 0.5;
uniform float burned = 0.0;
varying vec3 wp;
varying vec3 wn;
void vertex(){ wp = VERTEX; wn = NORMAL; }
void fragment(){
	vec3 base = texture(colormap, UV).rgb;
	float l = dot(base, vec3(0.3, 0.59, 0.11));
	base = mix(vec3(l), base, 0.55) * 0.8;
	vec3 an = abs(wn);
	vec3 r = texture(rust_tex, wp.zy * 0.6).rgb * an.x + texture(rust_tex, wp.xz * 0.6).rgb * an.y + texture(rust_tex, wp.xy * 0.6).rgb * an.z;
	float n = texture(rust_tex, wp.xz * 0.13 + wp.y * 0.2).r;
	float k = smoothstep(0.35, 0.75, n + rust * 0.6 - 0.3);
	vec3 c = mix(base, r * 0.8, k * rust);
	c = mix(c, vec3(0.05, 0.045, 0.04) + r * 0.08, burned);
	ALBEDO = c;
	ROUGHNESS = mix(0.45, 0.95, max(k * rust, burned));
	METALLIC = mix(0.35, 0.1, k);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("colormap", load("res://assets/thirdparty/kenney/car-kit/Textures/colormap.png"))
	m.set_shader_parameter("rust_tex", Mats.tex("rusty_painted_metal", "albedo"))
	m.set_shader_parameter("rust", {"wreck": 0.9, "donor": 0.55, "repairable": 0.35, "burned": 0.6}.get(state, 0.5))
	m.set_shader_parameter("burned", 1.0 if state == "burned" else 0.0)
	return m


func display_name() -> String:
	if title != "":
		return title
	var names := {"sedan": "легковушка", "suv": "внедорожник", "van": "фургон", "truck": "грузовичок", "hatchback-sports": "хэтчбек", "delivery": "фургон доставки"}
	return "%s %s" % [STATE_NAMES.get(state, ""), names.get(model, "машина")]


func get_prompt(_player: Node) -> String:
	if driver:
		return ""
	return "Осмотреть: " + display_name()


func interact(_player: Node) -> void:
	Events.open_screen.emit("car", self)


## Состояние для интерфейса.
func can_drive() -> bool:
	return state == "repairable" and parts.battery and parts.plugs and parts.wheel and float(parts.fuel) > 0.5


func report() -> Array:
	var out: Array = []
	if state in ["wreck", "burned"]:
		out.append(["Машина не на ходу: %s" % ("выгорела дотла" if state == "burned" else "разбита"), false])
	for k in ["battery", "plugs", "wheel"]:
		var ok: bool = parts.get(k, false)
		var txt := "%s: %s" % [PART_NAMES[k], ("в порядке" if ok else "нет / неисправен") if state == "repairable" else ("можно снять" if ok else "нет")]
		out.append([txt, ok])
	if state == "repairable":
		out.append(["Бензин: %.1f л" % float(parts.fuel), float(parts.fuel) > 0.5])
	return out


## Список действий: [id, подпись, доступно]
func actions(player: Node) -> Array:
	var a: Array = []
	a.append(["trunk", "Обыскать багажник", true])
	a.append(["glove", "Обыскать бардачок", state != "burned"])
	if state == "donor":
		var wr: bool = player.has_tool("wrench")
		if parts.battery:
			a.append(["take_battery", "Снять аккумулятор (ключ)", wr])
		if parts.plugs:
			a.append(["take_plugs", "Выкрутить свечи (ключ)", wr])
		if parts.wheel:
			a.append(["take_wheel", "Снять колесо (ключ)", wr])
	if state == "repairable":
		var wr2: bool = player.has_tool("wrench")
		if not parts.battery:
			a.append(["put_battery", "Поставить аккумулятор", player.count_item("car_battery") > 0 and wr2])
		if not parts.plugs:
			a.append(["put_plugs", "Вкрутить свечи", player.count_item("spark_plugs") > 0 and wr2])
		if not parts.wheel:
			a.append(["put_wheel", "Поменять спущенное колесо", player.count_item("spare_wheel") > 0 and wr2])
		a.append(["refuel", "Залить бензин из канистры", player.count_item("fuel_can") > 0])
		a.append(["drive", "Сесть за руль", true])
	return a


func do_action(id: String, player: Node) -> void:
	match id:
		"trunk":
			trunk.ensure_inventory()
			AudioLib.play_3d("door_creak", global_position, -6.0, 1.4)
			Events.open_screen.emit("container", trunk)
			return
		"glove":
			glove.ensure_inventory()
			Events.open_screen.emit("container", glove)
			return
		"take_battery":
			parts.battery = false
			player.give("car_battery", 1)
		"take_plugs":
			parts.plugs = false
			player.give("spark_plugs", 1)
		"take_wheel":
			parts.wheel = false
			player.give("spare_wheel", 1)
		"put_battery":
			player.inventory.remove("car_battery", 1)
			parts.battery = true
		"put_plugs":
			player.inventory.remove("spark_plugs", 1)
			parts.plugs = true
		"put_wheel":
			player.inventory.remove("spare_wheel", 1)
			parts.wheel = true
			var fl := get_node_or_null("wheel-front-left")
			if fl and fl.get_child_count() > 0:
				fl.get_child(0).scale = Vector3.ONE * SCALE
		"refuel":
			player.inventory.remove("fuel_can", 1)
			parts.fuel = float(parts.fuel) + 10.0
			AudioLib.play_3d("water_fill", global_position, 0.0, 0.7)
		"drive":
			if not can_drive():
				AudioLib.play_3d("engine_start_fail", global_position, 0.0)
				Events.notify.emit("Не заводится. Проверьте аккумулятор, свечи, колесо и бензин.", "warn")
				return
			Events.close_screens.emit()
			enter(player)
			return
	if id.begins_with("take_") or id.begins_with("put_"):
		AudioLib.play_3d("metal_clank", global_position, -4.0)
		GameState.add_skill_xp("mechanics", 10)
	if state == "repairable" and can_drive():
		GameState.set_flag("niva_repaired")
	_save()
	Events.open_screen.emit("car", self)


func enter(player: Node) -> void:
	driver = player
	player.in_vehicle = self
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	(player.get_node("Shape") as CollisionShape3D).disabled = true
	freeze = false
	cam.current = true
	cam.far = Settings.view_distance + 40.0
	_cam_yaw = 0.0
	_cam_pitch = 0.0
	engine_snd.play()
	AudioLib.play_3d("engine_start_fail", global_position, -4.0, 1.3)
	GameState.set_flag("niva_driven")
	Events.notify.emit("Мотор завёлся! Шумно — слышно издалека.", "good")


func exit_car() -> void:
	if driver == null:
		return
	var p: Node3D = driver
	var out := global_transform * Vector3(-1.8, 0.4, 0.3)
	out.y = maxf(out.y, RegionData.height_at(out.x, out.z) + 0.2)
	p.global_position = out
	p.visible = true
	p.process_mode = Node.PROCESS_MODE_INHERIT
	(p.get_node("Shape") as CollisionShape3D).disabled = false
	p.in_vehicle = null
	p.camera.current = true
	p.set_look(global_rotation.y + PI, 0.0)
	driver = null
	engine_force = 0.0
	brake = 30.0
	engine_snd.stop()
	get_tree().create_timer(2.0).timeout.connect(func():
		if driver == null:
			freeze = true
			_save())
	_save()


func _physics_process(delta: float) -> void:
	if driver == null:
		return
	# игрок «едет» вместе с машиной: стриминг мира и коллизия земли следуют за ним
	(driver as Node3D).global_position = global_position + Vector3.UP * 1.2
	var mv := InputRouter.move_vector() if InputRouter.gameplay_active else Vector2.ZERO
	var throttle := -mv.y
	var spd := linear_velocity.dot(global_transform.basis.z)
	steering = move_toward(steering, -mv.x * 0.42, delta * 2.0)
	if float(parts.fuel) <= 0.0:
		throttle = 0.0
	if throttle > 0.05:
		engine_force = throttle * 950.0 if spd > -1.0 and spd < 24.0 else 0.0
		brake = 0.0 if spd > -1.0 else 25.0
	elif throttle < -0.05:
		engine_force = throttle * 600.0 if spd < 1.0 and spd > -7.0 else 0.0
		brake = 0.0 if spd < 1.0 else 25.0
	else:
		engine_force = 0.0
		brake = 3.0
	if Input.is_action_pressed("jump"):
		brake = 45.0
	parts.fuel = maxf(0.0, float(parts.fuel) - (absf(engine_force) * 0.000016 + 0.0004) * delta)
	engine_snd.pitch_scale = 0.7 + clampf(absf(spd) / 18.0, 0.0, 1.4)
	engine_snd.volume_db = -6.0 + clampf(absf(throttle) * 6.0, 0.0, 6.0)
	if Engine.get_physics_frames() % 30 == 0:
		Events.noise_emitted.emit(global_position, 45.0, driver)
	# обзор
	var look := InputRouter.consume_look()
	_cam_yaw = clampf(_cam_yaw - deg_to_rad(look.x), -2.2, 2.2)
	_cam_pitch = clampf(_cam_pitch - deg_to_rad(look.y), -0.9, 0.6)
	cam.rotation = Vector3(_cam_pitch, PI + _cam_yaw, 0)
	if InputRouter.gameplay_active and Input.is_action_just_pressed("interact"):
		exit_car()


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func _save() -> void:
	GameState.world["car:" + car_id] = {"parts": parts, "pos": SaveSystem.v3(global_position), "rot": rotation.y}


var save_id: String:
	get:
		return "car:" + car_id


func save_data() -> Dictionary:
	_save()
	return GameState.world["car:" + car_id]


func load_data(d: Dictionary) -> void:
	parts = d.get("parts", parts)
	if d.has("pos"):
		global_position = SaveSystem.to_v3(d.pos, global_position)
		rotation.y = float(d.get("rot", rotation.y))
