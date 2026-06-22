# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node2D

# ============================================================
# WORLD SOUTH — Praderas del Sur y Bosque Goblin
# VERSION VOID MEGAPACK — Assets pixel-art Void/Goblin
#
#  ANILLO 0 — Entrada (zona segura)              Lv 1-5
#  ANILLO 1 — Pradera Media                      Lv 6-15
#  ANILLO 2 — Bosque Goblin                      Lv 16-30
#  ANILLO 3 — Pantano Maldito (extremo sur)      Lv 31-50
#
# MMORPG Pixel — Godot 4.x
# ============================================================

const SCENE_WIDTH:  int = 18000
const SCENE_HEIGHT: int = 12000

const RING0_Y_MAX: int = -4800
const RING1_Y_MAX: int =     0
const RING2_Y_MAX: int =  2400
const RING3_Y_MAX: int =  6000

# Altura de la escena de town (para calcular el punto de spawn al volver)
const SCENE_HEIGHT_TOWN_HALF: int = 540  # town.tscn SCENE_HEIGHT/2 = 1080/2

# ── Colores de zona (solo para overlays y labels) ──────────
const C_WATER   := Color(0.28, 0.58, 0.85)
const C_SWAMP   := Color(0.22, 0.35, 0.18)
const C_DIRT    := Color(0.55, 0.40, 0.22)

const C_RING0 := Color(0.30, 0.80, 0.30, 0.04)
const C_RING1 := Color(0.85, 0.80, 0.10, 0.05)
const C_RING2 := Color(0.85, 0.40, 0.10, 0.07)
const C_RING3 := Color(0.60, 0.10, 0.10, 0.10)

# ── Rutas de assets Void Megapack ──────────────────────────
const A_GRASS_TILE   := "res://assets/void/grass_tile.png"
const A_GRASS_DIRT   := "res://assets/void/grass1.png"
const A_GRASS_PATCH  := "res://assets/void/grass_patch.png"
const A_TREE_LARGE   := "res://assets/void/tree_large.png"
const A_TREE_PINE    := "res://assets/void/tree_pine.png"
const A_TREE_CAMP    := "res://assets/void/tree_camp.png"   # treeLarge del ForestBiome
const A_CHEST_CLOSED := "res://assets/mobs/south/goblin_chest.png"
const A_CHEST_OPEN   := "res://assets/mobs/south/goblin_chest_open.png"  # BUG A FIXED: sprite abierto separado (si no existe usa chest_open.png genérico)
const A_CAMPFIRE     := "res://assets/void/campfire_sprite.png"
const A_TENT_GOBLIN  := "res://assets/void/tent_goblin.png"
const A_TENT_CONE    := "res://assets/void/tent_cone.png"
const A_ROCK_1       := "res://assets/void/rock_1.png"
const A_ROCK_2       := "res://assets/void/rock_2.png"
const A_ROCK_3       := "res://assets/void/rock_3.png"
const A_FLAG         := "res://assets/void/flag.png"
const A_COLUMNS      := "res://assets/void/columns.png"
# ── Assets Sunnyside (árbol y suelo) ───────────────────────
const A_TREE_SUNNY   := "res://assets/decorations/tree.png"              # fallback estático
const A_TREE_WIND    := "res://assets/decorations/town_tree_b_strip4.png" # pino cónico strip4 — 4 frames 84×129
const A_TREE_WIND_B  := "res://assets/decorations/town_tree_b_strip4.png" # mismo — alias para stockade
const A_TILE_YELLOW  := "res://assets/tiles/tile_grass_yellow.png"
const A_TILE_DIRT    := "res://assets/tiles/tile_dirt.png"

var _boss_spawned:  bool = false

# ── Mejora 6: Detección de cruce de zona ─────────────────────
var _current_ring: int = -1
var _boss_defeated: bool = false
var _boss_node:     Node = null
var _camps: Array = []

# Árbol animations — igual que town_scene (Sprite2D + region_rect en _process)
# { sprite, frame_count, frame_w, frame_h, cur_frame, elapsed, interval }
var _tree_anim_data: Array = []

# ── Cache de texturas ─────────────────────────────────────
var _tex_cache: Dictionary = {}

func _get_tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		if ResourceLoader.exists(path):
			_tex_cache[path] = load(path)
		else:
			_tex_cache[path] = null
	return _tex_cache[path]

func _make_sprite(tex_path: String, pos: Vector2, scale_v: Vector2 = Vector2.ONE,
		z: int = 1, centered: bool = true) -> Sprite2D:
	var tex = _get_tex(tex_path)
	if tex == null:
		return null
	var sp = Sprite2D.new()
	sp.texture = tex
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = centered
	sp.position = pos
	sp.scale = scale_v
	sp.z_index = z
	add_child(sp)
	return sp


# ════════════════════════════════════════════════════════════
# READY
# ════════════════════════════════════════════════════════════

func _ready() -> void:
	print("[WorldSouth] Mapa Void Megapack cargado — 200+ players")
	var _srv: bool = has_node("/root/NetworkManager") and get_node("/root/NetworkManager").is_server
	if not _srv:
		GameManager.ensure_player_and_ui(self)
	_draw_background()
	_draw_ring_overlays()
	_draw_terrain_features()
	if not _srv:
		_animate_scene_trees()
	call_deferred("_setup_camera_limits")
	if not _srv:
		_spawn_player()
	_setup_borders()
	# Diferir spawns para que get_tree().current_scene apunte a esta escena
	# FIX MOBS: solo el SERVIDOR genera campamentos/enemigos — el cliente
	# ya no spawnea nada localmente, los recibe creados por el servidor
	# vía _rpc_sync_enemy_list (ver network_manager.gd). Los recursos
	# (minerales/hierbas/árboles) SÍ se quedan locales por jugador.
	if _srv:
		call_deferred("_spawn_all_camps")
		call_deferred("_spawn_scattered_enemies")
	call_deferred("_spawn_resource_nodes")
	if not _srv:
		_draw_boss_altar(Vector2(0, SCENE_HEIGHT / 2))
		_add_zone_label("☠ SALIDA — BOSS: Goblin Chieftain Lv 50", Vector2(-180, SCENE_HEIGHT / 2 - 90), Color(1, 0.1, 0.1))
		_create_ambient_particles()
	GameManager.set_zone("world_south")
	if not _srv and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_zone_music("world_south")
	if not _srv and has_node("/root/WeatherSystem"):
		get_node("/root/WeatherSystem").set_weather("rain")


# ════════════════════════════════════════════════════════════
# FONDO — tiles de hierba Void Megapack
# ════════════════════════════════════════════════════════════

func _draw_background() -> void:
	# Si ya existe "Background" colocado desde el editor, respetar y no regenerar.
	if has_node("Background"):
		return
	# Fondo: tile_grass_yellow (128x128) repetido como TextureRect
	# Esto da el aspecto Sunnyside con los puntitos característicos en tono amarillo
	var tr = TextureRect.new()
	var tex = _get_tex(A_TILE_YELLOW)
	if tex:
		tr.texture = tex
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		# Fallback: color plano amarillo Sunnyside
		var bg = ColorRect.new()
		bg.color    = Color(0.72, 0.78, 0.22)
		bg.size     = Vector2(SCENE_WIDTH, SCENE_HEIGHT)
		bg.position = Vector2(-SCENE_WIDTH / 2, -SCENE_HEIGHT / 2)
		bg.z_index  = -20
		add_child(bg)
	tr.size     = Vector2(SCENE_WIDTH, SCENE_HEIGHT)
	tr.position = Vector2(-SCENE_WIDTH / 2, -SCENE_HEIGHT / 2)
	tr.z_index  = -20
	add_child(tr)

	# Pantano sur — tono verde oscuro encima del amarillo
	var swamp_bg = ColorRect.new()
	swamp_bg.color    = Color(C_SWAMP.r, C_SWAMP.g, C_SWAMP.b, 0.75)
	swamp_bg.size     = Vector2(SCENE_WIDTH, SCENE_HEIGHT * 0.30)
	swamp_bg.position = Vector2(-SCENE_WIDTH / 2, SCENE_HEIGHT / 2 - SCENE_HEIGHT * 0.30)
	swamp_bg.z_index  = -19
	add_child(swamp_bg)

func _draw_terrain_tiles() -> void:
	pass  # eliminado — el suelo base viene del tile_grass_yellow en _draw_background


# ════════════════════════════════════════════════════════════
# ÁRBOLES DE ESCENA — animación igual que town_scene
# Lee los Sprite2D de Decorations/Trees del .tscn y los anima en _process
# Para editar posiciones: abre world_south.tscn en Godot y mueve los nodos Tree*
# ════════════════════════════════════════════════════════════

func _animate_scene_trees() -> void:
	var trees_node = get_node_or_null("Decorations/Trees")
	if not trees_node:
		return
	for sp in trees_node.get_children():
		if not (sp is Sprite2D and sp.region_enabled):
			continue
		var frame_w    = sp.region_rect.size.x
		var frame_h    = sp.region_rect.size.y
		var frame_count = 4
		var cur_frame  = randi() % frame_count
		sp.region_rect = Rect2(cur_frame * frame_w, 0, frame_w, frame_h)
		_tree_anim_data.append({
			"sprite":      sp,
			"frame_count": frame_count,
			"frame_w":     frame_w,
			"frame_h":     frame_h,
			"cur_frame":   cur_frame,
			"elapsed":     randf_range(0.0, 0.22),
			"interval":    randf_range(0.14, 0.22),
		})

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_process_tree_anims(_delta)
		return
	var py: float = players[0].global_position.y

	var ring: int
	if py <= RING0_Y_MAX:
		ring = 0
	elif py <= RING1_Y_MAX:
		ring = 1
	elif py <= RING2_Y_MAX:
		ring = 2
	else:
		ring = 3

	if ring != _current_ring:
		var prev := _current_ring
		_current_ring = ring
		if prev != -1:
			var ui := GameManager.get_game_ui()
			if ui == null:
				ui = get_tree().get_first_node_in_group("game_ui")
			if ui != null and ui.has_method("show_zone_warning"):
				match ring:
					0: ui.show_zone_warning("⬡ Zona Segura — Sur  Lv 1–5",   Color(0.3, 1.0, 0.3))
					1: ui.show_zone_warning("⬡ Zona Media — Sur  Lv 6–15",   Color(0.9, 0.85, 0.1))
					2: ui.show_zone_warning("⚠ Zona Peligrosa — Sur  Lv 16–30", Color(1.0, 0.55, 0.1))
					3: ui.show_zone_warning("☠ Zona Mortal — Sur  Lv 31–50",  Color(1.0, 0.15, 0.15))

	_process_tree_anims(_delta)

func _process_tree_anims(delta: float) -> void:
	for d in _tree_anim_data:
		var sp: Sprite2D = d["sprite"]
		if not is_instance_valid(sp):
			continue
		d["elapsed"] += delta
		if d["elapsed"] >= d["interval"]:
			d["elapsed"] = 0.0
			d["cur_frame"] = (d["cur_frame"] + 1) % d["frame_count"]
			sp.region_rect = Rect2(d["cur_frame"] * d["frame_w"], 0, d["frame_w"], d["frame_h"])

func _draw_ring_overlays() -> void:
	# Si ya existe "RingOverlays" colocado desde el editor, respetar y no regenerar.
	if has_node("RingOverlays"):
		return
	# Solo labels de zona — sin overlays de color para mantener el suelo limpio
	_add_zone_label("⬡ ZONA SEGURA  Lv 1-5",      Vector2(-600, -4740), Color(0.2, 0.9, 0.2))
	_add_zone_label("⬡ ZONA MEDIA   Lv 6-15",     Vector2(-660, 60), Color(0.9, 0.8, 0.1))
	_add_zone_label("⬡ ZONA PELIGROSA Lv 16-30",  Vector2(-780, 2460), Color(0.9, 0.5, 0.1))
	_add_zone_label("☠ ZONA MORTAL  Lv 31-50",    Vector2(-750, 6060), Color(0.9, 0.2, 0.2))

func _add_zone_label(text: String, pos: Vector2, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text; lbl.position = pos; lbl.z_index = 20
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	var tw = create_tween().set_loops()
	tw.tween_property(lbl, "modulate:a", 0.4, 2.5)
	tw.tween_property(lbl, "modulate:a", 1.0, 2.5)
	add_child(lbl)


# ════════════════════════════════════════════════════════════
# TERRENO — árboles, ríos, rocas, parches de hierba
# ════════════════════════════════════════════════════════════

func _draw_terrain_features() -> void:
	# Si ya existe "Terrain" colocado desde el editor, respetar y no regenerar.
	if has_node("Terrain"):
		return
	# Ríos
	_draw_river(Vector2(-SCENE_WIDTH / 2, 200),  Vector2(SCENE_WIDTH, 30))
	_draw_river(Vector2(-1200, 900),              Vector2(800, 22))

	# Los árboles del mapa vienen del .tscn (Decorations/Trees) — editables en Godot editor

	# Rocas dispersas
	for i in 35:
		var rx = randf_range(-SCENE_WIDTH / 2 + 60, SCENE_WIDTH / 2 - 60)
		var ry = randf_range(-SCENE_HEIGHT / 2 + 60, SCENE_HEIGHT / 2 - 60)
		_draw_rock(Vector2(rx, ry))

	# Hongonas del pantano (zona ring3)
	for i in 25:
		var mx = randf_range(-SCENE_WIDTH / 2 + 40, SCENE_WIDTH / 2 - 40)
		var my = randf_range(RING2_Y_MAX, SCENE_HEIGHT / 2 - 30)
		_draw_swamp_mushroom(Vector2(mx, my))

	# Charcos de pantano
	for i in 12:
		var px = randf_range(-2500, 2500)
		var py = randf_range(RING2_Y_MAX + 100, SCENE_HEIGHT / 2 - 80)
		_draw_swamp_pool(Vector2(px, py), Vector2(randf_range(60, 160), randf_range(30, 70)))

# ── Sub-funciones de terreno ───────────────────────────────

func _draw_grass_patch(pos: Vector2) -> void:
	var sp = _make_sprite(A_GRASS_PATCH, pos,
			Vector2(randf_range(0.4, 0.7), randf_range(0.4, 0.7)), -15)
	if sp:
		sp.modulate.a = randf_range(0.55, 0.85)

func _draw_rock(pos: Vector2) -> void:
	var paths = [A_ROCK_1, A_ROCK_2, A_ROCK_3]
	var path = paths[randi() % 3]
	var sc = randf_range(0.18, 0.34)
	_make_sprite(path, pos, Vector2(sc, sc), 3)

func _draw_river(pos: Vector2, size: Vector2) -> void:
	var bank = ColorRect.new()
	bank.color = C_DIRT; bank.size = size + Vector2(0, 8)
	bank.position = pos - Vector2(0, 4); bank.z_index = -12; add_child(bank)
	var water = ColorRect.new()
	water.color = C_WATER; water.size = size; water.position = pos; water.z_index = -11
	add_child(water)
	# ── Shader de agua animada ─────────────────────────────
	var water_path := "res://scripts/water_anim.gdshader"
	if ResourceLoader.exists(water_path):
		var mat := ShaderMaterial.new()
		mat.shader = load(water_path)
		mat.set_shader_parameter("water_color_shallow", Color(0.28, 0.62, 0.90, 0.92))
		mat.set_shader_parameter("water_color_deep",    Color(0.14, 0.38, 0.72, 0.98))
		water.material = mat
	else:
		# fallback: tween de alpha original
		var tw = create_tween().set_loops()
		tw.tween_property(water, "modulate:a", 0.75, 1.5)
		tw.tween_property(water, "modulate:a", 1.0,  1.5)

func _draw_swamp_mushroom(pos: Vector2) -> void:
	var stem = ColorRect.new()
	stem.color = Color(0.65, 0.58, 0.45); stem.size = Vector2(6, 10)
	stem.position = pos; stem.z_index = 2; add_child(stem)
	var cap = ColorRect.new()
	cap.color = Color(0.80, 0.18, 0.10) if randf() < 0.5 else Color(0.55, 0.18, 0.70)
	cap.size = Vector2(16, 9); cap.position = pos + Vector2(-5, -11)
	cap.z_index = 3; add_child(cap)

func _draw_swamp_pool(pos: Vector2, size: Vector2) -> void:
	var pool = ColorRect.new()
	pool.color = Color(0.18, 0.30, 0.15, 0.75)
	pool.size = size; pool.position = pos - size / 2; pool.z_index = -10; add_child(pool)


# ════════════════════════════════════════════════════════════
# CÁMARA / JUGADOR / BORDES
# ════════════════════════════════════════════════════════════

func _setup_camera_limits() -> void:
	# Se llama con call_deferred para que la Camera2D del Player
	# ya esté en el árbol al momento de configurar los límites.
	var cam = get_viewport().get_camera_2d()
	if cam:
		cam.limit_left   = -SCENE_WIDTH  / 2; cam.limit_right  = SCENE_WIDTH  / 2
		cam.limit_top    = -SCENE_HEIGHT / 2; cam.limit_bottom = SCENE_HEIGHT / 2
	else:
		# Reintentar en el siguiente frame si la cámara aún no existe
		call_deferred("_setup_camera_limits")

func _spawn_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		if GameManager.player_spawn_override:
			players[0].global_position = GameManager.consume_spawn_override()
		else:
			players[0].global_position = Vector2(0, -SCENE_HEIGHT / 2 + 100)

func _setup_borders() -> void:
	var HW = SCENE_WIDTH / 2; var HH = SCENE_HEIGHT / 2
	var PATH = 160; var T = 28
	_add_wall(Vector2(-HW, 0),  Vector2(T, SCENE_HEIGHT))
	_add_wall(Vector2( HW, 0),  Vector2(T, SCENE_HEIGHT))
	var sh = HW - PATH
	_add_wall(Vector2(-(PATH + sh / 2), -HH), Vector2(sh, T))
	_add_wall(Vector2(  PATH + sh / 2,  -HH), Vector2(sh, T))
	# Muro sur con hueco central — la salida sur lleva a la sala del boss
	_add_wall(Vector2(-(PATH + sh / 2), HH), Vector2(sh, T))
	_add_wall(Vector2(  PATH + sh / 2,  HH), Vector2(sh, T))
	var exit = Area2D.new(); exit.name = "ExitTrigger"
	exit.position = Vector2(0, -HH)
	var sc = CollisionShape2D.new(); var sr = RectangleShape2D.new()
	sr.size = Vector2(PATH * 2, T * 4); sc.shape = sr; exit.add_child(sc); add_child(exit)
	exit.body_entered.connect(func(body):
		if body.is_in_group("player"):
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").fade_out(0.8)
			GameManager.save_game()
			InventoryManager.save_inventory()
			PlayerData.flush_pending_save()
			var ls = get_node_or_null("/root/LoadingScreen")
			# Spawn just south of the dungeon entrance border trigger in town
			var spawn_pos = Vector2(0, SCENE_HEIGHT_TOWN_HALF - 60)
			if ls and ls.has_method("go_to_with_spawn"):
				ls.go_to_with_spawn("res://scenes/town.tscn", spawn_pos)
			else:
				GameManager.player_spawn_position = spawn_pos
				GameManager.player_spawn_override  = true
				var _nm_ref = get_node_or_null("/root/NetworkManager"); if _nm_ref: _nm_ref._clear_remote_nodes()
			get_tree().call_deferred("change_scene_to_file", "res://scenes/town.tscn")
	)

	# Salida sur — lleva a la sala exclusiva del Boss (boss_south.tscn)
	var boss_exit = Area2D.new(); boss_exit.name = "BossExitTrigger"
	boss_exit.position = Vector2(0, HH)
	var bsc = CollisionShape2D.new(); var bsr = RectangleShape2D.new()
	bsr.size = Vector2(PATH * 2, T * 4); bsc.shape = bsr; boss_exit.add_child(bsc); add_child(boss_exit)
	boss_exit.body_entered.connect(func(body):
		if body.is_in_group("player") and not _boss_spawned:
			_boss_spawned = true
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").fade_out(0.6)
			var _nm_ref = get_node_or_null("/root/NetworkManager"); if _nm_ref: _nm_ref._clear_remote_nodes()
			get_tree().call_deferred("change_scene_to_file", "res://scenes/boss_south.tscn")
	)

func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body = StaticBody2D.new(); body.position = pos
	var col = CollisionShape2D.new(); var rect = RectangleShape2D.new()
	rect.size = size; col.shape = rect; body.add_child(col); add_child(body)


# ════════════════════════════════════════════════════════════
# CAMPAMENTOS — con sprites Void Megapack
# ════════════════════════════════════════════════════════════

func _spawn_all_camps() -> void:
	# Si ya existe "Camps" colocado desde el editor, respetar y no regenerar.
	if has_node("Camps"):
		return
	# Ring 0 — Lv 1-5 — Slimes, Lobos y Goblins
	_spawn_camp("Campamento Slime",       Vector2(-2400, -4860), "slime",          1, 3,  "ring0")
	_spawn_camp("Pradera del Lobo",       Vector2(2400, -4950), "wolf",           2, 4,  "ring0")
	_spawn_camp("Nido de Goblins Bebé",   Vector2(0, -4920), "wogol",          3, 5,  "ring0", true)
	# Ring 1 — Lv 6-15 — Guerreros Goblin y Arqueros
	_spawn_camp("Aldea Goblin Quemada",   Vector2(-4800, -1500), "goblin_warrior",  6,  9,  "ring1")
	_spawn_camp("Guarida del Bandido",    Vector2(5100, -1200), "goblin_archer",   8,  11, "ring1")
	_spawn_camp("Puesto del Cazador",     Vector2(-2400, -600), "goblin_warrior", 10,  13, "ring1")
	_spawn_camp("Corral de Orcos",        Vector2(2700, -300), "orc",            11, 14, "ring1")
	_spawn_camp("Cruce del Río",          Vector2(0, -900), "goblin_archer",  12, 15, "ring1")
	# Ring 2 — Lv 16-30 — Chamanes, Arañas, Hombres Lobo, Bárbaros
	_spawn_camp("Gran Fuerte Goblin",     Vector2(-7200, 1800), "goblin_barbarian",16, 20, "ring2")
	_spawn_camp("Guarida del Troll",      Vector2(6600, 2100), "ogre",           18, 22, "ring2")
	_spawn_camp("Campamento del Chamán",  Vector2(-3600, 2700), "goblin_shaman",  20, 25, "ring2")
	_spawn_camp("Nido de la Araña Reina", Vector2(3900, 3000), "spider_forest",  22, 27, "ring2")
	_spawn_camp("Manada de Hombres Lobo", Vector2(0, 3300), "werewolf",       25, 30, "ring2")
	# Ring 3 — Lv 31-50 — Jefe Goblin (boss), Reina Araña, Nigromantes
	_spawn_camp("Altar del Pantano",      Vector2(-7800, 5400), "necromancer",    31, 38, "ring3")
	_spawn_camp("Trono del Jefe Goblin",  Vector2(7500, 5700), "goblin_chieftain",35, 42, "ring3")
	_spawn_camp("Cueva de la Araña Reina",Vector2(-3000, 6300), "spider_queen",   38, 45, "ring3")
	_spawn_camp("Guarida del Hydra",      Vector2(3600, 6600), "demonolog",      40, 48, "ring3")
	_spawn_camp("El Foso Eterno",         Vector2(0, 6900), "demon_lord",     45, 50, "ring3")

func _ring_color(ring: String) -> Color:
	match ring:
		"ring0": return Color(0.3, 1.0, 0.3)
		"ring1": return Color(1.0, 0.9, 0.1)
		"ring2": return Color(1.0, 0.55, 0.1)
		"ring3": return Color(1.0, 0.2, 0.2)
	return Color.WHITE

func _spawn_camp(camp_name: String, center: Vector2, mob_type: String,
				 lv_min: int, lv_max: int, ring: String, skip_ground: bool = false) -> void:
	var camp = {"center": center, "enemies": [], "chest_looted": false}
	if not skip_ground:
		_draw_camp_ground(center, ring)
	# Tiendas más grandes y separadas
	_draw_camp_tent_sprite(center + Vector2(-330, -90))
	_draw_camp_tent_cone(center + Vector2(330, -60))
	_draw_camp_banner_sprite(center + Vector2(0, -300), ring)
	_draw_campfire_sprite(center + Vector2(0, 120))
	_draw_camp_stockade(center)

	var lbl = Label.new()
	lbl.text     = "%s\n[Lv %d–%d]" % [camp_name, lv_min, lv_max]
	lbl.position = center + Vector2(-90, -200); lbl.z_index = 30
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", _ring_color(ring))
	add_child(lbl); camp["label"] = lbl

	var chest_node = _draw_chest(center + Vector2(0, 60), ring, lv_min, lv_max)
	camp["chest_node"] = chest_node
	_set_chest_locked(chest_node, true)

	var mob_count = clamp(4 + (lv_min / 10), 4, 9)
	# Offsets con mayor radio para que los mobs estén dentro del anillo de árboles
	var offsets = [
		Vector2(-120,  70), Vector2( 120,  70),
		Vector2(-150, -20), Vector2( 150, -20),
		Vector2( -80,-100), Vector2(  80,-100),
		Vector2(   0,-130),
		Vector2( -50, 110), Vector2(  50, 110)
	]
	var alive_ref = [0]
	if has_node("/root/EnemyManager"):
		var em = get_node("/root/EnemyManager")
		for i in mob_count:
			# FIX BUG CRÍTICO MULTIJUGADOR: antes se usaba randi_range() global,
			# que genera un nivel DISTINTO en cada peer (servidor y cada cliente
			# corren su propia simulación independiente). Esto hacía que cada
			# jugador viera mobs con niveles/cantidades diferentes en el mismo
			# camp, y rompía el matching por proximidad de _rpc_sync_enemy_list
			# (que asume "mismo enemigo" = "misma posición", pero el nivel ya
			# no coincidía visualmente). Con una semilla determinística por
			# camp+slot, TODOS los peers calculan el mismo nivel para el mismo
			# slot, sin necesidad de mandar el dato extra por red.
			var slot_seed: int = int(center.x) * 73856093 ^ int(center.y) * 19349663 ^ (i * 83492791)
			var slot_rng := RandomNumberGenerator.new()
			slot_rng.seed = slot_seed
			var lv = slot_rng.randi_range(lv_min, lv_max)
			if em.has_method("spawn_enemy"):
				var e = em.spawn_enemy(mob_type, center + offsets[i], lv, self)
				if e:
					camp["enemies"].append(e)
					alive_ref[0] += 1
					var c_chest    = chest_node
					var c_ring     = ring
					var c_center   = center
					var c_mob_type = mob_type
					var c_lv_min   = lv_min
					var c_lv_max   = lv_max
					var c_name     = name
					e._camp_death_callback = func():
						alive_ref[0] = max(0, alive_ref[0] - 1)  # FIX v19: evitar negativo
						if alive_ref[0] == 0:
							_on_camp_cleared(c_chest, c_ring, c_center,
									c_mob_type, c_lv_min, c_lv_max, c_name)
	_camps.append(camp)


# ── Dibujo del campamento con sprites Void ─────────────────

func _draw_camp_ground(center: Vector2, ring: String) -> void:
	# Suelo del campamento: base café oscura (tile_dirt) + variación por ring.
	# Se dibuja como un parche circular de tierra que contrasta claramente
	# con la hierba amarilla del fondo, evitando el aspecto de "mancha verde".

	# 1) Capa base sólida café — da la forma del parche
	var base = ColorRect.new()
	base.color    = Color(0.48, 0.33, 0.18, 0.90)   # café tierra
	base.size     = Vector2(380, 280)
	base.position = center - Vector2(190, 140)
	base.z_index  = -5
	add_child(base)

	# 2) Tiles de dirt encima para textura pixel-art
	var offsets_dirt = [
		Vector2(   0,   0), Vector2(-90,  25), Vector2( 90,  25),
		Vector2( -55, -75), Vector2(  55, -75),
		Vector2(-140,  10), Vector2( 140,  10),
		Vector2(   0, -100),
	]
	for off in offsets_dirt:
		var sp = _make_sprite(
			A_TILE_DIRT,
			center + off + Vector2(randf_range(-8, 8), randf_range(-8, 8)),
			Vector2(randf_range(0.90, 1.15), randf_range(0.90, 1.15)),
			-4, true
		)
		if sp:
			sp.rotation_degrees = [0.0, 90.0, 180.0, 270.0][randi() % 4]
			sp.modulate = Color(0.75, 0.58, 0.38, 0.85)   # tonalidad café suave

	# 3) Tinte de ring muy sutil encima (0.06 alpha) para diferenciar zonas
	var tint = ColorRect.new()
	var rc = _ring_color(ring)
	tint.color    = Color(rc.r, rc.g, rc.b, 0.06)
	tint.size     = Vector2(380, 280)
	tint.position = center - Vector2(190, 140)
	tint.z_index  = -3
	add_child(tint)

func _draw_campfire_sprite(pos: Vector2) -> void:
	# Sprite del campfire animado (parpadeo de fuego)
	var sp = _make_sprite(A_CAMPFIRE, pos, Vector2(1.0, 1.0), 6)
	if sp:
		sp.offset = Vector2(0, -10)
		# Animación de parpadeo para simular fuego
		var tw = create_tween().set_loops()
		tw.tween_property(sp, "modulate", Color(1.3, 1.05, 0.65, 1.0), 0.28)
		tw.tween_property(sp, "modulate", Color(0.85, 0.75, 0.45, 1.0), 0.28)
		# Escala pulso fuego
		var tw2 = create_tween().set_loops()
		tw2.tween_property(sp, "scale", Vector2(1.08, 0.88), 0.22)
		tw2.tween_property(sp, "scale", Vector2(0.92, 1.05), 0.22)
	# Humo encima
	_add_smoke_particles(pos + Vector2(0, -28))

func _draw_camp_tent_sprite(pos: Vector2) -> void:
	# tent_goblin.png: 165x135 — tienda roja goblin, bien escalada
	var sp = _make_sprite(A_TENT_GOBLIN, pos, Vector2(1.25, 1.25), 7)
	if sp:
		sp.offset = Vector2(0, -10)

func _draw_camp_tent_cone(pos: Vector2) -> void:
	# tent_cone.png: 113x240 — tienda cónica marrón
	var sp = _make_sprite(A_TENT_CONE, pos, Vector2(1.15, 1.15), 7)
	if sp:
		sp.offset = Vector2(0, -15)

func _draw_camp_banner_sprite(pos: Vector2, ring: String) -> void:
	# Flag Void (22x29) en su color de ring con tween de ondeo
	var sp = _make_sprite(A_FLAG, pos, Vector2(1.4, 1.4), 9)
	if sp:
		sp.modulate = _ring_color(ring)
		var tw = create_tween().set_loops()
		tw.tween_property(sp, "scale:x",  1.10, 0.45 + randf() * 0.25)
		tw.tween_property(sp, "scale:x",  1.40, 0.45 + randf() * 0.25)
	# Poste
	var pole = ColorRect.new(); pole.color = Color(0.35, 0.22, 0.08)
	pole.size = Vector2(4, 44); pole.position = pos - Vector2(2, 44)
	pole.z_index = 8; add_child(pole)

func _draw_camp_stockade(center: Vector2) -> void:
	# Anillo del pino cónico animado (town_tree_b_strip4) rodeando el campamento.
	# Usa Sprite2D + region_rect animado en _process — igual que town_scene.
	const RADIUS    := 260.0
	const NUM_TREES := 12
	var tex = _get_tex(A_TREE_WIND_B)   # town_tree_b 84×129 × 4 frames
	if tex == null:
		return
	var frame_count := 4
	var frame_w := tex.get_width() / frame_count   # 84
	var frame_h := tex.get_height()                # 129
	for i in NUM_TREES:
		var a = (i / float(NUM_TREES)) * TAU
		var south = PI * 1.5
		if abs(wrapf(a - south, -PI, PI)) < 0.44:
			continue
		var north = PI * 0.5
		if abs(wrapf(a - north, -PI, PI)) < 0.27:
			continue
		var pos = center + Vector2(cos(a), sin(a)) * RADIUS
		var cur_frame := randi() % frame_count
		var sp := Sprite2D.new()
		sp.texture        = tex
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.region_enabled = true
		sp.region_rect    = Rect2(cur_frame * frame_w, 0, frame_w, frame_h)
		sp.centered       = true
		sp.position       = pos
		sp.z_index        = -2
		sp.offset         = Vector2(0, -6)
		add_child(sp)
		_tree_anim_data.append({
			"sprite":      sp,
			"frame_count": frame_count,
			"frame_w":     frame_w,
			"frame_h":     frame_h,
			"cur_frame":   cur_frame,
			"elapsed":     randf_range(0.0, 0.22),
			"interval":    randf_range(0.14, 0.22),
		})

func _add_smoke_particles(pos: Vector2) -> void:
	var smoke = GPUParticles2D.new()
	smoke.emitting = true; smoke.amount = 10; smoke.lifetime = 2.0; smoke.z_index = 8; smoke.position = pos
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(4.0, 1.0, 0.0)
	mat.direction = Vector3(0.1, -1.0, 0.0); mat.spread = 20.0
	mat.initial_velocity_min = 8.0; mat.initial_velocity_max = 20.0
	mat.gravity = Vector3(0, -6, 0); mat.scale_min = 3.0; mat.scale_max = 7.0
	var grad = Gradient.new()
	grad.add_point(0.0, Color(0.5, 0.5, 0.5, 0.0)); grad.add_point(0.2, Color(0.55, 0.52, 0.50, 0.55))
	grad.add_point(1.0, Color(0.7, 0.7, 0.7, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = grad; mat.color_ramp = gt
	smoke.process_material = mat
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8); img.fill(Color.WHITE)
	smoke.texture = ImageTexture.create_from_image(img); add_child(smoke)

func _get_chest_closed_tex() -> Texture2D:
	# BUG B FIX: goblin_chest.png es un spritesheet 5x2 (frames de 50x50);
	# recortamos solo el primer frame para no mostrar la hoja completa.
	var raw = _get_tex(A_CHEST_CLOSED)
	if raw == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = raw
	atlas.region = Rect2(0, 0, 50, 50)
	return atlas

func _draw_chest(pos: Vector2, ring: String, lv_min: int, lv_max: int) -> Area2D:
	# Sprite real del cofre goblin (Void Megapack, 200x200 escalado a ~40px)
	var sp = Sprite2D.new()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true; sp.position = pos; sp.z_index = 6
	sp.scale = Vector2(0.9, 0.9)
	var tex_closed = _get_chest_closed_tex()
	# BUG A FIX: si goblin_chest_open.png no existe, usamos chest_open.png genérico
	var tex_open   = _get_tex(A_CHEST_OPEN)
	if tex_open == null:
		tex_open = _get_tex("res://assets/decorations/dungeon/chest_open_full.png")
	if tex_closed:
		sp.texture = tex_closed
	else:
		# Fallback: ColorRect simple si falta el asset
		var body = ColorRect.new(); body.color = Color(0.50, 0.35, 0.12)
		body.size = Vector2(20, 14); body.position = pos - Vector2(10, 7)
		body.z_index = 6; add_child(body)
	add_child(sp)

	# Brillo de ring pulsante bajo el cofre
	var glow = ColorRect.new()
	glow.color = Color(_ring_color(ring).r, _ring_color(ring).g, _ring_color(ring).b, 0.35)
	glow.size  = Vector2(44, 20); glow.position = pos - Vector2(22, 22); glow.z_index = 5
	add_child(glow)
	var tw = create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.10, 1.0)
	tw.tween_property(glow, "modulate:a", 1.00, 1.0)

	# Area2D de interacción
	var area = Area2D.new(); area.name = "ChestArea"; area.position = pos; area.z_index = 10
	var col  = CollisionShape2D.new(); var cir = CircleShape2D.new(); cir.radius = 26.0
	col.shape = cir; area.add_child(col); add_child(area)
	area.set_meta("ring",        ring)
	area.set_meta("lv_min",      lv_min)
	area.set_meta("lv_max",      lv_max)
	area.set_meta("looted",      false)
	area.set_meta("glow_node",   glow)
	area.set_meta("chest_sprite", sp)
	area.set_meta("tex_open",    tex_open if tex_open else tex_closed)
	area.body_entered.connect(func(body2): if body2.is_in_group("player"): _open_chest(area))
	return area


# ════════════════════════════════════════════════════════════
# LÓGICA DE CAMPAMENTOS (igual que original)
# ════════════════════════════════════════════════════════════

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
	notice.text = "[CAMPAMENTO LIMPIO]"
	notice.add_theme_color_override("font_color", Color.GOLD)
	notice.add_theme_font_size_override("font_size", 13)
	notice.position = chest_area.global_position + Vector2(-75, -55); notice.z_index = 200
	add_child(notice)
	var tw2 = notice.create_tween().set_parallel(true)
	tw2.tween_property(notice, "position:y", notice.position.y - 40, 2.5)
	tw2.tween_property(notice, "modulate:a", 0.0, 2.5)
	tw2.finished.connect(func(): if is_instance_valid(notice): notice.queue_free())
	get_tree().create_timer(90.0).timeout.connect(
		func(): _respawn_camp(chest_area, ring, center, mob_type, lv_min, lv_max, camp_name)
	)

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
			# Mismo fix de semilla determinística que en _spawn_camp (ver comentario ahí)
			var slot_seed: int = int(center.x) * 73856093 ^ int(center.y) * 19349663 ^ (i * 83492791) ^ 0x5EED
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
	var notice = Label.new()
	notice.text = "⚠ Campamento reforzado: %s" % camp_name
	notice.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	notice.add_theme_font_size_override("font_size", 12)
	notice.position = center + Vector2(-100, -90); notice.z_index = 200; add_child(notice)
	var tw = notice.create_tween().set_parallel(true)
	tw.tween_property(notice, "position:y", notice.position.y - 35, 2.5)
	tw.tween_property(notice, "modulate:a", 0.0, 2.5)
	tw.finished.connect(func(): if is_instance_valid(notice): notice.queue_free())

func _set_chest_locked(area: Area2D, locked: bool) -> void:
	if not is_instance_valid(area): return
	area.set_meta("camp_locked", locked)
	var glow = area.get_meta("glow_node") if area.has_meta("glow_node") else null
	if glow and is_instance_valid(glow):
		if locked: glow.color = Color(0.2, 0.2, 0.2, 0.25)

func _show_chest_locked_msg(area: Area2D) -> void:
	var notice = Label.new()
	notice.text = "[BLOQUEADO] Derrota todos los enemigos primero"
	notice.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	notice.add_theme_font_size_override("font_size", 12)
	notice.position = area.global_position + Vector2(-120, -50); notice.z_index = 200; add_child(notice)
	var tw = notice.create_tween().set_parallel(true)
	tw.tween_property(notice, "position:y", notice.position.y - 30, 2.0)
	tw.tween_property(notice, "modulate:a", 0.0, 2.0)
	tw.finished.connect(func(): if is_instance_valid(notice): notice.queue_free())

func _open_chest(area: Area2D) -> void:
	if area.get_meta("camp_locked", false):
		_show_chest_locked_msg(area); return
	if area.get_meta("looted"): return
	area.set_meta("looted", true)
	var glow = area.get_meta("glow_node") if area.has_meta("glow_node") else null
	if glow and is_instance_valid(glow): glow.color = Color(0.5, 0.5, 0.5, 0.1)  # FIX v19: null check
	# Cambiar sprite a cofre abierto
	if area.has_meta("chest_sprite") and area.has_meta("tex_open"):
		var csp = area.get_meta("chest_sprite")
		var topen = area.get_meta("tex_open")
		if is_instance_valid(csp) and topen:
			csp.texture = topen
	var ring   = area.get_meta("ring")
	var lv_min = area.get_meta("lv_min"); var lv_max = area.get_meta("lv_max")
	print("[WorldSouth] ¡Cofre abierto! Ring=%s Lv%d-%d" % [ring, lv_min, lv_max])
	if not has_node("/root/InventoryManager"): return
	var inv = get_node("/root/InventoryManager")
	if not inv.has_method("add_item"): return
	match ring:
		"ring0":
			inv.add_item("material_herb",  randi_range(3,  6))
			inv.add_item("wood_log",       randi_range(2,  4))
		"ring1":
			inv.add_item("material_herb",  randi_range(4,  8))
			inv.add_item("wood_log",       randi_range(3,  6))
			inv.add_item("material_bone",  randi_range(2,  5))
		"ring2":
			inv.add_item("material_herb",  randi_range(5, 10))
			inv.add_item("ore_iron_t1",    randi_range(3,  7))
			inv.add_item("material_bone",  randi_range(4,  9))
			if randf() < 0.25: inv.add_item("weapon_shadow_blade", 1)
		"ring3":
			inv.add_item("material_herb",  randi_range(8, 15))
			inv.add_item("ore_iron_t1",    randi_range(6, 12))
			inv.add_item("crystal_shard",  randi_range(4,  8))
			if randf() < 0.50: inv.add_item("weapon_shadow_blade", 1)
			if randf() < 0.20: inv.add_item("armor_shadow_chest",  1)
	var cooldown = 120.0 + (lv_min * 3.0)
	get_tree().create_timer(cooldown).timeout.connect(func():
		area.set_meta("looted", false)
		# Restituir sprite cerrado al respetar
		if area.has_meta("chest_sprite"):
			var csp2 = area.get_meta("chest_sprite")
			var tclosed = _get_chest_closed_tex()
			if is_instance_valid(csp2) and tclosed:
				csp2.texture = tclosed
		if glow and is_instance_valid(glow):  # FIX v19
			glow.color = Color(_ring_color(ring).r, _ring_color(ring).g, _ring_color(ring).b, 0.40)
	)


# ════════════════════════════════════════════════════════════
# ENEMIGOS DISPERSOS
# ════════════════════════════════════════════════════════════

func _spawn_scattered_enemies() -> void:
	# Si ya existe "ScatteredEnemies" en la escena (colocado desde el editor), no regenerar.
	if has_node("ScatteredEnemies"):
		return
	if not has_node("/root/EnemyManager"): return
	var em = get_node("/root/EnemyManager")
	if not em.has_method("spawn_enemy"): return
	var scattered = [
		# Ring 0 — slimes y lobos
		["slime",          1, Vector2(-900,-1800)], ["slime",          3, Vector2( 800,-1850)],
		["wolf",           4, Vector2(-400,-2000)], ["slime",          5, Vector2( 300,-1950)],
		["wolf",           2, Vector2(-1100,-1700)],["slime",          4, Vector2(1000,-1750)],
		# Ring 1 — guerreros y arqueros goblin
		["goblin_warrior", 7, Vector2(-2000,-600)], ["goblin_archer",  9, Vector2(2100,-500)],
		["goblin_warrior", 11,Vector2(-1400,-350)], ["goblin_archer",  13,Vector2(1500,-300)],
		["goblin_warrior", 8, Vector2(-700,-200)],  ["goblin_archer",  10,Vector2( 750,-150)],
		["goblin_warrior", 12,Vector2(-1800,-100)], ["goblin_warrior", 14,Vector2(1900,-50)],
		["goblin_archer",  9, Vector2(-300,-400)],  ["goblin_warrior", 11,Vector2( 400,-450)],
		# Ring 2 — chamanes, arañas, hombres lobo, bárbaros
		["goblin_barbarian",17,Vector2(-2600,400)],  ["goblin_barbarian",20,Vector2(2400,500)],
		["goblin_shaman",  23,Vector2(-1600,700)],  ["spider_forest",  26,Vector2(1700,800)],
		["werewolf",       18,Vector2(-2200,1000)],  ["spider_forest",  22,Vector2(2000,900)],
		["goblin_barbarian",28,Vector2(-600,1200)],  ["goblin_shaman",  25,Vector2( 700,1300)],
		["werewolf",       30,Vector2(-1800,1400)],  ["goblin_barbarian",27,Vector2(1600,1500)],
		# Ring 3 — jefes, reinas araña, nigromantes
		["goblin_chieftain",33,Vector2(-2800,2000)], ["spider_queen",   38,Vector2(2600,2100)],
		["necromancer",    42,Vector2(-1500,2300)],  ["goblin_chieftain",45,Vector2(1400,2400)],
		["spider_queen",   36,Vector2(-2000,2200)],  ["werewolf",       40,Vector2(1800,2300)],
		["necromancer",    48,Vector2(-800,2500)],   ["goblin_chieftain",50,Vector2( 600,2550)],
		["spider_queen",   44,Vector2(-2500,2400)],  ["goblin_barbarian",46,Vector2(2300,2300)],
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
	if not ResourceLoader.exists(rn_script_path): return
	var rn_script = load(rn_script_path)
	var nodes_data = [
		["herb","material_herb",Vector2(-800,-1800),2,5,35.0],
		["herb","material_herb",Vector2( 700,-1850),2,5,35.0],
		["herb","material_herb",Vector2(-300,-2000),2,5,35.0],
		["tree","wood_log",     Vector2(-1100,-1700),2,4,45.0],
		["tree","wood_log",     Vector2( 950,-1750),2,4,45.0],
		["tree","wood_log",     Vector2(  50,-1950),2,4,45.0],
		["herb","material_herb",Vector2(-1800,-500),3,6,50.0],
		["herb","material_herb",Vector2( 1900,-400),3,6,50.0],
		["tree","wood_log",     Vector2(-1000,-250),2,5,55.0],
		["tree","wood_log",     Vector2( 1100,-150),2,5,55.0],
		["iron_ore","ore",      Vector2(-2200,500), 3,7,60.0],
		["iron_ore","ore",      Vector2( 2000,600), 3,7,60.0],
		["iron_ore","ore",      Vector2(-1300,800), 3,7,60.0],
		["herb","material_herb",Vector2( 1400,900), 4,8,55.0],
		["crystal","crystal_shard",Vector2(-2600,1800),3,6,100.0],
		["crystal","crystal_shard",Vector2( 2400,1900),3,6,100.0],
		["crystal","crystal_shard",Vector2(-1200,2100),3,6,100.0],
		["iron_ore","ore",      Vector2(  800,2200), 5,9,75.0],
		["iron_ore","ore",      Vector2(-2200,2400), 5,9,75.0],
		["iron_ore","ore",      Vector2( 2000,2300), 5,9,75.0],
		# T1
		["coal_ore",     "ore", Vector2(-700,   400), 2, 5, 35.0, 1],
		["coal_ore",     "ore", Vector2( 600,   500), 2, 5, 35.0, 1],
		["stone_ore",    "ore", Vector2( 900,   900), 3, 7, 30.0, 1],
		["iron_ore",     "ore", Vector2(-2200,  500), 3, 7, 60.0, 1],
		["silver_ore",   "ore", Vector2(-2100,  450), 2, 4, 90.0, 1],
		["gold_ore",     "ore", Vector2(-2000,  400), 1, 3,150.0, 1],
		["bluestone_ore","ore", Vector2(-1900,  350), 1, 2,200.0, 1],
		# T2
		["coal_ore",     "ore", Vector2(-1800, 1100), 3, 6, 40.0, 2],
		["stone_ore",    "ore", Vector2(-1400, 1500), 3, 7, 35.0, 2],
		["iron_ore",     "ore", Vector2( 2000,  600), 3, 7, 62.0, 2],
		["iron_ore",     "ore", Vector2(-1300,  800), 3, 7, 62.0, 2],
		["silver_ore",   "ore", Vector2(-2400, 1200), 2, 4, 95.0, 2],
		["silver_ore",   "ore", Vector2( 2200, 1300), 2, 4, 95.0, 2],
		["gold_ore",     "ore", Vector2(-2500, 2000), 1, 3,155.0, 2],
		["bluestone_ore","ore", Vector2( 1800, 2500), 1, 2,205.0, 2],
		# T3
		["coal_ore",     "ore", Vector2(  800, 2200), 3, 6, 42.0, 3],
		["iron_ore",     "ore", Vector2(  800, 2200), 4, 8, 75.0, 3],
		["iron_ore",     "ore", Vector2(-2200, 2400), 4, 8, 75.0, 3],
		["silver_ore",   "ore", Vector2(-2300, 2300), 2, 5,100.0, 3],
		["gold_ore",     "ore", Vector2( 2400, 2100), 1, 3,160.0, 3],
		["bluestone_ore","ore", Vector2(-2600, 2200), 1, 2,210.0, 3],
		# T4
		["coal_ore",     "ore", Vector2( 2000, 2300), 3, 7, 50.0, 4],
		["iron_ore",     "ore", Vector2( 2000, 2300), 5, 9, 78.0, 4],
		["silver_ore",   "ore", Vector2(-2700, 2500), 2, 5,110.0, 4],
		["gold_ore",     "ore", Vector2( 2600, 2400), 2, 4,170.0, 4],
		["bluestone_ore","ore", Vector2(-2800, 2600), 1, 2,220.0, 4],
	]
	for d in nodes_data:
		var node = Node2D.new(); node.set_script(rn_script); node.position = d[2]; add_child(node)
		if node.has_method("setup"): node.setup(d[0], d[1], d[3], d[4], d[5], d[6] if d.size() > 6 else -1)


# ════════════════════════════════════════════════════════════
# BOSS MUNDIAL
# ════════════════════════════════════════════════════════════

# ════════════════════════════════════════════════════════════
# BOSS MUNDIAL — la entrada está en la salida sur del mapa (_setup_borders)
# ════════════════════════════════════════════════════════════


func _draw_boss_altar(center: Vector2) -> void:
	# Plataforma oscura del boss
	var platform = ColorRect.new(); platform.color = Color(0.15, 0.28, 0.08)
	platform.size = Vector2(260, 200); platform.position = center - Vector2(130, 100)
	platform.z_index = -3; add_child(platform)
	# Columnas Void alrededor del altar
	var col_sp = _make_sprite(A_COLUMNS, center + Vector2(-100, 30), Vector2(0.55, 0.55), 4)
	if col_sp:
		col_sp.modulate = Color(0.7, 0.4, 0.2)
	var col_sp2 = _make_sprite(A_COLUMNS, center + Vector2(100, 30), Vector2(0.55, 0.55), 4)
	if col_sp2:
		col_sp2.scale.x = -0.55
		col_sp2.modulate = Color(0.7, 0.4, 0.2)
	# Rocas alrededor
	for i in 5:
		var angle = (i / 5.0) * TAU
		var rpos = center + Vector2(cos(angle), sin(angle)) * 150
		_draw_rock(rpos)
	# Labels de totems con efecto
	var totems = ["🌿","🍄","💀","🦎","🐍"]
	for i in totems.size():
		var angle = (i / float(totems.size())) * TAU
		var tpos  = center + Vector2(cos(angle), sin(angle)) * 140
		var lbl   = Label.new(); lbl.text = totems[i]; lbl.position = tpos
		lbl.add_theme_font_size_override("font_size", 22); add_child(lbl)
		var tw = create_tween().set_loops()
		tw.tween_property(lbl, "modulate:a", 0.2, 1.5 + i * 0.12)
		tw.tween_property(lbl, "modulate:a", 1.0, 1.5 + i * 0.12)

func _spawn_world_boss(pos: Vector2) -> void:
	_boss_spawned = true
	print("[WorldSouth] ¡WORLD BOSS: Goblin Chieftain Lv 50 invocado!")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_boss_music("world_south")
		get_node("/root/AudioManager").play_sfx("boss_roar")
	if not has_node("/root/EnemyManager"): return
	var em = get_node("/root/EnemyManager")
	if not em.has_method("spawn_enemy"): return
	_boss_node = em.spawn_enemy("goblin_chieftain", pos, 50, self)
	if _boss_node == null: return
	_boss_node.scale = Vector2(2.0, 2.0)
	for prop in ["enemy_label","max_hp","current_hp"]:
		if prop in _boss_node:
			match prop:
				"enemy_label": _boss_node.enemy_label = "Goblin Chieftain — Jefe Supremo"
				"max_hp":     _boss_node.max_hp = 8000
				"current_hp": _boss_node.current_hp = 8000
	if _boss_node.has_signal("enemy_died"):
		_boss_node.enemy_died.connect(_on_world_boss_defeated)
	_spawn_boss_aura(_boss_node, Color(0.20, 0.85, 0.15))
	# Escoltas — 4 chamanes y 2 bárbaros
	var escort_data = [
		["goblin_shaman",    pos + Vector2(-200, -80), 42],
		["goblin_shaman",    pos + Vector2( 200, -80), 42],
		["goblin_barbarian", pos + Vector2(-160,  80), 44],
		["goblin_barbarian", pos + Vector2( 160,  80), 44],
		["goblin_warrior",   pos + Vector2(-280,   0), 40],
		["goblin_warrior",   pos + Vector2( 280,   0), 40],
	]
	for ed in escort_data:
		em.spawn_enemy(ed[0], ed[1], ed[2], self)

func _spawn_boss_aura(boss: Node, col: Color) -> void:
	if not boss is Node2D: return
	var aura = GPUParticles2D.new()
	aura.emitting = true; aura.amount = 80; aura.lifetime = 1.8; aura.z_index = 3
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 32.0; mat.direction = Vector3(0, -1, 0); mat.spread = 180.0
	mat.initial_velocity_min = 20.0; mat.initial_velocity_max = 55.0
	mat.gravity = Vector3(0, 10, 0); mat.scale_min = 2.0; mat.scale_max = 6.0
	var grad = Gradient.new()
	grad.add_point(0.0, Color(col.r, col.g, col.b, 0.0))
	grad.add_point(0.2, Color(col.r, col.g, col.b, 1.0))
	grad.add_point(0.8, Color(col.r*0.8, col.g*0.8, col.b*0.8, 0.5))
	grad.add_point(1.0, Color(col.r*0.5, col.g*0.5, col.b*0.5, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = grad; mat.color_ramp = gt
	aura.process_material = mat
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8); img.fill(Color.WHITE)
	aura.texture = ImageTexture.create_from_image(img); boss.add_child(aura)

func _on_world_boss_defeated() -> void:
	if _boss_defeated: return
	_boss_defeated = true
	print("[WorldSouth] Goblin Chieftain derrotado!")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").stop_boss_music()
		get_node("/root/AudioManager").play_sfx("boss_death")
	if not has_node("/root/InventoryManager"): return
	var inv = get_node("/root/InventoryManager")
	if not inv.has_method("add_item"): return
	inv.add_item("material_herb",    randi_range(15, 25))
	inv.add_item("ore_iron_t1",      randi_range(8,  15))
	inv.add_item("crystal_shard",    randi_range(5,  10))
	inv.add_item("weapon_shadow_blade", 1)
	inv.add_item("armor_shadow_chest",  1)
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("add_experience"): gm.add_experience(8000)
	get_tree().create_timer(1800.0).timeout.connect(
		func():
			_boss_spawned = false
			_boss_defeated = false
			# ── MEJORA 8: Notificación global de boss disponible ──
			var ui_nodes = get_tree().get_nodes_in_group("ui")
			for ui in ui_nodes:
				if ui.has_method("show_boss_notification"):
					ui.show_boss_notification(
						"☠ Goblin Shaman",
						"las Tierras del Sur",
						Color(0.35, 0.90, 0.30)   # verde goblin
					)
					break
	)


# ════════════════════════════════════════════════════════════
# PARTÍCULAS AMBIENTE
# ════════════════════════════════════════════════════════════

func _create_ambient_particles() -> void:
	# Pétalos / hojas en zona norte
	var petals = GPUParticles2D.new()
	petals.emitting = true; petals.amount = 200; petals.lifetime = 7.0
	petals.z_index = 10; petals.position = Vector2(0, -SCENE_HEIGHT / 2)
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(SCENE_WIDTH / 2.0, 1.0, 0.0)
	mat.direction = Vector3(0.2, 1.0, 0.0); mat.spread = 20.0
	mat.initial_velocity_min = 20.0; mat.initial_velocity_max = 55.0
	mat.gravity = Vector3(0, 12, 0); mat.scale_min = 2.0; mat.scale_max = 5.0
	var grad = Gradient.new()
	grad.add_point(0.0, Color(0.95, 0.5, 0.5, 0.0)); grad.add_point(0.2, Color(0.95, 0.6, 0.7, 0.8))
	grad.add_point(0.8, Color(0.90, 0.45, 0.55, 0.6)); grad.add_point(1.0, Color(0.85, 0.4, 0.5, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = grad; mat.color_ramp = gt
	petals.process_material = mat
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8); img.fill(Color.WHITE)
	petals.texture = ImageTexture.create_from_image(img); add_child(petals)
