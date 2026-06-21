# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# PARTY MANAGER — Autoload global  (v22.2 — party real por red)
#
# CAMBIOS v22.2:
#   - sync_from_network(): recibe la party actualizada desde
#     NetworkManager y sincroniza el array members[] con peers reales.
#   - invite_online_player(): envía invitación real por red.
#   - accept_invite(): acepta y notifica al servidor.
#   - Los NPCs simulados se mantienen para uso offline.
#   - share_xp() ya no da XP doble: solo ajusta localmente;
#     la distribución a otros peers la hace NetworkManager.
# ============================================================

signal party_changed()
signal member_hp_changed(member_id: int)

const MAX_MEMBERS:   int   = 4
const SHARE_RADIUS:  float = 800.0
const SHARE_PENALTY: float = 0.70

var members: Array = []
var _next_id: int  = 0

var _pending_invite_name: String = ""

func _ready() -> void:
	call_deferred("_register_local_player")
	# Conectar señal de invitación de red
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		if not nm.party_invite_received.is_connected(_on_network_invite_received):
			nm.party_invite_received.connect(_on_network_invite_received)
		if not nm.party_updated.is_connected(_on_party_updated_from_network):
			nm.party_updated.connect(_on_party_updated_from_network)

func _register_local_player() -> void:
	if members.size() > 0:
		return
	var entry := {
		"id":      _next_id,
		"name":    PlayerData.character_name if PlayerData.character_name != "" else "Tú",
		"hp":      PlayerData.hp,
		"max_hp":  PlayerData.max_hp,
		"color":   Color(0.35, 0.75, 1.00),
		"node":    null,
		"peer_id": 0,       # 0 = jugador local
		"is_real": true,    # jugador real vs NPC simulado
	}
	members.append(entry)
	_next_id += 1
	if not PlayerData.health_changed.is_connected(_on_local_hp_changed):
		PlayerData.health_changed.connect(_on_local_hp_changed)
	party_changed.emit()

func _process(delta: float) -> void:
	if members.size() > 0 and members[0]["node"] == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			members[0]["node"] = players[0]
	if members.size() > 0:
		var local_name: String = PlayerData.character_name
		if local_name != "" and members[0]["name"] != local_name:
			members[0]["name"] = local_name
	_process_sim(delta)

func _on_local_hp_changed(new_hp: int, new_max: int) -> void:
	if members.size() == 0:
		return
	members[0]["hp"]     = new_hp
	members[0]["max_hp"] = new_max
	member_hp_changed.emit(members[0]["id"])

# ════════════════════════════════════════════════════════════
# INVITACIÓN REAL POR RED
# ════════════════════════════════════════════════════════════

## Invitar a un jugador online (por su peer_id de NetworkManager)
func invite_online_player(peer_id: int) -> void:
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("send_party_invite"):
		nm.send_party_invite(peer_id)
	else:
		push_warning("[PartyManager] NetworkManager no disponible para invitar")

## Aceptar invitación recibida por red
func accept_network_invite(inviter_peer_id: int) -> void:
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("accept_party_invite"):
		nm.accept_party_invite(inviter_peer_id)

## Salir de la party (red o local)
func leave_party() -> void:
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("leave_party"):
		nm.leave_party()
	# Limpiar localmente (slot 0 siempre es el jugador local)
	if members.size() > 1:
		members.resize(1)
		party_changed.emit()

## Callback: recibimos invitación de otro jugador
func _on_network_invite_received(from_name: String, from_peer_id: int) -> void:
	# Aquí emitimos señal para que la UI muestre el popup de aceptar/rechazar.
	# La UI debe llamar accept_network_invite(from_peer_id) o ignorarlo.
	# También conectamos a game_ui.gd para mostrar el diálogo.
	var gui = get_tree().get_first_node_in_group("game_ui")
	if gui and gui.has_method("show_party_invite_popup"):
		gui.show_party_invite_popup(from_name, from_peer_id)
	else:
		# Auto-aceptar si no hay UI disponible (modo debug)
		accept_network_invite(from_peer_id)

## Callback: el servidor notificó que la party cambió
func _on_party_updated_from_network() -> void:
	pass  # sync_from_network() lo llama NetworkManager directamente

## Sincronizar members[] con los datos reales que manda el servidor
func sync_from_network(member_ids: Array, member_names: Array, online_players: Dictionary) -> void:
	# Reconstruir members[] conservando slot 0 (jugador local)
	var local_entry = members[0] if members.size() > 0 else null
	members.clear()
	if local_entry:
		members.append(local_entry)

	var palette: Array = [
		Color(0.95, 0.45, 0.25),
		Color(0.55, 0.90, 0.35),
		Color(0.85, 0.30, 0.85),
	]
	var slot = 0
	var my_pid = 0
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		my_pid = nm.my_peer_id

	for i in range(member_ids.size()):
		var pid = member_ids[i]
		if pid == my_pid:
			continue  # ya está en slot 0
		var pdata = online_players.get(pid, {})
		var entry := {
			"id":      _next_id,
			"name":    member_names[i] if i < member_names.size() else pdata.get("name","???"),
			"hp":      pdata.get("hp", 100),
			"max_hp":  pdata.get("max_hp", 100),
			"color":   palette[clamp(slot, 0, palette.size() - 1)],
			"node":    null,
			"peer_id": pid,
			"is_real": true,
		}
		members.append(entry)
		_next_id += 1
		slot += 1

	party_changed.emit()

# ════════════════════════════════════════════════════════════
# INVITACIÓN SIMULADA (offline / compatibilidad)
# ════════════════════════════════════════════════════════════

func invite_by_name(companion_name: String) -> bool:
	# Si hay red activa, buscar jugador online con ese nombre
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.is_client:
		for pid in nm.online_players:
			if nm.online_players[pid].get("name","").to_lower() == companion_name.to_lower():
				invite_online_player(pid)
				return true
	# Fallback: companion simulado (offline)
	if members.size() >= MAX_MEMBERS:
		return false
	if companion_name.strip_edges() == "":
		return false
	for m in members:
		if m["name"].to_lower() == companion_name.to_lower():
			return false
	_add_simulated_member(companion_name)
	return true

func _add_simulated_member(cname: String) -> void:
	var palette: Array = [
		Color(0.95, 0.45, 0.25),
		Color(0.55, 0.90, 0.35),
		Color(0.85, 0.30, 0.85),
	]
	var slot_index: int = members.size()
	var col: Color = palette[clamp(slot_index - 1, 0, palette.size() - 1)]
	var base_hp: int = int(PlayerData.max_hp * randf_range(0.80, 1.20))
	base_hp = max(base_hp, 50)
	var entry := {
		"id":      _next_id,
		"name":    cname,
		"hp":      base_hp,
		"max_hp":  base_hp,
		"color":   col,
		"node":    null,
		"peer_id": -1,      # -1 = NPC simulado
		"is_real": false,
	}
	members.append(entry)
	_next_id += 1
	party_changed.emit()

func kick_member(member_id: int) -> void:
	if members.size() == 0:
		return
	if member_id == members[0]["id"]:
		return
	for i in range(members.size()):
		if members[i]["id"] == member_id:
			members.remove_at(i)
			party_changed.emit()
			return

func disband() -> void:
	if members.size() <= 1:
		members.clear()
		_register_local_player()
		return
	members.resize(1)
	party_changed.emit()
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("leave_party"):
		nm.leave_party()

func member_count() -> int:
	return members.size()

# ════════════════════════════════════════════════════════════
# XP COMPARTIDA (v22.2: solo ajuste local; red lo maneja NetworkManager)
# ════════════════════════════════════════════════════════════

func share_xp(base_xp: int, killer_position: Vector2) -> void:
	if members.size() <= 1:
		return

	var in_range: int = 1
	for i in range(1, members.size()):
		var m = members[i]
		if m["is_real"]:
			# Los peers reales reciben XP directo via NetworkManager._rpc_grant_xp
			# Solo contamos para el ajuste del líder
			in_range += 1
		elif m["node"] != null and is_instance_valid(m["node"]):
			if killer_position.distance_to(m["node"].global_position) <= SHARE_RADIUS:
				in_range += 1
		else:
			in_range += 1

	if in_range <= 1:
		return

	var xp_each: int = max(1, int(base_xp * SHARE_PENALTY / float(in_range)))
	var xp_leader_adj: int = xp_each - base_xp
	if xp_leader_adj != 0:
		PlayerData.gain_xp(xp_leader_adj)

	for i in range(1, members.size()):
		var m = members[i]
		if not m["is_real"]:
			_simulate_companion_xp(m, xp_each)
		if i == 1:
			_show_party_xp_text("+%d XP (×%d 👥)" % [xp_each, in_range], killer_position)

# ════════════════════════════════════════════════════════════
# HP DE MIEMBROS REALES (desde NetworkManager)
# ════════════════════════════════════════════════════════════

## Llamado cuando llega un update de posición/HP de un peer de la party
func update_member_hp_from_network(peer_id: int, hp: int, max_hp: int) -> void:
	for m in members:
		if m.get("peer_id") == peer_id:
			m["hp"]     = hp
			m["max_hp"] = max_hp
			member_hp_changed.emit(m["id"])
			return

# ════════════════════════════════════════════════════════════
# SIMULACIÓN DE COMPANIONS (offline)
# ════════════════════════════════════════════════════════════

func _process_sim(delta: float) -> void:
	for i in range(1, members.size()):
		var m = members[i]
		if m["is_real"]:
			continue
		# Pequeño regen/daño aleatorio para animar las barras
		if randf() < delta * 0.1:
			var change = randi_range(-3, 5)
			m["hp"] = clamp(m["hp"] + change, 1, m["max_hp"])
			member_hp_changed.emit(m["id"])

func _simulate_companion_xp(m: Dictionary, amount: int) -> void:
	var xp_fake: int = m.get("xp_accum", 0) + amount
	m["xp_accum"] = xp_fake
	if xp_fake > 500:
		m["xp_accum"] = 0
		m["max_hp"] = m["max_hp"] + 5
		if m["hp"] < m["max_hp"]:
			m["hp"] = m["hp"] + 5

func _show_party_xp_text(text: String, pos: Vector2) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	label.add_theme_font_size_override("font_size", 13)
	label.position = Vector2(-50, -70)
	label.z_index  = 100
	player.add_child(label)
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.finished.connect(func(): if is_instance_valid(label): label.queue_free())
