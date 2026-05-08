extends Camera2D

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var roll_intensity: float = 0.0
var zoom_punch: float = 0.0

var base_zoom := Vector2.ONE


func _ready() -> void:
	add_to_group("main_camera")
	base_zoom = zoom


func _process(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer = max(shake_timer - delta, 0.0)
		var strength := 0.0
		if shake_duration > 0.0:
			strength = ease(shake_timer / shake_duration, 1.8)
		var offset_strength := shake_intensity * strength
		offset = Vector2(
			randf_range(-offset_strength, offset_strength),
			randf_range(-offset_strength, offset_strength)
		)
		rotation = randf_range(-roll_intensity, roll_intensity) * strength
	else:
		offset = offset.lerp(Vector2.ZERO, 0.26)
		rotation = lerp(rotation, 0.0, 0.22)

	zoom_punch = move_toward(zoom_punch, 0.0, delta * 4.6)
	var target_zoom := base_zoom * (1.0 - zoom_punch)
	zoom = zoom.lerp(target_zoom, 0.24)


func shake(intensity: float, duration: float) -> void:
	shake_intensity = max(shake_intensity, intensity)
	shake_duration = max(duration, 0.01)
	shake_timer = shake_duration
	roll_intensity = clamp(intensity * 0.006, 0.0, 0.045)
	zoom_punch = max(zoom_punch, clamp(intensity * 0.008, 0.0, 0.08))
