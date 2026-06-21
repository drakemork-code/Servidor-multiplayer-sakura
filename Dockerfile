# ==============================================================
#  Sakura Chronicles — Servidor de Multiplayer
# ==============================================================
# Descarga Godot 4.6.3 headless y corre el proyecto con --server.
# El proyecto vive descomprimido en sakura_new/ dentro del repo.
# ==============================================================

FROM ubuntu:22.04

ARG GODOT_VERSION=4.6.3-stable
ENV GODOT_BIN=/opt/godot/godot
ENV PORT=7350

# Dependencias mínimas para correr Godot en modo headless
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget unzip ca-certificates \
        libfontconfig1 libxcursor1 libxinerama1 libxrandr2 libxi6 \
        libgl1 libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Godot Engine (Linux x86_64, headless-capable)
RUN wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
        -O /tmp/godot.zip \
    && unzip -q /tmp/godot.zip -d /opt/godot \
    && mv /opt/godot/Godot_v${GODOT_VERSION}_linux.x86_64 "$GODOT_BIN" \
    && chmod +x "$GODOT_BIN" \
    && rm /tmp/godot.zip

# Proyecto del juego — se copia directo, ya no como zip
WORKDIR /app
COPY sakura_new/ /app/sakura_new/

EXPOSE 7350

# Railway inyecta PORT en runtime; server_main.gd lo lee de ahí.
CMD ["/opt/godot/godot", "--headless", "--path", "/app/sakura_new", "--", "--server"]
