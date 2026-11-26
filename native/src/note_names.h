// Fretboard Master – nazwy dźwięków
// Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#pragma once

#include <string>

namespace fbm {

// Zapis nazw dźwięków – ustawienie niezależne od języka programu.
enum class Notation : int {
    International = 0, // C C♯ D … A A♯ B
    German = 1,        // C C♯ D … A B H (B = B♭)
    Solfege = 2,       // Do Do♯ Re … La La♯ Si
};

// Nazwa dźwięku o numerze MIDI (60 = C4). Z oktawą w zapisie naukowym (C4, A4).
std::string note_name(int midi, Notation notation, bool with_octave);

// Częstotliwość dźwięku MIDI w strojeniu równomiernie temperowanym.
double midi_to_frequency(int midi, double a4_hz);

} // namespace fbm
