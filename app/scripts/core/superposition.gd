# Fretboard Master – superpozycje: ułożenie skali (arpeggia, akordu) w zakresie progów tak, by każda
# wysokość dźwięku była zagrana raz, w jednym miejscu gryfu, od najniższej do najwyższej.
# Warianty: przeszukiwanie z odcinaniem (branch and bound) – dźwięki rosnąco, struny tylko w górę
# (z niższej na wyższą), na jednej strunie rozpiętość najwyżej 5 progów; koszt: rozciąganie palców,
# rozpiętość całej pozycji, pominięte dźwięki, w stylu „3 dźwięki na strunę” – liczba dźwięków na strunie.
# Wynik: najwyżej MAX_VARIANTS wariantów od najwygodniejszego; każdy – [{s, f, midi}] rosnąco.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name Superposition
extends RefCounted

const MAX_VARIANTS := 5
const MAX_WIDTH := 8          # najszerszy zakres (liczba progów) z superpozycją
const NODE_LIMIT := 80000
const SKIP_COST := 30.0       # pominięty dźwięk (nie mieści się w żadnym grywalnym układzie)
const SPREAD := 12.0          # warianty droższe od najlepszego o więcej – odrzucane

var _cands: Array = []        # dla każdej wysokości: [Vector2i(struna, próg)]
var _pitches: Array = []
var _strings := 6
var _three := false
var _best: Array = []         # [[koszt, przypisanie]] rosnąco
var _nodes := 0
var _assign: Array = []
var _lo: Array = []
var _hi: Array = []
var _count: Array = []


# open_midi: dźwięki pustych strun (indeks 0 = struna najwyższa), pcs: {wysokość 0–11: true}.
static func variants(open_midi: Array, pcs: Dictionary, from: int, to: int, style := "") -> Array:
	if to - from + 1 > MAX_WIDTH or to < from:
		return []
	var sp := Superposition.new()
	return sp._solve(open_midi, pcs, from, to, style == "3nps")


func _solve(open_midi: Array, pcs: Dictionary, from: int, to: int, three: bool) -> Array:
	_strings = open_midi.size()
	_three = three
	var by_pitch := {}
	for s in _strings:
		for f in range(from, to + 1):
			var m: int = open_midi[s] + f
			if pcs.has(posmod(m, 12)):
				if not by_pitch.has(m):
					by_pitch[m] = []
				by_pitch[m].append(Vector2i(s, f))
	_pitches = by_pitch.keys()
	_pitches.sort()
	if _pitches.is_empty():
		return []
	_cands = []
	for m in _pitches:
		var c: Array = by_pitch[m]
		c.sort_custom(func(a, b): return a.x > b.x)   # najpierw niższa struna
		_cands.append(c)
	_lo.resize(_strings)
	_hi.resize(_strings)
	_count.resize(_strings)
	for s in _strings:
		_lo[s] = 99
		_hi[s] = -1
		_count[s] = 0
	_assign.resize(_pitches.size())
	_dfs(0, _strings, 0.0)
	var out := []
	if _best.is_empty():
		return out
	var limit: float = _best[0][0] + SPREAD
	for b in _best:
		if b[0] > limit:
			break
		var v := []
		for i in _pitches.size():
			var p = b[1][i]
			if p != null:
				v.append({"s": p.x, "f": p.y, "midi": _pitches[i]})
		out.append(v)
	return out


func _bound_full() -> float:
	return _best[_best.size() - 1][0] if _best.size() >= MAX_VARIANTS else INF


# Koszt częściowy (nie maleje przy dokładaniu dźwięków): rozciąganie na strunach, rozpiętość pozycji,
# za dużo dźwięków na strunie w stylu 3 na strunę.
func _partial() -> float:
	var c := 0.0
	var glo := 99
	var ghi := -1
	for s in _strings:
		if _hi[s] < 0:
			continue
		c += maxi(0, _hi[s] - _lo[s] - 3) * 4.0
		if _three:
			c += maxi(0, _count[s] - 3) * 6.0
		glo = mini(glo, _lo[s])
		ghi = maxi(ghi, _hi[s])
	if ghi >= 0:
		c += maxi(0, ghi - glo - 4) * 2.0
	return c


func _dfs(k: int, last_s: int, skip_cost: float) -> void:
	_nodes += 1
	if _nodes > NODE_LIMIT:
		return
	var part := _partial() + skip_cost
	if part >= _bound_full():
		return
	if k == _pitches.size():
		var total := part
		if _three:
			for s in _strings:
				if _count[s] > 0 and _count[s] < 3:
					total += (3 - _count[s]) * 3.0
		_keep(total)
		return
	for p in _cands[k]:
		var s: int = p.x
		if s > last_s:
			continue   # struny tylko w górę (indeks maleje)
		var f: int = p.y
		var lo0: int = _lo[s]
		var hi0: int = _hi[s]
		var nlo := mini(lo0, f)
		var nhi := maxi(hi0, f)
		if nhi - nlo > 4:
			continue
		_lo[s] = nlo
		_hi[s] = nhi
		_count[s] += 1
		_assign[k] = p
		_dfs(k + 1, s, skip_cost)
		_count[s] -= 1
		_lo[s] = lo0
		_hi[s] = hi0
	_assign[k] = null
	_dfs(k + 1, last_s, skip_cost + SKIP_COST)


func _keep(cost: float) -> void:
	_best.append([cost, _assign.duplicate()])
	_best.sort_custom(func(a, b): return a[0] < b[0])
	if _best.size() > MAX_VARIANTS:
		_best.resize(MAX_VARIANTS)
