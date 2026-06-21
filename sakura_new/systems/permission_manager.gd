# ==============================================================
# Sakura Chronicles
# Copyright (c) 2024 Drake Andonov & Ruth Gonzaga Quimi
# Todos los derechos reservados. All rights reserved.
# Prohibida la copia, distribucion o modificacion no autorizada.
# Unauthorized copying, distribution or modification is prohibited.
# ==============================================================

extends Node

# ============================================================
# PERMISSION MANAGER — Autoload global
# Solicita permisos de Android/iOS al iniciar la app.
# Solo activo en mobile — en PC/editor no hace nada.
#
# Permisos solicitados:
#   - POST_NOTIFICATIONS      (notificaciones push)
#   - VIBRATE                 (vibración en eventos)
#   - INTERNET                (futuro multijugador)
#   - ACCESS_NETWORK_STATE    (detectar conexión)
#   - RECEIVE_BOOT_COMPLETED  (notificaciones tras reinicio)
#   - READ_EXTERNAL_STORAGE   (saves en versiones antiguas Android)
#   - WRITE_EXTERNAL_STORAGE  (saves en versiones antiguas Android)
# ============================================================

signal all_permissions_done()
signal permission_result(permission: String, granted: bool)

# Permisos a solicitar en orden
const REQUIRED_PERMISSIONS: Array = [
	"android.permission.POST_NOTIFICATIONS",
	"android.permission.VIBRATE",
	"android.permission.INTERNET",
	"android.permission.ACCESS_NETWORK_STATE",
	"android.permission.RECEIVE_BOOT_COMPLETED",
]

# Permisos de almacenamiento — solo necesarios en Android < 10 (API 29)
# En Android 10+ el juego usa internal storage (user://) sin permiso
const STORAGE_PERMISSIONS: Array = [
	"android.permission.READ_EXTERNAL_STORAGE",
	"android.permission.WRITE_EXTERNAL_STORAGE",
]

var _permissions_checked: bool = false
var _pending_permissions: Array = []
var _granted: Dictionary = {}   # permission -> bool

func _ready() -> void:
	if not _is_mobile():
		print("[PermissionManager] No es mobile — omitiendo solicitud de permisos")
		all_permissions_done.emit()
		return
	# Esperar un frame para que la escena principal esté lista
	call_deferred("_request_all_permissions")

func _is_mobile() -> bool:
	return OS.get_name() in ["Android", "iOS"]

# ──────────────────────────────────────────────
# SOLICITUD DE PERMISOS
# ──────────────────────────────────────────────
func _request_all_permissions() -> void:
	if _permissions_checked:
		return
	_permissions_checked = true

	print("[PermissionManager] Iniciando solicitud de permisos...")

	var to_request: Array = []

	# Permisos principales
	for perm in REQUIRED_PERMISSIONS:
		if not _has_permission(perm):
			to_request.append(perm)
		else:
			_granted[perm] = true
			print("[PermissionManager] Ya concedido: ", perm)

	# Almacenamiento solo en Android < 10
	if OS.get_name() == "Android":
		var sdk_version: int = _get_android_sdk_version()
		print("[PermissionManager] Android SDK: ", sdk_version)
		if sdk_version < 29:  # Android < 10
			for perm in STORAGE_PERMISSIONS:
				if not _has_permission(perm):
					to_request.append(perm)
				else:
					_granted[perm] = true

	if to_request.is_empty():
		print("[PermissionManager] Todos los permisos ya concedidos")
		all_permissions_done.emit()
		return

	_pending_permissions = to_request.duplicate()
	print("[PermissionManager] Solicitando: ", to_request)

	# En Godot 4 se solicitan todos a la vez
	OS.request_permissions()

	# Dar 500ms y verificar de nuevo (Godot 4 Android manejo nativo)
	await get_tree().create_timer(0.5).timeout
	_verify_permissions()

func _verify_permissions() -> void:
	var all_ok: bool = true
	for perm in _pending_permissions:
		var granted: bool = _has_permission(perm)
		_granted[perm] = granted
		permission_result.emit(perm, granted)
		if not granted:
			# VIBRATE e INTERNET son automáticos en Android — no requieren diálogo
			var auto_granted: Array = [
				"android.permission.VIBRATE",
				"android.permission.INTERNET",
				"android.permission.ACCESS_NETWORK_STATE",
				"android.permission.RECEIVE_BOOT_COMPLETED",
			]
			if perm not in auto_granted:
				all_ok = false
				push_warning("[PermissionManager] Permiso no concedido: " + perm)
			else:
				_granted[perm] = true  # estos son automáticos
		else:
			print("[PermissionManager] ✅ Concedido: ", perm)

	print("[PermissionManager] Verificación completa. Todos OK: ", all_ok)
	all_permissions_done.emit()

func _has_permission(permission: String) -> bool:
	if not _is_mobile():
		return true
	# OS.check_permission() removed in Godot 4 — use get_granted_permissions()
	if OS.has_feature("Android"):
		var granted: PackedStringArray = OS.get_granted_permissions()
		return granted.has(permission)
	return false

func _get_android_sdk_version() -> int:
	# Godot 4 no expone directamente el SDK version
	# Usamos un feature tag como aproximación
	if OS.has_feature("Android"):
		# En Android 10+ (API 29+) no necesitamos permisos de storage
		# Godot 4.x target SDK 33+ por defecto, así que asumimos moderno
		return 33
	return 0

# ──────────────────────────────────────────────
# API PÚBLICA
# ──────────────────────────────────────────────
func is_granted(permission: String) -> bool:
	if not _is_mobile():
		return true
	return _granted.get(permission, false) or _has_permission(permission)

func has_notifications() -> bool:
	return is_granted("android.permission.POST_NOTIFICATIONS")

func has_vibration() -> bool:
	return is_granted("android.permission.VIBRATE")

func has_internet() -> bool:
	return is_granted("android.permission.INTERNET")

# Vibrar si se tiene el permiso
func vibrate(ms: int = 50) -> void:
	if not _is_mobile():
		return
	if has_vibration():
		Input.vibrate_handheld(ms)

# Vibración de eventos de juego
func vibrate_hit()   -> void: vibrate(30)   # golpe recibido
func vibrate_death() -> void: vibrate(200)  # muerte
func vibrate_loot()  -> void: vibrate(15)   # item recogido
func vibrate_level() -> void: vibrate(100)  # subida de nivel
