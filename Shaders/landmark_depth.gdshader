shader_type canvas_item;
render_mode unshaded;

// Alpha-aware, sub-pixel softness for world-space landmarks. It is weaker
// than the mid parallax defocus so the landmark still reads as a place in the
// cave, not a foreground prop.
uniform float softness : hint_range(0.0, 1.0) = 0.24;
uniform float blur_radius : hint_range(0.5, 2.0) = 0.85;
uniform float opacity : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec4 centre = texture(TEXTURE, UV);
	vec2 offset = TEXTURE_PIXEL_SIZE * blur_radius;
	vec4 left = texture(TEXTURE, UV - vec2(offset.x, 0.0));
	vec4 right = texture(TEXTURE, UV + vec2(offset.x, 0.0));
	vec4 up = texture(TEXTURE, UV - vec2(0.0, offset.y));
	vec4 down = texture(TEXTURE, UV + vec2(0.0, offset.y));
	float alpha = centre.a * 0.56 + (left.a + right.a + up.a + down.a) * 0.11;
	vec3 rgb = centre.rgb * centre.a * 0.56;
	rgb += (left.rgb * left.a + right.rgb * right.a + up.rgb * up.a + down.rgb * down.a) * 0.11;
	rgb /= max(alpha, 0.0001);
	vec4 blurred = vec4(rgb, alpha);
	vec4 colour = mix(centre, blurred, softness);
	colour.a *= opacity;
	COLOR = colour;
}
