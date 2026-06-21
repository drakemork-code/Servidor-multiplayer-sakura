# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# HUD CONFIG — Autoload global
# Guarda/carga posición, escala y opacidad de cada elemento del HUD.
# Persistido en: user://hud_config.json
#
# Elementos configurables:
#   "stats"     — Caja HP/Energía/Nivel/Oro (arriba-izquierda)
#   "xp_bar"    — Barra de XP (abajo, ancho completo)
#   "joystick"  — Joystick móvil (abajo-izquierda)
#   "actions"   — Botones de acción móvil (abajo-derecha)
#   "zone_label"— Etiqueta de zona actual (arriba-centro)
# ============================================================

signal config_changed()

const SAVE_PATH := "user://hud_config.json"

# Claves de los elementos HUD
const HUD_KEYS := ["stats", "xp_bar", "joystick", "actions", "zone_label"]

# Estructura por elemento
# offset_x / offset_y: desplazamiento en px desde posición por defecto
# scale: 0.5 – 2.0  (1.0 = tamaño normal)
# alpha: 0.0 – 1.0  (1.0 = totalmente opaco)
var elements: Dictionary = {}

# Ajustes globales
var global_scale : float = 1.0
var global_alpha : float = 1.0
var joy_deadzone : float = 8.0      # px
var joy_sensitivity : float = 1.0   # 0.5 – 2.0

# ── Valores por defecto ─────────────────────────────────────
func _default_element() -> Dictionary:
	return { "offset_x": 0.0, "offset_y": 0.0, "scale": 1.0, "alpha": 1.0 }

func _ready() -> void:
	_reset_elements()
	load_config()
	print("[HudConfig] Listo — ", SAVE_PATH)

func _reset_elements() -> void:
	elements.clear()
	for key in HUD_KEYS:
		elements[key] = _default_element()

# ──────────────────────────────────────────────
# GUARDAR / CARGAR
# ──────────────────────────────────────────────

func save_config() -> void:
	var data := {
		"elements":        elements,
		"global_scale":    global_scale,
		"global_alpha":    global_alpha,
		"joy_deadzone":    joy_deadzone,
		"joy_sensitivity": joy_sensitivity,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("[HudConfig] Guardado OK")
	else:
		push_warning("[HudConfig] No se pudo escribir: " + SAVE_PATH)

func load_config() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var raw := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_warning("[HudConfig] JSON inválido, usando defaults")
		return

	# Cargar elementos individualmente (merge con defaults para campos nuevos)
	if parsed.has("elements") and parsed["elements"] is Dictionary:
		for key in HUD_KEYS:
			if parsed["elements"].has(key) and parsed["elements"][key] is Dictionary:
				var saved_el : Dictionary = parsed["elements"][key]
				var el := _default_element()
				if saved_el.has("offset_x"): el["offset_x"] = float(saved_el["offset_x"])
				if saved_el.has("offset_y"): el["offset_y"] = float(saved_el["offset_y"])
				if saved_el.has("scale"):    el["scale"]    = clampf(float(saved_el["scale"]),    0.3, 2.5)
				if saved_el.has("alpha"):    el["alpha"]    = clampf(float(saved_el["alpha"]),    0.0, 1.0)
				elements[key] = el

	if parsed.has("global_scale"):    global_scale    = clampf(float(parsed["global_scale"]),    0.3, 2.5)
	if parsed.has("global_alpha"):    global_alpha    = clampf(float(parsed["global_alpha"]),    0.0, 1.0)
	if parsed.has("joy_deadzone"):    joy_deadzone    = clampf(float(parsed["joy_deadzone"]),    2.0, 40.0)
	if parsed.has("joy_sensitivity"): joy_sensitivity = clampf(float(parsed["joy_sensitivity"]), 0.3, 3.0)

	print("[HudConfig] Cargado OK")

func reset_to_defaults() -> void:
	_reset_elements()
	global_scale    = 1.0
	global_alpha    = 1.0
	joy_deadzone    = 8.0
	joy_sensitivity = 1.0
	save_config()
	config_changed.emit()
	print("[HudConfig] Reset a defaults")

# ──────────────────────────────────────────────
# ACCESO RÁPIDO
# ──────────────────────────────────────────────

func get_element(key: String) -> Dictionary:
	if elements.has(key):
		return elements[key]
	return _default_element()

func set_element_offset(key: String, ox: float, oy: float) -> void:
	if not elements.has(key):
		elements[key] = _default_element()
	elements[key]["offset_x"] = ox
	elements[key]["offset_y"] = oy

func set_element_scale(key: String, s: float) -> void:
	if not elements.has(key):
		elements[key] = _default_element()
	elements[key]["scale"] = clampf(s, 0.3, 2.5)

func set_element_alpha(key: String, a: float) -> void:
	if not elements.has(key):
		elements[key] = _default_element()
	elements[key]["alpha"] = clampf(a, 0.0, 1.0)

# Posición efectiva final (offset ya aplicado)
func get_effective_scale(key: String) -> float:
	return get_element(key)["scale"] * global_scale

func get_effective_alpha(key: String) -> float:
	return get_element(key)["alpha"] * global_alpha
