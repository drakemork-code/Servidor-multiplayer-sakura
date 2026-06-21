# Sakura Chronicles v12 — Multiplayer + Auth Integrado

## Qué se integró

| Archivo | Cambio |
|---|---|
| `project.godot` | Añadidos autoloads `NetworkManager` y `ServerMain` |
| `scripts/main_menu.gd` | Registro con Gmail + código 6 dígitos + 1 cuenta por IP |
| `systems/network_manager.gd` | Nuevo — ENet client/server, sync 20Hz, chat real |
| `systems/chat_manager.gd` | Añadido `send_message()` real + `add_message()` |
| `scripts/player_remote.gd` | Nuevo — visualización de otros jugadores con lerp |
| `scenes/player_remote.tscn` | Nueva — escena del jugador remoto |
| `server_main.gd` | Nuevo — entry point servidor headless |
| `server_backend/` | Backend Node.js para emails Gmail y control de IPs |

---

## Setup en 3 pasos

### Paso 1 — Backend de Auth en Railway

```
1. Crear nuevo proyecto en railway.app
2. "Deploy from GitHub" → subir solo la carpeta server_backend/
   (o crear repo separado con esos archivos)
3. Añadir variables de entorno:
   GMAIL_USER = tucuenta@gmail.com
   GMAIL_PASS = xxxx xxxx xxxx xxxx  ← contraseña de aplicación Gmail (no la normal)
4. Railway te da una URL tipo: https://sakura-auth-xxx.railway.app
```

**Obtener contraseña de aplicación Gmail:**
- myaccount.google.com → Seguridad → Verificación en 2 pasos (activar)
- Luego: Seguridad → Contraseñas de aplicación → Generar

### Paso 2 — Actualizar URL en el juego

En `scripts/main_menu.gd`, línea con `AUTH_BACKEND`:
```gdscript
const AUTH_BACKEND : String = "https://sakura-auth-xxx.railway.app"  # tu URL real
```

### Paso 3 — Servidor de juego ENet en Railway

```
1. Nuevo proyecto Railway → subir el proyecto Godot completo
2. Usar el Dockerfile incluido (raíz del proyecto)
3. Variables:
   PORT = 7350
   RESTART_WARNING_SEC = 120
4. Railway URL → copiar host
```

Actualizar en `systems/network_manager.gd`:
```gdscript
const DEFAULT_HOST : String = "sakura-game-xxx.railway.app"
```

---

## Flujo de registro de cuenta

```
Usuario ingresa Gmail + contraseña
         ↓
Godot → POST /send-code → Auth Backend
         ↓
Backend verifica:
  • Gmail válido (@gmail.com)
  • Gmail no registrado antes
  • IP no registrada antes
  • Rate limit (1 código/60s)
         ↓
Envía email con código de 6 dígitos (válido 5 min)
         ↓
Usuario escribe el código en el juego
         ↓
Godot → POST /verify-code → Auth Backend
         ↓
Backend verifica código
  ✅ Correcto → registra Gmail + IP, devuelve username
  ❌ Incorrecto → error
         ↓
Godot crea cuenta local (accounts.save) con hash contraseña
```

## Flujo de login (sin red)

El login se hace localmente comparando el hash de contraseña guardado.
No requiere conexión al backend de auth.

---

## Control 1 cuenta por IP

- El backend guarda en `db.json` todas las IPs que ya crearon cuenta
- Al hacer `/send-code`, si la IP ya está registrada → rechaza
- Al hacer `/verify-code`, la IP queda permanentemente registrada
- `db.json` persiste en Railway (no se borra al reiniciar, solo al redesplegar)

**Para Railway con redespliegues frecuentes:** conectar una base de datos Railway Postgres (gratis en plan Hobby) y guardar IPs/gmails ahí en vez de db.json.

---

## Actualizar el juego

```bash
git add .
git commit -m "v13 - nuevo contenido"
git push
# Railway redespliega en ~2 min
# El servidor avisa a jugadores online 30s antes de reiniciar
```

---

## Probar en local sin email

Cuando el backend no tiene GMAIL_USER/GMAIL_PASS configurado,
el endpoint `/send-code` devuelve el código en la respuesta JSON:
```json
{ "ok": true, "code": "483921" }
```
Esto permite probar el flujo completo sin tener emails configurados.
**Quitar el campo `code` de la respuesta en producción si quieres seguridad extra.**
