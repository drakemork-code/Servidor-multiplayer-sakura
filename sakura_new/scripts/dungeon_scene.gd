# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node2D

# ============================================================
# DUNGEON SCENE — Dungeon of Sakura v3.1
# Layout completamente rediseñado con salas geométricamente
# conectadas y verificadas. Todas las conexiones son exactas.
# ============================================================

const TILE_SIZE: int = 32  # 16px sprite escalado x2

# ── Rutas de assets ──────────────────────────────────────────
const T_FLOOR        := "res://assets/tiles/dungeon/floor_plain.png"
const T_FLOOR_LIGHT  := "res://assets/tiles/dungeon/floor_light.png"
const T_FLOOR_STAIN  := "res://assets/tiles/dungeon/floor_stain_1.png"
const T_FLOOR_GOO    := "res://assets/tiles/dungeon/floor_stain_goo.png"
const T_FLOOR_PUDDLE := "res://assets/tiles/dungeon/floor_gargoyle_red_puddle.png"
const T_WALL_FRONT   := "res://assets/tiles/dungeon/wall_front.png"
const T_WALL_FL      := "res://assets/tiles/dungeon/wall_front_left.png"
const T_WALL_FR      := "res://assets/tiles/dungeon/wall_front_right.png"
const T_WALL_MID     := "res://assets/tiles/dungeon/wall_center.png"
const T_WALL_LEFT    := "res://assets/tiles/dungeon/wall_left.png"
const T_WALL_RIGHT   := "res://assets/tiles/dungeon/wall_right.png"
const T_WALL_TOP_C   := "res://assets/tiles/dungeon/wall_top_center.png"
const T_WALL_TOP_L   := "res://assets/tiles/dungeon/wall_top_left.png"
const T_WALL_TOP_R   := "res://assets/tiles/dungeon/wall_top_right.png"
const T_WALL_ONW     := "res://assets/tiles/dungeon/wall_outer_nw.png"
const T_WALL_ONE     := "res://assets/tiles/dungeon/wall_outer_ne.png"
const T_WALL_OSW     := "res://assets/tiles/dungeon/wall_outer_sw.png"
const T_WALL_OSE     := "res://assets/tiles/dungeon/wall_outer_se.png"
const T_WALL_ON      := "res://assets/tiles/dungeon/wall_outer_n.png"
const T_WALL_INE     := "res://assets/tiles/dungeon/wall_inner_ne.png"
const T_WALL_INW     := "res://assets/tiles/dungeon/wall_inner_nw.png"
const T_WALL_GAR     := "res://assets/tiles/dungeon/wall_gargoyle_red_1.png"
const T_WALL_GOO     := "res://assets/tiles/dungeon/wall_goo.png"

const D_TORCH_1      := "res://assets/decorations/dungeon/torch_1.png"
const D_TORCH_2      := "res://assets/decorations/dungeon/torch_2.png"
const D_TORCH_3      := "res://assets/decorations/dungeon/torch_3.png"
const D_TORCH_4      := "res://assets/decorations/dungeon/torch_4.png"
const D_COLUMN       := "res://assets/decorations/dungeon/column.png"
const D_SKULL        := "res://assets/decorations/dungeon/skull.png"
const D_BOX          := "res://assets/decorations/dungeon/box.png"
const D_BOXES        := "res://assets/decorations/dungeon/boxes_stacked.png"
const D_CHEST_C      := "res://assets/decorations/dungeon/chest_closed.png"
const D_CHEST_O      := "res://assets/decorations/dungeon/chest_open_full.png"
const D_CHEST_GC     := "res://assets/decorations/dungeon/chest_golden_closed.png"
const D_CHEST_GO     := "res://assets/decorations/dungeon/chest_golden_open_full.png"
const D_STAIRS       := "res://assets/decorations/dungeon/stairs_mid.png"
const D_FLAG         := "res://assets/decorations/dungeon/wall_flag_red.png"

# ── Preload de texturas frecuentes ───────────────────────────
var _tex_cache: Dictionary = {}

func _get_tex(path: String) -> Texture2D:
	if path in _tex_cache:
		return _tex_cache[path]
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		_tex_cache[path] = t
		return t
	return null

# ── Torch textures list for animation ────────────────────────
var _torch_textures: Array = []

# ═════════════════════════════════════════════════════════════
# LAYOUT — todas las salas verificadas geométricamente
# [rx, ry, rw, rh, room_type]  — coordenadas en TILES
#
# MAPA (esquemático):
#   [Sala4 Oeste] ──── [INICIO] ──── [Pasillo] ── [Sala2 Guardia] ── [Pasillo] ── [Sala3 Este]
#                                       │
#                                   [Pasillo]
#                                       │
#                               [MINIBOSS 1 Cripta]
#                              /         │         \
#                   [Pas] ──[Sala7]   [Pasillo]  [Sala6 Magia]── [Pas]
#                                       │
#                               [MINIBOSS 2 Nigromante]
#                              /         │         \
#                  [Pas] ──[Sala10]  [Pasillo]  [Sala9]── [Pas]
#                                       │
#                                   [Antesala]
#                                       │
#                                 [BOSS — Azathiel]
# ═════════════════════════════════════════════════════════════
const ROOMS: Array = [
	# ── Sala de inicio  px x[0,384] y[0,256] ─────────────────
	[  0,  0, 12,  8, "start"],
	# ── Pasillo S desde inicio  px x[128,256] y[256,384] ─────
	[  4,  8,  4,  4, "corridor"],
	# ── Sala 2 Guardia  px x[0,512] y[384,704] ───────────────
	[  0, 12, 16, 10, "normal"],
	# ── Pasillo E desde sala 2  px x[512,672] y[448,576] ─────
	[ 16, 14,  5,  4, "corridor"],
	# ── Sala 3 Este  px x[672,1120] y[320,704] ───────────────
	[ 21, 10, 14, 12, "normal"],
	# ── Pasillo S desde sala 2 hacia miniboss  px x[128,256] y[704,832] ──
	[  4, 22,  4,  4, "corridor"],
	# ── Sala 4 Oeste (pegada al inicio)  px x[-448,0] y[0,256] ──
	[-14,  0, 14,  8, "normal"],
	# ── MINIBOSS 1 Cripta  px x[-128,384] y[832,1216] ────────
	[ -4, 26, 16, 12, "miniboss"],
	# ── Pasillo E desde miniboss1  px x[384,544] y[960,1088] ─
	[ 12, 30,  5,  4, "corridor"],
	# ── Sala 6 Magia  px x[544,992] y[832,1216] ──────────────
	[ 17, 26, 14, 12, "normal"],
	# ── Pasillo W desde miniboss1  px x[-320,-128] y[960,1088]
	[-10, 30,  6,  4, "corridor"],
	# ── Sala 7 Celda  px x[-704,-320] y[768,1152] ────────────
	[-22, 24, 12, 12, "normal"],
	# ── Pasillo S desde miniboss1  px x[64,192] y[1216,1344] ─
	[  2, 38,  4,  4, "corridor"],
	# ── MINIBOSS 2 Nigromante  px x[-192,384] y[1344,1728] ───
	[ -6, 42, 18, 12, "miniboss"],
	# ── Pasillo E desde miniboss2  px x[384,544] y[1472,1600] 
	[ 12, 46,  5,  4, "corridor"],
	# ── Sala 9 Este  px x[544,992] y[1344,1728] ──────────────
	[ 17, 42, 14, 12, "normal"],
	# ── Pasillo W desde miniboss2  px x[-384,-192] y[1472,1600]
	[-12, 46,  6,  4, "corridor"],
	# ── Sala 10 Oeste  px x[-768,-384] y[1280,1664] ──────────
	[-24, 40, 12, 12, "normal"],
	# ── Pasillo S desde miniboss2  px x[64,192] y[1728,1856] ─
	[  2, 54,  4,  4, "corridor"],
	# ── Antesala  px x[-256,448] y[1856,2112] ────────────────
	[ -8, 58, 22,  8, "normal"],
	# ── Pasillo S desde antesala  px x[64,192] y[2112,2240] ──
	[  2, 66,  4,  4, "corridor"],
	# ── SALA DEL BOSS  px x[-448,640] y[2240,2816] ───────────
	[-14, 70, 34, 18, "boss"],
]

# ═════════════════════════════════════════════════════════════
# SPAWNS DE ENEMIGOS — centros calculados con los bounds reales
# ═════════════════════════════════════════════════════════════
const ENEMY_SPAWNS: Array = [
	# ── Sala 2 Guardia  x[0,512] y[384,704] ──────────────────
	[Vector2( 128, 500), "imp",       2],
	[Vector2( 280, 460), "bat",       2],
	[Vector2( 400, 500), "imp",       2],
	[Vector2( 200, 620), "bat",       2],
	[Vector2( 370, 620), "bat",       2],
	# ── Sala 3 Este  x[672,1120] y[320,704] ──────────────────
	[Vector2( 750, 450), "zombie",    3],
	[Vector2( 880, 400), "wogol",     3],
	[Vector2(1010, 450), "zombie",    3],
	[Vector2( 800, 600), "wogol",     3],
	[Vector2(1060, 580), "bat",       3],
	# ── Sala 4 Oeste  x[-448,0] y[0,256] ─────────────────────
	[Vector2(-340, 100), "imp",       2],
	[Vector2(-200, 100), "bat",       2],
	[Vector2(-280, 190), "imp",       2],
	# ── MINIBOSS 1  x[-128,384] y[832,1216] ──────────────────
	[Vector2( -60, 950), "ogre",      4],
	[Vector2( 240, 950), "ogre",      4],
	[Vector2(-100,1060), "wogol",     4],
	[Vector2( 280,1060), "wogol",     4],
	[Vector2( 100,1020), "chort",     1],   # MINIBOSS 1
	# ── Sala 6 Magia  x[544,992] y[832,1216] ─────────────────
	[Vector2( 620, 950), "elemental_fire", 4],
	[Vector2( 760,1000), "imp",            4],
	[Vector2( 900, 950), "elemental_fire", 4],
	[Vector2( 680,1130), "imp",            4],
	[Vector2( 840,1130), "bies",           4],
	# ── Sala 7 Celda  x[-704,-320] y[768,1152] ───────────────
	[Vector2(-620, 900), "demonolog",  4],
	[Vector2(-440, 900), "demonolog",  4],
	[Vector2(-540,1020), "dark_knight",4],
	[Vector2(-400,1080), "bat",        4],
	# ── MINIBOSS 2  x[-192,384] y[1344,1728] ─────────────────
	[Vector2(-100,1460), "zombie",     5],
	[Vector2( 260,1460), "zombie",     5],
	[Vector2(-140,1570), "ogre",       4],
	[Vector2( 300,1570), "ogre",       4],
	[Vector2(  80,1530), "necromancer",1],  # MINIBOSS 2
	# ── Sala 9 Este  x[544,992] y[1344,1728] ─────────────────
	[Vector2( 620,1460), "bies",       5],
	[Vector2( 860,1460), "zombie",     5],
	[Vector2( 680,1600), "elemental_fire",5],
	[Vector2( 860,1600), "bies",       5],
	# ── Sala 10 Oeste  x[-768,-384] y[1280,1664] ─────────────
	[Vector2(-700,1400), "zombie",     5],
	[Vector2(-480,1400), "zombie",     5],
	[Vector2(-620,1530), "dark_knight",5],
	[Vector2(-480,1580), "bat",        5],
	# ── Antesala  x[-256,448] y[1856,2112] ───────────────────
	[Vector2(-160,1960), "dark_knight",5],
	[Vector2( 320,1960), "dark_knight",5],
	[Vector2(  80,2010), "elemental_fire",5],
	[Vector2(-100,2060), "elemental_fire",5],
	[Vector2( 260,2060), "elemental_fire",5],
]

# Boss al centro de la sala del boss x[-448,640] y[2240,2816]
const BOSS_POSITION: Vector2 = Vector2(96, 2528)

# ═════════════════════════════════════════════════════════════
# DECORACIONES
# ═════════════════════════════════════════════════════════════
const DECORATIONS: Array = [
	# Inicio — escaleras al tope de la sala (junto al trigger de salida)
	[Vector2( 160,  32), "stairs"],
	[Vector2(  32,  32), "flag"],
	# Sala 2 Guardia
	[Vector2(  64, 420), "skull"],
	[Vector2( 420, 420), "skull"],
	[Vector2( 240, 500), "boxes"],
	[Vector2( 160, 600), "chest"],
	[Vector2( 350, 580), "stain"],
	[Vector2(  96, 460), "flag"],
	# Sala 3 Este
	[Vector2( 720, 380), "skull"],
	[Vector2(1060, 380), "skull"],
	[Vector2( 850, 460), "boxes"],
	[Vector2( 750, 600), "chest"],
	[Vector2( 980, 580), "stain"],
	[Vector2( 850, 360), "flag"],
	# Sala 4 Oeste
	[Vector2(-380,  80), "box"],
	[Vector2(-240,  80), "skull"],
	[Vector2(-300, 160), "stain"],
	[Vector2(-160, 180), "chest"],
	# Miniboss 1 — columnas simétricas
	[Vector2(-100, 900), "column"],
	[Vector2( 300, 900), "column"],
	[Vector2(-100,1100), "column"],
	[Vector2( 300,1100), "column"],
	[Vector2(  32,1150), "skull"],
	[Vector2( 160,1150), "skull"],
	[Vector2(  96,1150), "boxes"],
	# Sala 6 Magia
	[Vector2( 580, 870), "flag"],
	[Vector2( 940, 870), "flag"],
	[Vector2( 760,1080), "chest"],
	[Vector2( 640,1100), "stain"],
	[Vector2( 900,1120), "box"],
	# Sala 7 Celda
	[Vector2(-660, 820), "column"],
	[Vector2(-380, 820), "column"],
	[Vector2(-560,1080), "skull"],
	[Vector2(-440,1080), "skull"],
	[Vector2(-500,1020), "stain"],
	[Vector2(-620, 960), "chest"],
	# Miniboss 2 — columnas
	[Vector2(-140,1380), "column"],
	[Vector2( 320,1380), "column"],
	[Vector2(-140,1600), "column"],
	[Vector2( 320,1600), "column"],
	[Vector2(  32,1660), "skull"],
	[Vector2( 160,1660), "skull"],
	# Sala 9
	[Vector2( 580,1380), "flag"],
	[Vector2( 940,1380), "flag"],
	[Vector2( 760,1560), "chest"],
	[Vector2( 640,1600), "stain"],
	# Sala 10
	[Vector2(-700,1320), "column"],
	[Vector2(-420,1320), "column"],
	[Vector2(-600,1580), "skull"],
	[Vector2(-460,1580), "boxes"],
	[Vector2(-660,1480), "chest"],
	# Antesala
	[Vector2(-200,1900), "column"],
	[Vector2( 380,1900), "column"],
	[Vector2(-180,2040), "flag"],
	[Vector2( 380,2040), "flag"],
	[Vector2(  32,2040), "skull"],
	[Vector2( 160,2040), "skull"],
	# Sala del Boss
	[Vector2(-380,2300), "column"],
	[Vector2( 540,2300), "column"],
	[Vector2(-380,2560), "column"],
	[Vector2( 540,2560), "column"],
	[Vector2(-300,2300), "column"],
	[Vector2( 460,2300), "column"],
	[Vector2(-300,2560), "column"],
	[Vector2( 460,2560), "column"],
	[Vector2(  96,2720), "boss_chest"],
	[Vector2(-160,2720), "skull"],
	[Vector2( 350,2720), "skull"],
	[Vector2( -64,2560), "puddle"],
	[Vector2( 224,2560), "puddle"],
	[Vector2(  96,2280), "flag"],
]

# ═════════════════════════════════════════════════════════════
# ANTORCHAS
# ═════════════════════════════════════════════════════════════
const TORCH_POSITIONS: Array = [
	# Inicio
	Vector2(  64, 160), Vector2( 300, 160),
	# Sala 2
	Vector2(  64, 430), Vector2( 450, 430),
	Vector2(  64, 650), Vector2( 450, 650),
	# Sala 3
	Vector2( 700, 360), Vector2(1090, 360),
	Vector2( 700, 660), Vector2(1090, 660),
	# Sala 4
	Vector2(-420,  60), Vector2(-110,  60),
	Vector2(-420, 200), Vector2(-110, 200),
	# Miniboss 1
	Vector2(-100, 870), Vector2( 340, 870),
	Vector2(-100,1180), Vector2( 340,1180),
	# Sala 6
	Vector2( 570, 870), Vector2( 960, 870),
	Vector2( 570,1180), Vector2( 960,1180),
	# Sala 7
	Vector2(-680, 810), Vector2(-360, 810),
	Vector2(-680,1120), Vector2(-360,1120),
	# Miniboss 2
	Vector2(-160,1380), Vector2( 350,1380),
	Vector2(-160,1690), Vector2( 350,1690),
	# Sala 9
	Vector2( 570,1380), Vector2( 960,1380),
	Vector2( 570,1690), Vector2( 960,1690),
	# Sala 10
	Vector2(-720,1320), Vector2(-410,1320),
	Vector2(-720,1630), Vector2(-410,1630),
	# Antesala
	Vector2(-220,1900), Vector2( 400,1900),
	Vector2(-220,2080), Vector2( 400,2080),
	# Boss room
	Vector2(-400,2280), Vector2( 560,2280),
	Vector2(-400,2760), Vector2( 560,2760),
	Vector2(-160,2400), Vector2( 320,2400),
]

# ═════════════════════════════════════════════════════════════
# ESTADO
# ═════════════════════════════════════════════════════════════
var boss_spawned:      bool  = false
var boss_defeated:     bool  = false
var enemies_remaining: int   = 0
var _exit_enabled:     bool  = false

var _torch_nodes:   Array = []
var _torch_lights:  Array = []
var _chest_sprites: Dictionary = {}

var _walls_body: StaticBody2D
var _canvas_mod: CanvasModulate

# ═════════════════════════════════════════════════════════════
# INIT
# ═════════════════════════════════════════════════════════════
func _ready() -> void:
	print("[DungeonScene] v3.1 — layout rediseñado, cargando...")
	GameManager.set_zone("dungeon")
	GameManager.is_in_dungeon = true

	_load_torch_textures()
	_build_dungeon_geometry()
	_setup_ambient_light()
	_place_decorations_and_chests()
	_place_torches()
	_setup_exit_trigger()
	_setup_boss_trigger()
	_setup_player_spawn()
	_setup_chest_interaction()

	await get_tree().process_frame
	_spawn_dungeon_enemies()

	get_tree().create_timer(1.0).timeout.connect(func(): _exit_enabled = true)
	_notify_hud_dungeon_mode(true)
	# ── Música de zona ───────────────────────────────────────
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_zone_music("dungeon")
	print("[DungeonScene] Lista. Salas: ", ROOMS.size(), " | Enemigos: ", enemies_remaining)

func _load_torch_textures() -> void:
	_torch_textures = [
		_get_tex(D_TORCH_1),
		_get_tex(D_TORCH_2),
		_get_tex(D_TORCH_3),
		_get_tex(D_TORCH_4),
	]

# ═════════════════════════════════════════════════════════════
# GEOMETRÍA
# ═════════════════════════════════════════════════════════════
func _build_dungeon_geometry() -> void:
	# Si ya existe "Floors" colocado desde el editor, respetar y no regenerar.
	if has_node("Floors"):
		return
	var floor_node = Node2D.new()
	floor_node.name = "Floors"
	add_child(floor_node)

	_walls_body = StaticBody2D.new()
	_walls_body.name = "Walls"
	add_child(_walls_body)

	for room_data in ROOMS:
		var rx: int    = room_data[0]
		var ry: int    = room_data[1]
		var rw: int    = room_data[2]
		var rh: int    = room_data[3]
		var rtype: String = room_data[4]
		_build_room(floor_node, rx, ry, rw, rh, rtype)

func _build_room(floor_node: Node2D, rx: int, ry: int, rw: int, rh: int, rtype: String) -> void:
	var px: int = rx * TILE_SIZE
	var py: int = ry * TILE_SIZE

	# ── Piso ─────────────────────────────────────────────────
	for row in range(rh):
		for col in range(rw):
			var fx: int = px + col * TILE_SIZE
			var fy: int = py + row * TILE_SIZE
			var use_light: bool = (rtype in ["miniboss", "boss"]) or (row == rh / 2 and col == rw / 2)
			_add_floor_sprite(floor_node, fx, fy, use_light)

	# ── Pared norte ───────────────────────────────────────────
	_add_wall_sprite(px - TILE_SIZE,       py - TILE_SIZE, T_WALL_ONW)
	_add_wall_sprite(px + rw * TILE_SIZE,  py - TILE_SIZE, T_WALL_ONE)
	for col in range(rw):
		_add_wall_sprite(px + col * TILE_SIZE, py - TILE_SIZE, T_WALL_TOP_C)
	_add_wall_col_collision(px - TILE_SIZE, py - TILE_SIZE, rw + 2, 1)

	# ── Pared sur ─────────────────────────────────────────────
	_add_wall_sprite(px - TILE_SIZE,       py + rh * TILE_SIZE, T_WALL_OSW)
	_add_wall_sprite(px + rw * TILE_SIZE,  py + rh * TILE_SIZE, T_WALL_OSE)
	for col in range(rw):
		_add_wall_sprite(px + col * TILE_SIZE, py + rh * TILE_SIZE, T_WALL_MID)
	_add_wall_col_collision(px - TILE_SIZE, py + rh * TILE_SIZE, rw + 2, 1)

	# ── Pared oeste ───────────────────────────────────────────
	for row in range(rh):
		_add_wall_sprite(px - TILE_SIZE, py + row * TILE_SIZE, T_WALL_LEFT)
	_add_wall_col_collision(px - TILE_SIZE, py, 1, rh)

	# ── Pared este ────────────────────────────────────────────
	for row in range(rh):
		_add_wall_sprite(px + rw * TILE_SIZE, py + row * TILE_SIZE, T_WALL_RIGHT)
	_add_wall_col_collision(px + rw * TILE_SIZE, py, 1, rh)

	# ── Frente visual norte ───────────────────────────────────
	for col in range(rw):
		_add_wall_sprite(px + col * TILE_SIZE, py - TILE_SIZE * 2, T_WALL_FRONT)

	# ── Deco especial por tipo ────────────────────────────────
	if rtype == "boss":
		_add_wall_sprite(px,                          py - TILE_SIZE, T_WALL_GAR)
		_add_wall_sprite(px + (rw - 1) * TILE_SIZE,  py - TILE_SIZE, T_WALL_GAR)
		_add_wall_sprite(px + int(rw / 2) * TILE_SIZE, py - TILE_SIZE, T_WALL_GAR)
	elif rtype == "miniboss":
		_add_wall_sprite(px,                          py - TILE_SIZE, T_WALL_GOO)
		_add_wall_sprite(px + (rw - 1) * TILE_SIZE,  py - TILE_SIZE, T_WALL_GOO)

func _add_floor_sprite(parent: Node2D, x: int, y: int, lit: bool) -> void:
	var sp := Sprite2D.new()
	sp.texture  = _get_tex(T_FLOOR_LIGHT if lit else T_FLOOR)
	sp.position = Vector2(x + TILE_SIZE / 2, y + TILE_SIZE / 2)
	sp.scale    = Vector2(2.0, 2.0)
	sp.centered = true
	parent.add_child(sp)

func _add_wall_sprite(x: int, y: int, tex_path: String) -> void:
	var sp := Sprite2D.new()
	sp.texture  = _get_tex(tex_path)
	sp.position = Vector2(x + TILE_SIZE / 2, y + TILE_SIZE / 2)
	sp.scale    = Vector2(2.0, 2.0)
	sp.centered = true
	sp.z_index  = 1
	_walls_body.add_child(sp)

func _add_wall_col_collision(x: int, y: int, cols: int, rows: int) -> void:
	var shape    := CollisionShape2D.new()
	var rect     := RectangleShape2D.new()
	rect.size     = Vector2(cols * TILE_SIZE, rows * TILE_SIZE)
	shape.shape   = rect
	shape.position = Vector2(
		x + cols * TILE_SIZE / 2,
		y + rows * TILE_SIZE / 2
	)
	_walls_body.add_child(shape)

# ═════════════════════════════════════════════════════════════
# LUZ AMBIENTE
# ═════════════════════════════════════════════════════════════
func _setup_ambient_light() -> void:
	_canvas_mod       = CanvasModulate.new()
	_canvas_mod.color = Color(0.12, 0.09, 0.18)
	add_child(_canvas_mod)

# ═════════════════════════════════════════════════════════════
# ANTORCHAS
# ═════════════════════════════════════════════════════════════
func _place_torches() -> void:
	# Si ya existe "Torches" colocado desde el editor, respetar y no regenerar.
	if has_node("Torches"):
		return
	for pos in TORCH_POSITIONS:
		_place_torch(pos)

func _place_torch(pos: Vector2) -> void:
	var sp := Sprite2D.new()
	sp.texture  = _torch_textures[0] if _torch_textures.size() > 0 else null
	sp.position = pos
	sp.scale    = Vector2(2.0, 2.0)
	sp.z_index  = 4
	add_child(sp)
	_torch_nodes.append(sp)

	var light           := PointLight2D.new()
	light.position       = pos
	light.texture        = _create_light_texture()
	light.energy         = 1.0
	light.texture_scale  = 3.5
	light.color          = Color(1.0, 0.60, 0.20, 0.85)
	light.z_index        = 3
	add_child(light)
	_torch_lights.append(light)

func _create_light_texture() -> GradientTexture2D:
	var gt   := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.add_point(0.0, Color(1, 1, 1, 1))
	grad.add_point(1.0, Color(1, 1, 1, 0))
	gt.gradient  = grad
	gt.width     = 64
	gt.height    = 64
	gt.fill      = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to   = Vector2(1.0, 0.5)
	return gt

# ═════════════════════════════════════════════════════════════
# DECORACIONES Y COFRES
# ═════════════════════════════════════════════════════════════
func _place_decorations_and_chests() -> void:
	# Si ya existe "Decorations" colocado desde el editor, respetar y no regenerar.
	if has_node("Decorations"):
		return
	for deco in DECORATIONS:
		var pos: Vector2  = deco[0]
		var dtype: String = deco[1]
		_place_deco(pos, dtype)

func _place_deco(pos: Vector2, dtype: String) -> void:
	match dtype:
		"skull":
			_add_deco_sprite(pos, D_SKULL, 1.8, 3)
		"box":
			_add_deco_sprite(pos, D_BOX, 2.0, 3)
		"boxes":
			_add_deco_sprite(pos, D_BOXES, 2.0, 3)
		"column":
			_add_deco_sprite(pos, D_COLUMN, 2.0, 3)
			var col_body := StaticBody2D.new()
			col_body.position = pos + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(24, 24)
			cs.shape = rect
			col_body.add_child(cs)
			add_child(col_body)
		"flag":
			_add_deco_sprite(pos, D_FLAG, 2.0, 2)
		"stairs":
			_add_deco_sprite(pos, D_STAIRS, 2.0, 2)
		"stain":
			_add_deco_sprite(pos, T_FLOOR_STAIN, 2.0, 1)
		"puddle":
			_add_deco_sprite(pos, T_FLOOR_PUDDLE, 2.0, 1)
		"chest":
			_place_chest(pos, false, randi_range(15, 60), "crystal_shard")
		"boss_chest":
			_place_chest(pos, true, 500, "armor_shadow_chest")

func _add_deco_sprite(pos: Vector2, tex_path: String, sc: float, z: int) -> void:
	var sp := Sprite2D.new()
	sp.texture  = _get_tex(tex_path)
	sp.position = pos + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	sp.scale    = Vector2(sc, sc)
	sp.z_index  = z
	add_child(sp)

func _place_chest(pos: Vector2, is_boss_chest: bool, gold: int, loot: String) -> void:
	var sp := Sprite2D.new()
	sp.texture  = _get_tex(D_CHEST_GC if is_boss_chest else D_CHEST_C)
	sp.position = pos + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	sp.scale    = Vector2(2.0, 2.0)
	sp.z_index  = 3
	add_child(sp)
	_chest_sprites[pos] = {
		"sprite":  sp,
		"opened":  false,
		"gold":    gold,
		"loot":    loot,
		"is_boss": is_boss_chest,
	}

# ═════════════════════════════════════════════════════════════
# COFRES — interacción
# ═════════════════════════════════════════════════════════════
func _setup_chest_interaction() -> void:
	for pos in _chest_sprites.keys():
		var area := Area2D.new()
		area.position = pos + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
		area.name = "Chest_" + str(pos)
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = TILE_SIZE * 0.9
		cs.shape = circ
		area.add_child(cs)
		area.body_entered.connect(_on_chest_touched.bind(pos))
		add_child(area)

func _on_chest_touched(body: Node2D, chest_pos: Vector2) -> void:
	if not body.is_in_group("player"):
		return
	if not (chest_pos in _chest_sprites):
		return
	var chest: Dictionary = _chest_sprites[chest_pos]
	if chest["opened"]:
		return
	chest["opened"] = true
	var sp: Sprite2D = chest["sprite"]
	sp.texture = _get_tex(D_CHEST_GO if chest["is_boss"] else D_CHEST_O)
	if body.has_method("add_bronze"):
		body.add_bronze(chest["gold"])
	elif "bronze_coins" in body:
		body.bronze_coins += chest["gold"]
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("show_notification"):
		var msg := "✦ Cofre del Boss: +" + str(chest["gold"]) + " bronce!" if chest["is_boss"] else "Cofre abierto: +" + str(chest["gold"]) + " bronce"
		ui.show_notification(msg)
	if chest["is_boss"]:
		_show_victory_sequence()

# ═════════════════════════════════════════════════════════════
# TRIGGERS
# ═════════════════════════════════════════════════════════════
func _setup_exit_trigger() -> void:
	# Sala inicio: x[0,384] y[0,256]
	# Trigger en la fila SUPERIOR de la sala (cerca de las escaleras, y=48)
	# El jugador spawnea en la parte INFERIOR (y~192), así no queda atrapado
	var area := Area2D.new()
	area.position = Vector2(192, 48)
	area.name = "ExitTrigger"
	add_child(area)

	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size  = Vector2(200, 48)
	shape.shape = rect
	area.add_child(shape)

	var indicator := ColorRect.new()
	indicator.position = Vector2(-100, -24)
	indicator.size     = Vector2(200, 48)
	indicator.color    = Color(0.2, 0.8, 0.3, 0.25)
	indicator.z_index  = 1
	area.add_child(indicator)

	var lbl := Label.new()
	lbl.text = "[ Salir al Pueblo ]"
	lbl.position = Vector2(-70, -10)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
	lbl.z_index = 2
	area.add_child(lbl)

	area.body_entered.connect(_on_exit_trigger_entered)

func _setup_boss_trigger() -> void:
	# Si ya existe "BossTrigger" colocado desde el editor, respetar y no regenerar.
	if has_node("BossTrigger"):
		return
	# Inicio de la sala del boss  y=2240 + un poco
	var area := Area2D.new()
	area.position = Vector2(96, 2260)
	area.name = "BossTrigger"
	add_child(area)

	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size  = Vector2(400, 80)
	shape.shape = rect
	area.add_child(shape)

	var lbl := Label.new()
	lbl.text = "☠  TRONO DEL DEMONIO  ☠"
	lbl.position = Vector2(-130, -60)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.3, 0.8))
	lbl.z_index = 2
	area.add_child(lbl)

	area.body_entered.connect(_on_boss_trigger_entered)

# ═════════════════════════════════════════════════════════════
# ENEMIGOS
# ═════════════════════════════════════════════════════════════
func _spawn_dungeon_enemies() -> void:
	# Si ya existe "DungeonEnemies" colocado desde el editor, respetar y no regenerar.
	if has_node("DungeonEnemies"):
		return
	for spawn_data in ENEMY_SPAWNS:
		var pos: Vector2  = spawn_data[0]
		var type: String  = spawn_data[1]
		var level: int    = spawn_data[2]
		var e = EnemyManager.spawn_enemy(type, pos, level, self)
		if is_instance_valid(e):
			e.tree_exited.connect(_on_enemy_killed)
			enemies_remaining += 1
	_notify_hud_enemy_count(enemies_remaining)
	print("[DungeonScene] Enemigos spawneados: ", enemies_remaining)

func _spawn_boss() -> void:
	if boss_spawned:
		return
	boss_spawned = true
	_boss_entrance_effect()
	await get_tree().create_timer(1.5).timeout
	var boss = EnemyManager.spawn_enemy("demon_lord", BOSS_POSITION, 1, self)
	if is_instance_valid(boss):
		boss.tree_exited.connect(_on_boss_killed)
		enemies_remaining += 1
		_notify_hud_enemy_count(enemies_remaining)

func _boss_entrance_effect() -> void:
	var flash := ColorRect.new()
	flash.color   = Color(0.5, 0.0, 0.1, 0.8)
	flash.z_index = 200
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 1.2)
	tw.finished.connect(func(): if is_instance_valid(flash): flash.queue_free())
	_show_boss_title()

func _show_boss_title() -> void:
	var lbl := Label.new()
	lbl.text = "🔥 AZATHIEL — DEMONIO ANCESTRAL 🔥"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.1))
	lbl.z_index = 210
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 240, 110)
	get_tree().root.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.finished.connect(func(): if is_instance_valid(lbl): lbl.queue_free())

# ═════════════════════════════════════════════════════════════
# CALLBACKS
# ═════════════════════════════════════════════════════════════
func _on_exit_trigger_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or not _exit_enabled:
		return
	GameManager.is_in_dungeon = false
	_notify_hud_dungeon_mode(false)
	EnemyManager.despawn_all()
	GameManager.change_scene_with_spawn("res://scenes/town.tscn", Vector2(60, -200))

func _on_boss_trigger_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or boss_spawned:
		return
	_spawn_boss()

func _on_enemy_killed() -> void:
	enemies_remaining = max(0, enemies_remaining - 1)
	_notify_hud_enemy_count(enemies_remaining)

func _on_boss_killed() -> void:
	boss_defeated     = true
	enemies_remaining = max(0, enemies_remaining - 1)
	_notify_hud_enemy_count(enemies_remaining)
	_show_victory_sequence()

func _show_victory_sequence() -> void:
	await get_tree().create_timer(0.5).timeout
	var flash := ColorRect.new()
	flash.color   = Color(1, 0.85, 0.2, 0.6)
	flash.z_index = 200
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 1.5)
	tw.finished.connect(func(): if is_instance_valid(flash): flash.queue_free())

	var lbl := Label.new()
	lbl.text = "✦ MAZMORRA COMPLETADA — AZATHIEL DERROTADO ✦"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color.GOLD)
	lbl.z_index = 210
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 260, 100)
	get_tree().root.add_child(lbl)
	var tw2 := lbl.create_tween()
	tw2.tween_interval(4.0)
	tw2.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw2.finished.connect(func(): if is_instance_valid(lbl): lbl.queue_free())

# ═════════════════════════════════════════════════════════════
# SPAWN DEL JUGADOR Y CÁMARA
# ═════════════════════════════════════════════════════════════
func _setup_player_spawn() -> void:
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		# Sala inicio: x[0,384] y[0,256] — spawn cerca del centro inferior
		var start_room: Array = ROOMS[0]
		var spawn_x: int = (int(start_room[0]) + int(start_room[2]) / 2) * TILE_SIZE
		# Spawn en el borde inferior de la sala, lejos del trigger de salida (que está arriba)
		var spawn_y: int = (int(start_room[1]) + int(start_room[3]) - 1) * TILE_SIZE - TILE_SIZE / 2
		player.global_position = Vector2(float(spawn_x), float(spawn_y))

		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left   = -900
			cam.limit_right  = 1300
			cam.limit_top    = -200
			cam.limit_bottom = 3000
			cam.reset_smoothing()

		# PASO 10 — luz cálida del jugador en dungeon
		if not player.has_node("DungeonPlayerLight"):
			var plight := PointLight2D.new()
			plight.name    = "DungeonPlayerLight"
			plight.energy  = 0.6
			plight.texture_scale = 0.55
			plight.color   = Color(1.0, 0.92, 0.75)
			plight.z_index = 10
			var grad := GradientTexture2D.new()
			var g    := Gradient.new()
			g.add_point(0.0, Color(1, 1, 1, 1))
			g.add_point(1.0, Color(1, 1, 1, 0))
			grad.gradient = g
			grad.width    = 256
			grad.height   = 256
			grad.fill     = GradientTexture2D.FILL_RADIAL
			plight.texture = grad
			player.add_child(plight)
	print("[DungeonScene] Player spawneado en sala inicio")

func _notify_hud_dungeon_mode(active: bool) -> void:
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("set_dungeon_mode"):
		ui.set_dungeon_mode(active)

func _notify_hud_enemy_count(count: int) -> void:
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("update_enemy_count"):
		ui.update_enemy_count(count)

# ═════════════════════════════════════════════════════════════
# PROCESO — antorchas
# ═════════════════════════════════════════════════════════════
var _torch_timer: float = 0.0
var _torch_frame: int   = 0
const TORCH_FPS: float  = 6.0

func _process(delta: float) -> void:
	_torch_timer += delta
	if _torch_timer >= 1.0 / TORCH_FPS:
		_torch_timer -= 1.0 / TORCH_FPS
		_torch_frame = (_torch_frame + 1) % 4
		var tex = _torch_textures[_torch_frame] if _torch_textures.size() > _torch_frame else null
		if tex:
			for sp in _torch_nodes:
				if is_instance_valid(sp):
					sp.texture = tex

	var t := Time.get_ticks_msec() * 0.001
	for i in range(_torch_lights.size()):
		var light: PointLight2D = _torch_lights[i]
		if is_instance_valid(light):
			light.energy = 0.82 + 0.18 * sin(t * 3.0 + i * 1.57)
			# PASO 9 — variación de color orgánica entre naranja vivo y amarillo cálido
			var flicker_c: float = (sin(t * 2.7 + i * 2.1) + 1.0) * 0.5  # 0..1
			light.color = Color(1.0, lerp(0.55, 0.70, flicker_c), lerp(0.15, 0.25, flicker_c))

func _exit_tree() -> void:
	GameManager.is_in_dungeon = false
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").stop_boss_music()
		get_node("/root/AudioManager").fade_out(0.8)
