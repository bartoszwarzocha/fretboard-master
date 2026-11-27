// Fretboard Master – looper rdzenia audio (zob. looper.h).
// Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#include "looper.h"

#include <algorithm>

namespace fbm {

void Looper::clear() {
    std::vector<Track> old;
    {
        std::lock_guard lock(mutex_);
        old.swap(tracks_);
    }
    // `old` zwalnia pamięć tutaj – w wątku głównym, nie w wątku dźwięku.
}

void Looper::add(std::vector<float> &&samples, int64_t from, int64_t to, float gain) {
    Track t;
    t.data = std::move(samples);
    const auto n = static_cast<int64_t>(t.data.size());
    t.from = std::clamp<int64_t>(from, 0, n);
    t.to = std::clamp<int64_t>(to, t.from, n);
    t.gain = gain;
    std::lock_guard lock(mutex_);
    tracks_.reserve(16);
    tracks_.push_back(std::move(t));
}

void Looper::play(int64_t offset, int64_t length, int64_t delay) {
    offset_.store(std::max<int64_t>(offset, 0));
    length_.store(std::max<int64_t>(length, 1));
    delay_.store(std::max<int64_t>(delay, 0));
    playing_.store(true);
}

void Looper::stop() {
    playing_.store(false);
}

int64_t Looper::position(int64_t frame, int64_t clock_start) const {
    if (!playing_.load() || clock_start < 0) {
        return -1;
    }
    const int64_t pos = frame - clock_start - delay_.load();
    if (pos < 0) {
        return -1;
    }
    return offset_.load() + pos % length_.load();
}

void Looper::mix(float *stereo, int frames, int64_t first_frame, int64_t clock_start) {
    if (!playing_.load(std::memory_order_relaxed) || clock_start < 0) {
        return;
    }
    std::unique_lock lock(mutex_, std::try_to_lock);
    if (!lock.owns_lock() || tracks_.empty()) {
        return;
    }
    const int64_t offset = offset_.load(std::memory_order_relaxed);
    const int64_t length = length_.load(std::memory_order_relaxed);
    const int64_t start = clock_start + delay_.load(std::memory_order_relaxed);
    for (int i = 0; i < frames; ++i) {
        const int64_t pos = first_frame + i - start;
        if (pos < 0) {
            continue;
        }
        const int64_t k = offset + pos % length;
        float v = 0.0f;
        for (const Track &t : tracks_) {
            if (k >= t.from && k < t.to) {
                // Łagodne wejście i wyjście zakresu (ok. 3 ms) – bez trzasków na granicach pętli.
                const int64_t edge = std::min(k - t.from, t.to - 1 - k);
                const float fade = edge < 128 ? static_cast<float>(edge) / 128.0f : 1.0f;
                v += t.data[static_cast<size_t>(k)] * t.gain * fade;
            }
        }
        stereo[i * 2] += v;
        stereo[i * 2 + 1] += v;
    }
}

} // namespace fbm
