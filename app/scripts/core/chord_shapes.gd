# Fretboard Master – chwyty akordów: wszystkie grywalne układy akordu na gryfie, od najniższej pozycji.
# Zasady: w basie (najniższa brzmiąca struna) – pryma; brzmią kolejne struny bez przerw (najmniej 4,
# przy trójdźwiękach także 3 najwyższe); rozpiętość palców najwyżej 4 progi; najwyżej 4 palce, przy czym
# dźwięki na najniższym progu chwytu mogą być zagrane barré (jeden palec), jeśli nad nimi nie ma pustej
# struny; w chwycie są wszystkie dźwięki akordu (w akordach z 4 i więcej dźwiękami kwinta może odpaść).
# Wynik: [{cells: [{s, f, midi}] (rosnąco), muted: [s], barre: {f, from_s, to_s} lub {}, fret: najniższy
# próg z palcem, 0 – chwyt z pustymi strunami}], posortowane od najniższej pozycji, w pozycji – od najwygodniejszego.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name ChordShapes
extends RefCounted

const SPAN := 3               # różnica progów między skrajnymi palcami (4 progi)
const MAX_PER_POS := 1        # najwyżej tyle chwytów na jedną pozycję (najniższy próg z palcem)
const MAX_SHAPES := 8
const OPEN_MAX := 4           # chwyty z pustymi strunami – palce najwyżej do tego progu

static var _cache := {}


# open_midi: puste struny (indeks 0 = najwyższa), pcs: {wysokość 0–11: true}, root: wysokość prymy,
# fifth: wysokość kwinty (−1 – brak; może zostać pominięta przy 4+ dźwiękach).
static func shapes(open_midi: Array, frets: int, pcs: Dictionary, root: int, fifth := -1) -> Array:
	var key := "%s|%d|%s|%d|%d" % [str(open_midi), frets, str(pcs.keys()), root, fifth]
	if _cache.has(key):
		return _cache[key]
	var out := ChordShapes.new()._find(open_midi, frets, pcs, root, fifth)
	_cache[key] = out
	return out


var _open: Array
var _n := 6
var _pcs: Dictionary
var _root := 0
var _fifth := -1
var _found := {}              # podpis chwytu → [koszt, chwyt]


func _find(open_midi: Array, frets: int, pcs: Dictionary, root: int, fifth: int) -> Array:
	_open = open_midi
	_n = open_midi.size()
	_pcs = pcs
	_root = root
	_fifth = fifth
	for p in range(0, frets - SPAN + 1):
		var choice := []
		choice.resize(_n)
		_walk(_n - 1, p, choice)
	var by_pos := {}
	for k in _found:
		var it: Array = _found[k]
		var sh: Dictionary = it[1]
		if not by_pos.has(sh.fret):
			by_pos[sh.fret] = []
		by_pos[sh.fret].append(it)
	var positions := by_pos.keys()
	positions.sort()
	var out := []
	for p in positions:
		var list: Array = by_pos[p]
		list.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(list.size(), MAX_PER_POS):
			out.append(list[i][1])
			if out.size() >= MAX_SHAPES:
				return out
	return out


# Struny od najniższej (indeks n−1) do najwyższej (0); -1 – struna wytłumiona.
func _walk(s: int, p: int, choice: Array) -> void:
	if s < 0:
		_check(choice)
		return
	choice[s] = -1
	_walk(s - 1, p, choice)
	if _pcs.has(posmod(_open[s], 12)):
		choice[s] = 0
		_walk(s - 1, p, choice)
	for f in range(maxi(p, 1), p + SPAN + 1):
		if _pcs.has(posmod(_open[s] + f, 12)):
			choice[s] = f
			_walk(s - 1, p, choice)
	choice[s] = -1


func _check(choice: Array) -> void:
	# Brzmiące struny – ciągły odcinek (low – najniższa, high – najwyższa brzmiąca).
	var low := -1
	var high := -1
	for s in _n:
		if choice[s] >= 0:
			if high < 0:
				high = s
			low = s
	if low < 0:
		return
	for s in range(high, low + 1):
		if choice[s] < 0:
			return
	var count := low - high + 1
	if count < 3 or (count < 4 and _pcs.size() > 3) or (count == 3 and high != 0):
		return
	if posmod(_open[low] + choice[low], 12) != _root:
		return
	var have := {}
	var lo := 99
	var hi := 0
	for s in range(high, low + 1):
		var f: int = choice[s]
		have[posmod(_open[s] + f, 12)] = true
		if f > 0:
			lo = mini(lo, f)
			hi = maxi(hi, f)
	for pc in _pcs:
		if not have.has(pc) and not (pc == _fifth and _pcs.size() >= 4):
			return
	var has_open := false
	for s in range(high, low + 1):
		if choice[s] == 0:
			has_open = true
	if lo == 99:
		lo = 0
		hi = 0
	if hi - lo > SPAN:
		return
	# Puste struny tylko w chwytach przy siodełku (palce najwyżej do 4. progu).
	if has_open and hi > OPEN_MAX:
		return
	# Palce: dźwięki na najniższym progu – barré, gdy jest ich kilka i nad nimi nie ma pustej struny.
	var at_lo := []
	var others := 0
	for s in range(high, low + 1):
		var f: int = choice[s]
		if f == lo and lo > 0:
			at_lo.append(s)
		elif f > 0:
			others += 1
	var barre := {}
	var fingers := others + at_lo.size()
	if at_lo.size() >= 2:
		var b_hi: int = at_lo.min()      # najwyższa i najniższa struna barré
		var b_low: int = at_lo.max()
		var ok := true
		for s in range(b_hi, b_low):
			if choice[s] == 0:
				ok = false
		if ok:
			fingers = others + 1
			barre = {"f": lo, "from_s": b_hi, "to_s": b_low}
		elif b_low - b_hi > 1:
			return   # ten sam próg na odległych strunach z pustą struną pomiędzy – niegrywalne
	if fingers > 4:
		return
	# Koszt: mniej strun, rozciągnięcie, więcej palców, barré – drożej.
	var cost := (6 - count) * 3.0 + (hi - lo) * 1.5 + fingers * 1.0 + (2.0 if not barre.is_empty() else 0.0)
	var cells := []
	var muted := []
	for s in range(_n - 1, -1, -1):
		if s < high or s > low:
			muted.append(s)
		else:
			cells.append({"s": s, "f": choice[s], "midi": _open[s] + choice[s]})
	# Palce: barré – 1; pozostałe dźwięki z palcem kolejno wg progu (przy równym – od niższej struny).
	var pressed := cells.filter(func(c): return c.f > 0 and not (not barre.is_empty() and c.f == lo and c.s >= barre.from_s and c.s <= barre.to_s))
	pressed.sort_custom(func(a, b): return a.f < b.f or (a.f == b.f and a.s > b.s))
	var next := 2 if not barre.is_empty() else 1
	for c in cells:
		c["finger"] = 0 if c.f == 0 else 1
	for c in pressed:
		c["finger"] = mini(next, 4)
		next += 1
	cells.sort_custom(func(a, b): return a.midi < b.midi)
	var sig := str(choice)
	# Pozycja: chwyty z pustymi strunami – pozycja otwarta (0), pozostałe – najniższy próg z palcem.
	var shape := {"cells": cells, "muted": muted, "barre": barre, "fret": 0 if has_open else lo}
	if not _found.has(sig) or _found[sig][0] > cost:
		_found[sig] = [cost, shape]
