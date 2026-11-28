// Fretboard Master – sekwencer rdzenia audio (zob. sequencer.h).
// Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#include "sequencer.h"

#include <algorithm>
#include <cmath>
#include <cstring>

#define TSF_IMPLEMENTATION
#include "tsf.h"

namespace fbm {

namespace {
constexpr double kPi = 3.14159265358979323846;
constexpr int kDrumChannel = 9;
constexpr int kNoteChannel = 0;
constexpr float kDrumVelocity[3] = {0.0f, 0.62f, 1.0f};
constexpr int kSticksKey = 31;     // General MIDI / GS: Sticks (pałeczki) – odliczanie perkusisty
} // namespace

Sequencer::Sequencer() {
    build_clicks();
    offs_.reserve(64);
    pending_notes_.reserve(16);
}

Sequencer::~Sequencer() {
    if (sf_) {
        tsf_close(sf_);
    }
}

void Sequencer::set_sample_rate(double rate) {
    // Wywoływane przy zamkniętym strumieniu – wątek dźwięku nie działa.
    rate_ = rate;
    build_clicks();
    if (sf_) {
        tsf_set_output(sf_, TSF_STEREO_INTERLEAVED, static_cast<int>(rate_), 0.0f);
    }
}

bool Sequencer::load_soundfont(const void *data, int size) {
    tsf *f = tsf_load_memory(data, size);
    if (!f) {
        return false;
    }
    tsf_set_output(f, TSF_STEREO_INTERLEAVED, static_cast<int>(rate_), 0.0f);
    tsf_set_max_voices(f, 96);   // głosy przydzielone z góry – bez alokacji w wątku dźwięku
    tsf_channel_set_presetnumber(f, kDrumChannel, 0, 1);
    tsf_channel_set_presetnumber(f, kNoteChannel, 24, 0);
    std::lock_guard lock(shared_mutex_);
    tsf *old = sf_;
    sf_ = f;
    if (old) {
        tsf_close(old);
    }
    return true;
}

void Sequencer::configure(const MetronomeConfig &config) {
    std::lock_guard lock(shared_mutex_);
    const MetronomeConfig &cur = config_dirty_ ? pending_config_ : config_;
    const bool structure = cur.mode != config.mode || cur.beats != config.beats ||
            cur.subdivision != config.subdivision || cur.steps != config.steps ||
            cur.steps_per_beat != config.steps_per_beat;
    if (cur.bpm != config.bpm) {
        bpm_dirty_ = true;
    }
    pending_config_ = config;
    config_dirty_ = true;
    restart_ = restart_ || structure;
}

void Sequencer::start() {
    std::lock_guard lock(shared_mutex_);
    restart_ = true;
    bpm_dirty_ = true;
    playing_.store(true);
}

void Sequencer::stop() {
    playing_.store(false);
    clock_start_.store(-1);
}

void Sequencer::play_note(int program, int key, float velocity, double seconds) {
    std::lock_guard lock(shared_mutex_);
    if (pending_notes_.size() < 16) {
        pending_notes_.push_back({program, key, velocity, seconds});
    }
}

TickInfo Sequencer::tick_at(int64_t frame) const {
    std::lock_guard lock(ticks_mutex_);
    TickInfo best;
    for (const TickInfo &t : ticks_) {
        if (t.frame >= 0 && t.frame <= frame && t.frame > best.frame) {
            best = t;
        }
    }
    return best;
}

double Sequencer::tick_length() const {
    const int per_beat = config_.mode == MetronomeMode::Classic ? std::max(config_.subdivision, 1)
                                                                : std::max(config_.steps_per_beat, 1);
    return rate_ * 60.0 / std::clamp(bpm_, 20.0, 400.0) / per_beat;
}

int Sequencer::ticks_per_bar() const {
    if (config_.mode == MetronomeMode::Classic) {
        return std::max(config_.beats, 1) * std::max(config_.subdivision, 1);
    }
    return std::clamp(config_.steps, 1, kMaxSteps);
}

// Przejęcie zmian z wątku głównego – try_lock, żeby nigdy nie czekać w wątku dźwięku.
void Sequencer::pick_up_changes() {
    std::unique_lock lock(shared_mutex_, std::try_to_lock);
    if (!lock.owns_lock()) {
        return;
    }
    const int64_t now = frame_.load(std::memory_order_relaxed);
    if (config_dirty_) {
        config_ = pending_config_;
        config_dirty_ = false;
        if (sf_) {
            tsf_channel_set_presetnumber(sf_, kDrumChannel, config_.kit, 1);
        }
    }
    if (bpm_dirty_) {
        bpm_ = config_.bpm;
        bpm_dirty_ = false;
    }
    if (restart_) {
        restart_ = false;
        tick_ = 0;
        bar_ = 0;
        next_tick_ = static_cast<double>(now) + rate_ * 0.02;   // pierwsze uderzenie po 20 ms
        clock_start_.store(static_cast<int64_t>(std::ceil(next_tick_)));
        std::lock_guard tl(ticks_mutex_);
        for (TickInfo &t : ticks_) {
            t = TickInfo{};
        }
    }
    bar_frames_.store(tick_length() * ticks_per_bar(), std::memory_order_relaxed);
    if (sf_) {
        for (const NoteEvent &n : pending_notes_) {
            tsf_channel_set_presetnumber(sf_, kNoteChannel, std::clamp(n.program, 0, 127), 0);
            tsf_channel_note_on(sf_, kNoteChannel, n.key, n.velocity);
            if (offs_.size() < offs_.capacity()) {
                offs_.push_back({n.key, now + static_cast<int64_t>(n.seconds * rate_)});
            }
        }
    }
    pending_notes_.clear();
}

void Sequencer::fire_tick() {
    const int per_bar = ticks_per_bar();
    if (tick_ >= per_bar) {
        tick_ = 0;
    }
    const bool counting = bar_ < config_.countin_bars;
    if (config_.play_bars > 0 && bar_ >= config_.play_bars) {
        // koniec nagrania o zadanej długości – bez pierwszego uderzenia następnego taktu
    } else if (counting && config_.countin_sticks && config_.mode == MetronomeMode::Drums) {
        // Odliczanie perkusisty: pałeczki na każde uderzenie, pierwsze mocniej.
        const int per_beat = std::max(config_.steps_per_beat, 1);
        if (sf_ && tick_ % per_beat == 0) {
            tsf_channel_note_on(sf_, kDrumChannel, kSticksKey, tick_ == 0 ? 1.0f : 0.8f);
        }
    } else if (config_.silent) {
        // zegar bez dźwięku
    } else if (config_.mode == MetronomeMode::Classic) {
        const int sub = std::max(config_.subdivision, 1);
        const int beat = tick_ / sub;
        const int sound = static_cast<int>(config_.sound) * 3;
        if (tick_ % sub != 0) {
            trigger_click(sound + 2, 0.55f);
        } else if (config_.accents & (1u << beat)) {
            trigger_click(sound + 0, 1.0f);
        } else {
            trigger_click(sound + 1, 0.85f);
        }
    } else if (sf_) {
        for (int r = 0; r < kDrumRows; ++r) {
            const uint8_t v = config_.pattern[r][tick_];
            if (v) {
                tsf_channel_note_on(sf_, kDrumChannel, kDrumKeys[r], kDrumVelocity[std::min<int>(v, 2)]);
            }
        }
    }
    {
        std::lock_guard tl(ticks_mutex_);
        ticks_[tick_write_] = {static_cast<int64_t>(next_tick_), tick_, bar_, bpm_};
        tick_write_ = (tick_write_ + 1) % static_cast<int>(ticks_.size());
    }
    ++tick_;
    if (tick_ >= per_bar) {
        tick_ = 0;
        ++bar_;
        // Stopniowe przyspieszanie: co `ramp_bars` taktów tempo rośnie o `ramp_step`, do `ramp_to`.
        if (config_.ramp && config_.ramp_bars > 0 && bar_ % config_.ramp_bars == 0 && bpm_ < config_.ramp_to) {
            bpm_ = std::min(bpm_ + config_.ramp_step, config_.ramp_to);
        }
    }
    current_bpm_.store(bpm_);
}

int64_t Sequencer::probe_click() {
    const int64_t f = frame_.load() + static_cast<int64_t>(rate_ * 0.1);
    probe_frame_.store(f);
    return f;
}

void Sequencer::trigger_click(int sound_index, float gain) {
    for (Voice &v : voices_) {
        if (!v.buffer) {
            v.buffer = &clicks_[sound_index];
            v.pos = 0;
            v.gain = gain;
            return;
        }
    }
}

void Sequencer::mix_voices(float *out, int frames) {
    for (Voice &v : voices_) {
        if (!v.buffer) {
            continue;
        }
        const size_t n = std::min<size_t>(frames, v.buffer->size() - v.pos);
        const float *src = v.buffer->data() + v.pos;
        for (size_t i = 0; i < n; ++i) {
            const float s = src[i] * v.gain;
            out[i * 2] += s;
            out[i * 2 + 1] += s;
        }
        v.pos += n;
        if (v.pos >= v.buffer->size()) {
            v.buffer = nullptr;
        }
    }
}

// Wypełnienie bufora: odcinki między kolejnymi zdarzeniami, zdarzenia dokładnie na swojej próbce.
void Sequencer::render(float *stereo, int frames) {
    std::memset(stereo, 0, sizeof(float) * 2 * frames);
    pick_up_changes();
    if (!playing_.load(std::memory_order_relaxed) && running_) {
        running_ = false;
        if (sf_) {
            tsf_channel_note_off_all(sf_, kDrumChannel);
        }
    }
    if (playing_.load(std::memory_order_relaxed)) {
        running_ = true;
    }
    const int64_t start = frame_.load(std::memory_order_relaxed);
    int done = 0;
    while (done < frames) {
        const int64_t pos = start + done;
        int64_t next_event = start + frames;
        if (running_) {
            next_event = std::min<int64_t>(next_event, std::max<int64_t>(pos, static_cast<int64_t>(std::ceil(next_tick_))));
        }
        for (const PendingOff &o : offs_) {
            next_event = std::min(next_event, std::max(pos, o.frame));
        }
        const int len = static_cast<int>(next_event - pos);
        if (len > 0) {
            float *out = stereo + done * 2;
            if (sf_) {
                tsf_render_float(sf_, out, len, 1);
            }
            mix_voices(out, len);
            done += len;
            continue;
        }
        // Zdarzenia w próbce `pos`.
        for (size_t i = 0; i < offs_.size();) {
            if (offs_[i].frame <= pos) {
                if (sf_) {
                    tsf_channel_note_off(sf_, kNoteChannel, offs_[i].key);
                }
                offs_[i] = offs_.back();
                offs_.pop_back();
            } else {
                ++i;
            }
        }
        if (running_ && next_tick_ <= static_cast<double>(pos)) {
            fire_tick();
            next_tick_ += tick_length();
        }
    }
    looper_.mix(stereo, frames, start, clock_start_.load(std::memory_order_relaxed));
    // Impuls pomiaru opóźnienia (probe_click): 3 ms sinusa 1 kHz.
    const int64_t probe = probe_frame_.load(std::memory_order_relaxed);
    if (probe >= 0) {
        const int len = static_cast<int>(rate_ * 0.003);
        for (int64_t k = std::max(probe, start); k < std::min<int64_t>(probe + len, start + frames); ++k) {
            const float v = 0.9f * static_cast<float>(std::sin(2.0 * kPi * 1000.0 * (k - probe) / rate_));
            stereo[(k - start) * 2] += v;
            stereo[(k - start) * 2 + 1] += v;
        }
        if (probe + len <= start + frames) {
            probe_frame_.store(-1, std::memory_order_relaxed);
        }
    }
    // Kamerton: sinus z odrobiną 2. i 3. harmonicznej (słyszalny także w małych głośnikach),
    // głośność zmienia się płynnie (ok. 20 ms) – bez trzasków przy włączaniu i zmianie struny.
    const float target = tone_target_.load(std::memory_order_relaxed);
    if (target > 0.0f || tone_gain_ > 0.0f) {
        const double step = 2.0 * kPi * tone_hz_.load(std::memory_order_relaxed) / rate_;
        const float slew = static_cast<float>(1.0 / (0.02 * rate_));
        for (int i = 0; i < frames; ++i) {
            tone_gain_ += std::clamp(target - tone_gain_, -slew, slew);
            const double ph = tone_phase_;
            const float v = tone_gain_ * static_cast<float>(0.8 * std::sin(ph) + 0.15 * std::sin(2.0 * ph) + 0.05 * std::sin(3.0 * ph));
            stereo[i * 2] += v;
            stereo[i * 2 + 1] += v;
            tone_phase_ += step;
            if (tone_phase_ > 2.0 * kPi) {
                tone_phase_ -= 2.0 * kPi;
            }
        }
        if (tone_gain_ < 1e-5f && target <= 0.0f) {
            tone_gain_ = 0.0f;
        }
    }
    const float vol = volume_.load(std::memory_order_relaxed);
    for (int i = 0; i < frames * 2; ++i) {
        stereo[i] = std::clamp(stereo[i] * vol, -1.0f, 1.0f);
    }
    frame_.store(start + frames, std::memory_order_relaxed);
}

// Brzmienia metronomu klasycznego (syntetyzowane raz, przy zmianie częstotliwości próbkowania):
// klik – krótki ton sinusoidalny, drewienko – dwa tłumione rezonanse, dzwonek – nieharmoniczne alikwoty.
void Sequencer::build_clicks() {
    auto make = [this](double seconds, auto &&sample) {
        std::vector<float> b(static_cast<size_t>(seconds * rate_));
        for (size_t i = 0; i < b.size(); ++i) {
            b[i] = static_cast<float>(sample(static_cast<double>(i) / rate_));
        }
        // łagodne wyciszenie ostatnich 2 ms – bez trzasku
        const size_t fade = std::min<size_t>(b.size(), static_cast<size_t>(rate_ * 0.002));
        for (size_t i = 0; i < fade; ++i) {
            b[b.size() - 1 - i] *= static_cast<float>(i) / static_cast<float>(fade);
        }
        return b;
    };
    const double click_hz[3] = {2093.0, 1568.0, 1175.0};
    const double wood_hz[3] = {1180.0, 880.0, 740.0};
    const double bell_hz[3] = {1760.0, 1318.5, 1046.5};
    for (int k = 0; k < 3; ++k) {
        const double f = click_hz[k];
        clicks_[k] = make(0.045, [f](double t) {
            const double attack = std::min(1.0, t / 0.0006);
            return 0.8 * attack * std::exp(-t / 0.009) * std::sin(2.0 * kPi * f * t);
        });
        const double w = wood_hz[k];
        clicks_[3 + k] = make(0.08, [w](double t) {
            const double attack = std::min(1.0, t / 0.0004);
            return attack * (0.75 * std::exp(-t / 0.018) * std::sin(2.0 * kPi * w * t) +
                                    0.35 * std::exp(-t / 0.007) * std::sin(2.0 * kPi * w * 2.61 * t));
        });
        const double b = bell_hz[k];
        clicks_[6 + k] = make(0.6, [b](double t) {
            const double attack = std::min(1.0, t / 0.001);
            return attack * (0.55 * std::exp(-t / 0.22) * std::sin(2.0 * kPi * b * t) +
                                    0.25 * std::exp(-t / 0.09) * std::sin(2.0 * kPi * b * 2.76 * t) +
                                    0.12 * std::exp(-t / 0.04) * std::sin(2.0 * kPi * b * 5.40 * t));
        });
    }
}

} // namespace fbm
