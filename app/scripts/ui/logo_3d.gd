# Fretboard Master – logo programu jako tafla 3D (model assets/branding/logo.glb od autora).
#  • animated = true (ekran startowy, menu): tafla lekko się kołysze i pochyla w stronę kursora.
#    Po IDLE_STOP s bez ruchu myszy wraca do spoczynku i zatrzymuje się – przetwarzanie jest wtedy
#    wyłączone, a obraz nie jest odświeżany (tryb oszczędny działa dalej).
#  • intro > 0 (ekran startowy): logo nadlatuje z oddali, obracając się; w ostatniej sekundzie
#    już tylko się zbliża, płynnie wyhamowując.
#  • animated = false (nagłówek modułów, „O programie”): obraz rysowany raz.
# Przy logo stoi numer wersji „2.0” jako tekst 3D (czcionka Anton, TextMesh) – zgrupowany z logo,
# porusza się razem z nim. Numer pochodzi z ustawień projektu (application/config/version),
# więc przy kolejnej wersji wystarczy go podbić.
# Optymalizacja: 22 siatki modelu są przy pierwszym użyciu scalane w JEDNĄ siatkę z czterema
# powierzchniami (po jednej na kolor) – 4 wywołania rysowania zamiast 22; siatka i materiały są
# współdzielone przez wszystkie wystąpienia logo. Bez cieni, jedno światło kierunkowe.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name Logo3D
extends SubViewportContainer

const MODEL_PATH := "res://assets/branding/logo.glb"
const VERSION_FONT := "res://assets/fonts/Anton.ttf"
const VERSION_HEIGHT := 0.72   # wysokość „2.0” względem wysokości napisu „Master”
const VERSION_DROP := 0.2      # obniżenie „2.0” poniżej linii bazowej „Master” (jak we wzorze autora)
const VERSION_GAP := 0.012     # odstęp od krawędzi tafli względem szerokości logo
const VERSION_COLOR := Color("D9DADF")   # jasnoszare, srebrzyste
const MASTER_PARTS := [&"path3", &"path5", &"path6", &"path8", &"path9", &"path10"]

# Kolory części modelu (nazwy węzłów z pliku .glb – kontury wektorowe z Inkscape).
const COLORS := {
	&"panel": Color("060607"),      # tafla: obrys zewnętrzny i pole wewnętrzne
	&"frame": Color("F09206"),      # pomarańczowa obwódka
	&"orange": Color("F49C08"),     # litera F z kluczami i napis „Master”
	&"white": Color("F4F4F2"),      # „retboard”
}
const PARTS := {
	&"use28": &"panel", &"path2": &"panel", &"path1": &"frame",
	&"path11": &"orange", &"path25": &"orange", &"path26": &"orange", &"path27": &"orange", &"path28": &"orange",
	&"path3": &"orange", &"path5": &"orange", &"path6": &"orange", &"path8": &"orange", &"path9": &"orange", &"path10": &"orange",
}

const SWAY_DEG := Vector2(2.2, 3.5)      # amplituda kołysania (pochylenie, obrót)
const SWAY_PERIOD := Vector2(5.3, 7.1)   # okresy kołysania w sekundach
const CURSOR_DEG := Vector2(7.0, 11.0)   # maksymalne pochylenie w stronę kursora
const FOLLOW := 5.0                      # szybkość dochodzenia do pozycji docelowej
const IDLE_STOP := 8.0                   # po tylu sekundach bez ruchu myszy animacja wygasa
const FOV := 22.0
const INTRO_FAR := 14.0                  # odległość startowa nadlotu (w szerokościach logo)
const INTRO_TURNS := 1.5                 # liczba obrotów w czasie nadlotu
const INTRO_GLIDE := 1.0                 # ostatnia sekunda: tylko zbliżanie, bez obrotu
const SPIN_EVERY := Vector2(3.0, 10.0)   # losowy obrót o 360° co tyle sekund (od–do)
const SPIN_RATES := {"rare": Vector2(8.0, 20.0), "normal": SPIN_EVERY, "often": Vector2(2.0, 5.0)}
const SPIN_TIME := Vector2(0.5, 0.7)     # czas trwania obrotu (od–do)

static var _mesh: ArrayMesh
static var _text: TextMesh
static var _logo_pos: Vector3
static var _text_pos: Vector3
static var _size: Vector3

var animated := true
var intro := 0.0
var _vp: SubViewport
var _pivot: Node3D
var _time := 0.0
var _idle := 0.0
var _amp := 1.0
var _rot := Vector2.ZERO
var _spin := -1.0          # postęp obrotu 0–1; -1 = brak obrotu
var _spin_len := 0.6
var _spin_timer: Timer
var _sway := true


static func create(p_size: Vector2, p_animated := true, p_intro := 0.0) -> Logo3D:
	var l := Logo3D.new()
	l.custom_minimum_size = p_size
	l.animated = p_animated
	l.intro = p_intro
	l.stretch = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _ready() -> void:
	if _mesh == null:
		_build_mesh()
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Graphics.msaa_mode()
	_vp.positional_shadow_atlas_size = 0
	_vp.audio_listener_enable_3d = false
	_vp.gui_disable_input = true
	add_child(_vp)

	add_lighting(_vp)

	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	var logo := MeshInstance3D.new()
	logo.mesh = _mesh
	logo.position = _logo_pos
	logo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(logo)
	var ver := MeshInstance3D.new()
	ver.mesh = _text
	ver.position = _text_pos
	ver.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(ver)

	var cam := Camera3D.new()
	cam.fov = FOV
	_vp.add_child(cam)
	_fit_camera(cam)
	resized.connect(_fit_camera.bind(cam))

	var audit := "--perf-audit" in OS.get_cmdline_user_args()
	if audit:
		intro = 0.0
	if intro > 0.0:
		_amp = 0.0
		_apply_intro()
	# Animacje wyłączone – logo nieruchome; ograniczone – bez kołysania, tylko obroty.
	var live := animated and not audit and App.animations() != "off"
	_sway = App.animations() == "full"
	if not _sway:
		_amp = 0.0
	# W audycie logo animowane jest rysowane w każdej klatce (najgorszy przypadek), ale bez ruchu.
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live or (animated and audit) else SubViewport.UPDATE_ONCE
	set_process(live)
	set_process_input(live)
	if live and bool(App.setting(&"logo_spin")):
		# Losowe obroty odlicza Timer – między obrotami logo nie wymaga przetwarzania klatek.
		_spin_timer = Timer.new()
		_spin_timer.one_shot = true
		_spin_timer.timeout.connect(_start_spin)
		add_child(_spin_timer)
		_spin_timer.start(intro + _spin_wait())


func _process(delta: float) -> void:
	_time += delta
	if _time < intro:
		_apply_intro()
		return
	_idle += delta
	var active := _idle < IDLE_STOP and _sway
	_amp = move_toward(_amp, 1.0 if active else 0.0, delta * 0.5)
	var target := Vector2(
			sin((_time - intro) * TAU / SWAY_PERIOD.x) * SWAY_DEG.x,
			sin((_time - intro) * TAU / SWAY_PERIOD.y) * SWAY_DEG.y) * _amp
	if active:
		target += _cursor_tilt() * minf(_amp * 2.0, 1.0)
	_rot = _rot.lerp(target, 1.0 - exp(-FOLLOW * delta))
	var spin_deg := 0.0
	if _spin >= 0.0:
		_spin = minf(_spin + delta / _spin_len, 1.0)
		spin_deg = 360.0 * _smooth(_spin)
		if _spin >= 1.0:
			_spin = -1.0
			spin_deg = 0.0
			_spin_timer.start(_spin_wait())
	_pivot.position = Vector3.ZERO
	_pivot.rotation_degrees = Vector3(_rot.x, _rot.y + spin_deg, 0)
	if not active and _spin < 0.0 and _amp == 0.0 and _rot.length() < 0.02:
		_pivot.rotation_degrees = Vector3.ZERO
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		set_process(false)


# Obrót o 360° wokół osi pionowej – płynny start i zatrzymanie. Pomijany, gdy okno nie ma fokusu.
func _start_spin() -> void:
	if not get_window().has_focus():
		_spin_timer.start(_spin_wait())
		return
	_spin = 0.0
	_spin_len = randf_range(SPIN_TIME.x, SPIN_TIME.y)
	if not is_processing():
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		set_process(true)


# Odstęp do następnego obrotu według ustawienia częstości (rzadko / normalnie / często).
func _spin_wait() -> float:
	var range_s: Vector2 = SPIN_RATES.get(str(App.setting(&"logo_spin_rate")), SPIN_EVERY)
	return randf_range(range_s.x, range_s.y)


static func _smooth(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


# Nadlot: odległość maleje z wyhamowaniem (ease-out) przez cały czas; obrót wygasa łagodnie
# do zera na INTRO_GLIDE s przed końcem, potem logo już tylko się zbliża.
func _apply_intro() -> void:
	var p := clampf(_time / intro, 0.0, 1.0)
	var approach := 1.0 - pow(1.0 - p, 3.0)
	_pivot.position = Vector3(0, 0, -_size.x * INTRO_FAR * (1.0 - approach))
	var spin_end := maxf(intro - INTRO_GLIDE, 0.001)
	var q := clampf(_time / spin_end, 0.0, 1.0)
	_pivot.rotation_degrees = Vector3(0, 360.0 * INTRO_TURNS * pow(1.0 - q, 2.0), 0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_idle = 0.0
		if not is_processing():
			_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			set_process(true)


# Pochylenie w stronę kursora, liczone względem środka logo i rozmiaru okna.
func _cursor_tilt() -> Vector2:
	var rel := (get_global_mouse_position() - get_global_rect().get_center()) / (get_viewport_rect().size * 0.5)
	rel = rel.clamp(-Vector2.ONE, Vector2.ONE)
	return Vector2(rel.y * CURSOR_DEG.x, rel.x * CURSOR_DEG.y)


func _fit_camera(cam: Camera3D) -> void:
	var aspect := maxf(size.x, 1.0) / maxf(size.y, 1.0)
	var half_v := deg_to_rad(FOV) * 0.5
	var half_h := atan(tan(half_v) * aspect)
	# Zapas 10% na kołysanie, żeby krawędzie tafli nie wychodziły poza kadr.
	var dist := maxf(_size.x * 0.55 / tan(half_h), _size.y * 0.55 / tan(half_v)) + _size.z
	cam.position = Vector3(0, 0, dist)
	cam.near = maxf(dist - _size.x, 0.001)
	cam.far = dist + _size.x * (INTRO_FAR + 1.0)
	if _vp and not is_processing():
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE  # nowy rozmiar – jedno odświeżenie


# Scalenie modelu w jedną siatkę: powierzchnia na kolor, model ustawiony frontem do kamery (+Z)
# i wyśrodkowany. Wykonywane raz na cały program.
static func _build_mesh() -> void:
	var root := (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	# Kontury z Inkscape leżą w płaszczyźnie XZ (front w +Y) – obrót o 90° wokół X.
	var orient := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	var tools := {}
	var stack: Array = [[root, orient]]
	var box := AABB()
	var first := true
	var master := AABB()
	var outline := PackedVector3Array()   # obrys zewnętrzny tafli (do położenia „2.0”)
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is Node3D and node != root:
			xf = xf * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var mesh := (node as MeshInstance3D).mesh
			var part: StringName = PARTS.get(StringName(node.name), &"white")
			if not tools.has(part):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[part] = st
			for s in mesh.get_surface_count():
				(tools[part] as SurfaceTool).append_from(mesh, s, xf)
			var b := xf * mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
			if StringName(node.name) in MASTER_PARTS:
				master = b if master.size == Vector3.ZERO else master.merge(b)
			elif StringName(node.name) == &"use28":
				for v in (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					outline.append(xf * v)
		for c in node.get_children():
			stack.append([c, xf])
	root.free()

	_mesh = ArrayMesh.new()
	var center := box.get_center()
	for part in [&"panel", &"frame", &"orange", &"white"]:
		if not tools.has(part):
			continue
		var arrays := (tools[part] as SurfaceTool).commit_to_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] -= center
		arrays[Mesh.ARRAY_VERTEX] = verts
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_mesh.surface_set_material(_mesh.get_surface_count() - 1, material(part))
	# Numer wersji „2.0” – tekst 3D z czcionki Anton, jasnoszary, poza taflą: tuż przy jej prawej
	# krawędzi na wysokości „Master”, nieco poniżej jego linii bazowej, wyraźnie mniejszy (wzór autora).
	_text = TextMesh.new()
	_text.text = _version_label()
	_text.font = load(VERSION_FONT)
	_text.font_size = 64
	_text.pixel_size = 0.001
	_text.depth = 0.0001   # praktycznie płaskie – czytelne przy każdym pochyleniu
	_text.curve_step = 1.0
	var h0 := _text.get_aabb().size.y
	_text.pixel_size = 0.001 * master.size.y * VERSION_HEIGHT / maxf(h0, 0.000001)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = VERSION_COLOR
	tmat.metallic = 0.25
	tmat.roughness = 0.3
	tmat.metallic_specular = 0.8
	_text.material = tmat
	var tb := _text.get_aabb()
	# Prawa krawędź obrysu tafli na wysokości „Master” (dolna, węższa część tafli).
	var edge := master.end.x
	for v in outline:
		if v.y >= master.position.y and v.y <= master.get_center().y:   # dolna połowa – bez narożnika części górnej
			edge = maxf(edge, v.x)
	var lb := AABB(-box.size * 0.5, box.size)
	var tpos := Vector3(edge - center.x + box.size.x * VERSION_GAP - tb.position.x,
			master.position.y - center.y - tb.position.y - master.size.y * VERSION_DROP,
			lb.end.z - tb.end.z)   # przód „2.0” równo z przodem liter
	var group := lb.merge(AABB(tb.position + tpos, tb.size))
	var shift := -group.get_center()
	_logo_pos = shift
	_text_pos = tpos + shift
	_size = group.size


# Materiał części logo (wspólny – używają go też ikony 3D modułów w menu).
static var _materials := {}

static func material(part: StringName) -> StandardMaterial3D:
	if _materials.has(part):
		return _materials[part]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLORS[part]
	# Połysk: gładka powierzchnia z lakierem (clearcoat) – wyraźne odblaski przy kołysaniu.
	# Elementy pomarańczowe: gładsze i z mocniejszym odbiciem – ostrzejsze, ale wąskie odblaski,
	# więc kolor powierzchni się nie rozjaśnia.
	var glossy: bool = part == &"frame" or part == &"orange"
	mat.roughness = 0.45 if part == &"panel" else (0.14 if glossy else 0.28)
	mat.metallic_specular = 1.0 if glossy else 0.7
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.6
	mat.clearcoat_roughness = 0.12
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[part] = mat
	return mat


# Otoczenie i światło logo (te same dla ikon 3D modułów).
static func add_lighting(vp: SubViewport) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.38
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.shadow_enabled = false
	light.light_energy = 0.95
	light.rotation_degrees = Vector3(-28, -32, 0)
	vp.add_child(light)


# „2.0” z numeru wersji „2.0.0” w ustawieniach projektu (główny.podrzędny).
static func _version_label() -> String:
	var parts := str(ProjectSettings.get_setting("application/config/version", "2.0.0")).split(".")
	return ".".join(parts.slice(0, 2)) if parts.size() >= 2 else parts[0]
