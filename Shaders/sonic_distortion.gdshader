shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float effect_time = 0.0;
uniform float strength : hint_range(0.0, 1.5) = 1.0;
uniform float distortion_pixels : hint_range(0.0, 16.0) = 5.0;
uniform float frequency : hint_range(1.0, 100.0) = 42.0;

uniform vec2 travel_direction = vec2(1.0, 0.0);

uniform vec4 sonic_tint : source_color = vec4(
	0.72,
	0.92,
	1.0,
	1.0
);


void fragment() {
	vec2 p = UV * 2.0 - 1.0;

	// Längliches Verzerrungsfeld.
	vec2 shaped_p = p;
	shaped_p.x *= 0.78;
	shaped_p.y *= 1.12;

	float radius = length(shaped_p);

	// Weiche Außenkante.
	float outer_mask = 1.0 - smoothstep(
		0.46,
		0.98,
		radius
	);

	// Zentrum etwas freihalten.
	float center_fade = smoothstep(
		0.03,
		0.18,
		radius
	);

	float mask = outer_mask * center_fade;

	// Sehr schnelle laufende Schallwelle.
	float carrier = sin(
		shaped_p.x * frequency
		- effect_time * 56.0
		+ sin(
			shaped_p.y * 19.0
			+ effect_time * 17.0
		) * 1.6
	);

	// Kreisförmige Druckwellen.
	float radial_wave = sin(
		radius * 54.0
		- effect_time * 39.0
	);

	// Noch feinere Hochfrequenz.
	float micro_wave = sin(
		shaped_p.x * 81.0
		+ shaped_p.y * 31.0
		- effect_time * 83.0
	);

	float wave = (
		carrier * 0.52
		+ radial_wave * 0.32
		+ micro_wave * 0.16
	);

	vec2 dir = travel_direction;

	if (length(dir) < 0.001) {
		dir = vec2(1.0, 0.0);
	}

	dir = normalize(dir);

	vec2 side = vec2(
		-dir.y,
		dir.x
	);

	// Lokale Koordinaten auf Screen-Richtung übertragen.
	vec2 screen_radial = (
		dir * shaped_p.x
		+ side * shaped_p.y
	);

	screen_radial = normalize(
		screen_radial + vec2(0.0001)
	);

	// Schall verzerrt besonders quer zur Flugrichtung.
	vec2 displacement_direction = (
		side * carrier * 0.72
		+ screen_radial * radial_wave * 0.28
	);

	float displacement_strength = (
		distortion_pixels
		* strength
		* mask
		* (
			0.38
			+ abs(wave) * 0.62
		)
	);

	vec2 screen_offset = (
		displacement_direction
		* SCREEN_PIXEL_SIZE
		* displacement_strength
	);

	// Sehr dezente chromatische Aufspaltung.
	vec2 chroma_offset = screen_offset * 0.18;

	float red = texture(
		screen_texture,
		SCREEN_UV + screen_offset + chroma_offset
	).r;

	float green = texture(
		screen_texture,
		SCREEN_UV + screen_offset
	).g;

	float blue = texture(
		screen_texture,
		SCREEN_UV + screen_offset - chroma_offset
	).b;

	vec3 refracted = vec3(
		red,
		green,
		blue
	);

	// Sichtbare dünne Druckbänder.
	float pressure_band = 1.0 - smoothstep(
		0.08,
		0.32,
		abs(
			sin(
				radius * 38.0
				- effect_time * 31.0
			)
		)
	);

	pressure_band *= mask * strength;

	vec3 final_color = refracted;

	final_color += (
		sonic_tint.rgb
		* pressure_band
		* 0.055
	);

	// Hochfrequentes Schimmern.
	float shimmer = pow(
		abs(carrier),
		7.0
	);

	final_color += (
		sonic_tint.rgb
		* shimmer
		* mask
		* strength
		* 0.035
	);

	float alpha = (
		mask
		* strength
		* (
			0.34
			+ pressure_band * 0.16
		)
	);

	COLOR = vec4(
		final_color,
		clamp(alpha, 0.0, 0.72)
	);
}