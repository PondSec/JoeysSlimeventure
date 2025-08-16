shader_type canvas_item;

uniform sampler2D screen_texture: hint_screen_texture;
uniform sampler2D noise_texture: filter_nearest, repeat_enable;
uniform vec2 speed = vec2(0.5, 0.2);
uniform float distortion = 0.01;
uniform float wave_strength = 0.1;

void vertex() {
	VERTEX.y += sin(TIME);
}

void fragment() {
	vec2 noise = 2.0 * texture(noise_texture, UV + speed * TIME).rg - vec2(1.0);
	COLOR = texture(TEXTURE, UV + noise * wave_strength);
	COLOR *= texture(screen_texture, SCREEN_UV + noise * distortion);
}
