# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# TOOL MANAGER — Autoload global
#
# Gestiona las herramientas de recolección del jugador:
#   • Equipar / desequipar por profesión
#   • Consultar tier máximo de nodo para una profesión
#   • Durabilidad: se gasta en cada recolección; al llegar a 0
#     la herramienta se rompe y vuelve al inventario dañada
#   • Señales para que la UI refleje cambios en tiempo real
#
# Profesiones:    "mining"  |  "woodcutting"  |  "herbalism"
# Tiers:          1 (hierro) | 2 (acero) | 3 (mithril)
# Nodos por tier:
#   Sin herramienta → solo T1
#   T1 tool         → T1
#   T2 tool         → T1, T2
#   T3 tool         → T1, T2, T3
# ============================================================

signal tool_equipped(profession: String, item: Dictionary)
signal tool_unequipped(profession: String)
signal tool_broken(profession: String, item: Dictionary)
signal tool_durability_changed(profession: String, current: int, maximum: int)

# Herramientas actualmente equipadas, una por profesión
var equipped_tools: Dictionary = {
	"mining":      null,
	"woodcutting": null,
	"herbalism":   null,
}

# ── Tabla: tool_type → tier máximo de nodo desbloqueado ────
# Tier 1 → accede a nodos T1
# Tier 2 → accede a nodos T1 y T2
# Tier 3 → accede a nodos T1, T2 y T3
# Sin herramienta → solo T1 (recolección manual básica)
const TOOL_MAX_NODE_TIER: Dictionary = {
	# Tier 1
	"tool_pickaxe_iron":      1,
	"tool_axe_iron":          1,
	"tool_herbalism_knife":   1,
	# Tier 2
	"tool_pickaxe_steel":     2,
	"tool_axe_steel":         2,
	"tool_herbalism_sickle":  2,
	# Tier 3
	"tool_pickaxe_mithril":   3,
	"tool_axe_mithril":       3,
	"tool_herbalism_scythe":  3,
}

# Bonus de velocidad de recolección por tier (multiplicador)
const TOOL_SPEED_BONUS: Dictionary = {
	1: 1.0,    # Sin cambio
	2: 0.75,   # 25% más rápido
	3: 0.55,   # 45% más rápido
}

# Bonus de cantidad de drop por tier (items extra garantizados)
const TOOL_DROP_BONUS: Dictionary = {
	1: 0,
	2: 0,
	3: 1,    # +1 ítem siempre en T3
}

# Durabilidad consumida por recolección
const DURABILITY_COST: Dictionary = {
	1: 1,
	2: 1,
	3: 2,    # Las herramientas T3 gastan más por acceso a nodos raros
}

# ──────────────────────────────────────────────
func _ready() -> void:
	print("[ToolManager] Inicializado")

# ══════════════════════════════════════════════════════════════
# EQUIPAR / DESEQUIPAR
# ══════════════════════════════════════════════════════════════

## Equipa una herramienta del inventario.
## Devuelve true si se equipó con éxito.
func equip_tool(item_key: String) -> bool:
	var inv := _get_inventory()
	if not inv:
		push_warning("[ToolManager] InventoryManager no disponible")
		return false

	var item : Dictionary = inv.get_item_data(item_key)
	if item.is_empty():
		push_warning("[ToolManager] Item no encontrado: " + item_key)
		return false

	if item.get("category", "") != "tool":
		push_warning("[ToolManager] El item no es una herramienta: " + item_key)
		return false

	var profession: String = item.get("tool_type", "")
	if profession == "" or not equipped_tools.has(profession):
		push_warning("[ToolManager] tool_type inválido: " + str(item))
		return false

	# Desequipar la herramienta previa de esta profesión si existe
	if equipped_tools[profession] != null:
		_do_unequip(profession)

	# Quitar del inventario y equipar
	if not inv.remove_item(item_key, 1):
		push_warning("[ToolManager] No se pudo quitar del inventario: " + item_key)
		return false

	equipped_tools[profession] = item.duplicate(true)
	equipped_tools[profession]["key"] = item_key

	print("[ToolManager] Equipado: %s → %s (tier %d)" % [
		item.get("name", item_key), profession, item.get("tier", 1)
	])
	tool_equipped.emit(profession, equipped_tools[profession])
	return true

## Desequipa la herramienta de una profesión y la devuelve al inventario.
func unequip_tool(profession: String) -> bool:
	if not equipped_tools.has(profession):
		return false
	if equipped_tools[profession] == null:
		return false
	return _do_unequip(profession)

func _do_unequip(profession: String) -> bool:
	var item: Dictionary = equipped_tools[profession]
	if item.is_empty():
		return false

	var inv := _get_inventory()
	if inv:
		inv.add_item(item["key"], 1)
		# Restaurar durabilidad guardada en el item equipado
		_update_item_durability_in_inv(item)

	equipped_tools[profession] = null
	tool_unequipped.emit(profession)
	print("[ToolManager] Desequipado: %s" % profession)
	return true

# ══════════════════════════════════════════════════════════════
# CONSULTAS DE TIER
# ══════════════════════════════════════════════════════════════

## Devuelve el tier máximo de nodo al que puede acceder el jugador
## para una profesión dada.
##   Sin herramienta → 1 (recolección a mano, solo T1)
##   Con herramienta → según TOOL_MAX_NODE_TIER
func get_max_node_tier(profession: String) -> int:
	var tool = equipped_tools.get(profession)
	if tool == null:
		return 1   # Sin herramienta: T1 manual
	var key: String = tool.get("key", "")
	return TOOL_MAX_NODE_TIER.get(key, 1)

## ¿Puede el jugador recolectar un nodo de este tier y profesión?
func can_gather(profession: String, node_tier: int) -> bool:
	return get_max_node_tier(profession) >= node_tier

## Tier de la herramienta equipada (0 si no hay herramienta).
func get_equipped_tier(profession: String) -> int:
	var tool = equipped_tools.get(profession)
	if tool == null:
		return 0
	return tool.get("tier", 1)

## Multiplicador de velocidad de recolección para la herramienta equipada.
## Valor < 1.0 → más rápido (menos segundos de espera).
func get_gather_speed_mult(profession: String) -> float:
	var tier := get_equipped_tier(profession)
	return TOOL_SPEED_BONUS.get(tier, 1.0)

## Items extra por drop para la herramienta equipada.
func get_drop_bonus(profession: String) -> int:
	var tier := get_equipped_tier(profession)
	return TOOL_DROP_BONUS.get(tier, 0)

## Nombre y tier de la herramienta equipada para mostrar en UI.
## Devuelve "" si no hay herramienta.
func get_equipped_name(profession: String) -> String:
	var tool = equipped_tools.get(profession)
	if tool == null:
		return ""
	return tool.get("name", "?")

## Devuelve un Dictionary con info de durabilidad: {current, maximum, pct}
func get_durability_info(profession: String) -> Dictionary:
	var tool = equipped_tools.get(profession)
	if tool == null:
		return {"current": 0, "maximum": 0, "pct": 0.0}
	var cur : int = tool.get("durability", 0)
	var mx  : int = tool.get("max_durability", 1)
	return {"current": cur, "maximum": mx, "pct": float(cur) / float(max(mx, 1))}

# ══════════════════════════════════════════════════════════════
# DURABILIDAD
# ══════════════════════════════════════════════════════════════

## Llamar desde ResourceNode al recolectar exitosamente.
## Gasta durabilidad y rompe la herramienta si llega a 0.
## Devuelve false si la herramienta se rompió.
func consume_durability(profession: String) -> bool:
	var tool = equipped_tools.get(profession)
	if tool == null:
		return true   # Sin herramienta: no hay durabilidad que gastar

	var tier     : int = tool.get("tier", 1)
	var cost     : int = DURABILITY_COST.get(tier, 1)
	var cur      : int = tool.get("durability", 0)
	var new_dur  : int = max(0, cur - cost)

	tool["durability"] = new_dur
	tool_durability_changed.emit(profession, new_dur, tool.get("max_durability", 1))

	if new_dur <= 0:
		_break_tool(profession)
		return false

	return true

func _break_tool(profession: String) -> void:
	var tool: Dictionary = equipped_tools[profession]
	print("[ToolManager] ⚠ Herramienta rota: %s" % tool.get("name", profession))

	# Devolver al inventario en estado roto (durabilidad 0)
	var inv := _get_inventory()
	if inv:
		# Guardamos la key para poder actualizar
		var key: String = tool.get("key", "")
		inv.add_item(key, 1)
		# Marcar en la base de datos como dañada
		_set_broken_in_db(key)

	tool_broken.emit(profession, tool)
	equipped_tools[profession] = null
	tool_unequipped.emit(profession)

	# Notificar al jugador visualmente
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if p.has_method("show_floating_text"):
			p.show_floating_text(
				"⚠ %s rota!" % tool.get("name", "Herramienta"),
				Color(1.0, 0.3, 0.1)
			)

	# SFX
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("error")

func _set_broken_in_db(item_key: String) -> void:
	var inv := _get_inventory()
	if not inv:
		return
	# Actualizar el ítem en el inventario con durabilidad = 0
	for i in range(inv.items.size()):
		if inv.items[i] != null and inv.items[i].get("key", "") == item_key:
			inv.items[i]["durability"] = 0
			inv.inventory_changed.emit()
			return

func _update_item_durability_in_inv(tool: Dictionary) -> void:
	# Al desequipar, sincronizar durabilidad actual en el inventario
	var inv := _get_inventory()
	if not inv:
		return
	var key: String = tool.get("key", "")
	for i in range(inv.items.size()):
		if inv.items[i] != null and inv.items[i].get("key", "") == key:
			inv.items[i]["durability"] = tool.get("durability", 0)
			inv.inventory_changed.emit()
			return

# ══════════════════════════════════════════════════════════════
# REPARACIÓN
# ══════════════════════════════════════════════════════════════

## Repara una herramienta en el inventario (no equipada).
## cost_bronze: precio cobrado al jugador (0 = gratis, para NPCs).
## Devuelve true si se reparó.
func repair_tool(item_key: String, cost_bronze: int = 0) -> bool:
	if cost_bronze > 0:
		if not PlayerData.spend_bronze(cost_bronze):
			print("[ToolManager] Bronce insuficiente para reparar")
			return false

	var inv := _get_inventory()
	if not inv:
		return false

	for i in range(inv.items.size()):
		var it = inv.items[i]
		if it != null and it.get("key", "") == item_key:
			var db_item = inv.item_database.get(item_key, {})
			inv.items[i]["durability"] = db_item.get("max_durability", it.get("max_durability", 200))
			inv.inventory_changed.emit()
			print("[ToolManager] Reparado: %s" % item_key)
			return true

	# Buscar también en herramienta equipada
	for prof in equipped_tools:
		var t = equipped_tools[prof]
		if t != null and t.get("key", "") == item_key:
			var db_item = inv.item_database.get(item_key, {}) if inv else {}
			equipped_tools[prof]["durability"] = db_item.get("max_durability", t.get("max_durability", 200))
			tool_durability_changed.emit(prof, equipped_tools[prof]["durability"], equipped_tools[prof].get("max_durability", 200))
			print("[ToolManager] Reparada (equipada): %s" % item_key)
			return true

	return false

## Coste de reparación en bronce para una herramienta dada su durabilidad actual.
func repair_cost(item_key: String) -> int:
	var inv := _get_inventory()
	if not inv:
		return 0
	var db_item = inv.item_database.get(item_key, {})
	var mx   : int = db_item.get("max_durability", 200)
	var tier : int = db_item.get("tier", 1)
	# 50% de durabilidad gastada = coste base × tier
	var base_cost_per_point : int = ([2, 5, 12] as Array)[tier - 1]   # bronce por punto de durabilidad
	# Buscar durabilidad actual
	var cur : int = mx
	if inv:
		for it in inv.items:
			if it != null and it.get("key", "") == item_key:
				cur = it.get("durability", mx)
				break
	for prof in equipped_tools:
		var t = equipped_tools[prof]
		if t != null and t.get("key", "") == item_key:
			cur = t.get("durability", mx)
			break
	var missing : int = max(0, mx - cur)
	return missing * base_cost_per_point

# ══════════════════════════════════════════════════════════════
# GUARDADO / CARGADO
# ══════════════════════════════════════════════════════════════

func get_save_data() -> Dictionary:
	var data := {}
	for prof in equipped_tools:
		var t = equipped_tools[prof]
		if t != null:
			data[prof] = { "key": t.get("key", ""), "durability": t.get("durability", 0) }
		else:
			data[prof] = null
	return data

func load_save_data(data: Dictionary) -> void:
	var inv := _get_inventory()
	if not inv:
		return
	for prof in data:
		var entry = data[prof]
		if entry == null:
			continue
		var item_key: String = entry.get("key", "")
		if item_key == "":
			continue
		# Poner el ítem en inventario temporalmente si no está
		# (puede ya estar si se cargó antes)
		var idx : int = inv._find_item_index(item_key, inv.items)
		if idx == -1:
			inv.add_item(item_key, 1)
		# Restaurar durabilidad guardada
		idx = inv._find_item_index(item_key, inv.items)
		if idx != -1:
			inv.items[idx]["durability"] = entry.get("durability", inv.items[idx].get("max_durability", 200))
		# Equipar
		equip_tool(item_key)

# ──────────────────────────────────────────────
# HELPERS PRIVADOS
# ──────────────────────────────────────────────

func _get_inventory() -> Node:
	return get_node_or_null("/root/InventoryManager")
