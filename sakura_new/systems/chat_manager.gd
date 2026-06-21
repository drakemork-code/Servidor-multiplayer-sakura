# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# CHAT MANAGER — Autoload global
# Canales: Global, Local (radio), Grupo, Gremio
# Simulación realista de jugadores online
# ============================================================

signal message_received(channel: String, sender: String, text: String, color: Color)
signal channel_changed(channel: String)

enum Channel { GLOBAL, LOCAL, GROUP, GUILD }

const LOCAL_RADIUS: float = 600.0
const MAX_HISTORY: int = 200

var active_channel: Channel = Channel.GLOBAL

var history: Dictionary = {
	"global": [],
	"local":  [],
	"group":  [],
	"guild":  [],
}
var _use_network: bool = true   # false = modo offline/simulado

# Timers para distintos patrones de chat
var _sim_timer: float       = 0.0
var _burst_timer: float     = 0.0
var _burst_count: int       = 0
var _burst_active: bool     = false
var _next_interval: float   = 8.0
var _local_timer: float     = 0.0

# Conversaciones encadenadas (pares que se responden)
var _pending_replies: Array = []

# ── Perfiles de jugadores simulados con personalidad ──────────
const PLAYERS: Array = [
	{"name": "Nakari",    "col": Color(0.85, 0.60, 1.00), "style": "casual"},
	{"name": "Thorvik",   "col": Color(0.90, 0.75, 0.40), "style": "trader"},
	{"name": "Lirien",    "col": Color(0.55, 1.00, 0.70), "style": "helper"},
	{"name": "Yuzuki",    "col": Color(1.00, 0.70, 0.75), "style": "newbie"},
	{"name": "Draken",    "col": Color(0.75, 0.85, 1.00), "style": "veteran"},
	{"name": "Mira",      "col": Color(0.70, 1.00, 0.85), "style": "casual"},
	{"name": "Kaziel",    "col": Color(1.00, 0.85, 0.40), "style": "veteran"},
	{"name": "Syl",       "col": Color(0.90, 0.60, 0.60), "style": "trader"},
	{"name": "Vorn",      "col": Color(0.65, 0.80, 1.00), "style": "helper"},
	{"name": "Aelith",    "col": Color(1.00, 0.95, 0.65), "style": "casual"},
]

# ── Mensajes globales realistas por categoría ─────────────────
const MSGS_BOSS: Array = [
	["Lirien",  "Boss del Norte en 2 min! Alguien se apunta?"],
	["Draken",  "El Skeleton King ha respawneado, voy para allá"],
	["Kaziel",  "Cuidado con el boss del Este — tiene nueva fase de hielo"],
	["Vorn",    "¿Cuántos para el boss? Necesito al menos 3"],
	["Nakari",  "Boss raid en 10 min — guild channel para coord"],
]
const MSGS_TRADE: Array = [
	["Thorvik", "Vendo Hacha T2 +15%  ATK — DM si te interesa"],
	["Syl",     "Compro cristales de maná x20, pago bien"],
	["Thorvik", "WTS: Armadura de cuero Lv 18, oferta inicial 8g"],
	["Mira",    "Vendo pociones de vida x50 — baratas, pasad por el mercado"],
	["Syl",     "Busco receta de forja T3, cambio por materiales raros"],
]
const MSGS_SOCIAL: Array = [
	["Yuzuki",  "¡¡Llegué al nivel 20!! 🎉🎉"],
	["Nakari",  "jajaja me acabo de caer al vacío con todo el loot"],
	["Aelith",  "¿Alguien sabe dónde está el herrero nuevo?"],
	["Mira",    "Llevo 3 horas farmeando y nada... suerte cero 😩"],
	["Yuzuki",  "Este juego engancha demasiado, son las 2am..."],
	["Nakari",  "Por fin conseguí el set completo de oscuridad 😤"],
	["Aelith",  "¿El dungeon de piedra da buen XP? Primera vez yendo"],
]
const MSGS_INFO: Array = [
	["Draken",  "Los nodos de cristal del Sur han respawneado"],
	["Kaziel",  "Tip: el goblin shamán del bosque dropea bastón épico al 3%"],
	["Vorn",    "El mercader ambulante está al SW del mapa hoy"],
	["Lirien",  "Doble XP los viernes en dungeons, no lo olviden"],
	["Draken",  "Si corréis al NE hay un evento de invasión activo ahora"],
]
const MSGS_GUILD: Array = [
	["Kaziel",  "Gremio <DragonSoul> recluta — Lv 15+, activos"],
	["Lirien",  "¿Alguien libre para guild quest esta noche?"],
	["Nakari",  "Los del gremio ya tenemos la segunda sede desbloqueada 🏰"],
]
const MSGS_QUESTION: Array = [
	["Yuzuki",  "¿Cómo se desbloquea la profesión de alquimista?"],
	["Aelith",  "¿Alguien tiene mapa del dungeon subterráneo?"],
	["Mira",    "¿Qué arma es mejor para mago a nivel 15, báculo o varita?"],
]

# Respuestas posibles para preguntas comunes
const REPLIES: Dictionary = {
	"alquimista": [["Vorn", "Habla con la NPC del mercado central, ella da la quest inicial"]],
	"mago":       [["Draken", "Báculo da más DMG, varita más velocidad de cast — depende tu build"]],
	"dungeon":    [["Kaziel", "El mapa del dungeon está en el noticiero al entrar, arriba izda"]],
}

# Conversaciones multi-turno realistas
const CONVOS: Array = [
	[
		["Yuzuki",  "¿Alguien puede acompañarme al boss? soy curandera"],
		["Vorn",    "Yo voy, soy tanque Lv 22"],
		["Nakari",  "Me apunto también, tengo DPS"],
		["Lirien",  "Voy en 5 min, termino de vender"],
	],
	[
		["Mira",    "Me han dropeado un báculo épico 😱😱"],
		["Aelith",  "nooooo que envidia!! de qué boss?"],
		["Mira",    "Del lich del dungeon helado, 4to piso"],
		["Draken",  "Ese boss es muy difícil, gratz!"],
		["Kaziel",  "Gg, te lo has ganado"],
	],
	[
		["Thorvik", "Bajan los precios del cristal de mana..."],
		["Syl",     "Sí, demasiada gente farmeando la cueva norte"],
		["Thorvik", "Voy a esperar a que suba antes de vender"],
		["Syl",     "Buena idea, yo igual"],
	],
	[
		["Aelith",  "¿Hay servidores caídos o es mi internet?"],
		["Yuzuki",  "A mí me va bien"],
		["Vorn",    "Igual, sin problemas"],
		["Aelith",  "Ok gracias, era mi wifi xd"],
	],
]

var _convo_index: int = 0
var _convo_msg_index: int = -1
var _convo_timer: float = 0.0
var _in_convo: bool = false

func _ready() -> void:
	_post_system_msg("global", "Bienvenido a Sakura Chronicles — Canal: Global")
	# Poblar con mensajes iniciales para que el chat no esté vacío
	await get_tree().create_timer(1.5).timeout
	_burst_initial_chat()
	print("[ChatManager] Inicializado")

func _burst_initial_chat() -> void:
	# Simula que hay actividad cuando el jugador entra
	var intro_msgs = [
		["Lirien",  "El boss del Norte acaba de morir, fue épico"],
		["Kaziel",  "Buenas a todos"],
		["Thorvik", "Vendo espada T2, precio justo — /tell Thorvik"],
		["Yuzuki",  "¡Finalmente desbloqueé la segunda habilidad! 🔥"],
		["Draken",  "Cuidado en el bosque sur, spawnearon élites"],
	]
	var delay = 0.4
	for msg in intro_msgs:
		var captured = msg
		get_tree().create_timer(delay).timeout.connect(func():
			receive_message("global", captured[0], captured[1])
		)
		delay += randf_range(0.6, 1.8)

func _process(delta: float) -> void:
	# Conversación en curso
	if _in_convo:
		_convo_timer += delta
		if _convo_timer >= randf_range(2.5, 5.0):
			_convo_timer = 0.0
			_continue_convo()
		return

	_sim_timer += delta
	_local_timer += delta

	# Mensajes globales cada 8-25 segundos con variación natural
	if _sim_timer >= _next_interval:
		_sim_timer = 0.0
		_next_interval = randf_range(8.0, 25.0)
		_fire_random_global()
		# 15% de probabilidad de iniciar conversación
		if randf() < 0.15:
			_start_random_convo()

	# Mensajes locales menos frecuentes
	if _local_timer >= randf_range(30.0, 60.0):
		_local_timer = 0.0
		_fire_local_msg()

func _fire_random_global() -> void:
	# Elige una categoría con probabilidades distintas
	var roll = randf()
	var pool: Array
	if roll < 0.25:
		pool = MSGS_SOCIAL
	elif roll < 0.45:
		pool = MSGS_TRADE
	elif roll < 0.60:
		pool = MSGS_BOSS
	elif roll < 0.75:
		pool = MSGS_INFO
	elif roll < 0.88:
		pool = MSGS_QUESTION
	else:
		pool = MSGS_GUILD
	var entry = pool[randi() % pool.size()]
	receive_message("global", entry[0], entry[1])

func _fire_local_msg() -> void:
	var local_msgs = [
		["Pasante",   "Oye, buen equipo llevas 👀"],
		["Wanderer",  "¿Sabes dónde están los nodos de cristal?"],
		["Hunter",    "Cuidado, mobs de élite al norte del camino"],
		["Aelith",    "Hey, ¿también tú aquí? "],
		["Syl",       "¿Llevas mucho tiempo en esta zona?"],
		["NPC_Guard", "Viajero, mantén la guardia en este sector"],
	]
	var e = local_msgs[randi() % local_msgs.size()]
	receive_message("local", e[0], e[1])

func _start_random_convo() -> void:
	_convo_index = randi() % CONVOS.size()
	_convo_msg_index = 0
	_in_convo = true
	_convo_timer = 0.0
	# Enviar primer mensaje inmediatamente
	var msg = CONVOS[_convo_index][0]
	receive_message("global", msg[0], msg[1])
	_convo_msg_index = 1

func _continue_convo() -> void:
	var convo = CONVOS[_convo_index]
	if _convo_msg_index >= convo.size():
		_in_convo = false
		return
	var msg = convo[_convo_msg_index]
	receive_message("global", msg[0], msg[1])
	_convo_msg_index += 1
	if _convo_msg_index >= convo.size():
		_in_convo = false

# ──────────────────────────────────────────────
# ENVIAR MENSAJE (jugador local)
# ──────────────────────────────────────────────
func send_message(channel_name: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	if _use_network and multiplayer.has_multiplayer_peer() and NetworkManager.is_client:
		NetworkManager.send_chat(channel_name, text)
	else:
		receive_message(channel_name, PlayerData.character_name, text)


func _schedule_reply(channel_key: String, question: String) -> void:
	var lower = question.to_lower()
	var reply_pool: Array = []
	for key in REPLIES:
		if lower.find(key) != -1:
			reply_pool = REPLIES[key]
			break
	if reply_pool.is_empty():
		# Respuesta genérica
		var generics = [
			["Vorn",   "No estoy seguro, pregunta en el discord del gremio"],
			["Lirien", "Creo que sí, pero confirma con alguien más"],
			["Kaziel", "Yo tampoco sé bien, lo siento"],
			["Nakari", "Buena pregunta, yo quiero saber también"],
		]
		reply_pool = [generics[randi() % generics.size()]]
	var reply = reply_pool[randi() % reply_pool.size()]
	var delay = randf_range(3.0, 9.0)
	get_tree().create_timer(delay).timeout.connect(func():
		receive_message(channel_key, reply[0], reply[1])
	)

# ──────────────────────────────────────────────
# RECIBIR MENSAJE
# ──────────────────────────────────────────────
func receive_message(channel_key: String, sender: String, text: String) -> void:
	# Usar color del perfil del jugador si existe
	var col := Color(0.85, 0.85, 0.85)
	match channel_key:
		"global": col = Color(0.85, 0.85, 0.85)
		"local":  col = Color(0.75, 1.00, 0.75)
		"group":  col = Color(0.55, 0.85, 1.00)
		"guild":  col = Color(1.00, 0.85, 0.40)
	# Buscar color personalizado del jugador
	for p in PLAYERS:
		if p["name"] == sender:
			col = p["col"]
			break
	_push(channel_key, sender, text, col)
	message_received.emit(channel_key, sender, text, col)

func set_active_channel(channel: Channel) -> void:
	active_channel = channel
	channel_changed.emit(_channel_key(channel))

func get_history(channel_key: String) -> Array:
	return history.get(channel_key, [])

# ──────────────────────────────────────────────
# INTERNOS
# ──────────────────────────────────────────────
func _push(key: String, sender: String, text: String, col: Color) -> void:
	if not history.has(key):
		history[key] = []
	history[key].append({"sender": sender, "text": text, "color": col,
		"time": Time.get_time_string_from_system()})
	if history[key].size() > MAX_HISTORY:
		history[key].pop_front()

func _post_system_msg(key: String, text: String) -> void:
	_push(key, "Sistema", text, Color(0.60, 0.60, 0.70))
	message_received.emit(key, "Sistema", text, Color(0.60, 0.60, 0.70))

func _channel_key(c: Channel) -> String:
	match c:
		Channel.GLOBAL: return "global"
		Channel.LOCAL:  return "local"
		Channel.GROUP:  return "group"
		Channel.GUILD:  return "guild"
	return "global"
