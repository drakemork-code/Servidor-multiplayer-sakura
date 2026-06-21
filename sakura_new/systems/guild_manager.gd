# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# GUILD MANAGER — Autoload global
# Gremios: crear, disolver, invitar, expulsar, rangos, MOTD, banco
# ============================================================

signal guild_created(guild_name: String)
signal guild_disbanded()
signal member_joined(player_name: String)
signal member_kicked(player_name: String)
signal motd_updated(motd: String)
signal guild_msg(sender: String, text: String)

enum Rank { LEADER, OFFICER, MEMBER }

const RANK_NAMES: Dictionary = {
	Rank.LEADER:  "Líder",
	Rank.OFFICER: "Oficial",
	Rank.MEMBER:  "Miembro",
}

var guild_name:  String = ""
var motd:        String = ""
var members:     Array  = []   # [{name, rank, online}]
var bank_items:  Array  = []   # misma estructura que InventoryManager.items
var _in_guild:   bool   = false

func _ready() -> void:
	_load_guild()
	print("[GuildManager] Inicializado")

# ──────────────────────────────────────────────
# CREAR / DISOLVER
# ──────────────────────────────────────────────
func create_guild(name: String) -> bool:
	if _in_guild or name.strip_edges() == "":
		return false
	guild_name = name.strip_edges()
	_in_guild  = true
	motd       = "¡Bienvenidos a %s!" % guild_name
	members    = [{"name": PlayerData.character_name, "rank": Rank.LEADER, "online": true}]
	guild_created.emit(guild_name)
	# Logro gremio
	var _am = get_node_or_null("/root/AchievementManager")
	if _am: _am.on_guild_joined()
	_save_guild()
	# Notificar al chat
	if has_node("/root/ChatManager"):
		get_node("/root/ChatManager").receive_message("guild",
			"Sistema", "Gremio «%s» fundado. ¡Buena suerte!" % guild_name)
	print("[GuildManager] Gremio creado: ", guild_name)
	return true

func disband_guild() -> void:
	if not _in_guild or not _is_leader():
		return
	guild_name = ""
	motd       = ""
	members.clear()
	bank_items.clear()
	_in_guild  = false
	guild_disbanded.emit()
	_delete_guild_save()
	print("[GuildManager] Gremio disuelto")

func is_in_guild() -> bool:
	return _in_guild

func get_guild_name() -> String:
	return guild_name

# ──────────────────────────────────────────────
# MIEMBROS
# ──────────────────────────────────────────────
func invite_member(player_name: String) -> bool:
	if not _in_guild or player_name.strip_edges() == "":
		return false
	# No duplicados
	for m in members:
		if m["name"].to_lower() == player_name.to_lower():
			return false
	members.append({"name": player_name, "rank": Rank.MEMBER, "online": false})
	member_joined.emit(player_name)
	_save_guild()
	if has_node("/root/ChatManager"):
		get_node("/root/ChatManager").receive_message("guild",
			"Sistema", "%s se ha unido al gremio." % player_name)
	return true

func kick_member(player_name: String) -> bool:
	if not _in_guild:
		return false
	var my_rank = _get_my_rank()
	if my_rank == Rank.MEMBER:
		return false   # solo lider/oficial pueden expulsar
	for i in members.size():
		var m = members[i]
		if m["name"].to_lower() == player_name.to_lower():
			if m["rank"] == Rank.LEADER:
				return false  # no se puede expulsar al lider
			members.remove_at(i)
			member_kicked.emit(player_name)
			_save_guild()
			return true
	return false

func set_rank(player_name: String, rank: Rank) -> bool:
	if not _in_guild or not _is_leader():
		return false
	for m in members:
		if m["name"].to_lower() == player_name.to_lower():
			m["rank"] = rank
			_save_guild()
			return true
	return false

func set_motd(text: String) -> void:
	if not _in_guild or _get_my_rank() == Rank.MEMBER:
		return
	motd = text.substr(0, 200)
	motd_updated.emit(motd)
	_save_guild()

func get_members() -> Array:
	return members

func get_member_count() -> int:
	return members.size()

# ──────────────────────────────────────────────
# BANCO DE GREMIO
# ──────────────────────────────────────────────
func deposit_item(item: Dictionary) -> bool:
	if not _in_guild:
		return false
	bank_items.append(item.duplicate())
	_save_guild()
	if has_node("/root/ChatManager"):
		get_node("/root/ChatManager").receive_message("guild", "Sistema",
			"%s depositó %s en el banco." % [PlayerData.character_name, item.get("name", "??")])
	return true

func withdraw_item(index: int) -> Dictionary:
	if index < 0 or index >= bank_items.size():
		return {}
	var item = bank_items[index]
	bank_items.remove_at(index)
	_save_guild()
	return item

func get_bank_items() -> Array:
	return bank_items

# ──────────────────────────────────────────────
# GUARDAR / CARGAR
# ──────────────────────────────────────────────
func _save_guild() -> void:
	var data = {
		"name":       guild_name,
		"motd":       motd,
		"members":    members,
		"bank_items": bank_items,
		"in_guild":   _in_guild,
	}
	var f = FileAccess.open("user://guild.save", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func _load_guild() -> void:
	if not FileAccess.file_exists("user://guild.save"):
		return
	var f = FileAccess.open("user://guild.save", FileAccess.READ)
	if not f:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data or typeof(data) != TYPE_DICTIONARY:
		return
	guild_name  = data.get("name", "")
	motd        = data.get("motd", "")
	members     = data.get("members", [])
	bank_items  = data.get("bank_items", [])
	_in_guild   = data.get("in_guild", false)

func _delete_guild_save() -> void:
	if FileAccess.file_exists("user://guild.save"):
		DirAccess.remove_absolute("user://guild.save")

# ──────────────────────────────────────────────
# UTILIDADES
# ──────────────────────────────────────────────
func _is_leader() -> bool:
	return _get_my_rank() == Rank.LEADER

func _get_my_rank() -> Rank:
	var my_name = PlayerData.character_name if PlayerData else ""
	for m in members:
		if m["name"] == my_name:
			return m["rank"]
	return Rank.MEMBER
