extends CharacterBody2D

signal defeated

const CONTACT_COOLDOWN := 0.85

@export var max_health: int = 26
@export var hover_speed: float = 105.0
@export var chase_speed: float = 155.0
@export var swoop_speed: float = 280.0
@export var detection_range: float = 360.0
@export var swoop_trigger_range: float = 115.0
@export var contact_damage: int = 10

var current_health: int = 26
var player: Node2D
var home_position: Vector2 = Vector2.ZERO
var anim_timer: float = 0.0
var attack_cooldown: float = 0.7
var contact_cooldown: float = 0.0
var swoop_timer: float = 0.0
var swoop_direction: Vector2 = Vector2.ZERO
var flash_timer: float = 0.0
var local_time: float = 0.0
var is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	current_health = max_health
	home_position = global_position
	player = get_tree().get_first_node_in_group("players") as Node2D
	add_to_group("enemies")
	hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as Node2D

	local_time += delta
	anim_timer += delta
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	contact_cooldown = maxf(contact_cooldown - delta, 0.0)
	flash_timer = maxf(flash_timer - delta, 0.0)

	if swoop_timer > 0.0:
		swoop_timer = maxf(swoop_timer - delta, 0.0)
		velocity = swoop_direction * swoop_speed
		if swoop_timer <= 0.0:
			attack_cooldown = 1.05
	else:
		_update_flight(delta)

	move_and_slide()
	sprite.flip_h = velocity.x < 0.0
	sprite.modulate = Color(1.0, 0.72, 0.72, 1.0) if flash_timer > 0.0 else Color.WHITE
	sprite.frame = int(fposmod(floor(anim_timer * 12.0), 4.0))


func take_damage(amount: int, direction: Vector2, _is_crit: bool = false) -> void:
	if is_dead:
		return

	current_health -= amount
	flash_timer = 0.14
	var knockback_direction: Vector2 = direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	velocity += knockback_direction * 130.0
	if current_health <= 0:
		_die()


func _update_flight(delta: float) -> void:
	if player != null and is_instance_valid(player):
		var distance_to_player: float = global_position.distance_to(player.global_position)
		if distance_to_player <= detection_range:
			if attack_cooldown <= 0.0 and distance_to_player <= swoop_trigger_range:
				swoop_direction = (player.global_position - global_position).normalized()
				if swoop_direction == Vector2.ZERO:
					swoop_direction = Vector2.RIGHT
				swoop_timer = 0.38
				return

			var side_offset: float = -56.0 if player.global_position.x >= global_position.x else 56.0
			var chase_target: Vector2 = player.global_position + Vector2(side_offset, -42.0 + sin(local_time * 6.0) * 10.0)
			_seek_towards(chase_target, chase_speed, delta)
			return

	var idle_target: Vector2 = home_position + Vector2(sin(local_time * 1.8) * 54.0, cos(local_time * 2.6) * 18.0)
	_seek_towards(idle_target, hover_speed, delta)


func _seek_towards(target: Vector2, speed: float, delta: float) -> void:
	var to_target: Vector2 = target - global_position
	var desired: Vector2 = Vector2.ZERO
	if to_target.length() > 1.0:
		var desired_speed: float = minf(speed, to_target.length() * 4.0)
		desired = to_target.normalized() * desired_speed
	velocity = velocity.lerp(desired, delta * 4.6)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead or contact_cooldown > 0.0:
		return
	if not body.is_in_group("players"):
		return
	contact_cooldown = CONTACT_COOLDOWN
	if body.has_method("take_damage"):
		body.call("take_damage", contact_damage, global_position)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	emit_signal("defeated")
	var death_tween: Tween = create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	death_tween.tween_property(sprite, "scale", Vector2(1.7, 0.45), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	death_tween.set_parallel(false)
	death_tween.tween_callback(queue_free)
