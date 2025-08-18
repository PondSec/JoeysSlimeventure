shader_type canvas_item;
uniform float progress : hint_range(0, 1) = 0.0; // Wird von Animation gesteuert
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    vec2 uv = UV;
    float distance = length(uv - vec2(0.5, 0.5));
    if (distance > progress * 0.7) {
        COLOR = fade_color;
    } else {
        COLOR = texture(TEXTURE, uv);
    }
}