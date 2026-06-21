shader_type canvas_item;

// ── Agua animada ──────────────────────────────────────────────────────────
// Desplaza las UVs con ondas seno para simular movimiento de agua.
// Asignar a cualquier ColorRect o Sprite2D que represente agua.
// No requiere textura — funciona sobre color sólido.

uniform vec4  water_color_shallow : source_color = vec4(0.28, 0.62, 0.90, 0.92);
uniform vec4  water_color_deep    : source_color = vec4(0.14, 0.38, 0.72, 0.98);
uniform float wave_speed   : hint_range(0.1, 4.0) = 1.2;
uniform float wave_scale   : hint_range(1.0, 20.0) = 6.0;
uniform float wave_height  : hint_range(0.001, 0.05) = 0.018;
// Brillo de espuma en crestas de ola
uniform float foam_strength : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	vec2 uv = UV;

	// Dos capas de onda desplazadas en dirección y fase
	float wave1 = sin(uv.x * wave_scale       + TIME * wave_speed)       * wave_height;
	float wave2 = sin(uv.x * wave_scale * 1.7 + TIME * wave_speed * 0.6) * wave_height * 0.5;
	float wave3 = sin(uv.y * wave_scale * 0.8 + TIME * wave_speed * 0.9) * wave_height * 0.4;

	uv.y += wave1 + wave2;
	uv.x += wave3;

	// Mezclar color superficial y profundo según desplazamiento vertical
	float depth = clamp((uv.y - UV.y + wave_height) / (wave_height * 2.0), 0.0, 1.0);
	vec4 base_color = mix(water_color_shallow, water_color_deep, depth);

	// Espuma en las crestas (valores altos de onda)
	float crest = smoothstep(0.6, 1.0, (wave1 + wave_height) / (wave_height * 2.0));
	base_color.rgb = mix(base_color.rgb, vec3(1.0), crest * foam_strength);

	// Parpadeo de brillo especular simple
	float glint = pow(abs(sin(uv.x * 12.0 + TIME * 2.5)), 18.0) * 0.18;
	base_color.rgb += vec3(glint);

	COLOR = base_color;
}
