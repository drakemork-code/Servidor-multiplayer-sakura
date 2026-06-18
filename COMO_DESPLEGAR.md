# Cómo desplegar el servidor de multiplayer en Railway

Esta carpeta (`servidor-multiplayer/`) contiene TODO lo necesario para
que Railway construya y corra el servidor de Sakura Chronicles
directamente desde tu código fuente de Godot, sin que tú tengas que
exportar ningún binario desde una PC. Railway descarga el motor de
Godot dentro de su propio proceso de build (lo dice el `Dockerfile`),
así que tu única tarea es subir esta carpeta a GitHub.

## Qué hay aquí

- `Dockerfile`: instrucciones para que Railway construya la imagen.
  Descarga Godot 4.6.3 headless y corre tu proyecto con `--server`.
- `sakura_new/`: tu proyecto de Godot completo, con los 3 archivos
  ya corregidos (`network_manager.gd`, `server_main.gd`, `main_menu.gd`)
  para usar WebSocket en vez de ENet.
- `railway.json`: le dice a Railway "usa el Dockerfile", para que no
  intente adivinar cómo correr este proyecto.
- `.dockerignore`: evita copiar archivos innecesarios a la imagen.

## Paso 1 — Subir esta carpeta a tu repo de GitHub

Tienes dos formas, elige la que te sea más fácil desde la tablet:

**Opción simple (recomendada): nuevo repo separado**
1. Crea un repo nuevo en GitHub, por ejemplo `sakura-mp-server`.
2. Sube el contenido de esta carpeta (`Dockerfile`, `railway.json`,
   `.dockerignore`, `sakura_new/`) a la raíz de ese repo nuevo.
   Puedes hacerlo desde la app de GitHub o subiendo el ZIP por la
   web de GitHub ("Add file" → "Upload files", arrastra todo).

**Opción alternativa: mismo repo del backend, en una subcarpeta**
1. En tu repo actual (el del backend de auth), crea una carpeta
   nueva, ej. `servidor-multiplayer/`.
2. Sube ahí el `Dockerfile`, `railway.json`, `.dockerignore` y la
   carpeta `sakura_new/`.
3. Cuando configures el servicio en Railway (paso 2), tendrás que
   indicarle el "Root Directory" = `servidor-multiplayer` para que
   sepa dónde está el Dockerfile.

## Paso 2 — Crear el servicio nuevo en Railway

1. Entra a tu proyecto de Railway (el mismo donde ya está el backend).
2. Click "+ New" → "GitHub Repo".
3. Selecciona el repo que subiste en el Paso 1 (sea el nuevo o el
   mismo del backend).
4. Si usaste la opción "mismo repo": en Settings del nuevo servicio,
   busca "Root Directory" y ponle `servidor-multiplayer`.
5. Railway va a detectar el `Dockerfile` automáticamente y empezar
   a construir la imagen. Esto puede tardar varios minutos la primera
   vez porque descarga Godot (~70MB) dentro del build.
6. Ve a la pestaña "Deployments" de ese servicio para ver el progreso
   y los logs en vivo.

## Paso 3 — Activar el dominio público

1. En el servicio nuevo, ve a "Settings" → "Networking".
2. Click "Generate Domain". Railway te va a dar algo como
   `sakura-mp-server-production.up.railway.app`.
3. Copia ese dominio — lo necesitas para el paso 4.

(Opcional: si prefieres usar tu dominio propio, en la misma sección
puedes agregar un Custom Domain apuntando a `sakurachronicles.net`
o un subdominio como `play.sakurachronicles.net`, siguiendo las
instrucciones que Railway te muestra ahí mismo con el CNAME a crear.)

## Paso 4 — Conectar el cliente a ese dominio

En `scripts/main_menu.gd` (dentro de tu proyecto de Godot real, el
que usas en la tablet para seguir desarrollando) busca estas líneas:

```gdscript
const MP_HOST : String = "sakurachronicles.up.railway.app"
const MP_PORT : int    = 443
```

Cambia `MP_HOST` por el dominio que copiaste en el Paso 3. `MP_PORT`
se queda en 443 porque Railway siempre expone HTTPS/WSS por ese
puerto hacia afuera, sin importar qué puerto interno use tu servicio.

## Paso 5 — Re-exportar el APK y probar

1. Exporta el APK normal desde Godot en tu tablet, como siempre.
2. Instálalo en dos dispositivos (o tablet + emulador).
3. Inicia sesión con dos cuentas distintas, entra al mundo desde la
   misma zona con ambas.
4. Deberías ver al otro jugador moverse en tiempo real.

## Verificar que el servidor está corriendo bien

En los logs del servicio en Railway (pestaña "Deployments" → click
en el deploy activo → "View Logs") deberías ver algo como:

```
===========================================
  Sakura Chronicles — Servidor WebSocket v22.3
  Puerto: 7350  |  Max jugadores: 100
  ...
===========================================
[NetworkManager] Servidor WebSocket v22.3 en puerto 7350
```

Si en cambio ves un error de Godot tratando de reimportar assets y
tardando mucho, es normal en el primer arranque — espera unos minutos.
Si el contenedor se reinicia en bucle, revisa el log completo y
compártemelo para diagnosticar.

## Nota sobre costos

Railway cobra por uso de cómputo (CPU/RAM) del servicio mientras esté
corriendo, no por tener el dominio. Un servidor headless de un juego
2D con pocos jugadores simultáneos consume muy poco, pero si nunca
lo usas igual va a estar facturando mientras esté "running". Si
quieres, puedes pausar el servicio en Railway cuando no estés
probando con otro jugador, para no gastar de más mientras desarrollas.
