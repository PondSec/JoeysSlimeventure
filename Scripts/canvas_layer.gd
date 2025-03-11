extends CanvasLayer

# Referenz auf die ProgressBar
var health_bar: ProgressBar

func _ready() -> void:
	health_bar = $HealthBar  # Passe den Pfad zu deinem Fortschrittsbalken an

func update_health(value: int) -> void:
	if health_bar:
		health_bar.value = value
