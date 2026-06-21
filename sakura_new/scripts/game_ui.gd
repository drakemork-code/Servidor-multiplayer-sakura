# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends CanvasLayer

signal dialog_closed   # emitida al cerrar cualquier diálogo NPC

# ============================================================
# GAME UI — CanvasLayer  (Paso 3 — completo)
# HUD: HP, Energía, XP, Nivel, Oro
# Paneles: Inventario, Diálogo NPC, Tienda, Banco
# Tooltip flotante
# ============================================================

# ── HUD refs ────────────────────────────────────────────────
@onready var hp_bar       : ProgressBar = $HUDContainer/StatsBox/VBox/HPBar
@onready var hp_label     : Label       = $HUDContainer/StatsBox/VBox/HPLabel
@onready var energy_bar   : ProgressBar = $HUDContainer/StatsBox/VBox/EnergyBar
@onready var energy_label : Label       = $HUDContainer/StatsBox/VBox/EnergyLabel
@onready var level_label  : Label       = $HUDContainer/StatsBox/VBox/LevelLabel
@onready var gold_label   : RichTextLabel = $HUDContainer/StatsBox/VBox/GoldLabel
@onready var xp_bar       : ProgressBar = $HUDContainer/XPBarBG/XPBar
@onready var xp_label     : Label       = $HUDContainer/XPBarBG/XPLabel

# ── Paneles ─────────────────────────────────────────────────
@onready var inventory_panel : PanelContainer = $InventoryPanel
@onready var dialog_panel    : PanelContainer = $DialogPanel
@onready var shop_panel      : PanelContainer = $ShopPanel
@onready var bank_panel      : PanelContainer = $BankPanel
@onready var tooltip_panel   : PanelContainer = $TooltipPanel
@onready var panel_root      : Control        = $PanelRoot

# ── Inventario refs ─────────────────────────────────────────
@onready var slots_grid    : GridContainer  = $InventoryPanel/VBox/SlotsGrid
@onready var equip_row     : HBoxContainer  = $InventoryPanel/VBox/EquipmentRow
@onready var atk_label     : Label          = $InventoryPanel/VBox/StatsRow/AtkLabel
@onready var def_label     : Label          = $InventoryPanel/VBox/StatsRow/DefLabel

# ── Diálogo refs ────────────────────────────────────────────
@onready var dialog_text   : Label          = $DialogPanel/VBox/TextPadding/DialogTextBg/DialogText
@onready var dialog_btns   : HBoxContainer  = $DialogPanel/VBox/BtnPadding/ButtonsContainer
@onready var npc_name_lbl  : Label          = $DialogPanel/VBox/Header/HeaderInner/NameBox/NPCName
@onready var npc_role_lbl  : Label          = $DialogPanel/VBox/Header/HeaderInner/NameBox/NPCRole
@onready var npc_avatar    : ColorRect      = $DialogPanel/VBox/Header/HeaderInner/AvatarFrame/Avatar

# ── Tienda refs ─────────────────────────────────────────────
@onready var shop_gold_info : RichTextLabel   = $ShopPanel/VBox/TitleBar/GoldInfo
@onready var buy_grid       : GridContainer = $ShopPanel/VBox/BuyPanel/BuyGrid
@onready var sell_grid      : GridContainer = $ShopPanel/VBox/SellPanel/SellGrid

# ── Banco refs ──────────────────────────────────────────────
@onready var bank_inv_grid  : GridContainer = $BankPanel/VBox/HBox/InvColumn/InvScroll/InvGrid
@onready var bank_stor_grid : GridContainer = $BankPanel/VBox/HBox/BankColumn/BankScroll/BankGrid

# ── Tooltip refs ────────────────────────────────────────────
@onready var tip_title : Label = $TooltipPanel/VBox/Title
@onready var tip_desc  : Label = $TooltipPanel/VBox/Desc
@onready var tip_stats : Label = $TooltipPanel/VBox/Stats

# ── Skill Bar ───────────────────────────────────────────────
@onready var skill_bar      : Control      = $HUDContainer/SkillBar
@onready var skill_slots    : Array        = []   # rellenado en _ready()

# ── Estado ──────────────────────────────────────────────────
var is_inventory_open  : bool  = false
var is_dialog_open     : bool  = false
var is_shop_open       : bool  = false
var is_bank_open       : bool  = false
var _current_shop_id   : String = ""
var current_npc                = null
var current_dialog_index : int = 0
var current_dialog_lines : Array = []
var _typewriter_tween           = null
var inv_slot_nodes    : Array  = []
var equip_slot_nodes  : Dictionary = {}
var _drag_from_index  : int    = -1
var _drag_from_bank   : bool   = false
# ── Selección táctil (móvil/tablet) ─────────────────────────
var _touch_selected_index : int  = -1
var _touch_selected_bank  : bool = false
# ── Minimapa ─────────────────────────────────────────────────
var _minimap_panel:  PanelContainer = null
var _minimap_canvas: ColorRect      = null
var _minimap_player_dot: ColorRect  = null
var _minimap_zone:   String         = ""
# Límites del mundo en coordenadas de juego (se calculan por zona)
const MINIMAP_SIZE:   int   = 140   # tamaño del panel en píxeles de UI
const MINIMAP_MARGIN: int   = 6     # margen interior


# ── Controles móviles ────────────────────────────────────────
@onready var mobile_controls : Control = $MobileControls
@onready var joystick_base   : Control = $MobileControls/JoystickBase
@onready var joystick_knob   : ColorRect = $MobileControls/JoystickBase/Knob

var _joystick_touch_index : int     = -1
var _joystick_direction   : Vector2 = Vector2.ZERO
var _joystick_base_center : Vector2 = Vector2.ZERO
var _joystick_radius      : float   = 70.0

# Catálogos de tienda por NPC
# Precios expresados en BRONCE (100 bronce = 1 plata = 🥈)
# T2 requieren nivel de recolección ≥ 5 | T3 requieren nivel ≥ 10
const SHOP_CATALOGS : Dictionary = {
	"forge": [
		{key="weapon_broad_sword",   price=300},
		{key="weapon_mace",          price=350},
		{key="weapon_bow",           price=280},
		{key="armor_iron_helm",      price=200},
		{key="armor_iron_chest",     price=350},
	],
	"herbalist": [
		{key="consumable_health_potion",  price=40},
		{key="consumable_energy_potion",  price=35},
		{key="consumable_antidote",       price=30},
		{key="material_herb",             price=10},
	],
	"tailor": [
		{key="armor_leather_chest",  price=180},
		{key="gloves_leather",       price=80},
		{key="boots_leather",        price=90},
	],
	# Solo T1 comprables — T2 y T3 son exclusivamente crafteables
	"tools_mining": [
		{key="tool_pickaxe_iron",    price=200, tier=1, skill="mining"},
	],
	"tools_woodcutting": [
		{key="tool_axe_iron",    price=200, tier=1, skill="woodcutting"},
	],
	"tools_herbalism": [
		{key="tool_herbalism_knife",   price=150, tier=1, skill="herbalism"},
	],
}

const EQUIP_SLOTS : Array = ["head","weapon","chest","gloves","boots","ring"]
const EQUIP_ICONS : Dictionary = {
	"head":"🪖","weapon":"⚔️","chest":"🥋","gloves":"🧤","boots":"👢","ring":"💍"
}

# ============================================================
func _ready() -> void:
	add_to_group("ui")
	if true:
		GameManager.register_ui(self)

	# Señales
	PlayerData.health_changed.connect(_on_health_changed)
	PlayerData.energy_changed.connect(_on_energy_changed)
	PlayerData.xp_gained.connect(_on_xp_changed)
	PlayerData.level_up.connect(_on_level_up)
	PlayerData.stat_updated.connect(_on_stat_updated)
	PlayerData.currency_changed.connect(_on_currency_changed)
	PlayerData.gathering_skill_changed.connect(_on_gathering_skill_changed)
	PlayerData.player_died.connect(_on_player_died_penalty_screen)  # MEJORA 7
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	InventoryManager.item_added.connect(_on_item_added_to_inventory)

	# Init stats HUD
	_update_all_stats()

	# Ocultar todos los paneles
	inventory_panel.visible = false
	dialog_panel.visible    = false
	shop_panel.visible      = false
	bank_panel.visible      = false
	tooltip_panel.visible   = false

	# Conectar botones de cierre
	$InventoryPanel/VBox/TitleBar/CloseBtn.pressed.connect(close_inventory)
	$ShopPanel/VBox/TitleBar/CloseShopBtn.pressed.connect(close_shop)
	$BankPanel/VBox/TitleBar/CloseBankBtn.pressed.connect(close_bank)

	# Construir slots de inventario (8×5 = 40)
	_build_inventory_slots()
	_build_equip_slots()
	# Inicializar controles móviles
	_setup_mobile_controls()

	# ── HUD Config — aplicar configuración guardada ──────────
	_apply_hud_config()

	# ── ToolManager — conectar señales ───────────────────────
	if has_node("/root/ToolManager"):
		var tm = get_node("/root/ToolManager")
		tm.tool_equipped.connect(func(_p, _i): _build_tool_slots())
		tm.tool_unequipped.connect(func(_p): _build_tool_slots())
		tm.tool_broken.connect(_on_tool_broken)
		tm.tool_durability_changed.connect(_on_tool_durability_changed)

	# ── Botón de ajuste de HUD ───────────────────────────────
	_add_hud_edit_button()

	# ── Skill Bar ────────────────────────────────────────────
	_setup_skill_bar()

	# ── Minimapa ─────────────────────────────────────────────
	_setup_minimap()

	# ── MEJORA 9: Panel de Grupo ──────────────────────────────
	_setup_party_panel()

	# ── MOBILE MEJORA: teclado virtual + safe area listener ──
	_setup_mobile_enhancements()

# ============================================================
func _process(_delta: float) -> void:
	# Energía → float, actualizar cada frame
	if energy_bar:
		energy_bar.value = PlayerData.energy
	if energy_label:
		energy_label.text = "%d/%d EN" % [int(PlayerData.energy), PlayerData.max_energy]
	# Tooltip sigue el cursor
	if tooltip_panel and tooltip_panel.visible:
		if DisplayServer.is_touchscreen_available():
			# TOUCH FIX: el tooltip queda fijo cerca del slot tocado (esquina superior central)
			var vp := get_viewport().get_visible_rect().size
			tooltip_panel.position = Vector2(vp.x * 0.5 - 100.0, vp.y * 0.08)
		else:
			tooltip_panel.position = get_viewport().get_mouse_position() + Vector2(14, 14)
	# Actualizar minimapa
	_update_minimap()

# ============================================================
# HUD
# ============================================================
func _update_all_stats() -> void:
	_on_health_changed(PlayerData.hp, PlayerData.max_hp)
	_on_energy_changed(PlayerData.energy, PlayerData.max_energy)
	_on_level_up(PlayerData.level)
	_on_xp_changed(0)
	_on_stat_updated()

func _on_health_changed(new_hp: int, max_hp_val: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp_val
		hp_bar.value     = new_hp
	if hp_label:
		hp_label.text = "%d/%d HP" % [new_hp, max_hp_val]

func _on_energy_changed(new_en: float, max_en: int) -> void:
	if energy_bar:
		energy_bar.max_value = max_en
		energy_bar.value     = new_en

func _on_level_up(new_level: int) -> void:
	if level_label:
		level_label.text = "Nv. %d" % new_level
	# PASO 6 — Level-up burst mejorado
	_spawn_levelup_burst()

func _spawn_levelup_burst() -> void:
	var player_node = get_tree().get_first_node_in_group("player")
	var scene_root: Node = get_tree().current_scene

	# — Emisor 1: estrellas doradas hacia arriba —
	var stars := CPUParticles2D.new()
	stars.emitting             = true
	stars.one_shot             = true
	stars.amount               = 20
	stars.lifetime             = 0.9
	stars.explosiveness        = 0.85
	stars.direction            = Vector2(0, -1)
	stars.spread               = 55.0
	stars.initial_velocity_min = 60.0
	stars.initial_velocity_max = 130.0
	stars.gravity              = Vector2(0, 60)
	stars.scale_amount_min     = 4.0
	stars.scale_amount_max     = 7.0
	stars.color                = Color.GOLD
	stars.z_index              = 200
	if is_instance_valid(player_node):
		stars.position = player_node.global_position + Vector2(0, -8)
		scene_root.add_child.call_deferred(stars)
	else:
		stars.position = get_viewport().get_visible_rect().size * 0.5
		add_child.call_deferred(stars)

	# — Emisor 2: anillo expansivo de partículas —
	var ring := CPUParticles2D.new()
	ring.emitting              = true
	ring.one_shot              = true
	ring.amount                = 30
	ring.lifetime              = 0.6
	ring.explosiveness         = 1.0
	ring.emission_shape        = CPUParticles2D.EMISSION_SHAPE_SPHERE
	ring.emission_sphere_radius = 10.0
	ring.direction             = Vector2(0, 0)
	ring.spread                = 180.0
	ring.initial_velocity_min  = 90.0
	ring.initial_velocity_max  = 160.0
	ring.gravity               = Vector2.ZERO
	ring.scale_amount_min      = 3.0
	ring.scale_amount_max      = 5.0
	ring.color                 = Color(1.0, 0.92, 0.3, 0.85)
	ring.z_index               = 199
	if is_instance_valid(player_node):
		ring.position = player_node.global_position
		scene_root.add_child.call_deferred(ring)
	else:
		ring.position = get_viewport().get_visible_rect().size * 0.5
		add_child.call_deferred(ring)

	# — Luz puntual temporal de 0.5 s —
	var light := PointLight2D.new()
	light.energy       = 1.4
	light.color        = Color(1.0, 0.88, 0.3)
	light.texture_scale = 3.0
	light.z_index      = 198
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var dist = Vector2(x - 32, y - 32).length() / 32.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - dist, 0.0, 1.0)))
	light.texture = ImageTexture.create_from_image(img)
	if is_instance_valid(player_node):
		light.position = player_node.global_position
		scene_root.add_child.call_deferred(light)
	else:
		light.position = get_viewport().get_visible_rect().size * 0.5
		add_child.call_deferred(light)
	var tw_light := create_tween()
	tw_light.tween_property(light, "energy", 0.0, 0.5)
	tw_light.tween_callback(func(): if is_instance_valid(light): light.queue_free())

	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(stars): stars.queue_free()
	if is_instance_valid(ring):  ring.queue_free()

func _on_xp_changed(_amount: int) -> void:
	if xp_bar:
		var to_next = PlayerData.get_xp_to_next_level()
		xp_bar.max_value = to_next
		xp_bar.value     = PlayerData.xp
	if xp_label:
		xp_label.text = "XP %d / %d" % [PlayerData.xp, PlayerData.get_xp_to_next_level()]

func _on_stat_updated() -> void:
	_refresh_currency_labels()

func _on_currency_changed() -> void:
	_refresh_currency_labels()
	# FIX: reconstruir grid de compra para que los botones reflejen si el jugador puede pagar
	if is_shop_open and shop_panel.visible and _current_shop_id != "":
		_build_buy_grid(_current_shop_id)
	# Animación de destello en el label de monedas
	if gold_label:
		var tw := create_tween()
		tw.tween_property(gold_label, "modulate", Color(1.4, 1.3, 0.5, 1.0), 0.08)
		tw.tween_property(gold_label, "modulate", Color.WHITE, 0.25)

func _on_gathering_skill_changed(skill: String, new_level: int) -> void:
	# Si la tienda de herramientas está abierta, reconstruirla para mostrar nuevos desbloqueos
	if is_shop_open and _current_shop_id.begins_with("tools_"):
		_build_buy_grid(_current_shop_id)
	# Notificación en pantalla
	var ui_msg := ""
	match new_level:
		5: ui_msg = "🔓 ¡%s T2 desbloqueado!" % skill.capitalize()
		10: ui_msg = "🔓 ¡%s T3 desbloqueado!" % skill.capitalize()
		_: ui_msg = "↑ %s nivel %d" % [skill.capitalize(), new_level]
	_show_screen_notification(ui_msg, Color(0.4, 1.0, 0.6))

func _refresh_currency_labels() -> void:
	if gold_label:
		gold_label.text = _get_beautiful_currency_text()
	if shop_panel and shop_panel.visible and shop_gold_info:
		shop_gold_info.text = _get_beautiful_currency_text()

## Monedas con diseño visual bonito — iconos y colores por tipo
func _get_beautiful_currency_text() -> String:
	var g = PlayerData.gold
	var s = PlayerData.silver
	var b = PlayerData.bronze
	var parts: Array = []
	var img_g := "[img=16x16]res://assets/ui/coin_gold.png[/img]"
	var img_s := "[img=16x16]res://assets/ui/coin_silver.png[/img]"
	var img_b := "[img=16x16]res://assets/ui/coin_bronze.png[/img]"
	if g > 0: parts.append("%d%s" % [g, img_g])
	if s > 0: parts.append("%d%s" % [s, img_s])
	parts.append("%d%s" % [b, img_b])
	return " ".join(parts)

## Muestra un popup pequeño al costado del jugador indicando qué recogió
func show_item_pickup_popup(item_name: String, qty: int, icon: String = "") -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var lbl := Label.new()
	var qty_str := " x%d" % qty if qty > 1 else ""
	var ico_str := icon + " " if icon != "" else ""
	lbl.text = "+ %s%s%s" % [ico_str, item_name, qty_str]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.95, 1.0, 0.6, 1.0))
	# Outline para legibilidad
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.z_index = 95
	# Posición: al costado derecho del jugador, offset aleatorio en Y
	var rand_y_offset := randf_range(-20.0, 10.0)
	lbl.position = player.global_position + Vector2(22.0, -30.0 + rand_y_offset)
	get_tree().current_scene.add_child(lbl)
	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 38.0, 1.5)
	tw.tween_property(lbl, "position:x", lbl.position.x + 8.0, 1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.5)
	tw.finished.connect(func(): if is_instance_valid(lbl): lbl.queue_free())

# ============================================================
# INVENTARIO
# ============================================================
func _build_inventory_slots() -> void:
	for child in slots_grid.get_children():
		child.queue_free()
	inv_slot_nodes.clear()
	for i in range(40):
		var slot = _make_item_slot(i, false)
		slots_grid.add_child(slot)
		inv_slot_nodes.append(slot)

func _build_equip_slots() -> void:
	# Limpiar equip_row original y reusar como contenedor del nuevo panel
	for child in equip_row.get_children():
		child.queue_free()
	equip_slot_nodes.clear()

	# ── Contenedor principal del panel de equipamiento ─────────────────
	var equip_panel = _create_equip_panel()
	equip_row.add_child(equip_panel)

func _tex_style(path: String, fallback_color: Color = Color(0.08,0.05,0.14,0.97)) -> StyleBox:
	if ResourceLoader.exists(path):
		var tex = ResourceLoader.load(path, "Texture2D")
		if tex:
			var s = StyleBoxTexture.new()
			s.texture = tex
			return s
	var s = StyleBoxFlat.new()
	s.bg_color = fallback_color
	s.border_color = Color(0.55, 0.42, 0.12, 1.0)
	s.set_border_width_all(2)
	s.corner_radius_top_left = 5; s.corner_radius_top_right = 5
	s.corner_radius_bottom_left = 5; s.corner_radius_bottom_right = 5
	return s

func _create_equip_panel() -> Control:
	var root = PanelContainer.new()
	root.custom_minimum_size = Vector2(490, 180)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Textura de piedra oscura con remaches y grietas generada con Python
	root.add_theme_stylebox_override("panel", _tex_style("res://assets/ui/panel_stone.png", Color(0.06,0.04,0.10,0.97)))

	# ── Layout: izquierda | silueta | derecha | stats ──────────────────
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	root.add_child(hbox)

	# Columna izquierda: head / weapon
	var col_left = VBoxContainer.new()
	col_left.custom_minimum_size = Vector2(68, 0)
	col_left.add_theme_constant_override("separation", 4)
	col_left.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(col_left)

	# Silueta central del personaje
	var char_panel = _make_char_silhouette()
	hbox.add_child(char_panel)

	# Columna derecha: chest / gloves / boots / ring (2×2 grid)
	var col_right = GridContainer.new()
	col_right.columns = 2
	col_right.custom_minimum_size = Vector2(144, 0)
	col_right.add_theme_constant_override("h_separation", 4)
	col_right.add_theme_constant_override("v_separation", 4)
	hbox.add_child(col_right)

	# Separador
	var sep = VSeparator.new()
	sep.add_theme_color_override("color", Color(0.55, 0.42, 0.12, 0.5))
	hbox.add_child(sep)

	# Panel de stats totales
	var stats_panel = _make_stats_panel()
	hbox.add_child(stats_panel)

	# ── Crear slots por columna ────────────────────────────────────────
	var left_slots  = ["head", "weapon"]
	var right_slots = ["chest", "gloves", "boots", "ring"]

	for sk in left_slots:
		var slot = _make_equip_slot_card(sk)
		col_left.add_child(slot)
		equip_slot_nodes[sk] = slot

	# 2×2 grid: chest | gloves / boots | ring
	for sk in right_slots:
		var slot = _make_equip_slot_card(sk)
		col_right.add_child(slot)
		equip_slot_nodes[sk] = slot

	return root

func _make_char_silhouette() -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(100, 170)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	panel.add_theme_stylebox_override("panel", _tex_style("res://assets/ui/char_parchment.png", Color(0.09,0.06,0.16,0.85)))

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Título "Personaje"
	var title = Label.new()
	title.text = "— PERSONAJE —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.7, 0.58, 0.25, 1))
	vbox.add_child(title)

	# Silueta ASCII pixel-art del personaje (ColorRect dibujado por código)
	var silhouette = _draw_char_silhouette_node()
	vbox.add_child(silhouette)

	# Stats totales debajo de la silueta
	var stats_vbox = VBoxContainer.new()
	stats_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(stats_vbox)

	var atk_inner = Label.new()
	atk_inner.name = "SilAtk"
	atk_inner.text = "⚔  0"
	atk_inner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atk_inner.add_theme_font_size_override("font_size", 11)
	atk_inner.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1))
	stats_vbox.add_child(atk_inner)

	var def_inner = Label.new()
	def_inner.name = "SilDef"
	def_inner.text = "🛡  0"
	def_inner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	def_inner.add_theme_font_size_override("font_size", 11)
	def_inner.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0, 1))
	stats_vbox.add_child(def_inner)

	return panel

func _draw_char_silhouette_node() -> Control:
	# Dibuja una silueta simple pixel-art del personaje con ColorRects
	var container = Control.new()
	container.custom_minimum_size = Vector2(80, 100)

	# Escala de píxeles: cada "píxel" = 4×4 px reales
	var S = 4
	var ox = 20  # offset X para centrar en 80px
	var oy = 4

	# Mapa de píxeles de la silueta (0=vacío, 1=cuerpo, 2=detalle)
	var pixels = [
		[0,0,1,1,1,0,0],  # cabeza
		[0,0,1,1,1,0,0],
		[0,0,1,1,1,0,0],
		[0,1,1,1,1,1,0],  # hombros
		[0,1,1,1,1,1,0],  # torso
		[0,1,1,1,1,1,0],
		[0,1,1,1,1,1,0],
		[0,0,1,1,1,0,0],  # cintura
		[0,1,0,0,0,1,0],  # piernas
		[0,1,0,0,0,1,0],
		[0,1,0,0,0,1,0],
		[0,1,0,0,0,1,0],
		[0,1,1,0,1,1,0],  # pies
	]

	var body_col   = Color(0.35, 0.28, 0.55, 0.9)
	var detail_col = Color(0.55, 0.42, 0.12, 0.7)

	for row in range(pixels.size()):
		for col in range(pixels[row].size()):
			var v = pixels[row][col]
			if v == 0: continue
			var rect = ColorRect.new()
			rect.color = body_col if v == 1 else detail_col
			rect.position = Vector2(ox + col * S, oy + row * S)
			rect.size = Vector2(S - 1, S - 1)
			container.add_child(rect)

	return container

func _make_equip_slot_card(slot_key: String) -> PanelContainer:
	# Card completa: icono grande + nombre + stats
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(64, 76)

	card.add_theme_stylebox_override("panel", _tex_style("res://assets/ui/slot_metal.png", Color(0.10,0.07,0.18,0.9)))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# ── Etiqueta de slot (header pequeño) ─────────────────────────
	var slot_label = Label.new()
	slot_label.name = "SlotLabel"
	var slot_names = {"head":"CABEZA","weapon":"ARMA","chest":"PECHO",
	                  "gloves":"MANOS","boots":"PIES","ring":"ANILLO"}
	slot_label.text = slot_names.get(slot_key, slot_key.to_upper())
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.add_theme_font_size_override("font_size", 7)
	slot_label.add_theme_color_override("font_color", Color(0.65, 0.52, 0.20, 1))
	vbox.add_child(slot_label)

	# ── Área del icono ─────────────────────────────────────────────
	var icon_container = PanelContainer.new()
	icon_container.custom_minimum_size = Vector2(54, 42)

	var ic_style = StyleBoxFlat.new()
	ic_style.bg_color = Color(0.05, 0.03, 0.10, 0.95)
	ic_style.border_color = Color(0.28, 0.20, 0.06, 0.8)
	ic_style.set_border_width_all(1)
	ic_style.corner_radius_top_left     = 3
	ic_style.corner_radius_top_right    = 3
	ic_style.corner_radius_bottom_left  = 3
	ic_style.corner_radius_bottom_right = 3
	icon_container.add_theme_stylebox_override("panel", ic_style)
	vbox.add_child(icon_container)

	# TextureRect para PNG
	var icon_rect = TextureRect.new()
	icon_rect.name = "IconRect"
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_container.add_child(icon_rect)

	# Label fallback emoji
	var icon_lbl = Label.new()
	icon_lbl.name = "IconLabel"
	icon_lbl.text = EQUIP_ICONS.get(slot_key, "?")
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 22)
	icon_lbl.add_theme_color_override("font_color", Color(0.35, 0.30, 0.45, 0.7))
	icon_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_container.add_child(icon_lbl)

	# ── Nombre del item ────────────────────────────────────────────
	var name_lbl = Label.new()
	name_lbl.name = "ItemName"
	name_lbl.text = ""
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 7)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	name_lbl.clip_text = true
	name_lbl.custom_minimum_size = Vector2(58, 0)
	vbox.add_child(name_lbl)

	# ── Stats del item (ATK / DEF) ────────────────────────────────
	var stats_hbox = HBoxContainer.new()
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(stats_hbox)

	var atk_lbl = Label.new()
	atk_lbl.name = "ItemAtk"
	atk_lbl.text = ""
	atk_lbl.add_theme_font_size_override("font_size", 7)
	atk_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1))
	stats_hbox.add_child(atk_lbl)

	var def_lbl = Label.new()
	def_lbl.name = "ItemDef"
	def_lbl.text = ""
	def_lbl.add_theme_font_size_override("font_size", 7)
	def_lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0, 1))
	stats_hbox.add_child(def_lbl)

	# ── Interacción: click/tap para desequipar ─────────────────────
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_unequip_slot(slot_key)
		elif ev is InputEventScreenTouch and ev.pressed:
			_unequip_slot(slot_key)
	)

	return card

func _make_stats_panel() -> VBoxContainer:
	# FIX 3: panel más ancho, con padding, más stats y descripciones claras
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(120, 0)
	vbox.add_theme_constant_override("separation", 5)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN

	# Margin container para separar del borde
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_top",    6)
	margin.add_theme_constant_override("margin_bottom", 6)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	margin.add_child(inner)
	vbox.add_child(margin)

	var title = Label.new()
	title.text = "ESTADÍSTICAS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.85, 0.70, 0.30, 1))
	inner.add_child(title)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.55, 0.42, 0.12, 0.6))
	inner.add_child(sep)

	# Filas de stats con descripciones tooltips-friendly
	var stat_rows = [
		["stat_atk",  "⚔ Ataque",   Color(1.0,  0.45, 0.45, 1), "Daño base por golpe"],
		["stat_def",  "🛡 Defensa",  Color(0.45, 0.75, 1.0,  1), "Reduce daño recibido"],
		["stat_tier", "◆ Tier",     Color(0.8,  0.6,  1.0,  1), "Tier máximo equipado"],
		["stat_spd",  "👟 Velocidad",Color(0.4,  1.0,  0.6,  1), "Velocidad de movimiento"],
	]

	for row in stat_rows:
		var row_panel = PanelContainer.new()
		var row_style = StyleBoxFlat.new()
		row_style.bg_color = Color(0.10, 0.07, 0.18, 0.85)
		row_style.set_border_width_all(1)
		row_style.border_color = Color(0.35, 0.25, 0.55, 0.5)
		row_style.set_corner_radius_all(3)
		row_style.content_margin_left   = 6
		row_style.content_margin_right  = 6
		row_style.content_margin_top    = 3
		row_style.content_margin_bottom = 3
		row_panel.add_theme_stylebox_override("panel", row_style)

		var rh = HBoxContainer.new()
		rh.add_theme_constant_override("separation", 6)
		row_panel.add_child(rh)

		var lbl_key = Label.new()
		lbl_key.text = row[1]
		lbl_key.add_theme_font_size_override("font_size", 10)
		lbl_key.add_theme_color_override("font_color", row[2])
		lbl_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_key.tooltip_text = row[3]   # FIX 3: descripción al hacer hover
		rh.add_child(lbl_key)

		var lbl_val = Label.new()
		lbl_val.name = row[0]
		lbl_val.text = "—"
		lbl_val.add_theme_font_size_override("font_size", 11)
		lbl_val.add_theme_color_override("font_color", Color.WHITE)
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rh.add_child(lbl_val)

		inner.add_child(row_panel)

	var sep2 = HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.45, 0.32, 0.10, 0.4))
	inner.add_child(sep2)

	# Rareza dominante
	var rarity_lbl = Label.new()
	rarity_lbl.name = "stat_rarity"
	rarity_lbl.text = ""
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 10)
	rarity_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0, 1))
	inner.add_child(rarity_lbl)

	var hint = Label.new()
	hint.text = "Mantén → info del item"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(110, 0)
	inner.add_child(hint)

	return vbox

func _make_item_slot(index: int, from_bank: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(48, 48)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.4, 0.8)
	panel.add_theme_stylebox_override("panel", style)

	# PASO 14 — TextureRect para PNG, con Label emoji de fallback encima
	var icon_rect = TextureRect.new()
	icon_rect.name         = "Icon"
	icon_rect.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(icon_rect)

	var icon_lbl = Label.new()
	icon_lbl.name = "IconLabel"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_lbl.add_theme_font_size_override("font_size", 20)
	panel.add_child(icon_lbl)

	var qty_lbl = Label.new()
	qty_lbl.name = "Qty"
	qty_lbl.add_theme_font_size_override("font_size", 8)
	qty_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	qty_lbl.offset_left = -18; qty_lbl.offset_top = -14
	qty_lbl.offset_right = 0;  qty_lbl.offset_bottom = 0
	qty_lbl.add_theme_color_override("font_color", Color(1,1,0.6,1))
	panel.add_child(qty_lbl)

	# Eventos de mouse
	panel.mouse_entered.connect(func(): _on_slot_hover(index, from_bank))
	panel.mouse_exited.connect(func(): _hide_tooltip())
	panel.gui_input.connect(func(ev): _on_slot_input(ev, index, from_bank))

	return panel

func _update_slot_visual(slot: PanelContainer, item) -> void:
	if not slot: return
	var icon_rect : TextureRect = slot.get_node_or_null("Icon")
	var icon_lbl  : Label       = slot.get_node_or_null("IconLabel")
	var qty_lbl   : Label       = slot.get_node_or_null("Qty")
	var style = StyleBoxFlat.new()

	if item == null:
		style.bg_color     = Color(0.08, 0.08, 0.12, 0.9)
		style.border_color = Color(0.3, 0.3, 0.4, 0.8)
		style.set_border_width_all(1)
		if icon_rect: icon_rect.texture = null
		if icon_lbl:  icon_lbl.text     = ""
		if qty_lbl:   qty_lbl.text      = ""
	else:
		var rc = InventoryManager.get_item_display_color(item)
		style.bg_color     = Color(rc.r*0.2, rc.g*0.2, rc.b*0.2, 0.9)
		style.border_color = rc
		style.set_border_width_all(2)

		# PASO 14 — intentar cargar PNG del ítem; fallback a emoji
		var item_key: String = item.get("key", item.get("id", ""))
		var png_path: String = "res://assets/items/%s.png" % item_key
		var tex = ResourceLoader.load(png_path, "Texture2D") if (item_key != "" and ResourceLoader.exists(png_path)) else null
		if tex:
			if icon_rect: icon_rect.texture = tex
			if icon_lbl:  icon_lbl.text     = ""
		else:
			if icon_rect: icon_rect.texture = null
			if icon_lbl:  icon_lbl.text     = InventoryManager.get_category_icon(item.get("category",""))

		var qty = item.get("qty", 1)
		if qty_lbl: qty_lbl.text = str(qty) if qty > 1 else ""

	slot.add_theme_stylebox_override("panel", style)

func refresh_inventory_ui() -> void:
	for i in range(inv_slot_nodes.size()):
		var item = InventoryManager.items[i] if i < InventoryManager.items.size() else null
		_update_slot_visual(inv_slot_nodes[i], item)

	# ── Equipamiento: actualizar cada card ────────────────────────────
	var total_atk  : int = PlayerData.get_total_attack()
	var total_def  : int = PlayerData.get_total_defense()
	var max_tier   : int = 0
	var top_rarity : String = "common"
	var rarity_rank = {"common":0,"uncommon":1,"rare":2,"epic":3,"legendary":4}

	for slot_key in equip_slot_nodes:
		var card : PanelContainer = equip_slot_nodes[slot_key]
		var equipped = InventoryManager.equipped_items.get(slot_key)
		_refresh_equip_card(card, slot_key, equipped)

		if equipped:
			var t = equipped.get("tier", 1)
			if t > max_tier: max_tier = t
			var r = equipped.get("rarity", "common")
			if rarity_rank.get(r, 0) > rarity_rank.get(top_rarity, 0):
				top_rarity = r

	# ── Panel de stats lateral ────────────────────────────────────────
	_refresh_stats_side_panel(total_atk, total_def, max_tier, top_rarity)

	# ── Labels ATK/DEF en el panel principal (silueta) ───────────────
	var sil_panel = equip_row.get_node_or_null("../EquipmentRow")
	# Buscar dentro del árbol del equip_row
	_update_label_in_tree(equip_row, "SilAtk", "⚔  %d" % total_atk)
	_update_label_in_tree(equip_row, "SilDef", "🛡  %d" % total_def)

	# Stats originales (compatibilidad)
	if atk_label: atk_label.text = "⚔ ATK: %d" % total_atk
	if def_label: def_label.text = "🛡 DEF: %d" % total_def

func _refresh_equip_card(card: PanelContainer, slot_key: String, equipped) -> void:
	var vbox = card.get_child(0) if card.get_child_count() > 0 else null
	if not vbox: return

	var icon_container = card.get_node_or_null("VBoxContainer/PanelContainer") 
	# Buscar nodos por nombre
	var icon_rect  = _find_node_by_name(card, "IconRect")
	var icon_lbl   = _find_node_by_name(card, "IconLabel")
	var name_lbl   = _find_node_by_name(card, "ItemName")
	var atk_lbl    = _find_node_by_name(card, "ItemAtk")
	var def_lbl    = _find_node_by_name(card, "ItemDef")

	# Actualizar borde de rareza del card
	var card_style = StyleBoxFlat.new()
	card_style.corner_radius_top_left     = 5
	card_style.corner_radius_top_right    = 5
	card_style.corner_radius_bottom_left  = 5
	card_style.corner_radius_bottom_right = 5

	if equipped:
		var rc = InventoryManager.get_item_display_color(equipped)
		var item_key = equipped.get("key", equipped.get("id", ""))

		# Borde de rareza brillante
		card_style.bg_color    = Color(rc.r * 0.12, rc.g * 0.12, rc.b * 0.12, 0.95)
		card_style.border_color = rc
		card_style.set_border_width_all(2)
		card_style.shadow_color = Color(rc.r, rc.g, rc.b, 0.5)
		card_style.shadow_size  = 4

		# Icono PNG
		var png_path = "res://assets/items/%s.png" % item_key
		var tex = ResourceLoader.load(png_path, "Texture2D") if (item_key != "" and ResourceLoader.exists(png_path)) else null
		if icon_rect:
			icon_rect.texture = tex
			icon_rect.modulate = Color.WHITE
		if icon_lbl:
			icon_lbl.text = "" if tex else InventoryManager.get_category_icon(equipped.get("category",""))
			icon_lbl.add_theme_color_override("font_color", rc if not tex else Color.TRANSPARENT)

		# Nombre (recortado)
		var iname = equipped.get("name", slot_key)
		if name_lbl:
			name_lbl.text = iname
			name_lbl.add_theme_color_override("font_color", rc)

		# Stats individuales del item
		var iatk = equipped.get("atk", 0)
		var idef = equipped.get("def", 0)
		if atk_lbl: atk_lbl.text = "⚔%d" % iatk if iatk > 0 else ""
		if def_lbl: def_lbl.text = "🛡%d" % idef if idef > 0 else ""

	else:
		# Slot vacío
		card_style.bg_color    = Color(0.10, 0.07, 0.18, 0.9)
		card_style.border_color = Color(0.35, 0.28, 0.08, 0.6)
		card_style.set_border_width_all(1)
		card_style.shadow_size = 0

		if icon_rect: icon_rect.texture = null
		if icon_lbl:
			icon_lbl.text = EQUIP_ICONS.get(slot_key, "?")
			icon_lbl.add_theme_color_override("font_color", Color(0.35, 0.30, 0.45, 0.7))
		if name_lbl: name_lbl.text = ""
		if atk_lbl:  atk_lbl.text  = ""
		if def_lbl:  def_lbl.text  = ""

	card.add_theme_stylebox_override("panel", card_style)

func _refresh_stats_side_panel(total_atk: int, total_def: int, max_tier: int, top_rarity: String) -> void:
	# Buscar el VBoxContainer de stats (último hijo del HBoxContainer dentro de equip_row)
	if equip_row.get_child_count() == 0: return
	var equip_panel = equip_row.get_child(0)
	if not equip_panel: return
	var hbox = equip_panel.get_child(0) if equip_panel.get_child_count() > 0 else null
	if not hbox: return

	_update_label_in_tree(hbox, "stat_atk",    str(total_atk))
	_update_label_in_tree(hbox, "stat_def",    str(total_def))
	_update_label_in_tree(hbox, "stat_tier",   "T%d" % max(max_tier, 1))
	_update_label_in_tree(hbox, "stat_spd",    str(PlayerData.get_total_speed()))  # FIX 3: velocidad
	_update_label_in_tree(hbox, "SilAtk",      "⚔  %d" % total_atk)
	_update_label_in_tree(hbox, "SilDef",      "🛡  %d" % total_def)

	var rarity_lbl = _find_node_by_name(hbox, "stat_rarity")
	if rarity_lbl:
		var rarity_names = {"common":"Común","uncommon":"Infrecuente","rare":"Raro","epic":"Épico","legendary":"Legendario"}
		var rarity_colors = {
			"common":    Color(0.67, 0.67, 0.67),
			"uncommon":  Color(0.2,  0.87, 0.4),
			"rare":      Color(0.27, 0.6,  1.0),
			"epic":      Color(0.8,  0.33, 1.0),
			"legendary": Color(1.0,  0.67, 0.2)
		}
		rarity_lbl.text = "◈ " + rarity_names.get(top_rarity, top_rarity)
		rarity_lbl.add_theme_color_override("font_color", rarity_colors.get(top_rarity, Color.WHITE))

func _find_node_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name: return root
	for child in root.get_children():
		var found = _find_node_by_name(child, target_name)
		if found: return found
	return null

func _update_label_in_tree(root: Node, target_name: String, new_text: String) -> void:
	var lbl = _find_node_by_name(root, target_name)
	if lbl and lbl is Label:
		lbl.text = new_text

func _on_inventory_changed() -> void:
	if is_inventory_open:
		refresh_inventory_ui()

func _on_item_added_to_inventory(item_key: String, quantity: int) -> void:
	var info : Dictionary = InventoryManager.get_item_info(item_key)
	var item_name : String = info.get("name", item_key)
	var icon : String = InventoryManager.get_category_icon(info.get("category", ""))
	show_item_pickup_popup(item_name, quantity, icon)

var _inv_toggle_frame: int = -1  # guard anti-doble disparo

func toggle_inventory() -> void:
	var cur_frame = Engine.get_process_frames()
	if cur_frame == _inv_toggle_frame:
		return  # mismo frame = doble disparo, ignorar
	_inv_toggle_frame = cur_frame
	is_inventory_open = not is_inventory_open
	inventory_panel.visible = is_inventory_open
	if is_inventory_open:
		refresh_inventory_ui()

func close_inventory() -> void:
	is_inventory_open = false
	inventory_panel.visible = false

# ── Slots: hover / input ─────────────────────────────────────
func _on_slot_hover(index: int, from_bank: bool) -> void:
	var item = InventoryManager.bank_items[index] if from_bank else (InventoryManager.items[index] if index < InventoryManager.items.size() else null)
	if item == null: return
	_show_tooltip(item)

func _hide_tooltip() -> void:
	tooltip_panel.visible = false

func _show_tooltip(item: Dictionary) -> void:
	# Priorizar quality sobre rarity para colores
	var quality: String = item.get("quality", "")
	var rarity: String  = item.get("rarity", "common")
	var display_rarity: String = quality if quality != "" else rarity
	var rc = InventoryManager.get_rarity_color(display_rarity)

	# Nombre con icono de calidad si aplica
	var base_name: String = item.get("name", item.get("key", "?"))
	tip_title.text = base_name
	tip_title.add_theme_color_override("font_color", rc)

	# Descripción (puede incluir la línea de calidad ya embebida por QualitySystem)
	tip_desc.text  = item.get("desc", item.get("description", ""))

	var stats_txt  = ""

	# Calidad (si existe)
	if quality != "":
		var q_icon: String = QualitySystem.get_quality_icon(quality)
		var q_name: String = QualitySystem.get_quality_name(quality)
		stats_txt += "%s %s\n" % [q_icon, q_name]

	if item.has("atk") and item["atk"] > 0: stats_txt += "ATK +%d  " % item["atk"]
	if item.has("def") and item["def"] > 0: stats_txt += "DEF +%d  " % item["def"]
	if item.has("hp_restore"):  stats_txt += "HP +%d  "  % item["hp_restore"]

	# ── Durabilidad de herramientas ───────────────────────────
	if item.get("category", "") == "tool":
		var cur : int = item.get("durability", item.get("max_durability", 0))
		var mx  : int = item.get("max_durability", 0)
		var pct : int = int(float(cur) / float(max(mx, 1)) * 100.0)
		stats_txt += "\n🔧 Durabilidad: %d/%d (%d%%)" % [cur, mx, pct]
		var tier: int = item.get("tier", 1)
		var tier_str := ["", "T1 — nodos básicos", "T2 — nodos medios", "T3 — nodos épicos"]
		if tier >= 1 and tier <= 3:
			stats_txt += "\n📊 %s" % tier_str[tier]
	elif item.has("durability") and item.get("category","") in ["weapon","armor"]:
		var cur : int = item.get("durability", item.get("max_durability", 0))
		var mx  : int = item.get("max_durability", 0)
		if mx > 0:
			var pct : int = int(float(cur) / float(max(mx, 1)) * 100.0)
			# FIX 4C: color según estado de durabilidad
			var dur_icon : String
			if pct > 60:   dur_icon = "🟩"
			elif pct > 25: dur_icon = "🟨"
			else:          dur_icon = "🟥"
			var estado : String
			if pct == 0:    estado = " ¡ROTA!"
			elif pct <= 25: estado = " Crítica"
			elif pct <= 60: estado = " Dañada"
			else:           estado = ""
			stats_txt += "\n%s Durabilidad: %d/%d%s" % [dur_icon, cur, mx, estado]
			if pct == 0:
				stats_txt += "\n   → Repara en herrero"

	tip_stats.text    = stats_txt
	tooltip_panel.visible = true

func _on_slot_input(ev: InputEvent, index: int, from_bank: bool) -> void:
	# ── Ratón (PC) ───────────────────────────────────────────
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			_right_click_slot(index, from_bank)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if _drag_from_index == -1:
				_drag_from_index = index
				_drag_from_bank  = from_bank
			else:
				_swap_slots(_drag_from_index, _drag_from_bank, index, from_bank)
				_drag_from_index = -1
	# ── Táctil (móvil/tablet) ────────────────────────────────
	elif ev is InputEventScreenTouch and ev.pressed:
		_on_slot_touch(index, from_bank)

func _on_slot_touch(index: int, from_bank: bool) -> void:
	# Sin selección previa → seleccionar este slot (resaltar)
	if _touch_selected_index == -1:
		var item = _get_slot_item(index, from_bank)
		if item == null:
			return  # tap en slot vacío sin selección: ignorar
		_touch_selected_index = index
		_touch_selected_bank  = from_bank
		_highlight_selected_slot(index, from_bank, true)
		# TOUCH FIX: mostrar tooltip inmediatamente al seleccionar slot
		var _tip_item = _get_slot_item(index, from_bank)
		if _tip_item != null:
			_show_tooltip(_tip_item)
		return

	# Tap en el mismo slot ya seleccionado → equipar / usar
	if _touch_selected_index == index and _touch_selected_bank == from_bank:
		_highlight_selected_slot(index, from_bank, false)
		_touch_selected_index = -1
		_right_click_slot(index, from_bank)
		return

	# Tap en otro slot → swap (o acción banco↔inventario)
	_highlight_selected_slot(_touch_selected_index, _touch_selected_bank, false)
	_swap_slots(_touch_selected_index, _touch_selected_bank, index, from_bank)
	_touch_selected_index = -1

func _get_slot_item(index: int, from_bank: bool):
	var arr = InventoryManager.bank_items if from_bank else InventoryManager.items
	return arr[index] if index < arr.size() else null

func _highlight_selected_slot(index: int, from_bank: bool, on: bool) -> void:
	var nodes = inv_slot_nodes  # solo inventario por ahora; banco usa mismo array si se amplía
	if index < 0 or index >= nodes.size():
		return
	var panel : PanelContainer = nodes[index]
	if not panel:
		return
	var style = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if on:
		style.border_color = Color(1.0, 0.85, 0.1, 1.0)  # borde amarillo dorado
		style.set_border_width_all(3)
	else:
		# Restaurar: forzar refresh visual desde InventoryManager
		pass
	panel.add_theme_stylebox_override("panel", style)
	if not on:
		var item = _get_slot_item(index, from_bank)
		_update_slot_visual(panel, item)

func _right_click_slot(index: int, from_bank: bool) -> void:
	if from_bank:
		var bank_item = InventoryManager.bank_items[index] if index < InventoryManager.bank_items.size() else null
		if bank_item == null: return
		InventoryManager.withdraw_from_bank(bank_item.get("key",""))
		return
	var item = InventoryManager.items[index] if index < InventoryManager.items.size() else null
	if item == null: return
	var cat = item.get("category","")
	if cat == "consumable":
		InventoryManager.use_item(index)
	elif cat in ["weapon","armor"]:
		InventoryManager.equip_item_at(index)

func _swap_slots(from_i: int, from_bank: bool, to_i: int, to_bank: bool) -> void:
	if from_bank == to_bank:
		var arr = InventoryManager.bank_items if from_bank else InventoryManager.items
		if from_i < arr.size() and to_i < arr.size():
			var tmp = arr[from_i]
			arr[from_i] = arr[to_i]
			arr[to_i]   = tmp
			InventoryManager.inventory_changed.emit()
	else:
		# Cross: deposit o withdraw
		var src_arr = InventoryManager.bank_items if from_bank else InventoryManager.items
		var item = src_arr[from_i] if from_i < src_arr.size() else null
		if item == null: return
		if from_bank:
			InventoryManager.withdraw_from_bank(item.get("key",""))
		else:
			InventoryManager.deposit_to_bank(item.get("key",""))

func _unequip_slot(slot_key: String) -> void:
	InventoryManager.unequip_item(slot_key)

# ============================================================
# DIÁLOGO NPC
# ============================================================
func show_npc_dialog(npc, lines: Array) -> void:
	current_npc          = npc
	current_dialog_lines = lines
	current_dialog_index = 0
	is_dialog_open       = true
	dialog_panel.visible = true
	dialog_panel.move_to_front()   # FIX 1: siempre por encima de todo

	npc_name_lbl.text = npc.npc_name
	npc_role_lbl.text = npc.npc_role
	if "npc_color" in npc:
		npc_avatar.color = npc.npc_color
	else:
		npc_avatar.color = Color(0.3, 0.6, 1, 1)

	_start_typewriter(lines[0] if lines.size() > 0 else "...")
	_setup_dialog_buttons(npc)

func _start_typewriter(full_text: String) -> void:
	dialog_text.text = ""
	if _typewriter_tween:
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	for i in range(full_text.length()):
		var ch = full_text[i]
		_typewriter_tween.tween_callback(func(): dialog_text.text += ch).set_delay(0.03)

func _skip_typewriter() -> void:
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
		dialog_text.text = current_dialog_lines[current_dialog_index] if current_dialog_index < current_dialog_lines.size() else ""

func advance_dialog() -> void:
	if _typewriter_tween and _typewriter_tween.is_running():
		_skip_typewriter()
		return
	current_dialog_index += 1
	if current_dialog_index >= current_dialog_lines.size():
		dialog_text.text = "¿En qué más puedo ayudarte?"
	else:
		_start_typewriter(current_dialog_lines[current_dialog_index])
	# FIX 5c: Actualizar botón Siguiente — ocultarlo si ya no hay más líneas
	_refresh_siguiente_btn()

func _refresh_siguiente_btn() -> void:
	# FIX 5c: Añade o quita el botón Siguiente según el índice actual
	var has_next_btn : bool = false
	var next_btn = null
	for child in dialog_btns.get_children():
		if child is Button and child.text.begins_with("➤"):
			has_next_btn = true
			next_btn = child
			break
	var should_have_next : bool = current_dialog_lines.size() > current_dialog_index + 1
	if has_next_btn and not should_have_next:
		next_btn.free()
	elif not has_next_btn and should_have_next:
		# Insertar al inicio
		var btn = Button.new()
		btn.text = "➤ Siguiente"
		btn.pressed.connect(func(): advance_dialog())
		dialog_btns.add_child(btn)
		dialog_btns.move_child(btn, 0)

func _setup_dialog_buttons(npc) -> void:
	# FIX 5: free() inmediato en vez de queue_free()+await → evita botones duplicados
	for child in dialog_btns.get_children():
		child.free()

	# FIX 5b: Siguiente solo si quedan más líneas por mostrar
	if current_dialog_lines.size() > current_dialog_index + 1:
		_add_dialog_btn("➤ Siguiente", func(): advance_dialog())
	if npc.has_shop:
		_add_dialog_btn("🛒 Tienda", func(): open_shop(npc.shop_id))
	if npc.has_bank:
		_add_dialog_btn("🏦 Banco", func(): open_bank())
	if npc.has_crafting:
		_add_dialog_btn("⚒ Crafteo", func(): open_crafting(npc.shop_id))
		# Botones de tienda de herramientas
		if npc.shop_id == "forge":
			_add_dialog_btn("⛏ Herr. Minería",     func(): open_shop("tools_mining"))
			_add_dialog_btn("🪓 Herr. Leñador",     func(): open_shop("tools_woodcutting"))
			_add_dialog_btn("🌿 Herr. Herbalismo",  func(): open_shop("tools_herbalism"))
	if npc.has_quest:
		_add_dialog_btn("📜 Misión", func(): show_quest(npc.npc_name))
	if npc.has_auction:
		_add_dialog_btn("🏷 Subastas", func(): open_auction())
	if npc.has_dungeon:
		_add_dialog_btn("⚔ Entrar a la Mazmorra", func(): npc.open_dungeon())
	if npc.has_healer:
		_add_dialog_btn("💚 Curarme", func(): open_healer(npc))
	_add_dialog_btn("✕ Cerrar", func(): close_dialog())

func _add_dialog_btn(label: String, cb: Callable) -> void:
	var btn = Button.new()
	btn.text = label
	btn.pressed.connect(cb)
	# ── Styling premium RPG ──────────────────────────────
	var is_close = label.begins_with("✕")
	var is_next  = label.begins_with("➤")
	btn.add_theme_font_size_override("font_size", 12)
	# Normal style
	var sn = StyleBoxFlat.new()
	sn.bg_color        = Color(0.55, 0.38, 0.10, 1.0) if is_next else (Color(0.35, 0.08, 0.08, 1.0) if is_close else Color(0.13, 0.11, 0.22, 1.0))
	sn.border_width_left   = 1; sn.border_width_top    = 1
	sn.border_width_right  = 1; sn.border_width_bottom = 2
	sn.border_color    = Color(0.72, 0.56, 0.18, 0.8) if not is_close else Color(0.7, 0.2, 0.2, 0.8)
	sn.corner_radius_top_left = 4; sn.corner_radius_top_right = 4
	sn.corner_radius_bottom_left = 4; sn.corner_radius_bottom_right = 4
	sn.content_margin_left = 10; sn.content_margin_right = 10
	sn.content_margin_top = 5;  sn.content_margin_bottom = 5
	# Hover style
	var sh = sn.duplicate()
	sh.bg_color = Color(0.78, 0.56, 0.15, 1.0) if is_next else (Color(0.55, 0.12, 0.12, 1.0) if is_close else Color(0.22, 0.17, 0.38, 1.0))
	sh.border_color = Color(1.0, 0.82, 0.3, 1.0) if not is_close else Color(1.0, 0.35, 0.35, 1.0)
	# Pressed style
	var sp = sn.duplicate()
	sp.bg_color = sn.bg_color.darkened(0.2)
	sp.shadow_size = 0
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover",  sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus",  sh)
	var fc = Color(1.0, 0.92, 0.55, 1.0) if is_next else (Color(1.0, 0.65, 0.65, 1.0) if is_close else Color(0.92, 0.88, 1.0, 1.0))
	btn.add_theme_color_override("font_color", fc)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 0.7, 1))
	dialog_btns.add_child(btn)

func close_dialog() -> void:
	is_dialog_open = false
	current_npc    = null
	dialog_panel.visible = false
	if true:
		GameManager.end_npc_interaction()
	dialog_closed.emit()  # FIX: NPC restaura sus labels flotantes

# ============================================================
# TIENDA
# ============================================================
func open_shop(shop_id: String) -> void:
	close_dialog()
	is_shop_open = true
	_current_shop_id = shop_id
	shop_panel.visible = true
	shop_panel.move_to_front()   # FIX 1: siempre por encima de todo
	shop_gold_info.text = _get_beautiful_currency_text()
	_build_buy_grid(shop_id)
	_build_sell_grid()

func _build_buy_grid(shop_id: String) -> void:
	for child in buy_grid.get_children():
		child.queue_free()
	var catalog = SHOP_CATALOGS.get(shop_id, [])
	for entry in catalog:
		var info  = InventoryManager.get_item_info(entry.key)
		if info.is_empty():
			info = {"key": entry.key, "name": entry.key, "category": "tool", "rarity": "common"}
		else:
			info["key"] = entry.key  # FIX: asegurar que info siempre tenga "key" para el lambda de compra
		var price = entry.get("price", 10)
		var tier  = entry.get("tier", 0)
		var skill = entry.get("skill", "")
		var card  = _make_shop_card(info, price, true, -1, tier, skill)
		buy_grid.add_child(card)

func _build_sell_grid() -> void:
	for child in sell_grid.get_children():
		child.queue_free()
	for i in range(InventoryManager.items.size()):
		var item = InventoryManager.items[i]
		if item == null: continue
		var info  = InventoryManager.get_item_info(item.get("key",""))
		var price = int(info.get("price", 10) * 0.5)
		var card  = _make_shop_card(item, price, false, i)
		sell_grid.add_child(card)

func _make_shop_card(item: Dictionary, price: int, is_buy: bool, inv_index: int = -1,
		tier: int = 0, skill: String = "") -> VBoxContainer:
	var card = VBoxContainer.new()
	card.custom_minimum_size = Vector2(108, 100)

	var rc  = InventoryManager.get_rarity_color(item.get("rarity","common"))
	var ico = Label.new()
	ico.text = InventoryManager.get_category_icon(item.get("category",""))
	ico.add_theme_font_size_override("font_size", 22)
	ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(ico)

	var name_lbl = Label.new()
	name_lbl.text = item.get("name", item.get("key","?"))
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", rc)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(name_lbl)

	# Requerimientos de tier (solo para herramientas de recolección)
	var can_buy := true
	if is_buy and tier > 1 and skill != "":
		var spec_lv   = PlayerData.get_gathering_level(skill)
		var req_lv    = 5 if tier == 2 else 10
		can_buy       = spec_lv >= req_lv
		var req_lbl   = Label.new()
		var tier_name = "Adepto" if tier == 2 else "Maestro"
		req_lbl.text  = "T%d · %s %s Nv.%d [%d/%d]" % [tier, skill.capitalize(), tier_name, req_lv, spec_lv, req_lv]
		req_lbl.add_theme_font_size_override("font_size", 8)
		var req_color = Color(0.4, 1.0, 0.5) if can_buy else Color(1.0, 0.4, 0.4)
		req_lbl.add_theme_color_override("font_color", req_color)
		req_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(req_lbl)

	# Precio formateado con iconos de moneda
	var price_text := _format_price(price)
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn = Button.new()
	btn.text = ("Comprar" if is_buy else "Vender")
	btn.add_theme_font_size_override("font_size", 9)
	var price_rtl = RichTextLabel.new()
	price_rtl.bbcode_enabled = true
	price_rtl.text = price_text
	price_rtl.fit_content = true
	price_rtl.scroll_active = false
	price_rtl.add_theme_font_size_override("normal_font_size", 9)
	price_rtl.custom_minimum_size = Vector2(60, 20)
	if is_buy and not can_buy:
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5)
	if is_buy:
		btn.pressed.connect(func(): _buy_item(item.get("key",""), price))
	else:
		btn.pressed.connect(func(): _sell_item(inv_index, price))
	btn_row.add_child(btn)
	btn_row.add_child(price_rtl)
	card.add_child(btn_row)
	return card

## Formatea precio como texto plano (para notificaciones sin BBCode)
func _format_price_plain(bronze_total: int) -> String:
	var g = bronze_total / 10000
	var s = (bronze_total % 10000) / 100
	var b = bronze_total % 100
	var parts: Array = []
	if g > 0: parts.append("%dO" % g)
	if s > 0: parts.append("%dP" % s)
	if b > 0 or parts.is_empty(): parts.append("%dB" % b)
	return " ".join(parts)

## Formatea un precio en bronce con iconos de moneda
func _format_price(bronze_total: int) -> String:
	var g = bronze_total / 10000
	var s = (bronze_total % 10000) / 100
	var b = bronze_total % 100
	var parts: Array = []
	var img_g := "[img=14x14]res://assets/ui/coin_gold.png[/img]"
	var img_s := "[img=14x14]res://assets/ui/coin_silver.png[/img]"
	var img_b := "[img=14x14]res://assets/ui/coin_bronze.png[/img]"
	if g > 0: parts.append("%d%s" % [g, img_g])
	if s > 0: parts.append("%d%s" % [s, img_s])
	if b > 0 or parts.is_empty(): parts.append("%d%s" % [b, img_b])
	return " ".join(parts)

func _buy_item(item_key: String, price: int) -> void:
	if PlayerData.get_total_bronze() < price:
		_flash_label(shop_gold_info, Color(1,0.2,0.2,1))
		var needed = price - PlayerData.get_total_bronze()
		_show_screen_notification("Sin fondos — faltan %s" % _format_price_plain(needed), Color(1,0.3,0.3))
		return
	# ── Verificar espacio ANTES de cobrar ────────────────────
	# Un ítem stackeable puede ir a un slot existente aunque no haya slots vacíos
	var db_entry : Dictionary = InventoryManager.item_database.get(item_key, {})
	var max_stack : int = db_entry.get("max_stack", 1)
	var can_stack : bool = max_stack > 1 and InventoryManager.has_item(item_key)
	if not can_stack and not InventoryManager.has_space():
		_show_screen_notification("¡Inventario lleno! Libera espacio primero.", Color(1, 0.5, 0.1))
		_flash_label(shop_gold_info, Color(1, 0.5, 0.1))
		return
	PlayerData.spend_bronze(price)
	var ok : bool = InventoryManager.add_item(item_key, 1)
	if not ok:
		# Reembolso automático si add_item falló por cualquier razón
		PlayerData.add_bronze(price)
		_show_screen_notification("No se pudo obtener el ítem. Oro devuelto.", Color(1, 0.3, 0.3))
		return
	shop_gold_info.text = _get_beautiful_currency_text()
	_build_sell_grid()

	# ── Notificación de compra exitosa ───────────────────────
	var item : Dictionary = InventoryManager.get_item_data(item_key)
	var item_name : String = item.get("name", item_key)
	_show_screen_notification("✓ %s comprado/a" % item_name, Color(0.4, 1.0, 0.6))

	# ── Auto-equipar herramientas compradas ──────────────────
	if item.get("category", "") == "tool":
		_show_equip_tool_prompt(item_key, item)

func _show_equip_tool_prompt(item_key: String, item: Dictionary) -> void:
	var tool_name: String = item.get("name", item_key)
	var profession: String = item.get("tool_type", "")
	if not has_node("/root/ToolManager"):
		return
	var tm = get_node("/root/ToolManager")
	var current_tool: String = tm.get_equipped_name(profession)
	if current_tool == "":
		tm.equip_tool(item_key)
		_show_screen_notification("✓ %s equipada" % tool_name, Color(0.3, 1.0, 0.5))

func _sell_item(inv_index: int, price: int) -> void:
	if inv_index < 0: return
	InventoryManager.remove_item_at(inv_index)
	PlayerData.add_bronze(price)
	shop_gold_info.text = _get_beautiful_currency_text()
	_build_sell_grid()

func close_shop() -> void:
	is_shop_open = false
	shop_panel.visible = false

# ============================================================
# BANCO
# ============================================================
func open_bank() -> void:
	close_dialog()
	is_bank_open = true
	bank_panel.visible = true
	_build_bank_grids()
	_build_bank_upgrade_panel()

func _build_bank_grids() -> void:
	# Mochila
	for child in bank_inv_grid.get_children():
		child.queue_free()
	for i in range(40):
		var slot = _make_item_slot(i, false)
		var item = InventoryManager.items[i] if i < InventoryManager.items.size() else null
		_update_slot_visual(slot, item)
		bank_inv_grid.add_child(slot)

	# Almacén (slots dinámicos del banco)
	for child in bank_stor_grid.get_children():
		child.queue_free()
	var bank_slot_count = InventoryManager.get_bank_slot_count()
	for i in range(bank_slot_count):
		var slot = _make_item_slot(i, true)
		var item = InventoryManager.bank_items[i] if i < InventoryManager.bank_items.size() else null
		_update_slot_visual(slot, item)
		bank_stor_grid.add_child(slot)

	# Actualizar título con tier y slots actuales
	var bank_title_node = bank_panel.get_node_or_null("VBox/HBox/BankColumn/BankTitle")
	if bank_title_node:
		var tier = BankManager.bank_tier
		var icon = BankManager.get_tier_icon()
		bank_title_node.text = "%s Banco (%d espacios)" % [icon, bank_slot_count]

# ── Panel de mejoras del banco (se construye dinámicamente) ───
var _bank_upgrade_panel: PanelContainer = null

func _build_bank_upgrade_panel() -> void:
	# Eliminar panel anterior si existe
	if is_instance_valid(_bank_upgrade_panel):
		_bank_upgrade_panel.queue_free()

	var vbox_root = bank_panel.get_node_or_null("VBox")
	if not vbox_root:
		return

	# Contenedor principal del panel de mejoras
	var up_panel = PanelContainer.new()
	_bank_upgrade_panel = up_panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.8, 0.7, 0.2, 0.9)
	style.set_corner_radius_all(6)
	up_panel.add_theme_stylebox_override("panel", style)
	vbox_root.add_child(up_panel)

	var up_vbox = VBoxContainer.new()
	up_vbox.add_theme_constant_override("separation", 6)
	up_panel.add_child(up_vbox)

	# Título del panel
	var title_lbl = Label.new()
	title_lbl.text = "🔧 Mejoras del Banco"
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_vbox.add_child(title_lbl)

	# Separador
	var sep = HSeparator.new()
	up_vbox.add_child(sep)

	# Estado actual
	var current_tier = BankManager.bank_tier
	var current_slots = BankManager.get_current_slots()
	var status_lbl = Label.new()
	status_lbl.text = "%s %s — %d espacios" % [
		BankManager.get_tier_icon(), BankManager.get_tier_label(), current_slots
	]
	status_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_vbox.add_child(status_lbl)

	# Fila de los 4 tiers
	var tiers_hbox = HBoxContainer.new()
	tiers_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tiers_hbox.add_theme_constant_override("separation", 8)
	up_vbox.add_child(tiers_hbox)

	const COSTS: Array = [500, 2000, 7500, 25000]
	const LABELS: Array = ["Básico\n(+15)", "Ampliado\n(+15)", "Plata\n(+15)", "Oro\n(+15)"]
	const ICONS: Array = ["🏦", "📦", "🏛️", "🏰"]
	var player_bronze = PlayerData.get_total_bronze()

	for t in range(4):
		var tier_num = t + 1
		var tier_box = VBoxContainer.new()
		tier_box.alignment = BoxContainer.ALIGNMENT_CENTER
		tier_box.custom_minimum_size = Vector2(90, 0)
		tiers_hbox.add_child(tier_box)

		# Fondo del tier
		var tier_panel = PanelContainer.new()
		var ts = StyleBoxFlat.new()
		if current_tier >= tier_num:
			# Comprado
			ts.bg_color = Color(0.1, 0.35, 0.1, 0.9)
			ts.border_color = Color(0.3, 0.9, 0.3, 0.8)
		elif tier_num == current_tier + 1:
			# Disponible siguiente
			if player_bronze >= COSTS[t]:
				ts.bg_color = Color(0.25, 0.2, 0.05, 0.9)
				ts.border_color = Color(1.0, 0.85, 0.2, 0.9)
			else:
				ts.bg_color = Color(0.2, 0.15, 0.05, 0.9)
				ts.border_color = Color(0.6, 0.5, 0.1, 0.7)
		else:
			# Bloqueado
			ts.bg_color = Color(0.1, 0.08, 0.12, 0.9)
			ts.border_color = Color(0.3, 0.25, 0.35, 0.6)
		ts.set_border_width_all(2)
		ts.set_corner_radius_all(5)
		tier_panel.add_theme_stylebox_override("panel", ts)
		tier_box.add_child(tier_panel)

		var inner_vbox = VBoxContainer.new()
		inner_vbox.add_theme_constant_override("separation", 2)
		tier_panel.add_child(inner_vbox)

		# Icono
		var icon_lbl = Label.new()
		if current_tier >= tier_num:
			icon_lbl.text = "✅"
		else:
			icon_lbl.text = ICONS[t]
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 20)
		inner_vbox.add_child(icon_lbl)

		# Nombre y slots
		var name_lbl = Label.new()
		name_lbl.text = LABELS[t]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 10)
		var nc = Color(0.7, 0.7, 0.7) if current_tier >= tier_num else Color(0.9, 0.85, 0.7)
		name_lbl.add_theme_color_override("font_color", nc)
		inner_vbox.add_child(name_lbl)

		# Costo o estado
		var cost_lbl = Label.new()
		if current_tier >= tier_num:
			cost_lbl.text = "Comprado"
			cost_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		else:
			var c = COSTS[t]
			var g = c / 10000; var s = (c % 10000) / 100; var b = c % 100
			var parts: Array = []
			if g > 0: parts.append("%d🥇"%g)
			if s > 0: parts.append("%d🥈"%s)
			if b > 0 or parts.is_empty(): parts.append("%d🥉"%b)
			cost_lbl.text = " ".join(parts)
			var can_afford = player_bronze >= c and tier_num == current_tier + 1
			var locked     = tier_num > current_tier + 1
			cost_lbl.add_theme_color_override("font_color",
				Color(0.5,0.5,0.5) if locked else
				(Color(0.3,0.9,0.3) if can_afford else Color(0.9,0.4,0.4)))
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 10)
		inner_vbox.add_child(cost_lbl)

	# Botón de mejora (solo si es el siguiente tier disponible)
	if BankManager.can_upgrade():
		var btn = Button.new()
		var next_cost = BankManager.get_next_upgrade_cost()
		var can_buy   = player_bronze >= next_cost
		btn.text      = "⬆ Mejorar Banco"
		btn.disabled  = not can_buy
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.5, 0.15) if can_buy else Color(0.2, 0.17, 0.1)
		btn_style.border_color = Color(0.4, 0.9, 0.4) if can_buy else Color(0.4, 0.35, 0.2)
		btn_style.set_border_width_all(2)
		btn_style.set_corner_radius_all(5)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_color_override("font_color", Color(1,1,1))
		btn.custom_minimum_size = Vector2(200, 36)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		up_vbox.add_child(btn)
		btn.pressed.connect(_on_bank_upgrade_pressed)
	else:
		var max_lbl = Label.new()
		max_lbl.text = "🏆 Banco al nivel máximo"
		max_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		max_lbl.add_theme_font_size_override("font_size", 12)
		up_vbox.add_child(max_lbl)

func _on_bank_upgrade_pressed() -> void:
	var result = BankManager.try_upgrade()
	if result["ok"]:
		# Reconstruir toda la UI del banco con los nuevos slots
		_build_bank_grids()
		_build_bank_upgrade_panel()
		# Notificación flotante
		var player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.has_method("show_floating_text"):
			player.show_floating_text(result["msg"].replace("\n", " "), Color(0.3, 1.0, 0.5))
		print("[BankUI] ", result["msg"])
	else:
		# Mostrar error brevemente en el panel de mejoras
		var err_label = Label.new()
		err_label.text = "❌ " + result["msg"]
		err_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		err_label.add_theme_font_size_override("font_size", 11)
		err_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if is_instance_valid(_bank_upgrade_panel):
			_bank_upgrade_panel.get_node_or_null("VBoxContainer").add_child(err_label) if _bank_upgrade_panel.get_node_or_null("VBoxContainer") else null
		var tween = create_tween()
		tween.tween_interval(2.5)
		tween.tween_callback(func(): if is_instance_valid(err_label): err_label.queue_free())
		print("[BankUI] Error: ", result["msg"])

func close_bank() -> void:
	is_bank_open = false
	bank_panel.visible = false
	BankManager.save_bank_data()

# ============================================================
# CRAFTEO / QUESTS / DUNGEON
# ============================================================

var _craft_panel : Control = null
var _craft_shop_id : String = ""
var _craft_selected_recipe : String = ""

func open_crafting(craft_id: String = "") -> void:
	close_dialog()
	if _craft_panel != null:
		_craft_panel.queue_free()
		_craft_panel = null
		return

	_craft_shop_id = craft_id
	_craft_selected_recipe = ""
	_build_craft_panel()

func _build_craft_panel() -> void:
	# Panel raíz centrado
	var panel = PanelContainer.new()
	# MOBILE FIX: limitar tamaño al viewport disponible
	var _vp_sz: Vector2 = get_viewport().get_visible_rect().size
	var _pw: float = minf(680.0, _vp_sz.x * 0.97)
	var _ph: float = minf(520.0, _vp_sz.y * 0.95)
	panel.custom_minimum_size = Vector2(_pw, _ph)
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -_pw * 0.5
	panel.offset_top    = -_ph * 0.5
	panel.offset_right  =  _pw * 0.5
	panel.offset_bottom =  _ph * 0.5
	panel_root.add_child(panel)
	_craft_panel = panel

	# Fondo oscuro semitransparente
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	panel.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# ── Título + botón cerrar ────────────────────────────────
	var title_bar = HBoxContainer.new()
	vbox.add_child(title_bar)

	var shop_icons := {"forge": "⚒", "herbalist": "🌿", "tailor": "🧵"}
	var shop_names := {"forge": "FORJA", "herbalist": "HERBOLARIO", "tailor": "SASTRE"}
	var s_icon: String = shop_icons.get(_craft_shop_id, "⚒")
	var s_name: String = shop_names.get(_craft_shop_id, "TALLER DE CRAFTEO")

	var title_lbl = Label.new()
	title_lbl.text = "%s  %s" % [s_icon, s_name]
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(func():
		_craft_panel.queue_free()
		_craft_panel = null
	)
	title_bar.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# ── Tabs de Tier ─────────────────────────────────────────
	var all_recipes: Array = CraftManager.get_available_recipes(_craft_shop_id)

	# Agrupar recetas por tier
	var by_tier: Dictionary = {1: [], 2: [], 3: [], 4: []}
	for r in all_recipes:
		var t: int = r.get("craft_tier", 1)
		if by_tier.has(t):
			by_tier[t].append(r)

	# Tier activo (el más bajo con recetas)
	var active_tier: int = 1
	for ti in [1, 2, 3, 4]:
		if by_tier[ti].size() > 0:
			active_tier = ti
			break

	# Wrapper para tier activo seleccionado (mutable en closures)
	var selected_tier := [active_tier]

	var tier_labels := {
		1: "⬜ T1 — Hierro",
		2: "🟦 T2 — Plata",
		3: "🟨 T3 — Oro",
		4: "🌑 T4 — Vacío"
	}
	var tier_active_colors := {
		1: Color(0.85, 0.85, 0.85),
		2: Color(0.4,  0.75, 1.0),
		3: Color(1.0,  0.85, 0.2),
		4: Color(0.6,  0.3,  1.0)
	}
	var tier_inactive_color := Color(0.45, 0.42, 0.55)

	# HBox de tabs
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 2)
	vbox.add_child(tabs_hbox)

	# Área de contenido que se reconstruye al cambiar tier
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 10)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_hbox)

	# Función para reconstruir contenido del tier seleccionado
	var tab_buttons: Array = []

	var rebuild_content: Callable
	rebuild_content = func(tier: int) -> void:
		selected_tier[0] = tier
		_craft_selected_recipe = ""
		# Limpiar contenido anterior
		for ch in content_hbox.get_children():
			ch.queue_free()
		await content_hbox.get_tree().process_frame

		# Actualizar colores de tabs
		for i in tab_buttons.size():
			var tb = tab_buttons[i]
			var ti_num = i + 1
			if ti_num == tier:
				tb.add_theme_color_override("font_color", tier_active_colors.get(ti_num, Color.WHITE))
				var ts_act = StyleBoxFlat.new()
				ts_act.bg_color = Color(0.22, 0.20, 0.30)
				ts_act.set_corner_radius_all(3)
				tb.add_theme_stylebox_override("normal", ts_act)
				tb.add_theme_stylebox_override("hover",  ts_act)
				tb.add_theme_stylebox_override("pressed",ts_act)
			else:
				tb.add_theme_color_override("font_color", tier_inactive_color)
				var ts_in = StyleBoxFlat.new()
				ts_in.bg_color = Color(0.14, 0.12, 0.20)
				ts_in.set_corner_radius_all(3)
				tb.add_theme_stylebox_override("normal",  ts_in)
				tb.add_theme_stylebox_override("hover",   ts_in)
				tb.add_theme_stylebox_override("pressed", ts_in)

		# Lista de recetas del tier seleccionado
		var tier_recipes: Array = by_tier.get(tier, [])

		var recipe_scroll = ScrollContainer.new()
		recipe_scroll.custom_minimum_size = Vector2(240, 400)
		recipe_scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		content_hbox.add_child(recipe_scroll)

		var recipe_list = VBoxContainer.new()
		recipe_list.add_theme_constant_override("separation", 3)
		recipe_scroll.add_child(recipe_list)

		if tier_recipes.is_empty():
			var empty_lbl = Label.new()
			empty_lbl.text = "Sin recetas T%d." % tier
			empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.6))
			recipe_list.add_child(empty_lbl)
		else:
			# Agrupar por tipo de arma/categoría para mayor legibilidad
			var category_order := {
				"weapon": 0, "armor": 1, "consumable": 2
			}
			var sorted_recipes: Array = tier_recipes.duplicate()
			sorted_recipes.sort_custom(func(a, b):
				var ca = category_order.get(a.get("category",""), 9)
				var cb = category_order.get(b.get("category",""), 9)
				if ca != cb: return ca < cb
				return a.get("craft_skill_level", 1) < b.get("craft_skill_level", 1)
			)

			var last_cat := ""
			for recipe in sorted_recipes:
				var r_key: String = recipe.get("key", "")
				var r_cat: String  = recipe.get("category", "")
				var can_c: bool    = CraftManager.can_craft(r_key)

				# Separador de categoría
				if r_cat != last_cat:
					last_cat = r_cat
					var cat_icons := {"weapon": "⚔️ Armas", "armor": "🛡️ Armaduras", "consumable": "🧪 Consumibles"}
					var cat_lbl = Label.new()
					cat_lbl.text = cat_icons.get(r_cat, r_cat.capitalize())
					cat_lbl.add_theme_font_size_override("font_size", 10)
					cat_lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.75))
					recipe_list.add_child(cat_lbl)

				var btn = Button.new()
				btn.text = "%s %s" % [recipe.get("icon", "?"), recipe.get("name", r_key)]
				btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				btn.alignment        = HORIZONTAL_ALIGNMENT_LEFT
				btn.toggle_mode      = true
				btn.custom_minimum_size = Vector2(210, 0)

				var ts_btn = StyleBoxFlat.new()
				if can_c:
					ts_btn.bg_color = Color(0.12, 0.20, 0.14)
					btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))
				else:
					ts_btn.bg_color = Color(0.20, 0.12, 0.12)
					btn.add_theme_color_override("font_color", Color(0.85, 0.45, 0.45))
				ts_btn.set_corner_radius_all(3)
				btn.add_theme_stylebox_override("normal",  ts_btn)
				btn.add_theme_stylebox_override("hover",   ts_btn)

				btn.pressed.connect(func():
					_craft_selected_recipe = r_key
					_refresh_craft_detail(content_hbox, tier_recipes)
				)
				recipe_list.add_child(btn)

		# Panel de detalle inicial
		var detail_panel = PanelContainer.new()
		detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_panel.name = "DetailPanel"
		content_hbox.add_child(detail_panel)

		var hint_lbl = Label.new()
		hint_lbl.text = "← Selecciona una receta"
		hint_lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.6))
		hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		detail_panel.add_child(hint_lbl)

	# Crear botones de tabs
	for ti in [1, 2, 3, 4]:
		var tab_btn = Button.new()
		tab_btn.text = tier_labels.get(ti, "T%d" % ti)
		tab_btn.custom_minimum_size = Vector2(0, 30)
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_btn.add_theme_font_size_override("font_size", 12)

		var ts_tab = StyleBoxFlat.new()
		ts_tab.bg_color = Color(0.14, 0.12, 0.20)
		ts_tab.set_corner_radius_all(3)
		tab_btn.add_theme_stylebox_override("normal",  ts_tab.duplicate())
		tab_btn.add_theme_stylebox_override("hover",   ts_tab.duplicate())
		tab_btn.add_theme_stylebox_override("pressed", ts_tab.duplicate())

		# Deshabilitar tabs sin recetas
		if by_tier.get(ti, []).is_empty():
			tab_btn.disabled = true
			tab_btn.add_theme_color_override("font_color", Color(0.3, 0.28, 0.38))
		else:
			var captured_ti: int = ti
			tab_btn.pressed.connect(func(): rebuild_content.call(captured_ti))
			tab_btn.add_theme_color_override("font_color", tier_inactive_color)

		tabs_hbox.add_child(tab_btn)
		tab_buttons.append(tab_btn)

	# Construir con el tier activo inicial
	rebuild_content.call(active_tier)

func _refresh_craft_detail(hbox: HBoxContainer, recipes: Array) -> void:
	# Reemplazar el panel de detalle
	var old = hbox.get_node_or_null("DetailPanel")
	if old:
		old.get_parent().remove_child(old)
		old.free()

	var recipe_data: Dictionary = {}
	for r in recipes:
		if r.get("key", "") == _craft_selected_recipe:
			recipe_data = r
			break

	if recipe_data.is_empty():
		return

	var can_c: bool    = CraftManager.can_craft(_craft_selected_recipe)
	var fail_reason: String = CraftManager.get_craft_fail_reason(_craft_selected_recipe)

	var detail_panel = PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.name = "DetailPanel"
	hbox.add_child(detail_panel)

	# Fondo del detalle
	var bg_detail = StyleBoxFlat.new()
	bg_detail.bg_color = Color(0.10, 0.09, 0.15)
	bg_detail.set_corner_radius_all(4)
	detail_panel.add_theme_stylebox_override("panel", bg_detail)

	var dvbox = VBoxContainer.new()
	dvbox.add_theme_constant_override("separation", 5)
	detail_panel.add_child(dvbox)

	# ── Encabezado: ícono + nombre ───────────────────────────
	var tier_val: int = recipe_data.get("craft_tier", 1)
	var tier_colors_map := {
		1: Color(0.80, 0.80, 0.80),
		2: Color(0.4,  0.80, 1.0),
		3: Color(1.0,  0.85, 0.2),
		4: Color(0.65, 0.35, 1.0)
	}
	var tier_bg_colors := {
		1: Color(0.16, 0.16, 0.16),
		2: Color(0.10, 0.18, 0.26),
		3: Color(0.20, 0.18, 0.08),
		4: Color(0.15, 0.08, 0.25)
	}
	var tier_icons_map := {
		1: "⬜ Tier 1 — Hierro",
		2: "🟦 Tier 2 — Plata",
		3: "🟨 Tier 3 — Oro",
		4: "🌑 Tier 4 — Vacío"
	}

	# Banner de tier
	var tier_banner = PanelContainer.new()
	var ts_banner = StyleBoxFlat.new()
	ts_banner.bg_color = tier_bg_colors.get(tier_val, Color(0.15, 0.15, 0.15))
	ts_banner.set_corner_radius_all(3)
	tier_banner.add_theme_stylebox_override("panel", ts_banner)
	dvbox.add_child(tier_banner)

	var banner_hbox = HBoxContainer.new()
	tier_banner.add_child(banner_hbox)

	var banner_lbl = Label.new()
	banner_lbl.text = tier_icons_map.get(tier_val, "T%d" % tier_val)
	banner_lbl.add_theme_font_size_override("font_size", 11)
	banner_lbl.add_theme_color_override("font_color", tier_colors_map.get(tier_val, Color.WHITE))
	banner_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_hbox.add_child(banner_lbl)

	# Título del ítem
	var d_title = Label.new()
	d_title.text = "%s  %s" % [recipe_data.get("icon", ""), recipe_data.get("name", "")]
	d_title.add_theme_font_size_override("font_size", 15)
	d_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	dvbox.add_child(d_title)

	# Descripción
	var d_desc = Label.new()
	d_desc.text = recipe_data.get("desc", "")
	d_desc.add_theme_font_size_override("font_size", 11)
	d_desc.add_theme_color_override("font_color", Color(0.72, 0.68, 0.85))
	d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	dvbox.add_child(d_desc)

	dvbox.add_child(HSeparator.new())

	# ── Requisitos ──────────────────────────────────────────
	var req_lv: int = recipe_data.get("required_level", 1)
	var ok_lv: bool = PlayerData.level >= req_lv
	var req_lbl = Label.new()
	req_lbl.text = "👤 Nv. personaje: %d  (tienes %d)" % [req_lv, PlayerData.level]
	req_lbl.add_theme_font_size_override("font_size", 11)
	req_lbl.add_theme_color_override("font_color",
		Color(0.4, 1.0, 0.5) if ok_lv else Color(1.0, 0.4, 0.4))
	dvbox.add_child(req_lbl)

	var craft_skill_req: int = recipe_data.get("craft_skill_level", 1)
	var shop_ids_ui: Array = recipe_data.get("shop_ids", [])
	var skill_display_names := {"smithing": "Herrería", "tailoring": "Sastrería", "alchemy": "Alquimia"}
	for sid_ui in shop_ids_ui:
		var cs = CraftManager.get_craft_skill_for_shop(sid_ui)
		if cs != "":
			var cur_cs: int = PlayerData.get_crafting_level(cs)
			var ok_cs: bool = cur_cs >= craft_skill_req
			var sname: String = skill_display_names.get(cs, cs.capitalize())
			var craft_skill_lbl = Label.new()
			craft_skill_lbl.text = "🔨 %s: Nv.%d  (tienes %d)" % [sname, craft_skill_req, cur_cs]
			craft_skill_lbl.add_theme_font_size_override("font_size", 11)
			craft_skill_lbl.add_theme_color_override("font_color",
				Color(0.4, 1.0, 0.5) if ok_cs else Color(1.0, 0.6, 0.2))
			dvbox.add_child(craft_skill_lbl)
			break

	var xp_reward: int = CraftManager.CRAFT_XP_BY_TIER.get(tier_val, 30)
	var xp_reward_lbl = Label.new()
	xp_reward_lbl.text = "✨ XP crafteo: +%d" % xp_reward
	xp_reward_lbl.add_theme_font_size_override("font_size", 10)
	xp_reward_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.4))
	dvbox.add_child(xp_reward_lbl)

	# Probabilidades de calidad (solo armas y armaduras)
	var recipe_cat_ui: String = recipe_data.get("category", "consumable")
	if recipe_cat_ui == "weapon" or recipe_cat_ui == "armor":
		var craft_skill_probs: int = 1
		for sid_prob in shop_ids_ui:
			var csp = CraftManager.get_craft_skill_for_shop(sid_prob)
			if csp != "":
				craft_skill_probs = PlayerData.get_crafting_level(csp)
				break
		var prob_lbl = Label.new()
		prob_lbl.text = "🎲 Calidades posibles:\n" + QualitySystem.get_probability_text(craft_skill_probs)
		prob_lbl.add_theme_font_size_override("font_size", 10)
		prob_lbl.add_theme_color_override("font_color", Color(0.78, 0.72, 0.90))
		prob_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		dvbox.add_child(prob_lbl)

		# Nota: épico/legendario solo por loot
		var quality_note = Label.new()
		quality_note.text = "🔒 Épico/Legendario: solo loot de bosses"
		quality_note.add_theme_font_size_override("font_size", 10)
		quality_note.add_theme_color_override("font_color", Color(0.55, 0.40, 0.70))
		dvbox.add_child(quality_note)

	dvbox.add_child(HSeparator.new())

	# ── Ingredientes ────────────────────────────────────────
	var ing_title = Label.new()
	ing_title.text = "Ingredientes:"
	ing_title.add_theme_font_size_override("font_size", 12)
	ing_title.add_theme_color_override("font_color", Color(0.88, 0.85, 1.0))
	dvbox.add_child(ing_title)

	for ing in recipe_data.get("ingredients", []):
		var ing_key: String = ing["key"]
		var ing_qty: int    = ing["qty"]
		var have: int       = InventoryManager.get_item_count(ing_key)
		var ing_info: Dictionary = InventoryManager.item_database.get(ing_key, {})
		var ing_name: String = ing_info.get("name", ing_key)
		var ing_rarity: String = ing_info.get("rarity", "common")

		# Color de rareza del ingrediente
		var rarity_colors := {
			"common": Color(0.75, 0.75, 0.75),
			"uncommon": Color(0.3, 0.9, 0.5),
			"rare": Color(0.3, 0.65, 1.0),
			"epic": Color(0.8, 0.35, 1.0),
			"legendary": Color(1.0, 0.7, 0.2)
		}

		var row = HBoxContainer.new()
		var name_lbl = Label.new()
		name_lbl.text = "  • %s" % ing_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", rarity_colors.get(ing_rarity, Color(0.75, 0.75, 0.75)))
		row.add_child(name_lbl)

		var qty_lbl = Label.new()
		qty_lbl.text = "%d / %d" % [have, ing_qty]
		qty_lbl.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.5) if have >= ing_qty else Color(1.0, 0.35, 0.35))
		qty_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(qty_lbl)

		dvbox.add_child(row)

	dvbox.add_child(HSeparator.new())

	# ── Botón Fabricar ──────────────────────────────────────
	var craft_btn = Button.new()
	craft_btn.custom_minimum_size = Vector2(0, 42)

	if can_c:
		craft_btn.text = "⚒  FABRICAR"
		var ts_craft = StyleBoxFlat.new()
		ts_craft.bg_color = Color(0.10, 0.28, 0.14)
		ts_craft.set_corner_radius_all(4)
		craft_btn.add_theme_stylebox_override("normal",  ts_craft)
		craft_btn.add_theme_stylebox_override("hover",   ts_craft)
		craft_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		craft_btn.add_theme_font_size_override("font_size", 14)
		var captured_recipe_data := recipe_data.duplicate()
		var captured_shop_id := _craft_shop_id
		craft_btn.pressed.connect(func():
			var obtained_quality := ["common"]
			CraftManager.craft_success.connect(
				func(_rk: String, rdata: Dictionary): obtained_quality[0] = rdata.get("crafted_quality", "common"),
				CONNECT_ONE_SHOT
			)
			if CraftManager.craft(_craft_selected_recipe):
				var rcat: String = captured_recipe_data.get("category", "consumable")
				if rcat == "weapon" or rcat == "armor":
					var q: String  = obtained_quality[0]
					var qc: Color  = QualitySystem.get_quality_color(q)
					var qn: String = QualitySystem.get_quality_name(q)
					var qi: String = QualitySystem.get_quality_icon(q)
					_show_screen_notification("%s ¡Calidad obtenida: %s!" % [qi, qn], qc)
				_craft_panel.queue_free()
				_craft_panel = null
				_craft_selected_recipe = ""
				open_crafting(captured_shop_id)
		)
	else:
		craft_btn.text = fail_reason if fail_reason != "" else "❌ Sin recursos"
		craft_btn.disabled = true
		var ts_disabled = StyleBoxFlat.new()
		ts_disabled.bg_color = Color(0.20, 0.14, 0.14)
		ts_disabled.set_corner_radius_all(4)
		craft_btn.add_theme_stylebox_override("normal", ts_disabled)
		craft_btn.add_theme_color_override("font_color", Color(0.65, 0.45, 0.45))
		craft_btn.add_theme_font_size_override("font_size", 11)

	dvbox.add_child(craft_btn)


func show_quest(npc_name_val: String) -> void:
	close_dialog()
	print("[UI] Quest de: ", npc_name_val)  # Paso 5

func show_dungeon_prompt() -> void:
	var popup = AcceptDialog.new()
	popup.dialog_text    = "⚠ ¿Entrar a la Stone Dungeon?\n\nSolo los valientes regresan con vida."
	popup.ok_button_text  = "⚔ Entrar"
	popup.add_cancel_button("Cancelar")
	popup.confirmed.connect(func():
		GameManager.change_scene_with_spawn(
			"res://scenes/dungeons/stone_dungeon.tscn",
			Vector2(0, 320)
		)
	)
	panel_root.add_child(popup)
	popup.popup_centered()
# ============================================================

func _setup_mobile_controls() -> void:
	var is_touch = DisplayServer.is_touchscreen_available()
	if mobile_controls:
		# MobileControls debe estar visible para que el ChatPanel funcione
		# Los botones táctiles se ocultan en PC, pero el ChatPanel siempre visible
		mobile_controls.visible = true
		var action_btns = mobile_controls.get_node_or_null("ActionButtons")
		var joystick    = mobile_controls.get_node_or_null("JoystickBase")
		if not is_touch:
			if action_btns: action_btns.visible = false
			if joystick:    joystick.visible    = false
	if is_touch:
		var attack_btn   = get_node_or_null("MobileControls/ActionButtons/AttackBtn")
		var dodge_btn    = get_node_or_null("MobileControls/ActionButtons/DodgeBtn")
		var interact_btn = get_node_or_null("MobileControls/ActionButtons/InteractBtn")
		var inv_btn      = get_node_or_null("MobileControls/ActionButtons/InventoryBtn")

		# ── Iconos ───────────────────────────────────────────
		if attack_btn:   attack_btn.text   = "⚔"
		if dodge_btn:    dodge_btn.text    = "🔄"
		if interact_btn: interact_btn.text = "🤝"
		if inv_btn:      inv_btn.text      = "🎒"

		# ── MULTI-TOUCH: gui_input con touch index propio ────
		# Cada botón escucha su propio InputEventScreenTouch con su índice
		# de dedo, independiente del joystick. Así se pueden pulsar
		# simultáneamente sin que interfieran entre sí.
		_wire_touch_btn(attack_btn,   func(): _mobile_attack())
		_wire_touch_btn(dodge_btn,    func(): _mobile_dodge())
		_wire_touch_btn(interact_btn, func(): _mobile_interact())
		_wire_touch_btn(inv_btn,      func(): toggle_inventory())

		# ── Chat button ──────────────────────────────────────────
		var chat_btn = get_node_or_null("MobileControls/ActionButtons/ChatBtn")
		if chat_btn:
			_wire_touch_btn(chat_btn, func(): _toggle_chat_panel())

		# Skill buttons
		var sq_btn = get_node_or_null("MobileControls/ActionButtons/SkillQBtn")
		var se_btn = get_node_or_null("MobileControls/ActionButtons/SkillEBtn")
		var sr_btn = get_node_or_null("MobileControls/ActionButtons/SkillRBtn")
		if sq_btn: sq_btn.text = "Q"; _wire_touch_btn(sq_btn, func(): WeaponSkillSystem.use_skill(0))
		if se_btn: se_btn.text = "E"; _wire_touch_btn(se_btn, func(): WeaponSkillSystem.use_skill(1))
		if sr_btn: sr_btn.text = "R"; _wire_touch_btn(sr_btn, func(): WeaponSkillSystem.use_skill(2))

		# ── Estilizar todos los botones de acción ────────────────
		_style_action_buttons()

		if joystick_base:
			joystick_base.gui_input.connect(_on_joystick_input)
			# MOBILE MEJORA: radio mínimo 60px para tablets pequeñas
			var _jr := joystick_base.size.x / 2.0
			_joystick_radius = max(_jr, 60.0)

	# Inicializar panel de chat siempre (editor PC + dispositivo móvil)
	_setup_chat_panel()
	# Forzar visibilidad del ChatPanel independientemente de MobileControls
	var chat_panel_node = get_node_or_null("MobileControls/ChatPanel")
	if chat_panel_node:
		chat_panel_node.visible = true

## ─────────────────────────────────────────────────────────────────
## CHAT PANEL MÓVIL — Siempre visible, centrado, transparente, retráctil
## ─────────────────────────────────────────────────────────────────
var _chat_active_channel: String = "global"
var _chat_collapsed: bool = false

func _toggle_chat_panel() -> void:
	# El chat ya es siempre visible; el botón del joystick ahora colapsa/expande
	_toggle_chat_collapse()

func _toggle_chat_collapse() -> void:
	var panel = get_node_or_null("MobileControls/ChatPanel")
	if not panel: return
	_chat_collapsed = not _chat_collapsed
	var scroll  = panel.get_node_or_null("VBox/MsgScroll")
	var input_r = panel.get_node_or_null("VBox/InputRow")
	var collapse_btn = panel.get_node_or_null("VBox/ChannelBar/BtnCollapse")
	if scroll:  scroll.visible  = not _chat_collapsed
	if input_r and _chat_collapsed: input_r.visible = false  # colapsar también oculta input
	if collapse_btn:
		collapse_btn.text = "▲" if _chat_collapsed else "▼"
	# Ajustar tamaño del panel al colapsar
	if _chat_collapsed:
		panel.custom_minimum_size = Vector2(0, 0)
		panel.offset_top = -32.0
	else:
		panel.offset_top = -240.0

func _setup_chat_panel() -> void:
	var panel = get_node_or_null("MobileControls/ChatPanel")
	if not panel:
		return

	# ── Estilo semi-transparente tipo HUD de MMORPG ──────────────
	var sb := StyleBoxFlat.new()
	sb.bg_color        = Color(0.04, 0.03, 0.08, 0.60)   # muy transparente
	sb.set_border_width_all(1)
	sb.border_color    = Color(0.75, 0.60, 0.20, 0.45)   # borde dorado suave
	sb.set_corner_radius_all(8)
	sb.shadow_size     = 0
	panel.add_theme_stylebox_override("panel", sb)

	# ── Estilo de botones de canal ─────────────────────────────────
	var _style_channel_btn = func(btn: Button) -> void:
		if not btn: return
		var sn := StyleBoxFlat.new()
		sn.bg_color       = Color(0.10, 0.08, 0.18, 0.0)
		sn.set_border_width_all(0)
		sn.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sn)
		var sp := StyleBoxFlat.new()
		sp.bg_color       = Color(0.75, 0.60, 0.20, 0.25)
		sp.set_border_width_all(1)
		sp.border_color   = Color(0.75, 0.60, 0.20, 0.7)
		sp.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("pressed", sp)
		btn.add_theme_color_override("font_color",          Color(0.80, 0.78, 0.70, 0.90))
		btn.add_theme_color_override("font_pressed_color",  Color(1.00, 0.92, 0.55, 1.00))
		btn.add_theme_color_override("font_hover_color",    Color(1.00, 1.00, 1.00, 1.00))

	# ── Estilo input field ─────────────────────────────────────────
	var chat_input = panel.get_node_or_null("VBox/InputRow/ChatInput")
	if chat_input:
		var si := StyleBoxFlat.new()
		si.bg_color     = Color(0.05, 0.04, 0.10, 0.65)
		si.set_border_width_all(1)
		si.border_color = Color(0.75, 0.60, 0.20, 0.35)
		si.set_corner_radius_all(4)
		si.content_margin_left   = 8
		si.content_margin_right  = 8
		si.content_margin_top    = 4
		si.content_margin_bottom = 4
		chat_input.add_theme_stylebox_override("normal", si)
		chat_input.add_theme_color_override("font_color",             Color(0.95, 0.93, 0.85, 1.0))
		chat_input.add_theme_color_override("font_placeholder_color", Color(0.60, 0.58, 0.52, 0.7))

	# ── Botones de canal ───────────────────────────────────────────
	var btn_global   = panel.get_node_or_null("VBox/ChannelBar/BtnGlobal")
	var btn_local    = panel.get_node_or_null("VBox/ChannelBar/BtnLocal")
	var btn_group    = panel.get_node_or_null("VBox/ChannelBar/BtnGroup")
	var btn_write    = panel.get_node_or_null("VBox/ChannelBar/BtnWrite")
	var btn_collapse = panel.get_node_or_null("VBox/ChannelBar/BtnCollapse")
	var input_row    = panel.get_node_or_null("VBox/InputRow")
	var send_btn     = panel.get_node_or_null("VBox/InputRow/SendBtn")

	for b in [btn_global, btn_local, btn_group]:
		_style_channel_btn.call(b)

	# Botón escribir (✏) — muestra/oculta el campo de input
	if btn_write:
		var sw := StyleBoxFlat.new()
		sw.bg_color     = Color(0.20, 0.55, 0.90, 0.30)
		sw.set_border_width_all(1)
		sw.border_color = Color(0.40, 0.75, 1.00, 0.65)
		sw.set_corner_radius_all(4)
		btn_write.add_theme_stylebox_override("normal", sw)
		btn_write.add_theme_color_override("font_color", Color(0.70, 0.90, 1.0, 1.0))

	# Botón colapsar — estilo mínimo
	if btn_collapse:
		var sc := StyleBoxFlat.new()
		sc.bg_color     = Color(0.75, 0.60, 0.20, 0.18)
		sc.set_border_width_all(1)
		sc.border_color = Color(0.75, 0.60, 0.20, 0.5)
		sc.set_corner_radius_all(4)
		btn_collapse.add_theme_stylebox_override("normal", sc)
		btn_collapse.add_theme_color_override("font_color", Color(0.90, 0.80, 0.40, 1.0))

	# Botón enviar
	if send_btn:
		var ss := StyleBoxFlat.new()
		ss.bg_color     = Color(0.75, 0.60, 0.20, 0.30)
		ss.set_border_width_all(1)
		ss.border_color = Color(0.75, 0.60, 0.20, 0.65)
		ss.set_corner_radius_all(4)
		send_btn.add_theme_stylebox_override("normal", ss)
		send_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1.0))

	# ── Conexiones ────────────────────────────────────────────────
	if btn_global:   btn_global.pressed.connect(func():   _set_chat_channel("global"))
	if btn_local:    btn_local.pressed.connect(func():    _set_chat_channel("local"))
	if btn_group:    btn_group.pressed.connect(func():    _set_chat_channel("group"))
	if btn_collapse: btn_collapse.pressed.connect(func(): _toggle_chat_collapse())
	if btn_write and input_row:
		btn_write.pressed.connect(func():
			input_row.visible = not input_row.visible
			if input_row.visible:
				var ci = input_row.get_node_or_null("ChatInput")
				if ci:
					ci.grab_focus()
					ci.call_deferred("grab_focus")
					# Abrir teclado virtual en móvil
					if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
						DisplayServer.virtual_keyboard_show("")
			else:
				# Ocultar teclado virtual al cerrar input
				if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
					DisplayServer.virtual_keyboard_hide()
		)
	if send_btn:     send_btn.pressed.connect(func():     _send_chat_msg())
	if chat_input:
		chat_input.text_submitted.connect(func(_t): _send_chat_msg())
		# Al enviar, ocultar el input row automáticamente en móvil
		chat_input.text_submitted.connect(func(_t2):
			if input_row: input_row.visible = false
		)

	# Forzar tamaño correcto del MsgList (fix Godot 4: fit_content en ScrollContainer)
	var msg_list_setup: RichTextLabel = panel.get_node_or_null("VBox/MsgScroll/MsgList")
	if msg_list_setup:
		msg_list_setup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		msg_list_setup.size_flags_vertical   = Control.SIZE_FILL
		msg_list_setup.fit_content           = true
		msg_list_setup.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
		msg_list_setup.custom_minimum_size   = Vector2(100, 0)

	# Conectar ChatManager
	if ChatManager.message_received.is_connected(_on_chat_message):
		pass
	else:
		ChatManager.message_received.connect(_on_chat_message)

	# Cargar historial global (diferido para asegurar que MsgList ya existe en el árbol)
	call_deferred("_reload_chat_history", "global")

func _set_chat_channel(key: String) -> void:
	_chat_active_channel = key
	var panel = get_node_or_null("MobileControls/ChatPanel")
	if not panel: return
	for ch in ["global","local","group"]:
		var cap = ch.capitalize()
		var b = panel.get_node_or_null("VBox/ChannelBar/Btn" + cap)
		if b: b.button_pressed = (ch == key)
	ChatManager.set_active_channel(
		ChatManager.Channel.GLOBAL if key == "global"
		else ChatManager.Channel.LOCAL if key == "local"
		else ChatManager.Channel.GROUP
	)
	_reload_chat_history(key)

func _reload_chat_history(key: String) -> void:
	var panel = get_node_or_null("MobileControls/ChatPanel")
	if not panel: return
	var msg_list: RichTextLabel = panel.get_node_or_null("VBox/MsgScroll/MsgList")
	if not msg_list: return
	msg_list.clear()
	for entry in ChatManager.get_history(key):
		_append_chat_line(msg_list, entry.sender, entry.text, entry.color)

func _on_chat_message(channel: String, sender: String, text: String, color: Color) -> void:
	if channel != _chat_active_channel:
		return
	var panel = get_node_or_null("MobileControls/ChatPanel")
	if not panel: return
	var msg_list: RichTextLabel = panel.get_node_or_null("VBox/MsgScroll/MsgList")
	if msg_list:
		_append_chat_line(msg_list, sender, text, color)

func _append_chat_line(rtl: RichTextLabel, sender: String, text: String, col: Color) -> void:
	var hex := "#%02x%02x%02x" % [int(col.r*255), int(col.g*255), int(col.b*255)]
	rtl.append_text("[color=%s][b]%s:[/b][/color] %s\n" % [hex, sender, text])
	# Forzar redibujado y scroll al final
	rtl.queue_redraw()
	var scroll = rtl.get_parent() as ScrollContainer
	if scroll:
		scroll.call_deferred("set_v_scroll", scroll.get_v_scroll_bar().max_value)

func _send_chat_msg() -> void:
	var panel = get_node_or_null("MobileControls/ChatPanel")
	if not panel: return
	var inp: LineEdit = panel.get_node_or_null("VBox/InputRow/ChatInput")
	if not inp or inp.text.strip_edges() == "": return
	ChatManager.send_message(ChatManager._channel_key(ChatManager.active_channel), inp.text)
	inp.text = ""
	# Ocultar fila de input después de enviar (en móvil)
	var ir = panel.get_node_or_null("VBox/InputRow")
	if ir: ir.visible = false
	inp.release_focus()
	# Ocultar teclado virtual en móvil al enviar
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

## ─────────────────────────────────────────────────────────────────
## ESTILO RPG PARA BOTONES DE ACCIÓN MÓVIL
## Aplica StyleBoxFlat con estética pixel-art oscura y borde dorado
## a los cuatro botones de acción (⚔💨💬🎒) y los tres skill (Q/E/R).
## ─────────────────────────────────────────────────────────────────
func _style_action_buttons() -> void:
	# ── Paleta ────────────────────────────────────────────────────
	const COL_BG_NORMAL   := Color(0.08, 0.06, 0.14, 0.92)
	const COL_BG_HOVER    := Color(0.16, 0.11, 0.28, 0.97)
	const COL_BG_PRESSED  := Color(0.05, 0.03, 0.10, 1.00)
	const COL_BORDER      := Color(0.75, 0.60, 0.20, 1.00)
	const COL_BORDER_PRES := Color(1.00, 0.82, 0.25, 1.00)
	const COL_SHADOW      := Color(0.00, 0.00, 0.00, 0.60)
	const COL_FONT        := Color(0.97, 0.93, 0.72, 1.00)
	const COL_FONT_HOV    := Color(1.00, 1.00, 1.00, 1.00)
	const CORNER          := 5
	const BORDER_W        := 2

	var BTN_DATA := [
		["MobileControls/ActionButtons/AttackBtn",   "atk", Color(0.85, 0.25, 0.25, 0.35)],
		["MobileControls/ActionButtons/DodgeBtn",    "dod", Color(0.20, 0.65, 0.85, 0.30)],
		["MobileControls/ActionButtons/InteractBtn", "npc", Color(0.30, 0.75, 0.40, 0.30)],
		["MobileControls/ActionButtons/InventoryBtn","bag", Color(0.80, 0.55, 0.10, 0.35)],
		["MobileControls/ActionButtons/ChatBtn",      "cht", Color(0.20, 0.45, 0.75, 0.35)],
		["MobileControls/ActionButtons/SkillQBtn",   "Q",  Color(0.55, 0.15, 0.80, 0.35)],
		["MobileControls/ActionButtons/SkillEBtn",   "E",  Color(0.55, 0.15, 0.80, 0.35)],
		["MobileControls/ActionButtons/SkillRBtn",   "R",  Color(0.55, 0.15, 0.80, 0.35)],
	]

	for entry in BTN_DATA:
		var btn : Button = get_node_or_null(entry[0])
		if not btn:
			continue
		var accent : Color = entry[2]

		var sn := StyleBoxFlat.new()
		sn.bg_color = Color(0.08, 0.06, 0.14, 0.92).blend(accent)
		sn.set_border_width_all(BORDER_W)
		sn.border_color = COL_BORDER
		sn.set_corner_radius_all(CORNER)
		sn.shadow_color = COL_SHADOW
		sn.shadow_size = 4
		sn.shadow_offset = Vector2(2, 3)

		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(0.16, 0.11, 0.28, 0.97).blend(accent)
		sh.set_border_width_all(BORDER_W + 1)
		sh.border_color = COL_BORDER_PRES
		sh.set_corner_radius_all(CORNER)
		sh.shadow_color = COL_SHADOW
		sh.shadow_size = 6
		sh.shadow_offset = Vector2(2, 4)

		var sp := StyleBoxFlat.new()
		sp.bg_color = Color(0.05, 0.03, 0.10, 1.00).blend(accent)
		sp.set_border_width_all(BORDER_W)
		sp.border_color = COL_BORDER_PRES
		sp.set_corner_radius_all(CORNER - 1)
		sp.shadow_size = 0

		btn.add_theme_stylebox_override("normal",   sn)
		btn.add_theme_stylebox_override("hover",    sh)
		btn.add_theme_stylebox_override("pressed",  sp)
		btn.add_theme_stylebox_override("focus",    sh)

		btn.add_theme_color_override("font_color",         COL_FONT)
		btn.add_theme_color_override("font_hover_color",   COL_FONT_HOV)
		btn.add_theme_color_override("font_pressed_color", COL_BORDER_PRES)
		btn.add_theme_constant_override("outline_size",    2)
		btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		var is_skill : bool = entry[1] in ["Q", "E", "R"]
		btn.add_theme_font_size_override("font_size", 18 if is_skill else 26)

## Conecta un Button para multi-touch: responde a InputEventScreenTouch
## con su propio touch index, sin interferir con el joystick.
func _wire_touch_btn(btn: Button, callback: Callable) -> void:
	if btn == null:
		return
	# Deshabilitar señal pressed nativa para evitar doble disparo con gui_input
	# (Button dispara pressed Y gui_input al mismo toque cuando el player está quieto)
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.focus_mode  = Control.FOCUS_NONE
	# Desconectar cualquier señal pressed previa para evitar doble disparo
	if btn.pressed.get_connections().size() > 0:
		for c in btn.pressed.get_connections():
			btn.pressed.disconnect(c.callable)
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.pressed:
			btn.accept_event()
			callback.call()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			btn.accept_event()
			callback.call()
	)

func _on_joystick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _joystick_touch_index == -1:
			_joystick_touch_index = event.index
			_joystick_base_center = joystick_base.global_position + joystick_base.size / 2.0
		elif not event.pressed and event.index == _joystick_touch_index:
			_joystick_touch_index = -1
			_joystick_direction = Vector2.ZERO
			if joystick_knob:
				joystick_knob.position = joystick_base.size / 2.0 - joystick_knob.size / 2.0
			_send_joystick_actions(Vector2.ZERO)
	elif event is InputEventScreenDrag:
		if event.index == _joystick_touch_index:
			var local_center = joystick_base.size / 2.0
			var drag_local = event.position - local_center
			if drag_local.length() > _joystick_radius:
				drag_local = drag_local.normalized() * _joystick_radius
			_joystick_direction = drag_local / _joystick_radius
			if joystick_knob:
				joystick_knob.position = local_center + drag_local - joystick_knob.size / 2.0
			_send_joystick_actions(_joystick_direction)

func _send_joystick_actions(dir: Vector2) -> void:
	var threshold = 0.20  # MOBILE FIX: menor threshold = más sensible en touch
	_inject_action("move_right", dir.x >  threshold)
	_inject_action("move_left",  dir.x < -threshold)
	_inject_action("move_down",  dir.y >  threshold)
	_inject_action("move_up",    dir.y < -threshold)

func _inject_action(action: String, pressed: bool) -> void:
	var ev = InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _mobile_attack() -> void:
	var player = GameManager.get_player()
	if player and player.has_method("_perform_attack"):
		if not player.is_attacking and player.attack_cooldown_timer <= 0:
			player._perform_attack()

func _mobile_dodge() -> void:
	var player = GameManager.get_player()
	if player and player.has_method("_perform_dodge"):
		player._perform_dodge()

func _mobile_interact() -> void:
	var player = GameManager.get_player()
	if player and player.has_method("_interact_with_nearby"):
		player._interact_with_nearby()

# ============================================================
# UTILIDADES
# ============================================================
func _flash_label(lbl: Control, color: Color) -> void:
	var original = lbl.get_theme_color("font_color") if lbl.has_theme_color("font_color","") else Color.WHITE
	lbl.add_theme_color_override("font_color", color)
	await get_tree().create_timer(0.4).timeout
	lbl.add_theme_color_override("font_color", original)

func _show_screen_notification(msg: String, color: Color = Color.WHITE) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.position = Vector2(get_viewport().size.x / 2.0 - 150.0, 80.0)
	lbl.size = Vector2(300.0, 30.0)
	lbl.z_index = 10
	panel_root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 40.0, 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free)


# ════════════════════════════════════════════════════════════
# MEJORA 6 — INDICADOR DE ZONA PELIGROSA EN HUD
# ════════════════════════════════════════════════════════════
# Banner centrado que aparece 3 s y se desvanece.
# Se usa un nodo persistente (_zone_warn_root) para evitar
# acumulación si el jugador cruza límites muy rápido.

var _zone_warn_root: Control = null
var _zone_warn_tween: Tween  = null

func show_zone_warning(msg: String, color: Color) -> void:
	# Cancelar animación anterior si aún está activa
	if _zone_warn_tween and _zone_warn_tween.is_valid():
		_zone_warn_tween.kill()
	if _zone_warn_root and is_instance_valid(_zone_warn_root):
		_zone_warn_root.queue_free()
		_zone_warn_root = null

	var vp_size := get_viewport().get_visible_rect().size

	# ── Contenedor raíz ───────────────────────────────────────
	var root := Control.new()
	root.name        = "ZoneWarningBanner"
	root.z_index     = 20
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(root)
	_zone_warn_root = root

	# ── Fondo semitransparente ────────────────────────────────
	var bg := ColorRect.new()
	bg.color        = Color(0.0, 0.0, 0.0, 0.55)
	bg.size         = Vector2(vp_size.x * 0.60, 54.0)
	bg.position     = Vector2((vp_size.x - bg.size.x) * 0.5, vp_size.y * 0.18)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# ── Barra de color lateral izquierda ─────────────────────
	var bar := ColorRect.new()
	bar.color    = color
	bar.size     = Vector2(5.0, bg.size.y)
	bar.position = bg.position
	root.add_child(bar)

	# ── Etiqueta de texto ─────────────────────────────────────
	var lbl := Label.new()
	lbl.text                     = msg
	lbl.horizontal_alignment     = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment       = VERTICAL_ALIGNMENT_CENTER
	lbl.size                     = Vector2(bg.size.x - 10.0, bg.size.y)
	lbl.position                 = bg.position + Vector2(10.0, 0.0)
	lbl.mouse_filter             = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(lbl)

	# ── Animación: aparece → espera 3 s → desvanece ──────────
	root.modulate.a = 0.0
	_zone_warn_tween = create_tween()
	# fade in 0.35 s
	_zone_warn_tween.tween_property(root, "modulate:a", 1.0, 0.35)
	# mantener 3 s
	_zone_warn_tween.tween_interval(3.0)
	# fade out 0.8 s
	_zone_warn_tween.tween_property(root, "modulate:a", 0.0, 0.8)
	_zone_warn_tween.tween_callback(func():
		if is_instance_valid(_zone_warn_root):
			_zone_warn_root.queue_free()
		_zone_warn_root = null
	)

func is_any_panel_open() -> bool:
	return is_inventory_open or is_dialog_open or is_shop_open or is_bank_open or (_auction_panel != null and is_instance_valid(_auction_panel))

# ════════════════════════════════════════════════════════════
# MEJORA 8 — NOTIFICACIÓN GLOBAL DE BOSS DISPONIBLE
# ════════════════════════════════════════════════════════════
# Banner espectacular en pantalla cuando un boss respawnea.
# Se llama desde cada world_*.gd en el callback de respawn.
# Parámetros:
#   boss_name  → "Skeleton King", "Goblin Shaman", etc.
#   zone_name  → "las Tierras del Norte", "el Sur", etc.
#   boss_color → color temático del boss (rojo, verde, etc.)
# ════════════════════════════════════════════════════════════

var _boss_notif_root:  Control = null
var _boss_notif_tween: Tween   = null

func show_boss_notification(boss_name: String, zone_name: String, boss_color: Color = Color(0.9, 0.1, 0.1)) -> void:
	# Cancelar notificación anterior si aún está en pantalla
	if _boss_notif_tween and _boss_notif_tween.is_valid():
		_boss_notif_tween.kill()
	if _boss_notif_root and is_instance_valid(_boss_notif_root):
		_boss_notif_root.queue_free()
		_boss_notif_root = null

	# ── Sonido boss_roar ──────────────────────────────────────
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("boss_roar")

	var vp_size := get_viewport().get_visible_rect().size

	# ── Raíz del banner ───────────────────────────────────────
	var root := Control.new()
	root.name         = "BossNotifBanner"
	root.z_index      = 25
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(root)
	_boss_notif_root = root

	var banner_w : float = vp_size.x * 0.70
	var banner_h : float = 76.0
	var banner_x : float = (vp_size.x - banner_w) * 0.5
	var banner_y : float = vp_size.y * 0.12

	# ── Sombra exterior ───────────────────────────────────────
	var shadow := ColorRect.new()
	shadow.color        = Color(0.0, 0.0, 0.0, 0.45)
	shadow.size         = Vector2(banner_w + 8, banner_h + 8)
	shadow.position     = Vector2(banner_x - 4, banner_y - 4)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)

	# ── Fondo principal (oscuro con tinte del color del boss) ─
	var bg_col := Color(
		boss_color.r * 0.18 + 0.04,
		boss_color.g * 0.10 + 0.02,
		boss_color.b * 0.10 + 0.02,
		0.92
	)
	var bg := ColorRect.new()
	bg.color        = bg_col
	bg.size         = Vector2(banner_w, banner_h)
	bg.position     = Vector2(banner_x, banner_y)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# ── Barra lateral izquierda (color boss) ──────────────────
	var bar_left := ColorRect.new()
	bar_left.color    = boss_color
	bar_left.size     = Vector2(6.0, banner_h)
	bar_left.position = Vector2(banner_x, banner_y)
	root.add_child(bar_left)

	# ── Barra lateral derecha ─────────────────────────────────
	var bar_right := ColorRect.new()
	bar_right.color    = boss_color
	bar_right.size     = Vector2(6.0, banner_h)
	bar_right.position = Vector2(banner_x + banner_w - 6.0, banner_y)
	root.add_child(bar_right)

	# ── Línea superior e inferior de borde ────────────────────
	var border_top := ColorRect.new()
	border_top.color    = Color(boss_color.r, boss_color.g, boss_color.b, 0.55)
	border_top.size     = Vector2(banner_w, 2.0)
	border_top.position = Vector2(banner_x, banner_y)
	root.add_child(border_top)
	var border_bot := ColorRect.new()
	border_bot.color    = border_top.color
	border_bot.size     = Vector2(banner_w, 2.0)
	border_bot.position = Vector2(banner_x, banner_y + banner_h - 2.0)
	root.add_child(border_bot)

	# ── Icono ☠ grande a la izquierda ────────────────────────
	var skull_lbl := Label.new()
	skull_lbl.text                 = "☠"
	skull_lbl.add_theme_font_size_override("font_size", 32)
	skull_lbl.add_theme_color_override("font_color", boss_color)
	skull_lbl.size                 = Vector2(52.0, banner_h)
	skull_lbl.position             = Vector2(banner_x + 14.0, banner_y)
	skull_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	skull_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skull_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	root.add_child(skull_lbl)

	# ── Icono ☠ grande a la derecha ───────────────────────────
	var skull_r := Label.new()
	skull_r.text                 = "☠"
	skull_r.add_theme_font_size_override("font_size", 32)
	skull_r.add_theme_color_override("font_color", boss_color)
	skull_r.size                 = Vector2(52.0, banner_h)
	skull_r.position             = Vector2(banner_x + banner_w - 66.0, banner_y)
	skull_r.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	skull_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skull_r.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	root.add_child(skull_r)

	# ── Texto central: nombre del boss ────────────────────────
	var name_lbl := Label.new()
	name_lbl.text                 = boss_name + " ha despertado"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	name_lbl.size                 = Vector2(banner_w - 120.0, banner_h * 0.55)
	name_lbl.position             = Vector2(banner_x + 60.0, banner_y + 4.0)
	name_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", boss_color)
	name_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	name_lbl.add_theme_constant_override("shadow_offset_x", 2)
	name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(name_lbl)

	# ── Subtexto: zona ────────────────────────────────────────
	var zone_lbl := Label.new()
	zone_lbl.text                 = "en " + zone_name
	zone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	zone_lbl.size                 = Vector2(banner_w - 120.0, banner_h * 0.45)
	zone_lbl.position             = Vector2(banner_x + 60.0, banner_y + banner_h * 0.52)
	zone_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	zone_lbl.add_theme_font_size_override("font_size", 13)
	zone_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.82))
	zone_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.80))
	zone_lbl.add_theme_constant_override("shadow_offset_x", 1)
	zone_lbl.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(zone_lbl)

	# ── Animación: desliza desde arriba → espera → fade out ──
	root.modulate.a     = 0.0
	root.position.y    -= 30.0   # empieza 30px arriba
	_boss_notif_tween   = create_tween().set_parallel(false)
	# slide-in + fade-in simultáneos (0.45 s)
	var slide_tween := create_tween().set_parallel(true)
	slide_tween.tween_property(root, "modulate:a", 1.0,     0.45)
	slide_tween.tween_property(root, "position:y",  root.position.y + 30.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await slide_tween.finished
	# Pulso de color en el icono para reforzar el aviso
	var pulse := create_tween()
	pulse.tween_property(skull_lbl, "modulate", Color(1.5, 1.2, 1.2), 0.18)
	pulse.tween_property(skull_lbl, "modulate", Color.WHITE, 0.22)
	pulse.tween_property(skull_r,   "modulate", Color(1.5, 1.2, 1.2), 0.18)
	pulse.tween_property(skull_r,   "modulate", Color.WHITE, 0.22)
	# Esperar 5 s visible
	await get_tree().create_timer(5.0).timeout
	# Fade out 1.0 s
	if is_instance_valid(root):
		var fade := create_tween()
		fade.tween_property(root, "modulate:a", 0.0, 1.0)
		await fade.finished
		if is_instance_valid(root):
			root.queue_free()
	_boss_notif_root = null

# ============================================================
# DUNGEON HUD (Paso 5)
# ============================================================

var _dungeon_hud: Control = null

func set_dungeon_mode(active: bool) -> void:
	if active:
		_create_dungeon_hud()
	else:
		_remove_dungeon_hud()

func _create_dungeon_hud() -> void:
	if _dungeon_hud and is_instance_valid(_dungeon_hud):
		return

	_dungeon_hud = PanelContainer.new()
	_dungeon_hud.name = "DungeonHUD"
	# Posición: esquina superior derecha
	_dungeon_hud.position = Vector2(get_viewport().get_visible_rect().size.x - 220, 12)
	_dungeon_hud.custom_minimum_size = Vector2(200, 50)
	panel_root.add_child(_dungeon_hud)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	_dungeon_hud.add_child(vbox)

	var zone_lbl = Label.new()
	zone_lbl.name = "ZoneLabel"
	zone_lbl.text = "🏰 Stone Dungeon"
	zone_lbl.add_theme_font_size_override("font_size", 12)
	zone_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 1.0))
	vbox.add_child(zone_lbl)

	var enemy_lbl = Label.new()
	enemy_lbl.name = "EnemyCount"
	enemy_lbl.text = "Enemigos: ?"
	enemy_lbl.add_theme_font_size_override("font_size", 11)
	enemy_lbl.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	vbox.add_child(enemy_lbl)

func _remove_dungeon_hud() -> void:
	if _dungeon_hud and is_instance_valid(_dungeon_hud):
		_dungeon_hud.queue_free()
		_dungeon_hud = null

func update_enemy_count(count: int) -> void:
	if not _dungeon_hud or not is_instance_valid(_dungeon_hud):
		return
	var lbl = _dungeon_hud.get_node_or_null("VBox/EnemyCount")
	if lbl:
		if count == 0:
			lbl.text = "✅ Zona despejada"
			lbl.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		else:
			lbl.text = "Enemigos: %d" % count
			lbl.add_theme_color_override("font_color", Color(1, 0.5, 0.5))

# ============================================================
# CASA DE SUBASTAS
# ============================================================

var _auction_panel     : Control = null
var _auction_tab_index : int     = 0   # 0=Explorar  1=Mis Subastas  2=Publicar

func open_auction() -> void:
	close_dialog()
	if _auction_panel != null:
		_auction_panel.queue_free()
		_auction_panel = null
		return
	_auction_tab_index = 0
	_build_auction_panel()

# ============================================================
# CURANDERA — NPC de curación (v26)
# ============================================================
func open_healer(_npc) -> void:
	var pd = PlayerData
	if pd.hp >= pd.max_hp:
		_show_screen_notification("💚 Ya tienes la vida al máximo.", Color(0.4, 1.0, 0.5))
		return
	if pd.can_use_free_heal():
		pd.heal(pd.max_hp - pd.hp)
		pd.register_healer_use(true)
		_show_screen_notification("💚 ¡Primera curación gratis! Vida restaurada.", Color(0.4, 1.0, 0.5))
		return
	if pd.can_use_free_cooldown_heal():
		pd.heal(pd.max_hp - pd.hp)
		pd.register_healer_use(false)
		_show_screen_notification("💚 Vida restaurada. (Próxima gratis en 10 min)", Color(0.4, 1.0, 0.5))
		return
	var mins_left : int = int(ceil(float(pd.healer_cooldown_remaining()) / 60.0))
	if pd.get_total_bronze() >= pd.HEALER_COST_BRONZE:
		_show_healer_confirm_panel(mins_left)
	else:
		_show_screen_notification(
			"💚 Debes esperar %d min. o necesitas %d bronce." % [mins_left, pd.HEALER_COST_BRONZE],
			Color(1.0, 0.85, 0.3)
		)

func _show_healer_confirm_panel(mins_left: int) -> void:
	var pd = PlayerData
	var root := PanelContainer.new()
	root.name = "HealerConfirmPanel"
	root.custom_minimum_size = Vector2(280, 160)
	root.anchor_left   = 0.5; root.anchor_top    = 0.5
	root.anchor_right  = 0.5; root.anchor_bottom = 0.5
	root.offset_left   = -140; root.offset_top   = -80
	root.offset_right  =  140; root.offset_bottom =  80
	root.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.08, 0.06, 0.15, 0.97)
	style.border_width_left = 2; style.border_width_top    = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(0.4, 1.0, 0.5, 0.9)
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	root.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)
	var title := Label.new()
	title.text = "💚 Curandera"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	vbox.add_child(title)
	var info := Label.new()
	info.text = "Curación gratis en %d min.\n¿Pagar %d bronce ahora?" % [mins_left, pd.HEALER_COST_BRONZE]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)
	var btn_pay := Button.new()
	btn_pay.text = "✅ Pagar"
	btn_pay.pressed.connect(func():
		if pd.spend_bronze(pd.HEALER_COST_BRONZE):
			pd.heal(pd.max_hp - pd.hp)
			pd.register_healer_use(false)
			_show_screen_notification("💚 Vida restaurada. (%d bronce gastado)" % pd.HEALER_COST_BRONZE, Color(0.4, 1.0, 0.5))
		else:
			_show_screen_notification("Sin bronce suficiente.", Color(1.0, 0.4, 0.4))
		root.queue_free()
	)
	hbox.add_child(btn_pay)
	var btn_cancel := Button.new()
	btn_cancel.text = "✕ Cancelar"
	btn_cancel.pressed.connect(func(): root.queue_free())
	hbox.add_child(btn_cancel)
	add_child(root)

func _build_auction_panel() -> void:
	if _auction_panel != null:
		_auction_panel.queue_free()

	var root := PanelContainer.new()
	root.name = "AuctionPanel"
	# MOBILE FIX: adaptar al viewport
	var _avp: Vector2 = get_viewport().get_visible_rect().size
	var _aw: float = minf(700.0, _avp.x * 0.97)
	var _ah: float = minf(520.0, _avp.y * 0.95)
	root.custom_minimum_size = Vector2(_aw, _ah)
	root.anchor_left   = 0.5
	root.anchor_top    = 0.5
	root.anchor_right  = 0.5
	root.anchor_bottom = 0.5
	root.offset_left   = -_aw * 0.5
	root.offset_top    = -_ah * 0.5
	root.offset_right  =  _aw * 0.5
	root.offset_bottom =  _ah * 0.5
	panel_root.add_child(root)
	_auction_panel = root

	# VIS 1: Fondo oscuro con borde dorado y sombra
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color           = Color(0.07, 0.06, 0.13, 0.97)
	panel_style.border_width_left  = 2
	panel_style.border_width_top   = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color       = Color(0.85, 0.68, 0.15, 1.0)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_color       = Color(0, 0, 0, 0.7)
	panel_style.shadow_size        = 12
	panel_style.shadow_offset      = Vector2(4, 6)
	panel_style.content_margin_left   = 14
	panel_style.content_margin_right  = 14
	panel_style.content_margin_top    = 12
	panel_style.content_margin_bottom = 12
	root.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	root.add_child(vbox)

	# Título
	var title_bar := HBoxContainer.new()
	vbox.add_child(title_bar)

	var title_lbl := Label.new()
	title_lbl.text = "🏷  CASA DE SUBASTAS"
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.6, 0.4, 0.0, 0.8))
	title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	title_lbl.add_theme_constant_override("shadow_offset_y", 1)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_lbl)

	var won_count := AuctionManager.get_won_items_count()
	if won_count > 0:
		var claim_btn := Button.new()
		claim_btn.text = "📦 Reclamar  +%d" % won_count
		claim_btn.add_theme_font_size_override("font_size", 11)
		# VIS 6: Botón reclamar — verde neón, llama la atención
		var cs := StyleBoxFlat.new()
		cs.bg_color    = Color(0.05, 0.50, 0.18, 1.0)
		cs.border_width_left = 1; cs.border_width_top = 1
		cs.border_width_right = 1; cs.border_width_bottom = 3
		cs.border_color = Color(0.3, 1.0, 0.5, 1.0)
		cs.corner_radius_top_left = 5; cs.corner_radius_top_right = 5
		cs.corner_radius_bottom_left = 5; cs.corner_radius_bottom_right = 5
		cs.content_margin_left = 10; cs.content_margin_right = 10
		cs.content_margin_top = 4; cs.content_margin_bottom = 4
		claim_btn.add_theme_stylebox_override("normal", cs)
		var ch := cs.duplicate(); ch.bg_color = Color(0.08, 0.70, 0.25, 1.0)
		claim_btn.add_theme_stylebox_override("hover", ch)
		claim_btn.add_theme_color_override("font_color", Color(0.8, 1.0, 0.85))
		claim_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		claim_btn.pressed.connect(func():
			AuctionManager.claim_won_items()
			_build_auction_panel()
		)
		title_bar.add_child(claim_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 30)
	# VIS 8: X de cierre — rojo oscuro con hover rojo vivo
	var xs := StyleBoxFlat.new()
	xs.bg_color    = Color(0.35, 0.07, 0.07, 1.0)
	xs.border_width_left = 1; xs.border_width_top = 1
	xs.border_width_right = 1; xs.border_width_bottom = 1
	xs.border_color = Color(0.7, 0.2, 0.2, 0.8)
	xs.corner_radius_top_left = 4; xs.corner_radius_top_right = 4
	xs.corner_radius_bottom_left = 4; xs.corner_radius_bottom_right = 4
	var xh := xs.duplicate(); xh.bg_color = Color(0.7, 0.10, 0.10, 1.0); xh.border_color = Color(1.0, 0.3, 0.3, 1.0)
	close_btn.add_theme_stylebox_override("normal", xs)
	close_btn.add_theme_stylebox_override("hover", xh)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.85))
	close_btn.pressed.connect(func():
		_auction_panel.queue_free()
		_auction_panel = null
	)
	title_bar.add_child(close_btn)

	# Tabs
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 2)
	vbox.add_child(tab_bar)

	var tab_labels := ["🔍 Explorar", "📋 Mis Subastas", "📤 Publicar"]
	for i in range(tab_labels.size()):
		var idx := i
		var tb := Button.new()
		tb.text = tab_labels[i]
		tb.toggle_mode = true
		tb.button_pressed = (idx == _auction_tab_index)
		tb.custom_minimum_size = Vector2(140, 32)
		tb.add_theme_font_size_override("font_size", 11)
		# VIS 3: Tab activa = dorado, inactiva = oscura
		var is_active : bool = (idx == _auction_tab_index)
		var ts := StyleBoxFlat.new()
		ts.bg_color = Color(0.55, 0.38, 0.07, 1.0) if is_active else Color(0.12, 0.10, 0.20, 0.9)
		ts.border_width_bottom = 2 if is_active else 0
		ts.border_color = Color(1.0, 0.82, 0.2, 1.0)
		ts.corner_radius_top_left = 5
		ts.corner_radius_top_right = 5
		ts.content_margin_left = 10; ts.content_margin_right = 10
		ts.content_margin_top = 5; ts.content_margin_bottom = 5
		tb.add_theme_stylebox_override("normal", ts)
		tb.add_theme_stylebox_override("pressed", ts)
		var th := ts.duplicate()
		th.bg_color = Color(0.70, 0.50, 0.10, 1.0)
		tb.add_theme_stylebox_override("hover", th)
		tb.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35) if is_active else Color(0.65, 0.60, 0.80))
		tb.pressed.connect(func():
			_auction_tab_index = idx
			_build_auction_panel()
		)
		tab_bar.add_child(tb)

	vbox.add_child(HSeparator.new())

	var content_scroll := ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_scroll)

	match _auction_tab_index:
		0: _build_auction_browse(content_scroll)
		1: _build_auction_my_listings(content_scroll)
		2: _build_auction_post(content_scroll)

func _build_auction_browse(scroll: ScrollContainer) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	var active := AuctionManager.get_active_listings()
	if active.is_empty():
		var lbl := Label.new()
		lbl.text = "No hay subastas activas."
		lbl.add_theme_color_override("font_color", Color(0.55, 0.5, 0.65))
		vbox.add_child(lbl)
		return

	vbox.add_child(_auction_row_header())
	vbox.add_child(HSeparator.new())
	for listing in active:
		vbox.add_child(_auction_listing_row(listing, true))

func _build_auction_my_listings(scroll: ScrollContainer) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	var mine := AuctionManager.get_my_listings()
	if mine.is_empty():
		var lbl := Label.new()
		lbl.text = "No tienes subastas publicadas."
		lbl.add_theme_color_override("font_color", Color(0.55, 0.5, 0.65))
		vbox.add_child(lbl)
		return

	vbox.add_child(_auction_row_header())
	vbox.add_child(HSeparator.new())
	for listing in mine:
		vbox.add_child(_auction_listing_row(listing, false))

var _post_selected_key : String = ""
var _post_qty_value    : int    = 1
var _post_price_value  : int    = 10

func _build_auction_post(scroll: ScrollContainer) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var info_lbl := Label.new()
	info_lbl.text = "Selecciona un ítem de tu inventario para subastar:"
	info_lbl.add_theme_font_size_override("font_size", 11)
	info_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
	vbox.add_child(info_lbl)

	var grid := GridContainer.new()
	grid.columns = 5
	vbox.add_child(grid)

	var has_items := false
	for i in range(InventoryManager.items.size()):
		var item = InventoryManager.items[i]
		if item == null:
			continue
		has_items = true
		var ikey : String = item.get("key", "")
		var qty  : int    = item.get("qty", 1)
		var rc : Color = InventoryManager.get_rarity_color(item.get("rarity", "common"))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 52)
		btn.toggle_mode = true
		btn.button_pressed = (ikey == _post_selected_key)
		btn.text = "%s\n%s\n×%d" % [
			InventoryManager.get_category_icon(item.get("category", "")),
			item.get("name", ikey), qty
		]
		btn.add_theme_font_size_override("font_size", 9)
		btn.add_theme_color_override("font_color", rc)
		btn.pressed.connect(func():
			_post_selected_key = ikey
			_post_qty_value = 1
			_build_auction_panel()
		)
		grid.add_child(btn)

	if not has_items:
		var empty := Label.new()
		empty.text = "Tu inventario está vacío."
		empty.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))
		vbox.add_child(empty)
		return

	if _post_selected_key == "":
		return

	vbox.add_child(HSeparator.new())

	var sel_info : Dictionary = InventoryManager.get_item_info(_post_selected_key)
	var sel_lbl := Label.new()
	sel_lbl.text = "Seleccionado: %s  %s" % [
		InventoryManager.get_category_icon(sel_info.get("category", "")),
		sel_info.get("name", _post_selected_key)
	]
	sel_lbl.add_theme_font_size_override("font_size", 13)
	sel_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	vbox.add_child(sel_lbl)

	# Cantidad
	var qty_row := HBoxContainer.new()
	vbox.add_child(qty_row)
	var ql := Label.new()
	ql.text = "Cantidad:"
	ql.custom_minimum_size = Vector2(110, 0)
	qty_row.add_child(ql)
	var max_qty : int = InventoryManager.get_item_count(_post_selected_key)
	# MOBILE FIX: reemplazar SpinBox por botones táctiles grandes
	var _qty_val_ref := [clamp(_post_qty_value, 1, max_qty)]
	var qty_minus := Button.new(); qty_minus.text = "−"; qty_minus.custom_minimum_size = Vector2(48, 48)
	var qty_lbl_val := Label.new(); qty_lbl_val.text = str(_qty_val_ref[0]); qty_lbl_val.custom_minimum_size = Vector2(48, 48)
	qty_lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; qty_lbl_val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var qty_plus := Button.new(); qty_plus.text = "+"; qty_plus.custom_minimum_size = Vector2(48, 48)
	qty_minus.pressed.connect(func():
		_qty_val_ref[0] = max(1, _qty_val_ref[0] - 1)
		_post_qty_value = _qty_val_ref[0]
		qty_lbl_val.text = str(_qty_val_ref[0]))
	qty_plus.pressed.connect(func():
		_qty_val_ref[0] = min(max_qty, _qty_val_ref[0] + 1)
		_post_qty_value = _qty_val_ref[0]
		qty_lbl_val.text = str(_qty_val_ref[0]))
	for _b in [qty_minus, qty_lbl_val, qty_plus]: qty_row.add_child(_b)

	# Precio mínimo
	var price_row := HBoxContainer.new()
	vbox.add_child(price_row)
	var pl := Label.new()
	pl.text = "Precio mínimo 🪙:"
	pl.custom_minimum_size = Vector2(110, 0)
	price_row.add_child(pl)
	# MOBILE FIX: precio con botones táctiles +/- con steps
	var _price_steps := [1, 10, 100, 1000]
	var _price_step_idx := [1]  # step = 10 por defecto
	var _price_val_ref := [max(_post_price_value, 1)]
	var pr_minus := Button.new(); pr_minus.text = "−"; pr_minus.custom_minimum_size = Vector2(48, 48)
	var pr_lbl_val := Label.new(); pr_lbl_val.text = str(_price_val_ref[0]); pr_lbl_val.custom_minimum_size = Vector2(70, 48)
	pr_lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pr_lbl_val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pr_plus := Button.new(); pr_plus.text = "+"; pr_plus.custom_minimum_size = Vector2(48, 48)
	var pr_step_btn := Button.new()
	pr_step_btn.text = "×%d" % _price_steps[_price_step_idx[0]]; pr_step_btn.custom_minimum_size = Vector2(52, 48)
	pr_minus.pressed.connect(func():
		var _step = _price_steps[_price_step_idx[0]]
		_price_val_ref[0] = max(1, _price_val_ref[0] - _step)
		_post_price_value = _price_val_ref[0]; pr_lbl_val.text = str(_price_val_ref[0]))
	pr_plus.pressed.connect(func():
		var _step = _price_steps[_price_step_idx[0]]
		_price_val_ref[0] = min(99999, _price_val_ref[0] + _step)
		_post_price_value = _price_val_ref[0]; pr_lbl_val.text = str(_price_val_ref[0]))
	pr_step_btn.pressed.connect(func():
		_price_step_idx[0] = (_price_step_idx[0] + 1) % _price_steps.size()
		pr_step_btn.text = "×%d" % _price_steps[_price_step_idx[0]])
	for _b in [pr_minus, pr_lbl_val, pr_plus, pr_step_btn]: price_row.add_child(_b)

	# Publicar
	var pub_btn := Button.new()
	pub_btn.text = "📤  PUBLICAR SUBASTA  —  duración: 2 min"
	pub_btn.custom_minimum_size = Vector2(0, 44)
	pub_btn.add_theme_font_size_override("font_size", 12)
	# VIS 9: Botón publicar — dorado llamativo
	var ps := StyleBoxFlat.new()
	ps.bg_color    = Color(0.50, 0.33, 0.04, 1.0)
	ps.border_width_left = 1; ps.border_width_top = 1
	ps.border_width_right = 1; ps.border_width_bottom = 3
	ps.border_color = Color(1.0, 0.80, 0.15, 1.0)
	ps.corner_radius_top_left = 6; ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 6; ps.corner_radius_bottom_right = 6
	ps.shadow_color = Color(0, 0, 0, 0.4); ps.shadow_size = 4
	var ph := ps.duplicate(); ph.bg_color = Color(0.70, 0.48, 0.06, 1.0); ph.border_color = Color(1.0, 0.95, 0.30, 1.0)
	pub_btn.add_theme_stylebox_override("normal", ps)
	pub_btn.add_theme_stylebox_override("hover", ph)
	pub_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	pub_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.8))
	pub_btn.pressed.connect(func():
		var ok := AuctionManager.post_item(_post_selected_key, _post_qty_value, _post_price_value)
		if ok:
			_post_selected_key = ""
			_auction_tab_index = 1
			_build_auction_panel()
		else:
			pub_btn.text = "⚠ No tienes suficiente ítem"
	)
	vbox.add_child(pub_btn)

func _auction_row_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	# VIS 7: fondo del header de columnas
	var hbg := ColorRect.new()
	hbg.color = Color(0.18, 0.14, 0.30, 0.60)
	hbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbg.z_index = -1
	row.add_child(hbg)
	for col in [["  Ítem", 200], ["Vendedor", 90], ["Puja 🪙", 90], ["⏱ Tiempo", 75], ["Acción", 130]]:
		var lbl := Label.new()
		lbl.text = col[0]
		lbl.custom_minimum_size = Vector2(col[1], 20)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.82, 0.75, 1.0))
		row.add_child(lbl)
	return row

func _auction_listing_row(listing: Dictionary, show_bid: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var info  : Dictionary = InventoryManager.get_item_info(listing["item_key"])
	var rc    : Color = InventoryManager.get_rarity_color(info.get("rarity", "common"))

	# VIS 4: fondo de fila — verde suave si estás ganando, neutro si no
	var is_winning_row : bool = listing.get("top_bidder", "") == PlayerData.character_name
	var row_bg := ColorRect.new()
	row_bg.color = Color(0.05, 0.22, 0.07, 0.45) if is_winning_row else Color(0.10, 0.09, 0.18, 0.30)
	row_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row_bg.z_index = -1
	row.add_child(row_bg)

	# Ítem
	var il := Label.new()
	il.text = "%s %s ×%d" % [
		InventoryManager.get_category_icon(info.get("category", "")),
		info.get("name", listing["item_key"]),
		listing.get("qty", 1)
	]
	il.custom_minimum_size = Vector2(200, 0)
	il.add_theme_font_size_override("font_size", 10)
	il.add_theme_color_override("font_color", rc)
	il.clip_text = true
	row.add_child(il)

	# Vendedor
	var sl := Label.new()
	sl.text = listing.get("seller", "?")
	sl.custom_minimum_size = Vector2(90, 0)
	sl.add_theme_font_size_override("font_size", 10)
	sl.add_theme_color_override("font_color", Color(0.75, 0.7, 0.9))
	row.add_child(sl)

	# Puja
	var is_winning : bool = listing.get("top_bidder", "") == PlayerData.character_name
	var bl := Label.new()
	bl.text = "%d" % listing["current_bid"]
	bl.custom_minimum_size = Vector2(90, 0)
	bl.add_theme_font_size_override("font_size", 10)
	bl.add_theme_color_override("font_color",
		Color(0.3, 1.0, 0.4) if is_winning else Color(1.0, 0.85, 0.2))
	row.add_child(bl)

	# Tiempo
	var tl := Label.new()
	tl.text = AuctionManager.format_time(listing.get("time_left", 0))
	tl.custom_minimum_size = Vector2(75, 0)
	tl.add_theme_font_size_override("font_size", 10)
	tl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	row.add_child(tl)

	# Botón
	if show_bid:
		var lid : int = listing["id"]
		var ab := Button.new()
		ab.custom_minimum_size = Vector2(130, 0)
		ab.add_theme_font_size_override("font_size", 9)
		if is_winning:
			ab.text = "✅ Ganando"
			ab.disabled = true
		elif listing.get("seller","") == PlayerData.character_name:
			ab.text = "📋 Tu subasta"
			ab.disabled = true
		else:
			var next_bid : int = int(listing["current_bid"]) + 5
			ab.text = "⬆ Pujar  %d🪙" % next_bid
			# VIS 5: botón de puja verde brillante
			var bs := StyleBoxFlat.new()
			bs.bg_color    = Color(0.08, 0.42, 0.15, 1.0)
			bs.border_width_left = 1; bs.border_width_top = 1
			bs.border_width_right = 1; bs.border_width_bottom = 2
			bs.border_color = Color(0.25, 0.9, 0.35, 0.9)
			bs.corner_radius_top_left = 4; bs.corner_radius_top_right = 4
			bs.corner_radius_bottom_left = 4; bs.corner_radius_bottom_right = 4
			bs.content_margin_left = 8; bs.content_margin_right = 8
			var bh := bs.duplicate()
			bh.bg_color = Color(0.12, 0.60, 0.22, 1.0)
			bh.border_color = Color(0.4, 1.0, 0.5, 1.0)
			ab.add_theme_stylebox_override("normal", bs)
			ab.add_theme_stylebox_override("hover", bh)
			ab.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
			ab.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
			ab.pressed.connect(func():
				var ok := AuctionManager.place_bid(lid, next_bid)
				if ok:
					_build_auction_panel()
				else:
					ab.text = "⚠ Sin fondos"
					ab.disabled = true
			)
		row.add_child(ab)

	return row

# ============================================================
# HUD SYSTEM — funciones de configuración y edición
# ============================================================

func _apply_hud_config() -> void:
	if not has_node("/root/HudConfig"):
		return
	# Stats Box
	var stats := get_node_or_null("HUDContainer/StatsBox")
	if stats:
		var el := HudConfig.get_element("stats")
		stats.position = Vector2(12, 12) + Vector2(el["offset_x"], el["offset_y"])
		stats.scale = Vector2.ONE * HudConfig.get_effective_scale("stats")
		stats.modulate.a = HudConfig.get_effective_alpha("stats")

	# XP Bar
	var xp := get_node_or_null("HUDContainer/XPBarBG")
	if xp:
		var el := HudConfig.get_element("xp_bar")
		xp.modulate.a = HudConfig.get_effective_alpha("xp_bar")

	# Joystick
	var joy := get_node_or_null("MobileControls/JoystickBase")
	if joy:
		var el := HudConfig.get_element("joystick")
		joy.modulate.a = HudConfig.get_effective_alpha("joystick")
		joy.scale = Vector2.ONE * HudConfig.get_effective_scale("joystick")

	# Action Buttons
	var acts := get_node_or_null("MobileControls/ActionButtons")
	if acts:
		var el := HudConfig.get_element("actions")
		acts.modulate.a = HudConfig.get_effective_alpha("actions")
		acts.scale = Vector2.ONE * HudConfig.get_effective_scale("actions")

	HudConfig.config_changed.connect(_apply_hud_config)

func _add_hud_edit_button() -> void:
	var btn := Button.new()
	btn.text = "⚙"
	btn.tooltip_text = "Ajustes"
	btn.anchor_left   = 1.0
	btn.anchor_right  = 1.0
	btn.anchor_top    = 0.0
	btn.anchor_bottom = 0.0
	# FIX: el minimapa ocupa la esquina superior derecha (top=10, height≈208px aprox).
	# El botón se movió debajo del minimapa para que no quede tapado.
	# MINIMAP_SIZE(140) + label(30) + leyenda(18) + margen_top(10) + gap(8) = 206px → offset_top = 210
	btn.offset_left   = -36.0
	btn.offset_right  = -8.0
	btn.offset_top    = 210.0
	btn.offset_bottom = 238.0
	btn.flat = true
	btn.z_index = 90   # FIX: por encima del minimapa (z_index=80) para nunca quedar tapado
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_on_settings_pressed)
	$HUDContainer.add_child(btn)

func _on_settings_pressed() -> void:
	# Abre SettingsScene como overlay (no reemplaza la escena activa)
	if get_tree().current_scene.has_node("SettingsScene"):
		return  # ya está abierto
	var scene_res = load("res://scenes/settings_scene.tscn")
	if scene_res:
		get_tree().current_scene.add_child(scene_res.instantiate())
	else:
		push_warning("[GameUI] No se encontró settings_scene.tscn")

# ============================================================
# TOOL SYSTEM — funciones de herramientas equipadas
# ============================================================

func _build_tool_slots() -> void:
	var tool_row_node := get_node_or_null("InventoryPanel/VBox/ToolRow")
	if not tool_row_node:
		return
	for child in tool_row_node.get_children():
		child.queue_free()
	if not has_node("/root/ToolManager"):
		return
	var tm = get_node("/root/ToolManager")
	var professions := ["mining", "woodcutting", "herbalism"]
	var prof_icons  := {"mining": "⛏", "woodcutting": "🪓", "herbalism": "🌿"}

	for prof in professions:
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(50, 50)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 1)

		var prof_lbl := Label.new()
		prof_lbl.text = prof_icons.get(prof, "?")
		prof_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prof_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(prof_lbl)

		var name_lbl := Label.new()
		var tool_name : String = tm.get_equipped_name(prof)
		name_lbl.text = tool_name if tool_name != "" else "–"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 7)
		vbox.add_child(name_lbl)

		if tool_name != "":
			var dur_info : Dictionary = tm.get_durability_info(prof)
			var dur_bar := ProgressBar.new()
			dur_bar.min_value = 0.0
			dur_bar.max_value = 1.0
			dur_bar.value     = dur_info["pct"]
			dur_bar.custom_minimum_size = Vector2(44, 5)
			dur_bar.show_percentage = false
			vbox.add_child(dur_bar)

		slot_panel.add_child(vbox)
		slot_panel.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
				tm.unequip_tool(prof)
				_build_tool_slots()
		)
		tool_row_node.add_child(slot_panel)

func _on_tool_broken(profession: String, item: Dictionary) -> void:
	_show_screen_notification("⚠ %s se ha roto!" % item.get("name", profession), Color(1, 0.4, 0.1))
	_build_tool_slots()

func _on_tool_durability_changed(_profession: String, _current: int, _maximum: int) -> void:
	_build_tool_slots()

# ============================================================
# SKILL BAR — habilidades de arma Q / E / R
# ============================================================

func _setup_skill_bar() -> void:
	skill_slots.clear()
	var slot_names := ["Slot1", "Slot2", "Slot3"]
	for sname in slot_names:
		var node := skill_bar.get_node("HBox/" + sname)
		skill_slots.append(node)

	# Conectar señales de WeaponSkillSystem
	if not WeaponSkillSystem.skill_cooldown_updated.is_connected(_on_skill_cd_updated):
		WeaponSkillSystem.skill_cooldown_updated.connect(_on_skill_cd_updated)
	if not WeaponSkillSystem.skill_ready.is_connected(_on_skill_ready):
		WeaponSkillSystem.skill_ready.connect(_on_skill_ready)

	# Conectar cambio de equipo para refrescar iconos
	if not InventoryManager.item_equipped.is_connected(_on_weapon_equipped_for_skills):
		InventoryManager.item_equipped.connect(_on_weapon_equipped_for_skills)
	if not InventoryManager.item_unequipped.is_connected(_on_weapon_unequipped_for_skills):
		InventoryManager.item_unequipped.connect(_on_weapon_unequipped_for_skills)

	_refresh_skill_icons()

func _on_weapon_equipped_for_skills(item: Dictionary) -> void:
	if item.get("slot", "") == "weapon":
		_refresh_skill_icons()

func _on_weapon_unequipped_for_skills(slot: String) -> void:
	if slot == "weapon":
		_refresh_skill_icons()

func _refresh_skill_icons() -> void:
	var weapon_item = InventoryManager.equipped_items.get("weapon", null)
	var wtype: String = ""
	if weapon_item:
		wtype = weapon_item.get("weapon_type", "")

	for i in range(skill_slots.size()):
		var slot_node = skill_slots[i]
		var icon_rect : TextureRect = slot_node.get_node("VBox/Icon")
		var icon_lbl  : Label       = slot_node.get_node_or_null("VBox/Icon/IconLabel")
		var name_lbl  : Label       = slot_node.get_node("VBox/SkillName")
		var cd_lbl    : Label       = slot_node.get_node("VBox/CooldownLabel")
		var overlay   : ColorRect   = slot_node.get_node("CDOverlay")

		if wtype.is_empty() or not WeaponSkillSystem.SKILL_DATA.has(wtype):
			icon_rect.texture = null
			if icon_lbl: icon_lbl.text = "—"
			name_lbl.text = ""
			cd_lbl.text   = ""
			overlay.visible = false
			continue

		var skills: Array = WeaponSkillSystem.SKILL_DATA[wtype]
		if i >= skills.size():
			continue
		var skill: Dictionary = skills[i]

		# PASO 12B — cargar PNG desde el campo "icon" de SKILL_DATA
		var png_path: String = skill.get("icon", "")
		var tex: Texture2D = null
		if png_path.begins_with("res://") and ResourceLoader.exists(png_path):
			tex = ResourceLoader.load(png_path, "Texture2D")
		if tex:
			icon_rect.texture = tex
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if icon_lbl: icon_lbl.text = ""
		else:
			icon_rect.texture = null
			if icon_lbl: icon_lbl.text = "?"

		# PASO 12C — actualizar botón móvil del slot con el mismo icono
		var mobile_btn_paths := [
			"MobileControls/ActionButtons/SkillQBtn",
			"MobileControls/ActionButtons/SkillEBtn",
			"MobileControls/ActionButtons/SkillRBtn",
		]
		if i < mobile_btn_paths.size():
			var mbtn : Button = get_node_or_null(mobile_btn_paths[i])
			if mbtn:
				# Limpiar hijos previos de icono
				for child in mbtn.get_children():
					if child.name == "_skill_icon_rect":
						child.queue_free()
				if tex:
					var tr := TextureRect.new()
					tr.name = "_skill_icon_rect"
					tr.texture = tex
					tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
					tr.offset_left   =  4.0
					tr.offset_top    =  4.0
					tr.offset_right  = -4.0
					tr.offset_bottom = -4.0
					tr.mouse_filter   = Control.MOUSE_FILTER_IGNORE
					mbtn.add_child(tr)
					mbtn.text = ""
				else:
					mbtn.text = ["Q","E","R"][i]

		var full_name: String = skill.get("name", "")
		name_lbl.text = full_name if full_name.length() <= 11 else full_name.substr(0, 10) + "."
		cd_lbl.text   = ""
		overlay.visible = false

func _on_skill_cd_updated(slot: int, remaining: float, total: float) -> void:
	if slot >= skill_slots.size():
		return
	var slot_node = skill_slots[slot]
	var cd_lbl  : Label     = slot_node.get_node("VBox/CooldownLabel")
	var overlay : ColorRect = slot_node.get_node("CDOverlay")

	if remaining > 0.0:
		cd_lbl.text = "%.1fs" % remaining
		overlay.visible = true
		# Overlay crece desde abajo: tapa la fracción del cooldown restante
		var pct: float = remaining / max(total, 0.01)
		overlay.anchor_top    = 1.0 - pct
		overlay.anchor_bottom = 1.0
	else:
		cd_lbl.text     = ""
		overlay.visible = false

func _on_skill_ready(slot: int) -> void:
	if slot >= skill_slots.size():
		return
	var slot_node = skill_slots[slot]
	# Flash verde — habilidad disponible
	var tw: Tween = slot_node.create_tween()
	tw.tween_property(slot_node, "modulate", Color(0.4, 1.0, 0.4), 0.12)
	tw.tween_property(slot_node, "modulate", Color.WHITE, 0.28)

# ══════════════════════════════════════════════════════════════
# ══════════════════════════════════════════════════════════════
# MINIMAPA v2
# Muestra un mapa en miniatura en la esquina superior derecha.
# Leyenda de puntos:
#   Jugador        → punto blanco con flecha de dirección
#   Enemigos vivos → puntos rojos pequeños (grupo "enemy")
#   Portales/bordes → puntos azules (MINIMAP_POIS con type "portal")
#   Campamentos    → puntos amarillos (MINIMAP_POIS con type "camp")
#   Boss zone      → punto rojo grande parpadeante (type "boss")
#   NPCs           → puntos verdes (type "npc")
# Los anillos de peligro se muestran como bandas de color en los worlds.
# ══════════════════════════════════════════════════════════════

# ── Colores de terreno base por zona ──────────────────────────
const MINIMAP_ZONE_COLORS: Dictionary = {
	"town":        Color(0.25, 0.55, 0.20),   # verde hierba
	"dungeon":     Color(0.12, 0.12, 0.16),   # gris muy oscuro
	"world_north": Color(0.72, 0.85, 0.95),   # blanco nieve
	"world_south": Color(0.30, 0.62, 0.22),   # verde campo
	"world_east":  Color(0.62, 0.22, 0.12),   # rojo volcánico
	"world_west":  Color(0.12, 0.12, 0.22),   # azul oscuro bosque
}

# ── Rectángulos de mundo REALES (6000×4000, centrados en origen) ──
# Cada world_*.gd usa: position = Vector2(-SCENE_WIDTH/2, -SCENE_HEIGHT/2)
const MINIMAP_WORLD_RECTS: Dictionary = {
	"town":        Rect2( -640,  -540,  1280, 1080),
	"dungeon":     Rect2( -640,  -540,  1280, 1080),
	"world_north": Rect2(-3000, -2000,  6000, 4000),
	"world_south": Rect2(-3000, -2000,  6000, 4000),
	"world_east":  Rect2(-3000, -2000,  6000, 4000),
	"world_west":  Rect2(-3000, -2000,  6000, 4000),
}

# ── Bandas de peligro por zona (para worlds) ─────────────────
# Cada entrada: [y_from, y_to, color] en coordenadas globales
const MINIMAP_DANGER_BANDS: Dictionary = {
	"world_north": [
		# y positivo = sur (entrada), y negativo = norte (boss)
		[-2000,  -800, Color(0.60, 0.10, 0.10, 0.55)],   # Ring3 — mortal
		[ -800,     0, Color(0.80, 0.35, 0.10, 0.45)],   # Ring2 — peligroso
		[    0,  1600, Color(0.80, 0.75, 0.10, 0.30)],   # Ring1 — medio
		[ 1600,  2000, Color(0.20, 0.75, 0.20, 0.20)],   # Ring0 — seguro
	],
	"world_south": [
		[-2000,  -800, Color(0.60, 0.10, 0.10, 0.55)],
		[ -800,     0, Color(0.80, 0.35, 0.10, 0.45)],
		[    0,  1600, Color(0.80, 0.75, 0.10, 0.30)],
		[ 1600,  2000, Color(0.20, 0.75, 0.20, 0.20)],
	],
	"world_east": [
		[-2000,  -800, Color(0.60, 0.10, 0.10, 0.55)],
		[ -800,     0, Color(0.80, 0.35, 0.10, 0.45)],
		[    0,  1600, Color(0.80, 0.75, 0.10, 0.30)],
		[ 1600,  2000, Color(0.20, 0.75, 0.20, 0.20)],
	],
	"world_west": [
		[-2000,  -800, Color(0.60, 0.10, 0.10, 0.55)],
		[ -800,     0, Color(0.80, 0.35, 0.10, 0.45)],
		[    0,  1600, Color(0.80, 0.75, 0.10, 0.30)],
		[ 1600,  2000, Color(0.20, 0.75, 0.20, 0.20)],
	],
}

# ── Puntos de interés estáticos por zona ─────────────────────
# type: "portal" → azul | "camp" → amarillo | "boss" → rojo parpadeante | "npc" → verde
const MINIMAP_POIS: Dictionary = {
	"town": [
		{"pos": Vector2(  0, -200), "color": Color(0.9, 0.7, 0.1), "size": 5, "type": "npc",    "label": "M"},  # Mercado
		{"pos": Vector2(200,  80),  "color": Color(0.5, 0.5, 0.9), "size": 5, "type": "npc",    "label": "B"},  # Banco
		{"pos": Vector2(-180, 100), "color": Color(0.9, 0.4, 0.2), "size": 5, "type": "npc",    "label": "F"},  # Forja
		{"pos": Vector2(  0,  450), "color": Color(0.3, 0.6, 1.0), "size": 5, "type": "portal", "label": "↗"},  # Portal Norte
		{"pos": Vector2(  0, -450), "color": Color(0.3, 0.6, 1.0), "size": 5, "type": "portal", "label": "↘"},  # Portal Sur
	],
	"world_north": [
		{"pos": Vector2(   0,  1900), "color": Color(0.3, 0.6, 1.0), "size": 5, "type": "portal", "label": "T"},  # Portal a town sur
		{"pos": Vector2(-2900,    0), "color": Color(0.3, 0.6, 1.0), "size": 5, "type": "portal", "label": "←"},  # Portal oeste
		{"pos": Vector2( 2900,    0), "color": Color(0.3, 0.6, 1.0), "size": 5, "type": "portal", "label": "→"},  # Portal este
		{"pos": Vector2(   0, -1900), "color": Color(0.9, 0.1, 0.1), "size": 7, "type": "boss",   "label": "☠"},  # Boss Skeleton King
	],
	"world_south": [
		{"pos": Vector2(   0, -1900), "color": Color(0.3, 0.6, 1.0), "size": 5, "type": "portal", "label": "T"},  # Portal a town norte
		{"pos": Vector2(   0,  1900), "color": Color(0.9, 0.1, 0.1), "size": 7, "type": "boss",   "label": "☠"},  # Salida sur — Boss Goblin Chieftain
	],
	"world_east": [
		{"pos": Vector2(-2900,    0), "color": Color(0.3, 0.6, 1.0), "size": 5, "type": "portal", "label": "T"},
		{"pos": Vector2( 2900,    0), "color": Color(0.9, 0.1, 0.1), "size": 7, "type": "boss",   "label": "☠"},  # Boss Orc Warlord
	],
	"world_west": [
		{"pos": Vector2( 2900,    0), "color": Color(0.3, 0.6, 1.0), "size": 5, "type": "portal", "label": "T"},
		{"pos": Vector2(-2900,    0), "color": Color(0.9, 0.1, 0.1), "size": 7, "type": "boss",   "label": "☠"},  # Boss Shadow Lord
	],
	"dungeon": [
		{"pos": Vector2(   0,  490), "color": Color(0.3, 0.6, 1.0), "size": 5, "type": "portal", "label": "↑"},
		{"pos": Vector2(   0, -490), "color": Color(0.9, 0.1, 0.1), "size": 7, "type": "boss",   "label": "☠"},  # Boss Azathiel
	],
}

# ── Timer acumulado para el parpadeo del boss ─────────────────
var _minimap_boss_blink_t: float = 0.0

func _setup_minimap() -> void:
	# ── Panel contenedor — esquina superior derecha ────────────
	_minimap_panel = PanelContainer.new()
	_minimap_panel.name = "MinimapPanel"
	_minimap_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_minimap_panel.offset_left   = -(MINIMAP_SIZE + 12)
	_minimap_panel.offset_top    = 10
	_minimap_panel.offset_right  = -6
	_minimap_panel.offset_bottom = MINIMAP_SIZE + 30 + 10 + 18   # +30 label zona +18 leyenda
	_minimap_panel.z_index       = 80

	# Estilo — fondo semitransparente con borde dorado
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.04, 0.04, 0.06, 0.75)
	style.border_width_left          = 2
	style.border_width_right         = 2
	style.border_width_top           = 2
	style.border_width_bottom        = 2
	style.border_color               = Color(0.75, 0.70, 0.45, 0.95)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	_minimap_panel.add_theme_stylebox_override("panel", style)

	# VBox interior
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	_minimap_panel.add_child(vbox)

	# Label de nombre de zona
	var zone_lbl := Label.new()
	zone_lbl.name = "ZoneLabel"
	zone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_lbl.add_theme_font_size_override("font_size", 9)
	zone_lbl.add_theme_color_override("font_color", Color(0.92, 0.90, 0.70))
	zone_lbl.custom_minimum_size = Vector2(MINIMAP_SIZE, 14)
	zone_lbl.clip_text = true
	vbox.add_child(zone_lbl)

	# Canvas personalizado (más ligero que SubViewportContainer)
	var map_ctrl := _MinimapDraw.new()
	map_ctrl.name = "MapDraw"
	map_ctrl.custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	vbox.add_child(map_ctrl)

	add_child(_minimap_panel)
	_minimap_canvas = map_ctrl

	# ── Leyenda compacta debajo del mapa ──────────────────────
	var legend_hbox := HBoxContainer.new()
	legend_hbox.name = "LegendBox"
	legend_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	legend_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(legend_hbox)

	var legend_items := [
		["●", Color(1.0, 1.0, 1.0), "Tú"],
		["●", Color(0.9, 0.15, 0.15), "Ene"],
		["●", Color(0.3, 0.6, 1.0), "Portal"],
		["●", Color(0.95, 0.80, 0.10), "Camp"],
	]
	for item in legend_items:
		var dot := Label.new()
		dot.text = item[0]
		dot.add_theme_font_size_override("font_size", 8)
		dot.add_theme_color_override("font_color", item[1])
		legend_hbox.add_child(dot)
		var txt := Label.new()
		txt.text = item[2]
		txt.add_theme_font_size_override("font_size", 7)
		txt.add_theme_color_override("font_color", Color(0.75, 0.75, 0.65))
		legend_hbox.add_child(txt)

	print("[Minimap v2] Inicializado con enemigos, portales, campamentos y boss zone")

func _update_minimap() -> void:
	if not is_instance_valid(_minimap_panel):
		return

	# ── Zona actual ───────────────────────────────────────────
	var zone := ""
	if has_node("/root/AudioManager"):
		zone = get_node("/root/AudioManager").get_current_zone()

	# ── Jugador ───────────────────────────────────────────────
	var player = null
	if GameManager.has_method("get_player"):
		player = GameManager.get_player()
	if not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

	# ── Enemigos vivos ────────────────────────────────────────
	var enemies: Array = get_tree().get_nodes_in_group("enemy")

	# ── Campamentos (nodos con metadato "camp_center") ────────
	var camp_positions: Array = []
	var scene_root = get_tree().current_scene
	if is_instance_valid(scene_root) and scene_root.get("_camps") != null:
		for camp in scene_root._camps:
			if camp.has("center"):
				camp_positions.append(camp["center"])

	# ── Tiempo para parpadeo de boss ──────────────────────────
	_minimap_boss_blink_t += get_process_delta_time()

	# ── Pasar datos al canvas de dibujo ──────────────────────
	if is_instance_valid(_minimap_canvas) and _minimap_canvas.has_method("update_data"):
		_minimap_canvas.update_data(
			zone, player, enemies, camp_positions,
			MINIMAP_WORLD_RECTS, MINIMAP_ZONE_COLORS,
			MINIMAP_DANGER_BANDS, MINIMAP_POIS,
			_minimap_boss_blink_t
		)
		_minimap_canvas.queue_redraw()

	# ── Label de zona ────────────────────────────────────────
	if is_instance_valid(_minimap_panel):
		var zone_lbl: Label = _minimap_panel.get_node_or_null("VBox/ZoneLabel")
		if zone_lbl:
			var display_names := {
				"town":        "⚏ Ciudad",
				"dungeon":     "☗ Mazmorra",
				"world_north": "❄ Norte",
				"world_south": "✿ Sur",
				"world_east":  "🔥 Este",
				"world_west":  "🌑 Oeste",
			}
			zone_lbl.text = display_names.get(zone, zone.capitalize() if zone != "" else "—")

# ──────────────────────────────────────────────────────────────
# _MinimapDraw — clase interna de dibujo del minimapa v2
# Dibuja: terreno + bandas de peligro + POIs + campamentos +
#         enemigos + boss parpadeante + jugador con flecha
# ──────────────────────────────────────────────────────────────
class _MinimapDraw extends ColorRect:
	var _zone:          String  = ""
	var _player:        Node    = null
	var _enemies:       Array   = []
	var _camp_pos:      Array   = []
	var _world_rects:   Dictionary = {}
	var _zone_colors:   Dictionary = {}
	var _danger_bands:  Dictionary = {}
	var _pois:          Dictionary = {}
	var _blink_t:       float   = 0.0

	func _init() -> void:
		color = Color(0.06, 0.07, 0.06, 1.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func update_data(
			z: String, p: Node, enems: Array, camps: Array,
			wr: Dictionary, zc: Dictionary,
			db: Dictionary, poi: Dictionary,
			blink: float) -> void:
		_zone         = z
		_player       = p
		_enemies      = enems
		_camp_pos     = camps
		_world_rects  = wr
		_zone_colors  = zc
		_danger_bands = db
		_pois         = poi
		_blink_t      = blink

	func _draw() -> void:
		var sz     := size
		var margin := 4.0
		var canvas_rect := Rect2(margin, margin, sz.x - margin*2, sz.y - margin*2)

		# ── Fondo de terreno por zona ──────────────────────────
		var terrain_col: Color = _zone_colors.get(_zone, Color(0.15, 0.18, 0.15))
		draw_rect(Rect2(0, 0, sz.x, sz.y), Color(0.04, 0.04, 0.06))  # negro base
		draw_rect(canvas_rect, terrain_col)

		if not _world_rects.has(_zone):
			# Sin datos de zona: solo borde
			draw_rect(canvas_rect, Color(0.5, 0.5, 0.4, 0.4), false, 1.0)
			return

		var world_rect: Rect2 = _world_rects[_zone]

		# ── Bandas de peligro (solo en worlds) ────────────────
		if _danger_bands.has(_zone):
			for band in _danger_bands[_zone]:
				var y_from: float = band[0]
				var y_to:   float = band[1]
				var b_col:  Color = band[2]
				# Convertir Y del mundo a Y del canvas
				var y_top    := _world_to_canvas(Vector2(0, y_from), world_rect, canvas_rect).y
				var y_bottom := _world_to_canvas(Vector2(0, y_to),   world_rect, canvas_rect).y
				if y_top > y_bottom:
					var tmp := y_top; y_top = y_bottom; y_bottom = tmp
				y_top    = clampf(y_top,    canvas_rect.position.y, canvas_rect.end.y)
				y_bottom = clampf(y_bottom, canvas_rect.position.y, canvas_rect.end.y)
				if y_bottom > y_top:
					draw_rect(Rect2(canvas_rect.position.x, y_top,
					                canvas_rect.size.x, y_bottom - y_top), b_col)

		# ── Borde interior del canvas ──────────────────────────
		draw_rect(canvas_rect, Color(0.60, 0.58, 0.38, 0.55), false, 1.0)

		# ── Campamentos dinámicos (amarillo) ──────────────────
		for camp_pos in _camp_pos:
			if not (camp_pos is Vector2):
				continue
			var cp := _world_to_canvas(camp_pos, world_rect, canvas_rect)
			if canvas_rect.has_point(cp):
				draw_circle(cp, 3.5, Color(0.0, 0.0, 0.0, 0.5))
				draw_circle(cp, 3.0, Color(0.95, 0.80, 0.10))

		# ── Puntos de interés estáticos ───────────────────────
		if _pois.has(_zone):
			for poi in _pois[_zone]:
				var poi_canvas := _world_to_canvas(poi["pos"], world_rect, canvas_rect)
				if not canvas_rect.has_point(poi_canvas):
					continue
				var poi_size: float = float(poi.get("size", 3))
				var ptype: String   = poi.get("type", "npc")

				match ptype:
					"boss":
						# Parpadeo: usa seno para oscilar la alpha
						var blink_alpha := 0.55 + 0.45 * sin(_blink_t * 4.0)
						var boss_col    := Color(0.95, 0.08, 0.08, blink_alpha)
						draw_circle(poi_canvas, poi_size + 2.0, Color(0.0, 0.0, 0.0, 0.4))
						draw_circle(poi_canvas, poi_size + 1.5, boss_col)
						# Corona de rayos
						for i in 6:
							var angle = (i / 6.0) * TAU + _blink_t * 1.2
							var ray_end := poi_canvas + Vector2(cos(angle), sin(angle)) * (poi_size + 4.0)
							draw_line(poi_canvas, ray_end, Color(0.95, 0.30, 0.10, blink_alpha * 0.7), 1.0)
					"portal":
						draw_circle(poi_canvas, poi_size * 0.5 + 1.0, Color(0.0, 0.0, 0.0, 0.4))
						draw_circle(poi_canvas, poi_size * 0.5, Color(0.30, 0.60, 1.00))
						# Aro exterior del portal
						draw_arc(poi_canvas, poi_size * 0.5 + 2.0, 0.0, TAU, 8, Color(0.6, 0.8, 1.0, 0.5), 1.0)
					"camp":
						draw_circle(poi_canvas, poi_size * 0.5 + 1.0, Color(0.0, 0.0, 0.0, 0.4))
						draw_circle(poi_canvas, poi_size * 0.5, Color(0.95, 0.80, 0.10))
					_:  # npc / default
						draw_rect(
							Rect2(poi_canvas - Vector2(poi_size * 0.5, poi_size * 0.5),
							      Vector2(poi_size, poi_size)),
							poi.get("color", Color(0.5, 0.9, 0.5))
						)

		# ── Enemigos vivos (puntos rojos pequeños) ─────────────
		var drawn_enemies := 0
		for enemy in _enemies:
			if not is_instance_valid(enemy):
				continue
			# No dibujar más de 40 puntos de enemigo para no saturar
			if drawn_enemies >= 40:
				break
			var ep := _world_to_canvas(enemy.global_position, world_rect, canvas_rect)
			if canvas_rect.has_point(ep):
				draw_circle(ep, 1.8, Color(0.85, 0.12, 0.12, 0.85))
				drawn_enemies += 1

		# ── Jugador (punto blanco con flecha de dirección) ─────
		if is_instance_valid(_player):
			var pc := _world_to_canvas(_player.global_position, world_rect, canvas_rect)
			# Sombra
			draw_circle(pc + Vector2(1, 1), 4.5, Color(0, 0, 0, 0.55))
			# Punto blanco sólido
			draw_circle(pc, 4.5, Color(1.0, 1.0, 1.0))
			# Borde oscuro para contraste
			draw_circle(pc, 4.5, Color(0.2, 0.2, 0.2, 0.6), false, 1.2)
			# Flecha de dirección
			if _player.get("facing_dir") != null:
				var dir: Vector2 = _player.facing_dir.normalized()
				if dir.length_squared() > 0.01:
					var arrow_tip  := pc + dir * 8.5
					var arrow_left := pc + dir.rotated(2.4) * 4.5
					var arrow_right:= pc + dir.rotated(-2.4) * 4.5
					var pts := PackedVector2Array([arrow_tip, arrow_left, arrow_right])
					draw_colored_polygon(pts, Color(0.3, 0.8, 1.0, 0.9))

	func _world_to_canvas(world_pos: Vector2, world_rect: Rect2, canvas_rect: Rect2) -> Vector2:
		var nx: float = (world_pos.x - world_rect.position.x) / world_rect.size.x
		var ny: float = (world_pos.y - world_rect.position.y) / world_rect.size.y
		nx = clampf(nx, 0.0, 1.0)
		ny = clampf(ny, 0.0, 1.0)
		return Vector2(
			canvas_rect.position.x + nx * canvas_rect.size.x,
			canvas_rect.position.y + ny * canvas_rect.size.y
		)


# ════════════════════════════════════════════════════════════
# MEJORA 7 — PANTALLA DE MUERTE CON PENALIZACIONES
# ════════════════════════════════════════════════════════════
# Muestra un overlay rojo con las penalizaciones aplicadas.
# Se autodestruye cuando el jugador llega al pueblo (2 s).

func _on_player_died_penalty_screen() -> void:
	# Calcular penalizaciones para mostrarlas en pantalla
	var xp_loss : int = 0
	if PlayerData.level > 1 and PlayerData.level < PlayerData.MAX_LEVEL:
		xp_loss = int(PlayerData.get_xp_to_next_level() * 0.07)

	var dur_lines : Array = []
	var slots : Array = ["weapon","helmet","chest","legs","boots","gloves"]
	for slot in slots:
		var item = InventoryManager.equipped_items.get(slot, null)
		if item == null or not item.has("durability"):
			continue
		var max_dur : int = item.get("max_durability", 100)
		var loss    : int = max(1, int(max_dur * 0.15))
		dur_lines.append("  • %s: -%d durabilidad" % [item.get("name","?"), loss])

	# ── Overlay oscuro ────────────────────────────────────────
	var vp := get_viewport().get_visible_rect().size
	var overlay := ColorRect.new()
	overlay.name        = "DeathPenaltyOverlay"
	overlay.color       = Color(0.0, 0.0, 0.0, 0.0)
	overlay.size        = vp
	overlay.z_index     = 50
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(overlay)

	# ── Panel central ─────────────────────────────────────────
	var panel_w : float = 420.0
	var panel_h : float = 180.0 + dur_lines.size() * 22.0
	var panel := PanelContainer.new()
	panel.size     = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.z_index  = 51
	overlay.add_child(panel)

	# Estilo rojo oscuro
	var style := StyleBoxFlat.new()
	style.bg_color          = Color(0.18, 0.0, 0.0, 0.92)
	style.border_color      = Color(0.8, 0.1, 0.1, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Título ☠
	var title := Label.new()
	title.text                 = "☠  Has muerto  ☠"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	vbox.add_child(title)

	# Separador
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.6, 0.1, 0.1))
	vbox.add_child(sep)

	# Penalizaciones
	var pen_lbl := Label.new()
	pen_lbl.text = "Penalizaciones aplicadas:"
	pen_lbl.add_theme_font_size_override("font_size", 14)
	pen_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7))
	vbox.add_child(pen_lbl)

	if xp_loss > 0:
		var xp_lbl := Label.new()
		xp_lbl.text = "  • XP perdida: -%d (7%% del nivel actual)" % xp_loss
		xp_lbl.add_theme_font_size_override("font_size", 13)
		xp_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		vbox.add_child(xp_lbl)

	for line in dur_lines:
		var dlbl := Label.new()
		dlbl.text = line
		dlbl.add_theme_font_size_override("font_size", 13)
		dlbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
		vbox.add_child(dlbl)

	# Nota de respawn
	var note := Label.new()
	note.text                 = "Regresando al pueblo..."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	vbox.add_child(note)

	# ── Animación: fade in rápido → esperar → fade out ────────
	var tw := create_tween()
	tw.tween_property(overlay, "color:a", 0.65, 0.4)
	tw.tween_interval(1.4)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.5)
	tw.tween_callback(overlay.queue_free)


# ════════════════════════════════════════════════════════════
# MEJORA 9 — PANEL DE GRUPO (PARTY HUD)
# ════════════════════════════════════════════════════════════
# Muestra en la esquina inferior izquierda las barras HP de
# cada miembro del grupo, con su nombre y color temático.
# Incluye botón "👥 Grupo" para abrir el gestor de party
# (invitar / expulsar / disolver).
# ════════════════════════════════════════════════════════════

var _party_panel:      Control = null
var _party_bars:       Array   = []   # { id, hp_bar, name_lbl, hp_lbl }
var _party_mgr_panel:  Control = null # panel flotante de gestión

# ── CONSTANTES DE DISEÑO ─────────────────────────────────────
const PARTY_BAR_W:  int = 160
const PARTY_BAR_H:  int = 14
const PARTY_SLOT_H: int = 42

func _setup_party_panel() -> void:
	if not has_node("/root/PartyManager"):
		return

	# Contenedor en esquina inferior izquierda (encima del joystick móvil)
	_party_panel = Control.new()
	_party_panel.name         = "PartyPanel"
	_party_panel.anchor_left  = 0.0
	_party_panel.anchor_right = 0.0
	_party_panel.anchor_top   = 1.0
	_party_panel.anchor_bottom= 1.0
	_party_panel.offset_left  = 8.0
	_party_panel.offset_top   = -260.0
	_party_panel.offset_right = PARTY_BAR_W + 16.0
	_party_panel.offset_bottom= -52.0
	_party_panel.z_index      = 70
	$HUDContainer.add_child(_party_panel)

	# Conectar señales de PartyManager
	PartyManager.party_changed.connect(_on_party_changed)
	PartyManager.member_hp_changed.connect(_on_member_hp_changed)

	_rebuild_party_bars()

	# Botón "👥 Grupo" pequeño encima del panel
	var group_btn := Button.new()
	group_btn.text        = "👥 Grupo"
	group_btn.flat        = true
	group_btn.anchor_left = 0.0; group_btn.anchor_right  = 0.0
	group_btn.anchor_top  = 1.0; group_btn.anchor_bottom = 1.0
	group_btn.offset_left = 8.0;  group_btn.offset_right  = 100.0
	group_btn.offset_top  = -278.0; group_btn.offset_bottom = -262.0
	group_btn.z_index     = 71
	group_btn.add_theme_font_size_override("font_size", 11)
	group_btn.add_theme_color_override("font_color", Color(0.85, 0.82, 1.0))
	group_btn.pressed.connect(_toggle_party_manager)
	$HUDContainer.add_child(group_btn)

	# ── Botón Tablero de Progresión ──────────────────────────
	var prog_btn := Button.new()
	prog_btn.text         = "📊 Progresión"
	prog_btn.flat         = true
	prog_btn.anchor_left  = 0.0; prog_btn.anchor_right  = 0.0
	prog_btn.anchor_top   = 1.0; prog_btn.anchor_bottom = 1.0
	prog_btn.offset_left  = 8.0;  prog_btn.offset_right  = 118.0
	prog_btn.offset_top   = -295.0; prog_btn.offset_bottom = -279.0
	prog_btn.z_index      = 71
	prog_btn.add_theme_font_size_override("font_size", 11)
	prog_btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.40))
	prog_btn.pressed.connect(_toggle_progression_board)
	$HUDContainer.add_child(prog_btn)

func _rebuild_party_bars() -> void:
	if not is_instance_valid(_party_panel):
		return
	for child in _party_panel.get_children():
		child.queue_free()
	_party_bars.clear()
	await get_tree().process_frame

	if not has_node("/root/PartyManager"):
		return

	var members: Array = PartyManager.members
	var y_off: float   = 0.0

	for m in members:
		var slot := _make_party_slot(m, y_off)
		_party_panel.add_child(slot)
		y_off += PARTY_SLOT_H + 4

func _make_party_slot(m: Dictionary, y: float) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(PARTY_BAR_W + 8, PARTY_SLOT_H)
	root.position            = Vector2(0, y)

	# Fondo semitransparente
	var bg := ColorRect.new()
	bg.color        = Color(0.05, 0.05, 0.10, 0.72)
	bg.size         = Vector2(PARTY_BAR_W + 8, PARTY_SLOT_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# Barra de color lateral (color del miembro)
	var side_bar := ColorRect.new()
	side_bar.color    = m["color"]
	side_bar.size     = Vector2(3.0, PARTY_SLOT_H)
	side_bar.position = Vector2(0, 0)
	root.add_child(side_bar)

	# Nombre
	var name_lbl := Label.new()
	name_lbl.name     = "NameLbl_%d" % m["id"]
	name_lbl.text     = m["name"]
	name_lbl.position = Vector2(8, 3)
	name_lbl.size     = Vector2(PARTY_BAR_W - 4, 14)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", m["color"].lightened(0.25))
	name_lbl.clip_text = true
	root.add_child(name_lbl)

	# Barra HP (fondo gris)
	var hp_bg := ColorRect.new()
	hp_bg.color    = Color(0.18, 0.08, 0.08, 0.85)
	hp_bg.size     = Vector2(PARTY_BAR_W, PARTY_BAR_H)
	hp_bg.position = Vector2(4, 18)
	root.add_child(hp_bg)

	# Barra HP (relleno)
	var pct: float = float(m["hp"]) / float(max(m["max_hp"], 1))
	var hp_bar := ColorRect.new()
	hp_bar.name    = "HPBar_%d" % m["id"]
	hp_bar.color   = _hp_bar_color(pct)
	hp_bar.size    = Vector2(PARTY_BAR_W * pct, PARTY_BAR_H)
	hp_bar.position= Vector2(4, 18)
	root.add_child(hp_bar)

	# Texto HP
	var hp_lbl := Label.new()
	hp_lbl.name     = "HPLbl_%d" % m["id"]
	hp_lbl.text     = "%d/%d" % [m["hp"], m["max_hp"]]
	hp_lbl.position = Vector2(4, 18)
	hp_lbl.size     = Vector2(PARTY_BAR_W, PARTY_BAR_H)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 9)
	hp_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.90))
	hp_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	hp_lbl.add_theme_constant_override("shadow_offset_x", 1)
	hp_lbl.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(hp_lbl)

	_party_bars.append({"id": m["id"], "slot": root})
	return root

func _hp_bar_color(pct: float) -> Color:
	if pct > 0.60:
		return Color(0.20, 0.85, 0.30)   # verde
	elif pct > 0.30:
		return Color(0.95, 0.75, 0.10)   # amarillo
	else:
		return Color(0.90, 0.18, 0.18)   # rojo

func _on_party_changed() -> void:
	_rebuild_party_bars()

func _on_member_hp_changed(member_id: int) -> void:
	if not has_node("/root/PartyManager"):
		return
	var members: Array = PartyManager.members
	for m in members:
		if m["id"] != member_id:
			continue
		# Encontrar el slot y actualizar la barra
		for entry in _party_bars:
			if entry["id"] != member_id:
				continue
			var slot: Control = entry["slot"]
			if not is_instance_valid(slot):
				continue
			var hp_bar : ColorRect = slot.get_node_or_null("HPBar_%d" % member_id)
			var hp_lbl : Label     = slot.get_node_or_null("HPLbl_%d" % member_id)
			if hp_bar:
				var pct: float = float(m["hp"]) / float(max(m["max_hp"], 1))
				var tw := create_tween()
				tw.tween_property(hp_bar, "size:x", PARTY_BAR_W * pct, 0.15)
				hp_bar.color = _hp_bar_color(pct)
			if hp_lbl:
				hp_lbl.text = "%d/%d" % [m["hp"], m["max_hp"]]
		break

# ── PANEL DE GESTIÓN DE GRUPO ────────────────────────────────

func _toggle_party_manager() -> void:
	if _party_mgr_panel != null and is_instance_valid(_party_mgr_panel):
		_party_mgr_panel.queue_free()
		_party_mgr_panel = null
		return
	_open_party_manager()

func _open_party_manager() -> void:
	if _party_mgr_panel != null and is_instance_valid(_party_mgr_panel):
		_party_mgr_panel.queue_free()

	var root := PanelContainer.new()
	root.name = "PartyMgrPanel"
	root.custom_minimum_size = Vector2(300, 280)
	root.anchor_left   = 0.0; root.anchor_right  = 0.0
	root.anchor_top    = 0.5; root.anchor_bottom = 0.5
	root.offset_left   = 180.0
	root.offset_top    = -140.0
	root.offset_right  = 480.0
	root.offset_bottom = 140.0
	root.z_index       = 85

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.07, 0.06, 0.12, 0.96)
	style.border_color = Color(0.55, 0.45, 0.80, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	root.add_theme_stylebox_override("panel", style)
	panel_root.add_child(root)
	_party_mgr_panel = root

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	root.add_child(vbox)

	# ── Título ────────────────────────────────────────────────
	var title_bar := HBoxContainer.new()
	vbox.add_child(title_bar)

	var title_lbl := Label.new()
	title_lbl.text = "👥  GRUPO  (%d/%d)" % [PartyManager.member_count(), PartyManager.MAX_MEMBERS]
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(func():
		if is_instance_valid(root): root.queue_free()
		_party_mgr_panel = null
	)
	title_bar.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# ── Lista de miembros ─────────────────────────────────────
	var members_lbl := Label.new()
	members_lbl.text = "Miembros actuales:"
	members_lbl.add_theme_font_size_override("font_size", 11)
	members_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.80))
	vbox.add_child(members_lbl)

	for m in PartyManager.members:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)

		# Dot de color
		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_font_size_override("font_size", 12)
		dot.add_theme_color_override("font_color", m["color"])
		row.add_child(dot)

		# Nombre + HP (con etiqueta de líder)
		var info_lbl := Label.new()
		var role_tag: String = " 👑" if (m["id"] == PartyManager.members[0]["id"]) else ""
		info_lbl.text = "%s%s  (%d/%d HP)" % [m["name"], role_tag, m["hp"], m["max_hp"]]
		info_lbl.add_theme_font_size_override("font_size", 11)
		info_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 1.0))
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_lbl)

		# Botón expulsar (no para el líder)
		if m["id"] != PartyManager.members[0]["id"]:
			var kick_btn := Button.new()
			kick_btn.text = "✕"
			kick_btn.add_theme_font_size_override("font_size", 9)
			kick_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
			var mid: int = m["id"]
			kick_btn.pressed.connect(func():
				PartyManager.kick_member(mid)
				_open_party_manager()
			)
			row.add_child(kick_btn)

	vbox.add_child(HSeparator.new())

	# ── Invitar por nombre ────────────────────────────────────
	if PartyManager.member_count() < PartyManager.MAX_MEMBERS:
		var invite_lbl := Label.new()
		invite_lbl.text = "Invitar companion:"
		invite_lbl.add_theme_font_size_override("font_size", 11)
		invite_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.80))
		vbox.add_child(invite_lbl)

		var invite_row := HBoxContainer.new()
		invite_row.add_theme_constant_override("separation", 4)
		vbox.add_child(invite_row)

		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Nombre..."
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.add_theme_font_size_override("font_size", 11)
		invite_row.add_child(name_edit)

		var invite_btn := Button.new()
		invite_btn.text = "Invitar"
		invite_btn.add_theme_font_size_override("font_size", 11)
		invite_btn.pressed.connect(func():
			var cname: String = name_edit.text.strip_edges()
			if cname == "":
				return
			var ok := PartyManager.invite_by_name(cname)
			if ok:
				_show_screen_notification("✓ %s se unió al grupo" % cname, Color(0.4, 1.0, 0.6))
				_open_party_manager()
			else:
				_show_screen_notification("No se pudo invitar a %s" % cname, Color(1.0, 0.5, 0.3))
		)
		invite_row.add_child(invite_btn)
	else:
		var full_lbl := Label.new()
		full_lbl.text = "⚠ Grupo lleno (4/4)"
		full_lbl.add_theme_font_size_override("font_size", 11)
		full_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		vbox.add_child(full_lbl)

	vbox.add_child(HSeparator.new())

	# ── Botón disolver ────────────────────────────────────────
	if PartyManager.is_in_party():
		var disband_btn := Button.new()
		disband_btn.text = "💀 Disolver grupo"
		disband_btn.add_theme_font_size_override("font_size", 11)
		disband_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		disband_btn.pressed.connect(func():
			PartyManager.disband()
			_show_screen_notification("Grupo disuelto", Color(0.8, 0.5, 0.5))
			if is_instance_valid(root): root.queue_free()
			_party_mgr_panel = null
		)
		vbox.add_child(disband_btn)

	# Nota: radio de XP compartida
	var note_lbl := Label.new()
	note_lbl.text = "🔵 XP compartida en radio %d px" % int(PartyManager.SHARE_RADIUS)
	note_lbl.add_theme_font_size_override("font_size", 9)
	note_lbl.add_theme_color_override("font_color", Color(0.50, 0.65, 0.80))
	note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(note_lbl)

# ════════════════════════════════════════════════════════════
# TABLERO DE PROGRESIÓN — estilo Albion Online
# ════════════════════════════════════════════════════════════
# Panel que muestra de un vistazo:
#   • Nivel del personaje + barra XP
#   • Gathering skills (Mining, Woodcutting, Herbalism)
#     con barra de progreso, nivel actual, tier desbloqueado
#     y cuánta XP falta para el siguiente tier
#   • Crafting skills (Smithing, Tailoring, Alchemy)
#     igual que gathering
#   • Para cada skill: el ítem T-siguiente que podrías
#     craftear/recolectar y qué materiales necesitas
# ════════════════════════════════════════════════════════════

var _prog_board_panel: Control = null

func _toggle_progression_board() -> void:
	if _prog_board_panel != null and is_instance_valid(_prog_board_panel):
		_prog_board_panel.queue_free()
		_prog_board_panel = null
		return
	_open_progression_board()

func _open_progression_board() -> void:
	if _prog_board_panel != null and is_instance_valid(_prog_board_panel):
		_prog_board_panel.queue_free()

	# ── Contenedor principal ─────────────────────────────────
	var root := PanelContainer.new()
	root.name = "ProgressionBoard"
	# MOBILE FIX: adaptar al viewport
	var _pvp: Vector2 = get_viewport().get_visible_rect().size
	var _prw: float = minf(460.0, _pvp.x * 0.97)
	var _prh: float = minf(520.0, _pvp.y * 0.95)
	root.custom_minimum_size = Vector2(_prw, _prh)
	root.anchor_left   = 0.5; root.anchor_right  = 0.5
	root.anchor_top    = 0.5; root.anchor_bottom = 0.5
	root.offset_left   = -_prw * 0.5; root.offset_right  = _prw * 0.5
	root.offset_top    = -_prh * 0.5; root.offset_bottom = _prh * 0.5
	root.z_index = 88

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.05, 0.04, 0.10, 0.97)
	style.border_color = Color(0.75, 0.65, 0.20, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	root.add_theme_stylebox_override("panel", style)
	panel_root.add_child(root)
	_prog_board_panel = root

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ── Cabecera ──────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "📊  TABLERO DE PROGRESIÓN"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.30))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(func():
		if is_instance_valid(root): root.queue_free()
		_prog_board_panel = null
	)
	title_row.add_child(close_btn)

	vbox.add_child(_pb_separator())

	# ── Nivel del personaje ───────────────────────────────────
	_pb_add_char_level(vbox)
	vbox.add_child(_pb_separator())

	# ── Gathering skills ──────────────────────────────────────
	var g_title := _pb_section_title("⛏  RECOLECCIÓN", Color(0.40, 0.85, 0.55))
	vbox.add_child(g_title)

	var gathering_meta := {
		"mining":      {"icon": "⛏",  "label": "Minería",    "next_item": "Hierro T2",   "mats": "10× Hierro T1"},
		"woodcutting": {"icon": "🪓",  "label": "Tala",       "next_item": "Madera T2",   "mats": "10× Tronco T1"},
		"herbalism":   {"icon": "🌿",  "label": "Herboristería","next_item": "Hierba T2",  "mats": "8× Hierba T1"},
	}
	for skill_key in ["mining", "woodcutting", "herbalism"]:
		var meta = gathering_meta[skill_key]
		_pb_add_skill_row(vbox, skill_key, meta, true)

	vbox.add_child(_pb_separator())

	# ── Crafting skills ───────────────────────────────────────
	var c_title := _pb_section_title("🔨  CRAFTEO", Color(0.55, 0.65, 1.00))
	vbox.add_child(c_title)

	var crafting_meta := {
		"smithing":  {"icon": "🗡",  "label": "Herrería",   "next_item": "Espada T2",    "mats": "5× Hierro T1 + 2× Hueso"},
		"tailoring": {"icon": "🧵",  "label": "Sastrería",  "next_item": "Armadura T2",  "mats": "6× Madera T1 + 3× Hierba"},
		"alchemy":   {"icon": "⚗",  "label": "Alquimia",   "next_item": "Poción HP T2", "mats": "4× Hierba T1 + 2× Cristal"},
	}
	for skill_key in ["smithing", "tailoring", "alchemy"]:
		var meta = crafting_meta[skill_key]
		_pb_add_skill_row(vbox, skill_key, meta, false)

	vbox.add_child(_pb_separator())

	# ── Guía del loop de grindeo ──────────────────────────────
	_pb_add_loop_guide(vbox)


# ── Nivel del personaje ────────────────────────────────────
func _pb_add_char_level(vbox: Control) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	vbox.add_child(row)

	var lv_row := HBoxContainer.new()
	row.add_child(lv_row)

	var lv_icon := Label.new()
	lv_icon.text = "⚔"
	lv_icon.add_theme_font_size_override("font_size", 16)
	lv_row.add_child(lv_icon)

	var lv_lbl := Label.new()
	var lv: int = PlayerData.level
	var max_lv: int = PlayerData.MAX_LEVEL
	lv_lbl.text = "  Nivel %d / %d" % [lv, max_lv]
	lv_lbl.add_theme_font_size_override("font_size", 14)
	lv_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.40))
	lv_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv_row.add_child(lv_lbl)

	# Barra XP
	var xp_cur: int = PlayerData.xp
	var xp_need: int = PlayerData.get_xp_to_next_level() if lv < max_lv else 1
	var pct: float = float(xp_cur) / float(max(xp_need, 1))
	_pb_add_bar(row, pct, Color(0.30, 0.70, 1.0), "XP: %d / %d" % [xp_cur, xp_need])

	# Tier de combate desbloqueado
	var combat_tier: String = "T1 (Lv 1-14)"
	if lv >= 30: combat_tier = "T3 (Lv 30+)"
	elif lv >= 15: combat_tier = "T2 (Lv 15+)"
	var tier_lbl := Label.new()
	tier_lbl.text = "  Zona recomendada: %s" % combat_tier
	tier_lbl.add_theme_font_size_override("font_size", 10)
	tier_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.90))
	row.add_child(tier_lbl)


# ── Fila de skill (gathering o crafting) ──────────────────
func _pb_add_skill_row(vbox: Control, skill_key: String, meta: Dictionary, is_gathering: bool) -> void:
	var gs: Dictionary
	var max_lv: int
	var xp_table: Array

	if is_gathering:
		gs = PlayerData.gathering_skills.get(skill_key, {"level": 1, "xp": 0})
		max_lv   = PlayerData.GATHERING_MAX_LEVEL
		xp_table = PlayerData.GATHERING_XP_PER_LEVEL
	else:
		gs = PlayerData.crafting_skills.get(skill_key, {"level": 1, "xp": 0})
		max_lv   = PlayerData.CRAFTING_MAX_LEVEL
		xp_table = PlayerData.CRAFTING_XP_PER_LEVEL

	var lv: int  = gs.get("level", 1)
	var xp: int  = gs.get("xp", 0)
	var xp_need: int = xp_table[clamp(lv - 1, 0, xp_table.size() - 1)] if lv < max_lv else 1
	var pct: float = float(xp) / float(max(xp_need, 1)) if lv < max_lv else 1.0

	# Tier actual desbloqueado
	var tier_unlocked: int = 1
	if lv >= 10: tier_unlocked = 3
	elif lv >= 5: tier_unlocked = 2

	# Tier siguiente
	var tier_next: int = min(tier_unlocked + 1, 3)
	var lv_for_next: int = 5 if tier_next == 2 else 10

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	vbox.add_child(row)

	# Fila superior: icono + nombre + nivel + tier
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	row.add_child(top_row)

	var icon_lbl := Label.new()
	icon_lbl.text = meta["icon"]
	icon_lbl.add_theme_font_size_override("font_size", 14)
	top_row.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = meta["label"]
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 1.0))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_lbl)

	var lv_lbl := Label.new()
	lv_lbl.text = "Nv.%d/%d" % [lv, max_lv]
	lv_lbl.add_theme_font_size_override("font_size", 11)
	lv_lbl.add_theme_color_override("font_color", Color(0.70, 0.90, 0.70))
	top_row.add_child(lv_lbl)

	var tier_col := Color(0.70, 0.70, 0.70)
	if tier_unlocked == 2: tier_col = Color(0.40, 0.80, 1.0)
	elif tier_unlocked == 3: tier_col = Color(1.0, 0.80, 0.20)
	var tier_lbl := Label.new()
	tier_lbl.text = "T%d ✓" % tier_unlocked
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.add_theme_color_override("font_color", tier_col)
	top_row.add_child(tier_lbl)

	# Barra XP del skill
	var bar_color := Color(0.35, 0.75, 0.45) if is_gathering else Color(0.50, 0.60, 1.0)
	var xp_text: String = "XP: %d/%d" % [xp, xp_need] if lv < max_lv else "MAX"
	_pb_add_bar(row, pct, bar_color, xp_text)

	# Siguiente desbloqueo
	if lv < max_lv:
		var next_txt: String
		if tier_unlocked < 3:
			var xp_to_tier: int = 0
			for i in range(lv - 1, lv_for_next - 1):
				var idx = clamp(i, 0, xp_table.size() - 1)
				xp_to_tier += xp_table[idx]
			xp_to_tier -= xp
			next_txt = "→ T%d en Nv.%d  (~%d XP)  |  %s" % [tier_next, lv_for_next, max(0, xp_to_tier), meta["mats"]]
		else:
			next_txt = "→ Tier máximo desbloqueado ✓"
		var next_lbl := Label.new()
		next_lbl.text = next_txt
		next_lbl.add_theme_font_size_override("font_size", 9)
		next_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.80))
		row.add_child(next_lbl)


# ── Guía del loop de grindeo ──────────────────────────────
func _pb_add_loop_guide(vbox: Control) -> void:
	var title := _pb_section_title("🔄  LOOP DE GRINDEO", Color(0.90, 0.55, 0.35))
	vbox.add_child(title)

	var steps := [
		["1", "Farmea campamentos del anillo actual → materiales + XP"],
		["2", "Sube gathering skill → desbloquea nodos T2/T3"],
		["3", "Sube crafting skill → craftea equipo del siguiente tier"],
		["4", "Con equipo mejor → entra al anillo siguiente"],
		["5", "Limpia campamentos → cofre con materiales raros"],
		["6", "Ring 3 → boss de zona → drop épico/legendario"],
	]
	for step in steps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)

		var num := Label.new()
		num.text = "  %s." % step[0]
		num.add_theme_font_size_override("font_size", 11)
		num.add_theme_color_override("font_color", Color(0.90, 0.65, 0.25))
		num.custom_minimum_size = Vector2(22, 0)
		row.add_child(num)

		var desc := Label.new()
		desc.text = step[1]
		desc.add_theme_font_size_override("font_size", 10)
		desc.add_theme_color_override("font_color", Color(0.80, 0.78, 0.88))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)


# ── Helpers visuales ──────────────────────────────────────

func _pb_add_bar(parent: Control, pct: float, color: Color, text: String) -> void:
	var bar_root := Control.new()
	bar_root.custom_minimum_size = Vector2(0, 16)
	bar_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(bar_root)

	var bg := ColorRect.new()
	bg.color        = Color(0.12, 0.10, 0.18, 0.85)
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(bg)

	var fill := ColorRect.new()
	fill.color        = color
	fill.anchor_left  = 0.0; fill.anchor_right  = clamp(pct, 0.0, 1.0)
	fill.anchor_top   = 0.0; fill.anchor_bottom = 1.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(fill)

	var lbl := Label.new()
	lbl.text = text
	lbl.anchor_right = 1.0; lbl.anchor_bottom = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(lbl)

func _pb_separator() -> Control:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.40, 0.35, 0.60, 0.50))
	return sep

func _pb_section_title(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	return lbl

# ════════════════════════════════════════════════════════════
# MEJORAS MOBILE v20 — Teclado virtual, safe area, scroll táctil
# ════════════════════════════════════════════════════════════

func _setup_mobile_enhancements() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	# Escuchar cambios en el teclado virtual para ajustar el chat
	get_viewport().connect("size_changed", _on_viewport_size_changed)
	# Habilitar inercia táctil en todos los ScrollContainers del UI
	_enable_touch_scroll_recursive(self)

func _on_viewport_size_changed() -> void:
	# MOBILE FIX 7: cuando sube el teclado, subir el ChatPanel para no quedar tapado
	var chat_panel_node = get_node_or_null("MobileControls/ChatPanel")
	if not chat_panel_node:
		return
	var kb_height: int = 0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		kb_height = DisplayServer.virtual_keyboard_get_height()
	var vp_h: float = get_viewport().get_visible_rect().size.y
	if kb_height > 0:
		# Teclado visible: mover panel hacia arriba
		var kb_fraction: float = float(kb_height) / vp_h
		chat_panel_node.offset_bottom = -(kb_fraction * vp_h) - 4.0
		chat_panel_node.offset_top    = chat_panel_node.offset_bottom - 240.0
	else:
		# Teclado oculto: restaurar posición original
		chat_panel_node.offset_bottom = -4.0
		if not _chat_collapsed:
			chat_panel_node.offset_top = -244.0

func _enable_touch_scroll_recursive(node: Node) -> void:
	# MOBILE FIX 8: en Godot 4.6.3 no existe physics_scroll_enabled.
	# El scroll táctil se activa automáticamente cuando el proyecto corre
	# en Android/iOS. Esta función se mantiene por compatibilidad futura.
	for child in node.get_children():
		_enable_touch_scroll_recursive(child)
