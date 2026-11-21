extends Control
## Слоты сохранения: сохранить / загрузить / удалить. Автосохранение — отдельный слот.

signal closed
signal load_requested(slot: String)

var mode := "load"   ## load | save
var _list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := UIKit.modal(Vector2(780, 560))
	add_child(m[0])
	var v: VBoxContainer = m[1]
	var head := UIKit.hbox()
	head.add_child(UIKit.title("Сохранить игру" if mode == "save" else "Загрузить игру", 30))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.button("Назад", func(): closed.emit(); queue_free(), 140))
	v.add_child(head)
	_list = UIKit.vbox(8)
	v.add_child(UIKit.scroll(_list))
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for slot in SaveSystem.SLOTS:
		if mode == "save" and slot == "auto":
			continue
		var meta := SaveSystem.slot_meta(slot)
		var row := UIKit.hbox(10)
		var info := UIKit.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.label(SaveSystem.slot_title(slot), 21, UIKit.ACCENT))
		if meta.is_empty():
			info.add_child(UIKit.label("пусто", 17, UIKit.DIM))
		else:
			info.add_child(UIKit.label("%s  •  %s  •  сохранено %s" % [meta.get("location", ""), meta.get("clock", ""), str(meta.get("saved_at", "")).replace("T", " ")], 17, UIKit.DIM))
		row.add_child(info)
		var s: String = slot
		if mode == "save":
			row.add_child(UIKit.button("Сохранить", func():
				SaveSystem.save_game(s)
				_refresh(), 160))
		else:
			var lb := UIKit.button("Загрузить", func(): load_requested.emit(s), 160)
			lb.disabled = meta.is_empty()
			row.add_child(lb)
		if not meta.is_empty():
			row.add_child(UIKit.button("Удалить", func(): SaveSystem.delete_slot(s); _refresh(), 120))
		_list.add_child(row)
		_list.add_child(HSeparator.new())
