# Fretboard Master – ustawienia: język, motyw kolorystyczny, zapis nazw dźwięków, dane wydajności.
# Pozostałe grupy (dźwięk i MIDI, gitara) powstaną razem z rdzeniem audio.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends ModuleScreen

const LANGUAGE_NAMES := {"": "System language", "en": "English", "pl": "Polski", "de": "Deutsch",
		"es": "Español", "ru": "Русский"}

var _sample: Label


func _init() -> void:
	module_id = &"settings"


func _build_content() -> void:
	var title := Label.new()
	title.text = "Settings"
	title.theme_type_variation = &"Heading"
	content.add_child(title)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.custom_minimum_size.x = 760
	content.add_child(card)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 20)
	card.add_child(grid)

	# Język
	var lang := _option(grid, "Language")
	for code in App.LANGUAGES:
		lang.add_item(LANGUAGE_NAMES[code])
		# Nazwy języków w ich własnym zapisie – bez tłumaczenia (poza „Język systemu”).
	lang.set_item_auto_translate_mode(0, Node.AUTO_TRANSLATE_MODE_ALWAYS)
	for i in range(1, lang.item_count):
		lang.set_item_auto_translate_mode(i, Node.AUTO_TRANSLATE_MODE_DISABLED)
	lang.selected = App.LANGUAGES.find(App.language())
	lang.item_selected.connect(func(i): App.set_setting(&"language", App.LANGUAGES[i]))

	# Motyw
	var theme_opt := _option(grid, "Colour theme")
	var ids := ThemeManager.PALETTES.keys()
	for id in ids:
		theme_opt.add_item(ThemeManager.PALETTES[id].name)
	theme_opt.selected = ids.find(ThemeManager.palette_id())
	theme_opt.item_selected.connect(func(i): App.set_setting(&"theme", String(ids[i])))

	# Zapis nazw dźwięków – niezależny od języka
	var notation := _option(grid, "Note names")
	for label in NoteNames.NOTATION_LABELS:
		notation.add_item(label)
	notation.selected = App.notation()
	notation.item_selected.connect(func(i):
		App.set_setting(&"notation", i)
		_update_sample())
	grid.add_child(Control.new())
	_sample = Label.new()
	_sample.theme_type_variation = &"Muted"
	_sample.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	grid.add_child(_sample)
	_update_sample()

	# Dane wydajności
	grid.add_child(Control.new())
	var perf := CheckBox.new()
	perf.text = "Show performance data (F3)"
	perf.button_pressed = PerfAudit._overlay != null and PerfAudit._overlay.visible
	perf.toggled.connect(func(_on): PerfAudit.toggle_overlay())
	grid.add_child(perf)


func _option(grid: GridContainer, label_text: String) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(label)
	var opt := OptionButton.new()
	opt.custom_minimum_size.x = 420
	opt.fit_to_longest_item = false
	grid.add_child(opt)
	return opt


func _update_sample() -> void:
	_sample.text = "%s  %s" % [tr("Example:"), NoteNames.chromatic_scale(App.notation())]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _sample:
		_update_sample()
