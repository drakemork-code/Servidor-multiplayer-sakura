# ╔══════════════════════════════════════════════════════════════╗
# ║              SAKURA CHRONICLES — SPLASH SCREEN               ║
# ╚══════════════════════════════════════════════════════════════╝
extends Node2D

# ════════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ════════════════════════════════════════════════════════════════
const SPLASH_DURATION   : float  = 3.0
const TITLE_FADE_IN     : float  = 1.2
const FADE_OUT_DURATION : float  = 0.8
const NEXT_SCENE        : String = "res://scenes/main_menu.tscn"
const BG_COLOR          : Color  = Color(0.024, 0.020, 0.086)
const TITLE_COLOR       : Color  = Color(1.0, 0.855, 0.435)
const SUBTITLE_COLOR    : Color  = Color(0.745, 0.525, 0.635)
const LINE_COLOR        : Color  = Color(0.780, 0.510, 0.235)
const PETAL_COUNT       : int    = 80
const PETAL_SPEED_MIN   : float  = 50.0
const PETAL_SPEED_MAX   : float  = 140.0
const PETAL_SIZE_MIN    : float  = 4.0
const PETAL_SIZE_MAX    : float  = 20.0
const PETAL_COLOR_A     : Color  = Color(0.96, 0.62, 0.74, 0.90)
const PETAL_COLOR_B     : Color  = Color(1.00, 0.82, 0.88, 0.60)

# ════════════════════════════════════════════════════════════════
# INTERNAS
# ════════════════════════════════════════════════════════════════
var _petals         : Array[Dictionary] = []
var _time           : float  = 0.0
var _fading_out     : bool   = false
var _vp             : Vector2
var _overlay        : ColorRect
var _title_label    : Label
var _subtitle_label : Label
var _version_label  : Label
var _deco_line      : Line2D

# Capas de renderizado: fondo/glow BAJO el texto, pétalos ENCIMA
var _layer_bg       : Node2D   # fondo + glow
var _layer_ui       : CanvasLayer  # texto (siempre encima del fondo)
var _layer_petals   : CanvasLayer  # pétalos encima de TODO
var _layer_overlay  : CanvasLayer  # fade negro, lo más encima

func _ready() -> void:
	# En modo servidor headless, saltar splash inmediatamente
	if "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args():
		queue_free()
		return
	await get_tree().process_frame
	_vp = get_viewport().get_visible_rect().size
	_build_scene()
	_spawn_initial_petals()
	_animate_title()

func _build_scene() -> void:
	var cx := _vp.x * 0.5
	var cy := _vp.y * 0.5

	# ── Capa 0: fondo ────────────────────────────────────────────
	_layer_bg = Node2D.new()
	add_child(_layer_bg)

	var bg := ColorRect.new()
	bg.color    = BG_COLOR
	bg.position = Vector2.ZERO
	bg.size     = _vp
	_layer_bg.add_child(bg)

	# Glow central
	var glow := _GlowNode.new()
	glow.position = Vector2(cx, cy)
	glow.vp_size  = _vp
	_layer_bg.add_child(glow)

	# ── Capa 1: UI / texto ───────────────────────────────────────
	_layer_ui = CanvasLayer.new()
	_layer_ui.layer = 1
	add_child(_layer_ui)
	# Control raíz que ocupa todo el viewport — los labels se centran dentro
	var _ui_root := Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer_ui.add_child(_ui_root)

	# Línea decorativa
	_deco_line = Line2D.new()
	_deco_line.points        = [Vector2(-_vp.x * 0.22, 0.0), Vector2(_vp.x * 0.22, 0.0)]
	_deco_line.width         = 1.5
	_deco_line.default_color = LINE_COLOR
	_deco_line.modulate.a    = 0.0
	_deco_line.position      = Vector2(cx, cy + _vp.y * 0.018)
	_layer_ui.add_child(_deco_line)

	# Título — centrado exacto
	var title_size: int = clamp(int(_vp.y * 0.095), 36, 90)
	_title_label = _make_label("Sakura Chronicles", title_size, TITLE_COLOR)
	_title_label.position = Vector2(0, cy - title_size * 1.1)
	_title_label.modulate.a = 0.0
	_layer_ui.add_child(_title_label)

	# Subtítulo
	var sub_size: int = clamp(int(_vp.y * 0.028), 14, 26)
	_subtitle_label = _make_label("MMORPG  ·  PIXEL ART  ·  ADVENTURE", sub_size, SUBTITLE_COLOR)
	_subtitle_label.position = Vector2(0, cy + _vp.y * 0.038)
	_subtitle_label.modulate.a = 0.0
	_layer_ui.add_child(_subtitle_label)

	# Versión
	var ver_size: int = clamp(int(_vp.y * 0.016), 11, 18)
	_version_label = _make_label("v2.6.0", ver_size, Color(0.37, 0.29, 0.34))
	_version_label.position.y = _vp.y * 0.93
	_version_label.modulate.a = 0.0
	_layer_ui.add_child(_version_label)

	# ── Capa 2: pétalos — ENCIMA del texto ───────────────────────
	_layer_petals = CanvasLayer.new()
	_layer_petals.layer = 2
	add_child(_layer_petals)
	# El dibujo de pétalos se hace en _draw() de este Node2D
	# pero necesita estar en la capa de pétalos, así que usamos
	# un nodo hijo dedicado
	var petal_drawer := _PetalCanvas.new()
	petal_drawer.splash = self
	_layer_petals.add_child(petal_drawer)
	_petal_canvas = petal_drawer

	# ── Capa 3: overlay negro (fade) ─────────────────────────────
	_layer_overlay = CanvasLayer.new()
	_layer_overlay.layer = 10
	add_child(_layer_overlay)

	_overlay = ColorRect.new()
	_overlay.color        = Color(0, 0, 0, 1)
	_overlay.position     = Vector2.ZERO
	_overlay.size         = _vp
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer_overlay.add_child(_overlay)

var _petal_canvas : Node2D

func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Ancho completo del viewport, centrado horizontal automático
	lbl.size = Vector2(_vp.x, size + 8)
	lbl.position = Vector2(-_vp.x * 0.5, 0)
	return lbl

# ── Animación ─────────────────────────────────────────────────────────────
func _animate_title() -> void:
	create_tween().tween_property(_overlay, "modulate:a", 0.0, 0.6)

	await get_tree().create_timer(0.3).timeout
	_title_label.position.y += 22
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title_label, "modulate:a",  1.0, TITLE_FADE_IN)
	tw.tween_property(_title_label, "position:y",
		_title_label.position.y - 22, TITLE_FADE_IN).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.5).timeout
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(_subtitle_label, "modulate:a", 1.0, 0.8)
	tw2.tween_property(_version_label,  "modulate:a", 1.0, 1.0)
	tw2.tween_property(_deco_line,      "modulate:a", 0.65, 0.9)

# ── Pétalos ───────────────────────────────────────────────────────────────
func _spawn_initial_petals() -> void:
	for i in PETAL_COUNT:
		_petals.append(_new_petal(true))

func _new_petal(random_y: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var col := PETAL_COLOR_A.lerp(PETAL_COLOR_B, rng.randf())
	col.a   *= rng.randf_range(0.5, 1.0)
	return {
		"x":            rng.randf_range(-20.0, _vp.x + 20.0),
		"y":            rng.randf_range(-_vp.y * 0.1, _vp.y) if random_y else rng.randf_range(-_vp.y * 0.15, -5.0),
		"size":         rng.randf_range(PETAL_SIZE_MIN, PETAL_SIZE_MAX),
		"speed":        rng.randf_range(PETAL_SPEED_MIN, PETAL_SPEED_MAX),
		"drift":        rng.randf_range(-30.0, 30.0),
		"angle":        rng.randf_range(0.0, TAU),
		"spin":         rng.randf_range(-2.0, 2.0),
		"wobble":       rng.randf_range(0.5, 2.5),
		"wobble_phase": rng.randf_range(0.0, TAU),
		"color":        col,
	}

func _process(delta: float) -> void:
	_time += delta
	for p in _petals:
		var wobble_x := sin(_time * float(p["wobble"]) + float(p["wobble_phase"])) * 25.0
		p["x"]     = float(p["x"]) + (float(p["drift"]) + wobble_x) * delta
		p["y"]     = float(p["y"]) + float(p["speed"]) * delta
		p["angle"] = float(p["angle"]) + float(p["spin"]) * delta
		if float(p["y"]) > _vp.y + 60.0:
			p["x"]     = randf_range(-20.0, _vp.x + 20.0)
			p["y"]     = randf_range(-_vp.y * 0.15, -5.0)
			p["angle"] = randf_range(0.0, TAU)

	if _petal_canvas:
		_petal_canvas.queue_redraw()

	if not _fading_out and _time >= SPLASH_DURATION - FADE_OUT_DURATION:
		_fading_out = true
		var tw := create_tween()
		tw.tween_property(_overlay, "modulate:a", 1.0, FADE_OUT_DURATION)
		tw.tween_callback(_go_to_next_scene)

func _go_to_next_scene() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)

func _input(event: InputEvent) -> void:
	if not _fading_out and (event is InputEventKey or
		event is InputEventMouseButton or event is InputEventScreenTouch):
		_fading_out = true
		var tw := create_tween()
		tw.tween_property(_overlay, "modulate:a", 1.0, 0.35)
		tw.tween_callback(_go_to_next_scene)

# ════════════════════════════════════════════════════════════════
# Nodo que dibuja los pétalos (en su propia CanvasLayer encima del texto)
# ════════════════════════════════════════════════════════════════
class _PetalCanvas extends Node2D:
	var splash : Node2D

	func _draw() -> void:
		if not splash:
			return
		for p in splash._petals:
			var pos   := Vector2(float(p["x"]), float(p["y"]))
			var size  := float(p["size"])
			var angle := float(p["angle"])
			var color := p["color"] as Color
			_draw_petal(pos, size, angle, color)

	func _draw_petal(pos: Vector2, size: float, angle: float, color: Color) -> void:
		var pts := PackedVector2Array()
		for i in 22:
			var t  := TAU * i / 22.0
			var ex := cos(t) * size * 0.36
			var ey := sin(t) * size
			pts.append(pos + Vector2(ex, ey).rotated(angle))
		draw_colored_polygon(pts, color)
		draw_circle(pos, size * 0.18,
			Color(minf(color.r + 0.15, 1.0),
				  minf(color.g + 0.12, 1.0),
				  minf(color.b + 0.10, 1.0),
				  color.a * 0.55))

# ════════════════════════════════════════════════════════════════
# Nodo que dibuja el resplandor rosado central
# ════════════════════════════════════════════════════════════════
class _GlowNode extends Node2D:
	var vp_size : Vector2 = Vector2(1920, 1080)
	func _draw() -> void:
		for i in 22:
			var t   := 1.0 - float(i) / 22.0
			var rad := vp_size.y * 0.52 * (1.0 - t)
			var a   := 16.0 * pow(t, 3.0) / 255.0
			draw_circle(Vector2.ZERO, rad, Color(0.95, 0.47, 0.65, a))
