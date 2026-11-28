# Fretboard Master – śledzenie granego dźwięku z surowych odczytów rdzenia (FbmAudio.pitch(), ok. 30 razy
# na sekundę). To, czego wymaga spokojny, a dokładny odczyt (jak w dobrych tunerach):
# – bramka: tylko ramki dość głośne i wyraźne (pewność NSDF), reszta pomijana;
# – atak struny: pierwsze ok. 90 ms po szarpnięciu (dźwięk jeszcze „podjeżdża”) pomijane;
# – histereza dźwięku: zmiana półtonu dopiero po kilku zgodnych ramkach, a bieżący dźwięk trzymany
#   do ±65 centów (struna rozstrojona o pół tonu nie przeskakuje między dwoma dźwiękami);
# – wygładzanie: mediana z ostatnich ramek, potem filtr wykładniczy z adaptacją – spokojnie przy
#   stałym dźwięku, szybko przy zmianie (strojenie kluczem).
# Wynik: note – potwierdzony dźwięk (MIDI), value – wygładzona wysokość w półtonach (ułamkowa).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name PitchTracker
extends RefCounted

const MIN_CLARITY := 0.85
const MIN_DB := -55.0
const ATTACK := 0.09          # s pomijane po ataku
const GAP := 0.15             # s ciszy – następny dźwięk to nowy atak
const ONSET_DB := 6.0         # skok głośności – nowy atak (kolejne szarpnięcie tej samej struny)
const CONFIRM := 3            # zgodne ramki do zmiany dźwięku
const KEEP := 0.65            # półtonu – bieżący dźwięk trzymany mimo odchyłki
const MEDIAN := 5

var a4 := 440.0
var note := -1
var value := 0.0
var _hist: Array[float] = []
var _cand := -1
var _cand_n := 0
var _onset := -1.0
var _last_t := -1.0
var _last_db := -120.0


# Zmiana stroju odniesienia A4 – ta sama częstotliwość to inna wysokość w półtonach.
func set_a4(hz_a4: float) -> void:
	if note >= 0 and hz_a4 != a4:
		var d := 12.0 * log(a4 / hz_a4) / log(2.0)
		value += d
		for i in _hist.size():
			_hist[i] += d
	a4 = hz_a4


func reset() -> void:
	note = -1
	value = 0.0
	_hist.clear()
	_cand = -1
	_cand_n = 0
	_last_t = -1.0


# Nowa ramka z rdzenia; true – odczyt (note/value) się zmienił.
func feed(p: Dictionary, now: float) -> bool:
	var hz := float(p.get("hz", 0.0))
	var db := float(p.get("level_db", -120.0))
	if hz <= 0.0 or float(p.get("clarity", 0.0)) < MIN_CLARITY or db < MIN_DB:
		return false   # głośność porównywana z ostatnią dobrą ramką (pojedynczy zanik to nie nowy atak)
	if _last_t < 0.0 or now - _last_t > GAP or db - _last_db > ONSET_DB:
		_onset = now
	_last_t = now
	_last_db = db
	if now - _onset < ATTACK:
		return false
	var m := 69.0 + 12.0 * log(hz / a4) / log(2.0)
	if note >= 0 and absf(m - note) <= KEEP:
		_cand = -1
		_cand_n = 0
	else:
		var n := roundi(m)
		if n == _cand:
			_cand_n += 1
		else:
			_cand = n
			_cand_n = 1
		if note >= 0 and _cand_n < CONFIRM:
			return false
		note = n
		value = m
		_hist.clear()
		_hist.append(m)
		_cand = -1
		_cand_n = 0
		return true
	_hist.append(m)
	if _hist.size() > MEDIAN:
		_hist.remove_at(0)
	var sorted := _hist.duplicate()
	sorted.sort()
	var med: float = sorted[sorted.size() / 2]
	var d := absf(med - value) * 100.0
	value = lerpf(value, med, clampf(0.12 + d / 40.0, 0.12, 0.6))
	return true


# Czas ostatniej przyjętej ramki (do wygaszania odczytu po wybrzmieniu).
func last_time() -> float:
	return _last_t


func hz() -> float:
	return a4 * pow(2.0, (value - 69.0) / 12.0)
