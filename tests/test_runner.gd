extends Node
## Автотесты ZERO ZONE (headless). Запуск: godot --headless --path . res://tests/test_runner.tscn
## Проверяют реальные системы: компиляцию, инвентарь, крафт, мир, взаимодействие, сохранения, задания.

var passed := 0
var failed := 0
var _fails: Array = []


func ok(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  ✓ ", name)
	else:
		failed += 1
		_fails.append(name)
		print("  ✗ FAIL: ", name)


func _ready() -> void:
	await get_tree().process_frame
	print("=== ZERO ZONE tests ===")
	test_scripts()
	test_inventory()
	test_crafting()
	await test_world_and_save()
	await test_ui_and_gameplay()
	await test_app_flow()
	print("=== RESULT: %d passed, %d failed ===" % [passed, failed])
	for f in _fails:
		print("FAILED: ", f)
	get_tree().quit(1 if failed > 0 else 0)


func test_scripts() -> void:
	print("[scripts]")
	var files: Array = []
	_collect("res://scripts", files)
	_collect("res://autoload", files)
	var bad := 0
	for f in files:
		var s = load(f)
		if s == null:
			bad += 1
			print("    cannot load ", f)
	ok(bad == 0, "все %d скриптов компилируются" % files.size())
	for j in ["items", "recipes", "loot", "notes", "quests", "dialogues", "radio", "world", "region"]:
		ok(ItemDB.load_json("res://data/%s.json" % j).size() > 0, "data/%s.json читается" % j)
	# целостность данных: рецепты и добыча ссылаются на существующие предметы
	var missing: Array = []
	for r in ItemDB.recipes.values():
		for id in r.get("in", {}):
			if not ItemDB.exists(id):
				missing.append(id)
		if not ItemDB.exists(str(r.out[0])):
			missing.append(r.out[0])
	for t in ItemDB.loot.values():
		for e in t.entries:
			if not ItemDB.exists(str(e[0])):
				missing.append(e[0])
	for it in ItemDB.items.values():
		if it.has("note") and not ItemDB.notes.has(str(it.note)):
			missing.append("note:" + str(it.note))
	ok(missing.is_empty(), "ссылки на предметы/записки корректны %s" % str(missing))


func _collect(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + d, out)


func test_inventory() -> void:
	print("[inventory]")
	var inv := Inventory.new(6, 10.0)
	ok(inv.add("crackers", 13) == 0, "добавление стака сверх размера стака")
	ok(inv.count("crackers") == 13, "подсчёт предметов")
	ok(inv.slots[0].n == 10 and inv.slots[1].n == 3, "разбиение на стаки по 10")
	ok(inv.remove("crackers", 4) and inv.count("crackers") == 9, "удаление")
	inv.add("wood_log", 30)
	ok(inv.total_weight() <= 10.0 + 25.0 + 0.01, "ограничение веса с допуском перегруза")
	var other := Inventory.new(4)
	var moved := inv.transfer_to(0, other)
	ok(moved > 0 and other.count("crackers") == moved, "перенос в контейнер")
	inv.move(1, 5)
	ok(inv.slots[1] == null or inv.slots[5] != null, "перемещение ячеек")
	var arr := inv.to_array()
	var inv2 := Inventory.new(6, 10.0)
	inv2.from_array(arr)
	ok(inv2.count("wood_log") == inv.count("wood_log"), "сериализация инвентаря")


func test_crafting() -> void:
	print("[crafting]")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var loot := ItemDB.roll_loot("kitchen", rng)
	ok(loot is Array, "бросок таблицы добычи")
	var r: Dictionary = ItemDB.recipes.get("rag_bandage", {})
	ok(not r.is_empty() and r.get("known", false), "рецепт «Самодельная повязка» известен")


func test_world_and_save() -> void:
	print("[world]")
	GameState.new_game()
	var world := World.new()
	add_child(world)
	world.build(true)
	await get_tree().process_frame
	var p = GameState.player
	ok(p != null, "игрок создан")
	ok(p.inventory.has("doc_postcard") and p.inventory.has("tuning_fork"), "стартовый набор выдан")
	ok(get_tree().get_nodes_in_group("npc").size() >= 3, "NPC созданы (Тихон и Шакалы)")
	var containers := _find(world, LootContainer)
	ok(containers.size() > 60, "контейнеров с добычей в мире: %d" % containers.size())
	var doors := _find(world, Door)
	ok(doors.size() > 40, "дверей в мире: %d" % doors.size())
	ok(world.terrain.chunks.size() > 10, "чанки рельефа построены: %d" % world.terrain.chunks.size())
	var h := RegionData.height_at(0, 0)
	ok(absf(h) < 15.0, "высота рельефа в центре посёлка разумна (%.2f)" % h)

	# --- выживание
	var s: Survival = p.survival
	var hunger0 := s.hunger
	s.tick(0.0, 60.0, {"air_temp": 5.0, "insulation": 0.6})
	ok(s.hunger < hunger0 and s.hunger > hunger0 - 3.0, "голод падает ~1.25/ч (%.2f → %.2f)" % [hunger0, s.hunger])
	s.apply_use(ItemDB.item("canned_meat").use)
	ok(s.hunger > hunger0, "еда восстанавливает сытость")

	# --- взаимодействие с контейнером
	var c: LootContainer = null
	for x in containers:
		if x.container_id == "vera/doormat":
			c = x
	ok(c != null, "коврик у дома Веры существует")
	if c:
		var inv := c.ensure_inventory()
		ok(inv.has("key_vera"), "под ковриком — ключ Веры")
		inv.transfer_to(inv.find("key_vera"), p.inventory)
		ok(p.inventory.has("key_vera") and not inv.has("key_vera"), "ключ перенесён в инвентарь")

	# --- крафт из реальных предметов
	p.inventory.add("cloth", 2)
	var before: int = p.inventory.count("rag_bandage")
	ok(Crafting.craft("rag_bandage", p, ""), "крафт повязки из ткани")
	ok(p.inventory.count("rag_bandage") == before + 1 and p.inventory.count("cloth") == 0, "ткань израсходована, повязка получена")

	# --- задания
	GameState.discover("sosnovka")
	await get_tree().process_frame
	ok(int(GameState.quests.postcard.stage) >= 1, "задание продвинулось после прихода в Сосновку")
	GameState.set_flag("read_vera_1")
	await get_tree().process_frame
	ok(int(GameState.quests.postcard.stage) >= 2, "этап «дом Веры» засчитан")

	# --- машина
	var niva: Car = null
	for car in _find(world, Car):
		if car.state == "repairable":
			niva = car
	ok(niva != null and not niva.can_drive(), "«Нива» есть и пока не на ходу")
	if niva:
		niva.parts = {"battery": true, "plugs": true, "wheel": true, "fuel": 10.0}
		ok(niva.can_drive(), "после ремонта «Нива» может ехать")

	# --- размещение (убежище)
	var rec := {"kind": "crate", "item": "storage_crate", "pos": SaveSystem.v3(p.global_position + Vector3(2, 0, 0)), "rot": 0.0, "id": "t1"}
	GameState.placed.append(rec)
	Placement.spawn(rec, world.dynamic_root)

	# --- сохранение / загрузка
	p.global_position = Vector3(10, RegionData.height_at(10, 5) + 1.0, 5)
	p.inventory.add("honey", 1)
	GameState.world["c:test"] = [{"id": "nails", "n": 3, "d": {}}]
	ok(SaveSystem.save_game("5"), "сохранение в слот 5")
	var meta := SaveSystem.slot_meta("5")
	ok(meta.has("clock") and meta.has("location"), "метаданные слота")
	world.queue_free()
	GameState.player = null
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.new_game()
	ok(SaveSystem.prepare_load("5"), "загрузка: подготовка")
	var world2 := World.new()
	add_child(world2)
	world2.build(false)
	await get_tree().process_frame
	var p2 = GameState.player
	ok(p2 != world and p2.global_position.distance_to(Vector3(10, 0, 5) * Vector3(1, 0, 1) + Vector3(0, p2.global_position.y, 0)) < 0.5, "позиция игрока восстановлена")
	ok(p2.inventory.has("honey") and p2.inventory.has("key_vera"), "инвентарь восстановлен")
	ok(GameState.get_flag("read_vera_1"), "флаги мира восстановлены")
	ok(GameState.world.has("c:test"), "состояние контейнеров восстановлено")
	ok(GameState.placed.size() == 1, "размещённые объекты восстановлены")
	var inv_v: LootContainer = null
	for x in _find(world2, LootContainer):
		if x.container_id == "vera/doormat":
			inv_v = x
	ok(inv_v != null and not inv_v.ensure_inventory().has("key_vera"), "коврик остался пустым после загрузки")
	SaveSystem.delete_slot("5")
	# прогон нескольких кадров игрового цикла
	GameState.running = true
	InputRouter.set_gameplay_active(true)
	for i in 30:
		await get_tree().physics_frame
	ok(not p2.dead, "игрок жив после симуляции кадров")
	GameState.running = false
	world2.queue_free()
	await get_tree().process_frame


func _find(n: Node, cls) -> Array:
	var out: Array = []
	var stack: Array = [n]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if is_instance_of(x, cls):
			out.append(x)
		stack.append_array(x.get_children())
	return out


func test_ui_and_gameplay() -> void:
	print("[ui & gameplay]")
	GameState.new_game()
	var world := World.new()
	add_child(world)
	world.build(true)
	var ui := GameUI.new()
	add_child(ui)
	GameState.running = true
	InputRouter.set_gameplay_active(true)
	await get_tree().process_frame
	var p = GameState.player
	p.inventory.add("radio", 1)
	var niva: Car = null
	for car in _find(world, Car):
		if car.state == "repairable":
			niva = car
	var tikhon: NPC = null
	for n in get_tree().get_nodes_in_group("npc"):
		if n.npc_id == "tikhon":
			tikhon = n
	var cont: LootContainer = _find(world, LootContainer)[5]
	var screens := [["inventory", null], ["crafting", "fire"], ["container", cont], ["journal", null], ["map", null],
		["dialogue", tikhon], ["note", {"note": "postcard", "item": "doc_postcard"}], ["radio", null],
		["sleep", {"quality": 1.0, "title": "Кровать"}], ["hide", {"title": "Подпол"}],
		["chalk", {"pos": p.global_position, "normal": Vector3.FORWARD}], ["car", niva], ["pause", null]]
	for sc in screens:
		Events.open_screen.emit(sc[0], sc[1])
		await get_tree().process_frame
		await get_tree().process_frame
		ok(ui.screen != null and ui.screen_name == sc[0], "экран «%s» открывается" % sc[0])
		Events.close_screens.emit()
		await get_tree().process_frame
	ok(not get_tree().paused, "после закрытия экранов игра не на паузе")

	# --- диалог: прогон всех узлов Тихона
	Events.open_screen.emit("dialogue", tikhon)
	await get_tree().process_frame
	var dlg = ui.screen
	for node_id in ItemDB.dialogues.tikhon.nodes:
		if node_id in ["end", "trade"]:
			continue
		dlg.show_node(node_id)
		for o in ItemDB.dialogues.tikhon.nodes[node_id].get("options", []):
			if not o.get("do", []).is_empty() and not str(o.do).contains("take:"):
				Conditions.run_all(o.do)
	ok(GameState.get_flag("met_tikhon"), "диалог ставит флаги (знакомство с Тихоном)")
	ok("earplugs" in GameState.known_recipes, "диалог открывает рецепты (беруши)")
	dlg.show_node("trade")
	p.inventory.add("canned_meat", 3)
	dlg._trade_give = {"canned_meat": 3}
	dlg._trade_take = {"potato": 2}
	var pot0: int = p.count_item("potato")
	dlg._do_trade()
	ok(p.count_item("potato") == pot0 + 2, "обмен с Тихоном работает")
	Events.close_screens.emit()
	await get_tree().process_frame

	# --- ходьба (сенсорный джойстик)
	var start: Vector3 = p.global_position
	InputRouter.touch_move = Vector2(0, -1)
	for i in 150:
		await get_tree().physics_frame
	InputRouter.touch_move = Vector2.ZERO
	var moved: float = Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
	ok(moved > 2.5, "игрок идёт вперёд от джойстика (%.1f м)" % moved)
	ok(p.global_position.y > RegionData.height_at(p.global_position.x, p.global_position.z) - 1.0, "игрок не провалился под землю")

	# --- двери
	var door: Door = _find(world, Door)[3]
	var was: bool = door.open
	if door.locked:
		door.locked = false
	door.use(p)
	ok(door.open != was, "дверь открывается/закрывается")

	# --- записка открывает рецепт и журнал
	p.read_note("diy")
	ok("workbench" in GameState.known_recipes, "записка «Сделай сам» открыла рецепт верстака")
	ok(GameState.notes_read.has("diy"), "записка в журнале")
	Events.close_screens.emit()

	# --- Гул: снаружи дезориентация растёт
	GameState.next_hum_at = GameState.time_min + 1.0
	for i in 5:
		await get_tree().process_frame
	GameState.advance(3.0)
	for i in 5:
		await get_tree().process_frame
	ok(GameState.is_hum_active(), "Гул начинается по расписанию")
	var hx0: float = p.survival.hum_exposure
	p.survival.tick(0.1, 10.0, {"hum_active": true, "hum_protect": p.hum_protection(), "air_temp": 5.0})
	ok(p.survival.hum_exposure > hx0, "Гул снаружи вызывает дезориентацию")
	p.survival.hum_exposure = 0.0
	GameState.hum_active_until = GameState.time_min - 1.0
	for i in 3:
		await get_tree().process_frame

	# --- сон
	var t0 := GameState.time_min
	var sl := SmallScreens.SleepScreen.new()
	sl.quality = 1.0
	add_child(sl)
	GameState.next_hum_at = GameState.time_min + 5000.0
	sl._sleep(2)
	ok(GameState.time_min - t0 >= 110.0, "сон проматывает время (%.0f мин)" % (GameState.time_min - t0))
	sl.queue_free()
	await get_tree().process_frame

	# --- размещение костра и огонь для готовки
	p.inventory.add("campfire_kit", 1)
	world.placement.begin("campfire_kit")
	await get_tree().process_frame
	world.placement._valid = true
	world.placement._pos = p.global_position + Vector3(2, 0, 0)
	var placed0 := GameState.placed.size()
	world.placement.confirm()
	ok(GameState.placed.size() == placed0 + 1, "костёр поставлен и сохранён в убежище")
	var fire: MiscInteract.HeatSource = null
	for h in get_tree().get_nodes_in_group("heat_source"):
		if str(h.source_id).begins_with("placed/"):
			fire = h
	ok(fire != null, "костёр создан в мире")
	if fire:
		p.inventory.add("wood_log", 1)
		p.inventory.add("water_dirty", 1)
		fire.interact(p)
		ok(fire.lit, "костёр разжигается спичками и поленом")
		Events.close_screens.emit()
		ok(Crafting.craft("water_clean", p, "fire"), "кипячение воды на огне")
	await get_tree().process_frame

	# --- машина: ремонт и езда
	if niva:
		niva.parts = {"battery": true, "plugs": true, "wheel": true, "fuel": 10.0}
		p.global_position = niva.global_position + Vector3(-2.5, 0.5, 0)
		world.terrain.build_around(niva.global_position)
		for i in 5:
			await get_tree().physics_frame
		niva.enter(p)
		InputRouter.set_gameplay_active(true)
		for i in 3:
			await get_tree().process_frame
		InputRouter.touch_move = Vector2(0, -1)
		for i in 120:
			await get_tree().physics_frame
		InputRouter.touch_move = Vector2.ZERO
		ok(niva.speed_kmh() > 8.0, "«Нива» едет (%.1f км/ч)" % niva.speed_kmh())
		niva.exit_car()
		ok(p.in_vehicle == null and p.visible, "выход из машины")
		ok(GameState.get_flag("niva_driven"), "задание «Нива» отмечает поездку")

	# --- радио: Марта вечером на 101.3
	GameState.time_min = floor(GameState.time_min / 1440.0) * 1440.0 + 21.0 * 60.0
	var radio := SmallScreens.RadioScreen.new()
	add_child(radio)
	radio.freq = 101.3
	radio._on_tune()
	ok(GameState.get_flag("radio_marta_heard"), "радио: Марта в эфире вечером на 101.3")
	radio.queue_free()

	# --- смерть и экран смерти
	p.survival.health = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	ok(p.dead and ui.screen_name == "death", "смерть показывает экран «Глеб погиб»")
	GameState.running = false
	ui.queue_free()
	world.queue_free()
	await get_tree().process_frame


func test_app_flow() -> void:
	print("[app flow]")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 3:
		await get_tree().process_frame
	ok(main.menu != null, "главное меню показывается")
	main.start_game(true)
	for i in 12:
		await get_tree().process_frame
	ok(main.world != null and GameState.player != null and GameState.running, "новая игра из меню запускается")
	ok(SaveSystem.save_game("4"), "сохранение из игры")
	main.ui.to_main_menu.emit()
	for i in 4:
		await get_tree().process_frame
	ok(main.world == null and main.menu != null and GameState.player == null, "выход в главное меню освобождает мир")
	main.load_game("4")
	for i in 12:
		await get_tree().process_frame
	ok(main.world != null and GameState.player != null, "загрузка сохранения из меню")
	main.end_game()
	SaveSystem.delete_slot("4")
	main.queue_free()
	await get_tree().process_frame
