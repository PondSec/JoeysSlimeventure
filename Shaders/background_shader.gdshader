// background_shader.gdshader
shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.05, 0.11, 0.12, 1.0);
uniform vec4 noise_color : source_color = vec4(0.15, 0.25, 0.28, 1.0);
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float noise_scale : hint_range(0.1, 10.0) = 5.0;
uniform float time_speed : hint_range(0.0, 2.0) = 0.5;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + 
           (c - a) * u.y * (1.0 - u.x) + 
           (d - b) * u.x * u.y;
}

float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(st * frequency);
        st *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

void fragment() {
    vec2 uv = UV * noise_scale;
    uv += TIME * time_speed * 0.1;
    
    // Erzeuge Rauschmuster
    float n = fbm(uv);
    
    // Mische Hintergrundfarbe mit Rauschfarbe
    vec4 color = mix(bg_color, noise_color, n * noise_intensity);
    
    // Leichtes Pulsieren für mehr Lebendigkeit
    float pulse = sin(TIME * 0.5) * 0.02 + 1.0;
    color.rgb *= pulse;
    
    COLOR = color;
}