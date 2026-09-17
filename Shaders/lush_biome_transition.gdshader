shader_type canvas_item;
render_mode unshaded;

// The biome art is intentionally rendered on independent canvases.  This
// material only controls a soft world-to-biome crossfade and always preserves
// the source alpha of the two transparent frame assets.
uniform float biome_strength : hint_range(0.0, 1.0) = 0.0;
uniform float edge_feather : hint_range(0.0, 0.45) = 0.14;
uniform float alpha_gain : hint_range(0.5, 1.5) = 1.0;
// Used only by the mid-depth lush layer. The alpha-aware sampling prevents
// dark rectangular fringes around transparent pixel-art foliage.
uniform float depth_blur : hint_range(0.0, 1.0) = 0.0;
uniform float blur_radius : hint_range(0.5, 2.0) = 1.0;
// The gameplay CanvasModulate intentionally keeps the cave dark.  These
// authored backdrop layers sit outside gameplay lighting, so compensate that
// global tint here rather than making Joey's lights affect them.
uniform float art_exposure : hint_range(1.0, 8.0) = 1.0;

void fragment() {
	vec4 colour = texture(TEXTURE, UV);
	if (depth_blur > 0.0) {
		vec2 offset = TEXTURE_PIXEL_SIZE * blur_radius;
		vec4 left_sample = texture(TEXTURE, UV - vec2(offset.x, 0.0));
		vec4 right_sample = texture(TEXTURE, UV + vec2(offset.x, 0.0));
		vec4 top_sample = texture(TEXTURE, UV - vec2(0.0, offset.y));
		vec4 bottom_sample = texture(TEXTURE, UV + vec2(0.0, offset.y));
		float blurred_alpha = colour.a * 0.40 + (left_sample.a + right_sample.a + top_sample.a + bottom_sample.a) * 0.15;
		vec3 blurred_rgb = colour.rgb * colour.a * 0.40;
		blurred_rgb += (left_sample.rgb * left_sample.a + right_sample.rgb * right_sample.a + top_sample.rgb * top_sample.a + bottom_sample.rgb * bottom_sample.a) * 0.15;
		blurred_rgb /= max(blurred_alpha, 0.0001);
		colour = mix(colour, vec4(blurred_rgb, blurred_alpha), depth_blur);
	}
	float soft_strength = biome_strength * biome_strength * (3.0 - 2.0 * biome_strength);
	float left = smoothstep(0.0, edge_feather, UV.x);
	float right = 1.0 - smoothstep(1.0 - edge_feather, 1.0, UV.x);
	float top = smoothstep(0.0, edge_feather, UV.y);
	float bottom = 1.0 - smoothstep(1.0 - edge_feather, 1.0, UV.y);
	colour.rgb *= art_exposure;
	colour.a = clamp(colour.a * alpha_gain, 0.0, 1.0) * soft_strength * left * right * top * bottom;
	COLOR = colour;
}
