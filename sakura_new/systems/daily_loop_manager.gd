# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# DAILY LOOP MANAGER — Autoload global
# • Recompensa por login diario (streak hasta día 7)
# • Evento semanal rotativo
# ============================================================

signal daily_reward_available(day: int)
signal daily_reward_claimed(day: int, rewards: Array)
signal weekly_event_changed(event_name: String, event_desc: String)

# ── Recompensas por día ──────────────────────────────────────
const DAY_REWARDS: Dictionary = {
	1: [{"item": "coin_bronze",   "qty": 50,  "label": "50 monedas de bronce"}],
	2: [{"item": "material_herb", "qty": 5,   "label": "5 Hierbas (T1)"},
		{"item": "ore_iron_t1",   "qty": 3,   "label": "3 Mineral de Hierro (T1)"}],
	3: [{"item": "xp_potion",     "qty": 1,   "label": "Poción de XP"}],
	4: [{"item": "coin_bronze",   "qty": 150, "label": "150 monedas de bronce"},
		{"item": "material_bone", "qty": 5,   "label": "5 Huesos"}],
	5: [{"item": "crystal_shard", "qty": 3,   "label": "3 Cristales"}],
	6: [{"item": "coin_bronze",   "qty": 300, "label": "300 monedas de bronce"}],
	7: [{"item": "chest_rare",    "qty": 1,   "label": "¡Cofre de calidad RARO garantizado!"}],
}

const STREAK_MAX_HOURS: float = 36.0   # horas antes de romper racha

# ── Eventos semanales (rotativos por número de semana) ───────
const WEEKLY_EVENTS: Array = [
	{"name": "Semana de la Forja",   "desc": "+20% XP de Herrería esta semana", "bonus_skill": "smithing",   "bonus_xp": 0.20},
	{"name": "Caza del Tesoro",      "desc": "Cofres especiales en zonas PvE",  "bonus_skill": "",            "bonus_xp": 0.0},
	{"name": "Festival de Herbología","desc": "+20% XP de Herbolaria",           "bonus_skill": "herbalism",  "bonus_xp": 0.20},
	{"name": "Asedio",               "desc": "Zona PvP activa con recompensa de gremio", "bonus_skill": "", "bonus_xp": 0.0},
	{"name": "Luna de Minería",      "desc": "+25% XP de Minería",              "bonus_skill": "mining",     "bonus_xp": 0.25},
	{"name": "Gran Mercado",         "desc": "-10% comisión en la subasta",      "bonus_skill": "",            "bonus_xp": 0.0, "auction_discount": 0.10},
]

# ── Estado ───────────────────────────────────────────────────
var login_streak:      int    = 0
var last_login_unix:   int    = 0
var last_claim_day:    int    = 0   # día (1-7) del ciclo actual reclamado
var reward_pending:    bool   = false
var current_week_event: Dictionary = {}

func _ready() -> void:
	_load_data()
	_check_login()
	_update_weekly_event()
	print("[DailyLoop] Racha: %d días | Evento: %s" % [login_streak, current_week_event.get("name","?")])

# ──────────────────────────────────────────────
# LOGIN / RACHA
# ──────────────────────────────────────────────
func _check_login() -> void:
	var now = int(Time.get_unix_time_from_system())
	var hours_since = float(now - last_login_unix) / 3600.0

	if last_login_unix == 0:
		# Primera vez
		login_streak  = 1
		reward_pending = true
	elif hours_since < 20.0:
		# Mismo día (menos de 20h) — sin nueva recompensa
		reward_pending = false
	elif hours_since <= STREAK_MAX_HOURS:
		# Nuevo día, racha sigue
		login_streak = clamp(login_streak + 1, 1, 7)
		reward_pending = true
	else:
		# Racha rota
		login_streak  = 1
		reward_pending = true

	last_login_unix = now
	_save_data()

	if reward_pending:
		daily_reward_available.emit(login_streak)

func get_streak() -> int:
	return login_streak

func is_reward_pending() -> bool:
	return reward_pending

# ──────────────────────────────────────────────
# RECLAMAR RECOMPENSA
# ──────────────────────────────────────────────
func claim_daily_reward() -> Array:
	if not reward_pending:
		return []
	reward_pending = false
	last_claim_day = login_streak

	var rewards = DAY_REWARDS.get(login_streak, DAY_REWARDS[1])
	_give_rewards(rewards)
	daily_reward_claimed.emit(login_streak, rewards)
	_save_data()
	return rewards

func _give_rewards(rewards: Array) -> void:
	for r in rewards:
		match r["item"]:
			"coin_bronze":
				if PlayerData:
					PlayerData.add_bronze(r["qty"])
			"xp_potion":
				if PlayerData:
					PlayerData.gain_xp(500 * PlayerData.level)
			_:
				# Intentar añadir al inventario
				if has_node("/root/InventoryManager"):
					get_node("/root/InventoryManager").add_item(r["item"], r["qty"])

# ──────────────────────────────────────────────
# EVENTO SEMANAL
# ──────────────────────────────────────────────
func _update_weekly_event() -> void:
	var week_num = int(Time.get_unix_time_from_system() / (7 * 86400))
	var idx = week_num % WEEKLY_EVENTS.size()
	current_week_event = WEEKLY_EVENTS[idx]
	weekly_event_changed.emit(current_week_event["name"], current_week_event["desc"])

func get_weekly_event() -> Dictionary:
	return current_week_event

## Devuelve el multiplicador de XP para una skill según el evento activo
func get_skill_xp_bonus(skill: String) -> float:
	if current_week_event.get("bonus_skill", "") == skill:
		return 1.0 + current_week_event.get("bonus_xp", 0.0)
	return 1.0

# ──────────────────────────────────────────────
# GUARDAR / CARGAR
# ──────────────────────────────────────────────
func _save_data() -> void:
	var data = {
		"streak":        login_streak,
		"last_login":    last_login_unix,
		"last_claim":    last_claim_day,
		"pending":       reward_pending,
	}
	var f = FileAccess.open("user://daily_loop.save", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func _load_data() -> void:
	if not FileAccess.file_exists("user://daily_loop.save"):
		return
	var f = FileAccess.open("user://daily_loop.save", FileAccess.READ)
	if not f:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data:
		return
	login_streak   = data.get("streak", 0)
	last_login_unix= data.get("last_login", 0)
	last_claim_day = data.get("last_claim", 0)
	reward_pending = data.get("pending", false)
