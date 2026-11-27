# Fretboard Master 2.0

Program do nauki gry na gitarze. Godot 4.7 (renderer Compatibility/OpenGL) + rdzeń C++ (GDExtension).

© 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Program zamknięty, freeware –
zob. [LICENSE.md](LICENSE.md) i [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Struktura
| Katalog | Zawartość |
|---|---|
| `app/` | projekt Godota (otwierać w edytorze: `app/project.godot`) |
| `app/scripts/autoload/` | `App` (nawigacja, ustawienia, język), `ThemeManager` (motywy, czcionki), `Backdrop` (tło, cząsteczki, efekt trafienia), `Graphics` (okno, klatki, jakość, korekcja obrazu), `PerfAudit` |
| `app/scripts/screens/` | ekrany: startowy, menu, moduły, ustawienia, „O programie” |
| `app/scripts/ui/` | elementy interfejsu: kafelki, nagłówek, pola zastępcze grafik |
| `app/i18n/` | tłumaczenia gettext (EN – źródłowy, PL, DE, ES, RU) |
| `app/perf/budgets.cfg` | budżety wydajności ekranów |
| `native/` | rdzeń C++ (CMake, godot-cpp pobierany automatycznie) |
| `tools/` | narzędzia: generator tłumaczeń, wersja Godota |
| `docs/` | zasady optymalizacji, audyt wydajności |

## Wymagania
- Godot 4.7.1 (`tools/godot-version.txt`)
- CMake ≥ 3.24, kompilator C++20 (Windows: Visual Studio 2022; Linux: GCC/Clang), Python 3, Git

## Budowanie rdzenia C++
Windows (Developer PowerShell):
```
cmake -S native -B native/build -G "Visual Studio 17 2022" -A x64
cmake --build native/build --config Release
```
Linux:
```
cmake -S native -B native/build -DCMAKE_BUILD_TYPE=Release
cmake --build native/build -j
```
Biblioteka trafia do `app/bin/`. Wersja dla eksportu wydania: dodać `-DGODOTCPP_TARGET=template_release`.
Bez rdzenia program działa – nazwy dźwięków liczy wtedy zapasowy kod GDScript.

## Uruchamianie
Edytor: otworzyć `app/project.godot`, F5. Z wiersza poleceń: `godot --path app`.

## Tłumaczenia
Teksty źródłowe i przekłady: `tools/i18n_table.py`. Po zmianie: `python3 tools/i18n_table.py`
(generuje `app/i18n/*.po` i `fbm.pot`).

## Wydajność
F3 – dane wydajności jako tekst w stopce (to samo co „Pokaż dane wydajności” w ustawieniach). Audyt wszystkich ekranów: `godot --path app -- --perf-audit`
(szczegóły: [docs/audyt-wydajnosci.md](docs/audyt-wydajnosci.md)).

## Pola zastępcze
Na razie bez grafik – w ich miejscu przerywane ramki z nazwą i ścieżką pliku:
- `app/assets/graphics/menu-guitar.png` – grafika gitary w menu (1800 × 1200 px),
