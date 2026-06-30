# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# SERVER MAIN — Punto de entrada del servidor headless  (v22.3)
#
# CAMBIOS v22.2:
#   - Carga saves de servidor al arrancar (_server_load_saves)
#   - Conecta server_save_callback de PlayerData para recibir
#     saves de clientes via push_save_to_server()
#   - Log de parties activas en el heartbeat
#   - Limpieza de parties al desconectar peer
#
# CAMBIOS v22.3:
#   - Transporte WebSocket en vez de ENet (Railway no expone UDP)
#   - Puerto leído de la env var PORT que asigna Railway; si no
#     existe (ej. corriendo local), usa el puerto por defecto 7350
# ============================================================

const DEFAULT_PORT : int   = 7350
const TICK_RATE     : float = 1.0 / 20.0

var PORT : int = DEFAULT_PORT
var _uptime     : float = 0.0
var _tick_accum : float = 0.0
var _hb_logged  : int   = 0   # último minuto logueado

func _ready() -> void:
	if not "--server" in OS.get_cmdline_args() and not "--server" in OS.get_cmdline_user_args():
		queue_free()
		return

	# Railway asigna el puerto público vía la env var PORT.
	# Si no existe (corriendo en local para pruebas), usamos 7350.
	var env_port = OS.get_environment("PORT")
	if env_port != "":
		PORT = int(env_port)

	print("===========================================")
	print("  Sakura Chronicles — Servidor WebSocket v22.3")
	print("  Puerto: %d  |  Max jugadores: %d" % [PORT, NetworkManager.MAX_PLAYERS])
	print("  Enemigos: server-authoritative")
	print("  Party: real por red")
	print("  Saves: server-side")
	print("===========================================")

	# Iniciar red
	NetworkManager.start_server(PORT)

	# ── Cargar escenas de mundo para que los enemigos existan en el árbol ──
	# El servidor es authoritative: spawns, daño y muerte se calculan aquí.
	var world_scenes = [
		"res://scenes/world_north.tscn",
		"res://scenes/world_south.tscn",
		"res://scenes/world_east.tscn",
		"res://scenes/world_west.tscn",
	]
	for scene_path in world_scenes:
		if ResourceLoader.exists(scene_path):
			var packed: PackedScene = load(scene_path)
			var instance = packed.instantiate()
			get_tree().root.call_deferred("add_child", instance)
			print("[Server] Escena cargada: ", scene_path)
		else:
			push_error("[Server] No se encontró escena: " + scene_path)

	# Señales
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)

	# Aviso de reinicio
	var restart_warning = OS.get_environment("RESTART_WARNING_SEC")
	if restart_warning != "":
		var secs = int(restart_warning)
		print("[Server] Aviso de reinicio en %d segundos" % secs)
		await get_tree().create_timer(max(secs - 30, 1)).timeout
		NetworkManager.broadcast_shutdown_warning(30)

func _process(delta: float) -> void:
	_uptime     += delta
	_tick_accum += delta

	# Heartbeat cada 60 segundos
	var minute = int(_uptime / 60.0)
	if minute > _hb_logged and _uptime > 5.0:
		_hb_logged = minute
		var player_count = NetworkManager.online_players.size()
		var party_count  = NetworkManager._server_parties.size()
		print("[Server] Uptime: %ds | Jugadores: %d | Parties: %d" % [
			int(_uptime), player_count, party_count
		])

func _on_player_joined(peer_id: int, data: Dictionary) -> void:
	print("[Server] + %s (ID %d)" % [data.get("name","?"), peer_id])
	# El guardado/cargado de personajes es responsabilidad exclusiva
	# del auth server (Firestore). El servidor Godot solo maneja
	# estado en tiempo real (posición, combate, parties).

func _on_player_left(peer_id: int) -> void:
	print("[Server] - Peer %d desconectado" % peer_id)
