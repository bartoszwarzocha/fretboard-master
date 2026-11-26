# Fretboard Master – składniki innych autorów / Third-party notices

Fretboard Master jest programem zamkniętym (freeware), objętym licencją z pliku `LICENSE.md`. Program korzysta z poniższych składników innych autorów. Każdy z nich podlega własnej licencji, której pełny tekst jest dołączany do programu w katalogu `licenses/`.

Fretboard Master is closed-source freeware covered by `LICENSE.md`. It uses the third-party components listed below. Each component is governed by its own licence; the full licence texts are shipped with the program in the `licenses/` folder.

| Składnik / Component | Zastosowanie / Use | Licencja / Licence | Źródło / Source |
|---|---|---|---|
| Godot Engine | grafika i interfejs / graphics and UI | MIT | https://godotengine.org |
| Składniki Godota (FreeType, HarfBuzz, ICU, mbed TLS i inne) / Godot third-party components | wbudowane w silnik / built into the engine | wg `COPYRIGHT.txt` Godota (MIT, BSD, FreeType License, Apache 2.0 i inne) | https://github.com/godotengine/godot/blob/master/COPYRIGHT.txt |
| godot-cpp | połączenie z rdzeniem C++ / C++ bindings | MIT | https://github.com/godotengine/godot-cpp |
| PortAudio | wejście i wyjście dźwięku / audio I/O | MIT (PortAudio License) | https://www.portaudio.com |
| PortMidi | urządzenia MIDI / MIDI devices | MIT-style | https://github.com/PortMidi/portmidi |
| libsndfile | zapis i odczyt plików dźwiękowych / audio file I/O | LGPL 2.1 lub nowsza / or later | https://libsndfile.github.io/libsndfile/ |
| TinySoundFont | wbudowany syntezator MIDI / built-in MIDI synthesizer | MIT | https://github.com/schellingb/TinySoundFont |
| PFFFT | analiza widma / spectrum analysis | BSD-like (FFTPACK) | https://bitbucket.org/jpommier/pffft |
| SQLite | profil i postępy / profile and progress | domena publiczna / public domain | https://sqlite.org |
| Inter, Space Grotesk, Noto Music, Noto Sans Symbols 2 | kroje pisma / fonts | SIL Open Font License 1.1 | https://fonts.google.com |

## Warunki szczególne / Specific obligations

**Godot Engine i składniki na licencjach MIT/BSD.** Informacja o prawach autorskich i tekst licencji muszą być dołączone do programu. W oknie „O programie” wyświetlany jest wykaz składników, a pełne teksty – w katalogu `licenses/` (tekst licencji Godota i jego składników można pobrać w programie przez `Engine.get_license_text()` i `Engine.get_copyright_info()`).

*Godot Engine and MIT/BSD components: the copyright notice and licence text must accompany the program. The "About" window lists the components; full texts are in `licenses/`.*

**libsndfile (LGPL 2.1+).** Biblioteka jest dołączana wyłącznie jako osobna biblioteka dynamiczna (`sndfile.dll`), niezmieniona, łączona dynamicznie. Użytkownik może ją zastąpić własną, zgodną wersją. Kod źródłowy użytej wersji jest dostępny pod adresem projektu lub na żądanie. Licencja programu nie zakazuje modyfikowania tej biblioteki ani odtwarzania kodu w zakresie potrzebnym do debugowania takich modyfikacji – tak jak wymaga tego LGPL.

*libsndfile (LGPL 2.1+): shipped only as a separate, unmodified, dynamically linked library (`sndfile.dll`) that the user may replace with a compatible version. The source of the version used is available from the project site or on request. The program licence does not prohibit modifying this library or reverse engineering to the extent needed to debug such modifications, as required by the LGPL.*

**Kroje OFL.** Kroje pisma mogą być osadzone w programie; nie są sprzedawane osobno, a ich licencja (OFL 1.1) jest dołączona.

*OFL fonts: the fonts may be embedded in the program; they are not sold separately, and their licence (OFL 1.1) is included.*
