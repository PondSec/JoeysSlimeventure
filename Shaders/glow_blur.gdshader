shader_type canvas_item;

// Einstellbare Parameter
uniform float blur_strength : hint_range(0, 20) = 5.0;
uniform float glow_intensity : hint_range(0, 2) = 0.8;
uniform vec4 glow_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform int samples : hint_range(4, 32) = 16;
uniform bool high_quality = true;

// Gaußsche Kernel Gewichtung
float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma)) / (sqrt(2.0 * 3.14159265359) * sigma);
}

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);

    // Berechne Blur-Stärke basierend auf Auflösung
    vec2 pixel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
    float sigma = blur_strength * 0.5;
    float total_weight = 0.0;
    vec4 blur_color = vec4(0.0);

    // Anpassbare Sample-Anzahl
    int sample_radius = int(sqrt(float(samples)));

    // Hochqualitativer Gaußscher Blur
    if (high_quality) {
        for (int x = -sample_radius; x <= sample_radius; x++) {
            for (int y = -sample_radius; y <= sample_radius; y++) {
                vec2 offset = vec2(float(x), float(y)) * pixel_size * blur_strength * 0.5;
                float distance = length(offset);
                float weight = gaussian(distance, sigma);

                blur_color += texture(TEXTURE, UV + offset) * weight;
                total_weight += weight;
            }
        }
        blur_color /= total_weight;
    }
    // Schnellerer aber weniger genauer Blur
    else {
        // 2-Pass Blur Approximation (bessere Performance)
        vec4 blur_h = vec4(0.0);
        vec4 blur_v = vec4(0.0);
        float weights = 0.0;

        for (int i = -sample_radius; i <= sample_radius; i++) {
            float weight = gaussian(float(i) / float(sample_radius), sigma);
            blur_h += texture(TEXTURE, UV + vec2(float(i), 0.0) * pixel_size * blur_strength) * weight;
            blur_v += texture(TEXTURE, UV + vec2(0.0, float(i)) * pixel_size * blur_strength) * weight;
            weights += weight;
        }
        blur_color = (blur_h + blur_v) / (weights * 2.0);
    }

    // Bloom/Glow Effekt mit Farbüberblendung
    vec3 glow = blur_color.rgb * glow_color.rgb * glow_color.a * glow_intensity;
    float luminance = dot(blur_color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float glow_mask = smoothstep(0.1, 0.5, luminance);

    // Kombiniere die Effekte
    COLOR.rgb = mix(base_color.rgb, base_color.rgb + glow, glow_mask);
    COLOR.a = base_color.a;
}