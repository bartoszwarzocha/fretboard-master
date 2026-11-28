# Fretboard Master – instrument: gitara (6–8 strun) albo gitara basowa (4–6 strun). Jedno miejsce,
# z którego gryf, tuner, pięciolinia i odsłuch biorą liczbę strun, strój i brzmienie MIDI.
# Stroje basu – dla 4 strun; bas 5-strunowy ma dodatkową niską strunę (H), 6-strunowy także wysoką (C).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name Instrument
extends RefCounted

# [identyfikator, nazwa, dźwięki pustych strun MIDI od najniższej]
const BASS_TUNINGS := [
	["standard", "Standard", [28, 33, 38, 43]],
	["drop_d", "Drop D", [26, 33, 38, 43]],
	["half_down", "Half step down", [27, 32, 37, 42]],
	["full_down", "Whole step down", [26, 31, 36, 41]],
	["drop_c", "Drop C", [24, 31, 36, 41]],
]
# Struny dodatkowe gitary (7. i 8.) poniżej najniższej struny stroju.
const GUITAR_EXTRA_LOW := [35, 30]
const BASS_PROGRAMS := [33, 34, 35, 32, 38]


static func is_bass() -> bool:
	return str(App.setting(&"instrument")) == "bass"


static func tuning_key() -> StringName:
	return &"bass_tuning" if is_bass() else &"tuning"


static func tuning_id() -> String:
	return str(App.setting(tuning_key()))


static func string_count() -> int:
	if is_bass():
		return clampi(int(App.setting(&"bass_strings")), 4, 6)
	return clampi(int(App.setting(&"strings")), 6, 8)


# Dźwięki bazowe stroju (6 strun gitary albo 4 strun basu), od najniższej.
static func base_tuning(id := "") -> Array:
	if id.is_empty():
		id = tuning_id()
	if is_bass():
		for t in BASS_TUNINGS:
			if t[0] == id:
				return t[2]
		return BASS_TUNINGS[0][2]
	return ModuleHeader.TUNING_MIDI.get(id, ModuleHeader.TUNING_MIDI["standard"])


# Wszystkie struny bieżącego instrumentu, od najniższej (z dodatkowymi strunami).
static func open_low_to_high(id := "") -> Array:
	var notes: Array = base_tuning(id).duplicate()
	var n := string_count()
	if is_bass():
		if n >= 5:
			notes.push_front(int(notes[1]) - 10)    # niskie H – kwarta pod E
		if n >= 6:
			notes.push_back(int(notes[notes.size() - 1]) + 5)   # wysokie C – kwarta nad G
	else:
		for i in n - 6:
			notes.push_front(GUITAR_EXTRA_LOW[i])
	return notes


# Program MIDI odsłuchu: dla basu – osobne ustawienie brzmienia basu.
static func midi_program() -> int:
	return int(App.setting(&"bass_midi_instrument" if is_bass() else &"midi_instrument"))


const FLAT_TUNINGS := ["half_down", "full_down", "drop_c"]


# Dźwięki stroju do opisu (od najniższej struny); stroje obniżone – z bemolami.
static func tuning_names(id: String) -> String:
	var parts := PackedStringArray()
	for m in open_low_to_high(id):
		parts.append(string_name(m, id))
	return " ".join(parts)


# Nazwa pustej struny: w strojach obniżonych – z bemolami (E♭ zamiast D♯).
static func string_name(m: int, id := "") -> String:
	if id.is_empty():
		id = tuning_id()
	return flat_name(m) if id in FLAT_TUNINGS else NoteNames.note_name(m, App.notation())


static func flat_name(m: int) -> String:
	var n := NoteNames.note_name(m, App.notation())
	if not "♯" in n:
		return n
	# Dźwięk z krzyżykiem – nazwa sąsiedniego wyższego z bemolem (np. A♯ → B♭, w zapisie niemieckim B).
	var up := NoteNames.note_name(m + 1, App.notation())
	if App.notation() == NoteNames.GERMAN and up == "H":
		return "B"
	return up + "♭"
