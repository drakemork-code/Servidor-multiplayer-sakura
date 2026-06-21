# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node2D

# ============================================================
# GRASS TALL — Hierba Alta / Pasto Town Scene
# ============================================================
# Animaciones:
#   "wind"     → bucle 4 frames a 6.667fps (≈0.15s/frame) = 60fps smooth
#   "interact" → 3 frames disparados cuando el jugador pasa cerca
#
# Para 60 FPS:
#   • El AnimatedSprite2D usa process_callback = PHYSICS (60fps)
#   • wind speed = 6.667 fps  (1 frame cada 0.15 s)
#   • interact speed = 8.0 fps (aplastamiento rápido → recuperación)
# ============================================================

@export var interact_radius: float = 20.0

@onready var _anim: AnimatedSprite2D  = $AnimSprite
@onready var _area: Area2D            = $InteractArea

var _interacting: bool = false
var _player_nearby: bool = false

# ── Collision shape for interact area ──────────────────────
func _ready() -> void:
	# Build a circular collision shape at runtime
	var shape := CircleShape2D.new()
	shape.radius = interact_radius
	
	var cs := $InteractArea/CollisionShape2D
	cs.shape = shape
	
	# En Godot 4, AnimatedSprite2D no tiene process_callback (era Godot 3).
	# El sprite se sincroniza automáticamente con el árbol de escena.
	_anim.play("wind")
	
	# Connect interact area signals
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_anim.animation_finished.connect(_on_animation_finished)

# ── Player proximity handling ──────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("players"):
		_player_nearby = true
		if not _interacting:
			_trigger_interact()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("players"):
		_player_nearby = false

func _trigger_interact() -> void:
	if _interacting:
		return
	_interacting = true
	_anim.play("interact")

func _on_animation_finished() -> void:
	if _anim.animation == "interact":
		_interacting = false
		_anim.play("wind")
		# If player is still nearby, retrigger after a short delay
		if _player_nearby:
			await get_tree().create_timer(0.3).timeout
			if _player_nearby:
				_trigger_interact()

# ── Optional: slight random offset on wind phase for variety ──
func randomize_phase() -> void:
	_anim.frame = randi() % 4
