# -*- coding: utf-8 -*-
"""Fretboard Master – źródło tłumaczeń. Uruchom: python tools/i18n_table.py  →  app/i18n/*.po, fbm.pot
Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone."""
import os

LANGS = ["pl", "de", "es", "ru"]
# msgid (EN) : (pl, de, es, ru)
T = {
 "Encyclopedia": ("Encyklopedia", "Enzyklopädie", "Enciclopedia", "Энциклопедия"),
 "Scales, chords and arpeggios on the fretboard and the staff. Start any trainer from here.": (
  "Skale, akordy i arpeggia na gryfie i pięciolinii. Stąd uruchomisz każdy trener.",
  "Tonleitern, Akkorde und Arpeggien auf dem Griffbrett und im Notensystem. Von hier aus startest du jeden Trainer.",
  "Escalas, acordes y arpegios en el mástil y en el pentagrama. Desde aquí inicias cualquier entrenador.",
  "Гаммы, аккорды и арпеджио на грифе и нотном стане. Отсюда запускается любой тренажёр."),
 "Trainers": ("Trenery", "Trainer", "Entrenadores", "Тренажёры"),
 "The program listens to your guitar and rates your playing: find the note, play the scale, recognise the chord.": (
  "Program słucha gitary i ocenia grę: znajdź dźwięk, zagraj skalę, rozpoznaj akord.",
  "Das Programm hört deiner Gitarre zu und bewertet dein Spiel: Ton finden, Tonleiter spielen, Akkord erkennen.",
  "El programa escucha tu guitarra y evalúa cómo tocas: encuentra la nota, toca la escala, reconoce el acorde.",
  "Программа слушает гитару и оценивает игру: найди ноту, сыграй гамму, узнай аккорд."),
 "Note reading": ("Czytanie nut", "Notenlesen", "Lectura de notas", "Чтение нот"),
 "Notes and tablature at a gradually increasing tempo.": (
  "Nuty i tabulatura w stopniowo rosnącym tempie.",
  "Noten und Tabulatur in allmählich steigendem Tempo.",
  "Notas y tablatura a un tempo que aumenta gradualmente.",
  "Ноты и табулатура в постепенно растущем темпе."),
 "Tuning": ("Strojenie", "Stimmen", "Afinación", "Настройка"),
 "Chromatic tuner and alternate tunings.": (
  "Stroik chromatyczny i stroje alternatywne.",
  "Chromatisches Stimmgerät und alternative Stimmungen.",
  "Afinador cromático y afinaciones alternativas.",
  "Хроматический тюнер и альтернативные строи."),
 "Metronome": ("Metronom", "Metronom", "Metrónomo", "Метроном"),
 "Tempo, metre, accents and gradual speed-up.": (
  "Tempo, metrum, akcenty i stopniowe przyspieszanie.",
  "Tempo, Taktart, Akzente und schrittweise Beschleunigung.",
  "Tempo, compás, acentos y aceleración gradual.",
  "Темп, размер, акценты и постепенное ускорение."),
 "Practice plan": ("Plan ćwiczeń", "Übungsplan", "Plan de práctica", "План занятий"),
 "Your set of exercises for today and for the week.": (
  "Twój zestaw ćwiczeń na dziś i na tydzień.",
  "Deine Übungen für heute und für die Woche.",
  "Tus ejercicios para hoy y para la semana.",
  "Твои упражнения на сегодня и на неделю."),
 "Progress": ("Postępy", "Fortschritt", "Progreso", "Прогресс"),
 "Statistics, weak spots on the fretboard, achievements.": (
  "Statystyki, słabe miejsca na gryfie, osiągnięcia.",
  "Statistiken, Schwachstellen auf dem Griffbrett, Erfolge.",
  "Estadísticas, puntos débiles en el mástil, logros.",
  "Статистика, слабые места на грифе, достижения."),
 "Settings": ("Ustawienia", "Einstellungen", "Ajustes", "Настройки"),
 "Sound and MIDI, guitar, appearance, language.": (
  "Dźwięk i MIDI, gitara, wygląd, język.",
  "Klang und MIDI, Gitarre, Darstellung, Sprache.",
  "Sonido y MIDI, guitarra, apariencia, idioma.",
  "Звук и MIDI, гитара, внешний вид, язык."),
 "Main menu": ("Menu główne", "Hauptmenü", "Menú principal", "Главное меню"),
 "Program logo": ("Logo programu", "Programmlogo", "Logotipo del programa", "Логотип программы"),
 "Company logo": ("Logo firmy", "Firmenlogo", "Logotipo de la empresa", "Логотип компании"),
 "Guitar artwork": ("Grafika gitary", "Gitarrengrafik", "Ilustración de la guitarra", "Изображение гитары"),
 "1800 × 1200 px (3:2), PNG": ("1800 × 1200 px (3:2), PNG", "1800 × 1200 px (3:2), PNG", "1800 × 1200 px (3:2), PNG", "1800 × 1200 пикс. (3:2), PNG"),
 "presents": ("przedstawia", "präsentiert", "presenta", "представляет"),
 "fretboard · theory · training": ("gryf · teoria · trening", "Griffbrett · Theorie · Training", "mástil · teoría · práctica", "гриф · теория · тренировка"),
 "Hello!": ("Dzień dobry!", "Hallo!", "¡Hola!", "Здравствуйте!"),
 "What shall we practise today?": ("Co dziś ćwiczymy?", "Was üben wir heute?", "¿Qué practicamos hoy?", "Что сегодня тренируем?"),
 "About": ("O programie", "Über das Programm", "Acerca de", "О программе"),
 "Version %s": ("Wersja %s", "Version %s", "Versión %s", "Версия %s"),
 "This module is under construction.": ("Moduł w przygotowaniu.", "Dieses Modul ist in Vorbereitung.", "Este módulo está en preparación.", "Модуль в разработке."),
 "Esc – back to the main menu": ("Esc – powrót do menu głównego", "Esc – zurück zum Hauptmenü", "Esc – volver al menú principal", "Esc – возврат в главное меню"),
 "System language": ("Język systemu", "Systemsprache", "Idioma del sistema", "Язык системы"),
 "Language": ("Język", "Sprache", "Idioma", "Язык"),
 "Colour theme": ("Motyw kolorystyczny", "Farbschema", "Tema de color", "Цветовая тема"),
 "Night": ("Nocny", "Nacht", "Noche", "Ночная"),
 "Graphite": ("Grafitowy", "Graphit", "Grafito", "Графитовая"),
 "Light": ("Jasny", "Hell", "Claro", "Светлая"),
 "Note names": ("Zapis nazw dźwięków", "Notennamen", "Nombres de las notas", "Названия нот"),
 "International (C D E F G A B)": ("Międzynarodowy (C D E F G A B)", "International (C D E F G A B)", "Internacional (C D E F G A B)", "Международные (C D E F G A B)"),
 "German (C D E F G A H, B = B♭)": ("Niemiecki (C D E F G A H, B = B♭)", "Deutsch (C D E F G A H, B = B♭)", "Alemán (C D E F G A H, B = B♭)", "Немецкие (C D E F G A H, B = B♭)"),
 "Solfège (Do Re Mi Fa Sol La Si)": ("Solmizacja (Do Re Mi Fa Sol La Si)", "Solmisation (Do Re Mi Fa Sol La Si)", "Solfeo (Do Re Mi Fa Sol La Si)", "Сольмизация (Do Re Mi Fa Sol La Si)"),
 "Example:": ("Przykład:", "Beispiel:", "Ejemplo:", "Пример:"),
 "Show performance data (F3)": ("Pokaż dane wydajności (F3)", "Leistungsdaten anzeigen (F3)", "Mostrar datos de rendimiento (F3)", "Показывать данные производительности (F3)"),
 "Fretboard Master is a guitar-learning program: an encyclopedia of scales and chords, trainers, note reading, a tuner and a metronome – with real-time recognition of the notes you play.": (
  "Fretboard Master to program do nauki gry na gitarze: encyklopedia skal i akordów, trenery, czytanie nut, stroik i metronom – z rozpoznawaniem dźwięku granego na gitarze w czasie rzeczywistym.",
  "Fretboard Master ist ein Programm zum Gitarrelernen: Enzyklopädie der Tonleitern und Akkorde, Trainer, Notenlesen, Stimmgerät und Metronom – mit Echtzeit-Erkennung der gespielten Töne.",
  "Fretboard Master es un programa para aprender guitarra: enciclopedia de escalas y acordes, entrenadores, lectura de notas, afinador y metrónomo, con reconocimiento en tiempo real de las notas que tocas.",
  "Fretboard Master – программа для обучения игре на гитаре: энциклопедия гамм и аккордов, тренажёры, чтение нот, тюнер и метроном – с распознаванием сыгранных нот в реальном времени."),
 "Copyright": ("Prawa autorskie", "Urheberrecht", "Derechos de autor", "Авторские права"),
 "Licence": ("Licencja", "Lizenz", "Licencia", "Лицензия"),
 "Freeware – proprietary licence": ("Freeware – licencja własnościowa", "Freeware – proprietäre Lizenz", "Freeware – licencia propietaria", "Freeware – проприетарная лицензия"),
 "C++ core": ("Rdzeń C++", "C++-Kern", "Núcleo C++", "Ядро C++"),
 "version %s": ("wersja %s", "Version %s", "versión %s", "версия %s"),
 "not built – GDScript fallback": ("niezbudowany – zastępczo GDScript", "nicht gebaut – GDScript-Ersatz", "no compilado – alternativa en GDScript", "не собрано – замена на GDScript"),
 "Third-party components": ("Składniki innych autorów", "Komponenten von Drittanbietern", "Componentes de terceros", "Сторонние компоненты"),
 "Public domain": ("Domena publiczna", "Gemeinfrei", "Dominio público", "Общественное достояние"),
}

def esc(s): return s.replace("\\", "\\\\").replace('"', '\\"')

def write(path, lang, idx):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write('# Fretboard Master – translations. Generated by tools/i18n_table.py – do not edit by hand.\n')
        f.write('msgid ""\nmsgstr ""\n"Project-Id-Version: Fretboard Master 2.0\\n"\n"MIME-Version: 1.0\\n"\n'
                '"Content-Type: text/plain; charset=UTF-8\\n"\n"Content-Transfer-Encoding: 8bit\\n"\n')
        if lang: f.write(f'"Language: {lang}\\n"\n')
        f.write("\n")
        for k, v in T.items():
            f.write(f'msgid "{esc(k)}"\nmsgstr "{esc(v[idx]) if idx is not None else ""}"\n\n')

out = os.path.join(os.path.dirname(__file__), "..", "app", "i18n")
os.makedirs(out, exist_ok=True)
write(os.path.join(out, "fbm.pot"), None, None)
for i, l in enumerate(LANGS):
    write(os.path.join(out, f"{l}.po"), l, i)
print(len(T), "strings")
