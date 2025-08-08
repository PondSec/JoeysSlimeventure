extends Sprite2D

var flicker_timer: float = 0.0  # Timer für das Flackern
var flicker_interval: float = 0.02 + randf_range(0.0, 0.08)  # Kleineres Intervall für stärkeres Flackern
@onready var light = $Light


# Variablen für das Flackern
var base_energy: float = 1.0  # Grundenergie des Lichts
var energy_range: float = 0.8  # Größere Schwankungen für stärkeres Flackern
var smooth_energy: float = base_energy  # Smoothed energy für sanfte Übergänge

# Called every frame. 'delta' is the elapsed time since the previous frame.
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

func _ready() -> void:
	light.add_to_group("lights")
