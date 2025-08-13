shader_type canvas_item;

// Kontrollparameter
uniform float wind_power : hint_range(0.1, 2.0) = 0.8;      // Gesamtstärke
uniform float sway_speed : hint_range(0.1, 2.0) = 0.6;       // Grundgeschwindigkeit
uniform float flutter_freq : hint_range(1.0, 15.0) = 8.0;    // Blattflatter-Frequenz
uniform float stem_sway : hint_range(0.0, 1.0) = 0.4;       // Stielbewegung
uniform float random_offset : hint_range(0.0, 100.0) = 0.0;  // Zufälliger Offset pro Pflanze

void vertex() {
    float time = (TIME + random_offset) * sway_speed; // Füge zufälligen Offset hinzu
    vec2 pos = VERTEX;
    vec2 uv = UV;
    
    // Smoothing factors for different parts
    float stem_smooth = smoothstep(0.0, 0.3, uv.y); // Only affects lower part
    float leaf_smooth = smoothstep(0.3, 1.0, uv.y); // Affects upper part
    
    // 1. Grundbewegung (Stiel) - großes, langsames Pendeln
    float slow_sway = sin(time * 0.5) * stem_sway * stem_smooth;
    
    // 2. Mittelbereich - wellenförmige Bewegung mit mehr Harmonischen für Glättung
    float wave_motion = (sin(time * 1.8 + uv.x * 3.0) * 0.5 + 
                        sin(time * 2.3 + uv.x * 4.0) * 0.3) * 0.3 * leaf_smooth;
    
    // 3. Blattspitzen - schnelles Flattern mit mehreren Frequenzen für glattere Bewegung
    float tip_flutter = (sin(time * flutter_freq + uv.x * 15.0) * 0.7 +
                        sin(time * flutter_freq * 1.3 + uv.x * 18.0) * 0.3) *
                        smoothstep(0.6, 1.0, uv.y);
    
    // Kombinierte Bewegung (X-Achse) mit glatten Übergängen
    float x_movement = (slow_sway + wave_motion + tip_flutter) * wind_power * 15.0;
    
    // 4. Subtile Y-Bewegung mit mehr Harmonischen
    float y_movement = (cos(time * 1.2 + uv.x * 2.0) * 0.7 +
                       cos(time * 1.7 + uv.x * 3.0) * 0.3) * 
                       wind_power * 3.0 * uv.y;
    
    // Sanftere Bewegungsübergänge
    pos.x += x_movement;
    pos.y += y_movement;
    
    VERTEX = pos;
}

void fragment() {
    // Leichter Schatteneffekt für Tiefe mit glatterer Bewegung
    vec2 uv_moved = UV + vec2(sin((TIME + random_offset) * 0.7 + UV.y * 5.0) * 0.005);
    vec4 tex = texture(TEXTURE, uv_moved);
    
    // Leichte Farbvariation mit mehr Harmonischen
    float light_var = 0.9 + 0.1 * (sin((TIME + random_offset) * 2.0 + UV.x * 10.0) * 0.7 +
                                  sin((TIME + random_offset) * 2.7 + UV.x * 12.0) * 0.3);
    COLOR = tex * vec4(light_var, light_var * 1.05, light_var, 1.0);
}