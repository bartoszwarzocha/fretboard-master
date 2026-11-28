# Test śledzenia dźwięku: godot --headless --path app -s ../tools/tests/pitch_tracker_test.gd
# Surowe odczyty z szumem ±8 ct, atakiem (+30 ct przez 60 ms), pojedynczymi błędami oktawy i cichymi
# ramkami; sprawdza rozrzut wyniku, opóźnienie zmiany dźwięku i odporność na pojedyncze skoki.
extends SceneTree


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var t := PitchTracker.new()
	var dt := 1.0 / 30.0
	var now := 0.0
	var out := []
	var raw := []
	# 1) A2 (45) – 2 s, atak, szum, dwa skoki oktawy, ramka cicha
	for i in 60:
		var cents := rng.randf_range(-8.0, 8.0) + (30.0 if i < 2 else 0.0) + 3.0
		var m := 45.0 + cents / 100.0
		if i == 20 or i == 35:
			m += 12.0
		var p := {"hz": 440.0 * pow(2.0, (m - 69.0) / 12.0), "clarity": 0.95, "level_db": -25.0 if i != 40 else -70.0}
		if t.feed(p, now) and i > 10:
			out.append((t.value - 45.0) * 100.0)
			raw.append(cents)
		now += dt
	var mean := 0.0
	for v in out:
		mean += v
	mean /= out.size()
	var sd := 0.0
	for v in out:
		sd += (v - mean) * (v - mean)
	sd = sqrt(sd / out.size())
	var rsd := 0.0
	for v in raw:
		rsd += (v - 3.0) * (v - 3.0)
	rsd = sqrt(rsd / raw.size())
	print("stały dźwięk: średnia %.2f ct (prawda 3,0), rozrzut %.2f ct (surowy %.2f ct), dźwięk %d" % [mean, sd, rsd, t.note])
	# 2) zmiana na D3 (50) bez przerwy – ile ramek do przełączenia
	var n := 0
	while t.note != 50 and n < 30:
		t.feed({"hz": 440.0 * pow(2.0, (50.0 - 69.0) / 12.0), "clarity": 0.95, "level_db": -20.0}, now)
		now += dt
		n += 1
	print("zmiana dźwięku po %d ramkach (%.0f ms)" % [n, n * dt * 1000.0])
	# 3) struna rozstrojona o 55 ct – bez przeskakiwania między dźwiękami
	t.reset()
	now += 1.0
	var flips := 0
	var last := -1
	for i in 60:
		var m := 50.55 + rng.randf_range(-0.08, 0.08)
		t.feed({"hz": 440.0 * pow(2.0, (m - 69.0) / 12.0), "clarity": 0.95, "level_db": -20.0}, now)
		if t.note >= 0 and last >= 0 and t.note != last:
			flips += 1
		if t.note >= 0:
			last = t.note
		now += dt
	print("rozstrojona o ~55 ct: zmian dźwięku %d" % flips)
	quit()
