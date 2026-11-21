class_name Crafting
extends RefCounted
## Крафт из реальных предметов инвентаря. Станции: руки, верстак, огонь (костёр/печь).


static func station_available(station: String, player: Node, context: String) -> bool:
	match station:
		"hand":
			return true
		"fire":
			return context == "fire" or player.near_fire
		"workbench":
			if context == "workbench":
				return true
			for n in player.get_tree().get_nodes_in_group("workbench"):
				if (n as Node3D).global_position.distance_to(player.global_position) < 3.0:
					return true
			return false
	return false


static func station_name(s: String) -> String:
	return {"hand": "руками", "fire": "на огне", "workbench": "на верстаке"}.get(s, s)


## [можно?, причина]
static func check(rid: String, player: Node, context: String) -> Array:
	var r: Dictionary = ItemDB.recipes.get(rid, {})
	if r.is_empty():
		return [false, "нет рецепта"]
	for id in r.get("in", {}):
		if player.count_item(id) < int(r["in"][id]):
			return [false, "не хватает: %s" % ItemDB.item_name(id)]
	for t in r.get("tools", []):
		if not player.has_tool(str(t)):
			return [false, "нужен инструмент: %s" % _tool_name(str(t))]
	if not station_available(str(r.get("station", "hand")), player, context):
		return [false, "нужно %s" % station_name(str(r.station))]
	return [true, ""]


static func _tool_name(tag: String) -> String:
	return {"axe": "топор", "saw": "ножовка", "hammer": "молоток", "knife": "нож", "wrench": "ключ", "fire": "огонь"}.get(tag, tag)


static func craft(rid: String, player: Node, context: String) -> bool:
	var c := check(rid, player, context)
	if not c[0]:
		Events.notify.emit("Нельзя: %s" % c[1], "warn")
		return false
	var r: Dictionary = ItemDB.recipes[rid]
	for id in r.get("in", {}):
		player.inventory.remove(id, int(r["in"][id]))
	var out: Array = r.out
	var bonus := 0
	if GameState.skill_level("craft") >= 3 and randf() < 0.25 and int(out[1]) > 1:
		bonus = 1
	player.give(str(out[0]), int(out[1]) + bonus)
	var minutes := float(r.get("time", 3)) * maxf(0.4, 1.0 - GameState.skill_level("craft") * 0.15)
	GameState.advance(minutes)
	GameState.add_skill_xp("craft", 4 + int(r.get("time", 3)))
	AudioLib.play_2d("chop" if r.get("station", "hand") != "fire" else "fire_loop", -10.0, 1.3)
	Events.item_crafted.emit(str(out[0]), int(out[1]))
	return true
