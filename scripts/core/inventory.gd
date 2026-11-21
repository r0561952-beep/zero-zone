class_name Inventory
extends RefCounted
## Инвентарь: сетка ячеек со стаками, ограничение по весу.
## Ячейка: {"id": String, "n": int, "d": Dictionary (заряд/свежесть и т.п.)} или null.
## Используется и игроком, и контейнерами (шкафы, ящики, багажники).

signal changed

var slots: Array = []
var max_weight: float = 0.0   ## 0 — без ограничения по весу (контейнеры)


func _init(size: int = 24, weight_limit: float = 0.0) -> void:
	slots.resize(size)
	max_weight = weight_limit


func size() -> int:
	return slots.size()


func total_weight() -> float:
	var w := 0.0
	for s in slots:
		if s:
			w += ItemDB.weight(s.id) * int(s.n)
	return w


func count(id: String) -> int:
	var c := 0
	for s in slots:
		if s and s.id == id:
			c += int(s.n)
	return c


func has(id: String, n: int = 1) -> bool:
	return count(id) >= n


func has_tag(tag: String) -> bool:
	for s in slots:
		if s and ItemDB.has_tag(s.id, tag):
			return true
	return false


func first_with_tag(tag: String) -> int:
	for i in slots.size():
		if slots[i] and ItemDB.has_tag(slots[i].id, tag):
			return i
	return -1


func find(id: String) -> int:
	for i in slots.size():
		if slots[i] and slots[i].id == id:
			return i
	return -1


func free_slots() -> int:
	var c := 0
	for s in slots:
		if s == null:
			c += 1
	return c


static func default_data(id: String) -> Dictionary:
	var it := ItemDB.item(id)
	var d := {}
	if it.has("charge"):
		d["charge"] = float(it.charge)
	if it.has("spoil_hours"):
		d["fresh"] = 1.0
	return d


## Добавить предметы. Возвращает число НЕ поместившихся.
func add(id: String, n: int = 1, data: Dictionary = {}) -> int:
	if not ItemDB.exists(id) or n <= 0:
		return n
	var stack := ItemDB.stack_size(id)
	var left := n
	if max_weight > 0.0:
		var w := ItemDB.weight(id)
		if w > 0.0:
			var can := int(floor((max_weight + 25.0 - total_weight()) / w))  # перегруз допускается до +25 кг
			left = mini(left, maxi(can, 0))
	var rejected := n - left
	# Дозаполнить существующие стаки (только без индивидуальных данных)
	if stack > 1 and data.is_empty():
		for s in slots:
			if left <= 0:
				break
			if s and s.id == id and int(s.n) < stack:
				var add_n := mini(stack - int(s.n), left)
				s.n = int(s.n) + add_n
				left -= add_n
	# Новые ячейки
	for i in slots.size():
		if left <= 0:
			break
		if slots[i] == null:
			var add_n := mini(stack, left)
			var d := data.duplicate() if not data.is_empty() else default_data(id)
			slots[i] = {"id": id, "n": add_n, "d": d}
			left -= add_n
	changed.emit()
	return left + rejected


## Убрать n предметов (с любых ячеек). Возвращает true, если хватило.
func remove(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	var left := n
	for i in range(slots.size() - 1, -1, -1):
		if left <= 0:
			break
		var s = slots[i]
		if s and s.id == id:
			var take := mini(int(s.n), left)
			s.n = int(s.n) - take
			left -= take
			if int(s.n) <= 0:
				slots[i] = null
	changed.emit()
	return true


func remove_at(i: int, n: int = 1) -> Dictionary:
	var s = slots[i]
	if s == null:
		return {}
	var take := mini(n, int(s.n))
	var out := {"id": s.id, "n": take, "d": s.d.duplicate()}
	s.n = int(s.n) - take
	if int(s.n) <= 0:
		slots[i] = null
	changed.emit()
	return out


## Переместить/объединить/поменять ячейки местами (drag & drop).
func move(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= slots.size() or to >= slots.size():
		return
	var a = slots[from]
	var b = slots[to]
	if a and b and a.id == b.id and a.d.is_empty() and b.d.is_empty():
		var stack := ItemDB.stack_size(a.id)
		var mv := mini(stack - int(b.n), int(a.n))
		b.n = int(b.n) + mv
		a.n = int(a.n) - mv
		if int(a.n) <= 0:
			slots[from] = null
	else:
		slots[from] = b
		slots[to] = a
	changed.emit()


## Переложить ячейку в другой инвентарь (контейнер ↔ игрок).
func transfer_to(i: int, other: Inventory, n: int = -1) -> int:
	var s = slots[i]
	if s == null:
		return 0
	var amount := int(s.n) if n < 0 else mini(n, int(s.n))
	var left := other.add(s.id, amount, s.d if not s.d.is_empty() else {})
	var moved := amount - left
	if moved > 0:
		s.n = int(s.n) - moved
		if int(s.n) <= 0:
			slots[i] = null
		changed.emit()
	return moved


func sort() -> void:
	var items: Array = []
	for s in slots:
		if s:
			items.append(s)
	items.sort_custom(func(x, y):
		var cx := ItemDB.CATEGORY_ORDER.find(ItemDB.category(x.id))
		var cy := ItemDB.CATEGORY_ORDER.find(ItemDB.category(y.id))
		if cx != cy:
			return cx < cy
		return ItemDB.item_name(x.id) < ItemDB.item_name(y.id))
	for i in slots.size():
		slots[i] = items[i] if i < items.size() else null
	changed.emit()


## Порча еды со временем (вызывается раз в игровой час).
func tick_spoil(hours: float) -> void:
	var spoiled := false
	for i in slots.size():
		var s = slots[i]
		if s and s.d.has("fresh"):
			var life := float(ItemDB.item(s.id).get("spoil_hours", 100.0))
			s.d.fresh = float(s.d.fresh) - hours / life
			if float(s.d.fresh) <= 0.0:
				slots[i] = null
				spoiled = true
	if spoiled:
		Events.notify.emit("Часть еды испортилась", "warn")
		changed.emit()


func to_array() -> Array:
	var out: Array = []
	for s in slots:
		out.append(s if s else null)
	return out


func from_array(a: Array) -> void:
	for i in slots.size():
		if i < a.size() and a[i] is Dictionary and ItemDB.exists(str(a[i].get("id", ""))):
			var s: Dictionary = a[i]
			slots[i] = {"id": str(s.id), "n": int(s.get("n", 1)), "d": s.get("d", {})}
		else:
			slots[i] = null
	changed.emit()
