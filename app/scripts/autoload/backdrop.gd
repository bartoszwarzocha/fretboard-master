# Fretboard Master – tło okna (jednolite, gradient, deseń proceduralny, własny obraz), cząsteczki
# w tle (kurz, iskry, nuty, bokeh) i efekt trafienia dźwięku (burst()).
# Tło to jeden prostokąt z shaderem pod wszystkimi ekranami (warstwa -10) – jedno wywołanie
# rysowania. Cząsteczki i efekty istnieją w drzewie tylko wtedy, gdy są włączone.
# Tło ruchome i cząsteczki wymagają stałego odświeżania obrazu – is_live() mówi o tym modułowi
# Graphics, który wtedy wyłącza tryb oszczędny procesora.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends CanvasLayer

signal live_changed

const MODES := ["solid", "gradient", "pattern", "image"]
const PATTERNS := ["wood", "carbon", "leather", "felt", "notes", "hex", "canvas"]
const PARTICLES := ["off", "dust", "sparks", "notes", "bokeh"]
const HIT_STYLES := ["sparks", "notes", "glow"]
const GRADIENTS := ["linear", "radial", "conic"]
const BG_KEYS := [&"bg_mode", &"bg_color", &"bg_color2", &"bg_color3", &"bg_gradient_type",
		&"bg_gradient_x", &"bg_gradient_y", &"bg_gradient_angle", &"bg_pattern",
		&"bg_intensity", &"bg_scale", &"bg_dim", &"bg_blur", &"bg_image", &"bg_animated", &"bg_anim_speed"]
const PARTICLE_KEYS := [&"particles", &"particles_density", &"particles_speed", &"particles_color"]

var _rect: ColorRect
var _mat: ShaderMaterial
var _image_path := ""
var _particles: GPUParticles2D
var _fx: CanvasLayer
var _fade := 1.0
var _textures := {}
var _music_tile: Texture2D   # deseń „nuty” – glify Bravury, kafel 512 × 512 powtarzany w shaderze
var _music_note: Texture2D   # ósemka ♪ do cząsteczek
var _music_busy := false


func _ready() -> void:
	layer = -10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://assets/shaders/backdrop.gdshader")
	_rect.material = _mat
	add_child(_rect)
	_rect.resized.connect(_on_resized)
	App.settings_changed.connect(_on_setting)
	ThemeManager.theme_changed.connect(_update_background)
	_update_background()
	_update_particles()


## Tło przyciemnione do czerni (0) albo docelowe (1); time > 0 – płynne przejście.
func set_fade(value: float, time := 0.0) -> void:
	if time <= 0.0:
		_fade = value
		_mat.set_shader_parameter(&"fade", value)
		if _particles:
			_particles.modulate.a = value
		return
	var tw := create_tween().set_parallel()
	tw.tween_method(func(v: float) -> void: set_fade(v), _fade, value, time)


func is_live() -> bool:
	return bool(App.setting(&"bg_animated")) or _particles != null


func _on_setting(key: StringName) -> void:
	if key in BG_KEYS:
		_update_background()
		if key == &"bg_animated":
			live_changed.emit()
	elif key in PARTICLE_KEYS or key == &"animations":
		_update_particles()


func _on_resized() -> void:
	_mat.set_shader_parameter(&"size", _rect.size)
	if _particles:
		_fit_particles()


static func _color_or(hex: String, fallback: Color) -> Color:
	return fallback if hex.is_empty() else Color(hex)


# --- Tło ----------------------------------------------------------------------

func _update_background() -> void:
	var mode := maxi(MODES.find(str(App.setting(&"bg_mode"))), 0)
	if mode == 3 and not _load_image():
		mode = 0
	_mat.set_shader_parameter(&"mode", mode)
	_mat.set_shader_parameter(&"pattern", maxi(PATTERNS.find(str(App.setting(&"bg_pattern"))), 0))
	if mode == 2 and str(App.setting(&"bg_pattern")) == "notes":
		if _music_tile:
			_mat.set_shader_parameter(&"notes_tex", _music_tile)
		else:
			_render_music()
	_mat.set_shader_parameter(&"color1", _color_or(str(App.setting(&"bg_color")), ThemeManager.color("bg")))
	_mat.set_shader_parameter(&"color2", _color_or(str(App.setting(&"bg_color2")), ThemeManager.color("pattern")))
	_mat.set_shader_parameter(&"angle", float(App.setting(&"bg_gradient_angle")))
	_mat.set_shader_parameter(&"gradient_type", maxi(GRADIENTS.find(str(App.setting(&"bg_gradient_type"))), 0))
	_mat.set_shader_parameter(&"gradient_center", Vector2(float(App.setting(&"bg_gradient_x")),
			float(App.setting(&"bg_gradient_y"))))
	var c3 := str(App.setting(&"bg_color3"))
	_mat.set_shader_parameter(&"use_color3", not c3.is_empty())
	if not c3.is_empty():
		_mat.set_shader_parameter(&"color3", Color(c3))
	_mat.set_shader_parameter(&"intensity", float(App.setting(&"bg_intensity")))
	_mat.set_shader_parameter(&"pattern_scale", float(App.setting(&"bg_scale")))
	_mat.set_shader_parameter(&"dim", float(App.setting(&"bg_dim")))
	_mat.set_shader_parameter(&"blur", float(App.setting(&"bg_blur")))
	var speed := float(App.setting(&"bg_anim_speed")) if bool(App.setting(&"bg_animated")) else 0.0
	_mat.set_shader_parameter(&"time_speed", speed)
	_mat.set_shader_parameter(&"size", _rect.size)


# Własny obraz: wczytywany raz (z mipmapami do rozmycia); false = brak lub błąd pliku.
func _load_image() -> bool:
	var path := str(App.setting(&"bg_image"))
	if path.is_empty():
		return false
	if path == _image_path:
		return true
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return false
	var limit := 2560
	if img.get_width() > limit or img.get_height() > limit:
		var k := float(limit) / maxi(img.get_width(), img.get_height())
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	_mat.set_shader_parameter(&"image", ImageTexture.create_from_image(img))
	_mat.set_shader_parameter(&"image_size", Vector2(img.get_size()))
	_image_path = path
	return true


# --- Cząsteczki w tle ---------------------------------------------------------

func _update_particles() -> void:
	var kind := str(App.setting(&"particles"))
	var on := kind != "off" and App.animations() != "off"
	if not on:
		if _particles:
			_particles.queue_free()
			_particles = null
			live_changed.emit()
		return
	var was_on := _particles != null
	if _particles:
		_particles.queue_free()
	_particles = GPUParticles2D.new()
	_particles.modulate.a = _fade
	var density := float(App.setting(&"particles_density"))
	var speed := float(App.setting(&"particles_speed"))
	var color := _color_or(str(App.setting(&"particles_color")), ThemeManager.color("accent"))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.gravity = Vector3.ZERO
	pm.color = color
	pm.color_ramp = _fade_ramp()
	pm.direction = Vector3(0, -1, 0)
	var mat := CanvasItemMaterial.new()
	match kind:
		"dust":
			_particles.amount = int(lerpf(20, 160, density))
			_particles.lifetime = 14.0
			_particles.texture = _texture("dot")
			pm.spread = 180.0
			pm.initial_velocity_min = 4.0
			pm.initial_velocity_max = 16.0
			pm.scale_min = 0.12
			pm.scale_max = 0.35
			pm.turbulence_enabled = false
			pm.color = Color(color, 0.45)
		"sparks":
			_particles.amount = int(lerpf(16, 120, density))
			_particles.lifetime = 7.0
			_particles.texture = _texture("dot")
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			pm.spread = 25.0
			pm.initial_velocity_min = 30.0
			pm.initial_velocity_max = 90.0
			pm.scale_min = 0.08
			pm.scale_max = 0.22
			pm.gravity = Vector3(0, -6, 0)
		"notes":
			_particles.amount = int(lerpf(8, 60, density))
			_particles.lifetime = 16.0
			_particles.texture = _music_note if _music_note else _texture("dot")
			if _music_note == null:
				_render_music()
			pm.spread = 20.0
			pm.initial_velocity_min = 12.0
			pm.initial_velocity_max = 30.0
			pm.angle_min = -20.0
			pm.angle_max = 20.0
			pm.angular_velocity_min = -8.0
			pm.angular_velocity_max = 8.0
			pm.scale_min = 0.25
			pm.scale_max = 0.55
			pm.color = Color(color, 0.55)
		_:   # bokeh
			_particles.amount = int(lerpf(6, 40, density))
			_particles.lifetime = 18.0
			_particles.texture = _texture("bokeh")
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			pm.spread = 180.0
			pm.initial_velocity_min = 3.0
			pm.initial_velocity_max = 10.0
			pm.scale_min = 0.6
			pm.scale_max = 2.2
			pm.color = Color(color, 0.22)
	_particles.speed_scale = speed * (0.5 if App.animations() == "reduced" else 1.0)
	_particles.preprocess = _particles.lifetime
	_particles.process_material = pm
	_particles.material = mat
	add_child(_particles)
	_fit_particles()
	if not was_on:
		live_changed.emit()


func _fit_particles() -> void:
	var s := _rect.size
	var pm := _particles.process_material as ParticleProcessMaterial
	_particles.position = s * 0.5
	pm.emission_box_extents = Vector3(s.x * 0.5, s.y * 0.5, 0)
	_particles.visibility_rect = Rect2(-s * 0.6, s * 1.2)


static func _fade_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


# --- Efekt trafienia ----------------------------------------------------------

## Krótki wybuch cząsteczek w punkcie ekranu (np. trafiony dźwięk na gryfie).
func burst(at: Vector2, color := Color.TRANSPARENT) -> void:
	if not bool(App.setting(&"hit_particles")) or App.animations() == "off":
		return
	if color.a == 0.0:
		color = ThemeManager.color("accent")
	if _fx == null:
		_fx = CanvasLayer.new()
		_fx.layer = 100
		add_child(_fx)
	var p := GPUParticles2D.new()
	var style := str(App.setting(&"hit_style"))
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, 260, 0)
	pm.spread = 180.0
	pm.color = color
	pm.color_ramp = _fade_ramp()
	pm.damping_min = 40.0
	pm.damping_max = 80.0
	var mat := CanvasItemMaterial.new()
	match style:
		"notes":
			p.amount = 14
			p.texture = _music_note if _music_note else _texture("dot")
			pm.initial_velocity_min = 90.0
			pm.initial_velocity_max = 200.0
			pm.angle_min = -30.0
			pm.angle_max = 30.0
			pm.scale_min = 0.3
			pm.scale_max = 0.5
			pm.gravity = Vector3(0, -40, 0)
		"glow":
			p.amount = 10
			p.texture = _texture("bokeh")
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			pm.initial_velocity_min = 30.0
			pm.initial_velocity_max = 110.0
			pm.scale_min = 0.4
			pm.scale_max = 1.0
			pm.gravity = Vector3.ZERO
		_:   # sparks
			p.amount = 36
			p.texture = _texture("dot")
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			pm.initial_velocity_min = 160.0
			pm.initial_velocity_max = 380.0
			pm.scale_min = 0.08
			pm.scale_max = 0.2
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.9
	p.speed_scale = 1.4 if App.animations() == "reduced" else 1.0
	p.process_material = pm
	p.material = mat
	p.position = at
	p.finished.connect(p.queue_free)
	_fx.add_child(p)
	p.emitting = true
	if not is_live():
		# Na czas efektu obraz musi się odświeżać mimo trybu oszczędnego.
		OS.low_processor_usage_mode = false
		get_tree().create_timer(1.2).timeout.connect(func() -> void: live_changed.emit())


# --- Tekstury cząsteczek (generowane raz, w pamięci) ---------------------------

func _texture(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	var n := 64
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var a := 0.0
			match kind:
				"dot":
					var d := p.distance_to(c) / (n * 0.5)
					a = clampf(exp(-d * d * 9.0) * 1.2, 0.0, 1.0)
				"bokeh":
					var d := p.distance_to(c) / (n * 0.5)
					a = (1.0 - smoothstep(0.82, 0.95, d)) * (0.45 + 0.55 * smoothstep(0.55, 0.9, d))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[kind] = tex
	return tex


# --- Nuty z czcionki Bravura (SMuFL) -------------------------------------------
# Glify są raz rysowane w SubViewporcie, kopiowane do zwykłych tekstur, a viewport jest usuwany.

const MUSIC_GLYPHS := ["♩", "♪", "♫", "♬", "♩", "♪", "♫", "𝄞", "♯", "♭"]
const MUSIC_TILE := 512
const MUSIC_CELL := 128


func _render_music() -> void:
	if _music_busy or _music_tile:
		return
	_music_busy = true
	var vp := SubViewport.new()
	vp.size = Vector2i(MUSIC_TILE, MUSIC_TILE + 64)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := Control.new()
	canvas.size = Vector2(vp.size)
	canvas.draw.connect(_draw_music.bind(canvas))
	vp.add_child(canvas)
	add_child(vp)
	for i in 2:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	var tile := img.get_region(Rect2i(0, 0, MUSIC_TILE, MUSIC_TILE))
	tile.generate_mipmaps()
	_music_tile = ImageTexture.create_from_image(tile)
	var note := img.get_region(Rect2i(0, MUSIC_TILE, 64, 64))
	note.generate_mipmaps()
	_music_note = ImageTexture.create_from_image(note)
	_music_busy = false
	_update_background()
	if str(App.setting(&"particles")) == "notes":
		_update_particles()


# Kafel deseniu: w każdej komórce 128 × 128 jeden znak nutowy, losowo obrócony i przesunięty
# (stałe ziarno – deseń zawsze taki sam). Pod kafelkiem: ósemka do cząsteczek.
func _draw_music(c: Control) -> void:
	var font := ThemeManager.font_music
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var n := MUSIC_TILE / MUSIC_CELL
	for y in n:
		for x in n:
			var g: String = MUSIC_GLYPHS[rng.randi() % MUSIC_GLYPHS.size()]
			var px := 40 if g == "𝄞" else 64
			var ink := IconGlyph.glyph_ink(font, g, px)
			var center := (Vector2(x, y) + Vector2(0.5, 0.5)) * MUSIC_CELL \
					+ Vector2(rng.randf_range(-18, 18), rng.randf_range(-18, 18))
			c.draw_set_transform(center, rng.randf_range(-0.35, 0.35))
			c.draw_char(font, -ink.get_center(), g, px, Color.WHITE)
	var ink8 := IconGlyph.glyph_ink(font, "♪", 48)
	c.draw_set_transform(Vector2(32, MUSIC_TILE + 32))
	c.draw_char(font, -ink8.get_center(), "♪", 48, Color.WHITE)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
