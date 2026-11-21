extends Node
## Рендер иконок предметов из 3D‑моделей (items.json → model) в assets/icons/<id>.png (128×128, прозрачный фон).
## Запуск: xvfb-run godot --path . res://tools/godot/render_icons.tscn
func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.58)
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, 35, 0)
	key.light_energy = 1.6
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.5
	vp.add_child(fill)
	var holder := Node3D.new()
	vp.add_child(holder)
	var n := 0
	for id in ItemDB.items:
		var model := str(ItemDB.items[id].get("model", ""))
		if model == "" or not Models.exists(model):
			continue
		for c in holder.get_children():
			c.free()
		var inst := Models.instance(model)
		holder.add_child(inst)
		var box := Models.node_aabb(inst, Transform3D.IDENTITY)
		# длинные предметы — по диагонали
		inst.rotation_degrees = Vector3(0, 30, 0) if box.size.y > box.size.x * 1.8 or box.size.z > box.size.x * 1.8 else Vector3(0, 25, 0)
		if box.size.y > box.size.x * 2.0 and box.size.y > box.size.z:
			inst.rotation_degrees = Vector3(0, 20, -45)
		box = Models.node_aabb(holder, Transform3D.IDENTITY)
		var c := box.get_center()
		var r := box.size.length() * 0.5
		cam.size = r * 2.05
		cam.position = c + Vector3(0.6, 0.55, 1.0).normalized() * (r * 4.0)
		cam.look_at(c, Vector3.UP)
		cam.near = 0.01
		cam.far = r * 10.0
		for i in 6:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("res://assets/icons/%s.png" % id)
		n += 1
	print("icons: ", n)
	get_tree().quit()
