# Fretboard Master – motywy kolorystyczne i kroje. Cały wygląd interfejsu powstaje tutaj,
# w jednym zasobie Theme przypisanym do głównego okna (bez domyślnego wyglądu Godota).
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Node

signal theme_changed

const PALETTES := {
	&"night": {
		"name": "Night",
		"bg": Color("070A14"), "surface": Color("0E1324"), "surface_2": Color("121933"),
		"border": Color("1C2440"), "border_strong": Color("26305A"),
		"text": Color("E8ECF6"), "muted": Color("AEB7CF"), "faint": Color("6F7A99"),
		"accent": Color("F5B544"), "accent_text": Color("1A1206"), "focus": Color("3FD0C9"),
		"placeholder": Color("3A4566"),
	},
	&"graphite": {
		"name": "Graphite",
		"bg": Color("0F1012"), "surface": Color("17191C"), "surface_2": Color("1E2125"),
		"border": Color("2A2E34"), "border_strong": Color("3A3F47"),
		"text": Color("ECEDEF"), "muted": Color("B3B8C0"), "faint": Color("7C838D"),
		"accent": Color("F5B544"), "accent_text": Color("1A1206"), "focus": Color("3FD0C9"),
		"placeholder": Color("4A505A"),
	},
	&"light": {
		"name": "Light",
		"bg": Color("F4F1EA"), "surface": Color("FFFFFF"), "surface_2": Color("F0ECE3"),
		"border": Color("E2DCCF"), "border_strong": Color("CFC6B4"),
		"text": Color("1B2030"), "muted": Color("4E5568"), "faint": Color("7C8295"),
		"accent": Color("D98E0B"), "accent_text": Color("FFFFFF"), "focus": Color("118C86"),
		"placeholder": Color("B9B09E"),
	},
}
const DEFAULT_PALETTE := &"night"
# Kolory akcentu do wyboru w ustawieniach ("" = akcent motywu).
const ACCENTS := ["F5B544", "FF8A1F", "FF5C5C", "E85D9C", "B98CFF", "5AA9FF", "3FD0C9", "7BD88F"]
# Ustawienia, po których zmianie motyw jest budowany od nowa.
const THEME_KEYS := [&"theme", &"accent", &"panel_opacity", &"panel_radius", &"panel_shadow", &"font_scale"]

const RADIUS_CARD := 20
const RADIUS_CONTROL := 10

var palette: Dictionary = PALETTES[DEFAULT_PALETTE]
var theme: Theme

# Kroje: Inter (tekst), Space Grotesk (nagłówki), Noto – symbole muzyczne. Wspólne zasoby, tworzone raz.
var font_body: FontVariation
var font_body_medium: FontVariation
var font_body_bold: FontVariation
var font_heading: FontVariation
var font_symbols: FontFile
var font_music: FontFile   # Bravura (SMuFL) – symbole muzyczne w ikonach, tle i (później) w nutach


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_load_fonts()
	App.settings_changed.connect(_on_settings_changed)
	if DisplayServer.has_method(&"set_system_theme_change_callback"):
		DisplayServer.set_system_theme_change_callback(func() -> void:
			if str(App.setting(&"theme")) == "auto":
				apply(palette_id()))
	apply(palette_id())


# Motyw „auto” wybiera nocny albo jasny według ustawienia systemu.
func palette_id() -> StringName:
	var id := StringName(App.setting(&"theme"))
	if id == &"auto":
		return &"night" if DisplayServer.is_dark_mode() else &"light"
	return id if PALETTES.has(id) else DEFAULT_PALETTE


func color(key: String) -> Color:
	return palette[key]


func apply(id: StringName) -> void:
	palette = (PALETTES.get(id, PALETTES[DEFAULT_PALETTE]) as Dictionary).duplicate()
	var accent := str(App.setting(&"accent"))
	if not accent.is_empty():
		palette.accent = Color(accent)
		palette.accent_text = Color("1A1206") if palette.accent.get_luminance() > 0.55 else Color.WHITE
	theme = _build_theme()
	get_tree().root.theme = theme
	RenderingServer.set_default_clear_color(palette.bg)
	theme_changed.emit()


func _on_settings_changed(key: StringName) -> void:
	if key in THEME_KEYS:
		apply(palette_id())
	elif key == &"language":
		# Space Grotesk nie ma cyrylicy – dla rosyjskiego nagłówki składa Inter.
		_update_heading_font()


# --- Kroje --------------------------------------------------------------------

func _load_fonts() -> void:
	# Symbole: najpierw Noto Sans Symbols (♯ ♭ ♮ ⚙ w stylu tekstowym), potem Symbols 2 i Noto Music (𝄞).
	var symbols: Array[Font] = [
		load("res://assets/fonts/NotoSansSymbols.ttf"),
		load("res://assets/fonts/NotoSansSymbols2.ttf"),
		load("res://assets/fonts/NotoMusic.ttf"),
	]
	font_symbols = symbols[0]
	font_symbols.fallbacks = [symbols[1], symbols[2]]
	font_music = load("res://assets/fonts/Bravura.otf")
	var inter: FontFile = load("res://assets/fonts/Inter.ttf")
	inter.fallbacks = symbols
	font_body = _variation(inter, 400)
	font_body_medium = _variation(inter, 500)
	font_body_bold = _variation(inter, 650)
	font_heading = FontVariation.new()
	_update_heading_font()


func _update_heading_font() -> void:
	var lang := TranslationServer.get_locale().substr(0, 2)
	if lang == "ru":
		font_heading.base_font = font_body_bold.base_font
		font_heading.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	else:
		var grotesk: FontFile = load("res://assets/fonts/SpaceGrotesk.ttf")
		grotesk.fallbacks = [font_body_bold.base_font]
		font_heading.base_font = grotesk
		font_heading.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}


func _variation(base: FontFile, weight: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return v


# --- Theme --------------------------------------------------------------------

func box(bg: Color, border := Color.TRANSPARENT, radius := RADIUS_CONTROL, border_w := 1,
		pad_h := 16, pad_v := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	s.anti_aliasing = true
	return s


# Rozmiar czcionki przeliczony przez ustawienie „Wielkość czcionki”.
func fs(px: int) -> int:
	return roundi(px * float(App.setting(&"font_scale")))


func radius_card() -> int:
	return int(App.setting(&"panel_radius"))


# Tło panelu lub kafelka z ustawień wyglądu: przezroczystość, zaokrąglenie, cień.
func card_box(bg: Color, border: Color, pad := 24) -> StyleBoxFlat:
	var opacity := float(App.setting(&"panel_opacity"))
	var s := box(Color(bg, bg.a * opacity), Color(border, border.a * maxf(opacity, 0.35)), radius_card(), 1, pad, pad)
	var shadow := int(App.setting(&"panel_shadow"))
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.4)
	return s


func _build_theme() -> Theme:
	var p := palette
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = fs(18)

	# Teksty
	t.set_color("font_color", "Label", p.text)
	t.add_type("Heading")
	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", font_heading)
	t.set_font_size("font_size", "Heading", fs(34))
	t.add_type("Title")
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", font_heading)
	t.set_font_size("font_size", "Title", fs(26))
	t.add_type("Muted")
	t.set_type_variation("Muted", "Label")
	t.set_color("font_color", "Muted", p.muted)
	t.set_font_size("font_size", "Muted", fs(16))
	t.add_type("Caption")
	t.set_type_variation("Caption", "Label")
	t.set_color("font_color", "Caption", p.faint)
	t.set_font_size("font_size", "Caption", fs(14))
	t.add_type("Strong")
	t.set_type_variation("Strong", "Label")
	t.set_font("font", "Strong", font_body_bold)

	# Panele
	t.set_stylebox("panel", "PanelContainer", card_box(p.surface, p.border))
	t.set_stylebox("panel", "Panel", card_box(p.surface, p.border, 0))
	t.add_type("Bar")
	t.set_type_variation("Bar", "PanelContainer")
	var bar := box(Color(p.surface, float(App.setting(&"panel_opacity"))), p.border, 0, 0, 32, 12)
	t.set_stylebox("panel", "Bar", bar)

	# Przyciski
	for type in ["Button", "OptionButton", "CheckBox"]:
		t.set_font("font", type, font_body_medium)
		t.set_font_size("font_size", type, fs(17))
		t.set_color("font_color", type, p.text)
		t.set_color("font_hover_color", type, p.text)
		t.set_color("font_pressed_color", type, p.text)
		t.set_color("font_focus_color", type, p.text)
		t.set_color("font_disabled_color", type, p.faint)
	t.set_stylebox("normal", "Button", box(p.surface_2, p.border_strong))
	t.set_stylebox("hover", "Button", box(p.border, p.border_strong))
	t.set_stylebox("pressed", "Button", box(p.border_strong, p.border_strong))
	t.set_stylebox("disabled", "Button", box(p.surface, p.border))
	t.set_stylebox("focus", "Button", _focus_box())

	t.add_type("AccentButton")
	t.set_type_variation("AccentButton", "Button")
	t.set_font("font", "AccentButton", font_body_bold)
	t.set_color("font_color", "AccentButton", p.accent_text)
	t.set_color("font_hover_color", "AccentButton", p.accent_text)
	t.set_color("font_pressed_color", "AccentButton", p.accent_text)
	t.set_stylebox("normal", "AccentButton", box(p.accent))
	t.set_stylebox("hover", "AccentButton", box(p.accent.lightened(0.12)))
	t.set_stylebox("pressed", "AccentButton", box(p.accent.darkened(0.1)))

	# Zakładki nawigacji w nagłówku modułów
	t.add_type("NavButton")
	t.set_type_variation("NavButton", "Button")
	t.set_color("font_color", "NavButton", p.muted)
	t.set_color("font_hover_color", "NavButton", p.text)
	t.set_color("font_pressed_color", "NavButton", p.text)
	t.set_stylebox("normal", "NavButton", box(Color.TRANSPARENT, Color.TRANSPARENT, RADIUS_CONTROL, 0, 16, 9))
	t.set_stylebox("hover", "NavButton", box(p.surface_2, Color.TRANSPARENT, RADIUS_CONTROL, 0, 16, 9))
	t.set_stylebox("pressed", "NavButton", box(p.border, Color.TRANSPARENT, RADIUS_CONTROL, 0, 16, 9))
	t.set_stylebox("hover_pressed", "NavButton", box(p.border, Color.TRANSPARENT, RADIUS_CONTROL, 0, 16, 9))

	# Odnośnik tekstowy (stopka)
	t.add_type("TextLink")
	t.set_type_variation("TextLink", "Button")
	t.set_color("font_color", "TextLink", p.muted)
	t.set_color("font_hover_color", "TextLink", p.text)
	t.set_font_size("font_size", "TextLink", fs(16))
	for st in ["normal", "hover", "pressed"]:
		t.set_stylebox(st, "TextLink", box(Color.TRANSPARENT, Color.TRANSPARENT, 6, 0, 4, 2))

	# Listy rozwijane i menu
	t.set_stylebox("normal", "OptionButton", box(p.surface_2, p.border_strong))
	t.set_stylebox("hover", "OptionButton", box(p.border, p.border_strong))
	t.set_stylebox("pressed", "OptionButton", box(p.border_strong, p.border_strong))
	t.set_stylebox("focus", "OptionButton", _focus_box())
	t.set_color("font_color", "PopupMenu", p.text)
	t.set_color("font_hover_color", "PopupMenu", p.text)
	t.set_font_size("font_size", "PopupMenu", fs(17))
	t.set_stylebox("panel", "PopupMenu", box(p.surface_2, p.border_strong, RADIUS_CONTROL, 1, 6, 6))
	t.set_stylebox("hover", "PopupMenu", box(p.border, Color.TRANSPARENT, 6, 0, 8, 4))
	t.set_constant("v_separation", "PopupMenu", 10)

	# Pola wyboru i strzałka listy – ikony rysowane z SVG w kolorach motywu
	var on := '<rect x="1" y="1" width="20" height="20" rx="6" fill="#%s"/><path d="M6 11.5l3.2 3.2L16 7.8" fill="none" stroke="#%s" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>' % [p.accent.to_html(false), p.accent_text.to_html(false)]
	var off := '<rect x="1.5" y="1.5" width="19" height="19" rx="6" fill="#%s" stroke="#%s" stroke-width="1.5"/>' % [p.surface_2.to_html(false), p.border_strong.to_html(false)]
	t.set_icon("checked", "CheckBox", _svg_icon(on, 22))
	t.set_icon("unchecked", "CheckBox", _svg_icon(off, 22))
	t.set_icon("checked_disabled", "CheckBox", _svg_icon(on, 22))
	t.set_icon("unchecked_disabled", "CheckBox", _svg_icon(off, 22))
	t.set_constant("h_separation", "CheckBox", 12)
	var arrow := '<path d="M5 8l6 6 6-6" fill="none" stroke="#%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>' % p.muted.to_html(false)
	t.set_icon("arrow", "OptionButton", _svg_icon(arrow, 22))
	t.set_constant("arrow_margin", "OptionButton", 12)
	t.set_stylebox("normal", "CheckBox", box(Color.TRANSPARENT, Color.TRANSPARENT, 6, 0, 0, 4))
	t.set_stylebox("hover", "CheckBox", box(Color.TRANSPARENT, Color.TRANSPARENT, 6, 0, 0, 4))
	t.set_stylebox("pressed", "CheckBox", box(Color.TRANSPARENT, Color.TRANSPARENT, 6, 0, 0, 4))
	t.set_stylebox("focus", "CheckBox", _focus_box())

	# Separatory, paski przewijania, podpowiedzi
	var line := StyleBoxLine.new()
	line.color = p.border
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 1)
	t.set_stylebox("scroll", "VScrollBar", box(Color.TRANSPARENT, Color.TRANSPARENT, 4, 0, 4, 0))
	t.set_stylebox("grabber", "VScrollBar", box(p.border_strong, Color.TRANSPARENT, 4, 0, 4, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(p.faint, Color.TRANSPARENT, 4, 0, 4, 0))
	t.set_stylebox("panel", "TooltipPanel", box(p.surface_2, p.border_strong, 8, 1, 10, 6))
	t.set_color("font_color", "TooltipLabel", p.text)

	# Suwaki: tor, wypełnienie w kolorze akcentu, okrągły uchwyt
	var track := box(p.border, Color.TRANSPARENT, 3, 0, 0, 3)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", box(p.accent, Color.TRANSPARENT, 3, 0, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(p.accent.lightened(0.1), Color.TRANSPARENT, 3, 0, 0, 3))
	var knob := '<circle cx="11" cy="11" r="8.5" fill="#%s" stroke="#%s" stroke-width="2.5"/>' % [p.text.to_html(false), p.accent.to_html(false)]
	t.set_icon("grabber", "HSlider", _svg_icon(knob, 22))
	t.set_icon("grabber_highlight", "HSlider", _svg_icon(knob, 22))
	t.set_stylebox("focus", "HSlider", _focus_box())

	# Pola tekstowe
	t.set_stylebox("normal", "LineEdit", box(p.surface_2, p.border_strong))
	t.set_stylebox("focus", "LineEdit", _focus_box())
	t.set_color("font_color", "LineEdit", p.text)
	t.set_font_size("font_size", "LineEdit", fs(16))

	# Pasek przewijania: wąski, zaokrąglony, bez strzałek
	t.set_stylebox("scroll", "VScrollBar", box(Color.TRANSPARENT, Color.TRANSPARENT, 4, 0, 4, 4))
	t.set_stylebox("grabber", "VScrollBar", box(p.border_strong, Color.TRANSPARENT, 4, 0, 4, 4))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(p.faint, Color.TRANSPARENT, 4, 0, 4, 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(p.muted, Color.TRANSPARENT, 4, 0, 4, 4))

	# Zakładki okna ustawień (pionowe)
	t.add_type("SideTab")
	t.set_type_variation("SideTab", "Button")
	t.set_color("font_color", "SideTab", p.muted)
	t.set_color("font_hover_color", "SideTab", p.text)
	t.set_color("font_pressed_color", "SideTab", p.text)
	t.set_color("font_hover_pressed_color", "SideTab", p.text)
	t.set_constant("h_separation", "SideTab", 14)
	t.set_stylebox("normal", "SideTab", box(Color.TRANSPARENT, Color.TRANSPARENT, RADIUS_CONTROL, 0, 18, 12))
	t.set_stylebox("hover", "SideTab", box(p.surface_2, Color.TRANSPARENT, RADIUS_CONTROL, 0, 18, 12))
	var sel := box(p.border, Color.TRANSPARENT, RADIUS_CONTROL, 0, 18, 12)   # jak w makiecie: granatowe tło
	t.set_stylebox("pressed", "SideTab", sel)
	t.set_stylebox("hover_pressed", "SideTab", sel)
	t.set_stylebox("focus", "SideTab", _focus_box())

	# Nagłówek sekcji w ustawieniach
	t.add_type("Section")
	t.set_type_variation("Section", "Label")
	t.set_font("font", "Section", font_body_bold)
	t.set_font_size("font_size", "Section", fs(13))
	t.set_color("font_color", "Section", p.accent)
	return t


# Ikona z fragmentu SVG (rysowana raz przy budowie motywu, w rozdzielczości 2× dla ostrości po skalowaniu).
func _svg_icon(body: String, px: int) -> ImageTexture:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % [px, px, px, px, body]
	var img := Image.new()
	img.load_svg_from_string(svg, 2.0)
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(px, px))
	return tex


func _focus_box() -> StyleBoxFlat:
	var s := box(Color.TRANSPARENT, palette.focus, RADIUS_CONTROL + 2, 2)
	s.draw_center = false
	s.set_expand_margin_all(3)
	return s
