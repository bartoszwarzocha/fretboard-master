// Fretboard Master – rdzeń audio widoczny w Godocie jako singleton „FbmAudio”: wyjście dźwięku przez
// PortAudio (ASIO, WASAPI, WDM-KS; na Linuksie ALSA) z buforem w próbkach i sekwencer (metronom,
// automat perkusyjny, dźwięki MIDI z wbudowanego syntezatora SoundFont).
// Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#pragma once

#include "input_ring.h"
#include "pitch.h"
#include "sequencer.h"

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <memory>
#include <vector>

namespace godot {

class FbmAudio : public Object {
    GDCLASS(FbmAudio, Object)

protected:
    static void _bind_methods();

public:
    FbmAudio();
    ~FbmAudio() override;

    // Sterowniki obecne w tej kompilacji i w systemie: "asio", "wasapi", "wdm_ks", "alsa", …
    PackedStringArray host_apis() const;
    // Urządzenia wyjściowe sterownika; pierwsze to "Default" (domyślne urządzenie sterownika).
    PackedStringArray output_devices(const String &api) const;
    // Urządzenia wejściowe sterownika; pierwsze to "Default".
    PackedStringArray input_devices(const String &api) const;
    // Otwiera wyjście i wejście (gitara: kanał `in_channel` urządzenia `in_device`); zwraca "" albo opis
    // błędu wyjścia. Gdy się da – jeden strumień dwukierunkowy (wspólny zegar wejścia i wyjścia, pod
    // przyszły looper); w przeciwnym razie osobny strumień wejścia. Błąd samego wejścia – input_error().
    // buffer_frames – rozmiar bufora w próbkach.
    String open(const String &api, const String &device, const String &in_device, int in_channel, int buffer_frames);
    void close();
    bool is_open() const;
    String current_api() const;
    double sample_rate() const;
    double output_latency_ms() const;
    double input_latency_ms() const;

    // --- wejście ---
    bool input_ok() const;
    String input_error() const;
    // Szczyt sygnału wejścia od poprzedniego wywołania, w dBFS (−120 – cisza / brak wejścia).
    double input_peak_db();
    // Rozpoznany dźwięk z ostatnich ok. 85 ms wejścia: {"hz" (0 – brak), "clarity", "level_db"}.
    Dictionary pitch();
    // Najniższa rozpoznawana częstotliwość (Hz): gitara ok. 55, gitara basowa ok. 28 (H0 = 30,9 Hz).
    void set_pitch_min(double hz);
    // Liczba próbek wejścia od otwarcia (numeracja wspólna z wyjściem przy strumieniu dwukierunkowym).
    int64_t input_frames() const;
    // Próbki wejścia od numeru `from` (do `max_count`, tyle, ile już jest); pusta tablica, gdy nie ma
    // nowych, a null zamiast tablicy (Variant) – gdy `from` jest już nadpisany.
    Variant input_read(int64_t from, int max_count);
    // Opóźnienie wejście + wyjście w próbkach: dźwięk zagrany do próbki wyjścia f pojawia się na wejściu
    // jako próbka f + latency_frames().
    int64_t latency_frames() const;
    // Numer próbki wejścia nagranej w chwili, gdy brzmi próbka wyjścia `out_frame` (gracz gra równo
    // z tym, co słyszy): opóźnienia wyjścia i wejścia wg sterownika plus przesunięcie numeracji
    // osobnych strumieni wejścia i wyjścia (śledzone na bieżąco). Resztę dopełnia pomiar impulsem.
    int64_t input_frame_at(int64_t out_frame) const;
    // Diagnostyka: częstotliwość, opóźnienia wg sterownika, czy duplex, przesunięcie numeracji strumieni,
    // kompensowane opóźnienie i (dla porównania) opóźnienie z czasów przetworników (ms).
    Dictionary timing_info() const;
    // Pomiar opóźnienia: krótki impuls na wyjściu; zwraca numer próbki wyjścia, w której zabrzmi.
    int64_t probe_click();
    // Ile ms minęło od ostatniego wywołania wyjścia (urządzenie odłączone – rośnie; −1 – zamknięte).
    double stream_age_ms() const;

    // --- looper (zob. looper.h) ---
    void looper_clear();
    void looper_add(const PackedFloat32Array &samples, int64_t from, int64_t to, double gain);
    void looper_play(int64_t offset, int64_t length, int64_t delay);
    void looper_stop();
    // Pozycja słyszana właśnie teraz, w próbkach ścieżek (−1 – nie gra).
    int64_t looper_position() const;
    // Szczyty w `buckets` równych przedziałach (do rysowania fali).
    PackedFloat32Array waveform(const PackedFloat32Array &samples, int buckets) const;
    // Pierwsza i ostatnia próbka głośniejsza niż `threshold_db` (z zapasem `margin` próbek); x = y = 0 – cisza.
    Vector2i sound_bounds(const PackedFloat32Array &samples, double threshold_db, int margin) const;

    // Dla testów: rozpoznanie wysokości w podanych próbkach.
    Dictionary detect_pitch(const PackedFloat32Array &samples, double rate);

    // Kamerton: ciągły ton `hz`; gain 0 – wyłączony.
    void set_tone(double hz, double gain);

    bool load_soundfont(const PackedByteArray &data);
    void set_volume(double linear);

    // Metronom i automat perkusyjny. config – słownik (zob. fbm_audio.cpp), pattern – wiersze × kroki.
    void configure(const Dictionary &config, const PackedByteArray &pattern);
    void start();
    void stop();
    bool is_playing() const;
    // {"step", "bar", "bpm", "playing"} – stan słyszany właśnie teraz (z uwzględnieniem opóźnienia wyjścia).
    Dictionary visual_state() const;
    void play_note(int program, int key, double velocity, double seconds);

    // Dla testów bez karty dźwiękowej: wypełnia `frames` próbek i zwraca szczyt sygnału.
    double render_offline(int frames);

    struct Stream;

private:
    int64_t heard_frame() const;
    fbm::Sequencer sequencer_;
    fbm::InputRing ring_;
    fbm::PitchDetector detector_;
    double pitch_min_ = 55.0;
    std::vector<float> window_;
    String input_error_;
    std::unique_ptr<Stream> stream_;
    bool pa_ready_ = false;
    bool pa_dead_ = false;          // porzucony strumień odłączonego urządzenia – bez Pa_Terminate
    String api_;
};

} // namespace godot
