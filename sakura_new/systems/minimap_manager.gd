# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# MINIMAP MANAGER — Autoload global
# Mapa circular en el HUD con posición del jugador,
# entradas/salidas, NPCs importantes y compañeros de grupo.
# ============================================================

signal minimap_ready()
signal zone_data_updated(zone: String, bounds: Rect2)

# ── Definición de zonas ──────────────────────────────────────
# Bounds en coordenadas de juego para cada zona
const ZONE_BOUNDS: Dictionary = {
	"world_north":  Rect2(-3000, -2000,  6000, 4000),
	"world_south":  Rect2(-3000, -2000,  6000, 4000),
	"world_east":   Rect2(-3000, -2000,  6000, 4000),
	"world_west":   Rect2(-3000, -2000,  6000, 4000),
	"lobby":        Rect2( -960,  -540,  1920, 1080),
	"dungeon":      Rect2( -640,  -480,  1280,  960),
}

# ── Puntos de interés fijos por zona ─────────────────────────
# Lista de {label, pos, color}
const ZONE_POIS: Dictionary = {
	"world_north": [
		{"label":"Portal Sur", "pos":Vector2(0, 1900),   "color":Color(0.3,1.0,0.3)},
		{"label":"Boss Norte", "pos":Vector2(0, -1900),  "color":Color(1.0,0.2,0.2)},
	],
	"world_south": [
		{"label":"Portal Norte","pos":Vector2(0, 1900),  "color":Color(0.3,1.0,0.3)},
		{"label":"Boss Sur",    "pos":Vector2(0,-1900),  "color":Color(1.0,0.2,0.2)},
	],
	"world_east": [
		{"label":"Portal",      "pos":Vector2(-1900, 0), "color":Color(0.3,1.0,0.3)},
		{"label":"Boss Este",   "pos":Vector2( 1900, 0), "color":Color(1.0,0.2,0.2)},
	],
	"world_west": [
		{"label":"Portal",      "pos":Vector2( 1900, 0), "color":Color(0.3,1.0,0.3)},
		{"label":"Boss Oeste",  "pos":Vector2(-1900, 0), "color":Color(1.0,0.2,0.2)},
	],
	"lobby": [
		{"label":"Forja",       "pos":Vector2( 592, 275), "color":Color(1.0,0.6,0.1)},
		{"label":"Banco",       "pos":Vector2(-440,-170), "color":Color(0.9,0.8,0.2)},
		{"label":"Mercado",     "pos":Vector2( 388, -37), "color":Color(0.3,0.9,0.5)},
		{"label":"Subasta",     "pos":Vector2( -60, -80), "color":Color(0.7,0.4,1.0)},
		{"label":"Mazmorra",    "pos":Vector2( 120,-285), "color":Color(1.0,0.2,0.2)},
		{"label":"Zona Norte",  "pos":Vector2(   0,-540), "color":Color(0.5,0.8,1.0)},
		{"label":"Zona Sur",    "pos":Vector2(   0, 540), "color":Color(0.5,0.8,1.0)},
		{"label":"Zona Este",   "pos":Vector2( 960,   0), "color":Color(0.5,0.8,1.0)},
		{"label":"Zona Oeste",  "pos":Vector2(-960,   0), "color":Color(0.5,0.8,1.0)},
	],
}

var current_zone: String = ""
var _current_bounds: Rect2 = Rect2(-1000, -1000, 2000, 2000)

func _ready() -> void:
	print("[MinimapManager] Inicializado")

func set_zone(zone: String) -> void:
	current_zone = zone
	if ZONE_BOUNDS.has(zone):
		_current_bounds = ZONE_BOUNDS[zone]
	zone_data_updated.emit(zone, _current_bounds)

func get_bounds() -> Rect2:
	return _current_bounds

func get_pois() -> Array:
	return ZONE_POIS.get(current_zone, [])

## Convierte coordenada del mundo a coordenada normalizada [0..1]
func world_to_normalized(world_pos: Vector2) -> Vector2:
	var b = _current_bounds
	var nx = (world_pos.x - b.position.x) / b.size.x
	var ny = (world_pos.y - b.position.y) / b.size.y
	return Vector2(clampf(nx, 0.0, 1.0), clampf(ny, 0.0, 1.0))

func get_player_pos() -> Vector2:
	var players = Engine.get_main_loop().get_nodes_in_group("player") if Engine.get_main_loop() else []
	if players.size() > 0:
		return players[0].global_position
	return Vector2.ZERO

func get_party_positions() -> Array:
	var result: Array = []
	if not has_node("/root/PartyManager"):
		return result
	var pm = get_node("/root/PartyManager")
	for i in range(1, pm.members.size()):
		var m = pm.members[i]
		if m["node"] != null and is_instance_valid(m["node"]):
			result.append({"pos": m["node"].global_position, "name": m["name"], "color": m["color"]})
	return result
