# Fretboard Master – rdzeń C++ (GDExtension)
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
cmake_minimum_required(VERSION 3.22)
project(fbm_core LANGUAGES CXX)

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

add_library(fbm_core SHARED
    src/register_types.cpp
    src/register_types.h
    src/fbm_core.cpp
    src/fbm_core.h
    src/note_names.cpp
    src/note_names.h
)
target_link_libraries(fbm_core PRIVATE godot-cpp)

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
