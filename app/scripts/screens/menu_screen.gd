# Fretboard Master – menu główne: logo i powitanie w lewej kolumnie, kafelki modułów na całą
# wysokość, stopka z logo firmy i wersją.
# Wejście z ekranu startowego (intro_from): logo firmy i programu odjeżdżają z miejsc, w których
# były na ekranie startowym, na swoje miejsca w menu; kafelki pojawiają się w losowej kolejności,
# szybko się przybliżając. Całość trwa ok. 1,15 s; potem żaden węzeł nie jest przetwarzany.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Control

const MOVE_TIME := 1.0                    # przejazd logo
const TILE_DELAY := Vector2(0.2, 0.65)    # losowe opóźnienie kafelka (od–do)
const TILE_TIME := 0.5                    # pojawienie się kafelka
const SPLASH_LOGO := Vector2(640, 320)    # rozmiar logo programu na ekranie startowym
const SPLASH_COMPANY := Vector2(260, 70)  # rozmiar logo firmy na ekranie startowym
const MENU_LOGO := Vector2(340, 170)
const MENU_COMPANY := Vector2(150, 40)

## Prostokąty logo na ekranie startowym: {"logo": Rect2, "company": Rect2}; puste = bez animacji.
var intro_from := {}

var _version_label: Label
var _logo_slot: Control
var _logo: Logo3D
var _company_slot: Control
var _company: CompanyLogo
var _tiles: Array[Control] = []
var _fade: Array[Control] = []


func _ready() -> void:
	set_process(false)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 32)
	margin.add_child(page)

	# Treść: lewa kolumna (logo, hasło, powitanie), po prawej kafelki na całą wysokość
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 48)
	page.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 360
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)

	# Logo programu: rysowane w rozmiarze z ekranu startowego i pomniejszone (zawsze ostre,
	# bez zmiany rozmiaru bufora w czasie przejazdu).
	_logo_slot = Control.new()
	_logo_slot.custom_minimum_size = MENU_LOGO
	_logo_slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(_logo_slot)
	_logo = Logo3D.create(SPLASH_LOGO)
	_logo.size = SPLASH_LOGO
	_logo.scale = Vector2.ONE * (MENU_LOGO.y / SPLASH_LOGO.y)
	_logo_slot.add_child(_logo)

	var tagline := Label.new()
	tagline.text = "fretboard · theory · training"
	tagline.theme_type_variation = &"Caption"
	tagline.uppercase = true
	left.add_child(tagline)
	_fade.append(tagline)
	var gap := Control.new()
	gap.custom_minimum_size.y = 48
	left.add_child(gap)
	var hello := Label.new()
	hello.text = "Hello!"
	hello.theme_type_variation = &"Muted"
	hello.add_theme_font_size_override("font_size", 18)
	left.add_child(hello)
	_fade.append(hello)
	var question := Label.new()
	question.text = "What shall we practise today?"
	question.theme_type_variation = &"Title"
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(question)
	_fade.append(question)

	var grid := TileGrid.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	for i in App.MODULES.size():
		var tile := ModuleTile.create(App.MODULES[i], i == 0)
		grid.add_child(tile)
		_tiles.append(tile)

	# Stopka – wyśrodkowana w pionie między linią a dolną krawędzią okna
	page.add_child(HSeparator.new())
	var foot := HBoxContainer.new()
	foot.custom_minimum_size.y = 72
	foot.add_theme_constant_override("separation", 24)
	page.add_child(foot)
	_company_slot = Control.new()
	_company_slot.custom_minimum_size = MENU_COMPANY
	_company_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_company_slot)
	_company = CompanyLogo.create(SPLASH_COMPANY)
	_company.size = SPLASH_COMPANY
	_company.scale = Vector2.ONE * (MENU_COMPANY.y / SPLASH_COMPANY.y)
	_company_slot.add_child(_company)
	var copyright := Label.new()
	copyright.text = "© 2026 BW Digital Systems & Publishing"
	copyright.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	copyright.theme_type_variation = &"Muted"
	copyright.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(copyright)
	_fade.append(copyright)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	var about := Button.new()
	about.text = "About"
	about.theme_type_variation = &"TextLink"
	about.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	about.pressed.connect(App.go.bind(&"about"))
	foot.add_child(about)
	_fade.append(about)
	var bar := Label.new()
	bar.text = "|"
	bar.theme_type_variation = &"Caption"
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(bar)
	_fade.append(bar)
	var version := Label.new()
	version.theme_type_variation = &"Strong"
	version.add_theme_font_size_override("font_size", 16)
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	version.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	version.text = tr("Version %s") % App.version()
	foot.add_child(version)
	_fade.append(version)
	_version_label = version

	if not intro_from.is_empty():
		_prepare_intro()
		_play_intro.call_deferred()
	_tiles[0].grab_focus.call_deferred()


# Stan początkowy przejścia – ustawiany przed pierwszą klatką, żeby nic nie mignęło.
func _prepare_intro() -> void:
	for t in _tiles:
		t.modulate.a = 0.0
	for c in _fade:
		c.modulate.a = 0.0
	_logo.visible = false
	_company.visible = false


func _play_intro() -> void:
	await get_tree().process_frame   # układ kontenerów jest już policzony
	_fly(_logo, _logo_slot, intro_from.get("logo", Rect2()), MENU_LOGO.y / SPLASH_LOGO.y)
	_fly(_company, _company_slot, intro_from.get("company", Rect2()), MENU_COMPANY.y / SPLASH_COMPANY.y)
	var order := _tiles.duplicate()
	order.shuffle()
	for i in order.size():
		var tile: Control = order[i]
		tile.pivot_offset = tile.size * 0.5
		tile.scale = Vector2.ONE * 0.55
		var delay := lerpf(TILE_DELAY.x, TILE_DELAY.y, float(i) / maxf(order.size() - 1, 1.0))
		var tw := tile.create_tween().set_parallel()
		tw.tween_property(tile, "scale", Vector2.ONE, TILE_TIME).set_delay(delay) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tile, "modulate:a", 1.0, TILE_TIME * 0.6).set_delay(delay)
	for c in _fade:
		c.create_tween().tween_property(c, "modulate:a", 1.0, 0.4).set_delay(0.7)


# Przejazd logo z prostokąta na ekranie startowym do miejsca w menu (pozycja i skala).
func _fly(item: Control, slot: Control, from: Rect2, end_scale: float) -> void:
	item.visible = true
	if from.size == Vector2.ZERO:
		return
	item.z_index = 10   # nad kafelkami w czasie przejazdu
	item.position = from.position - slot.global_position
	item.scale = Vector2.ONE * (from.size.y / item.size.y)
	var tw := item.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(item, "position", Vector2.ZERO, MOVE_TIME)
	tw.tween_property(item, "scale", Vector2.ONE * end_scale, MOVE_TIME)
	tw.chain().tween_callback(func() -> void: item.z_index = 0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _version_label:
		_version_label.text = tr("Version %s") % App.version()
