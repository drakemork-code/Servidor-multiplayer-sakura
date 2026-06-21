# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# BANK MANAGER — Autoload global
# Sistema de mejoras del banco: 4 tiers, +15 slots cada uno
#
# Slots:  Base=15 | T1=30 | T2=45 | T3=60 | T4=75
#
# Precios (bronce total — 100🥉=1🥈 | 100🥈=1🥇):
#   Tier 1 →    500 🥉  (5🥈)
#   Tier 2 →  2 000 🥉  (20🥈)
#   Tier 3 →  7 500 🥉  (75🥈 / 0.75🥇)
#   Tier 4 → 25 000 🥉  (250🥈 / 2.5🥇)
# ============================================================

signal bank_upgraded(new_tier: int, new_slots: int)
signal bank_slots_changed(new_slots: int)

const BASE_SLOTS     : int = 15
const SLOTS_PER_TIER : int = 15
const MAX_TIER        : int = 4

# Costos en bronce total
const UPGRADE_COSTS: Array[int] = [500, 2000, 7500, 25000]

const UPGRADE_LABELS: Array[String] = [
	"Almacén Básico",
	"Almacén Ampliado",
	"Bóveda de Plata",
	"Bóveda de Oro",
]

const UPGRADE_ICONS: Array[String] = ["🏦", "📦", "🏛️", "🏰"]

var bank_tier: int = 0   # 0 = sin mejoras (solo los 15 base)

# ──────────────────────────────────────────────
# PROPIEDADES
# ──────────────────────────────────────────────

func get_current_slots() -> int:
	return BASE_SLOTS + bank_tier * SLOTS_PER_TIER

func can_upgrade() -> bool:
	return bank_tier < MAX_TIER

func get_next_upgrade_cost() -> int:
	if bank_tier >= UPGRADE_COSTS.size():
		return 0
	return UPGRADE_COSTS[bank_tier]

func get_tier_label(tier: int = -1) -> String:
	if tier < 0:
		tier = bank_tier
	if tier == 0:
		return "Banco Básico"
	var idx = tier - 1
	if idx < UPGRADE_LABELS.size():
		return UPGRADE_LABELS[idx]
	return "Tier " + str(tier)

func get_tier_icon(tier: int = -1) -> String:
	if tier < 0:
		tier = bank_tier
	if tier == 0:
		return "🏦"
	var idx = tier - 1
	if idx < UPGRADE_ICONS.size():
		return UPGRADE_ICONS[idx]
	return "🏦"

# Convierte bronce total a texto legible: "2🥇 5🥈 37🥉"
func _format_cost(total_bronze: int) -> String:
	var g = int(total_bronze / 10000)
	var s = int((total_bronze % 10000) / 100)
	var b = total_bronze % 100
	var parts: Array = []
	if g > 0: parts.append("%d🥇" % g)
	if s > 0: parts.append("%d🥈" % s)
	if b > 0 or parts.is_empty(): parts.append("%d🥉" % b)
	return " ".join(parts)

# ──────────────────────────────────────────────
# COMPRAR MEJORA
# ──────────────────────────────────────────────

func try_upgrade() -> Dictionary:
	if not can_upgrade():
		return {"ok": false, "msg": "El banco ya está en su nivel máximo (%d espacios)." % get_current_slots()}

	var cost = get_next_upgrade_cost()
	var have = PlayerData.get_total_bronze()
	if have < cost:
		return {
			"ok":  false,
			"msg": "Fondos insuficientes.\nNecesitas %s\nTienes %s" % [_format_cost(cost), PlayerData.get_currency_text()]
		}

	PlayerData.spend_bronze(cost)

	bank_tier += 1
	var new_slots = get_current_slots()

	# Expandir array de items del banco en InventoryManager
	InventoryManager.expand_bank_slots(new_slots)

	save_bank_data()

	bank_upgraded.emit(bank_tier, new_slots)
	bank_slots_changed.emit(new_slots)

	return {
		"ok":    true,
		"msg":   "%s %s\n+%d espacios → %d total" % [get_tier_icon(), get_tier_label(), SLOTS_PER_TIER, new_slots],
		"tier":  bank_tier,
		"slots": new_slots,
	}

# ──────────────────────────────────────────────
# DESCRIPCIÓN DE PRÓXIMA MEJORA
# ──────────────────────────────────────────────

func get_upgrade_description() -> String:
	if not can_upgrade():
		return "🏆 Banco al máximo nivel\n%d espacios disponibles" % get_current_slots()
	var next_tier  = bank_tier + 1
	var cost       = get_next_upgrade_cost()
	var next_slots = BASE_SLOTS + next_tier * SLOTS_PER_TIER
	return "%s %s\n%d → %d espacios\nCosto: %s" % [
		get_tier_icon(next_tier),
		get_tier_label(next_tier),
		get_current_slots(),
		next_slots,
		_format_cost(cost),
	]

# ──────────────────────────────────────────────
# GUARDAR / CARGAR
# ──────────────────────────────────────────────

func save_bank_data() -> void:
	var file = FileAccess.open("user://bank.save", FileAccess.WRITE)
	if not file:
		push_error("[BankManager] No se pudo guardar bank.save")
		return
	var data: Dictionary = {
		"bank_tier":  bank_tier,
		"bank_items": [],
	}
	for item in InventoryManager.bank_items:
		data["bank_items"].append(item)
	file.store_var(data)
	file.close()
	print("[BankManager] Guardado — Tier %d, %d slots" % [bank_tier, get_current_slots()])

func load_bank_data() -> void:
	if not FileAccess.file_exists("user://bank.save"):
		_init_default()
		return
	var file = FileAccess.open("user://bank.save", FileAccess.READ)
	if not file:
		_init_default()
		return
	var data = file.get_var()
	file.close()

	if not data or typeof(data) != TYPE_DICTIONARY:
		_init_default()
		return

	bank_tier = clamp(data.get("bank_tier", 0), 0, MAX_TIER)
	var slots = get_current_slots()
	InventoryManager.expand_bank_slots(slots)

	var saved_items: Array = data.get("bank_items", [])
	InventoryManager.bank_items.clear()
	for i in range(slots):
		if i < saved_items.size():
			InventoryManager.bank_items.append(saved_items[i])
		else:
			InventoryManager.bank_items.append(null)

	print("[BankManager] Cargado — Tier %d, %d slots" % [bank_tier, slots])

func _init_default() -> void:
	bank_tier = 0
	InventoryManager.expand_bank_slots(get_current_slots())
