# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# AUDIO MANAGER — Autoload Singleton
# Nombre de autoload: AudioManager
# Ruta: res://systems/audio_manager.gd
#
# Funcionalidades:
#   - Música de fondo por zona con crossfade
#   - Música de boss (duck + swap al entrar zona boss)
#   - SFX en pool (hasta 8 canales simultáneos)
#   - Volumen maestro, música y SFX independientes
#   - Fade in/out global (para transiciones de escena)
#   - FIX: tweens únicos para evitar trabarse
#   - FIX: loop garantizado en todos los streams OGG
#   - FIX: reinicio limpio al regresar a zona previamente visitada
# ============================================================

# ── Rutas de música ─────────────────────────────────────────
const ZONE_MUSIC: Dictionary = {
	"town":         "res://audio/music/ambient_town.ogg",
	"dungeon":      "res://audio/music/ambient_dungeon.ogg",
	"world_north":  "res://audio/music/ambient_snow.ogg",
	"world_south":  "res://audio/music/ambient_field.ogg",
	"world_east":   "res://audio/music/ambient_volcano.ogg",
	"world_west":   "res://audio/music/ambient_dark_forest.ogg",
}

# Música del menú principal / login
const LOGIN_MUSIC_PATH: String = "res://audio/music/where_the_valley_meets_sky.mp3"

const BOSS_MUSIC: Dictionary = {
	"world_north":  "res://audio/music/boss_skeleton_king.ogg",
	"world_south":  "res://audio/music/boss_goblin_shaman.ogg",
	"world_east":   "res://audio/music/boss_orc_warlord.ogg",
	"world_west":   "res://audio/music/boss_shadow_lord.ogg",
	"dungeon":      "res://audio/music/boss_dungeon.ogg",
}

# ── Rutas de SFX ────────────────────────────────────────────
const SFX_PATHS: Dictionary = {
	"hit":                "res://audio/sfx/hit.ogg",
	"hit_heavy":          "res://audio/sfx/hit_heavy.ogg",
	"miss":               "res://audio/sfx/miss.ogg",
	"level_up":           "res://audio/sfx/level_up.ogg",
	"player_death":       "res://audio/sfx/player_death.ogg",
	"enemy_death":        "res://audio/sfx/enemy_death.ogg",
	"boss_death":         "res://audio/sfx/boss_death.ogg",
	"boss_roar":          "res://audio/sfx/boss_roar.ogg",
	"collect_tree":       "res://audio/sfx/collect_wood.ogg",
	"collect_herb":       "res://audio/sfx/collect_herb.ogg",
	"collect_iron_ore":   "res://audio/sfx/collect_mine.ogg",
	"collect_mushroom":   "res://audio/sfx/collect_herb.ogg",
	"collect_crystal":    "res://audio/sfx/collect_crystal.ogg",
	"collect_bone":       "res://audio/sfx/collect_bone.ogg",
	"buy":                "res://audio/sfx/buy.ogg",
	"sell":               "res://audio/sfx/sell.ogg",
	"craft":              "res://audio/sfx/craft.ogg",
	"deposit":            "res://audio/sfx/deposit.ogg",
	"error":              "res://audio/sfx/error.ogg",
	"menu_open":          "res://audio/sfx/menu_open.ogg",
	"menu_close":         "res://audio/sfx/menu_close.ogg",
	"item_pickup":        "res://audio/sfx/item_pickup.ogg",
	"footstep_snow":      "res://audio/sfx/footstep_snow.ogg",
	"footstep_grass":     "res://audio/sfx/footstep_grass.ogg",
	"footstep_stone":     "res://audio/sfx/footstep_stone.ogg",
	"scene_transition":   "res://audio/sfx/scene_transition.ogg",
}

# ── Buses ────────────────────────────────────────────────────
const BUS_MASTER: String = "Master"
const BUS_MUSIC:  String = "Music"
const BUS_SFX:    String = "SFX"

# ── Players ──────────────────────────────────────────────────
var _music_player_a: AudioStreamPlayer = null
var _music_player_b: AudioStreamPlayer = null
var _boss_player:    AudioStreamPlayer = null
var _sfx_pool:       Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8

# ── Estado ───────────────────────────────────────────────────
var _current_zone:        String = ""
var _current_music_path:  String = ""
var _in_boss_zone:        bool   = false

var _music_volume:   float = 0.8
var _sfx_volume:     float = 1.0
var _master_volume:  float = 1.0

const CROSSFADE_TIME: float = 1.5
const BOSS_DUCK_DB:   float = -10.0

# FIX: guardamos referencia a tweens activos para cancelarlos antes de crear nuevos
var _crossfade_tween: Tween = null
var _boss_tween:      Tween = null

# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_ensure_audio_buses()
	_build_music_players()
	_build_sfx_pool()
	print("[AudioManager] Inicializado — buses: %s / %s / %s" % [BUS_MASTER, BUS_MUSIC, BUS_SFX])

# ══════════════════════════════════════════════════════════════
# BUSES DE AUDIO
# ══════════════════════════════════════════════════════════════

func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, BUS_MUSIC)
		AudioServer.set_bus_send(idx, BUS_MASTER)

	if AudioServer.get_bus_index(BUS_SFX) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, BUS_MASTER)

	_apply_volumes()

# ══════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE PLAYERS
# ══════════════════════════════════════════════════════════════

func _build_music_players() -> void:
	_music_player_a = _make_music_player("MusicA")
	_music_player_b = _make_music_player("MusicB")
	_boss_player    = _make_music_player("BossMusic")
	_boss_player.volume_db = -80.0

func _make_music_player(node_name: String) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.name       = node_name
	p.bus        = BUS_MUSIC
	p.autoplay   = false
	p.volume_db  = -80.0
	add_child(p)
	return p

func _build_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		p.bus  = BUS_SFX
		add_child(p)
		_sfx_pool.append(p)

# ══════════════════════════════════════════════════════════════
# MÚSICA DE ZONA
# ══════════════════════════════════════════════════════════════

func play_zone_music(zone: String) -> void:
	# FIX: siempre restaurar el volumen del bus Master al entrar a una escena nueva.
	# El fade_out() de la transición baja el Master a 0; sin este fade_in la música
	# se reproduce pero no se escucha nada.
	_restore_master_volume()

	# FIX: si es la misma zona sin boss, solo saltar si el player A realmente suena.
	# Antes se salteaba siempre, causando que al volver de boss la música no reiniciara.
	if zone == _current_zone and not _in_boss_zone:
		if _music_player_a.playing:
			return

	_current_zone = zone
	_in_boss_zone = false

	var path: String = ZONE_MUSIC.get(zone, "")
	if path == "" or not ResourceLoader.exists(path):
		_safe_fade_out(_music_player_a, CROSSFADE_TIME)
		_safe_fade_out(_boss_player, CROSSFADE_TIME * 0.5)
		return

	_crossfade_to(path)

# FIX: restaura el bus Master al volumen correcto cancelando cualquier fade_out activo.
# Se llama siempre al iniciar música de zona para garantizar que se escuche.
func _restore_master_volume() -> void:
	var master_idx = AudioServer.get_bus_index(BUS_MASTER)
	if master_idx < 0:
		return
	var current_db = AudioServer.get_bus_volume_db(master_idx)
	var target_db  = linear_to_db(_master_volume)
	# Si ya está al volumen correcto no hacer nada
	if abs(current_db - target_db) < 0.5:
		return
	# Fade suave de vuelta al volumen normal (0.6s — más corto que el crossfade)
	var tw = create_tween()
	tw.tween_method(
		func(v: float): AudioServer.set_bus_volume_db(master_idx, linear_to_db(v)),
		db_to_linear(current_db), _master_volume, 0.6
	)

func _crossfade_to(new_path: String) -> void:
	# FIX: si la ruta es la misma Y ya está sonando, no interrumpir
	if new_path == _current_music_path and _music_player_a.playing:
		return
	_current_music_path = new_path

	# FIX: cancelar tween anterior para no tener múltiples tweens compitiendo
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	var fade_in_player  = _music_player_b if _music_player_a.playing else _music_player_a
	var fade_out_player = _music_player_a if fade_in_player == _music_player_b else _music_player_b

	var stream = load(new_path)
	if stream == null:
		return
	# FIX: garantizar loop en OGG (Godot 4 no hace loop por defecto)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	# Soporte MP3 con loop
	if stream is AudioStreamMP3:
		stream.loop = true

	fade_in_player.stream    = stream
	fade_in_player.volume_db = -80.0
	fade_in_player.play()

	# FIX: usar variable para poder cancelar el tween si se llama otro crossfade
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)
	_crossfade_tween.tween_property(fade_in_player,  "volume_db", linear_to_db(_music_volume), CROSSFADE_TIME)
	_crossfade_tween.tween_property(fade_out_player, "volume_db", -80.0,                        CROSSFADE_TIME)
	# Capturar referencia local para el lambda (evita que el closure capture el var que cambia)
	var _fop: AudioStreamPlayer = fade_out_player
	_crossfade_tween.finished.connect(func():
		if is_instance_valid(_fop):
			_fop.stop()
	)

	_music_player_a = fade_in_player
	_music_player_b = fade_out_player

# ══════════════════════════════════════════════════════════════
# MÚSICA DE BOSS
# ══════════════════════════════════════════════════════════════

func play_boss_music(zone: String) -> void:
	if _in_boss_zone:
		return
	_in_boss_zone = true

	var path: String = BOSS_MUSIC.get(zone, "")
	if path == "" or not ResourceLoader.exists(path):
		return

	var stream = load(path)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true

	# FIX: cancelar tweens de boss anteriores
	if _boss_tween and _boss_tween.is_valid():
		_boss_tween.kill()

	_boss_tween = create_tween()
	_boss_tween.set_parallel(true)
	_boss_tween.tween_property(_music_player_a, "volume_db",
		linear_to_db(_music_volume) + BOSS_DUCK_DB, 0.8)

	_boss_player.stream    = stream
	_boss_player.volume_db = -80.0
	_boss_player.play()
	_boss_tween.tween_property(_boss_player, "volume_db", linear_to_db(_music_volume), 0.8)

func stop_boss_music() -> void:
	if not _in_boss_zone:
		return
	_in_boss_zone = false

	if _boss_tween and _boss_tween.is_valid():
		_boss_tween.kill()

	_boss_tween = create_tween()
	_boss_tween.set_parallel(true)
	_boss_tween.tween_property(_music_player_a, "volume_db", linear_to_db(_music_volume), 1.2)
	_boss_tween.tween_property(_boss_player, "volume_db", -80.0, 1.2)
	var _bp: AudioStreamPlayer = _boss_player
	_boss_tween.finished.connect(func():
		if is_instance_valid(_bp):
			_bp.stop()
	)

# ══════════════════════════════════════════════════════════════
# SFX
# ══════════════════════════════════════════════════════════════

func play_sfx(sfx_key: String, pitch_variation: float = 0.0) -> void:
	var path: String = SFX_PATHS.get(sfx_key, "")
	if path == "" or not ResourceLoader.exists(path):
		return

	var stream = load(path)
	if stream == null:
		return

	var player = _get_free_sfx_player()
	if player == null:
		return

	player.stream    = stream
	player.volume_db = linear_to_db(_sfx_volume)
	if pitch_variation > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	else:
		player.pitch_scale = 1.0
	player.play()

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return _sfx_pool[0]

# ══════════════════════════════════════════════════════════════
# FADE GLOBAL (transiciones de escena)
# ══════════════════════════════════════════════════════════════

func fade_out(duration: float = 1.0) -> void:
	# FIX: limpiar _current_zone para que play_zone_music() de la nueva escena
	# no sea ignorado por el check "misma zona ya sonando".
	_current_zone = ""
	_current_music_path = ""
	var tw = create_tween()
	var master_idx = AudioServer.get_bus_index(BUS_MASTER)
	tw.tween_method(
		func(v: float): AudioServer.set_bus_volume_db(master_idx, linear_to_db(v)),
		_master_volume, 0.0, duration
	)

func fade_in(duration: float = 1.0) -> void:
	var master_idx = AudioServer.get_bus_index(BUS_MASTER)
	AudioServer.set_bus_volume_db(master_idx, -80.0)
	var tw = create_tween()
	tw.tween_method(
		func(v: float): AudioServer.set_bus_volume_db(master_idx, linear_to_db(v)),
		0.0, _master_volume, duration
	)

# FIX: versión segura de fade_out_player que no crea tweens huérfanos
func _safe_fade_out(player: AudioStreamPlayer, duration: float) -> void:
	if not is_instance_valid(player) or not player.playing:
		return
	var tw = create_tween()
	var _p: AudioStreamPlayer = player
	tw.tween_property(_p, "volume_db", -80.0, duration)
	tw.finished.connect(func():
		if is_instance_valid(_p):
			_p.stop()
	)

# Compatibilidad con código antiguo
func _fade_out_player(player: AudioStreamPlayer, duration: float) -> void:
	_safe_fade_out(player, duration)

# ══════════════════════════════════════════════════════════════
# CONTROL DE VOLUMEN
# ══════════════════════════════════════════════════════════════

func set_master_volume(value: float) -> void:
	_master_volume = clamp(value, 0.0, 1.0)
	_apply_volumes()

func set_music_volume(value: float) -> void:
	_music_volume = clamp(value, 0.0, 1.0)
	if _music_player_a.playing:
		_music_player_a.volume_db = linear_to_db(_music_volume)
	if _boss_player.playing:
		_boss_player.volume_db = linear_to_db(_music_volume)

func set_sfx_volume(value: float) -> void:
	_sfx_volume = clamp(value, 0.0, 1.0)

func _apply_volumes() -> void:
	var master_idx = AudioServer.get_bus_index(BUS_MASTER)
	var music_idx  = AudioServer.get_bus_index(BUS_MUSIC)
	var sfx_idx    = AudioServer.get_bus_index(BUS_SFX)

	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(_master_volume))
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(_music_volume))
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(_sfx_volume))

# ══════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════

func stop_all() -> void:
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	if _boss_tween and _boss_tween.is_valid():
		_boss_tween.kill()
	_music_player_a.stop()
	_music_player_b.stop()
	_boss_player.stop()
	for p in _sfx_pool:
		p.stop()

# ══════════════════════════════════════════════════════════════
# MÚSICA DE LOGIN / MENÚ PRINCIPAL
# ══════════════════════════════════════════════════════════════

func play_login_music() -> void:
	if not ResourceLoader.exists(LOGIN_MUSIC_PATH):
		push_warning("[AudioManager] No se encontró la música de login: %s" % LOGIN_MUSIC_PATH)
		return
	# Si ya está sonando la música de login, no interrumpir
	if _current_music_path == LOGIN_MUSIC_PATH and _music_player_a.playing:
		return
	_current_zone = "login"
	_crossfade_to(LOGIN_MUSIC_PATH)

func stop_login_music(fade_duration: float = 1.8) -> void:
	if _current_zone != "login":
		return
	_current_zone       = ""
	_current_music_path = ""
	_safe_fade_out(_music_player_a, fade_duration)
	_safe_fade_out(_music_player_b, fade_duration)

func is_playing_boss_music() -> bool:
	return _in_boss_zone and _boss_player.playing

func get_current_zone() -> String:
	return _current_zone
