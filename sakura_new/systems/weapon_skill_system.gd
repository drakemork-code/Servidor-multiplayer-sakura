# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node
# ============================================================
# WEAPON SKILL SYSTEM — Autoload: WeaponSkillSystem
# ============================================================
# Ramas de armas:
#   ⚔️  ESPADAS  — sword, axe
#   🛡️  TANQUE   — mace
#   🏹  ARCOS    — bow
#   ✨  SAGRADO  — staff_holy
#   💀  OSCURO   — necronomicon
#
# Cada rama tiene 3 habilidades (Q / E / R).
# Cada habilidad tiene su propio cooldown y coste de energía.
# Añade este script como Autoload con nombre "WeaponSkillSystem".
# ============================================================

signal skill_used(slot: int, weapon_type: String)
signal skill_cooldown_updated(slot: int, remaining: float, total: float)
signal skill_ready(slot: int)

# ── Cooldowns actuales (en segundos) ─────────────────────────
var _cd: Array[float]    = [0.0, 0.0, 0.0]   # [skill1, skill2, skill3]
var _cd_max: Array[float] = [0.0, 0.0, 0.0]  # para calcular porcentaje en UI

# ── Definición de habilidades por weapon_type ─────────────────
# Formato:  [ {name, cost, cooldown, func}, ... ]  (índice = slot 0/1/2)
const SKILL_DATA: Dictionary = {
	# ══════════════════════════════════════════
	# ⚔️ RAMA ESPADAS — sword
	# ══════════════════════════════════════════
	"sword": [
		{
			"name":     "Tajo Torbellino",
			"icon":     "res://assets/ui/skill_icons/Icon2.png",
			"cost":     8,
			"cooldown": 4.0,
			"desc":     "Giras y golpeas a todos los enemigos cercanos."
		},
		{
			"name":     "Estocada Veloz",
			"icon":     "res://assets/ui/skill_icons/Icon3.png",
			"cost":     12,
			"cooldown": 7.0,
			"desc":     "Lanzas 3 estocadas rápidas hacia adelante."
		},
		{
			"name":     "Oleada de Acero",
			"icon":     "res://assets/ui/skill_icons/Icon15.png",
			"cost":     20,
			"cooldown": 15.0,
			"desc":     "Proyectil de energía que atraviesa enemigos en línea."
		},
	],
	# ══════════════════════════════════════════
	# ⚔️ RAMA ESPADAS — axe (misma rama, diferente estilo)
	# ══════════════════════════════════════════
	"axe": [
		{
			"name":     "Hacha Giratoria",
			"icon":     "res://assets/ui/skill_icons/Icon18.png",
			"cost":     10,
			"cooldown": 5.0,
			"desc":     "Lanzas el hacha en arco amplio frente a ti."
		},
		{
			"name":     "Golpe Brutal",
			"icon":     "res://assets/ui/skill_icons/Icon30.png",
			"cost":     15,
			"cooldown": 8.0,
			"desc":     "Golpe poderoso que aturde al enemigo 1 segundo."
		},
		{
			"name":     "Furia Berserker",
			"icon":     "res://assets/ui/skill_icons/Icon10.png",
			"cost":     25,
			"cooldown": 18.0,
			"desc":     "Aumenta tu ATK un 50% durante 5 segundos."
		},
	],
	# ══════════════════════════════════════════
	# ⚔️ RAMA ESPADAS — sword_shield
	# ══════════════════════════════════════════
	"sword_shield": [
		{
			"name":     "Golpe de Escudo",
			"icon":     "res://assets/ui/skill_icons/Icon4.png",
			"cost":     8,
			"cooldown": 5.0,
			"desc":     "Chocas con el escudo y empujas al enemigo."
		},
		{
			"name":     "Postura Defensiva",
			"icon":     "res://assets/ui/skill_icons/Icon8.png",
			"cost":     10,
			"cooldown": 10.0,
			"desc":     "Reduces el daño recibido un 40% por 3 segundos."
		},
		{
			"name":     "Contraataque",
			"icon":     "res://assets/ui/skill_icons/Icon11.png",
			"cost":     22,
			"cooldown": 16.0,
			"desc":     "El próximo golpe recibido lo devuelves al atacante."
		},
	],
	# ══════════════════════════════════════════
	# 🛡️ RAMA TANQUE — mace
	# ══════════════════════════════════════════
	"mace": [
		{
			"name":     "Golpe Sísmico",
			"icon":     "res://assets/ui/skill_icons/Icon46.png",
			"cost":     10,
			"cooldown": 5.0,
			"desc":     "Golpeas el suelo y sacudes a todos en radio amplio."
		},
		{
			"name":     "Provocar",
			"icon":     "res://assets/ui/skill_icons/Icon35.png",
			"cost":     8,
			"cooldown": 9.0,
			"desc":     "Atrae la atención de todos los enemigos cercanos."
		},
		{
			"name":     "Bastión de Titanio",
			"icon":     "res://assets/ui/skill_icons/Icon32.png",
			"cost":     30,
			"cooldown": 20.0,
			"desc":     "Invulnerabilidad total durante 2.5 segundos."
		},
	],
	# ══════════════════════════════════════════
	# 🏹 RAMA ARCOS — bow
	# ══════════════════════════════════════════
	"bow": [
		{
			"name":     "Flecha Perforante",
			"icon":     "res://assets/ui/skill_icons/Icon31.png",
			"cost":     7,
			"cooldown": 3.5,
			"desc":     "Dispara una flecha que atraviesa hasta 3 enemigos."
		},
		{
			"name":     "Lluvia de Flechas",
			"icon":     "res://assets/ui/skill_icons/Icon9.png",
			"cost":     18,
			"cooldown": 10.0,
			"desc":     "Llueve flechas sobre un área durante 2 segundos."
		},
		{
			"name":     "Disparo Cargado",
			"icon":     "res://assets/ui/skill_icons/Icon40.png",
			"cost":     25,
			"cooldown": 14.0,
			"desc":     "Un disparo de alto daño que aplica sangrado (3s)."
		},
	],
	# ══════════════════════════════════════════
	# ✨ RAMA SAGRADO — staff_holy
	# ══════════════════════════════════════════
	"staff_holy": [
		{
			"name":     "Rayo Sagrado",
			"icon":     "res://assets/ui/skill_icons/Icon42.png",
			"cost":     10,
			"cooldown": 4.0,
			"desc":     "Dispara luz divina que daña y ralentiza no-muertos."
		},
		{
			"name":     "Curación Mayor",
			"icon":     "res://assets/ui/skill_icons/Icon22.png",
			"cost":     20,
			"cooldown": 8.0,
			"desc":     "Restauras el 30% de tu HP máximo."
		},
		{
			"name":     "Juicio Divino",
			"icon":     "res://assets/ui/skill_icons/Icon48.png",
			"cost":     35,
			"cooldown": 22.0,
			"desc":     "Explosión de luz que daña a todos en pantalla."
		},
	],
	# ══════════════════════════════════════════
	# ✝️ RAMA SAGRADO — greatsword_holy
	# Espada de 2 manos: daño + autocuración leve
	# ══════════════════════════════════════════
	"greatsword_holy": [
		{
			"name":     "Tajo de Luz",
			"icon":     "res://assets/ui/skill_icons/Icon29.png",
			"cost":     10,
			"cooldown": 4.5,
			"desc":     "Golpe en arco amplio con luz sagrada. Cura 5% HP al impactar."
		},
		{
			"name":     "Onda Sagrada",
			"icon":     "res://assets/ui/skill_icons/Icon49.png",
			"cost":     18,
			"cooldown": 9.0,
			"desc":     "Proyectil de energía santa que atraviesa enemigos y cura 10% HP."
		},
		{
			"name":     "Cólera Divina",
			"icon":     "res://assets/ui/skill_icons/Icon27.png",
			"cost":     32,
			"cooldown": 20.0,
			"desc":     "Explosión de luz en radio amplio. Daño masivo y recupera 20% HP."
		},
	],
	# ══════════════════════════════════════════
	# 💀 RAMA OSCURO — necronomicon
	# ══════════════════════════════════════════
	"necronomicon": [
		{
			"name":     "Drenaje de Alma",
			"icon":     "res://assets/ui/skill_icons/Icon14.png",
			"cost":     12,
			"cooldown": 5.0,
			"desc":     "Roba vida al enemigo más cercano."
		},
		{
			"name":     "Nube de Plaga",
			"icon":     "res://assets/ui/skill_icons/Icon7.png",
			"cost":     18,
			"cooldown": 10.0,
			"desc":     "Nube tóxica que envenena a todos los enemigos del área."
		},
		{
			"name":     "Ejército Oscuro",
			"icon":     "res://assets/ui/skill_icons/Icon23.png",
			"cost":     40,
			"cooldown": 25.0,
			"desc":     "Invoca 3 espectros que atacan durante 6 segundos."
		},
	],
}

# ── Buffs activos ─────────────────────────────────────────────
var _berserker_timer: float    = 0.0
var _berserker_active: bool    = false
var _defense_timer: float      = 0.0
var _defense_active: bool      = false
var _invul_timer: float        = 0.0
var _invul_active: bool        = false
var _counter_ready: bool       = false   # contraataque espada+escudo

# Referencia al jugador (se inyecta desde player.gd)
var _player: Node = null

# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_tick_cooldowns(delta)
	_tick_buffs(delta)

# ── Inyección del jugador ─────────────────────────────────────
func register_player(player: Node) -> void:
	_player = player

# ─────────────────────────────────────────────────────────────
# PUNTO DE ENTRADA — llamado desde player.gd
# slot: 0 = Q, 1 = E, 2 = R
# ─────────────────────────────────────────────────────────────
func use_skill(slot: int) -> void:
	if not _player:
		return
	if PlayerData.is_dead:
		return

	var wtype := _get_weapon_type()
	if wtype.is_empty():
		_player.show_floating_text("Sin arma equipada", Color.GRAY)
		return

	if not SKILL_DATA.has(wtype):
		_player.show_floating_text("Sin habilidades para este arma", Color.GRAY)
		return

	# Cooldown activo?
	if _cd[slot] > 0.0:
		var remaining: float = snapped(_cd[slot], 0.1)
		_player.show_floating_text("%.1fs" % remaining, Color(1, 0.5, 0))
		return

	var skills: Array = SKILL_DATA[wtype]
	if slot >= skills.size():
		return

	var skill: Dictionary = skills[slot]

	# Energía suficiente?
	if not PlayerData.use_energy(skill["cost"]):
		_player.show_floating_text("Sin energía!", Color.ORANGE)
		return

	# Aplicar cooldown
	_cd[slot]     = skill["cooldown"]
	_cd_max[slot] = skill["cooldown"]
	skill_used.emit(slot, wtype)
	skill_cooldown_updated.emit(slot, _cd[slot], _cd_max[slot])

	# Ejecutar efecto
	_execute(wtype, slot, skill)

# ─────────────────────────────────────────────────────────────
# EJECUCIÓN POR RAMA
# ─────────────────────────────────────────────────────────────
func _execute(wtype: String, slot: int, skill: Dictionary) -> void:
	match wtype:
		"sword":        _exec_sword(slot, skill)
		"axe":          _exec_axe(slot, skill)
		"sword_shield": _exec_sword_shield(slot, skill)
		"mace":         _exec_mace(slot, skill)
		"bow":          _exec_bow(slot, skill)
		"staff_holy":      _exec_staff_holy(slot, skill)
		"greatsword_holy": _exec_greatsword_holy(slot, skill)
		"necronomicon":    _exec_necronomicon(slot, skill)

# ══════════════════════════════════════════════════
# ⚔️ ESPADA
# ══════════════════════════════════════════════════
func _exec_sword(slot: int, skill: Dictionary) -> void:
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y

	match slot:
		0: # Tajo Torbellino — AoE melee 360°
			_player.show_floating_text("⚔️ " + skill["name"], Color.YELLOW)
			_vfx_aoe(px, py, 90.0, Color(1.0, 0.7, 0.2), 0.25)
			var dmg := _calc_dmg(1.3)
			_damage_enemies_radius(Vector2(px, py), 90.0, dmg)

		1: # Estocada Veloz — 3 golpes en cono
			_player.show_floating_text("💨 " + skill["name"], Color.YELLOW)
			for i in range(3):
				var delay := i * 0.12
				get_tree().create_timer(delay).timeout.connect(func():
					if not is_instance_valid(_player): return
					_vfx_melee(Color(1.0, 0.9, 0.3), 75.0)
					_damage_enemies_cone(_player.global_position, _player.facing_dir, 75.0, 55.0, _calc_dmg(0.6))
				)

		2: # Oleada de Acero — proyectil lineal
			_player.show_floating_text("🌊 " + skill["name"], Color.CYAN)
			_launch_projectile(_player.global_position, _player.facing_dir,
				580.0, _calc_dmg(2.0), Color(0.8, 0.9, 1.0), true)

# ══════════════════════════════════════════════════
# ⚔️ HACHA
# ══════════════════════════════════════════════════
func _exec_axe(slot: int, skill: Dictionary) -> void:
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y

	match slot:
		0: # Hacha Giratoria — arco frontal
			_player.show_floating_text("🪓 " + skill["name"], Color.YELLOW)
			_vfx_melee(Color(0.8, 0.4, 0.1), 100.0)
			_damage_enemies_cone(_player.global_position, _player.facing_dir, 100.0, 80.0, _calc_dmg(1.4))

		1: # Golpe Brutal — golpe único + stun visual
			_player.show_floating_text("💥 " + skill["name"], Color.ORANGE)
			_vfx_aoe(px, py, 60.0, Color(1.0, 0.3, 0.0), 0.3)
			_damage_enemies_radius(Vector2(px, py), 60.0, _calc_dmg(1.8))
			# Stun (efecto visual en enemigos)
			_stun_enemies_radius(Vector2(px, py), 60.0, 1.0)

		2: # Furia Berserker — buff de ataque
			_player.show_floating_text("🔥 ¡FURIA BERSERKER!", Color.RED)
			_berserker_active = true
			_berserker_timer  = 5.0
			PlayerData.equipment_attack += int(PlayerData.get_total_attack() * 0.5)
			PlayerData.stat_updated.emit()
			_vfx_aoe(px, py, 50.0, Color(1.0, 0.1, 0.0), 0.5)

# ══════════════════════════════════════════════════
# ⚔️ ESPADA + ESCUDO
# ══════════════════════════════════════════════════
func _exec_sword_shield(slot: int, skill: Dictionary) -> void:
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y

	match slot:
		0: # Golpe de Escudo — empuje
			_player.show_floating_text("🛡️ " + skill["name"], Color.CYAN)
			_vfx_melee(Color(0.5, 0.7, 1.0), 70.0)
			_damage_enemies_cone(_player.global_position, _player.facing_dir, 70.0, 60.0, _calc_dmg(0.9))
			_knockback_enemies_cone(_player.global_position, _player.facing_dir, 70.0, 60.0, 320.0)

		1: # Postura Defensiva — buff DEF
			_player.show_floating_text("🔰 Postura Defensiva", Color(0.5, 0.8, 1.0))
			_defense_active = true
			_defense_timer  = 3.0
			PlayerData.equipment_defense += int(PlayerData.get_total_defense() * 0.4)
			PlayerData.stat_updated.emit()
			_vfx_aoe(px, py, 45.0, Color(0.4, 0.7, 1.0), 0.4)

		2: # Contraataque — próximo golpe devuelto
			_player.show_floating_text("⚡ Contraataque listo!", Color.GOLD)
			_counter_ready = true
			_vfx_aoe(px, py, 35.0, Color(1.0, 0.9, 0.2), 0.6)

# ══════════════════════════════════════════════════
# 🛡️ MAZA (TANQUE)
# ══════════════════════════════════════════════════
func _exec_mace(slot: int, skill: Dictionary) -> void:
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y

	match slot:
		0: # Golpe Sísmico — AoE grande
			_player.show_floating_text("🌍 " + skill["name"], Color.YELLOW)
			_shake_camera(0.35, 7.0)
			_vfx_aoe(px, py, 120.0, Color(0.7, 0.5, 0.2), 0.4)
			_damage_enemies_radius(Vector2(px, py), 120.0, _calc_dmg(1.5))

		1: # Provocar — forzar agresión
			_player.show_floating_text("😤 ¡PROVOCO!", Color.RED)
			_vfx_aoe(px, py, 200.0, Color(1.0, 0.2, 0.2), 0.2)
			_taunt_enemies_radius(Vector2(px, py), 200.0)

		2: # Bastión de Titanio — invulnerabilidad
			_player.show_floating_text("🏔️ ¡INVULNERABLE!", Color.GOLD)
			_invul_active = true
			_invul_timer  = 2.5
			PlayerData.is_dodging = true  # reutilizamos flag de invulnerabilidad
			_vfx_aoe(px, py, 55.0, Color(1.0, 0.85, 0.0), 0.8)
			# Se desactiva en _tick_buffs

# ══════════════════════════════════════════════════
# 🏹 ARCO
# ══════════════════════════════════════════════════
func _exec_bow(slot: int, skill: Dictionary) -> void:
	match slot:
		0: # Flecha Perforante — proyectil recto que traspasa
			_player.show_floating_text("🏹 " + skill["name"], Color.YELLOW)
			_launch_projectile(_player.global_position, _player.facing_dir,
				600.0, _calc_dmg(1.2), Color(0.9, 0.7, 0.3), true)

		1: # Lluvia de Flechas — AoE en zona apuntada
			_player.show_floating_text("🌧️ " + skill["name"], Color.CYAN)
			var target_pos: Vector2 = _player.global_position + _player.facing_dir * 200.0
			for i in range(8):
				var delay := i * 0.22
				get_tree().create_timer(delay).timeout.connect(func():
					if not is_instance_valid(_player): return
					var scatter := Vector2(randf_range(-60, 60), randf_range(-60, 60))
					var hit_pos: Vector2 = target_pos + scatter
					_vfx_aoe(hit_pos.x, hit_pos.y, 35.0, Color(0.9, 0.6, 0.2), 0.3)
					_damage_enemies_radius(hit_pos, 35.0, _calc_dmg(0.5))
				)

		2: # Disparo Cargado — alto daño + sangrado
			_player.show_floating_text("💢 " + skill["name"], Color.RED)
			_launch_projectile(_player.global_position, _player.facing_dir,
				700.0, _calc_dmg(2.5), Color(1.0, 0.2, 0.2), false)
			# Sangrado: daño continuo leve (simulado con timers)
			_apply_bleed_zone(_player.global_position + _player.facing_dir * 150.0, 3.0)

# ══════════════════════════════════════════════════
# ✨ BASTÓN SAGRADO
# ══════════════════════════════════════════════════
func _exec_staff_holy(slot: int, skill: Dictionary) -> void:
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y

	match slot:
		0: # Rayo Sagrado — proyectil de luz
			_player.show_floating_text("✨ " + skill["name"], Color.YELLOW)
			_launch_projectile(_player.global_position, _player.facing_dir,
				550.0, _calc_dmg(1.1), Color(1.0, 0.95, 0.5), false)

		1: # Curación Mayor — restaura 30% HP propio + cura miembros cercanos del grupo
			var heal_amount := int(PlayerData.max_hp * 0.30)
			PlayerData.heal(heal_amount)
			_player.show_floating_text("💚 +" + str(heal_amount) + " HP", Color.GREEN)
			_vfx_aoe(px, py, 50.0, Color(0.3, 1.0, 0.4), 0.6)
			# ── MEJORA 9: curar también a los miembros del grupo ──
			if has_node("/root/PartyManager"):
				var pm = get_node("/root/PartyManager")
				if pm.is_in_party():
					var party_heal := int(heal_amount * 0.80)   # 80% del heal propio
					var healed: int = pm.aoe_heal_members(party_heal, _player.global_position)
					if healed > 0:
						_vfx_aoe(px, py, PartyManager.HEAL_RADIUS, Color(0.4, 1.0, 0.6, 0.35), 0.7)

		2: # Juicio Divino — explosión en toda la pantalla
			_player.show_floating_text("☀️ ¡JUICIO DIVINO!", Color.GOLD)
			_shake_camera(0.5, 8.0)
			_vfx_aoe(px, py, 250.0, Color(1.0, 0.95, 0.6), 0.7)
			_damage_enemies_radius(Vector2(px, py), 250.0, _calc_dmg(2.2))

# ══════════════════════════════════════════════════
# ✝️  ESPADA SAGRADA DE 2 MANOS (GREATSWORD HOLY)
# ══════════════════════════════════════════════════
func _exec_greatsword_holy(slot: int, skill: Dictionary) -> void:
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y

	match slot:
		0: # Tajo de Luz — cono amplio + cura 5% HP
			_player.show_floating_text("✝️ " + skill["name"], Color(1.0, 0.95, 0.6))
			_damage_enemies_cone(_player.global_position, _player.facing_dir, 110.0, 80.0, _calc_dmg(1.2))
			var heal_tajo := int(PlayerData.max_hp * 0.05)
			PlayerData.heal(heal_tajo)
			_player.show_floating_text("+%d HP" % heal_tajo, Color.GREEN)
			_vfx_aoe(px, py, 80.0, Color(1.0, 0.95, 0.5), 0.4)

		1: # Onda Sagrada — proyectil que atraviesa + cura 10% HP
			_player.show_floating_text("🌟 " + skill["name"], Color(1.0, 0.95, 0.6))
			_launch_projectile(_player.global_position, _player.facing_dir,
				580.0, _calc_dmg(1.6), Color(1.0, 0.98, 0.6), true)
			var heal_onda := int(PlayerData.max_hp * 0.10)
			PlayerData.heal(heal_onda)
			_player.show_floating_text("+%d HP" % heal_onda, Color.GREEN)
			_vfx_aoe(px, py, 50.0, Color(0.9, 1.0, 0.6), 0.45)

		2: # Cólera Divina — explosión en radio + cura 20% HP
			_player.show_floating_text("☀️ ¡CÓLERA DIVINA!", Color.GOLD)
			_shake_camera(0.4, 7.0)
			_vfx_aoe(px, py, 230.0, Color(1.0, 0.97, 0.6), 0.75)
			_damage_enemies_radius(Vector2(px, py), 230.0, _calc_dmg(2.5))
			var heal_colera := int(PlayerData.max_hp * 0.20)
			PlayerData.heal(heal_colera)
			_player.show_floating_text("+%d HP" % heal_colera, Color(0.4, 1.0, 0.5))

# ══════════════════════════════════════════════════
# 💀 NECRONOMICÓN (OSCURO)
# ══════════════════════════════════════════════════
func _exec_necronomicon(slot: int, skill: Dictionary) -> void:
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y

	match slot:
		0: # Drenaje de Alma — roba vida
			_player.show_floating_text("💜 " + skill["name"], Color(0.7, 0.3, 1.0))
			var nearest := _nearest_enemy(Vector2(px, py), 400.0)
			if nearest:
				var drain := _calc_dmg(1.0)
				_deal_damage_to(nearest, drain)
				var heal_val := int(drain * 0.5)
				PlayerData.heal(heal_val)
				_player.show_floating_text("+%d HP robado" % heal_val, Color(0.8, 0.4, 1.0))
				_draw_drain_line(_player.global_position, nearest.global_position)
			else:
				_player.show_floating_text("Sin objetivos", Color.GRAY)

		1: # Nube de Plaga — veneno AoE
			_player.show_floating_text("☠️ " + skill["name"], Color(0.4, 0.8, 0.2))
			_vfx_aoe(px, py, 130.0, Color(0.3, 0.7, 0.1), 0.35)
			_damage_enemies_radius(Vector2(px, py), 130.0, _calc_dmg(0.8))
			# Veneno tick
			_apply_poison_zone(Vector2(px, py), 130.0, 4.0)

		2: # Ejército Oscuro — invocar espectros
			_player.show_floating_text("💀 ¡EJÉRCITO OSCURO!", Color(0.5, 0.1, 0.8))
			_spawn_spirits(3, 6.0)

# ─────────────────────────────────────────────────────────────
# HELPERS — Daño y efectos
# ─────────────────────────────────────────────────────────────

func _calc_dmg(multiplier: float) -> int:
	var base := PlayerData.get_total_attack()
	return int(base * multiplier)

func _get_weapon_type() -> String:
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		return ""
	var weapon_item = inv.equipped_items.get("weapon", null)
	if not weapon_item:
		return ""
	return weapon_item.get("weapon_type", "")

func _get_all_enemies() -> Array:
	return get_tree().get_nodes_in_group("enemy")

func _damage_enemies_radius(center: Vector2, radius: float, damage: int) -> void:
	for enemy in _get_all_enemies():
		if not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(center) <= radius:
			_deal_damage_to(enemy, damage)

func _damage_enemies_cone(origin: Vector2, direction: Vector2, range_f: float, angle_deg: float, damage: int) -> void:
	var dir_norm := direction.normalized()
	for enemy in _get_all_enemies():
		if not is_instance_valid(enemy): continue
		var to_enemy: Vector2 = enemy.global_position - origin
		if to_enemy.length() > range_f: continue
		var angle_rad := deg_to_rad(angle_deg * 0.5)
		if dir_norm.dot(to_enemy.normalized()) >= cos(angle_rad):
			_deal_damage_to(enemy, damage)

func _knockback_enemies_cone(origin: Vector2, direction: Vector2, range_f: float, angle_deg: float, force: float) -> void:
	var dir_norm := direction.normalized()
	for enemy in _get_all_enemies():
		if not is_instance_valid(enemy): continue
		var to_enemy: Vector2 = enemy.global_position - origin
		if to_enemy.length() > range_f: continue
		var angle_rad := deg_to_rad(angle_deg * 0.5)
		if dir_norm.dot(to_enemy.normalized()) >= cos(angle_rad):
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(to_enemy.normalized() * force)

func _stun_enemies_radius(center: Vector2, radius: float, duration: float) -> void:
	for enemy in _get_all_enemies():
		if not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(center) <= radius:
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(duration)

func _taunt_enemies_radius(center: Vector2, radius: float) -> void:
	var player_node := get_tree().get_first_node_in_group("player")
	for enemy in _get_all_enemies():
		if not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(center) <= radius:
			if enemy.has_method("force_target"):
				enemy.force_target(player_node)
			# ── Boss: Provocar fuerza el top de threat hacia el Tank ──
			if "boss_mechanics" in enemy and is_instance_valid(enemy.boss_mechanics):
				enemy.boss_mechanics.force_taunt(player_node)

func _deal_damage_to(enemy: Node, damage: int) -> void:
	if enemy.has_method("take_damage"):
		var knockback := Vector2.ZERO
		if is_instance_valid(_player):
			knockback = (enemy.global_position - _player.global_position).normalized()
		enemy.take_damage(damage, knockback)
		# ── Threat de boss: acumula amenaza por daño infligido ──
		if "boss_mechanics" in enemy and is_instance_valid(enemy.boss_mechanics):
			enemy.boss_mechanics.add_threat(_player, float(damage))

func _nearest_enemy(from: Vector2, max_range: float) -> Node:
	var best: Node = null
	var best_dist := max_range
	for enemy in _get_all_enemies():
		if not is_instance_valid(enemy): continue
		var d: float = enemy.global_position.distance_to(from)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best

# ─────────────────────────────────────────────────────────────
# PROYECTILES
# ─────────────────────────────────────────────────────────────
func _launch_projectile(origin: Vector2, direction: Vector2, speed: float, damage: int, color: Color, pierce: bool) -> void:
	var proj := ColorRect.new()
	proj.size    = Vector2(10, 10)
	proj.color   = color
	proj.z_index = 80
	proj.position = origin - proj.size * 0.5
	get_tree().root.add_child(proj)

	var dir_norm  := direction.normalized()
	var max_range := 480.0
	var traveled  := 0.0
	var hit_set   : Array = []

	var tw := proj.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(proj): return
		var step := speed * get_process_delta_time()
		proj.position += dir_norm * step
		traveled += step
		# Detección de enemigos en cada frame del tween
		for enemy in _get_all_enemies():
			if not is_instance_valid(enemy): continue
			if hit_set.has(enemy): continue
			if enemy.global_position.distance_to(proj.position + proj.size * 0.5) < 22.0:
				_deal_damage_to(enemy, damage)
				hit_set.append(enemy)
				if not pierce:
					if is_instance_valid(proj): proj.queue_free()
					return
		if traveled >= max_range:
			if is_instance_valid(proj): proj.queue_free()
	, 0.0, 1.0, max_range / speed)

	tw.tween_property(proj, "modulate:a", 0.0, 0.1)
	tw.tween_callback(func(): if is_instance_valid(proj): proj.queue_free())

# ─────────────────────────────────────────────────────────────
# ESPECTROS (Necronomicón)
# ─────────────────────────────────────────────────────────────
func _spawn_spirits(count: int, duration: float) -> void:
	for i in range(count):
		var spirit := ColorRect.new()
		spirit.size  = Vector2(14, 14)
		spirit.color = Color(0.5, 0.1, 0.9, 0.7)
		spirit.z_index = 75
		var angle := (TAU / count) * i
		spirit.position = _player.global_position + Vector2(cos(angle), sin(angle)) * 45.0 - spirit.size * 0.5
		get_tree().root.call_deferred("add_child", spirit)

		# Movimiento orbital + daño
		var elapsed := 0.0
		var atk_cd  := 0.0

		# Usamos un Timer para el ciclo de vida
		var life_timer := get_tree().create_timer(duration)
		life_timer.timeout.connect(func():
			if is_instance_valid(spirit): spirit.queue_free()
		)

		var orbit_angle := angle
		var spirit_ref  := spirit
		spirit.set_meta("orbit_angle", orbit_angle)
		spirit.set_meta("atk_cd", atk_cd)

		var update_fn: Callable
		update_fn = func(delta: float):
			if not is_instance_valid(spirit_ref) or not is_instance_valid(_player):
				return
			orbit_angle += delta * 2.5
			spirit_ref.position = _player.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * 50.0 - spirit_ref.size * 0.5
			# Ataque automático
			atk_cd -= delta
			if atk_cd <= 0.0:
				atk_cd = 0.8
				var nearest := _nearest_enemy(spirit_ref.position + spirit_ref.size * 0.5, 120.0)
				if nearest:
					_deal_damage_to(nearest, _calc_dmg(0.4))
					_vfx_aoe(nearest.global_position.x, nearest.global_position.y, 18.0, Color(0.6, 0.1, 1.0), 0.15)

		# Timer de movimiento — se añade después de que spirit esté en el árbol
		var tick := Timer.new()
		tick.wait_time = 0.05
		tick.autostart = false
		tick.timeout.connect(func(): update_fn.call(0.05))
		spirit.call_deferred("add_child", tick)
		tick.call_deferred("start")

# ─────────────────────────────────────────────────────────────
# ZONAS DE EFECTO CONTINUO
# ─────────────────────────────────────────────────────────────
func _apply_poison_zone(center: Vector2, radius: float, duration: float) -> void:
	var ticks := int(duration / 0.8)
	for i in range(ticks):
		get_tree().create_timer(0.8 * i).timeout.connect(func():
			_damage_enemies_radius(center, radius, _calc_dmg(0.2))
		)
	# PASO 13 — icono de estado veneno sobre enemigos afectados
	_apply_status_icons_radius(center, radius, "poison", duration)

func _apply_bleed_zone(center: Vector2, duration: float) -> void:
	var ticks := int(duration / 0.6)
	for i in range(ticks):
		get_tree().create_timer(0.6 * i).timeout.connect(func():
			_damage_enemies_radius(center, 40.0, _calc_dmg(0.15))
		)
	# PASO 13 — icono de estado quemado/sangrado sobre enemigos afectados
	_apply_status_icons_radius(center, 40.0, "burn", duration)

# PASO 13 — helper: aplica icono de status a todos los enemigos en radio
func _apply_status_icons_radius(center: Vector2, radius: float, type: String, duration: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e): continue
		if e.global_position.distance_to(center) <= radius:
			if e.has_method("apply_status_icon"):
				e.apply_status_icon(type, duration)


# ─────────────────────────────────────────────────────────────
# VFX
# ─────────────────────────────────────────────────────────────
func _vfx_aoe(px: float, py: float, radius: float, color: Color, alpha: float) -> void:
	var particles := CPUParticles2D.new()
	particles.global_position = Vector2(px, py)
	particles.emitting        = true
	particles.one_shot        = true
	particles.amount          = int(radius * 0.6)
	particles.lifetime        = 0.55
	particles.color           = Color(color.r, color.g, color.b, alpha)
	particles.emission_shape  = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	particles.gravity         = Vector2.ZERO
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 60.0
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.2
	particles.z_index         = 70
	get_tree().root.add_child(particles)
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)

	# PASO 11 — flash de luz del mismo color que las partículas
	var flash_light := PointLight2D.new()
	flash_light.global_position = Vector2(px, py)
	flash_light.color           = Color(color.r, color.g, color.b)
	flash_light.energy          = 1.5
	flash_light.texture_scale   = clampf(radius / 80.0, 0.3, 1.8)
	flash_light.z_index         = 75
	var grad2 := GradientTexture2D.new()
	var g2    := Gradient.new()
	g2.add_point(0.0, Color(1, 1, 1, 1))
	g2.add_point(1.0, Color(1, 1, 1, 0))
	grad2.gradient = g2
	grad2.width    = 256
	grad2.height   = 256
	grad2.fill     = GradientTexture2D.FILL_RADIAL
	flash_light.texture = grad2
	get_tree().root.add_child(flash_light)
	var lt := flash_light.create_tween()
	var lifetime := clampf(radius / 200.0 + 0.2, 0.2, 0.4)
	lt.tween_property(flash_light, "energy", 0.0, lifetime)
	lt.tween_callback(func(): if is_instance_valid(flash_light): flash_light.queue_free())

func _vfx_melee(color: Color, range_f: float) -> void:
	if not _player: return
	var pos: Vector2 = _player.global_position + _player.facing_dir.normalized() * (range_f * 0.5)
	_vfx_aoe(pos.x, pos.y, range_f * 0.5, color, 0.3)

func _draw_drain_line(from: Vector2, to: Vector2) -> void:
	# VFX simple de drenaje con nodos ColorRect pequeños a lo largo de la línea
	var steps := 8
	for i in range(steps):
		var t := float(i) / float(steps)
		var pt := from.lerp(to, t)
		var dot := ColorRect.new()
		dot.size     = Vector2(5, 5)
		dot.color    = Color(0.7, 0.2, 1.0, 0.8)
		dot.position = pt - dot.size * 0.5
		dot.z_index  = 80
		get_tree().root.add_child(dot)
		var delay := float(i) * 0.04
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(dot):
				var tw2 := dot.create_tween()
				tw2.tween_property(dot, "modulate:a", 0.0, 0.3)
				tw2.tween_callback(func(): if is_instance_valid(dot): dot.queue_free())
		)

func _shake_camera(duration: float, intensity: float) -> void:
	if _player and _player.has_method("_shake_camera"):
		_player._shake_camera(duration, intensity)

# ─────────────────────────────────────────────────────────────
# COOLDOWNS Y BUFFS
# ─────────────────────────────────────────────────────────────
func _tick_cooldowns(delta: float) -> void:
	for i in range(3):
		if _cd[i] > 0.0:
			var prev := _cd[i]
			_cd[i] = max(0.0, _cd[i] - delta)
			skill_cooldown_updated.emit(i, _cd[i], _cd_max[i])
			if _cd[i] == 0.0 and prev > 0.0:
				skill_ready.emit(i)

func _tick_buffs(delta: float) -> void:
	# Berserker (axe skill 3)
	if _berserker_active:
		_berserker_timer -= delta
		if _berserker_timer <= 0.0:
			_berserker_active = false
			PlayerData.equipment_attack -= int(PlayerData.get_total_attack() / 1.5 * 0.5)
			PlayerData.stat_updated.emit()
			if _player: _player.show_floating_text("Furia terminó", Color.ORANGE)

	# Postura Defensiva (sword_shield skill 2)
	if _defense_active:
		_defense_timer -= delta
		if _defense_timer <= 0.0:
			_defense_active = false
			PlayerData.equipment_defense -= int(PlayerData.get_total_defense() / 1.4 * 0.4)
			PlayerData.stat_updated.emit()
			if _player: _player.show_floating_text("Postura terminó", Color.CYAN)

	# Bastión de Titanio (mace skill 3)
	if _invul_active:
		_invul_timer -= delta
		if _invul_timer <= 0.0:
			_invul_active = false
			PlayerData.is_dodging = false
			if _player: _player.show_floating_text("Invulnerabilidad terminó", Color.GRAY)

# ─────────────────────────────────────────────────────────────
# CONTRAATAQUE — llamado desde player.gd cuando recibe daño
# ─────────────────────────────────────────────────────────────
func on_player_hit(attacker: Node, incoming_damage: int) -> void:
	if _counter_ready and is_instance_valid(attacker):
		_counter_ready = false
		_player.show_floating_text("⚡ ¡CONTRAATAQUE!", Color.GOLD)
		_deal_damage_to(attacker, int(incoming_damage * 1.5))
		_vfx_aoe(attacker.global_position.x, attacker.global_position.y, 40.0, Color.GOLD, 0.5)

# ─────────────────────────────────────────────────────────────
# CONSULTA DE COOLDOWN (para la UI)
# ─────────────────────────────────────────────────────────────
func get_cooldown(slot: int) -> float:
	return _cd[slot]

func get_cooldown_max(slot: int) -> float:
	return _cd_max[slot]

func get_skill_info(weapon_type: String, slot: int) -> Dictionary:
	if not SKILL_DATA.has(weapon_type): return {}
	var skills: Array = SKILL_DATA[weapon_type]
	if slot >= skills.size(): return {}
	return skills[slot]
