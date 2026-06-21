extends Node
class_name BossMechanics

# ════════════════════════════════════════════════════════════
# BossMechanics — sistema compartido de mecánicas de raid boss
# Se añade como hijo de cualquier boss_*.gd. Provee:
#   - Threat list real (no solo "el último que pegó")
#   - AoE telegrafiado: círculo de aviso → daño tras X segundos
#   - Daño a todo el grupo dentro de un radio (party-aware)
#   - Castigo por quedarse quieto durante el telegraph
#   - Hooks de fase reutilizables por los 4 bosses
# ════════════════════════════════════════════════════════════

var boss: Node = null               # referencia al Enemy (boss_node)

# ── Threat (amenaza) ───────────────────────────────────────
# Diccionario { node: float } — daño acumulado por jugador
var threat: Dictionary = {}
const TAUNT_THREAT_BONUS := 500.0   # Provocar agrega esto al instante

func setup(boss_node: Node) -> void:
	boss = boss_node

func add_threat(attacker: Node, amount: float) -> void:
	if not is_instance_valid(attacker):
		return
	threat[attacker] = threat.get(attacker, 0.0) + amount

func force_taunt(tank: Node) -> void:
	add_threat(tank, TAUNT_THREAT_BONUS)
	if is_instance_valid(boss) and boss.has_method("force_target"):
		boss.force_target(tank)

## Devuelve el jugador con más threat acumulado (el objetivo actual ideal)
func get_top_threat_target() -> Node:
	var best: Node = null
	var best_val := -1.0
	for k in threat.keys():
		if not is_instance_valid(k):
			continue
		if threat[k] > best_val:
			best_val = threat[k]
			best = k
	return best

func clear_threat_for(node: Node) -> void:
	threat.erase(node)


# ── Party-aware helpers ───────────────────────────────────────
func _get_party_player_nodes() -> Array:
	var out: Array = []
	if has_node("/root/PartyManager"):
		var pm = get_node("/root/PartyManager")
		if "members" in pm:
			for m in pm.members:
				var n = m.get("node", null)
				if is_instance_valid(n):
					out.append(n)
	if out.is_empty():
		var p = get_tree().get_first_node_in_group("player")
		if is_instance_valid(p):
			out.append(p)
	return out


# ── AoE telegrafiado ───────────────────────────────────────
## Crea un círculo de aviso en `pos`, espera `warn_time` segundos, y entonces
## aplica `damage` a todos los jugadores del grupo que estén dentro de `radius`.
## Si `punish_still` es true, jugadores que NO se movieron durante el warn
## reciben daño extra (penaliza ignorar la mecánica).
func telegraph_aoe(pos: Vector2, radius: float, damage: int, warn_time: float = 1.4,
		color: Color = Color(1.0, 0.2, 0.2, 0.35), punish_still: bool = false) -> void:
	if not is_instance_valid(boss):
		return
	var parent := boss.get_parent()
	if parent == null:
		return

	# Indicador visual: círculo que crece y pulsa
	var ring := _make_warning_ring(pos, radius, color)
	parent.add_child(ring)

	# Registrar posición inicial de cada jugador (para detectar quietud)
	var start_positions := {}
	if punish_still:
		for p in _get_party_player_nodes():
			start_positions[p] = p.global_position

	await boss.get_tree().create_timer(warn_time).timeout

	if is_instance_valid(ring):
		ring.queue_free()

	if not is_instance_valid(boss):
		return

	# Flash de impacto
	var flash := _make_impact_flash(pos, radius, color)
	parent.add_child(flash)

	for p in _get_party_player_nodes():
		if not is_instance_valid(p):
			continue
		if p.global_position.distance_to(pos) <= radius:
			var dmg := damage
			if punish_still and start_positions.has(p):
				var moved: float = p.global_position.distance_to(start_positions[p])
				if moved < 24.0:
					dmg = int(damage * 1.6)   # castigo por no moverse
			if p.has_method("take_damage"):
				p.take_damage(dmg)
			if p.has_method("show_floating_text"):
				p.show_floating_text("-%d" % dmg, Color(1.0, 0.3, 0.2))


func _make_warning_ring(pos: Vector2, radius: float, color: Color) -> Node2D:
	var ring := Node2D.new()
	ring.position = pos
	ring.z_index = 50
	var draw_script := GDScript.new()
	draw_script.source_code = """
extends Node2D
var r: float = %f
var col: Color = %s
var t: float = 0.0
func _process(delta):
	t += delta
	queue_redraw()
func _draw():
	var pulse: float = 0.85 + 0.15 * sin(t * 10.0)
	draw_circle(Vector2.ZERO, r * pulse, Color(col.r, col.g, col.b, col.a * 0.5))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.9), 3.0)
""" % [radius, color]
	draw_script.reload()
	ring.set_script(draw_script)
	return ring


func _make_impact_flash(pos: Vector2, radius: float, color: Color) -> Node2D:
	var flash := Node2D.new()
	flash.position = pos
	flash.z_index = 51
	var draw_script := GDScript.new()
	draw_script.source_code = """
extends Node2D
var r: float = %f
var col: Color = %s
func _ready():
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
func _draw():
	draw_circle(Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.55))
""" % [radius, color]
	draw_script.reload()
	flash.set_script(draw_script)
	return flash


# ── Daño instantáneo a todo el grupo (sin telegraph, para fase de furia) ──
func damage_all_in_radius(pos: Vector2, radius: float, damage: int) -> void:
	for p in _get_party_player_nodes():
		if is_instance_valid(p) and p.global_position.distance_to(pos) <= radius:
			if p.has_method("take_damage"):
				p.take_damage(damage)


# ── Invocaciones (adds) ────────────────────────────────────
## Spawnea `count` adds del tipo `mob_type` alrededor de `center`.
## Devuelve el array de nodos invocados para que el boss los controle
## (ej: deben morir para evitar un wipe, o curan al boss si no se interrumpen).
func spawn_adds(center: Vector2, mob_type: String, count: int, level: int, radius: float = 90.0) -> Array:
	var out: Array = []
	if not has_node("/root/EnemyManager"):
		return out
	var em = get_node("/root/EnemyManager")
	if not em.has_method("spawn_enemy"):
		return out
	for i in range(count):
		var ang := (TAU / count) * i
		var offset := Vector2(cos(ang), sin(ang)) * radius
		# Usar el padre del boss (la sala del boss) como parent_override,
		# no "self" (BossMechanics), que no es la raíz de la escena y por
		# tanto no tiene scene_file_path válido para el filtrado por zona.
		var zone_parent: Node = boss.get_parent() if is_instance_valid(boss) else null
		var add: Node = em.spawn_enemy(mob_type, center + offset, level, zone_parent)
		if add:
			out.append(add)
	return out
