extends Camera2D

var shake_intensity: float = 0.0
var shake_duration: float = 0.0

func _process(delta: float) -> void:
	if shake_duration > 0:
		shake_duration -= delta
		offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
	else:
		offset = Vector2.ZERO

func shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration
