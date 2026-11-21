class_name ForageSpot
extends Interactable
## Лесные находки: грибы, брусника, хворост. Отрастают через 3 игровых дня.

const REGROW_MIN := 3 * 1440.0

var kind := "mushrooms"
var spot_id := ""
var _visual: Node3D


func _ready() -> void:
	setup_box(Vector3(0.8, 0.5, 0.8), Vector3(0, 0.25, 0), false)
	_visual = Node3D.new()
	add_child(_visual)
	_build_visual()
	_update_visible()


func _available() -> bool:
	var t = GameState.world.get(spot_id)
	return t == null or GameState.time_min - float(t) > REGROW_MIN


func _update_visible() -> void:
	_visual.visible = _available()
	collision_layer = 4 if _available() else 0


func _build_visual() -> void:
	var kit := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(spot_id)
	match kind:
		"mushrooms":
			for i in 5:
				var p := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
				kit.add_cylinder(Mats.get_mat("mattress"), p, 0.09, 0.018, 0.015, 5)
				kit.add_cylinder(Mats.get_mat("wood_light"), p + Vector3(0, 0.08, 0), 0.04, 0.06, 0.01, 6)
		"berries":
			for i in 3:
				var p2 := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
				kit.add_cylinder(Mats.get_mat("pine_foliage2"), p2, 0.25, 0.18, 0.05, 6)
			for i in 10:
				var b := Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.1, 0.25), rng.randf_range(-0.35, 0.35))
				kit.add_box(Mats.get_mat("sign_red"), Transform3D(Basis(), b), Vector3(0.035, 0.035, 0.035))
		_:
			for i in 6:
				var a := rng.randf() * TAU
				var xf := Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(rng.randf_range(-0.3, 0.3), 0.04 + i * 0.015, rng.randf_range(-0.3, 0.3)))
				kit.add_box(Mats.get_mat("bark"), xf, Vector3(0.035, 0.7, 0.035))
	_visual.add_child(kit.build_instance("Forage", false))


func get_prompt(_player: Node) -> String:
	if not _available():
		return ""
	return {"mushrooms": "Собрать грибы", "berries": "Собрать бруснику", "sticks": "Собрать хворост"}.get(kind, "Собрать")


func interact(player: Node) -> void:
	if not _available():
		return
	GameState.world[spot_id] = GameState.time_min
	AudioLib.play_3d("rummage", global_position, -8.0)
	var bonus := GameState.skill_level("survival")
	match kind:
		"mushrooms":
			player.give("mushrooms_raw", randi_range(2, 4) + bonus)
		"berries":
			player.give("berries", randi_range(3, 6) + bonus)
		_:
			player.give("sticks", randi_range(3, 5))
	GameState.add_skill_xp("survival", 3)
	_update_visible()
