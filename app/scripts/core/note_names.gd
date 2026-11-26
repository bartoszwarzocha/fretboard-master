# Fretboard Master – nazwy dźwięków. Korzysta z rdzenia C++ (FbmCore), a gdy biblioteka
# nie jest zbudowana – z identycznej implementacji zapasowej w GDScripcie.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name NoteNames
extends RefCounted

enum { INTERNATIONAL = 0, GERMAN = 1, SOLFEGE = 2 }

const NOTATION_LABELS: Array[String] = [
	"International (C D E F G A B)",
	"German (C D E F G A H, B = B♭)",
	"Solfège (Do Re Mi Fa Sol La Si)",
]

const _NAMES := [
	["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"],
	["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "B", "H"],
	["Do", "Do♯", "Re", "Re♯", "Mi", "Fa", "Fa♯", "Sol", "Sol♯", "La", "La♯", "Si"],
]


static func core_available() -> bool:
	return ClassDB.class_exists(&"FbmCore")


static func core_version() -> String:
	if core_available():
		return str(ClassDB.class_call_static(&"FbmCore", &"version"))
	return ""


static func note_name(midi: int, notation: int, with_octave := false) -> String:
	if core_available():
		return str(ClassDB.class_call_static(&"FbmCore", &"note_name", midi, notation, with_octave))
	var pc := posmod(midi, 12)
	var text: String = _NAMES[clampi(notation, 0, 2)][pc]
	if with_octave:
		text += str((midi - pc) / 12 - 1)
	return text


static func chromatic_scale(notation: int, from_midi := 60) -> String:
	var parts: PackedStringArray = []
	for i in 12:
		parts.append(note_name(from_midi + i, notation))
	return " ".join(parts)
