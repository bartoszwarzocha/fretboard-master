// Fretboard Master – sekwencer rdzenia audio: metronom klasyczny, automat perkusyjny (General MIDI,
// kanał 10) i pojedyncze dźwięki MIDI (np. dźwięk próbny). Taktowanie z dokładnością do próbki:
// zdarzenia są wyliczane w wątku dźwięku, w trakcie wypełniania bufora wyjściowego.
// Niezależny od Godota i PortAudio – można go testować bez karty dźwiękowej (render do pamięci).
// Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#pragma once

#include <array>
#include <atomic>
#include <cstdint>
#include <mutex>
#include <vector>

struct tsf;

namespace fbm {

constexpr int kDrumRows = 6;      // crash, ride, hi-hat otwarty, hi-hat zamknięty, werbel, stopa
constexpr int kMaxSteps = 64;
constexpr int kDrumKeys[kDrumRows] = {49, 51, 46, 42, 38, 36};   // klawisze perkusji General MIDI

enum class MetronomeMode : int { Classic = 0, Drums = 1 };
enum class ClickSound : int { Click = 0, Wood = 1, Bell = 2 };

struct MetronomeConfig {
    double bpm = 96.0;
    MetronomeMode mode = MetronomeMode::Classic;
    int beats = 4;                 // uderzenia w takcie (dla 6/8 i 7/8 – ósemki)
    uint32_t accents = 1;          // maska bitowa uderzeń akcentowanych
    int subdivision = 1;           // metronom klasyczny: kliknięcia na uderzenie (1, 2, 3, 4)
    ClickSound sound = ClickSound::Click;
    int steps = 8;                 // automat: liczba kroków w takcie
    int steps_per_beat = 2;        // automat: kroki na uderzenie
    int kit = 0;                   // automat: numer zestawu perkusyjnego (GS: 0, 8, 16, 32, 40…)
    std::array<std::array<uint8_t, kMaxSteps>, kDrumRows> pattern{};   // 0 – pusto, 1 – uderzenie, 2 – akcent
    bool ramp = false;             // stopniowe przyspieszanie
    double ramp_to = 120.0;
    double ramp_step = 4.0;
    int ramp_bars = 8;
};

// Ostatni krok widoczny w interfejsie (z numerem próbki, od której brzmi).
struct TickInfo {
    int64_t frame = -1;
    int step = -1;                 // krok w takcie (klasyczny: uderzenie × podział + część)
    int64_t bar = 0;
    double bpm = 0.0;
};

class Sequencer {
public:
    Sequencer();
    ~Sequencer();
    Sequencer(const Sequencer &) = delete;
    Sequencer &operator=(const Sequencer &) = delete;

    // --- wątek główny ---
    void set_sample_rate(double rate);
    bool load_soundfont(const void *data, int size);
    bool has_soundfont() const { return sf_ != nullptr; }
    void configure(const MetronomeConfig &config);   // tempo zmienia się w locie, struktura taktu – od nowa
    void start();
    void stop();
    bool playing() const { return playing_.load(); }
    double current_bpm() const { return current_bpm_.load(); }
    void set_volume(float linear) { volume_.store(linear); }
    // Pojedynczy dźwięk MIDI (program General MIDI 0–127, kanał 1) trwający `seconds`.
    void play_note(int program, int key, float velocity, double seconds);
    // Dźwięk wzorcowy (kamerton): ciągły ton o częstotliwości `hz`; gain 0 wycisza (łagodnie).
    void set_tone(double hz, float gain) {
        tone_hz_.store(hz);
        tone_target_.store(gain);
    }
    // Krok brzmiący w próbce `frame` (do animacji wskaźnika w interfejsie).
    TickInfo tick_at(int64_t frame) const;

    // --- wątek dźwięku ---
    void render(float *stereo, int frames);
    int64_t frames_rendered() const { return frame_.load(); }

private:
    struct Voice {
        const std::vector<float> *buffer = nullptr;
        size_t pos = 0;
        float gain = 0.0f;
    };
    struct NoteEvent {
        int program, key;
        float velocity;
        double seconds;
    };
    struct PendingOff {
        int key;
        int64_t frame;
    };

    void build_clicks();
    void pick_up_changes();
    void fire_tick();
    void trigger_click(int sound_index, float gain);
    double tick_length() const;
    int ticks_per_bar() const;
    void mix_voices(float *out, int frames);

    double rate_ = 48000.0;
    tsf *sf_ = nullptr;

    // Zmiany z wątku głównego (przejmowane przez wątek dźwięku przy try_lock – bez blokowania dźwięku).
    mutable std::mutex shared_mutex_;
    MetronomeConfig pending_config_;
    bool config_dirty_ = false;
    bool restart_ = false;
    bool bpm_dirty_ = false;
    std::vector<NoteEvent> pending_notes_;

    // Stan wątku dźwięku.
    MetronomeConfig config_;
    std::atomic<bool> playing_{false};
    bool running_ = false;
    double bpm_ = 96.0;
    double next_tick_ = 0.0;       // numer próbki następnego kroku
    int tick_ = 0;
    int64_t bar_ = 0;
    std::atomic<int64_t> frame_{0};
    std::atomic<double> current_bpm_{96.0};
    std::atomic<float> volume_{0.7f};
    std::array<Voice, 16> voices_{};
    std::vector<PendingOff> offs_;
    std::array<std::vector<float>, 9> clicks_;   // brzmienie × (akcent, uderzenie, podział)
    std::vector<float> scratch_;
    std::atomic<double> tone_hz_{440.0};
    std::atomic<float> tone_target_{0.0f};
    float tone_gain_ = 0.0f;
    double tone_phase_ = 0.0;

    // Historia kroków dla interfejsu.
    mutable std::mutex ticks_mutex_;
    std::array<TickInfo, 64> ticks_{};
    int tick_write_ = 0;
};

} // namespace fbm
