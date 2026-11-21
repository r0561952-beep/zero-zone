extends Node
## База контента: предметы, рецепты, добыча, записки, задания, диалоги, радио, описание мира.
## Всё читается из data/*.json — правка контента не требует изменения кода.

const CATEGORY_ORDER := ["food", "water", "medical", "tool", "material", "clothing", "key", "document", "quest"]
const CATEGORY_NAMES := {
	"all": "Всё", "food": "Еда", "water": "Вода", "medical": "Медицина", "tool": "Инструменты",
	"material": "Материалы", "clothing": "Одежда", "key": "Ключи", "document": "Документы", "quest": "Сюжетное",
}
const CATEGORY_COLORS := {
	"food": Color(0.62, 0.45, 0.22), "water": Color(0.25, 0.45, 0.6), "medical": Color(0.65, 0.2, 0.2),
	"tool": Color(0.42, 0.42, 0.45), "material": Color(0.45, 0.36, 0.26), "clothing": Color(0.3, 0.4, 0.3),
	"key": Color(0.7, 0.6, 0.25), "document": Color(0.7, 0.66, 0.55), "quest": Color(0.55, 0.35, 0.6),
}
const EQUIP_SLOTS := ["head", "torso", "inner", "hands", "legs", "feet"]
const EQUIP_NAMES := {"hand": "В руке", "head": "Голова", "torso": "Верхняя одежда", "inner": "Под куртку", "hands": "Руки", "legs": "Ноги", "feet": "Обувь"}

var items: Dictionary = {}
var recipes: Dictionary = {}
var loot: Dictionary = {}
var notes: Dictionary = {}
var quests: Dictionary = {}
var dialogues: Dictionary = {}
var radio: Dictionary = {}
var world: Dictionary = {}
var region: Dictionary = {}


func _ready() -> void:
	items = load_json("res://data/items.json")
	recipes = load_json("res://data/recipes.json")
	loot = load_json("res://data/loot.json")
	notes = load_json("res://data/notes.json")
	quests = load_json("res://data/quests.json")
	dialogues = load_json("res://data/dialogues.json")
	radio = load_json("res://data/radio.json")
	world = load_json("res://data/world.json")
	region = load_json("res://data/region.json")


static func load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ItemDB: не удалось открыть %s" % path)
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		push_error("ItemDB: ошибка JSON в %s" % path)
		return {}
	d.erase("_comment")
	return d


func item(id: String) -> Dictionary:
	return items.get(id, {})


func exists(id: String) -> bool:
	return items.has(id)


func item_name(id: String) -> String:
	return str(items.get(id, {}).get("name", id))


func weight(id: String) -> float:
	return float(items.get(id, {}).get("weight", 0.1))


func stack_size(id: String) -> int:
	return int(items.get(id, {}).get("stack", 1))


func category(id: String) -> String:
	return str(items.get(id, {}).get("cat", "material"))


func value(id: String) -> int:
	return int(items.get(id, {}).get("value", 1))


func has_tag(id: String, tag: String) -> bool:
	return tag in items.get(id, {}).get("tags", [])


func equip_slot(id: String) -> String:
	return str(items.get(id, {}).get("equip", ""))


## Возвращает список [[id, count], ...] по таблице добычи.
func roll_loot(table: String, rng: RandomNumberGenerator, bonus_rolls: int = 0) -> Array:
	var t: Dictionary = loot.get(table, {})
	var out: Array = []
	if t.is_empty():
		return out
	if rng.randf() < float(t.get("empty", 0.0)):
		return out
	var rolls: Array = t.get("rolls", [1, 1])
	var n := rng.randi_range(int(rolls[0]), int(rolls[1])) + bonus_rolls
	var entries: Array = t.get("entries", [])
	var total := 0.0
	for e in entries:
		total += float(e[1])
	for i in n:
		var r := rng.randf() * total
		for e in entries:
			r -= float(e[1])
			if r <= 0.0:
				out.append([str(e[0]), rng.randi_range(int(e[2]), int(e[3]))])
				break
	return out
