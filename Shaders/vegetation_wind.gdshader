shader_type canvas_item;

// Continuous per-instance plant motion. The breeze moves through the cave in
// one direction, while every plant keeps a distinct idle phase and strength.
uniform float wind_phase = 0.0;
uniform float wind_world_x = 0.0;
uniform float sway_pixels : hint_range(0.0, 80.0) = 4.0;
uniform float press_pixels : hint_range(0.0, 120.0) = 10.0;
uniform float root_uv_y : hint_range(0.0, 1.0) = 0.98;
uniform float root_at_bottom : hint_range(0.0, 1.0) = 1.0;
uniform float interaction_strength : hint_range(0.0, 1.0) = 0.0;
uniform float interaction_direction : hint_range(-1.0, 1.0) = 1.0;
uniform float tint_variation : hint_range(-0.08, 0.08) = 0.0;

float root_to_tip(float y) {
	float from_bottom = clamp((root_uv_y - y) / max(root_uv_y, 0.001), 0.0, 1.0);
	float from_top = clamp((y - root_uv_y) / max(1.0 - root_uv_y, 0.001), 0.0, 1.0);
	return mix(from_top, from_bottom, root_at_bottom);
}

void fragment() {
	float height = root_to_tip(UV.y);
	float bend = pow(smoothstep(0.025, 0.94, height), 1.34);
	float idle = sin(TIME * 0.54 + wind_phase) * 0.62;
	idle += sin(TIME * 0.22 + wind_phase * 2.17) * 0.23;
	// A soft gust travels across adjacent plants; the small per-plant phase
	// variation stops a whole row from ever moving in exact synchrony.
	float travelling_phase = TIME * 0.78 - wind_world_x * 0.019 + wind_phase * 0.10;
	float gust = smoothstep(0.64, 0.96, sin(travelling_phase));
	float leaf_detail = sin(TIME * 1.18 + wind_phase * 1.73 + height * 4.4) * 0.10;
	float wind_displacement = (idle + leaf_detail + gust * 1.28) * sway_pixels * bend;
	float pressed = interaction_direction * interaction_strength * press_pixels * pow(bend, 0.72);
	float pressed_down = interaction_strength * press_pixels * 0.18 * pow(bend, 1.8);
	vec2 sample_uv = UV;
	sample_uv.x -= (wind_displacement + pressed) * TEXTURE_PIXEL_SIZE.x;
	sample_uv.y += pressed_down * TEXTURE_PIXEL_SIZE.y;
	vec4 colour = texture(TEXTURE, sample_uv);
	float living_tint = 1.0 + tint_variation + gust * 0.012;
	colour.rgb *= vec3(living_tint * 0.985, living_tint * 1.012, living_tint * 0.978);
	COLOR = colour;
}
