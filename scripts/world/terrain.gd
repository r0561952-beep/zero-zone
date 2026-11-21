class_name TerrainStreamer
extends Node3D
## Стриминг мира по чанкам 64×64 м: рельеф (2 уровня детализации), деревья (MultiMesh, 2 LOD),
## коллизия рядом с игроком, находки (грибы, ягоды, хворост). Чанки строятся по одному за кадр.

const CHUNK := 64.0
const COLLIDE_DIST := 90.0
const NEAR_LOD_DIST := 150.0
const TREE_NEAR := 110.0

var material: ShaderMaterial
var tree_meshes: Dictionary = {}      # тип -> [near_mesh, far_mesh]
var chunks: Dictionary = {}           # Vector2i -> Dictionary
var _queue: Array[Vector2i] = []
var _timer := 0.0
var _center := Vector2i(999, 999)
var no_tree_rects: Array = []         # [Rect2] — участки под зданиями
var focus: Node3D


func _ready() -> void:
	RegionData.ensure_loaded()
	material = _make_material()
	tree_meshes = TreeFactory.build_all()
	Events.settings_changed.connect(func(): _center = Vector2i(999, 999))


func _make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/world/terrain.gdshader")
	var tex := ImageTexture.create_from_image(RegionData.mask_image)
	m.set_shader_parameter("mask_tex", tex)
	m.set_shader_parameter("region_rect", Vector4(RegionData.ox, RegionData.oz, (RegionData.w - 1) * RegionData.cell, (RegionData.h - 1) * RegionData.cell))
	for pair in [["grass", "withered_grass"], ["forest", "forest_leaves_02"], ["gravel", "gravel_road"], ["mud", "muddy_tracks"]]:
		m.set_shader_parameter(pair[0] + "_alb", Mats.tex(pair[1], "albedo"))
		m.set_shader_parameter(pair[0] + "_nrm", Mats.tex(pair[1], "normal"))
	return m


func set_wetness(w: float, snow: float) -> void:
	material.set_shader_parameter("wetness", w)
	material.set_shader_parameter("snow", snow)


func _process(delta: float) -> void:
	if focus == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.4
		_refresh(focus.global_position)
	# строим по одному чанку за кадр (без фризов)
	var budget := 2 if _queue.size() > 12 else 1
	while budget > 0 and not _queue.is_empty():
		budget -= 1
		_build_chunk(_queue.pop_front())


## Синхронно построить всё вокруг точки (при загрузке/телепорте).
func build_around(pos: Vector3) -> void:
	_refresh(pos)
	while not _queue.is_empty():
		_build_chunk(_queue.pop_front())


func _refresh(pos: Vector3) -> void:
	var view := Settings.view_distance + CHUNK * 0.5
	var c := Vector2i(int(floor(pos.x / CHUNK)), int(floor(pos.z / CHUNK)))
	var r := int(ceil(view / CHUNK))
	var wanted := {}
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var k := c + Vector2i(dx, dz)
			var cc := Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK)
			var d := cc.distance_to(Vector2(pos.x, pos.z))
			if d > view + CHUNK * 0.7:
				continue
			if not RegionData.in_bounds(cc.x, cc.y, -CHUNK * 0.5):
				continue
			var lod := 0 if d < NEAR_LOD_DIST else 1
			var col := d < COLLIDE_DIST + CHUNK * 0.7
			var trees_near := d < TREE_NEAR + CHUNK * 0.7
			wanted[k] = true
			var ch = chunks.get(k)
			if ch == null:
				chunks[k] = {"lod": lod, "col": col, "near": trees_near, "built": false}
				if not _queue.has(k):
					_queue.append(k)
			elif ch.lod != lod or ch.col != col or ch.near != trees_near:
				ch.lod = lod
				ch.col = col
				ch.near = trees_near
				if not _queue.has(k):
					_queue.append(k)
	for k in chunks.keys():
		if not wanted.has(k):
			_free_chunk(k)
	# ближние — в начало очереди
	_queue.sort_custom(func(a, b):
		var pa := Vector2((a.x + 0.5) * CHUNK, (a.y + 0.5) * CHUNK)
		var pb := Vector2((b.x + 0.5) * CHUNK, (b.y + 0.5) * CHUNK)
		var p := Vector2(pos.x, pos.z)
		return pa.distance_squared_to(p) < pb.distance_squared_to(p))
	_center = c


func _free_chunk(k: Vector2i) -> void:
	var ch: Dictionary = chunks[k]
	if ch.has("node") and is_instance_valid(ch.node):
		ch.node.queue_free()
	chunks.erase(k)
	_queue.erase(k)


func _build_chunk(k: Vector2i) -> void:
	var ch = chunks.get(k)
	if ch == null:
		return
	var origin := Vector3(k.x * CHUNK, 0, k.y * CHUNK)
	var node: Node3D = ch.get("node")
	if node == null or not is_instance_valid(node):
		node = Node3D.new()
		node.name = "Chunk_%d_%d" % [k.x, k.y]
		node.position = origin
		add_child(node)
		ch["node"] = node
		ch["mesh_lod"] = -1
		ch["has_col"] = false
		ch["trees_built"] = false
		ch["trees_near"] = false
	# --- рельеф
	if ch.mesh_lod != ch.lod:
		if node.has_node("Ground"):
			node.get_node("Ground").free()
		var mi := MeshInstance3D.new()
		mi.name = "Ground"
		mi.mesh = _ground_mesh(origin, 2.0 if ch.lod == 0 else 4.0)
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
		ch.mesh_lod = ch.lod
	# --- коллизия
	if ch.col and not ch.has_col:
		node.add_child(_ground_collision(origin))
		ch.has_col = true
	elif not ch.col and ch.has_col:
		if node.has_node("GroundBody"):
			node.get_node("GroundBody").free()
		ch.has_col = false
	# --- деревья
	if not ch.trees_built:
		ch["trees"] = _scatter_trees(k, origin)
		_build_tree_multimesh(node, ch.trees)
		ch.trees_built = true
	if ch.col and not ch.trees_near:
		_build_tree_bodies(node, k, ch.trees)
		_build_forage(node, k, origin)
		ch.trees_near = true
	elif not ch.col and ch.trees_near:
		for n in ["TreeBodies", "Forage"]:
			if node.has_node(n):
				node.get_node(n).free()
		ch.trees_near = false


func _ground_mesh(origin: Vector3, step: float) -> ArrayMesh:
	var n := int(CHUNK / step) + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(n * n)
	norms.resize(n * n)
	uvs.resize(n * n)
	for z in n:
		for x in n:
			var wx := origin.x + x * step
			var wz := origin.z + z * step
			var i := z * n + x
			verts[i] = Vector3(x * step, RegionData.height_at(wx, wz), z * step)
			norms[i] = RegionData.normal_at(wx, wz)
			uvs[i] = Vector2(wx, wz)
	for z in n - 1:
		for x in n - 1:
			var a := z * n + x
			var b := a + 1
			var c := a + n
			var d := c + 1
			# по часовой при взгляде сверху
			idx.append_array([a, b, d, a, d, c])
	# «юбка» по краям, чтобы не было щелей между LOD
	var base := verts.size()
	var edge: Array = []
	for x in n:
		edge.append(x)
	for z in range(1, n):
		edge.append(z * n + n - 1)
	for x in range(n - 2, -1, -1):
		edge.append((n - 1) * n + x)
	for z in range(n - 2, 0, -1):
		edge.append(z * n)
	edge.append(0)
	for e in edge:
		verts.append(verts[e] - Vector3(0, 1.5, 0))
		norms.append(norms[e])
		uvs.append(uvs[e])
	for j in edge.size() - 1:
		var t0: int = edge[j]
		var t1: int = edge[j + 1]
		var b0 := base + j
		var b1 := base + j + 1
		idx.append_array([t0, b1, t1, t0, b0, b1])
		idx.append_array([t0, t1, b1, t0, b1, b0])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _ground_collision(origin: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 1
	body.set_meta("surface", "dirt")
	var n := int(CHUNK) + 1
	var data := PackedFloat32Array()
	data.resize(n * n)
	for z in n:
		for x in n:
			data[z * n + x] = RegionData.height_at(origin.x + x, origin.z + z)
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(CHUNK * 0.5, 0, CHUNK * 0.5)
	body.add_child(cs)
	return body


# ========================================================================= ДЕРЕВЬЯ
func _rng_for(k: Vector2i, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(k.x, k.y, salt)) ^ 0x5EED
	return r


func _blocked(wx: float, wz: float) -> bool:
	for r in no_tree_rects:
		if (r as Rect2).has_point(Vector2(wx, wz)):
			return true
	return false


func _scatter_trees(k: Vector2i, origin: Vector3) -> Array:
	var rng := _rng_for(k, 1)
	var out: Array = []
	var step := 4.0
	var n := int(CHUNK / step)
	var dens := clampf(Settings.vegetation, 0.3, 1.0)
	var i := 0
	for gz in n:
		for gx in n:
			var wx := origin.x + (gx + rng.randf_range(0.1, 0.9)) * step
			var wz := origin.z + (gz + rng.randf_range(0.1, 0.9)) * step
			var roll := rng.randf()
			var t_roll := rng.randf()
			var sc := rng.randf_range(0.75, 1.3)
			var rot := rng.randf() * TAU
			var m := RegionData.mask_at(wx, wz)
			var p := m.g * 0.62
			var open_land := m.g < 0.12 and m.r < 0.1 and m.a < 0.1 and m.b < 0.05
			# одинокие деревья и кусты в полях и посёлке
			if open_land:
				p = 0.035
			if roll > p * (0.55 + dens * 0.45):
				i += 1
				continue
			if m.b > 0.2 or m.r > 0.25 or m.a > 0.1 or _blocked(wx, wz):
				i += 1
				continue
			var kind := "pine"
			if open_land:
				kind = "bush" if t_roll < 0.6 else ("birch" if t_roll < 0.85 else "apple")
			elif t_roll < 0.22:
				kind = "birch"
			elif t_roll < 0.28:
				kind = "dead"
			elif t_roll < 0.45 and m.g < 0.55:
				kind = "bush" if t_roll < 0.36 else "birch"
			var id := "t:%d:%d:%d" % [k.x, k.y, i]
			i += 1
			if GameState.world.has(id):
				continue
			var y := RegionData.height_at(wx, wz) - 0.15
			out.append({"id": id, "kind": kind, "pos": Vector3(wx, y, wz) - origin, "rot": rot, "scale": sc})
	return out


func _build_tree_multimesh(node: Node3D, trees: Array) -> void:
	var by_kind := {}
	for t in trees:
		if not by_kind.has(t.kind):
			by_kind[t.kind] = []
		by_kind[t.kind].append(t)
	var view := Settings.view_distance
	for kind in by_kind:
		var list: Array = by_kind[kind]
		for lod in 2:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = tree_meshes[kind][lod]
			mm.instance_count = list.size()
			for j in list.size():
				var t: Dictionary = list[j]
				var b := Basis(Vector3.UP, t.rot).scaled(Vector3.ONE * t.scale)
				mm.set_instance_transform(j, Transform3D(b, t.pos))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Trees_%s_%d" % [kind, lod]
			mmi.multimesh = mm
			if lod == 0:
				mmi.visibility_range_end = TREE_NEAR
				mmi.visibility_range_end_margin = 10.0
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			else:
				mmi.visibility_range_begin = TREE_NEAR
				mmi.visibility_range_begin_margin = 10.0
				mmi.visibility_range_end = view + 30.0
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			mmi.set_meta("kind", kind)
			node.add_child(mmi)
			for j in list.size():
				list[j]["mm_" + str(lod)] = [mmi, j]


func _build_tree_bodies(node: Node3D, k: Vector2i, trees: Array) -> void:
	var holder := Node3D.new()
	holder.name = "TreeBodies"
	node.add_child(holder)
	for t in trees:
		if t.kind == "bush":
			continue
		var body := TreeBody.new()
		body.tree = t
		body.streamer = self
		body.position = t.pos
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.28 * t.scale
		sh.height = 4.0
		cs.shape = sh
		cs.position.y = 2.0
		body.add_child(cs)
		holder.add_child(body)


## Срубить дерево: скрыть экземпляры, запомнить в мире.
func fell_tree(t: Dictionary) -> void:
	GameState.world[t.id] = true
	for lod in 2:
		var key := "mm_" + str(lod)
		if t.has(key):
			var mmi: MultiMeshInstance3D = t[key][0]
			if is_instance_valid(mmi):
				mmi.multimesh.set_instance_transform(t[key][1], Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0, -50, 0)))


# ====================================================================== НАХОДКИ
func _build_forage(node: Node3D, k: Vector2i, origin: Vector3) -> void:
	var rng := _rng_for(k, 7)
	var holder := Node3D.new()
	holder.name = "Forage"
	node.add_child(holder)
	var spots := rng.randi_range(0, 3)
	for i in spots:
		var wx := origin.x + rng.randf_range(4, CHUNK - 4)
		var wz := origin.z + rng.randf_range(4, CHUNK - 4)
		var m := RegionData.mask_at(wx, wz)
		var kind := ""
		if m.g > 0.55:
			kind = "mushrooms" if rng.randf() < 0.55 else "sticks"
		elif m.g > 0.2:
			kind = "berries"
		if kind == "" or m.b > 0.1 or m.r > 0.2 or _blocked(wx, wz):
			continue
		var f := ForageSpot.new()
		f.kind = kind
		f.spot_id = "f:%d:%d:%d" % [k.x, k.y, i]
		f.position = Vector3(wx, RegionData.height_at(wx, wz), wz) - origin
		holder.add_child(f)
	# редкая случайная находка — брошенный рюкзак
	if rng.randf() < 0.05:
		var wx2 := origin.x + rng.randf_range(6, CHUNK - 6)
		var wz2 := origin.z + rng.randf_range(6, CHUNK - 6)
		if RegionData.mask_at(wx2, wz2).b < 0.1 and not _blocked(wx2, wz2):
			var c := LootContainer.new()
			c.container_id = "bag:%d:%d" % [k.x, k.y]
			c.loot_table = "car_trunk"
			c.title = "Брошенный рюкзак"
			c.slots_count = 8
			c.position = Vector3(wx2, RegionData.height_at(wx2, wz2), wz2) - origin
			c.visual = "backpack"
			holder.add_child(c)
