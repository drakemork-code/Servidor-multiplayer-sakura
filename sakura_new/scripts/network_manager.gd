# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# NETWORK MANAGER — Autoload global  (v22.3 — server-authoritative)
#
# CAMBIOS v22.2:
#   1. Broadcast de posición filtrado por escena (ya no envía
#      estado de 100 jugadores a todos — solo a peers en la misma zona)
#   2. RPCs server-authoritative para enemigos:
#        enemy_take_damage  → el servidor valida y retransmite HP
#        enemy_died         → el servidor decide muerte + loot
#   3. Party real por red:
#        send_party_invite / accept_party_invite / leave_party
#        share_xp retransmite XP real a peers de la party
#   4. Chat guild y group filtrado correctamente por guild_id y party
#
# CAMBIOS v22.3:
#   5. Transporte cambiado de ENetMultiplayerPeer (UDP) a
#      WebSocketMultiplayerPeer (TCP). Railway solo expone TCP/HTTP
#      al público, no UDP, así que ENet no podía salir a internet.
#      WebSocket usa el mismo puerto que el backend HTTP (Railway
#      asigna el puerto vía la env var PORT) y funciona con el
#      sistema multiplayer de alto nivel de Godot sin cambios en
#      el resto del archivo (RPCs, spawn de remotos, sync, etc.)
# ============================================================

signal connected_to_server()
signal disconnected_from_server()
signal connection_failed()
signal player_joined(peer_id: int, data: Dictionary)
signal player_left(peer_id: int)
signal chat_message_received(channel: String, sender: String, text: String, color_hex: String)
signal server_shutdown_warning(seconds: int)
signal party_invite_received(from_name: String, from_peer_id: int)
signal party_updated()

# ── Config ────────────────────────────────────────────────────
const DEFAULT_HOST    : String = "127.0.0.1"
const DEFAULT_PORT    : int    = 7350
const MAX_PLAYERS     : int    = 100  # límite lógico; WebSocketMultiplayerPeer no lo aplica directo en create_server
const SYNC_HZ         : float  = 20.0
const RECONNECT_DELAY : float  = 5.0

# ── Estado local ──────────────────────────────────────────────
var is_server  : bool = false
var is_client  : bool = false
var my_peer_id : int  = 0

# peers online: { peer_id: { name, position, scene, hp, max_hp, anim, facing, guild_id } }
var online_players : Dictionary = {}

# Anti-cheat: timestamp del último ataque válido aceptado por peer_id (server-side)
var _last_attack_time : Dictionary = {}
const MIN_ATTACK_INTERVAL : float = 0.18  # margen bajo el cooldown más rápido del cliente (0.45s autoataque)

# party server-side (solo el servidor es la autoridad):
#   { party_id: [peer_id, peer_id, ...] }
var _server_parties : Dictionary = {}
# party del cliente local: Array[peer_id]
var my_party : Array = []

var _remote_nodes   : Dictionary = {}
var _sync_timer     : float = 0.0
var _reconnect_timer : float = 0.0
var _trying_reconnect : bool = false
var _last_host : String = DEFAULT_HOST
var _last_port : int    = DEFAULT_PORT

const REMOTE_PLAYER_SCENE = preload("res://scenes/player_remote.tscn")

# ──────────────────────────────────────────────────────────────
func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	print("[NetworkManager] Inicializado v22.2")

func _process(delta: float) -> void:
	if is_client and multiplayer.has_multiplayer_peer():
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_sync_timer += delta
			if _sync_timer >= 1.0 / SYNC_HZ:
				_sync_timer = 0.0
				_send_my_state()
	if _trying_reconnect:
		_reconnect_timer += delta
		if _reconnect_timer >= RECONNECT_DELAY:
			_reconnect_timer = 0.0
			join_server(_last_host, _last_port)

# ──────────────────────────────────────────────────────────────
# SERVIDOR / CLIENTE
# ──────────────────────────────────────────────────────────────

func start_server(port: int = DEFAULT_PORT) -> void:
	var peer = WebSocketMultiplayerPeer.new()
	var err  = peer.create_server(port)
	if err != OK:
		push_error("[NetworkManager] Error al crear servidor: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	is_server = true
	my_peer_id = 1
	print("[NetworkManager] Servidor WebSocket v22.3 en puerto %d" % port)

func join_server(host: String = DEFAULT_HOST, port: int = DEFAULT_PORT) -> void:
	_last_host = host
	_last_port = port
	var peer = WebSocketMultiplayerPeer.new()
	# Railway sirve HTTPS, así que el WebSocket debe ser "wss://" (seguro).
	# Para pruebas locales (127.0.0.1) usamos "ws://" sin TLS.
	var scheme = "wss://" if host != "127.0.0.1" and host != "localhost" else "ws://"
	var url = "%s%s:%d" % [scheme, host, port]
	var err  = peer.create_client(url)
	if err != OK:
		push_error("[NetworkManager] Error al conectar: %s" % err)
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	is_client = true
	_trying_reconnect = false

func disconnect_from_server() -> void:
	_trying_reconnect = false
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	is_client = false
	online_players.clear()
	my_party.clear()
	_clear_remote_nodes()

# ──────────────────────────────────────────────────────────────
# CALLBACKS DE CONEXIÓN
# ──────────────────────────────────────────────────────────────

func _on_connected_to_server() -> void:
	my_peer_id = multiplayer.get_unique_id()
	_trying_reconnect = false
	_register_on_server.rpc_id(1, _build_my_data())
	connected_to_server.emit()

func _on_connection_failed() -> void:
	is_client = false
	_trying_reconnect = true
	_reconnect_timer  = 0.0
	connection_failed.emit()

func _on_server_disconnected() -> void:
	is_client = false
	online_players.clear()
	my_party.clear()
	_clear_remote_nodes()
	_trying_reconnect = true
	_reconnect_timer  = 0.0
	disconnected_from_server.emit()

func _on_peer_connected(peer_id: int) -> void:
	if is_server:
		for pid in online_players:
			_send_player_joined.rpc_id(peer_id, pid, online_players[pid])

func _on_peer_disconnected(peer_id: int) -> void:
	if is_server:
		online_players.erase(peer_id)
		_cleanup_party_for_peer(peer_id)
		_last_attack_time.erase(peer_id)
		_notify_player_left.rpc(peer_id)
	_remove_remote_node(peer_id)
	player_left.emit(peer_id)

# ──────────────────────────────────────────────────────────────
# REGISTRO Y SINCRONIZACIÓN DE JUGADORES
# ──────────────────────────────────────────────────────────────

func _build_my_data() -> Dictionary:
	return {
		"name":       PlayerData.character_name,
		"hair_style": PlayerData.hair_style,
		"race":       PlayerData.race,
		"gender":     PlayerData.character_gender,
		"hp":         PlayerData.hp,
		"max_hp":     PlayerData.max_hp,
		"level":      PlayerData.level,
		"scene":      GameManager.current_scene,
		"position":   _get_my_position(),
		"anim":       "idle",
		"facing":     1,
		"guild_id":   (PlayerData.get("guild_id") if PlayerData.get("guild_id") != null else ""),
		# FIX APARIENCIA: necesario para que el shader character_swap.gdshader
		# se vea igual en los clientes remotos que en el propietario.
		"skin_r": PlayerData.skin_color.r, "skin_g": PlayerData.skin_color.g, "skin_b": PlayerData.skin_color.b,
		"hair_r": PlayerData.hair_color.r, "hair_g": PlayerData.hair_color.g, "hair_b": PlayerData.hair_color.b,
		"eye_r":  PlayerData.eye_color.r,  "eye_g":  PlayerData.eye_color.g,  "eye_b":  PlayerData.eye_color.b,
		"outfit_r": PlayerData.outfit_color.r, "outfit_g": PlayerData.outfit_color.g, "outfit_b": PlayerData.outfit_color.b,
	}

func _get_my_position() -> Dictionary:
	var p = GameManager.player_ref
	if p:
		return {"x": p.global_position.x, "y": p.global_position.y}
	return {"x": 0.0, "y": 0.0}

func _send_my_state() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var p = GameManager.player_ref
	var anim   = "idle"
	var facing = 1
	if p:
		anim   = p._anim_current if "_anim_current" in p else "idle"
		facing = 1 if (p.facing_right if "facing_right" in p else true) else -1
	_update_player_state.rpc(
		GameManager.current_scene,
		_get_my_position(),
		PlayerData.hp,
		PlayerData.max_hp,
		anim,
		facing
	)

# ── RPCs estado jugador ───────────────────────────────────────

@rpc("any_peer", "reliable")
func _register_on_server(data: Dictionary) -> void:
	if not is_server:
		return
	var sender = multiplayer.get_remote_sender_id()
	online_players[sender] = data
	print("[Server] Jugador registrado: %s (ID %d)" % [data.get("name","?"), sender])
	_send_player_joined.rpc(sender, data)
	# Sincronizar enemigos activos al nuevo cliente
	_send_enemy_list_to_client(sender)

# ── FIX APARIENCIA EN CALIENTE ──────────────────────────────────
# Llamar a esta función desde cualquier UI futura de personalización
# (barbero, tienda de ropa, etc.) cuando el jugador cambie su apariencia
# en caliente, sin necesidad de reconectarse.
func broadcast_appearance_update() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	_rpc_appearance_update.rpc_id(1, _build_my_data())

@rpc("any_peer", "reliable")
func _rpc_appearance_update(data: Dictionary) -> void:
	if not is_server:
		return
	var sender = multiplayer.get_remote_sender_id()
	if not sender in online_players:
		return
	# Conservar estado en tiempo real (posición/hp/anim) y solo actualizar apariencia
	for key in ["hair_style", "race", "gender", "skin_r","skin_g","skin_b",
				"hair_r","hair_g","hair_b","eye_r","eye_g","eye_b",
				"outfit_r","outfit_g","outfit_b"]:
		if data.has(key):
			online_players[sender][key] = data[key]
	print("[Server] Apariencia actualizada en caliente: %s (ID %d)" % [online_players[sender].get("name","?"), sender])
	# Reenviar a todos los peers en la misma escena (incluido el dueño no — solo a los demás)
	var scene = online_players[sender].get("scene", "")
	for pid in online_players:
		if pid != sender and online_players[pid].get("scene","") == scene:
			_recv_appearance_update.rpc_id(pid, sender, online_players[sender])

@rpc("authority", "reliable")
func _recv_appearance_update(peer_id: int, data: Dictionary) -> void:
	if peer_id == my_peer_id:
		return
	if peer_id in online_players:
		for key in data:
			online_players[peer_id][key] = data[key]
	if peer_id in _remote_nodes:
		var node = _remote_nodes[peer_id]
		if is_instance_valid(node) and node.has_method("setup"):
			node.setup(online_players[peer_id])

func _send_enemy_list_to_client(peer_id: int) -> void:
	var em = get_node_or_null("/root/EnemyManager")
	if not em:
		return
	# FIX MULTIJUGADOR: filtrar solo enemigos de la MISMA zona que el cliente.
	# El servidor mantiene los 4 mapas cargados a la vez; sin este filtro se
	# enviaba la lista completa de los 4 mundos mezclada, causando matches
	# por proximidad ambiguos/cruzados entre mapas con coordenadas similares.
	var client_scene: String = online_players.get(peer_id, {}).get("scene", "")
	var enemy_list : Array = []
	for enemy in em.active_enemies:
		if is_instance_valid(enemy) and enemy.get("zone_scene_path") == client_scene:
			enemy_list.append({
				"network_id": enemy.get("network_id"),
				"x": enemy.global_position.x,
				"y": enemy.global_position.y,
				"current_hp": enemy.get("current_hp") if enemy.get("current_hp") != null else enemy.get("max_hp"),
				"max_hp": enemy.get("max_hp"),
			})
	print("[Server][Combat] Sincronizando %d enemigos de zona '%s' al peer %d" % [enemy_list.size(), client_scene, peer_id])
	if enemy_list.size() > 0:
		_rpc_sync_enemy_list.rpc_id(peer_id, enemy_list)


@rpc("any_peer", "reliable")
func request_enemy_resync() -> void:
	if not is_server:
		return
	var sender := multiplayer.get_remote_sender_id()
	print("[Server] Resync de enemigos solicitado por peer %d" % sender)
	await get_tree().process_frame
	_send_enemy_list_to_client(sender)

@rpc("authority", "reliable")
func _rpc_sync_enemy_list(enemy_list: Array) -> void:
	# Asignar network_ids del servidor a los enemigos locales por proximidad
	var local_enemies = get_tree().get_nodes_in_group("enemy")
	var matched := 0
	for edata in enemy_list:
		var srv_nid : int     = edata.get("network_id", 0)
		var srv_pos : Vector2 = Vector2(edata.get("x", 0.0), edata.get("y", 0.0))
		var srv_hp  : int     = edata.get("current_hp", 0)
		if srv_nid == 0:
			continue
		var best      : Node  = null
		var best_dist : float = 999999.0
		for e in local_enemies:
			if not is_instance_valid(e):
				continue
			var local_nid = e.get("network_id")
			if local_nid != null and local_nid != 0:
				continue
			var d = e.global_position.distance_to(srv_pos)
			if d < best_dist:
				best_dist = d
				best = e
		if is_instance_valid(best) and best_dist < 120.0:
			best.set("network_id", srv_nid)
			if best.get("current_hp") != null:
				best.set("current_hp", srv_hp)
			if best.has_method("_update_hp_bar"):
				best._update_hp_bar()
			matched += 1
			print("[Client] Enemy sync: nid=", srv_nid, " dist=", best_dist)
	print("[Client][Combat] Sincronización de enemigos: %d/%d emparejados" % [matched, enemy_list.size()])

@rpc("any_peer", "unreliable_ordered")
func _update_player_state(scene: String, pos: Dictionary, hp: int, max_hp: int, anim: String, facing: int) -> void:
	var sender = multiplayer.get_remote_sender_id()
	if is_server:
		if sender in online_players:
			var prev_scene = online_players[sender].get("scene", "")
			online_players[sender]["scene"]   = scene
			online_players[sender]["position"] = pos
			online_players[sender]["hp"]      = hp
			# Si cambió de escena, re-sincronizar enemigos
			if prev_scene != scene:
				_send_enemy_list_to_client(sender)
			online_players[sender]["max_hp"]  = max_hp
			online_players[sender]["anim"]    = anim
			online_players[sender]["facing"]  = facing
		# ── MEJORA: relay solo a peers en la MISMA ESCENA ──
		for pid in online_players:
			if pid != sender and online_players[pid].get("scene","") == scene:
				_recv_player_state.rpc_id(pid, sender, scene, pos, hp, max_hp, anim, facing)
	else:
		_apply_remote_state(sender, scene, pos, hp, max_hp, anim, facing)

@rpc("authority", "unreliable_ordered")
func _recv_player_state(peer_id: int, scene: String, pos: Dictionary, hp: int, max_hp: int, anim: String, facing: int) -> void:
	_apply_remote_state(peer_id, scene, pos, hp, max_hp, anim, facing)

func _apply_remote_state(peer_id: int, scene: String, pos: Dictionary, hp: int, max_hp: int, anim: String, facing: int) -> void:
	if peer_id == my_peer_id:
		return
	if not peer_id in online_players:
		online_players[peer_id] = {}
	online_players[peer_id]["scene"]   = scene
	online_players[peer_id]["position"] = pos
	online_players[peer_id]["hp"]      = hp
	online_players[peer_id]["max_hp"]  = max_hp
	online_players[peer_id]["anim"]    = anim
	online_players[peer_id]["facing"]  = facing
	_update_remote_node(peer_id, scene, pos, hp, max_hp, anim, facing)

@rpc("authority", "reliable")
func _send_player_joined(peer_id: int, data: Dictionary) -> void:
	if peer_id == my_peer_id:
		return
	online_players[peer_id] = data
	player_joined.emit(peer_id, data)
	_spawn_remote_node(peer_id, data)

@rpc("authority", "reliable")
func _notify_player_left(peer_id: int) -> void:
	online_players.erase(peer_id)
	my_party.erase(peer_id)
	_remove_remote_node(peer_id)
	player_left.emit(peer_id)
	party_updated.emit()

# ──────────────────────────────────────────────────────────────
# ENEMIGOS SERVER-AUTHORITATIVE
# ──────────────────────────────────────────────────────────────
# El cliente llama a request_enemy_damage() con el network_id del
# enemigo y el daño calculado localmente. El servidor valida,
# aplica el HP real, y retransmite el nuevo HP a todos en la escena.
# La muerte también la decide el servidor.

# Llamar desde enemy.gd en lugar de modificar current_hp directamente
func request_enemy_damage(enemy_network_id: int, damage: int, knockback_dir: Vector2) -> void:
	var is_online := multiplayer.has_multiplayer_peer() \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	if not is_online:
		# Offline o aún conectando: aplicar localmente igual que antes
		print("[Client][Combat] Offline — aplicando daño local. nid=%d dmg=%d" % [enemy_network_id, damage])
		var e = _find_enemy_by_network_id(enemy_network_id)
		if e and e.has_method("take_damage"):
			e.take_damage(damage, knockback_dir)
		return
	# FIX v26: enviar posición actual del atacante en el mismo paquete,
	# en lugar de depender del caché online_players que puede estar desactualizado.
	var my_pos = _get_my_position()
	print("[Client][Combat] Enviando ataque al servidor — nid=%d dmg=%d pos=(%.0f,%.0f)" % [enemy_network_id, damage, my_pos.get("x",0.0), my_pos.get("y",0.0)])
	_rpc_enemy_damage.rpc_id(1, enemy_network_id, damage, {"x": knockback_dir.x, "y": knockback_dir.y}, my_pos)

@rpc("any_peer", "reliable")
func _rpc_enemy_damage(enemy_network_id: int, damage: int, kb: Dictionary, attacker_pos: Dictionary = {}) -> void:
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("[Server][Combat] Ataque recibido de peer %d — nid=%d dmg_solicitado=%d" % [sender_id, enemy_network_id, damage])
	# Validar cooldown — rechazar ataques demasiado seguidos (spam/cheat)
	var now := Time.get_ticks_msec() / 1000.0
	var last_atk: float = _last_attack_time.get(sender_id, -999.0)
	if now - last_atk < MIN_ATTACK_INTERVAL:
		print("[Server][Combat] RECHAZADO — cooldown violado por peer %d (%.3fs desde el último)" % [sender_id, now - last_atk])
		return
	_last_attack_time[sender_id] = now
	var e = _find_enemy_by_network_id(enemy_network_id)
	if not is_instance_valid(e):
		print("[Server][Combat] RECHAZADO — no se encontró enemigo con nid=%d (¿no sincronizado aún?)" % enemy_network_id)
		return
	if e.state == e.State.DEAD:
		print("[Server][Combat] RECHAZADO — el enemigo nid=%d ya está muerto" % enemy_network_id)
		return
	# FIX v26: usar la posición enviada por el cliente en el paquete (fresca),
	# con fallback al caché online_players si el cliente no la envió.
	var sender_pos: Vector2
	if attacker_pos.has("x") and attacker_pos.has("y"):
		sender_pos = Vector2(attacker_pos.x, attacker_pos.y)
		# Actualizar también el caché con esta posición fresca
		if sender_id in online_players:
			online_players[sender_id]["position"] = attacker_pos
	else:
		var sender_pos_d = online_players.get(sender_id, {}).get("position", {"x":0.0,"y":0.0})
		sender_pos = Vector2(sender_pos_d.x, sender_pos_d.y)
	var dist = sender_pos.distance_to(e.global_position)
	if dist > 220.0:
		print("[Server][Combat] RECHAZADO — distancia inválida (%.1f px) peer %d vs nid=%d" % [dist, sender_id, enemy_network_id])
		return
	# Aplicar defensa server-side
	var hp_before = e.current_hp
	var real_dmg = max(1, damage - e.defense)
	e.current_hp -= real_dmg
	e.current_hp = max(0, e.current_hp)
	print("[Server][Combat] Validado OK — nid=%d hp %d → %d (dmg_real=%d, defensa=%d)" % [enemy_network_id, hp_before, e.current_hp, real_dmg, e.defense])
	var kbdir = Vector2(kb.get("x",0.0), kb.get("y",0.0))
	# Usar la escena del cliente que envió el daño (no GameManager del servidor)
	var scene = online_players.get(sender_id, {}).get("scene", "")
	# Broadcast nuevo HP a todos en la misma escena
	var broadcast_count := 0
	for pid in online_players:
		if online_players[pid].get("scene","") == scene:
			_rpc_enemy_sync_hp.rpc_id(pid, enemy_network_id, e.current_hp, e.max_hp, real_dmg, kb)
			broadcast_count += 1
	print("[Server][Combat] HP sincronizado a %d peer(s) en zona '%s'" % [broadcast_count, scene])
	# Aplicar también en el servidor visualmente
	_apply_enemy_damage_local(e, real_dmg, kbdir)
	if e.current_hp <= 0:
		print("[Server][Combat] Enemigo nid=%d murió — repartiendo recompensas" % enemy_network_id)
		_server_kill_enemy(e, enemy_network_id, scene)

@rpc("authority", "reliable")
func _rpc_enemy_sync_hp(enemy_network_id: int, new_hp: int, max_hp: int, dmg_shown: int, kb: Dictionary) -> void:
	var e = _find_enemy_by_network_id(enemy_network_id)
	if not is_instance_valid(e):
		print("[Client][Combat] Recibido HP sync para nid=%d pero no existe localmente" % enemy_network_id)
		return
	print("[Client][Combat] HP sync recibido — nid=%d hp→%d/%d dmg=%d" % [enemy_network_id, new_hp, max_hp, dmg_shown])
	e.current_hp = new_hp
	if e.has_method("_update_hp_bar"):
		e._update_hp_bar()
	if e.has_method("_show_colored_label"):
		e._show_colored_label("-" + str(dmg_shown), Color.WHITE)
	var kbdir = Vector2(kb.get("x",0.0), kb.get("y",0.0))
	_apply_enemy_damage_local(e, dmg_shown, kbdir)
	if new_hp <= 0 and e.state != e.State.DEAD:
		e._enter_dead()

func _server_kill_enemy(e: Node, enemy_network_id: int, scene: String) -> void:
	# El servidor reparte recompensas a TODOS en la party del killer (si hay)
	# y notifica a todos los clientes en la escena que el enemigo murió
	var loot_data = {
		"loot_main":   e.loot_main,
		"loot_extra":  e.loot_extra,
		"bronze_min":  e.bronze_min,
		"bronze_max":  e.bronze_max,
		"xp_reward":   e.xp_reward,
	}
	for pid in online_players:
		if online_players[pid].get("scene","") == scene:
			_rpc_enemy_killed.rpc_id(pid, enemy_network_id, loot_data)

@rpc("authority", "reliable")
func _rpc_enemy_killed(enemy_network_id: int, loot: Dictionary) -> void:
	print("[Client][Combat] Evento de muerte recibido — nid=%d" % enemy_network_id)
	# Aplicar loot y XP en el cliente receptor
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		var main = loot.get("loot_main","")
		var extra = loot.get("loot_extra","")
		if main != "" and randf() < 0.7:
			inv.add_item(main, 1)
		if extra != "" and randf() < 0.3:
			inv.add_item(extra, 1)
	var bmax = loot.get("bronze_max", 0)
	if bmax > 0:
		var drop = randi_range(loot.get("bronze_min",0), bmax)
		if drop > 0:
			PlayerData.add_bronze(drop)
	var xp = loot.get("xp_reward", 0)
	if xp > 0:
		var player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.has_method("gain_xp"):
			player.gain_xp(xp)
		else:
			PlayerData.gain_xp(xp)
	# Matar el nodo local si aún existe
	var e = _find_enemy_by_network_id(enemy_network_id)
	if is_instance_valid(e) and e.state != e.State.DEAD:
		e._enter_dead()

func _apply_enemy_damage_local(e: Node, dmg: int, kb: Vector2) -> void:
	if not is_instance_valid(e):
		return
	if kb.length() > 0.01:
		e.knockback_velocity = kb * 120.0
	e.state = e.State.HURT
	e.hurt_timer = 0.18
	if e.has_method("_broadcast_aggro_to_nearby"):
		e._broadcast_aggro_to_nearby()
	if e.has_method("_spawn_hit_particles"):
		e._spawn_hit_particles(e.global_position + Vector2(0, -12), Color.YELLOW)

func _find_enemy_by_network_id(nid: int) -> Node:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.get("network_id") == nid:
			return e
	return null

# Utilidad: asignar network_id a un enemigo al spawnearlo (desde world scripts)
func assign_enemy_network_id(enemy: Node) -> int:
	var nid = randi_range(100000, 999999)
	enemy.set("network_id", nid)
	return nid

# ──────────────────────────────────────────────────────────────
# PARTY POR RED
# ──────────────────────────────────────────────────────────────

func send_party_invite(target_peer_id: int) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	_rpc_party_invite.rpc_id(1, target_peer_id)

@rpc("any_peer", "reliable")
func _rpc_party_invite(target_peer_id: int) -> void:
	if not is_server:
		return
	var from_id   = multiplayer.get_remote_sender_id()
	var from_name = online_players.get(from_id, {}).get("name", "???")
	# Reenviar la invitación al destinatario
	_rpc_recv_party_invite.rpc_id(target_peer_id, from_id, from_name)

@rpc("authority", "reliable")
func _rpc_recv_party_invite(from_peer_id: int, from_name: String) -> void:
	party_invite_received.emit(from_name, from_peer_id)

func accept_party_invite(inviter_peer_id: int) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	_rpc_party_accept.rpc_id(1, inviter_peer_id)

@rpc("any_peer", "reliable")
func _rpc_party_accept(inviter_peer_id: int) -> void:
	if not is_server:
		return
	var accepter_id = multiplayer.get_remote_sender_id()
	# Encontrar o crear la party del invitador
	var party_id = _get_or_create_party(inviter_peer_id)
	var party = _server_parties[party_id]
	if party.size() < 4 and not accepter_id in party:
		party.append(accepter_id)
	# Notificar a todos los miembros
	_broadcast_party_update(party_id)

func leave_party() -> void:
	if not multiplayer.has_multiplayer_peer():
		my_party.clear()
		party_updated.emit()
		return
	_rpc_party_leave.rpc_id(1)

@rpc("any_peer", "reliable")
func _rpc_party_leave() -> void:
	if not is_server:
		return
	var leaver = multiplayer.get_remote_sender_id()
	_cleanup_party_for_peer(leaver)

func _get_or_create_party(peer_id: int) -> int:
	# ¿Ya está en alguna party?
	for pid in _server_parties:
		if peer_id in _server_parties[pid]:
			return pid
	# Crear nueva
	var new_id = randi_range(1, 999999)
	_server_parties[new_id] = [peer_id]
	return new_id

func _broadcast_party_update(party_id: int) -> void:
	if not party_id in _server_parties:
		return
	var members = _server_parties[party_id]
	for pid in members:
		var names = []
		for mid in members:
			names.append(online_players.get(mid,{}).get("name","?"))
		_rpc_recv_party_update.rpc_id(pid, members.duplicate(), names)

@rpc("authority", "reliable")
func _rpc_recv_party_update(member_ids: Array, member_names: Array) -> void:
	my_party = member_ids
	# Sincronizar con PartyManager local
	var pm = get_node_or_null("/root/PartyManager")
	if pm and pm.has_method("sync_from_network"):
		pm.sync_from_network(member_ids, member_names, online_players)
	party_updated.emit()

func _cleanup_party_for_peer(peer_id: int) -> void:
	for party_id in _server_parties.keys():
		var party = _server_parties[party_id]
		if peer_id in party:
			party.erase(peer_id)
			if party.size() == 0:
				_server_parties.erase(party_id)
			else:
				_broadcast_party_update(party_id)
			break

# XP compartida por red — llamar desde _rpc_enemy_killed cuando hay party
func broadcast_party_xp(xp_amount: int, killer_peer_id: int) -> void:
	if not is_server:
		return
	for party_id in _server_parties:
		var party = _server_parties[party_id]
		if killer_peer_id in party and party.size() > 1:
			var xp_each = max(1, int(xp_amount * 0.70 / float(party.size())))
			for pid in party:
				if pid != killer_peer_id:
					_rpc_grant_xp.rpc_id(pid, xp_each)

@rpc("authority", "reliable")
func _rpc_grant_xp(amount: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("gain_xp"):
		player.gain_xp(amount)
	else:
		PlayerData.gain_xp(amount)

# ──────────────────────────────────────────────────────────────
# CHAT REAL (con guild y group reales)
# ──────────────────────────────────────────────────────────────

func send_chat(channel: String, text: String) -> void:
	if not multiplayer.has_multiplayer_peer():
		ChatManager.receive_message(channel, PlayerData.character_name, text)
		return
	_rpc_chat.rpc_id(1, channel, text)

@rpc("any_peer", "reliable")
func _rpc_chat(channel: String, text: String) -> void:
	if not is_server:
		return
	var sender_id   = multiplayer.get_remote_sender_id()
	var sender_name = online_players.get(sender_id, {}).get("name", "???")
	match channel:
		"global":
			_recv_chat.rpc(channel, sender_name, text, "#FFFFFF")
		"local":
			var sender_pos = online_players.get(sender_id, {}).get("position", {"x":0,"y":0})
			for pid in online_players:
				var p_pos = online_players[pid].get("position", {"x":0,"y":0})
				var dist  = Vector2(sender_pos.x, sender_pos.y).distance_to(Vector2(p_pos.x, p_pos.y))
				if dist <= 600.0:
					_recv_chat.rpc_id(pid, channel, sender_name, text, "#AAFFAA")
		"group":
			# Filtrar por party REAL del sender
			var in_same_party: Array = [sender_id]
			for party_id in _server_parties:
				if sender_id in _server_parties[party_id]:
					in_same_party = _server_parties[party_id]
					break
			for pid in in_same_party:
				_recv_chat.rpc_id(pid, channel, sender_name, text, "#AACCFF")
		"guild":
			# Filtrar por guild_id del sender
			var sender_guild = online_players.get(sender_id, {}).get("guild_id", "")
			if sender_guild == "":
				return
			for pid in online_players:
				if online_players[pid].get("guild_id","") == sender_guild:
					_recv_chat.rpc_id(pid, channel, sender_name, text, "#FFDD88")

@rpc("authority", "reliable")
func _recv_chat(channel: String, sender: String, text: String, color_hex: String) -> void:
	chat_message_received.emit(channel, sender, text, color_hex)
	ChatManager.receive_message(channel, sender, text)

# ──────────────────────────────────────────────────────────────
# PERSISTENCIA — manejada exclusivamente por el auth server (Firestore)
# El servidor Godot NO guarda ni carga datos de personaje.
# Los saves van via HTTP a /save-player y /load-player en el repo 1.
# ──────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────
# NODOS REMOTOS
# ──────────────────────────────────────────────────────────────

func _spawn_remote_node(peer_id: int, data: Dictionary) -> void:
	var current = GameManager.current_scene
	if data.get("scene","") != current:
		return
	if peer_id in _remote_nodes:
		return
	if not ResourceLoader.exists("res://scenes/player_remote.tscn"):
		return
	var scene = load("res://scenes/player_remote.tscn")
	if not scene:
		return
	var node = scene.instantiate()
	node.name = "RemotePlayer_%d" % peer_id
	var pos_d = data.get("position", {"x":0.0,"y":0.0})
	node.global_position = Vector2(pos_d.x, pos_d.y)
	if node.has_method("setup"):
		node.setup(data)
	var cur_scene = get_tree().current_scene
	if not is_instance_valid(cur_scene):
		node.queue_free()
		return
	cur_scene.add_child(node)
	_remote_nodes[peer_id] = node

func _update_remote_node(peer_id: int, scene: String, pos: Dictionary, hp: int, max_hp: int, anim: String, facing: int) -> void:
	var current = GameManager.current_scene
	if scene != current:
		_remove_remote_node(peer_id)
		return
	if not peer_id in _remote_nodes:
		if peer_id in online_players:
			_spawn_remote_node(peer_id, online_players[peer_id])
		return
	var node = _remote_nodes[peer_id]
	if not is_instance_valid(node):
		_remote_nodes.erase(peer_id)
		return
	# Verificar que el nodo sigue en el árbol de escena actual
	if not node.is_inside_tree():
		_remote_nodes.erase(peer_id)
		return
	if node.has_method("update_state"):
		node.update_state(Vector2(pos.x, pos.y), hp, max_hp, anim, facing)

func _remove_remote_node(peer_id: int) -> void:
	if peer_id in _remote_nodes:
		var node = _remote_nodes[peer_id]
		if is_instance_valid(node):
			node.queue_free()
		_remote_nodes.erase(peer_id)

func _clear_remote_nodes() -> void:
	for pid in _remote_nodes:
		var node = _remote_nodes[pid]
		if is_instance_valid(node):
			node.queue_free()
	_remote_nodes.clear()

# ──────────────────────────────────────────────────────────────
# DAÑO AL JUGADOR SERVER-AUTHORITATIVE (FIX v26)
# El servidor notifica al cliente cuánto daño recibió.
# Así el mob nunca aplica daño localmente en el cliente.
# ──────────────────────────────────────────────────────────────

# Llamar desde enemy.gd en lugar de player_ref.take_damage() directamente.
# 'target_peer_id' es el my_peer_id del jugador objetivo.
func notify_player_damage(target_peer_id: int, damage: int) -> void:
	if not is_server:
		return
	_rpc_apply_player_damage.rpc_id(target_peer_id, damage)

@rpc("authority", "reliable")
func _rpc_apply_player_damage(damage: int) -> void:
	# Solo el cliente local ejecuta esto
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(damage)

# ──────────────────────────────────────────────────────────────
# AVISO DE REINICIO
# ──────────────────────────────────────────────────────────────

func broadcast_shutdown_warning(seconds: int) -> void:
	if not is_server:
		return
	_rpc_shutdown_warning.rpc(seconds)

@rpc("authority", "reliable")
func _rpc_shutdown_warning(seconds: int) -> void:
	server_shutdown_warning.emit(seconds)
	ChatManager.receive_message("global","⚠ Sistema",
		"El servidor se reinicia en %d segundos para una actualización." % seconds)
