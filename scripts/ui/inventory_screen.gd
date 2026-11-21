extends Control
## Инвентарь (вещи / крафт / персонаж) и режим контейнера (две сетки с переносом).
## Ячейки поддерживают перетаскивание (мышь и палец), выбор, детали, использование, выбрасывание.

var player: Node
var container: LootContainer = null
var craft_context := ""
var start_tab := 0
var _cat := "all"
var _sel_inv: Inventory
var _sel_i := -1
var _tabs: TabContainer
var _grid: GridContainer
var _other_grid: GridContainer
var _details: VBoxContainer
var _weight_lbl: Label
var _craft_list: VBoxContainer
var _craft_detail: VBoxContainer
var _sel_recipe := ""
var _char_box: VBoxContainer


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
	v.add_child(head)
	head.add_child(UIKit.title(container.title if container else "Инвентарь", 30))
	head.add_child(UIKit.spacer())
	_weight_lbl = UIKit.label("", 20, UIKit.DIM)
	head.add_child(_weight_lbl)
	head.add_child(UIKit.button("Сортировать", func(): player.inventory.sort(); _refresh(), 0, 18))
	head.add_child(UIKit.button("✕ Закрыть", func(): Events.close_screens.emit(), 0, 20))
	if container:
		_build_container_mode(v)
	else:
		_tabs = TabContainer.new()
		_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(_tabs)
		_build_items_tab()
		_build_craft_tab()
		_build_char_tab()
		_tabs.current_tab = start_tab
		_tabs.tab_changed.connect(func(_t): _refresh())
	player.inventory.changed.connect(_refresh)
	if container:
		container.inventory.changed.connect(_refresh)
	_refresh()


# ================================================================== ВКЛАДКА «ВЕЩИ»
func _build_items_tab() -> void:
	var h := UIKit.hbox(14)
	h.name = "Вещи"
	_tabs.add_child(h)
	var left := UIKit.vbox(8)
	h.add_child(left)
	var cats := HFlowContainer.new()
	cats.add_theme_constant_override("h_separation", 4)
	left.add_child(cats)
	for c in ["all"] + ItemDB.CATEGORY_ORDER:
		var cc: String = c
		var b := UIKit.button(ItemDB.CATEGORY_NAMES[cc], func(): _cat = cc; _refresh(), 0, 16)
		b.custom_minimum_size.y = 40
		cats.add_child(b)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(_grid)
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL_LIGHT, 1, Color(0.25, 0.24, 0.22), 6, 14, 12))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	_details = UIKit.vbox(8)
	right.add_child(UIKit.scroll(_details))


func _build_container_mode(v: VBoxContainer) -> void:
	var h := UIKit.hbox(16)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var lcol := UIKit.vbox(6)
	h.add_child(lcol)
	lcol.add_child(UIKit.label("Ваши вещи", 20, UIKit.ACCENT))
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	lcol.add_child(_grid)
	var mid := UIKit.vbox(10)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(mid)
	mid.add_child(UIKit.button("Взять всё ←", func(): _take_all(), 170))
	mid.add_child(UIKit.button("← Переложить →", func(): _transfer_selected(), 170))
	mid.add_child(UIKit.button("Положить всё →", func(): _put_all(), 170))
	_details = UIKit.vbox(6)
	mid.add_child(_details)
	var rcol := UIKit.vbox(6)
	h.add_child(rcol)
	rcol.add_child(UIKit.label(container.title, 20, UIKit.ACCENT))
	_other_grid = GridContainer.new()
	_other_grid.columns = 4
	_other_grid.add_theme_constant_override("h_separation", 6)
	_other_grid.add_theme_constant_override("v_separation", 6)
	rcol.add_child(UIKit.scroll(_other_grid))


func _take_all() -> void:
	var inv := container.inventory
	for i in inv.size():
		if inv.slots[i]:
			var sid: String = inv.slots[i].id
			var moved := inv.transfer_to(i, player.inventory)
			if moved > 0:
				Events.item_picked.emit(sid, moved)
	AudioLib.play_2d("pickup", -6.0)
	_refresh()


func _put_all() -> void:
	for i in player.inventory.size():
		var s = player.inventory.slots[i]
		if s and not ItemDB.category(s.id) in ["key", "quest", "document"]:
			player.inventory.transfer_to(i, container.inventory)
	_refresh()


func _transfer_selected() -> void:
	if _sel_inv == null or _sel_i < 0:
		return
	var other: Inventory = container.inventory if _sel_inv == player.inventory else player.inventory
	_sel_inv.transfer_to(_sel_i, other)
	AudioLib.play_2d("pickup", -8.0)
	_sel_i = -1
	_refresh()


# ================================================================== ВКЛАДКА «КРАФТ»
func _build_craft_tab() -> void:
	var h := UIKit.hbox(14)
	h.name = "Крафт"
	_tabs.add_child(h)
	_craft_list = UIKit.vbox(4)
	var sc := UIKit.scroll(_craft_list)
	sc.custom_minimum_size.x = 430
	sc.size_flags_horizontal = Control.SIZE_FILL
	h.add_child(sc)
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL_LIGHT, 1, Color(0.25, 0.24, 0.22), 6, 14, 12))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	_craft_detail = UIKit.vbox(8)
	right.add_child(_craft_detail)


func _refresh_craft() -> void:
	for c in _craft_list.get_children():
		c.queue_free()
	var ids: Array = GameState.known_recipes.duplicate()
	ids.sort_custom(func(a, b):
		var ca: bool = Crafting.check(a, player, craft_context)[0]
		var cb: bool = Crafting.check(b, player, craft_context)[0]
		if ca != cb:
			return ca
		return a < b)
	for rid in ids:
		var r: Dictionary = ItemDB.recipes[rid]
		var ok: bool = Crafting.check(rid, player, craft_context)[0]
		var out: Array = r.out
		var b := UIKit.button("%s%s  ×%d   [%s]" % ["● " if ok else "○ ", ItemDB.item_name(out[0]), int(out[1]), Crafting.station_name(r.get("station", "hand"))], func(): _sel_recipe = rid; _refresh_craft(), 0, 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not ok:
			b.modulate = Color(1, 1, 1, 0.6)
		if rid == _sel_recipe:
			b.add_theme_stylebox_override("normal", UIKit.box(Color(0.25, 0.2, 0.12), 1, UIKit.ACCENT, 6, 14, 8))
		_craft_list.add_child(b)
	var lock_count := ItemDB.recipes.size() - GameState.known_recipes.size()
	if lock_count > 0:
		_craft_list.add_child(UIKit.label("Ещё %d рецептов: ищите журналы, записки, спрашивайте людей, развивайте навыки." % lock_count, 16, UIKit.DIM, true))
	for c in _craft_detail.get_children():
		c.queue_free()
	if _sel_recipe == "" or not ItemDB.recipes.has(_sel_recipe):
		_craft_detail.add_child(UIKit.label("Выберите рецепт слева.", 20, UIKit.DIM))
		return
	var rr: Dictionary = ItemDB.recipes[_sel_recipe]
	var o: Array = rr.out
	var top := UIKit.hbox(12)
	top.add_child(UIKit.item_icon(o[0], int(o[1]), 84))
	var tv := UIKit.vbox(2)
	tv.add_child(UIKit.title(ItemDB.item_name(o[0]), 26))
	tv.add_child(UIKit.label(str(ItemDB.item(o[0]).get("desc", "")), 17, UIKit.DIM, true))
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	_craft_detail.add_child(top)
	_craft_detail.add_child(UIKit.label("Нужно:", 19, UIKit.ACCENT))
	for id in rr.get("in", {}):
		var need := int(rr["in"][id])
		var have: int = player.count_item(id)
		_craft_detail.add_child(UIKit.label("  %s — %d/%d" % [ItemDB.item_name(id), have, need], 19, UIKit.GOOD if have >= need else UIKit.BAD))
	for t in rr.get("tools", []):
		var ht: bool = player.has_tool(str(t))
		_craft_detail.add_child(UIKit.label("  Инструмент: %s" % Crafting._tool_name(str(t)), 19, UIKit.GOOD if ht else UIKit.BAD))
	var st := str(rr.get("station", "hand"))
	var sok := Crafting.station_available(st, player, craft_context)
	_craft_detail.add_child(UIKit.label("  Где: %s" % Crafting.station_name(st), 19, UIKit.GOOD if sok else UIKit.BAD))
	_craft_detail.add_child(UIKit.label("  Время: ~%d мин" % int(rr.get("time", 3)), 17, UIKit.DIM))
	var chk := Crafting.check(_sel_recipe, player, craft_context)
	var btn := UIKit.button("Создать", func():
		if Crafting.craft(_sel_recipe, player, craft_context):
			_refresh(), 220)
	btn.disabled = not chk[0]
	_craft_detail.add_child(btn)


# ================================================================ ВКЛАДКА «ПЕРСОНАЖ»
func _build_char_tab() -> void:
	_char_box = UIKit.vbox(6)
	var sc := UIKit.scroll(_char_box)
	sc.name = "Персонаж"
	_tabs.add_child(sc)


func _refresh_char() -> void:
	for c in _char_box.get_children():
		c.queue_free()
	_char_box.add_child(UIKit.title("Глеб Ланской, 36 лет", 26))
	_char_box.add_child(UIKit.label("Настройщик фортепиано. Абсолютный слух. Приехал за сестрой.", 17, UIKit.DIM))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	_char_box.add_child(grid)
	for slot in ["hand"] + ItemDB.EQUIP_SLOTS:
		grid.add_child(UIKit.label(ItemDB.EQUIP_NAMES[slot], 19, UIKit.DIM))
		if player.equipment.has(slot):
			var id: String = player.equipment[slot].id
			grid.add_child(UIKit.label(ItemDB.item_name(id), 19))
			var s: String = slot
			grid.add_child(UIKit.button("Снять", func(): player.unequip(s); _refresh(), 0, 17))
		else:
			grid.add_child(UIKit.label("—", 19, UIKit.DIM))
			grid.add_child(Control.new())
	var s: Survival = player.survival
	_char_box.add_child(UIKit.label("Утепление одежды: %d%%   •   Защита от дождя: %d%%" % [int(player.insulation() * 100.0), int(player._rain_protect() * 100.0)], 19))
	_char_box.add_child(UIKit.label("Ощущается как %+d°C   •   Мокрость %d%%   •   Отравление %d%%" % [int(s.feels_temp), int(s.wet * 100.0), int(s.sick)], 19))
	if s.earplugs_min > 0.0:
		_char_box.add_child(UIKit.label("Беруши: ещё %d мин" % int(s.earplugs_min), 19, UIKit.GOOD))
	_char_box.add_child(UIKit.label("Навыки", 22, UIKit.ACCENT))
	for sk in GameState.SKILLS:
		var lvl := GameState.skill_level(sk)
		var xp := int(GameState.skills.get(sk, 0))
		var nxt: int = GameState.SKILL_LEVELS[mini(lvl + 1, GameState.SKILL_LEVELS.size() - 1)]
		_char_box.add_child(UIKit.label("%s — ур. %d  (%d/%d)" % [GameState.SKILLS[sk], lvl, xp, nxt], 19))


# ======================================================================= ОБНОВЛЕНИЕ
func _refresh() -> void:
	if not is_inside_tree():
		return
	var w: float = player.inventory.total_weight()
	_weight_lbl.text = "Вес: %.1f / %d кг" % [w, int(player.MAX_WEIGHT)]
	_weight_lbl.add_theme_color_override("font_color", UIKit.BAD if w > player.MAX_WEIGHT else UIKit.DIM)
	if _tabs and _tabs.current_tab == 1:
		_refresh_craft()
		return
	if _tabs and _tabs.current_tab == 2:
		_refresh_char()
		return
	_fill_grid(_grid, player.inventory, _cat)
	if container:
		_fill_grid(_other_grid, container.inventory, "all")
	_refresh_details()


func _fill_grid(g: GridContainer, inv: Inventory, cat: String) -> void:
	for c in g.get_children():
		c.queue_free()
	for i in inv.size():
		var s = inv.slots[i]
		if cat != "all" and (s == null or ItemDB.category(s.id) != cat):
			continue
		var slot := InvSlot.new()
		slot.inv = inv
		slot.index = i
		slot.screen = self
		slot.selected = (inv == _sel_inv and i == _sel_i)
		g.add_child(slot)


func select(inv: Inventory, i: int) -> void:
	if inv == _sel_inv and i == _sel_i and container:
		_transfer_selected()
		return
	_sel_inv = inv
	_sel_i = i
	AudioLib.ui("select")
	_refresh()


func _refresh_details() -> void:
	for c in _details.get_children():
		c.queue_free()
	if _sel_inv == null or _sel_i < 0 or _sel_i >= _sel_inv.size() or _sel_inv.slots[_sel_i] == null:
		if not container:
			_details.add_child(UIKit.label("Выберите предмет.\nПеретаскивайте ячейки, чтобы менять порядок.", 18, UIKit.DIM, true))
		return
	var s: Dictionary = _sel_inv.slots[_sel_i]
	var it := ItemDB.item(s.id)
	if container:
		_details.add_child(UIKit.label(ItemDB.item_name(s.id), 18, UIKit.ACCENT, true))
		return
	var top := UIKit.hbox(12)
	top.add_child(UIKit.item_icon(s.id, int(s.n), 90))
	var tv := UIKit.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.title(ItemDB.item_name(s.id), 26))
	tv.add_child(UIKit.label("%s  •  %.2f кг%s" % [ItemDB.CATEGORY_NAMES.get(ItemDB.category(s.id), ""), ItemDB.weight(s.id), ("  •  ×%d" % int(s.n)) if int(s.n) > 1 else ""], 17, UIKit.DIM))
	top.add_child(tv)
	_details.add_child(top)
	if it.has("desc"):
		_details.add_child(UIKit.label(str(it.desc), 19, UIKit.TEXT, true))
	var info: Array = []
	if it.has("use"):
		var u: Dictionary = it.use
		for k in [["hunger", "сытость"], ["thirst", "вода"], ["health", "здоровье"], ["sleep", "бодрость"], ["warmth", "тепло"], ["sick", "отравление"]]:
			if u.has(k[0]):
				info.append("%s %+d" % [k[1], int(u[k[0]])])
	if s.d.has("charge"):
		info.append("заряд %d%%" % int(s.d.charge))
	if s.d.has("fresh"):
		info.append("свежесть %d%%" % int(float(s.d.fresh) * 100.0))
	if it.has("insulation"):
		info.append("утепление +%d%%" % int(float(it.insulation) * 100.0))
	if it.has("weapon"):
		info.append("урон %d" % int(it.weapon.damage))
	if not info.is_empty():
		_details.add_child(UIKit.label(", ".join(info), 18, UIKit.ACCENT, true))
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 6)
	acts.add_theme_constant_override("v_separation", 6)
	_details.add_child(acts)
	var idx := _sel_i
	var use_text := ""
	if it.has("note"):
		use_text = "Читать" if ItemDB.category(s.id) == "document" else "Осмотреть / слушать"
	elif it.has("place"):
		use_text = "Разместить"
	elif it.has("equip"):
		use_text = "Взять в руку" if it.equip == "hand" else "Надеть"
	elif it.has("use"):
		use_text = {"food": "Съесть", "water": "Выпить", "medical": "Применить"}.get(ItemDB.category(s.id), "Использовать")
	elif ItemDB.has_tag(s.id, "radio"):
		use_text = "Включить"
	elif ItemDB.has_tag(s.id, "fork") or ItemDB.has_tag(s.id, "light") or ItemDB.has_tag(s.id, "light_torch") or ItemDB.has_tag(s.id, "chalk"):
		use_text = "Использовать"
	if use_text != "":
		acts.add_child(UIKit.button(use_text, func(): player.use_slot(idx); _refresh(), 0, 19))
	for q in 4:
		var qq := q
		acts.add_child(UIKit.button("В слот %d" % (q + 1), func():
			player.quickbar[qq] = s.id
			Events.equipment_changed.emit()
			Events.notify.emit("%s → быстрый слот %d" % [ItemDB.item_name(s.id), qq + 1], "info"), 0, 16))
	if not ItemDB.category(s.id) in ["key", "quest"]:
		acts.add_child(UIKit.button("Выбросить", func(): player.drop_slot(idx); _sel_i = -1; _refresh(), 0, 17))
	if int(s.n) > 1 and player.inventory.free_slots() > 0:
		acts.add_child(UIKit.button("Разделить", func():
			var half := int(s.n) / 2
			var taken: Dictionary = player.inventory.remove_at(idx, half)
			for j in player.inventory.size():
				if player.inventory.slots[j] == null:
					player.inventory.slots[j] = {"id": taken.id, "n": taken.n, "d": taken.d}
					break
			player.inventory.changed.emit(), 0, 17))


## Ячейка инвентаря с поддержкой drag & drop.
class InvSlot:
	extends Panel
	var inv: Inventory
	var index := 0
	var screen: Control
	var selected := false

	func _ready() -> void:
		custom_minimum_size = Vector2(72, 72)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var s = inv.slots[index]
		add_theme_stylebox_override("panel", UIKit.box(Color(0.08, 0.08, 0.085, 0.95), 2 if selected else 1, UIKit.ACCENT if selected else Color(0.24, 0.23, 0.21), 6))
		if s:
			var ic := UIKit.item_icon(s.id, int(s.n), 66)
			ic.position = Vector2(3, 3)
			add_child(ic)
			if s.d.has("charge") or s.d.has("fresh"):
				var v := float(s.d.get("charge", 100.0)) / 100.0 if s.d.has("charge") else float(s.d.fresh)
				var bar := ColorRect.new()
				bar.color = UIKit.GOOD if v > 0.4 else UIKit.BAD
				bar.position = Vector2(6, 64)
				bar.size = Vector2(60.0 * clampf(v, 0, 1), 3)
				add_child(bar)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if inv.slots[index] != null or screen.get("container") != null:
				screen.select(inv, index)
			if e.double_click and inv.slots[index] != null and screen.get("container") == null:
				GameState.player.use_slot(index)

	func _get_drag_data(_p: Vector2) -> Variant:
		if inv.slots[index] == null:
			return null
		var prev := UIKit.item_icon(inv.slots[index].id, int(inv.slots[index].n), 64)
		prev.modulate.a = 0.8
		set_drag_preview(prev)
		return {"inv": inv, "i": index}

	func _can_drop_data(_p: Vector2, d: Variant) -> bool:
		return d is Dictionary and d.has("inv")

	func _drop_data(_p: Vector2, d: Variant) -> void:
		var src: Inventory = d.inv
		if src == inv:
			inv.move(int(d.i), index)
		else:
			var s = src.slots[int(d.i)]
			if s == null:
				return
			src.transfer_to(int(d.i), inv)
		AudioLib.play_2d("pickup", -10.0)
