# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node2D

# FIX ZONE BUG: ruta explícita y determinista de esta zona, usada por
# enemy_manager.gd para etiquetar zone_scene_path de cada enemigo.
# No depender de scene_file_path: con las 4 escenas de mundo instanciadas
# en rápida sucesión (call_deferred) desde server_main.gd, scene_file_path
# puede no resolverse de forma fiable por instancia en ese escenario.
const ZONE_PATH: String = "res://scenes/world_north.tscn"

# ============================================================
# WORLD NORTH — Picos de Nieve y Ruinas Antiguas
# VERSION EXPANDIDA — 200+ jugadores simultáneos
#
# Tema visual : Nieve, montañas, cristales de hielo, ruinas enanas
# Enemigos    : Todos los niveles distribuidos por ANILLOS geográficos
#
#  ANILLO 0 — Entrada (junto al portal, x: -600..600, y: 500..720)
#             Mobs: lv 1-5   → ideal para jugadores nuevos
#
#  ANILLO 1 — Campo Medio (x: ±600..1800, y: 0..500)
#             Mobs: lv 6-15  → zona de progresión principal
#
#  ANILLO 2 — Montañas Altas (x: ±1800..2800, y: -400..0  /  y: -400..-800)
#             Mobs: lv 16-30 → zona de riesgo, buen loot
#
#  ANILLO 3 — Cima Helada (x: cualquier, y: -800..-1440)
#             Mobs: lv 31-50 → zona peligrosa, cofres épicos, boss world
#
# Filosofía: el jugador ELIGE hasta dónde se aventura en el mismo mapa.
#            No hay paredes entre anillos — sólo dificultad creciente.
#
# MMORPG Pixel — Godot 4.x
# ============================================================

const SCENE_WIDTH:  int = 18000
const SCENE_HEIGHT: int = 12000

# ── Límites de anillos (Y desde el portal sur hacia el norte) ──
const RING0_Y_MIN: int =  4800    # Zona de entrada — y positivo = sur del mapa
const RING1_Y_MIN: int =     0
const RING2_Y_MIN: int = -2400
const RING3_Y_MIN: int = -6000   # Cima — hasta -SCENE_HEIGHT/2

# ── Paleta ──────────────────────────────────────────────────
const C_SNOW_LIGHT  := Color(0.88, 0.92, 0.98)
const C_SNOW_DARK   := Color(0.60, 0.68, 0.80)
const C_ICE         := Color(0.55, 0.80, 0.95)
const C_ROCK        := Color(0.38, 0.35, 0.32)
const C_RUIN        := Color(0.30, 0.28, 0.25)
const C_PINE_DARK   := Color(0.10, 0.28, 0.18)
const C_PINE_SNOW   := Color(0.72, 0.82, 0.90)
const C_BOSS_ZONE   := Color(0.08, 0.05, 0.18)

# ── Colores de anillo (overlay visual sutil) ─────────────────
const C_RING0 := Color(0.30, 0.80, 0.30, 0.04)   # verde muy tenue — zona segura
const C_RING1 := Color(0.85, 0.80, 0.10, 0.05)   # amarillo tenue — precaución
const C_RING2 := Color(0.85, 0.40, 0.10, 0.07)   # naranja — peligroso
const C_RING3 := Color(0.60, 0.10, 0.10, 0.10)   # rojo — muy peligroso

# ── Boss world (spawn único, cooldown global) ────────────────
var _boss_spawned:  bool = false

# ── Mejora 6: Detección de cruce de zona ─────────────────────
var _current_ring: int = -1   # -1 = sin inicializar
var _boss_defeated: bool = false
var _boss_node:     Node = null

# ── Campamentos activos ──────────────────────────────────────
var _camps: Array = []   # [{center, label_node, chest_node, enemies:[]}]

# ── Partículas ───────────────────────────────────────────────
var _snow_particles: GPUParticles2D = null


# ════════════════════════════════════════════════════════════
func _ready() -> void:
	print("[WorldNorth] Mapa expandido cargado — 200+ players")
	var _srv: bool = has_node("/root/NetworkManager") and get_node("/root/NetworkManager").is_server
	if not _srv:
		GameManager.ensure_player_and_ui(self)
	if not _srv:
		_draw_background()
		_draw_ring_overlays()
		_draw_terrain_features()
		call_deferred("_setup_camera_limits")
		_spawn_player()
	_setup_borders()
	# FIX MOBS: solo el SERVIDOR genera campamentos/enemigos — el cliente
	# ya no spawnea nada localmente, los recibe creados por el servidor
	# vía _rpc_sync_enemy_list (ver network_manager.gd). Los recursos
	# (minerales/hierbas/árboles) SÍ se quedan locales por jugador.
	if _srv:
		call_deferred("_spawn_all_camps")
		call_deferred("_spawn_scattered_enemies")
	call_deferred("_spawn_resource_nodes")
	if not _srv:
		_draw_boss_altar(Vector2(0, -SCENE_HEIGHT / 2))
		_add_zone_label("☠ SALIDA — BOSS: Skeleton King Lv 50", Vector2(-170, -SCENE_HEIGHT / 2 + 60), Color(1, 0.1, 0.1))
		_create_snow_particles()
	GameManager.set_zone("world_north")
	if not _srv and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_zone_music("world_north")
	if not _srv and has_node("/root/WeatherSystem"):
		get_node("/root/WeatherSystem").set_weather("snow")

# ════════════════════════════════════════════════════════════
# MEJORA 6 — DETECCIÓN DE CRUCE DE ANILLO (zona peligrosa)
# North: el jugador avanza hacia Y negativo para llegar a zonas
# más peligrosas (RING3_Y_MIN es el más al norte, valor más negativo)
# ════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var py: float = players[0].global_position.y

	# Determinar anillo actual según posición Y
	var ring: int
	if py >= RING0_Y_MIN:
		ring = 0
	elif py >= RING1_Y_MIN:
		ring = 1
	elif py >= RING2_Y_MIN:
		ring = 2
	else:
		ring = 3

	if ring == _current_ring:
		return
	var prev := _current_ring
	_current_ring = ring

	# Solo avisar al avanzar a zona más peligrosa (ring sube) o al retroceder
	if prev == -1:
		return   # primera inicialización silenciosa

	var ui := GameManager.get_game_ui() if GameManager.has_method("get_game_ui") else null
	if ui == null:
		ui = get_tree().get_first_node_in_group("game_ui")
	if ui == null or not ui.has_method("show_zone_warning"):
		return

	match ring:
		0: ui.show_zone_warning("⬡ Zona Segura — Norte  Lv 1–5",   Color(0.3, 1.0, 0.3))
		1: ui.show_zone_warning("⬡ Zona Media — Norte  Lv 6–15",   Color(0.9, 0.85, 0.1))
		2: ui.show_zone_warning("⚠ Zona Peligrosa — Norte  Lv 16–30", Color(1.0, 0.55, 0.1))
		3: ui.show_zone_warning("☠ Zona Mortal — Norte  Lv 31–50",  Color(1.0, 0.15, 0.15))


# ════════════════════════════════════════════════════════════
# FONDO Y OVERLAYS DE ANILLOS
# ════════════════════════════════════════════════════════════

func _draw_background() -> void:
	# Si ya existe "Background" colocado desde el editor, respetar y no regenerar.
	if has_node("Background"):
		return
	var bg = ColorRect.new()
	bg.color    = C_SNOW_LIGHT
	bg.size     = Vector2(SCENE_WIDTH, SCENE_HEIGHT)
	bg.position = Vector2(-SCENE_WIDTH / 2, -SCENE_HEIGHT / 2)
	bg.z_index  = -20
	add_child(bg)

	# Degradado de zona peligrosa — más oscuro al norte
	var danger_gradient = ColorRect.new()
	danger_gradient.color    = Color(0.40, 0.35, 0.55, 0.30)
	danger_gradient.size     = Vector2(SCENE_WIDTH, SCENE_HEIGHT * 0.50)
	danger_gradient.position = Vector2(-SCENE_WIDTH / 2, -SCENE_HEIGHT / 2)
	danger_gradient.z_index  = -19
	add_child(danger_gradient)

func _draw_ring_overlays() -> void:
	# Si ya existe "RingOverlays" colocado desde el editor, respetar y no regenerar.
	if has_node("RingOverlays"):
		return
	# Overlay visual por anillo — muy sutil, sólo guía de color
	var rings = [
		[C_RING0, Vector2(SCENE_WIDTH, SCENE_HEIGHT / 2 - RING0_Y_MIN),
		 Vector2(-SCENE_WIDTH/2, RING0_Y_MIN)],
		[C_RING1, Vector2(SCENE_WIDTH, RING0_Y_MIN - RING1_Y_MIN),
		 Vector2(-SCENE_WIDTH/2, RING1_Y_MIN)],
		[C_RING2, Vector2(SCENE_WIDTH, RING1_Y_MIN - RING2_Y_MIN),
		 Vector2(-SCENE_WIDTH/2, RING2_Y_MIN)],
		[C_RING3, Vector2(SCENE_WIDTH, RING2_Y_MIN - (-SCENE_HEIGHT/2)),
		 Vector2(-SCENE_WIDTH/2, -SCENE_HEIGHT/2)],
	]
	for r in rings:
		var ov = ColorRect.new()
		ov.color    = r[0]
		ov.size     = r[1]
		ov.position = r[2]
		ov.z_index  = -18
		add_child(ov)

	# Etiquetas de zona (sólo en desarrollo — quitar en prod si se prefiere)
	_add_zone_label("⬡ ZONA SEGURA  Lv 1-5",  Vector2(-200, RING0_Y_MIN + 30), Color(0.2,0.8,0.2))
	_add_zone_label("⬡ ZONA MEDIA   Lv 6-15", Vector2(-220, RING1_Y_MIN + 30), Color(0.9,0.8,0.1))
	_add_zone_label("⬡ ZONA PELIGROSA Lv 16-30", Vector2(-260, RING2_Y_MIN + 30), Color(0.9,0.5,0.1))
	_add_zone_label("☠ ZONA MORTAL  Lv 31-50", Vector2(-250, RING3_Y_MIN + 30), Color(0.9,0.2,0.2))

func _add_zone_label(text: String, pos: Vector2, color: Color) -> void:
	var lbl = Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.z_index  = 20
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	# Animación de pulso
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
	# Cordillera al norte
	for i in 14:
		var bx = -SCENE_WIDTH/2 + i * (SCENE_WIDTH / 13.0)
		_draw_mountain_peak(Vector2(bx, -SCENE_HEIGHT/2 + randf_range(60, 200)), randf_range(80, 180))

	# Formaciones de cristal dispersas
	for i in 30:
		var cx = randf_range(-SCENE_WIDTH/2 + 100, SCENE_WIDTH/2 - 100)
		var cy = randf_range(-SCENE_HEIGHT/2 + 100, RING1_Y_MIN)
		_draw_crystal_formation(Vector2(cx, cy))

	# Ruinas columnas — más densas en anillo 2-3
	for i in 24:
		var rx = randf_range(-SCENE_WIDTH/2 + 50, SCENE_WIDTH/2 - 50)
		var ry = randf_range(-SCENE_HEIGHT/2 + 100, RING1_Y_MIN - 100)
		_draw_ruin_column(Vector2(rx, ry))

	# Pinos nevados — bordes y zona media
	for i in 60:
		var px = randf_range(-SCENE_WIDTH/2 + 20, SCENE_WIDTH/2 - 20)
		var py = randf_range(RING2_Y_MIN, SCENE_HEIGHT/2 - 20)
		_draw_snowy_pine(Vector2(px, py))

	# Lagos helados decorativos
	_draw_frozen_lake(Vector2(-1500, 600), Vector2(280, 120))
	_draw_frozen_lake(Vector2( 1800, 300), Vector2(220, 100))
	_draw_frozen_lake(Vector2(  200,-600), Vector2(320, 140))
	_draw_frozen_lake(Vector2(-2200,-1200),Vector2(260, 110))

func _draw_mountain_peak(pos: Vector2, size: float) -> void:
	var body = ColorRect.new()
	body.color    = Color(0.28, 0.30, 0.35)
	body.size     = Vector2(size, size * 1.2)
	body.position = pos - Vector2(size/2, size*0.6)
	body.z_index  = -8
	add_child(body)
	var snow = ColorRect.new()
	snow.color    = C_SNOW_LIGHT
	snow.size     = Vector2(size * 0.55, size * 0.30)
	snow.position = pos - Vector2(size * 0.275, size * 0.62)
	snow.z_index  = -7
	add_child(snow)

func _draw_crystal_formation(pos: Vector2) -> void:
	for i in randi_range(3, 7):
		var shard = ColorRect.new()
		var h = randi_range(15, 38)
		shard.color    = Color(C_ICE.r, C_ICE.g, C_ICE.b, randf_range(0.55, 0.90))
		shard.size     = Vector2(randi_range(5, 12), h)
		shard.position = pos + Vector2(i * 9 - 18, -h * 0.5)
		shard.z_index  = -5
		add_child(shard)

func _draw_ruin_column(pos: Vector2) -> void:
	var col = ColorRect.new()
	col.color    = C_RUIN
	col.size     = Vector2(12, randi_range(30, 55))
	col.position = pos
	col.z_index  = 0
	add_child(col)
	var top = ColorRect.new()
	top.color    = Color(C_RUIN.r + 0.08, C_RUIN.g + 0.08, C_RUIN.b + 0.08)
	top.size     = Vector2(18, 8)
	top.position = pos + Vector2(-3, -8)
	top.z_index  = 0
	add_child(top)

func _draw_snowy_pine(pos: Vector2) -> void:
	var trunk = ColorRect.new()
	trunk.color    = C_ROCK
	trunk.size     = Vector2(7, 18)
	trunk.position = pos
	trunk.z_index  = 1
	add_child(trunk)
	for layer in 3:
		var pine = ColorRect.new()
		pine.color    = C_PINE_DARK
		pine.size     = Vector2(22 - layer * 4, 14)
		pine.position = pos + Vector2(-(11 - layer * 2) + 3, -14 - layer * 9)
		pine.z_index  = 1
		add_child(pine)
		var snow_cap = ColorRect.new()
		snow_cap.color    = C_PINE_SNOW
		snow_cap.size     = Vector2(22 - layer * 4, 5)
		snow_cap.position = pine.position
		snow_cap.z_index  = 2
		add_child(snow_cap)

func _draw_frozen_lake(pos: Vector2, size: Vector2) -> void:
	var lake = ColorRect.new()
	lake.color    = Color(0.60, 0.80, 0.95, 0.65)
	lake.size     = size
	lake.position = pos - size / 2
	lake.z_index  = -10
	add_child(lake)
	# Grietas de hielo decorativas
	for i in 4:
		var crack = ColorRect.new()
		crack.color    = Color(0.75, 0.88, 0.98, 0.80)
		crack.size     = Vector2(randf_range(20, 60), 2)
		crack.position = pos - size/2 + Vector2(randf_range(10, size.x-30), randf_range(5, size.y-5))
		crack.rotation = randf_range(-0.5, 0.5)
		crack.z_index  = -9
		add_child(crack)


# ════════════════════════════════════════════════════════════
# CÁMARA / JUGADOR / BORDES
# ════════════════════════════════════════════════════════════

func _setup_camera_limits() -> void:
	if has_node("/root/NetworkManager") and get_node("/root/NetworkManager").is_server:
		return
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
			players[0].global_position = Vector2(0, SCENE_HEIGHT / 2 - 100)

func _setup_borders() -> void:
	var HW: int = SCENE_WIDTH  / 2
	var HH: int = SCENE_HEIGHT / 2
	var PATH: int = 160
	var T:    int = 28

	# 2 lados cerrados (este/oeste); norte tiene hueco para salida al boss
	_add_wall(Vector2(-HW,  0), Vector2(T, SCENE_HEIGHT)) # Oeste
	_add_wall(Vector2( HW,  0), Vector2(T, SCENE_HEIGHT)) # Este

	# Norte — dos muros con hueco central (salida a la sala del boss)
	var nw: int = HW - PATH
	_add_wall(Vector2(-(PATH + nw/2), -HH), Vector2(nw, T))
	_add_wall(Vector2(  PATH + nw/2,  -HH), Vector2(nw, T))

	# Sur — dos muros con hueco central (portal al pueblo)
	var sw: int = HW - PATH
	_add_wall(Vector2(-(PATH + sw/2), HH), Vector2(sw, T))
	_add_wall(Vector2(  PATH + sw/2,  HH), Vector2(sw, T))

	# Trigger de salida
	var exit := Area2D.new()
	exit.name = "ExitTrigger"
	exit.position = Vector2(0, HH)
	var sc := CollisionShape2D.new()
	var sr := RectangleShape2D.new()
	sr.size = Vector2(PATH * 2, T * 4)
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
			var spawn_pos = Vector2(0, -460)  # justo al sur del borde norte de town (1920x1080)
			var ls = get_node_or_null("/root/LoadingScreen")
			if ls and ls.has_method("go_to_with_spawn"):
				ls.go_to_with_spawn("res://scenes/town.tscn", spawn_pos)
			else:
				GameManager.player_spawn_position = spawn_pos
				GameManager.player_spawn_override  = true
				var _nm_ref = get_node_or_null("/root/NetworkManager"); if _nm_ref: _nm_ref._clear_remote_nodes()
			get_tree().call_deferred("change_scene_to_file", "res://scenes/town.tscn")
	)

	# Salida norte — lleva a la sala exclusiva del Boss (boss_north.tscn)
	var boss_exit := Area2D.new()
	boss_exit.name = "BossExitTrigger"
	boss_exit.position = Vector2(0, -HH)
	var bsc := CollisionShape2D.new()
	var bsr := RectangleShape2D.new()
	bsr.size = Vector2(PATH * 2, T * 4)
	bsc.shape = bsr
	boss_exit.add_child(bsc)
	add_child(boss_exit)
	boss_exit.body_entered.connect(func(body):
		if body.is_in_group("player") and not _boss_spawned:
			_boss_spawned = true
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").fade_out(0.6)
			var _nm_ref = get_node_or_null("/root/NetworkManager"); if _nm_ref: _nm_ref._clear_remote_nodes()
			get_tree().call_deferred("change_scene_to_file", "res://scenes/boss_north.tscn")
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
#   • Grupo de mobs guardándolo (3-8 según tamaño)
#   • 1 cofre con loot acorde al nivel del anillo
#   • Label flotante con nombre y rango de nivel
# ════════════════════════════════════════════════════════════

func _spawn_all_camps() -> void:
	# Si ya existe "Camps" colocado desde el editor, respetar y no regenerar.
	if has_node("Camps"):
		return
	# ── ANILLO 0 — Lv 1-5 ─────────────────────────────────
	_spawn_camp("Puesto de Avanzada",  Vector2(-2400, 4860), "skeleton", 1, 3,  "ring0")
	_spawn_camp("Campamento Yeti",     Vector2(2400, 4860), "skeleton", 2, 4,  "ring0")
	_spawn_camp("Guarida del Lobo",    Vector2(0, 4950), "skeleton", 3, 5,  "ring0")

	# ── ANILLO 1 — Lv 6-15 ────────────────────────────────
	_spawn_camp("Fuerte del Hielo",    Vector2(-4800, 1800), "skeleton", 6,  9,  "ring1")
	_spawn_camp("Campamento Glacial",  Vector2(4800, 1500), "skeleton", 8,  11, "ring1")
	_spawn_camp("Ruinas del Monje",    Vector2(-2400, 600), "skeleton", 10, 13, "ring1")
	_spawn_camp("Guarida del Oso",     Vector2(2700, 300), "skeleton", 11, 14, "ring1")
	_spawn_camp("Torre Derrumbada",    Vector2(0, 1050), "skeleton", 12, 15, "ring1")

	# ── ANILLO 2 — Lv 16-30 ───────────────────────────────
	_spawn_camp("Fortaleza Escarchada",Vector2(-7200, -600), "skeleton", 16, 20, "ring2")
	_spawn_camp("Altar de Gélido",     Vector2(6600, -900), "skeleton", 18, 22, "ring2")
	_spawn_camp("Cripta de Cristal",   Vector2(-3600, -1500), "skeleton", 20, 25, "ring2")
	_spawn_camp("Bastión del Frío",    Vector2(3900, -1800), "skeleton", 22, 27, "ring2")
	_spawn_camp("Necrópolis Nevada",   Vector2(0, -2100), "skeleton", 25, 30, "ring2")

	# ── ANILLO 3 — Lv 31-50 ───────────────────────────────
	_spawn_camp("Cima del Eterno Hielo", Vector2(-7800, -4200), "skeleton", 31, 38, "ring3")
	_spawn_camp("Trono del Rey Helado",  Vector2(7500, -4500), "skeleton", 35, 42, "ring3")
	_spawn_camp("Santuario Prohibido",   Vector2(-3000, -5100), "skeleton", 38, 45, "ring3")
	_spawn_camp("Altar del Vacío",       Vector2(3600, -5400), "skeleton", 40, 48, "ring3")
	_spawn_camp("El Último Bastión",     Vector2(0, -5700), "skeleton", 45, 50, "ring3")

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

# ── Dibujos de campamento ────────────────────────────────────

func _draw_camp_ground(center: Vector2, ring: String) -> void:
	var dirt = ColorRect.new()
	dirt.color    = Color(0.45, 0.38, 0.28, 0.70)
	dirt.size     = Vector2(220, 160)
	dirt.position = center - Vector2(110, 80)
	dirt.z_index  = -3
	add_child(dirt)
	# Borde de color de anillo
	var border = ColorRect.new()
	border.color    = Color(_ring_color(ring).r, _ring_color(ring).g, _ring_color(ring).b, 0.25)
	border.size     = Vector2(228, 168)
	border.position = center - Vector2(114, 84)
	border.z_index  = -4
	add_child(border)

func _draw_campfire(pos: Vector2) -> void:
	# Leños
	var log1 = ColorRect.new()
	log1.color    = Color(0.30, 0.18, 0.08)
	log1.size     = Vector2(22, 7)
	log1.position = pos - Vector2(11, 3)
	log1.rotation = 0.4
	log1.z_index  = 2
	add_child(log1)
	var log2 = log1.duplicate()
	log2.rotation = -0.4
	add_child(log2)
	# Brasa
	var ember = ColorRect.new()
	ember.color    = Color(0.95, 0.50, 0.05)
	ember.size     = Vector2(12, 5)
	ember.position = pos - Vector2(6, 0)
	ember.z_index  = 3
	add_child(ember)
	# Llama — animada
	var flame = ColorRect.new()
	flame.color    = Color(1.0, 0.65, 0.10, 0.90)
	flame.size     = Vector2(9, 14)
	flame.position = pos - Vector2(4, 14)
	flame.z_index  = 4
	add_child(flame)
	var tw = create_tween().set_loops()
	tw.tween_property(flame, "scale", Vector2(1.3, 0.85), 0.35)
	tw.tween_property(flame, "scale", Vector2(0.80, 1.20), 0.35)
	# Partículas de humo sobre hoguera
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
	mat.direction            = Vector3(0.15, -1.0, 0.0)
	mat.spread               = 25.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 22.0
	mat.gravity              = Vector3(0, -8, 0)
	mat.scale_min            = 3.0
	mat.scale_max            = 7.0
	var grad = Gradient.new()
	grad.add_point(0.0, Color(0.5, 0.5, 0.5, 0.0))
	grad.add_point(0.2, Color(0.55, 0.52, 0.50, 0.60))
	grad.add_point(1.0, Color(0.7, 0.7, 0.7, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = grad
	mat.color_ramp = gt
	smoke.process_material = mat
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	smoke.texture = ImageTexture.create_from_image(img)
	add_child(smoke)

func _draw_camp_tent(pos: Vector2) -> void:
	var tent = ColorRect.new()
	tent.color    = Color(0.42, 0.38, 0.30)
	tent.size     = Vector2(40, 28)
	tent.position = pos - Vector2(20, 14)
	tent.z_index  = 5
	add_child(tent)
	var roof = ColorRect.new()
	roof.color    = Color(0.35, 0.30, 0.22)
	roof.size     = Vector2(46, 10)
	roof.position = pos - Vector2(23, 22)
	roof.z_index  = 6
	add_child(roof)
	var pole = ColorRect.new()
	pole.color    = Color(0.55, 0.45, 0.28)
	pole.size     = Vector2(3, 12)
	pole.position = pos - Vector2(1, 28)
	pole.z_index  = 7
	add_child(pole)

func _draw_camp_banner(pos: Vector2, ring: String) -> void:
	var pole = ColorRect.new()
	pole.color    = Color(0.45, 0.35, 0.20)
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
	# Animación de bandeo
	var tw = create_tween().set_loops()
	tw.tween_property(flag, "scale:x", 0.80, 0.6 + randf() * 0.3)
	tw.tween_property(flag, "scale:x", 1.0,  0.6 + randf() * 0.3)

func _draw_camp_stockade(center: Vector2) -> void:
	# Empalizada — 8 postes alrededor del campamento
	var radius = 115.0
	for i in 12:
		var angle = (i / 12.0) * TAU
		var ppos  = center + Vector2(cos(angle), sin(angle)) * radius
		var post  = ColorRect.new()
		post.color    = Color(0.32, 0.24, 0.14)
		post.size     = Vector2(7, 22)
		post.position = ppos - Vector2(3, 11)
		post.z_index  = 3
		add_child(post)
		# Punta del poste
		var tip = ColorRect.new()
		tip.color    = Color(0.38, 0.28, 0.16)
		tip.size     = Vector2(7, 5)
		tip.position = ppos - Vector2(3, 16)
		tip.z_index  = 3
		add_child(tip)

func _draw_chest(pos: Vector2, ring: String, lv_min: int, lv_max: int) -> Area2D:
	# Cuerpo del cofre
	var body = ColorRect.new()
	body.color    = Color(0.55, 0.40, 0.15)
	body.size     = Vector2(20, 14)
	body.position = pos - Vector2(10, 7)
	body.z_index  = 6
	add_child(body)
	var lid = ColorRect.new()
	lid.color    = Color(0.65, 0.50, 0.20)
	lid.size     = Vector2(20, 6)
	lid.position = pos - Vector2(10, 13)
	lid.z_index  = 7
	add_child(lid)
	# Cierre dorado
	var lock = ColorRect.new()
	lock.color    = Color(0.95, 0.80, 0.20)
	lock.size     = Vector2(4, 4)
	lock.position = pos - Vector2(2, 3)
	lock.z_index  = 8
	add_child(lock)

	# Brillo animado según anillo
	var glow = ColorRect.new()
	glow.color    = Color(_ring_color(ring).r, _ring_color(ring).g, _ring_color(ring).b, 0.40)
	glow.size     = Vector2(26, 20)
	glow.position = pos - Vector2(13, 10)
	glow.z_index  = 5
	add_child(glow)
	var tw = create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.15, 1.0)
	tw.tween_property(glow, "modulate:a", 1.0,  1.0)

	# Área de interacción
	var area = Area2D.new()
	area.name     = "ChestArea"
	area.position = pos
	area.z_index  = 10
	var col = CollisionShape2D.new()
	var cir = CircleShape2D.new()
	cir.radius = 22.0
	col.shape   = cir
	area.add_child(col)
	add_child(area)
	area.set_meta("ring",   ring)
	area.set_meta("lv_min", lv_min)
	area.set_meta("lv_max", lv_max)
	area.set_meta("looted", false)
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
	var glow = area.get_meta("glow_node") if area.has_meta("glow_node") else null  # FIX v19
	glow.color = Color(0.5, 0.5, 0.5, 0.1)

	var ring   = area.get_meta("ring")
	var lv_min = area.get_meta("lv_min")
	var lv_max = area.get_meta("lv_max")

	print("[WorldNorth] ¡Cofre abierto! Ring=%s Lv%d-%d" % [ring, lv_min, lv_max])

	if not has_node("/root/InventoryManager"):
		return
	var inv = get_node("/root/InventoryManager")
	if not inv.has_method("add_item"):
		return

	# Loot escalado por anillo
	match ring:
		"ring0":
			inv.add_item("material_herb",   randi_range(2, 5))
			inv.add_item("wood_log",        randi_range(1, 3))
		"ring1":
			inv.add_item("material_bone",   randi_range(3, 7))
			inv.add_item("ore_iron_t1",        randi_range(2, 5))
			inv.add_item("crystal_shard",   randi_range(1, 2))
		"ring2":
			inv.add_item("crystal_shard",   randi_range(3, 6))
			inv.add_item("ore_iron_t1",        randi_range(4, 9))
			inv.add_item("material_bone",   randi_range(5, 10))
			if randf() < 0.30:
				inv.add_item("weapon_shadow_blade", 1)
		"ring3":
			inv.add_item("crystal_shard",   randi_range(6, 12))
			inv.add_item("ore_iron_t1",        randi_range(8, 15))
			inv.add_item("material_bone",   randi_range(8, 14))
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

	# Patrulleros dispersos — dan sensación de mundo vivo
	var scattered = [
		# Ring 0 — 6 patrulleros
		["skeleton", 2,  Vector2(-900, 1800)],
		["skeleton", 3,  Vector2( 800, 1850)],
		["skeleton", 4,  Vector2(-400, 2000)],
		["skeleton", 5,  Vector2( 300, 1950)],
		["skeleton", 3,  Vector2(-1100,1700)],
		["skeleton", 4,  Vector2( 1000,1750)],
		# Ring 1 — 10 patrulleros
		["skeleton", 7,  Vector2(-2000, 700)],
		["skeleton", 9,  Vector2( 2100, 600)],
		["skeleton", 11, Vector2(-1400, 400)],
		["skeleton", 13, Vector2( 1500, 300)],
		["skeleton", 8,  Vector2(-700,  250)],
		["skeleton", 10, Vector2( 750,  200)],
		["skeleton", 12, Vector2(-1800, 100)],
		["skeleton", 14, Vector2( 1900,  50)],
		["skeleton", 9,  Vector2(-300,  450)],
		["skeleton", 11, Vector2( 400,  500)],
		# Ring 2 — 10 patrulleros
		["skeleton", 17, Vector2(-2600, -100)],
		["skeleton", 20, Vector2( 2400, -200)],
		["skeleton", 23, Vector2(-1600, -400)],
		["skeleton", 26, Vector2( 1700, -450)],
		["skeleton", 18, Vector2(-2200, -600)],
		["skeleton", 22, Vector2( 2000, -500)],
		["skeleton", 28, Vector2(-600,  -650)],
		["skeleton", 25, Vector2( 700,  -700)],
		["skeleton", 30, Vector2(-1800, -750)],
		["skeleton", 27, Vector2( 1600, -800)],
		# Ring 3 — 10 patrulleros de élite
		["skeleton", 33, Vector2(-2800,-1100)],
		["skeleton", 38, Vector2( 2600,-1200)],
		["skeleton", 42, Vector2(-1500,-1500)],
		["skeleton", 45, Vector2( 1400,-1600)],
		["skeleton", 36, Vector2(-2000,-1300)],
		["skeleton", 40, Vector2( 1800,-1400)],
		["skeleton", 48, Vector2(-800, -1800)],
		["skeleton", 50, Vector2( 600, -1850)],
		["skeleton", 44, Vector2(-2500,-1700)],
		["skeleton", 46, Vector2( 2300,-1600)],
	]
	for d in scattered:
		em.spawn_enemy(d[0], d[2], d[1], self)


# ════════════════════════════════════════════════════════════
# RECURSOS (distribuidos por toda la zona)
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
		# Ring 0 — recursos básicos
		["herb",    "material_herb",  Vector2(-800, 1800), 1, 3, 40.0],
		["herb",    "material_herb",  Vector2( 700, 1850), 1, 3, 40.0],
		["herb",    "material_herb",  Vector2(-300, 2000), 1, 3, 40.0],
		["tree",    "wood_log",       Vector2(-1100,1700), 2, 4, 45.0],
		["tree",    "wood_log",       Vector2( 950, 1750), 2, 4, 45.0],
		["tree",    "wood_log",       Vector2(  50, 1950), 2, 4, 45.0],
		# Ring 1 — hierro y cristal iniciales
		["iron_ore","material_bone",  Vector2(-1800, 600), 2, 5, 55.0],
		["iron_ore","material_bone",  Vector2( 1900, 500), 2, 5, 55.0],
		["iron_ore","material_bone",  Vector2(-1000, 350), 2, 5, 55.0],
		["crystal", "crystal_shard",  Vector2( 1100, 250), 1, 3, 90.0],
		["crystal", "crystal_shard",  Vector2(-2200, 400), 1, 3, 90.0],
		["tree",    "wood_log",       Vector2( 2000, 200), 2, 4, 50.0],
		["herb",    "material_herb",  Vector2(-600,  450), 1, 3, 45.0],
		# Ring 2 — recursos de calidad media
		["crystal", "crystal_shard",  Vector2(-2500,-150), 2, 5, 100.0],
		["crystal", "crystal_shard",  Vector2( 2300,-250), 2, 5, 100.0],
		["crystal", "crystal_shard",  Vector2(-1300,-500), 2, 5, 100.0],
		["iron_ore","ore",       Vector2( 1400,-400), 3, 6, 65.0],
		["iron_ore","ore",       Vector2(-2000,-600), 3, 6, 65.0],
		["iron_ore","ore",       Vector2( 1800,-700), 3, 6, 65.0],
		# Ring 3 — recursos raros
		["crystal", "crystal_shard",  Vector2(-2700,-1200), 3, 7, 130.0],
		["crystal", "crystal_shard",  Vector2( 2500,-1300), 3, 7, 130.0],
		["crystal", "crystal_shard",  Vector2(-1200,-1600), 3, 7, 130.0],
		["crystal", "crystal_shard",  Vector2(  800,-1700), 3, 7, 130.0],
		["iron_ore","ore",       Vector2(-2200,-1500), 4, 8, 80.0],
		["iron_ore","ore",       Vector2( 2000,-1600), 4, 8, 80.0],

		# ── ORES TIERIZADOS ─────────────────────────────────────
		# T1 — anillos cercanos, pico T1
		["coal_ore",     "ore", Vector2(-600,  1600), 2, 5, 35.0, 1],
		["coal_ore",     "ore", Vector2( 500,  1700), 2, 5, 35.0, 1],
		["stone_ore",    "ore", Vector2(-400,  1900), 3, 7, 30.0, 1],
		["stone_ore",    "ore", Vector2( 800,  1600), 3, 7, 30.0, 1],
		["iron_ore",     "ore", Vector2(-1800,  600), 2, 5, 55.0, 1],
		["iron_ore",     "ore", Vector2( 1900,  500), 2, 5, 55.0, 1],
		["silver_ore",   "ore", Vector2(-1600, -400), 2, 4, 90.0, 1],
		["gold_ore",     "ore", Vector2(-1500, -350), 1, 3,150.0, 1],
		["bluestone_ore","ore", Vector2(-1400, -300), 1, 2,200.0, 1],
		# T2 — anillos medios, pico T2
		["coal_ore",     "ore", Vector2(-1500,  900), 2, 5, 40.0, 2],
		["coal_ore",     "ore", Vector2( 1600,  800), 2, 5, 40.0, 2],
		["stone_ore",    "ore", Vector2(-1700,  700), 3, 7, 35.0, 2],
		["stone_ore",    "ore", Vector2( 1500,  350), 3, 7, 35.0, 2],
		["iron_ore",     "ore", Vector2( 1400, -400), 3, 6, 65.0, 2],
		["iron_ore",     "ore", Vector2(-2000, -600), 3, 6, 65.0, 2],
		["silver_ore",   "ore", Vector2(-2400, -800), 2, 4, 95.0, 2],
		["silver_ore",   "ore", Vector2( 2200, -700), 2, 4, 95.0, 2],
		["gold_ore",     "ore", Vector2(-2600,-1100), 1, 3,155.0, 2],
		["bluestone_ore","ore", Vector2(-2500,-1050), 1, 2,205.0, 2],
		# T3 — anillos exteriores, pico T3
		["coal_ore",     "ore", Vector2(-900,   200), 3, 6, 42.0, 3],
		["stone_ore",    "ore", Vector2(-2100, -200), 3, 7, 38.0, 3],
		["iron_ore",     "ore", Vector2( 1800, -700), 3, 6, 70.0, 3],
		["silver_ore",   "ore", Vector2( 1700, -500), 2, 4,100.0, 3],
		["gold_ore",     "ore", Vector2( 2400,-1200), 1, 3,160.0, 3],
		["gold_ore",     "ore", Vector2(-1500,-1700), 1, 3,160.0, 3],
		["bluestone_ore","ore", Vector2(-2800,-1400), 1, 2,210.0, 3],
		["bluestone_ore","ore", Vector2( 2600,-1500), 1, 2,210.0, 3],
		# T4 — zona más peligrosa, pico T4
		["coal_ore",     "ore", Vector2(-2200,-1500), 3, 7, 50.0, 4],
		["stone_ore",    "ore", Vector2( 2000,-1600), 3, 8, 45.0, 4],
		["iron_ore",     "ore", Vector2(-2200,-1500), 4, 8, 80.0, 4],
		["iron_ore",     "ore", Vector2( 2000,-1600), 4, 8, 80.0, 4],
		["silver_ore",   "ore", Vector2(-2700,-1600), 2, 5,110.0, 4],
		["gold_ore",     "ore", Vector2(-2900,-1700), 1, 3,170.0, 4],
		["bluestone_ore","ore", Vector2( 2700,-1600), 1, 2,220.0, 4],
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
# BOSS MUNDIAL — la entrada está en la salida norte del mapa (_setup_borders)
# ════════════════════════════════════════════════════════════


func _draw_boss_altar(center: Vector2) -> void:
	var platform = ColorRect.new()
	platform.color    = Color(0.15, 0.10, 0.25)
	platform.size     = Vector2(260, 200)
	platform.position = center - Vector2(130, 100)
	platform.z_index  = -3
	add_child(platform)
	var runes = ["ᚱ","ᚢ","ᚾ","ᚨ","ᛋ","ᛏ","ᛖ"]
	for i in runes.size():
		var angle    = (i / float(runes.size())) * TAU
		var rune_pos = center + Vector2(cos(angle), sin(angle)) * 140
		var lbl = Label.new()
		lbl.text     = runes[i]
		lbl.position = rune_pos
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
		add_child(lbl)
		var tw = create_tween().set_loops()
		tw.tween_property(lbl, "modulate:a", 0.2, 1.5 + i * 0.12)
		tw.tween_property(lbl, "modulate:a", 1.0, 1.5 + i * 0.12)

func _spawn_world_boss(pos: Vector2) -> void:
	_boss_spawned = true
	print("[WorldNorth] ¡WORLD BOSS: Skeleton King Lv 50 invocado!")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_boss_music("world_north")
		get_node("/root/AudioManager").play_sfx("boss_roar")
	if not has_node("/root/EnemyManager"):
		return
	var em = get_node("/root/EnemyManager")
	if not em.has_method("spawn_enemy"):
		return
	_boss_node = em.spawn_enemy("skeleton", pos, 50, self)
	if _boss_node == null:
		return
	_boss_node.scale = Vector2(3.0, 3.0)
	for prop in ["enemy_label","max_hp","current_hp"]:
		if prop in _boss_node:
			match prop:
				"enemy_label": _boss_node.enemy_label = "Skeleton King"
				"max_hp":     _boss_node.max_hp      = 5000
				"current_hp": _boss_node.current_hp = 5000
	if _boss_node.has_signal("enemy_died"):
		_boss_node.enemy_died.connect(_on_world_boss_defeated)
	_spawn_boss_aura(_boss_node, Color(0.55, 0.80, 0.95))

func _spawn_boss_aura(boss: Node, col: Color) -> void:
	if not boss is Node2D:
		return
	var aura = GPUParticles2D.new()
	aura.emitting = true; aura.amount = 80; aura.lifetime = 1.8; aura.z_index = 3
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape         = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 32.0
	mat.direction              = Vector3(0, -1, 0)
	mat.spread                 = 180.0
	mat.initial_velocity_min   = 20.0
	mat.initial_velocity_max   = 55.0
	mat.gravity                = Vector3(0, 10, 0)
	mat.scale_min              = 2.0
	mat.scale_max              = 6.0
	var grad = Gradient.new()
	grad.add_point(0.0, Color(col.r, col.g, col.b, 0.0))
	grad.add_point(0.2, Color(col.r, col.g, col.b, 1.0))
	grad.add_point(0.8, Color(col.r*0.8, col.g*0.8, col.b*0.8, 0.5))
	grad.add_point(1.0, Color(col.r*0.5, col.g*0.5, col.b*0.5, 0.0))
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
	print("[WorldNorth] Skeleton King derrotado — loot épico!")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").stop_boss_music()
		get_node("/root/AudioManager").play_sfx("boss_death")
	if not has_node("/root/InventoryManager"):
		return
	var inv = get_node("/root/InventoryManager")
	if not inv.has_method("add_item"):
		return
	inv.add_item("crystal_shard",       randi_range(15, 25))
	inv.add_item("ore_iron_t1",            randi_range(10, 20))
	inv.add_item("material_bone",       randi_range(12, 20))
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
					"☠ Skeleton King",
					"las Tierras del Norte",
					Color(0.75, 0.85, 1.0)   # azul hielo
				)
				break
	)


# ════════════════════════════════════════════════════════════
# PARTÍCULAS DE NIEVE GLOBAL
# ════════════════════════════════════════════════════════════

func _create_snow_particles() -> void:
	_snow_particles = GPUParticles2D.new()
	_snow_particles.name     = "SnowParticles"
	_snow_particles.emitting = true
	_snow_particles.amount   = 500
	_snow_particles.lifetime = 8.0
	_snow_particles.z_index  = 15
	_snow_particles.position = Vector2(0, -SCENE_HEIGHT / 2)
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape       = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(SCENE_WIDTH / 2.0, 1.0, 0.0)
	mat.direction            = Vector3(0.15, 1.0, 0.0)
	mat.spread               = 15.0
	mat.initial_velocity_min = 35.0
	mat.initial_velocity_max = 80.0
	mat.gravity              = Vector3(0, 18, 0)
	mat.scale_min            = 1.5
	mat.scale_max            = 5.0
	mat.color                = Color(0.90, 0.95, 1.0, 0.70)
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1.0, 1.0, 1.0, 0.0))
	grad.add_point(0.2, Color(0.90, 0.95, 1.0, 0.80))
	grad.add_point(0.8, Color(0.85, 0.90, 1.0, 0.65))
	grad.add_point(1.0, Color(0.80, 0.85, 1.0, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = grad
	mat.color_ramp = gt
	mat.angle_min  = 0.0;  mat.angle_max = 360.0
	mat.angular_velocity_min = -25.0; mat.angular_velocity_max = 25.0
	_snow_particles.process_material = mat
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_snow_particles.texture = ImageTexture.create_from_image(img)
	add_child(_snow_particles)
