shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float glow_radius = 4.0;

void fragment() {
    vec2 uv = UV;
    // Abstand zum Zentrum der Textur (0.5,0.5)
    float dist = distance(uv, vec2(0.5));
    // Je näher an der Mitte, desto heller (Glow-Falloff)
    float intensity = smoothstep(glow_radius / 100.0, 0.0, dist);
    COLOR = glow_color * intensity;
}
