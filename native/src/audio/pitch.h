// Fretboard Master – rozpoznawanie wysokości dźwięku metodą McLeoda (MPM, znormalizowana funkcja
// różnicowa kwadratów). Dobra dla gitary: odporna na silne wyższe harmoniczne, bez błędów oktawy
// typowych dla prostej autokorelacji.
// Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#pragma once

#include <vector>

namespace fbm {

struct PitchResult {
    double hz = 0.0;        // 0 – brak wyraźnego dźwięku
    double clarity = 0.0;   // 0–1, wysokość szczytu NSDF
    double level_db = -120.0;
};

class PitchDetector {
public:
    // Zakres: od niskiego H w stroju obniżonym (ok. 55 Hz) do 1500 Hz.
    PitchResult detect(const float *x, int n, double rate, double min_hz = 55.0, double max_hz = 1500.0);

private:
    std::vector<double> nsdf_;
};

} // namespace fbm
