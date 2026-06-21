# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ══════════════════════════════════════════════════════════════
# WEATHER SYSTEM — Paso 16A + 16B
# Autoload opcional (agrega en Project > AutoLoad como "WeatherSystem")
# Controla partículas de lluvia/nieve + overlay de pantalla.
# Se activa desde los scripts de zona (world_north, world_south, etc.)
# llamando a:  WeatherSystem.set_weather("snow")
#              WeatherSystem.set_weather("rain")
#              WeatherSystem.set_weather("none")
# ══════════════════════════════════════════════════════════════

enum WeatherType { NONE, RAIN, SNOW }

var _current_weather: WeatherType = WeatherType.NONE

# Nodos creados en tiempo de ejecución
var _canvas_layer   : CanvasLayer    = null
var _particles      : CPUParticles2D = null
var _overlay        : ColorRect      = null
var _fade_tween     : Tween          = null

# ─────────────────────────────────────────────────────────────
# INICIALIZACIÓN
# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	# CanvasLayer fijo sobre todo el juego (capa 90 — bajo la UI pero sobre el mundo)
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 90
	add_child(_canvas_layer)

	# PASO 16B — overlay semitransparente de pantalla completa
	_overlay = ColorRect.new()
	_overlay.name = "WeatherOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color   = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_overlay)

	# PASO 16A — partículas de pantalla completa
	_particles = CPUParticles2D.new()
	_particles.name    = "WeatherParticles"
	_particles.emitting = false
	_particles.z_index  = 5
	_canvas_layer.add_child(_particles)

	# Escuchar cambios de zona del GameManager
	if has_node("/root/GameManager"):
		GameManager.player_entered_zone.connect(_on_zone_changed)

# ─────────────────────────────────────────────────────────────
# API PÚBLICA
# ─────────────────────────────────────────────────────────────

func set_weather(type: String) -> void:
	match type:
		"rain":  _transition_to(WeatherType.RAIN)
		"snow":  _transition_to(WeatherType.SNOW)
		_:       _transition_to(WeatherType.NONE)

# ─────────────────────────────────────────────────────────────
# SEÑAL DE ZONA
# ─────────────────────────────────────────────────────────────

func _on_zone_changed(zone_name: String) -> void:
	match zone_name:
		"world_north":
			set_weather("snow")
		"world_south":
			set_weather("rain")
		"world_east", "world_west":
			set_weather("none")
		_:
			# Dungeons, town, etc. — sin clima exterior
			set_weather("none")

# ─────────────────────────────────────────────────────────────
# TRANSICIÓN CON FADE
# ─────────────────────────────────────────────────────────────

func _transition_to(new_type: WeatherType) -> void:
	if new_type == _current_weather:
		return
	_current_weather = new_type

	# Cancelar tween anterior si existía
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	# Fade out overlay actual → aplica nuevo clima → fade in
	_fade_tween.tween_property(_overlay, "color:a", 0.0, 1.0)
	_fade_tween.tween_callback(func():
		_apply_weather(new_type)
	)
	_fade_tween.tween_property(_overlay, "color:a", _target_overlay_alpha(new_type), 1.0)

# ─────────────────────────────────────────────────────────────
# APLICAR CLIMA (configura partículas + overlay)
# ─────────────────────────────────────────────────────────────

func _apply_weather(type: WeatherType) -> void:
	# Obtener tamaño de viewport para cubrir pantalla completa
	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	match type:
		WeatherType.NONE:
			_particles.emitting = false
			_overlay.color = Color(0, 0, 0, 0)

		WeatherType.RAIN:
			# PASO 16A — lluvia: líneas diagonales grises semitransparentes
			_particles.amount               = 280
			_particles.lifetime             = 0.8
			_particles.one_shot             = false
			_particles.emitting             = true
			_particles.emission_shape       = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			_particles.emission_rect_extents = vp_size * 0.6
			_particles.position             = vp_size * 0.5
			_particles.gravity              = Vector2(80.0, 900.0)   # diagonal
			_particles.initial_velocity_min = 250.0
			_particles.initial_velocity_max = 380.0
			_particles.direction            = Vector2(0.22, 1.0)
			_particles.spread               = 5.0
			_particles.scale_amount_min     = 1.5
			_particles.scale_amount_max     = 3.5
			_particles.color                = Color(0.7, 0.75, 0.85, 0.45)

			# PASO 16B — overlay azul muy suave para lluvia
			_overlay.color = Color(0.1, 0.2, 0.4, 0.0)  # alpha se anima en tween

		WeatherType.SNOW:
			# PASO 16A — nieve: puntos blancos con gravedad lenta
			_particles.amount               = 160
			_particles.lifetime             = 4.5
			_particles.one_shot             = false
			_particles.emitting             = true
			_particles.emission_shape       = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			_particles.emission_rect_extents = vp_size * 0.6
			_particles.position             = Vector2(vp_size.x * 0.5, -20.0)
			_particles.gravity              = Vector2(0.0, 30.0)    # cae despacio
			_particles.initial_velocity_min = 10.0
			_particles.initial_velocity_max = 35.0
			_particles.direction            = Vector2(0.0, 1.0)
			_particles.spread               = 35.0
			_particles.scale_amount_min     = 1.0
			_particles.scale_amount_max     = 2.8
			_particles.color                = Color(1.0, 1.0, 1.0, 0.75)

			# PASO 16B — overlay blanco suave para nieve
			_overlay.color = Color(1.0, 1.0, 1.0, 0.0)  # alpha se anima en tween

func _target_overlay_alpha(type: WeatherType) -> float:
	match type:
		WeatherType.RAIN:  return 0.08
		WeatherType.SNOW:  return 0.04
		_:                 return 0.0
