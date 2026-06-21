# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

class_name Player
extends CharacterBody2D

## Offset del nombre del jugador sobre el sprite (ajustable en Inspector)
@export var name_label_offset: Vector2 = Vector2(-30, -82)

# ============================================================
# PLAYER — CharacterBody2D
# Movimiento WASD, dodge, ataque, interacción, cámara, efectos
# FIX: hechizos lanzables en movimiento
# FIX: facing_dir siempre apunta hacia el cursor del mouse
# ============================================================

@onready var sprite: Sprite2D             = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D             = $Camera2D
@onready var name_label: Label            = $NameLabel
@onready var hp_bar: ProgressBar          = $HPBar
@onready var collision: CollisionShape2D  = $CollisionShape2D
@onready var interaction_area: Area2D     = $InteractionArea

# Estado
var can_move: bool    = true
var is_attacking: bool = false
var attack_cooldown_timer: float = 0.0
const ATTACK_COOLDOWN: float = 0.45

# Dodge
const DODGE_DURATION: float  = 0.34
const DODGE_COOLDOWN: float  = 1.5
var dodge_timer: float       = 0.0

# Interacción
var nearby_npcs: Array         = []
var nearby_interactables: Array = []

# Efectos
var damage_flash_timer: float  = 0.0
var screen_flash: ColorRect    = null
# BUG C FIX: CanvasLayer propio para el flash de daño — se limpia solo cuando el jugador se libera
var _flash_canvas: CanvasLayer = null

# Dirección para flip y ataque
var facing_right: bool = true
var facing_dir: Vector2 = Vector2.RIGHT

# PASO 7 — Polvo de pisada
var _step_timer: float = 0.0
const _STEP_INTERVAL: float = 0.22  # emitir polvo cada N segundos al caminar

# ── Aimbot — apuntado automático al enemigo más cercano ──────
## Radio máximo en px para el aimbot (0 = desactivado)
const AIMBOT_RANGE: float     = 200.0
## Si hay movimiento, el aimbot solo actúa cuando el cursor está lejos del jugador
const AIMBOT_DEADZONE: float  = 60.0
var _aimbot_target: Node      = null

const HAIR_STYLES := ["bowlhair", "curlyhair", "longhair", "mophair", "shorthair", "spikeyhair"]
const PLAYER_BASE_PATH := "res://assets/characters/player/"

func _get_anim_path(anim_name: String) -> String:
	var hair := PlayerData.hair_style if PlayerData.hair_style in HAIR_STYLES else "spikeyhair"
	var counts := {"idle": 9, "walk": 8, "run": 8, "attack": 10}
	var count: int = counts.get(anim_name, 9)
	return PLAYER_BASE_PATH + "player_%s_%s_strip%d.png" % [hair, anim_name, count]

# ── Animación Sunnyside sprites ──────────────────────────────
const HUMAN_ANIMS := {
	"idle":   {"path": "res://assets/characters/player/player_idle_strip9.png",   "frames": 9},
	"walk":   {"path": "res://assets/characters/player/player_walk_strip8.png",   "frames": 8},
	"run":    {"path": "res://assets/characters/player/player_run_strip8.png",    "frames": 8},
	"attack": {"path": "res://assets/characters/player/player_attack_strip10.png","frames": 10},
}
var _anim_current: String = "idle"
var _anim_frame: int = 0
var _anim_frame_timer: float = 0.0
const ANIM_FPS: float = 9.0

func _ready() -> void:
	add_to_group("player")
	GameManager.register_player(self)
	_load_anim_texture("idle")
	WeaponSkillSystem.register_player(self)
	# BUG C FIX: CanvasLayer hijo del jugador → se limpia automáticamente al liberar el nodo
	_flash_canvas = CanvasLayer.new()
	_flash_canvas.layer = 100
	add_child(_flash_canvas)
	_setup_character()

	# PASO 15 — Sombra elíptica proyectada bajo el personaje
	var shadow := Sprite2D.new()
	shadow.name    = "BodyShadow"
	shadow.z_index = -1
	shadow.position = Vector2(0.0, 10.0)
	# Generar textura oval en código
	var img := Image.create(32, 12, false, Image.FORMAT_RGBA8)
	var cx := 16.0; var cy := 6.0; var rx := 13.0; var ry := 5.0
	for px in range(32):
		for py in range(12):
			var dx := (px - cx) / rx; var dy := (py - cy) / ry
			var dist := dx * dx + dy * dy
			if dist <= 1.0:
				var alpha := int((1.0 - dist) * 120)   # 0..120, centro más opaco
				img.set_pixel(px, py, Color(0, 0, 0, alpha / 255.0))
	var tex := ImageTexture.create_from_image(img)
	shadow.texture = tex
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.3)
	add_child(shadow)
	move_child(shadow, 0)   # detrás de todo
	set_meta("_body_shadow", shadow)

	hp_bar.max_value = PlayerData.max_hp
	hp_bar.value     = PlayerData.hp
	
	PlayerData.health_changed.connect(_on_health_changed)
	PlayerData.level_up.connect(_on_level_up)
	PlayerData.player_respawned.connect(_on_respawned)
	
	if GameManager.player_spawn_override:
		global_position = GameManager.consume_spawn_override()

func _load_anim_texture(anim_name: String) -> void:
	if not sprite:
		return
	if not anim_name in HUMAN_ANIMS:
		anim_name = "idle"
	var dynamic_path := _get_anim_path(anim_name)
	var data: Dictionary = HUMAN_ANIMS[anim_name]
	var tex_path: String = dynamic_path if ResourceLoader.exists(dynamic_path) else data["path"]
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
		sprite.hframes = data["frames"]
		sprite.vframes = 1
		sprite.frame = 0
	if not (sprite.material is ShaderMaterial):
		var mat := ShaderMaterial.new()
		var shader_path := "res://scripts/character_swap.gdshader"
		if ResourceLoader.exists(shader_path):
			mat.shader = load(shader_path)
			sprite.material = mat
	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("skin_color", PlayerData.skin_color)
		sprite.material.set_shader_parameter("hair_color", PlayerData.hair_color)
		sprite.material.set_shader_parameter("eye_color",  PlayerData.eye_color)
		sprite.modulate = Color.WHITE
		# ── Hit flash: next_pass encadenado al character_swap ──
		if sprite.material.next_pass == null:
			var flash_mat := ShaderMaterial.new()
			var flash_path := "res://scripts/hit_flash.gdshader"
			if ResourceLoader.exists(flash_path):
				flash_mat.shader = load(flash_path)
				flash_mat.set_shader_parameter("flash_amount", 0.0)
				sprite.material.next_pass = flash_mat
	else:
		sprite.modulate = PlayerData.skin_color

func _update_player_anim(anim_name: String) -> void:
	if _anim_current == anim_name:
		return
	_anim_current = anim_name
	_anim_frame = 0
	_anim_frame_timer = 0.0
	_load_anim_texture(anim_name)

func _tick_player_anim(delta: float) -> void:
	if not sprite or not sprite.texture:
		return
	_anim_frame_timer += delta
	var frame_dur := 1.0 / ANIM_FPS
	if _anim_frame_timer >= frame_dur:
		_anim_frame_timer -= frame_dur
		var anim_name := _anim_current if _anim_current in HUMAN_ANIMS else "idle"
		var total_frames: int = HUMAN_ANIMS[anim_name]["frames"]
		_anim_frame = (_anim_frame + 1) % total_frames
		sprite.frame = _anim_frame

func _setup_character() -> void:
	if name_label:
		name_label.text = PlayerData.character_name
		name_label.position = name_label_offset
	
	if PlayerData.is_drake_dev and name_label:
		name_label.add_theme_color_override("font_color", Color.GOLD)
		_spawn_drake_aura()

func _spawn_drake_aura() -> void:
	var particles = CPUParticles2D.new()
	add_child(particles)
	particles.position       = Vector2.ZERO
	particles.emitting       = true
	particles.amount         = 20
	particles.lifetime       = 1.0
	particles.color          = Color.GOLD
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.8
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 12.0

# ──────────────────────────────────────────────
# PROCESO PRINCIPAL
# ──────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	_tick_player_anim(delta)
	if PlayerData.is_dead:
		velocity = Vector2.ZERO
		return
	
	PlayerData.regenerate_energy(delta)
	
	if PlayerData.dodge_cooldown_remaining > 0:
		PlayerData.dodge_cooldown_remaining -= delta
	
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	
	if PlayerData.is_dodging:
		dodge_timer += delta
		if dodge_timer >= DODGE_DURATION:
			PlayerData.is_dodging = false
			dodge_timer = 0.0
	
	# damage_flash_timer se conserva como fallback si el shader no cargó
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		if damage_flash_timer <= 0 and sprite:
			sprite.modulate = Color.WHITE
	
	# FIX: actualizar facing_dir con el mouse SIEMPRE (permite girar sin moverse
	# y lanzar hechizos en cualquier dirección durante el movimiento)
	_update_facing_from_mouse()

	if can_move:
		_handle_movement(delta)
	else:
		velocity = Vector2.ZERO
	
	_handle_input()
	move_and_slide()

	z_index = int((global_position.y + 2000.0) / 8.0)

	# PASO 15 — animar sombra según velocidad (da sensación de peso)
	var _shadow_node = get_meta("_body_shadow", null)
	if _shadow_node and is_instance_valid(_shadow_node):
		var spd_norm := clampf(velocity.length() / float(PlayerData.speed), 0.0, 1.0)
		_shadow_node.scale = Vector2(1.0 + spd_norm * 0.18, 1.0 - spd_norm * 0.12)

	_check_scene_borders()

# Calcula facing_dir y flip del sprite.
# FIX MOBILE v20: en pantalla táctil usa joystick del GameUI en lugar del mouse.
# Prioridad: movimiento horizontal (joystick/tecla) > aimbot > joystick idle > mouse (solo PC).
func _update_facing_from_mouse() -> void:
	var move_x: float = 0.0
	if Input.is_action_pressed("move_left"):  move_x -= 1.0
	if Input.is_action_pressed("move_right"): move_x += 1.0

	if move_x != 0.0:
		# Hay movimiento horizontal — el flip sigue la acción inyectada (joystick o tecla)
		facing_right = move_x > 0.0
		if sprite: sprite.flip_h = not facing_right
		facing_dir = Vector2(move_x, 0.0).normalized()
		# En touch, también actualizar facing_dir con componente Y del joystick
		if DisplayServer.is_touchscreen_available():
			var ui_node: Node = _get_game_ui()
			if ui_node:
				var joy_dir2: Vector2 = ui_node.get("_joystick_direction") as Vector2
				if joy_dir2.length() > 0.15:
					facing_dir = joy_dir2.normalized()
					facing_right = facing_dir.x >= 0.0
					if sprite: sprite.flip_h = not facing_right
	else:
		# Sin movimiento horizontal: aimbot > joystick (touch) > mouse (PC)
		var aimbot_dir := _get_aimbot_direction()
		if aimbot_dir != Vector2.ZERO:
			facing_dir = aimbot_dir
			if abs(facing_dir.x) > 0.2:
				facing_right = facing_dir.x > 0.0
				if sprite: sprite.flip_h = not facing_right
		elif DisplayServer.is_touchscreen_available():
			# TOUCH: usar dirección del joystick virtual como fuente de facing
			var ui_node: Node = _get_game_ui()
			if ui_node:
				var joy_dir: Vector2 = ui_node.get("_joystick_direction") as Vector2
				if joy_dir.length() > 0.15:
					facing_dir = joy_dir.normalized()
					if abs(facing_dir.x) > 0.2:
						facing_right = facing_dir.x > 0.0
						if sprite: sprite.flip_h = not facing_right
				# else: mantener facing_dir anterior (no resetear a (0,0) en touch)
		else:
			# PC: usar posición del mouse
			var mouse_world: Vector2 = get_global_mouse_position()
			var to_mouse: Vector2 = mouse_world - global_position
			if to_mouse.length() > 12.0:
				facing_dir = to_mouse.normalized()
				if abs(facing_dir.x) > 0.3:
					facing_right = facing_dir.x > 0.0
					if sprite: sprite.flip_h = not facing_right

## Helper: obtiene el nodo GameUI desde el grupo "ui"
func _get_game_ui() -> Node:
	var nodes := get_tree().get_nodes_in_group("ui")
	if nodes.size() > 0: return nodes[0]
	return null

## Devuelve la dirección normalizada al enemigo más cercano en rango,
## o Vector2.ZERO si no hay ninguno. Usado por el aimbot.
func _get_aimbot_direction() -> Vector2:
	if AIMBOT_RANGE <= 0.0:
		return Vector2.ZERO
	var enemies := get_tree().get_nodes_in_group("enemy")
	var best_dist := AIMBOT_RANGE
	var best_dir  := Vector2.ZERO
	_aimbot_target = null
	for e in enemies:
		if not is_instance_valid(e): continue
		# No apuntar a enemigos muertos
		if e.has_method("get") and e.get("state") == 7: continue   # State.DEAD = 7
		var dist := global_position.distance_to(e.global_position)
		if dist < best_dist:
			best_dist = dist
			best_dir  = (e.global_position - global_position).normalized()
			_aimbot_target = e
	return best_dir

func _handle_movement(_delta: float) -> void:
	var input_vec = Vector2.ZERO
	
	if Input.is_action_pressed("move_up"):    input_vec.y -= 1
	if Input.is_action_pressed("move_down"):  input_vec.y += 1
	if Input.is_action_pressed("move_left"):  input_vec.x -= 1
	if Input.is_action_pressed("move_right"): input_vec.x += 1
	
	input_vec = input_vec.normalized()
	
	var current_speed = float(PlayerData.speed)
	if PlayerData.is_dodging:
		current_speed *= 2.5
	
	velocity = input_vec * current_speed
	
	# Animaciones (el flip lo maneja _update_facing_from_mouse)
	_update_animation(input_vec)

	# PASO 7 — Polvo de pisada según superficie
	if input_vec.length() > 0.1 and not PlayerData.is_dodging:
		_step_timer -= _delta
		if _step_timer <= 0.0:
			_step_timer = _STEP_INTERVAL
			_spawn_footstep_dust()

func _spawn_footstep_dust() -> void:
	# Detectar tile debajo del jugador via Raycast2D temporal
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0, 12), 1)
	var result = space.intersect_ray(query)

	# Color según el tile: grass→verde, stone→gris, snow→blanco, default→beige
	var tile_name := ""
	if result.has("collider"):
		var col = result["collider"]
		if col and col.get_parent() and col.get_parent().name:
			tile_name = col.get_parent().name.to_lower()
	# Fallback: usar el nombre de la escena actual
	if tile_name == "":
		var sname = get_tree().current_scene.name.to_lower()
		if "north" in sname or "snow" in sname:
			tile_name = "snow"
		elif "dungeon" in sname or "stone" in sname:
			tile_name = "stone"

	var dust_color: Color
	if "snow" in tile_name:
		dust_color = Color(0.95, 0.97, 1.0, 0.7)
	elif "stone" in tile_name or "dungeon" in tile_name:
		dust_color = Color(0.65, 0.62, 0.60, 0.65)
	else:
		dust_color = Color(0.55, 0.75, 0.35, 0.60)  # grass por defecto

	var dust := CPUParticles2D.new()
	dust.emitting             = true
	dust.one_shot             = true
	dust.amount               = 4
	dust.lifetime             = 0.28
	dust.explosiveness        = 0.8
	dust.direction            = Vector2(0, 1)
	dust.spread               = 50.0
	dust.initial_velocity_min = 10.0
	dust.initial_velocity_max = 25.0
	dust.gravity              = Vector2(0, 18)
	dust.scale_amount_min     = 2.0
	dust.scale_amount_max     = 4.5
	dust.color                = dust_color
	dust.z_index              = z_index - 1
	dust.position             = global_position + Vector2(0, 6)
	get_tree().current_scene.add_child(dust)
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(dust):
		dust.queue_free()

func _update_animation(input_vec: Vector2) -> void:
	# No sobreescribir la animación de ataque mientras dure
	if is_attacking:
		return
	if input_vec.length() > 0.1:
		_update_player_anim("walk")
	else:
		_update_player_anim("idle")
	if not animation_player:
		return
	if input_vec != Vector2.ZERO:
		if animation_player.has_animation("walk"):
			if animation_player.current_animation != "walk":
				animation_player.play("walk")
	else:
		if animation_player.has_animation("idle"):
			if animation_player.current_animation != "idle":
				animation_player.play("idle")

func _handle_input() -> void:
	if Input.is_action_just_pressed("dodge"):
		_perform_dodge()
	if Input.is_action_just_pressed("attack") and not is_attacking and attack_cooldown_timer <= 0:
		_perform_attack()
	if Input.is_action_just_pressed("inventory"):
		_toggle_inventory()
	if Input.is_action_just_pressed("interact"):
		_interact_with_nearby()
	# ── Habilidades de arma (Q / E / R) — FIX: se pueden lanzar en movimiento ─
	# can_move no bloquea habilidades; la dirección viene del mouse via facing_dir
	if Input.is_action_just_pressed("skill_q"):
		WeaponSkillSystem.use_skill(0)
	if Input.is_action_just_pressed("skill_e"):
		WeaponSkillSystem.use_skill(1)
	if Input.is_action_just_pressed("skill_r"):
		WeaponSkillSystem.use_skill(2)

# ──────────────────────────────────────────────
# ACCIONES
# ──────────────────────────────────────────────

func _perform_dodge() -> void:
	if PlayerData.is_dodging or PlayerData.dodge_cooldown_remaining > 0:
		return
	if not PlayerData.use_energy(15):
		show_floating_text("Sin energía!", Color.ORANGE)
		return
	
	PlayerData.is_dodging = true
	PlayerData.dodge_cooldown_remaining = DODGE_COOLDOWN
	dodge_timer = 0.0
	if sprite:
		sprite.modulate.a = 0.45
		var roll_tween = create_tween()
		var roll_dir := 1.0 if facing_right else -1.0
		roll_tween.tween_property(sprite, "rotation_degrees", roll_dir * 360.0, DODGE_DURATION)
		roll_tween.tween_callback(func():
			if is_instance_valid(sprite):
				sprite.rotation_degrees = 0.0
				sprite.modulate.a = 1.0
		)
	_spawn_roll_ghost()
	_spawn_dodge_trail()

func _spawn_dodge_trail() -> void:
	# PASO 5 — Trail de dodge: partículas en dirección contraria al movimiento
	var trail := CPUParticles2D.new()
	trail.emitting          = true
	trail.one_shot          = true
	trail.amount            = 12
	trail.lifetime          = 0.3
	trail.explosiveness     = 0.9
	trail.direction         = Vector2(-velocity.normalized().x, -velocity.normalized().y) \
	                          if velocity.length() > 1.0 else Vector2(0, 1)
	trail.spread            = 35.0
	trail.initial_velocity_min = 30.0
	trail.initial_velocity_max = 70.0
	trail.scale_amount_min  = 3.0
	trail.scale_amount_max  = 6.0
	trail.color             = Color(1.0, 1.0, 1.0, 0.55)
	trail.gravity           = Vector2.ZERO
	trail.position          = global_position
	trail.z_index           = z_index - 1
	get_tree().current_scene.add_child(trail)
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(trail):
		trail.queue_free()

func _perform_attack() -> void:
	is_attacking = true
	attack_cooldown_timer = ATTACK_COOLDOWN

	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")

	_check_attack_hit()
	_wear_weapon_on_attack()   # desgaste del arma (no bloquea el ataque)

	# Resetear is_attacking siempre después del cooldown de animación
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	if not is_instance_valid(self):
		return
	is_attacking = false

func _wear_weapon_on_attack() -> void:
	# Desgasta el arma equipada 1 punto cada ~10 ataques (prob 10%)
	if randf() > 0.10:
		return
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv or not inv.equipped_items.has("weapon"):
		return
	var weapon = inv.equipped_items.get("weapon", null)
	if weapon == null or not weapon.has("durability"):
		return
	weapon["durability"] = max(0, weapon["durability"] - 1)
	inv.equipped_items["weapon"] = weapon
	if weapon["durability"] == 0:
		var ui = GameManager.get_game_ui()
		if ui and ui.has_method("show_floating_text"):
			ui.show_floating_text(global_position, "¡Arma rota!", Color(1.0, 0.2, 0.2))
		print("[Durabilidad] Arma rota: ", weapon.get("name", "?"))

func _check_attack_hit() -> void:
	var attack_area = Area2D.new()
	attack_area.collision_layer = 0
	attack_area.collision_mask  = 4
	
	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 36.0
	shape_node.shape = circle
	attack_area.add_child(shape_node)
	
	# FIX AIMBOT: si hay enemigo objetivo activo, apuntar directo a él
	var aim_dir := facing_dir.normalized()
	if is_instance_valid(_aimbot_target):
		aim_dir = (_aimbot_target.global_position - global_position).normalized()
	var offset = aim_dir * 26.0
	attack_area.position = offset
	add_child(attack_area)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_instance_valid(attack_area):
		return
	
	var overlapping = attack_area.get_overlapping_areas()
	var hit_any = false
	
	for area in overlapping:
		var parent = area.get_parent()
		if is_instance_valid(parent) and parent.is_in_group("enemy"):
			var atk = PlayerData.get_total_attack()
			var knockback = (parent.global_position - global_position).normalized()
			var nm = get_node_or_null("/root/NetworkManager")
			var nid = parent.get("network_id") if parent.get("network_id") != null else 0
				if nm and nm.is_client:
					if nid != 0:
						print("[Client][Combat] Autoataque → nid=%d atk=%d" % [nid, atk])
						nm.request_enemy_damage(nid, atk, knockback)
					else:
						print("[Client][Combat] nid=0 — re-sync")
						nm._send_my_state()
						if parent.has_method("take_damage"):
							parent.take_damage(atk, knockback)
				elif parent.has_method("take_damage"):
					parent.take_damage(atk, knockback)
			hit_any = true
	
	var particle_color = Color.YELLOW if hit_any else Color(1, 1, 1, 0.5)
	_spawn_attack_particles(global_position + offset, particle_color)
	
	attack_area.queue_free()

func _spawn_roll_ghost() -> void:
	if not sprite or not sprite.texture:
		return
	for i in range(3):
		await get_tree().create_timer(i * 0.08).timeout
		if not is_instance_valid(self):
			return
		var ghost := Sprite2D.new()
		ghost.texture  = sprite.texture
		ghost.hframes  = sprite.hframes
		ghost.vframes  = sprite.vframes
		ghost.frame    = sprite.frame
		ghost.flip_h   = sprite.flip_h
		ghost.scale    = sprite.scale
		ghost.position = global_position
		ghost.z_index  = z_index - 1
		ghost.modulate = Color(0.5, 0.8, 1.0, 0.5)
		get_tree().current_scene.add_child(ghost)
		var tw := ghost.create_tween()
		tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func(): if is_instance_valid(ghost): ghost.queue_free())

func _spawn_attack_particles(pos: Vector2, color: Color) -> void:
	var count = 5 if color == Color.YELLOW else 3
	for i in range(count):
		var p = ColorRect.new()
		p.size     = Vector2(4, 4)
		p.color    = color
		p.position = pos
		p.z_index  = 90
		# BUG C FIX: usar _flash_canvas en lugar de get_tree().root para evitar huérfanos
		_flash_canvas.add_child(p)
		var tw  = p.create_tween().set_parallel(true)
		var dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() \
		          * randf_range(20.0, 60.0)
		tw.tween_property(p, "position", pos + dir, 0.3)
		tw.tween_property(p, "modulate:a", 0.0, 0.3)
		tw.finished.connect(func(): if is_instance_valid(p): p.queue_free())

func _toggle_inventory() -> void:
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("toggle_inventory"):
		ui.toggle_inventory()

func _interact_with_nearby() -> void:
	if nearby_npcs.size() > 0:
		var npc = nearby_npcs[0]
		if npc.has_method("interact"):
			npc.interact()
	elif nearby_interactables.size() > 0:
		var obj = nearby_interactables[0]
		if obj.has_method("interact"):
			obj.interact()

# ──────────────────────────────────────────────
# DAÑO Y CURACIÓN
# ──────────────────────────────────────────────

func take_damage(amount: int, is_pvp_hit: bool = false) -> void:
	var attacker := _find_nearest_attacker()
	if attacker:
		WeaponSkillSystem.on_player_hit(attacker, amount)
	_wear_armor_on_hit()   # desgaste de armadura al recibir daño
	if not is_pvp_hit and not GameManager.is_pvp_zone:
		var red_pct: int = PlayerData.get_dmg_reduction_pct()
		if red_pct > 0:
			amount = max(1, int(float(amount) * (1.0 - float(red_pct) / 100.0)))
	PlayerData.take_damage(amount)
	if has_node("/root/PermissionManager"):
		get_node("/root/PermissionManager").vibrate_hit()
	if sprite:
		var flash_mat := sprite.material.next_pass if sprite.material else null
		if flash_mat is ShaderMaterial:
			flash_mat.set_shader_parameter("flash_amount", 1.0)
			var tw := create_tween()
			tw.tween_method(func(v: float):
				if is_instance_valid(self) and flash_mat:
					flash_mat.set_shader_parameter("flash_amount", v)
			, 1.0, 0.0, 0.14)
		else:
			sprite.modulate = Color(2.0, 2.0, 2.0)
			damage_flash_timer = 0.14
	if camera:
		_shake_camera(0.2, 5.0)
	_screen_damage_flash()
	show_floating_text("-" + str(amount), Color.RED)

func _wear_armor_on_hit() -> void:
	# Desgasta una pieza de armadura aleatoria al recibir daño (prob 15%)
	if randf() > 0.15:
		return
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		return
	var armor_slots = ["helmet", "chest", "legs", "boots", "gloves"]
	var valid_slots: Array = []
	for s in armor_slots:
		var it = inv.equipped_items.get(s, null)
		if it != null and it.has("durability") and it["durability"] > 0:
			valid_slots.append(s)
	if valid_slots.is_empty():
		return
	var slot = valid_slots[randi() % valid_slots.size()]
	var armor = inv.equipped_items[slot]
	armor["durability"] = max(0, armor["durability"] - 1)
	inv.equipped_items[slot] = armor
	if armor["durability"] == 0:
		var ui = GameManager.get_game_ui()
		if ui and ui.has_method("show_floating_text"):
			ui.show_floating_text(global_position, "¡%s rota!" % armor.get("name","Armadura"), Color(1.0, 0.3, 0.1))
		print("[Durabilidad] Armadura rota en slot %s: %s" % [slot, armor.get("name","?")])

func _find_nearest_attacker() -> Node:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var best: Node = null
	var best_dist := 120.0
	for e in enemies:
		if not is_instance_valid(e): continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best

func _screen_damage_flash() -> void:
	if screen_flash and is_instance_valid(screen_flash):
		screen_flash.queue_free()
	
	screen_flash = ColorRect.new()
	screen_flash.color   = Color(1, 0, 0, 0.25)
	screen_flash.z_index = 150
	screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_canvas.add_child(screen_flash)  # BUG C FIX: hijo del CanvasLayer propio
	
	var tween = screen_flash.create_tween()
	tween.tween_property(screen_flash, "modulate:a", 0.0, 0.35)
	tween.finished.connect(func(): if is_instance_valid(screen_flash): screen_flash.queue_free())

func heal(amount: int) -> void:
	PlayerData.heal(amount)
	show_floating_text("+" + str(amount), Color.GREEN)

func gain_xp(amount: int) -> void:
	PlayerData.gain_xp(amount)
	show_floating_text("+" + str(amount) + " XP", Color.CYAN)

# ──────────────────────────────────────────────
# EFECTOS VISUALES
# ──────────────────────────────────────────────

func show_floating_text(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	label.position = Vector2(-20, -50)
	label.z_index  = 100
	add_child(label)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 1.4)
	tween.tween_property(label, "modulate:a", 0.0, 1.4)
	tween.finished.connect(func(): if is_instance_valid(label): label.queue_free())

func _shake_camera(duration: float, intensity: float) -> void:
	if not camera:
		return
	var original_offset = camera.offset
	var elapsed = 0.0
	while elapsed < duration:
		camera.offset = original_offset + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	camera.offset = original_offset

# ──────────────────────────────────────────────
# TRANSICIÓN DE ESCENAS POR BORDE
# ──────────────────────────────────────────────

func _check_scene_borders() -> void:
	# BUG D FIX: función intencionalmente vacía.
	# Los bordes de escena los gestionan las Areas2D SceneTransition en cada mapa.
	# Esta función se mantiene por si en el futuro se quiere añadir lógica adicional
	# (p.ej. forzar al jugador dentro de límites sin transición), pero no es un bug activo.
	pass

# ──────────────────────────────────────────────
# SEÑALES DE ÁREA DE INTERACCIÓN
# ──────────────────────────────────────────────

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("npc"):
		nearby_npcs.append(body)
	elif body.is_in_group("interactable"):
		nearby_interactables.append(body)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	nearby_npcs.erase(body)
	nearby_interactables.erase(body)

# ──────────────────────────────────────────────
# SEÑALES DE PLAYERDATA
# ──────────────────────────────────────────────

func _on_health_changed(new_hp: int, max_hp_val: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp_val
		hp_bar.value     = new_hp

func _on_level_up(new_level: int) -> void:
	show_floating_text("✦ NIVEL " + str(new_level) + " ✦", Color.GOLD)
	if camera:
		var flash = ColorRect.new()
		flash.color  = Color(1, 0.86, 0.4, 0.5)
		flash.size   = get_viewport_rect().size
		flash.z_index = 200
		get_tree().root.add_child(flash)
		var tween = create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.6)
		tween.finished.connect(func(): if is_instance_valid(flash): flash.queue_free())

func _on_respawned() -> void:
	if sprite:
		sprite.modulate = Color.WHITE
	is_attacking = false
	attack_cooldown_timer = 0.0
