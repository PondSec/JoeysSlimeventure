extends RigidBody2D

@export var player_force: float = 70.0
@export var torque_force: float = 90.0
@export var upward_force_min: float = 60.0
@export var upward_force_max: float = 140.0
@export var wind_force_min: float = 8.0
@export var wind_force_max: float = 20.0
@export var turbulence_force: float = 10.0
@export var direction_change_time: float = 1.5
@export var lifetime: float = 15.0
@export var fade_duration: float = 2.5

# Weiches Fallen
@export var sway_amplitude: float = 40.0
@export var sway_speed: float = 0.9
@export var rotation_variation: float = 0.3
@export var gravity_fluctuation: float = 0.25
@export var wind_smoothness: float = 2.0

# Bodenverhalten
@export var ground_friction: float = 10.0
@export var ground_push_force: float = 18.0
@export var ground_torque_force: float = 12.0
@export var lift_chance: float = 0.45
@export var flutter_duration: float = 0.6

# Nähe zum Spieler
@export var proximity_radius: float = 60.0
@export var proximity_lift_force: float = 70.0

var wind_direction: Vector2 = Vector2.ZERO
var target_wind_direction: Vector2 = Vector2.ZERO
var wind_timer: float = 0.0
var current_wind_force: float = 0.0
var is_airborne: bool = true
var sleep_timer: float = 0.0
var lifetime_timer: float = 0.0
var is_fading: bool = false
var sway_timer: float = randf() * PI * 2
var base_gravity: float
var last_player_pos := {}

func _ready():
	randomize()
	current_wind_force = randf_range(wind_force_min, wind_force_max)
	update_wind_direction()
	target_wind_direction = wind_direction
	base_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	angular_velocity = randf_range(-1.0, 1.0)
	lifetime_timer = lifetime
	$Sprite2D.modulate.a = 1.0

func _physics_process(delta):
	if not is_fading:
		lifetime_timer -= delta
		if lifetime_timer <= fade_duration and lifetime_timer > 0:
			start_fade_out()
		elif lifetime_timer <= 0:
			queue_free()

	check_airborne_status()

	if is_airborne:
		process_airborne(delta)
	else:
		process_ground(delta)

func process_airborne(delta):
	wind_timer -= delta
	if wind_timer <= 0:
		update_wind_direction()
		target_wind_direction = wind_direction
		wind_timer = randf_range(direction_change_time * 0.8, direction_change_time * 1.2)

	wind_direction = wind_direction.lerp(target_wind_direction, delta * wind_smoothness)
	apply_central_force(wind_direction * current_wind_force)

	sway_timer += delta * sway_speed
	var sway_offset = sin(sway_timer) * sway_amplitude * delta
	apply_central_force(Vector2(sway_offset, 0))

	angular_velocity += randf_range(-rotation_variation, rotation_variation) * delta
	var fall_mod = 1.0 + randf_range(-gravity_fluctuation, gravity_fluctuation)
	apply_central_force(Vector2(0, base_gravity * fall_mod * delta))

	# Mikro-Turbulenz für Lebendigkeit
	if randf() < 0.15:
		var random_turb = Vector2(randf_range(-4, 4), randf_range(-6, 2))
		apply_central_force(random_turb)

	if randf() < 0.05:
		apply_turbulence()

func process_ground(delta):
	linear_damp = ground_friction
	angular_damp = ground_friction * 1.4
	angular_velocity = lerp(angular_velocity, 0.0, delta * 2.0)
	rotation = lerp_angle(rotation, 0.0, delta * 2.0)

	for body in get_tree().get_nodes_in_group("players"):
		var dist = global_position.distance_to(body.global_position)
		if dist < proximity_radius:
			var dir = (global_position - body.global_position).normalized()
			var lift_power = clamp(1.0 - (dist / proximity_radius), 0.0, 1.0)
			if randf() < 0.05:
				is_airborne = true
				linear_damp = 0
				angular_damp = 0
				var upward = -Vector2(0, randf_range(upward_force_min * 0.3, upward_force_max * 0.6))
				apply_central_impulse(dir * ground_push_force * lift_power + upward)
				apply_torque_impulse(randf_range(-ground_torque_force, ground_torque_force))

func start_fade_out():
	if is_fading:
		return
	is_fading = true
	var sprite = $Sprite2D
	var tween = create_tween()
	tween.tween_method(set_alpha, 1.0, 0.0, fade_duration)
	tween.tween_callback(queue_free)

func set_alpha(alpha: float):
	var sprite = $Sprite2D
	if sprite:
		sprite.modulate.a = alpha

func check_airborne_status():
	if linear_velocity.length() < 8.0 and abs(angular_velocity) < 0.3:
		sleep_timer += get_physics_process_delta_time()
		if sleep_timer > 0.6:
			is_airborne = false
	else:
		sleep_timer = 0.0
		is_airborne = true

func update_wind_direction():
	var angle = randf_range(-PI * 0.4, PI * 0.4)
	wind_direction = Vector2(cos(angle), sin(angle)).normalized()
	current_wind_force = randf_range(wind_force_min, wind_force_max)

func apply_turbulence():
	var turbulence = Vector2(
		randf_range(-turbulence_force, turbulence_force),
		randf_range(-turbulence_force * 0.3, turbulence_force * 0.6)
	)
	apply_central_impulse(turbulence)
	apply_torque_impulse(randf_range(-torque_force * 0.15, torque_force * 0.15))

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		if body.has_method("get_velocity"):
			var vel = body.get_velocity()
			if vel.length() > 20:
				interact_with_player(body)
				# Sog-Effekt bei schneller Bewegung
				if vel.length() > 60:
					var trail_dir = (body.global_position - global_position).normalized()
					apply_central_force(trail_dir * vel.length() * 0.05)
		else:
			if not last_player_pos.has(body):
				last_player_pos[body] = body.global_position
				return
			var dist = body.global_position.distance_to(last_player_pos[body])
			last_player_pos[body] = body.global_position
			if dist > 10:
				interact_with_player(body)

func interact_with_player(player):
	var dir = (global_position - player.global_position).normalized()
	var tangential = Vector2(-dir.y, dir.x) * randf_range(0.5, 1.2)
	var swirl = (dir + tangential).normalized()

	if not is_airborne:
		if randf() < lift_chance:
			is_airborne = true
			sleep_timer = 0.0
			linear_damp = 0
			angular_damp = 0
			var upward_force = randf_range(upward_force_min * 0.5, upward_force_max)
			var force_vec = swirl * ground_push_force + Vector2(0, -upward_force)
			apply_central_impulse(force_vec)
			apply_torque_impulse(randf_range(-ground_torque_force, ground_torque_force))
		else:
			var sideways_force = swirl * randf_range(ground_push_force * 0.5, ground_push_force)
			apply_central_impulse(sideways_force)
			apply_torque_impulse(randf_range(-ground_torque_force * 0.3, ground_torque_force * 0.3))
	else:
		var swirl_force = swirl * randf_range(player_force * 0.7, player_force * 1.1)
		var upward_force = randf_range(upward_force_min * 0.6, upward_force_max)
		apply_central_impulse(swirl_force + Vector2(0, -upward_force))
		apply_torque_impulse(randf_range(-torque_force * 0.5, torque_force * 0.5))
