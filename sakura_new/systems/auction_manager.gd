# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# AUCTION MANAGER — Autoload global
# Sistema de Casa de Subastas: pujar, publicar y reclamar ítems.
# Los NPCs IA compiten automáticamente en subastas del jugador.
# ============================================================

signal auction_posted(listing: Dictionary)
signal bid_placed(listing_id: int, new_bid: int, bidder: String)
signal auction_expired(listing: Dictionary)
signal items_ready_to_claim(count: int)

# ── Constantes ───────────────────────────────────────────────
const AUCTION_DURATION_SEC : int   = 120   # 2 min por subasta
const NPC_BID_CHANCE       : float = 0.30  # 30% por tick de que un NPC puje
const NPC_BID_INCREMENT    : int   = 10    # Mínimo incremento NPC
const PROCESS_INTERVAL_SEC : float = 8.0   # Tick de procesado

const NPC_BIDDERS : Array = ["Kira", "Theron", "Magda", "Drek", "Sylva", "Oreyn", "Vael"]

# ── Estado ───────────────────────────────────────────────────
var listings    : Array = []   # Todas las subastas activas
var won_items   : Array = []   # Ítems ganados pendientes de reclamar
var _next_id    : int   = 1

# ============================================================
func _ready() -> void:
	_seed_initial_auctions()
	var t := Timer.new()
	t.wait_time  = PROCESS_INTERVAL_SEC
	t.autostart  = true
	t.timeout.connect(_process_tick)
	add_child(t)
	print("[AuctionManager] Listo — %d subastas iniciales" % listings.size())

# ── Subastas semilla (NPCs vendedores al inicio) ─────────────
func _seed_initial_auctions() -> void:
	_npc_post("weapon_iron_sword",        1,  55, "Drek",   randi_range(60, 110))
	_npc_post("armor_leather_chest",      1,  40, "Kira",   randi_range(80, 110))
	_npc_post("consumable_health_potion", 5,  12, "Sylva",  randi_range(40, 90))
	_npc_post("ore_iron_t1",      8,  15, "Theron", randi_range(8,  20))
	_npc_post("ore_iron_t2",      6,  12, "Theron", randi_range(22, 60))
	_npc_post("ore_iron_t3",      4,   8, "Theron", randi_range(60,150))
	_npc_post("ore_iron_t4",      2,   5, "Theron", randi_range(150,400))
	_npc_post("ore_coal_t1",     10,  20, "Theron", randi_range(5,  15))
	_npc_post("ore_coal_t2",      8,  15, "Theron", randi_range(15, 40))
	_npc_post("ore_coal_t3",      5,  10, "Theron", randi_range(40,100))
	_npc_post("ore_coal_t4",      2,   5, "Theron", randi_range(100,250))
	_npc_post("ore_silver_t1",    5,  10, "Theron", randi_range(20, 55))
	_npc_post("ore_silver_t2",    4,   8, "Theron", randi_range(55,130))
	_npc_post("ore_gold_t1",      3,   6, "Theron", randi_range(60,150))
	_npc_post("ore_gold_t2",      2,   4, "Theron", randi_range(150,400))
	_npc_post("ore_bluestone_t1", 2,   4, "Theron", randi_range(200,500))
	_npc_post("ore_bluestone_t2", 1,   3, "Theron", randi_range(500,1200))
	_npc_post("material_herb",           8,   8, "Magda",  randi_range(30, 80))
	_npc_post("armor_gloves",            1,  30, "Oreyn",  randi_range(60, 120))
	_npc_post("weapon_mace",             1,  70, "Vael",   randi_range(80, 120))
	_npc_post("armor_boots",             1,  35, "Kira",   randi_range(50, 100))

func _npc_post(item_key: String, qty: int, min_price: int,
               seller: String, duration: int) -> void:
	listings.append({
		"id":          _next_id,
		"item_key":    item_key,
		"qty":         qty,
		"seller":      seller,
		"min_price":   min_price,
		"current_bid": min_price,
		"top_bidder":  "",
		"time_left":   duration,
		"is_player":   false,
	})
	_next_id += 1

# ============================================================
# PUBLICAR ÍTEM (jugador)
# ============================================================
func post_item(item_key: String, qty: int, min_price: int) -> bool:
	if InventoryManager.get_item_count(item_key) < qty:
		return false
	InventoryManager.remove_item(item_key, qty)

	var listing := {
		"id":          _next_id,
		"item_key":    item_key,
		"qty":         qty,
		"seller":      PlayerData.character_name,
		"min_price":   min_price,
		"current_bid": min_price,
		"top_bidder":  "",
		"time_left":   AUCTION_DURATION_SEC,
		"is_player":   true,
	}
	_next_id += 1
	listings.append(listing)
	auction_posted.emit(listing)
	# Logro economía — primera venta
	var _am = get_node_or_null("/root/AchievementManager")
	if _am: _am.on_item_sold_auction()
	print("[AuctionManager] Publicado: %s x%d (mín %dg)" % [item_key, qty, min_price])
	return true

# ============================================================
# PUJAR (jugador)
# ============================================================
func place_bid(listing_id: int, bid_amount: int) -> bool:
	var listing := _find_listing(listing_id)
	if listing.is_empty():
		return false
	if bid_amount <= listing["current_bid"]:
		return false
	if PlayerData.get_total_bronze() < bid_amount:
		return false
	# Si el jugador ya era el pujador top, devolver la puja anterior
	if listing["top_bidder"] == PlayerData.character_name:
		PlayerData.add_bronze(listing["current_bid"])

	PlayerData.spend_bronze(bid_amount)
	listing["current_bid"] = bid_amount
	listing["top_bidder"]  = PlayerData.character_name
	bid_placed.emit(listing_id, bid_amount, PlayerData.character_name)
	print("[AuctionManager] Puja %d bronce en listing #%d" % [bid_amount, listing_id])
	return true

# ============================================================
# RECLAMAR ÍTEMS GANADOS
# ============================================================
func claim_won_items() -> int:
	var count := won_items.size()
	for w in won_items:
		InventoryManager.add_item(w["item_key"], w["qty"])
		print("[AuctionManager] Reclamado: %s x%d" % [w["item_key"], w["qty"]])
	won_items.clear()
	return count

func get_won_items_count() -> int:
	return won_items.size()

# ============================================================
# CONSULTAS
# ============================================================
func get_active_listings() -> Array:
	return listings.filter(func(l: Dictionary) -> bool: return l["time_left"] > 0)

func get_my_listings() -> Array:
	var pname := PlayerData.character_name
	return listings.filter(func(l: Dictionary) -> bool: return l["seller"] == pname)

func format_time(seconds: int) -> String:
	if seconds >= 60:
		return "%dm %ds" % [seconds / 60, seconds % 60]
	return "%ds" % seconds

# ============================================================
# TICK — Cada PROCESS_INTERVAL_SEC segundos
# ============================================================
func _process_tick() -> void:
	var expired : Array = []
	for listing in listings:
		if listing["time_left"] <= 0:
			expired.append(listing)
			continue
		listing["time_left"] -= int(PROCESS_INTERVAL_SEC)
		# NPCs pujan en subastas del jugador
		if listing.get("is_player", false) and listing["time_left"] > 0:
			_maybe_npc_bid(listing)
	for l in expired:
		_finalize(l)
		listings.erase(l)
	# Re-seedear si quedan pocas subastas
	if listings.size() < 4:
		_seed_initial_auctions()

func _maybe_npc_bid(listing: Dictionary) -> void:
	if randf() > NPC_BID_CHANCE:
		return
	var increment : int = randi_range(NPC_BID_INCREMENT, NPC_BID_INCREMENT * 3)
	var new_bid   : int = listing["current_bid"] + increment
	var bidder    : String = NPC_BIDDERS[randi() % NPC_BIDDERS.size()]
	# FIX 1: Si el jugador era el top bidder, reembolsarle su puja al ser superado
	var pname : String = PlayerData.character_name
	if listing["top_bidder"] == pname:
		PlayerData.add_bronze(listing["current_bid"])
		print("[AuctionManager] Reembolso %d bronce a %s (superado por NPC %s)" % [listing["current_bid"], pname, bidder])
	listing["current_bid"] = new_bid
	listing["top_bidder"]  = bidder
	bid_placed.emit(listing["id"], new_bid, bidder)

func _finalize(listing: Dictionary) -> void:
	var winner  : String = listing.get("top_bidder", "")
	var pname   : String = PlayerData.character_name
	auction_expired.emit(listing)

	if winner == pname:
		# Jugador ganó la subasta
		won_items.append({
			"item_key": listing["item_key"],
			"qty":      listing["qty"],
			"from":     listing["seller"],
		})
		items_ready_to_claim.emit(won_items.size())
		print("[AuctionManager] ¡Ganaste!: %s x%d" % [listing["item_key"], listing["qty"]])
	elif listing.get("is_player", false):
		if winner != "":
			# FIX: Aplicar descuento de comisión del evento semanal Gran Mercado
			var final_bronze : int = listing["current_bid"]
			var dlm = get_node_or_null("/root/DailyLoopManager")
			if dlm:
				var event = dlm.get_weekly_event()
				var discount_pct : float = event.get("auction_discount", 0.0)
				if discount_pct > 0.0:
					var discount : int = int(final_bronze * discount_pct)
					final_bronze -= discount
					print("[AuctionManager] %s: descuento comisión -%d bronce" % [event.get("name","?"), discount])
			PlayerData.add_bronze(final_bronze)
			print("[AuctionManager] Vendiste %s por %d bronce" % [listing["item_key"], final_bronze])
		else:
			# Sin pujas → devolver ítem
			InventoryManager.add_item(listing["item_key"], listing["qty"])
			print("[AuctionManager] Sin pujas, devuelto: %s" % listing["item_key"])

# ── Helpers ──────────────────────────────────────────────────
func _find_listing(id: int) -> Dictionary:
	for l in listings:
		if l["id"] == id:
			return l
	return {}
