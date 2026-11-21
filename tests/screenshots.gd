extends Node
## Рендер контрольных скриншотов (для разработки). Запуск с дисплеем:
## xvfb-run godot --path . res://tests/screenshots.tscn -- out=/tmp/shots
var out := "user://shots"
var world: World
var ui: GameUI

const SHOTS := [
	# имя, позиция, yaw(град), pitch, час, погода, свет
	["01_perimeter", Vector3(-632, 0, 40), -90.0, 0.0, 7.2, "fog", false],
	["02_street", Vector3(-185, 0, 2), -88.0, -2.0, 11.0, "clear", false],
	["03_vera_house", Vector3(80, 0, 40), 10.0, 3.0, 14.5, "overcast", false],
	["04_tikhon_inside", Vector3(-148.5, 0.5, -23.0), 120.0, -8.0, 16.5, "overcast", false],
	["05_school", Vector3(58, 0, -64), -120.0, 4.0, 12.0, "clear", false],
	["06_forest", Vector3(-420, 0, -120), -40.0, 2.0, 12.5, "overcast", false],
	["07_station", Vector3(590, 0, 82), -60.0, 2.0, 17.6, "rain", false],
	["08_night", Vector3(-30, 0, 10), -80.0, -4.0, 22.5, "clear", true],
	["09_garages", Vector3(30, 0, -60), 150.0, 0.0, 9.5, "fog", false],
]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	Settings.control_mode = "touch"
	Settings.apply_preset(1)
	GameState.new_game()
	world = World.new()
	add_child(world)
	world.build(true)
	ui = GameUI.new()
	add_child(ui)
	GameState.running = false
	var p = GameState.player
	for s in SHOTS:
		var pos: Vector3 = s[1]
		if s[0] != "04_tikhon_inside":
			pos.y = RegionData.height_at(pos.x, pos.z) + 0.1
		else:
			pos.y = RegionData.height_at(-150, -26) + 0.6
		p.global_position = pos
		p.set_look(deg_to_rad(s[2]), deg_to_rad(s[3]))
		GameState.time_min = 1440.0 + s[4] * 60.0
		world.sky.force_weather(s[5])
		p.flashlight_on = s[6]
		if s[6]:
			p.inventory.add("flashlight", 1, {"charge": 100.0})
		world.terrain.build_around(pos)
		for i in 40:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(out + "/" + s[0] + ".png")
		print("shot ", s[0])
	# интерфейс
	p.global_position = Vector3(-185, RegionData.height_at(-185, 2) + 0.1, 2)
	GameState.time_min = 1440.0 + 11.0 * 60.0
	Events.open_screen.emit("inventory", null)
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "/10_inventory.png")
	Events.close_screens.emit()
	Events.open_screen.emit("map", null)
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "/11_map.png")
	Events.close_screens.emit()
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "/12_hud_touch.png")
	get_tree().quit()
