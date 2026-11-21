class_name TreeBody
extends StaticBody3D
## Коллизия дерева рядом с игроком. Рубится топором; сухостой даёт хворост руками.

var tree: Dictionary
var streamer: Node
var _hits := 0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	set_meta("surface", "wood")


func _hits_needed() -> int:
	var base := {"pine": 5, "birch": 4, "dead": 3}.get(tree.kind, 4)
	return maxi(2, base - GameState.skill_level("survival"))


func get_prompt(player: Node) -> String:
	var kind_name: String = {"pine": "Ель", "birch": "Берёза", "dead": "Сухостой", "apple": "Дикая яблоня"}.get(tree.kind, "Дерево")
	if player.has_tool("axe"):
		return "%s — рубить (%d/%d)" % [kind_name, _hits, _hits_needed()]
	if tree.kind == "dead" and not GameState.world.has(tree.id + ":sticks"):
		return "Сухостой — наломать хвороста"
	return kind_name


func interact(player: Node) -> void:
	if player.has_tool("axe"):
		chop(player)
	elif tree.kind == "dead" and not GameState.world.has(tree.id + ":sticks"):
		GameState.world[tree.id + ":sticks"] = true
		AudioLib.play_3d("chop", global_position + Vector3.UP, -8.0, 1.6)
		player.give("sticks", 3)
	else:
		Events.notify.emit("Нужен топор", "warn")


func chop(player: Node) -> void:
	_hits += 1
	AudioLib.play_3d("chop", global_position + Vector3.UP * 1.2, 0.0, randf_range(0.9, 1.1), 70.0)
	Events.noise_emitted.emit(global_position, 18.0, player)
	player.survival.stamina = maxf(0.0, player.survival.stamina - 6.0)
	if _hits >= _hits_needed():
		AudioLib.play_3d("door_close", global_position, 4.0, 0.5, 80.0)
		streamer.fell_tree(tree)
		var logs := 3 if tree.kind == "pine" else (2 if tree.kind == "birch" else 2)
		player.give("wood_log", logs)
		player.give("sticks", 2)
		GameState.add_skill_xp("survival", 8)
		queue_free()
