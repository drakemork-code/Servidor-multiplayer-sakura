# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node2D

# ============================================================
# RESOURCE NODE — Nodo de Recolección Genérico
#
# Sistema de farmeo mejorado:
#   • T1: requiere herramienta T1 + skill recolección nivel 1
#   • T2: requiere herramienta T2 + skill recolección nivel 5
#   • T3: requiere herramienta T3 + skill recolección nivel 10
#   • Sin herramienta → NO se puede recolectar ningún nodo
#   • XP de recolección escalada por tier del nodo
#   • Hierbas: sprites animados (kale/sunflower/mushroom) con
#     viento suave y parche de tierra al agotarse
# ============================================================

# ── Configuración por tipo ───────────────────────────────────
const TYPE_CONFIG: Dictionary = {
	"tree": {
		"icon":            "🌲",
		"available_color": Color(0.20, 0.55, 0.20),
		"depleted_color":  Color(0.40, 0.30, 0.20),
		"size":            Vector2(22, 28),
	},
	"herb": {
		"icon":            "🌿",
		"available_color": Color(0.25, 0.75, 0.35),
		"depleted_color":  Color(0.50, 0.45, 0.20),
		"size":            Vector2(16, 16),
	},
	"iron_ore": {
		"icon":            "⛏",
		"available_color": Color(0.55, 0.55, 0.65),
		"depleted_color":  Color(0.30, 0.28, 0.28),
		"size":            Vector2(20, 18),
		"texture":         "res://assets/decorations/ore_iron.png",
	},
	# ── NUEVOS TIPOS DE ORE ──────────────────────────────────
	"coal_ore": {
		"icon":            "🪨",
		"available_color": Color(0.25, 0.25, 0.28),
		"depleted_color":  Color(0.18, 0.17, 0.17),
		"size":            Vector2(20, 18),
		"texture":         "res://assets/decorations/ore_coal.png",
	},
	"stone_ore": {
		"icon":            "🪨",
		"available_color": Color(0.65, 0.62, 0.58),
		"depleted_color":  Color(0.38, 0.36, 0.34),
		"size":            Vector2(20, 18),
		"texture":         "res://assets/decorations/ore_stone.png",
	},
	"silver_ore": {
		"icon":            "🔩",
		"available_color": Color(0.78, 0.82, 0.90),
		"depleted_color":  Color(0.35, 0.36, 0.40),
		"size":            Vector2(20, 18),
		"texture":         "res://assets/decorations/ore_silver.png",
	},
	"gold_ore": {
		"icon":            "✨",
		"available_color": Color(1.0, 0.80, 0.20),
		"depleted_color":  Color(0.40, 0.35, 0.15),
		"size":            Vector2(20, 18),
		"texture":         "res://assets/decorations/ore_gold.png",
	},
	"bluestone_ore": {
		"icon":            "💠",
		"available_color": Color(0.20, 0.55, 1.0),
		"depleted_color":  Color(0.15, 0.25, 0.45),
		"size":            Vector2(20, 18),
		"texture":         "res://assets/decorations/ore_bluestone.png",
	},
	"mushroom": {
		"icon":            "🍄",
		"available_color": Color(0.80, 0.30, 0.30),
		"depleted_color":  Color(0.40, 0.25, 0.25),
		"size":            Vector2(16, 18),
	},
	"crystal": {
		"icon":            "💎",
		"available_color": Color(0.55, 0.80, 0.95),
		"depleted_color":  Color(0.35, 0.35, 0.45),
		"size":            Vector2(20, 26),
	},
	"bone": {
		"icon":            "🦴",
		"available_color": Color(0.85, 0.82, 0.70),
		"depleted_color":  Color(0.40, 0.38, 0.30),
		"size":            Vector2(18, 14),
	},
}

# ── Mapa recurso → profesión ────────────────────────────────
const RESOURCE_SKILL_MAP: Dictionary = {
	"iron_ore":     "mining",
	"coal_ore":     "mining",
	"stone_ore":    "mining",
	"silver_ore":   "mining",
	"gold_ore":     "mining",
	"bluestone_ore":"mining",
	"crystal":      "mining",
	"tree":         "woodcutting",
	"herb":         "herbalism",
	"mushroom":     "herbalism",
	"bone":         "herbalism",
}

# ── XP base por recolección (multiplicado por tier del nodo) ─
const RESOURCE_XP_BASE: Dictionary = {
	"iron_ore":     12,
	"coal_ore":     8,
	"stone_ore":    6,
	"silver_ore":   20,
	"gold_ore":     35,
	"bluestone_ore":60,
	"crystal":      15,
	"tree":         10,
	"herb":         8,
	"mushroom":     8,
	"bone":         6,
}

# Multiplicador de XP por tier del nodo
const NODE_TIER_XP_MULT: Dictionary = {
	1: 1.0,
	2: 2.0,
	3: 3.5,
}

# Nombre de las herramientas requeridas por profesión y tier
const TOOL_NAMES: Dictionary = {
	"mining":      ["", "Pico de Hierro", "Pico de Acero",    "Pico de Mithril"],
	"woodcutting": ["", "Hacha de Hierro","Hacha de Acero",   "Hacha de Mithril"],
	"herbalism":   ["", "Navaja Herbaria","Hoz de Plata",     "Guadaña de Mithril"],
}

# Nivel mínimo de skill de recolección por tier
const TIER_MIN_SKILL_LEVEL: Dictionary = {
	1: 1,
	2: 5,
	3: 10,
}

# ── Sprites de hierbas disponibles (se elige al azar en spawn) ──
const HERB_VARIANTS: Array = [
	"herb_kale",
	"herb_sunflower",
]
# Mushroom usa su propio sprite
const MUSHROOM_SPRITE_NAME: String = "herb_mushroom"

# ── Constantes de sprites herbales ──────────────────────────
const HERB_CELL_W:      int = 16    # ancho de cada frame en el strip (nativo 16x16 px)
const HERB_WIND_FRAMES: int = 4     # frames de animación de viento

# ── Constantes de sprites de árbol ──────────────────────────
const TREE_FRAME_W:     int = 96
const TREE_WIND_FRAMES: int = 4
const TREE_CHOP_FRAMES: int = 7

# ── Propiedades del nodo ─────────────────────────────────────
@export var resource_type:  String  = "herb"
@export var item_key:       String  = "material_herb"
@export var qty_min:        int     = 1
@export var qty_max:        int     = 3
@export var respawn_time:   float   = 30.0
@export var node_tier:      int     = 1     # Tier del nodo (1, 2 ó 3)
@export var herb_variant:   String  = ""    # Forzar variante ("herb_kale", "herb_sunflower")

var _available:     bool    = true
var _label:         Label   = null
var _body:          ColorRect = null
var _timer:         Timer   = null
var _interact_area: Area2D  = null
var _tier_label:    Label   = null
var _ore_sprite:    Sprite2D = null   # sprite PNG para ores con textura

# ── Sprite animado para árboles ──────────────────────────────
var _tree_sprite:       Sprite2D = null
var _tree_wind_timer:   Timer    = null
var _tree_frame:        int      = 0

# ── Sprite animado para hierbas/hongos ──────────────────────
var _herb_sprite:       Sprite2D = null
var _herb_wind_timer:   Timer    = null
var _herb_frame:        int      = 0
var _herb_sprite_name:  String   = ""   # nombre base del sprite seleccionado
var _herb_depleted_tex: Texture2D = null
var _herb_wind_tex:     Texture2D = null

signal resource_collected(item_key: String, quantity: int)

func _ready() -> void:
	_build_interact_area()
	_build_timer()

# ══════════════════════════════════════════════════════════════
# CONSTRUCCIÓN VISUAL
# ══════════════════════════════════════════════════════════════

func _build_visuals() -> void:
	var cfg: Dictionary = _get_config()

	# ── Para árboles: usar spritesheet animado si está disponible ──
	if resource_type == "tree":
		_build_tree_sprite()
		if _tree_sprite:
			return   # el sprite reemplaza al ColorRect + label

	# ── Para hierbas y hongos: usar sprites Sunnyside ──────────
	if resource_type == "herb" or resource_type == "mushroom":
		_build_herb_sprite()
		if _herb_sprite:
			return   # el sprite reemplaza al ColorRect + label

	# ── Para ores con textura definida: usar sprite PNG ─────────
	var tex_path: String = cfg.get("texture", "")
	if tex_path != "":
		# ── Aura de tier (brilla detrás del sprite) ─────────
		const TIER_COLORS: Array = [
			Color(1.0, 1.0, 1.0, 0.0),    # T0 sin aura
			Color(0.85, 0.85, 0.85, 0.55), # T1 blanco suave
			Color(0.35, 0.65, 1.0,  0.65), # T2 azul
			Color(1.0,  0.80, 0.15, 0.70), # T3 dorado
			Color(0.75, 0.20, 1.0,  0.75), # T4 púrpura
		]
		var aura_color: Color = TIER_COLORS[clamp(node_tier, 0, 4)]
		if aura_color.a > 0.0:
			var aura = Sprite2D.new()
			aura.texture = load(tex_path)
			aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			aura.scale    = Vector2(1.3, 1.3)
			aura.modulate = aura_color
			aura.z_index  = -1
			add_child(aura)
			# Animación de pulso suave
			var tw = create_tween()
			tw.set_loops()
			tw.tween_property(aura, "scale", Vector2(1.45, 1.45), 0.9)
			tw.tween_property(aura, "scale", Vector2(1.3,  1.3),  0.9)
		# ── Sprite principal ────────────────────────────────
		var ore_sprite = Sprite2D.new()
		ore_sprite.texture = load(tex_path)
		ore_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ore_sprite.scale   = Vector2(1.0, 1.0)
		add_child(ore_sprite)
		_body = null
		_ore_sprite = ore_sprite
		return

	# ── Fallback: ColorRect + emoji label ──────────────────────
	_body = ColorRect.new()
	_body.color    = cfg["available_color"]
	_body.size     = cfg["size"]
	_body.position = -cfg["size"] / 2.0
	add_child(_body)

	_label = Label.new()
	_label.text                            = cfg["icon"]
	_label.add_theme_font_size_override("font_size", 14)
	_label.horizontal_alignment            = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment             = VERTICAL_ALIGNMENT_CENTER
	_label.size                            = cfg["size"] + Vector2(4, 4)
	_label.position                        = -cfg["size"] / 2.0 - Vector2(2, 2)
	add_child(_label)

# ── Herb/mushroom sprite builder ─────────────────────────────
func _build_herb_sprite() -> void:
	# Elegir variante del sprite
	if herb_variant != "" and ResourceLoader.exists("res://assets/decorations/%s_wind_strip4.png" % herb_variant):
		_herb_sprite_name = herb_variant
	elif resource_type == "mushroom":
		_herb_sprite_name = MUSHROOM_SPRITE_NAME
	else:
		# Elegir al azar entre variantes disponibles
		var available_variants: Array = []
		for v in HERB_VARIANTS:
			if ResourceLoader.exists("res://assets/decorations/%s_wind_strip4.png" % v):
				available_variants.append(v)
		if available_variants.is_empty():
			return  # sin sprites → usar ColorRect fallback
		_herb_sprite_name = available_variants[randi() % available_variants.size()]

	var wind_path     = "res://assets/decorations/%s_wind_strip4.png" % _herb_sprite_name
	var depleted_path = "res://assets/decorations/herb_soil_depleted.png"

	if not ResourceLoader.exists(wind_path):
		return  # sin sprite → fallback

	_herb_wind_tex = load(wind_path)

	if ResourceLoader.exists(depleted_path):
		_herb_depleted_tex = load(depleted_path)

	_herb_sprite = Sprite2D.new()
	_herb_sprite.texture         = _herb_wind_tex
	_herb_sprite.texture_filter  = CanvasItem.TEXTURE_FILTER_NEAREST
	_herb_sprite.region_enabled  = true
	_herb_sprite.region_rect     = Rect2(0, 0, HERB_CELL_W, HERB_CELL_W)
	_herb_sprite.centered        = true
	_herb_sprite.scale            = Vector2(2.0, 2.0)   # 16px nativo → 32px en pantalla (1 tile)
	add_child(_herb_sprite)

	# Timer de viento con velocidad y fase aleatoria
	_herb_wind_timer = Timer.new()
	_herb_wind_timer.wait_time = randf_range(0.18, 0.28)
	_herb_wind_timer.autostart = false
	_herb_wind_timer.one_shot  = false
	add_child(_herb_wind_timer)
	_herb_frame = randi() % HERB_WIND_FRAMES   # fase aleatoria para variedad
	_herb_wind_timer.timeout.connect(_on_herb_wind_tick)
	_herb_wind_timer.start()

func _on_herb_wind_tick() -> void:
	if not is_instance_valid(_herb_sprite):
		return
	if _available:
		_herb_frame = (_herb_frame + 1) % HERB_WIND_FRAMES
		_herb_sprite.region_rect = Rect2(_herb_frame * HERB_CELL_W, 0, HERB_CELL_W, HERB_CELL_W)

# ── Tree sprite builder ──────────────────────────────────────
func _build_tree_sprite() -> void:
	var wind_path = "res://assets/decorations/tree_granjeo_wind.png"
	if not ResourceLoader.exists(wind_path):
		wind_path = "res://assets/decorations/tree_deco_wind.png"
	if not ResourceLoader.exists(wind_path):
		return

	var tex: Texture2D = load(wind_path)
	_tree_sprite = Sprite2D.new()
	_tree_sprite.texture        = tex
	_tree_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tree_sprite.region_enabled = true
	_tree_sprite.region_rect    = Rect2(0, 0, TREE_FRAME_W, TREE_FRAME_W)
	_tree_sprite.centered       = true
	_tree_sprite.position       = Vector2(0, -TREE_FRAME_W * 0.5)
	_tree_sprite.scale          = Vector2(1.6, 1.6)
	add_child(_tree_sprite)

	_tree_wind_timer = Timer.new()
	_tree_wind_timer.wait_time = randf_range(0.14, 0.20)
	_tree_wind_timer.autostart = false
	_tree_wind_timer.one_shot  = false
	add_child(_tree_wind_timer)
	_tree_frame = randi() % TREE_WIND_FRAMES
	_tree_wind_timer.timeout.connect(_on_tree_wind_tick)
	_tree_wind_timer.start()

func _on_tree_wind_tick() -> void:
	if not is_instance_valid(_tree_sprite):
		return
	if _available:
		_tree_frame = (_tree_frame + 1) % TREE_WIND_FRAMES
	_tree_sprite.region_rect = Rect2(_tree_frame * TREE_FRAME_W, 0, TREE_FRAME_W, TREE_FRAME_W)

# ── Tier badge ───────────────────────────────────────────────
func _build_tier_badge() -> void:
	_tier_label = Label.new()
	var tier_icons := ["", "T1", "T2★", "T3★★"]
	_tier_label.text = tier_icons[clamp(node_tier, 0, 3)]
	_tier_label.add_theme_font_size_override("font_size", 8)
	var tier_colors := [Color.WHITE, Color(0.7, 0.7, 0.7), Color(0.4, 0.8, 1.0), Color(1.0, 0.85, 0.1)]
	_tier_label.add_theme_color_override("font_color", tier_colors[clamp(node_tier, 0, 3)])
	_tier_label.add_theme_constant_override("outline_size", 2)
	_tier_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_tier_label.position = Vector2(-8, -_get_config()["size"].y / 2.0 - 14)
	add_child(_tier_label)

func _get_config() -> Dictionary:
	if resource_type in TYPE_CONFIG:
		return TYPE_CONFIG[resource_type]
	return TYPE_CONFIG["herb"]

# ══════════════════════════════════════════════════════════════
# ÁREA DE INTERACCIÓN
# ══════════════════════════════════════════════════════════════

func _build_interact_area() -> void:
	_interact_area = Area2D.new()
	var shape = CollisionShape2D.new()
	var rect  = RectangleShape2D.new()
	var cfg   = _get_config()
	rect.size               = cfg["size"] + Vector2(12, 12)
	shape.shape             = rect
	_interact_area.add_child(shape)
	add_child(_interact_area)
	_interact_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not _available:
		return
	if body.name == "Player" or body.is_in_group("player"):
		_attempt_collect()

# ══════════════════════════════════════════════════════════════
# RECOLECCIÓN — Verificación completa de herramienta + skill level
# ══════════════════════════════════════════════════════════════

func _attempt_collect() -> void:
	if not _available:
		return

	var profession: String = RESOURCE_SKILL_MAP.get(resource_type, "")
	var tool_mgr   = get_node_or_null("/root/ToolManager")
	var player_data = get_node_or_null("/root/PlayerData")

	# ── 1. Verificar que tiene herramienta equipada ──────────
	if tool_mgr:
		var equipped_tier: int = tool_mgr.get_equipped_tier(profession)
		if equipped_tier == 0:
			_show_hint_no_tool(profession, 1)
			return
		# ── 2. Verificar que la herramienta es del tier suficiente ──
		if not tool_mgr.can_gather(profession, node_tier):
			_show_hint_need_better_tool(profession, node_tier)
			return

	# ── 3. Verificar nivel de skill de recolección ──────────
	if player_data:
		var min_skill_lv: int = TIER_MIN_SKILL_LEVEL.get(node_tier, 1)
		var current_skill_lv: int = player_data.get_gathering_level(profession)
		if current_skill_lv < min_skill_lv:
			_show_hint_need_skill_level(profession, node_tier, min_skill_lv, current_skill_lv)
			return

	# ── Todo ok: recolectar ──────────────────────────────────
	_collect(profession, tool_mgr)

func _collect(profession: String, tool_mgr) -> void:
	if not _available:
		return

	_available = false

	var qty: int = randi_range(qty_min, qty_max)

	if tool_mgr and profession != "":
		qty += tool_mgr.get_drop_bonus(profession)

	_give_items(qty)
	_give_gathering_xp(qty, profession)

	if tool_mgr and profession != "":
		tool_mgr.consume_durability(profession)

	_set_depleted()

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("collect_" + resource_type)

	resource_collected.emit(item_key, qty)
	_timer.start(respawn_time)

# ── Mensajes de error ────────────────────────────────────────

func _show_hint_no_tool(profession: String, required_tier: int) -> void:
	var needed_name: String = _get_tool_name(profession, required_tier)
	var msg: String = "Necesitas: %s" % needed_name if needed_name != "" else "Herramienta T%d requerida" % required_tier
	_show_player_hint(msg, Color(1.0, 0.5, 0.1))
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("error")

func _show_hint_need_better_tool(profession: String, required_tier: int) -> void:
	var needed_name: String = _get_tool_name(profession, required_tier)
	var msg: String
	if needed_name != "":
		msg = "Necesitas: %s (T%d)" % [needed_name, required_tier]
	else:
		msg = "Herramienta T%d requerida" % required_tier
	_show_player_hint(msg, Color(1.0, 0.4, 0.1))
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("error")

func _show_hint_need_skill_level(profession: String, node_t: int, min_lv: int, cur_lv: int) -> void:
	var skill_names := {"mining": "Minería", "woodcutting": "Tala", "herbalism": "Herbolario"}
	var sname: String = skill_names.get(profession, profession.capitalize())
	var msg: String = "%s Nv.%d requerido (tienes %d)" % [sname, min_lv, cur_lv]
	_show_player_hint(msg, Color(0.9, 0.2, 0.8))
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("error")

func _get_tool_name(profession: String, tier: int) -> String:
	if TOOL_NAMES.has(profession) and tier >= 1 and tier <= 3:
		return TOOL_NAMES[profession][tier]
	return ""

func _show_player_hint(msg: String, color: Color) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if p.has_method("show_floating_text"):
			p.show_floating_text(msg, color)

func _give_gathering_xp(qty: int, profession: String = "") -> void:
	var skill: String = profession if profession != "" else str(RESOURCE_SKILL_MAP.get(resource_type, ""))
	if skill == "":
		return
	var xp_base: int   = int(RESOURCE_XP_BASE.get(resource_type, 8))
	var xp_mult: float = NODE_TIER_XP_MULT.get(node_tier, 1.0)
	var total_xp: int  = int(xp_base * xp_mult * qty)
	if has_node("/root/PlayerData"):
		get_node("/root/PlayerData").gain_gathering_xp(skill, total_xp)
		# Logro recolección
		var _am = get_node_or_null("/root/AchievementManager")
		if _am: _am.on_resource_gathered(1)
		_show_player_hint("+%d %s XP" % [total_xp, skill.capitalize()], Color(0.6, 1.0, 0.4))

func _give_items(qty: int) -> void:
	var inv = null
	if has_node("/root/InventoryManager"):
		inv = get_node("/root/InventoryManager")
	if inv and inv.has_method("add_item"):
		inv.add_item(item_key, qty)
	else:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var p = players[0]
			if p.has_method("add_to_inventory"):
				p.add_to_inventory(item_key, qty)
	print("[ResourceNode] Recolectado: %s ×%d" % [item_key, qty])

# ══════════════════════════════════════════════════════════════
# ESTADO VISUAL
# ══════════════════════════════════════════════════════════════

func _set_depleted() -> void:
	# ── Hierba/hongo con sprite: mostrar suelo vacío ──
	if _herb_sprite and is_instance_valid(_herb_sprite):
		_herb_wind_timer.stop()
		_play_herb_harvest_sequence()
		return

	# ── Árbol con sprite: reproducir secuencia de tala ──
	if _tree_sprite and is_instance_valid(_tree_sprite):
		_tree_wind_timer.stop()
		_play_chop_sequence()
		return

	# ── Ore con sprite PNG: oscurecer y encoger ──────────────
	if _ore_sprite and is_instance_valid(_ore_sprite):
		var tw = create_tween()
		tw.tween_property(_ore_sprite, "modulate", Color(0.3, 0.3, 0.3, 0.7), 0.2)
		tw.tween_property(_ore_sprite, "scale", Vector2(1.6, 1.6), 0.15)
		return

	if _body:
		var cfg = _get_config()
		_body.color = cfg["depleted_color"]
	if _label:
		_label.text = "✕"
		_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	if _tier_label:
		_tier_label.modulate.a = 0.3

func _play_herb_harvest_sequence() -> void:
	if not is_instance_valid(_herb_sprite):
		return

	# Animación de cosecha: escalar hacia arriba y desvanecer
	var tw = create_tween()
	tw.tween_property(_herb_sprite, "scale", Vector2(2.6, 2.6), 0.08)
	tw.tween_property(_herb_sprite, "scale", Vector2(0.0, 0.0), 0.15)
	tw.tween_callback(func():
		if not is_instance_valid(_herb_sprite):
			return
		# Mostrar suelo vacío
		if _herb_depleted_tex:
			_herb_sprite.texture        = _herb_depleted_tex
			_herb_sprite.region_enabled = false
			_herb_sprite.scale          = Vector2(1.0, 1.0)
			_herb_sprite.modulate       = Color(1.0, 1.0, 1.0, 0.7)
		else:
			_herb_sprite.modulate = Color(1.0, 1.0, 1.0, 0.3)
		if _tier_label:
			_tier_label.modulate.a = 0.3
	)

func _play_chop_sequence() -> void:
	var chop_path = "res://assets/decorations/tree_granjeo_chop.png"
	var chop_tex: Texture2D = null
	if ResourceLoader.exists(chop_path):
		chop_tex = load(chop_path)

	if not chop_tex:
		_tree_sprite.modulate = Color(0.5, 0.4, 0.3, 0.6)
		if _tier_label:
			_tier_label.modulate.a = 0.3
		return

	_tree_sprite.texture        = chop_tex
	_tree_sprite.region_enabled = true
	_tree_sprite.region_rect    = Rect2(0, 0, TREE_FRAME_W, TREE_FRAME_W)

	var seq_frame := [0]
	var seq_timer := Timer.new()
	seq_timer.wait_time = 0.12
	seq_timer.autostart = false
	seq_timer.one_shot  = false
	add_child(seq_timer)
	seq_timer.timeout.connect(func():
		if not is_instance_valid(_tree_sprite):
			seq_timer.queue_free()
			return
		_tree_sprite.region_rect = Rect2(seq_frame[0] * TREE_FRAME_W, 0, TREE_FRAME_W, TREE_FRAME_W)
		seq_frame[0] += 1
		if seq_frame[0] == 3:
			seq_timer.wait_time = 0.22
		elif seq_frame[0] == 5:
			seq_timer.wait_time = 0.35
		if seq_frame[0] >= TREE_CHOP_FRAMES:
			seq_timer.stop()
			seq_timer.queue_free()
			if _tier_label:
				_tier_label.modulate.a = 0.3
	)
	seq_timer.start()

func _set_available() -> void:
	# ── Hierba con sprite: restaurar animación de viento ──
	if _herb_sprite and is_instance_valid(_herb_sprite):
		if _herb_wind_tex:
			_herb_sprite.texture        = _herb_wind_tex
			_herb_sprite.region_enabled = true
			_herb_sprite.region_rect    = Rect2(0, 0, HERB_CELL_W, HERB_CELL_W)
			_herb_sprite.modulate       = Color.WHITE
		var tw = create_tween()
		_herb_sprite.scale = Vector2(0.0, 0.0)
		tw.tween_property(_herb_sprite, "scale", Vector2(2.4, 2.4), 0.15)
		tw.tween_property(_herb_sprite, "scale", Vector2(2.0, 2.0), 0.10)
		_herb_frame = 0
		if is_instance_valid(_herb_wind_timer):
			_herb_wind_timer.start()
		if _tier_label:
			_tier_label.modulate.a = 1.0
		return

	# ── Árbol con sprite: restaurar animación de viento ──
	if _tree_sprite and is_instance_valid(_tree_sprite):
		var wind_path = "res://assets/decorations/tree_granjeo_wind.png"
		if not ResourceLoader.exists(wind_path):
			wind_path = "res://assets/decorations/tree_deco_wind.png"
		if ResourceLoader.exists(wind_path):
			_tree_sprite.texture     = load(wind_path)
			_tree_sprite.region_rect = Rect2(0, 0, TREE_FRAME_W, TREE_FRAME_W)
			_tree_sprite.modulate    = Color.WHITE
		_tree_frame = 0
		if is_instance_valid(_tree_wind_timer):
			_tree_wind_timer.start()
		if _tier_label:
			_tier_label.modulate.a = 1.0
		return

	# ── Ore con sprite PNG: restaurar color y escala ──────────
	if _ore_sprite and is_instance_valid(_ore_sprite):
		var tw = create_tween()
		_ore_sprite.scale = Vector2(1.6, 1.6)
		tw.tween_property(_ore_sprite, "modulate", Color.WHITE, 0.2)
		tw.tween_property(_ore_sprite, "scale", Vector2(2.2, 2.2), 0.12)
		tw.tween_property(_ore_sprite, "scale", Vector2(2.0, 2.0), 0.08)
		if _tier_label:
			_tier_label.modulate.a = 1.0
		return

	var cfg = _get_config()
	if _body:
		_body.color = cfg["available_color"]
	if _label:
		_label.text = cfg["icon"]
		_label.remove_theme_color_override("font_color")
	if _tier_label:
		_tier_label.modulate.a = 1.0

# ══════════════════════════════════════════════════════════════
# RESPAWN
# ══════════════════════════════════════════════════════════════

func _build_timer() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_respawn)
	add_child(_timer)

func _on_respawn() -> void:
	_available = true
	_set_available()
	# Flash de respawn
	if _ore_sprite and is_instance_valid(_ore_sprite):
		var tw = create_tween()
		tw.tween_property(_ore_sprite, "modulate", Color(1.8, 1.8, 1.8), 0.15)
		tw.tween_property(_ore_sprite, "modulate", Color(1, 1, 1), 0.25)
	elif _body and is_instance_valid(_body):
		var tw = create_tween()
		tw.tween_property(_body, "modulate", Color(1.5, 1.5, 1.5), 0.15)
		tw.tween_property(_body, "modulate", Color(1, 1, 1), 0.25)

# ══════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════

const TYPE_DEFAULT_TIER: Dictionary = {
	"coal_ore":      1, "stone_ore":     1, "iron_ore":      1,
	"silver_ore":    2, "gold_ore":      2, "bluestone_ore": 3,
	"crystal":       2, "tree":          1, "herb":          1,
	"mushroom":      1, "bone":          1,
}

func setup(p_type: String, p_item: String, p_qty_min: int, p_qty_max: int,
		p_respawn: float, p_tier: int = -1) -> void:
	resource_type = p_type
	item_key      = p_item
	qty_min       = p_qty_min
	qty_max       = p_qty_max
	respawn_time  = p_respawn
	if p_tier == -1:
		node_tier = TYPE_DEFAULT_TIER.get(p_type, 1)
	else:
		node_tier = clamp(p_tier, 1, 4)
	# Auto-derive tiered item key for ores
	const ORE_TYPES = ["coal_ore","stone_ore","iron_ore","silver_ore","gold_ore","bluestone_ore"]
	if p_type in ORE_TYPES:
		var ore_name = p_type.replace("_ore", "")
		item_key = "ore_%s_t%d" % [ore_name, node_tier]
	_build_visuals()
	_build_tier_badge()

func setup_herb_variant(variant: String) -> void:
	herb_variant = variant

func is_available() -> bool:
	return _available
