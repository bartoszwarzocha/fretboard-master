// Fretboard Master – rdzeń audio widoczny w Godocie jako singleton „FbmAudio”: wyjście dźwięku przez
// PortAudio (ASIO, WASAPI, WDM-KS; na Linuksie ALSA) z buforem w próbkach i sekwencer (metronom,
// automat perkusyjny, dźwięki MIDI z wbudowanego syntezatora SoundFont).
// Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#pragma once

#include "sequencer.h"

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <memory>

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
    // Otwiera wyjście; zwraca "" albo opis błędu. buffer_frames – rozmiar bufora w próbkach.
    String open(const String &api, const String &device, int buffer_frames);
    void close();
    bool is_open() const;
    String current_api() const;
    double sample_rate() const;
    double output_latency_ms() const;

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
    fbm::Sequencer sequencer_;
    std::unique_ptr<Stream> stream_;
    bool pa_ready_ = false;
    String api_;
};

} // namespace godot
