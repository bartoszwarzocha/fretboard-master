# Godot – checklista optymalizacji (OpenGL)

Lista do odhaczenia w każdym projekcie Godot 4 z rendererem Compatibility (OpenGL). Zasada nadrzędna: każdy element, który na ekranie powtarza się choćby dwa razy, jest rysowany instancyjnie, a liczba wywołań rysowania jest minimalna i mierzona.

## 1. Ustawienia projektu i renderer

- [ ] Renderer `gl_compatibility` (OpenGL 3.3 / OpenGL ES 3.0) jako jedyny; brak funkcji dostępnych tylko w Forward+.
- [ ] Wersja Godota przypięta w repozytorium; ta sama w edytorze, CI i szablonie eksportu.
- [ ] Rozdzielczość bazowa i `stretch/mode = canvas_items`, `aspect = expand` – interfejs skaluje się bez dodatkowych buforów.
- [ ] Ustawienia jakości grafiki (cienie, wygładzanie, rozdzielczość 3D, efekty) w opcjach użytkownika, z bezpiecznym poziomem domyślnym dla słabego sprzętu.
- [ ] Wygładzanie krawędzi dobrane świadomie: MSAA tylko w 3D i tylko na poziomie, który widać (zwykle 2×), FXAA zamiast wyższego MSAA na słabym sprzęcie.
- [ ] Wyłączone nieużywane systemy: fizyka 3D, nawigacja, XR, sieć – w ustawieniach projektu i w szablonie eksportu.
- [ ] Tonemapping i oświetlenie skalibrowane pod Compatibility (inny wygląd niż Forward+), zamiast dokładać efekty, by to wyrównać.

## 2. Wywołania rysowania i instancje

- [ ] Każda siatka z tym samym materiałem, występująca co najmniej dwa razy, rysowana jako jeden `MultiMesh` – jedno wywołanie (i jedno w przebiegu cieni) zamiast jednego na kopię.
- [ ] Klucz grupowania = siatka + materiały wszystkich powierzchni + rzucanie cienia; materiały „wypalone” w kopii siatki.
- [ ] Wspólny instancer na viewport: obiekty zachowują węzły, pozycje i animacje, ale ich własne `MeshInstance3D` nie są rysowane (`layers = 0`), a do MultiMesh kopiowane jest tylko to, co się zmieniło.
- [ ] Zbiór „brudnych” instancji: aktualizacja tylko przesuniętych, obróconych, ukrytych lub przebarwionych elementów.
- [ ] Cały bufor instancji wysyłany jednym wywołaniem (`multimesh_set_buffer`), gdy zmienia się wiele instancji naraz; przy pojedynczych zmianach – tylko te instancje.
- [ ] Pojemność MultiMesh rośnie przez podwajanie, a widoczna liczba sterowana `visible_instance_count` – bez częstych zmian rozmiaru bufora.
- [ ] Usuwanie instancji przez zamianę z ostatnią (swap-remove), bez przesuwania całej tablicy.
- [ ] Kolor, stan, podświetlenie i faza animacji w danych instancji (`use_colors`, `use_custom_data` / `INSTANCE_CUSTOM`), nigdy w osobnych materiałach.
- [ ] Dwie strony lub warianty tego samego obiektu jako instancje jednej siatki z innym przekształceniem lub kolorem.
- [ ] Elementy statyczne sceny (dekoracje, ramki, tło) scalone w jedną siatkę lub MultiMesh przy budowaniu sceny.
- [ ] Animowane części obiektów statycznych (kołysanie, migotanie) przez przekształcenia instancji albo shader wierzchołków, nie przez osobne węzły.
- [ ] SubViewporty tylko tam, gdzie konieczne, z `render_target_update_mode` ustawionym na odświeżanie po zmianie lub wyłączonym, gdy niewidoczne.

## 3. Materiały, shadery, tekstury

- [ ] Jeden współdzielony materiał na rodzaj obiektu, tworzony raz i przechowywany statycznie (pamięć podręczna), nigdy `duplicate()` materiału dla pojedynczego obiektu.
- [ ] Różnice między obiektami przez dane instancji lub `instance uniform`, nie przez kopie materiałów.
- [ ] Liczba różnych shaderów minimalna; warianty przez parametry, nie przez osobne pliki shaderów.
- [ ] Materiały bez oświetlenia (`unshaded`) wszędzie, gdzie światło nie jest potrzebne (interfejs, efekty, znaczniki).
- [ ] Przezroczystość tylko tam, gdzie widać różnicę; obiekty nieprzezroczyste nie mają włączonego mieszania alfa ani alpha scissor bez potrzeby.
- [ ] Atlasy tekstur dla ikon, znaczników i drobnej grafiki – jedna tekstura zamiast wielu.
- [ ] Kompresja tekstur VRAM w eksporcie (`s3tc_bptc` na komputerach), mipmapy dla tekstur 3D, brak mipmap w interfejsie 2D.
- [ ] Rozmiary tekstur dopasowane do faktycznej wielkości na ekranie; potęga dwójki tam, gdzie są mipmapy.
- [ ] Tekstury generowane w kodzie (gradienty, miękkie kropki) tworzone raz i współdzielone.

## 4. Interfejs 2D

- [ ] Elementy jednej warstwy korzystają z tej samej tekstury (atlas) i materiału, żeby Godot mógł je zgrupować w jedno wywołanie.
- [ ] Powtarzalne kształty 2D (kropki, znaczniki, siatki) przez `MultiMeshInstance2D` albo jedno własne `_draw` na warstwę, nie setki węzłów.
- [ ] `queue_redraw()` tylko po zmianie danych, nigdy w każdej klatce bez potrzeby.
- [ ] Czcionki MSDF ze wspólnym atlasem glifów; ograniczona liczba krojów i rozmiarów.
- [ ] Teksty statyczne nie są przeliczane co klatkę; tłumaczenia odświeżane jednym przebiegiem przy zmianie języka.
- [ ] Ukryte okna i panele mają `visible = false` (nie tylko przezroczystość 0) i wyłączone przetwarzanie.
- [ ] Długie listy wirtualizowane – tworzone tylko widoczne wiersze.
- [ ] `clip_contents` i efekty na `CanvasItem` (modulate, shadery) tylko tam, gdzie konieczne, bo przerywają grupowanie.
- [ ] Rozmycie tła i inne efekty pełnoekranowe liczone raz do tekstury, gdy tło się nie zmienia.

## 5. Sceny 3D: geometria, światło, cienie

- [ ] Modele w wersji low-poly; liczba trójkątów każdego modelu mierzona i zapisana w budżecie.
- [ ] Poziomy szczegółowości (LOD) i `visibility_range` dla obiektów oglądanych z różnych odległości.
- [ ] Jedno światło kierunkowe plus światło otoczenia; światła punktowe tylko wyjątkowo (w Compatibility każde światło to kolejne przebiegi).
- [ ] Cienie rzucają tylko obiekty, których cień widać; drobne elementy, efekty i cząsteczki z `cast_shadow = OFF`.
- [ ] Rozdzielczość i zasięg mapy cieni dopasowane do sceny (`directional_shadow`, `shadow_atlas`), niższe na słabym sprzęcie.
- [ ] Kamera z ciasnymi `near` i `far`; obiekty poza kadrem odrzucane przez prawidłowe `AABB` (ręcznie ustawione dla MultiMesh i cząsteczek).
- [ ] Animacje szkieletowe tylko tam, gdzie potrzebne; proste ruchy przez przekształcenia lub shader.
- [ ] Efekty kosztowne w Compatibility (głębia ostrości, odbicia, SSAO) zastąpione tanimi odpowiednikami lub wyłączone.

## 6. Efekty i cząsteczki

- [ ] Cząsteczki GPU (`GPUParticles2D/3D`), nie CPU.
- [ ] Pula emiterów tworzona raz i wielokrotnie używana; brak tworzenia i usuwania węzłów przy każdym efekcie.
- [ ] Jeden współdzielony materiał cząsteczek (unshaded, billboard, mieszanie addytywne) i współdzielone tekstury oraz rampy zanikania.
- [ ] Liczba cząsteczek i czas życia minimalne dla zamierzonego efektu; ręcznie ustawione `visibility_aabb`.
- [ ] Efekty tła (pyłki, ambient) wyłączalne i zatrzymane, gdy efekty są wyłączone lub ekran jest nieaktywny.
- [ ] Animacje interfejsu przez `Tween`, tworzone na żądanie i zabijane przed utworzeniem kolejnego dla tego samego elementu.

## 7. Logika klatki, skrypty, odświeżanie

- [ ] Żadnego `_process` / `_physics_process` w setkach węzłów; jeden centralny takt, który aktualizuje grupy obiektów.
- [ ] Przetwarzanie wyłączone (`set_process(false)`, `process_mode = DISABLED`) w węzłach, które aktualnie nic nie robią.
- [ ] Gorące pętle (wiele obiektów, obliczenia co klatkę) w C++ przez GDExtension, nie w GDScript.
- [ ] Brak alokacji w pętli klatki: bufory, tablice i obiekty tworzone raz i wielokrotnie używane.
- [ ] Tryb oszczędny `low_processor_usage_mode` na ekranach statycznych (menu, przeglądanie, ustawienia) – klatka rysowana tylko po zmianie.
- [ ] Limit klatek (`max_fps`) i V-Sync włączone; niższy limit, gdy okno jest nieaktywne lub zminimalizowane.
- [ ] Ciężkie obliczenia (AI, generowanie, wczytywanie) w wątkach roboczych, z wynikiem przekazywanym do wątku głównego.
- [ ] Zasoby wczytywane w tle (`ResourceLoader.load_threaded_request`), nie w chwili pierwszego użycia.

## 8. Start programu, eksport, rozmiar

- [ ] Ekran rozruchowy silnika (`boot_splash`) identyczny z pierwszym ekranem programu – brak mignięcia przy przejściu.
- [ ] Wstępna kompilacja shaderów i „rozgrzewka”: każdy materiał, efekt i rodzaj cząsteczek narysowany raz za ekranem startowym, żeby później nie było przycięć.
- [ ] Ekran startowy zablokowany do końca rozgrzewki, z limitem czasu na wypadek błędu.
- [ ] Czas startu mierzony (od uruchomienia do pierwszej interaktywnej klatki) i pilnowany w testach.
- [ ] Własny szablon eksportu zbudowany ze źródeł: `target=template_release`, `optimize=size` (lub `speed_trace` po pomiarze), LTO, `production=yes`.
- [ ] W szablonie wyłączone nieużywane moduły i funkcje (np. `disable_3d` gdy 3D niepotrzebne, `module_*_enabled=no` dla fizyki, nawigacji, XR, WebRTC, nieużywanych formatów plików), profil buildu (`build_profile`) z listą używanych klas.
- [ ] Plik PCK wbudowany w plik wykonywalny (`embed_pck`), z wykluczonymi katalogami testów, dokumentacji i narzędzi.
- [ ] Zasoby dźwiękowe w OGG Vorbis, grafika skompresowana, nieużywane zasoby usuwane przed eksportem.
- [ ] Skrypty eksportowane w postaci binarnej (`script_export_mode` = skompilowane).

## 9. Pomiar i budżety wydajności

- [ ] Audyt każdego ekranu: liczba wywołań rysowania (widoczne i w przebiegu cieni), liczba obiektów, czas CPU i GPU renderowania, czas skryptów – przez `RenderingServer.get_rendering_info` i `viewport_get_render_info`.
- [ ] Audyt wykrywa każdą siatkę rysowaną więcej niż raz bez instancji, światła, obiekty rzucające cień, materiały przezroczyste i węzły przetwarzane co klatkę.
- [ ] Budżet dla każdego ekranu (wywołania rysowania, trójkąty, ms CPU/GPU, pamięć) zapisany w repozytorium; przekroczenie = błąd testu w CI.
- [ ] Pomiar na najsłabszym docelowym sprzęcie (zintegrowana grafika), nie tylko na komputerze deweloperskim.
- [ ] Pomiar skoków czasu klatki (nie tylko średniej) przy otwieraniu okien, pierwszych efektach i zmianach scen.
- [ ] Pomiar zużycia energii i obciążenia w bezczynności – program w spoczynku nie może obciążać GPU.
- [ ] Każda nowa funkcja graficzna przechodzi audyt przed scaleniem.
