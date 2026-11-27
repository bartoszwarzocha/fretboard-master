# Fretboard Master – model 3D gitary w kafelku menu (assets/models/guitar-classical.glb od autora).
# Gitara stoi pod ukosem i powoli obraca się wokół własnej osi (od główki do korpusu). Materiały
# takie jak w pliku; światło bez odblasków (specular 0), bez cieni. Gdy animacje są wyłączone,
# model jest rysowany raz, w ujęciu trzy czwarte.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name GuitarModel3D
extends SubViewportContainer

const MODEL_PATH := "res://assets/models/guitar-classical.glb"
const TILT_DEG := -32.0       # pochylenie osi gitary względem pionu (główka w prawo u góry)
const LEAN_DEG := 12.0        # lekkie odchylenie w stronę widza
const TURN_TIME := 24.0       # s na pełny obrót
const STILL_DEG := 35.0       # ujęcie przy wyłączonych animacjach
const FOV := 22.0
const MARGIN := 1.08          # zapas wokół bryły

var _vp: SubViewport
var _spin: Node3D
var _cam: Camera3D
var _length := 1.0            # długość gitary (wzdłuż osi obrotu)
var _width := 0.4             # największa szerokość w poprzek osi


static func available() -> bool:
	return ResourceLoader.exists(MODEL_PATH)


static func create(p_min: Vector2) -> GuitarModel3D:
	var g := GuitarModel3D.new()
	g.custom_minimum_size = p_min
	g.stretch = true
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Graphics.msaa_mode()
	_vp.positional_shadow_atlas_size = 0
	_vp.audio_listener_enable_3d = false
	_vp.gui_disable_input = true
	add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.45
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.shadow_enabled = false
	light.light_energy = 0.9
	light.light_specular = 0.0
	light.rotation_degrees = Vector3(-30, -35, 0)
	_vp.add_child(light)

	# Ukos: oś gitary pochylona w płaszczyźnie ekranu i lekko w stronę widza; obrót – wokół tej osi.
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(LEAN_DEG, 0, TILT_DEG)
	_vp.add_child(tilt)
	_spin = Node3D.new()
	tilt.add_child(_spin)
	var model := (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	_spin.add_child(model)
	_center(model)

	_cam = Camera3D.new()
	_cam.fov = FOV
	_vp.add_child(_cam)
	_fit_camera()
	resized.connect(_fit_camera)

	var live := App.animations() != "off" and not ("--perf-audit" in OS.get_cmdline_user_args())
	_spin.rotation_degrees.y = STILL_DEG
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_ONCE
	set_process(live)


func _process(delta: float) -> void:
	_spin.rotate_y(TAU * delta / TURN_TIME)


# Środek bryły w początku układu, najdłuższa oś bryły wzdłuż osi Y (oś obrotu).
func _center(model: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var b: AABB = (model.global_transform.affine_inverse() * m.global_transform) * m.get_aabb() if m.is_inside_tree() \
				else _local_xform(model, m) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var s := box.size
	var basis := Basis.IDENTITY
	if s.x >= s.y and s.x >= s.z:
		basis = Basis(Vector3.FORWARD, PI / 2.0)       # oś X → Y
		_length = s.x
		_width = maxf(s.y, s.z)
	elif s.z >= s.y:
		basis = Basis(Vector3.RIGHT, -PI / 2.0)        # oś Z → Y
		_length = s.z
		_width = maxf(s.x, s.y)
	else:
		_length = s.y
		_width = maxf(s.x, s.z)
	model.transform = Transform3D(basis, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -box.get_center())


static func _local_xform(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


# Kamera mieści całą obracającą się gitarę: rzut pochylonej osi plus szerokość korpusu.
func _fit_camera() -> void:
	if _cam == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var a := deg_to_rad(absf(TILT_DEG))
	var w := _length * sin(a) + _width * cos(a)
	var h := _length * cos(a) + _width * sin(a)
	var aspect := size.x / size.y
	var half_h := maxf(h * 0.5, w * 0.5 / aspect) * MARGIN
	var dist := half_h / tan(deg_to_rad(FOV * 0.5)) + _width * 0.5
	_cam.position = Vector3(0, 0, dist)
	_cam.near = maxf(dist - _length, 0.01)
	_cam.far = dist + _length
	if _vp.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE   # obraz nieruchomy – przerysuj po zmianie rozmiaru
