# Audyt wydajności

## Nakładka (F3)
W działającym programie F3 pokazuje: FPS, bieżący ekran, wywołania rysowania, obiekty, prymitywy,
węzły z włączonym przetwarzaniem i pamięć wideo. Na czas działania nakładki tryb oszczędny jest wyłączony.

## Audyt wszystkich ekranów
```
godot --path app --rendering-driver opengl3 --resolution 1920x1080 -- --perf-audit [--shots=<katalog>]
```
Program przechodzi przez ekrany wymienione w `app/perf/budgets.cfg`, odczekuje 8 klatek, mierzy 30 klatek
i porównuje najgorsze wartości z budżetem. Wynik: tabela w konsoli, kod wyjścia 0 (OK), 1 (przekroczenie),
2 (brak pliku budżetów). `--shots` zapisuje zrzut każdego ekranu.

Bez monitora (Linux, CI): `xvfb-run -a -s "-screen 0 1920x1080x24" godot …`.

## Zasady
- Nowy ekran = nowa sekcja w `budgets.cfg` (pomiar + ok. 25% zapasu).
- Ekrany statyczne: `processing_nodes = 0`. Animacje włączają przetwarzanie tylko na czas trwania.
- Audyt sprawdzać po rosyjsku (najwięcej różnych glifów).
- Pełna lista zasad: `optymalizacja-godot.md`.

## Później
- Własny szablon eksportu z profilem budowania (wyłączone nieużywane moduły: 3D-fizyka, nawigacja, XR,
  Vulkan/D3D12) – mniejszy plik i szybszy start.
