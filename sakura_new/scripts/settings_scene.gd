# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends CanvasLayer

# ============================================================
# SETTINGS SCENE v2.0 — Panel de Ajustes Completo
#
# Pestañas:
#   🎮 HUD & CONTROLES — escala, opacidad, joystick, abrir editor
#   🔊 AUDIO           — maestro, música, SFX, voz ambiental
#   🖥 GRÁFICOS        — FPS, VSync, pantalla completa, brillo, partículas
#   ♿ ACCESIBILIDAD   — tamaño de fuente, contraste, shake de cámara
#   ℹ ACERCA DE       — créditos, versión
#
# Se abre como overlay sobre la escena activa (layer = 100).
# Se cierra con ESC o el botón ✕.
# ============================================================

# ── Estado ───────────────────────────────────────────────────
var _active_tab: int = 0
var _tab_btns: Array  = []
var _tab_pages: Array = []
var _reset_confirm: Control = null

# ── Sliders (referencias para load/save) ─────────────────────
var _sl: Dictionary = {}   # key → HSlider

# ── Opciones de gráficos ──────────────────────────────────────
var _fps_opts:  Array = [30, 60, 90, 120, 144, 0]   # 0 = sin límite
var _fps_idx:   int   = 1
var _res_opts:  Array = [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1440)]
var _res_idx:   int   = 0

const VERSION := "v2.5.0"

# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 100
	_build_ui()
	_load_values()
	if _tab_pages.size() > 0: UITheme.pop_in(_tab_pages[0] as Control)
	print("[Settings] Abierto")


# ════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE UI
# ════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Fondo translúcido bloqueador de input
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Panel externo (piedra rúnica)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", UITheme.main_panel_style())
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)

	# Barra de título
	outer.add_child(_build_titlebar())

	# Pestañas
	outer.add_child(_build_tab_bar())

	# Páginas de contenido
	var pages_host := Control.new()
	pages_host.custom_minimum_size = Vector2(0, 400)
	pages_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(pages_host)

	_tab_pages.append(_build_page_hud(pages_host))
	_tab_pages.append(_build_page_audio(pages_host))
	_tab_pages.append(_build_page_graphics(pages_host))
	_tab_pages.append(_build_page_accessibility(pages_host))
	_tab_pages.append(_build_page_about(pages_host))

	for p in _tab_pages:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Footer ornamental
	var foot_wrap := MarginContainer.new()
	foot_wrap.add_theme_constant_override("margin_left", 0)
	foot_wrap.add_theme_constant_override("margin_right", 0)
	foot_wrap.add_theme_constant_override("margin_top", 4)
	foot_wrap.add_theme_constant_override("margin_bottom", 8)
	outer.add_child(foot_wrap)
	var ornament := UITheme.ornament()
	foot_wrap.add_child(ornament)

	_switch_tab(0)


func _build_titlebar() -> Control:
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", UITheme.titlebar_style())

	var m := MarginContainer.new()
	for k in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m.add_theme_constant_override(k, 10)
	bg.add_child(m)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	m.add_child(hbox)

	var icon := Label.new()
	icon.text = "⚙"
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", UITheme.C_GOLD_BRIGHT)
	hbox.add_child(icon)

	var title := Label.new()
	title.text = "AJUSTES"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UITheme.C_GOLD_BRIGHT)
	hbox.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕  CERRAR"
	UITheme.style_button(close_btn, "danger")
	close_btn.pressed.connect(_close)
	hbox.add_child(close_btn)

	return bg


func _build_tab_bar() -> Control:
	var wrap := PanelContainer.new()
	var st := UITheme.flat_box(UITheme.C_BG_INNER, UITheme.C_BORDER_DIM, 0, 0)
	st.border_width_bottom = 1
	wrap.add_theme_stylebox_override("panel", st)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	wrap.add_child(hbox)

	var m := MarginContainer.new()
	for k in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m.add_theme_constant_override(k, 4)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(m)
	# replace hbox inside m
	hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 3)
	m.add_child(hbox)

	var tabs = [
		["🎮 HUD", 0],
		["🔊 Audio", 1],
		["🖥 Gráficos", 2],
		["♿ Accesib.", 3],
		["ℹ Acerca", 4],
	]
	for t in tabs:
		var btn := Button.new()
		btn.text = t[0]
		var idx: int = t[1]
		btn.pressed.connect(func(): _switch_tab(idx))
		UITheme.style_button(btn, "tab")
		btn.add_theme_font_size_override("font_size", 11)
		_tab_btns.append(btn)
		hbox.add_child(btn)

	return wrap


# ── Páginas ──────────────────────────────────────────────────

func _build_page_hud(host: Control) -> ScrollContainer:
	var scroll := _make_scroll_page(host)
	var c := _scroll_content(scroll)

	c.add_child(UITheme.section_header("EDITOR DE HUD"))

	var hud_btn := Button.new()
	hud_btn.text = "🖊  Abrir Editor Visual de HUD"
	UITheme.style_button(hud_btn, "epic")
	hud_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_btn.pressed.connect(_on_open_hud_edit)
	c.add_child(hud_btn)

	c.add_child(UITheme.separator())
	c.add_child(UITheme.section_header("ESCALA  &  OPACIDAD GLOBALES"))

	_sl["global_scale"] = UITheme.slider_row(c, "📐 Escala Global del HUD",   50, 200, 5,  "%",   "gold")
	_sl["global_scale"].value_changed.connect(func(v): _on_hud_scale(v))

	_sl["global_alpha"] = UITheme.slider_row(c, "🔆 Transparencia Global",    20, 100, 5,  "%",   "gold")
	_sl["global_alpha"].value_changed.connect(func(v): _on_hud_alpha(v))

	c.add_child(UITheme.separator())
	c.add_child(UITheme.section_header("CONTROLES  &  JOYSTICK"))

	_sl["deadzone"]     = UITheme.slider_row(c, "🕹 Zona Muerta Joystick",    2,  40,  1,  " px", "purple")
	_sl["deadzone"].value_changed.connect(func(v): _on_deadzone(v))

	_sl["sensitivity"]  = UITheme.slider_row(c, "⚡ Sensibilidad Joystick",  30, 300, 10, "%",   "purple")
	_sl["sensitivity"].value_changed.connect(func(v): _on_sensitivity(v))

	c.add_child(UITheme.separator())

	var reset_btn := Button.new()
	reset_btn.text = "🔄  Restablecer HUD por Defecto"
	UITheme.style_button(reset_btn, "warn")
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(_on_reset_hud_pressed)
	c.add_child(reset_btn)

	_reset_confirm = _build_confirm_box(
		"¿Restaurar el HUD a los valores de fábrica?",
		_on_reset_hud_confirm
	)
	_reset_confirm.visible = false
	c.add_child(_reset_confirm)

	return scroll


func _build_page_audio(host: Control) -> ScrollContainer:
	var scroll := _make_scroll_page(host)
	var c := _scroll_content(scroll)

	c.add_child(UITheme.section_header("VOLUMEN"))

	_sl["master_vol"] = UITheme.slider_row(c, "🔊 Maestro",   0, 100, 2, "%", "gold")
	_sl["master_vol"].value_changed.connect(func(v): AudioManager.set_master_volume(v / 100.0); UITheme.update_slider_label(_sl["master_vol"], v))

	_sl["music_vol"]  = UITheme.slider_row(c, "🎵 Música",    0, 100, 2, "%", "gold")
	_sl["music_vol"].value_changed.connect(func(v): AudioManager.set_music_volume(v / 100.0); UITheme.update_slider_label(_sl["music_vol"], v))

	_sl["sfx_vol"]    = UITheme.slider_row(c, "⚔ Efectos",   0, 100, 2, "%", "gold")
	_sl["sfx_vol"].value_changed.connect(func(v): AudioManager.set_sfx_volume(v / 100.0); UITheme.update_slider_label(_sl["sfx_vol"], v))

	c.add_child(UITheme.separator())
	c.add_child(UITheme.section_header("OPCIONES"))

	# Toggle música de combate
	var combat_row := HBoxContainer.new()
	var combat_lbl := Label.new()
	combat_lbl.text = "🎼 Música de combate"
	combat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
	combat_lbl.add_theme_font_size_override("font_size", 11)
	combat_row.add_child(combat_lbl)
	var combat_chk := CheckButton.new()
	combat_chk.button_pressed = true
	combat_chk.toggled.connect(func(on): AudioManager.enable_combat_music(on) if AudioManager.has_method("enable_combat_music") else null)
	_style_check(combat_chk)
	combat_row.add_child(combat_chk)
	c.add_child(combat_row)

	# Toggle sonido de pasos
	var steps_row := HBoxContainer.new()
	var steps_lbl := Label.new()
	steps_lbl.text = "👣 Sonido de pasos"
	steps_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steps_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
	steps_lbl.add_theme_font_size_override("font_size", 11)
	steps_row.add_child(steps_lbl)
	var steps_chk := CheckButton.new()
	steps_chk.button_pressed = true
	_style_check(steps_chk)
	steps_row.add_child(steps_chk)
	c.add_child(steps_row)

	# Toggle sonidos de UI
	var ui_row := HBoxContainer.new()
	var ui_lbl := Label.new()
	ui_lbl.text = "🖱 Sonidos de interfaz"
	ui_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
	ui_lbl.add_theme_font_size_override("font_size", 11)
	ui_row.add_child(ui_lbl)
	var ui_chk := CheckButton.new()
	ui_chk.button_pressed = true
	_style_check(ui_chk)
	ui_row.add_child(ui_chk)
	c.add_child(ui_row)

	# Botón test SFX
	c.add_child(UITheme.separator())
	var test_btn := Button.new()
	test_btn.text = "▶  Probar SFX"
	UITheme.style_button(test_btn, "ghost")
	test_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_btn.pressed.connect(func(): AudioManager.play_sfx("menu_open"))
	c.add_child(test_btn)

	return scroll


func _build_page_graphics(host: Control) -> ScrollContainer:
	var scroll := _make_scroll_page(host)
	var c := _scroll_content(scroll)

	c.add_child(UITheme.section_header("PANTALLA"))

	# Pantalla completa
	var fs_row := HBoxContainer.new()
	var fs_lbl := Label.new()
	fs_lbl.text = "⛶ Pantalla Completa"
	fs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
	fs_lbl.add_theme_font_size_override("font_size", 11)
	fs_row.add_child(fs_lbl)
	var fs_chk := CheckButton.new()
	fs_chk.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_chk.toggled.connect(func(on):
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if on
			else DisplayServer.WINDOW_MODE_WINDOWED
		)
	)
	_style_check(fs_chk)
	fs_row.add_child(fs_chk)
	c.add_child(fs_row)

	# VSync
	var vsync_row := HBoxContainer.new()
	var vsync_lbl := Label.new()
	vsync_lbl.text = "⟳ V-Sync"
	vsync_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vsync_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
	vsync_lbl.add_theme_font_size_override("font_size", 11)
	vsync_row.add_child(vsync_lbl)
	var vsync_chk := CheckButton.new()
	vsync_chk.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vsync_chk.toggled.connect(func(on):
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if on
			else DisplayServer.VSYNC_DISABLED
		)
	)
	_style_check(vsync_chk)
	vsync_row.add_child(vsync_chk)
	c.add_child(vsync_row)

	# FPS máximos
	c.add_child(UITheme.separator())
	c.add_child(UITheme.section_header("RENDIMIENTO"))

	var fps_row := HBoxContainer.new()
	fps_row.add_theme_constant_override("separation", 8)
	var fps_lbl := Label.new()
	fps_lbl.text = "🚀 FPS máximos"
	fps_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
	fps_lbl.add_theme_font_size_override("font_size", 11)
	fps_row.add_child(fps_lbl)

	var fps_prev := Button.new()
	fps_prev.text = "◀"
	UITheme.style_button(fps_prev, "ghost")
	fps_prev.custom_minimum_size = Vector2(30, 0)
	fps_row.add_child(fps_prev)

	var fps_val_lbl := Label.new()
	fps_val_lbl.custom_minimum_size = Vector2(60, 0)
	fps_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_val_lbl.add_theme_color_override("font_color", UITheme.C_GOLD_BRIGHT)
	fps_val_lbl.add_theme_font_size_override("font_size", 11)
	fps_row.add_child(fps_val_lbl)

	var fps_next := Button.new()
	fps_next.text = "▶"
	UITheme.style_button(fps_next, "ghost")
	fps_next.custom_minimum_size = Vector2(30, 0)
	fps_row.add_child(fps_next)
	c.add_child(fps_row)

	var _fps_update = func():
		var fps = _fps_opts[_fps_idx]
		fps_val_lbl.text = "Sin límite" if fps == 0 else "%d fps" % fps
		Engine.max_fps = fps

	fps_prev.pressed.connect(func():
		_fps_idx = (_fps_idx - 1 + _fps_opts.size()) % _fps_opts.size()
		_fps_update.call()
	)
	fps_next.pressed.connect(func():
		_fps_idx = (_fps_idx + 1) % _fps_opts.size()
		_fps_update.call()
	)
	_fps_update.call()

	# Calidad de partículas
	_sl["particles"] = UITheme.slider_row(c, "✨ Calidad de Partículas",  0, 100, 25, "%", "gold")
	_sl["particles"].value_changed.connect(func(v):
		UITheme.update_slider_label(_sl["particles"], v)
		# 0=off 25=baja 50=media 75=alta 100=ultra
		if has_node("/root/GameManager") and GameManager.has_method("set_particle_quality"):
			GameManager.set_particle_quality(v / 100.0)
	)

	# Brillo
	c.add_child(UITheme.separator())
	c.add_child(UITheme.section_header("IMAGEN"))

	_sl["brightness"] = UITheme.slider_row(c, "☀ Brillo",    50, 150, 5, "%", "gold")
	_sl["brightness"].value_changed.connect(func(v):
		UITheme.update_slider_label(_sl["brightness"], v)
		RenderingServer.set_default_clear_color(Color(0, 0, 0))
		get_tree().root.set_canvas_cull_mask(0xFFFFFFFF)   # noop, just hook
	)

	_sl["gamma"] = UITheme.slider_row(c, "◑ Gamma / Contraste",  50, 150, 5, "%", "gold")
	_sl["gamma"].value_changed.connect(func(v):
		UITheme.update_slider_label(_sl["gamma"], v)
	)

	return scroll


func _build_page_accessibility(host: Control) -> ScrollContainer:
	var scroll := _make_scroll_page(host)
	var c := _scroll_content(scroll)

	c.add_child(UITheme.section_header("TEXTO  &  LEGIBILIDAD"))

	_sl["ui_font_size"] = UITheme.slider_row(c, "🔤 Tamaño de Fuente UI",  80, 140, 5, "%", "purple")
	_sl["ui_font_size"].value_changed.connect(func(v):
		UITheme.update_slider_label(_sl["ui_font_size"], v)
	)

	_sl["name_font_size"] = UITheme.slider_row(c, "🏷 Nombres sobre personajes", 8, 18, 1, "px", "purple")
	_sl["name_font_size"].value_changed.connect(func(v):
		UITheme.update_slider_label(_sl["name_font_size"], v, 0)
	)

	c.add_child(UITheme.separator())
	c.add_child(UITheme.section_header("VISUAL  &  ACCESIBILIDAD"))

	# Contraste alto
	var hc_row := HBoxContainer.new()
	var hc_lbl := Label.new()
	hc_lbl.text = "◐ Alto Contraste UI"
	hc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hc_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
	hc_lbl.add_theme_font_size_override("font_size", 11)
	hc_row.add_child(hc_lbl)
	var hc_chk := CheckButton.new()
	_style_check(hc_chk)
	hc_row.add_child(hc_chk)
	c.add_child(hc_row)

	# Reducir movimiento
	var rm_row := HBoxContainer.new()
	var rm_lbl := Label.new()
	rm_lbl.text = "🚫 Reducir Animaciones"
	rm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rm_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
	rm_lbl.add_theme_font_size_override("font_size", 11)
	rm_row.add_child(rm_lbl)
	var rm_chk := CheckButton.new()
	_style_check(rm_chk)
	rm_row.add_child(rm_chk)
	c.add_child(rm_row)

	# Camera shake
	c.add_child(UITheme.separator())
	_sl["cam_shake"] = UITheme.slider_row(c, "📷 Intensidad Shake de Cámara", 0, 100, 10, "%", "purple")
	_sl["cam_shake"].value_changed.connect(func(v):
		UITheme.update_slider_label(_sl["cam_shake"], v)
		if has_node("/root/GameManager") and GameManager.has_method("set_cam_shake"):
			GameManager.set_cam_shake_intensity(v / 100.0)
	)

	# Indicadores de daño
	var dd_row := HBoxContainer.new()
	var dd_lbl := Label.new()
	dd_lbl.text = "💥 Números de Daño Flotantes"
	dd_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dd_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
	dd_lbl.add_theme_font_size_override("font_size", 11)
	dd_row.add_child(dd_lbl)
	var dd_chk := CheckButton.new()
	dd_chk.button_pressed = true
	_style_check(dd_chk)
	dd_row.add_child(dd_chk)
	c.add_child(dd_row)

	# Barra de HP de enemigos
	var ehp_row := HBoxContainer.new()
	var ehp_lbl := Label.new()
	ehp_lbl.text = "❤ Barra HP en Enemigos"
	ehp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ehp_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
	ehp_lbl.add_theme_font_size_override("font_size", 11)
	ehp_row.add_child(ehp_lbl)
	var ehp_chk := CheckButton.new()
	ehp_chk.button_pressed = true
	_style_check(ehp_chk)
	ehp_row.add_child(ehp_chk)
	c.add_child(ehp_row)

	return scroll


func _build_page_about(host: Control) -> ScrollContainer:
	var scroll := _make_scroll_page(host)
	var c := _scroll_content(scroll)

	c.add_child(UITheme.ornament(14, UITheme.C_SAKURA))

	var title := Label.new()
	title.text = "Sakura Chronicles"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UITheme.C_GOLD_BRIGHT)
	c.add_child(title)

	var ver := Label.new()
	ver.text = VERSION
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	c.add_child(ver)

	c.add_child(UITheme.separator())
	c.add_child(UITheme.section_header("CRÉDITOS", UITheme.C_SAKURA))

	var credits = [
		["🎮 Diseño & Dirección", "Drake Andonov"],
		["🎨 Arte & UI",          "Ruth Gonzaga Quimi"],
		["⚙ Programación",       "Drake Andonov"],
		["🔊 Audio",              "Efectos libres de derechos"],
		["🌸 Motor",              "Godot 4.x"],
	]
	for pair in credits:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var k := Label.new()
		k.text = pair[0]
		k.custom_minimum_size = Vector2(175, 0)
		k.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
		k.add_theme_font_size_override("font_size", 11)
		row.add_child(k)
		var v := Label.new()
		v.text = pair[1]
		v.add_theme_color_override("font_color", UITheme.C_TEXT_WHITE)
		v.add_theme_font_size_override("font_size", 11)
		row.add_child(v)
		c.add_child(row)

	c.add_child(UITheme.separator())

	var copy := Label.new()
	copy.text = "© 2024 Drake Andonov & Ruth Gonzaga Quimi\nTodos los derechos reservados."
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_theme_font_size_override("font_size", 10)
	copy.add_theme_color_override("font_color", UITheme.C_TEXT_MUTED)
	c.add_child(copy)

	c.add_child(UITheme.ornament(10, UITheme.C_GOLD_DIM))

	return scroll


# ════════════════════════════════════════════════════════════
# HELPERS DE CONSTRUCCIÓN
# ════════════════════════════════════════════════════════════

func _make_scroll_page(host: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(scroll)
	return scroll

func _scroll_content(scroll: ScrollContainer) -> VBoxContainer:
	var m := MarginContainer.new()
	for k in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m.add_theme_constant_override(k, 14)
	scroll.add_child(m)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(vbox)
	return vbox

func _build_confirm_box(question: String, on_yes: Callable) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.confirm_box_style())
	var m := MarginContainer.new()
	for k in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m.add_theme_constant_override(k, 14)
	box.add_child(m)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	m.add_child(vbox)

	var q := Label.new()
	q.text = question
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.add_theme_color_override("font_color", Color(1, 0.68, 0.68))
	q.add_theme_font_size_override("font_size", 13)
	vbox.add_child(q)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var yes := Button.new()
	yes.text = "✓  SÍ, RESTABLECER"
	UITheme.style_button(yes, "danger")
	yes.pressed.connect(on_yes)
	row.add_child(yes)

	var no := Button.new()
	no.text = "✗  Cancelar"
	UITheme.style_button(no, "ghost")
	no.pressed.connect(func(): box.visible = false)
	row.add_child(no)

	return box

func _style_check(chk: CheckButton) -> void:
	chk.add_theme_color_override("font_color", UITheme.C_GOLD_BRIGHT)
	chk.add_theme_color_override("font_hover_color", UITheme.C_TEXT_WHITE)


# ════════════════════════════════════════════════════════════
# PESTAÑAS
# ════════════════════════════════════════════════════════════

func _switch_tab(idx: int) -> void:
	_active_tab = idx
	for i in _tab_pages.size():
		_tab_pages[i].visible = (i == idx)
	for i in _tab_btns.size():
		UITheme.style_button(_tab_btns[i], "tab_active" if i == idx else "tab")
		_tab_btns[i].add_theme_font_size_override("font_size", 11)


# ════════════════════════════════════════════════════════════
# CARGAR Y GUARDAR VALORES
# ════════════════════════════════════════════════════════════

func _load_values() -> void:
	# HUD
	_set_sl("global_scale", roundf(HudConfig.global_scale    * 100.0))
	_set_sl("global_alpha", roundf(HudConfig.global_alpha    * 100.0))
	_set_sl("deadzone",     HudConfig.joy_deadzone)
	_set_sl("sensitivity",  roundf(HudConfig.joy_sensitivity * 100.0))
	# Audio
	_set_sl("master_vol",   roundf(AudioManager._master_volume * 100.0))
	_set_sl("music_vol",    roundf(AudioManager._music_volume  * 100.0))
	_set_sl("sfx_vol",      roundf(AudioManager._sfx_volume    * 100.0))
	# Gráficos
	_set_sl("particles",    100.0)
	_set_sl("brightness",   100.0)
	_set_sl("gamma",        100.0)
	# Accesibilidad
	_set_sl("ui_font_size",    100.0)
	_set_sl("name_font_size",  12.0)
	_set_sl("cam_shake",       100.0)
	# FPS
	var cur_fps = Engine.max_fps
	_fps_idx = 1  # default 60
	for i in _fps_opts.size():
		if _fps_opts[i] == cur_fps:
			_fps_idx = i
			break

func _set_sl(key: String, value: float) -> void:
	if not _sl.has(key): return
	_sl[key].set_value_no_signal(value)
	UITheme.update_slider_label(_sl[key], value, 0)


# ════════════════════════════════════════════════════════════
# CALLBACKS
# ════════════════════════════════════════════════════════════

func _on_hud_scale(v: float) -> void:
	HudConfig.global_scale = v / 100.0
	HudConfig.config_changed.emit()
	HudConfig.save_config()
	UITheme.update_slider_label(_sl["global_scale"], v)

func _on_hud_alpha(v: float) -> void:
	HudConfig.global_alpha = v / 100.0
	HudConfig.config_changed.emit()
	HudConfig.save_config()
	UITheme.update_slider_label(_sl["global_alpha"], v)

func _on_deadzone(v: float) -> void:
	HudConfig.joy_deadzone = v
	HudConfig.save_config()
	UITheme.update_slider_label(_sl["deadzone"], v)

func _on_sensitivity(v: float) -> void:
	HudConfig.joy_sensitivity = v / 100.0
	HudConfig.save_config()
	UITheme.update_slider_label(_sl["sensitivity"], v)

func _on_open_hud_edit() -> void:
	AudioManager.play_sfx("menu_open")
	queue_free()
	get_tree().change_scene_to_file("res://scenes/hud_edit.tscn")

func _on_reset_hud_pressed() -> void:
	AudioManager.play_sfx("menu_open")
	if _reset_confirm:
		_reset_confirm.visible = true

func _on_reset_hud_confirm() -> void:
	HudConfig.reset_to_defaults()
	if _reset_confirm: _reset_confirm.visible = false
	_load_values()
	AudioManager.play_sfx("item_pickup")

func _close() -> void:
	AudioManager.play_sfx("menu_close")
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
