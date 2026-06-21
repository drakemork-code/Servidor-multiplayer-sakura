# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node2D

# ============================================================
# BOSS WEST — Arena del Shadow Lord
# Shadow Lord — Abismo del Bosque Oscuro
# Fases: niebla (fase2), teletransporte + sombras (fase3)
# ============================================================

const ARENA_W: int = 640
const ARENA_H: int = 480

const BOSS_NAME     := "Shadow Lord"
const BOSS_LEVEL    := 50
const BOSS_MAX_HP   := 6000
const BOSS_MOB_TYPE := "darkelf"
const MUSIC_KEY     := "world_west"

const C_FLOOR     := Color(0.08, 0.06, 0.12)
const C_WALL      := Color(0.05, 0.04, 0.08)
const C_RUNE      := Color(0.65, 0.10, 0.90)
const C_DOOR_LOCK := Color(0.30, 0.05, 0.40)
const C_DOOR_OPEN := Color(0.55, 0.20, 0.90)

var _boss_node:     Node = null
var _boss_defeated: bool = false
var _door_col:      StaticBody2D = null
var _door_node:     ColorRect = null
var _current_phase: int = 1
var _mechanics: BossMechanics = null
var _mechanic_timer: float = 0.0
var _mechanic_interval: float = 9.0
var _adds_alive: Array = []
var _shadow_orbs:   Array = []

func _ready() -> void:
	# FIX CRÍTICO: el cambio de escena anterior destruye Player/Camera2D/GameUI.
	# Sin esto no existe ningún Camera2D en el árbol → pantalla negra.
	GameManager.ensure_player_and_ui(self)
	_draw_arena()
	_spawn_player_at_entrance()
	_close_door()
	_spawn_boss()
	_setup_exit_portal()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_boss_music(MUSIC_KEY)
	call_deferred("_debug_log_render_state")

func _debug_log_render_state() -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp else null
	var players := get_tree().get_nodes_in_group("player")
	print("[BossRoom:%s] viewport_size=%s window_size=%s stretch_mode=%s" % [
		name, vp.get_visible_rect().size if vp else "N/A",
		DisplayServer.window_get_size(), get_tree().root.content_scale_mode])
	print("[BossRoom:%s] camera=%s camera_enabled=%s camera_global_pos=%s zoom=%s" % [
		name, cam, (cam.enabled if cam else "N/A"),
		(cam.global_position if cam else "N/A"), (cam.zoom if cam else "N/A")])
	if players.size() > 0:
		print("[BossRoom:%s] player_global_pos=%s" % [name, players[0].global_position])
		if is_nan(players[0].global_position.x) or is_nan(players[0].global_position.y):
			push_error("[BossRoom:%s] ¡Posición del jugador es NaN!" % name)
	else:
		push_error("[BossRoom:%s] No se encontró ningún player tras ensure_player_and_ui()" % name)
	print("[BossRoom:%s] arena_node_children=%d" % [name, get_node("Arena").get_child_count() if has_node("Arena") else -1])

func _draw_arena() -> void:
	# Si ya existe "Arena" colocado desde el editor, respetar y no regenerar.
	if has_node("Arena") and get_node("Arena").get_child_count() > 0:
		return
	var hw := ARENA_W / 2; var hh := ARENA_H / 2
	var floor_rect = ColorRect.new(); floor_rect.color = C_FLOOR
	floor_rect.size = Vector2(ARENA_W, ARENA_H); floor_rect.position = Vector2(-hw, -hh)
	floor_rect.z_index = -10; add_child(floor_rect)
	# Niebla decorativa
	for i in 8:
		var fog = ColorRect.new(); fog.color = Color(0.20, 0.10, 0.30, 0.15)
		fog.size = Vector2(randf_range(80, 160), randf_range(30, 60))
		fog.position = Vector2(randf_range(-hw+20, hw-160), randf_range(-hh+20, hh-60))
		fog.z_index = -6; add_child(fog)
		var tw = create_tween().set_loops()
		tw.tween_property(fog, "modulate:a", 0.3, randf_range(1.5, 3.0))
		tw.tween_property(fog, "modulate:a", 1.0, randf_range(1.5, 3.0))
	_add_wall(Vector2(0, -hh), Vector2(ARENA_W, 32)); _add_wall(Vector2(0, hh), Vector2(ARENA_W, 32))
	_add_wall(Vector2(-hw, 0), Vector2(32, ARENA_H)); _add_wall(Vector2(hw, 0), Vector2(32, ARENA_H))
	# Runas de sombra
	var runes = ["ᛞ","ᛟ","ᛚ","ᛃ","ᚦ","ᛇ","ᛈ","ᚹ"]
	for i in runes.size():
		var angle = (i / float(runes.size())) * TAU
		var rpos  = Vector2(cos(angle), sin(angle)) * 170.0
		var lbl   = Label.new(); lbl.text = runes[i]; lbl.position = rpos; lbl.z_index = 2
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", C_RUNE); add_child(lbl)
		var tw = create_tween().set_loops()
		tw.tween_property(lbl, "modulate:a", 0.1, 1.0 + i * 0.15)
		tw.tween_property(lbl, "modulate:a", 1.0, 1.0 + i * 0.15)
	var zone_lbl = Label.new()
	zone_lbl.text = "☠ %s — Lv %d" % [BOSS_NAME, BOSS_LEVEL]
	zone_lbl.position = Vector2(-100, -hh + 8); zone_lbl.z_index = 30
	zone_lbl.add_theme_font_size_override("font_size", 14)
	zone_lbl.add_theme_color_override("font_color", Color(0.7, 0.2, 1.0)); add_child(zone_lbl)

func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new(); body.position = pos
	var vis = ColorRect.new(); vis.color = C_WALL; vis.size = size
	vis.position = -size / 2; vis.z_index = -5; body.add_child(vis)
	var col := CollisionShape2D.new(); var rect := RectangleShape2D.new()
	rect.size = size; col.shape = rect; body.add_child(col); add_child(body)

func _close_door() -> void:
	var hh := ARENA_H / 2
	_door_node = ColorRect.new(); _door_node.color = C_DOOR_LOCK
	_door_node.size = Vector2(80, 32); _door_node.position = Vector2(-40, hh - 16)
	_door_node.z_index = -4; add_child(_door_node)
	_door_col = StaticBody2D.new(); _door_col.position = Vector2(0, hh)
	var col := CollisionShape2D.new(); var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 32); col.shape = rect; _door_col.add_child(col); add_child(_door_col)
	var lbl = Label.new(); lbl.text = "[ CERRADO ]"; lbl.name = "DoorLabel"
	lbl.position = Vector2(-35, hh - 45); lbl.z_index = 10
	lbl.add_theme_color_override("font_color", C_DOOR_LOCK); add_child(lbl)

func _open_door() -> void:
	if _door_node and is_instance_valid(_door_node): _door_node.color = C_DOOR_OPEN
	if _door_col  and is_instance_valid(_door_col):  _door_col.queue_free(); _door_col = null
	if has_node("DoorLabel"): get_node("DoorLabel").queue_free()

func _process(delta: float) -> void:
	if _boss_defeated or _boss_node == null or not is_instance_valid(_boss_node):
		return
	if "hp" in _boss_node and _boss_node.hp <= 0:
		return
	_mechanic_timer += delta
	if _mechanic_timer >= _mechanic_interval:
		_mechanic_timer = 0.0
		_run_random_mechanic()

func _spawn_player_at_entrance() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].global_position = Vector2(0, ARENA_H / 2 - 60)

func _spawn_boss() -> void:
	if not has_node("/root/EnemyManager"): return
	var em = get_node("/root/EnemyManager")
	if not em.has_method("spawn_enemy"): return
	_boss_node = em.spawn_enemy(BOSS_MOB_TYPE, Vector2(0, -ARENA_H / 2 + 100), BOSS_LEVEL, self)
	if _boss_node == null: return
	_boss_node.scale = Vector2(3.0, 3.0)
	if "enemy_label" in _boss_node: _boss_node.enemy_label = BOSS_NAME
	if "max_hp"     in _boss_node: _boss_node.max_hp      = BOSS_MAX_HP
	if "hp"         in _boss_node: _boss_node.hp           = BOSS_MAX_HP
	_spawn_boss_aura(_boss_node, Color(0.60, 0.05, 0.90))
	_mechanics = BossMechanics.new()
	_boss_node.add_child(_mechanics)
	_mechanics.setup(_boss_node)
	_boss_node.boss_mechanics = _mechanics
	if _boss_node.has_signal("enemy_died"):
		_boss_node.enemy_died.connect(_on_boss_defeated)
	var phase_timer = Timer.new(); phase_timer.wait_time = 1.0
	phase_timer.autostart = true; phase_timer.one_shot = false
	phase_timer.timeout.connect(_check_boss_phase); add_child(phase_timer)
	print("[BossWest] %s invocado" % BOSS_NAME)

func _check_boss_phase() -> void:
	if _boss_node == null or not is_instance_valid(_boss_node): return
	if "hp" not in _boss_node or "max_hp" not in _boss_node: return
	var pct: float = float(_boss_node.hp) / float(_boss_node.max_hp)
	var new_phase := 1
	if   pct <= 0.30: new_phase = 3
	elif pct <= 0.60: new_phase = 2
	if new_phase == _current_phase: return
	_current_phase = new_phase; _apply_phase(_current_phase)

func _apply_phase(phase: int) -> void:
	if _boss_node == null or not is_instance_valid(_boss_node): return
	match phase:
		2:
			if "speed"      in _boss_node: _boss_node.speed      = 95.0
			if "attack_dmg" in _boss_node: _boss_node.attack_dmg = 30.0
			_boss_node.scale = Vector2(3.3, 3.3)
			_spawn_boss_aura(_boss_node, Color(0.80, 0.20, 1.00))
			_show_notice("🌫 %s — FASE 2: ¡Niebla Oscura!" % BOSS_NAME, Color(0.8, 0.2, 1.0))
		3:
			if "speed"      in _boss_node: _boss_node.speed      = 130.0
			if "attack_dmg" in _boss_node: _boss_node.attack_dmg = 50.0
			_boss_node.scale = Vector2(3.6, 3.6)
			_spawn_boss_aura(_boss_node, Color(1.00, 0.05, 0.30))
			_show_notice("☠ %s — FASE 3: ¡SOMBRAS ETERNAS!" % BOSS_NAME, Color(1.0, 0.05, 0.30))
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("boss_roar")

	_mechanic_interval = 8.5 if phase == 1 else (6.0 if phase == 2 else 4.0)
	_summon_shadow_adds(phase)

# ──────────────────────────────────────────────────────────
# MECÁNICAS DE COMBATE — Shadow Lord
# ──────────────────────────────────────────────────────────

## Invoca sombras que deben ser interrumpidas/aturdidas (CC) por los DPS
## antes de que completen su canalización, o curan al boss.
func _summon_shadow_adds(phase: int) -> void:
	if _mechanics == null or not is_instance_valid(_boss_node):
		return
	var count: int = 2 if phase == 2 else 3
	_show_notice("🌑 ¡Sombras invocadas! Interrumpidlas con stuns o curarán al Lord.", Color(0.7, 0.3, 1.0))
	var adds := _mechanics.spawn_adds(_boss_node.global_position, "darkelf", count, int(BOSS_LEVEL * 0.6), 110.0)
	_adds_alive = adds
	for a in adds:
		if a.has_signal("enemy_died"):
			a.enemy_died.connect(_on_add_died.bind(a))
	get_tree().create_timer(15.0).timeout.connect(_on_adds_timeout)

func _on_add_died(_add: Node) -> void:
	_adds_alive.erase(_add)

func _on_adds_timeout() -> void:
	var alive: int = 0
	for a in _adds_alive:
		if is_instance_valid(a):
			alive += 1
	if alive > 0 and is_instance_valid(_boss_node) and "hp" in _boss_node:
		var heal_amount: int = alive * int(BOSS_MAX_HP * 0.05)
		_boss_node.hp = min(_boss_node.max_hp, _boss_node.hp + heal_amount)
		_show_notice("⚠ ¡Las sombras canalizaron y curaron al Lord! (+%d HP)" % heal_amount, Color(0.8, 0.2, 1.0))
	_adds_alive.clear()

func _run_random_mechanic() -> void:
	if _mechanics == null or not is_instance_valid(_boss_node):
		return
	match randi() % 3:
		0: _mech_void_zones()
		1: _mech_shadow_teleport_slam()
		2: _mech_darkness_field()

## MECÁNICA 1 — Zonas de vacío random; castiga quedarse quieto.
func _mech_void_zones() -> void:
	_show_notice("🌑 Grietas de vacío se abren — ¡moveos!", Color(0.7, 0.2, 1.0))
	var dmg := int(BOSS_LEVEL * 5.0 * (1.0 + (_current_phase - 1) * 0.4))
	for i in range(3):
		var ang := randf() * TAU
		var dist := randf_range(60.0, 220.0)
		var p: Vector2 = _boss_node.global_position + Vector2(cos(ang), sin(ang)) * dist
		_mechanics.telegraph_aoe(p, 80.0, dmg, 1.6, Color(0.6, 0.1, 0.9, 0.4), true)

## MECÁNICA 2 — Teletransporte detrás del jugador con más threat + golpe AoE.
## Obliga al Tank a reaccionar rápido o usar defensiva.
func _mech_shadow_teleport_slam() -> void:
	var target := _mechanics.get_top_threat_target()
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(target) or not is_instance_valid(_boss_node):
		return
	_show_notice("🌑 ¡%s se desvanece entre sombras!" % BOSS_NAME, Color(0.8, 0.2, 1.0))
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(_boss_node) or not is_instance_valid(target):
		return
	_boss_node.global_position = target.global_position + Vector2(0, -50)
	var dmg := int(BOSS_LEVEL * 7.0 * (1.0 + (_current_phase - 1) * 0.4))
	_mechanics.telegraph_aoe(_boss_node.global_position, 130.0, dmg, 1.0,
		Color(0.7, 0.1, 1.0, 0.45), false)

## MECÁNICA 3 — Campo de oscuridad: AoE grande y duradero centrado en el boss.
## Empuja al grupo a salir del rango — coordinación de Tank y Healer.
func _mech_darkness_field() -> void:
	_show_notice("🌑 Campo de Oscuridad — alejaos del jefe.", Color(0.6, 0.1, 0.9))
	var dmg := int(BOSS_LEVEL * 7.5 * (1.0 + (_current_phase - 1) * 0.45))
	_mechanics.telegraph_aoe(_boss_node.global_position, 160.0, dmg, 2.0,
		Color(0.55, 0.05, 0.85, 0.4), false)

func _show_notice(text: String, col: Color) -> void:
	var lbl = Label.new(); lbl.text = text; lbl.position = Vector2(-160, -60); lbl.z_index = 200
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", col); add_child(lbl)
	var tw = lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 50, 3.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 3.0)
	tw.finished.connect(func(): if is_instance_valid(lbl): lbl.queue_free())

func _on_boss_defeated() -> void:
	if _boss_defeated: return
	_boss_defeated = true
	# Notificar al sistema de notificaciones de boss
	if has_node("/root/BossNotifManager"):
		get_node("/root/BossNotifManager").register_boss_death("west")
	if has_node("/root/AchievementManager"):
		get_node("/root/AchievementManager").on_boss_killed("west")

	# PASO 8B — Apagar luz del boss al morir
	if is_instance_valid(_boss_node):
		var aura_light = _boss_node.get_node_or_null("BossAuraLight")
		if aura_light and is_instance_valid(aura_light):
			var tw_off := create_tween()
			tw_off.tween_property(aura_light, "energy", 0.0, 0.4)
			tw_off.tween_callback(func(): if is_instance_valid(aura_light): aura_light.queue_free())
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").stop_boss_music()
		get_node("/root/AudioManager").play_sfx("boss_death")
	if has_node("/root/InventoryManager"):
		var inv = get_node("/root/InventoryManager")
		if inv.has_method("add_item"):
			inv.add_item("crystal_shard",             randi_range(18, 28))
			inv.add_item("material_bone",              randi_range(15, 25))
			inv.add_item("weapon_bow_t3",              1)   # drop garantizado épico (Arco de Plata)
			inv.add_item("material_boss_west_essence", randi_range(1, 2))  # material épico de boss
			if randf() < 0.25:
				inv.add_item("weapon_bow_t4",          1)   # drop legendario: Arco del Vacío
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("add_experience"): gm.add_experience(6000)
	_open_door(); _activate_return_portal()

func _setup_exit_portal() -> void:
	var pg = ColorRect.new(); pg.name = "PortalGfx"; pg.color = Color(0.2, 0.1, 0.3, 0.4)
	pg.size = Vector2(60, 40); pg.position = Vector2(-30, ARENA_H / 2 - 55); pg.z_index = 5; add_child(pg)
	var lbl = Label.new(); lbl.name = "PortalLabel"; lbl.text = "[ Portal — Vence al Boss ]"
	lbl.position = Vector2(-100, ARENA_H / 2 - 80); lbl.z_index = 10
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.4, 0.6)); add_child(lbl)

func _activate_return_portal() -> void:
	if has_node("PortalGfx"): get_node("PortalGfx").color = Color(0.60, 0.10, 1.00, 0.85)
	if has_node("PortalLabel"):
		get_node("PortalLabel").text = "→ Portal al Mundo Oeste"
		get_node("PortalLabel").add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
	var portal = Area2D.new(); portal.name = "ReturnPortal"
	portal.position = Vector2(0, ARENA_H / 2 - 45)
	var col = CollisionShape2D.new(); var circ = CircleShape2D.new()
	circ.radius = 35.0; col.shape = circ; portal.add_child(col); add_child(portal)
	portal.body_entered.connect(func(body):
		if body.is_in_group("player"):
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").fade_out(0.8)
			get_tree().change_scene_to_file("res://scenes/world_west.tscn")
	)

func _spawn_boss_aura(boss: Node, col: Color) -> void:
	if not boss is Node2D:
		return
	var old_aura = boss.get_node_or_null("BossAura")
	if old_aura and is_instance_valid(old_aura): old_aura.queue_free()
	var old_light = boss.get_node_or_null("BossAuraLight")
	if old_light and is_instance_valid(old_light): old_light.queue_free()
	# PASO 8A: Partículas orbitales
	var aura := CPUParticles2D.new()
	aura.name = "BossAura"; aura.emitting = true; aura.amount = 40
	aura.lifetime = 1.4; aura.z_index = 3
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 40.0
	aura.direction = Vector2(0, -1); aura.spread = 60.0
	aura.initial_velocity_min = 18.0; aura.initial_velocity_max = 45.0
	aura.gravity = Vector2(0, -30)
	aura.scale_amount_min = 2.5; aura.scale_amount_max = 5.5
	aura.color = Color(col.r, col.g, col.b, 0.85)
	boss.add_child(aura)
	# PASO 8B: Luz pulsante
	var light := PointLight2D.new()
	light.name = "BossAuraLight"; light.color = col; light.energy = 1.0
	light.texture_scale = 4.0; light.z_index = 2
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var dist = Vector2(x - 32, y - 32).length() / 32.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - dist * dist, 0.0, 1.0)))
	light.texture = ImageTexture.create_from_image(img)
	boss.add_child(light)
	var tw := boss.create_tween().set_loops()
	tw.tween_method(func(v: float): if is_instance_valid(light): light.energy = v, 0.5, 1.5, 0.7)
	tw.tween_method(func(v: float): if is_instance_valid(light): light.energy = v, 1.5, 0.5, 0.7)

