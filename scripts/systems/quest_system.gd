class_name QuestSystem
extends Node
## Задания: этапы продвигаются автоматически, когда выполняется условие (флаг, предмет, локация…).
## Некоторые задания начинаются сами при чтении записок (know_niva, know_chalk).

const AUTO_START := {"know_niva": "niva", "know_chalk": "chalk"}


func _ready() -> void:
	Events.world_flag_changed.connect(func(k):
		if AUTO_START.has(k):
			start(AUTO_START[k])
		_check())
	Events.inventory_changed.connect(_check)
	Events.location_discovered.connect(func(_l): _check())
	Events.game_loaded.connect(_check)


static func start(id: String) -> void:
	if GameState.quests.has(id) or not ItemDB.quests.has(id):
		return
	GameState.quests[id] = {"stage": 0, "done": false}
	Events.notify.emit("Новое задание: %s" % ItemDB.quests[id].title, "good")
	Events.quest_updated.emit(id)


func _check() -> void:
	var changed := true
	var guard := 0
	while changed and guard < 10:
		changed = false
		guard += 1
		for id in GameState.quests.keys():
			var q: Dictionary = GameState.quests[id]
			if q.get("done", false):
				continue
			var def: Dictionary = ItemDB.quests.get(id, {})
			var stages: Array = def.get("stages", [])
			var st := int(q.get("stage", 0))
			if st >= stages.size():
				continue
			if Conditions.check_all(stages[st].get("cond", [])):
				st += 1
				q.stage = st
				changed = true
				if st >= stages.size():
					q.done = true
					Events.notify.emit("Задание выполнено: %s" % def.title, "good")
					if def.has("done_text"):
						GameState.journal_add("quest_done_" + id, str(def.done_text))
					AudioLib.play_2d("theme_discovery", -8.0, 1.0, "Music")
				else:
					Events.notify.emit("%s: %s" % [def.title, stages[st].text], "info")
				Events.quest_updated.emit(id)


## Текст текущего этапа главного задания (для HUD).
static func current_objective() -> String:
	for id in ["postcard"] + GameState.quests.keys():
		var q: Dictionary = GameState.quests.get(id, {})
		if q.is_empty() or q.get("done", false):
			continue
		var def: Dictionary = ItemDB.quests.get(id, {})
		var stages: Array = def.get("stages", [])
		var st := int(q.get("stage", 0))
		if st < stages.size():
			return str(stages[st].text)
	return ""
