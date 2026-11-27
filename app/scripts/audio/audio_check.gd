# Fretboard Master – sprawdzanie dźwięku w ustawieniach: poziom sygnału z wejścia, rozpoznany dźwięk,
# odsłuch gitary, dźwięk próbny i pomiar opóźnienia (pętla wyjście → wejście).
# Działa tylko, gdy zakładka „Dźwięk i MIDI” jest otwarta – potem węzeł jest usuwany razem z nią.
# Docelowo (sterowniki ASIO/WDM-KS, bufor w próbkach) zastąpi to rdzeń audio w C++ (PortAudio);
# tu używany jest dźwięk Godota (WASAPI).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name AudioCheck
extends Node

signal level_changed(db: float)
signal pitch_changed(hz: float)          # 0 = brak rozpoznanego dźwięku
signal latency_measured(ms: float)       # < 0 = nie wykryto sygnału

const BUS := &"FbmInput"
const PITCH_EVERY := 0.1                 # s między kolejnymi rozpoznaniami dźwięku
const DECIMATE := 4                      # 48 kHz → 12 kHz do rozpoznawania
const WINDOW := 512                      # próbki po decymacji (ok. 43 ms)

var channel := 0                         # 0 – wejście 1 (lewy kanał), 1 – wejście 2 (prawy)
var _mic: AudioStreamPlayer
var _capture: AudioEffectCapture
var _tone: AudioStreamPlayer
var _ring := PackedFloat32Array()        # ostatnie próbki (po decymacji) do rozpoznawania
var _pitch_t := 0.0
var _level := -90.0
var _measure_t := -1.0                   # czas od kliknięcia w pomiarze opóźnienia (s); -1 = brak pomiaru
var _click_usec := 0


func _ready() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, &"Master")
		AudioServer.add_bus_effect(idx, AudioEffectCapture.new(), 0)
	_capture = AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture
	_capture.clear_buffer()
	set_monitor(bool(App.setting(&"input_monitor")))
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = BUS
	add_child(_mic)
	_mic.play()
	_tone = AudioStreamPlayer.new()
	add_child(_tone)


func _exit_tree() -> void:
	if _mic:
		_mic.stop()
	var idx := AudioServer.get_bus_index(BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, -80.0)


## Odsłuch gitary: wejście słychać w słuchawkach (z opóźnieniem dźwięku Godota).
func set_monitor(on: bool) -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, 0.0 if on else -80.0)


func _process(delta: float) -> void:
	var frames := _capture.get_frames_available()
	if frames <= 0:
		return
	var buf := _capture.get_buffer(frames)
	var peak := 0.0
	var i := 0
	for f in buf:
		var v: float = f.x if channel == 0 else f.y
		peak = maxf(peak, absf(v))
		if i % DECIMATE == 0:
			_ring.append(v)
		i += 1
	if _ring.size() > WINDOW:
		_ring = _ring.slice(_ring.size() - WINDOW)
	var db := linear_to_db(maxf(peak, 0.00001))
	_level = maxf(db, _level - 60.0 * delta)   # wskazanie opada płynnie
	level_changed.emit(_level)

	if _measure_t >= 0.0:
		_measure_t += delta
		if peak > 0.3:
			latency_measured.emit((Time.get_ticks_usec() - _click_usec) / 1000.0)
			_measure_t = -1.0
		elif _measure_t > 1.5:
			latency_measured.emit(-1.0)
			_measure_t = -1.0

	_pitch_t += delta
	if _pitch_t >= PITCH_EVERY:
		_pitch_t = 0.0
		pitch_changed.emit(_detect_pitch() if _level > -45.0 else 0.0)


# Rozpoznanie wysokości: znormalizowana funkcja różnicowa (jak w YIN) z interpolacją
# paraboliczną; zakres 70–1000 Hz (gitara). Wersja uproszczona – docelowo rdzeń C++.
func _detect_pitch() -> float:
	if _ring.size() < WINDOW:
		return 0.0
	var rate := AudioServer.get_mix_rate() / DECIMATE
	var min_lag := int(rate / 1000.0)
	var max_lag := mini(int(rate / 70.0), WINDOW / 2)
	var half := WINDOW - max_lag
	var d := PackedFloat32Array()
	d.resize(max_lag + 1)
	var running := 0.0
	var best := -1
	for lag in range(1, max_lag + 1):
		var s := 0.0
		for j in half:
			var diff := _ring[j] - _ring[j + lag]
			s += diff * diff
		running += s
		d[lag] = s * lag / maxf(running, 1e-9)
		if lag >= min_lag + 2 and best < 0 and d[lag - 1] < 0.2 and d[lag - 1] <= d[lag] and d[lag - 1] <= d[lag - 2]:
			best = lag - 1
	if best < 0:
		return 0.0
	var a := d[best - 1]
	var b := d[best]
	var c := d[best + 1]
	var shift := 0.5 * (a - c) / maxf(a - 2.0 * b + c, 1e-9)
	return rate / (best + clampf(shift, -0.5, 0.5))


## Dźwięk próbny: szarpnięta struna A (110 Hz) – synteza Karplusa-Stronga, ok. 1,5 s.
func play_test_tone() -> void:
	_tone.stream = _pluck(110.0 * float(App.setting(&"a4")) / 440.0, 1.5)
	_tone.play()


## Pomiar opóźnienia: krótkie kliknięcie na wyjściu i oczekiwanie na nie na wejściu
## (kabel z wyjścia do wejścia albo mikrofon przy głośniku).
func measure_latency() -> void:
	var rate := AudioServer.get_mix_rate()
	var data := PackedByteArray()
	data.resize(int(rate * 0.01) * 2)
	for k in data.size() / 2:
		data.encode_s16(k * 2, 30000 if k < 24 else 0)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(rate)
	wav.data = data
	_tone.stream = wav
	_capture.clear_buffer()
	_tone.play()
	_click_usec = Time.get_ticks_usec()
	_measure_t = 0.0


static func _pluck(hz: float, seconds: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * seconds)
	var period := maxi(int(rate / hz), 2)
	var line := PackedFloat32Array()
	line.resize(period)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in period:
		line[k] = rng.randf_range(-1.0, 1.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	var pos := 0
	for k in n:
		var v := line[pos]
		var nxt := line[(pos + 1) % period]
		line[pos] = 0.996 * 0.5 * (v + nxt)
		pos = (pos + 1) % period
		data.encode_s16(k * 2, int(clampf(v * 0.6, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
