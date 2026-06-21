# ==============================================================
# Sakura Chronicles — Loading Screen v3
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# ==============================================================
extends CanvasLayer

# ════════════════════════════════════════════════════════════════
# PALETA
# ════════════════════════════════════════════════════════════════
const C_BG           := Color(0.016, 0.018, 0.055, 1.0)
const C_BG2          := Color(0.028, 0.032, 0.090, 1.0)
const C_GOLD         := Color(1.000, 0.878, 0.353, 1.0)
const C_GOLD_DIM     := Color(0.700, 0.580, 0.200, 1.0)
const C_GOLD_BORDER  := Color(0.600, 0.470, 0.140, 0.8)
const C_SAKURA_A     := Color(0.960, 0.620, 0.740, 1.0)
const C_SAKURA_B     := Color(0.990, 0.800, 0.860, 1.0)
const C_SAKURA_PALE  := Color(0.980, 0.870, 0.910, 1.0)
const C_TEXT         := Color(0.920, 0.910, 0.980, 1.0)
const C_TEXT_DIM     := Color(0.620, 0.600, 0.720, 1.0)
const C_BLUE         := Color(0.200, 0.600, 1.000, 1.0)
const C_TEAL         := Color(0.140, 0.860, 0.780, 1.0)

const FONT_PATH := "res://resources/851Gkktt_005.ttf"
var _ui_font   : FontFile = null

# ════════════════════════════════════════════════════════════════
# TIPS
# ════════════════════════════════════════════════════════════════
const TIPS := {
	"town": [
		"Habla con los NPCs para descubrir misiones ocultas.",
		"El banco guarda tus objetos seguros entre aventuras.",
		"El mercado de subastas cambia de precios cada día.",
		"Sube tu habilidad de minería para acceder a menas más raras.",
		"Completa logros para desbloquear títulos especiales.",
		"Únete a una guild para desbloquear bonificaciones de grupo.",
	],
	"dungeon": [
		"Las mazmorras reinician cada 24 horas — coordina con tu party.",
		"Los cofres dorados solo aparecen una vez por run.",
		"La defensa reduce el daño en un 38% del valor total.",
		"El dodge invencible dura 0.4 s — úsalo en el momento justo.",
		"Los jefes de mazmorra tienen fases — no bajes la guardia.",
	],
	"world": [
		"Las hierbas raras solo crecen en zonas alejadas del mapa.",
		"Explora los bordes del mapa — hay secretos que aguardan.",
		"Los enemigos nocturnos sueltan objetos únicos.",
		"Acércate al borde del mapa para viajar a otras regiones.",
		"Las runas dispersas por el mundo otorgan bonificaciones temporales.",
	],
	"boss": [
		"Los jefes mundiales respawn según el ciclo de días del servidor.",
		"Observa los patrones de ataque — todos los jefes los tienen.",
		"Un jefe es más fácil con party — comparte el XP y el loot.",
		"Los jefes enrabian al llegar al 30% de vida — cuidado.",
		"El loot del jefe es mejor si participas más en el daño total.",
	],
}

const SCENE_NAMES := {
	"res://scenes/town.tscn":                        {"label": "Ciudad de Sakura",   "type": "town"},
	"res://scenes/world_north.tscn":                 {"label": "Tierras del Norte",  "type": "world"},
	"res://scenes/world_south.tscn":                 {"label": "Llanuras del Sur",   "type": "world"},
	"res://scenes/world_east.tscn":                  {"label": "Bosque del Este",    "type": "world"},
	"res://scenes/world_west.tscn":                  {"label": "Desierto del Oeste", "type": "world"},
	"res://scenes/boss_north.tscn":                  {"label": "Jefe del Norte",     "type": "boss"},
	"res://scenes/boss_south.tscn":                  {"label": "Jefe del Sur",       "type": "boss"},
	"res://scenes/boss_east.tscn":                   {"label": "Jefe del Este",      "type": "boss"},
	"res://scenes/boss_west.tscn":                   {"label": "Jefe del Oeste",     "type": "boss"},
	"res://scenes/dungeons/stone_dungeon.tscn":      {"label": "Mazmorra de Piedra", "type": "dungeon"},
}

# ════════════════════════════════════════════════════════════════
# ESTADO
# ════════════════════════════════════════════════════════════════
var _active        : bool    = false
var _target_scene  : String  = ""
var _spawn_pos     : Vector2 = Vector2.ZERO
var _use_spawn     : bool    = false
var _progress      : float   = 0.0
var _phase         : int     = 0       # 0=fade-in 1=loading 2=fade-out
var _elapsed       : float   = 0.0
var _min_show_time : float   = 1.8

# ── UI refs ───────────────────────────────────────────────────
var _root          : Control   = null
var _title_lbl     : Label     = null
var _logo_rect     : TextureRect = null
var _dest_lbl      : Label     = null
var _bar_fill      : ColorRect = null
var _bar_bg        : ColorRect = null
var _pct_lbl       : Label     = null
var _tip_lbl       : Label     = null
var _tip_icon      : Label     = null
var _overlay       : ColorRect = null   # fade negro

# ── Pétalos (dibujados con draw_colored_polygon) ──────────────
var _petal_node    : _PetalDrawer = null
var _petals        : Array = []
const PETAL_COUNT  : int = 45

# ── Animación ─────────────────────────────────────────────────
var _title_float   : float = 0.0   # oscilación vertical del título
var _glow_phase    : float = 0.0   # pulso del glow dorado
var _tip_alpha     : float = 0.0
var _tip_fade_in   : bool  = true
var _tip_timer     : float = 0.0
var _tip_list      : Array = []
var _tip_index     : int   = 0
var _bar_pulse     : float = 0.0

# ════════════════════════════════════════════════════════════════
func _ready() -> void:
	layer   = 1000
	visible = false
	_ui_font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	_build_ui()

# ════════════════════════════════════════════════════════════════
# API PÚBLICA
# ════════════════════════════════════════════════════════════════
func go_to(scene_path: String, spawn: Vector2 = Vector2.ZERO, use_spawn: bool = false) -> void:
	if _active:
		return
	_target_scene = scene_path
	_spawn_pos    = spawn
	_use_spawn    = use_spawn
	_start_loading()

func go_to_with_spawn(scene_path: String, spawn: Vector2) -> void:
	go_to(scene_path, spawn, true)

# ════════════════════════════════════════════════════════════════
# INICIO
# ════════════════════════════════════════════════════════════════
func _start_loading() -> void:
	_active   = true
	_progress = 0.0
	_phase    = 0
	_elapsed  = 0.0
	_title_float = 0.0
	_glow_phase  = 0.0
	_bar_pulse   = 0.0

	PlayerData.flush_pending_save()
	PlayerData.flush_pending_server_save()

	# Tips
	var info      : Dictionary = SCENE_NAMES.get(_target_scene, {"label": "...", "type": "world"})
	var tip_type  : String     = info.get("type", "world")
	_tip_list  = TIPS.get(tip_type, TIPS["world"]).duplicate()
	_tip_list.shuffle()
	_tip_index = 0
	_tip_lbl.text   = _tip_list[0]
	_tip_alpha      = 0.0
	_tip_fade_in    = true
	_tip_timer      = 0.0

	# Nombre de zona
	_dest_lbl.text = "✦  %s  ✦" % info.get("label", "Mundo")
	_dest_lbl.modulate.a = 0.0
	if _logo_rect: _logo_rect.modulate.a = 0.0
	_bar_fill.size.x = 0.0
	_pct_lbl.text = "0%"

	# Iniciar carga en hilo
	var err := ResourceLoader.load_threaded_request(_target_scene)
	if err != OK:
		push_error("[LoadingScreen] Error al iniciar carga: %s" % _target_scene)
		_finish_and_change()
		return

	# Mostrar pantalla
	_root.modulate.a = 0.0
	_root.visible    = true
	visible          = true
	_init_petals()

	# Fade in pantalla + título + zona
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.40)
	if _logo_rect: tw.tween_property(_logo_rect, "modulate:a", 1.0, 0.80).set_delay(0.20)
	tw.tween_property(_dest_lbl, "modulate:a", 1.0, 0.60).set_delay(0.40)
	tw.tween_callback(func(): _phase = 1).set_delay(0.45)

# ════════════════════════════════════════════════════════════════
# PROCESO
# ════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if not _active:
		return

	_elapsed      += delta
	_title_float  += delta * 1.4
	_glow_phase   += delta * 2.5
	_bar_pulse    += delta * 3.0
	_tip_timer    += delta

	# Oscilación sutil del logo
	if _logo_rect: _logo_rect.position.y = -4.0 + sin(_title_float) * 3.5

	# Pulso glow barra
	var glow_a := 0.12 + 0.08 * sin(_bar_pulse)
	if _bar_fill.size.x > 2.0:
		_bar_fill.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Pétalos
	if _petal_node:
		_update_petals(delta)
		_petal_node.queue_redraw()

	# Rotación de tips
	if _tip_timer > 3.8:
		_tip_fade_in = not _tip_fade_in
		if _tip_fade_in:
			_tip_index   = (_tip_index + 1) % _tip_list.size()
			_tip_lbl.text = _tip_list[_tip_index]
			_tip_timer   = 0.0

	_tip_alpha = move_toward(_tip_alpha, 1.0 if _tip_fade_in else 0.0, delta * 2.0)
	_tip_lbl.modulate.a  = _tip_alpha
	_tip_icon.modulate.a = _tip_alpha

	if _phase != 1:
		return

	# Progreso de carga
	var progress_arr : Array = []
	var status := ResourceLoader.load_threaded_get_status(_target_scene, progress_arr)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress_arr.size() > 0:
				_progress = move_toward(_progress, progress_arr[0], delta * 0.7)
		ResourceLoader.THREAD_LOAD_LOADED:
			_progress = move_toward(_progress, 1.0, delta * 1.5)
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("[LoadingScreen] Carga fallida: %s" % _target_scene)
			_finish_and_change()
			return

	var min_p := clampf(_elapsed / _min_show_time, 0.0, 0.90)
	_progress = maxf(_progress, min_p)
	_update_bar(_progress)

	if status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed >= _min_show_time:
		_progress = 1.0
		_update_bar(1.0)
		_phase = 2
		await get_tree().create_timer(0.22).timeout
		_fade_out_and_switch()

func _update_bar(p: float) -> void:
	var max_w := _bar_bg.size.x - 4.0
	_bar_fill.size.x = clampf(p * max_w, 0.0, max_w)
	_pct_lbl.text    = "%d%%" % int(p * 100.0)
	# Degradado: azul → teal → dorado
	var col: Color
	if p < 0.5:
		col = C_BLUE.lerp(C_TEAL, p * 2.0)
	else:
		col = C_TEAL.lerp(C_GOLD, (p - 0.5) * 2.0)
	_bar_fill.color = col

# ════════════════════════════════════════════════════════════════
# FINALIZAR
# ════════════════════════════════════════════════════════════════
func _fade_out_and_switch() -> void:
	_finish_and_change()

func _finish_and_change() -> void:
	_active = false

	if _use_spawn:
		GameManager.player_spawn_position = _spawn_pos
		GameManager.player_spawn_override  = true
	GameManager.previous_scene = GameManager.current_scene
	GameManager.current_scene  = _target_scene
	GameManager.scene_changed.emit(_target_scene)

	# Limpiar nodos remotos antes de cambiar escena para evitar crash
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("_clear_remote_nodes"):
		nm._clear_remote_nodes()

	# La pantalla sigue encima (layer=1000) — cambiar escena sin flash
	var packed := ResourceLoader.load_threaded_get(_target_scene)
	if packed == null:
		get_tree().change_scene_to_file(_target_scene)
	else:
		get_tree().change_scene_to_packed(packed)

	# Esperar que la nueva escena renderice completamente
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Fade out suave
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.38)
	tw.tween_callback(func():
		visible         = false
		_root.visible   = false
		_root.modulate.a = 1.0
	)

# ════════════════════════════════════════════════════════════════
# BUILD UI
# ════════════════════════════════════════════════════════════════
func _set_font(lbl: Label) -> void:
	if _ui_font:
		lbl.add_theme_font_override("font", _ui_font)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible      = false
	add_child(_root)

	# ── Fondo ─────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color        = C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# Gradiente superior (más claro)
	var bg2 := ColorRect.new()
	bg2.layout_mode    = 0
	bg2.anchor_right   = 1.0
	bg2.anchor_bottom  = 0.5
	bg2.color          = C_BG2
	bg2.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg2)

	# ── Nodo de pétalos (Node2D con _draw) ────────────────────
	_petal_node = _PetalDrawer.new()
	_petal_node.screen_ref = self
	_root.add_child(_petal_node)
	_petal_node.set_anchors_preset(Control.PRESET_FULL_RECT)

	# ── Marco dorado ──────────────────────────────────────────
	_build_frame()

	# ── Grupo central ─────────────────────────────────────────
	# Título — mismo logo PNG que el menú de login
	var logo_tex : Texture2D = null
	if ResourceLoader.exists("res://assets/ui/sakura_title_logo.png"):
		logo_tex = load("res://assets/ui/sakura_title_logo.png") as Texture2D
	var logo_rect := TextureRect.new()
	logo_rect.texture      = logo_tex
	logo_rect.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.layout_mode  = 0
	logo_rect.anchor_left   = 0.5; logo_rect.anchor_right  = 0.5
	logo_rect.anchor_top    = 0.0; logo_rect.anchor_bottom = 0.0
	logo_rect.offset_left   = -300; logo_rect.offset_right  = 300
	logo_rect.offset_top    = 8;    logo_rect.offset_bottom = 108
	logo_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_root.add_child(logo_rect)
	# _title_lbl apunta al TextureRect para poder animarlo (fade/posición)
	_title_lbl = Label.new()  # label vacío — solo para mantener las referencias de animación
	_title_lbl.visible = false
	_root.add_child(_title_lbl)
	_logo_rect = logo_rect

	# Nombre de zona
	_dest_lbl = Label.new()
	_dest_lbl.text = "✦  Cargando...  ✦"
	_dest_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dest_lbl.add_theme_font_size_override("font_size", 22)
	_dest_lbl.add_theme_color_override("font_color", C_TEXT)
	_dest_lbl.layout_mode    = 0
	_dest_lbl.anchor_left    = 0.5; _dest_lbl.anchor_right  = 0.5
	_dest_lbl.anchor_top     = 0.0; _dest_lbl.anchor_bottom = 0.0
	_dest_lbl.offset_left    = -240; _dest_lbl.offset_right  = 240
	_dest_lbl.offset_top     = 70;   _dest_lbl.offset_bottom = 96
	_dest_lbl.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_set_font(_dest_lbl)
	_root.add_child(_dest_lbl)

	# Línea decorativa bajo el título
	var deco := ColorRect.new()
	deco.layout_mode   = 0
	deco.anchor_left   = 0.5; deco.anchor_right  = 0.5
	deco.anchor_top    = 0.0; deco.anchor_bottom = 0.0
	deco.offset_left   = -180; deco.offset_right  = 180
	deco.offset_top    = 98;   deco.offset_bottom = 100
	deco.color         = C_GOLD_BORDER
	deco.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_root.add_child(deco)

	# ── Barra de progreso ─────────────────────────────────────
	var bar_w  := 500.0
	var bar_h  := 14.0

	_bar_bg = ColorRect.new()
	_bar_bg.layout_mode    = 0
	_bar_bg.anchor_left    = 0.5; _bar_bg.anchor_right  = 0.5
	_bar_bg.anchor_top     = 1.0; _bar_bg.anchor_bottom = 1.0
	_bar_bg.offset_left    = -(bar_w / 2.0)
	_bar_bg.offset_right   =  (bar_w / 2.0)
	_bar_bg.offset_top     = -82.0
	_bar_bg.offset_bottom  = -82.0 + bar_h
	_bar_bg.color          = Color(0.04, 0.05, 0.14, 1.0)
	_bar_bg.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_bg)

	# Borde de la barra
	for bd in [[-1,-1,bar_w+2,bar_h+2],[0,0,bar_w,bar_h]]:
		var br := ColorRect.new()
		br.layout_mode  = 0
		br.position     = Vector2(bd[0], bd[1])
		br.size         = Vector2(bd[2], bd[3])
		br.color        = C_GOLD_BORDER if bd[0] == -1 else Color(0.04, 0.05, 0.14, 1.0)
		br.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar_bg.add_child(br)

	_bar_fill = ColorRect.new()
	_bar_fill.layout_mode  = 0
	_bar_fill.position     = Vector2(2.0, 2.0)
	_bar_fill.size         = Vector2(0.0, bar_h - 4.0)
	_bar_fill.color        = C_BLUE
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bg.add_child(_bar_fill)

	# Porcentaje
	_pct_lbl = Label.new()
	_pct_lbl.text = "0%"
	_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct_lbl.add_theme_font_size_override("font_size", 12)
	_pct_lbl.add_theme_color_override("font_color", C_TEXT)
	_pct_lbl.layout_mode    = 0
	_pct_lbl.anchor_left    = 0.5; _pct_lbl.anchor_right  = 0.5
	_pct_lbl.anchor_top     = 1.0; _pct_lbl.anchor_bottom = 1.0
	_pct_lbl.offset_left    = -30; _pct_lbl.offset_right  = 30
	_pct_lbl.offset_top     = -100; _pct_lbl.offset_bottom = -84
	_pct_lbl.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pct_lbl)

	# ── Tips ──────────────────────────────────────────────────
	_tip_icon = Label.new()
	_tip_icon.text = "✦"
	_tip_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_icon.add_theme_font_size_override("font_size", 13)
	_tip_icon.add_theme_color_override("font_color", C_GOLD_DIM)
	_tip_icon.layout_mode    = 0
	_tip_icon.anchor_left    = 0.5; _tip_icon.anchor_right  = 0.5
	_tip_icon.anchor_top     = 1.0; _tip_icon.anchor_bottom = 1.0
	_tip_icon.offset_left    = -260; _tip_icon.offset_right  = 260
	_tip_icon.offset_top     = -58;  _tip_icon.offset_bottom = -42
	_tip_icon.modulate.a     = 0.0
	_tip_icon.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tip_icon)

	_tip_lbl = Label.new()
	_tip_lbl.text = ""
	_tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_lbl.add_theme_font_size_override("font_size", 14)
	_tip_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	_tip_lbl.layout_mode    = 0
	_tip_lbl.anchor_left    = 0.5; _tip_lbl.anchor_right  = 0.5
	_tip_lbl.anchor_top     = 1.0; _tip_lbl.anchor_bottom = 1.0
	_tip_lbl.offset_left    = -260; _tip_lbl.offset_right  = 260
	_tip_lbl.offset_top     = -42;  _tip_lbl.offset_bottom = -12
	_tip_lbl.modulate.a     = 0.0
	_tip_lbl.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tip_lbl)

func _build_frame() -> void:
	# Barras de borde dorado
	for bd in [
		[0.0,0.0,1.0,0.0,  0.0, 2.5, true ],  # top
		[0.0,1.0,1.0,1.0, -2.5, 0.0, true ],  # bottom
		[0.0,0.0,0.0,1.0,  0.0, 2.5, false],  # left
		[1.0,0.0,1.0,1.0, -2.5, 0.0, false],  # right
	]:
		var r := ColorRect.new()
		r.layout_mode    = 0
		r.anchor_left    = bd[0]; r.anchor_top    = bd[1]
		r.anchor_right   = bd[2]; r.anchor_bottom = bd[3]
		if bd[6]: r.offset_top  = bd[4]; r.offset_bottom = bd[5]
		else:      r.offset_left = bd[4]; r.offset_right  = bd[5]
		r.color        = C_GOLD_BORDER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(r)
	# Esquinas
	for corner in [[0.0,0.0],[1.0,0.0],[0.0,1.0],[1.0,1.0]]:
		var lbl := Label.new()
		lbl.text = "✦"
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", C_GOLD)
		lbl.layout_mode    = 0
		lbl.anchor_left    = corner[0]; lbl.anchor_top    = corner[1]
		lbl.anchor_right   = corner[0]; lbl.anchor_bottom = corner[1]
		var ox := -9.0 if corner[0] == 1.0 else -2.0
		var oy := -20.0 if corner[1] == 1.0 else 0.0
		lbl.offset_left    = ox;     lbl.offset_right  = ox + 20.0
		lbl.offset_top     = oy;     lbl.offset_bottom = oy + 22.0
		lbl.mouse_filter   = Control.MOUSE_FILTER_IGNORE
		_root.add_child(lbl)

# ════════════════════════════════════════════════════════════════
# PÉTALOS — dibujados con draw_colored_polygon (sin ColorRect)
# ════════════════════════════════════════════════════════════════
func _init_petals() -> void:
	_petals.clear()
	var vp := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
	for i in PETAL_COUNT:
		_petals.append(_new_petal(vp, true))

func _new_petal(vp: Vector2, rand_y: bool) -> Dictionary:
	var col := C_SAKURA_A.lerp(C_SAKURA_B, randf())
	col.a   *= randf_range(0.35, 0.90)
	return {
		"x":     randf_range(0.0, vp.x),
		"y":     randf_range(-50.0, vp.y) if rand_y else randf_range(-150.0, -5.0),
		"size":  randf_range(4.0, 16.0),
		"speed": randf_range(40.0, 120.0),
		"drift": randf_range(-25.0, 25.0),
		"angle": randf_range(0.0, TAU),
		"spin":  randf_range(-2.2, 2.2),
		"wob":   randf_range(0.5, 2.5),
		"wob_p": randf_range(0.0, TAU),
		"color": col,
		"t":     0.0,
	}

func _update_petals(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
	for p in _petals:
		var wx := sin(_elapsed * float(p["wob"]) + float(p["wob_p"])) * 20.0
		p["x"]     = float(p["x"]) + (float(p["drift"]) + wx) * delta
		p["y"]     = float(p["y"]) + float(p["speed"]) * delta
		p["angle"] = float(p["angle"]) + float(p["spin"]) * delta
		p["t"]     = clampf(float(p["y"]) / vp.y, 0.0, 1.0)
		if float(p["y"]) > vp.y + 40.0:
			var np := _new_petal(vp, false)
			np["x"] = randf_range(0.0, vp.x)
			_petals[_petals.find(p)] = np

# ════════════════════════════════════════════════════════════════
# Nodo interno que dibuja los pétalos via _draw
# ════════════════════════════════════════════════════════════════
class _PetalDrawer extends Control:
	var screen_ref : Node = null

	func _draw() -> void:
		if not screen_ref:
			return
		for p in screen_ref._petals:
			var pos   := Vector2(float(p["x"]), float(p["y"]))
			var sz    := float(p["size"])
			var angle := float(p["angle"])
			var col   := p["color"] as Color
			var fade  := 1.0 - float(p["t"]) * 0.6
			var final_col := Color(col.r, col.g, col.b, col.a * fade)
			_draw_petal(pos, sz, angle, final_col)

	func _draw_petal(pos: Vector2, size: float, angle: float, color: Color) -> void:
		# Forma de pétalo elíptico suave (22 vértices)
		var pts := PackedVector2Array()
		for i in 22:
			var t  := TAU * i / 22.0
			var ex := cos(t) * size * 0.38
			var ey := sin(t) * size
			pts.append(pos + Vector2(ex, ey).rotated(angle))
		draw_colored_polygon(pts, color)
		# Centro brillante
		draw_circle(pos, size * 0.20,
			Color(minf(color.r + 0.18, 1.0),
				  minf(color.g + 0.15, 1.0),
				  minf(color.b + 0.12, 1.0),
				  color.a * 0.50))
