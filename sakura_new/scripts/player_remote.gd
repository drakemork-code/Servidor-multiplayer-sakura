# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

class_name PlayerRemote
extends CharacterBody2D

# ============================================================
# PLAYER REMOTE — Visualización de jugadores de otros clientes
# No tiene física propia: recibe posición del servidor y
# hace interpolación suave (lerp) para evitar teletransporte.
# ============================================================

@onready var sprite       : Sprite2D       = $Sprite2D
@onready var name_label   : Label          = $NameLabel
@onready var hp_bar       : ProgressBar    = $HPBar

const LERP_SPEED   : float = 12.0
const ANIM_FPS     : float = 9.0
const PLAYER_BASE  : String = "res://assets/characters/player/"
const HAIR_STYLES  : Array  = ["bowlhair","curlyhair","longhair","mophair","shorthair","spikeyhair"]

var _target_pos    : Vector2 = Vector2.ZERO
var _anim_current  : String  = "idle"
var _anim_frame    : int     = 0
var _anim_timer    : float   = 0.0
var _facing_right  : bool    = true
var _hair_style    : String  = "spikeyhair"
var _peer_name     : String  = "???"

func _ready() -> void:
	# Sombra
	var shadow := Sprite2D.new()
	shadow.z_index = -1
	shadow.position = Vector2(0.0, 10.0)
	var img := Image.create(32, 12, false, Image.FORMAT_RGBA8)
	var cx := 16.0; var cy := 6.0; var rx := 13.0; var ry := 5.0
	for px in range(32):
		for py in range(12):
			var dx := (px - cx) / rx; var dy := (py - cy) / ry
			img.set_pixel(px, py, Color(0,0,0, 0.35) if dx*dx + dy*dy <= 1.0 else Color(0,0,0,0))
	shadow.texture = ImageTexture.create_from_image(img)
	add_child(shadow)
	move_child(shadow, 0)

func setup(data: Dictionary) -> void:
	var pos_d = data.get("position", {"x": 0.0, "y": 0.0})
	_target_pos = Vector2(pos_d.x, pos_d.y)
	global_position = _target_pos
	_apply_appearance_data(data)

# FIX BUG "JUGADOR DEFAULT": cuando el dato completo de apariencia (nombre,
# pelo, colores) llega DESPUÉS de que el nodo remoto ya fue creado con datos
# parciales (carrera de timing entre el RPC reliable de "joined" y el
# unreliable_ordered de posición — ver _spawn_remote_node en
# network_manager.gd), llamamos a esto en vez de setup() para refrescar
# solo la apariencia sin teletransportar el nodo de golpe a una posición
# vieja/desactualizada.
func refresh_appearance(data: Dictionary) -> void:
	_apply_appearance_data(data)

func _apply_appearance_data(data: Dictionary) -> void:
	_peer_name  = data.get("name", "???")
	print("[PlayerRemote] apariencia aplicada — nombre='%s'" % _peer_name)
	_hair_style = data.get("hair_style", "spikeyhair")
	if not _hair_style in HAIR_STYLES:
		_hair_style = "spikeyhair"
	# FIX NOMBRE: siempre mostrar el nombre real; si llega vacío mostrar "Jugador"
	var display_name := _peer_name if _peer_name != "" and _peer_name != "???" else "Jugador"
	if name_label:
		name_label.text = display_name
		# Asegurar que el label sea visible (tamaño y color)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.6, 1.0))
		name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		name_label.visible = true
	if hp_bar:
		hp_bar.max_value = data.get("max_hp", 100)
		hp_bar.value     = data.get("hp", 100)
	# FIX APARIENCIA: aplicar el mismo shader character_swap que usa el jugador
	# local, para que piel/pelo/ojos/outfit coincidan con lo que eligió el dueño.
	_apply_appearance_shader(data)
	_load_anim(_anim_current)

func _apply_appearance_shader(data: Dictionary) -> void:
	if not sprite:
		return
	if not (sprite.material is ShaderMaterial):
		var mat := ShaderMaterial.new()
		var shader_path := "res://scripts/character_swap.gdshader"
		if ResourceLoader.exists(shader_path):
			mat.shader = load(shader_path)
			sprite.material = mat
	if sprite.material is ShaderMaterial:
		var skin_col   := Color(data.get("skin_r",0.96), data.get("skin_g",0.78), data.get("skin_b",0.64))
		var hair_col   := Color(data.get("hair_r",0.25), data.get("hair_g",0.15), data.get("hair_b",0.08))
		var eye_col    := Color(data.get("eye_r",0.2),   data.get("eye_g",0.5),   data.get("eye_b",0.9))
		var outfit_col := Color(data.get("outfit_r",1.0),data.get("outfit_g",1.0),data.get("outfit_b",1.0))
		sprite.material.set_shader_parameter("skin_color", skin_col)
		sprite.material.set_shader_parameter("hair_color", hair_col)
		sprite.material.set_shader_parameter("eye_color",  eye_col)
		sprite.material.set_shader_parameter("outfit_color", outfit_col)
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = Color(data.get("skin_r",1.0), data.get("skin_g",1.0), data.get("skin_b",1.0))

func update_state(pos: Vector2, hp: int, max_hp: int, anim: String, facing: int) -> void:
	_target_pos   = pos
	_facing_right = facing >= 0
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value     = hp
	if anim != _anim_current:
		_anim_current = anim
		_anim_frame   = 0
		_anim_timer   = 0.0
		_load_anim(anim)

func _process(delta: float) -> void:
	# Interpolación suave de posición
	global_position = global_position.lerp(_target_pos, LERP_SPEED * delta)
	# Flip horizontal
	if sprite:
		sprite.flip_h = not _facing_right
	# Animación por frames
	_anim_timer += delta
	if _anim_timer >= 1.0 / ANIM_FPS:
		_anim_timer = 0.0
		var frame_count = _get_frame_count(_anim_current)
		_anim_frame = (_anim_frame + 1) % frame_count
		if sprite and sprite.texture:
			sprite.frame = _anim_frame

func _load_anim(anim_name: String) -> void:
	if not sprite:
		return
	var counts = {"idle": 9, "walk": 8, "run": 8, "attack": 10}
	var count  = counts.get(anim_name, 9)

	# 1) Intentar con hair_style primero
	var path = PLAYER_BASE + "player_%s_%s_strip%d.png" % [_hair_style, anim_name, count]
	var tex : Texture2D = null

	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D

	# 2) Fallback: sin hair_style
	if not tex:
		path = PLAYER_BASE + "player_%s_strip%d.png" % [anim_name, count]
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D

	# 3) Fallback: idle genérico
	if not tex:
		path = PLAYER_BASE + "player_idle_strip9.png"
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			count = 9

	# 4) Fallback final: sprite de color sólido para que el jugador remoto
	#    SIEMPRE sea visible aunque falten los assets en el cliente.
	if not tex:
		push_warning("[PlayerRemote] No se encontró sprite para: %s %s — usando placeholder" % [_hair_style, anim_name])
		var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.2, 0.4, 0.9, 1.0))
		for px in range(32):
			for py in range(20):
				var dx := float(px - 16) / 8.0
				var dy := float(py - 10) / 8.0
				if dx * dx + dy * dy <= 1.0:
					img.set_pixel(px, py, Color(0.96, 0.78, 0.64, 1.0))
		tex = ImageTexture.create_from_image(img)
		count = 1

	sprite.texture = tex
	sprite.hframes = count
	sprite.vframes = 1
	sprite.frame   = 0
	_anim_frame    = 0

func _get_frame_count(anim_name: String) -> int:
	return {"idle": 9, "walk": 8, "run": 8, "attack": 10}.get(anim_name, 9)
