extends Node
## ════════════════════════════════════════════════════════════════
## REDIS CLIENT (autoload, SOLO SERVIDOR) — cliente RESP mínimo vía
## StreamPeerTCP, hablando directo con Redis local en el mismo VPS
## (127.0.0.1:6379). NO pasa por Railway.
##
## Reemplaza el diseño original de PARTE 5.1 (Godot→Railway→Redis)
## por conexión directa, ya que Redis corre en la misma máquina que
## los 5 procesos de zona — evita el salto HTTP extra hacia Railway
## para cada consulta cross-zona de party.
##
## Implementa solo los 4 comandos que hacen falta: AUTH, SETEX, GET,
## DEL. No es un cliente Redis completo — es intencionalmente mínimo
## para no depender de una librería sin mantenimiento verificado
## (investigación previa documentada en PARTE 5.1: GDScript no tiene
## cliente Redis oficial ni estable).
## ════════════════════════════════════════════════════════════════

const REDIS_HOST := "127.0.0.1"
const REDIS_PORT := 6379
# Password leída de variable de entorno REDIS_PASSWORD (seteada en el
# .service de systemd) — NUNCA hardcodear la clave acá en el repo.
var _password: String = ""

var _tcp: StreamPeerTCP = null
var _connected: bool = false
var _reconnect_timer: float = 0.0
const RECONNECT_INTERVAL_SEC: float = 3.0

func _ready() -> void:
	if not NetworkManager.is_server:
		# Este autoload solo tiene sentido en procesos servidor. En el
		# cliente Godot (jugador) no hace nada — no se conecta a nada.
		set_process(false)
		return
	_password = OS.get_environment("REDIS_PASSWORD")
	_connect_redis()

func _process(delta: float) -> void:
	if not NetworkManager.is_server:
		return
	if not _connected:
		_reconnect_timer += delta
		if _reconnect_timer >= RECONNECT_INTERVAL_SEC:
			_reconnect_timer = 0.0
			_connect_redis()
		return
	if _tcp:
		_tcp.poll()
		if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_connected = false
			push_warning("[RedisClient] Conexión perdida, reintentando...")

func _connect_redis() -> void:
	_tcp = StreamPeerTCP.new()
	var err := _tcp.connect_to_host(REDIS_HOST, REDIS_PORT)
	if err != OK:
		push_warning("[RedisClient] No se pudo iniciar conexión a Redis: %s" % err)
		_connected = false
		return
	# Esperar a que el handshake TCP termine (normalmente instantáneo
	# en localhost, pero hay que darle al menos un poll).
	var attempts := 0
	while _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTING and attempts < 50:
		_tcp.poll()
		OS.delay_msec(10)
		attempts += 1
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		push_warning("[RedisClient] Falló conexión a Redis local (127.0.0.1:6379)")
		_connected = false
		return
	_connected = true
	print("[RedisClient] Conectado a Redis local")
	if not _password.is_empty():
		var auth_ok: bool = _send_command(["AUTH", _password]) != null
		if not auth_ok:
			push_error("[RedisClient] AUTH falló — revisar REDIS_PASSWORD")
			_connected = false

## Guarda un valor con expiración en segundos (equivalente a SETEX).
## Devuelve true si OK.
func setex(key: String, ttl_seconds: int, value: String) -> bool:
	if not _connected:
		return false
	var reply = _send_command(["SETEX", key, str(ttl_seconds), value])
	return reply == "OK"

## Devuelve el valor guardado, o "" si no existe / hay error.
func get_value(key: String) -> String:
	if not _connected:
		return ""
	var reply = _send_command(["GET", key])
	if reply == null:
		return ""
	return str(reply)

func delete(key: String) -> void:
	if not _connected:
		return
	_send_command(["DEL", key])

## ────────────────────────────────────────────────────────────────
## Protocolo RESP mínimo. Arma un comando en formato RESP Array of
## Bulk Strings y parsea SOLO los tipos de respuesta que necesitamos:
## Simple String (+), Bulk String ($), Error (-), Integer (:), Nil.
## ────────────────────────────────────────────────────────────────
func _send_command(parts: Array) -> Variant:
	if not _tcp or _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_connected = false
		return null

	var cmd := "*%d\r\n" % parts.size()
	for p in parts:
		var s := str(p)
		cmd += "$%d\r\n%s\r\n" % [s.to_utf8_buffer().size(), s]

	var write_err := _tcp.put_data(cmd.to_utf8_buffer())
	if write_err != OK:
		push_warning("[RedisClient] Error escribiendo comando: %s" % write_err)
		_connected = false
		return null

	return _read_reply()

func _read_reply() -> Variant:
	var line := _read_line()
	if line.is_empty():
		return null
	var prefix := line[0]
	var rest := line.substr(1)

	match prefix:
		"+":  # Simple string
			return rest
		"-":  # Error
			push_warning("[RedisClient] Redis error: %s" % rest)
			return null
		":":  # Integer
			return rest.to_int()
		"$":  # Bulk string
			var len_ := rest.to_int()
			if len_ == -1:
				return null  # nil
			var data := _read_exact(len_)
			_read_line()  # descartar el \r\n final
			return data
		"*":  # Array — no lo necesitamos parseado a fondo para
			  # SETEX/GET/DEL, pero lo consumimos para no dejar el
			  # buffer desalineado si alguna vez llega uno.
			var count := rest.to_int()
			var arr := []
			for i in range(max(count, 0)):
				arr.append(_read_reply())
			return arr
		_:
			push_warning("[RedisClient] Prefijo RESP desconocido: %s" % prefix)
			return null

func _read_line() -> String:
	var out := PackedByteArray()
	var attempts := 0
	while attempts < 2000:
		_tcp.poll()
		var avail := _tcp.get_available_bytes()
		if avail > 0:
			var b: PackedByteArray = _tcp.get_data(1)[1]
			if b.size() == 0:
				attempts += 1
				continue
			if b[0] == 10:  # \n — fin de línea, out ya tiene el \r si vino
				if out.size() > 0 and out[out.size() - 1] == 13:
					out = out.slice(0, out.size() - 1)
				return out.get_string_from_utf8()
			out.append(b[0])
		else:
			OS.delay_msec(1)
			attempts += 1
	push_warning("[RedisClient] Timeout leyendo línea de Redis")
	_connected = false
	return ""

func _read_exact(n: int) -> String:
	var out := PackedByteArray()
	var attempts := 0
	while out.size() < n and attempts < 2000:
		_tcp.poll()
		var avail := _tcp.get_available_bytes()
		if avail > 0:
			var chunk: PackedByteArray = _tcp.get_data(min(avail, n - out.size()))[1]
			out.append_array(chunk)
		else:
			OS.delay_msec(1)
			attempts += 1
	return out.get_string_from_utf8()
