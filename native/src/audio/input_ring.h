// Fretboard Master – bufor pierścieniowy wejścia audio (jeden zapisujący – wątek dźwięku, dowolnie wielu
// czytających). Każda próbka ma bezwzględny numer, liczony od otwarcia strumienia; przy strumieniu
// dwukierunkowym ten sam numer ma próbka wyjścia z tego samego wywołania, co pozwala zgrać nagranie
// z metronomem (przyszły looper) po odjęciu opóźnienia wejścia i wyjścia.
// Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#pragma once

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <vector>

namespace fbm {

class InputRing {
public:
    static constexpr int kSize = 1 << 18;   // ok. 5,5 s przy 48 kHz
    static constexpr int kMask = kSize - 1;

    InputRing() : data_(kSize, 0.0f) {}

    void reset() {
        written_.store(0, std::memory_order_relaxed);
        peak_.store(0.0f, std::memory_order_relaxed);
    }

    // --- wątek dźwięku --- `src` – przeplecione kanały, bierzemy kanał `channel` z `channels`.
    void write(const float *src, int frames, int channels, int channel) {
        int64_t w = written_.load(std::memory_order_relaxed);
        float peak = 0.0f;
        for (int i = 0; i < frames; ++i) {
            const float v = src ? src[i * channels + channel] : 0.0f;
            data_[static_cast<size_t>((w + i) & kMask)] = v;
            peak = std::max(peak, std::fabs(v));
        }
        written_.store(w + frames, std::memory_order_release);
        // Szczyt do wskaźnika poziomu: wolne opadanie po stronie czytającego (exchange zeruje).
        float old = peak_.load(std::memory_order_relaxed);
        while (peak > old && !peak_.compare_exchange_weak(old, peak, std::memory_order_relaxed)) {
        }
    }

    // --- wątek główny ---
    int64_t written() const { return written_.load(std::memory_order_acquire); }
    // Ostatnie `n` próbek (n ≤ kSize / 2); zwraca numer pierwszej.
    int64_t latest(float *dst, int n) const {
        const int64_t end = written();
        const int64_t start = end - n;
        for (int i = 0; i < n; ++i) {
            const int64_t k = start + i;
            dst[i] = k < 0 ? 0.0f : data_[static_cast<size_t>(k & kMask)];
        }
        return start;
    }
    // Próbki od numeru `from` (najwyżej `n`, tylko już zapisane i jeszcze nie nadpisane); zwraca ich liczbę.
    int read(int64_t from, float *dst, int n) const {
        const int64_t end = written();
        const int64_t lo = std::max<int64_t>(from, end - kSize / 2);
        if (lo != from) {
            return -1;   // za stare – nadpisane (wątek główny nie nadążył)
        }
        const int count = static_cast<int>(std::clamp<int64_t>(end - from, 0, n));
        for (int i = 0; i < count; ++i) {
            dst[i] = data_[static_cast<size_t>((from + i) & kMask)];
        }
        return count;
    }
    float take_peak() { return peak_.exchange(0.0f, std::memory_order_relaxed); }

private:
    std::vector<float> data_;
    std::atomic<int64_t> written_{0};
    std::atomic<float> peak_{0.0f};
};

} // namespace fbm
