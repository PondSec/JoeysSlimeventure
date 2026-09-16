extends Area2D

signal finished

const ORB_FRAMES := [
	preload("res://Assets/Enemy/Kristallruecken/frames/orb_01.png"),
	preload("res://Assets/Enemy/Kristallruecken/frames/orb_02.png")
]

@export var lifetime := 4.2

var direction := Vector2.RIGHT
var speed := 250.0
var damage := 20
var knockback := 190.0
var elapsed := 0.0
var resolved := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var light: PointLight2D = $PointLight2D


func _ready() -> void:
	_build_frames()
	body_entered.connect(_on_body_entered)


func configure(start_position: Vector2, aim_direction: Vector2, new_speed: float, new_damage: int, new_knockback: float) -> void:
	global_position = start_position
	direction = aim_direction.normalized() if aim_direction.length_squared() > 0.001 else Vector2.RIGHT
	speed = new_speed
	damage = new_damage
	knockback = new_knockback
	sprite.flip_h = direction.x < 0.0


func _physics_process(delta: float) -> void:
	if resolved:
		return
	elapsed += delta
	global_position += direction * speed * delta
	if elapsed >= lifetime:
		_finish()


func _on_body_entered(body: Node2D) -> void:
	if resolved:
		return
	if body.is_in_group("players"):
		if body.has_method("take_damage"):
			body.call("take_damage", damage, global_position)
		_finish()
		return
	# The boss and other enemies are deliberately ignored. Any remaining solid
	# body is level geometry and consumes the orb.
	if not body.is_in_group("enemies"):
		_finish()


func _finish() -> void:
	if resolved:
		return
	resolved = true
	monitoring = false
	light.energy = 0.0
	emit_signal("finished")
	queue_free()


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"fly")
	frames.set_animation_speed(&"fly", 10.0)
	frames.set_animation_loop(&"fly", true)
	for texture: Texture2D in ORB_FRAMES:
		frames.add_frame(&"fly", texture)
	sprite.sprite_frames = frames
	sprite.play(&"fly")
