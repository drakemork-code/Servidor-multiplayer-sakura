# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node2D

# ============================================================
# BOSS NORTH — Arena del Skeleton King
# Escena separada y exclusiva para el jefe del Norte
#
# Fases del boss:
#   Fase 1 (100% HP) — comportamiento normal
#   Fase 2 ( 60% HP) — más rápido, ataque de huesos en abanico
#   Fase 3 ( 30% HP) — modo furia, daño aumentado, aura de hielo
#
# Al morir: drop garantizado de item épico/legendario
#           + portal de regreso al mapa Norte.
# Respawn cooldown: 30 minutos (gestionado por world_north.gd)
# ============================================================

const ARENA_W: int = 640   # ~20 tiles × 32 px
const ARENA_H: int = 480   # ~15 tiles × 32 px

const BOSS_NAME     := "Skeleton King"
const BOSS_LEVEL    := 50
const BOSS_MAX_HP   := 5000
const BOSS_MOB_TYPE := "skeleton"

const MUSIC_KEY := "world_north"

# Colores temáticos
const C_FLOOR     := Color(0.18, 0.15, 0.28)
const C_WALL      := Color(0.12, 0.10, 0.20)
const C_RUNE      := Color(0.50, 0.20, 0.90)
const C_DOOR_OPEN := Color(0.30, 0.55, 0.90)
const C_DOOR_LOCK := Color(0.50, 0.15, 0.15)

var _boss_node:     Node = null
var _boss_defeated: bool = false
var _door_node:     ColorRect = null
var _door_col:      StaticBody2D = null
var _current_phase: int = 1
var _mechanics: BossMechanics = null
var _mechanic_timer: float = 0.0
var _mechanic_interval: float = 9.0   # baja según fase (más mecánicas = más difícil)
var _adds_alive: Array = []

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

# ──────────────────────────────────────────────────────────
# CONSTRUCCIÓN DE LA ARENA
# ──────────────────────────────────────────────────────────

func _draw_arena() -> void:
	# Si ya existe "Arena" colocado desde el editor, respetar y no regenerar.
	if has_node("Arena") and get_node("Arena").get_child_count() > 0:
		return
	var hw := ARENA_W / 2
	var hh := ARENA_H / 2

	# Suelo
	var floor_rect = ColorRect.new()
	floor_rect.color    = C_FLOOR
	floor_rect.size     = Vector2(ARENA_W, ARENA_H)
	floor_rect.position = Vector2(-hw, -hh)
	floor_rect.z_index  = -10
	add_child(floor_rect)

	# Muros (Norte, Sur, Este, Oeste como StaticBody2D)
	_add_wall(Vector2(0, -hh),  Vector2(ARENA_W, 32))  # Norte
	_add_wall(Vector2(0,  hh),  Vector2(ARENA_W, 32))  # Sur
	_add_wall(Vector2(-hw, 0),  Vector2(32, ARENA_H))  # Oeste
	_add_wall(Vector2( hw, 0),  Vector2(32, ARENA_H))  # Este

	# Decoración: runas en el suelo
	var runes = ["ᚱ","ᚢ","ᚾ","ᚨ","ᛋ","ᛏ","ᛖ","ᚦ"]
	for i in runes.size():
		var angle = (i / float(runes.size())) * TAU
		var rpos  = Vector2(cos(angle), sin(angle)) * 160.0
		var lbl   = Label.new()
		lbl.text     = runes[i]
		lbl.position = rpos
		lbl.z_index  = 2
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", C_RUNE)
		add_child(lbl)
		var tw = create_tween().set_loops()
		tw.tween_property(lbl, "modulate:a", 0.2, 1.4 + i * 0.10)
		tw.tween_property(lbl, "modulate:a", 1.0, 1.4 + i * 0.10)

	# Altar central del boss
	var altar = ColorRect.new()
	altar.color    = Color(0.10, 0.07, 0.20)
	altar.size     = Vector2(80, 60)
	altar.position = Vector2(-40, -hh + 70)
	altar.z_index  = -2
	add_child(altar)

	# Label de zona
	var zone_lbl = Label.new()
	zone_lbl.text     = "☠ %s — Lv %d" % [BOSS_NAME, BOSS_LEVEL]
	zone_lbl.position = Vector2(-110, -hh + 8)
	zone_lbl.z_index  = 30
	zone_lbl.add_theme_font_size_override("font_size", 14)
	zone_lbl.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	add_child(zone_lbl)

func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var vis = ColorRect.new()
	vis.color    = C_WALL
	vis.size     = size
	vis.position = -size / 2
	vis.z_index  = -5
	body.add_child(vis)
	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape  = rect
	body.add_child(col)
	add_child(body)

# ──────────────────────────────────────────────────────────
# PUERTA QUE SE CIERRA AL ENTRAR
# ──────────────────────────────────────────────────────────

func _close_door() -> void:
	var hh := ARENA_H / 2

	# Visual de la puerta cerrada (Sur)
	_door_node = ColorRect.new()
	_door_node.color    = C_DOOR_LOCK
	_door_node.size     = Vector2(80, 32)
	_door_node.position = Vector2(-40, hh - 16)
	_door_node.z_index  = -4
	add_child(_door_node)

	# Colisión de la puerta
	_door_col = StaticBody2D.new()
	_door_col.position = Vector2(0, hh)
	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 32)
	col.shape  = rect
	_door_col.add_child(col)
	add_child(_door_col)

	var lbl = Label.new()
	lbl.text     = "[ CERRADO ]"
	lbl.position = Vector2(-35, hh - 45)
	lbl.z_index  = 10
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_DOOR_LOCK)
	lbl.name     = "DoorLabel"
	add_child(lbl)

func _open_door() -> void:
	if _door_node and is_instance_valid(_door_node):
		_door_node.color = C_DOOR_OPEN
	if _door_col and is_instance_valid(_door_col):
		_door_col.queue_free()
		_door_col = null
	if has_node("DoorLabel"):
		get_node("DoorLabel").queue_free()

# ──────────────────────────────────────────────────────────
# JUGADOR
# ──────────────────────────────────────────────────────────

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
		if has_node("/root/GameManager") and get_node("/root/GameManager").player_spawn_override:
			players[0].global_position = get_node("/root/GameManager").consume_spawn_override()
		else:
			players[0].global_position = Vector2(0, ARENA_H / 2 - 60)

# ──────────────────────────────────────────────────────────
# SPAWN DEL BOSS CON 3 FASES
# ──────────────────────────────────────────────────────────

func _spawn_boss() -> void:
	if not has_node("/root/EnemyManager"):
		return
	var em = get_node("/root/EnemyManager")
	if not em.has_method("spawn_enemy"):
		return

	_boss_node = em.spawn_enemy(BOSS_MOB_TYPE, Vector2(0, -ARENA_H / 2 + 100), BOSS_LEVEL, self)
	if _boss_node == null:
		return

	# Escalar el boss
	_boss_node.scale = Vector2(3.0, 3.0)

	# Aplicar estadísticas de boss
	if "enemy_label" in _boss_node: _boss_node.enemy_label = BOSS_NAME
	if "max_hp"     in _boss_node: _boss_node.max_hp      = BOSS_MAX_HP
	if "hp"         in _boss_node: _boss_node.hp           = BOSS_MAX_HP

	# Aura de hielo
	_spawn_boss_aura(_boss_node, Color(0.55, 0.80, 0.95))

	# ── Mecánicas de raid: threat list + AoE telegrafiado ──
	_mechanics = BossMechanics.new()
	_boss_node.add_child(_mechanics)
	_mechanics.setup(_boss_node)
	_boss_node.boss_mechanics = _mechanics

	# Conectar señal de muerte
	if _boss_node.has_signal("enemy_died"):
		_boss_node.enemy_died.connect(_on_boss_defeated)

	# Sistema de fases: monitorear HP cada segundo
	var phase_timer = Timer.new()
	phase_timer.wait_time  = 1.0
	phase_timer.autostart  = true
	phase_timer.one_shot   = false
	phase_timer.timeout.connect(_check_boss_phase)
	add_child(phase_timer)

	print("[BossNorth] %s invocado — %d HP / 3 fases" % [BOSS_NAME, BOSS_MAX_HP])

func _check_boss_phase() -> void:
	if _boss_node == null or not is_instance_valid(_boss_node):
		return
	if "hp" not in _boss_node or "max_hp" not in _boss_node:
		return

	var pct: float = float(_boss_node.hp) / float(_boss_node.max_hp)
	var new_phase := 1
	if   pct <= 0.30: new_phase = 3
	elif pct <= 0.60: new_phase = 2

	if new_phase == _current_phase:
		return

	_current_phase = new_phase
	_apply_phase(_current_phase)

func _apply_phase(phase: int) -> void:
	if _boss_node == null or not is_instance_valid(_boss_node):
		return

	match phase:
		2:
			# Fase 2: más rápido, nuevo ataque
			if "speed"       in _boss_node: _boss_node.speed       = (_boss_node.get("speed") if _boss_node.get("speed") else 80) * 1.4
			if "attack_dmg"  in _boss_node: _boss_node.attack_dmg  = (_boss_node.get("attack_dmg") if _boss_node.get("attack_dmg") else 20) * 1.2
			_boss_node.scale = Vector2(3.3, 3.3)
			_spawn_boss_aura(_boss_node, Color(0.90, 0.60, 0.10))
			_show_phase_notice("⚡ %s — FASE 2: ¡Más rápido!" % BOSS_NAME, Color(1.0, 0.7, 0.1))

		3:
			# Fase 3: modo furia
			if "speed"       in _boss_node: _boss_node.speed       = (_boss_node.get("speed") if _boss_node.get("speed") else 80) * 1.8
			if "attack_dmg"  in _boss_node: _boss_node.attack_dmg  = (_boss_node.get("attack_dmg") if _boss_node.get("attack_dmg") else 20) * 1.6
			_boss_node.scale = Vector2(3.6, 3.6)
			_spawn_boss_aura(_boss_node, Color(1.0, 0.10, 0.10))
			_show_phase_notice("☠ %s — FASE 3: ¡MODO FURIA!" % BOSS_NAME, Color(1.0, 0.1, 0.1))
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("boss_roar")

	# Mecánicas más frecuentes y letales a medida que baja de fase
	_mechanic_interval = 9.0 if phase == 1 else (6.5 if phase == 2 else 4.5)
	_summon_skeleton_minions(phase)

# ──────────────────────────────────────────────────────────
# MECÁNICAS DE COMBATE — Skeleton King
# ──────────────────────────────────────────────────────────

## Invoca esqueletos menores que deben morir rápido (DPS) o curan
## al boss si sobreviven demasiado tiempo.
func _summon_skeleton_minions(phase: int) -> void:
	if _mechanics == null or not is_instance_valid(_boss_node):
		return
	var count: int = 2 if phase == 2 else 4
	_show_phase_notice("💀 ¡Esqueletos menores invocados! Destrúyelos antes de que curen al Rey.", Color(0.7, 0.85, 1.0))
	var adds := _mechanics.spawn_adds(_boss_node.global_position, "skeleton", count, int(BOSS_LEVEL * 0.6), 110.0)
	_adds_alive = adds
	for a in adds:
		if a.has_signal("enemy_died"):
			a.enemy_died.connect(_on_minion_died.bind(a))
	# Si los adds no mueren en 18s, curan al boss y desaparecen (castiga ignorarlos)
	get_tree().create_timer(18.0).timeout.connect(_on_minions_timeout)

func _on_minion_died(_add: Node) -> void:
	_adds_alive.erase(_add)

func _on_minions_timeout() -> void:
	var alive: int = 0
	for a in _adds_alive:
		if is_instance_valid(a):
			alive += 1
	if alive > 0 and is_instance_valid(_boss_node) and "hp" in _boss_node:
		var heal_amount: int = alive * int(BOSS_MAX_HP * 0.04)
		_boss_node.hp = min(_boss_node.max_hp, _boss_node.hp + heal_amount)
		_show_phase_notice("⚠ ¡Los esqueletos curaron al Rey! (+%d HP)" % heal_amount, Color(1.0, 0.3, 0.3))
	_adds_alive.clear()

## Elige una mecánica al azar según la fase actual.
func _run_random_mechanic() -> void:
	if _mechanics == null or not is_instance_valid(_boss_node):
		return
	var roll := randi() % 3
	match roll:
		0: _mech_frost_nova()
		1: _mech_ice_spikes_line()
		2: _mech_frozen_ground()

## MECÁNICA 1 — Frost Nova: AoE grande centrado en el boss.
## Obliga al grupo a separarse del Tank temporalmente o curarse fuerte.
func _mech_frost_nova() -> void:
	_show_phase_notice("❄ %s prepara Nova de Escarcha — ¡Alejaos!" % BOSS_NAME, Color(0.6, 0.85, 1.0))
	var dmg := int(BOSS_LEVEL * 6 * (1.0 + (_current_phase - 1) * 0.4))
	_mechanics.telegraph_aoe(_boss_node.global_position, 150.0, dmg, 1.8,
		Color(0.5, 0.8, 1.0, 0.4), false)

## MECÁNICA 2 — Línea de picos de hielo hacia el jugador con más threat (Tank).
## El Tank debe reposicionar al boss para no dejar la línea sobre el grupo.
func _mech_ice_spikes_line() -> void:
	var target := _mechanics.get_top_threat_target()
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(target):
		return
	_show_phase_notice("❄ ¡Picos de Hielo en línea! Esquiva el camino.", Color(0.7, 0.9, 1.0))
	var dir: Vector2 = (target.global_position - _boss_node.global_position).normalized()
	var steps := 4
	for i in range(steps):
		var p: Vector2 = _boss_node.global_position + dir * (90.0 * (i + 1))
		var dmg := int(BOSS_LEVEL * 5 * (1.0 + (_current_phase - 1) * 0.35))
		_mechanics.telegraph_aoe(p, 70.0, dmg, 1.2 + i * 0.15, Color(0.6, 0.85, 1.0, 0.4), true)

## MECÁNICA 3 — Suelo congelado: 3 zonas aleatorias que castigan quedarse quieto.
func _mech_frozen_ground() -> void:
	_show_phase_notice("❄ El suelo se congela — ¡no te quedes quieto!", Color(0.6, 0.8, 1.0))
	var dmg := int(BOSS_LEVEL * 4.5 * (1.0 + (_current_phase - 1) * 0.4))
	for i in range(3):
		var ang := randf() * TAU
		var dist := randf_range(60.0, 220.0)
		var p: Vector2 = _boss_node.global_position + Vector2(cos(ang), sin(ang)) * dist
		_mechanics.telegraph_aoe(p, 85.0, dmg, 1.6, Color(0.55, 0.8, 1.0, 0.35), true)

func _show_phase_notice(text: String, col: Color) -> void:
	var lbl = Label.new()
	lbl.text     = text
	lbl.position = Vector2(-160, -60)
	lbl.z_index  = 200
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", col)
	add_child(lbl)
	var tw = lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 50, 3.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 3.0)
	tw.finished.connect(func(): if is_instance_valid(lbl): lbl.queue_free())

# ──────────────────────────────────────────────────────────
# MUERTE DEL BOSS
# ──────────────────────────────────────────────────────────

func _on_boss_defeated() -> void:
	if _boss_defeated:
		return
	_boss_defeated = true
	print("[BossNorth] %s derrotado — drop garantizado!" % BOSS_NAME)
	# Notificar al sistema de notificaciones de boss
	if has_node("/root/BossNotifManager"):
		get_node("/root/BossNotifManager").register_boss_death("north")
	# Logro de boss
	if has_node("/root/AchievementManager"):
		get_node("/root/AchievementManager").on_boss_killed("north")
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

	# Drop garantizado épico/legendario
	if has_node("/root/InventoryManager"):
		var inv = get_node("/root/InventoryManager")
		if inv.has_method("add_item"):
			inv.add_item("crystal_shard",             randi_range(15, 25))
			inv.add_item("material_bone",              randi_range(12, 20))
			inv.add_item("weapon_mace_t3",             1)    # drop T3 garantizado (Maza de Hueso Sagrado)
			inv.add_item("armor_shadow_chest",         1)    # drop de armadura épica
			inv.add_item("material_boss_north_essence", randi_range(1, 2))  # material épico de boss
			# 20-30% de probabilidad de drop legendario adicional
			if randf() < 0.25:
				inv.add_item("weapon_necronomicon_t3", 1)    # Necronomicón Ancestral (T3)

	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("add_experience"):
			gm.add_experience(5000)

	# Abrir la puerta y activar el portal de regreso
	_open_door()
	_activate_return_portal()

	# Notificar respawn con 30 min de cooldown (manejado por world_north.gd)
	_show_phase_notice("★ ¡%s derrotado! Portal abierto." % BOSS_NAME, Color.GOLD)

# ──────────────────────────────────────────────────────────
# PORTAL DE REGRESO
# ──────────────────────────────────────────────────────────

func _setup_exit_portal() -> void:
	# Portal siempre visible al Sur (desactivado hasta vencer al boss)
	var portal_gfx = ColorRect.new()
	portal_gfx.name     = "PortalGfx"
	portal_gfx.color    = Color(0.2, 0.2, 0.3, 0.4)
	portal_gfx.size     = Vector2(60, 40)
	portal_gfx.position = Vector2(-30, ARENA_H / 2 - 55)
	portal_gfx.z_index  = 5
	add_child(portal_gfx)

	var portal_lbl = Label.new()
	portal_lbl.name     = "PortalLabel"
	portal_lbl.text     = "[ Portal — Vence al Boss ]"
	portal_lbl.position = Vector2(-100, ARENA_H / 2 - 80)
	portal_lbl.z_index  = 10
	portal_lbl.add_theme_font_size_override("font_size", 11)
	portal_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	add_child(portal_lbl)

func _activate_return_portal() -> void:
	if has_node("PortalGfx"):
		get_node("PortalGfx").color = Color(0.30, 0.60, 1.0, 0.85)
	if has_node("PortalLabel"):
		get_node("PortalLabel").text = "→ Portal al Mundo Norte"
		get_node("PortalLabel").add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		var tw = create_tween().set_loops()
		tw.tween_property(get_node("PortalLabel"), "modulate:a", 0.3, 0.8)
		tw.tween_property(get_node("PortalLabel"), "modulate:a", 1.0, 0.8)

	var portal = Area2D.new()
	portal.name = "ReturnPortal"
	portal.position = Vector2(0, ARENA_H / 2 - 45)
	var col = CollisionShape2D.new()
	var circ = CircleShape2D.new()
	circ.radius = 35.0
	col.shape   = circ
	portal.add_child(col)
	add_child(portal)
	portal.body_entered.connect(func(body):
		if body.is_in_group("player"):
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").fade_out(0.8)
			get_tree().change_scene_to_file("res://scenes/world_north.tscn")
	)

# ──────────────────────────────────────────────────────────
# AURA DE PARTÍCULAS
# ──────────────────────────────────────────────────────────

func _spawn_boss_aura(boss: Node, col: Color) -> void:
	if not boss is Node2D:
		return

	# ── Limpiar aura anterior si existe ──
	var old_aura = boss.get_node_or_null("BossAura")
	if old_aura and is_instance_valid(old_aura):
		old_aura.queue_free()
	var old_light = boss.get_node_or_null("BossAuraLight")
	if old_light and is_instance_valid(old_light):
		old_light.queue_free()

	# ── PASO 8A: Partículas orbitales (CPUParticles2D) ──
	var aura := CPUParticles2D.new()
	aura.name               = "BossAura"
	aura.emitting           = true
	aura.amount             = 40
	aura.lifetime           = 1.4
	aura.z_index            = 3
	aura.emission_shape     = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 40.0
	aura.direction          = Vector2(0, -1)
	aura.spread             = 60.0
	aura.initial_velocity_min = 18.0
	aura.initial_velocity_max = 45.0
	aura.gravity            = Vector2(0, -30)   # gravedad negativa → suben
	aura.scale_amount_min   = 2.5
	aura.scale_amount_max   = 5.5
	aura.color              = Color(col.r, col.g, col.b, 0.85)
	boss.add_child(aura)

	# ── PASO 8B: Luz pulsante ──
	var light := PointLight2D.new()
	light.name         = "BossAuraLight"
	light.color        = col
	light.energy       = 1.0
	light.texture_scale = 4.0
	light.z_index      = 2
	# Textura de luz radial generada en código
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var dist = Vector2(x - 32, y - 32).length() / 32.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - dist * dist, 0.0, 1.0)))
	light.texture = ImageTexture.create_from_image(img)
	boss.add_child(light)

	# Animar energy con sin(TIME) desde _process — lo hacemos con un Tween infinito
	# usando tween_method que cicla entre 0.5 y 1.5
	var tw := boss.create_tween().set_loops()
	tw.tween_method(func(v: float):
		if is_instance_valid(light):
			light.energy = v
	, 0.5, 1.5, 0.7)
	tw.tween_method(func(v: float):
		if is_instance_valid(light):
			light.energy = v
	, 1.5, 0.5, 0.7)

