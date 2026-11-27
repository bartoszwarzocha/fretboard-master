// Fretboard Master – rozpoznawanie wysokości dźwięku (zob. pitch.h).
// Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#include "pitch.h"

#include <algorithm>
#include <cmath>

namespace fbm {

PitchResult PitchDetector::detect(const float *x, int n, double rate, double min_hz, double max_hz) {
    PitchResult r;
    if (n < 64 || rate <= 0.0) {
        return r;
    }
    double mean = 0.0;
    for (int i = 0; i < n; ++i) {
        mean += x[i];
    }
    mean /= n;
    double energy = 0.0;
    for (int i = 0; i < n; ++i) {
        energy += (x[i] - mean) * (x[i] - mean);
    }
    const double rms = std::sqrt(energy / n);
    r.level_db = rms > 1e-9 ? 20.0 * std::log10(rms) : -120.0;
    if (r.level_db < -60.0) {
        return r;
    }

    const int min_lag = std::max(2, static_cast<int>(rate / max_hz));
    const int max_lag = std::min(n / 2, static_cast<int>(std::ceil(rate / min_hz)) + 2);
    if (max_lag <= min_lag + 2) {
        return r;
    }
    nsdf_.assign(static_cast<size_t>(max_lag + 1), 0.0);
    // m(τ) liczone przyrostowo: m(0) = 2·Σx², potem odejmujemy skrajne próbki.
    double m = 0.0;
    for (int i = 0; i < n; ++i) {
        const double v = x[i] - mean;
        m += 2.0 * v * v;
    }
    for (int tau = 0; tau <= max_lag; ++tau) {
        if (tau > 0) {
            const double a = x[tau - 1] - mean;
            const double b = x[n - tau] - mean;
            m -= a * a + b * b;
        }
        if (tau < min_lag / 2) {
            nsdf_[tau] = 1.0;
            continue;
        }
        double acf = 0.0;
        const int len = n - tau;
        for (int j = 0; j < len; ++j) {
            acf += (x[j] - mean) * (x[j + tau] - mean);
        }
        nsdf_[tau] = m > 1e-12 ? 2.0 * acf / m : 0.0;
    }

    // Szczyty w dodatnich odcinkach po pierwszym przejściu przez zero.
    std::vector<int> peaks;
    int tau = 1;
    while (tau < max_lag && nsdf_[tau] > 0.0) {
        ++tau;
    }
    while (tau < max_lag) {
        while (tau < max_lag && nsdf_[tau] <= 0.0) {
            ++tau;
        }
        int best = -1;
        while (tau < max_lag && nsdf_[tau] > 0.0) {
            if (best < 0 || nsdf_[tau] > nsdf_[best]) {
                best = tau;
            }
            ++tau;
        }
        if (best >= min_lag && best > 0 && best < max_lag) {
            peaks.push_back(best);
        }
    }
    if (peaks.empty()) {
        return r;
    }
    double top = 0.0;
    for (int p : peaks) {
        top = std::max(top, nsdf_[p]);
    }
    const double threshold = 0.9 * top;
    int chosen = peaks.front();
    for (int p : peaks) {
        if (nsdf_[p] >= threshold) {
            chosen = p;
            break;
        }
    }
    // Interpolacja paraboliczna wokół szczytu.
    const double y0 = nsdf_[chosen - 1], y1 = nsdf_[chosen], y2 = nsdf_[chosen + 1];
    const double den = y0 - 2.0 * y1 + y2;
    const double shift = std::fabs(den) > 1e-12 ? 0.5 * (y0 - y2) / den : 0.0;
    const double period = chosen + std::clamp(shift, -0.5, 0.5);
    r.clarity = std::min(1.0, y1 - 0.25 * (y0 - y2) * shift);
    if (r.clarity < 0.6 || period <= 0.0) {
        return r;
    }
    r.hz = rate / period;
    return r;
}

} // namespace fbm
