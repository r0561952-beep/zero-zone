class_name Placement
extends Node3D
## Обустройство убежища: размещение предметов (ящик, спальник, верстак, костёр, бочка, баррикада,
## свеча, лампа). Призрак‑превью перед игроком → «Поставить». Всё сохраняется в GameState.placed.

const KINDS := {
	"crate": {"title": "Ящик для хранения", "size": Vector3(0.8, 0.6, 0.6)},
	"bedroll": {"title": "Спальник", "size": Vector3(0.9, 0.2, 2.0)},
	"workbench": {"title": "Верстак", "size": Vector3(1.6, 0.9, 0.8)},
	"campfire": {"title": "Костёр", "size": Vector3(1.1, 0.4, 1.1)},
	"rain_collector": {"title": "Бочка для дождевой воды", "size": Vector3(0.7, 0.9, 0.7)},
	"barricade": {"title": "Баррикада", "size": Vector3(1.2, 2.0, 0.2)},
	"candle": {"title": "Свеча", "size": Vector3(0.1, 0.15, 0.1)},
	"lamp": {"title": "Керосиновая лампа", "size": Vector3(0.25, 0.8, 0.25)},
}

var active := false
var item_id := ""
var kind := ""
var ghost: Node3D
var _rot := 0.0
var _valid := false
var _pos := Vector3.ZERO


func begin(id: String) -> void:
	var it := ItemDB.item(id)
	if not it.has("place"):
		return
	cancel()
	item_id = id
	kind = str(it.place)
	_rot = 0.0
	ghost = Node3D.new()
	add_child(ghost)
	var vis := build_visual(kind)
	ghost.add_child(vis)
	_ghostify(vis)
	active = true
	InputRouter.set_gameplay_active(true)
	Events.notify.emit("Размещение: %s. [E] — поставить, [Q] — повернуть, [Esc] — отмена" % KINDS[kind].title if Settings.is_pc() else "Размещение: %s" % KINDS[kind].title, "info")
	Events.open_screen.emit("placement", null)


func _ghostify(n: Node) -> void:
	if n is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.6, 0.9, 0.6, 0.45)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		(n as MeshInstance3D).material_override = m
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_ghostify(c)
	if n is CollisionObject3D:
		(n as CollisionObject3D).collision_layer = 0


func _process(_delta: float) -> void:
	if not active or ghost == null:
		return
	var p = GameState.player
	if p == null:
		return
	var cam: Camera3D = p.camera
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 4.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [p.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var pos := to
	var ok := false
	if not hit.is_empty() and (hit.normal as Vector3).y > 0.7:
		pos = hit.position
		ok = true
	else:
		var q2 := PhysicsRayQueryParameters3D.create(to + Vector3.UP, to - Vector3.UP * 3.0, 1)
		var h2 := get_world_3d().direct_space_state.intersect_ray(q2)
		if not h2.is_empty() and (h2.normal as Vector3).y > 0.7:
			pos = h2.position
			ok = true
	if kind == "campfire" and p.is_indoors():
		ok = false
	_valid = ok and pos.distance_to(p.global_position) > 0.6
	_pos = pos
	ghost.global_position = pos
	ghost.rotation.y = p.rotation.y + _rot
	ghost.visible = true
	_set_ghost_color(Color(0.6, 0.9, 0.6, 0.45) if _valid else Color(0.9, 0.4, 0.3, 0.45))
	if Input.is_action_just_pressed("interact") and Settings.is_pc():
		confirm()
	elif Input.is_action_just_pressed("tuning_fork") and Settings.is_pc():
		rotate_ghost()
	elif Input.is_action_just_pressed("pause"):
		cancel()


func _set_ghost_color(c: Color, n: Node = null) -> void:
	if n == null:
		n = ghost
	if n is MeshInstance3D and (n as MeshInstance3D).material_override:
		((n as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = c
	for ch in n.get_children():
		_set_ghost_color(c, ch)


func rotate_ghost() -> void:
	_rot += PI * 0.25


func confirm() -> void:
	if not active:
		return
	if not _valid:
		Events.notify.emit("Сюда нельзя поставить" + (" (костёр — только снаружи)" if kind == "campfire" else ""), "warn")
		return
	var p = GameState.player
	if p.inventory.count(item_id) <= 0:
		cancel()
		return
	p.inventory.remove(item_id, 1)
	var rec := {"kind": kind, "item": item_id, "pos": SaveSystem.v3(_pos), "rot": ghost.rotation.y, "id": "pl%d" % int(GameState.time_min * 10.0 + randi() % 1000)}
	GameState.placed.append(rec)
	spawn(rec, get_parent())
	AudioLib.play_3d("chop", _pos, -6.0, 1.4)
	GameState.add_skill_xp("craft", 5)
	if kind in ["bedroll", "crate"]:
		GameState.set_flag("has_shelter")
		GameState.flags["shelter_pos"] = rec.pos
	Events.notify.emit("Поставлено: %s" % KINDS[kind].title, "good")
	cancel()


func cancel() -> void:
	if ghost:
		ghost.queue_free()
		ghost = null
	if active:
		active = false
		Events.close_screens.emit()


## Визуал размещаемого объекта (без логики).
static func build_visual(k: String) -> Node3D:
	var root := Node3D.new()
	match k:
		"crate":
			if not Models.place("wooden_crate_02", root, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), "", 1.0):
				var kit := MeshKit.new()
				kit.add_box(Mats.get_mat("wood_light"), Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(0.8, 0.6, 0.6))
				root.add_child(kit.build_instance())
		"bedroll":
			var kit2 := MeshKit.new()
			kit2.add_box(Mats.get_mat("blanket"), Transform3D(Basis(), Vector3(0, 0.06, 0)), Vector3(0.8, 0.12, 1.9))
			kit2.add_box(Mats.get_mat("sandbag"), Transform3D(Basis(), Vector3(0, 0.12, -0.8)), Vector3(0.6, 0.12, 0.3))
			root.add_child(kit2.build_instance())
		"workbench":
			var kit3 := MeshKit.new()
			kit3.add_box(Mats.get_mat("wood_light"), Transform3D(Basis(), Vector3(0, 0.85, 0)), Vector3(1.6, 0.08, 0.8))
			for x in [-0.72, 0.72]:
				for z in [-0.32, 0.32]:
					kit3.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(x, 0.42, z)), Vector3(0.08, 0.84, 0.08))
			kit3.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(0, 0.2, 0)), Vector3(1.5, 0.04, 0.7))
			root.add_child(kit3.build_instance())
			Models.place("metal_toolbox", root, Transform3D(Basis(), Vector3(0.4, 0.89, 0)), "", 0.0)
			Models.place("handsaw_wood", root, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.4, 0.92, 0)), "", 0.0)
		"campfire":
			if not Models.place("stone_fire_pit", root, Transform3D.IDENTITY, "", 1.1):
				var kit4 := MeshKit.new()
				kit4.add_cylinder(Mats.get_mat("concrete"), Vector3.ZERO, 0.2, 0.55, 0.5, 8)
				root.add_child(kit4.build_instance())
			var kit5 := MeshKit.new()
			for i in 4:
				kit5.add_box(Mats.get_mat("bark"), Transform3D(Basis(Vector3.UP, i * 0.8) * Basis(Vector3.RIGHT, 1.1), Vector3(0, 0.2, 0)), Vector3(0.1, 0.6, 0.1))
			root.add_child(kit5.build_instance())
		"rain_collector":
			Models.place("Barrel_01", root, Transform3D.IDENTITY, "", 0.0)
		"barricade":
			var kit6 := MeshKit.new()
			kit6.add_box(Mats.get_mat("planks_ext"), Transform3D(Basis(Vector3.FORWARD, 0.9), Vector3(0, 1.0, 0)), Vector3(0.2, 2.4, 0.05))
			kit6.add_box(Mats.get_mat("planks_ext"), Transform3D(Basis(Vector3.FORWARD, -0.9), Vector3(0, 1.0, 0.03)), Vector3(0.2, 2.4, 0.05))
			kit6.add_box(Mats.get_mat("planks_ext"), Transform3D(Basis(), Vector3(0, 1.5, -0.03)), Vector3(1.2, 0.2, 0.05))
			kit6.add_box(Mats.get_mat("planks_ext"), Transform3D(Basis(), Vector3(0, 0.6, -0.03)), Vector3(1.2, 0.2, 0.05))
			root.add_child(kit6.build_instance())
		"candle":
			var kit7 := MeshKit.new()
			kit7.add_cylinder(Mats.get_mat("white_paint"), Vector3.ZERO, 0.13, 0.02, 0.02, 6)
			root.add_child(kit7.build_instance("Candle", false))
		"lamp":
			Models.place("vintage_oil_lamp", root, Transform3D.IDENTITY, "", 0.0)
	return root


## Создать размещённый объект (при постройке и при загрузке).
static func spawn(rec: Dictionary, parent: Node3D) -> Node3D:
	var k: String = rec.kind
	var pos := SaveSystem.to_v3(rec.pos)
	var rot := float(rec.get("rot", 0.0))
	var id: String = rec.id
	var node: Node3D
	match k:
		"crate":
			var c := LootContainer.new()
			c.container_id = "placed/" + id
			c.title = "Ваш ящик"
			c.player_storage = true
			c.slots_count = 16
			c.box_size = Vector3(0.8, 0.6, 0.6)
			node = c
		"bedroll":
			var bed := MiscInteract.Bed.new()
			bed.title = "Спальник"
			bed.quality = 0.75
			bed.setup_box(Vector3(0.9, 0.2, 2.0), Vector3(0, 0.1, 0), false)
			node = bed
		"workbench":
			var wb := MiscInteract.Workbench.new()
			wb.setup_box(Vector3(1.6, 0.9, 0.8), Vector3(0, 0.45, 0))
			node = wb
		"campfire":
			var f := MiscInteract.HeatSource.new()
			f.source_id = "placed/" + id
			f.title = "Костёр"
			f.heat_radius = 4.0
			f.light_offset = Vector3(0, 0.45, 0)
			f.setup_box(Vector3(1.1, 0.4, 1.1), Vector3(0, 0.2, 0))
			node = f
		"rain_collector":
			var rc := MiscInteract.RainCollector.new()
			rc.source_id = "placed/" + id
			rc.setup_box(Vector3(0.6, 0.9, 0.6), Vector3(0, 0.45, 0))
			node = rc
		"barricade":
			var bb := StaticBody3D.new()
			bb.collision_layer = 1
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.2, 2.0, 0.2)
			cs.shape = bs
			cs.position.y = 1.0
			bb.add_child(cs)
			node = bb
		"candle", "lamp":
			var holder := Node3D.new()
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.7, 0.4)
			l.omni_range = 4.5 if k == "candle" else 7.0
			l.light_energy = 0.8 if k == "candle" else 1.3
			l.position = Vector3(0, 0.25 if k == "candle" else 0.5, 0)
			holder.add_child(l)
			node = holder
		_:
			node = Node3D.new()
	node.name = "Placed_" + id
	node.position = pos
	node.rotation.y = rot
	parent.add_child(node)
	if k != "crate":
		node.add_child(build_visual(k))
	else:
		node.add_child(build_visual(k))
	return node
