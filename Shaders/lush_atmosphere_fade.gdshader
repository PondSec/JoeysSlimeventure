shader_type canvas_item;

// Local lush regions must dissolve into the ordinary cave rather than ending
// as a visible rectangular backdrop.  The material keeps the centre rich and
// lets every edge breathe back into the normal cave palette.
uniform float horizontal_fade : hint_range(0.04, 0.45) = 0.18;
uniform float vertical_fade : hint_range(0.02, 0.35) = 0.11;

void fragment() {
	vec4 colour = texture(TEXTURE, UV);
	float left = smoothstep(0.0, horizontal_fade, UV.x);
	float right = 1.0 - smoothstep(1.0 - horizontal_fade, 1.0, UV.x);
	float top = smoothstep(0.0, vertical_fade, UV.y);
	float bottom = 1.0 - smoothstep(1.0 - vertical_fade, 1.0, UV.y);
	colour.a *= left * right * top * bottom;
	COLOR = colour;
}
