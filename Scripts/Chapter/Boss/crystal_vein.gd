extends Area2D

signal finished

const TELEGRAPH_TEXTURE := preload("res://Assets/Enemy/Kristallruecken/frames/ground_attack_02.png")
const BURST_TEXTURES := [
	preload("res://Assets/Enemy/Kristallruecken/frames/ground_attack_01.png"),
	preload("res://Assets/Enemy/Kristallruecken/frames/ground_attack_00.png")
]

@export var travel_speed := 430.0
@export var telegraph_duration := 0.34
@export var burst_duration := 0.18

var destination := Vector2.ZERO
var damage := 24
var knockback := 280.0
var stage := 0 # 0 travel, 1 telegraph, 2 damaging burst
var stage_time := 0.0
var hit_players: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var light: PointLight2D = $PointLight2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision.set_deferred("disabled", true)
	sprite.texture = TELEGRAPH_TEXTURE
	sprite.scale = Vector2(0.30, 0.30)
	light.energy = 0.0


func configure(start_position: Vector2, target_position: Vector2, new_damage: int, new_knockback: float) -> void:
	global_position = start_position
	destination = target_position
	damage = new_damage
	knockback = new_knockback


func _physics_process(delta: float) -> void:
	stage_time += delta
	match stage:
		0:
			global_position = global_position.move_toward(destination, travel_speed * delta)
			sprite.modulate = Color(0.44, 1.0, 0.80, 0.68 + sin(stage_time * 16.0) * 0.12)
			light.energy = 0.08
			if global_position.distance_to(destination) <= 1.0:
				stage = 1
				stage_time = 0.0
				sprite.scale = Vector2(0.23, 0.23)
		1:
			sprite.modulate = Color(0.60, 1.0, 0.84, 0.46 + sin(stage_time * 23.0) * 0.22)
			light.energy = 0.12
			if stage_time >= telegraph_duration:
				stage = 2
				stage_time = 0.0
				sprite.texture = BURST_TEXTURES[0]
				sprite.scale = Vector2(0.38, 0.38)
				sprite.modulate = Color.WHITE
				light.energy = 0.35
				collision.set_deferred("disabled", false)
		2:
			if stage_time >= burst_duration * 0.48:
				sprite.texture = BURST_TEXTURES[1]
			if stage_time >= burst_duration:
				_finish()


func _on_body_entered(body: Node2D) -> void:
	if stage != 2 or not body.is_in_group("players"):
		return
	var identifier := body.get_instance_id()
	if hit_players.has(identifier):
		return
	hit_players[identifier] = true
	if body.has_method("take_damage"):
		body.call("take_damage", damage, global_position)


func _finish() -> void:
	collision.set_deferred("disabled", true)
	emit_signal("finished")
	queue_free()
