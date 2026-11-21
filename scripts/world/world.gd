class_name World
extends Node3D
## Мир Нулевой зоны: строит регион из data/*.json, держит системы (погода, Гул, задания, размещение),
## отвечает на запросы игрока (температура, дождь, локации), хранит брошенные предметы и меловые знаки.

const PLAYER_SCRIPT := preload("res://scripts/player/player.gd")

var sky: SkyWeather
var terrain: TerrainStreamer
var placement: Placement
var quests: QuestSystem
var hum: HumSystem
var player: CharacterBody3D
var dynamic_root: Node3D
var _wet_t := 0.0
var _autosave_t := 0.0


func build(new_game: bool) -> void:
	RegionData.ensure_loaded()
	GameState.world_node = self
	if new_game:
		for d in ["front", "inner", "bedroom", "pantry"]:
			GameState.world["d:tikhon/" + d] = {"open": true, "locked": false}

	sky = SkyWeather.new()
	sky.name = "SkyWeather"
	add_child(sky)
	terrain = TerrainStreamer.new()
	terrain.name = "Terrain"
	add_child(terrain)

	var reg := ItemDB.region
	for r in reg.get("roads", []):
		if r.type == "asphalt":
			Structures.road_ribbon(r.points, float(r.width), self)
	if reg.has("stream"):
		Structures.stream_ribbon(reg.stream.points, float(reg.stream.width), self)

	var grass := GrassField.new()
	grass.name = "Grass"
	add_child(grass)
	var broot := Node3D.new()
	broot.name = "Buildings"
	add_child(broot)
	for b in ItemDB.world.get("buildings", []):
		BuildingTemplates.build(b, broot)
		var big := 9.0 if str(b.tpl).begins_with("house") else 5.0
		var sz := {"house_a": 8.0, "house_b": 9.6, "fap": 13.0, "shop": 10.0, "school": 26.0, "garage_row": 16.0, "cabin": 5.2, "gas_shop": 12.0, "shed": 6.0}.get(b.tpl, 8.0)
		var r := float(sz) * 0.5 + big
		terrain.no_tree_rects.append(Rect2(b.pos[0] - r, b.pos[1] - r, r * 2.0, r * 2.0))
		var rr := float(sz) * 0.5 + 0.8
		grass.no_grass.append(Rect2(b.pos[0] - rr, b.pos[1] - rr, rr * 2.0, rr * 2.0))

	var sroot := Node3D.new()
	sroot.name = "Structures"
	add_child(sroot)
	for s in ItemDB.world.get("structures", []):
		Structures.build(s, sroot)
		if s.has("pos"):
			terrain.no_tree_rects.append(Rect2(s.pos[0] - 8.0, s.pos[1] - 8.0, 16.0, 16.0))

	for c in ItemDB.world.get("cars", []):
		var car := Car.new()
		car.setup(c)
		car.name = "Car_" + str(c.id)
		car.position = Vector3(c.pos[0], RegionData.height_at(c.pos[0], c.pos[1]) + 0.02, c.pos[1])
		car.rotation.y = deg_to_rad(float(c.rot))
		add_child(car)
		terrain.no_tree_rects.append(Rect2(c.pos[0] - 4.0, c.pos[1] - 4.0, 8.0, 8.0))
		grass.no_grass.append(Rect2(c.pos[0] - 2.0, c.pos[1] - 2.0, 4.0, 4.0))

	for n in ItemDB.world.get("npcs", []):
		var npc := NPC.create(n)
		npc.name = "NPC_" + str(n.id)
		add_child(npc)
		var start: Vector3 = npc.home
		if npc.kind == "tikhon":
			var r := npc._routine_now()
			if r.size() > 0:
				start = (r[2] as Array)[-1]
		npc.global_position = start
		if GameState.world.has("npc:" + npc.npc_id):
			npc.load_data(GameState.world["npc:" + npc.npc_id])

	dynamic_root = Node3D.new()
	dynamic_root.name = "Dynamic"
	add_child(dynamic_root)
	for rec in GameState.placed:
		Placement.spawn(rec, dynamic_root)
	_spawn_saved_dropped()
	for ch in GameState.chalk:
		_spawn_chalk(ch)

	quests = QuestSystem.new()
	quests.name = "Quests"
	add_child(quests)
	hum = HumSystem.new()
	hum.name = "Hum"
	add_child(hum)
	placement = Placement.new()
	placement.name = "Placement"
	add_child(placement)

	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	add_child(player)
	var st: Dictionary = ItemDB.world.get("start", {"pos": [-636, 40], "rot": 90})
	var sp := Vector3(st.pos[0], RegionData.height_at(st.pos[0], st.pos[1]) + 0.3, st.pos[1])
	player.global_position = sp
	player.set_look(deg_to_rad(-float(st.rot)), 0.0)
	if new_game:
		player.give_starting_kit()
	else:
		SaveSystem.apply_pending()
	terrain.focus = player
	grass.focus = player
	terrain.build_around(player.global_position)
	# убедиться, что игрок над землёй после загрузки
	var gh := RegionData.height_at(player.global_position.x, player.global_position.z)
	if player.global_position.y < gh - 2.0 and player.global_position.y > -20.0:
		player.global_position.y = gh + 0.3
	Events.weather_changed.connect(func(_k): _autosave_t = 0.0)
	Events.location_discovered.connect(_on_location)
	Events.player_slept.connect(func(_h): SaveSystem.save_game("auto"))


func _process(delta: float) -> void:
	_wet_t -= delta
	if _wet_t <= 0.0:
		_wet_t = 1.0
		terrain.set_wetness(clampf(sky.p_rain * 1.2, 0.0, 1.0), clampf(sky.p_snow, 0.0, 1.0))
	_autosave_t += delta
	if _autosave_t > 300.0 and GameState.running and player and not player.dead:
		_autosave_t = 0.0
		SaveSystem.save_game("auto")


# ======================================================================== ЗАПРОСЫ
func air_temperature() -> float:
	return sky.air_temperature()


func wind_strength() -> float:
	return sky.wind_strength()


func is_raining() -> bool:
	return sky.is_raining()


func rain_intensity() -> float:
	return sky.rain_intensity()


func begin_placement(item_id: String) -> void:
	placement.begin(item_id)


func check_locations(pos: Vector3) -> void:
	for l in ItemDB.region.get("locations", []):
		var c := Vector2(l.center[0], l.center[1])
		if c.distance_to(Vector2(pos.x, pos.z)) < float(l.radius):
			GameState.discover(str(l.id))


func location_name_at(pos: Vector3) -> String:
	var best := "Лес"
	var best_d := INF
	for l in ItemDB.region.get("locations", []):
		var d := Vector2(l.center[0], l.center[1]).distance_to(Vector2(pos.x, pos.z))
		if d < float(l.radius) * 1.5 and d < best_d:
			best_d = d
			best = str(l.name)
	if pos.y < -15.0:
		return "Убежище под школой"
	return best


func _on_location(id: String) -> void:
	for l in ItemDB.region.get("locations", []):
		if l.id == id:
			Events.notify.emit(str(l.name), "location")
			GameState.add_skill_xp("search", 5)
			if id != "perimeter":
				get_tree().create_timer(1.0).timeout.connect(func(): SaveSystem.save_game("auto"))


# ================================================================ БРОШЕННЫЕ ПРЕДМЕТЫ
func spawn_dropped(id: String, n: int, data: Dictionary, pos: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos - Vector3.UP * 5.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		pos = hit.position
	if not GameState.world.has("dropped"):
		GameState.world["dropped"] = []
	var rec := {"id": id, "n": n, "d": data, "pos": SaveSystem.v3(pos)}
	GameState.world["dropped"].append(rec)
	_spawn_dropped_node(rec)


func _spawn_dropped_node(rec: Dictionary) -> void:
	var wi := WorldItem.new()
	wi.item_id = str(rec.id)
	wi.count = int(rec.n)
	wi.data = rec.get("d", {})
	wi.position = SaveSystem.to_v3(rec.pos)
	wi.set_meta("rec", rec)
	dynamic_root.add_child(wi)


func _spawn_saved_dropped() -> void:
	for rec in GameState.world.get("dropped", []):
		_spawn_dropped_node(rec)


func remove_dropped(node: Node) -> void:
	if not node.has_meta("rec"):
		return
	var rec: Dictionary = node.get_meta("rec")
	var arr: Array = GameState.world.get("dropped", [])
	arr.erase(rec)


# ======================================================================= МЕЛ
func add_chalk(pos: Vector3, normal: Vector3, text: String) -> void:
	var rec := {"pos": SaveSystem.v3(pos + normal * 0.02), "n": SaveSystem.v3(normal), "t": text}
	GameState.chalk.append(rec)
	_spawn_chalk(rec)
	var p = GameState.player
	if p:
		var ci: int = p.inventory.find("chalk")
		if ci >= 0:
			var d: Dictionary = p.inventory.slots[ci].d
			d["charge"] = float(d.get("charge", 100.0)) - 10.0
			if float(d.charge) <= 0.0:
				p.inventory.remove_at(ci, 1)
				Events.notify.emit("Мел закончился", "warn")


func _spawn_chalk(rec: Dictionary) -> void:
	var l := Label3D.new()
	l.text = str(rec.t)
	l.font_size = 140
	l.pixel_size = 0.0035
	l.modulate = Color(0.95, 0.95, 0.9, 0.85)
	l.shaded = true
	var n := SaveSystem.to_v3(rec.n, Vector3.FORWARD)
	var p := SaveSystem.to_v3(rec.pos)
	dynamic_root.add_child(l)
	l.global_position = p
	l.look_at(p - n, Vector3.UP)
