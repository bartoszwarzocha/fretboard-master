#!/usr/bin/env python3
# Fretboard Master – kopiuje LICENSE.md i THIRD-PARTY-NOTICES.md do app/legal/ (jako .txt – pliki
# .md są wykluczone z eksportu), skąd okno „Licencja” w programie czyta ich treść.
# Uruchamiać po każdej zmianie tych plików:  python3 tools/sync_legal.py
import pathlib, shutil
root = pathlib.Path(__file__).resolve().parent.parent
dst = root / "app" / "legal"
dst.mkdir(exist_ok=True)
for name in ["LICENSE", "THIRD-PARTY-NOTICES"]:
    shutil.copyfile(root / f"{name}.md", dst / f"{name}.txt")
    print(f"{name}.md -> app/legal/{name}.txt")
