# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# INVENTORY MANAGER — Autoload global
# 40 slots de inventario, 6 slots de equipamiento
# Categorías: weapon, consumable, material, armor, tool
# ============================================================

signal inventory_changed()
signal item_equipped(item: Dictionary)
signal item_unequipped(slot: String)
signal item_used(item_key: String)
signal item_added(item_key: String, quantity: int)

const MAX_SLOTS: int = 40

var items: Array = []
var bank_items: Array = []  # Almacenamiento del banco (slots dinámicos via BankManager)
# Los slots de banco son ahora dinámicos — usar BankManager.get_current_slots()

var equipped_items: Dictionary = {
	"head":    null,
	"weapon":  null,
	"chest":   null,
	"gloves":  null,
	"boots":   null,
	"ring":    null
}

# ──────────────────────────────────────────────
# BASE DE DATOS DE ITEMS
# ──────────────────────────────────────────────

var item_database: Dictionary = {
	# ── ARMAS — Espadas ──────────────────────────
	"weapon_broad_sword": {
		"name": "Espada Ancha", "category": "weapon", "slot": "weapon",
		"rarity": "common", "tier": 1, "atk": 14, "def": 2,
		"durability": 100, "max_durability": 100,
		"icon": "⚔️",
		"desc": "Hoja ancha y pesada. Mecánica Berserker (+35% daño).",
		"weapon_type": "sword"
	},
	"weapon_dual_swords": {
		"name": "Doble Espada", "category": "weapon", "slot": "weapon",
		"rarity": "uncommon", "tier": 1, "atk": 13, "def": 1,
		"durability": 100, "max_durability": 100,
		"desc": "Dos hojas gemelas. Alta velocidad, genera momentum con cada combo.",
		"weapon_type": "sword"
	},
	# ── ARMAS — Tank ─────────────────────────────
	"weapon_sword_shield": {
		"name": "Espada y Escudo", "category": "weapon", "slot": "weapon",
		"rarity": "uncommon", "tier": 1, "atk": 10, "def": 12,
		"durability": 100, "max_durability": 100,
		"desc": "+300% agro. Ideal para tanquear bosses.",
		"weapon_type": "sword_shield"
	},
	# ── ARMAS — Mazas ─────────────────────────────
	"weapon_mace": {
		"name": "Maza de Hierro", "category": "weapon", "slot": "weapon",
		"rarity": "common", "tier": 1, "atk": 16, "def": 3,
		"durability": 120, "max_durability": 120,
		"desc": "Golpes lentos pero devastadores. Stun chance 15%.",
		"weapon_type": "mace"
	},
	# ── ARMAS — Arcos ─────────────────────────────
	"weapon_bow": {
		"name": "Arco Corto", "category": "weapon", "slot": "weapon",
		"rarity": "common", "tier": 1, "atk": 11, "def": 0,
		"durability": 80, "max_durability": 80,
		"desc": "Ataques a distancia. Alta precisión.",
		"weapon_type": "bow"
	},
	# ── ARMAS — Bastones ──────────────────────────
	"weapon_staff_holy": {
		"name": "Bastón Sagrado", "category": "weapon", "slot": "weapon",
		"rarity": "uncommon", "tier": 1, "atk": 8, "def": 4,
		"durability": 90, "max_durability": 90,
		"desc": "Healer: cura a aliados cercanos. +25% curación.",
		"weapon_type": "staff_holy"
	},
	# ── ESPADA SAGRADA DE 2 MANOS — greatsword_holy (T1/T2/T3) ──
	"weapon_greatsword_holy_t1": {
		"name": "Espada Santa", "category": "weapon", "slot": "weapon",
		"rarity": "uncommon", "tier": 1, "atk": 16, "def": 5,
		"durability": 110, "max_durability": 110,
		"desc": "Espada sagrada de dos manos. Golpea con luz y cura un poco al atacar.",
		"weapon_type": "greatsword_holy"
	},
	"weapon_greatsword_holy_t2": {
		"name": "Espada de la Redención", "category": "weapon", "slot": "weapon",
		"rarity": "rare", "tier": 2, "atk": 34, "def": 10,
		"durability": 140, "max_durability": 140,
		"desc": "Espada sagrada templada. Cada golpe canaliza luz divina que sana al portador.",
		"weapon_type": "greatsword_holy"
	},
	"weapon_greatsword_holy_t3": {
		"name": "Espada del Juicio Eterno", "category": "weapon", "slot": "weapon",
		"rarity": "epic", "tier": 3, "atk": 62, "def": 18,
		"durability": 180, "max_durability": 180,
		"desc": "Arma legendaria imbuida de maná sagrado. Cada impacto hiere al mal y restaura la vida del guerrero.",
		"weapon_type": "greatsword_holy"
	},
	"weapon_necronomicon": {
		"name": "Necronomicón", "category": "weapon", "slot": "weapon",
		"rarity": "rare", "tier": 2, "atk": 18, "def": 1,
		"durability": 70, "max_durability": 70,
		"desc": "Invoca esqueletos para luchar por ti. Summoner.",
		"weapon_type": "necronomicon"
	},
	# ── ARMADURA — Cabeza ─────────────────────────
	"armor_iron_helm": {
		"name": "Yelmo de Hierro", "category": "armor", "slot": "head",
		"rarity": "common", "tier": 1, "atk": 0, "def": 8,
		"durability": 100, "max_durability": 100,
		"desc": "Protección básica de cabeza."
	},
	# ── ARMADURA — Pecho ──────────────────────────
	"armor_leather_chest": {
		"name": "Peto de Cuero", "category": "armor", "slot": "chest",
		"rarity": "common", "tier": 1, "atk": 0, "def": 10,
		"durability": 100, "max_durability": 100,
		"desc": "Armadura ligera de cuero."
	},
	"armor_iron_chest": {
		"name": "Peto de Hierro", "category": "armor", "slot": "chest",
		"rarity": "uncommon", "tier": 1, "atk": 0, "def": 18,
		"durability": 150, "max_durability": 150,
		"desc": "Armadura pesada. Reduce velocidad -5."
	},
	# ── ARMADURA — Guantes ────────────────────────
	"armor_gloves": {
		"name": "Guantes de Cuero", "category": "armor", "slot": "gloves",
		"rarity": "common", "tier": 1, "atk": 1, "def": 4,
		"durability": 80, "max_durability": 80,
		"desc": "Mejora el agarre de armas."
	},
	# ── ARMADURA — Botas ──────────────────────────
	"armor_boots": {
		"name": "Botas de Aventurero", "category": "armor", "slot": "boots",
		"rarity": "common", "tier": 1, "atk": 0, "def": 5,
		"durability": 100, "max_durability": 100,
		"desc": "+5 de velocidad."
	},
	# ── CONSUMIBLES ───────────────────────────────
	"potion_hp_small": {
		"name": "Poción HP Pequeña", "category": "consumable",
		"rarity": "common", "heal_amount": 50,
		"desc": "Restaura 50 HP."
	},
	"potion_hp": {
		"name": "Poción de Vida", "category": "consumable",
		"rarity": "common", "heal_amount": 150,
		"desc": "Restaura 150 HP."
	},
	"potion_hp_large": {
		"name": "Poción HP Grande", "category": "consumable",
		"rarity": "uncommon", "heal_amount": 350,
		"desc": "Restaura 350 HP."
	},
	"potion_energy": {
		"name": "Poción de Energía", "category": "consumable",
		"rarity": "common", "energy_amount": 30,
		"desc": "Restaura 30 de energía."
	},
	"antidote": {
		"name": "Antídoto", "category": "consumable",
		"rarity": "common", "desc": "Cura el estado Veneno."
	},
	# ── MATERIALES ────────────────────────────────
	"mushroom_normal": {
		"name": "Hongo Normal", "category": "material",
		"rarity": "common", "desc": "Hongo común del bosque. Stackeable.",
		"max_stack": 99
	},
	"mushroom_rare": {
		"name": "Hongo Brillante", "category": "material",
		"rarity": "rare", "desc": "Hongo bioluminiscente muy valorado.",
		"max_stack": 99
	},
	"herb_basic": {
		"name": "Hierba Básica", "category": "material",
		"rarity": "common", "desc": "Hierba para pociones.",
		"max_stack": 99
	},
	"herb_magic": {
		"name": "Hierba Mágica", "category": "material",
		"rarity": "uncommon", "desc": "Hierba imbuida de magia.",
		"max_stack": 99
	},
	# ── ORES TIERIZADOS T1-T4 ───────────────────────────────
	# Carbón
	"ore_coal_t1": {"name": "Carbón T1", "category": "material", "rarity": "common", "desc": "Combustible esencial para forja. Tier 1.", "max_stack": 99, "price": 5},
	"ore_coal_t2": {"name": "Carbón T2", "category": "material", "rarity": "uncommon", "desc": "Combustible esencial para forja. Tier 2.", "max_stack": 99, "price": 15},
	"ore_coal_t3": {"name": "Carbón T3", "category": "material", "rarity": "rare", "desc": "Combustible esencial para forja. Tier 3.", "max_stack": 99, "price": 40},
	"ore_coal_t4": {"name": "Carbón T4", "category": "material", "rarity": "epic", "desc": "Combustible esencial para forja. Tier 4.", "max_stack": 99, "price": 120},
	# Piedra
	"ore_stone_t1": {"name": "Piedra T1", "category": "material", "rarity": "common", "desc": "Material de construcción básico. Tier 1.", "max_stack": 99, "price": 3},
	"ore_stone_t2": {"name": "Piedra T2", "category": "material", "rarity": "uncommon", "desc": "Material de construcción básico. Tier 2.", "max_stack": 99, "price": 10},
	"ore_stone_t3": {"name": "Piedra T3", "category": "material", "rarity": "rare", "desc": "Material de construcción básico. Tier 3.", "max_stack": 99, "price": 30},
	"ore_stone_t4": {"name": "Piedra T4", "category": "material", "rarity": "epic", "desc": "Material de construcción básico. Tier 4.", "max_stack": 99, "price": 90},
	# Hierro
	"ore_iron_t1": {"name": "Hierro T1", "category": "material", "rarity": "common", "desc": "Mineral básico para forja. Tier 1.", "max_stack": 99, "price": 8},
	"ore_iron_t2": {"name": "Hierro T2", "category": "material", "rarity": "uncommon", "desc": "Mineral básico para forja. Tier 2.", "max_stack": 99, "price": 22},
	"ore_iron_t3": {"name": "Hierro T3", "category": "material", "rarity": "rare", "desc": "Mineral básico para forja. Tier 3.", "max_stack": 99, "price": 60},
	"ore_iron_t4": {"name": "Hierro T4", "category": "material", "rarity": "epic", "desc": "Mineral básico para forja. Tier 4.", "max_stack": 99, "price": 150},
	# Plata
	"ore_silver_t1": {"name": "Plata T1", "category": "material", "rarity": "common", "desc": "Mineral plateado con propiedades mágicas. Tier 1.", "max_stack": 99, "price": 20},
	"ore_silver_t2": {"name": "Plata T2", "category": "material", "rarity": "uncommon", "desc": "Mineral plateado con propiedades mágicas. Tier 2.", "max_stack": 99, "price": 55},
	"ore_silver_t3": {"name": "Plata T3", "category": "material", "rarity": "rare", "desc": "Mineral plateado con propiedades mágicas. Tier 3.", "max_stack": 99, "price": 130},
	"ore_silver_t4": {"name": "Plata T4", "category": "material", "rarity": "epic", "desc": "Mineral plateado con propiedades mágicas. Tier 4.", "max_stack": 99, "price": 350},
	# Oro
	"ore_gold_t1": {"name": "Oro T1", "category": "material", "rarity": "common", "desc": "Mineral precioso y resistente. Tier 1.", "max_stack": 99, "price": 60},
	"ore_gold_t2": {"name": "Oro T2", "category": "material", "rarity": "uncommon", "desc": "Mineral precioso y resistente. Tier 2.", "max_stack": 99, "price": 150},
	"ore_gold_t3": {"name": "Oro T3", "category": "material", "rarity": "rare", "desc": "Mineral precioso y resistente. Tier 3.", "max_stack": 99, "price": 400},
	"ore_gold_t4": {"name": "Oro T4", "category": "material", "rarity": "epic", "desc": "Mineral precioso y resistente. Tier 4.", "max_stack": 99, "price": 1000},
	# Piedra Azul
	"ore_bluestone_t1": {"name": "Piedra Azul T1", "category": "material", "rarity": "common", "desc": "Mineral místico imbuido de energía arcana. Tier 1.", "max_stack": 99, "price": 200},
	"ore_bluestone_t2": {"name": "Piedra Azul T2", "category": "material", "rarity": "uncommon", "desc": "Mineral místico imbuido de energía arcana. Tier 2.", "max_stack": 99, "price": 500},
	"ore_bluestone_t3": {"name": "Piedra Azul T3", "category": "material", "rarity": "rare", "desc": "Mineral místico imbuido de energía arcana. Tier 3.", "max_stack": 99, "price": 1200},
	"ore_bluestone_t4": {"name": "Piedra Azul T4", "category": "material", "rarity": "epic", "desc": "Mineral místico imbuido de energía arcana. Tier 4.", "max_stack": 99, "price": 3000},
	"wood_log": {
		"name": "Tronco de Madera", "category": "material",
		"rarity": "common", "desc": "Madera básica.",
		"max_stack": 99
	},
	"crystal_shard": {
		"name": "Fragmento de Cristal", "category": "material",
		"rarity": "uncommon", "desc": "Fragmento brillante de cristal mágico.",
		"max_stack": 99
	},
	# ── MATERIALES DE ENEMIGOS ───────────────────
	"material_slime_gel": {
		"name": "Gel de Slime", "category": "material",
		"rarity": "common", "desc": "Sustancia pegajosa de un slime. Útil para pociones.",
		"max_stack": 99
	},
	"material_goblin_ear": {
		"name": "Oreja de Goblin", "category": "material",
		"rarity": "common", "desc": "Prueba de una victoria contra un goblin.",
		"max_stack": 99
	},
	"material_orc_hide": {
		"name": "Cuero de Orco", "category": "material",
		"rarity": "uncommon", "desc": "Cuero grueso y resistente de un orco.",
		"max_stack": 99
	},
	"material_bone": {
		"name": "Hueso", "category": "material",
		"rarity": "common", "desc": "Fragmento de hueso de un esqueleto animado.",
		"max_stack": 99
	},
	"weapon_crude_axe": {
		"name": "Hacha Tosca", "category": "weapon", "slot": "weapon",
		"rarity": "common", "tier": 1, "atk": 8, "def": 1,
		"durability": 60, "max_durability": 60,
		"desc": "Hacha rudimentaria de un orco. Efectiva pero pesada.",
		"weapon_type": "axe"
	},
	# ── ITEMS DUNGEON (Paso 5) ───────────────────
	"armor_shadow_chest": {
		"name": "Peto de Sombra", "category": "armor", "slot": "chest",
		"rarity": "rare", "tier": 2, "atk": 2, "def": 18,
		"durability": 150, "max_durability": 150,
		"desc": "Armadura forjada en las sombras de la mazmorra. Absorbe el daño oscuro."
	},
	"weapon_shadow_blade": {
		"name": "Hoja de Sombra", "category": "weapon", "slot": "weapon",
		"rarity": "rare", "tier": 2, "atk": 28, "def": 5,
		"durability": 120, "max_durability": 120,
		"desc": "Espada que absorbe la oscuridad. +15% daño en mazmorras.",
		"weapon_type": "sword"
	},
	"material_shadow_essence": {
		"name": "Esencia de Sombra", "category": "material",
		"rarity": "epic", "desc": "Esencia pura de oscuridad extraída del Señor de las Sombras. Sirve para craftear equipo T3.",
		"max_stack": 10
	},
	# ── MATERIALES RECOLECTABLES (Paso 6) ─────────
	"material_herb": {
		"name": "Hierba Curativa", "category": "material",
		"rarity": "common", "desc": "Hierba medicinal recogida del campo. Ingrediente para pociones.",
		"max_stack": 99
	},
	"material_mushroom": {
		"name": "Hongo Silvestre", "category": "material",
		"rarity": "common", "desc": "Hongo encontrado en zonas húmedas. Útil en alquimia.",
		"max_stack": 99
	},
	# ── ITEMS CRAFTEABLES (Paso 6) ─────────────────
	"consumable_health_potion": {
		"name": "Poción de Vida", "category": "consumable",
		"rarity": "common", "desc": "Restaura 80 HP al usarse.",
		"max_stack": 20, "heal_amount": 80
	},
	"consumable_energy_potion": {
		"name": "Poción de Energía", "category": "consumable",
		"rarity": "common", "desc": "Restaura 50 puntos de energía.",
		"max_stack": 20
	},
	"consumable_antidote": {
		"name": "Antídoto", "category": "consumable",
		"rarity": "common", "desc": "Elimina efectos de veneno.",
		"max_stack": 20
	},
	"weapon_iron_sword": {
		"name": "Espada de Hierro", "category": "weapon", "slot": "weapon",
		"rarity": "common", "tier": 1, "atk": 18, "def": 3,
		"durability": 100, "max_durability": 100,
		"desc": "Espada sólida forjada en hierro.", "weapon_type": "sword"
	},
	# ── ARMAS Y ARMADURAS CRAFTEABLES T2/T3 ─────────────────────
	"weapon_steel_sword": {
		"name": "Espada de Plata", "category": "weapon", "slot": "weapon",
		"rarity": "uncommon", "tier": 2, "atk": 32, "def": 5,
		"durability": 180, "max_durability": 180,
		"desc": "Espada de plata templada. ATK+32.", "weapon_type": "sword"
	},
	"armor_steel_chest": {
		"name": "Peto de Plata", "category": "armor", "slot": "chest",
		"rarity": "uncommon", "tier": 2, "atk": 0, "def": 20,
		"durability": 200, "max_durability": 200,
		"desc": "Armadura de plata forjada. DEF+20."
	},
	"boots_steel": {
		"name": "Botas de Plata", "category": "armor", "slot": "boots",
		"rarity": "uncommon", "tier": 2, "atk": 0, "def": 10,
		"durability": 150, "max_durability": 150,
		"desc": "Botas reforzadas de plata. DEF+10 +15% velocidad."
	},
	"weapon_mithril_sword": {
		"name": "Espada de Oro", "category": "weapon", "slot": "weapon",
		"rarity": "rare", "tier": 3, "atk": 55, "def": 8,
		"durability": 300, "max_durability": 300,
		"desc": "Espada de oro puro. ATK+55.", "weapon_type": "sword"
	},
	"armor_mithril_chest": {
		"name": "Peto de Oro", "category": "armor", "slot": "chest",
		"rarity": "rare", "tier": 3, "atk": 0, "def": 45,
		"durability": 350, "max_durability": 350,
		"desc": "Armadura legendaria de oro. DEF+45."
	},
	"boots_mithril": {
		"name": "Botas de Oro", "category": "armor", "slot": "boots",
		"rarity": "rare", "tier": 3, "atk": 0, "def": 25,
		"durability": 250, "max_durability": 250,
		"desc": "Botas legendarias de oro. DEF+25 +25% velocidad."
	},
	"weapon_bluestone_sword": {
		"name": "Espada Arcana", "category": "weapon", "slot": "weapon",
		"rarity": "epic", "tier": 4, "atk": 75, "def": 12,
		"durability": 500, "max_durability": 500,
		"desc": "Forjada con piedra azul arcana. ATK+75 y +15% daño mágico.", "weapon_type": "sword"
	},
	"armor_bluestone_chest": {
		"name": "Peto Arcano", "category": "armor", "slot": "chest",
		"rarity": "epic", "tier": 4, "atk": 0, "def": 60,
		"durability": 600, "max_durability": 600,
		"desc": "Armadura arcana imbuida de magia. DEF+60 y resistencia mágica."
	},
	"boots_arcane": {
		"name": "Botas Arcanas", "category": "armor", "slot": "boots",
		"rarity": "epic", "tier": 4, "atk": 0, "def": 35,
		"durability": 450, "max_durability": 450,
		"desc": "Botas arcanas de piedra azul. DEF+35 +35% velocidad y levitación."
	},
	"armor_shadow_gauntlets": {
		"name": "Guanteletes de Sombra", "category": "armor", "slot": "gloves",
		"rarity": "epic", "tier": 3, "atk": 8, "def": 12,
		"durability": 200, "max_durability": 200,
		"desc": "Forjados con esencia de sombra del jefe de la mazmorra."
	},
	"boots_leather": {
		"name": "Botas de Cuero", "category": "armor", "slot": "boots",
		"rarity": "common", "tier": 1, "atk": 0, "def": 4,
		"durability": 80, "max_durability": 80,
		"desc": "Botas ligeras. +10% velocidad de movimiento."
	},
	"gloves_leather": {
		"name": "Guantes de Cuero", "category": "armor", "slot": "gloves",
		"rarity": "common", "tier": 1, "atk": 1, "def": 3,
		"durability": 80, "max_durability": 80,
		"desc": "Guantes básicos de cuero para proteger las manos."
	},
	# ── HERRAMIENTAS ──────────────────────────────
	"tool_pickaxe_iron": {
		"name": "Pico de Hierro", "category": "tool",
		"rarity": "common", "tier": 1,
		"durability": 200, "max_durability": 200,
		"desc": "Extrae minerales. Herramienta básica de minería T1.",
		"tool_type": "mining", "slot": "tool_mining",
		"price": 200, "level_req": 1, "spec_req": ""
	},
	"tool_axe_iron": {
		"name": "Hacha de Hierro", "category": "tool",
		"rarity": "common", "tier": 1,
		"durability": 200, "max_durability": 200,
		"desc": "Tala árboles. Herramienta básica de leñador T1.",
		"tool_type": "woodcutting", "slot": "tool_woodcutting",
		"price": 200, "level_req": 1, "spec_req": ""
	},
	"tool_herbalism_knife": {
		"name": "Navaja Herbaria", "category": "tool",
		"rarity": "common", "tier": 1,
		"durability": 150, "max_durability": 150,
		"desc": "Recolecta hierbas y plantas.",
		"tool_type": "herbalism", "slot": "tool_herbalism",
		"price": 200,
		"level_req": 1, "spec_req": ""
	},
	# ── HERRAMIENTAS T2 — solo crafteables en forja (smithing nivel 5) ──
	"tool_pickaxe_steel": {
		"name": "Pico de Acero", "category": "tool",
		"rarity": "uncommon", "tier": 2,
		"durability": 400, "max_durability": 400,
		"desc": "Extrae minerales T1-T3. Más rápido que el de hierro.",
		"tool_type": "mining", "slot": "tool_mining",
		"level_req": 5, "spec_req": "mining"
	},
	"tool_axe_steel": {
		"name": "Hacha de Acero", "category": "tool",
		"rarity": "uncommon", "tier": 2,
		"durability": 400, "max_durability": 400,
		"desc": "Tala árboles T1-T3. Más eficiente que la de hierro.",
		"tool_type": "woodcutting", "slot": "tool_woodcutting",
		"level_req": 5, "spec_req": "woodcutting"
	},
	"tool_herbalism_sickle": {
		"name": "Hoz Herbaria de Plata", "category": "tool",
		"rarity": "uncommon", "tier": 2,
		"durability": 300, "max_durability": 300,
		"desc": "Cosecha plantas T1-T3. Otorga hierbas raras adicionales.",
		"tool_type": "herbalism", "slot": "tool_herbalism",
		"level_req": 5, "spec_req": "herbalism"
	},
	# ── HERRAMIENTAS T3 — solo crafteables en forja (smithing nivel 10) ──
	"tool_pickaxe_mithril": {
		"name": "Pico de Mithril", "category": "tool",
		"rarity": "rare", "tier": 3,
		"durability": 800, "max_durability": 800,
		"desc": "Extrae cualquier mineral incluido mithril. +50% rendimiento.",
		"tool_type": "mining", "slot": "tool_mining",
		"level_req": 10, "spec_req": "mining"
	},
	"tool_axe_mithril": {
		"name": "Hacha de Mithril", "category": "tool",
		"rarity": "rare", "tier": 3,
		"durability": 800, "max_durability": 800,
		"desc": "Tala árboles ancestrales. +50% madera por corte.",
		"tool_type": "woodcutting", "slot": "tool_woodcutting",
		"level_req": 10, "spec_req": "woodcutting"
	},
	"tool_herbalism_scythe": {
		"name": "Guadaña de Mithril", "category": "tool",
		"rarity": "rare", "tier": 3,
		"durability": 600, "max_durability": 600,
		"desc": "Cosecha plantas épicas. +2 hierba por recolección.",
		"tool_type": "herbalism", "slot": "tool_herbalism",
		"level_req": 10, "spec_req": "herbalism"
	},
	# ══════════════════════════════════════════════════════════════
	# MEJORA 3 — Armas T2 / T3 / T4 para tipos incompletos
	# Drops de boss de zona: T3 garantizado + T4 drop legendario
	# ══════════════════════════════════════════════════════════════

	# ── BOW — Arco (T1 ya existe: weapon_bow  ATK 11) ────────────
	"weapon_bow_t2": {
		"name": "Arco Largo", "category": "weapon", "slot": "weapon",
		"rarity": "uncommon", "tier": 2, "atk": 28, "def": 0,
		"durability": 130, "max_durability": 130,
		"desc": "Arco de madera reforzada. Mayor alcance y cadencia.",
		"weapon_type": "bow"
	},
	"weapon_bow_t3": {
		"name": "Arco de Plata", "category": "weapon", "slot": "weapon",
		"rarity": "rare", "tier": 3, "atk": 50, "def": 0,
		"durability": 200, "max_durability": 200,
		"desc": "Arco élfico de plata. Drop del boss Shadow Lord (Oeste). Flechas perforan armadura.",
		"weapon_type": "bow"
	},
	"weapon_bow_t4": {
		"name": "Arco del Vacío", "category": "weapon", "slot": "weapon",
		"rarity": "epic", "tier": 4, "atk": 72, "def": 0,
		"durability": 350, "max_durability": 350,
		"desc": "Arco forjado en el vacío arcano. Solo drop legendario del boss Oeste. +20% daño a distancia.",
		"weapon_type": "bow"
	},

	# ── MACE — Maza (T1 ya existe: weapon_mace  ATK 16) ──────────
	"weapon_mace_t2": {
		"name": "Maza de Acero", "category": "weapon", "slot": "weapon",
		"rarity": "uncommon", "tier": 2, "atk": 36, "def": 5,
		"durability": 200, "max_durability": 200,
		"desc": "Maza de acero templado. Stun chance 20%. Golpe aplastante.",
		"weapon_type": "mace"
	},
	"weapon_mace_t3": {
		"name": "Maza de Hueso Sagrado", "category": "weapon", "slot": "weapon",
		"rarity": "rare", "tier": 3, "atk": 60, "def": 8,
		"durability": 300, "max_durability": 300,
		"desc": "Forjada con huesos de esqueleto rey. Drop del boss Skeleton King (Norte). Stun chance 30%.",
		"weapon_type": "mace"
	},
	"weapon_mace_t4": {
		"name": "Maza del Juicio", "category": "weapon", "slot": "weapon",
		"rarity": "epic", "tier": 4, "atk": 85, "def": 12,
		"durability": 500, "max_durability": 500,
		"desc": "La maza más poderosa conocida. Drop legendario del boss Norte. Cada golpe aturde.",
		"weapon_type": "mace"
	},

	# ── STAFF_HOLY — Bastón sagrado (T1 ya existe: weapon_staff_holy  ATK 8) ──
	"weapon_staff_holy_t2": {
		"name": "Bastón del Curandero", "category": "weapon", "slot": "weapon",
		"rarity": "uncommon", "tier": 2, "atk": 20, "def": 8,
		"durability": 160, "max_durability": 160,
		"desc": "Bastón sagrado reforzado. +40% curación. Cura a aliados en radio mayor.",
		"weapon_type": "staff_holy"
	},
	"weapon_staff_holy_t3": {
		"name": "Báculo de la Luz Divina", "category": "weapon", "slot": "weapon",
		"rarity": "rare", "tier": 3, "atk": 38, "def": 14,
		"durability": 250, "max_durability": 250,
		"desc": "Drop del boss Goblin Shaman (Sur). Irradia luz que cura a todos los aliados cercanos.",
		"weapon_type": "staff_holy"
	},
	"weapon_staff_holy_t4": {
		"name": "Báculo del Serafín", "category": "weapon", "slot": "weapon",
		"rarity": "epic", "tier": 4, "atk": 55, "def": 22,
		"durability": 420, "max_durability": 420,
		"desc": "Drop legendario del boss Sur. El mayor bastón de sanación. Resurrección pasiva.",
		"weapon_type": "staff_holy"
	},

	# ── AXE — Hacha (T1 ya existe: weapon_crude_axe  ATK 8) ──────
	"weapon_axe_t2": {
		"name": "Hacha de Guerra", "category": "weapon", "slot": "weapon",
		"rarity": "uncommon", "tier": 2, "atk": 38, "def": 4,
		"durability": 220, "max_durability": 220,
		"desc": "Hacha de dos filos forjada en hierro. Ataques en arco que golpean a múltiples enemigos.",
		"weapon_type": "axe"
	},
	"weapon_axe_t3": {
		"name": "Hacha del Señor Orco", "category": "weapon", "slot": "weapon",
		"rarity": "rare", "tier": 3, "atk": 62, "def": 6,
		"durability": 320, "max_durability": 320,
		"desc": "Drop del boss Orc Warlord (Este). Hacha colosal que ignora un 20% de la defensa enemiga.",
		"weapon_type": "axe"
	},
	"weapon_axe_t4": {
		"name": "Hacha del Apocalipsis", "category": "weapon", "slot": "weapon",
		"rarity": "epic", "tier": 4, "atk": 88, "def": 10,
		"durability": 550, "max_durability": 550,
		"desc": "Drop legendario del boss Este. La destrucción encarnada. Golpe en área garantizado.",
		"weapon_type": "axe"
	},

	# ── NECRONOMICON — (T2 ya existe: weapon_necronomicon ATK 18, T1 y T3 faltaban) ──
	"weapon_necronomicon_t1": {
		"name": "Grimorium Menor", "category": "weapon", "slot": "weapon",
		"rarity": "common", "tier": 1, "atk": 10, "def": 1,
		"durability": 60, "max_durability": 60,
		"desc": "Libro oscuro de iniciación. Invoca 1 esqueleto débil para luchar por ti.",
		"weapon_type": "necronomicon"
	},
	# weapon_necronomicon es el T2 (ATK 18) — ya existe, no se toca
	"weapon_necronomicon_t3": {
		"name": "Necronomicón Ancestral", "category": "weapon", "slot": "weapon",
		"rarity": "epic", "tier": 3, "atk": 42, "def": 3,
		"durability": 120, "max_durability": 120,
		"desc": "Drop del boss Skeleton King (Norte). Invoca 3 esqueletos de élite simultáneamente.",
		"weapon_type": "necronomicon"
	},

	# ── DROPS DE BOSS T4 — sword (Dungeon Boss: Azathiel) ────────
	# weapon_bluestone_sword ya es T4 del árbol sword — se reutiliza como drop de Azathiel.
	# Se añade aquí el material épico de boss que los bosses de zona dropean.
	"material_boss_north_essence": {
		"name": "Esencia del Rey Esqueleto", "category": "material",
		"rarity": "epic", "desc": "Esencia del Skeleton King. Requerida para craftear armas T4 de maza y necronomicón.",
		"max_stack": 5
	},
	"material_boss_south_essence": {
		"name": "Esencia del Chamán Goblin", "category": "material",
		"rarity": "epic", "desc": "Esencia del Goblin Shaman. Requerida para craftear armas T4 de bastón sagrado.",
		"max_stack": 5
	},
	"material_boss_east_essence": {
		"name": "Esencia del Señor Orco", "category": "material",
		"rarity": "epic", "desc": "Esencia del Orc Warlord. Requerida para craftear armas T4 de hacha.",
		"max_stack": 5
	},
	"material_boss_west_essence": {
		"name": "Esencia del Señor de las Sombras", "category": "material",
		"rarity": "epic", "desc": "Esencia del Shadow Lord. Requerida para craftear armas T4 de arco.",
		"max_stack": 5
	},
}

# ──────────────────────────────────────────────
# INIT
# ──────────────────────────────────────────────

func _ready() -> void:
	_init_slots()
	load_inventory()
	print("[InventoryManager] Inicializado — ", MAX_SLOTS, " slots")

func _init_slots() -> void:
	items.clear()
	for i in range(MAX_SLOTS):
		items.append(null)
	bank_items.clear()
	var _base_bank_slots = 15  # Slots iniciales; BankManager.load_bank_data() los expande
	for i in range(_base_bank_slots):
		bank_items.append(null)

# ──────────────────────────────────────────────
# GUARDAR / CARGAR INVENTARIO
# ──────────────────────────────────────────────

func save_inventory() -> void:
	var slot_data: Array = []
	for item in items:
		if item == null:
			slot_data.append(null)
		else:
			slot_data.append({
				"key": item.get("key", ""),
				"qty": item.get("qty", 1),
				"quality": item.get("quality", ""),
				"durability": item.get("durability", -1),
			})

	var equipped_data: Dictionary = {}
	for slot in equipped_items:
		var eq = equipped_items[slot]
		if eq == null:
			equipped_data[slot] = null
		else:
			equipped_data[slot] = {
				"key": eq.get("key", ""),
				"qty": eq.get("qty", 1),
				"quality": eq.get("quality", ""),
				"durability": eq.get("durability", -1),
			}

	var data: Dictionary = {
		"items":    slot_data,
		"equipped": equipped_data,
	}

	var file = FileAccess.open("user://inventory.save", FileAccess.WRITE)
	if not file:
		push_error("[InventoryManager] No se pudo guardar inventario")
		return
	file.store_string(JSON.stringify(data))
	file.close()

func load_inventory() -> void:
	if not FileAccess.file_exists("user://inventory.save"):
		return

	var file = FileAccess.open("user://inventory.save", FileAccess.READ)
	if not file:
		return

	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if not data or typeof(data) != TYPE_DICTIONARY:
		return

	# Cargar slots de inventario
	if data.has("items"):
		var saved: Array = data["items"]
		for i in range(min(saved.size(), items.size())):
			var entry = saved[i]
			if entry == null or typeof(entry) != TYPE_DICTIONARY:
				items[i] = null
				continue
			var key: String = entry.get("key", "")
			if key == "" or not item_database.has(key):
				items[i] = null
				continue
			var item_data: Dictionary = item_database[key].duplicate(true)
			item_data["key"] = key
			item_data["qty"] = entry.get("qty", 1)
			var qual: String = entry.get("quality", "")
			if qual != "":
				item_data["quality"] = qual
			var dur = entry.get("durability", -1)
			if dur >= 0:
				item_data["durability"] = dur
			items[i] = item_data

	# Cargar equipo
	if data.has("equipped"):
		var saved_eq: Dictionary = data["equipped"]
		for slot in equipped_items.keys():
			if not saved_eq.has(slot):
				continue
			var entry = saved_eq[slot]
			if entry == null or typeof(entry) != TYPE_DICTIONARY:
				equipped_items[slot] = null
				continue
			var key: String = entry.get("key", "")
			if key == "" or not item_database.has(key):
				equipped_items[slot] = null
				continue
			var item_data: Dictionary = item_database[key].duplicate(true)
			item_data["key"] = key
			item_data["qty"] = entry.get("qty", 1)
			var qual: String = entry.get("quality", "")
			if qual != "":
				item_data["quality"] = qual
			var dur = entry.get("durability", -1)
			if dur >= 0:
				item_data["durability"] = dur
			equipped_items[slot] = item_data
	# Recalcular stats de equipo tras cargar
	_update_equipment_stats()
	inventory_changed.emit()
	print("[InventoryManager] Inventario cargado desde disco")

# ──────────────────────────────────────────────
# AÑADIR / QUITAR ITEMS
# ──────────────────────────────────────────────

func add_item(item_key: String, quantity: int = 1, target_array: Array = items) -> bool:
	if not item_database.has(item_key):
		push_warning("[InventoryManager] Item desconocido: " + item_key)
		return false
	
	var db_entry = item_database[item_key]
	var max_stack = db_entry.get("max_stack", 1)
	
	# Intentar stackear en slot existente
	if max_stack > 1:
		for i in range(target_array.size()):
			if target_array[i] != null and target_array[i].get("key") == item_key:
				target_array[i]["qty"] = min(target_array[i]["qty"] + quantity, max_stack)
				inventory_changed.emit()
				item_added.emit(item_key, quantity)
				if target_array == items:
					save_inventory()
				return true
	
	# Buscar slot vacío
	for i in range(target_array.size()):
		if target_array[i] == null:
			var item_data = db_entry.duplicate(true)
			item_data["key"] = item_key
			item_data["qty"] = min(quantity, max_stack)
			target_array[i] = item_data
			inventory_changed.emit()
			item_added.emit(item_key, quantity)
			if target_array == items:
				save_inventory()
			return true
	
	print("[InventoryManager] Inventario lleno!")
	return false

## Añade un item con stats customizados (ej. con calidad aplicada).
## Estos items son ÚNICOS (no se stackean), cantidad siempre 1.
## item_instance debe tener "key" y todos los campos necesarios.
func add_item_instance(item_instance: Dictionary, target_array: Array = items) -> bool:
	# Items con calidad nunca se stackean (son únicos)
	for i in range(target_array.size()):
		if target_array[i] == null:
			var inst = item_instance.duplicate(true)
			inst["qty"] = 1
			target_array[i] = inst
			inventory_changed.emit()
			item_added.emit(inst.get("key", ""), 1)
			if target_array == items:
				save_inventory()
			return true
	print("[InventoryManager] Inventario lleno!")
	return false

func remove_item(item_key: String, quantity: int = 1, target_array: Array = items) -> bool:
	for i in range(target_array.size()):
		if target_array[i] != null and target_array[i].get("key") == item_key:
			target_array[i]["qty"] -= quantity
			if target_array[i]["qty"] <= 0:
				target_array[i] = null
			inventory_changed.emit()
			return true
	return false

## Devuelve true si hay al menos un slot vacío disponible
func has_space(target_array: Array = items) -> bool:
	for slot in target_array:
		if slot == null:
			return true
	return false

func has_item(item_key: String, quantity: int = 1, target_array: Array = items) -> bool:
	var total = 0
	for item in target_array:
		if item != null and item.get("key") == item_key:
			total += item.get("qty", 1)
	return total >= quantity

func get_item_count(item_key: String, target_array: Array = items) -> int:
	var total = 0
	for item in target_array:
		if item != null and item.get("key") == item_key:
			total += item.get("qty", 1)
	return total

# ──────────────────────────────────────────────
# EQUIPAMIENTO
# ──────────────────────────────────────────────

func equip_item(item_key: String) -> bool:
	var item_index = _find_item_index(item_key, items)
	if item_index == -1:
		return false
	
	var item = items[item_index]
	if not item.has("slot"):
		return false
	
	var slot: String = item["slot"]
	
	# Desequipar item previo
	if equipped_items[slot] != null:
		_return_to_inventory(slot)
	
	# Equipar
	equipped_items[slot] = item.duplicate(true)
	items[item_index] = null
	
	_update_equipment_stats()
	item_equipped.emit(equipped_items[slot])
	inventory_changed.emit()
	save_inventory()
	return true

func unequip_item(slot: String) -> bool:
	if equipped_items[slot] == null:
		return false
	return _return_to_inventory(slot)

func _return_to_inventory(slot: String) -> bool:
	var item = equipped_items[slot]
	# Items con calidad son instancias únicas, usar add_item_instance
	var has_quality: bool = item.has("quality") and item["quality"] != ""
	var ok: bool
	if has_quality:
		ok = add_item_instance(item)
	else:
		ok = add_item(item["key"], 1)
	if ok:
		equipped_items[slot] = null
		_update_equipment_stats()
		item_unequipped.emit(slot)
		save_inventory()
		return true
	return false

func _find_item_index(item_key: String, target_array: Array) -> int:
	for i in range(target_array.size()):
		if target_array[i] != null and target_array[i].get("key") == item_key:
			return i
	return -1

func _update_equipment_stats() -> void:
	# ── PvE: stats con calidad y bonus aleatorios ──────────────
	var total_atk: int = 0
	var total_def: int = 0
	# ── PvP: solo stats base sin calidad ni bonus ──────────────
	var pvp_atk: int   = 0
	var pvp_def: int   = 0
	# ── Bonus stats adicionales (solo aplican en PvE) ──────────
	var bonus_max_hp: int      = 0
	var bonus_speed_pct: int   = 0
	var bonus_crit_pct: int    = 0
	var bonus_dmg_red: int     = 0
	var bonus_regen: int       = 0
	var bonus_heal_pct: int    = 0

	for slot in equipped_items:
		var item = equipped_items[slot]
		if item == null:
			continue
		# Stats completas (con multiplicador de calidad aplicado)
		total_atk += item.get("atk", 0)
		total_def += item.get("def", 0)
		# Stats PvP: usar pvp_atk/pvp_def guardados pre-calidad;
		# items de la DB sin calidad ya tienen el valor correcto en atk/def
		pvp_atk += item.get("pvp_atk", item.get("atk", 0))
		pvp_def += item.get("pvp_def", item.get("def", 0))
		# Acumular bonus stats aleatorias (solo PvE)
		for bs in item.get("bonus_stats", []):
			match bs.get("key", ""):
				"bonus_max_hp":      bonus_max_hp    += bs.get("value", 0)
				"bonus_speed_pct":   bonus_speed_pct += bs.get("value", 0)
				"bonus_crit_pct":    bonus_crit_pct  += bs.get("value", 0)
				"bonus_dmg_red_pct": bonus_dmg_red   += bs.get("value", 0)
				"bonus_regen":       bonus_regen     += bs.get("value", 0)
				"bonus_heal_pct":    bonus_heal_pct  += bs.get("value", 0)
				"bonus_atk":         total_atk       += bs.get("value", 0)
				"bonus_def":         total_def       += bs.get("value", 0)

	# Escribir en PlayerData
	PlayerData.equipment_attack      = total_atk
	PlayerData.equipment_defense     = total_def
	PlayerData.pvp_equipment_attack  = pvp_atk
	PlayerData.pvp_equipment_defense = pvp_def
	# Bonus PvE
	PlayerData.bonus_max_hp_gear      = bonus_max_hp
	PlayerData.bonus_speed_pct_gear   = bonus_speed_pct
	PlayerData.bonus_crit_pct_gear    = bonus_crit_pct
	PlayerData.bonus_dmg_red_pct_gear = bonus_dmg_red
	PlayerData.bonus_regen_gear       = bonus_regen
	PlayerData.bonus_heal_pct_gear    = bonus_heal_pct
	PlayerData.stat_updated.emit()

# ──────────────────────────────────────────────
# CONSUMIBLES
# ──────────────────────────────────────────────

func use_consumable(item_key: String) -> bool:
	if not has_item(item_key, 1):
		return false
	
	var db = item_database.get(item_key, {})
	if db.get("category") != "consumable":
		return false
	
	if db.has("heal_amount"):
		PlayerData.heal(db["heal_amount"])
	
	if db.has("energy_amount"):
		PlayerData.energy = min(float(PlayerData.max_energy), PlayerData.energy + float(db["energy_amount"]))
		PlayerData.energy_changed.emit(PlayerData.energy, PlayerData.max_energy)
	
	remove_item(item_key, 1)
	item_used.emit(item_key)
	return true

# ──────────────────────────────────────────────
# BANCO
# ──────────────────────────────────────────────

func deposit_to_bank(item_key: String, qty: int = 1) -> bool:
	if not has_item(item_key, qty):
		return false
	remove_item(item_key, qty)
	return add_item(item_key, qty, bank_items)

func withdraw_from_bank(item_key: String, qty: int = 1) -> bool:
	if not has_item(item_key, qty, bank_items):
		return false
	remove_item(item_key, qty, bank_items)
	return add_item(item_key, qty)

func expand_bank_slots(new_total: int) -> void:
	# Expande (nunca encoge) el array bank_items al nuevo total
	var current = bank_items.size()
	if new_total <= current:
		return
	for i in range(new_total - current):
		bank_items.append(null)
	print("[InventoryManager] Banco expandido a %d slots" % new_total)
	inventory_changed.emit()

func get_bank_slot_count() -> int:
	return bank_items.size()

# ──────────────────────────────────────────────
# UTILIDADES
# ──────────────────────────────────────────────

## Devuelve el color de rareza/calidad. Prioriza el campo "quality" sobre "rarity".
func get_item_display_color(item: Dictionary) -> Color:
	var q: String = item.get("quality", "")
	if q != "":
		return get_rarity_color(q)
	return get_rarity_color(item.get("rarity", "common"))

func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color(0.67, 0.67, 0.67)
		"uncommon":  return Color(0.2,  0.87, 0.4)
		"rare":      return Color(0.27, 0.6,  1.0)
		"epic":      return Color(0.8,  0.33, 1.0)
		"legendary": return Color(1.0,  0.67, 0.2)
		_:           return Color.WHITE

func get_category_icon(category: String) -> String:
	match category:
		"weapon":     return "⚔️"
		"armor":      return "🛡️"
		"consumable": return "🧪"
		"material":   return "💎"
		"tool":       return "⛏️"
		_:            return "📦"

func get_item_info(item_key: String) -> Dictionary:
	return item_database.get(item_key, {}).duplicate()

func get_inventory_used_slots() -> int:
	var count = 0
	for item in items:
		if item != null:
			count += 1
	return count

# ──────────────────────────────────────────────
# PASO 3 — Funciones adicionales para UI
# ──────────────────────────────────────────────

## Eliminar por índice directo (para vender desde la tienda)
func remove_item_at(index: int, target_array: Array = items) -> void:
	if index < 0 or index >= target_array.size():
		return
	target_array[index] = null
	inventory_changed.emit()
	save_inventory()

## Usar item consumible por índice de slot
func use_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var item = items[index]
	if item == null:
		return
	var cat = item.get("category", "")
	if cat != "consumable":
		return
	var hp_restore = item.get("hp_restore",    item.get("heal_amount",   0))
	var en_restore = item.get("energy_restore", item.get("energy_amount", 0))
	if hp_restore > 0:
		PlayerData.heal(hp_restore)
	if en_restore > 0:
		PlayerData.energy = min(float(PlayerData.max_energy), PlayerData.energy + float(en_restore))
		PlayerData.energy_changed.emit(PlayerData.energy, PlayerData.max_energy)
	var qty = item.get("qty", 1)
	if qty > 1:
		items[index]["qty"] = qty - 1
	else:
		items[index] = null
	item_used.emit(item.get("key", ""))
	inventory_changed.emit()
	save_inventory()

## Equipar por índice de slot (wrapper del original)
func equip_item_at(index: int) -> bool:
	if index < 0 or index >= items.size():
		return false
	var item = items[index]
	if item == null:
		return false
	return equip_item(item.get("key", ""))

# ──────────────────────────────────────────────
# TOOL SYSTEM — funciones requeridas por ToolManager
# ──────────────────────────────────────────────

## Devuelve la definición completa del ítem desde item_database.
## Si el ítem no existe devuelve un Dictionary vacío.
func get_item_data(item_key: String) -> Dictionary:
	if item_database.has(item_key):
		var data : Dictionary = item_database[item_key].duplicate(true)
		data["key"] = item_key   # asegurar que la key esté dentro
		return data
	return {}


