extends Control
## Журнал Глеба: задания, записи (версии События), прочитанные документы, карта с туманом исследования.

var start_tab := 0
var _tabs: TabContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var root := UIKit.panel()
	margin.add_child(root)
	var v := UIKit.vbox(8)
	root.add_child(v)
	var head := UIKit.hbox()
	head.add_child(UIKit.title("Журнал", 30))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.label(GameState.clock_text(), 20, UIKit.DIM))
	head.add_child(UIKit.button("✕ Закрыть", func(): Events.close_screens.emit(), 0, 20))
	v.add_child(head)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_tabs)
	_quests_tab()
	_journal_tab()
	_notes_tab()
	_map_tab()
	_tabs.current_tab = start_tab


func _quests_tab() -> void:
	var box := UIKit.vbox(10)
	var sc := UIKit.scroll(box)
	sc.name = "Задания"
	_tabs.add_child(sc)
	var ids: Array = GameState.quests.keys()
	ids.sort_custom(func(a, b): return bool(ItemDB.quests.get(a, {}).get("main", false)) and not bool(ItemDB.quests.get(b, {}).get("main", false)))
	for id in ids:
		var q: Dictionary = GameState.quests[id]
		var def: Dictionary = ItemDB.quests.get(id, {})
		var stages: Array = def.get("stages", [])
		var t := "[b]%s%s[/b]%s\n" % ["★ " if def.get("main", false) else "", def.get("title", id), "  — выполнено" if q.get("done", false) else ""]
		for i in stages.size():
			if i < int(q.stage):
				t += "[color=#7f9a70]✓ %s[/color]\n" % stages[i].text
			elif i == int(q.stage) and not q.get("done", false):
				t += "[color=#d9a441]▸ %s[/color]\n" % stages[i].text
		if q.get("done", false) and def.has("done_text"):
			t += "[i]%s[/i]\n" % def.done_text
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL_LIGHT, 1, Color(0.24, 0.23, 0.2), 6, 14, 10))
		p.add_child(UIKit.rich(t))
		box.add_child(p)


func _journal_tab() -> void:
	var box := UIKit.vbox(10)
	var sc := UIKit.scroll(box)
	sc.name = "Записи"
	_tabs.add_child(sc)
	var versions := []
	if GameState.get_flag("version_chemical"):
		versions.append("• Химическая авария на «Прибое» (официально)")
	if GameState.get_flag("version_military"):
		versions.append("• Военные «геофизические работы» в в/ч 0451")
	if GameState.get_flag("version_call") or GameState.get_flag("version_tikhon"):
		versions.append("• Людей «позвали» — они ушли сами, на север")
	if GameState.get_flag("version_sanatorium"):
		versions.append("• Вышедших из зоны увозят в «Санаторий»")
	if GameState.get_flag("version_truth_1") or GameState.get_flag("heard_tape"):
		versions.append("• «КАМЕРТОН»: резонанс в старых шахтах под районом")
	if not versions.is_empty():
		var vp := PanelContainer.new()
		vp.add_theme_stylebox_override("panel", UIKit.box(Color(0.14, 0.11, 0.07, 0.95), 1, UIKit.ACCENT.darkened(0.3), 6, 14, 10))
		var vv := UIKit.vbox(4)
		vv.add_child(UIKit.label("Что случилось 3 октября? Версии:", 20, UIKit.ACCENT))
		for x in versions:
			vv.add_child(UIKit.label(x, 18, UIKit.TEXT, true))
		vp.add_child(vv)
		box.add_child(vp)
	var entries: Array = GameState.journal.duplicate()
	entries.reverse()
	for e in entries:
		var l := UIKit.rich("[color=#9a958a]%s[/color]\n%s" % [e.time, e.text])
		box.add_child(l)
		box.add_child(HSeparator.new())


func _notes_tab() -> void:
	var h := UIKit.hbox(12)
	h.name = "Документы"
	_tabs.add_child(h)
	var list := UIKit.vbox(4)
	var sc := UIKit.scroll(list)
	sc.custom_minimum_size.x = 380
	sc.size_flags_horizontal = Control.SIZE_FILL
	h.add_child(sc)
	var text := UIKit.rich("[color=#9a958a]Выберите документ.[/color]")
	var sc2 := UIKit.scroll(text)
	h.add_child(sc2)
	for nid in GameState.notes_read:
		var n: Dictionary = ItemDB.notes.get(nid, {})
		var nn: String = nid
		list.add_child(UIKit.button(str(n.get("title", nid)), func():
			text.text = "[b]%s[/b]\n\n%s" % [ItemDB.notes[nn].title, ItemDB.notes[nn].text], 0, 18))
	if GameState.notes_read.is_empty():
		list.add_child(UIKit.label("Пока ничего не прочитано.", 18, UIKit.DIM))


func _map_tab() -> void:
	var m := MapView.new()
	m.name = "Карта"
	_tabs.add_child(m)


## Карта региона: бумажная карта, туман неисследованного, игрок, локации, убежище.
class MapView:
	extends Control
	var tex: Texture2D
	var zoom := 1.0
	var _drag := false

	func _ready() -> void:
		tex = load("res://assets/map/region_map.png")
		clip_contents = true
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _rect() -> Rect2:
		var a := float(tex.get_width()) / float(tex.get_height())
		var w := size.x
		var h := w / a
		if h > size.y:
			h = size.y
			w = h * a
		w *= zoom
		h *= zoom
		var p = GameState.player
		var center := size * 0.5
		var r := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
		if zoom > 1.0 and p:
			var pp := _world_to_uv(p.global_position)
			r.position = center - Vector2(pp.x * w, pp.y * h)
		return r

	func _world_to_uv(pos: Vector3) -> Vector2:
		var reg := ItemDB.region
		return Vector2((pos.x - float(reg.origin[0])) / float(reg.size[0]), (pos.z - float(reg.origin[1])) / float(reg.size[1]))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom = minf(zoom * 1.25, 3.0)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom = maxf(zoom / 1.25, 1.0)
			elif e.button_index == MOUSE_BUTTON_LEFT:
				zoom = 2.2 if zoom < 1.5 else 1.0
			queue_redraw()

	func _draw() -> void:
		var r := _rect()
		draw_texture_rect(tex, r, false)
		# туман
		var fw := GameState.MAP_FOG_W
		var fh := GameState.MAP_FOG_H
		var cw := r.size.x / fw
		var ch := r.size.y / fh
		if GameState.map_fog.size() == fw * fh:
			for y in fh:
				for x in fw:
					if GameState.map_fog[y * fw + x] == 0:
						draw_rect(Rect2(r.position + Vector2(x * cw, y * ch), Vector2(cw + 1, ch + 1)), Color(0.09, 0.085, 0.08, 0.93))
		var font := UIKit.theme().default_font
		for l in ItemDB.region.get("locations", []):
			if not (str(l.id) in GameState.discovered):
				continue
			var uv := _world_to_uv(Vector3(l.center[0], 0, l.center[1]))
			var pos := r.position + uv * r.size
			draw_circle(pos, 4.0, Color(0.25, 0.2, 0.15))
			draw_string(font, pos + Vector2(8, 5), str(l.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.15, 0.12, 0.1))
		if GameState.flags.has("shelter_pos"):
			var sp := SaveSystem.to_v3(GameState.flags.shelter_pos)
			var spos := r.position + _world_to_uv(sp) * r.size
			draw_rect(Rect2(spos - Vector2(6, 6), Vector2(12, 12)), Color(0.2, 0.45, 0.2))
			draw_string(font, spos + Vector2(9, 5), "Убежище", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.15, 0.3, 0.15))
		var p = GameState.player
		if p:
			var pos2 := r.position + _world_to_uv(p.global_position) * r.size
			var fwd: Vector3 = -p.global_transform.basis.z
			var dir := Vector2(fwd.x, fwd.z).normalized()
			var side := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([pos2 + dir * 12, pos2 - dir * 7 + side * 7, pos2 - dir * 7 - side * 7]), Color(0.75, 0.15, 0.1))
		draw_string(font, Vector2(12, size.y - 12), "Нажмите — приблизить/отдалить", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.68, 0.62))
