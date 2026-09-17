extends Area2D

## A travelling sonic pulse: the broad middle frames are deliberately the most
## dangerous, while the small launch and fade-out frames are forgiving.
signal finished

## The supplied source is an irregular strip, not a grid.  Each rectangle hugs
## exactly one hand-drawn pulse (with a tiny safety margin); the companion
## centers keep their visual origin fixed even though those rectangles differ.
const FRAME_REGIONS := [
	Rect2(64, 318, 96, 96), Rect2(191, 264, 122, 188), Rect2(352, 232, 162, 256),
	Rect2(550, 202, 184, 316), Rect2(770, 178, 210, 360), Rect2(1008, 164, 220, 390),
	Rect2(1255, 196, 180, 330), Rect2(1462, 228, 156, 278), Rect2(1683, 260, 132, 218),
	Rect2(1865, 278, 118, 178), Rect2(2025, 318, 94, 96)
]
const FRAME_CENTERS := [
	Vector2(112, 366), Vector2(252, 360), Vector2(433, 360), Vector2(650, 360),
	Vector2(875, 360), Vector2(1118, 360), Vector2(1345, 360), Vector2(1540, 360),
	Vector2(1749, 360), Vector2(1924, 360), Vector2(2072, 366)
]
const DAMAGE_CURVE := [0.32, 0.48, 0.66, 0.84, 1.0, 1.0, 0.84, 0.66, 0.48, 0.32, 0.18]

@export var lifetime := 1.12
@export var max_wall_bounces := 2

var direction := Vector2.RIGHT
var speed := 250.0
var peak_damage := 13
var elapsed := 0.0
var resolved_targets: Array[Node2D] = []
var wall_bounces := 0
var bounce_lock_timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visual(0)


func configure(start_position: Vector2, aim_direction: Vector2, new_speed: float, new_peak_damage: int) -> void:
	global_position = start_position
	direction = aim_direction.normalized() if aim_direction.length_squared() > 0.001 else Vector2.RIGHT
	speed = new_speed
	peak_damage = new_peak_damage
	sprite.flip_h = direction.x < 0.0


func _physics_process(delta: float) -> void:
	elapsed += delta
	bounce_lock_timer = maxf(bounce_lock_timer - delta, 0.0)
	_move_with_wall_bounce(delta)
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	var frame_index := mini(int(floor(progress * FRAME_REGIONS.size())), FRAME_REGIONS.size() - 1)
	_update_visual(frame_index)
	if elapsed >= lifetime:
		_finish()


func _move_with_wall_bounce(delta: float) -> void:
	var travel := direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + travel + direction * 8.0, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for player in get_tree().get_nodes_in_group("players"):
		if player is CollisionObject2D:
			query.exclude.append((player as CollisionObject2D).get_rid())
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or bounce_lock_timer > 0.0:
		global_position += travel
		return

	var normal: Vector2 = hit.get("normal", Vector2.ZERO)
	if normal.length_squared() <= 0.001:
		global_position += travel
		return
	global_position = hit.get("position", global_position) + normal * 3.0
	if wall_bounces >= max_wall_bounces:
		_finish()
		return
	# Vector2.bounce uses the collision normal: incidence angle equals exit angle.
	direction = direction.bounce(normal).normalized()
	wall_bounces += 1
	bounce_lock_timer = 0.055
	sprite.flip_h = direction.x < 0.0


func _update_visual(frame_index: int) -> void:
	var region: Rect2 = FRAME_REGIONS[frame_index]
	sprite.region_rect = region
	# Sprite2D centers each region independently.  Counter that origin change
	# so the expanding pulse stays on its trajectory instead of visibly jumping.
	sprite.offset = region.get_center() - FRAME_CENTERS[frame_index]
	var intensity: float = float(DAMAGE_CURVE[frame_index])
	var pulse_scale := lerpf(0.62, 1.0, intensity)
	sprite.scale = Vector2(0.115 * pulse_scale, 0.115 * pulse_scale)
	var shape := collision_shape.shape as RectangleShape2D
	if shape != null:
		shape.size = Vector2(14.0 + 16.0 * intensity, 22.0 + 27.0 * intensity)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players") or body in resolved_targets:
		return
	resolved_targets.append(body)
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	var frame_index := mini(int(floor(progress * DAMAGE_CURVE.size())), DAMAGE_CURVE.size() - 1)
	var damage := maxi(1, roundi(float(peak_damage) * DAMAGE_CURVE[frame_index]))
	if body.has_method("take_damage"):
		body.call_deferred("take_damage", damage, global_position)


func _finish() -> void:
	monitoring = false
	emit_signal("finished")
	queue_free()
