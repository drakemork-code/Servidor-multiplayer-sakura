shader_type canvas_item;

// ── Dissolve al morir ─────────────────────────────────────────────────────
// dissolve_amount: 0.0 (sprite intacto) → 1.0 (completamente disuelto)

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4  edge_color : source_color = vec4(1.0, 0.4, 0.05, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

float noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i),              hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// No early returns — usar if/else chain (requerido por Godot 4 canvas_item)
	if (tex.a < 0.01 || dissolve_amount <= 0.0) {
		COLOR = tex;
	} else {
		float n = noise(UV * 8.0);

		if (n < dissolve_amount) {
			// Píxel disuelto
			COLOR = vec4(0.0);
		} else if (n < dissolve_amount + 0.08) {
			// Borde con tinte naranja
			float edge = 1.0 - (n - dissolve_amount) / 0.08;
			COLOR = vec4(mix(tex.rgb, edge_color.rgb, edge), tex.a);
		} else {
			COLOR = tex;
		}
	}
}
