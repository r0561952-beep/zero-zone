class_name Humanoid
extends Node3D
## Низкополигональная фигура человека с процедурной анимацией ходьбы, бега, удара и сна.
## Временный ассет: архитектура позволяет заменить на скелетную модель (glTF) без изменения ИИ.

var coat := Color(0.25, 0.27, 0.22)
var pants := Color(0.18, 0.18, 0.2)
var skin := Color(0.72, 0.58, 0.48)
var hat := Color(0, 0, 0, 0)
var beard := false
var height := 1.78

var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _torso: Node3D
var _head: Node3D
var _phase := 0.0
var _swing := 0.0
var lying := false


func _ready() -> void:
	var s := height / 1.78
	_torso = Node3D.new()
	_torso.position.y = 0.95 * s
	add_child(_torso)
	_part(_torso, _mat(coat), Vector3(0, 0.28 * s, 0), Vector3(0.42, 0.58, 0.24) * s)
	_part(_torso, _mat(coat), Vector3(0, -0.02 * s, 0), Vector3(0.4, 0.12, 0.23) * s)
	_head = Node3D.new()
	_head.position.y = 0.66 * s
	_torso.add_child(_head)
	_part(_head, _mat(skin), Vector3(0, 0.1 * s, 0), Vector3(0.2, 0.25, 0.22) * s)
	if beard:
		_part(_head, _mat(Color(0.75, 0.74, 0.72)), Vector3(0, 0.0, 0.07 * s), Vector3(0.19, 0.12, 0.1) * s)
	if hat.a > 0.0:
		_part(_head, _mat(hat), Vector3(0, 0.25 * s, 0), Vector3(0.23, 0.1, 0.25) * s)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.11 * side * s, 0.93 * s, 0)
		add_child(leg)
		_part(leg, _mat(pants), Vector3(0, -0.45 * s, 0), Vector3(0.15, 0.88, 0.16) * s)
		_part(leg, _mat(Color(0.1, 0.09, 0.08)), Vector3(0, -0.89 * s, 0.05 * s), Vector3(0.14, 0.08, 0.26) * s)
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(0.27 * side * s, 0.52 * s, 0)
		_torso.add_child(arm)
		_part(arm, _mat(coat), Vector3(0, -0.28 * s, 0), Vector3(0.12, 0.58, 0.13) * s)
		_part(arm, _mat(skin), Vector3(0, -0.6 * s, 0), Vector3(0.09, 0.1, 0.09) * s)
		_arms.append(arm)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _part(parent: Node3D, mat: Material, pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


## speed — м/с; attack — 0..1 (взмах).
func animate(delta: float, speed: float, attack: float = 0.0) -> void:
	if lying:
		rotation.x = lerpf(rotation.x, -PI * 0.5, 0.2)
		position.y = lerpf(position.y, 0.25, 0.2)
		return
	rotation.x = lerpf(rotation.x, 0.0, 0.2)
	position.y = lerpf(position.y, 0.0, 0.2)
	var amp := clampf(speed / 3.0, 0.0, 1.3) * 0.55
	_phase += delta * (2.0 + speed * 2.4)
	var sw := sin(_phase) * amp
	if _legs.size() == 2:
		_legs[0].rotation.x = sw
		_legs[1].rotation.x = -sw
		_arms[0].rotation.x = -sw * 0.8
		_arms[1].rotation.x = sw * 0.8
	if attack > 0.0:
		_arms[1].rotation.x = -2.2 * sin(attack * PI)
	_torso.position.y = 0.95 * height / 1.78 + absf(sin(_phase)) * 0.03 * amp
	_torso.rotation.x = 0.12 if speed > 3.0 else 0.0
	# дыхание в покое
	_head.rotation.x = sin(Time.get_ticks_msec() / 1400.0) * 0.03
