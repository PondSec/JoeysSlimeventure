extends Area2D

signal finished


const DISTORTION_SHADER: Shader = preload(
	"res://Shaders/sonic_distortion.gdshader"
)


# ============================================================
# SPRITE FRAMES
# ============================================================

const FRAME_REGIONS := [
	Rect2(64, 318, 96, 96),
	Rect2(191, 264, 122, 188),
	Rect2(352, 232, 162, 256),
	Rect2(550, 202, 184, 316),
	Rect2(770, 178, 210, 360),
	Rect2(1008, 164, 220, 390),
	Rect2(1255, 196, 180, 330),
	Rect2(1462, 228, 156, 278),
	Rect2(1683, 260, 132, 218),
	Rect2(1865, 278, 118, 178),
	Rect2(2025, 318, 94, 96)
]


const FRAME_CENTERS := [
	Vector2(112, 366),
	Vector2(252, 360),
	Vector2(433, 360),
	Vector2(650, 360),
	Vector2(875, 360),
	Vector2(1118, 360),
	Vector2(1345, 360),
	Vector2(1540, 360),
	Vector2(1749, 360),
	Vector2(1924, 360),
	Vector2(2072, 366)
]


const DAMAGE_CURVE := [
	0.32,
	0.48,
	0.66,
	0.84,
	1.0,
	1.0,
	0.84,
	0.66,
	0.48,
	0.32,
	0.18
]


# ============================================================
# PROJECTILE SETTINGS
# ============================================================

@export_group("Projectile")

@export var lifetime := 1.12
@export var max_wall_bounces := 2

# Falls dein Originalsprite horizontal nach rechts zeigt:
# 0 lassen.
@export var sprite_rotation_offset_degrees := 0.0


# ============================================================
# SONIC VISUAL SETTINGS
# ============================================================

@export_group("Sonic Visuals")

# Größe des Luftverzerrungsfeldes.
@export var distortion_size := Vector2(110.0, 88.0)

# Wie stark die Umgebung tatsächlich verbogen wird.
@export_range(0.0, 14.0, 0.1)
var distortion_pixels := 5.5

# Gesamtstärke.
@export_range(0.0, 1.5, 0.01)
var distortion_strength := 0.92

# Frequenz der Verzerrungswellen.
@export_range(5.0, 90.0, 1.0)
var distortion_frequency := 42.0

# Hochfrequentes Stauchen/Strecken des Sprites.
@export_range(0.0, 0.2, 0.001)
var visual_wobble := 0.055

# Minimale visuelle Rotationsvibration.
@export_range(0.0, 4.0, 0.05)
var sprite_vibration_degrees := 0.65

# Originalskalierung.
@export var sprite_base_scale := 0.092


# ============================================================
# RUNTIME
# ============================================================

var direction := Vector2.RIGHT
var speed := 250.0
var peak_damage := 13
var minimum_damage := 1
var maximum_damage := 999

var elapsed := 0.0

var resolved_targets: Array[Node2D] = []

var wall_bounces := 0
var bounce_lock_timer := 0.0

# Kurzer zusätzlicher Druckimpuls nach einem Bounce.
var bounce_visual_boost := 0.0


# ============================================================
# DISTORTION
# ============================================================

var distortion_field: Polygon2D
var distortion_material: ShaderMaterial


# ============================================================
# NODES
# ============================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	add_to_group("chapter_ultrasound")
	body_entered.connect(_on_body_entered)

	_create_distortion_field()
	_update_visual(0)
	_update_rotation()
	_update_distortion_direction()


# ============================================================
# CONFIGURE
# ============================================================

func configure(
	start_position: Vector2,
	aim_direction: Vector2,
	new_speed: float,
	new_peak_damage: int,
	new_minimum_damage: int = 1,
	new_maximum_damage: int = 999
) -> void:
	global_position = start_position

	if aim_direction.length_squared() > 0.001:
		direction = aim_direction.normalized()
	else:
		direction = Vector2.RIGHT

	speed = new_speed
	peak_damage = new_peak_damage
	minimum_damage = mini(new_minimum_damage, new_maximum_damage)
	maximum_damage = maxi(new_minimum_damage, new_maximum_damage)

	_update_rotation()
	_update_distortion_direction()


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	elapsed += delta

	bounce_lock_timer = maxf(
		bounce_lock_timer - delta,
		0.0
	)

	bounce_visual_boost = move_toward(
		bounce_visual_boost,
		0.0,
		delta * 5.5
	)

	_move_with_wall_bounce(delta)

	var progress := clampf(
		elapsed / lifetime,
		0.0,
		1.0
	)

	var frame_index := mini(
		int(floor(progress * FRAME_REGIONS.size())),
		FRAME_REGIONS.size() - 1
	)

	_update_visual(frame_index)
	_update_sonic_animation(frame_index)

	if elapsed >= lifetime:
		_finish()


# ============================================================
# MOVEMENT / BOUNCE
# ============================================================

func _move_with_wall_bounce(delta: float) -> void:
	var travel := direction * speed * delta

	# Cave terrain = Layer 2
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + travel + direction * 8.0,
		2
	)

	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit := get_world_2d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or bounce_lock_timer > 0.0:
		global_position += travel
		return

	var normal: Vector2 = hit.get(
		"normal",
		Vector2.ZERO
	)

	if normal.length_squared() <= 0.001:
		global_position += travel
		return

	var hit_position: Vector2 = hit.get(
		"position",
		global_position
	)

	global_position = hit_position + normal * 3.0

	if wall_bounces >= max_wall_bounces:
		_finish()
		return

	# Reflexion.
	direction = direction.bounce(normal).normalized()

	wall_bounces += 1
	bounce_lock_timer = 0.055

	# Kurzer visueller Druckimpuls.
	bounce_visual_boost = 1.0

	_update_rotation()
	_update_distortion_direction()


# ============================================================
# ROTATION
# ============================================================

func _update_rotation() -> void:
	rotation = (
		direction.angle()
		+ deg_to_rad(sprite_rotation_offset_degrees)
	)

	sprite.flip_h = false
	sprite.flip_v = false


# ============================================================
# SPRITE ANIMATION
# ============================================================

func _update_visual(frame_index: int) -> void:
	var region: Rect2 = FRAME_REGIONS[frame_index]

	sprite.region_rect = region

	# Verhindert sichtbares Springen durch unterschiedlich
	# große Regionen im Sprite-Sheet.
	sprite.offset = (
		region.get_center()
		- FRAME_CENTERS[frame_index]
	)

	var intensity: float = float(
		DAMAGE_CURVE[frame_index]
	)

	var pulse_scale := lerpf(
		0.62,
		1.0,
		intensity
	)

	# Zwei überlagerte Frequenzen.
	var wave_a := sin(elapsed * 83.0)

	var wave_b := sin(
		elapsed * 127.0
		+ 1.73
	)

	var wave := (
		wave_a * 0.72
		+ wave_b * 0.28
	)

	var current_wobble := (
		visual_wobble
		* lerpf(
			0.45,
			1.0,
			intensity
		)
	)

	var stretch_x := (
		1.0
		+ wave * current_wobble
	)

	var squeeze_y := (
		1.0
		- wave * current_wobble * 1.35
	)

	sprite.scale = Vector2(
		sprite_base_scale * pulse_scale * stretch_x,
		sprite_base_scale * pulse_scale * squeeze_y
	)

	# Winzige Hochfrequenzvibration.
	var vibration := (
		sin(elapsed * 111.0)
		* sprite_vibration_degrees
		* intensity
	)

	sprite.rotation = deg_to_rad(vibration)

	# Leichtes kaltes Flackern.
	var brightness := (
		0.94
		+ sin(elapsed * 96.0) * 0.06
	)

	sprite.self_modulate = Color(
		brightness * 0.90,
		brightness * 0.97,
		brightness,
		lerpf(
			0.82,
			1.0,
			intensity
		)
	)

	# Collision wächst mit dem Puls.
	var shape := collision_shape.shape as RectangleShape2D

	if shape != null:
		shape.size = Vector2(
			11.0 + 12.0 * intensity,
			18.0 + 21.0 * intensity
		)


# ============================================================
# SONIC DISTORTION ANIMATION
# ============================================================

func _update_sonic_animation(frame_index: int) -> void:
	if distortion_field == null:
		return

	if distortion_material == null:
		return

	var intensity := float(
		DAMAGE_CURVE[frame_index]
	)

	# Feld wächst während der Frameanimation.
	var field_x := lerpf(
		0.66,
		1.12,
		intensity
	)

	var field_y := lerpf(
		0.58,
		1.08,
		intensity
	)

	# Sehr schnelles "Atmen".
	var field_vibration := sin(
		elapsed * 72.0
	)

	field_x *= (
		1.0
		+ field_vibration * 0.018
	)

	field_y *= (
		1.0
		- field_vibration * 0.026
	)

	# Extra Druck nach Wandreflexion.
	field_x *= (
		1.0
		+ bounce_visual_boost * 0.10
	)

	field_y *= (
		1.0
		+ bounce_visual_boost * 0.18
	)

	distortion_field.scale = Vector2(
		field_x,
		field_y
	)

	var current_strength := (
		distortion_strength
		* lerpf(
			0.28,
			1.0,
			intensity
		)
	)

	# Hochfrequente Modulation.
	current_strength *= (
		0.93
		+ sin(elapsed * 91.0) * 0.07
	)

	# Beim Wandtreffer kurzer "WUMM".
	current_strength *= (
		1.0
		+ bounce_visual_boost * 0.45
	)

	distortion_material.set_shader_parameter(
		"effect_time",
		elapsed
	)

	distortion_material.set_shader_parameter(
		"strength",
		current_strength
	)

	distortion_material.set_shader_parameter(
		"distortion_pixels",
		distortion_pixels
	)

	distortion_material.set_shader_parameter(
		"frequency",
		distortion_frequency
	)


# ============================================================
# CREATE DISTORTION FIELD
# ============================================================

func _create_distortion_field() -> void:
	distortion_field = Polygon2D.new()
	distortion_field.name = "SonicDistortionField"

	# Hinter dem Sprite rendern.
	distortion_field.z_index = -1
	distortion_field.show_behind_parent = true

	var half_size := distortion_size * 0.5

	distortion_field.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])

	distortion_field.uv = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0)
	])

	distortion_field.color = Color.WHITE

	distortion_material = ShaderMaterial.new()
	distortion_material.shader = DISTORTION_SHADER

	distortion_field.material = distortion_material

	add_child(distortion_field)

	distortion_material.set_shader_parameter(
		"effect_time",
		0.0
	)

	distortion_material.set_shader_parameter(
		"strength",
		0.0
	)

	distortion_material.set_shader_parameter(
		"distortion_pixels",
		distortion_pixels
	)

	distortion_material.set_shader_parameter(
		"frequency",
		distortion_frequency
	)

	_update_distortion_direction()


# ============================================================
# DISTORTION DIRECTION
# ============================================================

func _update_distortion_direction() -> void:
	if distortion_material == null:
		return

	distortion_material.set_shader_parameter(
		"travel_direction",
		direction
	)


# ============================================================
# DAMAGE
# ============================================================

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players"):
		return

	if body in resolved_targets:
		return

	resolved_targets.append(body)

	var progress := clampf(
		elapsed / lifetime,
		0.0,
		1.0
	)

	var frame_index := mini(
		int(floor(progress * DAMAGE_CURVE.size())),
		DAMAGE_CURVE.size() - 1
	)

	var damage := clampi(
		roundi(float(peak_damage) * DAMAGE_CURVE[frame_index]),
		minimum_damage,
		maximum_damage
	)

	if body.has_method("take_damage"):
		body.call_deferred(
			"take_damage",
			damage,
			global_position
		)


# ============================================================
# FINISH
# ============================================================

func _finish() -> void:
	if is_queued_for_deletion():
		return

	monitoring = false
	finished.emit()
	queue_free()
