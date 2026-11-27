// Fretboard Master – rejestracja klas GDExtension
// Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
#include "register_types.h"

#include "audio/fbm_audio.h"
#include "fbm_core.h"

#include <gdextension_interface.h>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

namespace {
FbmAudio *audio_singleton = nullptr;
}

void initialize_fbm_core(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    GDREGISTER_CLASS(FbmCore);
    GDREGISTER_CLASS(FbmAudio);
    // Rdzeń audio – jeden na program, dostępny z GDScriptu jako Engine.get_singleton("FbmAudio").
    audio_singleton = memnew(FbmAudio);
    Engine::get_singleton()->register_singleton("FbmAudio", audio_singleton);
}

void uninitialize_fbm_core(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    if (audio_singleton) {
        Engine::get_singleton()->unregister_singleton("FbmAudio");
        memdelete(audio_singleton);
        audio_singleton = nullptr;
    }
}

extern "C" {
GDExtensionBool GDE_EXPORT fbm_core_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
        const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
    GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
    init_obj.register_initializer(initialize_fbm_core);
    init_obj.register_terminator(uninitialize_fbm_core);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init_obj.init();
}
}
