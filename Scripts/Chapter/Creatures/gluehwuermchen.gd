extends Node2D

## A passive lush-cave creature. It deliberately does not join the enemy
## groups, has no collision and cannot be damaged or target the player.
const FLIGHT_FRAMES := [
	preload("res://Assets/Creatures/Gluehwuermchen/frames/flight_00.png"),
	preload("res://Assets/Creatures/Gluehwuermchen/frames/flight_01.png"),
	preload("res://Assets/Creatures/Gluehwuermchen/frames/flight_02.png"),
	preload("res://Assets/Creatures/Gluehwuermchen/frames/flight_03.png"),
	preload("res://Assets/Creatures/Gluehwuermchen/frames/flight_04.png"),
	preload("res://Assets/Creatures/Gluehwuermchen/frames/flight_05.png"),
	preload("res://Assets/Creatures/Gluehwuermchen/frames/flight_06.png"),
	preload("res://Assets/Creatures/Gluehwuermchen/frames/flight_07.png"),
	preload("res://Assets/Creatures/Gluehwuermchen/frames/flight_08.png"),
	preload("res://Assets/Creatures/Gluehwuermchen/frames/flight_09.png"),
	preload("res://Assets/Creatures/Gluehwuermchen/frames/flight_10.png"),
	preload("res://Assets/Creatures/Gluehwuermchen/frames/flight_11.png")
]
const REST_FRAME := preload("res://Assets/Creatures/Gluehwuermchen/frames/rest_00.png")
const GLOW_COLOR := Color(0.78, 1.0, 0.22, 1.0)

enum State { FLYING, RESTING }

@export var cruise_radius := Vector2(92.0, 58.0)
@export var cruise_speed := 40.0
@export var flee_speed := 116.0
@export var flee_distance := 118.0
@export var hectic_player_speed := 150.0
@export var light_energy := 0.42

var home_position := Vector2.ZERO
var flight_target := Vector2.ZERO
var state: State = State.FLYING
var state_time := 0.0
var retarget_time := 0.0
var rest_duration := 0.0
var phase := 0.0
var player: Node2D
var rng := RandomNumberGenerator.new()

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_light: PointLight2D = $PointLight2D


func _ready() -> void:
	home_position = global_position
	rng.randomize()
	phase = rng.randf_range(0.0, TAU)
	_choose_flight_target(false)
	glow_light.color = GLOW_COLOR
	glow_light.energy = light_energy


func _process(delta: float) -> void:
	_sync_player()
	state_time += delta
	retarget_time -= delta
	_update_sprite()

	if _should_flee():
		state = State.FLYING
		retarget_time = 0.0
		_choose_flight_target(true)

	if state == State.RESTING:
		if state_time >= rest_duration:
			state = State.FLYING
			state_time = 0.0
			_choose_flight_target(false)
		return

	if retarget_time <= 0.0 or global_position.distance_to(flight_target) < 5.0:
		if rng.randf() < 0.28 and not _should_flee():
			_begin_rest()
			return
		_choose_flight_target(false)

	var is_fleeing := _should_flee()
	var is_agitated := _player_is_agitated()
	var speed := flee_speed if is_fleeing else cruise_speed
	if is_agitated:
		speed *= 1.34
	var previous_x := global_position.x
	var heading := (flight_target - global_position).normalized()
	# A small perpendicular drift makes each route arc naturally instead of
	# reading as a straight waypoint-to-waypoint steering path.
	var drift := Vector2(-heading.y, heading.x) * sin(state_time * 3.1 + phase) * (0.30 if is_agitated else 0.18)
	var flight_direction := (heading + drift).normalized()
	global_position += flight_direction * speed * delta
	if absf(global_position.x - previous_x) > 0.05:
		sprite.flip_h = global_position.x < previous_x
	sprite.position.y = sin(state_time * 2.4 + phase) * 2.0
	glow_light.energy = light_energy + sin(state_time * 4.0 + phase) * 0.06


func _choose_flight_target(is_fleeing: bool) -> void:
	var offset := Vector2(
		rng.randf_range(-cruise_radius.x, cruise_radius.x),
		rng.randf_range(-cruise_radius.y, cruise_radius.y)
	)
	if is_fleeing and player != null and is_instance_valid(player):
		var away := (global_position - player.global_position).normalized()
		if away.length_squared() < 0.01:
			away = Vector2.RIGHT.rotated(rng.randf_range(-0.65, 0.65))
		var escape_distance := cruise_radius.x * (1.72 if _player_is_agitated() else 1.18)
		flight_target = home_position + away * escape_distance + Vector2(offset.x * 0.25, offset.y)
	else:
		flight_target = home_position + offset
	retarget_time = rng.randf_range(1.1, 2.6)


func _begin_rest() -> void:
	var resting_position := _find_resting_position()
	if resting_position == Vector2.INF:
		_choose_flight_target(false)
		return
	global_position = resting_position
	state = State.RESTING
	state_time = 0.0
	rest_duration = rng.randf_range(1.15, 2.9)
	sprite.position = Vector2.ZERO
	glow_light.energy = light_energy * 0.78


func _find_resting_position() -> Vector2:
	# Future decorative plants can opt in simply by joining this group.
	var candidates := get_tree().get_nodes_in_group("firefly_perches")
	if not candidates.is_empty():
		var perch := candidates[rng.randi_range(0, candidates.size() - 1)] as Node2D
		if perch != null and perch.global_position.distance_to(home_position) <= cruise_radius.x * 1.8:
			return perch.global_position + Vector2(0.0, -4.0)

	# Ground fallback: raycast to actual level geometry, never a guessed Y value.
	var space := get_world_2d().direct_space_state
	var origin := global_position + Vector2(rng.randf_range(-34.0, 34.0), -18.0)
	var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0.0, 132.0), 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return Vector2.INF
	return hit.get("position", Vector2.INF) + Vector2(0.0, -7.0)


func _should_flee() -> bool:
	return player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) <= flee_distance


func _player_is_agitated() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var player_velocity: Variant = player.get("velocity")
	return player_velocity is Vector2 and (player_velocity as Vector2).length() >= hectic_player_speed


func _sync_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as Node2D


func _update_sprite() -> void:
	if state == State.RESTING:
		sprite.texture = REST_FRAME
		return
	var index := int(fposmod(floor(state_time * 12.0 + phase * 2.0), FLIGHT_FRAMES.size()))
	sprite.texture = FLIGHT_FRAMES[index]
