# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# VERSION GATE — Autoload global (servidor de combate)
#
# Consulta periódicamente al servidor de autenticación (Railway 2)
# cuál es la MIN_CLIENT_VERSION vigente, y expone esa info para
# que NetworkManager pueda rechazar a clientes desactualizados
# en el momento del registro (_register_on_server).
#
# IMPORTANTE: esto es una segunda capa de defensa. La primera y
# obligatoria es el auth server (login), que ya bloquea el acceso
# antes de siquiera llegar aquí. Este chequeo evita que un cliente
# modificado se salte el auth server y se conecte directo al
# WebSocket del servidor de mundo/combate.
# ============================================================

signal config_updated()

const AUTH_BACKEND      : String = "https://sakurachronicles.up.railway.app"
const REFRESH_INTERVAL  : float  = 60.0   # segundos entre refrescos de la config
const REQUEST_TIMEOUT   : float  = 8.0

var minimum_version : String = "0.0.0"  # fail-open hasta la primera respuesta válida
var maintenance      : bool   = false
var maintenance_msg  : String = ""
var _loaded_once     : bool   = false
var _refresh_timer   : float  = 0.0
var _http            : HTTPRequest = null

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_version_response)
	_refresh()

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		_refresh()

func _refresh() -> void:
	if not is_instance_valid(_http):
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return  # ya hay una consulta en curso
	var err := _http.request(
		AUTH_BACKEND + "/version-check",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify({"client_version": "server"})
	)
	if err != OK:
		push_warning("[VersionGate] No se pudo consultar /version-check: %d" % err)

func _on_version_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		# Si falla, mantenemos la última config válida conocida (o el
		# fail-open inicial si todavía no cargó nunca ninguna).
		push_warning("[VersionGate] version-check falló (result=%d code=%d), manteniendo config anterior" % [result, code])
		return
	var json : Variant = JSON.parse_string(body.get_string_from_utf8())
	if not json is Dictionary or not json.get("ok", false):
		return
	minimum_version = String(json.get("minimum_version", minimum_version))
	maintenance      = bool(json.get("maintenance", false))
	maintenance_msg  = String(json.get("maintenance_message", ""))
	_loaded_once = true
	config_updated.emit()
	print("[VersionGate] Config actualizada — minimum_version=%s maintenance=%s" % [minimum_version, maintenance])

# Compara versiones semver-like "1.2.10" > "1.2.9" (numérico por segmento).
static func compare_versions(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	var len_ := max(pa.size(), pb.size())
	for i in len_:
		var da := int(pa[i]) if i < pa.size() else 0
		var db := int(pb[i]) if i < pb.size() else 0
		if da != db:
			return 1 if da > db else -1
	return 0

# True si el cliente con esa versión debe ser rechazado.
# Mientras no se haya cargado ninguna config todavía (arranque en frío,
# auth server caído en el primer intento), se falla ABIERTO para no
# tumbar el servidor entero por un problema transitorio de red —
# el auth server sigue siendo el gate principal en el login.
func is_client_blocked(client_version: String) -> bool:
	if not _loaded_once:
		return false
	if maintenance:
		return true
	return compare_versions(client_version, minimum_version) < 0
