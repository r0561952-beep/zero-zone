class_name HumSystem
extends Node
## Гул «Камертона»: периодическая инфразвуковая волна. Глеб (абсолютный слух) слышит её за ~30 игровых
## минут. Защита: помещение (60%), машина (75%), подвал/убежище (100%), беруши (85%).

const WARN_MIN := 30.0
const DURATION_MIN := 25.0

var _warned := false
var _player: AudioStreamPlayer
var _warn_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.stream = AudioLib.stream("hum_loop")
	_player.bus = "SFX"
	_player.volume_db = -60.0
	add_child(_player)
	_warn_player = AudioStreamPlayer.new()
	_warn_player.stream = AudioLib.stream("hum_warning")
	_warn_player.bus = "SFX"
	add_child(_warn_player)


func _process(delta: float) -> void:
	if not GameState.running:
		return
	var t := GameState.time_min
	if not GameState.is_hum_active():
		if GameState.hum_active_until > 0.0 and t >= GameState.hum_active_until:
			_end()
		elif not _warned and t >= GameState.next_hum_at - WARN_MIN and t < GameState.next_hum_at:
			_warned = true
			Events.hum_warning.emit((GameState.next_hum_at - t) / GameState.minutes_per_second())
			Events.notify.emit("В ушах тонко звенит… Скоро придёт Гул. Нужно укрытие.", "bad")
			_warn_player.play()
		elif t >= GameState.next_hum_at:
			_start()
	var p = GameState.player
	var target_db := -60.0
	if GameState.is_hum_active() and p:
		var prot: float = p.hum_protection()
		if p.survival.earplugs_min > 0.0:
			prot = maxf(prot, 0.85)
		target_db = lerpf(0.0, -28.0, prot)
		Settings.set_ambient_muffle(lerpf(600.0, 4000.0, prot))
	_player.volume_db = lerpf(_player.volume_db, target_db, clampf(delta * 0.8, 0.0, 1.0))
	if not _player.playing and _player.volume_db > -55.0:
		_player.play()
	elif _player.playing and _player.volume_db <= -59.0:
		_player.stop()


func _start() -> void:
	GameState.hum_active_until = GameState.next_hum_at + DURATION_MIN
	GameState.next_hum_at = GameState.hum_active_until + _rng.randf_range(1.6, 3.0) * 1440.0
	_warned = false
	GameState.set_flag("hum_witnessed")
	Events.hum_started.emit()
	Events.notify.emit("ГУЛ. Земля дрожит низким звуком.", "bad")
	Events.hud_flash.emit(Color(0.3, 0.2, 0.1, 0.4))


func _end() -> void:
	GameState.hum_active_until = -1.0
	Settings.set_ambient_muffle(20000.0)
	Events.hum_ended.emit()
	Events.notify.emit("Гул стих.", "info")
