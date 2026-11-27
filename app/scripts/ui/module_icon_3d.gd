# Fretboard Master – siatki ikon 3D modułów (assets/models/module-icons.glb od autora).
# Ikony są rysowane we wspólnej scenie menu (MenuStage3D) – tutaj tylko przygotowanie siatek.
# Materiały – dokładnie te same co w logo 3D (Logo3D.material).
# Ikona Ustawień (zębatka) nie ma jej w pliku autora – jest budowana w kodzie (_gear_mesh) w tym
# samym stylu: te same warstwy, grubości, skala i materiały. Gdy plik dostanie warstwy
# „ustawienia-…”, zostaną użyte zamiast niej.
# Optymalizacja: plik wczytywany raz; warstwy każdej ikony scalane w jedną siatkę z trzema
# powierzchniami (tafla, obwódka, symbol) – 3 wywołania rysowania na ikonę, materiały wspólne.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name ModuleIcon3D
extends RefCounted

const MODEL_PATH := "res://assets/models/module-icons.glb"
# Moduł → przedrostek nazw warstw w pliku („<przedrostek>-krawedz/-obrys/-podkladka/-symbol”).
const PREFIX := {
	&"encyclopedia": "encyklopedia", &"trainers": "cwiczenia", &"reading": "czytanie-nut",
	&"tuning": "tuner", &"metronome": "metronom", &"plan": "plan-cwiczen", &"progress": "postepy",
	&"looper": "looper", &"settings": "ustawienia",
}
# Warstwa → część logo (ten sam materiał): ciemna tafla, pomarańczowa obwódka, pomarańczowy symbol.
const LAYER_PART := {"krawedz": &"panel", "podkladka": &"panel", "obrys": &"frame", "symbol": &"orange"}

static var _meshes := {}      # przedrostek → ArrayMesh
static var _sizes := {}       # przedrostek → Vector3


static func available(id: StringName) -> bool:
	return PREFIX.has(id) and ResourceLoader.exists(MODEL_PATH)


static func mesh(id: StringName) -> ArrayMesh:
	if _meshes.is_empty():
		_build_meshes()
	return _meshes.get(PREFIX.get(id, ""))


static func mesh_size(id: StringName) -> Vector3:
	if _meshes.is_empty():
		_build_meshes()
	return _sizes.get(PREFIX.get(id, ""), Vector3.ONE * 0.05)


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
	if not _meshes.has("ustawienia"):
		_meshes["ustawienia"] = _gear_mesh()
		_sizes["ustawienia"] = (_meshes["ustawienia"] as ArrayMesh).get_aabb().size


static func _local_xform(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


# --- Zębatka Ustawień -------------------------------------------------------------------------
# Wymiary w mm (jak w pliku ikon: 1 mm = 0,001 j.). Warstwy i ich połowy grubości jak w pliku:
# krawędź ±5, obrys ±6, podkładka ±7, symbol ±10 (×0,001).
const GEAR_TEETH := 8
const GEAR_TIP := 20.0        # promień wierzchołków zębów
const GEAR_ROOT := 15.0       # promień u nasady zębów
const GEAR_TIP_W := 5.6       # szerokość zęba na wierzchołku
const GEAR_BASE_W := 8.4      # szerokość zęba u nasady
const GEAR_EDGE := 1.1        # cienka ciemna krawędź na zewnątrz obrysu
const GEAR_RIM := 2.3         # grubość pomarańczowego obrysu
const GEAR_HUB := Vector2(4.2, 8.2)   # symbol: pierścień (promień otworu, promień zewnętrzny)
const MM := 0.001


static func _gear_mesh() -> ArrayMesh:
	var outline := PackedVector2Array()
	var step := TAU / GEAR_TEETH
	for i in GEAR_TEETH:
		var a := i * step
		var hb := GEAR_BASE_W * 0.5 / GEAR_ROOT
		var ht := GEAR_TIP_W * 0.5 / GEAR_TIP
		outline.append(Vector2.from_angle(a - hb) * GEAR_ROOT)
		outline.append(Vector2.from_angle(a - ht) * GEAR_TIP)
		outline.append(Vector2.from_angle(a + ht) * GEAR_TIP)
		outline.append(Vector2.from_angle(a + hb) * GEAR_ROOT)
		var gap := step - 2.0 * hb
		for k in range(1, 4):
			outline.append(Vector2.from_angle(a + hb + gap * k / 4.0) * GEAR_ROOT)
	# Zaokrąglenie narożników: wypukłych (zwężenie i poszerzenie) i wklęsłych (odwrotnie).
	outline = _offset(_offset(outline, -1.0), 1.0)
	outline = _offset(_offset(outline, 0.8), -0.8)

	var panel := SurfaceTool.new()
	panel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frame := SurfaceTool.new()
	frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	var symbol := SurfaceTool.new()
	symbol.begin(Mesh.PRIMITIVE_TRIANGLES)
	_extrude(panel, _offset(outline, GEAR_EDGE), 5.0)       # krawędź
	_extrude(frame, outline, 6.0)                           # obrys
	_extrude(panel, _offset(outline, -GEAR_RIM), 7.0)       # podkładka
	_ring(symbol, GEAR_HUB.x, GEAR_HUB.y, 10.0)              # symbol – pierścień z otworem
	var mesh := ArrayMesh.new()
	for pair in [[panel, &"panel"], [frame, &"frame"], [symbol, &"orange"]]:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, (pair[0] as SurfaceTool).commit_to_arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, Logo3D.material(pair[1]))
	return mesh


static func _offset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var res := Geometry2D.offset_polygon(poly, d, Geometry2D.JOIN_ROUND)
	return res[0] if not res.is_empty() else poly


# Trójkąt zwrócony przodem w stronę n (Godot: przód = zgodnie z ruchem wskazówek zegara).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v * MM)


static func _extrude(st: SurfaceTool, poly: PackedVector2Array, half: float) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for i in range(0, idx.size(), 3):
		var p := [poly[idx[i]], poly[idx[i + 1]], poly[idx[i + 2]]]
		_tri(st, _v(p[0], half), _v(p[1], half), _v(p[2], half), Vector3.BACK)
		_tri(st, _v(p[0], -half), _v(p[1], -half), _v(p[2], -half), Vector3.FORWARD)
	_walls(st, poly, half, not Geometry2D.is_polygon_clockwise(poly))


# Ściany boczne: normalna na zewnątrz konturu (outward) albo do środka (otwór).
static func _walls(st: SurfaceTool, poly: PackedVector2Array, half: float, ccw: bool, inward := false) -> void:
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var d := (q - p).normalized()
		var out := Vector2(d.y, -d.x) if ccw else Vector2(-d.y, d.x)
		if inward:
			out = -out
		var n := Vector3(out.x, out.y, 0.0)
		_tri(st, _v(p, half), _v(q, half), _v(q, -half), n)
		_tri(st, _v(p, half), _v(q, -half), _v(p, -half), n)


static func _ring(st: SurfaceTool, r_in: float, r_out: float, half: float) -> void:
	var seg := 48
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		outer.append(Vector2.from_angle(a) * r_out)
		inner.append(Vector2.from_angle(a) * r_in)
	for i in seg:
		var j := (i + 1) % seg
		for z in [half, -half]:
			var n := Vector3.BACK if z > 0.0 else Vector3.FORWARD
			_tri(st, _v(outer[i], z), _v(outer[j], z), _v(inner[j], z), n)
			_tri(st, _v(outer[i], z), _v(inner[j], z), _v(inner[i], z), n)
	_walls(st, outer, half, true)
	_walls(st, inner, half, true, true)


static func _v(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)
