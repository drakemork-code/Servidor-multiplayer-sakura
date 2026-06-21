shader_type canvas_item;

// ── Outline dinámico ──────────────────────────────────────────────────────
// Dibuja un borde de 1px alrededor del sprite detectando píxeles
// transparentes adyacentes. Activar con outline_enabled = true.

uniform bool  outline_enabled              = false;
uniform vec4  outline_color : source_color = vec4(1.0, 0.15, 0.15, 1.0);
uniform float outline_width : hint_range(0.5, 3.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// No early returns — if/else chain requerido en canvas_item Godot 4
	if (!outline_enabled) {
		COLOR = tex;
	} else if (tex.a > 0.5) {
		// Píxel opaco — dibujarlo normal
		COLOR = tex;
	} else {
		// Transparente — comprobar si algún vecino es opaco
		vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
		float n = texture(TEXTURE, UV + vec2(0.0,   px.y)).a
		        + texture(TEXTURE, UV + vec2(0.0,  -px.y)).a
		        + texture(TEXTURE, UV + vec2( px.x,  0.0)).a
		        + texture(TEXTURE, UV + vec2(-px.x,  0.0)).a;
		if (n > 0.5) {
			COLOR = outline_color;
		} else {
			COLOR = tex;
		}
	}
}
