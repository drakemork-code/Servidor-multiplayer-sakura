# ==============================================================
# Sakura Chronicles — Servidor de Multiplayer (Dockerfile)
# ==============================================================
# Este Dockerfile descarga el motor de Godot 4.6.3 (versión Linux,
# que incluye soporte headless) y corre el proyecto directamente
# desde el código fuente con la bandera --server.
#
# No requiere exportar ningún binario desde un PC: Railway construye
# esta imagen automáticamente al detectar este Dockerfile en el repo,
# y el motor de Godot que se descarga aquí es el que hace el trabajo.
# ==============================================================

FROM ubuntu:22.04

# Dependencias que Godot necesita para correr en Linux,
# incluso en modo headless (sin pantalla).
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    libfontconfig1 \
    libxcursor1 \
    libxinerama1 \
    libxrandr2 \
    libxi6 \
    libgl1 \
    libglu1-mesa \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Descargar el motor de Godot 4.6.3 (Linux x86_64)
WORKDIR /opt/godot
RUN wget -q https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip \
    && unzip Godot_v4.6.3-stable_linux.x86_64.zip \
    && mv Godot_v4.6.3-stable_linux.x86_64 godot \
    && chmod +x godot \
    && rm Godot_v4.6.3-stable_linux.x86_64.zip

# Copiar el proyecto del juego (carpeta sakura_new) dentro de la imagen
WORKDIR /app
COPY sakura_new /app/sakura_new

# Railway asigna el puerto público vía la variable de entorno PORT.
# server_main.gd ya está preparado para leerla.
ENV PORT=7350

# Arrancar el proyecto en modo headless + flag --server.
# El "--" separa los argumentos de Godot de los argumentos del propio juego;
# server_main.gd revisa OS.get_cmdline_user_args() para encontrar "--server".
CMD ["/opt/godot/godot", "--headless", "--path", "/app/sakura_new", "--", "--server"]
