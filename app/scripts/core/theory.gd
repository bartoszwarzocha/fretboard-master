# Fretboard Master – teoria: baza skal i akordów (data/theory.json), pisownia literowa dźwięków,
# znaki przykluczowe i wybór zapisu toniki. Bez zależności od ekranów – do Encyklopedii, ćwiczeń
# i pięciolinii.
# Dźwięk zapisany = {"l": litera 0–6 (C D E F G A B), "a": znak (-2..2: 𝄫 ♭ ♮ ♯ 𝄪)}.
# Stopnie względem skali durowej toniki: „1”, „b3”, „#4”, „bb7”, „9”, „#11”…; liczba stopnia
# wyznacza literę, znaki – wysokość. Znaki przykluczowe = liczba kwint: >0 krzyżyki, <0 bemole.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name Theory
extends RefCounted

const DATA_PATH := "res://data/theory.json"
const LETTER_PC := [0, 2, 4, 5, 7, 9, 11]
const LETTERS := ["C", "D", "E", "F", "G", "A", "B"]
const SOLFEGE := ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"]
const DEGREE_SEMIS := [0, 2, 4, 5, 7, 9, 11]
# Kwinty litery w tonacji durowej (C = 0, G = 1 … F = -1).
const LETTER_FIFTHS := [0, 2, 4, -1, 1, 3, 5]
const SHARP_ORDER := [3, 0, 4, 1, 5, 2, 6]   # F C G D A E B
const FLAT_ORDER := [6, 2, 5, 1, 4, 0, 3]    # B E A D G C F
const ACC_SIGNS := {-2: "𝄫", -1: "♭", 0: "", 1: "♯", 2: "𝄪"}
# Zapis toniki przy remisie (jak przyciski toniki w Encyklopedii): C C♯ D E♭ E F F♯ G A♭ A B♭ B.
const PREFERRED_ACC := [0, 1, 0, -1, 0, 0, 1, 0, -1, 0, -1, 0]

static var _data: Dictionary = {}
static var _by_id: Dictionary = {}


# --- Baza ---------------------------------------------------------------------------

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f:
			_data = JSON.parse_string(f.get_as_text())
			for kind in ["scales", "chords"]:
				for e in _data[kind]:
					_by_id[kind + ":" + str(e.id)] = e
	return _data


static func scales() -> Array:
	return data().get("scales", [])


static func chords() -> Array:
	return data().get("chords", [])


static func scale(id: String) -> Dictionary:
	data()
	return _by_id.get("scales:" + id, {})


static func chord(id: String) -> Dictionary:
	data()
	return _by_id.get("chords:" + id, {})


# Nazwa w języku programu (zapasowo angielska). entry – skala, akord, kategoria albo alias.
static func local_name(entry: Dictionary, lang := "") -> String:
	if lang.is_empty():
		lang = TranslationServer.get_locale().substr(0, 2)
	var names: Dictionary = entry.get("name", entry)
	return str(names.get(lang, names.get("en", "")))


# --- Stopnie i dźwięki --------------------------------------------------------------

# Stopień → [liczba stopnia, znak, półtony od toniki].
static func parse_degree(deg: String) -> Array:
	var acc := 0
	var i := 0
	while i < deg.length() and (deg[i] == "b" or deg[i] == "#"):
		acc += -1 if deg[i] == "b" else 1
		i += 1
	var n := int(deg.substr(i))
	return [n, acc, DEGREE_SEMIS[(n - 1) % 7] + 12 * ((n - 1) / 7) + acc]


static func pc(note: Dictionary) -> int:
	return posmod(LETTER_PC[note.l] + note.a, 12)


# Dźwięk na danym stopniu od toniki – litera wg numeru stopnia, znak dopasowany do wysokości.
static func spell(tonic: Dictionary, deg: String) -> Dictionary:
	var d := parse_degree(deg)
	var l: int = (tonic.l + d[0] - 1) % 7
	var target := posmod(pc(tonic) + d[2], 12)
	var a := posmod(target - LETTER_PC[l] + 6, 12) - 6
	return {"l": l, "a": a}


static func spell_all(tonic: Dictionary, degrees: Array) -> Array:
	var out := []
	for deg in degrees:
		out.append(spell(tonic, str(deg)))
	return out


# Nazwa dźwięku w wybranym zapisie (NoteNames: 0 międzynarodowy, 1 niemiecki, 2 solmizacja).
static func note_name(note: Dictionary, notation: int) -> String:
	var a: int = note.a
	if notation == NoteNames.GERMAN and note.l == 6:
		# Niemiecki/polski: H = B, B = B♭, a od nich dalsze znaki.
		return "B" + ACC_SIGNS.get(a + 1, "") if a <= -1 else "H" + ACC_SIGNS.get(a, "")
	var base: String = SOLFEGE[note.l] if notation == NoteNames.SOLFEGE else LETTERS[note.l]
	return base + ACC_SIGNS.get(a, "?")


# --- Znaki przykluczowe ---------------------------------------------------------------

static func major_fifths(tonic: Dictionary) -> int:
	return LETTER_FIFTHS[tonic.l] + 7 * int(tonic.a)


# Znaki przykluczowe skali na danej tonice (liczba kwint).
static func key_fifths(scale_entry: Dictionary, tonic: Dictionary) -> int:
	if scale_entry.has("parent"):
		return major_fifths(spell(tonic, str(scale_entry.parent)))
	var mode := str(scale_entry.get("sig", ""))
	var degs: Array = scale_entry.get("degrees", [])
	if mode.is_empty():
		mode = "major" if "3" in degs else "minor" if ("b3" in degs or "b6" in degs) else "major"
	return major_fifths(spell(tonic, "b3")) if mode == "minor" else major_fifths(tonic)


# Znak litery wynikający z przykluczowych (0 = bez znaku).
static func key_accidental(fifths: int, letter: int) -> int:
	if fifths > 0:
		return 1 if SHARP_ORDER.find(letter) < fifths else 0
	if fifths < 0:
		return -1 if FLAT_ORDER.find(letter) < -fifths else 0
	return 0


# Znaki przygodne do wypisania przy nutach (null = brak znaku, 0 = kasownik).
static func shown_accidentals(notes: Array, fifths: int) -> Array:
	var out := []
	for n in notes:
		out.append(null if int(n.a) == key_accidental(fifths, n.l) else int(n.a))
	return out


# --- Wybór zapisu toniki --------------------------------------------------------------

# Możliwe zapisy wysokości (pc) z jednym znakiem: np. 1 → C♯, D♭; 0 → C, B♯, D𝄫 pomijane.
static func spellings_of(p: int) -> Array:
	var out := []
	for l in 7:
		var a := posmod(p - LETTER_PC[l] + 6, 12) - 6
		if absi(a) <= 1:
			out.append({"l": l, "a": a})
	return out


# Zapis toniki dla skali: najmniej znaków przykluczowych (najwyżej 7), bez podwójnych znaków
# w dźwiękach; przy remisie – zapis z PREFERRED_ACC (F♯, ale E♭).
static func best_tonic(p: int, scale_entry: Dictionary) -> Dictionary:
	var best := {}
	var best_score := 1 << 30
	for t in spellings_of(p):
		var f := key_fifths(scale_entry, t)
		var notes := spell_all(t, scale_entry.get("degrees", []))
		var doubles := 0
		for n in notes:
			if absi(int(n.a)) >= 2:
				doubles += 1
		var score := absi(f) * 10 + doubles * 25 + (0 if t.a == PREFERRED_ACC[p] else 1)
		if absi(f) > 7:
			score += 1000
		if score < best_score:
			best_score = score
			best = t
	return best


# Zapis podstawy akordu: najmniej znaków w dźwiękach akordu, potem bez znaku, potem bemolowy
# (akordy jak w praktyce: B♭, E♭, A♭ – ale F♯ i C♯ przy remisie wg liczby znaków).
static func best_root(p: int, chord_entry: Dictionary) -> Dictionary:
	var best := {}
	var best_score := 1 << 30
	for t in spellings_of(p):
		var score := 0
		for n in spell_all(t, chord_entry.get("degrees", [])):
			score += absi(int(n.a)) * (4 if absi(int(n.a)) >= 2 else 1)
		score = score * 10 + (0 if t.a == 0 else 1)
		if score < best_score:
			best_score = score
			best = t
	return best
