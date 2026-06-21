# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node2D

# ============================================================
# WORLD WEST — Bosque Oscuro y Ruinas del Bosque Prohibido
# VERSION EXPANDIDA — 200+ jugadores simultáneos
#
# Tema visual : Bosque denso, árboles retorcidos, hongos bioluminiscentes,
#               ruinas antiguas cubiertas de hiedra, niebla perpetua
# Enemigos    : Todos los niveles distribuidos por ANILLOS geográficos
#
#  ANILLO 0 — Linde del Bosque (junto al portal este)
#             x: 600..1600,  y: libre   Lv 1-5   → zona de entrada, árboles jóvenes
#
#  ANILLO 1 — Interior del Bosque (x: 0..600)
#             Lv 6-15  → zona de progresión, árboles densos, niebla baja
#
#  ANILLO 2 — Corazón Oscuro (x: -1600..0)
#             Lv 16-30 → zona de riesgo, árboles retorcidos, ruinas antiguas
#
#  ANILLO 3 — Abismo del Bosque (extremo oeste, x: -3000..-1600)
#             Lv 31-50 → zona mortal, hongos gigantes, boss de bosque, cofres épicos
#
# Filosofía: el jugador ELIGE hasta dónde se interna en el bosque.
#            Cuanto más al oeste, más oscuro y peligroso.
#
# MMORPG Pixel — Godot 4.x
# ============================================================

const SCENE_WIDTH:  int = 18000
const SCENE_HEIGHT: int = 12000

# ── Límites de anillos (X desde el portal este hacia el oeste) ──
const RING0_X_MIN: int =  4800   # linde — lado este (entrada)
const RING1_X_MIN: int =     0
const RING2_X_MIN: int = -4800
const RING3_X_MIN: int = -9000   # extremo oeste = más peligroso

# ── Paleta ──────────────────────────────────────────────────
const C_FOREST_DARK    := Color(0.07, 0.13, 0.07)
const C_FOREST_MID     := Color(0.10, 0.20, 0.10)
const C_BARK_DARK      := Color(0.18, 0.12, 0.06)
const C_BARK_MID       := Color(0.28, 0.20, 0.10)
const C_LEAVES_GREEN   := Color(0.12, 0.35, 0.10)
const C_LEAVES_DARK    := Color(0.06, 0.22, 0.06)
const C_LEAVES_TWISTED := Color(0.08, 0.18, 0.05)
const C_MOSS           := Color(0.20, 0.40, 0.12)
const C_MUSHROOM_GLOW  := Color(0.40, 0.85, 0.60)
const C_MUSHROOM_PUR   := Color(0.55, 0.18, 0.80)
const C_MUSHROOM_RED   := Color(0.80, 0.15, 0.10)
const C_FOG            := Color(0.55, 0.65, 0.55, 0.18)
const C_RUIN_STONE     := Color(0.30, 0.32, 0.28)
const C_IVY            := Color(0.18, 0.42, 0.12)
const C_BOSS_ZONE      := Color(0.04, 0.08, 0.04)

# ── Colores de anillo ────────────────────────────────────────
const C_RING0 := Color(0.30, 0.80, 0.30, 0.04)   # verde tenue — zona segura
const C_RING1 := Color(0.85, 0.80, 0.10, 0.05)   # amarillo tenue
const C_RING2 := Color(0.85, 0.40, 0.10, 0.07)   # naranja — peligroso
const C_RING3 := Color(0.60, 0.10, 0.10, 0.10)   # rojo — muy peligroso

# ── Boss mundial ─────────────────────────────────────────────
var _boss_spawned:  bool = false

# ── Mejora 6: Detección de cruce de zona ─────────────────────
var _current_ring: int = -1
var _boss_defeated: bool = false
var _boss_node:     Node = null

# ── Campamentos activos ──────────────────────────────────────
var _camps: Array = []

# ── Partículas ambientales ────────────────────────────────────
var _fog_particles: GPUParticles2D = null


# ════════════════════════════════════════════════════════════
func _ready() -> void:
	print("[WorldWest] Mapa expandido cargado — 200+ players")
	var _srv: bool = has_node("/root/NetworkManager") and get_node("/root/NetworkManager").is_server
	if not _srv:
		GameManager.ensure_player_and_ui(self)
	_draw_background()
	_draw_ring_overlays()
	_draw_terrain_features()
	call_deferred("_setup_camera_limits")
	if not _srv:
		_spawn_player()
	_setup_borders()
	call_deferred("_spawn_all_camps")
	call_deferred("_spawn_scattered_enemies")
	call_deferred("_spawn_resource_nodes")
	if not _srv:
		_draw_boss_altar(Vector2(-SCENE_WIDTH / 2, 0))
		_add_zone_label("☠ SALIDA — BOSS: Ancient Forest Guardian Lv 50", Vector2(-SCENE_WIDTH / 2 + 20, -90), Color(1, 0.1, 0.8))
		_create_fog_particles()
	GameManager.set_zone("world_west")
	if not _srv and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_zone_music("world_west")
	if not _srv and has_node("/root/WeatherSystem"):
		get_node("/root/WeatherSystem").set_weather("none")


# ════════════════════════════════════════════════════════════
# MEJORA 6 — DETECCIÓN DE CRUCE DE ANILLO (zona peligrosa)
# West: peligro crece hacia X negativo (RING3_X_MIN más al oeste)
# ════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var px: float = players[0].global_position.x

	var ring: int
	if px >= RING0_X_MIN:
		ring = 0
	elif px >= RING1_X_MIN:
		ring = 1
	elif px >= RING2_X_MIN:
		ring = 2
	else:
		ring = 3

	if ring == _current_ring:
		return
	var prev := _current_ring
	_current_ring = ring

	if prev == -1:
		return

	var ui := GameManager.get_game_ui() if GameManager.has_method("get_game_ui") else null
	if ui == null:
		ui = get_tree().get_first_node_in_group("game_ui")
	if ui == null or not ui.has_method("show_zone_warning"):
		return

	match ring:
		0: ui.show_zone_warning("⬡ Zona Segura — Oeste  Lv 1–5",   Color(0.3, 1.0, 0.3))
		1: ui.show_zone_warning("⬡ Zona Media — Oeste  Lv 6–15",   Color(0.9, 0.85, 0.1))
		2: ui.show_zone_warning("⚠ Zona Peligrosa — Oeste  Lv 16–30", Color(1.0, 0.55, 0.1))
		3: ui.show_zone_warning("☠ Zona Mortal — Oeste  Lv 31–50",  Color(1.0, 0.15, 0.15))


# ════════════════════════════════════════════════════════════
# FONDO Y OVERLAYS DE ANILLOS
# ════════════════════════════════════════════════════════════

func _draw_background() -> void:
	# Si ya existe "Background" colocado desde el editor, respetar y no regenerar.
	if has_node("Background"):
		return
	var bg = ColorRect.new()
	bg.color    = C_FOREST_MID
	bg.size     = Vector2(SCENE_WIDTH, SCENE_HEIGHT)
	bg.position = Vector2(-SCENE_WIDTH / 2, -SCENE_HEIGHT / 2)
	bg.z_index  = -20
	add_child(bg)

	# Oscuridad progresiva hacia el oeste
	var dark_west = ColorRect.new()
	dark_west.color    = Color(0.02, 0.04, 0.02, 0.65)
	dark_west.size     = Vector2(SCENE_WIDTH * 0.45, SCENE_HEIGHT)
	dark_west.position = Vector2(-SCENE_WIDTH / 2, -SCENE_HEIGHT / 2)
	dark_west.z_index  = -19
	add_child(dark_west)

	# Franja de luz en la entrada este
	var entry_light = ColorRect.new()
	entry_light.color    = Color(0.35, 0.55, 0.25, 0.20)
	entry_light.size     = Vector2(SCENE_WIDTH * 0.20, SCENE_HEIGHT)
	entry_light.position = Vector2(SCENE_WIDTH * 0.30, -SCENE_HEIGHT / 2)
	entry_light.z_index  = -18
	add_child(entry_light)

func _draw_ring_overlays() -> void:
	# Si ya existe "RingOverlays" colocado desde el editor, respetar y no regenerar.
	if has_node("RingOverlays"):
		return
	# Eje X: este=seguro, oeste=peligroso
	var rings = [
		[C_RING0, Vector2(SCENE_WIDTH/2 - RING0_X_MIN + SCENE_WIDTH/2, SCENE_HEIGHT),
		 Vector2(RING0_X_MIN, -SCENE_HEIGHT/2)],
		[C_RING1, Vector2(RING0_X_MIN - RING1_X_MIN, SCENE_HEIGHT),
		 Vector2(RING1_X_MIN, -SCENE_HEIGHT/2)],
		[C_RING2, Vector2(RING1_X_MIN - RING2_X_MIN, SCENE_HEIGHT),
		 Vector2(RING2_X_MIN, -SCENE_HEIGHT/2)],
		[C_RING3, Vector2(RING2_X_MIN - RING3_X_MIN, SCENE_HEIGHT),
		 Vector2(RING3_X_MIN, -SCENE_HEIGHT/2)],
	]
	for r in rings:
		var ov = ColorRect.new()
		ov.color    = r[0]
		ov.size     = r[1]
		ov.position = r[2]
		ov.z_index  = -17
		add_child(ov)

	# Etiquetas de zona
	_add_zone_label("⬡ LINDE DEL BOSQUE  Lv 1-5",   Vector2(RING0_X_MIN + 10,  -200), Color(0.3, 1.0, 0.3))
	_add_zone_label("⬡ INTERIOR BOSQUE   Lv 6-15",  Vector2(RING1_X_MIN + 10,  -200), Color(1.0, 0.9, 0.1))
	_add_zone_label("⬡ CORAZÓN OSCURO    Lv 16-30", Vector2(RING2_X_MIN + 10,  -200), Color(1.0, 0.55, 0.1))
	_add_zone_label("☠ ABISMO DEL BOSQUE Lv 31-50", Vector2(RING3_X_MIN + 10,  -200), Color(1.0, 0.2, 0.2))

func _add_zone_label(text: String, pos: Vector2, color: Color) -> void:
	var lbl = Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.z_index  = 20
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	var tw = create_tween().set_loops()
	tw.tween_property(lbl, "modulate:a", 0.4, 2.5)
	tw.tween_property(lbl, "modulate:a", 1.0, 2.5)
	add_child(lbl)


# ════════════════════════════════════════════════════════════
# TERRENO
# ════════════════════════════════════════════════════════════

func _draw_terrain_features() -> void:
	# Si ya existe "Terrain" colocado desde el editor, respetar y no regenerar.
	if has_node("Terrain"):
		return
	# Capa de suelo con musgo
	_draw_forest_floor()

	# Árboles — densidad aumenta hacia el oeste
	for i in 120:
		var tx = randf_range(-SCENE_WIDTH/2 + 30, SCENE_WIDTH/2 - 30)
		var ty = randf_range(-SCENE_HEIGHT/2 + 30, SCENE_HEIGHT/2 - 30)
		# Más árboles retorcidos al oeste
		var twist_factor = clamp((-tx) / float(SCENE_WIDTH/2), 0.0, 1.0)
		_draw_forest_tree(Vector2(tx, ty), twist_factor)

	# Hongos bioluminiscentes — anillos 2-3
	for i in 50:
		var mx = randf_range(-SCENE_WIDTH/2 + 50, RING1_X_MIN - 50)
		var my = randf_range(-SCENE_HEIGHT/2 + 50, SCENE_HEIGHT/2 - 50)
		_draw_mushroom_cluster(Vector2(mx, my))

	# Ruinas cubiertas de hiedra — más densas en anillo 2-3
	for i in 30:
		var rx = randf_range(-SCENE_WIDTH/2 + 80, RING1_X_MIN - 80)
		var ry = randf_range(-SCENE_HEIGHT/2 + 80, SCENE_HEIGHT/2 - 80)
		_draw_ruin_wall(Vector2(rx, ry))

	# Raíces gigantes expuestas en el suelo — anillo 3
	for i in 20:
		var grx = randf_range(-SCENE_WIDTH/2 + 50, RING2_X_MIN - 50)
		var gry = randf_range(-SCENE_HEIGHT/2 + 50, SCENE_HEIGHT/2 - 50)
		_draw_giant_root(Vector2(grx, gry))

	# Charcas de pantano oscuro
	_draw_dark_pool(Vector2(-2400,  400), Vector2(260, 110))
	_draw_dark_pool(Vector2(-1600, -800), Vector2(200,  90))
	_draw_dark_pool(Vector2(-2900,  100), Vector2(300, 130))
	_draw_dark_pool(Vector2( -400, -300), Vector2(180,  80))
	_draw_dark_pool(Vector2(-1000,  900), Vector2(220, 100))

func _draw_forest_floor() -> void:
	# Manchas de musgo en el suelo
	for i in 80:
		var mx = randf_range(-SCENE_WIDTH/2 + 20, SCENE_WIDTH/2 - 20)
		var my = randf_range(-SCENE_HEIGHT/2 + 20, SCENE_HEIGHT/2 - 20)
		var patch = ColorRect.new()
		patch.color    = Color(C_MOSS.r, C_MOSS.g, C_MOSS.b, randf_range(0.25, 0.55))
		patch.size     = Vector2(randf_range(30, 90), randf_range(20, 55))
		patch.position = Vector2(mx, my)
		patch.z_index  = -15
		add_child(patch)

func _draw_forest_tree(pos: Vector2, twist: float) -> void:
	var trunk_h  = randi_range(35, 75)
	var trunk_w  = randi_range(9, 18)
	var lean     = randf_range(-twist * 8.0, twist * 8.0)

	var trunk = ColorRect.new()
	trunk.color    = C_BARK_DARK.lerp(Color(0.10, 0.08, 0.04), twist)
	trunk.size     = Vector2(trunk_w, trunk_h)
	trunk.position = pos - Vector2(trunk_w / 2.0, trunk_h)
	trunk.rotation = deg_to_rad(lean)
	trunk.z_index  = 1
	add_child(trunk)

	# Canopy — 2 a 3 capas
	var layers = 2 + int(randf() > 0.5)
	for l in layers:
		var canopy = ColorRect.new()
		var leaf_color = C_LEAVES_GREEN.lerp(C_LEAVES_TWISTED, twist)
		canopy.color    = leaf_color
		canopy.color.a  = randf_range(0.75, 0.95)
		var cw = trunk_w * (2.8 - l * 0.5) + randf_range(-5, 5)
		var ch = int(trunk_h * 0.35) + randi_range(-4, 4)
		canopy.size     = Vector2(cw, ch)
		canopy.position = pos - Vector2(cw / 2.0, trunk_h * 0.85 + l * ch * 0.55)
		canopy.z_index  = 2 + l
		add_child(canopy)

func _draw_mushroom_cluster(pos: Vector2) -> void:
	var colors = [C_MUSHROOM_GLOW, C_MUSHROOM_PUR, C_MUSHROOM_RED]
	for i in randi_range(2, 5):
		var col   = colors[randi() % colors.size()]
		var mh    = randi_range(10, 28)
		var mw    = randi_range(8, 20)
		var stem  = ColorRect.new()
		stem.color    = Color(0.80, 0.78, 0.72)
		stem.size     = Vector2(5, mh)
		stem.position = pos + Vector2(i * 12 - 24, -mh)
		stem.z_index  = 3
		add_child(stem)
		var cap = ColorRect.new()
		cap.color    = col
		cap.size     = Vector2(mw, mh * 0.45)
		cap.position = pos + Vector2(i * 12 - 24 - (mw - 5) / 2.0, -(mh + mh * 0.35))
		cap.z_index  = 4
		add_child(cap)
		# Brillo bioluminiscente
		var glow = ColorRect.new()
		glow.color    = Color(col.r, col.g, col.b, 0.30)
		glow.size     = Vector2(mw + 10, mh * 0.6)
		glow.position = cap.position - Vector2(5, 3)
		glow.z_index  = 3
		add_child(glow)
		var tw = create_tween().set_loops()
		tw.tween_property(glow, "modulate:a", 0.10, 1.4 + randf())
		tw.tween_property(glow, "modulate:a", 1.0,  1.4 + randf())

func _draw_ruin_wall(pos: Vector2) -> void:
	# Muro de piedra parcialmente derrumbado
	var wall_w = randi_range(40, 90)
	var wall_h = randi_range(20, 50)
	var wall = ColorRect.new()
	wall.color    = C_RUIN_STONE
	wall.size     = Vector2(wall_w, wall_h)
	wall.position = pos - Vector2(wall_w / 2.0, wall_h)
	wall.z_index  = 2
	add_child(wall)
	# Hiedra sobre la piedra
	for i in randi_range(2, 5):
		var ivy = ColorRect.new()
		var iw  = randi_range(8, 18)
		var ih  = randi_range(10, 25)
		ivy.color    = C_IVY
		ivy.size     = Vector2(iw, ih)
		ivy.position = pos - Vector2(wall_w / 2.0 - i * (wall_w / 5.0), ih + wall_h - 4)
		ivy.z_index  = 3
		add_child(ivy)

func _draw_giant_root(pos: Vector2) -> void:
	for branch in randi_range(3, 6):
		var root = ColorRect.new()
		var angle_deg = branch * 60.0 + randf_range(-20, 20)
		root.color    = C_BARK_DARK
		root.size     = Vector2(randf_range(50, 110), randi_range(6, 12))
		root.position = pos
		root.rotation = deg_to_rad(angle_deg)
		root.z_index  = -1
		add_child(root)

func _draw_dark_pool(pos: Vector2, size: Vector2) -> void:
	var pool = ColorRect.new()
	pool.color    = Color(0.06, 0.12, 0.06, 0.80)
	pool.size     = size
	pool.position = pos - size / 2.0
	pool.z_index  = -10
	add_child(pool)
	# Reflejos oscuros
	for i in 3:
		var refl = ColorRect.new()
		refl.color    = Color(0.25, 0.50, 0.25, 0.20)
		refl.size     = Vector2(randf_range(15, 50), 3)
		refl.position = pos - size/2.0 + Vector2(randf_range(5, size.x - 25), randf_range(5, size.y - 5))
		refl.z_index  = -9
		add_child(refl)
	# Niebla sobre la charca
	var fog = ColorRect.new()
	fog.color    = Color(0.40, 0.55, 0.40, 0.12)
	fog.size     = Vector2(size.x + 30, size.y + 20)
	fog.position = pos - (size + Vector2(30, 20)) / 2.0
	fog.z_index  = -8
	add_child(fog)


# ════════════════════════════════════════════════════════════
# CÁMARA / JUGADOR / BORDES
# ════════════════════════════════════════════════════════════

func _setup_camera_limits() -> void:
	var cam = get_viewport().get_camera_2d()
	if cam:
		cam.limit_left   = -SCENE_WIDTH  / 2
		cam.limit_right  =  SCENE_WIDTH  / 2
		cam.limit_top    = -SCENE_HEIGHT / 2
		cam.limit_bottom =  SCENE_HEIGHT / 2
	else:
		call_deferred("_setup_camera_limits")

func _spawn_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		if GameManager.player_spawn_override:
			players[0].global_position = GameManager.consume_spawn_override()
		else:
			players[0].global_position = Vector2(SCENE_WIDTH / 2 - 100, 0)

func _setup_borders() -> void:
	var HW: int = SCENE_WIDTH  / 2
	var HH: int = SCENE_HEIGHT / 2
	var PATH: int = 160
	var T:    int = 28

	# 2 lados cerrados
	_add_wall(Vector2(0,   -HH), Vector2(SCENE_WIDTH, T))  # Norte
	_add_wall(Vector2(0,    HH), Vector2(SCENE_WIDTH, T))  # Sur

	# Oeste — dos muros con hueco central (salida a la sala del boss)
	var bw: int = HH - PATH
	_add_wall(Vector2(-HW, -(PATH + bw/2)), Vector2(T, bw))
	_add_wall(Vector2(-HW,   PATH + bw/2),  Vector2(T, bw))

	# Este — dos muros con hueco central (portal al pueblo)
	var sh: int = HH - PATH
	_add_wall(Vector2(HW, -(PATH + sh/2)), Vector2(T, sh))
	_add_wall(Vector2(HW,   PATH + sh/2),  Vector2(T, sh))

	# Trigger de salida al este
	var exit := Area2D.new()
	exit.name = "ExitTrigger"
	exit.position = Vector2(HW, 0)
	var sc := CollisionShape2D.new()
	var sr := RectangleShape2D.new()
	sr.size = Vector2(T * 4, PATH * 2)
	sc.shape = sr
	exit.add_child(sc)
	add_child(exit)
	exit.body_entered.connect(func(body):
		if body.is_in_group("player"):
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").fade_out(0.8)
			GameManager.save_game()
			InventoryManager.save_inventory()
			PlayerData.flush_pending_save()
			var spawn_pos = Vector2(-900, 0)  # justo al este del borde oeste de town (1920x1080)
			var ls = get_node_or_null("/root/LoadingScreen")
			if ls and ls.has_method("go_to_with_spawn"):
				ls.go_to_with_spawn("res://scenes/town.tscn", spawn_pos)
			else:
				GameManager.player_spawn_position = spawn_pos
				GameManager.player_spawn_override  = true
				var _nm_ref = get_node_or_null("/root/NetworkManager"); if _nm_ref: _nm_ref._clear_remote_nodes()
			get_tree().call_deferred("change_scene_to_file", "res://scenes/town.tscn")
	)

	# Salida oeste — lleva a la sala exclusiva del Boss (boss_west.tscn)
	var boss_exit := Area2D.new()
	boss_exit.name = "BossExitTrigger"
	boss_exit.position = Vector2(-HW, 0)
	var bsc := CollisionShape2D.new()
	var bsr := RectangleShape2D.new()
	bsr.size = Vector2(T * 4, PATH * 2)
	bsc.shape = bsr
	boss_exit.add_child(bsc)
	add_child(boss_exit)
	boss_exit.body_entered.connect(func(body):
		if body.is_in_group("player") and not _boss_spawned:
			_boss_spawned = true
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").fade_out(0.6)
			var _nm_ref = get_node_or_null("/root/NetworkManager"); if _nm_ref: _nm_ref._clear_remote_nodes()
			get_tree().call_deferred("change_scene_to_file", "res://scenes/boss_west.tscn")
	)

func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)
	add_child(body)


# ════════════════════════════════════════════════════════════
# CAMPAMENTOS — Sistema al estilo Albion Online
#
# Cada campamento tiene:
#   • Decoración visual (hoguera, tiendas, estandarte)
#   • Grupo de mobs guardianes (4-9 según tier)
#   • 1 cofre con loot acorde al nivel del anillo
#   • Label flotante con nombre y rango de nivel
# ════════════════════════════════════════════════════════════

func _spawn_all_camps() -> void:
	# Si ya existe "Camps" colocado desde el editor, respetar y no regenerar.
	if has_node("Camps"):
		return
	# ── ANILLO 0 — Linde del Bosque — Lv 1-5 ─────────────
	_spawn_camp("Cabaña del Guardabosques", Vector2(7200, 600), "wolf",     1, 3, "ring0")
	_spawn_camp("Refugio del Leñador",      Vector2(7200, -600), "wolf",     2, 4, "ring0")
	_spawn_camp("Claro de los Exploradores",Vector2(6300, 0), "wolf",     3, 5, "ring0")

	# ── ANILLO 1 — Interior del Bosque — Lv 6-15 ──────────
	_spawn_camp("Nido de Arañas Menor",     Vector2(2400, 1800), "spider",   6,  9,  "ring1")
	_spawn_camp("Guarida del Bandido",      Vector2(2100, -2100), "spider",   8,  11, "ring1")
	_spawn_camp("Aldea Dríada Corrompida",  Vector2(600, 900), "spider",  10,  13, "ring1")
	_spawn_camp("Campamento del Druida",    Vector2(1200, -1200), "spider",  11,  14, "ring1")
	_spawn_camp("Puente de las Raíces",     Vector2(150, 0), "spider",  12,  15, "ring1")

	# ── ANILLO 2 — Corazón Oscuro — Lv 16-30 ──────────────
	_spawn_camp("Santuario Profanado",      Vector2(-1800, 2400), "darkelf", 16, 20, "ring2")
	_spawn_camp("Círculo de Piedras",       Vector2(-2400, -2700), "darkelf", 18, 22, "ring2")
	_spawn_camp("Guarida del Hombre Lobo",  Vector2(-3600, 1200), "darkelf", 20, 25, "ring2")
	_spawn_camp("Ruinas del Templo Elf",    Vector2(-4200, -1500), "darkelf", 22, 27, "ring2")
	_spawn_camp("Gran Altar Corrompido",    Vector2(-3300, 0), "darkelf", 25, 30, "ring2")

	# ── ANILLO 3 — Abismo del Bosque — Lv 31-50 ───────────
	_spawn_camp("Trono del Archidruida",    Vector2(-6600, 3000), "darkelf", 31, 38, "ring3")
	_spawn_camp("Ciudadela de Hongos",      Vector2(-7500, -3600), "darkelf", 35, 42, "ring3")
	_spawn_camp("Nido de la Araña Reina",   Vector2(-5400, 2400), "darkelf", 38, 45, "ring3")
	_spawn_camp("Altar de las Sombras",     Vector2(-8400, -1800), "darkelf", 40, 48, "ring3")
	_spawn_camp("El Claro Prohibido",       Vector2(-7800, 600), "darkelf", 45, 50, "ring3")

func _spawn_camp(camp_name: String, center: Vector2, mob_type: String,
				 lv_min: int, lv_max: int, ring: String) -> void:
	var camp = {"center": center, "enemies": [], "chest_looted": false}
	_draw_camp_ground(center, ring)
	_draw_campfire(center + Vector2(0, 60))
	_draw_camp_tent(center + Vector2(-165, 30))
	_draw_camp_tent(center + Vector2(165, 30))
	_draw_camp_banner(center + Vector2(0, -135), ring)
	_draw_camp_stockade(center)

	var lbl = Label.new()
	lbl.text = "%s\n[Lv %d\u2013%d]" % [camp_name, lv_min, lv_max]
	lbl.position = center + Vector2(-80, -80); lbl.z_index = 30
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", _ring_color(ring))
	add_child(lbl); camp["label"] = lbl

	# Cofre bloqueado al inicio — se desbloquea al limpiar el campamento
	var chest_node = _draw_chest(center + Vector2(0, 35), ring, lv_min, lv_max)
	camp["chest_node"] = chest_node
	_set_chest_locked(chest_node, true)

	var mob_count = clamp(4 + (lv_min / 10), 4, 9)
	var offsets = [
		Vector2(-70, 40), Vector2( 70, 40), Vector2(-90, -10), Vector2(90, -10),
		Vector2(-50,-55), Vector2( 50,-55), Vector2(  0, -70),
		Vector2(-25, 60), Vector2( 25,  60)
	]
	var alive_ref = [0]
	if has_node("/root/EnemyManager"):
		var em = get_node("/root/EnemyManager")
		for i in mob_count:
			# FIX BUG CRITICO MULTIJUGADOR: semilla deterministica por slot
			# para que servidor y todos los clientes generen el mismo nivel
			# (antes randi_range() global generaba un nivel distinto en cada
			# peer, rompiendo el matching de enemigos entre cliente/servidor).
			var slot_seed: int = int(center.x) * 73856093 ^ int(center.y) * 19349663 ^ (i * 83492791)
			var slot_rng := RandomNumberGenerator.new()
			slot_rng.seed = slot_seed
			var lv = slot_rng.randi_range(lv_min, lv_max)
			if em.has_method("spawn_enemy"):
				var e = em.spawn_enemy(mob_type, center + offsets[i], lv, self)
				if e:
					camp["enemies"].append(e)
					alive_ref[0] += 1
					var captured_chest    = chest_node
					var captured_ring     = ring
					var captured_center   = center
					var captured_mob_type = mob_type
					var captured_lv_min   = lv_min
					var captured_lv_max   = lv_max
					var captured_name     = name
					e._camp_death_callback = func():
						alive_ref[0] = max(0, alive_ref[0] - 1)  # FIX v19: evitar negativo
						if alive_ref[0] == 0:
							_on_camp_cleared(captured_chest, captured_ring, captured_center,
									captured_mob_type, captured_lv_min, captured_lv_max, captured_name)
	_camps.append(camp)

## Todos los mobs del campamento han muerto → desbloquear cofre y programar respawn
func _on_camp_cleared(chest_area: Area2D, ring: String, center: Vector2,
		mob_type: String, lv_min: int, lv_max: int, camp_name: String) -> void:
	if not is_instance_valid(chest_area): return
	_set_chest_locked(chest_area, false)
	var glow = chest_area.get_meta("glow_node") if chest_area.has_meta("glow_node") else null
	if glow and is_instance_valid(glow):
		var ring_col = _ring_color(ring)
		glow.color = Color(ring_col.r, ring_col.g, ring_col.b, 0.55)
		var tw = glow.create_tween().set_loops(0)
		tw.tween_property(glow, "modulate:a", 0.15, 0.55)
		tw.tween_property(glow, "modulate:a", 1.0,  0.55)
	var notice = Label.new()
	notice.text = "\u2736 \u00a1Campamento Limpio! \u2736"
	notice.add_theme_color_override("font_color", Color.GOLD)
	notice.add_theme_font_size_override("font_size", 13)
	notice.position = chest_area.global_position + Vector2(-75, -55)
	notice.z_index  = 200
	add_child(notice)
	var tw2 = notice.create_tween().set_parallel(true)
	tw2.tween_property(notice, "position:y", notice.position.y - 40, 2.5)
	tw2.tween_property(notice, "modulate:a", 0.0, 2.5)
	tw2.finished.connect(func(): if is_instance_valid(notice): notice.queue_free())

	# Respawn automático: los mobs vuelven al campamento tras 90 segundos
	get_tree().create_timer(90.0).timeout.connect(
		func(): _respawn_camp(chest_area, ring, center, mob_type, lv_min, lv_max, camp_name)
	)

## Reaparece los mobs de un campamento ya limpiado
func _respawn_camp(chest_area: Area2D, ring: String, center: Vector2,
		mob_type: String, lv_min: int, lv_max: int, camp_name: String) -> void:
	if not is_instance_valid(chest_area): return
	_set_chest_locked(chest_area, true)
	var mob_count = clamp(4 + (lv_min / 10), 4, 9)
	var offsets = [
		Vector2(-70, 40), Vector2( 70, 40), Vector2(-90, -10), Vector2(90, -10),
		Vector2(-50,-55), Vector2( 50,-55), Vector2(  0, -70),
		Vector2(-25, 60), Vector2( 25,  60)
	]
	var alive_ref = [0]
	if has_node("/root/EnemyManager"):
		var em = get_node("/root/EnemyManager")
		for i in mob_count:
			# FIX BUG CRITICO MULTIJUGADOR: semilla deterministica por slot
			# para que servidor y todos los clientes generen el mismo nivel
			# (antes randi_range() global generaba un nivel distinto en cada
			# peer, rompiendo el matching de enemigos entre cliente/servidor).
			var slot_seed: int = int(center.x) * 73856093 ^ int(center.y) * 19349663 ^ (i * 83492791)
			var slot_rng := RandomNumberGenerator.new()
			slot_rng.seed = slot_seed
			var lv = slot_rng.randi_range(lv_min, lv_max)
			if em.has_method("spawn_enemy"):
				var e = em.spawn_enemy(mob_type, center + offsets[i], lv, self)
				if e:
					alive_ref[0] += 1
					var c_chest    = chest_area
					var c_ring     = ring
					var c_center   = center
					var c_mob_type = mob_type
					var c_lv_min   = lv_min
					var c_lv_max   = lv_max
					var c_name     = camp_name
					e._camp_death_callback = func():
						alive_ref[0] = max(0, alive_ref[0] - 1)  # FIX v19: evitar negativo
						if alive_ref[0] == 0:
							_on_camp_cleared(c_chest, c_ring, c_center,
									c_mob_type, c_lv_min, c_lv_max, c_name)
	# Aviso visual de respawn
	var notice = Label.new()
	notice.text = "⚠ Campamento reforzado: %s" % camp_name
	notice.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	notice.add_theme_font_size_override("font_size", 12)
	notice.position = center + Vector2(-100, -90)
	notice.z_index  = 200
	add_child(notice)
	var tw = notice.create_tween().set_parallel(true)
	tw.tween_property(notice, "position:y", notice.position.y - 35, 2.5)
	tw.tween_property(notice, "modulate:a", 0.0, 2.5)
	tw.finished.connect(func(): if is_instance_valid(notice): notice.queue_free())

## Controla el aspecto visual del cofre (bloqueado/desbloqueado)
func _set_chest_locked(area: Area2D, locked: bool) -> void:
	if not is_instance_valid(area): return
	area.set_meta("camp_locked", locked)
	var glow = area.get_meta("glow_node") if area.has_meta("glow_node") else null
	if glow and is_instance_valid(glow):
		if locked:
			glow.color = Color(0.2, 0.2, 0.2, 0.25)


func _ring_color(ring: String) -> Color:
	match ring:
		"ring0": return Color(0.3, 1.0, 0.3)
		"ring1": return Color(1.0, 0.9, 0.1)
		"ring2": return Color(1.0, 0.55, 0.1)
		"ring3": return Color(1.0, 0.2, 0.2)
	return Color.WHITE

# ── Dibujos de campamento ─────────────────────────────────────

func _draw_camp_ground(center: Vector2, ring: String) -> void:
	var dirt = ColorRect.new()
	dirt.color    = Color(0.22, 0.18, 0.10, 0.75)
	dirt.size     = Vector2(220, 160)
	dirt.position = center - Vector2(110, 80)
	dirt.z_index  = -3
	add_child(dirt)
	var border = ColorRect.new()
	border.color    = Color(_ring_color(ring).r, _ring_color(ring).g, _ring_color(ring).b, 0.22)
	border.size     = Vector2(228, 168)
	border.position = center - Vector2(114, 84)
	border.z_index  = -4
	add_child(border)

func _draw_campfire(pos: Vector2) -> void:
	var log1 = ColorRect.new()
	log1.color    = Color(0.28, 0.16, 0.06)
	log1.size     = Vector2(22, 7)
	log1.position = pos - Vector2(11, 3)
	log1.rotation = 0.4
	log1.z_index  = 2
	add_child(log1)
	var log2 = log1.duplicate()
	log2.rotation = -0.4
	add_child(log2)
	var ember = ColorRect.new()
	ember.color    = Color(0.95, 0.50, 0.05)
	ember.size     = Vector2(12, 5)
	ember.position = pos - Vector2(6, 0)
	ember.z_index  = 3
	add_child(ember)
	var flame = ColorRect.new()
	flame.color    = Color(0.90, 0.55, 0.08, 0.85)
	flame.size     = Vector2(9, 14)
	flame.position = pos - Vector2(4, 14)
	flame.z_index  = 4
	add_child(flame)
	var tw = create_tween().set_loops()
	tw.tween_property(flame, "scale", Vector2(1.3, 0.85), 0.35)
	tw.tween_property(flame, "scale", Vector2(0.80, 1.20), 0.35)
	_add_smoke_particles(pos + Vector2(0, -20))

func _add_smoke_particles(pos: Vector2) -> void:
	var smoke = GPUParticles2D.new()
	smoke.emitting  = true
	smoke.amount    = 12
	smoke.lifetime  = 2.2
	smoke.z_index   = 8
	smoke.position  = pos
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape       = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(5.0, 1.0, 0.0)
	mat.direction            = Vector3(0.10, -1.0, 0.0)
	mat.spread               = 20.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 20.0
	mat.gravity              = Vector3(0, -6, 0)
	mat.scale_min            = 3.0
	mat.scale_max            = 7.0
	var grad = Gradient.new()
	grad.add_point(0.0, Color(0.3, 0.4, 0.3, 0.0))
	grad.add_point(0.2, Color(0.35, 0.42, 0.32, 0.55))
	grad.add_point(1.0, Color(0.5, 0.55, 0.5, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = grad
	mat.color_ramp = gt
	smoke.process_material = mat
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	smoke.texture = ImageTexture.create_from_image(img)
	add_child(smoke)

func _draw_camp_tent(pos: Vector2) -> void:
	var tent = ColorRect.new()
	tent.color    = Color(0.28, 0.22, 0.14)
	tent.size     = Vector2(40, 28)
	tent.position = pos - Vector2(20, 14)
	tent.z_index  = 5
	add_child(tent)
	var roof = ColorRect.new()
	roof.color    = Color(0.22, 0.18, 0.10)
	roof.size     = Vector2(46, 10)
	roof.position = pos - Vector2(23, 22)
	roof.z_index  = 6
	add_child(roof)
	var pole = ColorRect.new()
	pole.color    = Color(0.45, 0.35, 0.18)
	pole.size     = Vector2(3, 12)
	pole.position = pos - Vector2(1, 28)
	pole.z_index  = 7
	add_child(pole)

func _draw_camp_banner(pos: Vector2, ring: String) -> void:
	var pole = ColorRect.new()
	pole.color    = Color(0.30, 0.22, 0.12)
	pole.size     = Vector2(3, 32)
	pole.position = pos - Vector2(1, 32)
	pole.z_index  = 7
	add_child(pole)
	var flag = ColorRect.new()
	flag.color    = _ring_color(ring)
	flag.size     = Vector2(20, 14)
	flag.position = pos - Vector2(0, 46)
	flag.z_index  = 8
	add_child(flag)
	var tw = create_tween().set_loops()
	tw.tween_property(flag, "scale:x", 0.80, 0.7 + randf() * 0.3)
	tw.tween_property(flag, "scale:x", 1.0,  0.7 + randf() * 0.3)

func _draw_camp_stockade(center: Vector2) -> void:
	var radius = 115.0
	for i in 12:
		var angle = (i / 12.0) * TAU
		var ppos  = center + Vector2(cos(angle), sin(angle)) * radius
		var post  = ColorRect.new()
		post.color    = Color(0.20, 0.14, 0.07)
		post.size     = Vector2(7, 22)
		post.position = ppos - Vector2(3, 11)
		post.z_index  = 3
		add_child(post)
		var tip = ColorRect.new()
		tip.color    = Color(0.28, 0.20, 0.10)
		tip.size     = Vector2(7, 5)
		tip.position = ppos - Vector2(3, 16)
		tip.z_index  = 3
		add_child(tip)

func _draw_chest(pos: Vector2, ring: String, lv_min: int, lv_max: int) -> Area2D:
	var body = ColorRect.new()
	body.color    = Color(0.40, 0.28, 0.10)
	body.size     = Vector2(20, 14)
	body.position = pos - Vector2(10, 7)
	body.z_index  = 6
	add_child(body)
	var lid = ColorRect.new()
	lid.color    = Color(0.50, 0.36, 0.15)
	lid.size     = Vector2(20, 6)
	lid.position = pos - Vector2(10, 13)
	lid.z_index  = 7
	add_child(lid)
	var lock = ColorRect.new()
	lock.color    = Color(0.90, 0.75, 0.18)
	lock.size     = Vector2(4, 4)
	lock.position = pos - Vector2(2, 3)
	lock.z_index  = 8
	add_child(lock)

	var glow = ColorRect.new()
	glow.color    = Color(_ring_color(ring).r, _ring_color(ring).g, _ring_color(ring).b, 0.40)
	glow.size     = Vector2(26, 20)
	glow.position = pos - Vector2(13, 10)
	glow.z_index  = 5
	add_child(glow)
	var tw = create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.15, 1.0)
	tw.tween_property(glow, "modulate:a", 1.0,  1.0)

	var area = Area2D.new()
	area.name     = "ChestArea"
	area.position = pos
	area.z_index  = 10
	var col = CollisionShape2D.new()
	var cir = CircleShape2D.new()
	cir.radius  = 22.0
	col.shape   = cir
	area.add_child(col)
	add_child(area)
	area.set_meta("ring",      ring)
	area.set_meta("lv_min",    lv_min)
	area.set_meta("lv_max",    lv_max)
	area.set_meta("looted",    false)
	area.set_meta("glow_node", glow)
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			_open_chest(area)
	)
	return area

func _open_chest(area: Area2D) -> void:
	if area.get_meta("camp_locked", false):
		_show_chest_locked_msg(area)
		return
	if area.get_meta("looted"):
		return
	area.set_meta("looted", true)
	var glow   = area.get_meta("glow_node") if area.has_meta("glow_node") else null  # FIX v19
	glow.color = Color(0.5, 0.5, 0.5, 0.1)

	var ring   = area.get_meta("ring")
	var lv_min = area.get_meta("lv_min")
	var lv_max = area.get_meta("lv_max")
	print("[WorldWest] ¡Cofre abierto! Ring=%s Lv%d-%d" % [ring, lv_min, lv_max])

	if not has_node("/root/InventoryManager"):
		return
	var inv = get_node("/root/InventoryManager")
	if not inv.has_method("add_item"):
		return

	# Loot escalado por anillo — temático del Bosque Oscuro
	match ring:
		"ring0":
			inv.add_item("material_herb",    randi_range(3, 6))
			inv.add_item("wood_log",         randi_range(2, 4))
		"ring1":
			inv.add_item("material_herb",    randi_range(4, 8))
			inv.add_item("wood_log",         randi_range(3, 6))
			inv.add_item("material_bone",    randi_range(2, 5))
		"ring2":
			inv.add_item("material_herb",    randi_range(5, 10))
			inv.add_item("material_bone",    randi_range(4, 8))
			inv.add_item("crystal_shard",    randi_range(2, 5))
			if randf() < 0.30:
				inv.add_item("weapon_shadow_blade", 1)
		"ring3":
			inv.add_item("material_herb",    randi_range(8, 14))
			inv.add_item("material_bone",    randi_range(6, 12))
			inv.add_item("crystal_shard",    randi_range(5, 10))
			inv.add_item("ore_iron_t1",         randi_range(4, 9))
			if randf() < 0.50:
				inv.add_item("weapon_shadow_blade", 1)
			if randf() < 0.20:
				inv.add_item("armor_shadow_chest", 1)

	# Respawn del cofre tras cooldown
	var cooldown = 120.0 + (lv_min * 3.0)
	var timer = get_tree().create_timer(cooldown)
	timer.timeout.connect(func():
		area.set_meta("looted", false)
		if glow and is_instance_valid(glow):  # FIX v19
			glow.color = Color(_ring_color(ring).r, _ring_color(ring).g, _ring_color(ring).b, 0.40)
	)


# ════════════════════════════════════════════════════════════
# ENEMIGOS DISPERSOS (fuera de campamentos)
# ════════════════════════════════════════════════════════════

func _show_chest_locked_msg(area: Area2D) -> void:
	var notice = Label.new()
	notice.text = "[BLOQUEADO] Derrota todos los enemigos del campamento primero"
	notice.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	notice.add_theme_font_size_override("font_size", 12)
	notice.position = area.global_position + Vector2(-120, -50)
	notice.z_index  = 200
	add_child(notice)
	var tw = notice.create_tween().set_parallel(true)
	tw.tween_property(notice, "position:y", notice.position.y - 30, 2.0)
	tw.tween_property(notice, "modulate:a", 0.0, 2.0)
	tw.finished.connect(func(): if is_instance_valid(notice): notice.queue_free())

func _spawn_scattered_enemies() -> void:
	# Si ya existe "ScatteredEnemies" en la escena (colocado desde el editor), no regenerar.
	if has_node("ScatteredEnemies"):
		return
	if not has_node("/root/EnemyManager"):
		return
	var em = get_node("/root/EnemyManager")
	if not em.has_method("spawn_enemy"):
		return

	var scattered = [
		# Ring 0 — 6 patrulleros linde
		["wolf",     2,  Vector2(2700,  400)],
		["wolf",     3,  Vector2(2700, -500)],
		["wolf",     4,  Vector2(2200,  700)],
		["wolf",     5,  Vector2(2200, -700)],
		["wolf",     3,  Vector2(1900,  300)],
		["wolf",     4,  Vector2(1900, -300)],
		# Ring 1 — 10 patrulleros interior
		["spider",   7,  Vector2(1100,  900)],
		["spider",   9,  Vector2(1100, -900)],
		["spider",  11,  Vector2( 600,  700)],
		["spider",  13,  Vector2( 600, -700)],
		["spider",   8,  Vector2( 300,  400)],
		["spider",  10,  Vector2( 300, -400)],
		["spider",  12,  Vector2( 800, 1200)],
		["spider",  14,  Vector2( 800,-1200)],
		["spider",   9,  Vector2( 100,  100)],
		["spider",  11,  Vector2( 100, -100)],
		# Ring 2 — 10 patrulleros corazón
		["darkelf", 17,  Vector2( -300,  900)],
		["darkelf", 20,  Vector2( -300, -900)],
		["darkelf", 23,  Vector2( -900, 1200)],
		["darkelf", 26,  Vector2( -900,-1200)],
		["darkelf", 18,  Vector2( -700,  500)],
		["darkelf", 22,  Vector2( -700, -500)],
		["darkelf", 28,  Vector2(-1300,  700)],
		["darkelf", 25,  Vector2(-1300, -700)],
		["darkelf", 30,  Vector2(-1500,  200)],
		["darkelf", 27,  Vector2(-1500, -200)],
		# Ring 3 — 10 patrulleros de élite
		["darkelf", 33,  Vector2(-1900,  1000)],
		["darkelf", 38,  Vector2(-1900, -1000)],
		["darkelf", 42,  Vector2(-2300,  600)],
		["darkelf", 45,  Vector2(-2300, -600)],
		["darkelf", 36,  Vector2(-2700,  900)],
		["darkelf", 40,  Vector2(-2700, -900)],
		["darkelf", 48,  Vector2(-2100,  1400)],
		["darkelf", 50,  Vector2(-2100, -1400)],
		["darkelf", 44,  Vector2(-2500,  200)],
		["darkelf", 46,  Vector2(-2500, -200)],
	]
	for d in scattered:
		em.spawn_enemy(d[0], d[2], d[1], self)


# ════════════════════════════════════════════════════════════
# RECURSOS
# ════════════════════════════════════════════════════════════

func _spawn_resource_nodes() -> void:
	# Si ya existe "ResourceNodes" colocado desde el editor, respetar y no regenerar.
	if has_node("ResourceNodes"):
		return
	var rn_script_path = "res://scripts/resource_node.gd"
	if not ResourceLoader.exists(rn_script_path):
		return
	var rn_script = load(rn_script_path)

	var nodes_data = [
		# Ring 0 — hierbas y madera básica
		["herb",     "material_herb",  Vector2(2600,  300), 1, 3, 40.0],
		["herb",     "material_herb",  Vector2(2600, -300), 1, 3, 40.0],
		["tree",     "wood_log",       Vector2(2300,  600), 2, 4, 45.0],
		["tree",     "wood_log",       Vector2(2300, -600), 2, 4, 45.0],
		["herb",     "material_herb",  Vector2(1800,  500), 1, 3, 40.0],
		["tree",     "wood_log",       Vector2(1800, -500), 2, 4, 45.0],
		# Ring 1 — hierbas raras, madera oscura
		["herb",     "material_herb",  Vector2( 900,  800), 2, 5, 50.0],
		["herb",     "material_herb",  Vector2( 900, -800), 2, 5, 50.0],
		["tree",     "wood_log",       Vector2( 500,  600), 2, 4, 48.0],
		["tree",     "wood_log",       Vector2( 500, -600), 2, 4, 48.0],
		["crystal",  "crystal_shard",  Vector2( 200,  300), 1, 3, 90.0],
		["crystal",  "crystal_shard",  Vector2( 200, -300), 1, 3, 90.0],
		["iron_ore", "material_bone",  Vector2( 700, 1100), 2, 5, 55.0],
		# Ring 2 — recursos de calidad media
		["crystal",  "crystal_shard",  Vector2( -500,  700), 2, 5, 95.0],
		["crystal",  "crystal_shard",  Vector2( -500, -700), 2, 5, 95.0],
		["iron_ore", "ore",       Vector2(-1000, 1000), 3, 6, 65.0],
		["iron_ore", "ore",       Vector2(-1000,-1000), 3, 6, 65.0],
		["herb",     "material_herb",  Vector2(-1400,  600), 2, 5, 52.0],
		["herb",     "material_herb",  Vector2(-1400, -600), 2, 5, 52.0],
		["crystal",  "crystal_shard",  Vector2(-1200,    0), 2, 5, 100.0],
		# Ring 3 — recursos raros del bosque oscuro
		["crystal",  "crystal_shard",  Vector2(-1900,  800), 3, 7, 125.0],
		["crystal",  "crystal_shard",  Vector2(-1900, -800), 3, 7, 125.0],
		["crystal",  "crystal_shard",  Vector2(-2400,  500), 3, 7, 130.0],
		["crystal",  "crystal_shard",  Vector2(-2400, -500), 3, 7, 130.0],
		["iron_ore", "ore",       Vector2(-2100, 1200), 4, 8, 80.0],
		["iron_ore", "ore",       Vector2(-2100,-1200), 4, 8, 80.0],
		["herb",     "material_herb",  Vector2(-2700,  300), 3, 7, 60.0],
		["herb",     "material_herb",  Vector2(-2700, -300), 3, 7, 60.0],
		# ── ORES TIERIZADOS (world_west) ────────────────────────
		# T1
		["coal_ore",     "ore", Vector2(-1000, 1000), 2, 5, 35.0, 1],
		["stone_ore",    "ore", Vector2(-1000,-1000), 2, 6, 30.0, 1],
		["iron_ore",     "ore", Vector2( -700, 1100), 2, 5, 55.0, 1],
		["silver_ore",   "ore", Vector2( -600, 1050), 1, 3, 90.0, 1],
		["gold_ore",     "ore", Vector2( -500, 1000), 1, 2,150.0, 1],
		["bluestone_ore","ore", Vector2( -400,  950), 1, 2,200.0, 1],
		# T2
		["coal_ore",     "ore", Vector2(-1900,  800), 2, 5, 40.0, 2],
		["stone_ore",    "ore", Vector2(-1900, -800), 2, 6, 35.0, 2],
		["iron_ore",     "ore", Vector2(-1000, 1000), 3, 6, 65.0, 2],
		["iron_ore",     "ore", Vector2(-1000,-1000), 3, 6, 65.0, 2],
		["silver_ore",   "ore", Vector2(-1800,  700), 2, 4, 95.0, 2],
		["gold_ore",     "ore", Vector2(-1700,  600), 1, 3,155.0, 2],
		["bluestone_ore","ore", Vector2(-1600,  500), 1, 2,205.0, 2],
		# T3
		["coal_ore",     "ore", Vector2(-2400,  500), 3, 6, 42.0, 3],
		["stone_ore",    "ore", Vector2(-2400, -500), 3, 7, 38.0, 3],
		["iron_ore",     "ore", Vector2(-2100, 1200), 4, 8, 80.0, 3],
		["iron_ore",     "ore", Vector2(-2100,-1200), 4, 8, 80.0, 3],
		["silver_ore",   "ore", Vector2(-2300, 1100), 2, 5,100.0, 3],
		["gold_ore",     "ore", Vector2(-2500,  800), 1, 3,160.0, 3],
		["bluestone_ore","ore", Vector2(-2600,  700), 1, 2,210.0, 3],
		# T4
		["coal_ore",     "ore", Vector2(-2700,  300), 3, 7, 50.0, 4],
		["stone_ore",    "ore", Vector2(-2700, -300), 3, 8, 45.0, 4],
		["iron_ore",     "ore", Vector2(-2800,  400), 4, 9, 85.0, 4],
		["silver_ore",   "ore", Vector2(-2900,  200), 2, 5,110.0, 4],
		["gold_ore",     "ore", Vector2(-3000,  100), 1, 3,170.0, 4],
		["bluestone_ore","ore", Vector2(-3000, -100), 1, 2,220.0, 4],
	]

	for d in nodes_data:
		var node = Node2D.new()
		node.set_script(rn_script)
		node.position = d[2]
		add_child(node)
		if node.has_method("setup"):
			node.setup(d[0], d[1], d[3], d[4], d[5], d[6] if d.size() > 6 else -1)


# ════════════════════════════════════════════════════════════
# BOSS MUNDIAL — Ring 3, spawn único por servidor
# ════════════════════════════════════════════════════════════

# ════════════════════════════════════════════════════════════
# BOSS MUNDIAL — la entrada está en la salida oeste del mapa (_setup_borders)
# ════════════════════════════════════════════════════════════


func _draw_boss_altar(center: Vector2) -> void:
	# Plataforma del altar
	var platform = ColorRect.new()
	platform.color    = Color(0.06, 0.10, 0.05)
	platform.size     = Vector2(280, 220)
	platform.position = center - Vector2(140, 110)
	platform.z_index  = -3
	add_child(platform)

	# Árboles gigantes retorcidos alrededor del altar
	for i in 8:
		var angle = (i / 8.0) * TAU
		var tpos  = center + Vector2(cos(angle), sin(angle)) * 160
		_draw_forest_tree(tpos, 1.0)

	# Hongos gigantes bioluminiscentes
	for i in 5:
		var hpos = center + Vector2(cos(i * TAU / 5.0) * 120, sin(i * TAU / 5.0) * 120)
		_draw_mushroom_cluster(hpos)

	# Runas antiguas
	var runes = ["ᛟ","ᚦ","ᚨ","ᚾ","ᛉ","ᛗ","ᛜ"]
	for i in runes.size():
		var angle    = (i / float(runes.size())) * TAU
		var rune_pos = center + Vector2(cos(angle), sin(angle)) * 155
		var lbl = Label.new()
		lbl.text     = runes[i]
		lbl.position = rune_pos
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		add_child(lbl)
		var tw = create_tween().set_loops()
		tw.tween_property(lbl, "modulate:a", 0.15, 1.6 + i * 0.13)
		tw.tween_property(lbl, "modulate:a", 1.0,  1.6 + i * 0.13)

func _spawn_world_boss(pos: Vector2) -> void:
	_boss_spawned = true
	print("[WorldWest] ¡WORLD BOSS: Ancient Forest Guardian Lv 50 invocado!")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_boss_music("world_west")
		get_node("/root/AudioManager").play_sfx("boss_roar")
	if not has_node("/root/EnemyManager"):
		return
	var em = get_node("/root/EnemyManager")
	if not em.has_method("spawn_enemy"):
		return
	_boss_node = em.spawn_enemy("darkelf", pos, 50, self)
	if _boss_node == null:
		return
	_boss_node.scale = Vector2(3.0, 3.0)
	for prop in ["enemy_label","max_hp","current_hp"]:
		if prop in _boss_node:
			match prop:
				"enemy_label": _boss_node.enemy_label = "Ancient Forest Guardian"
				"max_hp":     _boss_node.max_hp      = 5000
				"current_hp": _boss_node.current_hp = 5000
	if _boss_node.has_signal("enemy_died"):
		_boss_node.enemy_died.connect(_on_world_boss_defeated)
	_spawn_boss_aura(_boss_node, Color(0.30, 0.90, 0.50))

func _spawn_boss_aura(boss: Node, col: Color) -> void:
	if not boss is Node2D:
		return
	var aura = GPUParticles2D.new()
	aura.emitting = true; aura.amount = 90; aura.lifetime = 2.0; aura.z_index = 3
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape         = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 36.0
	mat.direction              = Vector3(0, -1, 0)
	mat.spread                 = 180.0
	mat.initial_velocity_min   = 18.0
	mat.initial_velocity_max   = 50.0
	mat.gravity                = Vector3(0, 8, 0)
	mat.scale_min              = 2.0
	mat.scale_max              = 6.0
	var grad = Gradient.new()
	grad.add_point(0.0, Color(col.r, col.g, col.b, 0.0))
	grad.add_point(0.2, Color(col.r, col.g, col.b, 1.0))
	grad.add_point(0.8, Color(col.r*0.7, col.g*0.7, col.b*0.7, 0.5))
	grad.add_point(1.0, Color(col.r*0.4, col.g*0.4, col.b*0.4, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = grad
	mat.color_ramp = gt
	aura.process_material = mat
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	aura.texture = ImageTexture.create_from_image(img)
	boss.add_child(aura)

func _on_world_boss_defeated() -> void:
	if _boss_defeated:
		return
	_boss_defeated = true
	print("[WorldWest] Ancient Forest Guardian derrotado — loot épico!")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").stop_boss_music()
		get_node("/root/AudioManager").play_sfx("boss_death")
	if not has_node("/root/InventoryManager"):
		return
	var inv = get_node("/root/InventoryManager")
	if not inv.has_method("add_item"):
		return
	inv.add_item("material_herb",       randi_range(18, 28))
	inv.add_item("material_bone",       randi_range(10, 18))
	inv.add_item("crystal_shard",       randi_range(8,  15))
	inv.add_item("ore_iron_t1",            randi_range(6,  12))
	inv.add_item("weapon_shadow_blade", 1)
	inv.add_item("armor_shadow_chest",  1)
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("add_experience"):
			gm.add_experience(5000)

	# Respawn del boss tras 30 minutos
	var t = get_tree().create_timer(1800.0)
	t.timeout.connect(func():
		_boss_spawned  = false
		_boss_defeated = false
		# ── MEJORA 8: Notificación global de boss disponible ──
		var ui_nodes = get_tree().get_nodes_in_group("ui")
		for ui in ui_nodes:
			if ui.has_method("show_boss_notification"):
				ui.show_boss_notification(
					"☠ Shadow Lord",
					"el Bosque Oscuro del Oeste",
					Color(0.70, 0.25, 1.00)   # morado sombra
				)
				break
	)


# ════════════════════════════════════════════════════════════
# NIEBLA AMBIENTAL — Partículas globales del bosque oscuro
# ════════════════════════════════════════════════════════════

func _create_fog_particles() -> void:
	_fog_particles = GPUParticles2D.new()
	_fog_particles.name     = "FogParticles"
	_fog_particles.emitting = true
	_fog_particles.amount   = 300
	_fog_particles.lifetime = 12.0
	_fog_particles.z_index  = 10
	_fog_particles.position = Vector2(-SCENE_WIDTH / 4, 0)
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape       = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(SCENE_WIDTH / 2.0, SCENE_HEIGHT / 2.0, 0.0)
	mat.direction            = Vector3(1.0, 0.0, 0.0)
	mat.spread               = 20.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 14.0
	mat.gravity              = Vector3(0, 0, 0)
	mat.scale_min            = 18.0
	mat.scale_max            = 55.0
	var grad = Gradient.new()
	grad.add_point(0.0, Color(0.35, 0.50, 0.35, 0.0))
	grad.add_point(0.2, Color(0.40, 0.55, 0.40, 0.18))
	grad.add_point(0.8, Color(0.38, 0.52, 0.38, 0.14))
	grad.add_point(1.0, Color(0.35, 0.48, 0.35, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = grad
	mat.color_ramp = gt
	mat.angle_min  = 0.0; mat.angle_max = 360.0
	mat.angular_velocity_min = -5.0; mat.angular_velocity_max = 5.0
	_fog_particles.process_material = mat
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_fog_particles.texture = ImageTexture.create_from_image(img)
	add_child(_fog_particles)
