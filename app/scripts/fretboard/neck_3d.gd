# Fretboard Master – realistyczny gryf 3D (wg zaakceptowanej makiety z 27.11.2026).
# Cała geometria budowana w kodzie: podstrunnica (drewno shaderem, obszycie, boki szyjki), siodełko,
# progi (jedna siatka), wkładki (jedna siatka), struny (jedna siatka, powierzchnia na rodzaj struny)
# i znaczniki dźwięków – lekko wypukłe krążki rysowane instancyjnie (MultiMesh: obwódka + krążek).
# Napisy na znacznikach rysuje nakładka 2D (FretboardView) – bez osobnych węzłów tekstu.
# Scena jest statyczna: SubViewport rysuje ją tylko po zmianie (UPDATE_ONCE).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name Neck3D
extends Node3D

const WOOD_SHADER := """
shader_type spatial;
uniform vec3 c_dark : source_color;
uniform vec3 c_light : source_color;
uniform vec3 c_neck : source_color;
uniform vec3 c_bind : source_color;
uniform float binding_w = 0.0;
uniform float nut_w = 44.0;
uniform float w_slope = 0.03;
uniform float board_t = 6.0;
varying vec3 p;
varying vec3 n;
float h(vec2 q){ return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 q){ vec2 i = floor(q), f = fract(q); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
float fbm(vec2 q){ float s = 0.0, a = 0.5; for (int k = 0; k < 5; k++){ s += a*vn(q); q *= 2.03; a *= 0.5; } return s; }
void vertex(){ p = VERTEX; n = NORMAL; }
void fragment(){
	vec2 q = vec2(p.x*0.018, p.z*0.55);
	float w = fbm(q + vec2(fbm(q*vec2(0.5, 2.0))*1.5, 0.0));
	float lines = 0.5 + 0.5*sin(p.z*3.1 + w*9.0 + sin(p.x*0.02)*2.0);
	float t = clamp(w*0.9 + lines*0.30 - 0.22, 0.0, 1.0);
	vec3 col = mix(c_dark, c_light, t);
	float pores = smoothstep(0.80, 0.97, vn(vec2(p.x*0.9, p.z*7.0)));
	col *= 1.0 - pores*0.45;
	float half_w = 0.5*(nut_w + w_slope*p.x);
	if (binding_w > 0.0 && abs(p.z) > half_w - binding_w) col = c_bind;
	if (n.y < 0.5) {
		col = (p.y > -board_t) ? (binding_w > 0.0 ? c_bind : col*0.8) : c_neck*(0.7 + 0.3*fbm(vec2(p.x*0.05, p.y*0.4)));
	}
	ALBEDO = col;
	ROUGHNESS = 0.55;
	SPECULAR = 0.25;
}
"""

const STRING_SHADER := """
shader_type spatial;
uniform vec3 base : source_color;
uniform float metal = 1.0;
uniform float rough = 0.3;
uniform float pitch = 0.0;
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float s = 1.0;
	if (pitch > 0.0) s = 0.78 + 0.22*abs(sin(wp.x*3.14159/pitch));
	ALBEDO = base*s;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = 0.6;
}
"""

const PEARL_SHADER := """
shader_type spatial;
uniform vec3 tint : source_color = vec3(1.0);
uniform float pearl = 1.0;
varying vec3 p;
float h(vec2 q){ return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 q){ vec2 i = floor(q), f = fract(q); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
void vertex(){ p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float a = vn(p.xz*0.9) * 0.6 + vn(p.xz*2.7) * 0.4;
	float b = 0.5 + 0.5*sin(a*12.0 + p.x*0.4);
	vec3 col = mix(vec3(0.55, 0.57, 0.60), vec3(0.82, 0.80, 0.76), b);
	col += vec3(0.05, -0.02, 0.06) * sin(a*20.0);
	ALBEDO = mix(tint, col, pearl);
	ROUGHNESS = 0.2;
	SPECULAR = 0.7;
}
"""

# Rodzaje strun: [kolor, metaliczność, chropowatość, skok owijki (0 = gładka)].
const STRING_LOOK := {
	"nylon": [Color("#EDE8DA"), 0.0, 0.25, 0.0],
	"silver": [Color("#D9D9DC"), 1.0, 0.32, 0.55],
	"steel": [Color("#E2E2E4"), 1.0, 0.18, 0.0],
	"bronze": [Color("#D2A465"), 1.0, 0.30, 0.6],
	"nickel": [Color("#DADADA"), 1.0, 0.20, 0.0],
	"nickelw": [Color("#CFCFD2"), 1.0, 0.32, 0.55],
	"black": [Color("#2A2A2E"), 0.6, 0.45, 0.0],
}

var spec: NeckSpec
var cam: Camera3D
var _marker_mesh: ArrayMesh
var _rims: MultiMeshInstance3D
var _discs: MultiMeshInstance3D
var _markers: Array = []      # [{pos: Vector3 (wierzch krążka), r: float, note: Dictionary}]


func build(neck: NeckSpec) -> void:
	spec = neck
	_environment()
	_board()
	_nut()
	_frets()
	_inlays()
	_strings()
	_marker_mesh = _make_marker_mesh()
	_rims = _multimesh(_flat_material(Color("#0B0F1C"), 0.6))
	var mat := _flat_material(Color.WHITE, 0.22)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.metallic_specular = 0.75
	_discs = _multimesh(mat)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 20.0
	cam.far = 20000.0
	add_child(cam)


# --- Kamera -------------------------------------------------------------------

# Dopasowanie: cały gryf (od pustych strun do końca podstrunnicy) w prostokącie `region`
# obrazu o rozmiarze `size` (piksele), przy danym pochyleniu i kącie widzenia (poziomym).
func fit_camera(size: Vector2, region: Rect2, tilt_deg: float, fov_deg: float) -> void:
	var x_min := spec.marker_x(0) - spec.marker_r - 1.0
	var span_x := spec.x_end - x_min
	var t := deg_to_rad(clampf(tilt_deg, 0.0, 70.0))
	var depth := spec.half_w(spec.x_end) * 2.0 * cos(t) + 22.0 * sin(t) + 6.0
	var upp := maxf(span_x / maxf(region.size.x, 1.0), depth / maxf(region.size.y, 1.0))
	cam.fov = clampf(fov_deg, 5.0, 120.0)
	var dist := upp * size.x * 0.5 / tan(deg_to_rad(cam.fov * 0.5))
	var target := Vector3(x_min + span_x * 0.5, 0, 0)
	if t < 0.001:
		cam.look_at_from_position(target + Vector3(0, dist, 0), target, Vector3.FORWARD)
	else:
		cam.look_at_from_position(target + Vector3(0, dist * cos(t), dist * sin(t)), target)
	var c := region.get_center()
	cam.h_offset = -(c.x - size.x * 0.5) * upp
	cam.v_offset = (c.y - size.y * 0.5) * upp


func project(p: Vector3) -> Vector2:
	return cam.unproject_position(p)


# --- Znaczniki dźwięków ---------------------------------------------------------

# notes: [{s, f, text, root, dim}] – s: struna (0 = najwyższa), f: próg (0 = pusta struna).
func set_notes(notes: Array) -> void:
	_markers.clear()
	for n in notes:
		var s: int = n.s
		var f: int = n.f
		if s < 0 or s >= spec.strings or f < 0 or f > spec.frets:
			continue
		var r := spec.marker_radius(f)
		var x := spec.marker_x(f)
		var xs := maxf(x, 0.0)
		var y := spec.string_y(s, xs) + spec.gauge(s) * 0.6 + 0.1
		_markers.append({"pos": Vector3(x, y, spec.string_z(s, xs)), "r": r, "note": n})
	var mm_r := _rims.multimesh
	var mm_d := _discs.multimesh
	mm_r.instance_count = _markers.size()
	mm_d.instance_count = _markers.size()
	for i in _markers.size():
		var m: Dictionary = _markers[i]
		var r: float = m.r
		var p: Vector3 = m.pos
		mm_r.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r * 1.12, r * 0.6, r * 1.12)), p - Vector3(0, 0.25, 0)))
		mm_d.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r, r, r)), p))
		var col: Color = NeckSpec.note_color(m.note.get("root", false)).darkened(0.12)
		if m.note.get("dim", false):
			col = col.lerp(Color("#1A1F2E"), 0.7)
		mm_d.set_instance_color(i, col)


# Środek wierzchu krążka i jego promień – do napisów w nakładce.
func markers() -> Array:
	return _markers


# --- Budowa sceny ----------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#9AA6C8")
	sm.sky_horizon_color = Color("#D8D2C8")
	sm.ground_bottom_color = Color("#101420")
	sm.ground_horizon_color = Color("#5A5650")
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.look_at_from_position(Vector3(-260, 520, 300), Vector3.ZERO)
	sun.light_energy = 0.95
	sun.light_color = Color("#FFF2E0")
	var shadows := str(App.setting(&"shadows"))
	sun.shadow_enabled = shadows != "off"
	if sun.shadow_enabled:
		var atlas: int = {"low": 2048, "medium": 4096, "high": 8192}.get(shadows, 4096)
		RenderingServer.directional_shadow_atlas_set_size(atlas, true)
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 1800.0
		sun.shadow_bias = 0.03
		sun.shadow_normal_bias = 0.4
		sun.shadow_blur = 1.5
	var fill := DirectionalLight3D.new()
	add_child(fill)
	fill.look_at_from_position(Vector3(300, 300, -200), Vector3.ZERO)
	fill.light_energy = 0.35
	fill.light_color = Color("#C8D4FF")


func _shader_material(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _flat_material(col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m


func _add_mesh(mesh: Mesh, mat: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _board() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 120
	var nz := 24
	var x_end := spec.x_end
	for i in nx:
		var xa := x_end * float(i) / nx
		var xb := x_end * float(i + 1) / nx
		for j in nz:
			var ta := float(j) / nz * 2.0 - 1.0
			var tb := float(j + 1) / nz * 2.0 - 1.0
			var za := ta * spec.half_w(xa)
			var zb := tb * spec.half_w(xa)
			var zc := ta * spec.half_w(xb)
			var zd := tb * spec.half_w(xb)
			var p00 := Vector3(xa, spec.board_y(za), za)
			var p01 := Vector3(xa, spec.board_y(zb), zb)
			var p10 := Vector3(xb, spec.board_y(zc), zc)
			var p11 := Vector3(xb, spec.board_y(zd), zd)
			for v in [p00, p10, p11, p00, p11, p01]:
				st.set_normal(spec.board_normal(v.z))
				st.add_vertex(v)
	# Boki podstrunnicy i szyjki oraz czoło na końcu podstrunnicy.
	var depth := 22.0
	for side in [-1.0, 1.0]:
		for i in nx:
			var xa := x_end * float(i) / nx
			var xb := x_end * float(i + 1) / nx
			var za: float = side * spec.half_w(xa)
			var zb: float = side * spec.half_w(xb)
			var a_top := Vector3(xa, spec.board_y(za), za)
			var b_top := Vector3(xb, spec.board_y(zb), zb)
			var a_bot := Vector3(xa, -depth, za * 0.92)
			var b_bot := Vector3(xb, -depth, zb * 0.92)
			var quad := [a_top, b_top, b_bot, a_top, b_bot, a_bot] if side > 0 else [a_top, b_bot, b_top, a_top, a_bot, b_bot]
			for v in quad:
				st.set_normal(Vector3(0, 0, side))
				st.add_vertex(v)
	for j in nz:
		var za := (float(j) / nz * 2.0 - 1.0) * spec.half_w(x_end)
		var zb := (float(j + 1) / nz * 2.0 - 1.0) * spec.half_w(x_end)
		var a := Vector3(x_end, spec.board_y(za), za)
		var b := Vector3(x_end, spec.board_y(zb), zb)
		var c := Vector3(x_end, -NeckSpec.BOARD_T, zb)
		var d := Vector3(x_end, -NeckSpec.BOARD_T, za)
		for v in [a, c, b, a, d, c]:
			st.set_normal(Vector3.RIGHT)
			st.add_vertex(v)
	var m := _shader_material(WOOD_SHADER)
	m.set_shader_parameter("c_dark", spec.wood[0])
	m.set_shader_parameter("c_light", spec.wood[1])
	m.set_shader_parameter("c_neck", spec.neck_col)
	m.set_shader_parameter("c_bind", NeckSpec.BINDING)
	m.set_shader_parameter("binding_w", spec.bind)
	m.set_shader_parameter("nut_w", spec.nut_w)
	m.set_shader_parameter("w_slope", (spec.w12 - spec.nut_w) / (spec.L * 0.5))
	m.set_shader_parameter("board_t", NeckSpec.BOARD_T)
	_add_mesh(st.commit(), m)


func _nut() -> void:
	var box := BoxMesh.new()
	var top: float = spec.g.h_nut - 0.2
	box.size = Vector3(NeckSpec.NUT_LEN, top + 7.0, spec.nut_w)
	var mi := _add_mesh(box, _flat_material(spec.g.nut_col, 0.45))
	mi.position = Vector3(-NeckSpec.NUT_LEN * 0.5, (top - 7.0) * 0.5, 0)


func _frets() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 10
	var nz := 20
	var cw: float = spec.g.fret_r
	var ch: float = spec.g.fret_h
	for n in range(1, spec.frets + 1):
		var x := spec.xf(n)
		var hw := spec.half_w(x) - (0.3 if spec.bind > 0.0 else 0.0)
		for j in nz:
			var za := lerpf(-hw, hw, float(j) / nz)
			var zb := lerpf(-hw, hw, float(j + 1) / nz)
			for k in seg:
				var a0 := PI * float(k) / seg
				var a1 := PI * float(k + 1) / seg
				var pts := []
				for pair in [[za, a0], [za, a1], [zb, a1], [zb, a0]]:
					var z: float = pair[0]
					var an: float = pair[1]
					pts.append([Vector3(x + cw * cos(an), spec.board_y(z) + ch * sin(an), z),
							Vector3(cos(an) * ch, sin(an) * cw, 0).normalized()])
				for idx in [0, 2, 1, 0, 3, 2]:
					st.set_normal(pts[idx][1])
					st.add_vertex(pts[idx][0])
	var m := _flat_material(spec.fret_col, 0.16)
	m.metallic = 1.0
	_add_mesh(st.commit(), m)


func _inlays() -> void:
	if spec.inlays == "none":
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in spec.inlay_frets():
		var cx := (spec.xf(f - 1) + spec.xf(f)) * 0.5
		var cell := spec.xf(f) - spec.xf(f - 1)
		match spec.inlays:
			"dots": _disc_flat(st, Vector3(cx, 0, 0), 2.6)
			"blocks": _block(st, cx, cell, 0.0)
			_: _block(st, cx, cell, 0.22)
	for f in spec.double_dot_frets():
		var cx := (spec.xf(f - 1) + spec.xf(f)) * 0.5
		var mid := spec.strings / 2
		for s in [mid - 2, mid]:
			var z := (spec.string_z(s, cx) + spec.string_z(s + 1, cx)) * 0.5
			_disc_flat(st, Vector3(cx, 0, z), 2.6)
	var m := _shader_material(PEARL_SHADER)
	if spec.wood == NeckSpec.WOODS.maple:
		m.set_shader_parameter("tint", Color("#1A1714"))
		m.set_shader_parameter("pearl", 0.0)
	_add_mesh(st.commit(), m, false)


func _disc_flat(st: SurfaceTool, c: Vector3, r: float) -> void:
	var seg := 32
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var pts := [c, c + Vector3(cos(a0) * r, 0, sin(a0) * r), c + Vector3(cos(a1) * r, 0, sin(a1) * r)]
		for v: Vector3 in pts:
			v.y = spec.board_y(v.z) + 0.08
			st.set_normal(spec.board_normal(v.z))
			st.add_vertex(v)


# Wkładka prostokątna (waist = 0) albo trapezowa – węższa pośrodku, szersza przy krawędziach.
func _block(st: SurfaceTool, cx: float, cell: float, waist: float) -> void:
	var hz := spec.half_w(cx) * 0.66
	var rows := 12
	var wide := minf(cell * 0.30, 9.0)
	var narrow := wide * (1.0 - waist)
	for j in rows:
		var ta := float(j) / rows * 2.0 - 1.0
		var tb := float(j + 1) / rows * 2.0 - 1.0
		var wa := lerpf(narrow, wide, pow(absf(ta), 1.6))
		var wb := lerpf(narrow, wide, pow(absf(tb), 1.6))
		var za := ta * hz
		var zb := tb * hz
		var pts := [Vector3(cx - wa, 0, za), Vector3(cx + wa, 0, za), Vector3(cx + wb, 0, zb), Vector3(cx - wb, 0, zb)]
		for idx in [0, 1, 2, 0, 2, 3]:
			var v: Vector3 = pts[idx]
			v.y = spec.board_y(v.z) + 0.08
			st.set_normal(spec.board_normal(v.z))
			st.add_vertex(v)


# Wszystkie struny w jednej siatce – osobna powierzchnia (materiał) dla każdego rodzaju struny.
func _strings() -> void:
	var groups := {}
	for s in spec.strings:
		var kind := spec.string_material(s)
		if not groups.has(kind):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[kind] = st
		var d := spec.gauge(s) * 1.25
		var x1 := spec.x_end + 2.0
		var a := Vector3(0.0, spec.string_y(s, 0.0), spec.string_z(s, 0.0))
		var b := Vector3(x1, spec.string_y(s, x1), spec.string_z(s, x1))
		var ax := (b - a).normalized()
		var side := ax.cross(Vector3.UP).normalized()
		var up := side.cross(ax).normalized()
		var seg := 14
		for k in seg:
			var a0 := TAU * k / seg
			var a1 := TAU * (k + 1) / seg
			var n0 := up * cos(a0) + side * sin(a0)
			var n1 := up * cos(a1) + side * sin(a1)
			var r := d * 0.5
			var q := [[a + n0 * r, n0], [b + n0 * r, n0], [b + n1 * r, n1], [a + n1 * r, n1]]
			for idx in [0, 1, 2, 0, 2, 3]:
				(groups[kind] as SurfaceTool).set_normal(q[idx][1])
				(groups[kind] as SurfaceTool).add_vertex(q[idx][0])
	var mesh := ArrayMesh.new()
	var i := 0
	for kind in groups:
		(groups[kind] as SurfaceTool).commit(mesh)
		var look: Array = STRING_LOOK[kind]
		var m := _shader_material(STRING_SHADER)
		m.set_shader_parameter("base", look[0])
		m.set_shader_parameter("metal", look[1])
		m.set_shader_parameter("rough", look[2])
		m.set_shader_parameter("pitch", look[3])
		mesh.surface_set_material(i, m)
		i += 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)


func _multimesh(mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _marker_mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


# Krążek o promieniu 1: bok 0–0,16, wypukła czasza do 0,58 (połysk z góry podkreśla wypukłość).
func _make_marker_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 40
	var rings := 8
	var side_h := 0.16
	var dome := 0.42
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var q := [d0, d1, d1 + Vector3(0, side_h, 0), d0 + Vector3(0, side_h, 0)]
		var nn := [d0, d1, d1, d0]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(nn[idx])
			st.add_vertex(q[idx])
		for r in rings:
			var ra := 1.0 - float(r) / rings
			var rb := 1.0 - float(r + 1) / rings
			var ya := side_h + dome * (1.0 - ra * ra)
			var yb := side_h + dome * (1.0 - rb * rb)
			var v := [d0 * ra + Vector3(0, ya, 0), d1 * ra + Vector3(0, ya, 0), d1 * rb + Vector3(0, yb, 0), d0 * rb + Vector3(0, yb, 0)]
			var vn := [_dome_n(d0, ra, dome), _dome_n(d1, ra, dome), _dome_n(d1, rb, dome), _dome_n(d0, rb, dome)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(vn[idx])
				st.add_vertex(v[idx])
	return st.commit()


func _dome_n(d: Vector3, r: float, dome: float) -> Vector3:
	return Vector3(d.x * 2.0 * dome * r, 1.0, d.z * 2.0 * dome * r).normalized()
