# Fretboard Master – wspólna scena 3D ilustracji kafelków menu (ikony modułów i gitara).
# Wszystkie modele leżą w JEDNEJ scenie i są renderowane w JEDNYM SubViewporcie wielkości siatki
# kafelków (kamera ortogonalna, 1 jednostka = 100 px układu). Każdy kafel rysuje tylko swój wycinek
# tego obrazu (MenuArt) – zamiast osobnego viewportu, świata, bufora MSAA i przebiegu renderowania
# na każdy kafel jest jeden przebieg na całe menu.
#  • Ikony: delikatne kołysanie i pochylenie w stronę kursora (jak logo), falą po kolejnych kaflach;
#    po najechaniu na kafel – wyraźny obrót wokół osi pionowej, po zjechaniu dokończenie obrotu.
#  • Gitara: powolny obrót wokół własnej osi; własne światło (warstwa 2) – bez odblasków.
#  • Jeden takt (_process) dla wszystkich modeli. Gdy nic się nie rusza (brak gitary, mysz w
#    spoczynku), takt staje, a obraz jest odświeżany tylko po zmianie.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name MenuStage3D
extends Node

const UNIT := 0.01             # jednostki sceny na piksel układu
const FILL := 0.88             # ikona zajmuje tyle wolnego miejsca kafla (zapas na kołysanie)
const SWAY_DEG := Vector2(2.2, 3.5)
const SWAY_PERIOD := Vector2(5.3, 7.1)
const CURSOR_DEG := Vector2(9.0, 14.0)
const FOLLOW := 5.0
const IDLE_STOP := 8.0
const SPIN_SPEED := 300.0      # °/s przy obrocie po najechaniu
const SPIN_ACCEL := 900.0      # °/s²
const ICON_LAYER := 1
const GUITAR_LAYER := 2

var _grid: Control
var _vp: SubViewport
var _cam: Camera3D
var _items: Array[Dictionary] = []
var _time := 0.0
var _idle := 0.0
var _amp := 1.0
var _live := true
var _sway := true
var _guitar_spin: Node3D
var _scale := Vector2.ONE      # piksele ekranu na jednostkę układu
var _layout_dirty := true


func setup(grid: Control, arts: Array) -> void:
	_grid = grid
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	# Wygładzanie najwyżej 2× – przy tej wielkości modeli wyższe MSAA nie daje widocznej różnicy,
	# a bufor obejmuje całą siatkę kafelków.
	_vp.msaa_3d = mini(Graphics.msaa_mode(), Viewport.MSAA_2X) as Viewport.MSAA
	_vp.positional_shadow_atlas_size = 0
	_vp.audio_listener_enable_3d = false
	_vp.gui_disable_input = true
	add_child(_vp)
	Logo3D.add_lighting(_vp)
	for c in _vp.get_children():
		if c is DirectionalLight3D:
			(c as DirectionalLight3D).light_cull_mask = ICON_LAYER
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.position = Vector3(0, 0, 50)
	_cam.near = 1.0
	_cam.far = 100.0
	_vp.add_child(_cam)

	for i in arts.size():
		var art := arts[i] as MenuArt
		art.texture = _vp.get_texture()
		var pivot := Node3D.new()
		_vp.add_child(pivot)
		var item := {"art": art, "pivot": pivot, "index": i, "rot": Vector2.ZERO, "angle": 0.0,
				"speed": 0.0, "spin": false}
		if art.kind == MenuArt.Kind.GUITAR:
			_add_guitar(pivot, item)
		else:
			var mi := MeshInstance3D.new()
			mi.mesh = ModuleIcon3D.mesh(art.module_id)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.layers = ICON_LAYER
			pivot.add_child(mi)
			item["size"] = ModuleIcon3D.mesh_size(art.module_id)
		_items.append(item)
		art.tile.mouse_entered.connect(_set_spin.bind(item, true))
		art.tile.mouse_exited.connect(_set_spin.bind(item, false))
		art.resized.connect(_mark_layout)
	grid.resized.connect(_mark_layout)

	_live = App.animations() != "off"
	_sway = App.animations() == "full"
	if not _sway:
		_amp = 0.0
	set_process(_live)
	set_process_input(_live)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _live else SubViewport.UPDATE_ONCE
	_layout.call_deferred()


func _add_guitar(pivot: Node3D, item: Dictionary) -> void:
	var light := DirectionalLight3D.new()
	light.shadow_enabled = false
	light.light_energy = 0.97      # z otoczeniem sceny (0,38) – jasność jak wcześniej (0,9 + 0,45)
	light.light_specular = 0.0
	light.rotation_degrees = Vector3(-30, -35, 0)
	light.light_cull_mask = GUITAR_LAYER
	_vp.add_child(light)
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(GuitarModel3D.LEAN_DEG, 0, GuitarModel3D.TILT_DEG)
	pivot.add_child(tilt)
	_guitar_spin = Node3D.new()
	_guitar_spin.rotation_degrees.y = GuitarModel3D.STILL_DEG
	tilt.add_child(_guitar_spin)
	var g := GuitarModel3D.build(GUITAR_LAYER)
	_guitar_spin.add_child(g.node)
	var p := GuitarModel3D.projected(g.length, g.width)
	item["size"] = Vector3(p.x, p.y, g.length) * GuitarModel3D.MARGIN / GuitarModel3D.ZOOM
	item["guitar"] = true


func _mark_layout() -> void:
	_layout_dirty = true
	if not is_processing():
		_layout()
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# Rozmiar obrazu = siatka kafelków w pikselach ekranu; położenie i skala każdego modelu
# według miejsca na ilustrację w jego kaflu.
func _layout() -> void:
	_layout_dirty = false
	if _grid == null or _grid.size.x < 1.0:
		return
	_scale = _grid.get_global_transform_with_canvas().get_scale()
	var gs := _grid.size
	_vp.size = Vector2i(maxi(int(gs.x * _scale.x), 1), maxi(int(gs.y * _scale.y), 1))
	_cam.size = gs.y * UNIT
	for item in _items:
		var art := item.art as MenuArt
		var r := art.layout_rect()
		art.region = Rect2(r.position * _scale, r.size * _scale)
		art.queue_redraw()
		var c := r.get_center() - gs * 0.5
		item["pos"] = Vector3(c.x * UNIT, -c.y * UNIT, 0.0)
		var sz: Vector3 = item.size
		var fill := 1.0 if item.has("guitar") else FILL
		item["scale"] = minf(r.size.x * UNIT * fill / sz.x, r.size.y * UNIT * fill / sz.y)
		_place(item)


func _place(item: Dictionary) -> void:
	var pivot := item.pivot as Node3D
	var rot: Vector2 = item.rot
	var b := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y + fmod(item.angle, 360.0)), 0.0))
	pivot.transform = Transform3D(b.scaled(Vector3.ONE * float(item.get("scale", 1.0))), item.get("pos", Vector3.ZERO))


func _process(delta: float) -> void:
	if _layout_dirty:
		_layout()
	_time += delta
	_idle += delta
	var active := _idle < IDLE_STOP and _sway
	_amp = move_toward(_amp, 1.0 if active else 0.0, delta * 0.5)
	var moving := false
	if _guitar_spin:
		_guitar_spin.rotate_y(TAU * delta / GuitarModel3D.TURN_TIME)
		moving = true
	var view := _grid.get_viewport_rect().size * 0.5
	var mouse := _grid.get_global_mouse_position()
	for item in _items:
		if item.has("guitar"):
			continue
		var i: int = item.index
		var t := _time + i * 1.7
		var target := Vector2(sin(t * TAU / SWAY_PERIOD.x) * SWAY_DEG.x, sin(t * TAU / SWAY_PERIOD.y) * SWAY_DEG.y) * _amp
		if active:
			var rel := ((mouse - (item.art as MenuArt).get_global_rect().get_center()) / view).clamp(-Vector2.ONE, Vector2.ONE)
			target += Vector2(rel.y * CURSOR_DEG.x, rel.x * CURSOR_DEG.y) * minf(_amp * 2.0, 1.0)
		# Każdy kolejny kafel dochodzi do pozycji nieco wolniej – ruch biegnie po ikonach falą.
		var rot: Vector2 = item.rot
		rot = rot.lerp(target, 1.0 - exp(-(FOLLOW - i * 0.35) * delta))
		item["rot"] = rot
		var angle: float = item.angle
		var speed: float = item.speed
		if item.spin:
			speed = move_toward(speed, SPIN_SPEED, SPIN_ACCEL * delta)
			angle += speed * delta
		elif angle != 0.0:
			# Dokończenie obrotu do pełnej wielokrotności 360° z łagodnym hamowaniem.
			var goal := ceilf(angle / 360.0) * 360.0
			speed = clampf((goal - angle) * 4.0, 40.0, maxf(speed, 40.0))
			angle = minf(angle + speed * delta, goal)
			if angle >= goal:
				angle = 0.0
				speed = 0.0
		item["angle"] = angle
		item["speed"] = speed
		if item.spin or angle != 0.0 or rot.length() > 0.02:
			moving = true
		_place(item)
	if not moving and not active and _amp == 0.0:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		set_process(false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_idle = 0.0
		_wake()


func _set_spin(item: Dictionary, on: bool) -> void:
	item["spin"] = on
	_wake()


func _wake() -> void:
	if _live and _vp and not is_processing():
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		set_process(true)
