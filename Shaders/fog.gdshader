shader_type canvas_item;

uniform sampler2D noise_tex : source_color;
uniform float speed_x = 0.02;
uniform float speed_y = 0.01;
uniform float fog_strength = 0.4;
uniform vec4 fog_color : source_color = vec4(0.7, 0.8, 1.0, 0.35);
uniform float contrast = 1.5;
uniform float brightness = 0.2;
uniform float scale = 1.0;

void fragment() {
    vec2 uv = UV * scale;

    // Zeitabhängige Verschiebung für Bewegung
    float t = TIME * 0.1;
    vec2 move = vec2(speed_x * t, speed_y * t);

    // Zwei Noise-Ebenen überlagern für mehr Tiefe
    float n1 = texture(noise_tex, uv + move).r;
    float n2 = texture(noise_tex, uv - move * 0.7).r;

    float n = mix(n1, n2, 0.5);

    // Leichte Bewegung durch Sinus (pulsierender Nebel)
    n += sin(TIME * 0.5 + uv.x * 2.0) * 0.05;

    // Nebelkontrast verstärken
    n = pow(n, contrast);
    n = clamp(n + brightness, 0.0, 1.0);

    // Endfarbe mischen
    COLOR = vec4(fog_color.rgb, fog_color.a * n * fog_strength);
}