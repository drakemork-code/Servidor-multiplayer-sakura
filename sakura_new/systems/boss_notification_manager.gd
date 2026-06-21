# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# BOSS NOTIFICATION MANAGER — Autoload global
# Gestiona los cooldowns de respawn de los 4 bosses de zona
# y emite notificaciones cuando están disponibles.
# Integración con FCM (Firebase Cloud Messaging) via HTTP
# cuando el jugador está offline (stub — requiere plugin nativo).
# ============================================================

signal boss_available(zone: String, boss_data: Dictionary)
signal boss_defeated(zone: String, respawn_unix: int)
signal subscription_changed(zone: String, subscribed: bool)

const BOSS_COOLDOWN_SEC: float = 1800.0   # 30 minutos

# ── Definición de bosses ─────────────────────────────────────
const BOSS_DATA: Dictionary = {
	"north": {
		"name":     "Skeleton King",
		"level":    50,
		"zone_label": "el Norte",
		"emoji":    "☠",
		"drop_epic":    "Maza de Hueso Sagrado (T3 épico)",
		"drop_legend":  "drop legendario adicional (20-30%)",
		"color":    Color(0.75, 0.85, 1.0),
	},
	"south": {
		"name":     "Goblin Shaman",
		"level":    45,
		"zone_label": "el Sur",
		"emoji":    "🧿",
		"drop_epic":    "Báculo de la Luz Divina (T3 épico)",
		"drop_legend":  "Báculo del Serafín",
		"color":    Color(0.60, 1.0, 0.60),
	},
	"east": {
		"name":     "Orc Warlord",
		"level":    48,
		"zone_label": "el Este",
		"emoji":    "⚔",
		"drop_epic":    "Hacha del Señor Orco (T3 épico)",
		"drop_legend":  "Hacha del Apocalipsis",
		"color":    Color(1.0, 0.65, 0.25),
	},
	"west": {
		"name":     "Shadow Lord",
		"level":    50,
		"zone_label": "el Oeste",
		"emoji":    "🌑",
		"drop_epic":    "Arco de Plata (T3 épico)",
		"drop_legend":  "Arco del Vacío",
		"color":    Color(0.70, 0.45, 1.0),
	},
}

# ── Estado: muerte y respawn de cada boss ────────────────────
# { zone -> {death_unix, respawn_unix, alive} }
var boss_state: Dictionary = {}

# ── Suscripciones del jugador (qué zonas quiere notificación) ─
var subscriptions: Dictionary = {
	"north": true,
	"south": true,
	"east":  true,
	"west":  true,
}

var _timers: Dictionary = {}   # zone -> float (segundos restantes)

func _ready() -> void:
	_load_data()
	# Inicializar estado de zonas no guardadas
	for zone in BOSS_DATA:
		if not boss_state.has(zone):
			boss_state[zone] = {"death_unix": 0, "respawn_unix": 0, "alive": true}
	_start_pending_timers()
	print("[BossNotifManager] Inicializado — 4 bosses monitoreados")

func _process(delta: float) -> void:
	for zone in _timers.keys():
		_timers[zone] -= delta
		if _timers[zone] <= 0.0:
			_timers.erase(zone)
			_on_boss_respawned(zone)

# ──────────────────────────────────────────────
# REGISTRAR MUERTE DE BOSS (llamado desde boss_*.gd)
# ──────────────────────────────────────────────
func register_boss_death(zone: String) -> void:
	if not BOSS_DATA.has(zone):
		return
	var now = int(Time.get_unix_time_from_system())
	boss_state[zone] = {
		"death_unix":   now,
		"respawn_unix": now + int(BOSS_COOLDOWN_SEC),
		"alive":        false,
	}
	boss_defeated.emit(zone, now + int(BOSS_COOLDOWN_SEC))
	_timers[zone] = BOSS_COOLDOWN_SEC
	_save_data()
	print("[BossNotifManager] %s derrotado — respawn en 30 min" % BOSS_DATA[zone]["name"])

# ──────────────────────────────────────────────
# RESPAWN
# ──────────────────────────────────────────────
func _on_boss_respawned(zone: String) -> void:
	if not boss_state.has(zone):
		return
	boss_state[zone]["alive"] = true
	_save_data()

	var data = BOSS_DATA[zone]
	boss_available.emit(zone, data)

	if subscriptions.get(zone, true):
		_show_in_game_notification(zone, data)

	print("[BossNotifManager] %s disponible en %s" % [data["name"], data["zone_label"]])

func _show_in_game_notification(zone: String, data: Dictionary) -> void:
	var msg = "%s %s ha reaparecido en %s. Drop épico: %s" % [
		data["emoji"], data["name"], data["zone_label"], data["drop_epic"]
	]
	# Publicar en chat global
	if has_node("/root/ChatManager"):
		get_node("/root/ChatManager").receive_message("global", "Sistema", msg)
	# Mostrar en HUD si está disponible
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	for ui in ui_nodes:
		if ui.has_method("show_boss_notification"):
			ui.show_boss_notification(
				data["emoji"] + " " + data["name"],
				data["zone_label"],
				data["color"]
			)
			break

# ──────────────────────────────────────────────
# SUSCRIPCIONES
# ──────────────────────────────────────────────
func set_subscription(zone: String, enabled: bool) -> void:
	subscriptions[zone] = enabled
	subscription_changed.emit(zone, enabled)
	_save_data()

func is_subscribed(zone: String) -> bool:
	return subscriptions.get(zone, true)

# ──────────────────────────────────────────────
# CONSULTAS
# ──────────────────────────────────────────────
func is_boss_alive(zone: String) -> bool:
	return boss_state.get(zone, {"alive": true})["alive"]

func get_respawn_remaining(zone: String) -> float:
	return _timers.get(zone, 0.0)

func get_respawn_text(zone: String) -> String:
	var remaining = get_respawn_remaining(zone)
	if remaining <= 0.0:
		return "DISPONIBLE"
	var mins = int(remaining / 60)
	var secs = int(remaining) % 60
	return "%02d:%02d" % [mins, secs]

# ──────────────────────────────────────────────
# GUARDAR / CARGAR
# ──────────────────────────────────────────────
func _start_pending_timers() -> void:
	var now = int(Time.get_unix_time_from_system())
	for zone in boss_state:
		var st = boss_state[zone]
		if not st["alive"] and st["respawn_unix"] > now:
			var remaining = float(st["respawn_unix"] - now)
			_timers[zone] = remaining
		elif not st["alive"] and st["respawn_unix"] <= now and st["respawn_unix"] != 0:
			# Ya debería haber respawneado
			boss_state[zone]["alive"] = true

func _save_data() -> void:
	var data = {"boss_state": boss_state, "subscriptions": subscriptions}
	var f = FileAccess.open("user://boss_notif.save", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func _load_data() -> void:
	if not FileAccess.file_exists("user://boss_notif.save"):
		return
	var f = FileAccess.open("user://boss_notif.save", FileAccess.READ)
	if not f:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data:
		return
	boss_state    = data.get("boss_state",    {})
	subscriptions = data.get("subscriptions", {"north":true,"south":true,"east":true,"west":true})
