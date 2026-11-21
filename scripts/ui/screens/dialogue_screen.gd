extends Control
## Диалог с NPC (из data/dialogues.json) и обмен (бартер по ценности предметов, цены зависят от доверия).

var npc: Node
var _data: Dictionary
var _box: VBoxContainer
var _text: RichTextLabel
var _opts: VBoxContainer
var _trade_take: Dictionary = {}
var _trade_give: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	_data = ItemDB.dialogues.get(npc.npc_id, {})
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.35)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var p := UIKit.panel()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	p.anchor_left = 0.08
	p.anchor_right = 0.92
	p.anchor_top = 0.38
	p.anchor_bottom = 0.98
	add_child(p)
	_box = UIKit.vbox(8)
	p.add_child(_box)
	_box.add_child(UIKit.title(str(_data.get("name", npc.display)), 28))
	_text = UIKit.rich("")
	_box.add_child(_text)
	_opts = UIKit.vbox(6)
	_box.add_child(UIKit.scroll(_opts))
	var start := "hub"
	for e in _data.get("entry", []):
		if Conditions.check_all(e.get("cond", [])):
			start = str(e.node)
			break
	show_node(start)


func show_node(id: String) -> void:
	var nodes: Dictionary = _data.get("nodes", {})
	if id == "end" or not nodes.has(id):
		Events.close_screens.emit()
		return
	var n: Dictionary = nodes[id]
	for alt in n.get("alt", []):
		if Conditions.check_all(alt.get("cond", [])):
			show_node(str(alt.node))
			return
	if n.get("trade", false):
		_show_trade()
		return
	Conditions.run_all(n.get("do", []))
	if n.has("journal"):
		GameState.journal_add("dlg_" + npc.npc_id + "_" + id, str(n.journal))
	_text.text = str(n.get("text", ""))
	for c in _opts.get_children():
		c.queue_free()
	for o in n.get("options", []):
		if not Conditions.check_all(o.get("cond", [])):
			continue
		var oo: Dictionary = o
		var b := UIKit.button("— " + str(o.text), func():
			Conditions.run_all(oo.get("do", []))
			show_node(str(oo.next)), 0, 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_opts.add_child(b)
	if _opts.get_child_count() == 0:
		_opts.add_child(UIKit.button("— (уйти)", func(): Events.close_screens.emit(), 0, 20))


# ============================================================================ ОБМЕН
func _price_mult() -> float:
	return clampf(1.4 - GameState.get_trust(npc.npc_id) / 100.0, 0.9, 1.6)


func _stock() -> Dictionary:
	var key: String = "trade:" + npc.npc_id
	if not GameState.world.has(key):
		var st := {}
		for e in _data.get("trade_stock", []):
			st[str(e[0])] = int(e[1])
		GameState.world[key] = st
	return GameState.world[key]


func _show_trade() -> void:
	_text.text = "[i]Тихон разложил на лавке, что не жалко. «Меняемся по-честному. Деньги теперь — бумага».[/i]"
	_refresh_trade()


func _refresh_trade() -> void:
	for c in _opts.get_children():
		c.queue_free()
	var player = GameState.player
	var h := UIKit.hbox(16)
	_opts.add_child(h)
	var left := UIKit.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	left.add_child(UIKit.label("У Тихона (нажмите, чтобы взять):", 18, UIKit.ACCENT))
	var stock := _stock()
	for id in stock:
		if int(stock[id]) <= 0:
			continue
		var take_n := int(_trade_take.get(id, 0))
		var price := int(ceil(ItemDB.value(id) * _price_mult()))
		var iid: String = id
		left.add_child(UIKit.button("%s ×%d  — %d%s" % [ItemDB.item_name(id), int(stock[id]) - take_n, price, ("   [берёте %d]" % take_n) if take_n > 0 else ""], func():
			if int(_trade_take.get(iid, 0)) < int(stock[iid]):
				_trade_take[iid] = int(_trade_take.get(iid, 0)) + 1
			_refresh_trade(), 0, 17))
	var right := UIKit.vbox(4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	right.add_child(UIKit.label("Ваше (нажмите, чтобы предложить):", 18, UIKit.ACCENT))
	var wants: Array = _data.get("trade_wants", [])
	var seen := {}
	for s in player.inventory.slots:
		if s == null or seen.has(s.id) or ItemDB.category(s.id) in ["key", "quest", "document"]:
			continue
		seen[s.id] = true
		var have: int = player.count_item(s.id)
		var give_n := int(_trade_give.get(s.id, 0))
		var val := ItemDB.value(s.id) * (1.0 if s.id in wants else 0.6)
		var sid: String = s.id
		right.add_child(UIKit.button("%s ×%d — %d%s" % [ItemDB.item_name(s.id), have - give_n, int(val), ("   [отдаёте %d]" % give_n) if give_n > 0 else ""], func():
			if int(_trade_give.get(sid, 0)) < player.count_item(sid):
				_trade_give[sid] = int(_trade_give.get(sid, 0)) + 1
			_refresh_trade(), 0, 17))
	var take_v := 0
	for id in _trade_take:
		take_v += int(ceil(ItemDB.value(id) * _price_mult())) * int(_trade_take[id])
	var give_v := 0
	for id in _trade_give:
		give_v += int(ItemDB.value(id) * (1.0 if id in wants else 0.6)) * int(_trade_give[id])
	var bal := UIKit.label("Берёте на %d  •  отдаёте на %d" % [take_v, give_v], 20, UIKit.GOOD if give_v >= take_v and take_v > 0 else UIKit.TEXT)
	_opts.add_child(bal)
	var row := UIKit.hbox()
	_opts.add_child(row)
	var ok := UIKit.button("Обменяться", func(): _do_trade(), 200)
	ok.disabled = take_v == 0 or give_v < take_v
	row.add_child(ok)
	row.add_child(UIKit.button("Сбросить", func(): _trade_take = {}; _trade_give = {}; _refresh_trade(), 160))
	row.add_child(UIKit.button("Назад", func(): _trade_take = {}; _trade_give = {}; show_node("hub"), 140))


func _do_trade() -> void:
	var player = GameState.player
	var stock := _stock()
	for id in _trade_give:
		player.inventory.remove(id, int(_trade_give[id]))
		if ItemDB.value(id) > 0:
			stock[id] = int(stock.get(id, 0)) + int(_trade_give[id])
	for id in _trade_take:
		player.give(id, int(_trade_take[id]))
		stock[id] = int(stock[id]) - int(_trade_take[id])
	GameState.add_trust(npc.npc_id, 2)
	_trade_take = {}
	_trade_give = {}
	AudioLib.ui("confirm")
	Events.notify.emit("Обмен состоялся", "good")
	_refresh_trade()
