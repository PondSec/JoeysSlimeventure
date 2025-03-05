shader_type canvas_item;

uniform float wave_strength : hint_range(0.0, 10.0);  // Stärke der Wellenbewegung
uniform float wave_speed : hint_range(0.0, 5.0);      // Geschwindigkeit der Wellenbewegung
uniform vec2 wave_direction;                            // Richtung der Wellenbewegung (x, y)

void fragment() {
    // Berechnung der UV-Koordinaten der Textur
    vec2 uv = FRAGCOORD.xy / vec2(textureSize(TEXTURE, 0));

    // Berechnung des Wellen-Effekts (sinusbasierte Bewegung)
    float wave = sin(uv.y * 10.0 + TIME * wave_speed) * wave_strength;

    // Verschiebung der Textur basierend auf der Wellenbewegung und der Richtung
    uv.x += wave * wave_direction.x;
    uv.y += wave * wave_direction.y;

    // Begrenzung der UV-Koordinaten, um sie im Bereich [0, 1] zu halten
    uv = fract(uv);

    // Textur mit den modifizierten UV-Koordinaten abfragen
    vec4 tex_color = texture(TEXTURE, uv);
    
    // Ausgabe der berechneten Farbe
    COLOR = tex_color;
}
