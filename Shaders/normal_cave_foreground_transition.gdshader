shader_type canvas_item;

// In the wide lush transition zone, the ordinary cave frame dissolves at the
// exact pace that the lush frame appears. This prevents a doubled, hard edge.
uniform float lush_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 colour = texture(TEXTURE, UV);
	float soft_strength = lush_strength * lush_strength * (3.0 - 2.0 * lush_strength);
	colour.a *= 1.0 - soft_strength;
	COLOR = colour;
}
