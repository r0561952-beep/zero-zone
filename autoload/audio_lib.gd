extends Node
## Звуковая библиотека: загрузка и кэш звуков, пул 3D/2D-плееров, варианты (step_dirt → step_dirt_0..3).

const DIR := "res://assets/audio/"
const UI_DIR := "res://assets/thirdparty/kenney/interface-sounds/audio/"
const POOL_3D := 16

var _cache: Dictionary = {}
var _variants: Dictionary = {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _holder: Node3D


func _ready() -> void:
	_holder = Node3D.new()
	_holder.name = "AudioPool"
	add_child(_holder)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 6.0
		p.max_distance = 60.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_holder.add_child(p)
		_pool3d.append(p)
	for i in 6:
		var p2 := AudioStreamPlayer.new()
		p2.bus = "SFX"
		add_child(p2)
		_pool2d.append(p2)


func stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".ogg"
	if name.begins_with("ui:"):
		path = UI_DIR + name.substr(3) + ".ogg"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	if s is AudioStreamOggVorbis and name.ends_with("_loop"):
		(s as AudioStreamOggVorbis).loop = true
	_cache[name] = s
	return s


## Выбирает случайный вариант: "step_dirt" → "step_dirt_2" (если есть).
func variant(name: String) -> AudioStream:
	if not _variants.has(name):
		var list: Array = []
		for i in 6:
			var s := stream("%s_%d" % [name, i])
			if s:
				list.append(s)
		if list.is_empty():
			var s0 := stream(name)
			if s0:
				list.append(s0)
		_variants[name] = list
	var l: Array = _variants[name]
	return null if l.is_empty() else l[randi() % l.size()]


func play_3d(name: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_dist: float = 50.0) -> void:
	var s := variant(name)
	if s == null:
		return
	var best: AudioStreamPlayer3D = null
	for p in _pool3d:
		if not p.playing:
			best = p
			break
	if best == null:
		best = _pool3d[randi() % _pool3d.size()]
	best.stream = s
	best.global_position = pos
	best.volume_db = volume_db
	best.pitch_scale = pitch * randf_range(0.94, 1.06)
	best.max_distance = max_dist
	best.play()


func play_2d(name: String, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "SFX") -> void:
	var s := variant(name)
	if s == null:
		return
	var best: AudioStreamPlayer = null
	for p in _pool2d:
		if not p.playing:
			best = p
			break
	if best == null:
		best = _pool2d[0]
	best.stream = s
	best.volume_db = volume_db
	best.pitch_scale = pitch
	best.bus = bus
	best.play()


func ui(kind: String = "click") -> void:
	var map := {"click": "ui:click_002", "open": "ui:open_001", "close": "ui:close_001", "error": "ui:error_004",
		"select": "ui:select_003", "confirm": "ui:confirmation_002", "drop": "ui:drop_002"}
	play_2d(map.get(kind, "ui:click_002"), -4.0, 1.0, "UI")


## Создать зацикленный 3D‑источник (костёр, трансформатор…), привязанный к узлу.
func make_loop_3d(parent: Node3D, name: String, volume_db: float = 0.0, max_dist: float = 25.0, bus: String = "Ambient") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(name)
	p.volume_db = volume_db
	p.max_distance = max_dist
	p.unit_size = 4.0
	p.bus = bus
	p.autoplay = true
	parent.add_child(p)
	return p
