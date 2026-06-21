shader_type canvas_item;

// ── Hit Flash ─────────────────────────────────────────────────────────────
// Mezcla el sprite con blanco puro según flash_amount (0.0 = normal, 1.0 = blanco)
// Usar junto a un Tween que baja flash_amount de 1.0 a 0.0 en ~0.12 s
// Compatible con character_swap.gdshader — se puede encadenar como next_pass

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4  flash_color  : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Preservar transparencia — solo flashear píxeles visibles
	if (tex.a < 0.01) {
		COLOR = tex;
	} else {
		COLOR = vec4(mix(tex.rgb, flash_color.rgb, flash_amount), tex.a);
	}
}
