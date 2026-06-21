# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# ARMOR STATS SYSTEM — Autoload global
#
# Genera stats adicionales aleatorias en armaduras y armas
# al ser crafteadas o dropeadas de boss.
#
# Stats disponibles:
#   bonus_def         — DEF plana adicional
#   bonus_atk         — ATK plano adicional
#   bonus_heal_pct    — % curación extra a aliados
#   bonus_max_hp      — HP máx. adicional
#   bonus_speed_pct   — % velocidad de movimiento
#   bonus_crit_pct    — % probabilidad de crítico
#   bonus_dmg_red_pct — % reducción de daño recibido
#   bonus_regen       — Regeneración de HP por segundo
#
# Cantidad de stats extra según calidad:
#   Común      → 0 stats extra
#   Poco Común → 1 stat extra
#   Raro       → 1–2 stats extra
#   Épico      → 2–3 stats extra  (solo drops de boss)
#   Legendario → 3–4 stats extra  (solo drops de boss)
#
# Los valores escalan por tier (T1/T2/T3) y calidad.
# ============================================================

# ── Pool de stats disponibles ────────────────────────────────
# tier_ranges: [min_T1, max_T1, min_T2, max_T2, min_T3, max_T3]
const STAT_POOL: Array = [
	{
		"key":         "bonus_def",
		"label":       "DEF",
		"icon":        "🛡",
		"type":        "flat",
		"tier_ranges": [2, 6,   6, 14,   14, 28],
	},
	{
		"key":         "bonus_atk",
		"label":       "ATK",
		"icon":        "⚔",
		"type":        "flat",
		"tier_ranges": [1, 4,   4, 10,   10, 22],
	},
	{
		"key":         "bonus_heal_pct",
		"label":       "Curación a aliados",
		"icon":        "💚",
		"type":        "pct",
		"tier_ranges": [2, 5,   5, 12,   12, 25],
	},
	{
		"key":         "bonus_max_hp",
		"label":       "HP máx.",
		"icon":        "❤",
		"type":        "flat",
		"tier_ranges": [10, 25,  25, 60,  60, 120],
	},
	{
		"key":         "bonus_speed_pct",
		"label":       "Velocidad",
		"icon":        "💨",
		"type":        "pct",
		"tier_ranges": [2, 5,   5, 10,   10, 20],
	},
	{
		"key":         "bonus_crit_pct",
		"label":       "Crítico",
		"icon":        "🎯",
		"type":        "pct",
		"tier_ranges": [1, 3,   3, 7,    7, 15],
	},
	{
		"key":         "bonus_dmg_red_pct",
		"label":       "Reducción de daño",
		"icon":        "🔰",
		"type":        "pct",
		"tier_ranges": [1, 3,   3, 7,    7, 12],
	},
	{
		"key":         "bonus_regen",
		"label":       "Regen HP/s",
		"icon":        "✨",
		"type":        "flat",
		"tier_ranges": [1, 2,   2, 5,    5, 10],
	},
]

# ── Cuántos stats extra por calidad ──────────────────────────
const BONUS_COUNT_MIN: Dictionary = {
	"common":    0,
	"uncommon":  1,
	"rare":      1,
	"epic":      2,
	"legendary": 3,
}
const BONUS_COUNT_MAX: Dictionary = {
	"common":    0,
	"uncommon":  1,
	"rare":      2,
	"epic":      3,
	"legendary": 4,
}

# ── Multiplicador de valor máximo por calidad ────────────────
const QUALITY_VALUE_MULT: Dictionary = {
	"common":    1.00,
	"uncommon":  1.15,
	"rare":      1.35,
	"epic":      1.65,
	"legendary": 2.10,
}

# ── Durabilidad base por tier ────────────────────────────────
const BASE_DURABILITY: Dictionary = {
	"weapon": [80,  120, 160],
	"armor":  [100, 150, 200],
}

# ─────────────────────────────────────────────────────────────
# ROLL BONUS STATS
# Añade stats adicionales aleatorias al item.
# Llámalo después de QualitySystem.apply_quality().
# ─────────────────────────────────────────────────────────────
func roll_bonus_stats(item: Dictionary) -> Dictionary:
	var quality: String = item.get("quality", "common")
	var tier: int       = clamp(item.get("tier", 1), 1, 3)

	var count_min: int = BONUS_COUNT_MIN.get(quality, 0)
	var count_max: int = BONUS_COUNT_MAX.get(quality, 0)
	var count: int     = randi_range(count_min, count_max)

	if count == 0:
		item["bonus_stats"] = []
		return item

	var q_mult: float = QUALITY_VALUE_MULT.get(quality, 1.0)
	var t_idx: int    = (tier - 1) * 2  # índice en tier_ranges

	# Escoger stats sin repetir
	var available: Array = STAT_POOL.duplicate(true)
	available.shuffle()
	var chosen: Array = available.slice(0, count)

	var bonus_stats: Array = []
	for stat_def in chosen:
		var r: Array      = stat_def["tier_ranges"]
		var base_min: float = float(r[t_idx])
		var base_max: float = float(r[t_idx + 1]) * q_mult
		var val: int      = max(1, int(round(randf_range(base_min, base_max))))

		bonus_stats.append({
			"key":   stat_def["key"],
			"label": stat_def["label"],
			"icon":  stat_def["icon"],
			"type":  stat_def["type"],
			"value": val,
		})

	item["bonus_stats"] = bonus_stats

	# Actualizar descripción con los bonus stats
	_append_bonus_stats_to_desc(item)

	return item

# ─────────────────────────────────────────────────────────────
# ASEGURAR DURABILIDAD
# Garantiza que todo item de equipo tenga durabilidad definida.
# Llámalo sobre cualquier item antes de añadirlo al inventario.
# ─────────────────────────────────────────────────────────────
func ensure_durability(item: Dictionary) -> Dictionary:
	var tier: int     = clamp(item.get("tier", 1), 1, 3)
	var category: String = item.get("category", "armor")
	var quality: String  = item.get("quality", "common")

	if not item.has("max_durability") or item.get("max_durability", 0) <= 0:
		var dur_table: Array = BASE_DURABILITY.get(category, BASE_DURABILITY["armor"])
		var base_dur: int    = dur_table[tier - 1]
		# Calidades mayores → más durabilidad (bonus parcial del mult de calidad)
		var q_mult: float = QUALITY_VALUE_MULT.get(quality, 1.0)
		base_dur = max(50, int(round(base_dur * (1.0 + (q_mult - 1.0) * 0.5))))
		item["max_durability"] = base_dur
		item["durability"]     = base_dur
	elif not item.has("durability"):
		item["durability"] = item["max_durability"]

	return item

# ─────────────────────────────────────────────────────────────
# OBTENER LÍNEAS DE TEXTO DE BONUS STATS (para UI/tooltip)
# ─────────────────────────────────────────────────────────────
func get_bonus_stats_lines(item: Dictionary) -> Array:
	var lines: Array = []
	for bs in item.get("bonus_stats", []):
		var suffix: String = "%" if bs.get("type") == "pct" else ""
		lines.append("%s %s +%d%s" % [bs["icon"], bs["label"], bs["value"], suffix])
	return lines

# ─────────────────────────────────────────────────────────────
# OBTENER VALOR DE UN STAT BONUS ESPECÍFICO
# Útil para que player.gd o combat pueda leer los stats
# ─────────────────────────────────────────────────────────────
func get_bonus_value(item: Dictionary, stat_key: String) -> int:
	for bs in item.get("bonus_stats", []):
		if bs.get("key") == stat_key:
			return bs.get("value", 0)
	return 0

# ── Suma todos los bonus de un stat de todos los items equipados ──
func sum_bonus_from_equipment(equipped_items: Array, stat_key: String) -> int:
	var total: int = 0
	for item in equipped_items:
		if item is Dictionary:
			total += get_bonus_value(item, stat_key)
	return total

# ─────────────────────────────────────────────────────────────
# INTERNO — Añade los bonus stats a la desc del item
# ─────────────────────────────────────────────────────────────
func _append_bonus_stats_to_desc(item: Dictionary) -> void:
	var lines: Array = get_bonus_stats_lines(item)
	if lines.is_empty():
		return
	var extra: String = "\n" + "\n".join(lines)
	item["desc"] = item.get("desc", "") + extra
