// Fretboard Master – klasa rdzenia widoczna w Godocie
// Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#include "fbm_core.h"

#include "note_names.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

namespace {
constexpr const char *kCoreVersion = "0.1.0";
}

void FbmCore::_bind_methods() {
    ClassDB::bind_static_method("FbmCore", D_METHOD("version"), &FbmCore::version);
    ClassDB::bind_static_method("FbmCore", D_METHOD("note_name", "midi", "notation", "with_octave"),
            &FbmCore::note_name, DEFVAL(false));
    ClassDB::bind_static_method("FbmCore", D_METHOD("midi_to_frequency", "midi", "a4_hz"),
            &FbmCore::midi_to_frequency, DEFVAL(440.0));
}

String FbmCore::version() {
    return String(kCoreVersion);
}

String FbmCore::note_name(int midi, int notation, bool with_octave) {
    const auto name = fbm::note_name(midi, static_cast<fbm::Notation>(notation), with_octave);
    return String::utf8(name.c_str());
}

double FbmCore::midi_to_frequency(int midi, double a4_hz) {
    return fbm::midi_to_frequency(midi, a4_hz);
}

} // namespace godot
