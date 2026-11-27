# -*- coding: utf-8 -*-
"""Fretboard Master – źródło bazy skal i akordów Encyklopedii.
Uruchom: python tools/theory_db.py  →  app/data/theory.json (+ sprawdzenie poprawności danych).

Stopnie zapisane względem skali durowej toniki: liczba 1–13 z przedrostkiem znaków (b, bb, #, ##).
Liczba stopnia wyznacza literę dźwięku (pisownia literowa), znaki – jego wysokość.
Nazwy: (en, pl, de, es, ru). Synonimy (aliasy) – ta sama skala pod inną nazwą, bez duplikatów pozycji.
Skale diatoniczne mają „parent” – stopień, od którego zaczyna się macierzysta skala durowa
(znaki przykluczowe jak w niej); pozostałe – znaki tonacji durowej/molowej toniki („sig”: major/minor).
Źródło zestawu: baza v1 (po usunięciu duplikatów i błędów) uzupełniona wg List of musical scales and
modes (Wikipedia) i ogólnie przyjętej teorii (dane teoretyczne – nie podlegają ochronie).
Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone."""
import json
import os

BASE = {1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11}


def semis(deg):
	acc = 0
	d = deg
	while d[0] in "b#":
		acc += -1 if d[0] == "b" else 1
		d = d[1:]
	n = int(d)
	return BASE[(n - 1) % 7 + 1] + 12 * ((n - 1) // 7) + acc


def N(en, pl, de, es, ru):
	return {"en": en, "pl": pl, "de": de, "es": es, "ru": ru}


# ---------------------------------------------------------------- SKALE
# (id, stopnie, nazwa, aliasy, opcje)
SCALE_CATS = [
	("modes", N("Modes of the major scale", "Skale modalne", "Kirchentonarten", "Modos de la escala mayor", "Лады мажорной гаммы"), [
		("ionian", "1 2 3 4 5 6 7", N("Ionian (major)", "jońska (durowa)", "Ionisch (Dur)", "jónica (mayor)", "ионийский (мажор)"), [], {"parent": "1"}),
		("dorian", "1 2 b3 4 5 6 b7", N("Dorian", "dorycka", "Dorisch", "dórica", "дорийский"), [], {"parent": "b7"}),
		("phrygian", "1 b2 b3 4 5 b6 b7", N("Phrygian", "frygijska", "Phrygisch", "frigia", "фригийский"), [], {"parent": "b6"}),
		("lydian", "1 2 3 #4 5 6 7", N("Lydian", "lidyjska", "Lydisch", "lidia", "лидийский"), [], {"parent": "5"}),
		("mixolydian", "1 2 3 4 5 6 b7", N("Mixolydian", "miksolidyjska", "Mixolydisch", "mixolidia", "миксолидийский"), [], {"parent": "4"}),
		("aeolian", "1 2 b3 4 5 b6 b7", N("Aeolian (natural minor)", "eolska (molowa naturalna)", "Äolisch (natürliches Moll)", "eólica (menor natural)", "эолийский (натуральный минор)"),
			[N("Ethiopian", "etiopska", "Äthiopisch", "etíope", "эфиопский")], {"parent": "b3"}),
		("locrian", "1 b2 b3 4 b5 b6 b7", N("Locrian", "lokrycka", "Lokrisch", "locria", "локрийский"), [], {"parent": "b2"}),
	]),
	("melodic", N("Melodic minor modes", "Modusy skali molowej melodycznej", "Modi von Melodisch Moll", "Modos de la menor melódica", "Лады мелодического минора"), [
		("melodic_minor", "1 2 b3 4 5 6 7", N("Melodic minor (jazz minor)", "molowa melodyczna (jazzowa)", "Melodisch Moll (Jazz-Moll)", "menor melódica (menor de jazz)", "мелодический минор (джазовый)"),
			[N("Hawaiian", "hawajska", "Hawaiianisch", "hawaiana", "гавайский")], {}),
		("dorian_b2", "1 b2 b3 4 5 6 b7", N("Dorian ♭2", "dorycka ♭2", "Dorisch ♭2", "dórica ♭2", "дорийский ♭2"),
			[N("Javanese", "jawajska", "Javanisch", "javanesa", "яванский")], {}),
		("lydian_aug", "1 2 3 #4 #5 6 7", N("Lydian augmented", "lidyjska zwiększona", "Lydisch übermäßig", "lidia aumentada", "лидийский увеличенный"), [], {}),
		("lydian_dom", "1 2 3 #4 5 6 b7", N("Lydian dominant", "lidyjska dominantowa", "Lydisch dominant", "lidia dominante", "лидийский доминантовый"),
			[N("Overtone (acoustic)", "alikwotowa (akustyczna)", "Obertonskala (akustisch)", "de armónicos (acústica)", "обертоновый (акустический)")], {}),
		("mixolydian_b6", "1 2 3 4 5 b6 b7", N("Mixolydian ♭6", "miksolidyjska ♭6", "Mixolydisch ♭6", "mixolidia ♭6", "миксолидийский ♭6"),
			[N("Hindu", "hinduska", "Hindu", "hindú", "индийский")], {}),
		("locrian_n2", "1 2 b3 4 b5 b6 b7", N("Locrian ♮2 (half-diminished)", "lokrycka ♮2 (półzmniejszona)", "Lokrisch ♮2 (halbvermindert)", "locria ♮2 (semidisminuida)", "локрийский ♮2 (полууменьшённый)"), [], {}),
		("altered", "1 b2 b3 b4 b5 b6 b7", N("Altered (super Locrian)", "alterowana (superlokrycka)", "Alteriert (Superlokrisch)", "alterada (superlocria)", "альтерированный (суперлокрийский)"), [], {"sig": "minor"}),
	]),
	("harmonic", N("Harmonic minor modes", "Modusy skali molowej harmonicznej", "Modi von Harmonisch Moll", "Modos de la menor armónica", "Лады гармонического минора"), [
		("harmonic_minor", "1 2 b3 4 5 b6 7", N("Harmonic minor", "molowa harmoniczna", "Harmonisch Moll", "menor armónica", "гармонический минор"),
			[N("Mohammedan", "mahometańska", "Mohammedanisch", "mahometana", "магометанский")], {}),
		("locrian_n6", "1 b2 b3 4 b5 6 b7", N("Locrian ♮6", "lokrycka ♮6", "Lokrisch ♮6", "locria ♮6", "локрийский ♮6"), [], {}),
		("ionian_s5", "1 2 3 4 #5 6 7", N("Ionian ♯5", "jońska ♯5", "Ionisch ♯5", "jónica ♯5", "ионийский ♯5"), [], {}),
		("dorian_s4", "1 2 b3 #4 5 6 b7", N("Dorian ♯4 (Ukrainian Dorian)", "dorycka ♯4 (ukraińska dorycka)", "Dorisch ♯4 (ukrainisch-dorisch)", "dórica ♯4 (dórica ucraniana)", "дорийский ♯4 (украинский дорийский)"),
			[N("Romanian minor", "rumuńska molowa", "Rumänisch Moll", "menor rumana", "румынский минор")], {}),
		("phrygian_dom", "1 b2 3 4 5 b6 b7", N("Phrygian dominant", "frygijska dominantowa", "Phrygisch dominant", "frigia dominante", "фригийский доминантовый"),
			[N("Spanish (Phrygian major)", "hiszpańska (frygijska durowa)", "Spanisch (Phrygisch Dur)", "española (frigia mayor)", "испанский (фригийский мажор)"),
			 N("Ahava Rabbah (Jewish)", "Ahawa Rabba (żydowska)", "Ahava Rabba (jüdisch)", "Ahavá Rabá (judía)", "Ахава Раба (еврейский)")], {}),
		("lydian_s2", "1 #2 3 #4 5 6 7", N("Lydian ♯2", "lidyjska ♯2", "Lydisch ♯2", "lidia ♯2", "лидийский ♯2"), [], {}),
		("ultralocrian", "1 b2 b3 b4 b5 b6 bb7", N("Ultralocrian", "ultralokrycka", "Ultralokrisch", "ultralocria", "ультралокрийский"), [], {"sig": "minor"}),
	]),
	("pentatonic", N("Pentatonic", "Pentatonika", "Pentatonik", "Pentatónicas", "Пентатоника"), [
		("penta_major", "1 2 3 5 6", N("Major pentatonic", "pentatonika durowa", "Dur-Pentatonik", "pentatónica mayor", "мажорная пентатоника"),
			[N("Mongolian", "mongolska", "Mongolisch", "mongola", "монгольский"), N("Chinese (gong)", "chińska (gong)", "Chinesisch (Gong)", "china (gong)", "китайский (гун)")], {}),
		("penta_minor", "1 b3 4 5 b7", N("Minor pentatonic", "pentatonika molowa", "Moll-Pentatonik", "pentatónica menor", "минорная пентатоника"), [], {}),
		("penta_dom", "1 2 3 5 b7", N("Dominant pentatonic", "pentatonika dominantowa", "Dominant-Pentatonik", "pentatónica dominante", "доминантовая пентатоника"), [], {}),
		("egyptian", "1 2 4 5 b7", N("Egyptian (suspended)", "egipska (zawieszona)", "Ägyptisch (suspendiert)", "egipcia (suspendida)", "египетский (подвешенный)"), [], {"sig": "minor"}),
		("yo", "1 2 4 5 6", N("Yo", "yo", "Yo", "yo", "ё"),
			[N("Ritusen", "ritsusen", "Ritsusen", "ritsusen", "рицусэн")], {"sig": "major"}),
		("man_gong", "1 b3 4 b6 b7", N("Man gong (blues minor pentatonic)", "man gong (bluesowa molowa)", "Man Gong (Blues-Moll-Pentatonik)", "man gong (pentatónica de blues menor)", "мань гун (блюзовая минорная)"), [], {}),
		("hirajoshi", "1 2 b3 5 b6", N("Hirajōshi", "hirajoshi", "Hirajōshi", "hirajōshi", "хирадзёси"), [], {}),
		("kumoi", "1 2 b3 5 6", N("Kumoi", "kumoi", "Kumoi", "kumoi", "кумои"), [], {}),
		("in_sen", "1 b2 4 5 b7", N("In-sen", "in-sen", "In-Sen", "in-sen", "ин-сэн"), [], {"sig": "minor"}),
		("in", "1 b2 4 5 b6", N("In (Miyako-bushi)", "in (miyako-bushi)", "In (Miyako-bushi)", "in (miyako-bushi)", "ин (мияко-буси)"),
			[N("Japanese", "japońska", "Japanisch", "japonesa", "японский")], {"sig": "minor"}),
		("iwato", "1 b2 4 b5 b7", N("Iwato", "iwato", "Iwato", "iwato", "ивато"), [], {"sig": "minor"}),
		("pelog", "1 b2 b3 5 b6", N("Pelog (Balinese)", "pelog (balijska)", "Pelog (balinesisch)", "pelog (balinesa)", "пелог (балийский)"), [], {}),
		("chinese", "1 3 #4 5 7", N("Chinese", "chińska", "Chinesisch", "china", "китайский"), [], {}),
	]),
	("blues", N("Blues", "Blues", "Blues", "Blues", "Блюз"), [
		("blues", "1 b3 4 b5 5 b7", N("Blues (minor)", "bluesowa (molowa)", "Blues (Moll)", "blues (menor)", "блюзовый (минорный)"), [], {}),
		("blues_major", "1 2 b3 3 5 6", N("Major blues", "bluesowa durowa", "Blues (Dur)", "blues mayor", "мажорный блюзовый"), [], {"sig": "major"}),
		("blues_nonatonic", "1 2 b3 3 4 5 6 b7 7", N("Blues nonatonic", "bluesowa dziewięciodźwiękowa", "Blues (neuntönig)", "blues nonatónica", "девятиступенный блюзовый"), [], {"sig": "major"}),
	]),
	("bebop", N("Bebop", "Bebop", "Bebop", "Bebop", "Бибоп"), [
		("bebop_dom", "1 2 3 4 5 6 b7 7", N("Bebop dominant", "bebopowa dominantowa", "Bebop dominant", "bebop dominante", "бибоп доминантовый"), [], {}),
		("bebop_major", "1 2 3 4 5 #5 6 7", N("Bebop major", "bebopowa durowa", "Bebop Dur", "bebop mayor", "бибоп мажорный"), [], {}),
		("bebop_dorian", "1 2 b3 3 4 5 6 b7", N("Bebop Dorian (minor)", "bebopowa dorycka (molowa)", "Bebop dorisch (Moll)", "bebop dórica (menor)", "бибоп дорийский (минорный)"), [], {"sig": "minor"}),
		("bebop_melodic", "1 2 b3 4 5 #5 6 7", N("Bebop melodic minor", "bebopowa molowa melodyczna", "Bebop melodisch Moll", "bebop menor melódica", "бибоп мелодический минор"), [], {}),
		("bebop_locrian", "1 b2 b3 4 b5 5 b6 b7", N("Bebop Locrian (half-diminished)", "bebopowa lokrycka (półzmniejszona)", "Bebop lokrisch (halbvermindert)", "bebop locria (semidisminuida)", "бибоп локрийский (полууменьшённый)"), [], {}),
	]),
	("hexatonic", N("Hexatonic and tetratonic", "Heksatonika i tetratonika", "Hexatonik und Tetratonik", "Hexatónicas y tetratónicas", "Гексатоника и тетратоника"), [
		("hexa_major", "1 2 3 4 5 6", N("Major hexatonic", "heksatonika durowa", "Dur-Hexatonik", "hexatónica mayor", "мажорная гексатоника"), [], {}),
		("hexa_minor", "1 2 b3 4 5 b7", N("Minor hexatonic", "heksatonika molowa", "Moll-Hexatonik", "hexatónica menor", "минорная гексатоника"), [], {}),
		("prometheus", "1 2 3 #4 6 b7", N("Prometheus", "prometejska", "Prometheus", "prometeo", "прометеев"), [], {}),
		("tritone", "1 b2 3 b5 5 b7", N("Tritone", "trytonowa", "Tritonus-Skala", "de tritonos", "тритоновый"), [], {}),
		("tetra_genus", "1 2 4 5", N("Genus primum", "genus primum", "Genus primum", "genus primum", "genus primum"), [], {"sig": "major"}),
		("tetra_eskimo", "1 2 3 5", N("Eskimo tetratonic", "eskimoska", "Eskimo-Tetratonik", "tetratónica esquimal", "эскимосская тетратоника"), [], {}),
		("tetra_biyu", "1 b3 5 b7", N("Bi yu", "bi yu", "Bi Yu", "bi yu", "би юй"), [], {}),
	]),
	("symmetric", N("Symmetric", "Symetryczne", "Symmetrische", "Simétricas", "Симметричные"), [
		("whole_tone", "1 2 3 #4 #5 #6", N("Whole tone", "całotonowa", "Ganztonleiter", "de tonos enteros", "целотонный"), [], {}),
		("dim_hw", "1 b2 #2 3 #4 5 6 b7", N("Diminished half–whole (dominant)", "zmniejszona półton–cały ton (dominantowa)", "Halbton-Ganzton (dominantisch vermindert)", "disminuida semitono–tono (dominante)", "уменьшённый полутон–тон (доминантовый)"), [], {}),
		("dim_wh", "1 2 b3 4 b5 #5 6 7", N("Diminished whole–half", "zmniejszona cały ton–półton", "Ganzton-Halbton (vermindert)", "disminuida tono–semitono", "уменьшённый тон–полутон"), [], {}),
		("augmented", "1 #2 3 5 #5 7", N("Augmented", "zwiększona", "Übermäßige Skala", "aumentada", "увеличенный"), [], {}),
		("chromatic", "1 #1 2 #2 3 4 #4 5 #5 6 #6 7", N("Chromatic", "chromatyczna", "Chromatisch", "cromática", "хроматическая"), [], {"sig": "major"}),
	]),
	("ethnic", N("Ethnic and exotic", "Etniczne i egzotyczne", "Ethnische und exotische", "Étnicas y exóticas", "Этнические и экзотические"), [
		("double_harmonic", "1 b2 3 4 5 b6 7", N("Double harmonic (Byzantine)", "podwójna harmoniczna (bizantyjska)", "Doppelharmonisch (Byzantinisch)", "doble armónica (bizantina)", "двойной гармонический (византийский)"),
			[N("Arabic (Hijaz Kar)", "arabska (hidżaz kar)", "Arabisch (Hijaz Kar)", "árabe (hijaz kar)", "арабский (хиджаз кар)"), N("Gypsy major", "cygańska durowa", "Zigeuner-Dur", "gitana mayor", "цыганский мажор")], {}),
		("hungarian_minor", "1 2 b3 #4 5 b6 7", N("Hungarian minor", "węgierska molowa", "Ungarisch Moll", "menor húngara", "венгерский минор"),
			[N("Gypsy minor", "cygańska molowa", "Zigeuner-Moll", "gitana menor", "цыганский минор"), N("Algerian", "algierska", "Algerisch", "argelina", "алжирский")], {}),
		("hungarian_major", "1 #2 3 #4 5 6 b7", N("Hungarian major", "węgierska durowa", "Ungarisch Dur", "mayor húngara", "венгерский мажор"), [], {}),
		("neapolitan_major", "1 b2 b3 4 5 6 7", N("Neapolitan major", "neapolitańska durowa", "Neapolitanisch Dur", "napolitana mayor", "неаполитанский мажор"), [], {}),
		("neapolitan_minor", "1 b2 b3 4 5 b6 7", N("Neapolitan minor", "neapolitańska molowa", "Neapolitanisch Moll", "napolitana menor", "неаполитанский минор"), [], {}),
		("persian", "1 b2 3 4 b5 b6 7", N("Persian", "perska", "Persisch", "persa", "персидский"), [], {}),
		("oriental", "1 b2 3 4 b5 6 b7", N("Oriental", "orientalna", "Orientalisch", "oriental", "восточный"), [], {}),
		("major_locrian", "1 2 3 4 b5 b6 b7", N("Major Locrian (Arabian)", "lokrycka durowa (arabska)", "Lokrisch Dur (Arabisch)", "locria mayor (arábiga)", "мажорный локрийский (арабский)"), [], {}),
		("lydian_minor", "1 2 3 #4 5 b6 b7", N("Lydian minor", "lidyjska molowa", "Lydisch Moll", "lidia menor", "лидийский минор"), [], {}),
		("lydian_dim", "1 2 b3 #4 5 6 7", N("Lydian diminished", "lidyjska zmniejszona", "Lydisch vermindert", "lidia disminuida", "лидийский уменьшённый"), [], {}),
		("enigmatic", "1 b2 3 #4 #5 #6 7", N("Enigmatic", "enigmatyczna", "Enigmatisch", "enigmática", "загадочный"), [], {}),
		("leading_whole_tone", "1 2 3 #4 #5 #6 7", N("Leading whole tone", "całotonowa z dźwiękiem prowadzącym", "Ganzton mit Leitton", "de tonos enteros con sensible", "целотонный с вводным тоном"), [], {}),
		("harmonic_major", "1 2 3 4 5 b6 7", N("Harmonic major", "durowa harmoniczna", "Harmonisch Dur", "mayor armónica", "гармонический мажор"), [], {}),
		("flamenco", "1 b2 b3 3 4 5 b6 b7", N("Flamenco", "flamenco", "Flamenco", "flamenca", "фламенко"), [], {"sig": "minor"}),
		("spanish_8", "1 b2 #2 3 4 b5 b6 b7", N("Spanish eight-tone", "hiszpańska ośmiodźwiękowa", "Spanisch achttönig", "española de ocho tonos", "испанский восьмиступенный"), [], {}),
	]),
]

# ---------------------------------------------------------------- AKORDY
# (id, oznaczenie (przyrostek), stopnie, nazwa, aliasy, arpeggio)
CHORD_CATS = [
	("major", N("Major", "Durowe", "Dur", "Mayores", "Мажорные"), [
		("maj", "", "1 3 5", N("major", "durowy", "Dur", "mayor", "мажорный"), [], True),
		("add9", "add9", "1 3 5 9", N("added ninth", "durowy z noną", "Dur mit None", "mayor con novena añadida", "мажорный с ноной"),
			[N("add2", "add2", "add2", "add2", "add2")], False),
		("add11", "add11", "1 3 4 5", N("added eleventh (add4)", "durowy z kwartą (add4)", "Dur mit Quarte (add4)", "mayor con cuarta añadida (add4)", "мажорный с квартой (add4)"), [], False),
		("6", "6", "1 3 5 6", N("major sixth", "durowy z sekstą", "Sextakkord (Dur)", "sexta mayor", "мажорный секстаккорд"), [], True),
		("69", "6/9", "1 3 5 6 9", N("six-nine", "durowy z sekstą i noną", "Sext-None", "sexta-novena", "секстнонаккорд"), [], False),
		("maj7", "maj7", "1 3 5 7", N("major seventh", "wielki septymowy", "großer Septakkord", "séptima mayor", "большой мажорный септаккорд"), [], True),
		("maj9", "maj9", "1 3 5 7 9", N("major ninth", "wielki nonowy", "großer Nonenakkord", "novena mayor", "большой мажорный нонаккорд"), [], True),
		("maj7s11", "maj7♯11", "1 3 5 7 #11", N("major seventh sharp eleven", "wielki septymowy z ♯11", "großer Septakkord ♯11", "séptima mayor ♯11", "большой мажорный септаккорд ♯11"), [], False),
		("maj9s11", "maj9♯11", "1 3 5 7 9 #11", N("major ninth sharp eleven", "wielki nonowy z ♯11", "großer Nonenakkord ♯11", "novena mayor ♯11", "большой мажорный нонаккорд ♯11"), [], False),
		("maj11", "maj11", "1 3 5 7 9 11", N("major eleventh", "wielki undecymowy", "großer Undezimakkord", "oncena mayor", "большой мажорный ундецимаккорд"), [], False),
		("maj13", "maj13", "1 3 5 7 9 13", N("major thirteenth", "wielki tercdecymowy", "großer Tredezimakkord", "trecena mayor", "большой мажорный терцдецимаккорд"), [], False),
		("maj13s11", "maj13♯11", "1 3 5 7 9 #11 13", N("major thirteenth sharp eleven", "wielki tercdecymowy z ♯11", "großer Tredezimakkord ♯11", "trecena mayor ♯11", "большой мажорный терцдецимаккорд ♯11"), [], False),
		("maj7b5", "maj7♭5", "1 3 b5 7", N("major seventh flat five", "wielki septymowy z ♭5", "großer Septakkord ♭5", "séptima mayor ♭5", "большой мажорный септаккорд ♭5"), [], False),
		("maj7s5", "maj7♯5", "1 3 #5 7", N("augmented major seventh", "zwiększony wielki septymowy", "übermäßiger großer Septakkord", "séptima mayor aumentada", "увеличенный большой септаккорд"), [], True),
	]),
	("minor", N("Minor", "Molowe", "Moll", "Menores", "Минорные"), [
		("m", "m", "1 b3 5", N("minor", "molowy", "Moll", "menor", "минорный"), [], True),
		("madd9", "m(add9)", "1 b3 5 9", N("minor added ninth", "molowy z noną", "Moll mit None", "menor con novena añadida", "минорный с ноной"),
			[N("m(add2)", "m(add2)", "m(add2)", "m(add2)", "m(add2)")], False),
		("madd11", "m(add11)", "1 b3 4 5", N("minor added eleventh (add4)", "molowy z kwartą (add4)", "Moll mit Quarte (add4)", "menor con cuarta añadida (add4)", "минорный с квартой (add4)"), [], False),
		("m6", "m6", "1 b3 5 6", N("minor sixth", "molowy z sekstą", "Moll-Sextakkord", "sexta menor", "минорный секстаккорд"), [], True),
		("m69", "m6/9", "1 b3 5 6 9", N("minor six-nine", "molowy z sekstą i noną", "Moll-Sext-None", "menor sexta-novena", "минорный секстнонаккорд"), [], False),
		("m7", "m7", "1 b3 5 b7", N("minor seventh", "molowy septymowy", "Moll-Septakkord", "séptima menor", "малый минорный септаккорд"), [], True),
		("mmaj7", "m(maj7)", "1 b3 5 7", N("minor major seventh", "molowy z septymą wielką", "Moll mit großer Septime", "menor con séptima mayor", "минорный большой септаккорд"), [], True),
		("m7add11", "m7(add11)", "1 b3 5 b7 11", N("minor seventh added eleventh", "molowy septymowy z undecymą", "Moll-Septakkord mit Undezime", "séptima menor con oncena", "малый минорный септаккорд с ундецимой"), [], False),
		("m9", "m9", "1 b3 5 b7 9", N("minor ninth", "molowy nonowy", "Moll-Nonenakkord", "novena menor", "минорный нонаккорд"), [], True),
		("mmaj9", "m(maj9)", "1 b3 5 7 9", N("minor major ninth", "molowy nonowy z septymą wielką", "Moll-Nonenakkord mit großer Septime", "novena menor con séptima mayor", "минорный нонаккорд с большой септимой"), [], False),
		("m11", "m11", "1 b3 5 b7 9 11", N("minor eleventh", "molowy undecymowy", "Moll-Undezimakkord", "oncena menor", "минорный ундецимаккорд"), [], False),
		("m13", "m13", "1 b3 5 b7 9 11 13", N("minor thirteenth", "molowy tercdecymowy", "Moll-Tredezimakkord", "trecena menor", "минорный терцдецимаккорд"), [], False),
		("m7b5", "m7♭5", "1 b3 b5 b7", N("half-diminished (minor seventh flat five)", "półzmniejszony (m7♭5)", "halbvermindert (m7♭5)", "semidisminuido (m7♭5)", "полууменьшённый (m7♭5)"), [], True),
		("m9b5", "m9♭5", "1 b3 b5 b7 9", N("half-diminished ninth", "półzmniejszony z noną", "halbverminderter Nonenakkord", "semidisminuido con novena", "полууменьшённый с ноной"), [], False),
		("m7s5", "m7♯5", "1 b3 #5 b7", N("minor seventh sharp five", "molowy septymowy z ♯5", "Moll-Septakkord ♯5", "séptima menor ♯5", "малый минорный септаккорд ♯5"), [], False),
	]),
	("dominant", N("Dominant", "Dominantowe", "Dominant", "Dominantes", "Доминантовые"), [
		("7", "7", "1 3 5 b7", N("dominant seventh", "dominantowy septymowy", "Dominantseptakkord", "séptima dominante", "доминантсептаккорд"), [], True),
		("9", "9", "1 3 5 b7 9", N("dominant ninth", "dominantowy nonowy", "Dominantnonenakkord", "novena dominante", "доминантнонаккорд"), [], True),
		("11", "11", "1 3 5 b7 9 11", N("dominant eleventh", "dominantowy undecymowy", "Dominant-Undezimakkord", "oncena dominante", "доминантовый ундецимаккорд"), [], False),
		("13", "13", "1 3 5 b7 9 13", N("dominant thirteenth", "dominantowy tercdecymowy", "Dominant-Tredezimakkord", "trecena dominante", "доминантовый терцдецимаккорд"), [], False),
		("7add11", "7(add11)", "1 3 4 5 b7", N("seventh added eleventh", "septymowy z kwartą", "Septakkord mit Quarte", "séptima con cuarta añadida", "септаккорд с квартой"), [], False),
		("7add13", "7(add13)", "1 3 5 6 b7", N("seventh added thirteenth", "septymowy z sekstą", "Septakkord mit Sexte", "séptima con sexta añadida", "септаккорд с секстой"), [], False),
		("7sus2", "7sus2", "1 2 5 b7", N("seventh suspended second", "septymowy z zawieszoną sekundą", "Septakkord sus2", "séptima suspendida 2", "септаккорд sus2"), [], False),
		("7sus4", "7sus4", "1 4 5 b7", N("seventh suspended fourth", "septymowy z zawieszoną kwartą", "Septakkord sus4", "séptima suspendida 4", "септаккорд sus4"), [], True),
		("9sus4", "9sus4", "1 4 5 b7 9", N("ninth suspended fourth", "nonowy z zawieszoną kwartą", "Nonenakkord sus4", "novena suspendida 4", "нонаккорд sus4"), [], False),
		("13sus4", "13sus4", "1 4 5 b7 9 13", N("thirteenth suspended fourth", "tercdecymowy z zawieszoną kwartą", "Tredezimakkord sus4", "trecena suspendida 4", "терцдецимаккорд sus4"), [], False),
		("7s11", "7♯11", "1 3 5 b7 #11", N("seventh sharp eleven", "septymowy z ♯11", "Septakkord ♯11", "séptima ♯11", "септаккорд ♯11"), [], False),
		("9s11", "9♯11", "1 3 5 b7 9 #11", N("ninth sharp eleven", "nonowy z ♯11", "Nonenakkord ♯11", "novena ♯11", "нонаккорд ♯11"), [], False),
		("13s11", "13♯11", "1 3 5 b7 9 #11 13", N("thirteenth sharp eleven", "tercdecymowy z ♯11", "Tredezimakkord ♯11", "trecena ♯11", "терцдецимаккорд ♯11"), [], False),
		("7b13", "7♭13", "1 3 5 b7 b13", N("seventh flat thirteen", "septymowy z ♭13", "Septakkord ♭13", "séptima ♭13", "септаккорд ♭13"), [], False),
	]),
	("altered", N("Altered", "Alterowane", "Alteriert", "Alterados", "Альтерированные"), [
		("7b5", "7♭5", "1 3 b5 b7", N("seventh flat five", "septymowy z ♭5", "Septakkord ♭5", "séptima ♭5", "септаккорд ♭5"), [], False),
		("7s5", "7♯5", "1 3 #5 b7", N("augmented seventh", "septymowy zwiększony", "übermäßiger Septakkord", "séptima aumentada", "увеличенный септаккорд"),
			[N("+7", "+7", "+7", "+7", "+7")], True),
		("7b9", "7♭9", "1 3 5 b7 b9", N("seventh flat nine", "septymowy z ♭9", "Septakkord ♭9", "séptima ♭9", "септаккорд ♭9"), [], False),
		("7s9", "7♯9", "1 3 5 b7 #9", N("seventh sharp nine", "septymowy z ♯9", "Septakkord ♯9", "séptima ♯9", "септаккорд ♯9"), [], False),
		("7b5b9", "7♭5♭9", "1 3 b5 b7 b9", N("seventh flat five flat nine", "septymowy z ♭5 i ♭9", "Septakkord ♭5 ♭9", "séptima ♭5 ♭9", "септаккорд ♭5 ♭9"), [], False),
		("7b5s9", "7♭5♯9", "1 3 b5 b7 #9", N("seventh flat five sharp nine", "septymowy z ♭5 i ♯9", "Septakkord ♭5 ♯9", "séptima ♭5 ♯9", "септаккорд ♭5 ♯9"), [], False),
		("7s5b9", "7♯5♭9", "1 3 #5 b7 b9", N("seventh sharp five flat nine", "septymowy z ♯5 i ♭9", "Septakkord ♯5 ♭9", "séptima ♯5 ♭9", "септаккорд ♯5 ♭9"), [], False),
		("7s5s9", "7♯5♯9", "1 3 #5 b7 #9", N("seventh sharp five sharp nine", "septymowy z ♯5 i ♯9", "Septakkord ♯5 ♯9", "séptima ♯5 ♯9", "септаккорд ♯5 ♯9"), [], False),
		("9b5", "9♭5", "1 3 b5 b7 9", N("ninth flat five", "nonowy z ♭5", "Nonenakkord ♭5", "novena ♭5", "нонаккорд ♭5"), [], False),
		("9s5", "9♯5", "1 3 #5 b7 9", N("ninth sharp five", "nonowy z ♯5", "Nonenakkord ♯5", "novena ♯5", "нонаккорд ♯5"), [], False),
		("11b9", "11♭9", "1 3 5 b7 b9 11", N("eleventh flat nine", "undecymowy z ♭9", "Undezimakkord ♭9", "oncena ♭9", "ундецимаккорд ♭9"), [], False),
		("13b9", "13♭9", "1 3 5 b7 b9 13", N("thirteenth flat nine", "tercdecymowy z ♭9", "Tredezimakkord ♭9", "trecena ♭9", "терцдецимаккорд ♭9"), [], False),
	]),
	("other", N("Other", "Pozostałe", "Weitere", "Otros", "Другие"), [
		("5", "5", "1 5", N("power chord (fifth)", "kwintowy (power chord)", "Powerchord (Quinte)", "quinta (power chord)", "квинта (пауэр-аккорд)"), [], False),
		("aug", "+", "1 3 #5", N("augmented", "zwiększony", "übermäßig", "aumentado", "увеличенный"), [N("aug", "aug", "aug", "aug", "aug")], True),
		("dim", "°", "1 b3 b5", N("diminished", "zmniejszony", "vermindert", "disminuido", "уменьшённый"), [N("dim", "dim", "dim", "dim", "dim")], True),
		("dim7", "°7", "1 b3 b5 bb7", N("diminished seventh", "zmniejszony septymowy", "verminderter Septakkord", "séptima disminuida", "уменьшённый септаккорд"), [N("dim7", "dim7", "dim7", "dim7", "dim7")], True),
		("dimmaj7", "°(maj7)", "1 b3 b5 7", N("diminished major seventh", "zmniejszony z septymą wielką", "vermindert mit großer Septime", "disminuido con séptima mayor", "уменьшённый с большой септимой"), [], False),
		("sus2", "sus2", "1 2 5", N("suspended second", "z zawieszoną sekundą", "sus2", "suspendido 2", "sus2"), [], True),
		("sus4", "sus4", "1 4 5", N("suspended fourth", "z zawieszoną kwartą", "sus4", "suspendido 4", "sus4"), [], True),
		("sus24", "sus2sus4", "1 2 4 5", N("suspended second and fourth", "z zawieszoną sekundą i kwartą", "sus2 sus4", "suspendido 2 y 4", "sus2 sus4"), [], False),
	]),
]


def build():
	out = {"scales": [], "scale_categories": [], "chords": [], "chord_categories": []}
	errors = []
	seen = {}
	for cat_id, cat_name, items in SCALE_CATS:
		out["scale_categories"].append({"id": cat_id, "name": cat_name})
		for sid, degs, name, aliases, opt in items:
			d = degs.split()
			st = [semis(x) for x in d]
			if st != sorted(st) or len(set(st)) != len(st) or st[0] != 0 or st[-1] >= 12:
				errors.append("skala %s: stopnie nierosnące lub poza oktawą %s" % (sid, st))
			key = tuple(st)
			if key in seen:
				errors.append("skala %s: te same dźwięki co %s – użyj aliasu" % (sid, seen[key]))
			seen[key] = sid
			e = {"id": sid, "cat": cat_id, "degrees": d, "name": name}
			if aliases:
				e["aliases"] = aliases
			e.update(opt)
			out["scales"].append(e)
	seen = {}
	for cat_id, cat_name, items in CHORD_CATS:
		out["chord_categories"].append({"id": cat_id, "name": cat_name})
		for cid, sym, degs, name, aliases, arp in items:
			d = degs.split()
			st = [semis(x) for x in d]
			if st != sorted(st) or len(set(st)) != len(st):
				errors.append("akord %s: stopnie nierosnące %s" % (cid, st))
			key = tuple(sorted(set(x % 12 for x in st)))
			if key in seen:
				errors.append("akord %s: te same dźwięki co %s – użyj aliasu" % (cid, seen[key]))
			seen[key] = cid
			e = {"id": cid, "cat": cat_id, "symbol": sym, "degrees": d, "name": name}
			if aliases:
				e["aliases"] = aliases
			if arp:
				e["arpeggio"] = True
			out["chords"].append(e)
	return out, errors


if __name__ == "__main__":
	data, errs = build()
	for e in errs:
		print("BŁĄD:", e)
	root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "app", "data")
	os.makedirs(root, exist_ok=True)
	with open(os.path.join(root, "theory.json"), "w", encoding="utf-8") as f:
		json.dump(data, f, ensure_ascii=False, indent=1)
	print("%d skal, %d akordów, %d arpeggiów, błędów: %d" % (len(data["scales"]), len(data["chords"]),
		sum(1 for c in data["chords"] if c.get("arpeggio")), len(errs)))
