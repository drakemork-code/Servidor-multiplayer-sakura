# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends CharacterBody2D
class_name Enemy

# ============================================================
# ENEMY v2 — IA avanzada
# FSM: IDLE → ALERT → CHASE → ATTACK → RETREAT → HURT → DEAD
# + patrulla con waypoints, aggro grupal, flanqueo, retreat,
#   healer, charger, ranged, loot callback de campamento
# ============================================================

@export var enemy_type: String    = "slime"
@export var enemy_level: int      = 1
@export var max_hp: int           = 30
@export var attack_power: int     = 5
@export var defense: int          = 0
@export var move_speed: float     = 40.0
@export var xp_reward: int        = 10
@export var bronze_min: int       = 0
@export var bronze_max: int       = 3
@export var loot_main: String     = ""
@export var loot_extra: String    = ""
@export var body_color: Color     = Color(0.3, 0.9, 0.3)
@export var enemy_label: String   = "Slime"
# Tipo de sprite: "goblin" | "skeleton" | "slime" | "boss"
@export var sprite_type: String   = "goblin"
# Tipo de comportamiento: "normal" | "ranged" | "healer" | "charger" | "boss"
@export var behavior_type: String = "normal"

# ── ID de red único (asignado por EnemyManager al spawnear) ──
# Permite que el servidor identifique a qué enemigo se está golpeando.
var network_id: int = 0
# Cooldown para no espamear request_enemy_resync si el jugador golpea
# repetidamente un mob que todavía no tiene network_id (ver take_damage).
var _last_forced_resync_time: float = -999.0
const FORCED_RESYNC_COOLDOWN: float = 1.0
# FIX MULTIJUGADOR: a qué escena/zona pertenece este enemigo (resource path,
# ej. "res://scenes/world_south.tscn"). Necesario porque el servidor dedicado
# mantiene los 4 mapas cargados a la vez — sin esto, el filtrado de la lista
# de enemigos por zona sería ambiguo entre mapas.
var zone_scene_path: String = ""
var boss_mechanics: Node = null   # asignado por boss_*.gd cuando behavior_type == "boss"

# ── Señales ────────────────────────────────────────────
signal enemy_died()   # FIX v19: señal para callbacks de boss (has_signal funcionará)


# ── FSM ─────────────────────────────────────────────────────
enum State { IDLE, ALERT, CHASE, ATTACK, RETREAT, RETURN, HURT, DEAD }
var state: State = State.IDLE

# ── Internos ─────────────────────────────────────────────────
var current_hp: int   = 30
var player_ref: Node  = null
var attack_timer: float  = 0.0
var attack_cooldown: float = 1.2

# Timers de estado
var alert_timer: float   = 0.0
var hurt_timer: float    = 0.0
var dead_timer: float    = 0.0
var retreat_timer: float = 0.0

# ── Patrulla por waypoints ───────────────────────────────────
var patrol_waypoints: Array      = []   # Array[Vector2]
var patrol_index: int            = 0
var patrol_wait_timer: float     = 0.0
var is_patrol_waiting: bool      = false
var patrol_origin: Vector2       = Vector2.ZERO

# ── Flanqueo ─────────────────────────────────────────────────
var flank_offset: Vector2  = Vector2.ZERO
var flank_timer: float     = 0.0

# ── Ranged ───────────────────────────────────────────────────
const RANGED_MAX_DIST: float = 160.0
const RANGED_MIN_DIST: float = 90.0

# ── Healer ───────────────────────────────────────────────────
var heal_timer: float      = 0.0
const HEAL_COOLDOWN: float = 6.0
const HEAL_RANGE: float    = 110.0

# ── Charger ──────────────────────────────────────────────────
var charge_velocity: Vector2 = Vector2.ZERO
var is_charging: bool        = false
var charge_duration: float   = 0.0
var charge_cd_timer: float   = 0.0
const CHARGE_COOLDOWN: float = 5.5
const CHARGE_SPEED_MULT: float = 3.8
const CHARGE_DURATION: float   = 0.38

# ── Knockback / Stun ─────────────────────────────────────────
var knockback_velocity: Vector2 = Vector2.ZERO
var _stun_timer: float          = 0.0
var _force_target: Node         = null
var _force_target_timer: float  = 0.0   # taunt expira tras este tiempo (solo bosses con threat)

# ── Aggro ────────────────────────────────────────────────────
const AGGRO_BROADCAST_RADIUS: float = 130.0
const LEASH_DISTANCE: float         = 290.0
var _retreat_hp_pct: float          = 0.20   # boss nunca usa retreat

# ── Animación sprite ─────────────────────────────────────────
var _anim_frame_timer: float = 0.0
const ANIM_FPS: float = 8.0
var _current_anim: String = "idle"
var _anim_frame: int = 0
# frame counts per animation, per sprite type
const ANIM_DATA := {
	"goblin":   {"idle": 12, "walk": 12, "attack": 13, "hurt": 12, "death": 13},
	# FIX: skeleton usa sus propios sprites (frame counts corregidos según archivos reales)
	"skeleton": {"idle": 6,  "walk": 8,  "attack": 7,  "hurt": 7,  "death": 10},
	# FIX: wolf usa los mismos frame counts que goblin (sprites recoloreados)
	"wolf":     {"idle": 12, "walk": 12, "attack": 13, "hurt": 12, "death": 13},
	# Slime — sprites del craftpix pack (64x64 por frame, fila frontal extraída)
	"slime":    {"idle": 6,  "walk": 8,  "attack": 10, "hurt": 5,  "death": 10},
	# Void Megapack — sprites propios por mob
	"orc":      {"idle": 9,  "walk": 6,  "attack": 6,  "hurt": 5,  "death": 10},
	"spider":   {"idle": 4,  "walk": 7,  "attack": 7,  "hurt": 3,  "death": 7},
	"darkelf":  {"idle": 4,  "walk": 8,  "attack": 7,  "hurt": 3,  "death": 8},
	"wogol":    {"idle": 4,  "walk": 8,  "attack": 7,  "hurt": 3,  "death": 8},
	# ── Pack Mapa Sur — sprites propios ───────────────────────
	# GoblinWarrior: hoja 1280x1280, 8×8=64 slots, 48 frames usados (8 anims × 4 dirs)
	# Para Godot: usamos la fila frontal (row 0: idle-D frames 0-3, walk-D frames 16-23)
	# Se pone hframes=8, vframes=8 y animamos la fila correcta
	"goblin_warrior": {"idle": 4, "walk": 8, "attack": 8, "hurt": 4, "death": 8},
	# GoblinArchero: hoja 1024x1024 (anims) + 896x512 (atk), frame 128x128
	# Idle frames 32-35 (row4), Walk-D frames 24-31 (row3)
	"goblin_archer":  {"idle": 4, "walk": 8, "attack": 7, "hurt": 4, "death": 8},
	# GoblinShaman: hoja 960x1152, 10 cols × ~9 rows, frame 96×128
	# idle 0-5, walkR 37-41, atkR 6-15
	"goblin_shaman":  {"idle": 6, "walk": 5, "attack": 10, "hurt": 6, "death": 6},
	# GoblinChieftain (Boss): strip4 128x128 (loop animado)
	"goblin_chieftain": {"idle": 4, "walk": 4, "attack": 4, "hurt": 4, "death": 4},
	# Spider del ForestBiome: 294x112, 7 frames horizontales de 42x112
	"spider_south":   {"idle": 7, "walk": 7, "attack": 7, "hurt": 3, "death": 7},
	# Werewolf: 64x64 single-frame (estático — se mueve vía escala)
	"werewolf":       {"idle": 1, "walk": 1, "attack": 1, "hurt": 1, "death": 1},
}
# Dungeon tileset sprites (static, single frame, from 0x72 16x16 tileset)
const DUNGEON_STATIC_SPRITES := {
	"bat":            "res://assets/mobs/dungeon_tiles/bat.png",
	"imp":            "res://assets/mobs/dungeon_tiles/imp.png",
	"zombie":         "res://assets/mobs/dungeon_tiles/zombie.png",
	"wogol":          "res://assets/mobs/dungeon_tiles/wogol.png",
	"necromancer":    "res://assets/mobs/dungeon_tiles/necromancer.png",
	"dark_knight":    "res://assets/mobs/dungeon_tiles/dark_knight.png",
	"chort":          "res://assets/mobs/dungeon_tiles/chort.png",
	"ogre":           "res://assets/mobs/dungeon_tiles/ogre.png",
	"elemental_fire": "res://assets/mobs/dungeon_tiles/elemental_fire.png",
	"bies":           "res://assets/mobs/dungeon_tiles/bies.png",
	"demonolog":      "res://assets/mobs/dungeon_tiles/demonolog.png",
	"demon_lord":     "res://assets/mobs/dungeon_tiles/demon_lord.png",
}
# ── Pack Mapa Sur — sprites animados ──────────────────────────
# Cada entrada: [tex_idle, hframes, vframes, frame_w, frame_h, scale]
# goblin_warrior: 1280×1280, hf=8 vf=8, frame=160×160, idle fila 0
# goblin_archer:  1024×1024 idle+walk / 896×512 attack, frame=128×128
# goblin_shaman:  960×1152, hf=10 vf=9 (96×128)
# goblin_chieftain: strip4 512×128, hf=4 vf=1
# spider_south:   294×112, hf=7 vf=1 (42×112)
# werewolf:       64×64 single
const SOUTH_SPRITES := {
	"goblin_warrior": {
		"idle":   "res://assets/mobs/south/goblin_warrior.png",
		"attack": "res://assets/mobs/south/goblin_warrior.png",
		"walk":   "res://assets/mobs/south/goblin_warrior.png",
		"hurt":   "res://assets/mobs/south/goblin_warrior.png",
		"death":  "res://assets/mobs/south/goblin_warrior.png",
		"hframes": 8, "vframes": 8, "scale": Vector2(2.2, 2.2),
		"idle_row": 0, "walk_row": 4,
	},
	"goblin_archer": {
		"idle":   "res://assets/mobs/south/goblin_archer.png",
		"attack": "res://assets/mobs/south/goblin_archer_atk.png",
		"walk":   "res://assets/mobs/south/goblin_archer.png",
		"hurt":   "res://assets/mobs/south/goblin_archer.png",
		"death":  "res://assets/mobs/south/goblin_archer_death.png",
		"hframes": 8, "vframes": 6, "scale": Vector2(2.2, 2.2),
		"idle_row": 4, "walk_row": 3,
	},
	"goblin_shaman": {
		"idle":   "res://assets/mobs/south/goblin_shaman.png",
		"attack": "res://assets/mobs/south/goblin_shaman.png",
		"walk":   "res://assets/mobs/south/goblin_shaman.png",
		"hurt":   "res://assets/mobs/south/goblin_shaman.png",
		"death":  "res://assets/mobs/south/goblin_shaman.png",
		"hframes": 10, "vframes": 9, "scale": Vector2(2.4, 2.4),
		"idle_row": 0, "walk_row": 7,
	},
	"goblin_chieftain": {
		"idle":   "res://assets/mobs/south/goblin_chieftain.png",
		"attack": "res://assets/mobs/south/goblin_chieftain.png",
		"walk":   "res://assets/mobs/south/goblin_chieftain.png",
		"hurt":   "res://assets/mobs/south/goblin_chieftain.png",
		"death":  "res://assets/mobs/south/goblin_chieftain.png",
		"hframes": 4, "vframes": 1, "scale": Vector2(3.5, 3.5),
		"idle_row": 0, "walk_row": 0,
	},
	"spider_south": {
		"idle":   "res://assets/mobs/south/spider.png",
		"attack": "res://assets/mobs/south/spider.png",
		"walk":   "res://assets/mobs/south/spider.png",
		"hurt":   "res://assets/mobs/south/spider.png",
		"death":  "res://assets/mobs/south/spider.png",
		"hframes": 7, "vframes": 1, "scale": Vector2(3.0, 3.0),
		"idle_row": 0, "walk_row": 0,
	},
	"werewolf": {
		"idle":   "res://assets/mobs/south/werewolf.png",
		"attack": "res://assets/mobs/south/werewolf.png",
		"walk":   "res://assets/mobs/south/werewolf.png",
		"hurt":   "res://assets/mobs/south/werewolf.png",
		"death":  "res://assets/mobs/south/werewolf.png",
		"hframes": 1, "vframes": 1, "scale": Vector2(3.5, 3.5),
		"idle_row": 0, "walk_row": 0,
	},
}

# ── Camp callback (se asigna desde la escena world_*) ────────
var _camp_death_callback: Callable = Callable()

# ── Nodos ────────────────────────────────────────────────────
@onready var sprite: Sprite2D            = $Sprite
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var name_label: Label           = $NameLabel
@onready var hp_bar: ProgressBar         = $HPBar
@onready var aggro_area: Area2D          = $AggroRange
@onready var hitbox: Area2D              = $HitBox
@onready var collision: CollisionShape2D = $CollisionShape2D

# ════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("enemy")
	current_hp = max_hp
	# BUG FIX: patrol_origin se asigna de forma diferida porque
	# EnemyManager llama add_child() ANTES de asignar global_position.
	# Con call_deferred el origen se lee en el siguiente frame, cuando
	# la posición ya es correcta.
	call_deferred("_init_patrol")
	_update_hp_bar()
	_update_name_label()

	aggro_area.body_entered.connect(_on_aggro_body_entered)
	aggro_area.body_exited.connect(_on_aggro_body_exited)

	# Shaders pre-asignados en la escena: outline → flash → dissolve
	# No se crean por código para evitar version_get_shader null

	# Variar cooldown para que mobs no ataquen sincronizados
	match behavior_type:
		"ranged":  attack_cooldown = randf_range(1.8, 2.6)
		"healer":  attack_cooldown = 9999.0       # curador no ataca
		"charger": attack_cooldown = randf_range(1.4, 2.0)
		"boss":
			attack_cooldown = 0.85
			_retreat_hp_pct = 0.0             # boss nunca huye
		_:         attack_cooldown = randf_range(1.0, 1.6)

## Llamado de forma diferida para que global_position ya sea la final
func _setup_sprite() -> void:
	# Prioridad 1: sprites del Pack Mapa Sur (animated spritesheets propios)
	if sprite_type in SOUTH_SPRITES:
		var sd: Dictionary = SOUTH_SPRITES[sprite_type]
		var tex_path: String = sd.get("idle", "")
		if ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)
			sprite.hframes = sd.get("hframes", 1)
			sprite.vframes = sd.get("vframes", 1)
			sprite.frame   = sd.get("idle_row", 0) * sd.get("hframes", 1)
			sprite.scale   = sd.get("scale", Vector2(2.5, 2.5))
			sprite.position = Vector2(0, -14)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return
	# Prioridad 2: sprites estáticos del dungeon tileset (0x72)
	if enemy_type in DUNGEON_STATIC_SPRITES:
		var tex_path: String = DUNGEON_STATIC_SPRITES[enemy_type]
		if ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)
			sprite.hframes = 1
			sprite.vframes = 1
			sprite.frame   = 0
			var is_large := enemy_type in ["ogre", "demon_lord", "dark_knight", "chort", "necromancer"]
			sprite.scale    = Vector2(4.0, 4.0) if is_large else Vector2(3.0, 3.0)
			sprite.position = Vector2(0, -16) if is_large else Vector2(0, -8)
		return
	# Prioridad 3: Sunnyside animated sprites
	var base_path := "res://assets/mobs/sunnyside/"
	var stype := sprite_type if sprite_type in ANIM_DATA else "goblin"
	var tex_path := ""
	match stype:
		"goblin":   tex_path = base_path + "goblin_idle_strip12.png"
		"skeleton": tex_path = base_path + "skeleton_idle_strip6.png"
		# FIX: wolf usa sus propios sprites (recoloreados del goblin)
		"wolf":     tex_path = base_path + "wolf_idle_strip12.png"
		# Slime — sprites propios del craftpix pack
		"slime":    tex_path = base_path + "slime_idle_strip6.png"
		# Void Megapack — sprites propios
		"orc":      tex_path = base_path + "orc_idle_strip9.png"
		"spider":   tex_path = base_path + "spider_idle_strip4.png"
		"darkelf":  tex_path = base_path + "darkelf_idle_strip4.png"
		"wogol":    tex_path = base_path + "wogol_idle_strip4.png"
		_:          tex_path = base_path + "goblin_idle_strip12.png"
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
		var frames: int = ANIM_DATA[stype]["idle"]
		sprite.hframes = frames
		sprite.vframes = 1
		sprite.frame = 0
		# Escala y posición para sprites Sunnyside (64x64 por frame)
		sprite.scale    = Vector2(2.5, 2.5)
		sprite.position = Vector2(0, -12)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _update_sprite_anim(new_anim: String) -> void:
	if _current_anim == new_anim:
		return
	_current_anim = new_anim
	_anim_frame = 0
	_anim_frame_timer = 0.0
	_load_anim_texture(new_anim)

func _load_anim_texture(anim: String) -> void:
	# Pack Mapa Sur sprites — usa hframes/vframes con row offset
	if sprite_type in SOUTH_SPRITES:
		var sd: Dictionary = SOUTH_SPRITES[sprite_type]
		var tex_path: String = sd.get(anim, sd.get("idle", ""))
		if ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)
			sprite.hframes = sd.get("hframes", 1)
			sprite.vframes = sd.get("vframes", 1)
			var row := 0
			match anim:
				"idle":   row = sd.get("idle_row", 0)
				"walk":   row = sd.get("walk_row", sd.get("idle_row", 0))
				"attack": row = sd.get("atk_row",  sd.get("idle_row", 0))
				"hurt":   row = sd.get("hurt_row", sd.get("idle_row", 0))
				"death":  row = sd.get("death_row",sd.get("idle_row", 0))
			sprite.frame = row * sd.get("hframes", 1)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return
	# Dungeon tileset sprites are static - no animation switching
	if enemy_type in DUNGEON_STATIC_SPRITES:
		return
	var base_path := "res://assets/mobs/sunnyside/"
	var stype := sprite_type if sprite_type in ANIM_DATA else "goblin"
	var tex_path := ""
	match stype:
		"goblin":
			match anim:
				"idle":   tex_path = base_path + "goblin_idle_strip12.png"
				"walk":   tex_path = base_path + "goblin_walk_strip12.png"
				"attack": tex_path = base_path + "goblin_attack_strip13.png"
				"hurt":   tex_path = base_path + "goblin_hurt_strip12.png"
				"death":  tex_path = base_path + "goblin_death_strip13.png"
		"skeleton":
			match anim:
				"idle":   tex_path = base_path + "skeleton_idle_strip6.png"
				"walk":   tex_path = base_path + "skeleton_walk_strip8.png"
				"attack": tex_path = base_path + "skeleton_attack_strip7.png"
				"hurt":   tex_path = base_path + "skeleton_hurt_strip7.png"
				"death":  tex_path = base_path + "skeleton_death_strip10.png"
		# FIX: wolf con sprites propios (recoloreados, mismo frame count que goblin)
		"wolf":
			match anim:
				"idle":   tex_path = base_path + "wolf_idle_strip12.png"
				"walk":   tex_path = base_path + "wolf_walk_strip12.png"
				"attack": tex_path = base_path + "wolf_attack_strip13.png"
				"hurt":   tex_path = base_path + "wolf_hurt_strip12.png"
				"death":  tex_path = base_path + "wolf_death_strip13.png"
		# Slime — sprites propios del craftpix pack
		"slime":
			match anim:
				"idle":   tex_path = base_path + "slime_idle_strip6.png"
				"walk":   tex_path = base_path + "slime_walk_strip8.png"
				"attack": tex_path = base_path + "slime_attack_strip10.png"
				"hurt":   tex_path = base_path + "slime_hurt_strip5.png"
				"death":  tex_path = base_path + "slime_death_strip10.png"
		# Void Megapack — sprites propios por mob
		"orc":
			match anim:
				"idle":   tex_path = base_path + "orc_idle_strip9.png"
				"walk":   tex_path = base_path + "orc_walk_strip6.png"
				"attack": tex_path = base_path + "orc_attack_strip6.png"
				"hurt":   tex_path = base_path + "orc_hurt_strip5.png"
				"death":  tex_path = base_path + "orc_death_strip10.png"
		"spider":
			match anim:
				"idle":   tex_path = base_path + "spider_idle_strip4.png"
				"walk":   tex_path = base_path + "spider_walk_strip7.png"
				"attack": tex_path = base_path + "spider_attack_strip7.png"
				"hurt":   tex_path = base_path + "spider_hurt_strip3.png"
				"death":  tex_path = base_path + "spider_death_strip7.png"
		"darkelf":
			match anim:
				"idle":   tex_path = base_path + "darkelf_idle_strip4.png"
				"walk":   tex_path = base_path + "darkelf_walk_strip8.png"
				"attack": tex_path = base_path + "darkelf_attack_strip7.png"
				"hurt":   tex_path = base_path + "darkelf_hurt_strip3.png"
				"death":  tex_path = base_path + "darkelf_death_strip8.png"
		"wogol":
			match anim:
				"idle":   tex_path = base_path + "wogol_idle_strip4.png"
				"walk":   tex_path = base_path + "wogol_walk_strip8.png"
				"attack": tex_path = base_path + "wogol_attack_strip7.png"
				"hurt":   tex_path = base_path + "wogol_hurt_strip3.png"
				"death":  tex_path = base_path + "wogol_death_strip8.png"
	if tex_path != "" and ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
		var stype2 := sprite_type if sprite_type in ANIM_DATA else "goblin"
		var anim_key := anim if anim in ANIM_DATA[stype2] else "idle"
		sprite.hframes = ANIM_DATA[stype2][anim_key]
		sprite.frame = 0
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _tick_anim(delta: float) -> void:
	if not sprite or not sprite.texture:
		return
	_anim_frame_timer += delta
	var frame_duration := 1.0 / ANIM_FPS
	if _anim_frame_timer >= frame_duration:
		_anim_frame_timer -= frame_duration
		# South pack sprites use row-offset frame system
		if sprite_type in SOUTH_SPRITES:
			var sd: Dictionary = SOUTH_SPRITES[sprite_type]
			var hf: int = sd.get("hframes", 1)
			var anim_key := _current_anim if _current_anim in ANIM_DATA.get(sprite_type, {}) else "idle"
			var total_frames: int = ANIM_DATA.get(sprite_type, {}).get(anim_key, 1)
			var row := 0
			match _current_anim:
				"idle":   row = sd.get("idle_row", 0)
				"walk":   row = sd.get("walk_row", sd.get("idle_row", 0))
				"attack": row = sd.get("atk_row",  sd.get("idle_row", 0))
				"hurt":   row = sd.get("hurt_row", sd.get("idle_row", 0))
				"death":  row = sd.get("death_row",sd.get("idle_row", 0))
			_anim_frame = (_anim_frame + 1) % total_frames
			var target_frame: int = row * hf + _anim_frame
			var max_frame: int = sprite.hframes * sprite.vframes - 1
			if max_frame >= 0:
				sprite.frame = clampi(target_frame, 0, max_frame)
			return
		var stype := sprite_type if sprite_type in ANIM_DATA else "goblin"
		var anim_key := _current_anim if _current_anim in ANIM_DATA[stype] else "idle"
		var total_frames: int = ANIM_DATA[stype][anim_key]
		_anim_frame = (_anim_frame + 1) % total_frames
		var max_frame: int = sprite.hframes * sprite.vframes - 1
		if max_frame >= 0:
			sprite.frame = clampi(_anim_frame, 0, max_frame)

func _init_patrol() -> void:
	patrol_origin = global_position
	_generate_patrol_waypoints()
	_update_name_label()
	_setup_sprite()
	# Fase aleatoria para que no todos los mobs se muevan igual
	patrol_index = randi() % max(1, patrol_waypoints.size())
	patrol_wait_timer = randf_range(0.0, 1.5)
	is_patrol_waiting = true

func _generate_patrol_waypoints() -> void:
	patrol_waypoints.clear()
	var count = randi_range(3, 6)
	for i in count:
		var angle = (float(i) / float(count)) * TAU + randf_range(-0.25, 0.25)
		var dist  = randf_range(38.0, 85.0)
		patrol_waypoints.append(patrol_origin + Vector2(cos(angle), sin(angle)) * dist)

func _update_hp_bar() -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value     = current_hp

func _update_name_label() -> void:
	if name_label:
		var prefix = ""
		match behavior_type:
			"ranged":  prefix = "⇝ "
			"healer":  prefix = "✚ "
			"charger": prefix = "⚡ "
			"boss":    prefix = "☠ "
		name_label.text = prefix + enemy_label + " Nv." + str(enemy_level)

# ════════════════════════════════════════════════════════════
# PROCESO PRINCIPAL
# ════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	_tick_anim(delta)
	if _force_target_timer > 0.0:
		_force_target_timer -= delta
		if _force_target_timer <= 0.0:
			_force_target = null   # taunt expirado: vuelve a la threat list
	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	match state:
		State.IDLE:    _process_idle(delta)
		State.ALERT:   _process_alert(delta)
		State.CHASE:   _process_chase(delta)
		State.ATTACK:  _process_attack(delta)
		State.RETREAT: _process_retreat(delta)
		State.RETURN:  _process_return(delta)
		State.HURT:    _process_hurt(delta)
		State.DEAD:    _process_dead(delta)

	# Aplicar knockback con fricción
	if knockback_velocity.length() > 1.0:
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 8.0)
		velocity += knockback_velocity

	move_and_slide()

# ── IDLE: patrulla por waypoints ─────────────────────────────

func _process_idle(delta: float) -> void:
	_update_sprite_anim("idle")
	if behavior_type == "healer":
		_process_healer_passive(delta)

	if is_patrol_waiting:
		patrol_wait_timer -= delta
		velocity = velocity.lerp(Vector2.ZERO, delta * 6.0)
		if patrol_wait_timer <= 0.0:
			is_patrol_waiting = false
			patrol_index = (patrol_index + 1) % patrol_waypoints.size()
		return

	if patrol_waypoints.is_empty():
		_generate_patrol_waypoints()
		return

	var target = patrol_waypoints[patrol_index]
	var dir    = target - global_position

	if dir.length() < 10.0:
		is_patrol_waiting = true
		patrol_wait_timer = randf_range(0.7, 2.2)
		velocity = Vector2.ZERO
	else:
		velocity = dir.normalized() * (move_speed * 0.45)
		_flip_to(dir.x)

# ── ALERT: reacción al ver al jugador (pausa + llama aliados) ─

func _process_alert(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, delta * 10.0)
	alert_timer -= delta

	# Parpadeo amarillo de exclamación
	if sprite:
		var blink = (int(alert_timer * 12) % 2) == 0
		sprite.modulate = Color(1.6, 1.6, 0.2) if blink else Color.WHITE

	if alert_timer <= 0.0:
		if sprite:
			sprite.modulate = Color.WHITE
			pass # sprite color managed by texture
		# Llamar aliados en radio justo antes de lanzarse
		_broadcast_aggro_to_nearby()
		state = State.CHASE

# ── CHASE: perseguir con flanqueo ────────────────────────────

func _process_chase(delta: float) -> void:
	_update_sprite_anim("walk")
	if is_instance_valid(_force_target):
		player_ref = _force_target
	elif behavior_type == "boss" and is_instance_valid(boss_mechanics):
		# Sin taunt activo: el boss persigue al jugador con más threat acumulado
		var top: Node = boss_mechanics.get_top_threat_target()
		if is_instance_valid(top):
			player_ref = top

	if not is_instance_valid(player_ref):
		state = State.IDLE
		return

	var dist = global_position.distance_to(player_ref.global_position)

	# Leash — el mob se aleja demasiado del campamento → regresar
	if dist > LEASH_DISTANCE:
		state = State.RETURN
		player_ref = null
		flank_offset = Vector2.ZERO
		# Restaurar HP (comportamiento MMORPG estándar al lashear)
		current_hp = max_hp
		_update_hp_bar()
		if sprite:
			sprite.modulate = Color.WHITE
			pass # sprite color managed by texture
		return

	# Delegación por tipo de comportamiento
	match behavior_type:
		"ranged":  _chase_ranged(delta, dist); return
		"charger": _chase_charger(delta, dist); return

	# Rango de ataque normal
	if dist < 28.0:
		state = State.ATTACK
		velocity = Vector2.ZERO
		attack_timer = 0.0
		return

	# Actualizar offset de flanqueo periódicamente
	flank_timer -= delta
	if flank_timer <= 0.0:
		flank_timer = randf_range(1.2, 3.0)
		if randf() < 0.38:
			var to_player = (player_ref.global_position - global_position)
			var perp = Vector2(-to_player.y, to_player.x).normalized()
			flank_offset = perp * randf_range(18.0, 55.0)
		else:
			flank_offset = Vector2.ZERO

	var target_pos = player_ref.global_position + flank_offset
	var dir = (target_pos - global_position).normalized()
	velocity = dir * move_speed
	_flip_to(dir.x)

func _chase_ranged(delta: float, dist: float) -> void:
	var dir_to = (player_ref.global_position - global_position).normalized()
	if dist > RANGED_MAX_DIST:
		velocity = dir_to * move_speed * 0.85
	elif dist < RANGED_MIN_DIST:
		velocity = -dir_to * move_speed * 0.8   # alejarse
	else:
		# Strafe lateral para no quedarse estático
		var lateral = Vector2(-dir_to.y, dir_to.x) * (1.0 if int(Time.get_ticks_msec() / 800) % 2 == 0 else -1.0)
		velocity = lateral * move_speed * 0.45
		state = State.ATTACK
		attack_timer = 0.0
	_flip_to(dir_to.x)

func _chase_charger(delta: float, dist: float) -> void:
	# Si ya está cargando, continuar
	if is_charging:
		charge_duration -= delta
		velocity = charge_velocity
		if charge_duration <= 0.0:
			is_charging = false
		return

	charge_cd_timer -= delta
	var dir = (player_ref.global_position - global_position).normalized()

	# Iniciar carga si en rango y cooldown listo
	if dist < 200.0 and dist > 35.0 and charge_cd_timer <= 0.0:
		is_charging     = true
		charge_duration = CHARGE_DURATION
		charge_cd_timer = CHARGE_COOLDOWN
		charge_velocity = dir * move_speed * CHARGE_SPEED_MULT
		_spawn_hit_particles(global_position, Color.ORANGE)
		_spawn_hit_particles(global_position + Vector2(0, -14), Color(1.0, 0.5, 0.0))
	elif dist < 30.0:
		state = State.ATTACK
		attack_timer = 0.0
	else:
		velocity = dir * move_speed
	_flip_to(dir.x)

# ── ATTACK: atacar al jugador ─────────────────────────────────

func _process_attack(delta: float) -> void:
	_update_sprite_anim("attack")
	if not is_instance_valid(player_ref):
		state = State.IDLE
		return

	velocity = velocity.lerp(Vector2.ZERO, delta * 10.0)

	var dist = global_position.distance_to(player_ref.global_position)
	var exit_range = 45.0 if behavior_type != "ranged" else RANGED_MAX_DIST + 25.0
	if dist > exit_range:
		state = State.CHASE
		return

	if behavior_type == "healer":
		_process_healer_passive(delta)
		return

	attack_timer -= delta
	if attack_timer <= 0.0:
		# Pequeña variación para que no sea perfectamente rítmico
		attack_timer = attack_cooldown + randf_range(-0.12, 0.18)
		_do_attack()

func _do_attack() -> void:
	if not is_instance_valid(player_ref):
		return

	var final_atk = max(1, attack_power)

	if behavior_type == "ranged":
		_spawn_hit_particles(global_position + Vector2(0, -12), Color.CYAN)
		_spawn_projectile_visual()
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(player_ref):
			_apply_damage_to_player(player_ref, final_atk)
	elif behavior_type == "charger" and is_charging:
		# Daño extra durante carga
		_apply_damage_to_player(player_ref, int(final_atk * 1.6))
		_spawn_hit_particles(global_position, Color.DEEP_SKY_BLUE)
	elif behavior_type == "boss":
		# Boss: ataque en área pequeña
		_apply_damage_to_player(player_ref, final_atk)
		_spawn_hit_particles(global_position + Vector2(0, -16), Color.PURPLE)
		_spawn_hit_particles(global_position + Vector2(14, -8), Color.PURPLE)
		_spawn_hit_particles(global_position - Vector2(14, 8), Color.PURPLE)
	else:
		_apply_damage_to_player(player_ref, final_atk)
		_spawn_hit_particles(global_position + Vector2(0, -12), Color.ORANGE_RED)

# FIX v26: centralizar la aplicación de daño al jugador.
# En modo multijugador el servidor notifica al cliente vía RPC.
# En modo offline se aplica directo para mantener compatibilidad.
func _apply_damage_to_player(target: Node, amount: int) -> void:
	if not is_instance_valid(target):
		return
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.is_server:
		# Servidor: buscar el peer_id del jugador objetivo y notificarle
		var target_peer_id := _find_peer_id_for_player(target, nm)
		if target_peer_id > 0:
			print("[Server][Combat] Mob nid=%d → jugador peer %d daño=%d" % [network_id, target_peer_id, amount])
			nm.notify_player_damage(target_peer_id, amount)
		else:
			# Fallback: aplicar local en el servidor (p.ej. host jugando)
			if target.has_method("take_damage"):
				target.take_damage(amount)
	else:
		# FIX v27: en modo cliente (o sin conexión), los mobs son instancias
		# locales del cliente — aplicar el daño directamente aquí. El servidor
		# headless no tiene nodos Player en su árbol, así que no puede detectar
		# ni reenviar este daño. El cliente es fuente de verdad para el daño
		# que recibe de sus mobs locales visibles.
		if target.has_method("take_damage"):
			target.take_damage(amount)

func _find_peer_id_for_player(target: Node, nm: Node) -> int:
	# FIX v27: en vez de buscar por posición (que puede estar desactualizada
	# 50ms en un sync de 20Hz), usamos el nombre del nodo del jugador que
	# codifica su peer_id, o lo comparamos con el player local del servidor.
	# Como el servidor headless no tiene jugadores locales, buscamos en
	# online_players el peer cuya escena coincida y cuyo nodo Player sea target.
	# El método más robusto: el nodo Player en el servidor tiene nombre
	# "Player_{peer_id}" asignado al spawnearlo — lo usamos directamente.
	var node_name = target.name  # ej. "Player" o "Player_2"
	if node_name.begins_with("Player_"):
		var pid_str = node_name.substr(7)  # quitar "Player_"
		if pid_str.is_valid_int():
			return pid_str.to_int()
	# Fallback: buscar por proximidad de posición (comportamiento anterior)
	var target_pos = target.global_position
	for pid in nm.online_players:
		var pos_d = nm.online_players[pid].get("position", {"x": -99999.0, "y": -99999.0})
		var pos = Vector2(pos_d.x, pos_d.y)
		if pos.distance_to(target_pos) < 150.0:  # margen más generoso
			return pid
	# Último recurso: si solo hay un cliente conectado, devolverlo directo
	if nm.online_players.size() == 1:
		return nm.online_players.keys()[0]
	return 0

func _spawn_projectile_visual() -> void:
	if not is_instance_valid(player_ref): return
	var proj = ColorRect.new()
	proj.size    = Vector2(6, 6)
	proj.color   = Color.CYAN
	proj.z_index = 85
	proj.position = global_position
	get_tree().root.add_child(proj)
	var tw = proj.create_tween()
	tw.tween_property(proj, "global_position", player_ref.global_position, 0.12)
	tw.finished.connect(func(): if is_instance_valid(proj): proj.queue_free())

# ── RETREAT: huida táctica cuando HP bajo ─────────────────────

func _process_retreat(delta: float) -> void:
	retreat_timer -= delta
	if not is_instance_valid(player_ref):
		state = State.IDLE
		return

	var dir_away = (global_position - player_ref.global_position).normalized()
	# Añadir ligera aleatoriedad a la dirección de huida
	dir_away = (dir_away + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))).normalized()
	velocity = dir_away * move_speed * 1.4
	_flip_to(dir_away.x)

	# Modulate rojizo para indicar pánico
	if sprite and retreat_timer > 0:
		sprite.modulate = Color(1.3, 0.5, 0.5)

	if retreat_timer <= 0.0:
		if sprite:
			sprite.modulate = Color.WHITE
			pass # sprite color managed by texture
		# Volver a perseguir con rabia (si HP aún lo permite)
		if float(current_hp) / float(max_hp) < _retreat_hp_pct * 0.5:
			state = State.IDLE    # demasiado bajo, vagar
		else:
			state = State.CHASE

# ── RETURN: caminar de vuelta al origen del campamento ────────

func _process_return(delta: float) -> void:
	var dist_to_origin = global_position.distance_to(patrol_origin)
	if dist_to_origin < 25.0:
		# Llegamos: regenerar waypoints alrededor del origen correcto y patrullar
		_generate_patrol_waypoints()
		patrol_index      = 0
		is_patrol_waiting = true
		patrol_wait_timer = randf_range(0.4, 1.0)
		if sprite:
			sprite.modulate = Color.WHITE
			pass # sprite color managed by texture
		state = State.IDLE
		return
	var dir = (patrol_origin - global_position).normalized()
	velocity = dir * move_speed * 1.15
	_flip_to(dir.x)
	# Tinte azulado para indicar visualmente que el mob está regresando
	if sprite:
		sprite.modulate = Color(0.65, 0.80, 1.20)

# ── HURT ─────────────────────────────────────────────────────

func _process_hurt(delta: float) -> void:
	_update_sprite_anim("hurt")
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		if current_hp <= 0:
			_enter_dead()
		elif _should_retreat():
			state = State.RETREAT
			retreat_timer = randf_range(1.0, 2.2)
		elif is_instance_valid(player_ref):
			state = State.CHASE
		else:
			state = State.IDLE

func _should_retreat() -> bool:
	if behavior_type == "boss" or behavior_type == "healer":
		return false
	return float(current_hp) / float(max_hp) < _retreat_hp_pct

# ── DEAD ─────────────────────────────────────────────────────

func _process_dead(delta: float) -> void:
	_update_sprite_anim("death")
	dead_timer -= delta
	if dead_timer <= 0.0:
		queue_free()

func _start_dissolve() -> void:
	if not sprite:
		return
	# Usar el ShaderMaterial pre-asignado en la escena (evita version_get_shader null)
	var dissolve_mat := sprite.material as ShaderMaterial
	if dissolve_mat == null:
		# Fallback: fade clásico si no hay material asignado
		var tw_fall := create_tween()
		tw_fall.tween_property(sprite, "modulate:a", 0.0, 1.8)
		return
	dissolve_mat.set_shader_parameter("dissolve_amount", 0.0)
	# Animar dissolve_amount 0 → 1 en 1.6 s (dead_timer = 2.0)
	var tw := create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(self) and is_instance_valid(dissolve_mat):
			dissolve_mat.set_shader_parameter("dissolve_amount", v)
	, 0.0, 1.0, 1.6)

# ── HEALER PASIVO ─────────────────────────────────────────────

func _process_healer_passive(delta: float) -> void:
	heal_timer -= delta
	if heal_timer <= 0.0:
		heal_timer = HEAL_COOLDOWN
		_heal_nearby_allies()

func _heal_nearby_allies() -> void:
	var allies = get_tree().get_nodes_in_group("enemy")
	var healed_any = false
	for ally in allies:
		if not is_instance_valid(ally) or ally == self:
			continue
		if ally.state == ally.State.DEAD:
			continue
		if global_position.distance_to(ally.global_position) < HEAL_RANGE:
			var heal_amt = int(ally.max_hp * 0.12)
			ally.receive_heal(heal_amt)
			healed_any = true
	if healed_any:
		_spawn_hit_particles(global_position, Color.GREEN)
		_spawn_hit_particles(global_position + Vector2(0, -18), Color.LIME_GREEN)

func receive_heal(amount: int) -> void:
	if state == State.DEAD:
		return
	current_hp = min(max_hp, current_hp + amount)
	_update_hp_bar()
	_show_colored_label("+" + str(amount), Color.LIME_GREEN)

# ════════════════════════════════════════════════════════════
# RECIBIR DAÑO
# ════════════════════════════════════════════════════════════

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return

	# ── v22.2: enrutar por servidor si hay conexión activa ────
	var nm = get_node_or_null("/root/NetworkManager")
	var is_online_client := nm and nm.is_client and multiplayer.has_multiplayer_peer() \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

	if is_online_client and network_id != 0:
		print("[Client][Combat] Habilidad/skill → nid=%d dmg=%d" % [network_id, amount])
		nm.request_enemy_damage(network_id, amount, knockback_dir)
		# El servidor aplicará el daño y retransmitirá a todos;
		# no modificamos current_hp localmente para evitar desync.
		# Solo mostramos el estado HURT visual para feedback inmediato.
		state = State.HURT
		hurt_timer = 0.18
		if not is_instance_valid(player_ref):
			player_ref = get_tree().get_first_node_in_group("player")
		_broadcast_aggro_to_nearby()
		return

	# FIX BUG "DOS MUNDOS": si estamos online pero este mob todavía no fue
	# emparejado con el servidor (network_id == 0 por una carrera de timing
	# al cargar la zona), NO debemos aplicar el daño localmente — eso es
	# exactamente lo que causaba que un jugador "limpiara" un camp en su
	# propio cliente sin que el servidor (fuente de verdad) se enterara,
	# dejando al otro jugador viendo el camp lleno todavía. En vez de eso:
	# mostramos feedback visual de que el golpe no contó, y pedimos un
	# resync inmediato (sin esperar el siguiente tick de reintento) para
	# resolver el emparejamiento lo antes posible.
	if is_online_client and network_id == 0:
		print("[Client][Combat] Golpe descartado — mob aún sin sincronizar (nid=0). Forzando resync.")
		_show_colored_label("...", Color(0.6, 0.8, 1.0))
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_forced_resync_time >= FORCED_RESYNC_COOLDOWN:
			_last_forced_resync_time = now
			if nm.has_method("request_enemy_resync"):
				nm.request_enemy_resync.rpc_id(1)
		return

	# ── Offline: aplicar directamente ─────────────────────────

	var dmg = max(1, amount - defense)
	current_hp -= dmg
	_update_hp_bar()
	_show_colored_label("-" + str(dmg), Color.WHITE)

	if knockback_dir.length() > 0.01:
		knockback_velocity = knockback_dir * 120.0

	_spawn_hit_particles(global_position + Vector2(0, -12), Color.YELLOW)

	state = State.HURT
	hurt_timer = 0.18

	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")

	_broadcast_aggro_to_nearby()

	# ── Hit flash blanco via shader ──────────────────────────
	# La cadena es: outline(material) → flash(next_pass) → dissolve(next_pass.next_pass)
	if sprite:
		var _mat: ShaderMaterial = null
		if sprite.material is ShaderMaterial and sprite.material.next_pass is ShaderMaterial:
			_mat = sprite.material.next_pass as ShaderMaterial
		elif sprite.material is ShaderMaterial:
			_mat = sprite.material as ShaderMaterial
		if _mat is ShaderMaterial:
			_mat.set_shader_parameter("flash_amount", 1.0)
			var _flash_tween := create_tween()
			_flash_tween.tween_method(func(v: float):
				if is_instance_valid(self) and is_instance_valid(_mat):
					_mat.set_shader_parameter("flash_amount", v)
			, 1.0, 0.0, 0.12)
		else:
			# fallback si el shader no cargó
			sprite.modulate = Color(2.0, 2.0, 2.0)
			var _flash_tween = create_tween()
			_flash_tween.tween_interval(0.1)
			_flash_tween.tween_callback(func():
				if is_instance_valid(self) and is_instance_valid(sprite) and state != State.DEAD:
					sprite.modulate = Color.WHITE
			)

# ── Aggro grupal ──────────────────────────────────────────────

# PASO 13 — Iconos de estado sobre el personaje
# Llama a esta función desde weapon_skill_system o cualquier lugar
# que aplique un debuff. type puede ser "poison", "burn" o "freeze".
var _active_status_icons: Dictionary = {}  # type → Sprite2D

func apply_status_icon(type: String, duration: float) -> void:
	# Si ya existe ese icono, extender su duración eliminando el anterior
	if _active_status_icons.has(type) and is_instance_valid(_active_status_icons[type]):
		_active_status_icons[type].queue_free()
		_active_status_icons.erase(type)

	var icon_path: String = "res://assets/ui/status/status_%s.png" % type
	if not ResourceLoader.exists(icon_path):
		return

	var tex = ResourceLoader.load(icon_path, "Texture2D")
	if not tex:
		return

	var icon_sp := Sprite2D.new()
	icon_sp.texture = tex
	icon_sp.scale   = Vector2(0.5, 0.5)  # 16×16 efectivos desde 32×32
	icon_sp.z_index = 90
	# Posición sobre la cabeza del sprite
	var sprite_h: float = 24.0
	icon_sp.position = Vector2(0.0, -sprite_h - 8.0)
	add_child(icon_sp)
	_active_status_icons[type] = icon_sp

	# Quitar al terminar la duración
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(icon_sp):
			icon_sp.queue_free()
		_active_status_icons.erase(type)
	)


func _broadcast_aggro_to_nearby() -> void:
	if not is_instance_valid(player_ref):
		return
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	for ally in all_enemies:
		if not is_instance_valid(ally) or ally == self:
			continue
		if ally.state == ally.State.DEAD or ally.state == ally.State.CHASE or ally.state == ally.State.ATTACK:
			continue
		if global_position.distance_to(ally.global_position) < AGGRO_BROADCAST_RADIUS:
			if ally.has_method("enter_group_alert"):
				ally.enter_group_alert(player_ref)

## Método público: aliado nos avisa de la presencia del jugador
func enter_group_alert(target: Node) -> void:
	if state == State.IDLE or state == State.ALERT:
		player_ref = target
		state      = State.ALERT
		alert_timer = randf_range(0.15, 0.55)   # retraso escalonado

# ── Muerte ─────────────────────────────────────────────────

func _enter_dead() -> void:
	state     = State.DEAD
	dead_timer = 2.0
	_set_outline(false)
	_start_dissolve()

	if collision:  collision.set_deferred("disabled", true)
	if hitbox:
		hitbox.monitoring  = false
		hitbox.monitorable = false
	if aggro_area:
		aggro_area.monitoring = false

	_drop_rewards()

	# Partículas de muerte
	_spawn_hit_particles(global_position, Color.RED)
	_spawn_hit_particles(global_position + Vector2(8, -8), Color.ORANGE)

	# Notificar al campamento
	if _camp_death_callback.is_valid():
		_camp_death_callback.call()

	# FIX v19: emitir señal para que los world scripts detecten muerte del boss
	enemy_died.emit()

func _drop_rewards() -> void:
	if EnemyManager:
		EnemyManager.on_enemy_died(self)
		var _am = get_node_or_null("/root/AchievementManager")
		if _am: _am.on_enemy_killed()

	# ── v22.2: si hay red, el servidor ya repartió loot via _rpc_enemy_killed ──
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.is_client and network_id != 0:
		# El servidor habrá enviado _rpc_enemy_killed antes de que lleguemos aquí.
		# No repartir loot localmente para evitar duplicados.
		return

	# ── Offline / servidor: repartir loot localmente ──────────
	if loot_main != "" and randf() < 0.7:
		InventoryManager.add_item(loot_main, 1)
		_show_loot_text(loot_main)
	if loot_extra != "" and randf() < 0.3:
		InventoryManager.add_item(loot_extra, 1)
		_show_loot_text(loot_extra)

	if bronze_max > 0:
		var drop = randi_range(bronze_min, bronze_max)
		if drop > 0:
			PlayerData.add_bronze(drop)
			_show_loot_text("🥉 +" + str(drop))

	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("gain_xp"):
		player.gain_xp(xp_reward)
	else:
		PlayerData.gain_xp(xp_reward)

	if has_node("/root/PartyManager"):
		PartyManager.share_xp(xp_reward, global_position)

# ════════════════════════════════════════════════════════════
# EFECTOS VISUALES
# ════════════════════════════════════════════════════════════

func _flip_to(dir_x: float) -> void:
	if sprite and dir_x != 0:
		sprite.flip_h = dir_x < 0

func _show_colored_label(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 13)
	label.position = Vector2(-10, -40)
	label.z_index  = 100
	add_child(label)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.finished.connect(func(): if is_instance_valid(label): label.queue_free())

func _show_loot_text(item_name: String) -> void:
	var label = Label.new()
	label.text = item_name
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	label.add_theme_font_size_override("font_size", 11)
	label.position = Vector2(-30, -60)
	label.z_index  = 100
	add_child(label)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 1.4)
	tween.tween_property(label, "modulate:a", 0.0, 1.4)
	tween.finished.connect(func(): if is_instance_valid(label): label.queue_free())

func _spawn_hit_particles(pos: Vector2, color: Color) -> void:
	for i in range(5):
		var p = ColorRect.new()
		p.size     = Vector2(4, 4)
		p.color    = color
		p.position = pos
		p.z_index  = 90
		get_tree().root.add_child(p)
		var tw  = p.create_tween().set_parallel(true)
		var dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() \
				  * randf_range(20.0, 60.0)
		tw.tween_property(p, "position", pos + dir, 0.3)
		tw.tween_property(p, "modulate:a", 0.0, 0.3)
		tw.finished.connect(func(): if is_instance_valid(p): p.queue_free())

# ════════════════════════════════════════════════════════════
# SEÑALES DE ÁREA
# ════════════════════════════════════════════════════════════

func _on_aggro_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and (state == State.IDLE or state == State.ALERT):
		player_ref  = body
		state       = State.ALERT
		alert_timer = randf_range(0.3, 0.75)
		attack_timer = 0.0
		_set_outline(true)

func _set_outline(enabled: bool) -> void:
	if sprite and sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("outline_enabled", enabled)

func _on_aggro_body_exited(_body: Node2D) -> void:
	_set_outline(false)

# ════════════════════════════════════════════════════════════
# MÉTODOS PARA WeaponSkillSystem
# ════════════════════════════════════════════════════════════

## Aturde al enemigo por `duration` segundos.
func apply_stun(duration: float) -> void:
	_stun_timer = max(_stun_timer, duration)

## Impulso de knockback adicional.
func apply_knockback(impulse: Vector2) -> void:
	knockback_velocity += impulse

## Fuerza al enemigo a perseguir a `target`.
func force_target(target: Node) -> void:
	_force_target = target
	# Para bosses con threat real, el taunt dura 4s y luego vuelve a la threat list
	_force_target_timer = 4.0 if behavior_type == "boss" else 0.0
	if state == State.IDLE or state == State.CHASE:
		player_ref = target
		state      = State.ALERT
		alert_timer = 0.2
