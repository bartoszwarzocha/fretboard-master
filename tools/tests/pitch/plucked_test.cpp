// g++ -O2 -std=c++17 -Inative/src/audio tools/tests/pitch/plucked_test.cpp native/src/audio/pitch.cpp -o t && ./t
// Struna szarpana (Karplus-Strong) z miejscem szarpnięcia – realistyczne widmo; okna w kolejnych chwilach.
#include "pitch.h"
#include <cmath>
#include <cstdio>
#include <random>
#include <vector>
int main() {
    fbm::PitchDetector d; const double rate = 48000; const int n = 4096;
    std::mt19937 rng(7); std::uniform_real_distribution<double> u(-1, 1);
    int total = 0, up = 0, down = 0, other = 0, none = 0;
    for (int midi = 23; midi <= 88; ++midi) for (double pick : {0.08, 0.13, 0.25, 0.5}) {
        double f0 = 440 * std::pow(2.0, (midi - 69) / 12.0);
        int L = int(rate / f0);
        std::vector<double> buf(L);
        for (auto& v : buf) v = u(rng);
        // filtr grzebieniowy miejsca szarpnięcia: x[i] - x[i - pick*L]
        int k = std::max(1, int(pick * L));
        std::vector<double> b2(L);
        for (int i = 0; i < L; ++i) b2[i] = buf[i] - buf[(i - k + L) % L];
        buf = b2;
        int len = int(rate * 1.5);
        std::vector<float> y(len);
        int idx = 0;
        for (int i = 0; i < len; ++i) {
            double cur = buf[idx], nxt = buf[(idx + 1) % L];
            y[i] = float(cur * 0.3);
            buf[idx] = 0.4985 * (cur + nxt);
            idx = (idx + 1) % L;
        }
        for (int start : {0, 2400, 9600, 24000, 48000}) {
            std::vector<float> x(y.begin() + start, y.begin() + start + n);
            for (auto& v : x) v += float(0.002 * u(rng));
            auto r = d.detect(x.data(), n, rate, midi < 40 ? 27 : 55);
            ++total;
            if (r.hz <= 0) { ++none; continue; }
            double c = 12 * std::log2(r.hz / (rate / (L + 0.5)));
            if (std::fabs(c) < 0.6) continue;
            if (std::fabs(c - 12) < 0.6) ++up; else if (std::fabs(c + 12) < 0.6) ++down; else { ++other; printf("other midi %d pick %.2f start %d c %.2f\n", midi, pick, start, c); }
        }
    }
    printf("KS total %d  octave_up %d  octave_down %d  other %d  none %d\n", total, up, down, other, none);
}
