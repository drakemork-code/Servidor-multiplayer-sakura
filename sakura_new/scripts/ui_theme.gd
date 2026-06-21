# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

class_name UITheme
extends RefCounted

# ============================================================
# UI THEME — Sistema visual compartido v1.0
#
# Paleta y helpers compartidos por las pantallas de configuración:
#   • scripts/settings_scene.gd  — Ajustes
#   • scripts/hud_edit.gd        — Editor de HUD
#
# Mantiene la identidad "épica" dorado / púrpura ya usada en
# main_menu.gd, con el acento sakura del juego, y reutiliza las
# texturas rúnicas existentes en assets/ui/.
#
# Todas las funciones son ESTÁTICAS → se usan como UITheme.algo(...)
# No requiere autoload ni instanciación.
#
# Índice (Ctrl+F):
#   [COLORES]   Paleta de colores
#   [ASSETS]    Rutas de texturas
#   [PANELES]   StyleBox de paneles, tarjetas y handles
#   [BOTONES]   Estilos de botones (primary / epic / save / warn / danger / tab)
#   [SLIDERS]   Filas de control deslizante con valor
#   [TEXTO]     Headers de sección, separadores, ornamentos
#   [ANIM]      Animaciones de apertura / cierre
# ============================================================


# ──────────────────────────────────────────────
# [COLORES]
# ──────────────────────────────────────────────

# Fondos
const C_BG_VOID       := Color(0.025, 0.032, 0.075, 1.0)
const C_BG_DEEP       := Color(0.045, 0.055, 0.130, 1.0)
const C_BG_PANEL      := Color(0.055, 0.065, 0.145, 0.97)
const C_BG_PANEL_DARK := Color(0.030, 0.038, 0.090, 0.98)
const C_BG_INNER      := Color(0.028, 0.035, 0.085, 1.0)

# Dorados (acento principal — estilo "épico")
const C_GOLD_BRIGHT   := Color(1.000, 0.920, 0.380, 1.0)
const C_GOLD_MID      := Color(0.870, 0.740, 0.240, 1.0)
const C_GOLD_DIM      := Color(0.580, 0.470, 0.140, 1.0)

# Bordes
const C_BORDER_GOLD   := Color(0.750, 0.600, 0.180, 1.0)
const C_BORDER_DIM    := Color(0.280, 0.220, 0.075, 1.0)

# Acentos funcionales
const C_EPIC_PURPLE   := Color(0.620, 0.280, 0.980, 1.0)
const C_RARE_BLUE     := Color(0.200, 0.600, 1.000, 1.0)
const C_SUCCESS       := Color(0.240, 0.820, 0.380, 1.0)
const C_FIRE          := Color(1.000, 0.480, 0.120, 1.0)
const C_DANGER        := Color(1.000, 0.280, 0.280, 1.0)

# Sakura (firma del juego)
const C_SAKURA        := Color(0.910, 0.490, 0.627, 1.0)
const C_SAKURA_LIGHT  := Color(0.960, 0.753, 0.816, 1.0)

# Texto
const C_TEXT_WHITE    := Color(0.970, 0.960, 1.000, 1.0)
const C_TEXT_LIGHT    := Color(0.850, 0.840, 0.920, 1.0)
const C_TEXT_DIM      := Color(0.560, 0.550, 0.690, 1.0)
const C_TEXT_MUTED    := Color(0.380, 0.370, 0.480, 1.0)

# Secciones (encabezados)
const C_SECTION       := Color(0.670, 0.530, 1.000, 1.0)


# ──────────────────────────────────────────────
# [ASSETS]
# ──────────────────────────────────────────────

const TEX_PANEL_STONE := "res://assets/ui/panel_stone.png"   # Panel principal (piedra + remaches dorados)
const TEX_TITLEBAR    := "res://assets/ui/titlebar_rune.png"  # Barra de título rúnica
const TEX_SIDE_WOOD   := "res://assets/ui/stats_wood.png"     # Panel lateral de madera oscura


# ──────────────────────────────────────────────
# [PANELES]
# ──────────────────────────────────────────────

## StyleBox plano con borde, radio y sombra opcional — base de toda la UI.
static func flat_box(bg: Color, border: Color, bw: int = 2, radius: int = 8, shadow: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_size = 10
		s.shadow_offset = Vector2(0, 4)
	return s

## StyleBox con textura (9-slice) y fallback plano si la textura no existe.
static func tex_box(path: String, fallback_bg: Color, fallback_border: Color,
		margin: int = 16, content_margin: int = 18) -> StyleBox:
	if ResourceLoader.exists(path):
		var tex := ResourceLoader.load(path, "Texture2D")
		if tex:
			var s := StyleBoxTexture.new()
			s.texture = tex
			s.texture_margin_left   = margin
			s.texture_margin_right  = margin
			s.texture_margin_top    = margin
			s.texture_margin_bottom = margin
			s.content_margin_left   = content_margin
			s.content_margin_right  = content_margin
			s.content_margin_top    = content_margin
			s.content_margin_bottom = content_margin
			return s
	return flat_box(fallback_bg, fallback_border, 2, 10)

## Panel principal con la textura de piedra rúnica (Ajustes / Editor de HUD).
static func main_panel_style() -> StyleBox:
	return tex_box(TEX_PANEL_STONE, C_BG_PANEL_DARK, C_BORDER_GOLD, 16, 18)

## Barra de título con textura rúnica dorada.
static func titlebar_style() -> StyleBox:
	return tex_box(TEX_TITLEBAR, C_BG_PANEL_DARK, C_BORDER_GOLD, 6, 8)

## Panel lateral de madera oscura (sidebar del Editor de HUD).
static func side_panel_style() -> StyleBox:
	return tex_box(TEX_SIDE_WOOD, C_BG_INNER, C_BORDER_GOLD, 8, 14)

## "Tarjeta" translúcida para agrupar una sección dentro de un panel mayor.
static func card_style(accent: Color = C_BORDER_GOLD, radius: int = 9) -> StyleBoxFlat:
	var s := flat_box(Color(0.0, 0.0, 0.04, 0.32), accent, 1, radius)
	s.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	s.content_margin_left   = 12
	s.content_margin_right  = 12
	s.content_margin_top    = 10
	s.content_margin_bottom = 10
	return s

## Caja de confirmación (peligro) — usada para "¿Restablecer por defecto?".
static func confirm_box_style() -> StyleBoxFlat:
	return flat_box(Color(0.12, 0.00, 0.00, 0.92), Color(0.80, 0.13, 0.13), 2, 10, true)

## Estilo de "handle" arrastrable del Editor de HUD.
## `selected` añade un brillo dorado al borde y sombra.
static func handle_style(accent: Color, selected: bool) -> StyleBoxFlat:
	var s := flat_box(Color(accent.r, accent.g, accent.b, 0.34), Color(accent.r, accent.g, accent.b, 0.9), 2, 8, true)
	if selected:
		s.border_color = C_GOLD_BRIGHT
		s.set_border_width_all(3)
		s.shadow_color = Color(C_GOLD_BRIGHT.r, C_GOLD_BRIGHT.g, C_GOLD_BRIGHT.b, 0.55)
		s.shadow_size = 12
	return s


# ──────────────────────────────────────────────
# [BOTONES]
# ──────────────────────────────────────────────

## Aplica estilo completo (normal / hover / pressed + colores de fuente) a
## un Button según `kind`:
##   "primary"     dorado   — acciones principales
##   "epic"        púrpura  — "Personalizar HUD", presets
##   "save"        verde    — Guardar
##   "warn"        ámbar    — Reset
##   "danger"      rojo     — Cancelar / Cerrar
##   "tab"         pestaña inactiva
##   "tab_active"  pestaña activa (resaltada en dorado)
##   "ghost"       (por defecto) botón secundario neutro
static func style_button(btn: Button, kind: String = "ghost") -> void:
	var bg_n: Color; var bg_h: Color; var bg_p: Color
	var bd_n: Color; var bd_h: Color; var fc: Color
	var radius := 8

	match kind:
		"primary":
			bg_n = Color(0.420, 0.300, 0.055); bg_h = Color(0.580, 0.420, 0.075)
			bg_p = Color(0.280, 0.200, 0.038); bd_n = C_BORDER_GOLD
			bd_h = C_GOLD_BRIGHT;              fc   = C_GOLD_BRIGHT
		"epic":
			bg_n = Color(0.290, 0.100, 0.550); bg_h = Color(0.380, 0.150, 0.700)
			bg_p = Color(0.200, 0.060, 0.380); bd_n = Color(0.670, 0.400, 1.000)
			bd_h = Color(0.850, 0.620, 1.000); fc   = Color(0.940, 0.880, 1.000)
		"save":
			bg_n = Color(0.060, 0.180, 0.075); bg_h = Color(0.090, 0.280, 0.115)
			bg_p = Color(0.035, 0.110, 0.045); bd_n = Color(0.240, 0.620, 0.320)
			bd_h = C_SUCCESS;                  fc   = Color(0.700, 1.000, 0.760)
		"warn":
			bg_n = Color(0.200, 0.110, 0.020); bg_h = Color(0.320, 0.180, 0.030)
			bg_p = Color(0.130, 0.072, 0.012); bd_n = C_GOLD_DIM
			bd_h = C_GOLD_BRIGHT;              fc   = Color(1.000, 0.820, 0.450)
		"danger":
			bg_n = Color(0.220, 0.050, 0.050); bg_h = Color(0.350, 0.080, 0.080)
			bg_p = Color(0.140, 0.030, 0.030); bd_n = Color(0.550, 0.150, 0.150)
			bd_h = C_DANGER;                   fc   = Color(1.000, 0.650, 0.650)
		"tab_active":
			bg_n = Color(0.150, 0.040, 0.300); bg_h = Color(0.180, 0.055, 0.350)
			bg_p = Color(0.150, 0.040, 0.300); bd_n = C_BORDER_GOLD
			bd_h = C_GOLD_BRIGHT;              fc   = C_GOLD_BRIGHT
			radius = 6
		"tab":
			bg_n = Color(0.045, 0.040, 0.090, 0.55); bg_h = Color(0.085, 0.070, 0.150, 0.85)
			bg_p = Color(0.045, 0.040, 0.090, 0.55); bd_n = Color(0.220, 0.180, 0.090, 0.0)
			bd_h = C_BORDER_DIM;                     fc   = C_TEXT_DIM
			radius = 6
		_: # "ghost"
			bg_n = Color(0.075, 0.092, 0.200); bg_h = Color(0.110, 0.140, 0.290)
			bg_p = Color(0.048, 0.058, 0.130); bd_n = C_BORDER_DIM
			bd_h = C_BORDER_GOLD;              fc   = C_TEXT_LIGHT

	var sn := flat_box(bg_n, bd_n, 2, radius)
	var sh := flat_box(bg_h, bd_h, 2, radius)
	var sp := flat_box(bg_p, bd_n, 2, radius)
	for sb in [sn, sh, sp]:
		sb.content_margin_left   = 12
		sb.content_margin_right  = 12
		sb.content_margin_top    = 8
		sb.content_margin_bottom = 8

	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus",   flat_box(Color(0,0,0,0), bd_h, 2, radius))
	btn.add_theme_color_override("font_color", fc)
	btn.add_theme_color_override("font_hover_color", C_GOLD_BRIGHT if kind != "ghost" else C_TEXT_WHITE)
	btn.add_theme_color_override("font_pressed_color", fc)
	btn.add_theme_color_override("font_focus_color", fc)


# ──────────────────────────────────────────────
# [SLIDERS]
# ──────────────────────────────────────────────

## Aplica el estilo visual a un HSlider. `kind`: "purple" (HUD) | "gold" (audio).
static func style_slider(sl: HSlider, kind: String = "purple") -> void:
	var fill: Color
	var grabber: Color
	if kind == "gold":
		fill    = Color(0.520, 0.380, 0.080, 1.0)
		grabber = C_GOLD_BRIGHT
	else:
		fill    = Color(0.400, 0.160, 0.800, 1.0)
		grabber = Color(0.700, 0.450, 1.000, 1.0)

	var track := flat_box(Color(0.05, 0.035, 0.09, 0.85), C_BORDER_DIM, 1, 4)
	track.content_margin_top = 5; track.content_margin_bottom = 5
	var fill_sb := flat_box(fill, Color(0, 0, 0, 0), 0, 4)
	fill_sb.content_margin_top = 5; fill_sb.content_margin_bottom = 5

	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill_sb)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill_sb)
	sl.add_theme_color_override("grabber_color", grabber)
	sl.add_theme_color_override("grabber_highlight_color", C_GOLD_BRIGHT)

## Construye una fila completa [ texto ····· valor ] + slider debajo y la
## añade a `parent`. Devuelve el HSlider; el Label de valor queda accesible
## vía `slider.get_meta("val_lbl")` y el sufijo vía `get_meta("suffix")`.
## `kind` colorea el slider ("purple" | "gold").
static func slider_row(parent: Control, label_text: String,
		min_v: float, max_v: float, step_v: float, suffix: String,
		kind: String = "purple") -> HSlider:

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	parent.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", C_TEXT_LIGHT)
	lbl.add_theme_font_size_override("font_size", 11)
	top.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(58, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_color_override("font_color", C_GOLD_BRIGHT)
	val_lbl.add_theme_font_size_override("font_size", 11)
	top.add_child(val_lbl)

	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step_v
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(0, 16)
	style_slider(sl, kind)
	vbox.add_child(sl)

	sl.set_meta("val_lbl", val_lbl)
	sl.set_meta("suffix", suffix)
	return sl

## Actualiza el Label de valor asociado a un slider (creado con slider_row).
## `decimals = 0` → entero ("75%"); `decimals > 0` → con decimales ("1.25×").
static func update_slider_label(sl: HSlider, value: float, decimals: int = 0) -> void:
	var lbl: Label = sl.get_meta("val_lbl")
	var suffix: String = sl.get_meta("suffix")
	if decimals > 0:
		lbl.text = ("%.{d}f%s".format({"d": decimals})) % [value, suffix]
	else:
		lbl.text = "%d%s" % [int(round(value)), suffix]


# ──────────────────────────────────────────────
# [TEXTO]
# ──────────────────────────────────────────────

## Encabezado de sección: texto en color de acento + línea decorativa.
static func section_header(text: String, color: Color = C_SECTION) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(color.r, color.g, color.b, 0.35)
	vbox.add_child(line)

	return vbox

## Línea ornamental dorada centrada — firma visual de Sakura Chronicles.
static func ornament(font_size: int = 11, color: Color = C_GOLD_MID) -> Label:
	var lbl := Label.new()
	lbl.text = "⬩  ⚜  ⬩"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

## Separador horizontal de color tenue (por defecto, dorado oscuro).
static func separator(color: Color = C_BORDER_DIM) -> HSeparator:
	var sep := HSeparator.new()
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.content_margin_top = 1
	sep.add_theme_stylebox_override("separator", st)
	return sep

## Pequeño cuadro de color — usado en leyendas (colores de handles del HUD).
static func color_chip(color: Color, chip_size: int = 13) -> Control:
	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(chip_size, chip_size)
	rect.color = color
	var st := StyleBoxFlat.new() # placeholder no usado, mantiene import coherente
	return rect


# ──────────────────────────────────────────────
# [ANIM]
# ──────────────────────────────────────────────

## Animación de entrada: aparición + leve "pop" de escala.
## `node` debe ser un Control (no un CanvasLayer).
static func pop_in(node: Control, duration: float = 0.22) -> void:
	if not is_instance_valid(node): return
	node.modulate.a = 0.0
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.92, 0.92)
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, duration)
	tw.tween_property(node, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Animación de salida: desaparición + leve contracción.
## Devuelve el Tween para que el llamador pueda `await tw.finished`
## antes de `queue_free()`.
static func pop_out(node: Control, duration: float = 0.15) -> Tween:
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "modulate:a", 0.0, duration)
	tw.tween_property(node, "scale", Vector2(0.94, 0.94), duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tw
