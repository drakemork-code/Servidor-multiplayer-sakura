# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Area2D
class_name SceneTransition

# ============================================================
# SCENE TRANSITION — Area2D
# Al acercarse al borde, carga la siguiente escena
# ============================================================

@export var target_scene: String = ""
@export var spawn_position: Vector2 = Vector2.ZERO
@export var transition_direction: String = "north"  # north/south/east/west
@export var zone_label: String = ""

# NOTA: NO usar @onready aquí — el CollisionShape2D se añade
# dinámicamente desde town_scene.gd DESPUÉS del add_child(area),
# por lo que $CollisionShape2D no existe en _ready() y crashea.

var player_in_range: bool = false
var hint_label: Label = null
var _transitioning: bool = false   # evita doble disparo

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if zone_label != "":
		_create_zone_hint()

func _create_zone_hint() -> void:
	hint_label = Label.new()
	hint_label.text = "→ " + zone_label
	hint_label.add_theme_color_override("font_color", Color(1, 1, 0.6, 0.8))
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.visible = false
	add_child(hint_label)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if _transitioning:
		return

	player_in_range = true
	if hint_label:
		hint_label.visible = true

	if target_scene != "":
		_transitioning = true
		_trigger_transition(body)

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_in_range = false
	if hint_label:
		hint_label.visible = false

func _trigger_transition(player: Node2D) -> void:
	if target_scene == "":
		push_warning("[SceneTransition] No hay escena destino configurada")
		_transitioning = false
		return

	print("[SceneTransition] Entrando a: ", target_scene, " via ", transition_direction)

	# Guardar progreso antes de cambiar de escena
	GameManager.save_game()
	InventoryManager.save_inventory()

	var spawn = spawn_position
	if spawn == Vector2.ZERO:
		spawn = _calculate_opposite_spawn()

	# Usar pantalla de carga animada
	PlayerData.flush_pending_save()
	var ls = get_node_or_null("/root/LoadingScreen")
	if ls and ls.has_method("go_to_with_spawn"):
		ls.go_to_with_spawn(target_scene, spawn)
	else:
		# Fallback: fade simple original
		_do_fade_transition(player, spawn)

func _calculate_opposite_spawn() -> Vector2:
	# El jugador aparece cerca del borde de entrada de la escena destino.
	var is_going_to_town := target_scene == "res://scenes/town.tscn"

	if is_going_to_town:
		# town: SCENE_WIDTH=1920, SCENE_HEIGHT=1080 → half = ±960, ±540
		match transition_direction:
			"north": return Vector2(0,  -460)   # justo dentro del borde norte de town
			"south": return Vector2(0,   460)   # justo dentro del borde sur de town
			"east":  return Vector2( 880,   0)  # justo dentro del borde este de town
			"west":  return Vector2(-880,   0)  # justo dentro del borde oeste de town
			_:       return Vector2(0, 0)
	else:
		# Worlds: SCENE_WIDTH=18000, SCENE_HEIGHT=12000 → half = ±9000, ±6000
		# El jugador aparece a 100px del borde de entrada
		match transition_direction:
			"north": return Vector2(0,    5800)   # borde sur de world_north (y=+6000)
			"south": return Vector2(0,   -5800)   # borde norte de world_south (y=-6000)
			"east":  return Vector2(-8800,   0)   # borde oeste de world_east (x=-9000)
			"west":  return Vector2( 8800,   0)   # borde este de world_west (x=+9000)
			_:       return Vector2(0, 0)

func _do_fade_transition(_player: Node2D, spawn: Vector2) -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 999
	get_tree().root.add_child(canvas)

	var fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.size  = get_viewport().get_visible_rect().size
	canvas.add_child(fade_rect)

	# Fade a negro
	var tween_in = fade_rect.create_tween()
	tween_in.tween_property(fade_rect, "color:a", 1.0, 0.4)
	await tween_in.finished

	# Programar fade de vuelta ANTES de cambiar escena.
	# fade_rect es hijo de root (no de la escena actual) y sobrevive
	# al cambio de escena — su tween tambien.
	var tween_out = fade_rect.create_tween()
	tween_out.tween_interval(0.25)
	tween_out.tween_property(fade_rect, "color:a", 0.0, 0.45)
	tween_out.tween_callback(canvas.queue_free)

	# Cambiar escena (self se libera al final del frame, tween_out sigue vivo)
	PlayerData.flush_pending_save()  # BUG B FIX: persistir monedas antes de cambiar escena
	GameManager.change_scene_with_spawn(target_scene, spawn)
