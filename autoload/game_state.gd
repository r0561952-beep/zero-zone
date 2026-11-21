extends Node
## Состояние текущей игры: время, погода, флаги и дельты мира, журнал, навыки, отношения.
## Всё, что здесь лежит, сериализуется в сохранение через to_dict()/from_dict().

const SAVE_VERSION := 1
const SKILLS := {"search": "Поиск", "craft": "Ремесло", "survival": "Выживание", "mechanics": "Механика", "medicine": "Медицина"}
const SKILL_LEVELS := [0, 40, 110, 220, 400]
const MAP_FOG_W := 64
const MAP_FOG_H := 48

var running := false               ## идёт ли игра (время течёт)
var player: Node = null            ## ссылка на игрока (не сохраняется)
var world_node: Node = null        ## ссылка на мир (не сохраняется)
var pending_load: Dictionary = {}  ## данные сохранения, ожидающие применения

var time_min: float = 0.0          ## игровые минуты с начала (день 1, 00:00)
var weather: String = "fog"
var weather_until: float = 0.0
var next_hum_at: float = 0.0
var hum_active_until: float = -1.0
var flags: Dictionary = {}
var world: Dictionary = {}         ## дельты мира: контейнеры, двери, подобранные предметы, деревья...
var placed: Array = []             ## объекты убежища, поставленные игроком
var chalk: Array = []              ## меловые знаки игрока
var journal: Array = []
var notes_read: Array = []
var known_recipes: Array = []
var discovered: Array = []
var map_fog := PackedByteArray()
var map_marks: Array = []
var quests: Dictionary = {}
var trust: Dictionary = {}
var skills: Dictionary = {}
var counters: Dictionary = {}
var playtime: float = 0.0
var _last_hour := -1


func _process(delta: float) -> void:
	if not running or get_tree().paused:
		return
	playtime += delta
	advance(delta * minutes_per_second())


func minutes_per_second() -> float:
	return 1440.0 / (max(Settings.day_length_min, 5.0) * 60.0)


func advance(minutes: float) -> void:
	time_min += minutes
	var h := int(hour())
	if h != _last_hour:
		_last_hour = h
		Events.time_hour.emit(day(), h)


func hour() -> float:
	return fmod(time_min, 1440.0) / 60.0


func day() -> int:
	return int(time_min / 1440.0) + 1


func clock_text() -> String:
	var m := int(fmod(time_min, 1440.0))
	return "День %d, %02d:%02d" % [day(), m / 60, m % 60]


func is_night() -> bool:
	var h := hour()
	return h < 6.6 or h > 18.6


## Новая игра: начальное состояние.
func new_game() -> void:
	flags = {}
	world = {}
	placed = []
	chalk = []
	journal = []
	notes_read = []
	discovered = []
	map_marks = []
	quests = {}
	trust = {}
	counters = {}
	skills = {}
	for s in SKILLS:
		skills[s] = 0
	known_recipes = []
	for r in ItemDB.recipes:
		if ItemDB.recipes[r].get("known", false):
			known_recipes.append(r)
	map_fog = PackedByteArray()
	map_fog.resize(MAP_FOG_W * MAP_FOG_H)
	time_min = 6.0 * 60.0 + 40.0
	weather = "fog"
	weather_until = time_min + 150.0
	next_hum_at = time_min + 60.0 * 30.0   # первый Гул — через ~30 игровых часов
	hum_active_until = -1.0
	playtime = 0.0
	_last_hour = -1
	quests["postcard"] = {"stage": 0, "done": false}
	journal_add("intro", "Я прошёл через дыру в заборе периметра. Открытка Веры — в кармане. «Ищи под школой». Сосновка — на восток по лесной дороге, через мост.")
	pending_load = {}


func set_flag(key: String, value: Variant = true) -> void:
	if flags.get(key) == value:
		return
	flags[key] = value
	Events.world_flag_changed.emit(key)


func get_flag(key: String) -> bool:
	return bool(flags.get(key, false))


func add_counter(key: String, n: int = 1) -> int:
	counters[key] = int(counters.get(key, 0)) + n
	Events.world_flag_changed.emit("count:" + key)
	return counters[key]


func journal_add(id: String, text: String) -> void:
	for e in journal:
		if e.id == id:
			return
	journal.append({"id": id, "text": text, "time": clock_text()})
	Events.journal_added.emit(id)
	if id != "intro":
		Events.notify.emit("Журнал обновлён", "lore")


func learn_recipe(id: String) -> void:
	if id in known_recipes or not ItemDB.recipes.has(id):
		return
	known_recipes.append(id)
	var out: Array = ItemDB.recipes[id].out
	Events.notify.emit("Новый рецепт: %s" % ItemDB.item_name(out[0]), "good")


func add_trust(npc: String, n: int) -> void:
	trust[npc] = clampi(int(trust.get(npc, 0)) + n, -100, 100)


func get_trust(npc: String) -> int:
	return int(trust.get(npc, 0))


func skill_level(s: String) -> int:
	var xp := int(skills.get(s, 0))
	var lvl := 0
	for i in SKILL_LEVELS.size():
		if xp >= SKILL_LEVELS[i]:
			lvl = i
	return lvl


func add_skill_xp(s: String, xp: int) -> void:
	var before := skill_level(s)
	skills[s] = int(skills.get(s, 0)) + xp
	var after := skill_level(s)
	if after > before:
		Events.skill_level_up.emit(s, after)
		Events.notify.emit("Навык «%s» — уровень %d" % [SKILLS[s], after], "good")
		if s == "survival" and after >= 2:
			learn_recipe("spear")
		if s == "craft" and after >= 2:
			learn_recipe("crate_big")
		if s == "craft" and after >= 3:
			learn_recipe("jacket_patch")


func discover(loc_id: String) -> void:
	if loc_id in discovered:
		return
	discovered.append(loc_id)
	Events.location_discovered.emit(loc_id)


func reveal_map(world_pos: Vector3, radius_m: float) -> void:
	var reg := ItemDB.region
	if reg.is_empty() or map_fog.size() != MAP_FOG_W * MAP_FOG_H:
		return
	var ox: float = reg.origin[0]
	var oz: float = reg.origin[1]
	var sx: float = reg.size[0]
	var sz: float = reg.size[1]
	var cx := (world_pos.x - ox) / sx * MAP_FOG_W
	var cz := (world_pos.z - oz) / sz * MAP_FOG_H
	var r := radius_m / sx * MAP_FOG_W
	for y in range(int(cz - r) - 1, int(cz + r) + 2):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			if x < 0 or y < 0 or x >= MAP_FOG_W or y >= MAP_FOG_H:
				continue
			if Vector2(x + 0.5 - cx, y + 0.5 - cz).length() <= r:
				map_fog[y * MAP_FOG_W + x] = 1


func is_hum_active() -> bool:
	return time_min < hum_active_until


# ---------------------------------------------------------------- сериализация
func to_dict() -> Dictionary:
	return {
		"time_min": time_min, "weather": weather, "weather_until": weather_until,
		"next_hum_at": next_hum_at, "hum_active_until": hum_active_until,
		"flags": flags, "world": world, "placed": placed, "chalk": chalk,
		"journal": journal, "notes_read": notes_read, "known_recipes": known_recipes,
		"discovered": discovered, "map_fog": Marshalls.raw_to_base64(map_fog), "map_marks": map_marks,
		"quests": quests, "trust": trust, "skills": skills, "counters": counters, "playtime": playtime,
	}


func from_dict(d: Dictionary) -> void:
	time_min = float(d.get("time_min", 400.0))
	weather = str(d.get("weather", "clear"))
	weather_until = float(d.get("weather_until", time_min + 120.0))
	next_hum_at = float(d.get("next_hum_at", time_min + 1500.0))
	hum_active_until = float(d.get("hum_active_until", -1.0))
	flags = d.get("flags", {})
	world = d.get("world", {})
	placed = d.get("placed", [])
	chalk = d.get("chalk", [])
	journal = d.get("journal", [])
	notes_read = d.get("notes_read", [])
	known_recipes = d.get("known_recipes", [])
	discovered = d.get("discovered", [])
	map_fog = Marshalls.base64_to_raw(str(d.get("map_fog", "")))
	if map_fog.size() != MAP_FOG_W * MAP_FOG_H:
		map_fog = PackedByteArray()
		map_fog.resize(MAP_FOG_W * MAP_FOG_H)
	map_marks = d.get("map_marks", [])
	quests = d.get("quests", {})
	trust = d.get("trust", {})
	skills = d.get("skills", {})
	for s in SKILLS:
		if not skills.has(s):
			skills[s] = 0
	counters = d.get("counters", {})
	playtime = float(d.get("playtime", 0.0))
	_last_hour = -1
