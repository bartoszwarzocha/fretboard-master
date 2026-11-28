# Fretboard Master – superpozycje: ułożenie skali (arpeggia, akordu) w zakresie progów tak, by każda
# wysokość dźwięku była zagrana raz, w jednym miejscu gryfu, od najniższej do najwyższej.
# Zakres dowolnej szerokości: wariant dzieli się na pozycje ręki (każda najwyżej 5 progów, puste struny
# poza pozycją); przejście do nowej pozycji – przesunięcie ręki. Dźwięki rosnąco, struny tylko w górę.
# Programowanie dynamiczne po kolejnych wysokościach; stan: struna, pozycja ręki (od–do), liczba dźwięków
# na bieżącej strunie (styl „3 dźwięki na strunę”); w każdym stanie MAX_VARIANTS najtańszych dróg.
# Koszt: rozciąganie palców, przesunięcia ręki, pominięte dźwięki, w stylu 3 na strunę – liczba dźwięków.
# Wynik: najwyżej MAX_VARIANTS wariantów od najwygodniejszego; każdy – [{s, f, midi, pos}] rosnąco
# (pos – numer pozycji ręki od 0).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name Superposition
extends RefCounted

const MAX_VARIANTS := 5
const HAND := 4               # rozpiętość jednej pozycji: najwyżej 4 progi różnicy (5 progów)
const STRETCH := 4.0          # każdy próg rozpiętości ponad 3 (palec poza pozycją)
const SHIFT := 8.0            # przesunięcie ręki
const SHIFT_FRET := 0.5       # za każdy próg przesunięcia
const SKIP_COST := 30.0       # pominięty dźwięk (nie mieści się w żadnym grywalnym układzie)
const SPREAD := 12.0          # warianty droższe od najlepszego o więcej – odrzucane
const NPS_OVER := 6.0         # styl 3 na strunę: każdy dźwięk ponad 3 na strunie
const NPS_UNDER := 3.0        # styl 3 na strunę: każdy brakujący do 3 na opuszczanej strunie
const BEAM := 45.0            # drogi droższe od najtańszej w warstwie o więcej – odrzucane

var _three := false


# open_midi: dźwięki pustych strun (indeks 0 = struna najwyższa), pcs: {wysokość 0–11: true}.
static func variants(open_midi: Array, pcs: Dictionary, from: int, to: int, style := "") -> Array:
	if to < from:
		return []
	return Superposition.new()._solve(open_midi, pcs, from, to, style == "3nps")


func _solve(open_midi: Array, pcs: Dictionary, from: int, to: int, three: bool) -> Array:
	var strings := open_midi.size()
	_three = three
	var by_pitch := {}
	for s in strings:
		for f in range(from, to + 1):
			var m: int = open_midi[s] + f
			if pcs.has(posmod(m, 12)):
				if not by_pitch.has(m):
					by_pitch[m] = []
				by_pitch[m].append(Vector2i(s, f))
	var pitches: Array = by_pitch.keys()
	pitches.sort()
	if pitches.is_empty():
		return []
	# Stan: [struna, początek pozycji, koniec pozycji, dźwięki na strunie, numer pozycji]; pozycja -1 –
	# jeszcze bez palców (same puste struny). Droga: [koszt, komórka lub null, poprzednia droga, stan].
	var start := [strings, -1, -1, 0, 0]
	var layer := {_key(start): [[0.0, null, null, start]]}
	for k in pitches.size():
		var next := {}
		var best := INF
		for key in layer:
			best = minf(best, layer[key][0][0])
		for key in layer:
			for path in layer[key]:
				if path[0] > best + BEAM:
					break
				var st: Array = path[3]
				# Pominięcie dźwięku – stan bez zmian.
				_add(next, [path[0] + SKIP_COST, null, path, st])
				for p in by_pitch[pitches[k]]:
					var s: int = p.x
					var f: int = p.y
					if s > st[0]:
						continue   # struny tylko w górę (indeks maleje)
					var cost: float = path[0]
					var cnt: int = st[3] + 1 if s == st[0] else 1
					if three:
						if s != st[0] and st[0] < strings and st[3] > 0:
							cost += maxi(0, 3 - st[3]) * NPS_UNDER
						if cnt > 3:
							cost += NPS_OVER
					var lo: int = st[1]
					var hi: int = st[2]
					var pos: int = st[4]
					if f > 0:
						if lo < 0:
							lo = f
							hi = f
						else:
							var nlo := mini(lo, f)
							var nhi := maxi(hi, f)
							if nhi - nlo <= HAND:
								cost += (maxi(0, nhi - nlo - 3) - maxi(0, hi - lo - 3)) * STRETCH
								lo = nlo
								hi = nhi
							else:
								var dist := f - hi if f > hi else lo - f
								cost += SHIFT + dist * SHIFT_FRET
								lo = f
								hi = f
								pos += 1
					var ns := [s, lo, hi, mini(cnt, 4), pos]
					_add(next, [cost, p, path, ns])
		layer = next
	var ends := []
	for key in layer:
		for path in layer[key]:
			var c: float = path[0]
			var st: Array = path[3]
			if three and st[0] < strings and st[3] > 0:
				c += maxi(0, 3 - st[3]) * NPS_UNDER
			ends.append([c, path])
	ends.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	if ends.is_empty():
		return out
	var limit: float = ends[0][0] + SPREAD
	for e in ends:
		if e[0] > limit or out.size() >= MAX_VARIANTS:
			break
		out.append(_unwind(e[1], pitches))
	return out


# Numer pozycji nie wchodzi do klucza (koszt przesunięć już w drodze); liczba dźwięków na strunie – tylko
# w stylu 3 na strunę.
func _key(st: Array) -> int:
	return ((st[0] * 32 + st[1] + 1) * 32 + st[2] + 1) * 8 + (st[3] if _three else 0)


# Najwyżej MAX_VARIANTS najtańszych dróg w każdym stanie.
func _add(layer: Dictionary, path: Array) -> void:
	var key := _key(path[3])
	if not layer.has(key):
		layer[key] = [path]
		return
	var list: Array = layer[key]
	if list.size() >= MAX_VARIANTS and path[0] >= list[list.size() - 1][0]:
		return
	var i := list.size()
	while i > 0 and list[i - 1][0] > path[0]:
		i -= 1
	list.insert(i, path)
	if list.size() > MAX_VARIANTS:
		list.resize(MAX_VARIANTS)


func _unwind(path, pitches: Array) -> Array:
	var cells := []
	var states := []
	var node = path
	while node != null and node[2] != null:
		cells.push_front(node[1])
		states.push_front(node[3])
		node = node[2]
	var v := []
	for i in cells.size():
		var p = cells[i]
		if p != null:
			v.append({"s": p.x, "f": p.y, "midi": pitches[i], "pos": states[i][4]})
	return v
