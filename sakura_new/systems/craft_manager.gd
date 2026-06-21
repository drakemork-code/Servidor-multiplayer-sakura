# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# CRAFT MANAGER — Autoload global
# Sistema de crafteo con:
#   • Niveles y XP de crafteo por profesión (smithing/tailoring/alchemy)
#   • Nivel mínimo de crafteo requerido por receta
#   • Tier de receta (T1/T2/T3) mapeado a nivel mínimo de skill
#   • XP otorgada al craftear según tier de la receta
# ============================================================

signal craft_success(result_key: String, recipe: Dictionary)
signal craft_failed(reason: String)

# ── Mapa: shop_id → skill de crafteo ───────────────────────
const SHOP_CRAFT_SKILL: Dictionary = {
	"forge":      "smithing",
	"tailor":     "tailoring",
	"herbalist":  "alchemy",
}

# ── Nivel mínimo de skill de crafteo por tier de receta ────
# T1: nivel 1-4   T2: nivel 5-9   T3: nivel 10+
const CRAFT_TIER_MIN_LEVEL: Dictionary = {
	1: 1,
	2: 5,
	3: 10,
}

# ── XP de crafteo otorgada al fabricar por tier ────────────
const CRAFT_XP_BY_TIER: Dictionary = {
	1: 30,
	2: 75,
	3: 150,
}

# ──────────────────────────────────────────────
# RECETAS
# Formato:
#   name, result_qty, required_level (nivel personaje),
#   craft_skill_level (nivel de skill de crafteo requerido),
#   craft_tier (1/2/3 — determina XP ganada y tier visual),
#   shop_ids, category, ingredients, desc, icon
# ──────────────────────────────────────────────

const RECIPES: Dictionary = {
	# ══════════════════════════════════════════
	# HERBOLARIO — skill: alchemy
	# ══════════════════════════════════════════

	# T1 — Alchemy nivel 1+
	"consumable_health_potion": {
		"name": "Poción de Vida",
		"result_qty": 1,
		"required_level": 1,
		"craft_skill_level": 1,
		"craft_tier": 1,
		"shop_ids": ["herbalist"],
		"category": "consumable",
		"ingredients": [
			{"key": "material_herb",     "qty": 2},
			{"key": "material_mushroom", "qty": 1},
		],
		"desc": "Restaura 80 HP al usarse.",
		"icon": "🧪"
	},
	"consumable_energy_potion": {
		"name": "Poción de Energía",
		"result_qty": 1,
		"required_level": 1,
		"craft_skill_level": 1,
		"craft_tier": 1,
		"shop_ids": ["herbalist"],
		"category": "consumable",
		"ingredients": [
			{"key": "material_herb",     "qty": 1},
			{"key": "material_mushroom", "qty": 2},
		],
		"desc": "Restaura 50 de energía.",
		"icon": "💧"
	},
	"consumable_antidote": {
		"name": "Antídoto",
		"result_qty": 1,
		"required_level": 3,
		"craft_skill_level": 3,
		"craft_tier": 1,
		"shop_ids": ["herbalist"],
		"category": "consumable",
		"ingredients": [
			{"key": "material_herb",       "qty": 3},
			{"key": "material_slime_gel",  "qty": 1},
		],
		"desc": "Elimina efectos de veneno.",
		"icon": "💚"
	},

	# T2 — Alchemy nivel 5+
	"consumable_greater_health_potion": {
		"name": "Poción de Vida Mayor",
		"result_qty": 1,
		"required_level": 5,
		"craft_skill_level": 5,
		"craft_tier": 2,
		"shop_ids": ["herbalist"],
		"category": "consumable",
		"ingredients": [
			{"key": "material_herb",       "qty": 4},
			{"key": "material_mushroom",   "qty": 2},
			{"key": "material_slime_gel",  "qty": 1},
		],
		"desc": "Restaura 200 HP al usarse.",
		"icon": "🧪"
	},
	"consumable_elixir_strength": {
		"name": "Elixir de Fuerza",
		"result_qty": 1,
		"required_level": 6,
		"craft_skill_level": 6,
		"craft_tier": 2,
		"shop_ids": ["herbalist"],
		"category": "consumable",
		"ingredients": [
			{"key": "material_herb",        "qty": 3},
			{"key": "material_shadow_essence", "qty": 1},
			{"key": "material_mushroom",    "qty": 2},
		],
		"desc": "ATK+15 durante 60s.",
		"icon": "⚗️"
	},

	# T3 — Alchemy nivel 10+
	"consumable_resurrection_elixir": {
		"name": "Elixir de Resurrección",
		"result_qty": 1,
		"required_level": 10,
		"craft_skill_level": 10,
		"craft_tier": 3,
		"shop_ids": ["herbalist"],
		"category": "consumable",
		"ingredients": [
			{"key": "material_herb",           "qty": 5},
			{"key": "material_shadow_essence", "qty": 3},
			{"key": "material_mushroom",       "qty": 3},
			{"key": "ore_bluestone_t3",           "qty": 1},
		],
		"desc": "Revive con HP completo al morir (uso único).",
		"icon": "✨"
	},

	# ══════════════════════════════════════════
	# FORJA — skill: smithing
	# ══════════════════════════════════════════

	# T1 — Smithing nivel 1+
	"armor_leather_chest": {
		"name": "Peto de Cuero",
		"result_qty": 1,
		"required_level": 3,
		"craft_skill_level": 3,
		"craft_tier": 1,
		"shop_ids": ["forge"],
		"category": "armor",
		"ingredients": [
			{"key": "material_orc_hide", "qty": 3},
			{"key": "ore_iron_t1",          "qty": 2},
			{"key": "ore_coal_t1",          "qty": 1},
		],
		"desc": "Armadura de cuero reforzado. DEF+8.",
		"icon": "🥋"
	},
	"weapon_iron_sword": {
		"name": "Espada de Hierro",
		"result_qty": 1,
		"required_level": 4,
		"craft_skill_level": 4,
		"craft_tier": 1,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_iron_t1",    "qty": 4},
			{"key": "ore_coal_t1",    "qty": 2},
			{"key": "wood_log",    "qty": 1},
		],
		"desc": "Espada sólida de hierro. ATK+18.",
		"icon": "⚔"
	},

	# T2 — Smithing nivel 5+  (ore_silver reemplaza ore_steel)
	"weapon_steel_sword": {
		"name": "Espada de Plata",
		"result_qty": 1,
		"required_level": 7,
		"craft_skill_level": 5,
		"craft_tier": 2,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_silver_t2",  "qty": 4},
			{"key": "ore_coal_t2",    "qty": 3},
			{"key": "wood_log",    "qty": 2},
			{"key": "ore_iron_t2",    "qty": 2},
		],
		"desc": "Espada de plata templada. ATK+32.",
		"icon": "⚔"
	},
	"armor_steel_chest": {
		"name": "Peto de Plata",
		"result_qty": 1,
		"required_level": 8,
		"craft_skill_level": 6,
		"craft_tier": 2,
		"shop_ids": ["forge"],
		"category": "armor",
		"ingredients": [
			{"key": "ore_silver_t2",        "qty": 5},
			{"key": "ore_coal_t2",          "qty": 3},
			{"key": "material_orc_hide", "qty": 2},
		],
		"desc": "Armadura de plata. DEF+20.",
		"icon": "🛡"
	},
	"armor_shadow_gauntlets": {
		"name": "Guanteletes de Sombra",
		"result_qty": 1,
		"required_level": 8,
		"craft_skill_level": 7,
		"craft_tier": 2,
		"shop_ids": ["forge"],
		"category": "armor",
		"ingredients": [
			{"key": "material_shadow_essence", "qty": 2},
			{"key": "ore_iron_t2",                "qty": 3},
			{"key": "ore_silver_t2",              "qty": 2},
			{"key": "ore_coal_t2",                "qty": 2},
		],
		"desc": "Forjados con esencia oscura. ATK+8 DEF+12.",
		"icon": "🥊"
	},

	# T3 — Smithing nivel 10+  (ore_gold reemplaza ore_mithril; ore_bluestone para tier épico)
	"weapon_mithril_sword": {
		"name": "Espada de Oro",
		"result_qty": 1,
		"required_level": 13,
		"craft_skill_level": 10,
		"craft_tier": 3,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_gold_t3",                "qty": 5},
			{"key": "ore_silver_t3",              "qty": 3},
			{"key": "material_shadow_essence", "qty": 2},
			{"key": "ore_coal_t3",                "qty": 4},
			{"key": "wood_log",                "qty": 2},
		],
		"desc": "Espada de oro puro. ATK+55.",
		"icon": "⚔"
	},
	"armor_mithril_chest": {
		"name": "Peto de Oro",
		"result_qty": 1,
		"required_level": 14,
		"craft_skill_level": 11,
		"craft_tier": 3,
		"shop_ids": ["forge"],
		"category": "armor",
		"ingredients": [
			{"key": "ore_gold_t3",                "qty": 6},
			{"key": "ore_silver_t3",              "qty": 3},
			{"key": "material_shadow_essence", "qty": 3},
			{"key": "ore_coal_t3",                "qty": 5},
		],
		"desc": "Armadura legendaria de oro. DEF+45.",
		"icon": "🛡"
	},
	"weapon_bluestone_sword": {
		"name": "Espada Arcana",
		"result_qty": 1,
		"required_level": 16,
		"craft_skill_level": 13,
		"craft_tier": 3,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_bluestone_t3",           "qty": 4},
			{"key": "ore_gold_t3",                "qty": 3},
			{"key": "material_shadow_essence", "qty": 4},
			{"key": "crystal_shard",           "qty": 3},
		],
		"desc": "Forjada con piedra azul arcana. ATK+75 y +15% daño mágico.",
		"icon": "⚔"
	},
	"armor_bluestone_chest": {
		"name": "Peto Arcano",
		"result_qty": 1,
		"required_level": 17,
		"craft_skill_level": 14,
		"craft_tier": 3,
		"shop_ids": ["forge"],
		"category": "armor",
		"ingredients": [
			{"key": "ore_bluestone_t3",           "qty": 5},
			{"key": "ore_gold_t3",                "qty": 4},
			{"key": "material_shadow_essence", "qty": 3},
			{"key": "ore_coal_t3",                "qty": 6},
		],
		"desc": "Armadura arcana imbuida de magia. DEF+60 y resistencia mágica.",
		"icon": "🛡"
	},

	# ══════════════════════════════════════════
	# HERBOLARIO (HERBALIST) — skill: alchemy
	# ESPADA SAGRADA DE 2 MANOS — greatsword_holy
	# Crafteable en el herbalist porque combina forja con maná sagrado
	# ══════════════════════════════════════════

	# T1 — Alchemy nivel 3+  (acceso temprano, arma híbrida)
	"weapon_greatsword_holy_t1": {
		"name": "Espada Santa",
		"result_qty": 1,
		"required_level": 5,
		"craft_skill_level": 3,
		"craft_tier": 1,
		"shop_ids": ["herbalist"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_iron_t1",          "qty": 4},
			{"key": "ore_coal_t1",          "qty": 2},
			{"key": "material_herb",     "qty": 3},
			{"key": "wood_log",          "qty": 2},
		],
		"desc": "Espada sagrada de dos manos. ATK+16 y cura leve al atacar.",
		"icon": "✝️"
	},

	# T2 — Alchemy nivel 6+
	"weapon_greatsword_holy_t2": {
		"name": "Espada de la Redención",
		"result_qty": 1,
		"required_level": 9,
		"craft_skill_level": 6,
		"craft_tier": 2,
		"shop_ids": ["herbalist"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_silver_t2",              "qty": 4},
			{"key": "ore_coal_t2",                "qty": 3},
			{"key": "material_herb",           "qty": 4},
			{"key": "material_shadow_essence", "qty": 1},
			{"key": "wood_log",                "qty": 2},
		],
		"desc": "Espada sagrada templada. ATK+34 y curación mayor al atacar.",
		"icon": "✝️"
	},

	# T3 — Alchemy nivel 10+
	"weapon_greatsword_holy_t3": {
		"name": "Espada del Juicio Eterno",
		"result_qty": 1,
		"required_level": 14,
		"craft_skill_level": 10,
		"craft_tier": 3,
		"shop_ids": ["herbalist"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_gold_t3",                "qty": 4},
			{"key": "ore_silver_t3",              "qty": 3},
			{"key": "material_herb",           "qty": 5},
			{"key": "material_shadow_essence", "qty": 2},
			{"key": "ore_bluestone_t3",           "qty": 2},
			{"key": "crystal_shard",           "qty": 2},
		],
		"desc": "Arma legendaria de maná sagrado. ATK+62 y restaura vida con cada impacto.",
		"icon": "✝️"
	},

	# ══════════════════════════════════════════
	# SASTRE — skill: tailoring
	# ══════════════════════════════════════════

	# T1 — Tailoring nivel 1+
	"boots_leather": {
		"name": "Botas de Cuero",
		"result_qty": 1,
		"required_level": 2,
		"craft_skill_level": 1,
		"craft_tier": 1,
		"shop_ids": ["tailor"],
		"category": "armor",
		"ingredients": [
			{"key": "material_orc_hide", "qty": 2},
			{"key": "wood_log",          "qty": 1},
		],
		"desc": "Botas ligeras. +10% velocidad de movimiento.",
		"icon": "👢"
	},
	"gloves_leather": {
		"name": "Guantes de Cuero",
		"result_qty": 1,
		"required_level": 2,
		"craft_skill_level": 1,
		"craft_tier": 1,
		"shop_ids": ["tailor"],
		"category": "armor",
		"ingredients": [
			{"key": "material_orc_hide", "qty": 2},
		],
		"desc": "Guantes básicos de cuero. DEF+3.",
		"icon": "🧤"
	},
	"hood_cloth": {
		"name": "Capucha de Tela",
		"result_qty": 1,
		"required_level": 3,
		"craft_skill_level": 2,
		"craft_tier": 1,
		"shop_ids": ["tailor"],
		"category": "armor",
		"ingredients": [
			{"key": "material_orc_hide", "qty": 3},
			{"key": "material_herb",     "qty": 1},
		],
		"desc": "Capucha ligera. DEF+4.",
		"icon": "🎩"
	},

	# T2 — Tailoring nivel 5+
	"boots_steel": {
		"name": "Botas de Plata",
		"result_qty": 1,
		"required_level": 7,
		"craft_skill_level": 5,
		"craft_tier": 2,
		"shop_ids": ["tailor"],
		"category": "armor",
		"ingredients": [
			{"key": "ore_silver_t2",        "qty": 2},
			{"key": "ore_coal_t2",          "qty": 2},
			{"key": "material_orc_hide", "qty": 3},
		],
		"desc": "Botas reforzadas de plata. DEF+10 +15% velocidad.",
		"icon": "👢"
	},
	"cloak_shadow": {
		"name": "Capa de las Sombras",
		"result_qty": 1,
		"required_level": 9,
		"craft_skill_level": 7,
		"craft_tier": 2,
		"shop_ids": ["tailor"],
		"category": "armor",
		"ingredients": [
			{"key": "material_shadow_essence", "qty": 2},
			{"key": "material_orc_hide",       "qty": 4},
		],
		"desc": "Capa mística. DEF+15 y reduce agro de enemigos.",
		"icon": "🧥"
	},

	# T3 — Tailoring nivel 10+
	"boots_mithril": {
		"name": "Botas de Oro",
		"result_qty": 1,
		"required_level": 13,
		"craft_skill_level": 10,
		"craft_tier": 3,
		"shop_ids": ["tailor"],
		"category": "armor",
		"ingredients": [
			{"key": "ore_gold_t3",                "qty": 3},
			{"key": "ore_silver_t3",              "qty": 2},
			{"key": "material_shadow_essence", "qty": 2},
			{"key": "material_orc_hide",       "qty": 2},
		],
		"desc": "Botas legendarias de oro. DEF+25 +25% velocidad.",
		"icon": "👢"
	},
	"boots_arcane": {
		"name": "Botas Arcanas",
		"result_qty": 1,
		"required_level": 16,
		"craft_skill_level": 13,
		"craft_tier": 3,
		"shop_ids": ["tailor"],
		"category": "armor",
		"ingredients": [
			{"key": "ore_bluestone_t3",           "qty": 3},
			{"key": "ore_gold_t3",                "qty": 2},
			{"key": "material_shadow_essence", "qty": 3},
			{"key": "crystal_shard",           "qty": 2},
		],
		"desc": "Botas arcanas de piedra azul. DEF+35 +35% velocidad y levitación.",
		"icon": "👢"
	},

	# ══════════════════════════════════════════
	# FORJA — ARCO (BOW) — skill: smithing
	# T1 ya existe en inventario como weapon_bow (ATK 11)
	# ══════════════════════════════════════════

	# T1 — Smithing nivel 1+
	"weapon_bow": {
		"name": "Arco de Madera",
		"result_qty": 1,
		"required_level": 3,
		"craft_skill_level": 1,
		"craft_tier": 1,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "wood_log",       "qty": 4},
			{"key": "ore_iron_t1",    "qty": 2},
			{"key": "ore_coal_t1",    "qty": 1},
		],
		"desc": "Arco básico de madera y cuerda de hierro. ATK+11.",
		"icon": "🏹"
	},

	# T2 — Smithing nivel 5+
	"weapon_bow_t2": {
		"name": "Arco de Plata",
		"result_qty": 1,
		"required_level": 7,
		"craft_skill_level": 5,
		"craft_tier": 2,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "wood_log",        "qty": 5},
			{"key": "ore_silver_t2",   "qty": 3},
			{"key": "ore_coal_t2",     "qty": 2},
			{"key": "ore_iron_t2",     "qty": 2},
		],
		"desc": "Arco reforzado con hilos de plata. ATK+28.",
		"icon": "🏹"
	},

	# T3 — Smithing nivel 10+
	"weapon_bow_t3": {
		"name": "Arco Dorado",
		"result_qty": 1,
		"required_level": 13,
		"craft_skill_level": 10,
		"craft_tier": 3,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "wood_log",                "qty": 5},
			{"key": "ore_gold_t3",             "qty": 4},
			{"key": "ore_silver_t3",           "qty": 3},
			{"key": "material_shadow_essence", "qty": 2},
			{"key": "ore_coal_t3",             "qty": 3},
		],
		"desc": "Arco imbuido de oro forjado. ATK+50.",
		"icon": "🏹"
	},

	# ══════════════════════════════════════════
	# FORJA — MAZA (MACE) — skill: smithing
	# T1 ya existe en inventario como weapon_mace (ATK 16)
	# ══════════════════════════════════════════

	# T1 — Smithing nivel 1+
	"weapon_mace": {
		"name": "Maza de Hierro",
		"result_qty": 1,
		"required_level": 4,
		"craft_skill_level": 2,
		"craft_tier": 1,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_iron_t1",    "qty": 5},
			{"key": "ore_coal_t1",    "qty": 2},
			{"key": "ore_stone_t1",   "qty": 2},
			{"key": "wood_log",       "qty": 1},
		],
		"desc": "Maza pesada de hierro. ATK+16.",
		"icon": "🔨"
	},

	# T2 — Smithing nivel 5+
	"weapon_mace_t2": {
		"name": "Maza de Plata",
		"result_qty": 1,
		"required_level": 8,
		"craft_skill_level": 5,
		"craft_tier": 2,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_silver_t2",  "qty": 4},
			{"key": "ore_iron_t2",    "qty": 3},
			{"key": "ore_coal_t2",    "qty": 2},
			{"key": "ore_stone_t2",   "qty": 2},
		],
		"desc": "Maza reforzada de plata templada. ATK+32.",
		"icon": "🔨"
	},

	# T3 — Smithing nivel 10+
	"weapon_mace_t3": {
		"name": "Maza de Oro Macizo",
		"result_qty": 1,
		"required_level": 14,
		"craft_skill_level": 11,
		"craft_tier": 3,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_gold_t3",             "qty": 5},
			{"key": "ore_silver_t3",           "qty": 4},
			{"key": "ore_coal_t3",             "qty": 3},
			{"key": "material_shadow_essence", "qty": 2},
			{"key": "ore_stone_t3",            "qty": 3},
		],
		"desc": "Maza devastadora de oro macizo. ATK+52.",
		"icon": "🔨"
	},

	# ══════════════════════════════════════════
	# HERBOLARIO — BASTÓN SAGRADO (STAFF_HOLY) — skill: alchemy
	# T1 ya existe en inventario como weapon_staff_holy (ATK 8)
	# ══════════════════════════════════════════

	# T1 — Alchemy nivel 1+
	"weapon_staff_holy": {
		"name": "Bastón Sagrado",
		"result_qty": 1,
		"required_level": 3,
		"craft_skill_level": 2,
		"craft_tier": 1,
		"shop_ids": ["herbalist"],
		"category": "weapon",
		"ingredients": [
			{"key": "wood_log",       "qty": 4},
			{"key": "material_herb",  "qty": 3},
			{"key": "ore_iron_t1",    "qty": 1},
		],
		"desc": "Bastón de luz sagrada. ATK+8, cura aliados cercanos al atacar.",
		"icon": "✨"
	},

	# T2 — Alchemy nivel 5+
	"weapon_staff_holy_t2": {
		"name": "Bastón de la Gracia",
		"result_qty": 1,
		"required_level": 8,
		"craft_skill_level": 5,
		"craft_tier": 2,
		"shop_ids": ["herbalist"],
		"category": "weapon",
		"ingredients": [
			{"key": "wood_log",                "qty": 4},
			{"key": "material_herb",           "qty": 5},
			{"key": "ore_silver_t2",           "qty": 3},
			{"key": "material_shadow_essence", "qty": 1},
			{"key": "ore_coal_t2",             "qty": 2},
		],
		"desc": "Bastón sagrado imbuido de plata. ATK+22, curación mayor en área.",
		"icon": "✨"
	},

	# T3 — Alchemy nivel 10+
	"weapon_staff_holy_t3": {
		"name": "Bastón de la Redención Eterna",
		"result_qty": 1,
		"required_level": 14,
		"craft_skill_level": 10,
		"craft_tier": 3,
		"shop_ids": ["herbalist"],
		"category": "weapon",
		"ingredients": [
			{"key": "wood_log",                "qty": 4},
			{"key": "material_herb",           "qty": 6},
			{"key": "ore_gold_t3",             "qty": 4},
			{"key": "material_shadow_essence", "qty": 3},
			{"key": "ore_bluestone_t3",        "qty": 2},
			{"key": "crystal_shard",           "qty": 2},
		],
		"desc": "Bastón de luz divina. ATK+40, restaura HP masivo a aliados cercanos.",
		"icon": "✨"
	},

	# ══════════════════════════════════════════
	# FORJA — HACHA (AXE) — skill: smithing
	# T1 ya existe en inventario como weapon_crude_axe (ATK 8)
	# ══════════════════════════════════════════

	# T1 — Smithing nivel 1+
	"weapon_crude_axe": {
		"name": "Hacha de Piedra",
		"result_qty": 1,
		"required_level": 2,
		"craft_skill_level": 1,
		"craft_tier": 1,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_stone_t1",  "qty": 4},
			{"key": "ore_coal_t1",   "qty": 1},
			{"key": "wood_log",      "qty": 2},
		],
		"desc": "Hacha tosca de piedra y madera. ATK+8.",
		"icon": "🪓"
	},

	# T2 — Smithing nivel 5+
	"weapon_axe_t2": {
		"name": "Hacha de Hierro",
		"result_qty": 1,
		"required_level": 7,
		"craft_skill_level": 5,
		"craft_tier": 2,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_iron_t2",   "qty": 5},
			{"key": "ore_coal_t2",   "qty": 3},
			{"key": "wood_log",      "qty": 2},
			{"key": "ore_stone_t2",  "qty": 2},
		],
		"desc": "Hacha de hierro afilado. ATK+26.",
		"icon": "🪓"
	},

	# T3 — Smithing nivel 10+
	"weapon_axe_t3": {
		"name": "Hacha de Plata Rúnica",
		"result_qty": 1,
		"required_level": 13,
		"craft_skill_level": 10,
		"craft_tier": 3,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "ore_silver_t3",           "qty": 4},
			{"key": "ore_gold_t3",             "qty": 3},
			{"key": "ore_coal_t3",             "qty": 4},
			{"key": "material_shadow_essence", "qty": 2},
			{"key": "wood_log",                "qty": 2},
		],
		"desc": "Hacha rúnica con filo de plata. ATK+48.",
		"icon": "🪓"
	},

	# ══════════════════════════════════════════
	# FORJA — NECRONOMICON — skill: smithing
	# T2 ya existe en inventario como weapon_necronomicon (ATK 18)
	# Se añaden T1 y T3
	# ══════════════════════════════════════════

	# T1 — Smithing nivel 3+  (grimorio oscuro básico)
	"weapon_necronomicon_t1": {
		"name": "Grimorio Sombrío",
		"result_qty": 1,
		"required_level": 5,
		"craft_skill_level": 3,
		"craft_tier": 1,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "material_bone",   "qty": 4},
			{"key": "ore_iron_t1",     "qty": 2},
			{"key": "ore_coal_t1",     "qty": 2},
			{"key": "wood_log",        "qty": 1},
		],
		"desc": "Grimorio forjado con huesos oscuros. ATK+10.",
		"icon": "📖"
	},

	# T2: weapon_necronomicon ya existe en inventory_manager — no se añade aquí
	# como receta de crafteo porque es un drop raro; pero sí se puede forjar:
	"weapon_necronomicon": {
		"name": "Necronomicón",
		"result_qty": 1,
		"required_level": 9,
		"craft_skill_level": 6,
		"craft_tier": 2,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "material_bone",           "qty": 6},
			{"key": "ore_silver_t2",           "qty": 3},
			{"key": "ore_coal_t2",             "qty": 3},
			{"key": "material_shadow_essence", "qty": 2},
		],
		"desc": "Grimorio de poder oscuro. ATK+18.",
		"icon": "📖"
	},

	# T3 — Smithing nivel 10+
	"weapon_necronomicon_t3": {
		"name": "Necronomicón Abismal",
		"result_qty": 1,
		"required_level": 14,
		"craft_skill_level": 12,
		"craft_tier": 3,
		"shop_ids": ["forge"],
		"category": "weapon",
		"ingredients": [
			{"key": "material_bone",           "qty": 8},
			{"key": "ore_gold_t3",             "qty": 4},
			{"key": "ore_silver_t3",           "qty": 3},
			{"key": "material_shadow_essence", "qty": 4},
			{"key": "ore_bluestone_t3",        "qty": 2},
			{"key": "crystal_shard",           "qty": 2},
		],
		"desc": "Grimorio de poder abismal. ATK+46 y +20% daño de hechizos oscuros.",
		"icon": "📖"
	},

	# ══════════════════════════════════════════
	# HERRAMIENTAS — FORJA — skill: smithing
	# T1 solo comprables en tienda
	# T2 requiere smithing nivel 5 + ingredientes T2
	# T3 requiere smithing nivel 10 + ingredientes T3
	# ══════════════════════════════════════════

	# ── MINERÍA T2 / T3 ──────────────────────
	"tool_pickaxe_steel": {
		"name": "Pico de Acero",
		"result_qty": 1,
		"required_level": 5,
		"craft_skill_level": 5,
		"craft_tier": 2,
		"shop_ids": ["forge"],
		"category": "tool",
		"ingredients": [
			{"key": "ore_iron_t2",   "qty": 4},
			{"key": "ore_silver_t2", "qty": 2},
			{"key": "ore_coal_t2",   "qty": 3},
			{"key": "wood_log",      "qty": 2},
		],
		"desc": "Extrae minerales T1-T3. Más rápido que el de hierro.",
		"icon": "⛏"
	},
	"tool_pickaxe_mithril": {
		"name": "Pico de Mithril",
		"result_qty": 1,
		"required_level": 10,
		"craft_skill_level": 10,
		"craft_tier": 3,
		"shop_ids": ["forge"],
		"category": "tool",
		"ingredients": [
			{"key": "ore_gold_t3",             "qty": 4},
			{"key": "ore_silver_t3",           "qty": 3},
			{"key": "ore_coal_t3",             "qty": 4},
			{"key": "material_shadow_essence", "qty": 1},
			{"key": "wood_log",                "qty": 2},
		],
		"desc": "Extrae cualquier mineral incluido mithril. +50% rendimiento.",
		"icon": "⛏"
	},

	# ── LEÑADOR T2 / T3 ──────────────────────
	"tool_axe_steel": {
		"name": "Hacha de Acero",
		"result_qty": 1,
		"required_level": 5,
		"craft_skill_level": 5,
		"craft_tier": 2,
		"shop_ids": ["forge"],
		"category": "tool",
		"ingredients": [
			{"key": "ore_iron_t2",   "qty": 4},
			{"key": "ore_silver_t2", "qty": 2},
			{"key": "ore_coal_t2",   "qty": 3},
			{"key": "wood_log",      "qty": 3},
		],
		"desc": "Tala árboles T1-T3. Más eficiente que la de hierro.",
		"icon": "🪓"
	},
	"tool_axe_mithril": {
		"name": "Hacha de Mithril",
		"result_qty": 1,
		"required_level": 10,
		"craft_skill_level": 10,
		"craft_tier": 3,
		"shop_ids": ["forge"],
		"category": "tool",
		"ingredients": [
			{"key": "ore_gold_t3",             "qty": 4},
			{"key": "ore_silver_t3",           "qty": 3},
			{"key": "ore_coal_t3",             "qty": 4},
			{"key": "material_shadow_essence", "qty": 1},
			{"key": "wood_log",                "qty": 4},
		],
		"desc": "Tala árboles ancestrales. +50% madera por corte.",
		"icon": "🪓"
	},

	# ── HERBALISMO T2 / T3 ────────────────────
	"tool_herbalism_sickle": {
		"name": "Hoz Herbaria de Plata",
		"result_qty": 1,
		"required_level": 5,
		"craft_skill_level": 5,
		"craft_tier": 2,
		"shop_ids": ["forge"],
		"category": "tool",
		"ingredients": [
			{"key": "ore_silver_t2", "qty": 3},
			{"key": "ore_iron_t2",   "qty": 2},
			{"key": "ore_coal_t2",   "qty": 2},
			{"key": "material_herb", "qty": 3},
		],
		"desc": "Cosecha plantas T1-T3. Otorga hierbas raras adicionales.",
		"icon": "🌿"
	},
	"tool_herbalism_scythe": {
		"name": "Guadaña de Mithril",
		"result_qty": 1,
		"required_level": 10,
		"craft_skill_level": 10,
		"craft_tier": 3,
		"shop_ids": ["forge"],
		"category": "tool",
		"ingredients": [
			{"key": "ore_gold_t3",             "qty": 3},
			{"key": "ore_silver_t3",           "qty": 3},
			{"key": "ore_coal_t3",             "qty": 3},
			{"key": "material_herb",           "qty": 5},
			{"key": "material_shadow_essence", "qty": 1},
		],
		"desc": "Cosecha plantas épicas. +2 hierba por recolección.",
		"icon": "🌿"
	},
}

# Recetas disponibles según el shop_id del NPC
func get_available_recipes(shop_id: String) -> Array:
	var result: Array = []
	for key in RECIPES:
		var recipe: Dictionary = RECIPES[key]
		var shop_ids: Array = recipe.get("shop_ids", [])
		if shop_id in shop_ids or "all" in shop_ids:
			var entry = recipe.duplicate()
			entry["key"] = key
			result.append(entry)
	# Ordenar por craft_tier y luego por craft_skill_level
	result.sort_custom(func(a, b):
		var ta = a.get("craft_tier", 1)
		var tb = b.get("craft_tier", 1)
		if ta != tb: return ta < tb
		return a.get("craft_skill_level", 1) < b.get("craft_skill_level", 1)
	)
	return result

# Verifica si el jugador puede craftear una receta
func can_craft(recipe_key: String) -> bool:
	if not RECIPES.has(recipe_key):
		return false
	var recipe: Dictionary = RECIPES[recipe_key]

	# Verificar nivel de personaje
	if PlayerData.level < recipe.get("required_level", 1):
		return false

	# Verificar nivel de skill de crafteo
	var shop_ids: Array = recipe.get("shop_ids", [])
	for sid in shop_ids:
		if SHOP_CRAFT_SKILL.has(sid):
			var skill: String = SHOP_CRAFT_SKILL[sid]
			var min_skill_lv: int = recipe.get("craft_skill_level", 1)
			if PlayerData.get_crafting_level(skill) < min_skill_lv:
				return false
			break

	# Verificar ingredientes
	for ing in recipe.get("ingredients", []):
		if InventoryManager.get_item_count(ing["key"]) < ing["qty"]:
			return false

	return true

# Devuelve el motivo por el que no se puede craftear (para UI)
func get_craft_fail_reason(recipe_key: String) -> String:
	if not RECIPES.has(recipe_key):
		return "Receta desconocida."
	var recipe: Dictionary = RECIPES[recipe_key]

	# Nivel de personaje
	if PlayerData.level < recipe.get("required_level", 1):
		return "Nv. personaje insuf. (necesitas Nv.%d)" % recipe.get("required_level", 1)

	# Nivel de skill de crafteo
	var shop_ids: Array = recipe.get("shop_ids", [])
	for sid in shop_ids:
		if SHOP_CRAFT_SKILL.has(sid):
			var skill: String = SHOP_CRAFT_SKILL[sid]
			var min_skill_lv: int = recipe.get("craft_skill_level", 1)
			var cur_lv: int = PlayerData.get_crafting_level(skill)
			if cur_lv < min_skill_lv:
				var skill_names := {"smithing": "Herrería", "tailoring": "Sastrería", "alchemy": "Alquimia"}
				var sname: String = skill_names.get(skill, skill.capitalize())
				return "%s nivel %d requerido (tienes %d)" % [sname, min_skill_lv, cur_lv]
			break

	# Ingredientes
	for ing in recipe.get("ingredients", []):
		var have: int = InventoryManager.get_item_count(ing["key"])
		if have < ing["qty"]:
			var ing_data = InventoryManager.item_database.get(ing["key"], {})
			var ing_name = ing_data.get("name", ing["key"])
			return "Faltan %s (%d/%d)" % [ing_name, have, ing["qty"]]

	return ""

# Ejecuta el crafteo: consume ingredientes, añade resultado y otorga XP
func craft(recipe_key: String) -> bool:
	if not can_craft(recipe_key):
		var reason: String = get_craft_fail_reason(recipe_key)
		craft_failed.emit(reason)
		return false

	var recipe: Dictionary = RECIPES[recipe_key]

	# Consumir ingredientes
	for ing in recipe.get("ingredients", []):
		InventoryManager.remove_item(ing["key"], ing["qty"])

	# ── Determinar calidad del item crafteado ──────────────
	var category: String = recipe.get("category", "consumable")
	var quality: String  = "common"   # consumibles siempre common
	var applies_quality: bool = (category == "weapon" or category == "armor")

	if applies_quality:
		# Obtener nivel de skill de crafteo para tirar calidad
		var craft_skill_lv: int = 1
		var shop_ids_q: Array = recipe.get("shop_ids", [])
		for sid_q in shop_ids_q:
			if SHOP_CRAFT_SKILL.has(sid_q):
				var skill_q: String = SHOP_CRAFT_SKILL[sid_q]
				craft_skill_lv = PlayerData.get_crafting_level(skill_q)
				break
		quality = QualitySystem.roll_quality(craft_skill_lv)

	# ── Añadir resultado al inventario ────────────────────
	if applies_quality:
		# Obtener base del item desde la DB y aplicar calidad
		var base_item: Dictionary = InventoryManager.item_database.get(recipe_key, {}).duplicate(true)
		if base_item.is_empty():
			# Si la receta produce un item que no está en la DB base, usar datos de la receta
			base_item = {
				"name":           recipe.get("name", recipe_key),
				"category":       category,
				"slot":           _get_slot_for_category(recipe_key, recipe),
				"rarity":         "common",
				"tier":           recipe.get("craft_tier", 1),
				"atk":            recipe.get("atk", 0),
				"def":            recipe.get("def", 0),
				"durability":     200,
				"max_durability": 200,
				"desc":           recipe.get("desc", ""),
			}
		base_item["key"]    = recipe_key
		base_item["rarity"] = "common"  # rarity base, quality lo sobreescribirá visualmente
		# Guardar stats base PRE-calidad para normalización PvP
		base_item["pvp_atk"] = base_item.get("atk", 0)
		base_item["pvp_def"] = base_item.get("def", 0)
		var item_with_quality: Dictionary = QualitySystem.apply_quality(base_item, quality)
		# Añadir stats bonus aleatorias según calidad y tier
		item_with_quality = ArmorStatsSystem.roll_bonus_stats(item_with_quality)
		# Garantizar durabilidad
		item_with_quality = ArmorStatsSystem.ensure_durability(item_with_quality)
		InventoryManager.add_item_instance(item_with_quality)
		print("[CraftManager] Crafteado con calidad [%s]: %s" % [quality.to_upper(), recipe_key])
	else:
		var qty: int = recipe.get("result_qty", 1)
		InventoryManager.add_item(recipe_key, qty)
		print("[CraftManager] Crafteado: %s x%d" % [recipe_key, qty])

	# ── Otorgar XP de crafteo ─────────────────────────────
	var shop_ids: Array = recipe.get("shop_ids", [])
	for sid in shop_ids:
		if SHOP_CRAFT_SKILL.has(sid):
			var skill: String = SHOP_CRAFT_SKILL[sid]
			var tier: int = recipe.get("craft_tier", 1)
			var xp_amount: int = CRAFT_XP_BY_TIER.get(tier, 30)
			# Bonus XP si la calidad es superior a common
			match quality:
				"uncommon": xp_amount = int(xp_amount * 1.2)
				"rare":     xp_amount = int(xp_amount * 1.5)
				"epic":     xp_amount = int(xp_amount * 2.0)
			PlayerData.gain_crafting_xp(skill, xp_amount)
			print("[CraftManager] +%d XP de %s" % [xp_amount, skill])
			break

	var result_with_quality := recipe.duplicate(true)
	result_with_quality["crafted_quality"] = quality
	craft_success.emit(recipe_key, result_with_quality)
	# Logro crafteo
	var _am = get_node_or_null("/root/AchievementManager")
	if _am: _am.on_item_crafted(quality)
	return true

## Determina el slot de equipamiento a partir de la key o datos de receta
func _get_slot_for_category(recipe_key: String, recipe: Dictionary) -> String:
	if "weapon" in recipe_key: return "weapon"
	if "helm" in recipe_key or "hood" in recipe_key: return "head"
	if "chest" in recipe_key or "armor" in recipe_key: return "chest"
	if "gloves" in recipe_key or "gauntlet" in recipe_key: return "gloves"
	if "boots" in recipe_key: return "boots"
	if "ring" in recipe_key or "cloak" in recipe_key: return "ring"
	return "chest"

# Devuelve el skill name de crafteo para un shop_id
func get_craft_skill_for_shop(shop_id: String) -> String:
	return SHOP_CRAFT_SKILL.get(shop_id, "")
