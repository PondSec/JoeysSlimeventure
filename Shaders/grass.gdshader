shader_type canvas_item;
render_mode blend_mix;

// Wind Settings
uniform float wind_speed = 1.5;
uniform float wind_strength = 0.4;
uniform float wind_frequency = 4.0;

// Grass Properties
uniform float grass_stiffness = 0.65; // 0.0 = very floppy, 1.0 = stiff
uniform float recovery_speed = 2.0; // How fast grass springs back

// Player Interaction
uniform float player_pressure = 0.0;
uniform float pressure_position = 0.5;
uniform float pressure_width = 0.2;
uniform float pressure_strength = 0.5;

// Noise function for organic variation
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453);
}

void vertex() {
    vec2 pos = VERTEX;
    float time = TIME * wind_speed;
    float grass_id = rand(vec2(UV.x, 0.0));
    
    // Organic wind movement (multi-frequency)
    float wind_wave = 
        sin(time * 0.8 + UV.x * wind_frequency) * 0.6 +
        sin(time * 2.5 + UV.x * wind_frequency * 3.0) * 0.3;
    
    // Apply wind with height-based bending
    float height_factor = smoothstep(0.0, 0.7, UV.y);
    pos.x += wind_wave * wind_strength * 8.0 * height_factor * (1.0 - grass_stiffness);
    
    // PLAYER INTERACTION - PROPER IMPLEMENTATION
    if (player_pressure > 0.001) {
        // Calculate distance to pressure center
        float dist = abs(UV.x - pressure_position);
        
        if (dist < pressure_width) {
            // Smooth falloff curve
            float falloff = 1.0 - smoothstep(0.0, pressure_width, dist);
            
            // Calculate depression (curved like real grass)
            float depression = 
                // Main downward push
                falloff * player_pressure * pressure_strength * 
                // More effect at top of grass
                pow(UV.y, 1.5) * 20.0 +
                // Gentle sideways push away from center
                (UV.x - pressure_position) * falloff * 6.0;
            
            // Apply the effect
            pos.y += depression;
        }
    }
    
    VERTEX = pos;
}