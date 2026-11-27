// Fretboard Master – rdzeń audio (zob. fbm_audio.h).
// Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#include "fbm_audio.h"

#include <godot_cpp/core/class_db.hpp>

#include <portaudio.h>

#include <algorithm>
#include <cmath>
#include <vector>

namespace godot {

namespace {

struct ApiName {
    PaHostApiTypeId type;
    const char *id;
};
constexpr ApiName kApis[] = {
    {paASIO, "asio"}, {paWASAPI, "wasapi"}, {paWDMKS, "wdm_ks"}, {paALSA, "alsa"},
    {paJACK, "jack"}, {paCoreAudio, "coreaudio"},
};

PaHostApiIndex api_index(const String &id) {
    for (const ApiName &a : kApis) {
        if (id == a.id) {
            return Pa_HostApiTypeIdToHostApiIndex(a.type);
        }
    }
    return -1;
}

String device_name(PaDeviceIndex i) {
    const PaDeviceInfo *info = Pa_GetDeviceInfo(i);
    return info ? String::utf8(info->name) : String();
}

} // namespace

struct FbmAudio::Stream {
    PaStream *pa = nullptr;
    double rate = 48000.0;
    double latency = 0.0;          // s
    // Zegar strumienia: próbka `base_frame` trafia do przetwornika w chwili `base_dac` (czas strumienia).
    std::atomic<int64_t> base_frame{0};
    std::atomic<double> base_dac{0.0};
    fbm::Sequencer *seq = nullptr;
};

static int pa_callback(const void *, void *output, unsigned long frames, const PaStreamCallbackTimeInfo *time,
        PaStreamCallbackFlags, void *user) {
    auto *s = static_cast<FbmAudio::Stream *>(user);
    const int64_t first = s->seq->frames_rendered();
    s->seq->render(static_cast<float *>(output), static_cast<int>(frames));
    if (time && time->outputBufferDacTime > 0.0) {
        s->base_dac.store(time->outputBufferDacTime, std::memory_order_relaxed);
        s->base_frame.store(first, std::memory_order_relaxed);
    }
    return paContinue;
}

FbmAudio::FbmAudio() {
    pa_ready_ = Pa_Initialize() == paNoError;
}

FbmAudio::~FbmAudio() {
    close();
    if (pa_ready_) {
        Pa_Terminate();
    }
}

void FbmAudio::_bind_methods() {
    ClassDB::bind_method(D_METHOD("host_apis"), &FbmAudio::host_apis);
    ClassDB::bind_method(D_METHOD("output_devices", "api"), &FbmAudio::output_devices);
    ClassDB::bind_method(D_METHOD("open", "api", "device", "buffer_frames"), &FbmAudio::open);
    ClassDB::bind_method(D_METHOD("close"), &FbmAudio::close);
    ClassDB::bind_method(D_METHOD("is_open"), &FbmAudio::is_open);
    ClassDB::bind_method(D_METHOD("current_api"), &FbmAudio::current_api);
    ClassDB::bind_method(D_METHOD("sample_rate"), &FbmAudio::sample_rate);
    ClassDB::bind_method(D_METHOD("output_latency_ms"), &FbmAudio::output_latency_ms);
    ClassDB::bind_method(D_METHOD("load_soundfont", "data"), &FbmAudio::load_soundfont);
    ClassDB::bind_method(D_METHOD("set_volume", "linear"), &FbmAudio::set_volume);
    ClassDB::bind_method(D_METHOD("configure", "config", "pattern"), &FbmAudio::configure);
    ClassDB::bind_method(D_METHOD("start"), &FbmAudio::start);
    ClassDB::bind_method(D_METHOD("stop"), &FbmAudio::stop);
    ClassDB::bind_method(D_METHOD("is_playing"), &FbmAudio::is_playing);
    ClassDB::bind_method(D_METHOD("visual_state"), &FbmAudio::visual_state);
    ClassDB::bind_method(D_METHOD("play_note", "program", "key", "velocity", "seconds"), &FbmAudio::play_note);
    ClassDB::bind_method(D_METHOD("render_offline", "frames"), &FbmAudio::render_offline);
}

PackedStringArray FbmAudio::host_apis() const {
    PackedStringArray out;
    if (!pa_ready_) {
        return out;
    }
    for (const ApiName &a : kApis) {
        const PaHostApiIndex i = Pa_HostApiTypeIdToHostApiIndex(a.type);
        if (i >= 0 && Pa_GetHostApiInfo(i)->deviceCount > 0) {
            out.push_back(a.id);
        }
    }
    return out;
}

PackedStringArray FbmAudio::output_devices(const String &api) const {
    PackedStringArray out;
    const PaHostApiIndex h = pa_ready_ ? api_index(api) : -1;
    if (h < 0) {
        return out;
    }
    out.push_back("Default");
    const PaHostApiInfo *info = Pa_GetHostApiInfo(h);
    for (int k = 0; k < info->deviceCount; ++k) {
        const PaDeviceIndex d = Pa_HostApiDeviceIndexToDeviceIndex(h, k);
        const PaDeviceInfo *di = Pa_GetDeviceInfo(d);
        if (di && di->maxOutputChannels >= 2) {
            out.push_back(String::utf8(di->name));
        }
    }
    return out;
}

String FbmAudio::open(const String &api, const String &device, int buffer_frames) {
    close();
    if (!pa_ready_) {
        return "PortAudio";
    }
    const PaHostApiIndex h = api_index(api);
    if (h < 0) {
        return "driver";
    }
    const PaHostApiInfo *info = Pa_GetHostApiInfo(h);
    PaDeviceIndex dev = info->defaultOutputDevice;
    for (int k = 0; k < info->deviceCount; ++k) {
        const PaDeviceIndex d = Pa_HostApiDeviceIndexToDeviceIndex(h, k);
        if (device != "Default" && device_name(d) == device) {
            dev = d;
        }
    }
    if (dev == paNoDevice) {
        return "device";
    }
    const PaDeviceInfo *di = Pa_GetDeviceInfo(dev);
    PaStreamParameters out{};
    out.device = dev;
    out.channelCount = 2;
    out.sampleFormat = paFloat32;
    out.suggestedLatency = di->defaultLowOutputLatency;
    out.hostApiSpecificStreamInfo = nullptr;

    auto s = std::make_unique<Stream>();
    s->seq = &sequencer_;
    // 48 kHz, a gdy urządzenie go nie obsługuje – jego domyślna częstotliwość.
    double rate = 48000.0;
    if (Pa_IsFormatSupported(nullptr, &out, rate) != paFormatIsSupported) {
        rate = di->defaultSampleRate;
    }
    sequencer_.set_sample_rate(rate);
    const unsigned long frames = buffer_frames > 0 ? static_cast<unsigned long>(buffer_frames) : paFramesPerBufferUnspecified;
    PaError err = Pa_OpenStream(&s->pa, nullptr, &out, rate, frames, paClipOff, pa_callback, s.get());
    if (err != paNoError) {
        return String::utf8(Pa_GetErrorText(err));
    }
    err = Pa_StartStream(s->pa);
    if (err != paNoError) {
        Pa_CloseStream(s->pa);
        return String::utf8(Pa_GetErrorText(err));
    }
    const PaStreamInfo *si = Pa_GetStreamInfo(s->pa);
    s->rate = si ? si->sampleRate : rate;
    s->latency = si ? si->outputLatency : 0.0;
    stream_ = std::move(s);
    api_ = api;
    return "";
}

void FbmAudio::close() {
    if (stream_ && stream_->pa) {
        Pa_StopStream(stream_->pa);
        Pa_CloseStream(stream_->pa);
    }
    stream_.reset();
    api_ = "";
}

bool FbmAudio::is_open() const {
    return stream_ != nullptr;
}

String FbmAudio::current_api() const {
    return api_;
}

double FbmAudio::sample_rate() const {
    return stream_ ? stream_->rate : 0.0;
}

double FbmAudio::output_latency_ms() const {
    return stream_ ? stream_->latency * 1000.0 : 0.0;
}

bool FbmAudio::load_soundfont(const PackedByteArray &data) {
    // Wymiana SoundFontu tylko przy zatrzymanym strumieniu – wątek dźwięku nie może z niego korzystać.
    const bool was_open = stream_ != nullptr;
    PaStream *pa = was_open ? stream_->pa : nullptr;
    if (pa) {
        Pa_StopStream(pa);
    }
    const bool ok = sequencer_.load_soundfont(data.ptr(), static_cast<int>(data.size()));
    if (pa) {
        Pa_StartStream(pa);
    }
    return ok;
}

void FbmAudio::set_volume(double linear) {
    sequencer_.set_volume(static_cast<float>(std::clamp(linear, 0.0, 1.0)));
}

// Klucze słownika: bpm, mode (0 klasyczny, 1 automat), beats, accents (maska), subdivision, sound,
// steps, steps_per_beat, kit, ramp, ramp_to, ramp_step, ramp_bars. pattern: 6 wierszy × steps (0/1/2).
void FbmAudio::configure(const Dictionary &d, const PackedByteArray &pattern) {
    fbm::MetronomeConfig c;
    c.bpm = d.get("bpm", 96.0);
    c.mode = static_cast<fbm::MetronomeMode>(static_cast<int>(d.get("mode", 0)));
    c.beats = std::clamp(static_cast<int>(d.get("beats", 4)), 1, 32);
    c.accents = static_cast<uint32_t>(static_cast<int64_t>(d.get("accents", 1)));
    c.subdivision = std::clamp(static_cast<int>(d.get("subdivision", 1)), 1, 8);
    c.sound = static_cast<fbm::ClickSound>(std::clamp(static_cast<int>(d.get("sound", 0)), 0, 2));
    c.steps = std::clamp(static_cast<int>(d.get("steps", 8)), 1, fbm::kMaxSteps);
    c.steps_per_beat = std::clamp(static_cast<int>(d.get("steps_per_beat", 2)), 1, 8);
    c.kit = std::clamp(static_cast<int>(d.get("kit", 0)), 0, 127);
    c.ramp = d.get("ramp", false);
    c.ramp_to = d.get("ramp_to", 120.0);
    c.ramp_step = d.get("ramp_step", 4.0);
    c.ramp_bars = std::max(static_cast<int>(d.get("ramp_bars", 8)), 1);
    for (int r = 0; r < fbm::kDrumRows; ++r) {
        for (int s = 0; s < c.steps; ++s) {
            const int64_t i = static_cast<int64_t>(r) * c.steps + s;
            c.pattern[r][s] = i < pattern.size() ? pattern[i] : 0;
        }
    }
    sequencer_.configure(c);
}

void FbmAudio::start() {
    sequencer_.start();
}

void FbmAudio::stop() {
    sequencer_.stop();
}

bool FbmAudio::is_playing() const {
    return sequencer_.playing();
}

Dictionary FbmAudio::visual_state() const {
    Dictionary d;
    d["playing"] = sequencer_.playing();
    d["bpm"] = sequencer_.current_bpm();
    int64_t frame = sequencer_.frames_rendered();
    if (stream_) {
        const double dac = stream_->base_dac.load(std::memory_order_relaxed);
        if (dac > 0.0) {
            const double now = Pa_GetStreamTime(stream_->pa);
            frame = stream_->base_frame.load(std::memory_order_relaxed) +
                    static_cast<int64_t>((now - dac) * stream_->rate);
        } else {
            frame -= static_cast<int64_t>(stream_->latency * stream_->rate);
        }
    }
    const fbm::TickInfo t = sequencer_.tick_at(frame);
    d["step"] = t.step;
    d["bar"] = t.bar;
    return d;
}

void FbmAudio::play_note(int program, int key, double velocity, double seconds) {
    sequencer_.play_note(program, key, static_cast<float>(velocity), seconds);
}

double FbmAudio::render_offline(int frames) {
    if (stream_) {
        return -1.0;
    }
    std::vector<float> buf(static_cast<size_t>(frames) * 2);
    sequencer_.render(buf.data(), frames);
    float peak = 0.0f;
    for (float v : buf) {
        peak = std::max(peak, std::abs(v));
    }
    return peak;
}

} // namespace godot
