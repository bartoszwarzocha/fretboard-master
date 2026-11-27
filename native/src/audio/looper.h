// Fretboard Master – looper rdzenia audio: odtwarzanie nagranych ścieżek w pętli, zgrane co do próbki
// z zegarem sekwencera (metronom albo automat perkusyjny jako podkład). Ścieżki są monofoniczne,
// każda ma swój zakres (przycięcie albo wybrany fragment) i głośność. Zmiany z wątku głównego pod
// blokadą; wątek dźwięku tylko próbuje ją przejąć (try_lock) – nigdy nie czeka.
// Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#pragma once

#include <atomic>
#include <cstdint>
#include <mutex>
#include <vector>

namespace fbm {

class Looper {
public:
    // --- wątek główny ---
    void clear();
    // Ścieżka: próbki od początku nagrania; słychać tylko zakres [from, to).
    void add(std::vector<float> &&samples, int64_t from, int64_t to, float gain);
    // Pętla [offset, offset + length) w próbkach ścieżek; zaczyna się `delay` próbek po pierwszym
    // uderzeniu sekwencera (np. po odliczaniu przy nagrywaniu z odsłuchem pozostałych ścieżek).
    void play(int64_t offset, int64_t length, int64_t delay);
    void stop();
    bool playing() const { return playing_.load(); }
    // Pozycja w próbkach ścieżek dla próbki wyjścia `frame` przy zegarze od `clock_start` (−1 – przed startem).
    int64_t position(int64_t frame, int64_t clock_start) const;

    // --- wątek dźwięku ---
    void mix(float *stereo, int frames, int64_t first_frame, int64_t clock_start);

private:
    struct Track {
        std::vector<float> data;
        int64_t from = 0;
        int64_t to = 0;
        float gain = 1.0f;
    };
    std::mutex mutex_;
    std::vector<Track> tracks_;
    std::atomic<bool> playing_{false};
    std::atomic<int64_t> offset_{0};
    std::atomic<int64_t> length_{0};
    std::atomic<int64_t> delay_{0};
};

} // namespace fbm
