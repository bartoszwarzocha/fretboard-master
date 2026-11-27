# Fretboard Master – test teorii (pisownia, znaki przykluczowe, wybór toniki).
# Uruchom: godot --headless --path app -s ../tools/tests/theory_test.gd
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends SceneTree

var fails := 0


func names(notes: Array, notation := 0) -> String:
	var parts := []
	for n in notes:
		parts.append(Theory.note_name(n, notation))
	return " ".join(parts)


func check(label: String, got, want) -> void:
	if str(got) != str(want):
		fails += 1
		print("BŁĄD %s: jest «%s», powinno być «%s»" % [label, got, want])


func scale_case(id: String, p: int, want_tonic: String, want_notes: String, want_fifths: int) -> void:
	var s := Theory.scale(id)
	var t := Theory.best_tonic(p, s)
	check(id + " tonika", Theory.note_name(t, 0), want_tonic)
	check(id + " dźwięki", names(Theory.spell_all(t, s.degrees)), want_notes)
	check(id + " znaki", Theory.key_fifths(s, t), want_fifths)


func _init() -> void:
	scale_case("ionian", 3, "E♭", "E♭ F G A♭ B♭ C D", -3)
	scale_case("ionian", 1, "D♭", "D♭ E♭ F G♭ A♭ B♭ C", -5)
	scale_case("ionian", 6, "F♯", "F♯ G♯ A♯ B C♯ D♯ E♯", 6)
	scale_case("aeolian", 8, "G♯", "G♯ A♯ B C♯ D♯ E F♯", 5)
	scale_case("aeolian", 3, "E♭", "E♭ F G♭ A♭ B♭ C♭ D♭", -6)
	scale_case("dorian", 2, "D", "D E F G A B C", 0)
	scale_case("harmonic_minor", 9, "A", "A B C D E F G♯", 0)
	scale_case("lydian_dom", 0, "C", "C D E F♯ G A B♭", 0)
	scale_case("altered", 7, "G", "G A♭ B♭ C♭ D♭ E♭ F", -2)
	scale_case("penta_minor", 4, "E", "E G A B D", 1)
	scale_case("blues", 9, "A", "A C D E♭ E G", 0)
	scale_case("whole_tone", 0, "C", "C D E F♯ G♯ A♯", 0)
	var s := Theory.scale("harmonic_minor")
	var t := Theory.best_tonic(9, s)
	check("akc. A harm.", Theory.shown_accidentals(Theory.spell_all(t, s.degrees), 0), [null, null, null, null, null, null, 1])
	s = Theory.scale("ionian")
	t = Theory.best_tonic(3, s)
	check("akc. Es-dur", Theory.shown_accidentals(Theory.spell_all(t, s.degrees), -3), [null, null, null, null, null, null, null])
	check("niemiecki B", names([{"l": 6, "a": -1}, {"l": 6, "a": 0}, {"l": 6, "a": -2}], 1), "B H B♭")
	var c := Theory.chord("dim7")
	var r := Theory.best_root(11, c)
	check("B°7", names(Theory.spell_all(r, c.degrees)), "B D F A♭")
	c = Theory.chord("m7b5")
	check("Am7b5", names(Theory.spell_all({"l": 5, "a": 0}, c.degrees)), "A C E♭ G")
	c = Theory.chord("maj7")
	r = Theory.best_root(10, c)
	check("B♭maj7", names(Theory.spell_all(r, c.degrees)), "B♭ D F A")
	check("liczba skal", Theory.scales().size(), 69)
	# Każda skala na każdej z 12 tonik: znaki przykluczowe w zakresie ±7.
	for sc in Theory.scales():
		for p in 12:
			var tt := Theory.best_tonic(p, sc)
			var f := Theory.key_fifths(sc, tt)
			if absi(f) > 7:
				fails += 1
				print("BŁĄD %s na %d: %d znaków" % [sc.id, p, f])
	print("theory_test: %s (%d błędów)" % ["OK" if fails == 0 else "BŁĘDY", fails])
	quit(1 if fails else 0)
