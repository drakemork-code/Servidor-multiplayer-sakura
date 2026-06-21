# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# PLAYER DATA — Autoload global
# Stats, XP, nivel, energía, monedas (bronce/plata/oro),
# habilidades de recolección Y crafteo, guardar/cargar
# ============================================================

signal health_changed(new_hp: int, max_hp: int)
signal energy_changed(new_energy: float, max_energy: int)
signal xp_gained(amount: int)
signal level_up(new_level: int)
signal stat_updated()
signal player_died()
signal player_respawned()
signal currency_changed()
signal gathering_skill_changed(skill: String, new_level: int)
signal crafting_skill_changed(skill: String, new_level: int)

# ── Identidad ──────────────────────────────
var character_name: String = "Aventurero"
var character_gender: String = "male"  # "male" | "female"

# ── Apariencia ─────────────────────────────
var race: String       = "human"        # "human" | "elf" | "ogre" | "tauren"
var hair_style: String = "spikeyhair"   # bowlhair|curlyhair|longhair|mophair|shorthair|spikeyhair
var skin_color: Color  = Color(0.96, 0.78, 0.64)
var hair_color: Color  = Color(0.25, 0.15, 0.08)
var eye_color: Color   = Color(0.2, 0.5, 0.9)
var outfit_color: Color = Color(1.0, 1.0, 1.0)

# ── Progresión ─────────────────────────────
var level: int = 1
var xp: int = 0
const MAX_LEVEL: int = 50

# ── HP ─────────────────────────────────────
var hp: int = 100
var max_hp: int = 100

# ── Energía ────────────────────────────────
var energy: float = 50.0
var max_energy: int = 50

# ── Movimiento y combate ───────────────────
var speed: int = 130
var base_attack: int = 8
var base_defense: int = 2

# ── Estado ─────────────────────────────────
var is_dodging: bool = false
var is_dead: bool = false
var dodge_cooldown_remaining: float = 0.0

# ── Tutorial ───────────────────────────────
var tutorial_done: bool = false

# ── BUG B FIX: guardado diferido para evitar micro-stutters ──
# save_character_data() ya NO se llama por cada moneda recogida.
# En su lugar, se usa un timer de 30 s o al cambiar de escena.
var _pending_save: bool = false
var _save_cooldown_timer: float = 0.0
const SAVE_COOLDOWN_SEC: float = 30.0

# ── Server save periódico (monedas y stats al servidor cada 60 s) ──
var _server_save_timer: float = 0.0
const SERVER_SAVE_INTERVAL_SEC: float = 60.0
var _pending_server_save: bool = false

# Callback para guardar en servidor (lo asigna main_menu al entrar al juego)
var server_save_callback: Callable = Callable()

# ── Equipment stats (calculados por InventoryManager) ─
var equipment_defense: int = 0
var equipment_attack: int = 0
var pvp_equipment_attack: int  = 0
var pvp_equipment_defense: int = 0
var bonus_max_hp_gear: int       = 0
var bonus_speed_pct_gear: int    = 0
var bonus_crit_pct_gear: int     = 0
var bonus_dmg_red_pct_gear: int  = 0
var bonus_regen_gear: int        = 0
var bonus_heal_pct_gear: int     = 0

# ── DrakeDev mode ──────────────────────────
var is_drake_dev: bool = false

# ── Monedas ────────────────────────────────
var bronze: int = 0
var silver: int = 0
var gold:   int = 0

# ── Curandera / curación NPC ──────────────────
# v26: la primera curación con la Curandera es gratis. Luego de
# usarla, se cobra una tarifa en bronce, o se puede esperar el
# cooldown para curarse gratis de nuevo.
var healer_free_heal_used : bool = false
var healer_last_heal_unix : int  = 0
const HEALER_COOLDOWN_SECONDS : int = 600
const HEALER_COST_BRONZE      : int = 50

func can_use_free_heal() -> bool:
	return not healer_free_heal_used

func healer_cooldown_remaining() -> int:
	if healer_last_heal_unix == 0:
		return 0
	var elapsed = Time.get_unix_time_from_system() - healer_last_heal_unix
	return int(max(0, HEALER_COOLDOWN_SECONDS - elapsed))

func can_use_free_cooldown_heal() -> bool:
	return healer_cooldown_remaining() <= 0

func register_healer_use(was_free: bool) -> void:
	if not was_free:
		healer_free_heal_used = true
	healer_last_heal_unix = Time.get_unix_time_from_system()
	save_character_data()

func add_gold(amount: int) -> void:
	if amount >= 0:
		add_bronze(amount)
	else:
		spend_bronze(-amount)

func spend_gold(amount: int) -> bool:
	return spend_bronze(amount)

# ──────────────────────────────────────────────
# HABILIDADES DE RECOLECCIÓN
# ──────────────────────────────────────────────
const GATHERING_XP_PER_LEVEL: Array = [
	0, 80, 180, 320, 500, 730, 1010, 1350, 1760, 2250,
	2830, 3500, 4270, 5150,
]
const GATHERING_MAX_LEVEL: int = 15
const GATHERING_TIER_MIN_LEVEL: Dictionary = { 1: 1, 2: 5, 3: 10 }

var gathering_skills: Dictionary = {
	"mining":      {"xp": 0, "level": 1},
	"woodcutting": {"xp": 0, "level": 1},
	"herbalism":   {"xp": 0, "level": 1},
}

# ──────────────────────────────────────────────
# HABILIDADES DE CRAFTEO
# ──────────────────────────────────────────────
const CRAFTING_XP_PER_LEVEL: Array = [
	0, 100, 220, 380, 600, 880, 1220, 1620, 2100, 2680,
	3360, 4150, 5060, 6100,
]
const CRAFTING_MAX_LEVEL: int = 15

var crafting_skills: Dictionary = {
	"smithing":  {"xp": 0, "level": 1},
	"tailoring": {"xp": 0, "level": 1},
	"alchemy":   {"xp": 0, "level": 1},
}

func _ready() -> void:
	load_character_data()
	if character_name == "DrakeDev":
		activate_drake_mode()
	print("[PlayerData] Cargado: ", character_name, " Nv.", level, " Raza:", race)
	# ── v22.2: conectar server_save_callback automáticamente ──
	call_deferred("_connect_server_save")

# BUG B FIX: timer diferido — guarda cada 30 s si hay cambios pendientes
func _notification(what: int) -> void:
	# Guardar al cerrar la app en Android/iOS (botón X del sistema)
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush_pending_save()
		save_character_data()
		flush_pending_server_save()
	# Botón Atrás de Android: mostrar diálogo de confirmación en vez de salir directo
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_show_exit_dialog()

func _process(delta: float) -> void:
	# Guardado local diferido
	if _pending_save:
		_save_cooldown_timer += delta
		if _save_cooldown_timer >= SAVE_COOLDOWN_SEC:
			_pending_save = false
			_save_cooldown_timer = 0.0
			save_character_data()

	# FIX MONEDAS: guardado en servidor periódico (cada 60 s si hay cambios)
	if _pending_server_save and server_save_callback.is_valid():
		_server_save_timer += delta
		if _server_save_timer >= SERVER_SAVE_INTERVAL_SEC:
			_pending_server_save = false
			_server_save_timer = 0.0
			server_save_callback.call()

# Llamar esto al cambiar de escena para garantizar que no se pierdan datos
func flush_pending_save() -> void:
	if _pending_save:
		_pending_save = false
		_save_cooldown_timer = 0.0
		save_character_data()

# ── v22.2: conectar automáticamente al NetworkManager ─────────
# Los saves van exclusivamente a Firestore via el auth server (repo 1).
# El servidor Godot (repo 2) no maneja persistencia.
func _connect_server_save() -> void:
	pass  # No conectar — saves via Firestore únicamente

func _push_save_via_network() -> void:
	pass  # No usado — saves via Firestore únicamente

func _build_save_dict() -> Dictionary:
	# ── Gathering skills ──
	var gs: Dictionary = {}
	for k in gathering_skills:
		gs[k] = { "level": gathering_skills[k]["level"], "xp": gathering_skills[k]["xp"] }

	# ── Crafting skills ──
	var cs: Dictionary = {}
	for k in crafting_skills:
		cs[k] = { "level": crafting_skills[k]["level"], "xp": crafting_skills[k]["xp"] }

	return {
		# Identidad y apariencia
		"name":      character_name,
		"gender":    character_gender,
		"race":      race,
		"hair_style": hair_style,
		"skin_r": skin_color.r, "skin_g": skin_color.g, "skin_b": skin_color.b,
		"hair_r": hair_color.r, "hair_g": hair_color.g, "hair_b": hair_color.b,
		"eye_r":  eye_color.r,  "eye_g":  eye_color.g,  "eye_b":  eye_color.b,
		"outfit_r": outfit_color.r, "outfit_g": outfit_color.g, "outfit_b": outfit_color.b,
		# Progresión
		"level":       level,
		"xp":          xp,
		"max_hp":      max_hp,
		"hp":          hp,
		"max_energy":  max_energy,
		"energy":      int(energy),
		"speed":       speed,
		"base_attack": base_attack,
		"tutorial_done": tutorial_done,
		# Monedas
		"bronze": bronze,
		"silver": silver,
		"gold":   gold,
		# Profesiones
		"gathering_skills": gs,
		"crafting_skills":  cs,
	}
# ──────────────────────────────────────────────────────────────

# Forzar guardado en servidor inmediato (al cambiar de escena o cerrar)
func flush_pending_server_save() -> void:
	if server_save_callback.is_valid():
		_pending_server_save = false
		_server_save_timer = 0.0
		server_save_callback.call()

# ──────────────────────────────────────────────
# GUARDAR / CARGAR
# ──────────────────────────────────────────────
func load_character_data() -> void:
	if not FileAccess.file_exists("user://character.save"):
		return
	var file = FileAccess.open("user://character.save", FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data or typeof(data) != TYPE_DICTIONARY:
		return

	character_name   = data.get("name", "Aventurero")
	character_gender = data.get("gender", "male")
	race             = data.get("race", "human")
	hair_style       = data.get("hair_style", "spikeyhair")
	skin_color       = Color(data.get("skin_r", 0.96), data.get("skin_g", 0.78), data.get("skin_b", 0.64))
	hair_color       = Color(data.get("hair_r", 0.25), data.get("hair_g", 0.15), data.get("hair_b", 0.08))
	eye_color        = Color(data.get("eye_r", 0.2),  data.get("eye_g", 0.5),  data.get("eye_b", 0.9))
	outfit_color     = Color(data.get("outfit_r", 1.0), data.get("outfit_g", 1.0), data.get("outfit_b", 1.0))
	tutorial_done    = data.get("tutorial_done", false)
	level            = data.get("level", 1)
	xp               = data.get("xp", 0)
	max_hp           = data.get("max_hp", 100)
	hp               = data.get("hp", max_hp)
	max_energy       = data.get("max_energy", 50)
	energy           = float(data.get("energy", max_energy))
	speed            = data.get("speed", 130)
	base_attack      = data.get("base_attack", 8)
	bronze           = data.get("bronze", 0)
	silver           = data.get("silver", 0)
	gold             = data.get("gold", 0)
	healer_free_heal_used = data.get("healer_free_heal_used", false)
	healer_last_heal_unix = data.get("healer_last_heal_unix", 0)

	if data.has("gathering_skills"):
		var gs = data["gathering_skills"]
		for key in gathering_skills:
			if gs.has(key):
				gathering_skills[key]["level"] = gs[key].get("level", 1)
				gathering_skills[key]["xp"]    = gs[key].get("xp", 0)

	if data.has("crafting_skills"):
		var cs = data["crafting_skills"]
		for key in crafting_skills:
			if cs.has(key):
				crafting_skills[key]["level"] = cs[key].get("level", 1)
				crafting_skills[key]["xp"]    = cs[key].get("xp", 0)

var active_slot_index: int = -1

func save_character_data() -> void:
	var gs_data: Dictionary = {}
	for key in gathering_skills:
		gs_data[key] = { "level": gathering_skills[key]["level"], "xp": gathering_skills[key]["xp"] }

	var cs_data: Dictionary = {}
	for key in crafting_skills:
		cs_data[key] = { "level": crafting_skills[key]["level"], "xp": crafting_skills[key]["xp"] }

	# FIX 3: Serializar equipamiento para persistencia
	var equipped_data: Dictionary = {}
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and "equipped_items" in inv:
		for slot in inv.equipped_items:
			var item = inv.equipped_items[slot]
			if item != null:
				equipped_data[slot] = item if item is Dictionary else { "key": str(item) }

	var data: Dictionary = {
		"tutorial_done": tutorial_done,
		"name":        character_name,
		"gender":      character_gender,
		"race":        race,
		"hair_style":  hair_style,
		"skin_r": skin_color.r, "skin_g": skin_color.g, "skin_b": skin_color.b,
		"hair_r": hair_color.r, "hair_g": hair_color.g, "hair_b": hair_color.b,
		"eye_r":  eye_color.r,  "eye_g":  eye_color.g,  "eye_b":  eye_color.b,
		"outfit_r": outfit_color.r, "outfit_g": outfit_color.g, "outfit_b": outfit_color.b,
		"level":       level,
		"xp":          xp,
		"max_hp":      max_hp,
		"hp":          hp,
		"max_energy":  max_energy,
		"energy":      int(energy),
		"speed":       speed,
		"base_attack": base_attack,
		"bronze":      bronze,
		"silver":      silver,
		"gold":        gold,
		"healer_free_heal_used": healer_free_heal_used,
		"healer_last_heal_unix": healer_last_heal_unix,
		"gathering_skills": gs_data,
		"crafting_skills":  cs_data,
		"equipped_items":   equipped_data,
	}

	# FIX 3b: También disparar guardado del inventario antes de escribir
	if inv and inv.has_method("save_inventory"):
		inv.save_inventory()

	var file = FileAccess.open("user://character.save", FileAccess.WRITE)
	if not file:
		push_error("[PlayerData] No se pudo guardar")
		return
	file.store_string(JSON.stringify(data))
	file.close()

# ──────────────────────────────────────────────
# MODO DIOS (DrakeDev)
# ──────────────────────────────────────────────
func activate_drake_mode() -> void:
	is_drake_dev   = true
	level          = 50
	max_hp         = 99999
	hp             = 99999
	max_energy     = 999
	energy         = 999.0
	speed          = 220
	base_attack    = 9999
	bronze         = 99999
	silver         = 999
	gold           = 99
	character_name = "👑 DrakeDev"
	for key in gathering_skills:
		gathering_skills[key]["level"] = GATHERING_MAX_LEVEL
		gathering_skills[key]["xp"]    = 0
	for key in crafting_skills:
		crafting_skills[key]["level"] = CRAFTING_MAX_LEVEL
		crafting_skills[key]["xp"]    = 0
	print("[PlayerData] ===== MODO DIOS ACTIVADO =====")

# ──────────────────────────────────────────────
# PROGRESIÓN
# ──────────────────────────────────────────────
func get_xp_to_next_level() -> int:
	# Curva ajustada para 50 niveles: 200 * lv^2.4
	# Lv 1->2 ~200 XP | Lv 20->21 ~265k | Lv 49->50 ~2.3M
	if level >= MAX_LEVEL:
		return 999999999
	return int(200.0 * pow(float(level), 2.4))

func gain_xp(amount: int) -> void:
	if amount <= 0:
		return   # FIX: ignorar negativos (share_xp de party puede enviar negativos)
	if level >= MAX_LEVEL:
		return
	xp += amount
	xp_gained.emit(amount)
	while xp >= get_xp_to_next_level() and level < MAX_LEVEL:
		xp -= get_xp_to_next_level()
		_do_level_up()

func _do_level_up() -> void:
	level       = min(MAX_LEVEL, level + 1)
	# Vibración al subir de nivel
	var _pm = get_node_or_null("/root/PermissionManager")
	if _pm: _pm.vibrate_level()
	# HP: +15 por nivel (nivel 1=100, nivel 50=835)
	max_hp      += 15
	hp          = max_hp
	# Energía: +5 por nivel (nivel 1=50, nivel 50=295)
	max_energy  += 5
	energy      = float(max_energy)
	# Velocidad: base 130 + nivel*1.0, tope 180 en nivel 50
	speed       = 130 + int(level * 1.0)
	# Ataque base: escala más pronunciada hasta nivel 50
	base_attack = 8 + level * 3
	level_up.emit(level)
	stat_updated.emit()
	save_character_data()
	print("[PlayerData] ¡NIVEL ", level, "!")
	# Logro de nivel
	if Engine.has_singleton("AchievementManager") or has_node("/root/AchievementManager"):
		var am = get_node_or_null("/root/AchievementManager")
		if am: am.on_level_up(level)

# ──────────────────────────────────────────────
# SALUD
# ──────────────────────────────────────────────
func take_damage(amount: int) -> void:
	if is_drake_dev or is_dodging or is_dead:
		return
	var base_def  = int(level * 0.8)
	var total_def = equipment_defense + base_def
	var def_block = int(total_def * 0.38)
	var final_dmg = max(1, amount - def_block)
	hp = max(0, hp - final_dmg)
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()

func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	player_died.emit()
	print("[PlayerData] Jugador muerto. Aplicando penalizaciones y regresando al lobby en 2s...")

	# ── MEJORA 7: PENALIZACIONES POR MUERTE ──────────────────────
	_apply_death_penalties()
	# ─────────────────────────────────────────────────────────────

	await get_tree().create_timer(2.0).timeout
	respawn()
	save_character_data()
	if GameManager:
		GameManager.change_scene("res://scenes/town.tscn", {})
	else:
		get_tree().change_scene_to_file("res://scenes/town.tscn")


# ── MEJORA 7: lógica de penalización ─────────────────────────────────────────
func _apply_death_penalties() -> void:
	# 1) PÉRDIDA DE XP: 7% del XP necesario para el nivel actual
	#    (no se pierde si el jugador está en nivel 1 o en nivel máximo)
	if level > 1 and level < MAX_LEVEL:
		var xp_needed  : int = get_xp_to_next_level()
		var xp_loss    : int = int(xp_needed * 0.07)
		# Descontamos del XP acumulado en el nivel; no se baja de nivel
		xp = max(0, xp - xp_loss)
		xp_gained.emit(-xp_loss)   # valor negativo → la UI puede mostrarlo en rojo
		print("[PlayerData] Penalización XP: -%d XP (7%% del nivel %d)" % [xp_loss, level])

	# 2) PENALIZACIÓN DE DURABILIDAD: -15% (mín. 1) en cada pieza equipada
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		# Fallback: buscar en el árbol por nombre de clase
		for n in get_tree().get_nodes_in_group("autoload"):
			if n.name == "InventoryManager":
				inv = n
				break
	if inv == null:
		push_warning("[PlayerData] _apply_death_penalties: InventoryManager no encontrado")
		return

	var slots: Array = ["weapon", "helmet", "chest", "legs", "boots", "gloves"]
	for slot in slots:
		if not inv.equipped_items.has(slot):
			continue
		var item = inv.equipped_items[slot]
		if item == null or not item.has("durability"):
			continue
		var max_dur: int = item.get("max_durability", 100)
		var loss   : int = max(1, int(max_dur * 0.15))
		item["durability"] = max(0, item["durability"] - loss)
		inv.equipped_items[slot] = item
		print("[PlayerData] Durabilidad -%d en %s (%s): %d/%d" % [
			loss, slot, item.get("name","?"), item["durability"], max_dur])

	# Notificar al UI que el equipo cambió
	if inv.has_signal("item_equipped"):
		# Re-emitir los ítems equipados para que la UI refresque las barras
		for slot in slots:
			var item = inv.equipped_items.get(slot, null)
			if item != null:
				inv.item_equipped.emit(item)

func respawn() -> void:
	is_dead = false
	# v26: reapareces con 10% HP — busca la Curandera en el pueblo
	hp      = max(1, int(max_hp * 0.10))
	energy  = float(max_energy)
	health_changed.emit(hp, max_hp)
	player_respawned.emit()
	print("[PlayerData] Respawn en lobby — vida mínima, busca curación")

# ──────────────────────────────────────────────
# ENERGÍA
# ──────────────────────────────────────────────
func use_energy(amount: int) -> bool:
	if energy >= float(amount):
		energy -= float(amount)
		energy_changed.emit(energy, max_energy)
		return true
	return false

func regenerate_energy(delta: float) -> void:
	if energy < float(max_energy):
		energy = min(float(max_energy), energy + delta * 6.0)
		energy_changed.emit(energy, max_energy)

# ──────────────────────────────────────────────
# STATS TOTALES
# ──────────────────────────────────────────────
func get_total_attack() -> int:
	if GameManager.is_pvp_zone:
		return base_attack + pvp_equipment_attack
	return base_attack + equipment_attack

func get_total_defense() -> int:
	if GameManager.is_pvp_zone:
		return int(level * 0.8) + pvp_equipment_defense
	return int(level * 0.8) + equipment_defense

func get_total_speed() -> int:
	if GameManager.is_pvp_zone:
		return speed
	var pct_bonus: float = float(bonus_speed_pct_gear) / 100.0
	return int(float(speed) * (1.0 + pct_bonus))

func get_dmg_reduction_pct() -> int:
	if GameManager.is_pvp_zone:
		return 0
	return bonus_dmg_red_pct_gear

func get_crit_pct() -> int:
	if GameManager.is_pvp_zone:
		return 0
	return bonus_crit_pct_gear

func get_heal_bonus_pct() -> int:
	if GameManager.is_pvp_zone:
		return 0
	return bonus_heal_pct_gear

# ──────────────────────────────────────────────
# MONEDAS
# ──────────────────────────────────────────────
func add_bronze(amount: int) -> void:
	bronze += amount
	_normalize_currency()
	currency_changed.emit()
	stat_updated.emit()
	save_character_data()   # Guardado local inmediato (no se pierden monedas)
	# Marcar guardado en servidor pendiente (se dispara cada 60 s automáticamente)
	_pending_server_save = true
	_server_save_timer = 0.0   # reiniciar ventana cada vez que llegan monedas
	# Logro economía
	var am = get_node_or_null("/root/AchievementManager")
	if am: am.on_currency_changed(get_total_bronze())

func spend_bronze(amount: int) -> bool:
	var total = get_total_bronze()
	if total < amount:
		return false
	var remaining = total - amount
	gold   = remaining / 10000
	remaining -= gold * 10000
	silver = remaining / 100
	bronze = remaining - silver * 100
	currency_changed.emit()
	stat_updated.emit()
	save_character_data()   # Guardado local inmediato al gastar monedas
	_pending_server_save = true
	_server_save_timer = 0.0
	return true

func get_total_bronze() -> int:
	return bronze + silver * 100 + gold * 10000

func _normalize_currency() -> void:
	if bronze >= 100:
		silver += bronze / 100 as int
		bronze  = bronze % 100
	if silver >= 100:
		gold   += silver / 100 as int
		silver  = silver % 100

func get_currency_text() -> String:
	var parts: Array = []
	if gold   > 0: parts.append("%d🥇" % gold)
	if silver > 0: parts.append("%d🥈" % silver)
	parts.append("%d🥉" % bronze)
	return " ".join(parts)

# ──────────────────────────────────────────────
# HABILIDADES DE RECOLECCIÓN
# ──────────────────────────────────────────────
func get_gathering_level(skill: String) -> int:
	return gathering_skills.get(skill, {"level": 1})["level"]

func get_specialization_tier(skill: String) -> int:
	var lv = get_gathering_level(skill)
	if lv >= 10: return 3
	if lv >= 5:  return 2
	return 1

func can_gather_tier(skill: String, node_tier: int) -> bool:
	var min_lv: int = GATHERING_TIER_MIN_LEVEL.get(node_tier, 1)
	return get_gathering_level(skill) >= min_lv

func can_buy_tool_tier(skill: String, tier: int) -> bool:
	return get_specialization_tier(skill) >= tier

func gain_gathering_xp(skill: String, amount: int) -> void:
	if not gathering_skills.has(skill):
		return
	var s = gathering_skills[skill]
	if s["level"] >= GATHERING_MAX_LEVEL:
		return
	s["xp"] += amount
	var needed = _gathering_xp_needed(s["level"])
	while s["xp"] >= needed and s["level"] < GATHERING_MAX_LEVEL:
		s["xp"]    -= needed
		s["level"] += 1
		needed      = _gathering_xp_needed(s["level"])
		gathering_skill_changed.emit(skill, s["level"])
		var _am = get_node_or_null("/root/AchievementManager")
		if _am: _am.on_gathering_level_up(skill, s["level"])
	stat_updated.emit()
	save_character_data()

func _gathering_xp_needed(lv: int) -> int:
	var idx = lv - 1
	if idx < 0 or idx >= GATHERING_XP_PER_LEVEL.size():
		return 999999
	return GATHERING_XP_PER_LEVEL[idx]

# ──────────────────────────────────────────────
# HABILIDADES DE CRAFTEO
# ──────────────────────────────────────────────
func get_crafting_level(skill: String) -> int:
	return crafting_skills.get(skill, {"level": 1})["level"]

func gain_crafting_xp(skill: String, amount: int) -> void:
	if not crafting_skills.has(skill):
		return
	var s = crafting_skills[skill]
	if s["level"] >= CRAFTING_MAX_LEVEL:
		return
	s["xp"] += amount
	var needed = _crafting_xp_needed(s["level"])
	while s["xp"] >= needed and s["level"] < CRAFTING_MAX_LEVEL:
		s["xp"]    -= needed
		s["level"] += 1
		needed      = _crafting_xp_needed(s["level"])
		crafting_skill_changed.emit(skill, s["level"])
		var _am2 = get_node_or_null("/root/AchievementManager")
		if _am2: _am2.on_crafting_level_up(skill, s["level"])
	stat_updated.emit()
	save_character_data()

func _crafting_xp_needed(lv: int) -> int:
	var idx = lv - 1
	if idx < 0 or idx >= CRAFTING_XP_PER_LEVEL.size():
		return 999999
	return CRAFTING_XP_PER_LEVEL[idx]

# ──────────────────────────────────────────────
# DIÁLOGO DE SALIDA (botón Atrás de Android)
# ──────────────────────────────────────────────
var _exit_dialog_open: bool = false

func _show_exit_dialog() -> void:
	# Evitar abrir el diálogo dos veces si el usuario toca varias veces
	if _exit_dialog_open:
		return
	_exit_dialog_open = true

	# Guardar todo localmente antes de preguntar
	flush_pending_save()
	save_character_data()

	var dialog := ConfirmationDialog.new()
	dialog.title = "¿Salir del juego?"
	dialog.dialog_text = "Se guardará tu progreso antes de salir.\n¿Estás seguro?"
	dialog.ok_button_text  = "Salir"
	dialog.cancel_button_text = "Cancelar"

	# Confirmar: guardar en servidor y cerrar
	dialog.confirmed.connect(func() -> void:
		flush_pending_server_save()
		await get_tree().create_timer(0.5).timeout   # margen para que termine el HTTP
		get_tree().quit()
	)
	# Cancelar: solo cierra el diálogo
	dialog.canceled.connect(func() -> void:
		_exit_dialog_open = false
	)
	dialog.close_requested.connect(func() -> void:
		_exit_dialog_open = false
	)

	get_tree().root.add_child(dialog)
	dialog.popup_centered()
