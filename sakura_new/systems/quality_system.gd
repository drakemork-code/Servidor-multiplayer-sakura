# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# QUALITY SYSTEM — Autoload global
#
# Calidades aplicables a armas y armaduras crafteadas:
#   Común       (common)     — base
#   Poco Común  (uncommon)   — base ×1.15
#   Raro        (rare)       — base ×1.35  ← crafteable (máximo crafteable)
#   Épico       (epic)       — base ×1.65  ← NO crafteable (solo drops de boss)
#   Legendario  (legendary)  — base ×2.10  ← NO crafteable (solo drops de boss)
#
# Probabilidades al craftear según maestría (craft_skill_level 1-15):
#   Nivel 1  → Común 89%  | PocoCom 10%  | Raro 1%
#   Nivel 5  → Común 79%  | PocoCom 16%  | Raro 5%
#   Nivel 10 → Común 65%  | PocoCom 24%  | Raro 11%
#   Nivel 15 → Común 52%  | PocoCom 32%  | Raro 16%
#
# Épico y Legendario NUNCA se craftean — solo se obtienen como drops de boss.
# ============================================================

# ── Multiplicadores de stats por calidad ────────────────────
const QUALITY_MULT: Dictionary = {
	"common":    1.00,
	"uncommon":  1.15,
	"rare":      1.35,
	"epic":      1.65,
	"legendary": 2.10,
}

# ── Colores de calidad (iguales a get_rarity_color en InventoryManager) ──
const QUALITY_COLOR: Dictionary = {
	"common":    Color(0.67, 0.67, 0.67),
	"uncommon":  Color(0.20, 0.87, 0.40),
	"rare":      Color(0.27, 0.60, 1.00),
	"epic":      Color(0.80, 0.33, 1.00),
	"legendary": Color(1.00, 0.67, 0.20),
}

# ── Nombres de calidad en español ───────────────────────────
const QUALITY_NAME: Dictionary = {
	"common":    "Común",
	"uncommon":  "Poco Común",
	"rare":      "Raro",
	"epic":      "Épico",
	"legendary": "Legendario",
}

# ── Prefijos de nombre para calidades superiores ────────────
const QUALITY_PREFIX: Dictionary = {
	"common":    "",
	"uncommon":  "Refinado ",
	"rare":      "Élite ",
	"epic":      "Épico ",
	"legendary": "Legendario ",
}

# ── Emojis de calidad ────────────────────────────────────────
const QUALITY_ICON: Dictionary = {
	"common":    "⬜",
	"uncommon":  "🟩",
	"rare":      "🟦",
	"epic":      "🟪",
	"legendary": "🟧",
}

# ──────────────────────────────────────────────
# TIRADA DE CALIDAD
# Recibe el nivel de skill de crafteo (1-15)
# Devuelve una String de calidad
# ──────────────────────────────────────────────

func roll_quality(craft_skill_level: int) -> String:
	# Probabilidades base (porcentaje × 100 para evitar float)
	# Formato: [common, uncommon, rare]
	# Épico y Legendario NUNCA se craftean — solo drops de boss
	var lv: int = clamp(craft_skill_level, 1, 15)

	# Interpolación lineal entre nivel 1 y nivel 15
	# Nivel 1:  [8900, 1000, 100]  (suma 10000)
	# Nivel 15: [5200, 3200, 1600] (suma 10000)
	var t: float = float(lv - 1) / 14.0  # 0.0 en lv1, 1.0 en lv15

	var p_common:   int = int(lerp(8900.0, 5200.0, t))
	var p_uncommon: int = int(lerp(1000.0, 3200.0, t))
	var p_rare:     int = int(lerp(100.0,  1600.0, t))

	# Ajuste para que sumen exactamente 10000
	var total: int = p_common + p_uncommon + p_rare
	p_common += (10000 - total)  # el resto se lo lleva común

	var roll: int = randi_range(0, 9999)
	if roll < p_rare:
		return "rare"
	roll -= p_rare
	if roll < p_uncommon:
		return "uncommon"
	return "common"

# ──────────────────────────────────────────────
# APLICAR CALIDAD A UN ITEM INSTANCIA
# Recibe el dict base del item y la calidad,
# devuelve un dict nuevo con stats modificados.
# ──────────────────────────────────────────────

func apply_quality(base_item: Dictionary, quality: String) -> Dictionary:
	var item: Dictionary = base_item.duplicate(true)
	item["quality"] = quality

	var mult: float = QUALITY_MULT.get(quality, 1.0)

	# Aplicar multiplicador a stats de combate
	if item.has("atk") and item["atk"] > 0:
		item["atk"] = max(1, int(round(item["atk"] * mult)))
	if item.has("def") and item["def"] > 0:
		item["def"] = max(1, int(round(item["def"] * mult)))

	# Modificar durabilidad: calidades altas = más durable
	if item.has("max_durability"):
		var dur_mult: float = 1.0 + (mult - 1.0) * 0.5  # mitad del bonus va a durabilidad
		item["max_durability"] = max(50, int(round(item["max_durability"] * dur_mult)))
		item["durability"]     = item["max_durability"]

	# Actualizar nombre con prefijo
	var prefix: String = QUALITY_PREFIX.get(quality, "")
	if prefix != "":
		# Solo añadir prefijo si no lo tiene ya
		var base_name: String = item.get("name", "")
		if not base_name.begins_with(prefix):
			item["name"] = prefix + base_name

	# Actualizar desc con nota de calidad
	var q_name: String = QUALITY_NAME.get(quality, quality)
	var q_icon: String = QUALITY_ICON.get(quality, "")
	item["desc"] = item.get("desc", item.get("description", "")) + \
		"\n%s Calidad: %s" % [q_icon, q_name]

	return item

# ──────────────────────────────────────────────
# HELPERS UI
# ──────────────────────────────────────────────

func get_quality_color(quality: String) -> Color:
	return QUALITY_COLOR.get(quality, Color.WHITE)

func get_quality_name(quality: String) -> String:
	return QUALITY_NAME.get(quality, quality.capitalize())

func get_quality_icon(quality: String) -> String:
	return QUALITY_ICON.get(quality, "")

## Texto de probabilidades para mostrar en UI según nivel de skill
## Solo muestra Común, Poco Común y Raro (Épico y Legendario = solo drops)
func get_probability_text(craft_skill_level: int) -> String:
	var lv: int = clamp(craft_skill_level, 1, 15)
	var t: float = float(lv - 1) / 14.0
	var p_c: int = int(lerp(8900.0, 5200.0, t))
	var p_u: int = int(lerp(1000.0, 3200.0, t))
	var p_r: int = int(lerp(100.0,  1600.0, t))
	var total: int = p_c + p_u + p_r
	p_c += (10000 - total)
	return "⬜%.1f%%  🟩%.1f%%  🟦%.1f%%  🟪Drop  🟧Drop" % [
		p_c / 100.0, p_u / 100.0, p_r / 100.0
	]
