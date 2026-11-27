# Fretboard Master – wymiary i wygląd gryfu (wspólne dla widoków 3D i schematów).
# Rodzaj gitary wynika z ustawienia neck_view; drewno, progi, struny i wkładki – z ustawień
# (wartość "auto" = jak na danej gitarze, wg zaakceptowanej makiety gryfu z 27.11.2026).
# Jednostki: milimetry. Oś x – wzdłuż gryfu (0 = siodełko), oś z – w poprzek (z < 0 = struna najwyższa).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name NeckSpec
extends RefCounted

const TEAL := Color("#3FD0C9")
const ORANGE := Color("#F5B544")
const BOARD_T := 6.0          # grubość podstrunnicy
const NUT_LEN := 4.5          # długość siodełka

# Wymiary gitar 6-strunowych: menzura, szerokość przy siodełku i na 12. progu, rozstaw skrajnych strun
# przy siodełku i przy mostku, promień podstrunnicy (0 = płaska), obszycie, wysokość strun.
const GUITARS := {
	"classical": {"L": 650.0, "nut": 52.0, "w12": 62.0, "span_nut": 43.0, "span_br": 58.0, "R": 0.0,
		"bind": 0.0, "fret_r": 1.0, "fret_h": 1.0, "h_nut": 1.8, "h_end": 4.0,
		"wood": "classical", "metal": "classical", "strings": "nylon", "inlays": "none",
		"neck": Color("#7A4A2A"), "nut_col": Color("#EDE6D3")},
	"acoustic": {"L": 645.0, "nut": 44.0, "w12": 54.0, "span_nut": 36.0, "span_br": 54.0, "R": 406.0,
		"bind": 1.4, "fret_r": 1.1, "fret_h": 1.05, "h_nut": 1.6, "h_end": 3.4,
		"wood": "rosewood", "metal": "acoustic", "strings": "bronze", "inlays": "dots",
		"neck": Color("#5C321D"), "nut_col": Color("#EFE8D6")},
	"electric": {"L": 628.0, "nut": 43.0, "w12": 52.0, "span_nut": 35.0, "span_br": 52.0, "R": 305.0,
		"bind": 1.6, "fret_r": 1.15, "fret_h": 1.2, "h_nut": 1.8, "h_end": 3.0,
		"wood": "electric", "metal": "nickel", "strings": "nickel", "inlays": "trapezoids",
		"neck": Color("#6A2E1C"), "nut_col": Color("#EDE6D3")},
}

const WOODS := {
	"classical": [Color("#1B110C"), Color("#3A2418")],
	"rosewood": [Color("#24140D"), Color("#55301C")],
	"electric": [Color("#1E0E0A"), Color("#4A2216")],
	"maple": [Color("#B98A50"), Color("#E6C58E")],
	"ebony": [Color("#0D0A09"), Color("#2A201B")],
}
const METALS := {
	"classical": Color("#D8D2C4"), "acoustic": Color("#D9CDA8"), "nickel": Color("#DCD8CE"),
	"stainless": Color("#E6E8EC"), "gold": Color("#D6B25A"),
}
const BINDING := Color("#E8DDC0")

# Struny dodatkowe (7. i 8.) poniżej najniższej struny stroju.
const EXTRA_LOW := [35, 30]

var kind := "electric"
var g: Dictionary
var strings := 6
var frets := 22
var open_midi: Array = []      # indeks 0 = struna najwyższa (u góry widoku)
var wood: Array
var neck_col: Color
var fret_col: Color
var string_kind := "nickel"
var inlays := "dots"
var bind := 0.0
var L := 650.0
var nut_w := 44.0
var w12 := 54.0
var span_nut := 36.0
var span_br := 54.0
var R := 0.0
var x_end := 0.0
var marker_r := 3.0


static func is_3d(view: String) -> bool:
	return view.ends_with("_3d")


static func from_settings() -> NeckSpec:
	var s := NeckSpec.new()
	var view := str(App.setting(&"neck_view"))
	s.kind = view.trim_suffix("_3d") if is_3d(view) else "electric"
	if not GUITARS.has(s.kind):
		s.kind = "electric"
	s.g = GUITARS[s.kind]
	s.strings = clampi(int(App.setting(&"strings")), 6, 8)
	s.frets = clampi(int(App.setting(&"frets")), 12, 24)
	var tuning: Array = ModuleHeader.TUNING_MIDI.get(str(App.setting(&"tuning")), ModuleHeader.TUNING_MIDI["standard"])
	var low_to_high: Array = tuning.duplicate()
	for i in s.strings - 6:
		low_to_high.push_front(EXTRA_LOW[i])
	low_to_high.reverse()
	s.open_midi = low_to_high
	var w := str(App.setting(&"fretboard_wood"))
	s.wood = WOODS.get(s.g.wood if w == "auto" else w, WOODS.rosewood)
	s.neck_col = Color("#D9B279") if w == "maple" else s.g.neck
	var m := str(App.setting(&"fret_metal"))
	s.fret_col = METALS.get(s.g.metal if m == "auto" else m, METALS.nickel)
	var sc := str(App.setting(&"string_color"))
	s.string_kind = s.g.strings if sc == "auto" else sc
	var inl := str(App.setting(&"inlays"))
	s.inlays = s.g.inlays if inl == "auto" else inl
	s.bind = s.g.bind
	s.L = s.g.L
	# Dodatkowe struny poszerzają gryf o kolejne odstępy.
	var extra := s.strings - 6
	var sp_nut: float = s.g.span_nut / 5.0
	var sp_br: float = s.g.span_br / 5.0
	s.span_nut = s.g.span_nut + sp_nut * extra
	s.span_br = s.g.span_br + sp_br * extra
	s.nut_w = s.g.nut + sp_nut * extra
	s.w12 = s.g.w12 + (sp_nut + sp_br) * 0.5 * extra
	s.R = s.g.R
	s.x_end = s.xf(s.frets) + 0.55 * (s.xf(s.frets + 1) - s.xf(s.frets))
	s.marker_r = 0.5 * sp_nut
	return s


func xf(n: float) -> float:
	return L * (1.0 - pow(2.0, -n / 12.0))


func half_w(x: float) -> float:
	return 0.5 * (nut_w + (w12 - nut_w) * x / (L * 0.5))


func board_y(z: float) -> float:
	return 0.0 if R <= 0.0 else -(z * z) / (2.0 * R)


func board_normal(z: float) -> Vector3:
	return Vector3.UP if R <= 0.0 else Vector3(0, R, z).normalized()


func span(x: float) -> float:
	return span_nut + (span_br - span_nut) * x / L


func string_z(s: int, x: float) -> float:
	return span(x) * (float(s) / float(strings - 1) - 0.5)


func string_y(s: int, x: float) -> float:
	return board_y(string_z(s, x)) + g.h_nut + (g.h_end - g.h_nut) * x / L


# Grubość struny w mm (indeks 0 = najwyższa); 7. i 8. struna – grubsze od 6.
func gauge(s: int) -> float:
	var table: Array
	match string_kind:
		"nylon": table = [0.72, 0.84, 1.04, 0.76, 0.92, 1.12]
		"bronze": table = [0.30, 0.41, 0.61, 0.81, 1.07, 1.35]
		_: table = [0.25, 0.33, 0.43, 0.66, 0.91, 1.17]
	if s < 6:
		return table[s]
	return table[5] + 0.25 * (s - 5)


# Rodzaj materiału struny: plain/wound dla danego kompletu.
func string_material(s: int) -> String:
	match string_kind:
		"nylon": return "nylon" if s < 3 else "silver"
		"bronze": return "steel" if s < 2 else "bronze"
		"black": return "black"
		_: return "nickel" if s < 3 else "nickelw"


# Położenie znacznika dźwięku (środek krążka) na osi x: na środku pola między progami;
# pusta struna – przed siodełkiem.
func marker_x(f: int) -> float:
	if f == 0:
		return -NUT_LEN - marker_r - 3.0
	return (xf(f - 1) + xf(f)) * 0.5


func marker_radius(f: int) -> float:
	return marker_r if f == 0 else minf(marker_r, 0.5 * (xf(f) - xf(f - 1)) - spec_fret_r())


func spec_fret_r() -> float:
	return float(g.fret_r) + 0.4


# Progi z pojedynczą wkładką oraz progi z podwójną (kropki) – dla wybranego wzoru.
func inlay_frets() -> Array:
	var singles := [3, 5, 7, 9, 15, 17, 19, 21] if inlays == "dots" else [1, 3, 5, 7, 9, 12, 15, 17, 19, 21, 24]
	return singles.filter(func(f: int) -> bool: return f <= frets)


func double_dot_frets() -> Array:
	if inlays != "dots":
		return []
	return [12, 24].filter(func(f: int) -> bool: return f <= frets)


# Kolory znaczników z ustawień (Gitara i strój → Wygląd gryfu); "" = domyślny.
static func note_color(root: bool) -> Color:
	var hex := str(App.setting(&"marker_root_color" if root else &"marker_color"))
	return Color(hex) if not hex.is_empty() else (ORANGE if root else TEAL)


static func text_color(root: bool) -> Color:
	var hex := str(App.setting(&"marker_text_color"))
	if not hex.is_empty():
		return Color(hex)
	return Color("#1A1204") if root else Color("#04201E")


# Nazwa pustej struny do opisu (najwyższa struna małą literą, gdy powtarza nazwę najniższej).
func string_label(s: int) -> String:
	var t := NoteNames.note_name(open_midi[s], App.notation())
	if s == 0 and t == NoteNames.note_name(open_midi[strings - 1], App.notation()):
		t = t.to_lower()
	return t
