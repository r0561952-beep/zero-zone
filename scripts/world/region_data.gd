class_name RegionData
extends RefCounted
## Данные рельефа региона (генерируются tools/gen_region.py):
## высоты (float32) и маски (R — грунтовка, G — лес, B — вода, A — асфальт).

static var w := 0
static var h := 0
static var cell := 2.0
static var ox := 0.0
static var oz := 0.0
static var heights := PackedFloat32Array()
static var mask := PackedByteArray()
static var mask_image: Image
static var loaded := false


static func ensure_loaded() -> void:
	if loaded:
		return
	var f := FileAccess.open("res://data/region_height.bin", FileAccess.READ)
	if f == null:
		push_error("RegionData: нет region_height.bin — запустите tools/gen_region.py")
		w = 2
		h = 2
		heights.resize(4)
		mask.resize(16)
		loaded = true
		return
	w = f.get_32()
	h = f.get_32()
	cell = f.get_float()
	ox = f.get_float()
	oz = f.get_float()
	heights = f.get_buffer(w * h * 4).to_float32_array()
	var fm := FileAccess.open("res://data/region_mask.bin", FileAccess.READ)
	fm.get_32()
	fm.get_32()
	mask = fm.get_buffer(w * h * 4)
	mask_image = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, mask)
	loaded = true


static func _hraw(ix: int, iz: int) -> float:
	ix = clampi(ix, 0, w - 1)
	iz = clampi(iz, 0, h - 1)
	return heights[iz * w + ix]


## Высота рельефа в точке (билинейная интерполяция).
static func height_at(x: float, z: float) -> float:
	var fx := (x - ox) / cell
	var fz := (z - oz) / cell
	var ix := int(floor(fx))
	var iz := int(floor(fz))
	var tx := fx - ix
	var tz := fz - iz
	var a := _hraw(ix, iz)
	var b := _hraw(ix + 1, iz)
	var c := _hraw(ix, iz + 1)
	var d := _hraw(ix + 1, iz + 1)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


static func normal_at(x: float, z: float) -> Vector3:
	var e := cell
	var hl := height_at(x - e, z)
	var hr := height_at(x + e, z)
	var hd := height_at(x, z - e)
	var hu := height_at(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


## Маска (0..1 по каналам) в точке, ближайшая ячейка.
static func mask_at(x: float, z: float) -> Color:
	var ix := clampi(int(round((x - ox) / cell)), 0, w - 1)
	var iz := clampi(int(round((z - oz) / cell)), 0, h - 1)
	var i := (iz * w + ix) * 4
	if i + 3 >= mask.size():
		return Color(0, 0, 0, 0)
	return Color(mask[i] / 255.0, mask[i + 1] / 255.0, mask[i + 2] / 255.0, mask[i + 3] / 255.0)


static func in_bounds(x: float, z: float, margin: float = 0.0) -> bool:
	return x > ox + margin and z > oz + margin and x < ox + (w - 1) * cell - margin and z < oz + (h - 1) * cell - margin
