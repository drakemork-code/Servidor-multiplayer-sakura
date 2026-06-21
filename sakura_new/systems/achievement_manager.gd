# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# ACHIEVEMENT MANAGER — Autoload global
# Logros sandbox que reemplazan las misiones lineales.
# Categorías: Combate, Recolección, Crafteo, Social, Economía
# ============================================================

signal achievement_unlocked(achievement_id: String, data: Dictionary)
signal progress_updated(achievement_id: String, current: int, target: int)

# ── Definición de logros ─────────────────────────────────────
# Cada logro: { id, name, desc, category, target, reward_title, reward_bronze }
const ACHIEVEMENTS: Array = [
	# COMBATE
	{"id":"kill_first",    "name":"Primera Sangre",       "desc":"Mata tu primer enemigo",         "cat":"combate",     "target":1,    "title":"Aprendiz Guerrero", "bronze":50},
	{"id":"kill_100",      "name":"Carnicero",            "desc":"Mata 100 enemigos",               "cat":"combate",     "target":100,  "title":"Carnicero",         "bronze":200},
	{"id":"kill_500",      "name":"Azote del Mundo",      "desc":"Mata 500 enemigos",               "cat":"combate",     "target":500,  "title":"Azote del Mundo",   "bronze":500},
	{"id":"boss_first",    "name":"Cazador de Jefes",     "desc":"Derrota tu primer boss de zona",  "cat":"combate",     "target":1,    "title":"Cazabosses",        "bronze":300},
	{"id":"boss_all_four", "name":"El Que Todo lo Venció","desc":"Derrota los 4 bosses de zona",   "cat":"combate",     "target":4,    "title":"Campeón del Mundo", "bronze":1000},
	{"id":"reach_lv30",    "name":"Veterano",             "desc":"Alcanza nivel 30",                "cat":"combate",     "target":30,   "title":"Veterano",          "bronze":400},
	{"id":"reach_lv50",    "name":"Leyenda Viviente",     "desc":"Alcanza el nivel máximo 50",      "cat":"combate",     "target":50,   "title":"Leyenda",           "bronze":2000},

	# RECOLECCIÓN
	{"id":"mining_5",      "name":"Minero Experto",       "desc":"Alcanza nivel 5 en Minería",      "cat":"recoleccion", "target":5,    "title":"Minero",            "bronze":100},
	{"id":"herbalism_10",  "name":"Herbolario Maestro",   "desc":"Alcanza nivel 10 en Herbolaria",  "cat":"recoleccion", "target":10,   "title":"Herbolario",        "bronze":200},
	{"id":"gather_500",    "name":"Recolector Nato",      "desc":"Recolecta 500 recursos en total", "cat":"recoleccion", "target":500,  "title":"Recolector",        "bronze":300},
	{"id":"woodcut_5",     "name":"Leñador",              "desc":"Alcanza nivel 5 en Tala",         "cat":"recoleccion", "target":5,    "title":"Leñador",           "bronze":100},

	# CRAFTEO
	{"id":"craft_first",   "name":"Artesano",             "desc":"Fabrica tu primera pieza de equipo","cat":"crafteo",  "target":1,    "title":"Artesano",          "bronze":100},
	{"id":"craft_rare",    "name":"Maestro Artesano",     "desc":"Fabrica un ítem de calidad Raro+","cat":"crafteo",   "target":1,    "title":"Maestro Artesano",  "bronze":400},
	{"id":"smithing_10",   "name":"Herrero Experto",      "desc":"Alcanza nivel 10 en Herrería",    "cat":"crafteo",   "target":10,   "title":"Herrero",           "bronze":200},

	# SOCIAL
	{"id":"join_guild",    "name":"Hermandad",            "desc":"Únete a un gremio",               "cat":"social",     "target":1,    "title":"Hermano de Gremio", "bronze":100},
	{"id":"group_boss",    "name":"Fuerza de Grupo",      "desc":"Completa un boss en grupo de 3+", "cat":"social",     "target":1,    "title":"Compañero",         "bronze":300},

	# ECONOMÍA
	{"id":"sell_first",    "name":"Comerciante",          "desc":"Vende tu primer ítem en la subasta","cat":"economia","target":1,    "title":"Comerciante",       "bronze":100},
	{"id":"earn_1000",     "name":"Acaudalado",           "desc":"Acumula 1000 monedas de plata",   "cat":"economia",   "target":100000,"title":"Noble",            "bronze":500},
]

# ── Estado: progreso por logro ───────────────────────────────
var progress: Dictionary = {}   # id -> {current, unlocked}

func _ready() -> void:
	_load_data()
	# Inicializar entradas faltantes
	for ach in ACHIEVEMENTS:
		if not progress.has(ach["id"]):
			progress[ach["id"]] = {"current": 0, "unlocked": false}
	print("[AchievementManager] Cargados %d logros" % ACHIEVEMENTS.size())

# ──────────────────────────────────────────────
# EVENTOS EXTERNOS — llamar desde otros sistemas
# ──────────────────────────────────────────────
func on_enemy_killed() -> void:
	_increment("kill_first",  1)
	_increment("kill_100",    1)
	_increment("kill_500",    1)

func on_boss_killed(zone: String) -> void:
	_increment("boss_first",    1)
	_increment("boss_all_four", 1)

func on_level_up(new_level: int) -> void:
	_set_if_greater("reach_lv30", new_level, 30)
	_set_if_greater("reach_lv50", new_level, 50)

func on_resource_gathered(qty: int = 1) -> void:
	_increment("gather_500", qty)

func on_gathering_level_up(skill: String, new_lv: int) -> void:
	match skill:
		"mining":      _set_if_greater("mining_5",   new_lv, 5)
		"herbalism":   _set_if_greater("herbalism_10", new_lv, 10)
		"woodcutting": _set_if_greater("woodcut_5",  new_lv, 5)

func on_crafting_level_up(skill: String, new_lv: int) -> void:
	match skill:
		"smithing": _set_if_greater("smithing_10", new_lv, 10)

func on_item_crafted(quality: String = "common") -> void:
	_increment("craft_first", 1)
	if quality in ["rare", "epic", "legendary"]:
		_increment("craft_rare", 1)

func on_item_sold_auction() -> void:
	_increment("sell_first", 1)

func on_currency_changed(total_bronze: int) -> void:
	_set_if_greater("earn_1000", total_bronze, 100000)

func on_guild_joined() -> void:
	_increment("join_guild", 1)

func on_group_boss_killed(member_count: int) -> void:
	if member_count >= 3:
		_increment("group_boss", 1)

# ──────────────────────────────────────────────
# CONSULTAS
# ──────────────────────────────────────────────
func get_all() -> Array:
	return ACHIEVEMENTS

func get_progress(id: String) -> Dictionary:
	return progress.get(id, {"current": 0, "unlocked": false})

func get_unlocked_count() -> int:
	var count = 0
	for id in progress:
		if progress[id]["unlocked"]:
			count += 1
	return count

func get_unlocked_titles() -> Array:
	var titles: Array = []
	for ach in ACHIEVEMENTS:
		if progress.get(ach["id"], {}).get("unlocked", false):
			titles.append(ach.get("title", ""))
	return titles

# ──────────────────────────────────────────────
# INTERNOS
# ──────────────────────────────────────────────
func _increment(id: String, amount: int) -> void:
	var p = progress.get(id, {"current": 0, "unlocked": false})
	if p["unlocked"]:
		return
	p["current"] = p["current"] + amount
	progress[id] = p
	var ach = _find_ach(id)
	if ach and p["current"] >= ach["target"]:
		_unlock(id, ach)
	else:
		progress_updated.emit(id, p["current"], ach["target"] if ach else 1)
	_save_data()

func _set_if_greater(id: String, value: int, target: int) -> void:
	var p = progress.get(id, {"current": 0, "unlocked": false})
	if p["unlocked"]:
		return
	if value > p["current"]:
		p["current"] = value
		progress[id] = p
	if p["current"] >= target:
		var ach = _find_ach(id)
		if ach:
			_unlock(id, ach)
	_save_data()

func _unlock(id: String, ach: Dictionary) -> void:
	progress[id]["unlocked"] = true
	achievement_unlocked.emit(id, ach)
	# Dar recompensa
	if PlayerData and ach.get("bronze", 0) > 0:
		PlayerData.add_bronze(ach["bronze"])
	print("[AchievementManager] ¡LOGRO DESBLOQUEADO! ", ach["name"])

func _find_ach(id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a["id"] == id:
			return a
	return {}

func _save_data() -> void:
	var f = FileAccess.open("user://achievements.save", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(progress))
		f.close()

func _load_data() -> void:
	if not FileAccess.file_exists("user://achievements.save"):
		return
	var f = FileAccess.open("user://achievements.save", FileAccess.READ)
	if not f:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data and typeof(data) == TYPE_DICTIONARY:
		progress = data
