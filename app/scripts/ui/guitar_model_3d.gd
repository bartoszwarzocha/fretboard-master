# Fretboard Master – model 3D gitary w kafelku menu (assets/models/guitar-*.glb od autora).
# Gitara stoi pod ukosem i powoli obraca się wokół własnej osi (od główki do korpusu). Materiały
# takie jak w pliku; światło bez odblasków (specular 0), bez cieni. Rysowana we wspólnej scenie
# menu (MenuStage3D) – tutaj tylko wybór i przygotowanie modelu.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name GuitarModel3D
extends RefCounted

# Modele gitar: res://assets/models/guitar-<rodzaj>.glb. Kolejny model wystarczy dodać jako plik.
const MODEL_DIR := "res://assets/models/guitar-%s.glb"
const KINDS := ["classical", "acoustic", "electric"]
const TILT_DEG := -37.0       # pochylenie osi gitary względem pionu (główka w prawo u góry)
const LEAN_DEG := 12.0        # lekkie odchylenie w stronę widza
const TURN_TIME := 10.0       # s na pełny obrót
const STILL_DEG := 35.0       # ujęcie przy wyłączonych animacjach
const MARGIN := 1.08          # zapas wokół bryły
const ZOOM := 1.08            # powiększenie ponad dopasowanie


static func available() -> bool:
	return not _existing().is_empty()


static func _existing() -> Array:
	return KINDS.filter(func(k: String) -> bool: return ResourceLoader.exists(MODEL_DIR % k))


# Gitara zgodna z widokiem gryfu (classical_3d / acoustic_3d / electric_3d); przy widoku
# schematycznym albo braku pliku danego rodzaju – losowa z dostępnych (losowana przy wejściu do menu).
static func model_path() -> String:
	var kind := str(App.setting(&"neck_view")).trim_suffix("_3d")
	if kind in KINDS and ResourceLoader.exists(MODEL_DIR % kind):
		return MODEL_DIR % kind
	var have := _existing()
	return MODEL_DIR % have.pick_random() if not have.is_empty() else ""


# Model wyśrodkowany, najdłuższa oś bryły wzdłuż Y (oś obrotu), bez cieni, na podanej warstwie
# renderowania. Wynik: {"node": Node3D, "length": float, "width": float}.
static func build(layer: int) -> Dictionary:
	var model := (load(model_path()) as PackedScene).instantiate() as Node3D
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.layers = layer
		var b: AABB = _local_xform(model, m) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var s := box.size
	var basis := Basis.IDENTITY
	var length := s.y
	var width := maxf(s.x, s.z)
	if s.x >= s.y and s.x >= s.z:
		basis = Basis(Vector3.FORWARD, PI / 2.0)       # oś X → Y
		length = s.x
		width = maxf(s.y, s.z)
	elif s.z >= s.y:
		basis = Basis(Vector3.RIGHT, -PI / 2.0)        # oś Z → Y
		length = s.z
		width = maxf(s.x, s.y)
	model.transform = Transform3D(basis, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -box.get_center())
	return {"node": model, "length": length, "width": width}


# Rzut pochylonej gitary (szerokość, wysokość) – do dopasowania w kaflu.
static func projected(length: float, width: float) -> Vector2:
	var a := deg_to_rad(absf(TILT_DEG))
	return Vector2(length * sin(a) + width * cos(a), length * cos(a) + width * sin(a))


static func _local_xform(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
