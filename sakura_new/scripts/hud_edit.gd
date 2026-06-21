# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends CanvasLayer

# ============================================================
# HUD EDIT v2.0 — Editor Visual de HUD
#
# Funcionalidades:
#  • Handles arrastrables sobre el HUD real en tiempo real
#  • Panel lateral con sliders de escala y opacidad por elemento
#  • Sección global (escala/opacidad global, joystick)
#  • Snapping a cuadrícula (toggle)
#  • Preview de cada elemento seleccionado resaltado en dorado
#  • Undo de último movimiento (Z)
#  • Toast de confirmación al guardar
#  • Botones Guardar / Descartar / Reset usando UITheme
# ============================================================

var _game_ui: CanvasLayer = null

# Arrastre
var _dragging_key:     String  = ""
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_offset: Vector2 = Vector2.ZERO
var _undo_offset:      Vector2 = Vector2.ZERO
var _undo_key:         String  = ""

# Snapping
var _snap_enabled: bool   = false
var _snap_size:    float  = 8.0

# Nodos dinámicos
var _handles:       Dictionary = {}
var _selected_key:  String     = ""

# Panel lateral widgets
var _sel_lbl:        Label
var _sl_scale:       HSlider
var _sl_alpha:       HSlider
var _sl_gscale:      HSlider
var _sl_galpha:      HSlider
var _sl_deadzone:    HSlider
var _sl_sensitivity: HSlider
var _snap_chk:       CheckButton
var _snap_grid_sl:   HSlider

# Posiciones default (calculadas en _ready por viewport)
var _default_positions: Dictionary = {}

const HUD_META: Array = [
	{ "key": "stats",       "label": "❤ HP / Energía",    "color": Color(0.80, 0.18, 0.18) },
	{ "key": "xp_bar",      "label": "✨ Barra de XP",     "color": Color(0.90, 0.70, 0.10) },
	{ "key": "joystick",    "label": "🕹 Joystick",         "color": Color(0.18, 0.45, 0.90) },
	{ "key": "actions",     "label": "🎮 Botones Acción",   "color": Color(0.55, 0.15, 0.78) },
	{ "key": "zone_label",  "label": "🏷 Etiqueta de Zona", "color": Color(0.18, 0.65, 0.35) },
	{ "key": "minimap",     "label": "🗺 Minimapa",         "color": Color(0.18, 0.55, 0.80) },
	{ "key": "chat",        "label": "💬 Chat",             "color": Color(0.35, 0.60, 0.40) },
]


# ════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 99
	_find_game_ui()
	_calculate_defaults()
	_build_ui()
	_build_handles()
	_load_from_config()
	_select_element("stats")
	pass  # pop_in handled per-page
	print("[HudEdit] Editor iniciado")

func _find_game_ui() -> void:
	var nodes = get_tree().get_nodes_in_group("ui")
	if nodes.size() > 0:
		_game_ui = nodes[0] as CanvasLayer

func _calculate_defaults() -> void:
	var vp := get_viewport().get_visible_rect().size
	_default_positions = {
		"stats":      Vector2(100, 60),
		"xp_bar":     Vector2(vp.x * 0.5, vp.y - 9),
		"joystick":   Vector2(110, vp.y - 120),
		"actions":    Vector2(vp.x - 110, vp.y - 120),
		"zone_label": Vector2(vp.x * 0.5, 22),
		"minimap":    Vector2(vp.x - 90, 90),
		"chat":       Vector2(100, vp.y - 200),
	}


# ════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE UI
# ════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Semitransparente para ver el juego detrás
	var dim := ColorRect.new()
	dim.name = "DimBG"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# Contenedor de handles (toda la pantalla)
	var handles_root := Control.new()
	handles_root.name = "HandlesRoot"
	handles_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	handles_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(handles_root)
	set_meta("handles_root", handles_root)

	# Título flotante superior
	_build_top_bar()

	# Panel lateral derecho
	_build_side_panel()


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.add_theme_stylebox_override("panel", UITheme.titlebar_style())
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.size.y = 44
	add_child(bar)

	var m := MarginContainer.new()
	for k in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m.add_theme_constant_override(k, 6)
	bar.add_child(m)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	m.add_child(hbox)

	var title := Label.new()
	title.text = "🖊  EDITOR DE HUD"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UITheme.C_GOLD_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	var hint := Label.new()
	hint.text = "Arrastra los handles • Z = Deshacer"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	hbox.add_child(hint)

	var save_btn := Button.new()
	save_btn.text = "💾 Guardar"
	UITheme.style_button(save_btn, "save")
	save_btn.pressed.connect(_on_save)
	hbox.add_child(save_btn)

	var discard_btn := Button.new()
	discard_btn.text = "✗ Descartar"
	UITheme.style_button(discard_btn, "danger")
	discard_btn.pressed.connect(_on_discard)
	hbox.add_child(discard_btn)


func _build_side_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "SidePanel"
	panel.add_theme_stylebox_override("panel", UITheme.side_panel_style())
	panel.custom_minimum_size = Vector2(230, 0)
	# Anclar a la derecha
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left   = -230
	panel.offset_right  = 0
	panel.offset_top    = 44     # debajo de la barra superior
	panel.offset_bottom = 0
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)

	var m := MarginContainer.new()
	for k in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m.add_theme_constant_override(k, 10)
	scroll.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	m.add_child(vbox)

	# ── Elemento seleccionado ───────────────────────────────
	vbox.add_child(UITheme.section_header("ELEMENTO SELECCIONADO"))

	_sel_lbl = Label.new()
	_sel_lbl.text = "—"
	_sel_lbl.add_theme_color_override("font_color", UITheme.C_GOLD_BRIGHT)
	_sel_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_sel_lbl)

	_sl_scale = UITheme.slider_row(vbox, "📐 Escala Elemento", 30, 250, 5, "%", "purple")
	_sl_scale.value_changed.connect(func(v):
		if _selected_key == "": return
		HudConfig.set_element_scale(_selected_key, v / 100.0)
		UITheme.update_slider_label(_sl_scale, v)
		_apply_to_game_ui(_selected_key)
	)

	_sl_alpha = UITheme.slider_row(vbox, "🔆 Opacidad Elemento", 5, 100, 5, "%", "purple")
	_sl_alpha.value_changed.connect(func(v):
		if _selected_key == "": return
		HudConfig.set_element_alpha(_selected_key, v / 100.0)
		UITheme.update_slider_label(_sl_alpha, v)
		_apply_to_game_ui(_selected_key)
	)

	vbox.add_child(UITheme.separator())

	# ── Elementos (botones de selección) ────────────────────
	vbox.add_child(UITheme.section_header("ELEMENTOS"))
	for meta in HUD_META:
		var btn := Button.new()
		btn.text = meta["label"]
		var key: String = meta["key"]
		UITheme.style_button(btn, "ghost")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _select_element(key))
		btn.add_theme_font_size_override("font_size", 11)
		vbox.add_child(btn)

	vbox.add_child(UITheme.separator())

	# ── Global ─────────────────────────────────────────────
	vbox.add_child(UITheme.section_header("GLOBAL"))

	_sl_gscale = UITheme.slider_row(vbox, "📐 Escala Global", 50, 200, 5, "%", "gold")
	_sl_gscale.value_changed.connect(func(v):
		HudConfig.global_scale = v / 100.0
		UITheme.update_slider_label(_sl_gscale, v)
		_apply_all()
	)

	_sl_galpha = UITheme.slider_row(vbox, "🔆 Opacidad Global", 20, 100, 5, "%", "gold")
	_sl_galpha.value_changed.connect(func(v):
		HudConfig.global_alpha = v / 100.0
		UITheme.update_slider_label(_sl_galpha, v)
		_apply_all()
	)

	vbox.add_child(UITheme.separator())

	# ── Joystick ───────────────────────────────────────────
	vbox.add_child(UITheme.section_header("JOYSTICK"))

	_sl_deadzone = UITheme.slider_row(vbox, "🕹 Zona Muerta", 2, 40, 1, " px", "purple")
	_sl_deadzone.value_changed.connect(func(v):
		HudConfig.joy_deadzone = v
		UITheme.update_slider_label(_sl_deadzone, v)
	)

	_sl_sensitivity = UITheme.slider_row(vbox, "⚡ Sensibilidad", 30, 300, 10, "%", "purple")
	_sl_sensitivity.value_changed.connect(func(v):
		HudConfig.joy_sensitivity = v / 100.0
		UITheme.update_slider_label(_sl_sensitivity, v)
	)

	vbox.add_child(UITheme.separator())

	# ── Snapping ───────────────────────────────────────────
	vbox.add_child(UITheme.section_header("CUADRÍCULA"))

	var snap_row := HBoxContainer.new()
	var snap_lbl := Label.new()
	snap_lbl.text = "Snap a cuadrícula"
	snap_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snap_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
	snap_lbl.add_theme_font_size_override("font_size", 11)
	snap_row.add_child(snap_lbl)
	_snap_chk = CheckButton.new()
	_snap_chk.button_pressed = false
	_snap_chk.add_theme_color_override("font_color", UITheme.C_GOLD_BRIGHT)
	_snap_chk.toggled.connect(func(on): _snap_enabled = on)
	snap_row.add_child(_snap_chk)
	vbox.add_child(snap_row)

	_snap_grid_sl = UITheme.slider_row(vbox, "Tamaño de Celda", 4, 32, 4, " px", "gold")
	_snap_grid_sl.value = 8.0
	_snap_grid_sl.value_changed.connect(func(v):
		_snap_size = v
		UITheme.update_slider_label(_snap_grid_sl, v)
	)

	vbox.add_child(UITheme.separator())

	# ── Reset ──────────────────────────────────────────────
	var reset_btn := Button.new()
	reset_btn.text = "🔄  Restablecer Todo"
	UITheme.style_button(reset_btn, "warn")
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(_on_reset)
	vbox.add_child(reset_btn)


# ════════════════════════════════════════════════════════════
# HANDLES
# ════════════════════════════════════════════════════════════

func _build_handles() -> void:
	var root = get_meta("handles_root") as Control
	for meta in HUD_META:
		var key:   String = meta["key"]
		var label: String = meta["label"]
		var color: Color  = meta["color"]
		# Solo mostrar handle si la clave existe en HUD_KEYS
		if not HudConfig.HUD_KEYS.has(key):
			continue
		var h := _make_handle(key, label, color)
		root.add_child(h)
		_handles[key] = h
		# Posicionar
		var cfg := HudConfig.get_element(key)
		var base: Vector2 = _default_positions.get(key, Vector2(100, 100))
		h.position = base + Vector2(cfg["offset_x"], cfg["offset_y"])


func _make_handle(key: String, label: String, color: Color) -> Control:
	var root := Control.new()
	root.name = "Handle_" + key
	root.custom_minimum_size = Vector2(120, 38)
	root.pivot_offset = Vector2(60, 19)

	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UITheme.handle_style(color, false))
	bg.name = "BG"
	root.add_child(bg)

	var lbl := Label.new()
	lbl.text = label
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", UITheme.C_TEXT_WHITE)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(lbl)

	root.gui_input.connect(func(ev): _on_handle_input(ev, key))
	root.mouse_entered.connect(func(): _set_handle_style(key, true, false))
	root.mouse_exited.connect(func():
		if _dragging_key != key:
			_set_handle_style(key, false, key == _selected_key)
	)
	return root

func _set_handle_style(key: String, hovered: bool, selected: bool) -> void:
	var h = _handles.get(key)
	if not h: return
	for meta in HUD_META:
		if meta["key"] == key:
			var color: Color = meta["color"]
			var is_active := hovered or selected
			var bg := h.get_node_or_null("BG") as PanelContainer
			if bg:
				bg.add_theme_stylebox_override("panel", UITheme.handle_style(color, is_active))
			break


# ════════════════════════════════════════════════════════════
# INPUT — ARRASTRE
# ════════════════════════════════════════════════════════════

func _on_handle_input(ev: InputEvent, key: String) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_select_element(key)
				_dragging_key     = key
				_drag_start_mouse = get_viewport().get_mouse_position()
				var cfg := HudConfig.get_element(key)
				_drag_start_offset = Vector2(cfg["offset_x"], cfg["offset_y"])
				_undo_key    = key
				_undo_offset = _drag_start_offset
			else:
				if _dragging_key == key:
					_dragging_key = ""
					_set_handle_style(key, false, key == _selected_key)

func _input(event: InputEvent) -> void:
	# Undo con Z
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_Z and _undo_key != "":
			HudConfig.set_element_offset(_undo_key, _undo_offset.x, _undo_offset.y)
			_move_handle_to_config(_undo_key)
			_apply_to_game_ui(_undo_key)
			if _selected_key == _undo_key:
				_refresh_side_panel(_undo_key)
			_undo_key = ""
			return
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			_on_discard()
			return

	if _dragging_key == "" or not event is InputEventMouseMotion:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var delta := mouse_pos - _drag_start_mouse
	var new_offset := _drag_start_offset + delta

	if _snap_enabled:
		new_offset = (new_offset / _snap_size).round() * _snap_size

	HudConfig.set_element_offset(_dragging_key, new_offset.x, new_offset.y)

	var h = _handles.get(_dragging_key)
	if h:
		var base: Vector2 = _default_positions.get(_dragging_key, Vector2.ZERO)
		h.position = base + new_offset

	if _selected_key == _dragging_key:
		_refresh_side_panel(_dragging_key)

	_apply_to_game_ui(_dragging_key)


# ════════════════════════════════════════════════════════════
# SELECCIÓN
# ════════════════════════════════════════════════════════════

func _select_element(key: String) -> void:
	if _selected_key != "":
		_set_handle_style(_selected_key, false, false)
	_selected_key = key
	_set_handle_style(key, false, true)
	_refresh_side_panel(key)

func _refresh_side_panel(key: String) -> void:
	var cfg := HudConfig.get_element(key)
	for meta in HUD_META:
		if meta["key"] == key:
			_sel_lbl.text = meta["label"]
			break
	_sl_scale.set_value_no_signal(cfg["scale"] * 100.0)
	UITheme.update_slider_label(_sl_scale, cfg["scale"] * 100.0)
	_sl_alpha.set_value_no_signal(cfg["alpha"] * 100.0)
	UITheme.update_slider_label(_sl_alpha, cfg["alpha"] * 100.0)


# ════════════════════════════════════════════════════════════
# CARGAR CONFIG
# ════════════════════════════════════════════════════════════

func _load_from_config() -> void:
	_sl_gscale.set_value_no_signal(HudConfig.global_scale * 100.0)
	UITheme.update_slider_label(_sl_gscale, HudConfig.global_scale * 100.0)
	_sl_galpha.set_value_no_signal(HudConfig.global_alpha * 100.0)
	UITheme.update_slider_label(_sl_galpha, HudConfig.global_alpha * 100.0)
	_sl_deadzone.set_value_no_signal(HudConfig.joy_deadzone)
	UITheme.update_slider_label(_sl_deadzone, HudConfig.joy_deadzone)
	_sl_sensitivity.set_value_no_signal(HudConfig.joy_sensitivity * 100.0)
	UITheme.update_slider_label(_sl_sensitivity, HudConfig.joy_sensitivity * 100.0)
	for key in _handles:
		_move_handle_to_config(key)


# ════════════════════════════════════════════════════════════
# APLICAR AL GAME UI
# ════════════════════════════════════════════════════════════

func _apply_to_game_ui(key: String) -> void:
	if not _game_ui: return
	var node := _get_hud_node(key)
	if not node: return
	var cfg := HudConfig.get_element(key)
	var base: Vector2 = _default_positions.get(key, Vector2.ZERO)
	var new_pos := base + Vector2(cfg["offset_x"], cfg["offset_y"])
	var eff_scale: float = float(cfg["scale"]) * HudConfig.global_scale
	var eff_alpha: float = float(cfg["alpha"]) * HudConfig.global_alpha
	if node is Control:
		(node as Control).position = new_pos - (node as Control).size * 0.5
		(node as Control).scale = Vector2(eff_scale, eff_scale)
	if node is CanvasItem:
		(node as CanvasItem).modulate.a = eff_alpha

func _apply_all() -> void:
	for key in HudConfig.HUD_KEYS:
		_apply_to_game_ui(key)

func _move_handle_to_config(key: String) -> void:
	var h = _handles.get(key)
	if not h: return
	var cfg := HudConfig.get_element(key)
	var base: Vector2 = _default_positions.get(key, Vector2.ZERO)
	h.position = base + Vector2(cfg["offset_x"], cfg["offset_y"])

func _get_hud_node(key: String) -> Node:
	if not _game_ui: return null
	match key:
		"stats":      return _game_ui.get_node_or_null("HUDContainer/StatsBox")
		"xp_bar":     return _game_ui.get_node_or_null("HUDContainer/XPBarBG")
		"joystick":   return _game_ui.get_node_or_null("MobileControls/JoystickBase")
		"actions":    return _game_ui.get_node_or_null("MobileControls/ActionButtons")
		"zone_label": return _game_ui.get_node_or_null("HUDContainer/ZoneLabel")
		"minimap":    return _game_ui.get_node_or_null("HUDContainer/Minimap")
		"chat":       return _game_ui.get_node_or_null("HUDContainer/Chat")
	return null


# ════════════════════════════════════════════════════════════
# BOTONES
# ════════════════════════════════════════════════════════════

func _on_save() -> void:
	HudConfig.save_config()
	AudioManager.play_sfx("item_pickup")
	_show_toast("✓  Configuración guardada", UITheme.C_SUCCESS)
	await get_tree().create_timer(0.9).timeout
	_close_editor()

func _on_discard() -> void:
	HudConfig.load_config()
	_apply_all()
	_close_editor()

func _on_reset() -> void:
	HudConfig.reset_to_defaults()
	_load_from_config()
	for key in _handles:
		_move_handle_to_config(key)
	if _selected_key != "":
		_refresh_side_panel(_selected_key)
	_apply_all()
	_show_toast("↺  Valores restaurados", UITheme.C_GOLD_MID)

func _close_editor() -> void:
	var prev := GameManager.previous_scene if "previous_scene" in GameManager else ""
	var cur  := GameManager.current_scene  if "current_scene"  in GameManager else ""
	if prev != "" and prev != cur:
		GameManager.change_scene(prev)
	else:
		GameManager.change_scene("res://scenes/town.tscn")


# ════════════════════════════════════════════════════════════
# TOAST
# ════════════════════════════════════════════════════════════

func _show_toast(msg: String, color: Color = UITheme.C_SUCCESS) -> void:
	var vp := get_viewport().get_visible_rect().size
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.flat_box(
		Color(0.04, 0.08, 0.04, 0.92), UITheme.C_BORDER_GOLD, 2, 10, true
	))
	card.position = Vector2(vp.x * 0.5 - 110, vp.y * 0.5 - 24)
	add_child(card)

	var m := MarginContainer.new()
	for k in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m.add_theme_constant_override(k, 10)
	card.add_child(m)

	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	m.add_child(lbl)

	UITheme.pop_in(card)
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.tween_callback(card.queue_free)
