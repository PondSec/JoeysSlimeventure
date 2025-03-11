extends Node2D

var flicker_timer: float = 0.0  # Timer, um das Flackern zu steuern
var flicker_interval: float = 0.1  # Intervall für das Flackern (in Sekunden)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Timer aktualisieren
	flicker_timer += delta

	# Nur flackern, wenn das Zeitintervall überschritten wurde
	if flicker_timer >= flicker_interval:
		# Werte für die Grundenergie und die Schwankung
		var energy_range = 0.5  # Stärke des Flackerns
		var base_energy = 1.0  # Grundenergie des Lichts

		# Energie der PointLight2D-Objekte zufällig anpassen
		$Torch/Light.energy = base_energy + (randf() * energy_range - energy_range / 2)
		$Torch2/Light.energy = base_energy + (randf() * energy_range - energy_range / 2)
		$Torch3/Light.energy = base_energy + (randf() * energy_range - energy_range / 2)
		$Torch4/Light.energy = base_energy + (randf() * energy_range - energy_range / 2)

		# Timer zurücksetzen
		flicker_timer = 0.0

	# Animationen der Fackeln abspielen
	$Torch/TorchAnimation.play("torch")
	$Torch2/TorchAnimation.play("torch")
	$Torch3/TorchAnimation.play("torch")
	$Torch4/TorchAnimation.play("torch")
