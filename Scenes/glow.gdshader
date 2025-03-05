shader_type canvas_item;

uniform vec4 emission_color = vec4(0.5, 1.0, 0.0, 1.0); // Grüne Farbe für den Glüh-Effekt
uniform float emission_strength : hint_range(0.0, 10.0) = 1.0; // Stärke des Glühens

void fragment() {
    // Holen der Texturfarbe
    vec4 tex_color = texture(TEXTURE, FRAGCOORD.xy * TEXTURE_PIXEL_SIZE); // Texturkoordinaten anpassen

    // Berechnung der Endfarbe mit dem Emissionseffekt
    vec4 final_color = tex_color + emission_color * emission_strength;

    // Setzen der endgültigen Farbe
    COLOR = final_color;
}
