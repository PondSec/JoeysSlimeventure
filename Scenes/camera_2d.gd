extends Camera2D

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var roll_intensity: float = 0.0
var zoom_punch: float = 0.0

# A short, directional impact impulse is kept separate from the broad camera
# shake used by explosions.  Melee impacts should feel physical without making
# pixel-art combat noisy or moving the HUD.
var impact_duration: float = 0.0
var impact_timer: float = 0.0
var impact_amplitude: float = 0.0
var impact_direction := Vector2.ZERO
var impact_phase: float = 0.0

var base_zoom := Vector2.ONE


func _ready() -> void:
	add_to_group("main_camera")
	base_zoom = zoom


func _process(delta: float) -> void:

	var regular_offset := Vector2.ZERO
	if shake_timer > 0.0:
		shake_timer = max(shake_timer - delta, 0.0)
		var strength := 0.0
		if shake_duration > 0.0:
			strength = ease(shake_timer / shake_duration, 1.8)
		var offset_strength := shake_intensity * strength
		regular_offset = Vector2(
			randf_range(-offset_strength, offset_strength),
			randf_range(-offset_strength, offset_strength)
		)
		rotation = randf_range(-roll_intensity, roll_intensity) * strength
	else:
		rotation = lerp(rotation, 0.0, 0.22)

	var impact_offset := Vector2.ZERO
	if impact_timer > 0.0:
		impact_timer = maxf(impact_timer - delta, 0.0)
		impact_phase += delta * 92.0
		var normalized_time := impact_timer / maxf(impact_duration, 0.001)
		var envelope := normalized_time * normalized_time
		var side := Vector2(-impact_direction.y, impact_direction.x)
		# Two damped, authored-feeling oscillations read as an impact instead
		# of random jitter.  They decay entirely before the next combat frame.
		impact_offset = (impact_direction * sin(impact_phase) + side * cos(impact_phase * 0.63) * 0.28) * impact_amplitude * envelope
		if impact_timer <= 0.0:
			impact_amplitude = 0.0

	var target_offset := regular_offset + impact_offset
	if shake_timer <= 0.0 and impact_timer <= 0.0:
		offset = offset.lerp(target_offset, 0.26)
	else:
		offset = target_offset

	zoom_punch = move_toward(zoom_punch, 0.0, delta * 4.6)
	var target_zoom := base_zoom * (1.0 - zoom_punch)
	zoom = zoom.lerp(target_zoom, 0.24)


func shake(intensity: float, duration: float) -> void:
	shake_intensity = max(shake_intensity, intensity)
	shake_duration = max(duration, 0.01)
	shake_timer = shake_duration
	roll_intensity = clamp(intensity * 0.006, 0.0, 0.045)
	zoom_punch = max(zoom_punch, clamp(intensity * 0.008, 0.0, 0.08))


func impact_shake(direction: Vector2, intensity: float = 1.0, duration: float = 0.055) -> void:
	impact_direction = direction.normalized()
	if impact_direction.length_squared() < 0.001:
		impact_direction = Vector2.RIGHT
	impact_amplitude = maxf(impact_amplitude, clampf(intensity, 0.45, 2.6))
	impact_duration = maxf(impact_duration, duration)
	impact_timer = impact_duration
