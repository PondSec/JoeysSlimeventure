# Torch (Fackel) - Dokumentation

## Übersicht
Die `torch`-Klasse steuert das Flackern einer Fackel und ihre Animation. Sie erweitert `Sprite2D` und sorgt durch zufällige Schwankungen der Lichtenergie für eine realistische Darstellung einer brennenden Fackel.

## Eigenschaften

### Flacker-Parameter
```gdscript
var flicker_timer: float = 0.0  # Timer für das Flackern
var flicker_interval: float = 0.02 + randf_range(0.0, 0.08)  # Kleineres Intervall für stärkeres Flackern
```
- `flicker_timer`: Hält die verstrichene Zeit seit dem letzten Flackereffekt.
- `flicker_interval`: Bestimmt das zufällige Zeitintervall zwischen den Flackerzyklen.

### Energievariablen
```gdscript
var base_energy: float = 1.0  # Grundenergie des Lichts
var energy_range: float = 0.8  # Größere Schwankungen für stärkeres Flackern
var smooth_energy: float = base_energy  # Smoothed energy für sanfte Übergänge
```
- `base_energy`: Basislichtstärke der Fackel.
- `energy_range`: Bestimmt die maximale Schwankung der Lichtenergie.
- `smooth_energy`: Verwaltet eine geglättete Version der Lichtenergie, um abrupte Änderungen zu vermeiden.

## Methoden

### `_process(delta: float) -> void`
Die `_process`-Methode wird in jedem Frame aufgerufen und verwaltet das Flackern der Fackel sowie die Animation.

```gdscript
func _process(delta: float) -> void:
    # Timer aktualisieren
    flicker_timer += delta

    # Wenn das Zeitintervall überschritten ist, Flackern erzeugen
    if flicker_timer >= flicker_interval:
        # Neue zufällige Energie mit größeren Schwankungen
        var random_variation = randf_range(-energy_range / 2, energy_range / 2)
        smooth_energy = lerp(smooth_energy, base_energy + random_variation, 0.8)  # Schnellere Übergänge

        # Anwenden der geglätteten Energie
        $Light.energy = smooth_energy

        # Neues zufälliges Intervall setzen
        flicker_interval = 0.02 + randf_range(0.0, 0.08)  # Kürzeres Intervall für intensiveres Flackern
        flicker_timer = 0.0

    # Animationen der Fackeln abspielen
    $TorchAnimation.play("torch")
```

#### Ablauf:
1. Der `flicker_timer` wird mit der vergangenen Zeit (`delta`) aktualisiert.
2. Wenn das `flicker_interval` überschritten wurde:
   - Eine zufällige Variabilität (`random_variation`) wird zur Lichtenergie hinzugefügt.
   - Die Lichtenergie (`smooth_energy`) wird mit `lerp` geglättet, um harte Übergänge zu vermeiden.
   - Die aktualisierte Lichtenergie wird auf `$Light.energy` angewendet.
   - Ein neues zufälliges Intervall wird gesetzt.
   - Der Timer wird zurückgesetzt.
3. Die Fackelanimation wird abgespielt.

## Fazit
Diese `torch`-Klasse erzeugt eine lebendige, flackernde Lichtquelle durch zufällige, geglättete Schwankungen der Lichtenergie. Dadurch wirkt die Fackel realistisch und dynamisch.

