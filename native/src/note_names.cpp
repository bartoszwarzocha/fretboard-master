// Fretboard Master – nazwy dźwięków
// Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#include "note_names.h"

#include <array>
#include <cmath>

namespace fbm {

namespace {

constexpr std::array<const char *, 12> kInternational = {
    "C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"
};
constexpr std::array<const char *, 12> kGerman = {
    "C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "B", "H"
};
constexpr std::array<const char *, 12> kSolfege = {
    "Do", "Do♯", "Re", "Re♯", "Mi", "Fa", "Fa♯", "Sol", "Sol♯", "La", "La♯", "Si"
};

int positive_mod(int value, int divisor) {
    const int r = value % divisor;
    return r < 0 ? r + divisor : r;
}

} // namespace

std::string note_name(int midi, Notation notation, bool with_octave) {
    const int pitch_class = positive_mod(midi, 12);
    std::string name;
    switch (notation) {
        case Notation::German: name = kGerman[pitch_class]; break;
        case Notation::Solfege: name = kSolfege[pitch_class]; break;
        case Notation::International:
        default: name = kInternational[pitch_class]; break;
    }
    if (with_octave) {
        const int octave = (midi - pitch_class) / 12 - 1;
        name += std::to_string(octave);
    }
    return name;
}

double midi_to_frequency(int midi, double a4_hz) {
    return a4_hz * std::pow(2.0, (midi - 69) / 12.0);
}

} // namespace fbm
