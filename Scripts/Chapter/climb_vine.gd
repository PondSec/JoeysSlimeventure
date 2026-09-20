class_name ClimbVine
extends Node2D

## A single physical vine assembled from the supplied 32px segment. Its root
## owns the pendulum, so every visual segment and the rider move together.

const SEGMENT_TEXTURE := preload("res://Assets/Chapter/Traversal/climb_vine.png")
const SEGMENT_HEIGHT := 32.0
const MIN_CLIMB_DISTANCE := 26.0
const END_MARGIN := 24.0
const MAX_SWING_ANGLE := 0.30
const SWING_PUMP_ACCELERATION := 3.45
const SWING_DAMPING := 0.34
const MAX_ANGULAR_SPEED := 3.35

var length_pixels := 256.0
var swing_angle := 0.0
var angular_velocity := 0.0
var rider_input := 0.0
var rider: CharacterBody2D
var _previous_angle := 0.0


func configure(vine_length_pixels: float, initial_sway: float = 0.0) -> void:
	length_pixels = maxf(SEGMENT_HEIGHT * 3.0, vine_length_pixels)
	swing_angle = clampf(initial_sway, -MAX_SWING_ANGLE * 0.55, MAX_SWING_ANGLE * 0.55)
	_previous_angle = swing_angle
	_build_segment_chain()
	_build_grab_area()


func _physics_process(delta: float) -> void:
	_previous_angle = swing_angle
	var pendulum_gravity := 980.0 / maxf(length_pixels, 96.0)
	var angular_acceleration := -pendulum_gravity * sin(swing_angle)
	# A/D is a timing-based pump, not a horizontal motor. It adds energy only
	# while the rope already travels in that direction, so holding a key cannot
	# pin Joey against one side. Alternating input with the pendulum builds the
	# satisfying long arc needed for a meaningful jump.
	if absf(rider_input) > 0.08:
		if absf(angular_velocity) <= 0.10 and absf(swing_angle) <= 0.045:
			# A vine begins at rest; give the first A/D press enough torque to
			# establish its initial arc before timing-based pumping takes over.
			angular_acceleration += rider_input * SWING_PUMP_ACCELERATION * 0.72
		elif signf(rider_input) == signf(angular_velocity):
			angular_acceleration += rider_input * SWING_PUMP_ACCELERATION
	angular_acceleration -= angular_velocity * SWING_DAMPING
	angular_velocity = clampf(angular_velocity + angular_acceleration * delta, -MAX_ANGULAR_SPEED, MAX_ANGULAR_SPEED)
	var next_angle := swing_angle + angular_velocity * delta
	if next_angle > MAX_SWING_ANGLE:
		swing_angle = MAX_SWING_ANGLE
		angular_velocity = minf(angular_velocity, 0.0)
	elif next_angle < -MAX_SWING_ANGLE:
		swing_angle = -MAX_SWING_ANGLE
		angular_velocity = maxf(angular_velocity, 0.0)
	else:
		swing_angle = next_angle
	rotation = swing_angle
	# Input is supplied by the rider each physics frame. Letting it decay keeps
	# a released vine lively for a moment instead of freezing unnaturally.
	rider_input = move_toward(rider_input, 0.0, delta * 4.0)


func can_accept_rider(body: CharacterBody2D) -> bool:
	return body != null and is_instance_valid(body) and (rider == null or rider == body)


func begin_riding(body: CharacterBody2D) -> void:
	if can_accept_rider(body):
		rider = body


func end_riding(body: CharacterBody2D) -> void:
	if rider == body:
		rider = null
		rider_input = 0.0


func set_rider_input(value: float) -> void:
	rider_input = clampf(value, -1.0, 1.0)


func clamp_climb_distance(value: float) -> float:
	return clampf(value, MIN_CLIMB_DISTANCE, maxf(MIN_CLIMB_DISTANCE, length_pixels - END_MARGIN))


func closest_climb_distance(world_position: Vector2) -> float:
	var rope_direction := Vector2(sin(swing_angle), cos(swing_angle))
	return clamp_climb_distance((world_position - global_position).dot(rope_direction))


func get_hold_position(climb_distance: float) -> Vector2:
	var rope_direction := Vector2(sin(swing_angle), cos(swing_angle))
	return global_position + rope_direction * clamp_climb_distance(climb_distance)


func get_grip_position(climb_distance: float) -> Vector2:
	# Keep Joey's hands visibly on the vine at every angle. The grip moves along
	# the rope itself rather than using a fixed screen-up offset.
	var rope_direction := Vector2(sin(swing_angle), cos(swing_angle))
	return get_hold_position(climb_distance) - rope_direction * 10.0


func get_hold_velocity(climb_distance: float) -> Vector2:
	var tangent := Vector2(cos(swing_angle), -sin(swing_angle))
	return tangent * angular_velocity * clamp_climb_distance(climb_distance)


func _build_segment_chain() -> void:
	for child: Node in get_children():
		if child.name.begins_with("VineSegment"):
			child.queue_free()
	var segment_count := maxi(3, int(ceil(length_pixels / SEGMENT_HEIGHT)))
	for segment_index: int in range(segment_count):
		var segment := Sprite2D.new()
		segment.name = "VineSegment%02d" % segment_index
		segment.texture = SEGMENT_TEXTURE
		segment.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		segment.position = Vector2(0.0, SEGMENT_HEIGHT * (float(segment_index) + 0.5))
		segment.z_index = 5
		# Small alternating turns preserve the hand-drawn organic silhouette while
		# the parent transform keeps the entire vine physically coherent.
		segment.rotation = sin(float(segment_index) * 1.43) * 0.055
		segment.modulate = Color(0.74 + float(segment_index % 3) * 0.05, 1.0, 0.63, 1.0)
		add_child(segment)


func _build_grab_area() -> void:
	var area := Area2D.new()
	area.name = "ClimbArea"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(42.0, length_pixels - MIN_CLIMB_DISTANCE)
	shape.shape = rectangle
	shape.position = Vector2(0.0, MIN_CLIMB_DISTANCE + rectangle.size.y * 0.5)
	area.add_child(shape)
	area.body_entered.connect(_on_climb_area_body_entered)
	add_child(area)


func _on_climb_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("attach_climb_vine"):
		body.call("attach_climb_vine", self)
