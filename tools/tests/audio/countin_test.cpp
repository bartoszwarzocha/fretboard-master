// g++ -O2 -std=c++17 -Inative/src/audio -I<tsf> tools/tests/audio/countin_test.cpp native/src/audio/sequencer.cpp native/src/audio/looper.cpp -o t && ./t app/assets/sound/GeneralUser-GS.sf2
// Odliczanie pałeczkami: w takcie odliczania brzmią tylko pałeczki (na każde uderzenie), potem wzorzec;
// po zadanej liczbie taktów cisza; impuls pomiaru opóźnienia trafia dokładnie w zapowiedzianą próbkę.
#include "sequencer.h"
#include <cmath>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <vector>
int main(int argc, char **argv) {
    std::ifstream f(argv[1], std::ios::binary);
    std::vector<char> sf((std::istreambuf_iterator<char>(f)), {});
    fbm::Sequencer seq;
    const double rate = 48000;
    seq.set_sample_rate(rate);
    if (!seq.load_soundfont(sf.data(), (int)sf.size())) { std::puts("brak SF2"); return 1; }
    fbm::MetronomeConfig c;
    c.bpm = 120; c.mode = fbm::MetronomeMode::Drums; c.beats = 4; c.steps = 8; c.steps_per_beat = 2;
    for (int s = 0; s < 8; ++s) c.pattern[3][s] = 1;          // hi-hat na ósemki
    c.pattern[5][0] = 2; c.pattern[4][4] = 2;                 // stopa, werbel
    c.countin_bars = 1; c.countin_sticks = true; c.play_bars = 2;   // odliczanie + 1 takt nagrania
    seq.configure(c);
    seq.start();
    const int bar = int(rate * 2.0);                          // 4 uderzenia przy 120 BPM
    std::vector<float> buf(2 * 256);
    std::vector<float> mono;
    for (int done = 0; done < 3 * bar + 4800; done += 256) {
        seq.render(buf.data(), 256);
        for (int i = 0; i < 256; ++i) mono.push_back(buf[2 * i]);
    }
    const int64_t cs = seq.clock_start();
    // Onsety: energia w oknach 10 ms, wzrost > 8 dB.
    auto onsets = [&](int64_t a, int64_t b) {
        int n = 0; double prev = 1e-9;
        for (int64_t i = a; i + 480 <= b; i += 480) {
            double e = 1e-9;
            for (int k = 0; k < 480; ++k) e += mono[i + k] * mono[i + k];
            if (10 * std::log10(e / prev) > 8 && e > 1e-3) ++n;
            prev = e;
        }
        return n;
    };
    const int in_count = onsets(cs, cs + bar);
    const int in_bar1 = onsets(cs + bar, cs + 2 * bar);
    const int after = onsets(cs + 2 * bar, cs + 3 * bar);
    std::printf("start %lld, uderzenia w takcie odliczania: %d, w 1. takcie: %d, po końcu: %d\n", (long long)cs, in_count, in_bar1, after);
    // Impuls pomiaru: przed nim cisza po zatrzymaniu.
    seq.stop();
    for (int k = 0; k < 40; ++k) seq.render(buf.data(), 256);   // wybrzmienie
    const int64_t base = seq.frames_rendered();
    const int64_t p = seq.probe_click();
    std::vector<float> m2;
    for (int k = 0; k < 40; ++k) { seq.render(buf.data(), 256); for (int i = 0; i < 256; ++i) m2.push_back(buf[2 * i]); }
    int64_t first = -1;
    for (size_t i = 0; i < m2.size(); ++i) if (std::fabs(m2[i]) > 0.05f) { first = base + (int64_t)i; break; }
    std::printf("impuls: zapowiedziany %lld, pierwsza głośna próbka %lld\n", (long long)p, (long long)first);
    return (in_count == 4 && in_bar1 == 8 && after == 0 && first >= p && first <= p + 2) ? 0 : 1;
}
