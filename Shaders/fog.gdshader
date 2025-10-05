shader_type canvas_item;

// Die von uns erstellte Rausch-Textur
uniform sampler2D noise_texture;
// Geschwindigkeit, mit der sich der Nebel bewegt
uniform vec2 fog_speed = vec2(10.0, 5.0);
// Beeinflusst, wie "durchsichtig" oder "undurchsichtig" die Nebelbereiche sind
uniform float fog_density = 0.5;
// Die Farbe des Nebels
uniform vec4 fog_color : source_color = vec4(0.66, 0.75, 0.78, 1.0);

// Diese Funktion wird für jeden Pixel auf dem Bildschirm aufgerufen
void fragment() {
    // 1. Hole die UV-Koordinaten des aktuellen Pixels.
    // 2. Bewege sie über die Zeit, um den Nebel "fließen" zu lassen.
    //    TIME ist eine eingebaute Variable, die ständig zunimmt.
    vec2 moving_uv = UV + TIME * 0.1 * fog_speed;
    
    // 3. Sample (lies) den Rauschwert an der bewegten Position.
    //    texture() gibt einen Vektor (vec4) zurück, wir nehmen nur den Rot-Kanal (.r),
    //    da Graustufen-Rauschen in allen Kanälen gleich ist.
    float noise_value = texture(noise_texture, moving_uv).r;
    
    // 4. Modifiziere den Rauschwert, um den Kontrast zu erhöhen.
    //    Dies macht die hellen Bereiche heller und die dunklen dunkler,
    //    sodass der Nebel mehr "Löcher" und "Schwaden" hat.
    noise_value = pow(noise_value, fog_density);
    
    // 5. Der finale Alphawert (Durchsichtigkeit) des Nebels an diesem Pixel
    //    basiert auf dem modifizierten Rauschwert.
    float final_alpha = noise_value;
    
    // 6. Setze die Farbe des Pixels.
    //    COLOR ist die Ausgabe des Shaders.
    //    Wir verwenden unsere uniform fog_color, aber multiplizieren den Alpha-Wert
    //    mit unserem berechneten final_alpha.
    COLOR = vec4(fog_color.rgb, fog_color.a * final_alpha);
}