shader_type canvas_item;

// ─── Uniforms ─────────────────────────────────────────────────────────────
uniform vec4 skin_color   : source_color = vec4(0.914, 0.678, 0.490, 1.0);
uniform vec4 hair_color   : source_color = vec4(0.071, 0.071, 0.071, 1.0);
uniform vec4 eye_color    : source_color = vec4(0.15,  0.35,  0.75,  1.0);
uniform vec4 outfit_color : source_color = vec4(0.22,  0.42,  0.88,  1.0);

// ─── Reference centers ────────────────────────────────────────────────────
// Skin reference: #e9ad7d → rgb(233, 173, 125)
const vec3 REF_SKIN   = vec3(0.914, 0.678, 0.490);
// Outfit reference: dark blue used in the sprites ~rgb(56, 72, 166)
const vec3 REF_OUTFIT = vec3(0.22,  0.28,  0.65);

// ─── Helpers ──────────────────────────────────────────────────────────────
vec3 rgb2hsv(vec3 c) {
	float maxc = max(c.r, max(c.g, c.b));
	float minc = min(c.r, min(c.g, c.b));
	float d = maxc - minc;
	float h = 0.0;
	float s = (maxc > 0.001) ? d / maxc : 0.0;
	float v = maxc;
	if (d > 0.001) {
		if (maxc == c.r)      h = mod((c.g - c.b) / d, 6.0) / 6.0;
		else if (maxc == c.g) h = ((c.b - c.r) / d + 2.0) / 6.0;
		else                  h = ((c.r - c.g) / d + 4.0) / 6.0;
	}
	return vec3(h, s, v);
}

vec3 hsv2rgb(vec3 c) {
	float h6 = c.x * 6.0;
	float s  = c.y;
	float v  = c.z;
	int   i  = int(h6);
	float f  = h6 - float(i);
	float p  = v * (1.0 - s);
	float q  = v * (1.0 - s * f);
	float t  = v * (1.0 - s * (1.0 - f));
	if (i == 0) return vec3(v, t, p);
	if (i == 1) return vec3(q, v, p);
	if (i == 2) return vec3(p, v, t);
	if (i == 3) return vec3(p, q, v);
	if (i == 4) return vec3(t, p, v);
	return vec3(v, p, q);
}

// Remap a source pixel to a target color while preserving luminance variation
vec3 remap_color(vec3 src, vec3 ref, vec3 target) {
	float ref_lum = dot(ref,    vec3(0.299, 0.587, 0.114));
	float src_lum = dot(src,    vec3(0.299, 0.587, 0.114));
	float ratio   = src_lum / max(ref_lum, 0.001);
	vec3 target_hsv   = rgb2hsv(target);
	target_hsv.z      = clamp(target_hsv.z * ratio, 0.0, 1.0);
	return hsv2rgb(target_hsv);
}

// ─── Main ─────────────────────────────────────────────────────────────────
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 col = tex.rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 hsv   = rgb2hsv(col);
	float h_deg = hsv.x * 360.0;
	float skin_dist = distance(col, REF_SKIN);

	// Use if/else chain — no early returns (compatible with all Godot 4.x)
	if (tex.a < 0.1) {
		// Transparent — keep as-is
		COLOR = tex;
	} else if (lum < 0.18) {
		// Dark outline — keep as-is
		COLOR = tex;
	} else if (h_deg > 190.0 && h_deg < 280.0 && hsv.y > 0.15 && lum < 0.45) {
		// Outfit (dark blue)
		COLOR = vec4(remap_color(col, REF_OUTFIT, outfit_color.rgb), tex.a);
	} else if (skin_dist < 0.22) {
		// Skin
		COLOR = vec4(remap_color(col, REF_SKIN, skin_color.rgb), tex.a);
	} else if (hsv.y > 0.28 && lum > 0.18) {
		// Hair
		float ref_lum = 0.45;
		float ratio   = lum / ref_lum;
		vec3 hair_hsv = rgb2hsv(hair_color.rgb);
		hair_hsv.z    = clamp(hair_hsv.z * ratio, 0.0, 1.0);
		COLOR = vec4(hsv2rgb(hair_hsv), tex.a);
	} else {
		// Everything else — keep unchanged
		COLOR = tex;
	}
}
