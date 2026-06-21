# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node2D

# ============================================================
# TOWN SCENE v2 — Pueblo Principal (Lobby)
# ============================================================
# Mejoras visuales completas:
#   ✓ Fondo tileado con tile_grass.png (TextureRect TILE)
#   ✓ Animación de agua (shimmer de capas con tween)
#   ✓ Glow pulsante en faroles (ColorRect con additive blend)
#   ✓ Movimiento sutil en flores y arbustos (sway)
#   ✓ Humo animado en la forja
#   ✓ Decoraciones adicionales del tileset (cercas, flores, bien, barriles)
#   ✓ Parpadeo de hoguera en la entrada de la mazmorra
#   ✓ Sombras dinámicas bajo edificios
# ============================================================

const SCENE_WIDTH:  int = 1920
const SCENE_HEIGHT: int = 1080

const NPC_POSITIONS: Dictionary = {
	"bank":      Vector2(-440, -170),
	"dungeon":   Vector2( 120, -285),
	"forge":     Vector2( 592,  275),
	"market":    Vector2( 388,  -37),
	"tailor":    Vector2(-769,   -6),
	"alchemist": Vector2(-80,   100),
	"auction":   Vector2( -60,  -80),
	"healer":    Vector2(   0,  -20),
}

# ── Nodos de agua (para animarlos en runtime) ─────────────────
var _water_nodes: Array    = []
var _lamp_glows:  Array    = []
var _smoke_nodes: Array    = []

# ════════════════════════════════════════════════════════════
# READY
# ════════════════════════════════════════════════════════════

# ── VFX Sprite Animations (chimney smoke, fire) ─────────────
var _vfx_sprites: Array = []

# ── Town Tree Animations ─────────────────────────────────────
# Estructura: { sprite, frame_count, frame_w, frame_h, cur_frame, elapsed, interval }
var _tree_anim_data: Array = []
const VFX_FPS: float = 8.0
var _vfx_timer: float = 0.0

func _setup_vfx_animations() -> void:
	# Collect all VFX animated sprites
	var vfx_node = get_node_or_null("VFX")
	if not vfx_node:
		return
	for child in vfx_node.get_children():
		if child is Sprite2D and child.hframes > 1:
			_vfx_sprites.append(child)

func _process_vfx(delta: float) -> void:
	_vfx_timer += delta
	if _vfx_timer >= 1.0 / VFX_FPS:
		_vfx_timer = 0.0
		for s in _vfx_sprites:
			if is_instance_valid(s):
				s.frame = (s.frame + 1) % s.hframes


func _ready() -> void:
	_setup_vfx_animations()
	print("[TownScene] Pueblo v2 cargado")
	GameManager.set_zone("lobby")

	_replace_background_with_tiles()   # 1. Fondo tileado
	_setup_camera_limits()             # 2. Cámara
	_setup_npcs()                      # 3. NPCs con lógica
	_spawn_player()                    # 4. Jugador
	_setup_scene_borders()             # 5. Transiciones
	_check_tutorial()                  # 6. Tutorial primera vez

	#_spawn_resource_nodes()            # 6. Recursos en town.tscn (editables en editor)
	_setup_water_collision()           # 7. Colisión agua

	# ── Efectos visuales (se ejecutan después de un frame
	#    para que todos los nodos del .tscn ya estén listos) ──
	await get_tree().process_frame
	_add_path_edge_details()           # 8. Bordes de camino
	_add_tileset_decorations()         # 9. Cercas, flores extra, bien, barriles
	#_spawn_tall_grass()                # 10. Hierba alta animada (desactivada)
	_setup_building_shadows()          # 10. Sombras bajo edificios
	_animate_water()                   # 11. Animación de agua
	_setup_lamp_glows()                # 12. Glow de faroles
	_add_forge_effects()               # 13. Humo + brasas forja
	_add_dungeon_campfire()            # 14. Hoguera entrada mazmorra
	_animate_foliage()                 # 15. Sway flores/arbustos
	_spawn_town_trees()                # 16. Registra árboles de tscn para animación
	_start_ambient_npc_bob()           # 17. Idle ligero NPCs estáticos
	_add_tree_collisions()             # 18. Colisión física en troncos de árboles
	_fix_building_collisions()         # 19. FIX: Colisión real en edificios
	_spawn_animated_grass()            # 20. Pasto animado con viento e IA
	# ── Música de zona ───────────────────────────────────────
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_zone_music("town")

# ════════════════════════════════════════════════════════════
# 1. FONDO TILEADO CON tile_grass.png
# ════════════════════════════════════════════════════════════

func _replace_background_with_tiles() -> void:
	var bg = get_node_or_null("Background")
	if bg:
		bg.queue_free()

	# TextureRect en modo TILE — ocupa toda la escena
	# tile_grass.png es ahora 128×128 con variación orgánica (sin cuadrículas visibles)
	var tex_path = "res://assets/tiles/tile_grass.png"
	if not ResourceLoader.exists(tex_path):
		_add_fallback_background()
		return

	var tex_rect = TextureRect.new()
	tex_rect.name            = "BackgroundTile"
	tex_rect.texture         = load(tex_path)
	tex_rect.stretch_mode    = TextureRect.STRETCH_TILE
	tex_rect.position        = Vector2(-SCENE_WIDTH / 2, -SCENE_HEIGHT / 2)
	tex_rect.size            = Vector2(SCENE_WIDTH + 2, SCENE_HEIGHT + 2)
	tex_rect.z_index         = -20
	# TEXTURE_FILTER_LINEAR_MIPMAP suaviza las costuras entre tiles sin perder el look pixel-art
	tex_rect.texture_filter  = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(tex_rect)
	move_child(tex_rect, 0)

	# Reemplazar caminos ColorRect con TextureRect texturizados
	_replace_paths_with_textures()

	# Capa oscura muy sutil en los bordes (viñeta)
	_add_vignette()

func _replace_paths_with_textures() -> void:
	var path_tex_path = "res://assets/tiles/tile_stone_path.png"
	var dirt_tex_path = "res://assets/tiles/tile_dirt.png"
	if not ResourceLoader.exists(path_tex_path):
		return
	var path_tex  = load(path_tex_path)
	var dirt_tex: Texture2D = load(dirt_tex_path) if ResourceLoader.exists(dirt_tex_path) else path_tex

	var ground_layer = get_node_or_null("GroundLayer")
	if not ground_layer:
		return

	# Reemplazar cada ColorRect de camino/plaza con un TextureRect tileado
	var rects_to_replace: Array = []
	for child in ground_layer.get_children():
		if child is ColorRect:
			rects_to_replace.append(child)

	for cr in rects_to_replace:
		var w = cr.offset_right  - cr.offset_left
		var h = cr.offset_bottom - cr.offset_top
		var pos_x = cr.offset_left
		var pos_y = cr.offset_top
		var z = cr.z_index

		# Elegir textura: plazas de adoquín o tierra
		var use_tex = path_tex
		var name_lower = cr.name.to_lower()
		if "plaza" in name_lower or "dungeon" in name_lower or "bank" in name_lower:
			use_tex = dirt_tex

		var tr = TextureRect.new()
		tr.name           = cr.name + "Tex"
		tr.texture        = use_tex
		tr.stretch_mode   = TextureRect.STRETCH_TILE
		tr.position       = Vector2(pos_x, pos_y)
		tr.size           = Vector2(w, h)
		tr.z_index        = z
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter   = Control.MOUSE_FILTER_IGNORE
		ground_layer.add_child(tr)
		cr.queue_free.call_deferred()

func _add_fallback_background() -> void:
	var bg = ColorRect.new()
	bg.name         = "BackgroundTile"
	bg.offset_left  = -SCENE_WIDTH  / 2
	bg.offset_top   = -SCENE_HEIGHT / 2
	bg.offset_right = SCENE_WIDTH   / 2
	bg.offset_bottom= SCENE_HEIGHT  / 2
	bg.color        = Color(0.20, 0.33, 0.14)
	bg.z_index      = -20
	add_child(bg)
	move_child(bg, 0)

func _add_vignette() -> void:
	# Borde oscuro sutil para enmarcar la escena
	var v = ColorRect.new()
	v.name         = "Vignette"
	v.offset_left  = -SCENE_WIDTH  / 2
	v.offset_top   = -SCENE_HEIGHT / 2
	v.offset_right =  SCENE_WIDTH  / 2
	v.offset_bottom=  SCENE_HEIGHT / 2
	v.color        = Color(0, 0, 0, 0.18)
	v.z_index      = -19
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)

# ════════════════════════════════════════════════════════════
# 8. BORDES DE CAMINO — Detalles visuales en los cruces
# ════════════════════════════════════════════════════════════

func _add_path_edge_details() -> void:
	# Pequeños rectángulos de borde en los caminos para dar profundidad
	var ground_layer = get_node_or_null("GroundLayer")
	if not ground_layer:
		return
	# FIX: z_index = -2 (debajo del jugador), ancho 3px más sutil,
	# sombra solo en los lados donde el césped limita con el camino
	var edges = [
		# [cx, cy, w, h] — líneas de sombra en los bordes del camino
		[-48.0,  0.0, 4.0, 1080.0],   # Borde izquierdo camino vertical
		[ 48.0,  0.0, 4.0, 1080.0],   # Borde derecho camino vertical
		[  0.0, -48.0, 1920.0, 4.0],  # Borde superior camino horizontal
		[  0.0,  48.0, 1920.0, 4.0],  # Borde inferior camino horizontal
	]
	for e in edges:
		var r = ColorRect.new()
		r.offset_left   = e[0] - e[2] / 2
		r.offset_top    = e[1] - e[3] / 2
		r.offset_right  = e[0] + e[2] / 2
		r.offset_bottom = e[1] + e[3] / 2
		r.color   = Color(0.18, 0.14, 0.08, 0.45)
		r.z_index = -2
		ground_layer.add_child(r)

# ════════════════════════════════════════════════════════════
# 9. DECORACIONES EXTRA DEL TILESET
# ════════════════════════════════════════════════════════════

func _add_tileset_decorations() -> void:
	pass  # Decoraciones ahora son nodos estáticos en town.tscn
	#_add_fences()                   # Cercas en town.tscn
	#_add_extra_flowers()            # Flores en town.tscn
	#_add_barrels_and_well()         # Barriles y pozo en town.tscn
	#_add_extra_bushes()             # Arbustos en town.tscn

func _add_fences() -> void:
	# Cercas alrededor del banco y la forja (del tileset)
	var fence_spots = [
		# [x, y, rot°, escala]
		[-320.0, -340.0,   0.0, 2.4],   # banco norte-este
		[-370.0, -340.0,   0.0, 2.4],
		[-420.0, -340.0,   0.0, 2.4],
		[-470.0, -340.0,   0.0, 2.4],
		# forja
		[ 500.0,  160.0,  90.0, 2.4],
		[ 500.0,  210.0,  90.0, 2.4],
		[ 500.0,  260.0,  90.0, 2.4],
		# plaza sastre
		[-690.0, -165.0,   0.0, 2.4],
		[-740.0, -165.0,   0.0, 2.4],
		[-790.0, -165.0,   0.0, 2.4],
	]
	var tex_h    = _try_load_tex("res://assets/decorations/fence_h.png")
	var tex_post = _try_load_tex("res://assets/decorations/fence_post.png")
	if not tex_h:
		return
	var deco = _get_or_create_deco_layer()
	for s in fence_spots:
		var sp = Sprite2D.new()
		sp.texture         = tex_h if fmod(s[2], 180.0) < 1.0 else (tex_post if tex_post else tex_h)
		sp.position        = Vector2(s[0], s[1])
		sp.rotation_degrees= s[2]
		sp.scale           = Vector2(s[3], s[3])
		sp.texture_filter  = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.z_index         = 5
		deco.add_child(sp)

func _add_extra_flowers() -> void:
	var flower_data = [
		# [x, y, tipo 0=red 1=yellow 2=purple]
		[ 160.0, -320.0, 0], [ 200.0, -310.0, 1], [ 185.0, -330.0, 2],
		[-300.0,  320.0, 1], [-320.0,  310.0, 0], [-285.0,  335.0, 2],
		[ 700.0, -220.0, 0], [ 720.0, -208.0, 1],
		[-820.0,  380.0, 2], [-800.0,  395.0, 0],
		[  50.0,  420.0, 1], [  70.0,  435.0, 2], [  30.0,  410.0, 0],
		[-620.0, -430.0, 0], [-640.0, -415.0, 1],
		[ 450.0,  400.0, 2], [ 470.0,  415.0, 0],
	]
	var textures = [
		_try_load_tex("res://assets/decorations/flower_red.png"),
		_try_load_tex("res://assets/decorations/flower_yellow.png"),
		_try_load_tex("res://assets/decorations/flower_purple.png"),
	]
	var deco = _get_or_create_deco_layer()
	for fd in flower_data:
		var tex = textures[fd[2]]
		if not tex:
			continue
		var sp = Sprite2D.new()
		sp.name           = "FlowerAnim"
		sp.texture        = tex
		sp.position       = Vector2(fd[0], fd[1])
		sp.scale          = Vector2(2.0, 2.0)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.z_index        = 6
		deco.add_child(sp)
		_start_flower_sway(sp)

func _add_barrels_and_well() -> void:
	var deco   = _get_or_create_deco_layer()
	var barrel = _try_load_tex("res://assets/decorations/barrel.png")
	var well   = _try_load_tex("res://assets/decorations/well.png")

	var barrel_spots = [
		Vector2( 660.0,  220.0),   # junto a la forja
		Vector2( 680.0,  245.0),
		Vector2( 540.0,  320.0),
		Vector2(-440.0, -155.0),   # junto al banco
		Vector2(-415.0, -155.0),
		Vector2( 820.0, -160.0),   # almacén este
	]
	for pos in barrel_spots:
		if not barrel:
			break
		var sp = Sprite2D.new()
		sp.texture        = barrel
		sp.position       = pos
		sp.scale          = Vector2(2.2, 2.2)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.z_index        = int((pos.y + 540.0) / 8.0)
		deco.add_child(sp)

	# Pozo en el centro del pueblo
	if well:
		var sp = Sprite2D.new()
		sp.texture        = well
		sp.position       = Vector2(-80.0, 60.0)
		sp.scale          = Vector2(2.8, 2.8)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.z_index        = 10
		deco.add_child(sp)

func _add_extra_bushes() -> void:
	var deco = _get_or_create_deco_layer()
	var bush = _try_load_tex("res://assets/decorations/bush.png")
	if not bush:
		return
	var spots = [
		Vector2(-840.0, -60.0),
		Vector2( 820.0,  80.0),
		Vector2( 340.0, 440.0),
		Vector2(-200.0, 430.0),
		Vector2(-700.0, 470.0),
		Vector2( 840.0,-440.0),
		Vector2(-850.0,-450.0),
	]
	for pos in spots:
		var sp = Sprite2D.new()
		sp.name           = "BushAnim"
		sp.texture        = bush
		sp.position       = pos
		sp.scale          = Vector2(2.5, 2.5)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.z_index        = int((pos.y + 540.0) / 8.0)
		deco.add_child(sp)

func _setup_building_shadows() -> void:
	var buildings_node = get_node_or_null("Buildings")
	if not buildings_node:
		return
	# Datos: [pos_x, pos_y, sombra_w, sombra_h]
	var shadow_data = [
		[-440.0, -245.0,  120.0, 20.0],   # Banco
		[ 120.0, -360.0,  110.0, 20.0],   # Mazmorra
		[ 592.0,  200.0,  100.0, 18.0],   # Forja
		[ 388.0, -110.0,   90.0, 16.0],   # Market
		[-769.0,  -80.0,  110.0, 18.0],   # Sastre
	]
	for sd in shadow_data:
		var shadow = ColorRect.new()
		shadow.offset_left   = sd[0] - sd[2] / 2
		shadow.offset_top    = sd[1]
		shadow.offset_right  = sd[0] + sd[2] / 2
		shadow.offset_bottom = sd[1] + sd[3]
		shadow.color         = Color(0.0, 0.0, 0.0, 0.28)
		shadow.z_index       = -1
		buildings_node.add_child(shadow)

# ════════════════════════════════════════════════════════════
# 11. ANIMACIÓN DE AGUA — Shimmer de capas superpuestas
# ════════════════════════════════════════════════════════════

func _animate_water() -> void:
	# ════════════════════════════════════════════════════════════
	# ANIMACIÓN DE AGUA — 3 tipos con spritesheet de 4 frames
	#   water_deep.png   → Agua profunda  (río principal)
	#   water_shore.png  → Agua de orilla (bordes del río)
	#   water_bridge.png → Agua bajo puente
	# Cada sheet: 256×64 (4 frames × 64px), animado via Timer
	# ════════════════════════════════════════════════════════════
	var river_area = get_node_or_null("GroundLayer/RiverArea")
	if not river_area:
		return

	# Cargar los 3 spritesheets
	var tex_deep   = _try_load_tex("res://assets/tiles/water_deep.png")
	var tex_shore  = _try_load_tex("res://assets/tiles/water_shore.png")
	var tex_bridge = _try_load_tex("res://assets/tiles/water_bridge.png")

	# Fallback: si no hay spritesheets nuevos, usar tile_water.png estático
	var tex_fallback = _try_load_tex("res://assets/tiles/tile_water.png")

	# ── Reemplazar los ColorRect del río con animación apropiada ──
	var rects_to_process: Array = []
	for child in river_area.get_children():
		if child is ColorRect:
			rects_to_process.append(child)

	for cr in rects_to_process:
		var bounds = Rect2(
			Vector2(cr.offset_left, cr.offset_top),
			Vector2(cr.offset_right - cr.offset_left, cr.offset_bottom - cr.offset_top)
		)
		# RiverMain y RiverStream → agua profunda
		# RiverBank* → agua de orilla
		var is_bank = cr.name.begins_with("RiverBank")
		var tex_to_use: Texture2D = null
		if is_bank:
			tex_to_use = tex_shore if tex_shore else tex_fallback
		else:
			tex_to_use = tex_deep if tex_deep else tex_fallback

		if tex_to_use:
			var anim = _create_water_animated_node(bounds, tex_to_use, cr.z_index)
			river_area.add_child(anim)
			cr.hide()
			_water_nodes.append(anim)
		else:
			_water_nodes.append(cr)

	# ── Agua bajo el puente ──
	var bridge = get_node_or_null("Buildings/Bridge")
	if bridge and tex_bridge:
		_add_bridge_water(bridge, tex_bridge)
	elif bridge and tex_deep:
		_add_bridge_water(bridge, tex_deep)

func _create_water_animated_node(bounds: Rect2, spritesheet: Texture2D, z: int) -> Node2D:
	# ── Nodo contenedor para la animación de agua tileada ──
	var container = Node2D.new()
	container.position = bounds.position
	container.z_index  = z

	var tile_size   := 64
	var cols        := int(ceil(bounds.size.x / tile_size)) + 1
	var rows        := int(ceil(bounds.size.y / tile_size)) + 1
	var frame_count := 4
	var frame_w     := tile_size  # cada frame del sheet es 64×64

	# Crear una cuadrícula de Sprite2D que se animan juntos
	var sprites: Array = []
	for row in range(rows):
		for col in range(cols):
			var sp = Sprite2D.new()
			sp.texture        = spritesheet
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			# Usar region_rect para mostrar solo el frame actual
			sp.region_enabled = true
			sp.region_rect    = Rect2(0, 0, frame_w, tile_size)
			# Centrar el sprite en su celda
			sp.centered       = false
			sp.position       = Vector2(col * tile_size, row * tile_size)
			# Recortar si se sale del área
			var clip_x = minf(tile_size, bounds.size.x - col * tile_size)
			var clip_y = minf(tile_size, bounds.size.y - row * tile_size)
			if clip_x <= 0 or clip_y <= 0:
				continue
			container.add_child(sp)
			sprites.append(sp)

	# Timer que avanza los frames (0.18s por frame → ~5.5 fps, típico agua pixel-art)
	if sprites.size() > 0:
		var timer = Timer.new()
		timer.wait_time = 0.18
		timer.autostart = false
		container.add_child(timer)

		var current_frame := 0
		timer.timeout.connect(func():
			current_frame = (current_frame + 1) % frame_count
			var fx = current_frame * frame_w
			for sp in sprites:
				if is_instance_valid(sp):
					sp.region_rect = Rect2(fx, 0, frame_w, tile_size)
		)
		timer.call_deferred("start")

	return container

func _add_bridge_water(bridge_node: Node, spritesheet: Texture2D) -> void:
	# ── Agrega agua animada debajo del puente ──
	# El puente está en Buildings/Bridge, posición ~(-801, 313), scale ~(5.2, 4.0)
	# Colocamos el agua en GroundLayer/RiverArea con z_index bajo el puente
	var river_area = get_node_or_null("GroundLayer/RiverArea")
	if not river_area:
		return

	# Bounds aproximados del área bajo el puente
	var bridge_pos  = bridge_node.position
	var water_width  := 160.0
	var water_height := 96.0
	var water_bounds = Rect2(
		bridge_pos + Vector2(-water_width * 0.5, -water_height * 0.5),
		Vector2(water_width, water_height)
	)

	var anim = _create_water_animated_node(water_bounds, spritesheet, -1)
	anim.name = "BridgeWater"
	river_area.add_child(anim)

# ════════════════════════════════════════════════════════════
# 12. GLOW PULSANTE DE FAROLES
# ════════════════════════════════════════════════════════════

func _setup_lamp_glows() -> void:
	var deco_layer = get_node_or_null("Decorations")
	if not deco_layer:
		return

	for child in deco_layer.get_children():
		if child is Sprite2D:
			var sp = child as Sprite2D
			if sp.texture and "lamp" in sp.texture.resource_path.to_lower():
				_add_lamp_glow(sp)

	# También buscar en el layer de decoraciones añadido por código
	var extra_deco = get_node_or_null("ExtraDecorations")
	if extra_deco:
		for child in extra_deco.get_children():
			if child is Sprite2D:
				var sp = child as Sprite2D
				if sp.texture and "lamp" in sp.texture.resource_path.to_lower():
					_add_lamp_glow(sp)

func _add_lamp_glow(lamp_sprite: Sprite2D) -> void:
	# Círculo amarillo suave debajo de la lámpara
	var glow = ColorRect.new()
	glow.name         = "LampGlow"
	glow.size         = Vector2(72.0, 72.0)
	glow.position     = lamp_sprite.position + Vector2(-36.0, -12.0)
	glow.color        = Color(1.0, 0.85, 0.3, 0.0)
	glow.z_index      = lamp_sprite.z_index - 1
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lamp_sprite.get_parent().add_child(glow)
	_lamp_glows.append(glow)

	# Animación de parpadeo suave
	var phase = randf_range(0.0, 2.5)
	await get_tree().create_timer(phase).timeout
	_loop_lamp_glow(glow)

func _loop_lamp_glow(glow: ColorRect) -> void:
	if not is_instance_valid(glow):
		return
	var tw = glow.create_tween().set_loops(0)
	tw.tween_property(glow, "color:a", 0.38, randf_range(0.9, 1.4))
	tw.tween_property(glow, "color:a", 0.16, randf_range(0.7, 1.1))

# ════════════════════════════════════════════════════════════
# 13. EFECTOS DE FORJA — Humo + brasas
# ════════════════════════════════════════════════════════════

func _add_forge_effects() -> void:
	# Posición de la forja en la escena
	var forge_pos = Vector2(592.0, 130.0)
	_spawn_smoke_emitter(forge_pos + Vector2(-10, -40))
	_spawn_smoke_emitter(forge_pos + Vector2( 12, -50))
	_spawn_ember_glow(forge_pos + Vector2(0, -20))

func _spawn_smoke_emitter(origin: Vector2) -> void:
	# Generar partículas de humo (ColorRect pequeños que suben y se desvanecen)
	_emit_smoke_particle(origin)
	var timer = Timer.new()
	timer.wait_time = randf_range(0.6, 1.1)
	timer.autostart = false
	timer.timeout.connect(func():
		if is_instance_valid(timer):
			_emit_smoke_particle(origin)
			timer.wait_time = randf_range(0.5, 1.2)
	)
	add_child(timer)
	timer.start()
	_smoke_nodes.append(timer)

func _emit_smoke_particle(origin: Vector2) -> void:
	var p = ColorRect.new()
	p.size     = Vector2(randf_range(5.0, 10.0), randf_range(5.0, 10.0))
	p.color    = Color(0.5, 0.5, 0.5, 0.6)
	p.position = origin + Vector2(randf_range(-6.0, 6.0), 0.0)
	p.z_index  = 80
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	var drift_x = randf_range(-18.0, 18.0)
	var tw = p.create_tween().set_parallel(true)
	tw.tween_property(p, "position:y", origin.y - randf_range(40.0, 70.0), 2.0)
	tw.tween_property(p, "position:x", p.position.x + drift_x, 2.0)
	tw.tween_property(p, "color:a", 0.0, 1.8)
	tw.tween_property(p, "size", Vector2(randf_range(14.0, 22.0), randf_range(14.0, 22.0)), 2.0)
	tw.finished.connect(func(): if is_instance_valid(p): p.queue_free())

func _spawn_ember_glow(pos: Vector2) -> void:
	# Brillo naranja pulsante en la boca del horno
	var ember = ColorRect.new()
	ember.name         = "ForgeEmber"
	ember.size         = Vector2(32.0, 20.0)
	ember.position     = pos - Vector2(16.0, 10.0)
	ember.color        = Color(1.0, 0.45, 0.0, 0.0)
	ember.z_index      = 15
	ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ember)
	var tw = ember.create_tween().set_loops(0)
	tw.tween_property(ember, "color:a", 0.70, randf_range(0.25, 0.45))
	tw.tween_property(ember, "color",
		Color(1.0, 0.30, 0.0, 0.55), randf_range(0.2, 0.4))
	tw.tween_property(ember, "color:a", 0.20, randf_range(0.3, 0.5))

# ════════════════════════════════════════════════════════════
# 14. HOGUERA ENTRADA MAZMORRA
# ════════════════════════════════════════════════════════════

func _add_dungeon_campfire() -> void:
	var fire_positions = [
		Vector2( 60.0, -355.0),
		Vector2(180.0, -355.0),
	]
	for fp in fire_positions:
		_spawn_campfire(fp)

func _spawn_campfire(pos: Vector2) -> void:
	# Base naranja + brillo oscilante
	var base = ColorRect.new()
	base.size     = Vector2(10.0, 10.0)
	base.color    = Color(1.0, 0.55, 0.0, 0.85)
	base.position = pos - Vector2(5.0, 5.0)
	base.z_index  = 20
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	var glow = ColorRect.new()
	glow.size     = Vector2(28.0, 28.0)
	glow.color    = Color(1.0, 0.6, 0.1, 0.0)
	glow.position = pos - Vector2(14.0, 14.0)
	glow.z_index  = 19
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var tw = glow.create_tween().set_loops(0)
	tw.tween_property(glow, "color:a", 0.35, randf_range(0.18, 0.28))
	tw.tween_property(glow, "color", Color(1.0, 0.4, 0.0, 0.18), randf_range(0.15, 0.25))
	tw.tween_property(glow, "color:a", 0.10, randf_range(0.18, 0.30))

	# Partículas de fuego pequeñas
	var fire_timer = Timer.new()
	fire_timer.wait_time = 0.12
	fire_timer.autostart = false
	fire_timer.timeout.connect(func(): _emit_fire_particle(pos))
	add_child(fire_timer)
	fire_timer.start()

func _emit_fire_particle(origin: Vector2) -> void:
	var p = ColorRect.new()
	p.size     = Vector2(randf_range(3.0, 6.0), randf_range(3.0, 6.0))
	p.color    = Color(randf_range(0.9,1.0), randf_range(0.3,0.7), 0.0, 0.9)
	p.position = origin + Vector2(randf_range(-4.0, 4.0), 0.0)
	p.z_index  = 21
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	var tw = p.create_tween().set_parallel(true)
	tw.tween_property(p, "position:y", origin.y - randf_range(12.0, 24.0), 0.45)
	tw.tween_property(p, "position:x", p.position.x + randf_range(-5.0, 5.0), 0.45)
	tw.tween_property(p, "color:a", 0.0, 0.4)
	tw.finished.connect(func(): if is_instance_valid(p): p.queue_free())

# ════════════════════════════════════════════════════════════
# 15. SWAY DE FLORES, ARBUSTOS Y ÁRBOLES
# ════════════════════════════════════════════════════════════

func _animate_foliage() -> void:
	# Animar flores y arbustos existentes en .tscn
	var deco_layer = get_node_or_null("Decorations")
	if not deco_layer:
		return
	for child in deco_layer.get_children():
		if not (child is Sprite2D):
			continue
		var sp = child as Sprite2D
		if not sp.texture:
			continue
		var path = sp.texture.resource_path.to_lower()
		if "flower" in path:
			_start_flower_sway(sp)
		elif "bush" in path:
			_start_flower_sway(sp)

# ════════════════════════════════════════════════════════════
# ÁRBOLES DEL PUEBLO — Sprites animados del Sunnyside Asset Pack
#   town_tree_a_strip4.png: 384×102 (4 frames × 96px) — árbol redondo
#   town_tree_b_strip4.png: 336×129 (4 frames × 84px) — árbol cónico
# ════════════════════════════════════════════════════════════
func _spawn_town_trees() -> void:
	# Árboles ahora son nodos estáticos en town.tscn — solo los registramos para animación
	var trees_node = get_node_or_null("Decorations/Trees")
	if not trees_node:
		return
	for sp in trees_node.get_children():
		if sp is Sprite2D and sp.region_enabled:
			var frame_w = sp.region_rect.size.x
			var frame_h = sp.region_rect.size.y
			var frame_count = 4
			var cur_frame = randi() % frame_count
			sp.region_rect = Rect2(cur_frame * frame_w, 0, frame_w, frame_h)
			_tree_anim_data.append({
				"sprite": sp, "frame_count": frame_count,
				"frame_w": frame_w, "frame_h": frame_h,
				"cur_frame": cur_frame,
				"elapsed": randf_range(0.0, 0.22),
				"interval": randf_range(0.14, 0.22),
			})
	return
	var deco = _get_or_create_deco_layer()
	var tex_a = _try_load_tex("res://assets/decorations/town_tree_a_strip4.png")
	var tex_b = _try_load_tex("res://assets/decorations/town_tree_b_strip4.png")

	if not tex_a:
		tex_a = _try_load_tex("res://assets/decorations/sunnyside_tree_strip4.png")
	if not tex_b:
		tex_b = _try_load_tex("res://assets/decorations/sunnyside_tree_strip4.png")

	# FIX: posiciones rediseñadas para que los árboles formen bordes naturales
	# sin invadir caminos (x ∈ [-65,65] = camino vertical, y ∈ [-65,65] = camino horizontal)
	# ni solaparse con edificios. Distribución: borde norte + columnas laterales + borde sur.
	var spots = [
		# ── Borde norte — línea de bosque detrás de los edificios ──
		[Vector2(-820, -430), "a"], [Vector2(-720, -460), "b"],
		[Vector2(-620, -440), "a"], [Vector2(-500, -450), "b"],
		[Vector2(-400, -430), "a"],
		[Vector2( 200, -440), "b"], [Vector2( 340, -460), "a"],
		[Vector2( 480, -430), "b"], [Vector2( 620, -450), "a"],
		[Vector2( 760, -420), "b"], [Vector2( 880, -440), "a"],

		# ── Borde oeste — columna pegada al borde (no bloquea mercado) ──
		[Vector2(-870, -280), "b"], [Vector2(-890,  -80), "a"],
		[Vector2(-880,  130), "b"], [Vector2(-870,  330), "a"],
		[Vector2(-840,  490), "b"],

		# ── Cluster suroeste ──
		[Vector2(-650,  380), "a"], [Vector2(-550,  410), "b"],
		[Vector2(-640,  460), "a"],

		# ── Borde este — columna (respeta tailor y casas) ──
		[Vector2( 780, -280), "a"], [Vector2( 860, -100), "b"],
		[Vector2( 820,  120), "a"], [Vector2( 800,  340), "b"],
		[Vector2( 760,  480), "a"],

		# ── Borde sur — fila de cierre del mapa ──
		[Vector2(-700,  490), "b"], [Vector2(-560,  500), "a"],
		[Vector2(-400,  490), "b"], [Vector2(-240,  500), "a"],
		[Vector2(  90,  490), "b"], [Vector2( 220,  500), "a"],
		[Vector2( 400,  490), "b"], [Vector2( 560,  500), "a"],
	]

	for entry in spots:
		var pos: Vector2 = entry[0]
		var variant: String = entry[1]
		var tex = tex_a if variant == "a" else tex_b
		if not tex:
			tex = tex_a if tex_a else tex_b
		if not tex:
			continue

		var frame_count := 4
		var frame_w := tex.get_width() / frame_count
		var frame_h := tex.get_height()

		var sp := Sprite2D.new()
		sp.name           = "TownTree"
		sp.texture        = tex
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.region_enabled = true
		sp.centered       = true
		sp.position       = pos
		sp.z_index        = int((pos.y + 540.0) / 8.0)
		# FIX escala: town_tree son 96-102px (ya grande), sunnyside fallback 32px necesita x3
		var is_fallback := frame_w <= 34
		sp.scale = Vector2(3.0, 3.0) if is_fallback else Vector2(1.0, 1.0)
		deco.add_child(sp)

		# Registrar para animación en _process (más fiable que Timer hijo)
		var cur_frame: int = randi() % frame_count
		sp.region_rect = Rect2(cur_frame * frame_w, 0, frame_w, frame_h)
		_tree_anim_data.append({
			"sprite":      sp,
			"frame_count": frame_count,
			"frame_w":     frame_w,
			"frame_h":     frame_h,
			"cur_frame":   cur_frame,
			"elapsed":     randf_range(0.0, 0.22),  # offset inicial para desincronizar
			"interval":    randf_range(0.14, 0.22),
		})


func _add_tree_collisions() -> void:
	# Añade StaticBody2D en el tronco de cada árbol (tscn + ExtraDecorations)
	# Frame: 32×34 px, escala 6 → tronco ≈ 50 px más abajo del centro del sprite
	const TRUNK_OFFSET_Y := 38.0
	const TRUNK_W        := 14.0
	const TRUNK_H        := 16.0

	var layers : Array = []
	var dec = get_node_or_null("Decorations")
	var ext = get_node_or_null("ExtraDecorations")
	if dec: layers.append(dec)
	if ext: layers.append(ext)

	for layer in layers:
		for child in layer.get_children():
			if not (child is Sprite2D):
				continue
			var sp := child as Sprite2D
			if not sp.texture:
				continue
			var path := sp.texture.resource_path.to_lower()
			if "town_tree" not in path and "tree" not in path:
				continue
			# Cuerpo estático en el tronco
			var body := StaticBody2D.new()
			body.name            = "TreeCollision"
			body.position        = sp.position + Vector2(0.0, TRUNK_OFFSET_Y)
			body.collision_layer = 1
			body.collision_mask  = 0
			var cshape := CollisionShape2D.new()
			var rect   := RectangleShape2D.new()
			rect.size       = Vector2(TRUNK_W, TRUNK_H)
			cshape.shape    = rect
			body.add_child(cshape)
			layer.add_child(body)

func _start_flower_sway(sp: Sprite2D) -> void:
	var base_rot  = sp.rotation_degrees
	var base_sc   = sp.scale
	var phase     = randf_range(0.0, TAU)
	var period    = randf_range(2.2, 3.6)
	var amplitude = randf_range(2.5, 5.5)  # grados

	var tw = sp.create_tween().set_loops(0).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(sp, "rotation_degrees", base_rot + amplitude, period * 0.5)
	tw.tween_property(sp, "rotation_degrees", base_rot - amplitude, period * 0.5)
	# Escala ligera para dar sensación de profundidad
	tw.parallel().tween_property(sp, "scale", base_sc * 1.03, period * 0.5)
	tw.parallel().tween_property(sp, "scale", base_sc * 0.97, period * 0.5)

func _start_ambient_npc_bob() -> void:
	var npc_sprites = get_node_or_null("NPCSprites")
	if not npc_sprites:
		return
	for child in npc_sprites.get_children():
		if child is Sprite2D:
			_bob_npc(child as Sprite2D)

func _bob_npc(sp: Sprite2D) -> void:
	var base_y  = sp.position.y
	var period  = randf_range(2.0, 3.5)
	var phase   = randf_range(0.0, 2.0)
	await get_tree().create_timer(phase).timeout
	if not is_instance_valid(sp):
		return
	var tw = sp.create_tween().set_loops(0).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(sp, "position:y", base_y - 2.5, period * 0.5)
	tw.tween_property(sp, "position:y", base_y + 0.5, period * 0.5)

# ════════════════════════════════════════════════════════════
# TUTORIAL — Primera vez en el juego
# Entrega espada tosca + armadura de cuero y muestra panel
# ════════════════════════════════════════════════════════════

func _check_tutorial() -> void:
	if PlayerData.tutorial_done:
		return
	# Esperar un frame extra para que la UI y el jugador estén listos
	await get_tree().process_frame
	await get_tree().process_frame
	_run_tutorial()

func _run_tutorial() -> void:
	# --- Entregar ítems iniciales ---
	var got_weapon = InventoryManager.add_item("weapon_broad_sword")
	var got_armor  = InventoryManager.add_item("armor_leather_chest")

	# Equipar automáticamente si el slot está vacío
	if got_weapon and InventoryManager.equipped_items.get("weapon") == null:
		InventoryManager.equip_item("weapon_broad_sword")
	if got_armor and InventoryManager.equipped_items.get("chest") == null:
		InventoryManager.equip_item("armor_leather_chest")

	# --- Marcar tutorial completado y guardar ---
	PlayerData.tutorial_done = true
	PlayerData.save_character_data()

	# --- Mostrar panel de bienvenida ---
	_show_tutorial_panel()

func _show_tutorial_panel() -> void:
	# Crear overlay semitransparente
	var overlay := ColorRect.new()
	overlay.name         = "TutorialOverlay"
	overlay.color        = Color(0, 0, 0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "TutorialPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -220
	panel.offset_right  =  220
	panel.offset_top    = -170
	panel.offset_bottom =  170

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "¡Bienvenido a Sakura Chronicles!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)

	var desc := Label.new()
	desc.text = "Has recibido tu equipo inicial:\n\n  🗡  Espada Ancha\n  🛡  Peto de Cuero\n\nConsejos:\n• [Q/E/R] — Habilidades de combate\n• [F] — Interactuar con NPCs\n• Habla con el NPC del Banco para guardar\n  tus monedas de forma segura."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var btn := Button.new()
	btn.text     = "¡Comenzar aventura!"
	btn.custom_minimum_size = Vector2(200, 40)

	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	vbox.add_child(desc)
	vbox.add_child(btn)
	panel.add_child(vbox)
	overlay.add_child(panel)

	# Añadir al CanvasLayer de UI si existe, o directamente a la escena
	var ui_layers = get_tree().get_nodes_in_group("ui")
	if ui_layers.size() > 0:
		ui_layers[0].add_child(overlay)
	else:
		add_child(overlay)

	btn.pressed.connect(func():
		overlay.queue_free()
	)

# ════════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════════

func _try_load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _get_or_create_deco_layer() -> Node2D:
	var existing = get_node_or_null("ExtraDecorations")
	if existing:
		return existing
	var layer = Node2D.new()
	layer.name    = "ExtraDecorations"
	layer.z_index = 5
	add_child(layer)
	return layer

# ════════════════════════════════════════════════════════════
# CÁMARA
# ════════════════════════════════════════════════════════════

func _setup_camera_limits() -> void:
	var half_w = SCENE_WIDTH  / 2
	var half_h = SCENE_HEIGHT / 2
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left   = -half_w
			cam.limit_right  =  half_w
			cam.limit_top    = -half_h
			cam.limit_bottom =  half_h
			cam.position_smoothing_enabled = true
			cam.position_smoothing_speed   = 5.0

# ════════════════════════════════════════════════════════════
# SPAWN JUGADOR
# ════════════════════════════════════════════════════════════

func _spawn_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if GameManager.player_spawn_override:
		player.global_position = GameManager.consume_spawn_override()
	else:
		player.global_position = Vector2.ZERO

# ════════════════════════════════════════════════════════════
# NPCs
# ════════════════════════════════════════════════════════════

func _setup_npcs() -> void:
	_spawn_npc({
		"npc_name": "Banco", "npc_role": "🏦  BANCO", "npc_gender": "female",
		"npc_tint": Color(1.0, 0.85, 0.2), "has_bank": true, "shop_id": "bank",
		"position": NPC_POSITIONS["bank"],
		"dialog_lines": ["¡Bienvenido al Banco de Sakura!","Tus objetos estarán seguros aquí.","Deposita y retira cuando quieras."]
	})
	_spawn_npc({
		"npc_name": "Entrada Mazmorra", "npc_role": "💀  GUARDIÁN", "npc_gender": "male",
		"npc_tint": Color(0.7, 0.7, 1.0), "has_dungeon": true,
		"position": NPC_POSITIONS["dungeon"],
		"dialog_lines": ["¡Alto! La Stone Dungeon es peligrosa.","Solo los valientes se atreven a entrar.","¿Deseas intentarlo?"]
	})
	_spawn_npc({
		"npc_name": "Forja", "npc_role": "⚒  HERRERO", "npc_gender": "male",
		"npc_tint": Color(0.53, 0.67, 1.0), "has_shop": true, "has_crafting": true,
		"shop_id": "forge", "position": NPC_POSITIONS["forge"],
		"dialog_lines": ["¡Bienvenido a la Forja!","Con hierro y cobre creo armas T1-T4.","También vendo herramientas de minería."]
	})
	_spawn_npc({
		"npc_name": "Mercado", "npc_role": "🌿  HERBOLARIA", "npc_gender": "female",
		"npc_tint": Color(0.27, 0.93, 0.53), "has_shop": true, "has_crafting": true,
		"shop_id": "herbalist", "position": NPC_POSITIONS["market"],
		"dialog_lines": ["¡Las plantas del bosque guardan secretos!","Preparo pociones de curación y más.","¿Qué necesitas hoy?"]
	})
	_spawn_npc({
		"npc_name": "Centro", "npc_role": "🧵  SASTRE", "npc_gender": "female",
		"npc_tint": Color(1.0, 0.5, 0.7), "has_shop": true, "has_crafting": true,
		"shop_id": "tailor", "position": NPC_POSITIONS["tailor"],
		"dialog_lines": ["¡Las mejores telas de la región!","Armaduras ligeras y pesadas.","¿Buscas algo en particular?"]
	})
	_spawn_npc({
		"npc_name": "Subastador", "npc_role": "🏷  CASA DE SUBASTAS", "npc_gender": "male",
		"npc_tint": Color(1.0, 0.75, 0.1), "has_auction": true, "shop_id": "auction",
		"position": NPC_POSITIONS["auction"],
		"dialog_lines": ["¡Bienvenido a la Casa de Subastas!","Compra y vende al mejor postor.","¡Los NPCs también participan, actúa rápido!"]
	})
	_spawn_npc({
		"npc_name": "Alquimista", "npc_role": "⚗  ALQUIMISTA", "npc_gender": "female",
		"npc_tint": Color(0.7, 0.4, 1.0), "has_shop": true, "has_crafting": true,
		"shop_id": "herbalist", "position": NPC_POSITIONS["alchemist"],
		"dialog_lines": ["El conocimiento arcano fluye en mis pociones.", "Traeme materiales y crearé maravillas.", "¿Necesitas algo especial hoy?"]
	})
	_spawn_npc({
		"npc_name": "Curandera", "npc_role": "💚  SANACIÓN", "npc_gender": "female",
		"npc_tint": Color(0.4, 1.0, 0.6), "has_healer": true,
		"position": NPC_POSITIONS["healer"],
		"dialog_lines": ["Que la luz cure tus heridas, viajero.", "Tu primera curación conmigo es gratuita.", "Después de eso, cobro una pequeña tarifa, o puedes esperar y curarte sin costo."]
	})

func _spawn_npc(config: Dictionary) -> void:
	var npc_scene_path = "res://scenes/npc.tscn"
	if not ResourceLoader.exists(npc_scene_path):
		_spawn_placeholder_npc(config); return
	var npc: NPC = load(npc_scene_path).instantiate()
	npc.position     = config.get("position", Vector2.ZERO)
	npc.npc_name     = config.get("npc_name", "NPC")
	npc.npc_role     = config.get("npc_role", "")
	npc.npc_gender   = config.get("npc_gender", "male")
	npc.npc_tint     = config.get("npc_tint", Color.WHITE)
	npc.has_shop     = config.get("has_shop", false)
	npc.has_bank     = config.get("has_bank", false)
	npc.has_crafting = config.get("has_crafting", false)
	npc.has_quest    = config.get("has_quest", false)
	npc.has_auction  = config.get("has_auction", false)
	npc.has_dungeon  = config.get("has_dungeon", false)
	npc.has_healer   = config.get("has_healer", false)
	npc.shop_id      = config.get("shop_id", "")
	npc.dialog_lines.clear()
	for line in config.get("dialog_lines", ["Hola."]):
		npc.dialog_lines.append(line)
	add_child(npc)

func _spawn_placeholder_npc(config: Dictionary) -> void:
	var ph = Node2D.new()
	ph.position = config.get("position", Vector2.ZERO)
	var rect  = ColorRect.new()
	rect.size     = Vector2(16, 24)
	rect.position = Vector2(-8, -24)
	rect.color    = config.get("npc_tint", Color.WHITE)
	ph.add_child(rect)
	var lbl = Label.new()
	lbl.text = config.get("npc_name", "NPC")
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.position = Vector2(-20, -36)
	ph.add_child(lbl)
	add_child(ph)

# ════════════════════════════════════════════════════════════
# BORDES DE ESCENA
# ════════════════════════════════════════════════════════════

func _setup_scene_borders() -> void:
	# Solo se puede salir por el camino central de cada borde (ancho del path)
	const PATH_WIDTH := 160.0
	var half_w := float(SCENE_WIDTH) / 2.0
	var half_h := float(SCENE_HEIGHT) / 2.0

	# ── NORTE ──────────────────────────────────────────────
	var north_y := -half_h + 20
	_create_border_trigger(Vector2(0, north_y), Vector2(PATH_WIDTH, 40),
		"north", "res://scenes/world_north.tscn", "❄ Zona Nieve")
	var n_side_w := half_w - PATH_WIDTH / 2.0
	_add_border_wall(Vector2(-(PATH_WIDTH / 2.0 + n_side_w / 2.0), north_y), Vector2(n_side_w, 40))
	_add_border_wall(Vector2( (PATH_WIDTH / 2.0 + n_side_w / 2.0), north_y), Vector2(n_side_w, 40))

	# ── SUR ────────────────────────────────────────────────
	var south_y := half_h - 20
	_create_border_trigger(Vector2(0, south_y), Vector2(PATH_WIDTH, 40),
		"south", "res://scenes/world_south.tscn", "🌿 Zona Sur")
	var s_side_w := half_w - PATH_WIDTH / 2.0
	_add_border_wall(Vector2(-(PATH_WIDTH / 2.0 + s_side_w / 2.0), south_y), Vector2(s_side_w, 40))
	_add_border_wall(Vector2( (PATH_WIDTH / 2.0 + s_side_w / 2.0), south_y), Vector2(s_side_w, 40))

	# ── ESTE ───────────────────────────────────────────────
	var east_x := half_w - 20
	_create_border_trigger(Vector2(east_x, 0), Vector2(40, PATH_WIDTH),
		"east", "res://scenes/world_east.tscn", "🌋 Zona Volcánica")
	var e_side_h := half_h - PATH_WIDTH / 2.0
	_add_border_wall(Vector2(east_x, -(PATH_WIDTH / 2.0 + e_side_h / 2.0)), Vector2(40, e_side_h))
	_add_border_wall(Vector2(east_x,  (PATH_WIDTH / 2.0 + e_side_h / 2.0)), Vector2(40, e_side_h))

	# ── OESTE ──────────────────────────────────────────────
	var west_x := -half_w + 20
	_create_border_trigger(Vector2(west_x, 0), Vector2(40, PATH_WIDTH),
		"west", "res://scenes/world_west.tscn", "🌑 Bosque Oscuro")
	var w_side_h := half_h - PATH_WIDTH / 2.0
	_add_border_wall(Vector2(west_x, -(PATH_WIDTH / 2.0 + w_side_h / 2.0)), Vector2(40, w_side_h))
	_add_border_wall(Vector2(west_x,  (PATH_WIDTH / 2.0 + w_side_h / 2.0)), Vector2(40, w_side_h))

func _add_border_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var shape_node := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	shape_node.shape = rect_shape
	body.add_child(shape_node)
	add_child(body)

func _create_border_trigger(pos: Vector2, size: Vector2, direction: String,
		target: String, label: String) -> void:
	var area = Area2D.new()
	area.position = pos
	area.set_script(load("res://scripts/scene_transition.gd"))
	add_child(area)
	var shape_node = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = size
	shape_node.shape = rect_shape
	area.add_child(shape_node)
	area.target_scene         = target
	area.transition_direction = direction
	area.zone_label           = label

func _process(delta: float) -> void:
	_process_vfx(delta)
	_process_tree_anims(delta)
	_process_animated_grass(delta)

func _process_tree_anims(delta: float) -> void:
	for d in _tree_anim_data:
		if not is_instance_valid(d["sprite"]):
			continue
		d["elapsed"] += delta
		if d["elapsed"] >= d["interval"]:
			d["elapsed"] = 0.0
			d["cur_frame"] = (d["cur_frame"] + 1) % d["frame_count"]
			var sp: Sprite2D = d["sprite"]
			sp.region_rect = Rect2(d["cur_frame"] * d["frame_w"], 0, d["frame_w"], d["frame_h"])

# ════════════════════════════════════════════════════════════
# RECURSOS & AGUA
# ════════════════════════════════════════════════════════════

func _spawn_resource_nodes() -> void:
	# Árboles
	_spawn_resource(Vector2(-620,  200), "tree",     "wood_log",          1, 3, Color(0.15, 0.50, 0.10), 40.0)
	_spawn_resource(Vector2(-680, -200), "tree",     "wood_log",          1, 3, Color(0.15, 0.50, 0.10), 40.0)
	_spawn_resource(Vector2( 660,  250), "tree",     "wood_log",          2, 4, Color(0.15, 0.50, 0.10), 40.0)
	# Mineral
	_spawn_resource(Vector2(-420,  360), "iron_ore", "ore",          1, 2, Color(0.55, 0.55, 0.60), 60.0)
	_spawn_resource(Vector2( 700, -180), "iron_ore", "ore",          1, 2, Color(0.55, 0.55, 0.60), 60.0)
	# Hierbas (kale) — parche norte del pueblo
	_spawn_resource_herb(Vector2( 360,  355), "herb_kale")
	_spawn_resource_herb(Vector2( 410,  340), "herb_kale")
	_spawn_resource_herb(Vector2(-250, -310), "herb_kale")
	# Hierbas (girasol) — parche sur
	_spawn_resource_herb(Vector2(-300, -280), "herb_sunflower")
	_spawn_resource_herb(Vector2( 290,  390), "herb_sunflower")
	# Hongos
	_spawn_resource(Vector2(-200,  -90), "mushroom", "material_mushroom", 1, 3, Color(0.80, 0.30, 0.18), 30.0)
	_spawn_resource(Vector2( 450, -300), "mushroom", "material_mushroom", 1, 2, Color(0.80, 0.30, 0.18), 30.0)

func _spawn_resource(pos: Vector2, type: String, key: String, min_q: int,
		max_q: int, color: Color, respawn_sec: float) -> void:
	var node = Node2D.new()
	node.set_script(load("res://scripts/resource_node.gd"))
	node.position = pos
	node.resource_type = type
	node.item_key      = key
	node.qty_min       = min_q
	node.qty_max       = max_q
	node.respawn_time  = respawn_sec
	add_child(node)

func _spawn_resource_herb(pos: Vector2, variant: String = "") -> void:
	var node = Node2D.new()
	node.set_script(load("res://scripts/resource_node.gd"))
	node.position      = pos
	node.resource_type = "herb"
	node.item_key      = "material_herb"
	node.qty_min       = 1
	node.qty_max       = 3
	node.respawn_time  = 25.0
	if variant != "":
		node.herb_variant = variant
	add_child(node)

func _setup_water_collision() -> void:
	var water_blocks = [
		[-793.0, 187.0,  320.0, 104.0],
		[-793.0, 461.5,  320.0, 147.0],
	]
	var river_area = get_node_or_null("GroundLayer/RiverArea")
	if not river_area:
		river_area = self
	for block in water_blocks:
		var body = StaticBody2D.new()
		body.position        = Vector2(block[0], block[1])
		body.collision_layer = 1
		body.collision_mask  = 0
		body.z_index         = -5
		river_area.add_child(body)
		var shape_node = CollisionShape2D.new()
		var rect       = RectangleShape2D.new()
		rect.size      = Vector2(block[2], block[3])
		shape_node.shape = rect
		body.add_child(shape_node)

# ════════════════════════════════════════════════════════════
# TALL GRASS — Hierba Alta con Animación de Viento
# ════════════════════════════════════════════════════════════
# Llamar desde _ready() después de _add_tileset_decorations()

func _spawn_tall_grass() -> void:
	var grass_scene_path := "res://scenes/grass_tall.tscn"
	if not ResourceLoader.exists(grass_scene_path):
		push_warning("[TownScene] grass_tall.tscn no encontrada, omitiendo hierba alta")
		return

	var grass_packed : PackedScene = load(grass_scene_path)
	var ground_layer : Node2D = get_node_or_null("GroundLayer")
	if not ground_layer:
		ground_layer = self

	# Posiciones de la hierba (evitando caminos y edificios)
	# Formato: [x, y, escala_x]  — escala_x negativa = espejo horizontal
	var spots : Array = [
		[-750.0, -350.0,  1.0], [-650.0, -280.0, -1.0],
		[-820.0,  150.0,  1.0], [-700.0,  240.0, -1.0],
		[ 600.0, -350.0,  1.0], [ 720.0, -200.0, -1.0],
		[ 650.0,  250.0,  1.0], [ 780.0,  380.0, -1.0],
		[-300.0,  350.0,  1.0], [ 300.0,  380.0, -1.0],
		[-800.0,   50.0, -1.0], [ 800.0,   60.0,  1.0],
		[-200.0, -400.0,  1.0], [ 200.0, -420.0, -1.0],
		[-500.0,  430.0,  1.0], [ 500.0,  430.0, -1.0],
	]

	for s in spots:
		var g : Node2D = grass_packed.instantiate()
		g.position = Vector2(s[0], s[1])
		# Scale: pixel art sprites are 32px, scale to ~2x so they fit the scene (not 3.5x like chars)
		g.scale    = Vector2(s[2] * 2.0, 2.0)
		g.z_index  = int((s[1] + 540.0) / 8.0)   # y-sort con offset
		ground_layer.add_child(g)
		# Desfasar la fase inicial para que no todas animen igual
		if g.has_method("randomize_phase"):
			g.randomize_phase()

# ════════════════════════════════════════════════════════════
# 19. FIX COLISIÓN EDIFICIOS — Asigna RectangleShape2D a cada edificio
# ════════════════════════════════════════════════════════════

func _fix_building_collisions() -> void:
	# Datos: [nombre_nodo, half_w, half_h, offset_x, offset_y, base_y_world]
	# base_y_world = Y aproximada de la BASE del edificio en coordenadas del mundo
	# z_index = int(base_y / 8)  — igual que el jugador, para y-sorting correcto
	# IMPORTANTE: debe ser > -20 (z del fondo) para que el sprite sea visible
	var building_data := [
		["Buildings/Bank",         130.0, 52.0,  -10.0,  20.0, -151],
		["Buildings/StoneDungeon", 110.0, 48.0,    0.0,  30.0, -294],
		["Buildings/Forge",        100.0, 48.0,    0.0,  20.0,  268],
		["Buildings/Market",        88.0, 44.0,    0.0,  20.0,  -57],
		["Buildings/Tailor",        80.0, 40.0,   40.0,   0.0,  -26],
		["Buildings/House1",        70.0, 38.0,  112.0,  78.0,  192],
		["Buildings/House2",        70.0, 38.0,   -2.0,  16.0,  470],
		["Buildings/House3",        70.0, 38.0,    0.0,  16.0,  470],
		["Buildings/House4",        70.0, 38.0,    0.0,  16.0,  -55],
	]
	for bd in building_data:
		var body : Node = get_node_or_null(bd[0])
		if not body:
			continue
		# z_index con la misma fórmula que jugador/NPC: int((base_y + 540) / 8)
		body.z_index = int((bd[5] + 540) / 8)

		# Buscar o crear CollisionShape2D
		var cshape : CollisionShape2D = null
		for child in body.get_children():
			if child is CollisionShape2D:
				cshape = child
				break
		if not cshape:
			cshape = CollisionShape2D.new()
			body.add_child(cshape)
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(bd[1] * 2.0, bd[2] * 2.0)
		cshape.shape    = rect_shape
		cshape.position = Vector2(bd[3], bd[4])

# ════════════════════════════════════════════════════════════
# 20. PASTO ANIMADO — Hierba con viento e interacción (IA-generada)
# ════════════════════════════════════════════════════════════

var _grass_instances : Array = []
var _grass_wind_timer : float = 0.0
var _grass_wind_strength : float = 0.0
var _grass_wind_target : float = 0.0
var _wind_change_timer : float = 0.0

# Datos de cada mata de pasto: {node, base_pos, phase, speed, sway_dir}
var _grass_data : Array = []

func _spawn_animated_grass() -> void:
	var ground_layer : Node2D = get_node_or_null("GroundLayer")
	if not ground_layer:
		ground_layer = self

	# Zonas de pasto: evitar caminos (x ±48, y ±48) y edificios
	# Formato: [x, y, flip]
	var spots : Array = [
		[-750.0, -370.0, false], [-690.0, -310.0, true],  [-830.0, -250.0, false],
		[-820.0,  130.0, false], [-760.0,  210.0, true],  [-880.0,  290.0, false],
		[-820.0,  430.0, true],  [-750.0,  480.0, false],
		[ 600.0, -370.0, false], [ 680.0, -280.0, true],  [ 750.0, -440.0, false],
		[ 650.0,  280.0, false], [ 720.0,  370.0, true],  [ 800.0,  450.0, false],
		[-330.0,  390.0, false], [-260.0,  460.0, true],  [ 280.0,  390.0, false],
		[ 350.0,  460.0, true],  [-400.0, -400.0, false], [ 420.0, -390.0, true],
		[-150.0,  200.0, false], [ 160.0,  210.0, true],  [-200.0,  430.0, false],
		[ 220.0,  430.0, true],  [ 800.0,  100.0, false], [-850.0,   50.0, true],
	]

	for s in spots:
		var grass_node := _make_grass_sprite()
		if not grass_node:
			break
		grass_node.position = Vector2(s[0], s[1])
		grass_node.scale    = Vector2(2.2, 2.2)
		grass_node.z_index  = int((s[1] + 540.0) / 8.0)
		if s[2]:
			grass_node.scale.x = -2.2
		ground_layer.add_child(grass_node)

		var gd := {
			"node":     grass_node,
			"base_pos": Vector2(s[0], s[1]),
			"phase":    randf() * TAU,
			"speed":    randf_range(0.8, 1.6),
			"sway_dir": 1.0 if randf() > 0.5 else -1.0,
			"interacting": false,
			"interact_timer": 0.0,
		}
		_grass_data.append(gd)
		_grass_instances.append(grass_node)

	# Iniciar viento suave
	_grass_wind_strength = randf_range(0.3, 0.7)
	_grass_wind_target   = _grass_wind_strength

func _make_grass_sprite() -> Node2D:
	# Usar la textura existente de hierba alta
	var tex_path := "res://assets/decorations/grass_ai_wind.png"
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/decorations/grass_tall_wind.png"
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/decorations/grass_tall_interact.png"
	if not ResourceLoader.exists(tex_path):
		return null

	var tex : Texture2D = load(tex_path)
	var node := Node2D.new()
	node.name = "GrassAnimated"

	# Sprite animado: la hoja de sprites tiene los frames en horizontal
	var sp := Sprite2D.new()
	sp.texture        = tex
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered       = true
	# Detectar frames (wind = 4 frames de 16px de ancho si el sprite es 64×16)
	var frame_count: int = max(1, tex.get_width() / 16)
	sp.hframes = frame_count
	sp.vframes = 1
	sp.frame   = randi() % frame_count
	node.add_child(sp)
	node.set_meta("sprite", sp)
	node.set_meta("frame_count", frame_count)
	node.set_meta("anim_timer", 0.0)
	node.set_meta("anim_speed", randf_range(6.0, 9.0))  # fps

	# Área de interacción — detecta al jugador
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 1   # capa del jugador
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 18.0
	cs.shape    = circ
	cs.position = Vector2(0, -4)
	area.add_child(cs)
	node.add_child(area)
	node.set_meta("area", area)
	node.set_meta("player_near", false)

	return node

func _process_animated_grass(delta: float) -> void:
	# Actualizar viento global
	_wind_change_timer -= delta
	if _wind_change_timer <= 0.0:
		_wind_change_timer = randf_range(2.0, 5.0)
		_grass_wind_target = randf_range(0.2, 1.0)

	_grass_wind_strength = lerp(_grass_wind_strength, _grass_wind_target, delta * 0.5)

	var player : Node2D = get_tree().get_first_node_in_group("player")

	for gd in _grass_data:
		var grass_node : Node2D = gd["node"]
		if not is_instance_valid(grass_node):
			continue

		# Detectar proximidad del jugador manualmente (más barato que señales)
		var near := false
		if player and is_instance_valid(player):
			near = grass_node.global_position.distance_to(player.global_position) < 32.0

		# Animación de frame (viento)
		if grass_node.has_meta("sprite"):
			var sp : Sprite2D = grass_node.get_meta("sprite")
			var fc : int      = grass_node.get_meta("frame_count")
			var at : float    = grass_node.get_meta("anim_timer")
			var asp : float   = grass_node.get_meta("anim_speed")
			at += delta
			if at >= 1.0 / asp:
				at = 0.0
				sp.frame = (sp.frame + 1) % fc
			grass_node.set_meta("anim_timer", at)

		# Sway de posición: oscilación sinusoidal suave (viento)
		gd["phase"] = gd["phase"] + delta * gd["speed"] * gd["sway_dir"]
		var sway_x := sin(gd["phase"]) * 1.8 * _grass_wind_strength

		# Si jugador cerca: aplastamiento extra
		if near:
			var push_dir := (grass_node.global_position - player.global_position).normalized()
			sway_x += push_dir.x * 4.0

		grass_node.position = gd["base_pos"] + Vector2(sway_x, 0.0)



func _on_arbol_1_draw() -> void:
	pass # Replace with function body.
