# Fretboard Master – okno główne: wyświetla jeden ekran naraz. Ekran nieaktywny jest usuwany
# z drzewa, więc nie zużywa czasu procesora ani wywołań rysowania.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Control

const SplashScreen := preload("res://scripts/screens/splash_screen.gd")
const MenuScreen := preload("res://scripts/screens/menu_screen.gd")
const ModuleScreen := preload("res://scripts/screens/module_screen.gd")
const SettingsScreen := preload("res://scripts/screens/settings_screen.gd")
const AboutScreen := preload("res://scripts/screens/about_screen.gd")

var _background: ColorRect
var _screen: Control


func _ready() -> void:
	set_process(false)
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	ThemeManager.theme_changed.connect(_update_background)
	App.screen_requested.connect(_show)
	_show(&"splash")


func _update_background() -> void:
	_background.color = Color.BLACK if App.current_screen == &"splash" else ThemeManager.color("bg")


func _show(screen_id: StringName) -> void:
	if _screen:
		_screen.queue_free()
		remove_child(_screen)
	App.current_screen = screen_id
	match screen_id:
		&"splash":
			_screen = SplashScreen.new()
		&"menu":
			_screen = MenuScreen.new()
		&"settings":
			_screen = SettingsScreen.new()
		&"about":
			_screen = AboutScreen.new()
		_:
			_screen = ModuleScreen.new()
			_screen.module_id = screen_id
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	_update_background()
