# Czcionki

Wszystkie na licencji SIL Open Font License 1.1 (pliki OFL-*.txt).

| Plik | Zastosowanie | Zmiany |
|---|---|---|
| Manrope.ttf | tekst interfejsu (domyślnie), nagłówki po rosyjsku | brak (wersja zmienna, oś wght) |
| Montserrat.ttf | tekst interfejsu (do wyboru w ustawieniach) | brak (wersja zmienna, oś wght) |
| Rubik.ttf | tekst interfejsu (do wyboru w ustawieniach) | brak (wersja zmienna, oś wght) |
| Inter.ttf | tekst interfejsu (do wyboru; krój z makiety) | brak (wersja zmienna, oś wght) |
| SpaceGrotesk.ttf | nagłówki | brak |
| Anton.ttf | numer wersji „2.0” przy logo (tekst 3D) | brak |
| NotoSansSymbols.ttf | symbole ←↗♩♭♮♯⚙ | podzbiór, ustalona grubość 400, zmienione metryki pionowe |
| NotoSansSymbols2.ttf | pozostałe symbole interfejsu | podzbiór, zmienione metryki pionowe |
| NotoMusic.ttf | klucz wiolinowy 𝄞 w tekście | podzbiór, zmienione metryki pionowe |
| Bravura.otf | symbole muzyczne (SMuFL): ikony modułów ♮ 𝄞 ♩, deseń i cząsteczki „nuty”, w przyszłości zapis nutowy | brak (wersja 1.482; nazwa „Bravura” zastrzeżona w OFL – pliku nie modyfikujemy) |

Czcionkę interfejsu wybiera się w ustawieniach (Wygląd i grafika → Motyw); opcja „Własna…” pozwala użyć
dowolnej czcionki zainstalowanej w systemie – brakujące w niej znaki uzupełnia Manrope. Logo i „2.0” (Anton)
oraz nagłówki (Space Grotesk) nie zależą od tego wyboru.

Metryki pionowe czcionek z symbolami ustawiono na ascent 0,968 em i descent 0,241 em (jak w Inter),
żeby czcionki zastępcze nie powiększały wysokości wiersza. Są to wersje zmodyfikowane w rozumieniu
OFL; rodzina Noto nie ma zastrzeżonych nazw czcionek, więc zachowanie nazw jest dozwolone.

Import: czcionki rastrowe z lekkim hintingiem i nadpróbkowaniem zależnym od skali okna, bez systemowych
czcionek zastępczych. MSDF jest wyłączone – przy zmiennej czcionce Inter (nakładające się kontury) dawało
ubytki w literach (e, i, j) w małych rozmiarach.
