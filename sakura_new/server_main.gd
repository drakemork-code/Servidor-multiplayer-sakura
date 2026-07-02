# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# SERVER MAIN — Punto de entrada del servidor headless  (v23.0)
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
#
# CAMBIOS v23.0 (PARTE 5.2 — separación por zona):
#   - Cada instancia ahora corre UNA sola zona, elegida por el
#     argumento --zone=<nombre> (ej. --zone=world_south). Si no se
#     pasa --zone, cae en modo legado "all" (carga las 4 world_*
#     juntas, comportamiento de v22.3) para no romper deploys viejos
#     mientras se migra.
#   - El puerto ya NO se lee solo de la env var PORT: si hay --zone
#     válida, el puerto se resuelve del mapeo ZONE_PORTS de abajo
#     (mismo mapeo documentado en PARTE 5.1). PORT (env var) sigue
#     funcionando como override manual si se define explícita.
#   - "town" no tiene enemigos (no carga ninguna world_*.tscn), solo
#     acepta conexiones — confirmado en PARTE 5.1 que el server
#     nunca cargó town.tscn como escena de servidor, se mantiene así.
# ============================================================

const DEFAULT_PORT : int   = 7350
const TICK_RATE     : float = 1.0 / 20.0

# Mapeo zona → puerto (PARTE 5.1). Mantener sincronizado con el
# systemd template sakura-mp@.service y con el cliente
# (scene_transition.gd / network_manager.gd usan los mismos nombres
# de zona para pedir el traspaso).
const ZONE_PORTS: Dictionary = {
	"town":        7350,
	"world_north": 7351,
	"world_south": 7352,
	"world_east":  7353,
	"world_west":  7354,
}

const ZONE_SCENES: Dictionary = {
	"town":        [],  # sin enemigos, no carga escena de mundo
	"world_north": ["res://scenes/world_north.tscn"],
	"world_south": ["res://scenes/world_south.tscn"],
	"world_east":  ["res://scenes/world_east.tscn"],
	"world_west":  ["res://scenes/world_west.tscn"],
}

var PORT : int = DEFAULT_PORT
var ZONE : String = "all"  # "all" = modo legado monolítico (v22.3)
var _uptime     : float = 0.0
var _tick_accum : float = 0.0
var _hb_logged  : int   = 0   # último minuto logueado

func _get_arg_value(prefix: String) -> String:
	# Busca "--zone=algo" tanto en args normales como en user_args
	# (Godot separa los args después de "--" en get_cmdline_user_args()).
	for args in [OS.get_cmdline_args(), OS.get_cmdline_user_args()]:
		for a in args:
			if a.begins_with(prefix):
				return a.substr(prefix.length())
	return ""

func _ready() -> void:
	if not "--server" in OS.get_cmdline_args() and not "--server" in OS.get_cmdline_user_args():
		queue_free()
		return

	var zone_arg = _get_arg_value("--zone=")
	if zone_arg != "" and ZONE_PORTS.has(zone_arg):
		ZONE = zone_arg
		PORT = ZONE_PORTS[ZONE]
	elif zone_arg != "":
		push_error("[Server] --zone='%s' no es una zona válida. Válidas: %s. Cayendo a modo legado 'all'." % [zone_arg, str(ZONE_PORTS.keys())])

	# Railway asigna el puerto público vía la env var PORT. Si está
	# seteada, tiene prioridad sobre el puerto resuelto por --zone
	# (permite override manual, ej. detrás de un proxy con remapeo).
	var env_port = OS.get_environment("PORT")
	if env_port != "":
		PORT = int(env_port)

	print("===========================================")
	print("  Sakura Chronicles — Servidor v23.0  (zona: %s)" % ZONE)
	print("  Puerto: %d  |  Max jugadores: %d" % [PORT, NetworkManager.MAX_PLAYERS])
	print("  Enemigos: server-authoritative")
	print("  Party: real por red")
	print("  Saves: server-side")
	print("  Version gate: activo (consultando auth server)")
	print("===========================================")

	# Iniciar red
	NetworkManager.start_server(PORT)
	NetworkManager.CURRENT_ZONE = ZONE

	# ── Cargar escenas de mundo para que los enemigos existan en el árbol ──
	# El servidor es authoritative: spawns, daño y muerte se calculan aquí.
	# En modo "all" (legado) carga las 4 juntas, igual que v22.3.
	# En modo por-zona, carga SOLO la lista de ZONE_SCENES de su zona
	# (puede ser vacía, ej. "town" no tiene mundo con enemigos).
	var world_scenes: Array = []
	if ZONE == "all":
		world_scenes = [
			"res://scenes/world_north.tscn",
			"res://scenes/world_south.tscn",
			"res://scenes/world_east.tscn",
			"res://scenes/world_west.tscn",
		]
	else:
		world_scenes = ZONE_SCENES.get(ZONE, [])

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
