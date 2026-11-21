class_name GrassField
extends MultiMeshInstance3D
## Бурьян и пожухлая трава вокруг игрока (14 месяцев без людей — всё заросло).
## Детерминированная сетка: при движении трава не «плывёт», а досыпается по клеткам. Ветер — в шейдере.

const CELL := 1.35
const MAX_INSTANCES := 3200

var focus: Node3D
var no_grass: Array = []        ## Rect2 — пятна зданий (внутри трава не растёт)
var _last := Vector3(INF, 0, INF)
var _radius := 30.0


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _clump_mesh()
	mm.instance_count = MAX_INSTANCES
	mm.visible_instance_count = 0
	multimesh = mm
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform float wind = 0.35;
varying float v_var;
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float s = sin(TIME * 1.6 + wp.x * 0.35 + wp.z * 0.21) * wind * h * h * 0.35;
	VERTEX.x += s;
	VERTEX.z += s * 0.6;
	v_var = fract(sin(dot(wp.xz, vec2(12.9898, 78.233))) * 43758.5453);
	NORMAL = normalize(vec3(0.0, 1.0, 0.0) + NORMAL * 0.3);
}
void fragment() {
	vec3 c = COLOR.rgb * mix(0.75, 1.15, v_var);
	c = mix(c, c * vec3(1.05, 0.9, 0.75), step(0.7, v_var));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	BACKLIGHT = vec3(0.15, 0.13, 0.08);
}
"""
	sm.shader = sh
	material_override = sm
	Events.settings_changed.connect(func(): _last = Vector3(INF, 0, INF))


func _clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var base := Color(0.2, 0.18, 0.1)
	for i in 9:
		var a := rng.randf() * TAU
		var h := rng.randf_range(0.35, 0.95)
		var w := rng.randf_range(0.035, 0.06)
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.22)
		var dir := Vector3(cos(a + 1.57), 0, sin(a + 1.57))
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.05, 0.3)
		var tip_col := Color(0.62, 0.55, 0.34).lerp(Color(0.48, 0.45, 0.28), rng.randf())
		var p0 := off - dir * w
		var p1 := off + dir * w
		var p2 := off + lean * 0.6 + Vector3.UP * h * 0.55 + dir * w * 0.6
		var p3 := off + lean * 0.6 + Vector3.UP * h * 0.55 - dir * w * 0.6
		var p4 := off + lean + Vector3.UP * h
		var n := dir.cross(Vector3.UP).normalized()
		for tri in [[p0, p3, p1], [p1, p3, p2], [p3, p4, p2]]:
			for v in tri:
				st.set_normal(n)
				var t: float = clampf((v as Vector3).y / h, 0.0, 1.0)
				st.set_color(base.lerp(tip_col, t))
				st.add_vertex(v)
	return st.commit()


func _process(_delta: float) -> void:
	if focus == null or not visible:
		return
	var p := focus.global_position
	if Vector2(p.x - _last.x, p.z - _last.z).length() > 4.0:
		_rebuild(p)


func _blocked(x: float, z: float) -> bool:
	for r in no_grass:
		if (r as Rect2).has_point(Vector2(x, z)):
			return true
	return false


func _rebuild(center: Vector3) -> void:
	_last = center
	var dens := clampf(Settings.vegetation, 0.0, 1.0)
	if dens < 0.4:
		multimesh.visible_instance_count = 0
		return
	_radius = 22.0 + 14.0 * dens
	var mm := multimesh
	var n := 0
	var c0x := int(floor((center.x - _radius) / CELL))
	var c1x := int(ceil((center.x + _radius) / CELL))
	var c0z := int(floor((center.z - _radius) / CELL))
	var c1z := int(ceil((center.z + _radius) / CELL))
	var r2 := _radius * _radius
	for cz in range(c0z, c1z):
		for cx in range(c0x, c1x):
			var hsh := hash(Vector2i(cx, cz))
			var r1 := float(hsh & 0xFFFF) / 65535.0
			var r2b := float((hsh >> 16) & 0xFFFF) / 65535.0
			var x := (cx + r1) * CELL
			var z := (cz + r2b) * CELL
			var dx := x - center.x
			var dz := z - center.z
			if dx * dx + dz * dz > r2:
				continue
			var m := RegionData.mask_at(x, z)
			var chance := 0.85 - m.g * 0.55
			if m.r > 0.35 or m.a > 0.15 or m.b > 0.25:
				chance = 0.04
			if r1 * 0.7 + r2b * 0.3 > chance * dens + 0.05:
				continue
			if _blocked(x, z):
				continue
			var y := RegionData.height_at(x, z) - 0.03
			var sc := 0.7 + r2b * 0.8
			var b := Basis(Vector3.UP, r1 * TAU).scaled(Vector3(sc, sc * (0.8 + r1 * 0.6), sc))
			mm.set_instance_transform(n, Transform3D(b, Vector3(x, y, z)))
			n += 1
			if n >= MAX_INSTANCES:
				break
		if n >= MAX_INSTANCES:
			break
	mm.visible_instance_count = n
	# AABB — вокруг игрока
	custom_aabb = AABB(center - Vector3(_radius + 2, 30, _radius + 2), Vector3((_radius + 2) * 2, 60, (_radius + 2) * 2))
