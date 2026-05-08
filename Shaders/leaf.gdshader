shader_type canvas_item;

uniform float wave_speed : hint_range(0.5, 5.0) = 2.0;
uniform float wave_amplitude : hint_range(0.0, 10.0) = 4.0;
uniform float flutter_speed : hint_range(0.0, 10.0) = 3.0;
uniform float flutter_strength : hint_range(0.0, 1.0) = 0.3;
uniform float light_flicker_speed : hint_range(0.0, 10.0) = 1.2;
uniform float light_flicker_intensity : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	// Zeit für animierte Bewegung
	float t = TIME;

	// Kleine Wellenbewegung über X-Achse (biegt das Blatt)
	float wave = sin(UV.y * 10.0 + t * wave_speed) * wave_amplitude;
	vec2 flutter_uv = UV + vec2(wave * 0.002, 0.0);

	// Flattern (leichtes Zittern / Schwingen)
	float flutter = sin(t * flutter_speed + UV.x * 15.0) * flutter_strength;

	// Farbe und Textur abrufen
	vec4 tex_color = texture(TEXTURE, flutter_uv + vec2(0.0, flutter * 0.01));

	// Leichtes Flimmern, simuliert wechselndes Licht
	float flicker = sin(t * light_flicker_speed + UV.x * 6.0 + UV.y * 3.0) * light_flicker_intensity;
	tex_color.rgb += flicker;

	COLOR = tex_color;
}