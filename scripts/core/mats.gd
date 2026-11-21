class_name Mats
extends RefCounted
## Библиотека материалов. PBR‑текстуры Poly Haven (CC0): albedo + normal + ARM (AO/Roughness/Metal).
## Каждый материал хранит meta "tile" — размер повтора текстуры в метрах (для MeshKit).

const TEX_DIR := "res://assets/thirdparty/polyhaven/textures/%s/%s_%s.jpg"

## имя -> [id текстуры Poly Haven, метры на повтор, оттенок]
const TEXTURED := {
	"grass": ["withered_grass", 3.0, Color(1, 1, 1)],
	"forest_floor": ["forest_leaves_02", 3.0, Color(1, 1, 1)],
	"gravel": ["gravel_road", 3.0, Color(1, 1, 1)],
	"asphalt": ["road_damaged", 7.0, Color(0.9, 0.9, 0.9)],
	"mud": ["muddy_tracks", 3.0, Color(1, 1, 1)],
	"planks_ext": ["weathered_planks", 2.4, Color(0.9, 0.86, 0.8)],
	"planks_blue": ["blue_painted_planks", 2.4, Color(1, 1, 1)],
	"planks_green": ["blue_painted_planks", 2.4, Color(0.72, 1.0, 0.62)],
	"planks_ochre": ["blue_painted_planks", 2.4, Color(1.0, 0.85, 0.45)],
	"plaster": ["worn_plaster_wall", 3.0, Color(1, 1, 1)],
	"plaster_white": ["white_plaster_rough_01", 2.5, Color(0.92, 0.92, 0.9)],
	"ceiling": ["white_plaster_rough_01", 3.0, Color(0.75, 0.74, 0.72)],
	"brick": ["brick_wall_02", 2.2, Color(1, 1, 1)],
	"wall_int": ["peeling_painted_wall", 2.5, Color(1, 1, 1)],
	"wall_green": ["peeling_painted_wall", 2.5, Color(0.65, 0.85, 0.7)],
	"wallpaper": ["decrepit_wallpaper", 2.0, Color(1, 1, 1)],
	"floor_wood": ["old_planks_02", 2.0, Color(1, 1, 1)],
	"linoleum": ["old_linoleum_flooring_01", 2.0, Color(1, 1, 1)],
	"tiles": ["dirty_tiles", 1.5, Color(1, 1, 1)],
	"roof_iron": ["rusty_corrugated_iron", 2.5, Color(1, 1, 1)],
	"roof_slate": ["corrugated_iron_02", 2.5, Color(0.8, 0.8, 0.78)],
	"metal_rust": ["rusty_painted_metal", 1.6, Color(1, 1, 1)],
	"car_paint_red": ["rusty_painted_metal", 1.6, Color(1.0, 0.55, 0.5)],
	"car_paint_blue": ["rusty_painted_metal", 1.6, Color(0.55, 0.7, 1.0)],
	"car_paint_white": ["rusty_painted_metal", 1.6, Color(1.0, 1.0, 1.0)],
	"car_paint_green": ["rusty_painted_metal", 1.6, Color(0.6, 0.85, 0.55)],
	"bark": ["pine_bark", 1.6, Color(1, 1, 1)],
	"birch_bark": ["pine_bark", 1.6, Color(2.2, 2.2, 2.1)],
	"door": ["rough_pine_door", 2.2, Color(0.9, 0.85, 0.8)],
	"concrete_floor": ["concrete_floor_worn_001", 3.0, Color(1, 1, 1)],
	"concrete": ["concrete_wall_008", 3.0, Color(1, 1, 1)],
	"snow": ["snow_02", 3.0, Color(1, 1, 1)],
}

## Простые цветные материалы: [цвет, шероховатость, металличность]
const PLAIN := {
	"frame_white": [Color(0.78, 0.77, 0.72), 0.8, 0.0],
	"frame_dark": [Color(0.22, 0.18, 0.15), 0.85, 0.0],
	"dark": [Color(0.05, 0.05, 0.05), 0.9, 0.0],
	"metal_dark": [Color(0.18, 0.18, 0.19), 0.55, 0.8],
	"metal_light": [Color(0.55, 0.56, 0.57), 0.45, 0.85],
	"rubber": [Color(0.06, 0.06, 0.06), 0.9, 0.0],
	"red_paint": [Color(0.55, 0.1, 0.08), 0.6, 0.1],
	"white_paint": [Color(0.8, 0.8, 0.78), 0.6, 0.0],
	"chalkboard": [Color(0.12, 0.2, 0.16), 0.95, 0.0],
	"mattress": [Color(0.55, 0.5, 0.42), 0.95, 0.0],
	"blanket": [Color(0.35, 0.16, 0.14), 0.95, 0.0],
	"wood_dark": [Color(0.28, 0.2, 0.14), 0.8, 0.0],
	"wood_light": [Color(0.55, 0.42, 0.3), 0.8, 0.0],
	"stove_white": [Color(0.82, 0.8, 0.74), 0.85, 0.0],
	"fridge": [Color(0.86, 0.86, 0.82), 0.4, 0.1],
	"pine_foliage": [Color(0.13, 0.2, 0.13), 0.95, 0.0],
	"pine_foliage2": [Color(0.16, 0.23, 0.14), 0.95, 0.0],
	"birch_foliage": [Color(0.55, 0.45, 0.18), 0.95, 0.0],
	"birch_foliage2": [Color(0.45, 0.32, 0.12), 0.95, 0.0],
	"grass_blade": [Color(0.46, 0.42, 0.26), 1.0, 0.0],
	"hive_yellow": [Color(0.65, 0.55, 0.25), 0.8, 0.0],
	"hive_blue": [Color(0.3, 0.42, 0.55), 0.8, 0.0],
	"sign_white": [Color(0.85, 0.85, 0.82), 0.7, 0.0],
	"sign_red": [Color(0.6, 0.08, 0.06), 0.6, 0.0],
	"wire": [Color(0.08, 0.08, 0.08), 0.7, 0.5],
	"burned": [Color(0.07, 0.06, 0.055), 0.95, 0.2],
	"sandbag": [Color(0.42, 0.38, 0.28), 1.0, 0.0],
}

static var _cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func get_mat(name: String) -> Material:
	if _cache.has(name):
		return _cache[name]
	var m: Material
	if TEXTURED.has(name):
		m = _textured(name, TEXTURED[name])
	elif PLAIN.has(name):
		var p: Array = PLAIN[name]
		var sm := StandardMaterial3D.new()
		sm.albedo_color = p[0]
		sm.roughness = p[1]
		sm.metallic = p[2]
		sm.set_meta("tile", 1.0)
		m = sm
	elif name == "glass":
		var g := StandardMaterial3D.new()
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.albedo_color = Color(0.25, 0.3, 0.32, 0.35)
		g.roughness = 0.15
		g.metallic = 0.3
		g.set_meta("tile", 1.0)
		m = g
	elif name == "glass_dirty":
		var g2 := StandardMaterial3D.new()
		g2.albedo_color = Color(0.12, 0.13, 0.12)
		g2.roughness = 0.25
		g2.metallic = 0.4
		g2.set_meta("tile", 1.0)
		m = g2
	elif name == "emissive_warm":
		var e := StandardMaterial3D.new()
		e.albedo_color = Color(1.0, 0.75, 0.4)
		e.emission_enabled = true
		e.emission = Color(1.0, 0.6, 0.25)
		e.emission_energy_multiplier = 2.5
		e.set_meta("tile", 1.0)
		m = e
	else:
		push_warning("Mats: неизвестный материал %s" % name)
		var d := StandardMaterial3D.new()
		d.albedo_color = Color.MAGENTA
		m = d
	_cache[name] = m
	return m


static func tex(ph_id: String, kind: String) -> Texture2D:
	var key := ph_id + ":" + kind
	if _tex_cache.has(key):
		return _tex_cache[key]
	var path := TEX_DIR % [ph_id, ph_id, kind]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[key] = t
	return t


static func _textured(_name: String, def: Array) -> StandardMaterial3D:
	var id: String = def[0]
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = tex(id, "albedo")
	sm.albedo_color = def[2]
	var n := tex(id, "normal")
	if n:
		sm.normal_enabled = true
		sm.normal_texture = n
		sm.normal_scale = 0.8
	var arm := tex(id, "arm")
	if arm:
		sm.roughness_texture = arm
		sm.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		sm.roughness = 1.0
		sm.metallic_texture = arm
		sm.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		sm.metallic = 1.0
		sm.ao_enabled = true
		sm.ao_texture = arm
		sm.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		sm.ao_light_affect = 0.6
	else:
		sm.roughness = 0.9
	if sm.albedo_texture == null:
		sm.albedo_color = Color(0.5, 0.48, 0.45) * def[2]
	sm.set_meta("tile", def[1])
	return sm


## Сброс кэша (для смены качества).
static func clear() -> void:
	_cache.clear()
