# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

class_name NPC
extends CharacterBody2D

## Offsets de labels sobre el NPC (ajustables en el Inspector de Godot)
@export_group("UI Label Offsets")
@export var name_label_offset: Vector2    = Vector2(-30, -44)
@export var role_label_offset: Vector2    = Vector2(-30, -54)
@export var interact_hint_offset: Vector2 = Vector2(-24, -66)

# ============================================================
# NPC — CharacterBody2D
# Sistema de diálogo, tienda, banco, crafteo, quests
# ============================================================

@export var npc_name: String           = "NPC"
@export var npc_role: String           = "Comerciante"
@export var npc_gender: String         = "male"
@export var npc_tint: Color            = Color.WHITE
@export_multiline var dialog_lines: Array[String] = [
	"¡Hola, aventurero!",
	"¿En qué puedo ayudarte?"
]

@export var has_shop: bool     = false
@export var has_bank: bool     = false
@export var has_crafting: bool = false
@export var has_quest: bool    = false
@export var has_auction: bool  = false
@export var has_dungeon: bool  = false
@export var has_healer: bool   = false

# ID para la tienda específica (forge, herbalist, bank, etc.)
@export var shop_id: String = ""

# ── Sunnyside animation ──────────────────────────────────────
const NPC_IDLE_PATH := "res://assets/npcs/sunnyside/human_idle_strip9.png"
const NPC_WALK_PATH := "res://assets/npcs/sunnyside/human_walk_strip8.png"
var _npc_anim_timer: float = 0.0
var _npc_anim_frame: int = 0
var _npc_anim_frames_total: int = 9
const NPC_ANIM_FPS: float = 8.0
@onready var sprite: Sprite2D             = $Sprite2D
@onready var name_label: Label            = $NameLabel
@onready var role_label: Label            = $RoleLabel
@onready var interaction_area: Area2D     = $InteractionArea
@onready var interact_hint: Label         = $InteractHint

var player_nearby: bool  = false
var player_ref: Node     = null
var current_dialog_index: int = 0

signal npc_interacted(npc: NPC)

func _ready() -> void:
	add_to_group("npc")
	
	if name_label:
		name_label.text = npc_name
		name_label.position = name_label_offset
	if role_label:
		role_label.text = npc_role
		role_label.position = role_label_offset
	if sprite:
		sprite.modulate = npc_tint
		sprite.scale = Vector2(3.5, 3.5)
		if ResourceLoader.exists(NPC_IDLE_PATH):
			sprite.texture = load(NPC_IDLE_PATH)
			sprite.hframes = 9
			sprite.frame = randi() % 9
	if interact_hint:
		interact_hint.visible = false
		interact_hint.position = interact_hint_offset
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	
	# Animación idle sutil (bob up/down)
	_start_idle_animation()

func _start_idle_animation() -> void:
	if not sprite:
		return
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -3.0, 0.8).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:y",  3.0, 0.8).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	# Y-sort: misma fórmula que el jugador para profundidad correcta
	z_index = int((global_position.y + 540.0) / 8.0)
	# Hint de interacción
	if interact_hint:
		interact_hint.visible = player_nearby
	# Animación sprite Sunnyside
	if sprite and sprite.texture:
		_npc_anim_timer += delta
		if _npc_anim_timer >= 1.0 / NPC_ANIM_FPS:
			_npc_anim_timer = 0.0
			_npc_anim_frame = (_npc_anim_frame + 1) % _npc_anim_frames_total
			sprite.frame = _npc_anim_frame

# ──────────────────────────────────────────────
# INTERACCIÓN
# ──────────────────────────────────────────────

func interact() -> void:
	if not player_nearby:
		return
	
	current_dialog_index = 0
	GameManager.start_npc_interaction(npc_name)
	npc_interacted.emit(self)
	
	# FIX: Ocultar labels flotantes para que no se superpongan al diálogo
	if name_label:   name_label.visible = false
	if role_label:   role_label.visible = false
	if interact_hint: interact_hint.visible = false
	
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("show_npc_dialog"):
		ui.show_npc_dialog(self, dialog_lines)
		# Restaurar labels cuando el diálogo se cierre
		if ui.has_signal("dialog_closed"):
			var callable = func(): _restore_labels()
			ui.dialog_closed.connect(callable, CONNECT_ONE_SHOT)

func get_current_dialog() -> String:
	if dialog_lines.is_empty():
		return "..."
	return dialog_lines[current_dialog_index % dialog_lines.size()]

func next_dialog() -> bool:
	current_dialog_index += 1
	if current_dialog_index >= dialog_lines.size():
		current_dialog_index = 0
		return false  # Dialog terminado
	return true

# ──────────────────────────────────────────────
# FUNCIONES DE SISTEMAS
# ──────────────────────────────────────────────

func open_shop() -> void:
	if not has_shop:
		return
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("open_shop"):
		ui.open_shop(shop_id if shop_id != "" else npc_name)

func open_bank() -> void:
	if not has_bank:
		return
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("open_bank"):
		ui.open_bank()

func open_crafting() -> void:
	if not has_crafting:
		return
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("open_crafting"):
		ui.open_crafting(shop_id)

func open_quest() -> void:
	if not has_quest:
		return
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("show_quest"):
		ui.show_quest(npc_name)

func open_auction() -> void:
	if not has_auction:
		return
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("open_auction"):
		ui.open_auction()

# ──────────────────────────────────────────────
# SEÑALES DE ÁREA
# ──────────────────────────────────────────────

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		player_ref    = body
		if body.has_method("_on_interaction_area_body_entered"):
			body._on_interaction_area_body_entered(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		player_ref    = null
		if body.has_method("_on_interaction_area_body_exited"):
			body._on_interaction_area_body_exited(self)

func open_dungeon() -> void:
	if not has_dungeon:
		return
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("show_dungeon_prompt"):
		ui.show_dungeon_prompt()

func open_healer() -> void:
	if not has_healer:
		return
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("open_healer"):
		ui.open_healer(self)

func _restore_labels() -> void:
	if name_label:   name_label.visible = true
	if role_label:   role_label.visible = true
