# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# GAME MANAGER — Autoload global
# Gestiona: cambio de escenas, estado global, señales entre sistemas
# ============================================================

signal scene_changed(scene_name: String)
signal npc_interaction_started(npc_name: String)
signal npc_interaction_ended()
signal player_entered_zone(zone_name: String)
signal pvp_zone_changed(is_pvp: bool)

# Estado global
var current_scene: String = ""
var previous_scene: String = ""
var player_spawn_position: Vector2 = Vector2.ZERO
var player_spawn_override: bool = false
var is_in_dungeon: bool = false
var current_zone: String = "lobby"

# ── PvP ────────────────────────────────────────────────────
# true  → zona PvP: stats normalizadas (sin calidad ni bonus)
# false → PvE:      stats completas
var is_pvp_zone: bool = false

# Referencias activas
var player_ref: Node = null
var ui_ref: Node = null

# Datos de transición entre escenas
var scene_transition_data: Dictionary = {}

func _ready() -> void:
	print("[GameManager] Inicializado — Godot 4.3 MMORPG Pixel")

# ──────────────────────────────────────────────
# CAMBIO DE ESCENAS
# ──────────────────────────────────────────────

func change_scene(scene_path: String, transition_data: Dictionary = {}) -> void:
	scene_transition_data = transition_data

	print("[GameManager] Cambiando escena: ", scene_path)

	# Guardar posición del jugador antes de cambiar
	if player_ref:
		player_spawn_position = player_ref.global_position

	# FIX MONEDAS: forzar guardado local + servidor antes de cambiar de escena
	PlayerData.flush_pending_save()
	PlayerData.flush_pending_server_save()

	# Usar pantalla de carga animada si está disponible
	var ls = get_node_or_null("/root/LoadingScreen")
	if ls and ls.has_method("go_to"):
		ls.go_to(scene_path)
	else:
		# Fallback directo (no debería ocurrir si el autoload está registrado)
		previous_scene = current_scene
		current_scene  = scene_path
		get_tree().change_scene_to_file(scene_path)
		scene_changed.emit(scene_path)

func change_scene_with_spawn(scene_path: String, spawn_pos: Vector2, data: Dictionary = {}) -> void:
	scene_transition_data = data

	print("[GameManager] Cambiando escena con spawn: ", scene_path, " pos:", spawn_pos)

	if player_ref:
		player_spawn_position = player_ref.global_position

	PlayerData.flush_pending_save()
	PlayerData.flush_pending_server_save()

	var ls = get_node_or_null("/root/LoadingScreen")
	if ls and ls.has_method("go_to_with_spawn"):
		ls.go_to_with_spawn(scene_path, spawn_pos)
	else:
		player_spawn_position = spawn_pos
		player_spawn_override  = true
		previous_scene = current_scene
		current_scene  = scene_path
		get_tree().change_scene_to_file(scene_path)
		scene_changed.emit(scene_path)

func get_transition_data() -> Dictionary:
	var data = scene_transition_data.duplicate()
	scene_transition_data = {}
	return data

func consume_spawn_override() -> Vector2:
	player_spawn_override = false
	return player_spawn_position

# ──────────────────────────────────────────────
# NPCs
# ──────────────────────────────────────────────

func start_npc_interaction(npc_name: String) -> void:
	npc_interaction_started.emit(npc_name)

func end_npc_interaction() -> void:
	npc_interaction_ended.emit()

# ──────────────────────────────────────────────
# ZONAS
# ──────────────────────────────────────────────

func set_zone(zone_name: String) -> void:
	current_zone = zone_name
	player_entered_zone.emit(zone_name)
	print("[GameManager] Zona: ", zone_name)
	# Sincronizar minimapa
	var mm = get_node_or_null("/root/MinimapManager")
	if mm: mm.set_zone(zone_name)

func set_pvp_zone(pvp: bool) -> void:
	if is_pvp_zone == pvp:
		return
	is_pvp_zone = pvp
	pvp_zone_changed.emit(pvp)
	# Recalcular stats de equipo al cambiar modo
	InventoryManager._update_equipment_stats()
	var tag := "[PvP]" if pvp else "[PvE]"
	print("[GameManager] Modo %s activado en zona: %s" % [tag, current_zone])

# ──────────────────────────────────────────────
# REFERENCIAS GLOBALES
# ──────────────────────────────────────────────

func register_player(player: Node) -> void:
	player_ref = player

func register_ui(ui: Node) -> void:
	ui_ref = ui

func get_player() -> Node:
	return player_ref

func get_ui() -> Node:
	return ui_ref

# ──────────────────────────────────────────────
# GUARDADO
# ──────────────────────────────────────────────

# ──────────────────────────────────────────────
# INSTANCIAR PLAYER Y UI EN ESCENAS MUNDO
# Llamar al inicio de _ready() en cada escena mundo
# para que el Player y GameUI estén disponibles
# aunque hayan sido destruidos al cambiar de escena.
# ──────────────────────────────────────────────

const _PLAYER_SCENE_PATH := "res://scenes/player.tscn"
const _UI_SCENE_PATH     := "res://scenes/ui/game_ui.tscn"

func ensure_player_and_ui(parent: Node) -> void:
	# No instanciar player ni UI en el servidor headless
	var _nm = get_node_or_null("/root/NetworkManager")
	if _nm and _nm.is_server:
		return
	# ── Player ─────────────────────────────────
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		if ResourceLoader.exists(_PLAYER_SCENE_PATH):
			var ps: PackedScene = load(_PLAYER_SCENE_PATH)
			var player_node     = ps.instantiate()
			parent.add_child(player_node)
			print("[GameManager] Player reinstanciado en: ", parent.name)
		else:
			push_error("[GameManager] No se encontró player.tscn en: " + _PLAYER_SCENE_PATH)

	# ── GameUI ─────────────────────────────────
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() == 0:
		if ResourceLoader.exists(_UI_SCENE_PATH):
			var us: PackedScene = load(_UI_SCENE_PATH)
			var ui_node         = us.instantiate()
			parent.add_child(ui_node)
			print("[GameManager] GameUI reinstanciado en: ", parent.name)
		else:
			push_error("[GameManager] No se encontró game_ui.tscn en: " + _UI_SCENE_PATH)

	# ── Pedir save al servidor ahora que el player está en el mundo ──
	# Los saves van via Firestore (auth server), no via servidor Godot.

func get_game_ui() -> Node:
	var uis = get_tree().get_nodes_in_group("ui")
	return uis[0] if uis.size() > 0 else null

func save_game() -> void:
	PlayerData.save_character_data()
	PlayerData.flush_pending_server_save()
	print("[GameManager] Juego guardado (local + servidor)")

func load_game() -> void:
	PlayerData.load_character_data()
	print("[GameManager] Juego cargado")
