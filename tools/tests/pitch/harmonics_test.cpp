// Test błędów oktawy detektora (sygnały z silną 2. harmoniczną, gitara i bas).
// g++ -O2 -std=c++17 -Inative/src/audio tools/tests/pitch/harmonics_test.cpp native/src/audio/pitch.cpp -o t && ./t
#include "pitch.h"
#include <cmath>
#include <cstdio>
#include <random>
#include <vector>
int main(int argc, char** argv) {
    fbm::PitchDetector d;
    const double rate = 48000; const int n = 4096;
    std::mt19937 rng(1); std::normal_distribution<double> no(0, 1);
    // profile: amplitudes of harmonics 1..8
    std::vector<std::vector<double>> profiles = {
        {1, .5, .3, .2, .1, .05, .03, .02},      // normalny
        {.3, 1, .4, .3, .2, .1, .05, .03},       // silna 2.
        {.15, 1, .2, .5, .1, .2, .05, .05},      // bardzo silna 2. i 4.
        {.08, 1, .1, .6, .05, .3, .02, .1},      // prawie bez podstawowej (bas, mały głośnik)
        {.5, 1, .8, .6, .5, .3, .2, .1},         // jasna struna
    };
    int total = 0, up = 0, down = 0, other = 0, none = 0;
    for (int midi = 23; midi <= 88; ++midi) {
        double f0 = 440 * std::pow(2.0, (midi - 69) / 12.0);
        double minhz = midi < 40 ? 27 : 55;
        for (double noise : {0.003, 0.03}) for (double dec : {1.0, 0.0}) for (auto& pr : profiles) for (int ph = 0; ph < 4; ++ph) {
            std::vector<float> x(n);
            double inh = 0.0001 * ph; // lekka nieharmoniczność
            for (int i = 0; i < n; ++i) {
                double t = i / rate, v = 0;
                for (int h = 1; h <= 8; ++h) {
                    double fh = f0 * h * std::sqrt(1 + inh * h * h) * (1 + 0.002 * std::sin(2 * M_PI * 5 * t));
                    if (fh > rate / 2) break;
                    v += pr[h - 1] * std::exp(-dec * t * (1.5 + h * 0.8)) * std::sin(2 * M_PI * fh * t + h * ph);
                }
                x[i] = float(0.2 * v + noise * no(rng));
            }
            auto r = d.detect(x.data(), n, rate, minhz);
            ++total;
            if (r.hz <= 0) { ++none; continue; }
            double c = 12 * std::log2(r.hz / f0);
            if (std::fabs(c) < 0.5) continue;
            if (std::fabs(c - 12) < 0.5) ++up; else if (std::fabs(c + 12) < 0.5) ++down; else ++other;
            if (argc > 1) printf("midi %d prof %.2f -> %+.2f st\n", midi, pr[0], c);
        }
    }
    printf("total %d  octave_up %d  octave_down %d  other %d  none %d\n", total, up, down, other, none);
}
