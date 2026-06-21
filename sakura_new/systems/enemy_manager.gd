# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# ENEMY MANAGER — Autoload global  (v22.2 — network_id asignado)
#
# CAMBIOS v22.2:
#   - Cada enemigo spawnado recibe un `network_id` único global.
#   - take_damage() en enemy.gd debe enrutar por NetworkManager
#     cuando hay conexión activa (ver enemy.gd v22.2).
#   - Se expone spawn_enemy_networked() para world scripts que
#     quieran notificar el spawn a otros clientes (futuro).
# ============================================================

const ENEMY_SCENE_PATH = "res://scenes/enemy.tscn"

const ENEMY_CONFIGS: Dictionary = {
	"slime": {
		"enemy_label": "Slime", "max_hp": 30, "attack_power": 5, "defense": 0,
		"move_speed": 40.0, "xp_reward": 10, "bronze_min": 3, "bronze_max": 8,
		"loot_main": "material_slime_gel", "loot_extra": "",
		"body_color": Color(0.3, 0.9, 0.3), "sprite_type": "slime",
	},
	"goblin": {
		"enemy_label": "Goblin", "max_hp": 50, "attack_power": 10, "defense": 3,
		"move_speed": 60.0, "xp_reward": 25, "bronze_min": 15, "bronze_max": 40,
		"loot_main": "material_goblin_ear", "loot_extra": "material_goblin_ear",
		"body_color": Color(0.4, 0.7, 0.2),
	},
	"orc": {
		"enemy_label": "Orco", "max_hp": 80, "attack_power": 15, "defense": 5,
		"move_speed": 50.0, "xp_reward": 60, "bronze_min": 25, "bronze_max": 60,
		"loot_main": "material_orc_hide", "loot_extra": "weapon_crude_axe",
		"body_color": Color(0.5, 0.4, 0.2), "sprite_type": "orc",
	},
	"skeleton": {
		"enemy_label": "Esqueleto", "max_hp": 40, "attack_power": 12, "defense": 2,
		"move_speed": 55.0, "xp_reward": 20, "bronze_min": 5, "bronze_max": 20,
		"loot_main": "material_bone", "loot_extra": "",
		"body_color": Color(0.9, 0.9, 0.85), "sprite_type": "skeleton",
	},
	"wolf": {
		"enemy_label": "Lobo", "max_hp": 45, "attack_power": 8, "defense": 2,
		"move_speed": 70.0, "xp_reward": 18, "bronze_min": 8, "bronze_max": 22,
		"loot_main": "material_bone", "loot_extra": "material_herb",
		"body_color": Color(0.55, 0.50, 0.45), "sprite_type": "wolf", "behavior_type": "charger",
	},
	"spider": {
		"enemy_label": "Araña", "max_hp": 60, "attack_power": 13, "defense": 3,
		"move_speed": 58.0, "xp_reward": 42, "bronze_min": 18, "bronze_max": 45,
		"loot_main": "material_bone", "loot_extra": "crystal_shard",
		"body_color": Color(0.20, 0.14, 0.28), "sprite_type": "spider",
	},
	"darkelf": {
		"enemy_label": "Elfo Oscuro", "max_hp": 90, "attack_power": 18, "defense": 6,
		"move_speed": 62.0, "xp_reward": 112, "bronze_min": 35, "bronze_max": 80,
		"loot_main": "crystal_shard", "loot_extra": "weapon_shadow_blade",
		"body_color": Color(0.15, 0.08, 0.30), "sprite_type": "darkelf", "behavior_type": "ranged",
	},
	"dungeon_boss": {
		"enemy_label": "Señor de las Sombras", "max_hp": 300, "attack_power": 25, "defense": 8,
		"move_speed": 45.0, "xp_reward": 300, "bronze_min": 300, "bronze_max": 500,
		"loot_main": "armor_shadow_chest", "loot_extra": "weapon_shadow_blade",
		"body_color": Color(0.2, 0.1, 0.4),
	},
	"zombie": {
		"enemy_label": "Zombie", "max_hp": 45, "attack_power": 12, "defense": 1,
		"move_speed": 38.0, "xp_reward": 22, "bronze_min": 5, "bronze_max": 18,
		"loot_main": "material_bone", "loot_extra": "",
		"body_color": Color(0.35, 0.55, 0.30),
	},
	"bat": {
		"enemy_label": "Murciélago", "max_hp": 20, "attack_power": 6, "defense": 0,
		"move_speed": 75.0, "xp_reward": 12, "bronze_min": 2, "bronze_max": 8,
		"loot_main": "material_bone", "loot_extra": "",
		"body_color": Color(0.25, 0.12, 0.35),
	},
	"imp": {
		"enemy_label": "Imp", "max_hp": 35, "attack_power": 15, "defense": 2,
		"move_speed": 65.0, "xp_reward": 30, "bronze_min": 8, "bronze_max": 25,
		"loot_main": "crystal_shard", "loot_extra": "",
		"body_color": Color(0.7, 0.15, 0.20),
	},
	"wogol": {
		"enemy_label": "Wogol", "max_hp": 55, "attack_power": 14, "defense": 3,
		"move_speed": 52.0, "xp_reward": 33, "bronze_min": 12, "bronze_max": 30,
		"loot_main": "material_goblin_ear", "loot_extra": "crystal_shard",
		"body_color": Color(0.30, 0.50, 0.22), "sprite_type": "wogol",
	},
	"ogre": {
		"enemy_label": "Ogro", "max_hp": 130, "attack_power": 28, "defense": 7,
		"move_speed": 40.0, "xp_reward": 150, "bronze_min": 50, "bronze_max": 120,
		"loot_main": "material_orc_hide", "loot_extra": "weapon_crude_axe",
		"body_color": Color(0.42, 0.55, 0.18),
	},
	"necromancer": {
		"enemy_label": "Nigromante", "max_hp": 180, "attack_power": 32, "defense": 5,
		"move_speed": 42.0, "xp_reward": 350, "bronze_min": 80, "bronze_max": 200,
		"loot_main": "crystal_shard", "loot_extra": "weapon_shadow_blade",
		"body_color": Color(0.15, 0.08, 0.35),
	},
	"chort": {
		"enemy_label": "Chort", "max_hp": 150, "attack_power": 30, "defense": 6,
		"move_speed": 42.0, "xp_reward": 280, "bronze_min": 60, "bronze_max": 150,
		"loot_main": "crystal_shard", "loot_extra": "armor_shadow_chest",
		"body_color": Color(0.70, 0.10, 0.25),
	},
	"dark_knight": {
		"enemy_label": "Caballero Oscuro", "max_hp": 200, "attack_power": 38, "defense": 12,
		"move_speed": 38.0, "xp_reward": 420, "bronze_min": 100, "bronze_max": 250,
		"loot_main": "weapon_shadow_blade", "loot_extra": "armor_shadow_chest",
		"body_color": Color(0.18, 0.18, 0.30),
	},
	"elemental_fire": {
		"enemy_label": "Elemental de Fuego", "max_hp": 110, "attack_power": 35, "defense": 4,
		"move_speed": 58.0, "xp_reward": 187, "bronze_min": 60, "bronze_max": 140,
		"loot_main": "crystal_shard", "loot_extra": "",
		"body_color": Color(1.0, 0.40, 0.05),
	},
	"bies": {
		"enemy_label": "Bies", "max_hp": 65, "attack_power": 18, "defense": 3,
		"move_speed": 55.0, "xp_reward": 75, "bronze_min": 20, "bronze_max": 50,
		"loot_main": "crystal_shard", "loot_extra": "material_bone",
		"body_color": Color(0.60, 0.10, 0.55),
	},
	"demonolog": {
		"enemy_label": "Demonólogo", "max_hp": 160, "attack_power": 28, "defense": 6,
		"move_speed": 45.0, "xp_reward": 315, "bronze_min": 70, "bronze_max": 180,
		"loot_main": "crystal_shard", "loot_extra": "weapon_shadow_blade",
		"body_color": Color(0.20, 0.05, 0.40),
	},
	"demon_lord": {
		"enemy_label": "Azathiel — Demonio Ancestral", "max_hp": 800, "attack_power": 55, "defense": 15,
		"move_speed": 40.0, "xp_reward": 1000, "bronze_min": 600, "bronze_max": 1200,
		"loot_main": "armor_shadow_chest", "loot_extra": "weapon_shadow_blade",
		"body_color": Color(0.55, 0.05, 0.10),
	},
	"goblin_warrior": {
		"enemy_label": "Guerrero Goblin", "max_hp": 70, "attack_power": 16, "defense": 5,
		"move_speed": 58.0, "xp_reward": 45, "bronze_min": 20, "bronze_max": 55,
		"loot_main": "material_goblin_ear", "loot_extra": "weapon_crude_axe",
		"body_color": Color(0.30, 0.55, 0.18), "sprite_type": "goblin_warrior",
	},
	"goblin_archer": {
		"enemy_label": "Arquero Goblin", "max_hp": 55, "attack_power": 14, "defense": 3,
		"move_speed": 62.0, "xp_reward": 42, "bronze_min": 18, "bronze_max": 45,
		"loot_main": "material_goblin_ear", "loot_extra": "material_bone",
		"body_color": Color(0.35, 0.60, 0.20), "sprite_type": "goblin_archer", "behavior_type": "ranged",
	},
	"goblin_shaman": {
		"enemy_label": "Chamán Goblin", "max_hp": 90, "attack_power": 22, "defense": 4,
		"move_speed": 48.0, "xp_reward": 137, "bronze_min": 40, "bronze_max": 100,
		"loot_main": "crystal_shard", "loot_extra": "material_goblin_ear",
		"body_color": Color(0.20, 0.40, 0.60), "sprite_type": "goblin_shaman", "behavior_type": "healer",
	},
	"goblin_chieftain": {
		"enemy_label": "Jefe Goblin", "max_hp": 350, "attack_power": 40, "defense": 12,
		"move_speed": 44.0, "xp_reward": 400, "bronze_min": 200, "bronze_max": 450,
		"loot_main": "weapon_shadow_blade", "loot_extra": "armor_shadow_chest",
		"body_color": Color(0.20, 0.50, 0.10), "sprite_type": "goblin_chieftain", "is_miniboss": true,
	},
	"spider_queen": {
		"enemy_label": "Araña Reina", "max_hp": 220, "attack_power": 30, "defense": 8,
		"move_speed": 50.0, "xp_reward": 260, "bronze_min": 110, "bronze_max": 260,
		"loot_main": "crystal_shard", "loot_extra": "material_bone",
		"body_color": Color(0.12, 0.08, 0.20), "sprite_type": "spider_south", "is_miniboss": true,
	},
	"spider_forest": {
		"enemy_label": "Araña del Bosque", "max_hp": 65, "attack_power": 14, "defense": 4,
		"move_speed": 60.0, "xp_reward": 48, "bronze_min": 22, "bronze_max": 55,
		"loot_main": "material_bone", "loot_extra": "crystal_shard",
		"body_color": Color(0.18, 0.10, 0.25), "sprite_type": "spider_south",
	},
	"werewolf": {
		"enemy_label": "Hombre Lobo", "max_hp": 120, "attack_power": 26, "defense": 6,
		"move_speed": 72.0, "xp_reward": 175, "bronze_min": 55, "bronze_max": 130,
		"loot_main": "material_orc_hide", "loot_extra": "crystal_shard",
		"body_color": Color(0.40, 0.32, 0.22), "sprite_type": "werewolf", "behavior_type": "charger",
	},
	"goblin_barbarian": {
		"enemy_label": "Bárbaro Goblin", "max_hp": 160, "attack_power": 35, "defense": 8,
		"move_speed": 50.0, "xp_reward": 315, "bronze_min": 70, "bronze_max": 170,
		"loot_main": "material_orc_hide", "loot_extra": "weapon_crude_axe",
		"body_color": Color(0.45, 0.60, 0.15), "sprite_type": "goblin_warrior",
	},
}

var _enemy_scene: PackedScene = null
var active_enemies: Array = []

func _ready() -> void:
	print("[EnemyManager] Inicializado v22.2")
	_preload_scene()

func _preload_scene() -> void:
	if ResourceLoader.exists(ENEMY_SCENE_PATH):
		_enemy_scene = load(ENEMY_SCENE_PATH)
	else:
		push_error("[EnemyManager] No se encontró: " + ENEMY_SCENE_PATH)

# ──────────────────────────────────────────────
# SPAWN
# ──────────────────────────────────────────────

func spawn_enemy(enemy_type: String, position: Vector2, level: int = 1, parent_override: Node = null) -> Node:
	if not _enemy_scene:
		_preload_scene()
	if not _enemy_scene:
		push_error("[EnemyManager] Escena de enemigo no disponible")
		return null

	var config = ENEMY_CONFIGS.get(enemy_type, ENEMY_CONFIGS["slime"])
	# Nota v22.3: se usa "Node" en vez de "Enemy" como tipo aquí porque en
	# el servidor headless (sin caché de class_name del editor) la resolución
	# de "Enemy" como tipo global puede fallar al cargar este autoload antes
	# que enemy.gd. El comportamiento en tiempo de ejecución es idéntico.
	var enemy: Node = _enemy_scene.instantiate()

	enemy.enemy_type    = enemy_type
	enemy.enemy_level   = level
	enemy.enemy_label   = config.get("enemy_label", "Enemigo")
	enemy.body_color    = config.get("body_color", Color.GREEN)
	enemy.move_speed    = config.get("move_speed", 40.0)
	enemy.loot_main     = config.get("loot_main", "")
	enemy.loot_extra    = config.get("loot_extra", "")
	enemy.bronze_min    = config.get("bronze_min", 0)
	enemy.bronze_max    = config.get("bronze_max", 0)
	enemy.sprite_type   = config.get("sprite_type", "goblin")
	enemy.behavior_type = config.get("behavior_type", "normal")

	var is_boss_type = config.get("is_boss", false) or config.get("is_miniboss", false)
	if enemy_type == "dungeon_boss" or enemy_type == "demon_lord" or is_boss_type:
		enemy.max_hp       = config.get("max_hp", 300)
		enemy.attack_power = config.get("attack_power", 25)
		enemy.defense      = config.get("defense", 8)
		enemy.xp_reward    = config.get("xp_reward", 150)
		if enemy.get_node_or_null("Sprite"):
			enemy.get_node("Sprite").scale    = Vector2(4.5, 4.5)
			enemy.get_node("Sprite").position = Vector2(0, -20)
	else:
		var level_mult = 1.0 + (level - 1) * 0.25
		enemy.max_hp       = int(config.get("max_hp", 30) * level_mult)
		enemy.attack_power = int(config.get("attack_power", 5) * level_mult)
		enemy.defense      = int(config.get("defense", 0) * level_mult)
		enemy.xp_reward    = int(config.get("xp_reward", 10) * level_mult)

	# FIX CRÍTICO MULTIJUGADOR: el servidor dedicado carga los 4 mapas del
	# mundo como hijos directos de root (nunca con change_scene_to_file),
	# así que get_tree().current_scene nunca apunta a ninguno de ellos ahí.
	# Si no recibimos un parent_override explícito, caemos a current_scene
	# (comportamiento original, válido en cliente).
	var current_scene: Node = parent_override if parent_override else get_tree().current_scene
	if current_scene:
		current_scene.add_child(enemy)
		enemy.global_position = position
		enemy.zone_scene_path = current_scene.scene_file_path
		# ── Asignar network_id ─────────────────────────────────
		# Servidor: asignar ID único autoritativo.
		# Cliente online: dejar en 0, el servidor enviará el ID real
		#   vía _rpc_sync_enemy_list, que matchea por proximidad.
		# Offline: asignar ID local para combate sin red.
		var nm = get_node_or_null("/root/NetworkManager")
		var is_online_client = nm and nm.is_client and \
			multiplayer.has_multiplayer_peer() and \
			multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
		if nm and nm.is_server:
			nm.assign_enemy_network_id(enemy)
		elif is_online_client:
			enemy.set("network_id", 0)
		else:
			enemy.set("network_id", randi_range(100000, 999999))
		# ───────────────────────────────────────────────────────
		active_enemies.append(enemy)
		print("[EnemyManager] Spawn: ", enemy_type, " Nv.", level, " ID:", (enemy.get("network_id") if enemy.get("network_id") != null else "?"), " en ", position, " parent=", current_scene.name)
	else:
		push_error("[EnemyManager] No hay escena activa para spawnar enemigo (ni current_scene ni parent_override)")
		enemy.queue_free()
		return null

	return enemy

# ──────────────────────────────────────────────
# DESPAWN
# ──────────────────────────────────────────────

func despawn_all() -> void:
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	print("[EnemyManager] Todos los enemigos eliminados")

func on_enemy_died(enemy: Node) -> void:
	active_enemies.erase(enemy)

# ──────────────────────────────────────────────
# UTILIDADES
# ──────────────────────────────────────────────

func get_enemy_count() -> int:
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))
	return active_enemies.size()

func get_nearest_enemy(from_position: Vector2) -> Node:
	var nearest: Node = null
	var min_dist: float = INF
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			var dist = from_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest  = enemy
	return nearest

func get_enemy_by_network_id(nid: int) -> Node:
	for e in active_enemies:
		if is_instance_valid(e) and e.get("network_id") == nid:
			return e
	return null
