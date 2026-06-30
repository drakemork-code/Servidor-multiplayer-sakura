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
const ZONE_PATH: String = "res://scenes/world_east.tscn"

# ============================================================
# WORLD EAST — Tierras Volcánicas
# VERSION EXPANDIDA — 200+ jugadores simultáneos
#
# Tema visual : Volcanes, lava, minas de hierro, fortaleza orco
#
#  ANILLO 0 — Entrada (cerca del portal oeste)  Lv 1-5
#  ANILLO 1 — Llanura de Ceniza                 Lv 6-15
#  ANILLO 2 — Corazón Volcánico                 Lv 16-30
#  ANILLO 3 — Abismo de Lava (extremo este)      Lv 31-50
#
# MMORPG Pixel — Godot 4.x
# ============================================================

const SCENE_WIDTH:  int = 18000
const SCENE_HEIGHT: int = 12000

const RING0_X_MAX: int = -4800   # zona entrada — lado oeste
const RING1_X_MAX: int =     0
const RING2_X_MAX: int =  4800
const RING3_X_MAX: int =  9000   # extremo este = más peligroso

const C_ASH         := Color(0.22, 0.20, 0.18)
const C_ROCK_BLACK  := Color(0.15, 0.13, 0.12)
const C_LAVA        := Color(0.95, 0.40, 0.05)
const C_LAVA_BRIGHT := Color(1.00, 0.75, 0.10)
const C_LAVA_DARK   := Color(0.55, 0.15, 0.02)
const C_IRON_VEIN   := Color(0.55, 0.52, 0.58)
const C_BOSS_ZONE   := Color(0.28, 0.10, 0.05)

const C_RING0 := Color(0.30, 0.80, 0.30, 0.04)
const C_RING1 := Color(0.85, 0.80, 0.10, 0.05)
const C_RING2 := Color(0.85, 0.40, 0.10, 0.08)
const C_RING3 := Color(0.70, 0.10, 0.05, 0.12)

var _boss_spawned:  bool = false

# ── Mejora 6: Detección de cruce de zona ─────────────────────
var _current_ring: int = -1
var _boss_defeated: bool = false
var _boss_node:     Node = null
var _camps: Array = []


func _ready() -> void:
	print("[WorldEast] Mapa expandido cargado — 200+ players")
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
		_draw_boss_altar(Vector2(SCENE_WIDTH / 2, 0))
		_add_zone_label("☠ SALIDA — BOSS: Orc Warlord Lv 50", Vector2(SCENE_WIDTH / 2 - 180, -90), Color(1, 0.1, 0.1))
		_create_ember_particles()
		_animate_lava_rivers()
	GameManager.set_zone("world_east")
	if not _srv and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_zone_music("world_east")
	if not _srv and has_node("/root/WeatherSystem"):
		get_node("/root/WeatherSystem").set_weather("none")


# ════════════════════════════════════════════════════════════
# MEJORA 6 — DETECCIÓN DE CRUCE DE ANILLO (zona peligrosa)
# East: peligro crece hacia X positivo (RING3_X_MAX más al este)
# ════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var px: float = players[0].global_position.x

	var ring: int
	if px <= RING0_X_MAX:
		ring = 0
	elif px <= RING1_X_MAX:
		ring = 1
	elif px <= RING2_X_MAX:
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
		0: ui.show_zone_warning("⬡ Zona Segura — Este  Lv 1–5",   Color(0.3, 1.0, 0.3))
		1: ui.show_zone_warning("⬡ Zona Media — Este  Lv 6–15",   Color(0.9, 0.85, 0.1))
		2: ui.show_zone_warning("⚠ Zona Peligrosa — Este  Lv 16–30", Color(1.0, 0.55, 0.1))
		3: ui.show_zone_warning("☠ Zona Mortal — Este  Lv 31–50",  Color(1.0, 0.15, 0.15))


func _draw_background() -> void:
	# Si ya existe un nodo "Background" en la escena (colocado desde el editor),
	# se respeta y no se genera nada proceduralmente.
	if has_node("Background"):
		return
	var bg = ColorRect.new(); bg.color = C_ASH; bg.name = "Background"
	bg.size = Vector2(SCENE_WIDTH,SCENE_HEIGHT); bg.position = Vector2(-SCENE_WIDTH/2,-SCENE_HEIGHT/2)
	bg.z_index = -20; add_child(bg)
	var sky = ColorRect.new(); sky.color = Color(0.40,0.12,0.05,0.55); sky.name = "BackgroundSky"
	sky.size = Vector2(SCENE_WIDTH,SCENE_HEIGHT*0.30)
	sky.position = Vector2(-SCENE_WIDTH/2,-SCENE_HEIGHT/2); sky.z_index = -19; add_child(sky)
	# Brillo rojo al este — zona de boss
	var east_glow = ColorRect.new(); east_glow.color = Color(0.55,0.08,0.02,0.30); east_glow.name = "BackgroundGlow"
	east_glow.size = Vector2(SCENE_WIDTH*0.25,SCENE_HEIGHT)
	east_glow.position = Vector2(SCENE_WIDTH*0.25,-SCENE_HEIGHT/2); east_glow.z_index = -18; add_child(east_glow)

func _draw_ring_overlays() -> void:
	# Si ya existe "RingOverlays" en la escena, no regenerar.
	if has_node("RingOverlays"):
		return
	# Eje X: oeste=seguro, este=peligroso
	var rings = [
		[C_RING0, Vector2(abs(RING0_X_MAX)+SCENE_WIDTH/2, SCENE_HEIGHT), Vector2(-SCENE_WIDTH/2,-SCENE_HEIGHT/2)],
		[C_RING1, Vector2(abs(RING1_X_MAX-RING0_X_MAX),   SCENE_HEIGHT), Vector2(RING0_X_MAX,-SCENE_HEIGHT/2)],
		[C_RING2, Vector2(RING2_X_MAX-RING1_X_MAX,         SCENE_HEIGHT), Vector2(RING1_X_MAX,-SCENE_HEIGHT/2)],
		[C_RING3, Vector2(SCENE_WIDTH/2-RING2_X_MAX,        SCENE_HEIGHT), Vector2(RING2_X_MAX,-SCENE_HEIGHT/2)],
	]
	for r in rings:
		var ov = ColorRect.new(); ov.color = r[0]; ov.size = r[1]; ov.position = r[2]
		ov.z_index = -17; add_child(ov)
	_add_zone_label("⬡ Lv 1-5",   Vector2(RING0_X_MAX-580, -30), Color(0.2,0.9,0.2))
	_add_zone_label("⬡ Lv 6-15",  Vector2(RING1_X_MAX-200, -30), Color(0.9,0.8,0.1))
	_add_zone_label("⬡ Lv 16-30", Vector2(RING2_X_MAX-200, -30), Color(0.9,0.5,0.1))
	_add_zone_label("☠ Lv 31-50", Vector2(RING3_X_MAX-400, -30), Color(0.9,0.2,0.2))

func _add_zone_label(text: String, pos: Vector2, color: Color) -> void:
	var lbl = Label.new(); lbl.text = text; lbl.position = pos; lbl.z_index = 20
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	var tw = create_tween().set_loops()
	tw.tween_property(lbl,"modulate:a",0.4,2.5); tw.tween_property(lbl,"modulate:a",1.0,2.5)
	add_child(lbl)

func _draw_terrain_features() -> void:
	# Si ya existe un nodo "Terrain" en la escena (colocado desde el editor),
	# se respeta y no se genera nada proceduralmente.
	if has_node("Terrain"):
		return
	var _terrain = Node2D.new(); _terrain.name = "Terrain"; add_child(_terrain)
	# Volcanes — más al este
	_draw_volcano(Vector2(-1000,-SCENE_HEIGHT/2+80), 100)
	_draw_volcano(Vector2(  200,-SCENE_HEIGHT/2+60), 140)
	_draw_volcano(Vector2( 1200,-SCENE_HEIGHT/2+50), 160)
	_draw_volcano(Vector2( 2200,-SCENE_HEIGHT/2+40), 180)
	_draw_volcano(Vector2( 2700,-SCENE_HEIGHT/2+55), 130)

	# Ríos de lava paralelos al eje X
	_draw_lava_river(Vector2(-SCENE_WIDTH/2,-60), Vector2(SCENE_WIDTH,22))
	_draw_lava_river(Vector2(-SCENE_WIDTH/2, 250), Vector2(SCENE_WIDTH*0.60,18))
	_draw_lava_river(Vector2(RING2_X_MAX,-300), Vector2(SCENE_WIDTH/2-RING2_X_MAX+SCENE_WIDTH/2,16))

	# Rocas volcánicas
	for i in 60:
		var rx = randf_range(-SCENE_WIDTH/2+40, SCENE_WIDTH/2-40)
		var ry = randf_range(-SCENE_HEIGHT/2+200, SCENE_HEIGHT/2-40)
		_draw_volcanic_rock(Vector2(rx,ry))

	# Minas de hierro — más en ring 1-2
	for i in 14:
		var mx = randf_range(RING0_X_MAX, RING3_X_MAX-100)
		var my = randf_range(-500, 500)
		_draw_iron_mine(Vector2(mx,my))

	# Trono de hierro — boss al extremo este
	_draw_iron_throne(Vector2(2700, -300))

func _draw_volcano(pos: Vector2, size: float) -> void:
	var body = ColorRect.new(); body.color = Color(0.25,0.22,0.20)
	body.size = Vector2(size,size*0.9); body.position = pos - Vector2(size/2,size*0.45); body.z_index = -8; add_child(body)
	var crater = ColorRect.new(); crater.color = C_LAVA
	crater.size = Vector2(size*0.28,size*0.16); crater.position = pos - Vector2(size*0.14,size*0.08); crater.z_index = -7; add_child(crater)
	var glow = ColorRect.new(); glow.color = Color(C_LAVA_BRIGHT.r,C_LAVA_BRIGHT.g,C_LAVA_BRIGHT.b,0.55)
	glow.size = crater.size; glow.position = crater.position; glow.z_index = -6; add_child(glow)
	var tw = create_tween().set_loops()
	tw.tween_property(glow,"modulate:a",0.15,0.8+randf()*0.4)
	tw.tween_property(glow,"modulate:a",1.0, 0.8+randf()*0.4)

func _draw_lava_river(pos: Vector2, size: Vector2) -> void:
	var river = ColorRect.new(); river.color = C_LAVA_DARK
	river.size = size; river.position = pos; river.z_index = -12; add_child(river)
	var glow = ColorRect.new(); glow.color = Color(C_LAVA.r,C_LAVA.g,C_LAVA.b,0.45)
	glow.size = Vector2(size.x,size.y*0.5); glow.position = pos+Vector2(0,size.y*0.25); glow.z_index = -11; add_child(glow)
	# ── Shader de lava animada (water_anim con colores de lava) ──
	var water_path := "res://scripts/water_anim.gdshader"
	if ResourceLoader.exists(water_path):
		var mat := ShaderMaterial.new()
		mat.shader = load(water_path)
		mat.set_shader_parameter("water_color_shallow", Color(1.00, 0.50, 0.05, 0.95))
		mat.set_shader_parameter("water_color_deep",    Color(0.55, 0.15, 0.02, 1.00))
		mat.set_shader_parameter("wave_speed",   0.6)
		mat.set_shader_parameter("wave_scale",   4.0)
		mat.set_shader_parameter("foam_strength", 0.35)
		river.material = mat
	_add_lava_collision(pos,size)

func _add_lava_collision(pos: Vector2, size: Vector2) -> void:
	var body = StaticBody2D.new(); body.position = pos + size*0.5
	body.collision_layer = 1; body.collision_mask = 0; add_child(body)
	var col = CollisionShape2D.new(); var rect = RectangleShape2D.new()
	rect.size = size; col.shape = rect; body.add_child(col)

func _animate_lava_rivers() -> void:
	for child in get_children():
		if child is ColorRect and child.color.is_equal_approx(Color(C_LAVA.r,C_LAVA.g,C_LAVA.b,0.45)):
			var tw = create_tween().set_loops()
			tw.tween_property(child,"modulate:a",0.3,1.0+randf()*0.5)
			tw.tween_property(child,"modulate:a",1.0,1.0+randf()*0.5)

func _draw_volcanic_rock(pos: Vector2) -> void:
	var rock = ColorRect.new(); rock.color = C_ROCK_BLACK
	rock.size = Vector2(randi_range(14,32),randi_range(9,20))
	rock.position = pos; rock.z_index = 0; add_child(rock)

func _draw_iron_mine(pos: Vector2) -> void:
	var entrance = ColorRect.new(); entrance.color = Color(0.12,0.10,0.08)
	entrance.size = Vector2(34,26); entrance.position = pos; entrance.z_index = 1; add_child(entrance)
	for i in 3:
		var vein = ColorRect.new(); vein.color = C_IRON_VEIN
		vein.size = Vector2(4,randi_range(7,14)); vein.position = pos + Vector2(i*9+4,randi_range(2,8))
		vein.z_index = 2; add_child(vein)
	var sign = Label.new(); sign.text = "⛏"; sign.position = pos+Vector2(12,-16)
	sign.add_theme_font_size_override("font_size",14); sign.add_theme_color_override("font_color",Color(0.8,0.7,0.5))
	add_child(sign)

func _draw_iron_throne(pos: Vector2) -> void:
	var base = ColorRect.new(); base.color = Color(0.28,0.26,0.26)
	base.size = Vector2(50,60); base.position = pos - Vector2(25,30); base.z_index = 2; add_child(base)
	var back = ColorRect.new(); back.color = Color(0.22,0.20,0.20)
	back.size = Vector2(50,20); back.position = pos - Vector2(25,50); back.z_index = 2; add_child(back)
	var lbl = Label.new(); lbl.text = "👑"; lbl.position = pos - Vector2(12,68)
	lbl.add_theme_font_size_override("font_size",20); add_child(lbl)


func _setup_camera_limits() -> void:
	if has_node("/root/NetworkManager") and get_node("/root/NetworkManager").is_server:
		return
	var cam = get_viewport().get_camera_2d()
	if cam:
		cam.limit_left = -SCENE_WIDTH/2; cam.limit_right = SCENE_WIDTH/2
		cam.limit_top = -SCENE_HEIGHT/2; cam.limit_bottom = SCENE_HEIGHT/2
	else:
		call_deferred("_setup_camera_limits")

func _spawn_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		if GameManager.player_spawn_override:
			players[0].global_position = GameManager.consume_spawn_override()
		else:
			players[0].global_position = Vector2(-SCENE_WIDTH/2+100, 0)

func _setup_borders() -> void:
	var HW = SCENE_WIDTH/2; var HH = SCENE_HEIGHT/2; var PATH = 160; var T = 28
	_add_wall(Vector2(0,-HH), Vector2(SCENE_WIDTH,T))    # Norte
	_add_wall(Vector2(0, HH), Vector2(SCENE_WIDTH,T))    # Sur
	var sh = HH-PATH
	_add_wall(Vector2(-HW,-(PATH+sh/2)), Vector2(T,sh))
	_add_wall(Vector2(-HW,  PATH+sh/2),  Vector2(T,sh))
	# Este — dos muros con hueco central (salida a la sala del boss)
	_add_wall(Vector2(HW,-(PATH+sh/2)), Vector2(T,sh))
	_add_wall(Vector2(HW,  PATH+sh/2),  Vector2(T,sh))
	var exit = Area2D.new(); exit.name = "ExitTrigger"; exit.position = Vector2(-HW,0)
	var sc = CollisionShape2D.new(); var sr = RectangleShape2D.new()
	sr.size = Vector2(T*4,PATH*2); sc.shape = sr; exit.add_child(sc); add_child(exit)
	exit.body_entered.connect(func(body):
		if body.is_in_group("player"):
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").fade_out(0.8)
			GameManager.save_game()
			InventoryManager.save_inventory()
			PlayerData.flush_pending_save()
			var spawn_pos = Vector2(900, 0)  # justo al oeste del borde este de town (1920x1080)
			var ls = get_node_or_null("/root/LoadingScreen")
			if ls and ls.has_method("go_to_with_spawn"):
				ls.go_to_with_spawn("res://scenes/town.tscn", spawn_pos)
			else:
				GameManager.player_spawn_position = spawn_pos
				GameManager.player_spawn_override  = true
				var _nm_ref = get_node_or_null("/root/NetworkManager"); if _nm_ref: _nm_ref._clear_remote_nodes()
			get_tree().call_deferred("change_scene_to_file", "res://scenes/town.tscn")
	)

	# Salida este — lleva a la sala exclusiva del Boss (boss_east.tscn)
	var boss_exit = Area2D.new(); boss_exit.name = "BossExitTrigger"; boss_exit.position = Vector2(HW,0)
	var bsc = CollisionShape2D.new(); var bsr = RectangleShape2D.new()
	bsr.size = Vector2(T*4,PATH*2); bsc.shape = bsr; boss_exit.add_child(bsc); add_child(boss_exit)
	boss_exit.body_entered.connect(func(body):
		if body.is_in_group("player") and not _boss_spawned:
			_boss_spawned = true
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").fade_out(0.6)
			var _nm_ref = get_node_or_null("/root/NetworkManager"); if _nm_ref: _nm_ref._clear_remote_nodes()
			get_tree().call_deferred("change_scene_to_file", "res://scenes/boss_east.tscn")
	)

func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body = StaticBody2D.new(); body.position = pos
	var col = CollisionShape2D.new(); var rect = RectangleShape2D.new()
	rect.size = size; col.shape = rect; body.add_child(col); add_child(body)


func _ring_color(ring: String) -> Color:
	match ring:
		"ring0": return Color(0.3, 1.0, 0.3)
		"ring1": return Color(1.0, 0.9, 0.1)
		"ring2": return Color(1.0, 0.55, 0.1)
		"ring3": return Color(1.0, 0.2, 0.2)
	return Color.WHITE

func _spawn_all_camps() -> void:
	# Si ya existe "Camps" colocado desde el editor, respetar y no regenerar.
	if has_node("Camps"):
		return
	# Ring 0 — Lv 1-5 (oeste)
	_spawn_camp("Puesto de Ceniza",    Vector2(-7200, -1200), "orc", 1, 3,  "ring0")
	_spawn_camp("Mina Abandonada",     Vector2(-7200, 1200), "orc", 2, 4,  "ring0")
	_spawn_camp("Cueva del Orco Joven",Vector2(-6600, 0), "orc", 3, 5,  "ring0")
	# Ring 1 — Lv 6-15 (llanura de ceniza)
	_spawn_camp("Campamento Orco I",   Vector2(-2400, -1500), "orc", 6, 9,  "ring1")
	_spawn_camp("Cuartel de Ceniza",   Vector2(-2400, 1500), "orc", 8, 11, "ring1")
	_spawn_camp("Torre del Vigía",     Vector2(-1200, -900), "orc", 10,13, "ring1")
	_spawn_camp("Guarida del Shaman",  Vector2(-1200, 900), "orc", 11,14, "ring1")
	_spawn_camp("Mina del Hierro",     Vector2(-300, 0),  "orc", 12,15, "ring1")
	# Ring 2 — Lv 16-30 (corazón volcánico)
	_spawn_camp("Fortaleza Volcánica", Vector2(2400, -1800), "orc", 16,20, "ring2")
	_spawn_camp("Bunker de Lava",      Vector2(2400, 1800), "orc", 18,22, "ring2")
	_spawn_camp("Trono del Orco",      Vector2(3600, -900), "orc", 20,25, "ring2")
	_spawn_camp("Guarida del Ogro",    Vector2(3600, 900), "orc", 22,27, "ring2")
	_spawn_camp("Altar del Fuego",     Vector2(4200, 0),  "orc", 25,30, "ring2")
	# Ring 3 — Lv 31-50 (abismo de lava)
	_spawn_camp("Cráter del Abismo",   Vector2(6000, -2100), "orc", 31,38, "ring3")
	_spawn_camp("Forja del Infierno",  Vector2(6000, 2100), "orc", 35,42, "ring3")
	_spawn_camp("Bastión del Warlord", Vector2(7200, -1200), "orc", 38,45, "ring3")
	_spawn_camp("Templo de la Lava",   Vector2(7200, 1200), "orc", 40,48, "ring3")
	_spawn_camp("El Trono de Hierro",  Vector2(8100, 0), "orc", 45,50, "ring3")

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


func _draw_camp_ground(center: Vector2, ring: String) -> void:
	var border = ColorRect.new()
	border.color = Color(_ring_color(ring).r,_ring_color(ring).g,_ring_color(ring).b,0.22)
	border.size = Vector2(228,168); border.position = center-Vector2(114,84); border.z_index = -4; add_child(border)
	var dirt = ColorRect.new(); dirt.color = Color(0.32,0.28,0.22,0.75)
	dirt.size = Vector2(220,160); dirt.position = center-Vector2(110,80); dirt.z_index = -3; add_child(dirt)

func _draw_campfire(pos: Vector2) -> void:
	var log1 = ColorRect.new(); log1.color = Color(0.28,0.16,0.07); log1.size = Vector2(22,7)
	log1.position = pos-Vector2(11,3); log1.rotation = 0.4; log1.z_index = 2; add_child(log1)
	var log2 = log1.duplicate(); log2.rotation = -0.4; add_child(log2)
	var ember = ColorRect.new(); ember.color = Color(0.95,0.50,0.05)
	ember.size = Vector2(12,5); ember.position = pos-Vector2(6,0); ember.z_index = 3; add_child(ember)
	var flame = ColorRect.new(); flame.color = Color(1.0,0.55,0.05,0.95)
	flame.size = Vector2(9,14); flame.position = pos-Vector2(4,14); flame.z_index = 4; add_child(flame)
	var tw = create_tween().set_loops()
	tw.tween_property(flame,"scale",Vector2(1.3,0.85),0.30)
	tw.tween_property(flame,"scale",Vector2(0.80,1.20),0.30)

func _draw_camp_tent(pos: Vector2) -> void:
	var tent = ColorRect.new(); tent.color = Color(0.35,0.30,0.25)
	tent.size = Vector2(40,28); tent.position = pos-Vector2(20,14); tent.z_index = 5; add_child(tent)
	var roof = ColorRect.new(); roof.color = Color(0.28,0.24,0.20)
	roof.size = Vector2(46,10); roof.position = pos-Vector2(23,22); roof.z_index = 6; add_child(roof)
	var pole = ColorRect.new(); pole.color = Color(0.45,0.38,0.22)
	pole.size = Vector2(3,12); pole.position = pos-Vector2(1,28); pole.z_index = 7; add_child(pole)

func _draw_camp_banner(pos: Vector2, ring: String) -> void:
	var pole = ColorRect.new(); pole.color = Color(0.42,0.32,0.18)
	pole.size = Vector2(3,32); pole.position = pos-Vector2(1,32); pole.z_index = 7; add_child(pole)
	var flag = ColorRect.new(); flag.color = _ring_color(ring)
	flag.size = Vector2(20,14); flag.position = pos-Vector2(0,46); flag.z_index = 8; add_child(flag)
	var tw = create_tween().set_loops()
	tw.tween_property(flag,"scale:x",0.80,0.6+randf()*0.3)
	tw.tween_property(flag,"scale:x",1.0, 0.6+randf()*0.3)

func _draw_camp_stockade(center: Vector2) -> void:
	for i in 12:
		var angle = (i/12.0)*TAU
		var ppos = center+Vector2(cos(angle),sin(angle))*115
		var post = ColorRect.new(); post.color = Color(0.28,0.20,0.10)
		post.size = Vector2(7,22); post.position = ppos-Vector2(3,11); post.z_index = 3; add_child(post)
		var tip = ColorRect.new(); tip.color = Color(0.38,0.28,0.14)
		tip.size = Vector2(7,5); tip.position = ppos-Vector2(3,16); tip.z_index = 3; add_child(tip)

func _draw_chest(pos: Vector2, ring: String, lv_min: int, lv_max: int) -> Area2D:
	var body = ColorRect.new(); body.color = Color(0.52,0.38,0.14)
	body.size = Vector2(20,14); body.position = pos-Vector2(10,7); body.z_index = 6; add_child(body)
	var lid = ColorRect.new(); lid.color = Color(0.62,0.46,0.18)
	lid.size = Vector2(20,6); lid.position = pos-Vector2(10,13); lid.z_index = 7; add_child(lid)
	var lock = ColorRect.new(); lock.color = Color(0.95,0.75,0.15)
	lock.size = Vector2(4,4); lock.position = pos-Vector2(2,3); lock.z_index = 8; add_child(lock)
	var glow = ColorRect.new()
	glow.color = Color(_ring_color(ring).r,_ring_color(ring).g,_ring_color(ring).b,0.40)
	glow.size = Vector2(26,20); glow.position = pos-Vector2(13,10); glow.z_index = 5; add_child(glow)
	var tw = create_tween().set_loops()
	tw.tween_property(glow,"modulate:a",0.15,1.0); tw.tween_property(glow,"modulate:a",1.0,1.0)
	var area = Area2D.new(); area.name = "ChestArea"; area.position = pos; area.z_index = 10
	var col = CollisionShape2D.new(); var cir = CircleShape2D.new(); cir.radius = 22.0
	col.shape = cir; area.add_child(col); add_child(area)
	area.set_meta("ring",ring); area.set_meta("lv_min",lv_min); area.set_meta("lv_max",lv_max)
	area.set_meta("looted",false); area.set_meta("glow_node",glow)
	area.body_entered.connect(func(body2): if body2.is_in_group("player"): _open_chest(area))
	return area

func _open_chest(area: Area2D) -> void:
	if area.get_meta("camp_locked", false):
		_show_chest_locked_msg(area)
		return
	if area.get_meta("looted"): return
	area.set_meta("looted",true)
	var glow = area.get_meta("glow_node") if area.has_meta("glow_node") else null
	if glow and is_instance_valid(glow): glow.color = Color(0.5,0.5,0.5,0.1)  # FIX v19
	var ring = area.get_meta("ring"); var lv_min = area.get_meta("lv_min"); var lv_max = area.get_meta("lv_max")
	if not has_node("/root/InventoryManager"): return
	var inv = get_node("/root/InventoryManager"); if not inv.has_method("add_item"): return
	match ring:
		"ring0": inv.add_item("ore_iron_t1",randi_range(2,5)); inv.add_item("material_bone",randi_range(1,3))
		"ring1": inv.add_item("ore_iron_t1",randi_range(3,7)); inv.add_item("material_bone",randi_range(2,5)); inv.add_item("crystal_shard",randi_range(1,2))
		"ring2":
			inv.add_item("ore_iron_t1",randi_range(5,10)); inv.add_item("material_bone",randi_range(4,8))
			inv.add_item("crystal_shard",randi_range(2,4))
			if randf()<0.30: inv.add_item("weapon_shadow_blade",1)
		"ring3":
			inv.add_item("ore_iron_t1",randi_range(8,16)); inv.add_item("crystal_shard",randi_range(4,8))
			inv.add_item("material_bone",randi_range(6,12))
			if randf()<0.50: inv.add_item("weapon_shadow_blade",1)
			if randf()<0.20: inv.add_item("armor_shadow_chest",1)
	var cooldown = 120.0+(lv_min*3.0)
	var timer = get_tree().create_timer(cooldown)
	timer.timeout.connect(func():
		area.set_meta("looted",false)
		if glow and is_instance_valid(glow):  # FIX v19
			glow.color = Color(_ring_color(ring).r,_ring_color(ring).g,_ring_color(ring).b,0.40)
	)

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
	if not has_node("/root/EnemyManager"): return
	var em = get_node("/root/EnemyManager")
	if not em.has_method("spawn_enemy"): return
	var scattered = [
		["orc",2,Vector2(-2600,-600)],["orc",3,Vector2(-2600,600)],["orc",4,Vector2(-2700,0)],
		["orc",5,Vector2(-2300,300)], ["orc",3,Vector2(-2300,-300)],["orc",4,Vector2(-2100,0)],
		["orc",7,Vector2(-1200,-500)],["orc",9,Vector2(-1200,500)], ["orc",11,Vector2(-900,-300)],
		["orc",13,Vector2(-900,300)], ["orc",8,Vector2(-600,0)],    ["orc",10,Vector2(-600,-400)],
		["orc",12,Vector2(-600,400)], ["orc",14,Vector2(-300,0)],   ["orc",9,Vector2(-300,350)],
		["orc",17,Vector2(400,-500)], ["orc",20,Vector2(400,500)],  ["orc",23,Vector2(600,-300)],
		["orc",26,Vector2(600,300)],  ["orc",18,Vector2(1000,-600)],["orc",22,Vector2(1000,600)],
		["orc",28,Vector2(1300,0)],   ["orc",25,Vector2(1300,-400)],["orc",30,Vector2(1300,400)],
		["orc",33,Vector2(1800,-600)],["orc",38,Vector2(1800,600)], ["orc",42,Vector2(2100,-400)],
		["orc",45,Vector2(2100,400)], ["orc",36,Vector2(2300,0)],   ["orc",40,Vector2(2500,-500)],
		["orc",48,Vector2(2500,500)], ["orc",50,Vector2(2800,0)],   ["orc",44,Vector2(2800,-350)],
		["orc",46,Vector2(2800,350)],
	]
	for d in scattered: em.spawn_enemy(d[0],d[2],d[1],self)

func _spawn_resource_nodes() -> void:
	# Si ya existe "ResourceNodes" colocado desde el editor, respetar y no regenerar.
	if has_node("ResourceNodes"):
		return
	var rn_script_path = "res://scripts/resource_node.gd"
	if not ResourceLoader.exists(rn_script_path): return
	var rn_script = load(rn_script_path)
	var nodes_data = [
		["iron_ore","ore",Vector2(-2500,-300),1,3,40.0],
		["iron_ore","ore",Vector2(-2500, 300),1,3,40.0],
		["iron_ore","ore",Vector2(-2200,   0),1,3,40.0],
		["iron_ore","ore",Vector2(-1500,-400),2,5,55.0],
		["iron_ore","ore",Vector2(-1500, 400),2,5,55.0],
		["iron_ore","ore",Vector2(-1000,   0),2,5,55.0],
		["iron_ore","ore",Vector2( -600,-350),3,7,60.0],
		["iron_ore","ore",Vector2( -600, 350),3,7,60.0],
		["iron_ore","ore",Vector2(  400,-500),4,8,65.0],
		["iron_ore","ore",Vector2(  400, 500),4,8,65.0],
		["iron_ore","ore",Vector2( 1000,-400),4,8,65.0],
		["iron_ore","ore",Vector2( 1000, 400),4,8,65.0],
		["crystal","crystal_shard",Vector2(1400,0),3,6,80.0],
		["crystal","crystal_shard",Vector2(1800,-500),4,7,90.0],
		["crystal","crystal_shard",Vector2(1800, 500),4,7,90.0],
		["crystal","crystal_shard",Vector2(2200,-400),5,8,100.0],
		["crystal","crystal_shard",Vector2(2200, 400),5,8,100.0],
		["crystal","crystal_shard",Vector2(2600,-300),5,9,110.0],
		["crystal","crystal_shard",Vector2(2600, 300),5,9,110.0],
		# ── ORES TIERIZADOS (world_east) ────────────────────────
		# T1
		["coal_ore",     "ore", Vector2(-2500,-300), 2, 5, 35.0, 1],
		["stone_ore",    "ore", Vector2(-2500, 300), 2, 6, 30.0, 1],
		["iron_ore",     "ore", Vector2(-2200,   0), 1, 3, 40.0, 1],
		["silver_ore",   "ore", Vector2(-2100,  50), 1, 3, 90.0, 1],
		["gold_ore",     "ore", Vector2(-2000, 100), 1, 2,150.0, 1],
		["bluestone_ore","ore", Vector2(-1900, 150), 1, 2,200.0, 1],
		# T2
		["coal_ore",     "ore", Vector2(-1500,-400), 2, 5, 40.0, 2],
		["stone_ore",    "ore", Vector2(-1500, 400), 2, 6, 35.0, 2],
		["iron_ore",     "ore", Vector2(-1000,   0), 2, 5, 55.0, 2],
		["silver_ore",   "ore", Vector2( -900,  50), 2, 4, 95.0, 2],
		["gold_ore",     "ore", Vector2( -800, 100), 1, 3,155.0, 2],
		["bluestone_ore","ore", Vector2( -700, 150), 1, 2,205.0, 2],
		# T3
		["coal_ore",     "ore", Vector2( -600,-350), 3, 6, 42.0, 3],
		["stone_ore",    "ore", Vector2( -600, 350), 3, 7, 38.0, 3],
		["iron_ore",     "ore", Vector2(  400,-500), 3, 7, 60.0, 3],
		["iron_ore",     "ore", Vector2(  400, 500), 3, 7, 60.0, 3],
		["silver_ore",   "ore", Vector2(  500,-450), 2, 5,100.0, 3],
		["gold_ore",     "ore", Vector2( 1000,-400), 1, 3,160.0, 3],
		["bluestone_ore","ore", Vector2( 1000, 400), 1, 2,210.0, 3],
		# T4
		["coal_ore",     "ore", Vector2( 1000,-400), 3, 7, 50.0, 4],
		["iron_ore",     "ore", Vector2( 1000, 400), 4, 8, 65.0, 4],
		["silver_ore",   "ore", Vector2( 1200, 350), 2, 5,110.0, 4],
		["gold_ore",     "ore", Vector2( 1400,   0), 1, 3,170.0, 4],
		["bluestone_ore","ore", Vector2( 1600, 300), 1, 2,220.0, 4],
	]
	for d in nodes_data:
		var node = Node2D.new(); node.set_script(rn_script); node.position = d[2]; add_child(node)
		if node.has_method("setup"): node.setup(d[0],d[1],d[3],d[4],d[5], d[6] if d.size() > 6 else -1)

# ════════════════════════════════════════════════════════════
# BOSS MUNDIAL — la entrada está en la salida este del mapa (_setup_borders)
# ════════════════════════════════════════════════════════════


func _draw_boss_altar(center: Vector2) -> void:
	var platform = ColorRect.new(); platform.color = Color(0.22,0.12,0.05)
	platform.size = Vector2(260,200); platform.position = center-Vector2(130,100)
	platform.z_index = -3; add_child(platform)
	for i in 6:
		var angle = (i/6.0)*TAU
		var tpos = center+Vector2(cos(angle),sin(angle))*140
		var lbl = Label.new(); lbl.text = "🔥"; lbl.position = tpos
		lbl.add_theme_font_size_override("font_size",20); add_child(lbl)
		var tw = create_tween().set_loops()
		tw.tween_property(lbl,"modulate:a",0.2,1.2+i*0.10)
		tw.tween_property(lbl,"modulate:a",1.0,1.2+i*0.10)

func _spawn_world_boss(pos: Vector2) -> void:
	_boss_spawned = true
	print("[WorldEast] ¡WORLD BOSS: Orc Warlord Lv 50 invocado!")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_boss_music("world_east")
		get_node("/root/AudioManager").play_sfx("boss_roar")
	if not has_node("/root/EnemyManager"): return
	var em = get_node("/root/EnemyManager"); if not em.has_method("spawn_enemy"): return
	_boss_node = em.spawn_enemy("orc",pos,50,self)
	if _boss_node == null: _boss_node = em.spawn_enemy("goblin",pos,50,self)
	if _boss_node == null: return
	_boss_node.scale = Vector2(3.0,3.0)
	for prop in ["enemy_label","max_hp","current_hp"]:
		if prop in _boss_node:
			match prop:
				"enemy_label": _boss_node.enemy_label = "Orc Warlord"
				"max_hp":     _boss_node.max_hp = 5000
				"current_hp": _boss_node.current_hp = 5000
	if _boss_node.has_signal("enemy_died"): _boss_node.enemy_died.connect(_on_world_boss_defeated)
	_spawn_boss_aura(_boss_node, Color(1.0, 0.45, 0.05))

func _spawn_boss_aura(boss: Node, col: Color) -> void:
	if not boss is Node2D: return
	var aura = GPUParticles2D.new(); aura.emitting = true; aura.amount = 80; aura.lifetime = 1.5; aura.z_index = 3
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 32.0; mat.direction = Vector3(0,-1,0); mat.spread = 180.0
	mat.initial_velocity_min = 20.0; mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0,-15,0); mat.scale_min = 2.0; mat.scale_max = 6.0
	var grad = Gradient.new()
	grad.add_point(0.0,Color(col.r,col.g,col.b,0.0)); grad.add_point(0.1,Color(col.r,col.g,col.b,1.0))
	grad.add_point(0.5,Color(col.r*0.8,col.g*0.5,0.05,0.7)); grad.add_point(1.0,Color(0.3,0.3,0.3,0.0))
	var gt = GradientTexture1D.new(); gt.gradient = grad; mat.color_ramp = gt
	aura.process_material = mat
	var img = Image.create(4,4,false,Image.FORMAT_RGBA8); img.fill(Color.WHITE)
	aura.texture = ImageTexture.create_from_image(img); boss.add_child(aura)

func _on_world_boss_defeated() -> void:
	if _boss_defeated: return
	_boss_defeated = true
	print("[WorldEast] Orc Warlord derrotado!")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").stop_boss_music()
		get_node("/root/AudioManager").play_sfx("boss_death")
	if not has_node("/root/InventoryManager"): return
	var inv = get_node("/root/InventoryManager"); if not inv.has_method("add_item"): return
	inv.add_item("ore_iron_t1",randi_range(20,35)); inv.add_item("crystal_shard",randi_range(8,15))
	inv.add_item("material_bone",randi_range(10,18)); inv.add_item("weapon_shadow_blade",1)
	inv.add_item("armor_shadow_chest",1)
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("add_experience"): gm.add_experience(5000)
	var t = get_tree().create_timer(1800.0)
	t.timeout.connect(func():
		_boss_spawned = false
		_boss_defeated = false
		# ── MEJORA 8: Notificación global de boss disponible ──
		var ui_nodes = get_tree().get_nodes_in_group("ui")
		for ui in ui_nodes:
			if ui.has_method("show_boss_notification"):
				ui.show_boss_notification(
					"☠ Orc Warlord",
					"las Tierras del Este",
					Color(1.0, 0.45, 0.10)   # naranja volcánico
				)
				break
	)

func _create_ember_particles() -> void:
	var embers = GPUParticles2D.new(); embers.name = "EmberParticles"
	embers.emitting = true; embers.amount = 300; embers.lifetime = 5.0
	embers.z_index = 12; embers.position = Vector2(0,SCENE_HEIGHT/4)
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(SCENE_WIDTH/2.0,SCENE_HEIGHT/4.0,0.0)
	mat.direction = Vector3(0.2,-1.0,0.0); mat.spread = 40.0
	mat.initial_velocity_min = 25.0; mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(-5,-30,0); mat.scale_min = 1.5; mat.scale_max = 4.0
	var grad = Gradient.new()
	grad.add_point(0.0,Color(1.0,0.9,0.3,0.0)); grad.add_point(0.1,Color(1.0,0.7,0.1,1.0))
	grad.add_point(0.5,Color(0.9,0.3,0.05,0.8)); grad.add_point(0.9,Color(0.4,0.4,0.4,0.4))
	grad.add_point(1.0,Color(0.2,0.2,0.2,0.0))
	var gt = GradientTexture1D.new(); gt.gradient = grad; mat.color_ramp = gt
	mat.turbulence_enabled = true; mat.turbulence_noise_strength = 0.8; mat.turbulence_noise_scale = 2.5
	embers.process_material = mat
	var img = Image.create(3,3,false,Image.FORMAT_RGBA8); img.fill(Color.WHITE)
	embers.texture = ImageTexture.create_from_image(img); add_child(embers)
