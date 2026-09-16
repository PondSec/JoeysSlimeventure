shader_type canvas_item;
render_mode unshaded;

// The biome art is intentionally rendered on independent canvases.  This
// material only controls a soft world-to-biome crossfade and always preserves
// the source alpha of the two transparent frame assets.
uniform float biome_strength : hint_range(0.0, 1.0) = 0.0;
uniform float edge_feather : hint_range(0.0, 0.45) = 0.14;
// The gameplay CanvasModulate intentionally keeps the cave dark.  These
// authored backdrop layers sit outside gameplay lighting, so compensate that
// global tint here rather than making Joey's lights affect them.
uniform float art_exposure : hint_range(1.0, 8.0) = 1.0;

void fragment() {
	vec4 colour = texture(TEXTURE, UV);
	float soft_strength = biome_strength * biome_strength * (3.0 - 2.0 * biome_strength);
	float left = smoothstep(0.0, edge_feather, UV.x);
	float right = 1.0 - smoothstep(1.0 - edge_feather, 1.0, UV.x);
	float top = smoothstep(0.0, edge_feather, UV.y);
	float bottom = 1.0 - smoothstep(1.0 - edge_feather, 1.0, UV.y);
	colour.rgb *= art_exposure;
	colour.a *= soft_strength * left * right * top * bottom;
	COLOR = colour;
}
