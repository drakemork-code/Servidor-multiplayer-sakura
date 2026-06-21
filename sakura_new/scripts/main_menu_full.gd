# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# ==============================================================

# Suprimir warnings de layout_mode (valores int válidos en Godot 4.6)
@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
extends Control

# ═══════════════════════════════════════════════════════════════════
#   SAKURA CHRONICLES — MAIN MENU v2.5
#   Godot 4.6 — Pixel Art MMORPG
#   v2.5: Refactorización modular. Edita en scripts/menu/*.gd
#
#   MÓDULOS (scripts/menu/):
#     menu_constants.gd  → colores, razas, apariencia
#     menu_ui_theme.gd   → fondo, frame WoW, botones, paneles
#     menu_particles.gd  → partículas y pétalos sakura
#     menu_auth.gd       → TOS, login, registro, verificación
#     menu_server.gd     → guardar/cargar personaje en servidor
#     menu_slots.gd      → selección de personaje + slots
#     menu_create.gd     → creación de personaje
# ═══════════════════════════════════════════════════════════════════


# ═══════════════════════════════════════════════════════════════════
#   SAKURA CHRONICLES — MAIN MENU v2.4
#   Diseño épico estilo World of Warcraft
#   Godot 4.6 — Pixel Art MMORPG
#   v2.1: Auth + datos via Railway + Firestore
# ═══════════════════════════════════════════════════════════════════

# ── Pantallas ──────────────────────────────────────────────────────
@onready var screen_login   : Control = $ScreenLogin
@onready var screen_select  : Control = $ScreenSelect
@onready var screen_create  : Control = $ScreenCreate

# ── Login (asignados en _setup_login_screen) ───────────────────────
var login_user_field : LineEdit = null
var login_pass_field : LineEdit = null
var login_error_lbl  : Label   = null

# ── Selección (asignados en _setup_select_screen) ──────────────────
var slots_container   : Control         = null
var select_enter_btn  : Button        = null
var select_delete_btn : Button        = null
var select_error_lbl  : Label         = null
var account_gold_lbl  : Label         = null

# ── Crear personaje (asignados en _setup_create_screen) ────────────
var char_name_field   : LineEdit  = null
var char_error_lbl    : Label     = null
var gender_male_btn   : Button    = null
var gender_female_btn : Button    = null
var preview_rect      : ColorRect = null

# ═══════════════════════════════════════════════════════════════════
# BACKEND
# ═══════════════════════════════════════════════════════════════════
const AUTH_BACKEND : String = "https://sakurachronicles.up.railway.app"

# Credenciales del jugador logueado (se guardan en memoria durante la sesión)
var _logged_gmail    : String = ""
var _logged_password : String = ""   # contraseña en texto plano (solo en memoria)
var _logged_username : String = ""

# ═══════════════════════════════════════════════════════════════════
# PALETA DE COLORES — WoW EPIC FANTASY
# ═══════════════════════════════════════════════════════════════════
const C_BG_VOID       := Color(0.025, 0.032, 0.075, 1.0)
const C_BG_DEEP       := Color(0.045, 0.055, 0.130, 1.0)
const C_BG_MID        := Color(0.065, 0.080, 0.175, 1.0)
const C_BG_PANEL      := Color(0.055, 0.065, 0.145, 0.97)
const C_BG_PANEL_DARK := Color(0.030, 0.038, 0.090, 0.98)
const C_BG_INNER      := Color(0.028, 0.035, 0.085, 1.0)

const C_GOLD_BRIGHT   := Color(1.000, 0.920, 0.380, 1.0)
const C_GOLD_MID      := Color(0.870, 0.740, 0.240, 1.0)
const C_GOLD_DIM      := Color(0.580, 0.470, 0.140, 1.0)
const C_GOLD_DARK     := Color(0.350, 0.270, 0.075, 1.0)
const C_BORDER_GOLD   := Color(0.750, 0.600, 0.180, 1.0)
const C_BORDER_DIM    := Color(0.280, 0.220, 0.075, 1.0)
const C_BORDER_INNER  := Color(0.120, 0.095, 0.035, 1.0)

const C_EPIC_PURPLE   := Color(0.620, 0.280, 0.980, 1.0)
const C_RARE_BLUE     := Color(0.200, 0.600, 1.000, 1.0)
const C_UNCOMMON      := Color(0.240, 0.820, 0.380, 1.0)
const C_TEAL          := Color(0.160, 0.900, 0.820, 1.0)
const C_PINK          := Color(0.980, 0.380, 0.760, 1.0)
const C_FIRE          := Color(1.000, 0.480, 0.120, 1.0)
const C_RED_DANGER    := Color(1.000, 0.280, 0.280, 1.0)

const C_TEXT_WHITE    := Color(0.970, 0.960, 1.000, 1.0)
const C_TEXT_LIGHT    := Color(0.850, 0.840, 0.920, 1.0)
const C_TEXT_DIM      := Color(0.520, 0.510, 0.660, 1.0)
const C_TEXT_MUTED    := Color(0.340, 0.330, 0.460, 1.0)

const C_BTN_NORMAL    := Color(0.075, 0.092, 0.200, 1.0)
const C_BTN_HOVER     := Color(0.110, 0.140, 0.290, 1.0)
const C_BTN_PRESS     := Color(0.048, 0.058, 0.130, 1.0)
const C_BTN_PRIMARY   := Color(0.420, 0.300, 0.055, 1.0)
const C_BTN_PRIMARY_H := Color(0.580, 0.420, 0.075, 1.0)
const C_BTN_PRIMARY_P := Color(0.280, 0.200, 0.038, 1.0)

const C_SLOT_EMPTY    := Color(0.038, 0.055, 0.110, 1.0)
const C_SLOT_FULL     := Color(0.048, 0.068, 0.145, 1.0)
const C_SLOT_LOCKED   := Color(0.025, 0.025, 0.060, 1.0)
const C_SLOT_SELECTED := Color(0.065, 0.090, 0.190, 1.0)

# ═══════════════════════════════════════════════════════════════════
# CONSTANTES
# ═══════════════════════════════════════════════════════════════════
const SAVE_PATH        := "user://accounts.save"
const IP_BAN_PATH      := "user://ip_registry.save"
const CACHE_VERSION    := 2
const MAX_SLOTS        := 4
const SLOT_UNLOCK_COST := [0, 10, 50, 200]
const BUILTIN_USER     := "DrakeDev"
const BUILTIN_PASS     := "drakedev1"

# ═══════════════════════════════════════════════════════════════════
# RAZAS CON LORE
# ═══════════════════════════════════════════════════════════════════
const RACES := [
	{
		"id": "human",  "label": "Humano",
		"locked": false, "icon": "⚔",
		"color": Color(0.85, 0.72, 0.52),
		"lore": "Versátiles guerreros de Sakura.\nDominio de todas las artes.",
		"stats": "VIT+2  ATK+1  MGC+1"
	},
	{
		"id": "elf",    "label": "Elfo",
		"locked": true,  "icon": "🌿",
		"color": Color(0.52, 0.90, 0.58),
		"lore": "Maestros ancestrales de la magia.\nÁgiles y eternamente jóvenes.",
		"stats": "AGI+3  MGC+3  VIT-1"
	},
	{
		"id": "tauren", "label": "Tauren",
		"locked": true,  "icon": "🐂",
		"color": Color(0.72, 0.55, 0.38),
		"lore": "Guardianes de las praderas.\nFuerza y honor sobre todo.",
		"stats": "VIT+4  ATK+2  AGI-2"
	},
	{
		"id": "ogre",   "label": "Ogro",
		"locked": true,  "icon": "💪",
		"color": Color(0.48, 0.72, 0.38),
		"lore": "Terror de los campos de batalla.\nFuerza bruta inigualable.",
		"stats": "ATK+5  VIT+2  MGC-3"
	},
]

# ═══════════════════════════════════════════════════════════════════
# APARIENCIA
# ═══════════════════════════════════════════════════════════════════
const HAIR_STYLES_LIST := ["bowlhair","curlyhair","longhair","mophair","shorthair","spikeyhair"]
const HAIR_LABELS      := ["Bowl","Rizado","Largo","Mop","Corto","Spiky"]
const SKIN_PRESETS     := [
	Color(0.98,0.82,0.67), Color(0.90,0.70,0.50),
	Color(0.75,0.53,0.36), Color(0.58,0.37,0.24), Color(0.36,0.22,0.14)
]
const SKIN_LABELS      := ["Claro","Trigo","Oliva","Moreno","Ébano"]
const HAIR_COLOR_PRESETS := [
	Color(0.12,0.07,0.03), Color(0.38,0.22,0.08),
	Color(0.80,0.60,0.18), Color(0.72,0.16,0.10),
	Color(0.68,0.68,0.75), Color(0.97,0.97,0.97)
]
const HAIR_COLOR_LABELS := ["Negro","Castaño","Rubio","Rojo","Gris","Blanco"]
const EYE_COLOR_PRESETS := [
	Color(0.12,0.32,0.82), Color(0.18,0.58,0.28),
	Color(0.52,0.32,0.10), Color(0.10,0.10,0.10),
	Color(0.72,0.42,0.08), Color(0.55,0.18,0.72)
]
const EYE_COLOR_LABELS  := ["Azul","Verde","Marrón","Negro","Ámbar","Violeta"]
const OUTFIT_PRESETS := [
	Color(0.85,0.85,0.88), Color(0.22,0.42,0.88),
	Color(0.78,0.16,0.16), Color(0.12,0.62,0.28),
	Color(0.55,0.12,0.72), Color(0.82,0.62,0.08)
]
const OUTFIT_LABELS := ["Gris","Azul","Rojo","Verde","Púrpura","Dorado"]

# ═══════════════════════════════════════════════════════════════════
# ESTADO DE CREACIÓN
# ═══════════════════════════════════════════════════════════════════
var _selected_hair       : String = "spikeyhair"
var _selected_skin       : Color  = SKIN_PRESETS[0]
var _selected_hair_color : Color  = HAIR_COLOR_PRESETS[0]
var _selected_eye_color  : Color  = EYE_COLOR_PRESETS[0]
var _selected_outfit     : Color  = OUTFIT_PRESETS[0]
var _selected_race       : String = "human"
var _selected_gender     : String = "male"
var _preview_sprite      : Sprite2D = null
var _preview_shader_mat  : ShaderMaterial = null
var _preview_anim_timer  : float   = 0.0
var _preview_frame       : int     = 0
const PREVIEW_FPS    : float = 8.0
const PREVIEW_FRAMES : int   = 9

var _race_btns       : Array = []
var _skin_btns       : Array = []
var _hair_color_btns : Array = []
var _eye_color_btns  : Array = []
var _outfit_btns     : Array = []
var _race_desc_lbl   : Label = null
var _hair_style_index : int  = 0
var _hair_nav_label  : Label = null

# ── Slots ───────────────────────────────────────────────────────────
var _accounts      : Dictionary = {}
var _logged_user   : String = ""
var _slots         : Array  = []
var _slot_unlocked : Array  = []
var _account_gold  : int    = 0
var _selected_slot : int    = -1
var _creating_slot : int    = -1
var _slot_panels   : Array  = []

# ── Partículas ─────────────────────────────────────────────────────
var _particles      : Array  = []
var _particle_layer : Control = null
const PARTICLE_COUNT := 55

# ── Pétalos Sakura ──────────────────────────────────────────────────
var _petals       : Array   = []
var _petal_layer  : Control = null
const PETAL_COUNT := 22
const C_SAKURA       := Color(0.910, 0.490, 0.627, 1.0)
const C_SAKURA_LIGHT := Color(0.960, 0.753, 0.816, 1.0)

# ── Select screen UI refs ───────────────────────────────────────────
var _select_char_preview        : Control  = null
var _select_char_preview_sprite : Sprite2D = null
var _select_char_anim_timer     : float    = 0.0
var _select_char_anim_frame     : int      = 0
var _select_char_name_lbl : Label  = null
var _select_char_info_lbl : Label  = null
var _addons_panel         : Control = null

# ── Animación ──────────────────────────────────────────────────────
var _title_label  : Label = null
var _anim_timer   : float = 0.0
var _pulse_timer  : float = 0.0
var _border_anim  : float = 0.0

# ── Crear cuenta (pantalla separada) ──────────────────────────────
var _screen_register   : Control  = null
var _reg_gmail_field   : LineEdit = null
var _reg_pass_field    : LineEdit = null
var _reg_pass2_field   : LineEdit = null
var _reg_error_lbl     : Label    = null

# ── Verificación Gmail ─────────────────────────────────────────────
var _screen_verify     : Node     = null
var _verify_code_field : LineEdit = null
var _verify_error_lbl  : Label    = null
var _pending_gmail     : String   = ""
var _pending_password  : String   = ""   # contraseña en texto plano
var _verify_expires_at : float    = 0.0
const VERIFY_TIMEOUT   : float    = 300.0

# ═══════════════════════════════════════════════════════════════════
# _READY
# ═══════════════════════════════════════════════════════════════════
func _ready() -> void:
	_load_accounts()
	_ensure_builtin_account()
	_apply_global_theme()
	_build_epic_background()
	_setup_particles()
	_setup_sakura_petals()
	_setup_title_wow()
	_build_register_screen()
	_setup_login_screen()
	_setup_select_screen()
	_setup_create_screen()
	_style_quit_button()
	# Música del menú principal con fade-in suave
	AudioManager.play_login_music()
	# ── Términos y Condiciones (se muestra solo la primera vez) ──
	if FileAccess.file_exists("user://tos_accepted.flag"):
		_show_login()
	else:
		_show_tos_screen()

# ═══════════════════════════════════════════════════════════════════
# TÉRMINOS Y CONDICIONES — se muestra solo la primera vez
# ═══════════════════════════════════════════════════════════════════
func _show_tos_screen() -> void:
	# Overlay oscuro que cubre todo
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Panel central
	var panel := PanelContainer.new()
	panel.layout_mode = 0
	panel.anchor_left   = 0.5; panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left   = -300.0; panel.offset_right  = 300.0
	panel.offset_top    = -330.0; panel.offset_bottom = 330.0
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.025, 0.012, 0.060, 0.98)
	ps.border_color = Color(0.85, 0.65, 0.10, 1.0)
	ps.set_border_width_all(3)
	ps.set_corner_radius_all(10)
	ps.shadow_color = Color(0.8, 0.6, 0.1, 0.35)
	ps.shadow_size  = 8
	ps.content_margin_left = 22; ps.content_margin_right  = 22
	ps.content_margin_top  = 18; ps.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# Título
	var title := Label.new()
	title.text = "✦  TÉRMINOS Y CONDICIONES  ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.15))
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Separador
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.55, 0.40, 0.10, 0.6)
	sep_style.content_margin_top = 1; sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Texto con scroll
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 390)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var tos_label := RichTextLabel.new()
	tos_label.bbcode_enabled = true
	tos_label.fit_content = true
	tos_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tos_label.add_theme_color_override("default_color", Color(0.82, 0.76, 0.90))
	tos_label.add_theme_font_size_override("normal_font_size", 13)
	tos_label.text = """[b][color=#f0c040]Sakura Chronicles — Términos y Condiciones de Uso[/color][/b]
Última actualización: 2025

[b]1. Aceptación[/b]
Al acceder o usar Sakura Chronicles ("el Juego"), aceptas quedar vinculado por estos Términos. Si no estás de acuerdo, no uses el Juego.

[b]2. Cuenta y Seguridad[/b]
Eres responsable de mantener la confidencialidad de tu cuenta y contraseña. El uso compartido de cuentas está prohibido. Una cuenta por persona y por IP.

[b]3. Conducta del Jugador[/b]
Queda estrictamente prohibido:
• Usar cheats, hacks, bots o software de terceros para obtener ventaja.
• Explotar bugs o vulnerabilidades del juego en lugar de reportarlos.
• Acosar, insultar o discriminar a otros jugadores.
• Suplantar a otros jugadores, al equipo de desarrollo o a personal del juego.
• Comerciar cuentas, personajes o items por dinero real sin autorización.

[b]4. Propiedad Intelectual[/b]
Todo el contenido del Juego (gráficos, música, código, nombre, logotipos) es propiedad exclusiva de [color=#f0c040]Drake Andonov Mendoza[/color] © 2026 — [color=#a080ff]drakemork.org[/color]. Queda prohibida su reproducción, distribución o modificación sin autorización expresa.

[b]5. Datos y Privacidad[/b]
El Juego almacena tu dirección de correo electrónico e IP de registro para gestionar tu cuenta y prevenir fraudes. No se comparten datos con terceros con fines comerciales.

[b]6. Sanciones[/b]
El equipo de desarrollo se reserva el derecho de suspender o eliminar cuentas que violen estos Términos, sin previo aviso ni reembolso.

[b]7. Cambios[/b]
Podemos actualizar estos Términos en cualquier momento. El uso continuado del Juego implica la aceptación de los cambios.

[b]8. Contacto[/b]
Para dudas o reportes: [color=#a080ff]soporte@sakurachronicles.lat[/color]

[color=#806090]Al presionar "Acepto", confirmas que tienes al menos 13 años de edad y que has leído y aceptado estos Términos en su totalidad.[/color]"""
	scroll.add_child(tos_label)

	# Separador inferior
	var sep2 := HSeparator.new()
	sep2.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep2)

	# Botones
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var reject_btn := Button.new()
	reject_btn.text = "  Rechazar  "
	reject_btn.custom_minimum_size = Vector2(150, 44)
	var rb_n := StyleBoxFlat.new()
	rb_n.bg_color = Color(0.18, 0.05, 0.05, 1.0)
	rb_n.border_color = Color(0.6, 0.2, 0.2, 1.0)
	rb_n.set_border_width_all(1); rb_n.set_corner_radius_all(6)
	rb_n.content_margin_left = 12; rb_n.content_margin_right = 12
	reject_btn.add_theme_stylebox_override("normal", rb_n)
	reject_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	reject_btn.add_theme_font_size_override("font_size", 15)
	btn_row.add_child(reject_btn)

	var accept_btn := Button.new()
	accept_btn.text = "  Acepto  "
	accept_btn.custom_minimum_size = Vector2(150, 44)
	var ab_n := StyleBoxFlat.new()
	ab_n.bg_color = Color(0.10, 0.28, 0.10, 1.0)
	ab_n.border_color = Color(0.3, 0.75, 0.3, 1.0)
	ab_n.set_border_width_all(1); ab_n.set_corner_radius_all(6)
	ab_n.content_margin_left = 12; ab_n.content_margin_right = 12
	accept_btn.add_theme_stylebox_override("normal", ab_n)
	accept_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	accept_btn.add_theme_font_size_override("font_size", 15)
	btn_row.add_child(accept_btn)

	# Conexiones
	reject_btn.pressed.connect(func():
		get_tree().quit()
	)
	accept_btn.pressed.connect(func():
		# Guardar flag de aceptación
		var f := FileAccess.open("user://tos_accepted.flag", FileAccess.WRITE)
		if f:
			f.store_string("accepted")
			f.close()
		overlay.queue_free()
		_show_login()
	)

# ═══════════════════════════════════════════════════════════════════
# TEMA GLOBAL
# ═══════════════════════════════════════════════════════════════════
func _apply_global_theme() -> void:
	var new_theme := Theme.new()
	new_theme.set_color("font_color", "Label", C_TEXT_LIGHT)

	var le_n := _make_lineedit_style(C_BORDER_DIM)
	var le_f := _make_lineedit_style(C_BORDER_GOLD)
	new_theme.set_stylebox("normal", "LineEdit", le_n)
	new_theme.set_stylebox("focus",  "LineEdit", le_f)
	new_theme.set_color("font_color",             "LineEdit", C_TEXT_WHITE)
	new_theme.set_color("font_placeholder_color", "LineEdit", C_TEXT_MUTED)

	var sep_s := StyleBoxFlat.new()
	sep_s.bg_color = C_BORDER_DIM
	new_theme.set_stylebox("separator", "HSeparator", sep_s)

	self.theme = new_theme

func _make_lineedit_style(border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.038, 0.048, 0.115, 1.0)
	s.set_border_width_all(2)
	s.border_color = border
	s.set_corner_radius_all(4)
	s.content_margin_left   = 12
	s.content_margin_right  = 12
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	return s

# ═══════════════════════════════════════════════════════════════════
# FONDO ÉPICO WoW
# ═══════════════════════════════════════════════════════════════════
func _build_epic_background() -> void:
	var root := $BgBase.get_parent() as Control
	($BgBase as ColorRect).color = C_BG_VOID

	var sky := ColorRect.new()
	sky.layout_mode = 0
	sky.anchor_right = 1.0; sky.anchor_bottom = 0.50
	sky.color = C_BG_DEEP
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky); root.move_child(sky, 1)

	var mist := ColorRect.new()
	mist.layout_mode = 0
	mist.anchor_top = 0.35; mist.anchor_right = 1.0; mist.anchor_bottom = 1.0
	mist.color = Color(0.06, 0.10, 0.24, 0.70)
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mist); root.move_child(mist, 2)

	var vign := ColorRect.new()
	vign.layout_mode = 0
	vign.anchor_right = 1.0; vign.anchor_bottom = 1.0
	vign.color = Color(0.0, 0.0, 0.0, 0.20)
	vign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vign)

	for i in range(5):
		var line := ColorRect.new()
		line.layout_mode = 0
		line.anchor_right = 1.0
		var yf := 0.18 + i * 0.16
		line.anchor_top = yf; line.anchor_bottom = yf
		line.offset_bottom = 1
		line.color = Color(0.15, 0.18, 0.38, 0.10 + i * 0.02)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(line)

	_build_wow_frame(root)

func _build_wow_frame(root: Control) -> void:
	_add_frame_bar(root, 0, 0, 1, 0, 0, 3, C_BORDER_GOLD)
	_add_frame_bar(root, 0, 1, 1, 1, -3, 0, C_BORDER_GOLD)
	_add_frame_bar_v(root, 0, 0, 0, 1, 0, 3, C_BORDER_GOLD)
	_add_frame_bar_v(root, 1, 0, 1, 1, -3, 0, C_BORDER_GOLD)
	_add_frame_bar(root, 0.01, 0, 0.99, 0, 6, 7, C_BORDER_DIM)
	_add_frame_bar(root, 0.01, 1, 0.99, 1, -7, -6, C_BORDER_DIM)
	for corner in [0, 1, 2, 3]:
		_build_corner_ornament(root, corner)

func _add_frame_bar(root: Control, al: float, at: float, ar: float, ab: float,
					ot: float, ob: float, col: Color) -> void:
	var r := ColorRect.new()
	r.layout_mode = 0
	r.anchor_left = al; r.anchor_top = at; r.anchor_right = ar; r.anchor_bottom = ab
	r.offset_top = ot; r.offset_bottom = ob
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)

func _add_frame_bar_v(root: Control, al: float, at: float, ar: float, ab: float,
					  ol: float, or_: float, col: Color) -> void:
	var r := ColorRect.new()
	r.layout_mode = 0
	r.anchor_left = al; r.anchor_top = at; r.anchor_right = ar; r.anchor_bottom = ab
	r.offset_left = ol; r.offset_right = or_
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)

func _build_corner_ornament(root: Control, corner: int) -> void:
	var lbl := Label.new()
	lbl.text = "✦"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	lbl.layout_mode = 0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match corner:
		0: lbl.anchor_left=0.0; lbl.anchor_top=0.0; lbl.offset_left=-4; lbl.offset_top=-4; lbl.offset_right=22; lbl.offset_bottom=22
		1: lbl.anchor_left=1.0; lbl.anchor_top=0.0; lbl.anchor_right=1.0; lbl.offset_left=-22; lbl.offset_top=-4; lbl.offset_right=4; lbl.offset_bottom=22
		2: lbl.anchor_left=0.0; lbl.anchor_top=1.0; lbl.anchor_bottom=1.0; lbl.offset_left=-4; lbl.offset_top=-22; lbl.offset_right=22; lbl.offset_bottom=4
		3: lbl.anchor_left=1.0; lbl.anchor_top=1.0; lbl.anchor_right=1.0; lbl.anchor_bottom=1.0; lbl.offset_left=-22; lbl.offset_top=-22; lbl.offset_right=4; lbl.offset_bottom=4
	root.add_child(lbl)

# ═══════════════════════════════════════════════════════════════════
# PARTÍCULAS
# ═══════════════════════════════════════════════════════════════════
func _setup_particles() -> void:
	_particle_layer = $ParticleLayer
	for i in range(PARTICLE_COUNT):
		var p := _spawn_particle(true)
		_particles.append(p)
		_particle_layer.add_child(p["node"])

func _spawn_particle(rand_y: bool) -> Dictionary:
	var type_roll := randi() % 10
	var t : String = "orb" if type_roll < 4 else ("spark" if type_roll < 7 else "rune")
	var node := Label.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.layout_mode = 0
	var texts := {
		"orb":   ["✦","✧","◆","◈","⬥","❋"],
		"spark": ["·","•","∘","°","⁕","∗","⋆"],
		"rune":  ["ᚠ","ᚢ","ᚦ","ᚨ","ᚱ","ᚲ","ᛏ","ᛒ"]
	}
	node.text = texts[t][randi() % texts[t].size()]
	var colors := [C_TEAL, C_EPIC_PURPLE, C_PINK, C_GOLD_BRIGHT, C_RARE_BLUE, Color(0.40,0.80,1.0), C_GOLD_MID]
	var col : Color = colors[randi() % colors.size()]
	node.add_theme_color_override("font_color", col)
	var sz := randi_range(7, 18)
	node.add_theme_font_size_override("font_size", sz)
	var vw : float = 1280.0; var vh : float = 720.0
	var x := randf() * vw
	var y := randf() * vh if rand_y else vh + 25.0
	node.position = Vector2(x, y)
	return {"node": node, "x": x, "y": y, "speed": randf_range(12.0, 48.0),
			"drift": randf_range(-15.0, 15.0), "phase": randf() * TAU,
			"size": sz, "col": col, "type": t}

func _update_particles(delta: float) -> void:
	var vw := get_viewport_rect().size.x; var vh := get_viewport_rect().size.y
	for p in _particles:
		p["y"]     -= p["speed"] * delta
		p["x"]     += p["drift"] * delta * 0.25
		p["phase"] += delta * (1.0 + randf() * 0.5)
		var fl : float = 0.50 + 0.50 * sin(p["phase"])
		var nd : Label = p["node"]
		nd.position  = Vector2(p["x"], p["y"])
		nd.modulate   = Color(1, 1, 1, fl * 0.85)
		if p["y"] < -35.0 or p["x"] < -35.0 or p["x"] > vw + 35.0:
			p["y"] = vh + 25.0; p["x"] = randf() * vw
			nd.position = Vector2(p["x"], p["y"])

func _setup_sakura_petals() -> void:
	_petal_layer = Control.new()
	_petal_layer.name = "SakuraPetalLayer"
	_petal_layer.layout_mode = 0
	_petal_layer.anchor_right = 1.0; _petal_layer.anchor_bottom = 1.0
	_petal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_petal_layer.z_index = 5
	$BgBase.get_parent().add_child(_petal_layer)
	for i in range(PETAL_COUNT):
		var p := _spawn_sakura_petal(true)
		_petals.append(p)
		_petal_layer.add_child(p["node"])

func _spawn_sakura_petal(rand_y: bool) -> Dictionary:
	var vw : float = 1280.0; var vh : float = 720.0
	var node := ColorRect.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.layout_mode = 0
	var petal_size := randf_range(5.0, 11.0)
	node.custom_minimum_size = Vector2(petal_size, petal_size)
	node.size = Vector2(petal_size, petal_size)
	var use_light : bool = (randi() % 2) == 0
	node.color = C_SAKURA_LIGHT if use_light else C_SAKURA
	var x := randf() * vw
	var y := randf() * vh if rand_y else -petal_size - 10.0
	node.position = Vector2(x, y)
	return {"node": node, "x": x, "y": y, "speed": randf_range(40.0, 80.0),
			"drift": randf_range(-25.0, 25.0), "phase": randf() * TAU,
			"rot": 0.0, "rot_spd": randf_range(-120.0, 120.0), "size": petal_size}

func _update_sakura_petals(delta: float) -> void:
	var vw := get_viewport_rect().size.x; var vh := get_viewport_rect().size.y
	for p in _petals:
		p["y"]    += p["speed"] * delta
		p["x"]    += p["drift"] * sin(p["phase"]) * delta * 0.6
		p["phase"] += delta * 1.2; p["rot"] += p["rot_spd"] * delta
		var nd : ColorRect = p["node"]
		nd.position = Vector2(p["x"], p["y"]); nd.rotation_degrees = p["rot"]
		var t : float = clampf(p["y"] / vh, 0.0, 1.0)
		nd.modulate = Color(1, 1, 1, (1.0 - t * 0.6) * 0.75)
		if p["y"] > vh + 20.0:
			p["y"] = -p["size"] - 10.0; p["x"] = randf() * vw
			nd.position = Vector2(p["x"], p["y"])

# ═══════════════════════════════════════════════════════════════════
# TÍTULO WoW
# ═══════════════════════════════════════════════════════════════════
func _setup_title_wow() -> void:
	_title_label = $TitleLabel
	_title_label.add_theme_font_size_override("font_size", 44)
	var sub := $SubtitleLabel as Label
	sub.add_theme_color_override("font_color", Color(0.62, 0.55, 0.90, 0.88))
	var root := $BgBase.get_parent() as Control
	var title_deco := Control.new()
	title_deco.name = "TitleDecoGroup"; title_deco.layout_mode = 0
	title_deco.anchor_right = 1.0; title_deco.anchor_bottom = 1.0
	title_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_deco)
	var line := ColorRect.new()
	line.layout_mode = 0; line.anchor_left = 0.5; line.anchor_right = 0.5
	line.offset_left = -220.0; line.offset_right = 220.0
	line.offset_top = 88.0; line.offset_bottom = 91.0
	line.color = C_BORDER_GOLD; line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_deco.add_child(line)
	var diamond := Label.new()
	diamond.name = "TitleDiamond"; diamond.layout_mode = 0
	diamond.anchor_left = 0.5; diamond.anchor_right = 0.5
	diamond.offset_left = -16; diamond.offset_right = 16
	diamond.offset_top = 80.0; diamond.offset_bottom = 98.0
	diamond.text = "◆"; diamond.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diamond.add_theme_font_size_override("font_size", 16)
	diamond.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_deco.add_child(diamond)
	for side in [-1, 1]:
		var emb := Label.new()
		emb.layout_mode = 0; emb.anchor_left = 0.5; emb.anchor_right = 0.5
		emb.offset_left = side * 210 - 20; emb.offset_right = side * 210 + 20
		emb.offset_top = 82.0; emb.offset_bottom = 96.0
		emb.text = "⬥"; emb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emb.add_theme_font_size_override("font_size", 12)
		emb.add_theme_color_override("font_color", C_GOLD_DIM)
		emb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_deco.add_child(emb)

func _style_quit_button() -> void:
	var qb := $QuitBtnGlobal as Button
	_style_button(qb, false, true)
	qb.add_theme_font_size_override("font_size", 12)
	qb.z_index = 10; qb.move_to_front()

# ═══════════════════════════════════════════════════════════════════
# ESTILOS DE BOTONES
# ═══════════════════════════════════════════════════════════════════
func _make_btn_style(bg: Color, border: Color, radius: int = 4,
					shadow: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(2); s.set_corner_radius_all(radius)
	s.content_margin_left = 14; s.content_margin_right = 14
	s.content_margin_top = 9; s.content_margin_bottom = 9
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.5); s.shadow_size = 4
		s.shadow_offset = Vector2(2, 2)
	return s

func _style_button(btn: Button, is_primary: bool = false,
				   is_danger: bool = false, is_epic: bool = false) -> void:
	var bg_n : Color; var bg_h : Color; var bg_p : Color
	var bd_n : Color; var bd_h : Color; var fc   : Color
	if is_epic:
		bg_n = Color(0.30, 0.08, 0.55, 1.0); bg_h = Color(0.42, 0.12, 0.72, 1.0)
		bg_p = Color(0.20, 0.05, 0.38, 1.0); bd_n = C_EPIC_PURPLE
		bd_h = Color(0.85, 0.60, 1.00, 1.0); fc   = Color(0.90, 0.75, 1.00, 1.0)
	elif is_primary:
		bg_n = C_BTN_PRIMARY; bg_h = C_BTN_PRIMARY_H; bg_p = C_BTN_PRIMARY_P
		bd_n = C_BORDER_GOLD; bd_h = C_GOLD_BRIGHT; fc = C_GOLD_BRIGHT
	elif is_danger:
		bg_n = Color(0.22, 0.05, 0.05, 1.0); bg_h = Color(0.35, 0.08, 0.08, 1.0)
		bg_p = Color(0.14, 0.03, 0.03, 1.0); bd_n = Color(0.55, 0.15, 0.15, 1.0)
		bd_h = C_RED_DANGER; fc = Color(1.0, 0.65, 0.65, 1.0)
	else:
		bg_n = C_BTN_NORMAL; bg_h = C_BTN_HOVER; bg_p = C_BTN_PRESS
		bd_n = C_BORDER_DIM; bd_h = C_BORDER_GOLD; fc = C_TEXT_LIGHT
	var sn := _make_btn_style(bg_n, bd_n, 4, is_primary)
	var sh := _make_btn_style(bg_h, bd_h, 4, is_primary)
	var sp := _make_btn_style(bg_p, bd_n, 4)
	var sd := _make_btn_style(Color(0.04,0.05,0.12), Color(0.16,0.16,0.26), 4)
	btn.add_theme_stylebox_override("normal", sn); btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp); btn.add_theme_stylebox_override("disabled", sd)
	btn.add_theme_color_override("font_color", fc)
	btn.add_theme_color_override("font_hover_color", C_GOLD_BRIGHT if (is_primary or is_epic) else C_TEXT_WHITE)
	btn.add_theme_color_override("font_pressed_color", C_GOLD_MID)
	btn.add_theme_color_override("font_disabled_color", C_TEXT_MUTED)

func _apply_panel_style(panel: PanelContainer, is_wide: bool = false) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG_PANEL_DARK; s.set_border_width_all(3)
	s.border_color = C_BORDER_GOLD; s.set_corner_radius_all(6)
	s.shadow_color = Color(0.72, 0.58, 0.18, 0.35); s.shadow_size = 12
	s.shadow_offset = Vector2(0, 4)
	s.content_margin_left   = 24 if is_wide else 26
	s.content_margin_right  = 24 if is_wide else 26
	s.content_margin_top = 20; s.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", s)
	_add_panel_top_ornament(panel); _add_panel_bottom_bar(panel)

func _add_panel_top_ornament(panel: PanelContainer) -> void:
	var bar := ColorRect.new(); bar.layout_mode = 0
	bar.anchor_left = 0.0; bar.anchor_right = 1.0
	bar.anchor_top = 0.0; bar.anchor_bottom = 0.0
	bar.offset_left = 16; bar.offset_right = -16; bar.offset_top = 3; bar.offset_bottom = 5
	bar.color = C_BORDER_DIM; bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bar)
	var orn := Label.new(); orn.layout_mode = 0
	orn.anchor_left = 0.5; orn.anchor_right = 0.5; orn.anchor_top = 0.0
	orn.offset_left = -40; orn.offset_right = 40; orn.offset_top = -16; orn.offset_bottom = 6
	orn.text = "⬥  ◆  ⬥"; orn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn.add_theme_font_size_override("font_size", 12)
	orn.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_child(orn)

func _add_panel_bottom_bar(panel: PanelContainer) -> void:
	var bar := ColorRect.new(); bar.layout_mode = 0
	bar.anchor_left = 0.0; bar.anchor_right = 1.0
	bar.anchor_top = 1.0; bar.anchor_bottom = 1.0
	bar.offset_left = 16; bar.offset_right = -16; bar.offset_top = -5; bar.offset_bottom = -3
	bar.color = C_BORDER_DIM; bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bar)

func _make_separator(dark: bool = false) -> HSeparator:
	var sep := HSeparator.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = C_BORDER_DIM if dark else C_BORDER_INNER
	sep.add_theme_stylebox_override("separator", ss)
	return sep

func _make_sep_style(col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = col; return s

# ═══════════════════════════════════════════════════════════════════
# PANTALLA LOGIN — ahora llama al servidor
# ═══════════════════════════════════════════════════════════════════
func _setup_login_screen() -> void:
	var panel := PanelContainer.new()
	panel.layout_mode = 0
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -230.0; panel.offset_right = 230.0
	panel.offset_top = -240.0; panel.offset_bottom = 240.0
	screen_login.add_child(panel); _apply_panel_style(panel)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2; vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "🔐  INICIAR SESIÓN"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep1 := HSeparator.new()
	sep1.add_theme_stylebox_override("separator", _make_sep_style(C_BORDER_DIM))
	vbox.add_child(sep1)

	var gmail_lbl := Label.new()
	gmail_lbl.text = "📧  Correo Gmail"
	gmail_lbl.add_theme_font_size_override("font_size", 12)
	gmail_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	vbox.add_child(gmail_lbl)

	login_user_field = LineEdit.new()
	login_user_field.custom_minimum_size = Vector2(0, 40)
	login_user_field.layout_mode = 2
	login_user_field.placeholder_text = "tucuenta@gmail.com"
	login_user_field.add_theme_font_size_override("font_size", 14)
	vbox.add_child(login_user_field)

	var pass_lbl := Label.new()
	pass_lbl.text = "🔒  Contraseña"
	pass_lbl.add_theme_font_size_override("font_size", 12)
	pass_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	vbox.add_child(pass_lbl)

	login_pass_field = LineEdit.new()
	login_pass_field.custom_minimum_size = Vector2(0, 40)
	login_pass_field.layout_mode = 2
	login_pass_field.placeholder_text = "Contraseña secreta..."
	login_pass_field.secret = true
	login_pass_field.add_theme_font_size_override("font_size", 14)
	vbox.add_child(login_pass_field)

	login_error_lbl = Label.new()
	login_error_lbl.add_theme_color_override("font_color", C_RED_DANGER)
	login_error_lbl.add_theme_font_size_override("font_size", 11)
	login_error_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(login_error_lbl)

	var login_btn := Button.new()
	login_btn.custom_minimum_size = Vector2(0, 48)
	login_btn.layout_mode = 2
	login_btn.text = "▶  ENTRAR AL MUNDO"
	_style_button(login_btn, true)
	login_btn.add_theme_font_size_override("font_size", 16)
	login_btn.pressed.connect(_on_login_btn_pressed)
	vbox.add_child(login_btn)

	var sep2 := HSeparator.new()
	sep2.add_theme_stylebox_override("separator", _make_sep_style(C_BORDER_INNER))
	vbox.add_child(sep2)

	var create_btn := Button.new()
	create_btn.custom_minimum_size = Vector2(0, 40)
	create_btn.layout_mode = 2
	create_btn.text = "✨  CREAR NUEVA CUENTA"
	_style_button(create_btn)
	create_btn.add_theme_font_size_override("font_size", 13)
	create_btn.pressed.connect(_on_create_acc_btn_pressed)
	vbox.add_child(create_btn)

# ═══════════════════════════════════════════════════════════════════
# PANTALLA REGISTRO
# ═══════════════════════════════════════════════════════════════════
func _build_register_screen() -> void:
	var scr := Control.new()
	scr.name = "ScreenRegister"; scr.layout_mode = 3
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	scr.visible = false; scr.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scr); _screen_register = scr

	var panel := PanelContainer.new()
	panel.layout_mode = 0
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -240.0; panel.offset_right = 240.0
	panel.offset_top = -280.0; panel.offset_bottom = 280.0
	_apply_panel_style(panel); scr.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2; vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "✨  CREAR CUENTA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	vbox.add_child(title); vbox.add_child(_make_separator())

	var gmail_lbl := Label.new()
	gmail_lbl.text = "📧  Correo Gmail"
	gmail_lbl.add_theme_font_size_override("font_size", 12)
	gmail_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	vbox.add_child(gmail_lbl)
	_reg_gmail_field = LineEdit.new()
	_reg_gmail_field.custom_minimum_size = Vector2(0, 40); _reg_gmail_field.layout_mode = 2
	_reg_gmail_field.placeholder_text = "tucuenta@gmail.com"
	_reg_gmail_field.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_reg_gmail_field)

	var pass_lbl := Label.new()
	pass_lbl.text = "🔒  Contraseña"
	pass_lbl.add_theme_font_size_override("font_size", 12)
	pass_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	vbox.add_child(pass_lbl)
	_reg_pass_field = LineEdit.new()
	_reg_pass_field.custom_minimum_size = Vector2(0, 40); _reg_pass_field.layout_mode = 2
	_reg_pass_field.placeholder_text = "Mínimo 6 caracteres"
	_reg_pass_field.secret = true; _reg_pass_field.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_reg_pass_field)

	var pass2_lbl := Label.new()
	pass2_lbl.text = "🔑  Confirmar contraseña"
	pass2_lbl.add_theme_font_size_override("font_size", 12)
	pass2_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	vbox.add_child(pass2_lbl)
	_reg_pass2_field = LineEdit.new()
	_reg_pass2_field.custom_minimum_size = Vector2(0, 40); _reg_pass2_field.layout_mode = 2
	_reg_pass2_field.placeholder_text = "Repite la contraseña"
	_reg_pass2_field.secret = true; _reg_pass2_field.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_reg_pass2_field)

	var tip := Label.new()
	tip.text = "ℹ Solo se permite 1 cuenta por Gmail y por IP."
	tip.add_theme_font_size_override("font_size", 10)
	tip.add_theme_color_override("font_color", C_TEXT_MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; vbox.add_child(tip)

	_reg_error_lbl = Label.new()
	_reg_error_lbl.add_theme_font_size_override("font_size", 11)
	_reg_error_lbl.add_theme_color_override("font_color", C_RED_DANGER)
	_reg_error_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_reg_error_lbl)

	var create_btn := Button.new()
	create_btn.custom_minimum_size = Vector2(0, 46)
	create_btn.text = "📧  ENVIAR CÓDIGO DE VERIFICACIÓN"
	create_btn.add_theme_font_size_override("font_size", 14)
	_style_button(create_btn, true)
	create_btn.pressed.connect(_on_register_request_code)
	vbox.add_child(create_btn)

	var back_btn := Button.new()
	back_btn.custom_minimum_size = Vector2(0, 36); back_btn.text = "← Volver al Login"
	back_btn.add_theme_font_size_override("font_size", 12); _style_button(back_btn)
	back_btn.pressed.connect(func(): _screen_register.visible = false; screen_login.visible = true)
	vbox.add_child(back_btn)

	_build_verify_screen()

func _build_verify_screen() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ScreenVerify"; canvas.layer = 10
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.visible = false; add_child(canvas); _screen_verify = canvas

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(root_ctrl)

	var panel := PanelContainer.new()
	panel.layout_mode = 0
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -240.0; panel.offset_right = 240.0
	panel.offset_top = -260.0; panel.offset_bottom = 260.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_BG_PANEL_DARK; panel_style.set_border_width_all(3)
	panel_style.border_color = C_BORDER_GOLD; panel_style.set_corner_radius_all(6)
	panel_style.shadow_color = Color(0.72, 0.58, 0.18, 0.35); panel_style.shadow_size = 12
	panel_style.content_margin_left = 24; panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20; panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	root_ctrl.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2; vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new(); title.text = "VERIFICAR EMAIL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", C_GOLD_BRIGHT); vbox.add_child(title)
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_sep_style(C_BORDER_DIM)); vbox.add_child(sep)

	var info := Label.new()
	info.text = "Hemos enviado un código de 6 dígitos a tu Gmail.\nRevisa también la carpeta de spam."
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", C_TEXT_LIGHT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(info)

	var code_lbl := Label.new(); code_lbl.text = "Código de 6 dígitos"
	code_lbl.add_theme_font_size_override("font_size", 12)
	code_lbl.add_theme_color_override("font_color", C_TEXT_DIM); vbox.add_child(code_lbl)

	_verify_code_field = LineEdit.new()
	_verify_code_field.custom_minimum_size = Vector2(0, 58); _verify_code_field.layout_mode = 2
	_verify_code_field.placeholder_text = "000000"; _verify_code_field.max_length = 6
	_verify_code_field.add_theme_font_size_override("font_size", 32)
	_verify_code_field.alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(_verify_code_field)

	_verify_error_lbl = Label.new()
	_verify_error_lbl.add_theme_font_size_override("font_size", 11)
	_verify_error_lbl.add_theme_color_override("font_color", C_RED_DANGER)
	_verify_error_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; vbox.add_child(_verify_error_lbl)

	var confirm_btn := Button.new()
	confirm_btn.custom_minimum_size = Vector2(0, 48); confirm_btn.layout_mode = 2
	confirm_btn.text = "VERIFICAR Y CREAR CUENTA"
	confirm_btn.add_theme_font_size_override("font_size", 14)
	_style_button(confirm_btn, true)
	confirm_btn.pressed.connect(_on_verify_code_confirm); vbox.add_child(confirm_btn)

	var resend_btn := Button.new()
	resend_btn.custom_minimum_size = Vector2(0, 36); resend_btn.layout_mode = 2
	resend_btn.text = "Reenviar código"; resend_btn.add_theme_font_size_override("font_size", 12)
	_style_button(resend_btn); resend_btn.pressed.connect(_on_register_request_code)
	vbox.add_child(resend_btn)

	var back_btn := Button.new()
	back_btn.custom_minimum_size = Vector2(0, 36); back_btn.layout_mode = 2
	back_btn.text = "← Cambiar email"; back_btn.add_theme_font_size_override("font_size", 12)
	_style_button(back_btn)
	back_btn.pressed.connect(func():
		_screen_verify.visible = false
		_screen_register.visible = true; screen_login.visible = true)
	vbox.add_child(back_btn)

# ═══════════════════════════════════════════════════════════════════
# REGISTRO — PASO 1: solicitar código
# ═══════════════════════════════════════════════════════════════════
func _on_register_request_code() -> void:
	var gmail := _reg_gmail_field.text.strip_edges().to_lower()
	var pass1  := _reg_pass_field.text
	var pass2  := _reg_pass2_field.text

	if not gmail.ends_with("@gmail.com") or gmail.length() < 10:
		_reg_error_lbl.text = "⚠ Usa un correo @gmail.com válido."; return
	if pass1.length() < 6:
		_reg_error_lbl.text = "⚠ Contraseña mínimo 6 caracteres."; return
	if pass1 != pass2:
		_reg_error_lbl.text = "⚠ Las contraseñas no coinciden."; return

	_reg_error_lbl.text = "Enviando código..."
	_pending_gmail    = gmail
	_pending_password = pass1

	var http := HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_reg_error_lbl.text = "⚠ Error al enviar código. Intenta de nuevo."; return
		var json : Variant = JSON.parse_string(body.get_string_from_utf8())
		if not json is Dictionary or not json.get("ok", false):
			_reg_error_lbl.text = "⚠ %s" % json.get("error","Error desconocido"); return
		_verify_expires_at = Time.get_unix_time_from_system() + VERIFY_TIMEOUT
		_reg_error_lbl.text = ""
		_screen_register.visible = false; screen_login.visible = false
		_screen_verify.visible = true
		if _verify_code_field: _verify_code_field.text = ""; _verify_code_field.call_deferred("grab_focus")
		if _verify_error_lbl:  _verify_error_lbl.text  = ""
	)
	var err := http.request(
		AUTH_BACKEND + "/send-code",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify({"gmail": gmail})
	)
	if err != OK:
		_reg_error_lbl.text = "⚠ No se pudo conectar al servidor."; http.queue_free()

# ═══════════════════════════════════════════════════════════════════
# REGISTRO — PASO 2: verificar código
# ═══════════════════════════════════════════════════════════════════
func _on_verify_code_confirm() -> void:
	var entered := _verify_code_field.text.strip_edges()
	if entered.length() != 6:
		_verify_error_lbl.text = "⚠ El código tiene 6 dígitos."; return
	if Time.get_unix_time_from_system() > _verify_expires_at:
		_verify_error_lbl.text = "⚠ Código expirado. Solicita uno nuevo."; return

	_verify_error_lbl.text = "Verificando..."
	var http := HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_verify_error_lbl.text = "⚠ Error al verificar. Intenta de nuevo."; return
		var json : Variant = JSON.parse_string(body.get_string_from_utf8())
		if not json is Dictionary or not json.get("ok", false):
			_verify_error_lbl.text = "⚠ %s" % json.get("error","Código incorrecto"); return
		# ✅ Cuenta creada en servidor — guardar sesión y entrar
		_logged_gmail    = _pending_gmail
		_logged_password = _pending_password
		_logged_username = json.get("username", _pending_gmail.split("@")[0])
		_logged_user     = _logged_username
		_pending_gmail = ""; _pending_password = ""
		_screen_verify.visible = false
		screen_login.visible   = true
		login_error_lbl.text   = "✅ ¡Cuenta creada! Cargando..."
		login_error_lbl.add_theme_color_override("font_color", C_UNCOMMON)
		_show_select()
	)
	var err := http.request(
		AUTH_BACKEND + "/verify-code",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify({"gmail": _pending_gmail, "code": entered, "password": _pending_password})
	)
	if err != OK:
		_verify_error_lbl.text = "⚠ No se pudo conectar al servidor."; http.queue_free()

# ═══════════════════════════════════════════════════════════════════
# LOGIN — ahora via servidor
# ═══════════════════════════════════════════════════════════════════
func _on_login_btn_pressed() -> void:
	var gmail := login_user_field.text.strip_edges().to_lower()
	var password_input := login_pass_field.text

	# Cuenta especial de desarrollo — login local
	if gmail == BUILTIN_USER and password_input == BUILTIN_PASS:
		_logged_user     = BUILTIN_USER
		_logged_gmail    = BUILTIN_USER + "@dev.local"
		_logged_password = BUILTIN_PASS
		_logged_username = BUILTIN_USER
		_show_select(); return

	if gmail.is_empty():
		login_error_lbl.text = "⚠ Escribe tu correo."; return
	if password_input.is_empty():
		login_error_lbl.text = "⚠ Escribe tu contraseña."; return

	login_error_lbl.text = "Conectando... (puede tardar ~10s si el servidor está dormido)"
	login_error_lbl.add_theme_color_override("font_color", C_GOLD_MID)

	var http := HTTPRequest.new(); add_child(http)
	http.timeout = 20.0  # FIX APK: Railway puede tardar en despertar
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS:
			login_error_lbl.add_theme_color_override("font_color", C_RED_DANGER)
			login_error_lbl.text = "⚠ No se pudo conectar al servidor."; return
		var json : Variant = JSON.parse_string(body.get_string_from_utf8())
		if not json is Dictionary or not json.get("ok", false):
			login_error_lbl.add_theme_color_override("font_color", C_RED_DANGER)
			login_error_lbl.text = "⚠ %s" % json.get("error","Error de login"); return
		# ✅ Login exitoso
		_logged_gmail    = gmail
		_logged_password = password_input
		_logged_username = json.get("username", gmail.split("@")[0])
		_logged_user     = _logged_username
		login_error_lbl.text = ""
		_show_select()
	)
	var err := http.request(
		AUTH_BACKEND + "/login",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify({"gmail": gmail, "password": password_input})
	)
	if err != OK:
		login_error_lbl.add_theme_color_override("font_color", C_RED_DANGER)
		login_error_lbl.text = "⚠ No se pudo conectar al servidor."
		http.queue_free()

func _on_create_acc_btn_pressed() -> void:
	if is_instance_valid(_screen_register):
		screen_login.visible = false; _screen_register.visible = true
		if is_instance_valid(_reg_gmail_field): _reg_gmail_field.text = ""
		if is_instance_valid(_reg_pass_field):  _reg_pass_field.text  = ""
		if is_instance_valid(_reg_pass2_field): _reg_pass2_field.text = ""
		if is_instance_valid(_reg_error_lbl):   _reg_error_lbl.text   = ""

# ═══════════════════════════════════════════════════════════════════
# GUARDAR / CARGAR DATOS DEL PERSONAJE VIA SERVIDOR  (WoW-style)
# Todo se guarda en Firestore: monedas, xp, nivel, inventario,
# equipo, banco, profesiones de crafteo y recolección.
# ═══════════════════════════════════════════════════════════════════

# Construye el bloque "character" con todos los stats de PlayerData
func _build_character_payload() -> Dictionary:
	var gs: Dictionary = {}
	for sk in PlayerData.gathering_skills:
		gs[sk] = {
			"level": PlayerData.gathering_skills[sk]["level"],
			"xp":    PlayerData.gathering_skills[sk]["xp"],
		}
	var cs: Dictionary = {}
	for sk in PlayerData.crafting_skills:
		cs[sk] = {
			"level": PlayerData.crafting_skills[sk]["level"],
			"xp":    PlayerData.crafting_skills[sk]["xp"],
		}
	return {
		"name":       PlayerData.character_name,
		"gender":     PlayerData.character_gender,
		"race":       PlayerData.race,
		"hair_style": PlayerData.hair_style,
		"skin_r": PlayerData.skin_color.r, "skin_g": PlayerData.skin_color.g, "skin_b": PlayerData.skin_color.b,
		"hair_r": PlayerData.hair_color.r, "hair_g": PlayerData.hair_color.g, "hair_b": PlayerData.hair_color.b,
		"eye_r":  PlayerData.eye_color.r,  "eye_g":  PlayerData.eye_color.g,  "eye_b":  PlayerData.eye_color.b,
		"outfit_r": PlayerData.outfit_color.r, "outfit_g": PlayerData.outfit_color.g, "outfit_b": PlayerData.outfit_color.b,
		"level":        PlayerData.level,
		"xp":           PlayerData.xp,
		"max_hp":       PlayerData.max_hp,
		"hp":           PlayerData.hp,
		"max_energy":   PlayerData.max_energy,
		"energy":       int(PlayerData.energy),
		"speed":        PlayerData.speed,
		"base_attack":  PlayerData.base_attack,
		"tutorial_done": PlayerData.tutorial_done,
		"bronze": PlayerData.bronze,
		"silver": PlayerData.silver,
		"gold":   PlayerData.gold,
		"gathering_skills": gs,
		"crafting_skills":  cs,
	}

# Serializa el inventario (40 slots) para enviar al servidor
func _build_inventory_payload() -> Array:
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv: return []
	var result: Array = []
	for item in inv.items:
		if item == null:
			result.append(null)
		else:
			result.append({
				"key":        item.get("key", ""),
				"qty":        item.get("qty", 1),
				"quality":    item.get("quality", ""),
				"durability": item.get("durability", -1),
			})
	return result

# Serializa el equipo equipado
func _build_equipped_payload() -> Dictionary:
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv: return {}
	var result: Dictionary = {}
	for slot in inv.equipped_items:
		var eq = inv.equipped_items[slot]
		if eq == null:
			result[slot] = null
		else:
			result[slot] = {
				"key":        eq.get("key", ""),
				"qty":        eq.get("qty", 1),
				"quality":    eq.get("quality", ""),
				"durability": eq.get("durability", -1),
			}
	return result

# Serializa el banco completo (tier + items)
func _build_bank_payload() -> Dictionary:
	var bank_mgr = get_node_or_null("/root/BankManager")
	var inv      = get_node_or_null("/root/InventoryManager")
	var tier: int = 0
	var items_arr: Array = []
	if bank_mgr:
		tier = bank_mgr.bank_tier
	if inv:
		for item in inv.bank_items:
			if item == null:
				items_arr.append(null)
			else:
				items_arr.append({
					"key":        item.get("key", ""),
					"qty":        item.get("qty", 1),
					"quality":    item.get("quality", ""),
					"durability": item.get("durability", -1),
				})
	return { "tier": tier, "items": items_arr }

# ── SAVE ──────────────────────────────────────────────────────
func _server_save_player() -> void:
	if _logged_gmail.is_empty() or _logged_password.is_empty(): return
	var active_slot: int = max(0, _selected_slot)

	# Aseguramos que el inventario local esté guardado antes de serializar
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("save_inventory"): inv.save_inventory()
	var bank_mgr = get_node_or_null("/root/BankManager")
	if bank_mgr and bank_mgr.has_method("save_bank_data"): bank_mgr.save_bank_data()

	var payload := {
		"gmail":          _logged_gmail,
		"password":       _logged_password,
		"character_slot": active_slot,
		"character":      _build_character_payload(),
		"inventory":      _build_inventory_payload(),
		"equipped":       _build_equipped_payload(),
		"bank":           _build_bank_payload(),
	}
	var http := HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(result, code, _h, body):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			push_error("[MainMenu] Error guardando en servidor: code=%d" % code)
		else:
			print("[MainMenu] ✅ Save completo en servidor (WoW-style)")
	)
	var err := http.request(
		AUTH_BACKEND + "/save-player",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK: push_error("[MainMenu] HTTPRequest falló: %d" % err)

# ── LOAD ──────────────────────────────────────────────────────
# on_done(json_or_null) — json tiene:
#   { ok, active_slot, slots: [ {character, inventory, equipped, bank} | null, ...] }
func _server_load_player(on_done: Callable) -> void:
	if _logged_gmail.is_empty() or _logged_password.is_empty():
		on_done.call(null); return
	var http := HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		var json : Variant = JSON.parse_string(body.get_string_from_utf8())
		if json is Dictionary and json.get("ok", false):
			_apply_server_player_data(json)
			on_done.call(json)
		else:
			push_error("[MainMenu] Error cargando desde servidor (code %d)" % code)
			on_done.call(null)
	)
	http.request(
		AUTH_BACKEND + "/load-player",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify({"gmail": _logged_gmail, "password": _logged_password})
	)

# Aplica los datos del servidor sobre los singletons (inventario, banco, PlayerData)
func _apply_server_player_data(json: Dictionary) -> void:
	var active_slot: int = json.get("active_slot", 0)
	var slots: Array     = json.get("slots", [])
	if active_slot >= slots.size() or slots[active_slot] == null:
		return  # Sin datos de servidor — conservar save local

	var slot_data: Dictionary = slots[active_slot]

	# ── PlayerData (stats, monedas, profesiones) ──────────────
	var ch = slot_data.get("character", null)
	if ch is Dictionary:
		if ch.has("name"):        PlayerData.character_name   = ch["name"]
		if ch.has("gender"):      PlayerData.character_gender = ch["gender"]
		if ch.has("race"):        PlayerData.race             = ch["race"]
		if ch.has("hair_style"):  PlayerData.hair_style       = ch["hair_style"]
		if ch.has("skin_r"):
			PlayerData.skin_color = Color(ch.get("skin_r",0.96), ch.get("skin_g",0.78), ch.get("skin_b",0.64))
		if ch.has("hair_r"):
			PlayerData.hair_color = Color(ch.get("hair_r",0.25), ch.get("hair_g",0.15), ch.get("hair_b",0.08))
		if ch.has("eye_r"):
			PlayerData.eye_color  = Color(ch.get("eye_r",0.2),   ch.get("eye_g",0.5),   ch.get("eye_b",0.9))
		if ch.has("outfit_r"):
			PlayerData.outfit_color = Color(ch.get("outfit_r",1.0), ch.get("outfit_g",1.0), ch.get("outfit_b",1.0))
		if ch.has("level"):        PlayerData.level        = ch["level"]
		if ch.has("xp"):           PlayerData.xp           = ch["xp"]
		if ch.has("max_hp"):       PlayerData.max_hp       = ch["max_hp"]
		if ch.has("hp"):           PlayerData.hp           = ch["hp"]
		if ch.has("max_energy"):   PlayerData.max_energy   = ch["max_energy"]
		if ch.has("energy"):       PlayerData.energy       = float(ch["energy"])
		if ch.has("speed"):        PlayerData.speed        = ch["speed"]
		if ch.has("base_attack"):  PlayerData.base_attack  = ch["base_attack"]
		if ch.has("tutorial_done"): PlayerData.tutorial_done = ch["tutorial_done"]
		if ch.has("bronze"): PlayerData.bronze = ch["bronze"]
		if ch.has("silver"): PlayerData.silver = ch["silver"]
		if ch.has("gold"):   PlayerData.gold   = ch["gold"]
		if ch.has("gathering_skills"):
			var gs = ch["gathering_skills"]
			for sk in PlayerData.gathering_skills:
				if gs.has(sk):
					PlayerData.gathering_skills[sk]["level"] = gs[sk].get("level", 1)
					PlayerData.gathering_skills[sk]["xp"]    = gs[sk].get("xp", 0)
		if ch.has("crafting_skills"):
			var cs = ch["crafting_skills"]
			for sk in PlayerData.crafting_skills:
				if cs.has(sk):
					PlayerData.crafting_skills[sk]["level"] = cs[sk].get("level", 1)
					PlayerData.crafting_skills[sk]["xp"]    = cs[sk].get("xp", 0)
		PlayerData.stat_updated.emit()
		PlayerData.currency_changed.emit()

	# ── InventoryManager (inventario + equipo) ─────────────────
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		var inv_data = slot_data.get("inventory", null)
		if inv_data is Array:
			for i in range(min(inv_data.size(), inv.items.size())):
				var entry = inv_data[i]
				if entry == null or not (entry is Dictionary):
					inv.items[i] = null
				else:
					var ikey: String = entry.get("key", "")
					if ikey == "" or not inv.item_database.has(ikey):
						inv.items[i] = null
					else:
						var item_data: Dictionary = inv.item_database[ikey].duplicate(true)
						item_data["key"] = ikey
						item_data["qty"] = entry.get("qty", 1)
						var qual: String = entry.get("quality", "")
						if qual != "": item_data["quality"] = qual
						var dur = entry.get("durability", -1)
						if dur >= 0: item_data["durability"] = dur
						inv.items[i] = item_data

		var eq_data = slot_data.get("equipped", null)
		if eq_data is Dictionary:
			for slot_name in inv.equipped_items.keys():
				if not eq_data.has(slot_name): continue
				var entry = eq_data[slot_name]
				if entry == null or not (entry is Dictionary):
					inv.equipped_items[slot_name] = null
				else:
					var ikey: String = entry.get("key", "")
					if ikey == "" or not inv.item_database.has(ikey):
						inv.equipped_items[slot_name] = null
					else:
						var item_data: Dictionary = inv.item_database[ikey].duplicate(true)
						item_data["key"] = ikey
						item_data["qty"] = entry.get("qty", 1)
						var qual: String = entry.get("quality", "")
						if qual != "": item_data["quality"] = qual
						var dur = entry.get("durability", -1)
						if dur >= 0: item_data["durability"] = dur
						inv.equipped_items[slot_name] = item_data
		if inv.has_method("_update_equipment_stats"):
			inv._update_equipment_stats()
		inv.inventory_changed.emit()

	# ── BankManager (banco) ────────────────────────────────────
	var bank_data = slot_data.get("bank", null)
	if bank_data is Dictionary:
		var bank_mgr = get_node_or_null("/root/BankManager")
		if bank_mgr and inv:
			bank_mgr.bank_tier = clamp(bank_data.get("tier", 0), 0, bank_mgr.MAX_TIER)
			inv.expand_bank_slots(bank_mgr.get_current_slots())
			var bank_items_raw = bank_data.get("items", [])
			inv.bank_items.clear()
			for i in range(bank_mgr.get_current_slots()):
				if i < bank_items_raw.size():
					var entry = bank_items_raw[i]
					if entry == null or not (entry is Dictionary):
						inv.bank_items.append(null)
					else:
						var ikey: String = entry.get("key", "")
						if ikey == "" or not inv.item_database.has(ikey):
							inv.bank_items.append(null)
						else:
							var item_data: Dictionary = inv.item_database[ikey].duplicate(true)
							item_data["key"] = ikey
							item_data["qty"] = entry.get("qty", 1)
							var qual: String = entry.get("quality", "")
							if qual != "": item_data["quality"] = qual
							var dur = entry.get("durability", -1)
							if dur >= 0: item_data["durability"] = dur
							inv.bank_items.append(item_data)
				else:
					inv.bank_items.append(null)

	# Persistir localmente para coherencia offline
	PlayerData.save_character_data()
	if inv and inv.has_method("save_inventory"): inv.save_inventory()
	var _bm_flush = get_node_or_null("/root/BankManager")
	if _bm_flush and _bm_flush.has_method("save_bank_data"): _bm_flush.save_bank_data()
	print("[MainMenu] ✅ Datos del servidor aplicados (WoW-style)")

# ═══════════════════════════════════════════════════════════════════
# PANTALLA SELECCIÓN DE PERSONAJE
# ═══════════════════════════════════════════════════════════════════
func _setup_select_screen() -> void:
	var root := screen_select
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_right = 1.0; root.anchor_bottom = 1.0

	var right_panel := PanelContainer.new()
	right_panel.layout_mode = 0
	right_panel.anchor_left = 1.0; right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0; right_panel.anchor_bottom = 1.0
	right_panel.offset_left = -270.0; right_panel.offset_right = 0.0
	right_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var rp_style := StyleBoxFlat.new()
	rp_style.bg_color = Color(0.016, 0.008, 0.047, 0.96)
	rp_style.border_color = Color(0.55, 0.42, 0.12, 0.22)
	rp_style.set_border_width_all(0); rp_style.border_width_left = 1
	rp_style.content_margin_left = 0; rp_style.content_margin_right = 0
	rp_style.content_margin_top = 0; rp_style.content_margin_bottom = 0
	right_panel.add_theme_stylebox_override("panel", rp_style)
	root.add_child(right_panel)

	var rp_vbox := VBoxContainer.new()
	rp_vbox.layout_mode = 2; rp_vbox.add_theme_constant_override("separation", 0)
	right_panel.add_child(rp_vbox)

	var rp_header := VBoxContainer.new()
	rp_header.add_theme_constant_override("separation", 4)
	rp_header.add_child(_make_separator(true))
	var rp_title := Label.new()
	rp_title.text = "SELECCIONA PERSONAJE"
	rp_title.add_theme_font_size_override("font_size", 10)
	rp_title.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	rp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rp_header.add_child(rp_title)
	var rp_ornament := Label.new(); rp_ornament.text = "── ✦ ──"
	rp_ornament.add_theme_font_size_override("font_size", 10)
	rp_ornament.add_theme_color_override("font_color", C_GOLD_DIM)
	rp_ornament.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rp_header.add_child(rp_ornament)
	account_gold_lbl = Label.new(); account_gold_lbl.text = "💰 0 oro de cuenta"
	account_gold_lbl.add_theme_font_size_override("font_size", 10)
	account_gold_lbl.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	account_gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rp_header.add_child(account_gold_lbl); rp_header.add_child(_make_separator(true))
	rp_vbox.add_child(rp_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rp_vbox.add_child(scroll)
	var slots_vbox := VBoxContainer.new()
	slots_vbox.add_theme_constant_override("separation", 6)
	slots_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_vbox.layout_mode = 2
	scroll.add_child(slots_vbox); slots_container = slots_vbox

	select_error_lbl = Label.new()
	select_error_lbl.add_theme_color_override("font_color", C_GOLD_MID)
	select_error_lbl.add_theme_font_size_override("font_size", 11)
	select_error_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_error_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rp_vbox.add_child(select_error_lbl)

	var btns_bg := PanelContainer.new()
	var btns_s := StyleBoxFlat.new()
	btns_s.bg_color = Color(0.012, 0.006, 0.032, 0.0)
	btns_s.border_width_top = 1; btns_s.border_color = Color(0.55, 0.42, 0.12, 0.15)
	btns_bg.add_theme_stylebox_override("panel", btns_s)
	var btns_vbox := VBoxContainer.new()
	btns_vbox.add_theme_constant_override("separation", 6)
	btns_bg.add_child(btns_vbox); rp_vbox.add_child(btns_bg)

	select_enter_btn = Button.new()
	select_enter_btn.custom_minimum_size = Vector2(0, 44); select_enter_btn.layout_mode = 2
	select_enter_btn.text = "🌟  ENTRAR AL MUNDO"; select_enter_btn.disabled = true
	_style_button(select_enter_btn, true); select_enter_btn.add_theme_font_size_override("font_size", 13)
	select_enter_btn.pressed.connect(_on_enter_btn_pressed); btns_vbox.add_child(select_enter_btn)

	var btns_row2 := HBoxContainer.new()
	btns_row2.add_theme_constant_override("separation", 6); btns_vbox.add_child(btns_row2)

	select_delete_btn = Button.new()
	select_delete_btn.custom_minimum_size = Vector2(0, 34); select_delete_btn.layout_mode = 2
	select_delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_delete_btn.text = "🗑 Eliminar"; select_delete_btn.disabled = true
	_style_button(select_delete_btn, false, true); select_delete_btn.add_theme_font_size_override("font_size", 11)
	select_delete_btn.pressed.connect(_on_delete_btn_pressed); btns_row2.add_child(select_delete_btn)

	var logout_btn := Button.new()
	logout_btn.custom_minimum_size = Vector2(0, 34); logout_btn.layout_mode = 2
	logout_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL; logout_btn.text = "← Salir"
	_style_button(logout_btn); logout_btn.add_theme_font_size_override("font_size", 11)
	logout_btn.pressed.connect(_on_logout_btn_pressed); btns_row2.add_child(logout_btn)

	var center_zone := Control.new()
	center_zone.layout_mode = 0
	center_zone.anchor_left = 0.0; center_zone.anchor_right = 1.0
	center_zone.anchor_top = 0.0; center_zone.anchor_bottom = 1.0
	center_zone.offset_right = -270.0; center_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center_zone)

	_select_char_preview = Control.new()
	_select_char_preview.layout_mode = 0
	_select_char_preview.anchor_left = 0.5; _select_char_preview.anchor_right = 0.5
	_select_char_preview.anchor_top = 0.5; _select_char_preview.anchor_bottom = 0.5
	_select_char_preview.offset_left = -90.0; _select_char_preview.offset_right = 90.0
	_select_char_preview.offset_top = -130.0; _select_char_preview.offset_bottom = 100.0
	_select_char_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_zone.add_child(_select_char_preview)

	_select_char_name_lbl = Label.new()
	_select_char_name_lbl.layout_mode = 0
	_select_char_name_lbl.anchor_left = 0.5; _select_char_name_lbl.anchor_right = 0.5
	_select_char_name_lbl.anchor_top = 0.5; _select_char_name_lbl.anchor_bottom = 0.5
	_select_char_name_lbl.offset_left = -160.0; _select_char_name_lbl.offset_right = 160.0
	_select_char_name_lbl.offset_top = 108.0; _select_char_name_lbl.offset_bottom = 136.0
	_select_char_name_lbl.add_theme_font_size_override("font_size", 20)
	_select_char_name_lbl.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	_select_char_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_select_char_name_lbl.text = ""; center_zone.add_child(_select_char_name_lbl)

	_select_char_info_lbl = Label.new()
	_select_char_info_lbl.layout_mode = 0
	_select_char_info_lbl.anchor_left = 0.5; _select_char_info_lbl.anchor_right = 0.5
	_select_char_info_lbl.anchor_top = 0.5; _select_char_info_lbl.anchor_bottom = 0.5
	_select_char_info_lbl.offset_left = -160.0; _select_char_info_lbl.offset_right = 160.0
	_select_char_info_lbl.offset_top = 136.0; _select_char_info_lbl.offset_bottom = 165.0
	_select_char_info_lbl.add_theme_font_size_override("font_size", 11)
	_select_char_info_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	_select_char_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_select_char_info_lbl.text = "Selecciona un personaje para previsualizarlo"
	center_zone.add_child(_select_char_info_lbl)

	_addons_panel = _build_addons_panel(root); root.add_child(_addons_panel)

	var addons_btn := Button.new()
	addons_btn.layout_mode = 0
	addons_btn.anchor_bottom = 1.0; addons_btn.anchor_top = 1.0
	addons_btn.offset_left = 16; addons_btn.offset_right = 130
	addons_btn.offset_top = -110; addons_btn.offset_bottom = -76
	addons_btn.text = "⚙ Addons"; _style_button(addons_btn)
	addons_btn.add_theme_font_size_override("font_size", 11)
	addons_btn.pressed.connect(_on_addons_btn_pressed); root.add_child(addons_btn)

# ═══════════════════════════════════════════════════════════════════
# PANTALLA CREACIÓN DE PERSONAJE
# ═══════════════════════════════════════════════════════════════════
func _setup_create_screen() -> void:
	var root := screen_create
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_right = 1.0; root.anchor_bottom = 1.0

	var left_zone := Control.new()
	left_zone.layout_mode = 0; left_zone.anchor_right = 0.38
	left_zone.anchor_bottom = 1.0; left_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left_zone)

	var prev_container := Control.new()
	prev_container.layout_mode = 0
	prev_container.anchor_left = 0.5; prev_container.anchor_right = 0.5
	prev_container.anchor_top = 0.5; prev_container.anchor_bottom = 0.5
	prev_container.offset_left = -100.0; prev_container.offset_right = 100.0
	prev_container.offset_top = -160.0; prev_container.offset_bottom = 120.0
	prev_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_zone.add_child(prev_container)

	_preview_sprite = Sprite2D.new()
	_preview_sprite.position = Vector2(100, 145)
	_preview_sprite.scale = Vector2(5.0, 5.0)
	_preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_shader_mat = ShaderMaterial.new()
	var _shader_res := load("res://scripts/character_swap.gdshader")
	if _shader_res is Shader:
		_preview_shader_mat.shader = _shader_res
		_preview_sprite.material = _preview_shader_mat
	prev_container.add_child(_preview_sprite)

	var prev_name_lbl := Label.new(); prev_name_lbl.name = "PreviewNameLabel"
	prev_name_lbl.layout_mode = 0; prev_name_lbl.anchor_left = 0.0; prev_name_lbl.anchor_right = 1.0
	prev_name_lbl.anchor_top = 1.0; prev_name_lbl.anchor_bottom = 1.0
	prev_name_lbl.offset_top = -64.0; prev_name_lbl.offset_bottom = -38.0
	prev_name_lbl.add_theme_font_size_override("font_size", 16)
	prev_name_lbl.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	prev_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prev_name_lbl.text = ""; prev_container.add_child(prev_name_lbl)

	var prev_sub_lbl := Label.new(); prev_sub_lbl.name = "PreviewSubLabel"
	prev_sub_lbl.layout_mode = 0; prev_sub_lbl.anchor_left = 0.0; prev_sub_lbl.anchor_right = 1.0
	prev_sub_lbl.anchor_top = 1.0; prev_sub_lbl.anchor_bottom = 1.0
	prev_sub_lbl.offset_top = -36.0; prev_sub_lbl.offset_bottom = -14.0
	prev_sub_lbl.add_theme_font_size_override("font_size", 10)
	prev_sub_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	prev_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prev_sub_lbl.text = "Humano"; prev_container.add_child(prev_sub_lbl)

	var right_panel := PanelContainer.new()
	right_panel.layout_mode = 0
	right_panel.anchor_left = 0.38; right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0; right_panel.anchor_bottom = 1.0
	var rp_s := StyleBoxFlat.new()
	rp_s.bg_color = Color(0.014, 0.007, 0.040, 0.96)
	rp_s.border_width_left = 1; rp_s.border_color = Color(0.55, 0.42, 0.12, 0.18)
	rp_s.content_margin_left = 20; rp_s.content_margin_right = 20
	rp_s.content_margin_top = 14; rp_s.content_margin_bottom = 14
	right_panel.add_theme_stylebox_override("panel", rp_s); root.add_child(right_panel)

	var rp_vbox := VBoxContainer.new()
	rp_vbox.layout_mode = 2; rp_vbox.add_theme_constant_override("separation", 0)
	right_panel.add_child(rp_vbox)

	var rp_title := Label.new(); rp_title.text = "✦  CREA TU PERSONAJE  ✦"
	rp_title.add_theme_font_size_override("font_size", 12)
	rp_title.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	rp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rp_vbox.add_child(rp_title); rp_vbox.add_child(_make_separator())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rp_vbox.add_child(scroll)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.layout_mode = 2; inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.add_theme_constant_override("separation", 12); scroll.add_child(inner_vbox)

	inner_vbox.add_child(_build_section_label("Nombre"))
	char_name_field = LineEdit.new()
	char_name_field.custom_minimum_size = Vector2(0, 36); char_name_field.layout_mode = 2
	char_name_field.placeholder_text = "Ej: Kira, DarkBlade, Aelindra..."; char_name_field.max_length = 16
	char_name_field.add_theme_font_size_override("font_size", 13)
	char_name_field.text_changed.connect(func(_t): _update_preview())
	inner_vbox.add_child(char_name_field)

	char_error_lbl = Label.new()
	char_error_lbl.add_theme_color_override("font_color", C_RED_DANGER)
	char_error_lbl.add_theme_font_size_override("font_size", 10)
	char_error_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner_vbox.add_child(char_error_lbl)

	inner_vbox.add_child(_build_section_label("Raza"))
	var race_grid := GridContainer.new(); race_grid.columns = 2
	race_grid.add_theme_constant_override("h_separation", 6)
	race_grid.add_theme_constant_override("v_separation", 6); inner_vbox.add_child(race_grid)
	_race_btns.clear()
	for race in RACES:
		var btn := Button.new(); var locked : bool = race["locked"]
		btn.text = "%s  %s%s" % [race["icon"], race["label"], " 🔒" if locked else ""]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if locked: _style_button(btn); btn.modulate = Color(0.55, 0.55, 0.65)
		else: _style_button(btn, race["id"] == _selected_race)
		var race_id : String = race["id"]
		btn.pressed.connect(func(): _select_race(race_id))
		race_grid.add_child(btn); _race_btns.append({"btn": btn, "id": race_id})

	_race_desc_lbl = Label.new()
	_race_desc_lbl.add_theme_font_size_override("font_size", 9)
	_race_desc_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	_race_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_race_desc_lbl.custom_minimum_size = Vector2(0, 36)
	inner_vbox.add_child(_race_desc_lbl); _update_race_desc()

	# ── Género ──────────────────────────────────────────────────────
	inner_vbox.add_child(_build_section_label("Género"))
	var gender_row := HBoxContainer.new()
	gender_row.add_theme_constant_override("separation", 8)
	gender_row.layout_mode = 2
	inner_vbox.add_child(gender_row)

	gender_male_btn = Button.new()
	gender_male_btn.text = "♂  Masculino"
	gender_male_btn.custom_minimum_size = Vector2(0, 34)
	gender_male_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gender_male_btn.add_theme_font_size_override("font_size", 11)
	_style_button(gender_male_btn, _selected_gender == "male")
	gender_male_btn.pressed.connect(func(): _on_male_btn_pressed())
	gender_row.add_child(gender_male_btn)

	gender_female_btn = Button.new()
	gender_female_btn.text = "♀  Femenino"
	gender_female_btn.custom_minimum_size = Vector2(0, 34)
	gender_female_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gender_female_btn.add_theme_font_size_override("font_size", 11)
	_style_button(gender_female_btn, _selected_gender == "female")
	gender_female_btn.pressed.connect(func(): _on_female_btn_pressed())
	gender_row.add_child(gender_female_btn)

	inner_vbox.add_child(_build_section_label("Peinado"))
	var hair_row := HBoxContainer.new(); hair_row.add_theme_constant_override("separation", 6)
	inner_vbox.add_child(hair_row)
	var btn_prev := Button.new(); btn_prev.text = "◀"; btn_prev.custom_minimum_size = Vector2(30, 30)
	btn_prev.add_theme_font_size_override("font_size", 13); _style_button(btn_prev)
	btn_prev.pressed.connect(func(): _change_hair(-1))
	_hair_nav_label = Label.new(); _hair_nav_label.add_theme_font_size_override("font_size", 11)
	_hair_nav_label.add_theme_color_override("font_color", C_TEXT_LIGHT)
	_hair_nav_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hair_nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn_next := Button.new(); btn_next.text = "▶"; btn_next.custom_minimum_size = Vector2(30, 30)
	btn_next.add_theme_font_size_override("font_size", 13); _style_button(btn_next)
	btn_next.pressed.connect(func(): _change_hair(1))
	hair_row.add_child(btn_prev); hair_row.add_child(_hair_nav_label); hair_row.add_child(btn_next)
	_update_hair_nav_label()

	inner_vbox.add_child(_build_section_label("Color de Piel"))
	inner_vbox.add_child(_build_swatch_row("", SKIN_PRESETS, SKIN_LABELS, _skin_btns,
		func(i: int): _selected_skin = SKIN_PRESETS[i]; _update_preview()))
	inner_vbox.add_child(_build_section_label("Color de Cabello"))
	inner_vbox.add_child(_build_swatch_row("", HAIR_COLOR_PRESETS, HAIR_COLOR_LABELS,
		_hair_color_btns, func(i: int): _selected_hair_color = HAIR_COLOR_PRESETS[i]; _update_preview()))
	inner_vbox.add_child(_build_section_label("Color de Ojos"))
	inner_vbox.add_child(_build_swatch_row("", EYE_COLOR_PRESETS, EYE_COLOR_LABELS,
		_eye_color_btns, func(i: int): _selected_eye_color = EYE_COLOR_PRESETS[i]; _update_preview()))
	inner_vbox.add_child(_build_section_label("Color de Ropa"))
	inner_vbox.add_child(_build_swatch_row("", OUTFIT_PRESETS, OUTFIT_LABELS,
		_outfit_btns, func(i: int): _selected_outfit = OUTFIT_PRESETS[i]; _update_preview()))
	inner_vbox.add_child(_make_separator())

	rp_vbox.add_child(_make_separator())
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8); rp_vbox.add_child(action_row)

	var enter_btn := Button.new()
	enter_btn.custom_minimum_size = Vector2(0, 44); enter_btn.layout_mode = 2
	enter_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enter_btn.text = "✨  CREAR PERSONAJE"; _style_button(enter_btn, true)
	enter_btn.add_theme_font_size_override("font_size", 12)
	enter_btn.pressed.connect(_on_enter_create_btn_pressed); action_row.add_child(enter_btn)

	var back_btn := Button.new()
	back_btn.custom_minimum_size = Vector2(80, 44); back_btn.layout_mode = 2
	back_btn.text = "← Volver"; _style_button(back_btn)
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.pressed.connect(_on_cancel_create_btn_pressed); action_row.add_child(back_btn)

	_update_preview()

func _build_section_label(text: String) -> HBoxContainer:
	var hbox := HBoxContainer.new(); hbox.add_theme_constant_override("separation", 6)
	var l_line := ColorRect.new()
	l_line.custom_minimum_size = Vector2(0, 1); l_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER; l_line.color = Color(0.55, 0.45, 0.15, 0.25)
	hbox.add_child(l_line)
	var lbl := Label.new(); lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; hbox.add_child(lbl)
	var r_line := ColorRect.new()
	r_line.custom_minimum_size = Vector2(0, 1); r_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER; r_line.color = Color(0.55, 0.45, 0.15, 0.25)
	hbox.add_child(r_line); return hbox

func _build_swatch_row(label_text: String, presets: Array, _labels: Array,
					   btn_arr: Array, callback: Callable) -> HBoxContainer:
	btn_arr.clear()
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
	if label_text != "":
		var lbl := Label.new(); lbl.text = label_text
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", C_TEXT_DIM)
		lbl.custom_minimum_size = Vector2(72, 0); row.add_child(lbl)
	for i in range(presets.size()):
		var swatch := Button.new(); swatch.custom_minimum_size = Vector2(22, 22)
		swatch.add_theme_font_size_override("font_size", 8)
		var col : Color = presets[i]
		var sw_s := StyleBoxFlat.new(); sw_s.bg_color = col
		sw_s.set_border_width_all(2); sw_s.border_color = C_BORDER_DIM; sw_s.set_corner_radius_all(3)
		swatch.add_theme_stylebox_override("normal", sw_s)
		var sw_h := sw_s.duplicate() as StyleBoxFlat; sw_h.border_color = C_GOLD_BRIGHT
		swatch.add_theme_stylebox_override("hover", sw_h); swatch.add_theme_stylebox_override("pressed", sw_h)
		var idx := i
		swatch.pressed.connect(func(): callback.call(idx); _refresh_swatches(btn_arr, idx, sw_h))
		row.add_child(swatch); btn_arr.append({"btn": swatch, "normal": sw_s, "hover": sw_h})
	return row

func _refresh_swatches(btn_arr: Array, sel_idx: int, _sel_style: StyleBoxFlat) -> void:
	for i in range(btn_arr.size()):
		var d : Dictionary = btn_arr[i]; var sw : Button = d["btn"]
		if i == sel_idx: sw.add_theme_stylebox_override("normal", d["hover"])
		else: sw.add_theme_stylebox_override("normal", d["normal"])

func _update_preview() -> void:
	if not is_instance_valid(_preview_sprite): return
	var path := "res://assets/characters/player/player_%s_idle_strip9.png" % _selected_hair
	if ResourceLoader.exists(path):
		_preview_sprite.texture = load(path); _preview_sprite.hframes = 9; _preview_sprite.frame = 0
		if is_instance_valid(_preview_shader_mat):
			_preview_shader_mat.set_shader_parameter("skin_color",   _selected_skin)
			_preview_shader_mat.set_shader_parameter("hair_color",   _selected_hair_color)
			_preview_shader_mat.set_shader_parameter("eye_color",    _selected_eye_color)
			_preview_shader_mat.set_shader_parameter("outfit_color", _selected_outfit)
	else:
		_preview_sprite.texture = null
	var prev_cont := _preview_sprite.get_parent()
	if is_instance_valid(prev_cont):
		var name_lbl := prev_cont.get_node_or_null("PreviewNameLabel")
		if is_instance_valid(name_lbl) and name_lbl is Label:
			var n : String = ""
			if is_instance_valid(char_name_field): n = char_name_field.text
			name_lbl.text = n
		var sub_lbl := prev_cont.get_node_or_null("PreviewSubLabel")
		if is_instance_valid(sub_lbl) and sub_lbl is Label:
			sub_lbl.text = _get_race_label(_selected_race)

func _select_race(race_id: String) -> void:
	_selected_race = race_id
	for d in _race_btns:
		var btn : Button = d["btn"]; var rid : String = d["id"]
		_style_button(btn, rid == race_id and not (func():
			for r in RACES:
				if r["id"] == rid: return r["locked"]
			return false).call())
	_update_race_desc(); _update_preview()

func _update_race_desc() -> void:
	if not is_instance_valid(_race_desc_lbl): return
	for r in RACES:
		if r["id"] == _selected_race:
			_race_desc_lbl.text = r["lore"] + "\n" + r["stats"]
			_race_desc_lbl.add_theme_color_override("font_color", r["color"] as Color); break

func _change_hair(dir: int) -> void:
	_hair_style_index = (_hair_style_index + dir + HAIR_STYLES_LIST.size()) % HAIR_STYLES_LIST.size()
	_selected_hair = HAIR_STYLES_LIST[_hair_style_index]; _update_hair_nav_label(); _update_preview()

func _update_hair_nav_label() -> void:
	if is_instance_valid(_hair_nav_label): _hair_nav_label.text = HAIR_LABELS[_hair_style_index]

# ═══════════════════════════════════════════════════════════════════
# NAVEGACIÓN DE PANTALLAS
# ═══════════════════════════════════════════════════════════════════
func _show_login() -> void:
	screen_login.visible = true; screen_select.visible = false; screen_create.visible = false
	if is_instance_valid(_screen_register): _screen_register.visible = false
	login_error_lbl.add_theme_color_override("font_color", C_RED_DANGER)
	if is_instance_valid(_title_label): _title_label.visible = true
	var sub := get_node_or_null("SubtitleLabel"); if sub: sub.visible = true
	var root_node := $BgBase.get_parent()
	if root_node:
		var dg := root_node.get_node_or_null("TitleDecoGroup"); if dg: dg.visible = true

func _show_select() -> void:
	_load_slots()
	screen_login.visible = false; screen_select.visible = true; screen_create.visible = false
	if is_instance_valid(_screen_register): _screen_register.visible = false
	_selected_slot = -1; _refresh_slot_panels(); _refresh_select_buttons()
	if is_instance_valid(_title_label): _title_label.visible = true
	var sub := get_node_or_null("SubtitleLabel"); if sub: sub.visible = true
	var root_node := $BgBase.get_parent()
	if root_node:
		var dg := root_node.get_node_or_null("TitleDecoGroup"); if dg: dg.visible = true
	# Cargar datos del servidor y reconstruir _slots con los personajes del servidor
	_server_load_player(func(data):
		if data == null: return
		# FIX APK: reconstruir _slots[] desde los datos del servidor
		var server_slots: Array = data.get("slots", [])
		var unlk: Array         = data.get("unlocked", [])
		var changed := false
		for i in range(min(server_slots.size(), MAX_SLOTS)):
			var sv = server_slots[i]
			if sv == null:
				continue
			var ch = sv.get("character", null)
			if not (ch is Dictionary) or not ch.has("name"):
				continue
			# Solo sobrescribir si el slot local está vacío o tiene datos más viejos
			if _slots[i] == null or _slots[i].get("name", "") == "":
				_slots[i] = {
					"name":       ch.get("name", "?"),
					"gender":     ch.get("gender", "male"),
					"race":       ch.get("race", "human"),
					"hair_style": ch.get("hair_style", "spikeyhair"),
					"skin_r": ch.get("skin_r", 0.96), "skin_g": ch.get("skin_g", 0.78), "skin_b": ch.get("skin_b", 0.64),
					"hair_r": ch.get("hair_r", 0.25), "hair_g": ch.get("hair_g", 0.15), "hair_b": ch.get("hair_b", 0.08),
					"eye_r":  ch.get("eye_r", 0.2),   "eye_g":  ch.get("eye_g", 0.5),   "eye_b":  ch.get("eye_b", 0.9),
					"outfit_r": ch.get("outfit_r", 1.0), "outfit_g": ch.get("outfit_g", 1.0), "outfit_b": ch.get("outfit_b", 1.0),
					"level":  ch.get("level", 1),
					"xp":     ch.get("xp", 0),
					"max_hp": ch.get("max_hp", 100),
					"hp":     ch.get("hp", 100),
					"bronze": ch.get("bronze", 0),
					"silver": ch.get("silver", 0),
					"gold":   ch.get("gold", 0),
					"zone":   ch.get("zone", "Inicio"),
				}
				changed = true
			else:
				# Actualizar stats del slot existente con los del servidor
				_slots[i]["gold"]   = ch.get("gold",  _slots[i].get("gold", 0))
				_slots[i]["silver"] = ch.get("silver", _slots[i].get("silver", 0))
				_slots[i]["bronze"] = ch.get("bronze", _slots[i].get("bronze", 0))
				_slots[i]["xp"]     = ch.get("xp",    _slots[i].get("xp", 0))
				_slots[i]["level"]  = ch.get("level",  _slots[i].get("level", 1))
				changed = true
		# Desbloquear slots según el servidor
		for i in range(min(unlk.size(), MAX_SLOTS)):
			if unlk[i] == true and not _slot_unlocked[i]:
				_slot_unlocked[i] = true; changed = true
		if changed:
			_save_slots(); _sync_account_gold(); _refresh_slot_panels()
	)

func _show_create(slot_idx: int) -> void:
	_creating_slot = slot_idx
	screen_login.visible = false; screen_select.visible = false; screen_create.visible = true
	char_name_field.text = ""; char_error_lbl.text = ""
	_selected_gender = "male"; _select_gender("male"); _update_preview()
	if is_instance_valid(_title_label): _title_label.visible = false
	var sub := get_node_or_null("SubtitleLabel"); if sub: sub.visible = false
	var root_node := $BgBase.get_parent()
	if root_node:
		var dg := root_node.get_node_or_null("TitleDecoGroup"); if dg: dg.visible = false

# ═══════════════════════════════════════════════════════════════════
# SLOTS DE PERSONAJE
# ═══════════════════════════════════════════════════════════════════
func _get_slots_path() -> String:
	# FIX APK: usar gmail como fallback si _logged_user aún está vacío (race condition async login)
	var uid := _logged_user.strip_edges()
	if uid.is_empty():
		uid = _logged_gmail.split("@")[0].strip_edges()
	if uid.is_empty():
		uid = "default"
	return "user://slots_%s.save" % uid.to_lower()

func _load_slots() -> void:
	_slots.clear(); _slot_unlocked.clear(); _account_gold = 0
	var path := _get_slots_path()
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var data : Variant = JSON.parse_string(f.get_as_text()); f.close()
		if data is Dictionary:
			_account_gold = data.get("account_gold", 0)
			var saved : Array = data.get("slots", [])
			var unlk  : Array = data.get("unlocked", [true,false,false,false])
			for i in range(MAX_SLOTS):
				_slots.append(saved[i] if i < saved.size() else null)
				_slot_unlocked.append(unlk[i] if i < unlk.size() else (i == 0))
			if _slot_unlocked.size() > 0: _slot_unlocked[0] = true
			return
	for i in range(MAX_SLOTS):
		_slots.append(null); _slot_unlocked.append(i == 0)

func _save_slots() -> void:
	var f := FileAccess.open(_get_slots_path(), FileAccess.WRITE)
	if not f: return
	f.store_string(JSON.stringify({"account_gold": _account_gold, "slots": _slots, "unlocked": _slot_unlocked}))
	f.close()

func _refresh_slot_panels() -> void:
	for p in _slot_panels:
		if is_instance_valid(p): p.queue_free()
	_slot_panels.clear()
	account_gold_lbl.text = "💰 %d oro de cuenta" % _account_gold
	for i in range(MAX_SLOTS):
		var p := _make_wow_slot_panel(i)
		slots_container.add_child(p); _slot_panels.append(p)
	_refresh_center_preview()

func _refresh_center_preview() -> void:
	if not is_instance_valid(_select_char_preview): return
	for ch in _select_char_preview.get_children(): ch.queue_free()
	if _selected_slot < 0 or _selected_slot >= _slots.size():
		_select_char_name_lbl.text = ""
		_select_char_info_lbl.text = "Selecciona un personaje para previsualizarlo"; return
	var char_data : Variant = _slots[_selected_slot]
	if char_data == null:
		_select_char_name_lbl.text = ""; _select_char_info_lbl.text = "Slot vacío — crea tu héroe"; return
	var hair   : String = char_data.get("hair_style", "spikeyhair")
	var skin           := Color(char_data.get("skin_r",0.96), char_data.get("skin_g",0.78), char_data.get("skin_b",0.64))
	var hair_col       := Color(char_data.get("hair_r",0.071), char_data.get("hair_g",0.071), char_data.get("hair_b",0.071))
	var eye_col        := Color(char_data.get("eye_r",0.15), char_data.get("eye_g",0.35), char_data.get("eye_b",0.75))
	var outfit_col     := Color(char_data.get("outfit_r",0.22), char_data.get("outfit_g",0.42), char_data.get("outfit_b",0.88))
	var idle_path      := "res://assets/characters/player/player_%s_idle_strip9.png" % hair
	if ResourceLoader.exists(idle_path):
		var sp := Sprite2D.new(); sp.texture = load(idle_path)
		sp.hframes = 9; sp.frame = 0; sp.scale = Vector2(5.0, 5.0)
		sp.position = Vector2(90, 120); sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var shader_res := load("res://scripts/character_swap.gdshader")
		if shader_res is Shader:
			var mat := ShaderMaterial.new(); mat.shader = shader_res
			mat.set_shader_parameter("skin_color", skin); mat.set_shader_parameter("hair_color", hair_col)
			mat.set_shader_parameter("eye_color", eye_col); mat.set_shader_parameter("outfit_color", outfit_col)
			sp.material = mat
		_select_char_preview.add_child(sp)
		_select_char_preview_sprite = sp; _select_char_anim_timer = 0.0; _select_char_anim_frame = 0
	var name_str : String = char_data.get("name", "?")
	var level    : int    = char_data.get("level", 1)
	var race_lbl : String = _get_race_label(char_data.get("race", "human"))
	_select_char_name_lbl.text = name_str
	_select_char_info_lbl.text = "Nivel %d  —  %s  —  📍 %s" % [level, race_lbl, char_data.get("zone","Inicio")]

func _make_wow_slot_panel(idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 72)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var char_data : Variant = _slots[idx]
	var unlocked  : bool    = _slot_unlocked[idx]
	var is_sel    : bool    = _selected_slot == idx
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(3); s.set_border_width_all(1)
	s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top = 8;  s.content_margin_bottom = 8
	s.shadow_size = 6 if is_sel else 2; s.shadow_offset = Vector2(2, 2)
	if not unlocked:
		s.bg_color = Color(0.025, 0.015, 0.060, 0.85); s.border_color = Color(0.22, 0.15, 0.38, 0.4)
		s.shadow_color = Color(0,0,0,0.3)
	elif is_sel:
		s.bg_color = Color(0.055, 0.028, 0.100, 0.90); s.border_color = C_BORDER_GOLD
		s.shadow_color = Color(0.72, 0.58, 0.18, 0.45)
	elif char_data != null:
		s.bg_color = Color(0.035, 0.018, 0.075, 0.85); s.border_color = Color(0.32, 0.25, 0.08, 0.4)
		s.shadow_color = Color(0,0,0,0.25)
	else:
		s.bg_color = Color(0.04, 0.08, 0.06, 0.92); s.border_color = Color(0.30, 0.72, 0.40, 0.80)
		s.shadow_color = Color(0.10, 0.40, 0.15, 0.30); s.shadow_size = 4
	panel.add_theme_stylebox_override("panel", s)
	var bar := ColorRect.new(); bar.layout_mode = 0
	bar.anchor_top = 0.0; bar.anchor_bottom = 1.0; bar.offset_right = 3
	bar.color = C_GOLD_BRIGHT if is_sel else (C_GOLD_DIM if char_data != null else Color(0.28, 0.78, 0.38, 0.90))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_child(bar)
	var hbox := HBoxContainer.new(); hbox.layout_mode = 2
	hbox.add_theme_constant_override("separation", 10); panel.add_child(hbox)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(44, 52); portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		var lock_l := Label.new(); lock_l.text = "🔒"; lock_l.add_theme_font_size_override("font_size", 22)
		lock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lock_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_l.layout_mode = 0; lock_l.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_l.modulate = Color(1,1,1,0.4); portrait.add_child(lock_l)
	elif char_data != null:
		var hair : String = char_data.get("hair_style", "spikeyhair")
		var skin := Color(char_data.get("skin_r",0.96), char_data.get("skin_g",0.78), char_data.get("skin_b",0.64))
		var hc   := Color(char_data.get("hair_r",0.071), char_data.get("hair_g",0.071), char_data.get("hair_b",0.071))
		var ec   := Color(char_data.get("eye_r",0.15), char_data.get("eye_g",0.35), char_data.get("eye_b",0.75))
		var oc   := Color(char_data.get("outfit_r",0.22), char_data.get("outfit_g",0.42), char_data.get("outfit_b",0.88))
		var idle_path := "res://assets/characters/player/player_%s_idle_strip9.png" % hair
		if ResourceLoader.exists(idle_path):
			var sp := Sprite2D.new(); sp.texture = load(idle_path)
			sp.hframes = 9; sp.frame = 0; sp.scale = Vector2(1.8, 1.8)
			sp.position = Vector2(22, 34); sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var sr := load("res://scripts/character_swap.gdshader")
			if sr is Shader:
				var m := ShaderMaterial.new(); m.shader = sr
				m.set_shader_parameter("skin_color", skin); m.set_shader_parameter("hair_color", hc)
				m.set_shader_parameter("eye_color", ec); m.set_shader_parameter("outfit_color", oc)
				sp.material = m
			portrait.add_child(sp)
	else:
		var plus_l := Label.new(); plus_l.text = "+"
		plus_l.add_theme_font_size_override("font_size", 30)
		plus_l.add_theme_color_override("font_color", Color(0.35, 0.90, 0.50, 1.0))
		plus_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; plus_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus_l.layout_mode = 0; plus_l.set_anchors_preset(Control.PRESET_FULL_RECT); portrait.add_child(plus_l)
	hbox.add_child(portrait)
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 2); hbox.add_child(info_vbox)
	if not unlocked:
		var lbl1 := Label.new(); lbl1.text = "Bloqueado"
		lbl1.add_theme_font_size_override("font_size", 11)
		lbl1.add_theme_color_override("font_color", Color(0.55,0.42,0.80,0.6)); info_vbox.add_child(lbl1)
		var lbl2 := Label.new(); lbl2.text = "💰 %d g para desbloquear" % SLOT_UNLOCK_COST[idx]
		lbl2.add_theme_font_size_override("font_size", 9)
		lbl2.add_theme_color_override("font_color", C_GOLD_DIM); info_vbox.add_child(lbl2)
	elif char_data != null:
		var name_lbl := Label.new(); name_lbl.text = char_data.get("name", "?")
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", C_GOLD_BRIGHT if is_sel else C_GOLD_MID)
		name_lbl.clip_text = true; info_vbox.add_child(name_lbl)
		var sub_lbl := Label.new()
		sub_lbl.text = "Nv.%d  %s" % [char_data.get("level",1), _get_race_label(char_data.get("race","human"))]
		sub_lbl.add_theme_font_size_override("font_size", 10)
		sub_lbl.add_theme_color_override("font_color", C_TEXT_DIM); info_vbox.add_child(sub_lbl)
		var zone_lbl := Label.new(); zone_lbl.text = "📍 %s" % char_data.get("zone","Inicio")
		zone_lbl.add_theme_font_size_override("font_size", 9)
		zone_lbl.add_theme_color_override("font_color", C_TEXT_MUTED); info_vbox.add_child(zone_lbl)
	else:
		var free_badge := Label.new(); free_badge.text = "✨ RANURA LIBRE"
		free_badge.add_theme_font_size_override("font_size", 9)
		free_badge.add_theme_color_override("font_color", Color(0.35, 0.90, 0.50, 1.0)); info_vbox.add_child(free_badge)
		var create_lbl := Label.new(); create_lbl.text = "Crear personaje"
		create_lbl.add_theme_font_size_override("font_size", 12)
		create_lbl.add_theme_color_override("font_color", Color(0.70, 0.95, 0.75, 1.0)); info_vbox.add_child(create_lbl)
	if is_sel:
		var arrow := Label.new(); arrow.text = "◀"
		arrow.add_theme_font_size_override("font_size", 14)
		arrow.add_theme_color_override("font_color", C_GOLD_BRIGHT)
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hbox.add_child(arrow)
	var click_btn := Button.new(); click_btn.layout_mode = 0
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT); click_btn.flat = true
	var flat_s := StyleBoxEmpty.new()
	click_btn.add_theme_stylebox_override("normal", flat_s); click_btn.add_theme_stylebox_override("hover", flat_s)
	click_btn.add_theme_stylebox_override("pressed", flat_s); click_btn.add_theme_stylebox_override("focus", flat_s)
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
	if not unlocked: click_btn.pressed.connect(func(): _on_unlock_slot(idx))
	elif char_data != null: click_btn.pressed.connect(func(): _on_select_slot(idx))
	else: click_btn.pressed.connect(func(): _on_create_slot(idx))
	panel.add_child(click_btn); return panel

func _get_race_emoji(race_id: String) -> String:
	for r in RACES: if r["id"] == race_id: return r["icon"]
	return "⚔"

func _get_race_label(race_id: String) -> String:
	for r in RACES: if r["id"] == race_id: return r["label"]
	return "Humano"

func _refresh_select_buttons() -> void:
	var has_char := _selected_slot >= 0 and _slots[_selected_slot] != null
	select_enter_btn.disabled  = not has_char
	select_delete_btn.disabled = not has_char

# ═══════════════════════════════════════════════════════════════════
# PANEL ADDONS
# ═══════════════════════════════════════════════════════════════════
func _build_addons_panel(_parent: Control) -> Control:
	var overlay := PanelContainer.new(); overlay.layout_mode = 0
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP; overlay.visible = false
	var overlay_s := StyleBoxFlat.new(); overlay_s.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.add_theme_stylebox_override("panel", overlay_s)
	var win := PanelContainer.new(); win.layout_mode = 0
	win.anchor_left = 0.5; win.anchor_right = 0.5; win.anchor_top = 0.5; win.anchor_bottom = 0.5
	win.offset_left = -260; win.offset_right = 260; win.offset_top = -220; win.offset_bottom = 220
	var win_s := StyleBoxFlat.new(); win_s.bg_color = Color(0.016, 0.008, 0.050, 0.98)
	win_s.set_border_width_all(1); win_s.border_color = Color(0.55, 0.42, 0.12, 0.55)
	win_s.set_corner_radius_all(5); win_s.shadow_size = 12; win_s.shadow_color = Color(0,0,0,0.6)
	win.add_theme_stylebox_override("panel", win_s); overlay.add_child(win)
	var vbox := VBoxContainer.new(); vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 10); win.add_child(vbox)
	var title := Label.new(); title.text = "⚙  ADDONS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(title)
	vbox.add_child(_make_separator(true))
	var addons_data := [
		{"name": "Sakura UI Pack",    "desc": "Mejora visual de la interfaz.",         "status": "Activo",        "color": Color(0.3, 0.8, 0.3)},
		{"name": "Mapa Minimapa",     "desc": "Minimapa durante exploración.",          "status": "Próximamente",  "color": Color(0.6, 0.6, 0.2)},
		{"name": "Chat Global",       "desc": "Canal de chat entre jugadores.",         "status": "Próximamente",  "color": Color(0.6, 0.6, 0.2)},
		{"name": "Sistema de Guilds", "desc": "Crea y únete a guilds.",                 "status": "En desarrollo", "color": Color(0.5, 0.5, 0.7)},
	]
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(0, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; vbox.add_child(scroll)
	var list_vbox := VBoxContainer.new(); list_vbox.layout_mode = 2
	list_vbox.add_theme_constant_override("separation", 6)
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(list_vbox)
	for addon in addons_data:
		var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_s := StyleBoxFlat.new(); card_s.bg_color = Color(0.03, 0.015, 0.07, 0.9)
		card_s.set_border_width_all(1); card_s.border_color = Color(0.30, 0.22, 0.08, 0.4)
		card_s.set_corner_radius_all(3); card_s.content_margin_left = 12; card_s.content_margin_right = 12
		card_s.content_margin_top = 8; card_s.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_s); list_vbox.add_child(card)
		var row := HBoxContainer.new(); row.layout_mode = 2; row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2); row.add_child(info)
		var name_lbl := Label.new(); name_lbl.text = addon["name"]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", C_GOLD_MID); info.add_child(name_lbl)
		var desc_lbl := Label.new(); desc_lbl.text = addon["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 9)
		desc_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.add_child(desc_lbl)
		var status_lbl := Label.new(); status_lbl.text = addon["status"]
		status_lbl.add_theme_font_size_override("font_size", 10)
		status_lbl.add_theme_color_override("font_color", addon["color"])
		status_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(status_lbl)
	vbox.add_child(_make_separator(true))
	var close_btn := Button.new(); close_btn.text = "✕  Cerrar"
	close_btn.custom_minimum_size = Vector2(0, 36); close_btn.layout_mode = 2
	_style_button(close_btn); close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(func(): overlay.visible = false); vbox.add_child(close_btn)
	return overlay

func _on_addons_btn_pressed() -> void:
	if is_instance_valid(_addons_panel): _addons_panel.visible = true

# ═══════════════════════════════════════════════════════════════════
# ACCIONES DE SLOT
# ═══════════════════════════════════════════════════════════════════
func _on_select_slot(idx: int) -> void:
	_selected_slot = idx; _refresh_slot_panels(); _refresh_select_buttons()

func _on_create_slot(idx: int) -> void:
	if not _slot_unlocked[idx]: return; _show_create(idx)

func _on_unlock_slot(idx: int) -> void:
	var cost : int = SLOT_UNLOCK_COST[idx]
	if _account_gold < cost:
		select_error_lbl.text = "⚠ Necesitas %d 💰 — tienes %d." % [cost, _account_gold]; return
	_account_gold -= cost; _slot_unlocked[idx] = true; _save_slots()
	select_error_lbl.text = "✅ ¡Slot %d desbloqueado!" % (idx + 1)
	_refresh_slot_panels(); _refresh_select_buttons()

func _on_enter_btn_pressed() -> void:
	if _selected_slot < 0 or _slots[_selected_slot] == null:
		select_error_lbl.text = "⚠ Selecciona un personaje primero."; return
	var d : Dictionary = _slots[_selected_slot]
	PlayerData.character_name   = d.get("name",   "Aventurero")
	PlayerData.character_gender = d.get("gender", "male")
	PlayerData.race             = d.get("race",   "human")
	PlayerData.hair_style       = d.get("hair_style", "spikeyhair")
	PlayerData.skin_color       = Color(d.get("skin_r",0.96), d.get("skin_g",0.78), d.get("skin_b",0.64))
	PlayerData.hair_color       = Color(d.get("hair_r",0.25), d.get("hair_g",0.15), d.get("hair_b",0.08))
	PlayerData.eye_color        = Color(d.get("eye_r",0.2),   d.get("eye_g",0.5),   d.get("eye_b",0.9))
	PlayerData.outfit_color     = Color(d.get("outfit_r",1.0),d.get("outfit_g",1.0),d.get("outfit_b",1.0))
	PlayerData.level            = d.get("level", 1)
	PlayerData.xp               = d.get("xp",    0)
	PlayerData.max_hp           = d.get("max_hp", 100)
	PlayerData.hp               = d.get("hp",    100)
	PlayerData.bronze           = d.get("bronze", 0)
	PlayerData.silver           = d.get("silver", 0)
	PlayerData.gold             = d.get("gold",   0)
	_sync_account_gold()
	# Guardar en servidor antes de entrar
	_server_save_player()
	# Registrar callback para guardar en servidor cuando la app se cierre/pause
	PlayerData.server_save_callback = Callable(self, "save_active_slot_gold")
	if PlayerData.character_name == "DrakeDev" or PlayerData.character_name == "👑 DrakeDev":
		PlayerData.activate_drake_mode()
	_go_to_town()

func _on_delete_btn_pressed() -> void:
	if _selected_slot < 0 or _slots[_selected_slot] == null: return
	var cname : String = _slots[_selected_slot].get("name","?")
	if select_delete_btn.text == "🗑  Eliminar":
		select_delete_btn.text = "⚠  ¿Confirmar?"
		select_error_lbl.text  = "⚠ Confirma para borrar a '%s'." % cname
		await get_tree().create_timer(3.0).timeout
		select_delete_btn.text = "🗑  Eliminar"; select_error_lbl.text = ""
	else:
		_slots[_selected_slot] = null; _save_slots(); _selected_slot = -1
		select_delete_btn.text = "🗑  Eliminar"; select_error_lbl.text = "Personaje eliminado."
		_refresh_slot_panels(); _refresh_select_buttons()

func _on_logout_btn_pressed() -> void:
	_logged_user = ""; _logged_gmail = ""; _logged_password = ""; _show_login()

# ═══════════════════════════════════════════════════════════════════
# CREAR PERSONAJE
# ═══════════════════════════════════════════════════════════════════
func _select_gender(g: String) -> void:
	_selected_gender = g; _update_preview()
	if is_instance_valid(gender_male_btn):   _style_button(gender_male_btn,   g == "male")
	if is_instance_valid(gender_female_btn): _style_button(gender_female_btn, g == "female")

func _on_male_btn_pressed()   -> void: _select_gender("male")
func _on_female_btn_pressed() -> void: _select_gender("female")

func _on_enter_create_btn_pressed() -> void:
	var cname := char_name_field.text.strip_edges()
	if cname.length() < 2: char_error_lbl.text = "⚠ Mínimo 2 caracteres."; return
	if cname.length() > 16: char_error_lbl.text = "⚠ Máximo 16 caracteres."; return
	_slots[_creating_slot] = {
		"name": cname, "gender": _selected_gender, "race": _selected_race,
		"hair_style": _selected_hair,
		"skin_r": _selected_skin.r,       "skin_g": _selected_skin.g,       "skin_b": _selected_skin.b,
		"hair_r": _selected_hair_color.r, "hair_g": _selected_hair_color.g, "hair_b": _selected_hair_color.b,
		"eye_r":  _selected_eye_color.r,  "eye_g":  _selected_eye_color.g,  "eye_b":  _selected_eye_color.b,
		"outfit_r": _selected_outfit.r,   "outfit_g": _selected_outfit.g,   "outfit_b": _selected_outfit.b,
		"level": 1, "xp": 0, "max_hp": 100, "hp": 100, "bronze": 0, "silver": 0, "gold": 0,
	}
	_save_slots(); _show_select()

func _on_cancel_create_btn_pressed() -> void: _show_select()

# ═══════════════════════════════════════════════════════════════════
# SYNC ORO & NAVEGACIÓN
# ═══════════════════════════════════════════════════════════════════
func _sync_account_gold() -> void:
	var total := 0
	for slot in _slots:
		if slot != null: total += slot.get("gold", 0)
	_account_gold = total; _save_slots()
	if is_instance_valid(account_gold_lbl):
		account_gold_lbl.text = "💰 %d oro de cuenta" % _account_gold

func save_active_slot_gold() -> void:
	if _selected_slot < 0 or _slots[_selected_slot] == null: return
	_slots[_selected_slot]["gold"]   = PlayerData.gold
	_slots[_selected_slot]["level"]  = PlayerData.level
	_slots[_selected_slot]["xp"]     = PlayerData.xp
	_slots[_selected_slot]["hp"]     = PlayerData.hp
	_slots[_selected_slot]["bronze"] = PlayerData.bronze
	_slots[_selected_slot]["silver"] = PlayerData.silver
	_sync_account_gold()
	_server_save_player()   # ← También guarda en Firestore

func _go_to_town() -> void:
	AudioManager.stop_login_music(1.8)   # fade-out de 1.8 s mientras carga la escena
	GameManager.change_scene("res://scenes/town.tscn")
func _on_quit_btn_pressed() -> void: get_tree().quit()

# ═══════════════════════════════════════════════════════════════════
# CUENTAS LOCALES (solo para DrakeDev / legacy)
# ═══════════════════════════════════════════════════════════════════
func _hash(s: String) -> int:
	var h : int = 5381
	for i in range(s.length()): h = ((h << 5) + h) + s.unicode_at(i)
	return h

func _ensure_builtin_account() -> void:
	if not _accounts.has(BUILTIN_USER):
		_accounts[BUILTIN_USER] = _hash(BUILTIN_PASS); _save_accounts()

func _load_accounts() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f: return
	var parsed : Variant = JSON.parse_string(f.get_as_text()); f.close()
	if parsed is Dictionary:
		var raw : Dictionary = parsed.get("accounts", parsed) if parsed.has("accounts") else parsed
		for key in raw:
			if raw[key] is int: raw[key] = {"hash": raw[key], "gmail":"", "ip":"", "created":0}
		_accounts = raw

func _save_accounts() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f: return
	f.store_string(JSON.stringify({"_version": CACHE_VERSION, "accounts": _accounts})); f.close()

# ═══════════════════════════════════════════════════════════════════
# _PROCESS — Animaciones
# ═══════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	_anim_timer += delta; _pulse_timer += delta; _border_anim += delta
	_update_particles(delta); _update_sakura_petals(delta)

	if is_instance_valid(_preview_sprite) and _preview_sprite.texture != null:
		_preview_anim_timer += delta
		if _preview_anim_timer >= 1.0 / PREVIEW_FPS:
			_preview_anim_timer = 0.0
			_preview_frame = (_preview_frame + 1) % PREVIEW_FRAMES
			_preview_sprite.frame = _preview_frame

	if is_instance_valid(_select_char_preview_sprite) and _select_char_preview_sprite.texture != null:
		_select_char_anim_timer += delta
		if _select_char_anim_timer >= 1.0 / PREVIEW_FPS:
			_select_char_anim_timer = 0.0
			_select_char_anim_frame = (_select_char_anim_frame + 1) % PREVIEW_FRAMES
			_select_char_preview_sprite.frame = _select_char_anim_frame

	if is_instance_valid(_title_label):
		var pulse := 0.80 + 0.20 * sin(_anim_timer * 2.2)
		var hue   := 0.88 + 0.12 * sin(_anim_timer * 0.8)
		_title_label.modulate = Color(1.0, hue, pulse * 0.38, 1.0)

	var diamond := get_node_or_null("TitleDiamond")
	if is_instance_valid(diamond) and diamond is Label:
		var frames := ["◆","◇","◆","◆","✦","◆"]
		diamond.text = frames[int(_anim_timer * 2.5) % frames.size()]
		var g := 0.88 + 0.12 * sin(_anim_timer * 3.0)
		diamond.add_theme_color_override("font_color", Color(1.0, g, 0.25, 1.0))
