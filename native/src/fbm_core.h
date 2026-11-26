// Fretboard Master – klasa rdzenia widoczna w Godocie
// Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

// Punkt wejścia do rdzenia C++. Na razie: wersja i teoria muzyki (nazwy dźwięków, częstotliwości).
// Metody statyczne – wywoływane z GDScriptu przez ClassDB.class_call_static("FbmCore", …).
class FbmCore : public Object {
    GDCLASS(FbmCore, Object)

protected:
    static void _bind_methods();

public:
    static String version();
    static String note_name(int midi, int notation, bool with_octave);
    static double midi_to_frequency(int midi, double a4_hz);
};

} // namespace godot
