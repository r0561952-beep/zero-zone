class_name Conditions
extends RefCounted
## Условия и действия для диалогов и заданий (строки из JSON).
## Условия: flag:x, !flag:x, item:id[:n], !item:id, loc:id, trust:npc:n, !trust:npc:n,
##          quest:q (активно), !quest:q, quest:q:N (текущий этап N), count:key:n
## Действия: flag:x, trust:npc:n, give:id:n, give_once:id:n:flag, take:id:n, recipe:id,
##          quest_start:q, skill:s:xp


static func check_all(conds: Array) -> bool:
	for c in conds:
		if not check(str(c)):
			return false
	return true


static func check(c: String) -> bool:
	var neg := c.begins_with("!")
	if neg:
		c = c.substr(1)
	var p := c.split(":")
	var r := false
	var player = GameState.player
	match p[0]:
		"flag":
			r = GameState.get_flag(p[1])
		"item":
			var n := int(p[2]) if p.size() > 2 else 1
			r = player != null and player.count_item(p[1]) >= n
		"loc":
			r = p[1] in GameState.discovered
		"trust":
			r = GameState.get_trust(p[1]) >= int(p[2])
		"quest":
			var q: Dictionary = GameState.quests.get(p[1], {})
			if p.size() > 2:
				r = not q.is_empty() and not q.get("done", false) and int(q.get("stage", 0)) == int(p[2])
			else:
				r = not q.is_empty()
		"count":
			r = int(GameState.counters.get(p[1], 0)) >= int(p[2])
	return not r if neg else r


static func run_all(actions: Array) -> void:
	for a in actions:
		run(str(a))


static func run(a: String) -> void:
	var p := a.split(":")
	var player = GameState.player
	match p[0]:
		"flag":
			GameState.set_flag(p[1])
		"trust":
			GameState.add_trust(p[1], int(p[2]))
		"give":
			if player:
				player.give(p[1], int(p[2]))
		"give_once":
			if not GameState.get_flag(p[3]) and player:
				GameState.set_flag(p[3])
				player.give(p[1], int(p[2]))
		"take":
			if player:
				player.inventory.remove(p[1], int(p[2]))
				Events.notify.emit("−%s ×%s" % [ItemDB.item_name(p[1]), p[2]], "info")
		"recipe":
			GameState.learn_recipe(p[1])
		"quest_start":
			QuestSystem.start(p[1])
		"skill":
			GameState.add_skill_xp(p[1], int(p[2]))
