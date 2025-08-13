shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture;

// Bloom Einstellungen
uniform float threshold : hint_range(0.0, 1.0) = 0.4;  // Niedriger = mehr Partikel bekommen Bloom
uniform float bloom_strength : hint_range(0.0, 5.0) = 1.5;  // Stärkerer Effekt
uniform float blur_amount : hint_range(0.0, 20.0) = 8.0;  // Mehr Unschärfe für weicheren Kran
uniform int blur_samples : hint_range(1, 10) = 5;  // Mehr Samples für bessere Qualität

void fragment() {
    vec2 uv = UV;
    vec4 col = texture(screen_tex, uv);
    
    // Bloom-Effekt
    float brightness = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    vec4 bloom = vec4(0.0);
    
    if (brightness > threshold) {
        float sample_count = 0.0;
        
        // Größere Blur-Matrix für weicheren Effekt
        for (int x = -blur_samples; x <= blur_samples; x++) {
            for (int y = -blur_samples; y <= blur_samples; y++) {
                vec2 offset = vec2(float(x), float(y)) * blur_amount / 1000.0;
                bloom += texture(screen_tex, uv + offset);
                sample_count += 1.0;
            }
        }
        
        bloom /= sample_count;
        col += bloom * bloom_strength * smoothstep(threshold, threshold + 0.2, brightness);
    }
    
    COLOR = col;
}