extends Area2D

## A travelling sonic pulse: the broad middle frames are deliberately the most
## dangerous, while the small launch and fade-out frames are forgiving.
signal finished

const FRAME_REGIONS := [
	Rect2(0, 92, 154, 534), Rect2(146, 92, 180, 534), Rect2(316, 92, 204, 534),
	Rect2(510, 92, 220, 534), Rect2(716, 92, 236, 534), Rect2(932, 92, 246, 534),
	Rect2(1162, 92, 230, 534), Rect2(1378, 92, 204, 534), Rect2(1570, 92, 180, 534),
	Rect2(1738, 92, 150, 534), Rect2(1878, 92, 294, 534)
]
const DAMAGE_CURVE := [0.32, 0.48, 0.66, 0.84, 1.0, 1.0, 0.84, 0.66, 0.48, 0.32, 0.18]

@export var lifetime := 1.12

var direction := Vector2.RIGHT
var speed := 250.0
var peak_damage := 13
var elapsed := 0.0
var resolved_targets: Array[Node2D] = []

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
	global_position += direction * speed * delta
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	var frame_index := mini(int(floor(progress * FRAME_REGIONS.size())), FRAME_REGIONS.size() - 1)
	_update_visual(frame_index)
	if elapsed >= lifetime:
		_finish()


func _update_visual(frame_index: int) -> void:
	sprite.region_rect = FRAME_REGIONS[frame_index]
	var intensity: float = float(DAMAGE_CURVE[frame_index])
	var pulse_scale := lerpf(0.62, 1.0, intensity)
	sprite.scale = Vector2(0.145 * pulse_scale, 0.145 * pulse_scale)
	var shape := collision_shape.shape as RectangleShape2D
	if shape != null:
		shape.size = Vector2(18.0 + 20.0 * intensity, 28.0 + 34.0 * intensity)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players") or body in resolved_targets:
		return
	resolved_targets.append(body)
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	var frame_index := mini(int(floor(progress * DAMAGE_CURVE.size())), DAMAGE_CURVE.size() - 1)
	var damage := maxi(1, roundi(float(peak_damage) * DAMAGE_CURVE[frame_index]))
	if body.has_method("take_damage"):
		body.call("take_damage", damage, global_position)


func _finish() -> void:
	monitoring = false
	emit_signal("finished")
	queue_free()
