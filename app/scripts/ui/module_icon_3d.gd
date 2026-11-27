# Fretboard Master – ikona 3D modułu w kafelku menu (assets/models/module-icons.glb od autora).
#  • Wszystkie ikony delikatnie kołyszą się i pochylają w stronę kursora (jak logo); każda z
#    innym przesunięciem fazy i nieco inną szybkością, więc ruch przechodzi po nich falą.
#  • Po najechaniu na kafel (spin = true) ikona wyraźnie obraca się wokół osi pionowej; po zjechaniu
#    kończy rozpoczęty obrót i płynnie zatrzymuje się frontem do widza.
#  • Po IDLE_STOP s bez ruchu myszy ikona wraca do spoczynku, przetwarzanie i odświeżanie stają.
# Materiały i oświetlenie – dokładnie te same co w logo 3D (Logo3D.material, Logo3D.add_lighting).
# Optymalizacja: plik wczytywany raz; warstwy każdej ikony scalane w jedną siatkę z trzema
# powierzchniami (tafla, obwódka, symbol), współdzieloną przez wszystkie wystąpienia.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name ModuleIcon3D
extends SubViewportContainer

const MODEL_PATH := "res://assets/models/module-icons.glb"
# Moduł → przedrostek nazw warstw w pliku („<przedrostek>-krawedz/-obrys/-podkladka/-symbol”).
const PREFIX := {
	&"encyclopedia": "encyklopedia", &"trainers": "cwiczenia", &"reading": "czytanie-nut",
	&"tuning": "tuner", &"metronome": "metronom", &"plan": "plan-cwiczen", &"progress": "postepy",
	&"looper": "looper",
}
# Warstwa → część logo (ten sam materiał): ciemna tafla, pomarańczowa obwódka, pomarańczowy symbol.
const LAYER_PART := {"krawedz": &"panel", "podkladka": &"panel", "obrys": &"frame", "symbol": &"orange"}

const SWAY_DEG := Vector2(2.2, 3.5)
const SWAY_PERIOD := Vector2(5.3, 7.1)
const CURSOR_DEG := Vector2(9.0, 14.0)
const FOLLOW := 5.0
const IDLE_STOP := 8.0
const SPIN_SPEED := 300.0     # °/s przy obrocie po najechaniu
const SPIN_ACCEL := 900.0     # °/s² – rozpędzanie
const FOV := 22.0

static var _meshes := {}      # przedrostek → ArrayMesh
static var _sizes := {}       # przedrostek → Vector3

var module_id: StringName
var index := 0                # kolejność kafla – przesunięcie fazy kołysania
var spin := false:
	set(v):
		spin = v
		_wake()

var _vp: SubViewport
var _pivot: Node3D
var _time := 0.0
var _idle := 0.0
var _amp := 1.0
var _rot := Vector2.ZERO
var _angle := 0.0
var _speed := 0.0
var _sway := true
var _live := true


static func available(id: StringName) -> bool:
	return PREFIX.has(id) and ResourceLoader.exists(MODEL_PATH)


static func create(p_id: StringName, p_min: Vector2, p_index := 0) -> ModuleIcon3D:
	var c := ModuleIcon3D.new()
	c.module_id = p_id
	c.index = p_index
	c.custom_minimum_size = p_min
	c.stretch = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	if _meshes.is_empty():
		_build_meshes()
	var prefix: String = PREFIX.get(module_id, "")
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Graphics.msaa_mode()
	_vp.positional_shadow_atlas_size = 0
	_vp.audio_listener_enable_3d = false
	_vp.gui_disable_input = true
	add_child(_vp)
	Logo3D.add_lighting(_vp)

	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes.get(prefix)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(mi)

	var cam := Camera3D.new()
	cam.fov = FOV
	_vp.add_child(cam)
	_fit_camera(cam, _sizes.get(prefix, Vector3.ONE * 0.05))
	resized.connect(_fit_camera.bind(cam, _sizes.get(prefix, Vector3.ONE * 0.05)))

	var audit := "--perf-audit" in OS.get_cmdline_user_args()
	_live = not audit and App.animations() != "off"
	_sway = App.animations() == "full"
	if not _sway:
		_amp = 0.0
	_time = index * 1.7
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _live else SubViewport.UPDATE_ONCE
	set_process(_live)
	set_process_input(_live)


func _process(delta: float) -> void:
	_time += delta
	_idle += delta
	var active := _idle < IDLE_STOP and _sway
	_amp = move_toward(_amp, 1.0 if active else 0.0, delta * 0.5)
	var target := Vector2(
			sin(_time * TAU / SWAY_PERIOD.x) * SWAY_DEG.x,
			sin(_time * TAU / SWAY_PERIOD.y) * SWAY_DEG.y) * _amp
	if active:
		target += _cursor_tilt() * minf(_amp * 2.0, 1.0)
	# Każdy kolejny kafel dochodzi do pozycji nieco wolniej – ruch biegnie po ikonach falą.
	_rot = _rot.lerp(target, 1.0 - exp(-(FOLLOW - index * 0.4) * delta))

	if spin:
		_speed = move_toward(_speed, SPIN_SPEED, SPIN_ACCEL * delta)
		_angle += _speed * delta
	elif _angle != 0.0:
		# Dokończenie obrotu do najbliższej pełnej wielokrotności 360° z łagodnym hamowaniem.
		var goal := ceilf(_angle / 360.0) * 360.0
		var left := goal - _angle
		_speed = clampf(left * 4.0, 40.0, maxf(_speed, 40.0))
		_angle = minf(_angle + _speed * delta, goal)
		if _angle >= goal:
			_angle = 0.0
			_speed = 0.0
	_pivot.rotation_degrees = Vector3(_rot.x, _rot.y + fmod(_angle, 360.0), 0)

	if not active and not spin and _angle == 0.0 and _amp == 0.0 and _rot.length() < 0.02:
		_pivot.rotation_degrees = Vector3.ZERO
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		set_process(false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_idle = 0.0
		_wake()


func _wake() -> void:
	if _live and _vp and not is_processing():
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		set_process(true)


func _cursor_tilt() -> Vector2:
	var rel := (get_global_mouse_position() - get_global_rect().get_center()) / (get_viewport_rect().size * 0.5)
	rel = rel.clamp(-Vector2.ONE, Vector2.ONE)
	return Vector2(rel.y * CURSOR_DEG.x, rel.x * CURSOR_DEG.y)


func _fit_camera(cam: Camera3D, sz: Vector3) -> void:
	var aspect := maxf(size.x, 1.0) / maxf(size.y, 1.0)
	var half_v := deg_to_rad(FOV) * 0.5
	var half_h := atan(tan(half_v) * aspect)
	# Zapas na kołysanie; przy obrocie szerokość się nie zwiększa.
	var dist := maxf(sz.x * 0.56 / tan(half_h), sz.y * 0.56 / tan(half_v)) + sz.z
	cam.position = Vector3(0, 0, dist)
	cam.near = maxf(dist - sz.x, 0.001)
	cam.far = dist + sz.x
	if _vp and not is_processing():
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# Jednorazowo: każda ikona jako osobna siatka, frontem do kamery (+Z), wyśrodkowana.
# W pliku ikony leżą płasko w płaszczyźnie XZ (przód +Y, góra rysunku −Z) – obrót o 90° wokół X.
static func _build_meshes() -> void:
	var root := (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	var orient := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	var tools := {}     # przedrostek → {część → SurfaceTool}
	var boxes := {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var name := str(mi.name)
		var cut := name.rfind("-")
		if cut < 0 or mi.mesh == null:
			continue
		var prefix := name.substr(0, cut)
		var part: StringName = LAYER_PART.get(name.substr(cut + 1), &"orange")
		var xf := orient * _local_xform(root, mi)
		if not tools.has(prefix):
			tools[prefix] = {}
		var parts: Dictionary = tools[prefix]
		if not parts.has(part):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			parts[part] = st
		for s in mi.mesh.get_surface_count():
			(parts[part] as SurfaceTool).append_from(mi.mesh, s, xf)
		var b := xf * mi.mesh.get_aabb()
		boxes[prefix] = boxes[prefix].merge(b) if boxes.has(prefix) else b
	root.free()
	for prefix in tools:
		var mesh := ArrayMesh.new()
		var center: Vector3 = (boxes[prefix] as AABB).get_center()
		for part in [&"panel", &"frame", &"orange"]:
			if not (tools[prefix] as Dictionary).has(part):
				continue
			var arrays := ((tools[prefix] as Dictionary)[part] as SurfaceTool).commit_to_arrays()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] -= center
			arrays[Mesh.ARRAY_VERTEX] = verts
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, Logo3D.material(part))
		_meshes[prefix] = mesh
		_sizes[prefix] = (boxes[prefix] as AABB).size


static func _local_xform(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
