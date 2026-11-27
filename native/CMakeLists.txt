# Fretboard Master – rdzeń C++ (GDExtension)
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
cmake_minimum_required(VERSION 3.22)
project(fbm_core LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# godot-cpp przypięty do wersji zgodnej z Godotem 4.7 (API 4.7).
set(GODOTCPP_API_VERSION "4.7" CACHE STRING "Wersja API Godota" FORCE)
include(FetchContent)
FetchContent_Declare(
    godot-cpp
    GIT_REPOSITORY https://github.com/godotengine/godot-cpp.git
    GIT_TAG 10.0.0-stable
    GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(godot-cpp)

# --- Audio: PortAudio (MIT) statycznie w bibliotece rdzenia; TinySoundFont (MIT, jeden nagłówek) ---
# ASIO wymaga ASIO SDK Steinberga (licencja własnościowa Steinberga, zaakceptowana przez autora).
# SDK nie wolno rozpowszechniać – nie ma go w repozytorium. Pobranie: https://www.steinberg.net/asiosdk,
# rozpakowanie do native/third_party/asiosdk (folder w .gitignore; wykrywany samoczynnie)
# albo wskazanie innego folderu: cmake -DFBM_ASIO_SDK_DIR=ścieżka …
set(FBM_ASIO_SDK_DIR "" CACHE PATH "Folder ASIO SDK (pusty – wykrycie native/third_party/asiosdk)")
if(NOT FBM_ASIO_SDK_DIR AND WIN32 AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/third_party/asiosdk/common/asio.h")
    set(FBM_ASIO_SDK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/asiosdk")
endif()
if(FBM_ASIO_SDK_DIR)
    message(STATUS "Fretboard Master: ASIO SDK – ${FBM_ASIO_SDK_DIR}")
endif()
set(PA_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(PA_BUILD_STATIC ON CACHE BOOL "" FORCE)
set(PA_DISABLE_INSTALL ON CACHE BOOL "" FORCE)
set(PA_USE_JACK OFF CACHE BOOL "" FORCE)
set(PA_USE_DS OFF CACHE BOOL "" FORCE)
set(PA_USE_WMME OFF CACHE BOOL "" FORCE)
set(PA_USE_WASAPI ON CACHE BOOL "" FORCE)
set(PA_USE_WDMKS ON CACHE BOOL "" FORCE)
if(FBM_ASIO_SDK_DIR)
    set(ASIOSDK_ROOT_DIR "${FBM_ASIO_SDK_DIR}" CACHE PATH "" FORCE)
    set(ASIOSDK_INCLUDE_DIR "${FBM_ASIO_SDK_DIR}/common" CACHE PATH "" FORCE)
    set(PA_USE_ASIO ON CACHE BOOL "" FORCE)
else()
    set(PA_USE_ASIO OFF CACHE BOOL "" FORCE)
endif()
# PortAudio 19.7 deklaruje CMake 2.8 – nowsze CMake wymagają podniesienia minimum polityk;
# CMP0091: biblioteka statyczna z tym samym środowiskiem uruchomieniowym MSVC co godot-cpp (/MT).
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
set(CMAKE_POLICY_DEFAULT_CMP0091 NEW)
FetchContent_Declare(
    portaudio
    GIT_REPOSITORY https://github.com/PortAudio/portaudio.git
    GIT_TAG v19.7.0
    GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(portaudio)
set_target_properties(portaudio_static PROPERTIES POSITION_INDEPENDENT_CODE ON)

FetchContent_Declare(
    tinysoundfont
    GIT_REPOSITORY https://github.com/schellingb/TinySoundFont.git
    GIT_TAG a3621a19c6504885cd9583e6e26c35bc954fc8ec
)
FetchContent_GetProperties(tinysoundfont)
if(NOT tinysoundfont_POPULATED)
    FetchContent_Populate(tinysoundfont)
endif()

add_library(fbm_core SHARED
    src/register_types.cpp
    src/register_types.h
    src/fbm_core.cpp
    src/fbm_core.h
    src/note_names.cpp
    src/note_names.h
    src/audio/input_ring.h
    src/audio/looper.cpp
    src/audio/looper.h
    src/audio/pitch.cpp
    src/audio/pitch.h
    src/audio/sequencer.cpp
    src/audio/sequencer.h
    src/audio/fbm_audio.cpp
    src/audio/fbm_audio.h
)
target_include_directories(fbm_core PRIVATE src "${tinysoundfont_SOURCE_DIR}")
target_link_libraries(fbm_core PRIVATE godot-cpp portaudio_static)

get_target_property(GODOTCPP_SUFFIX godot-cpp GODOTCPP_SUFFIX)
set(FBM_OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../app/bin")

set_target_properties(fbm_core PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    POSITION_INDEPENDENT_CODE ON
    INTERPROCEDURAL_OPTIMIZATION_RELEASE ON
    LIBRARY_OUTPUT_DIRECTORY "$<1:${FBM_OUTPUT_DIR}>"
    RUNTIME_OUTPUT_DIRECTORY "$<1:${FBM_OUTPUT_DIR}>"
    PDB_OUTPUT_DIRECTORY "$<1:${FBM_OUTPUT_DIR}>"
    PREFIX "lib"
    OUTPUT_NAME "fbm_core${GODOTCPP_SUFFIX}"
)

if(MSVC)
    target_compile_options(fbm_core PRIVATE /W4 /utf-8)
else()
    target_compile_options(fbm_core PRIVATE -Wall -Wextra)
endif()
