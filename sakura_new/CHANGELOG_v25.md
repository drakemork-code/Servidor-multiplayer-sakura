# Sakura Chronicles — Changelog v2.5

## v2.5 — Reorganización del menú principal (compatible Godot 4.6.3 Android)

### Problema resuelto
GDScript no soporta mixins ni herencia horizontal entre scripts.
La versión v2.5 mantiene **un único archivo** `scripts/main_menu.gd`
pero organizado con un índice de secciones para facilitar la navegación.

### Cómo navegar el código (Ctrl+F en el editor)
Busca estas etiquetas para ir directamente a cada sección:

| Etiqueta       | Contenido                              |
|----------------|----------------------------------------|
| `[COLORES]`    | Paleta de colores WoW                  |
| `[CONSTANTES]` | Constantes del juego                   |
| `[RAZAS]`      | Datos de razas y apariencia            |
| `[VARIABLES]`  | Variables de estado                    |
| `[READY]`      | _ready() y _process()                  |
| `[TOS]`        | Términos y condiciones                 |
| `[TEMA]`       | Tema global y estilos visuales         |
| `[FONDO]`      | Fondo épico WoW                        |
| `[PARTICULAS]` | Partículas mágicas                     |
| `[SAKURA]`     | Pétalos de sakura                      |
| `[TITULO]`     | Título animado                         |
| `[LOGIN]`      | Pantalla de login                      |
| `[REGISTRO]`   | Pantalla de registro                   |
| `[VERIFICAR]`  | Verificación de email                  |
| `[AUTH]`       | Lógica de autenticación                |
| `[SERVIDOR]`   | Guardar/cargar en servidor             |
| `[SELECT]`     | Pantalla de selección de personaje     |
| `[CREAR]`      | Creación de personaje                  |
| `[NAVEGAR]`    | Navegación entre pantallas             |
| `[ACCIONES]`   | Callbacks y acciones de botones        |
| `[CUENTAS]`    | Gestión de cuentas locales             |

### Sin cambios de funcionalidad
Toda la lógica es idéntica a v2.4. Solo se agregó el índice y los
marcadores de sección para facilitar la corrección de bugs.
