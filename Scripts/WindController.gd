# WindController.gd
extends Node

@export_category("Global Wind Settings")
@export var base_direction_angle_range: float = PI * 0.4
@export var direction_change_time_min: float = 1.0
@export var direction_change_time_max: float = 2.0
@export var force_min: float = 8.0
@export var force_max: float = 20.0
@export var smoothness: float = 2.0
@export var global_variation_amount: float = 0.15  # small global turbulence
@export var update_interval: float = 0.1

var target_direction: Vector2 = Vector2.RIGHT
var direction: Vector2 = Vector2.RIGHT
var current_force: float = 10.0
var target_force: float = 10.0
var change_timer: float = 0.0
var dt_acc: float = 0.0

func _ready():
	randomize()
	_reset_target()
	direction = target_direction
	current_force = target_force
	change_timer = randf_range(direction_change_time_min, direction_change_time_max)

func _physics_process(delta: float) -> void:
	# Timer to occasionally pick a new target direction/force
	change_timer -= delta
	if change_timer <= 0.0:
		_reset_target()
		change_timer = randf_range(direction_change_time_min, direction_change_time_max)

	# Smoothly move direction/force towards targets
	direction = direction.lerp(target_direction, delta * smoothness).normalized()
	current_force = lerp(current_force, target_force, delta * (smoothness * 0.6))

	# small global turbulence to keep everything lively
	dt_acc += delta
	if dt_acc >= update_interval:
		dt_acc = 0.0
		var micro = Vector2(randf_range(-global_variation_amount, global_variation_amount),
							randf_range(-global_variation_amount, global_variation_amount))
		direction = (direction + micro).normalized()

func _reset_target() -> void:
	var angle = randf_range(-base_direction_angle_range, base_direction_angle_range)
	target_direction = Vector2(cos(angle), sin(angle)).normalized()
	target_force = randf_range(force_min, force_max)

# Return current global wind vector
func get_wind_vector() -> Vector2:
	return direction * current_force

# Return both direction and force if desired
func get_wind_raw() -> Dictionary:
	return {"direction": direction, "force": current_force}
