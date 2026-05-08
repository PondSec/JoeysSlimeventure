extends CharacterBody2D

signal defeated
signal health_changed(current_health: int, max_health: int)

const GRAVITY := 1450.0
const CONTACT_COOLDOWN := 1.0

@export var max_health: int = 220
@export var hop_force_y: float = -520.0
@export var move_force_x: float = 210.0
@export var contact_damage: int = 18
@export var slam_damage: int = 24
@export var minion_scene: PackedScene

var current_health: int = 220
var player: Node2D
var action_cooldown: float = 1.2
var spawn_cooldown: float = 4.8
var slam_cooldown: float = 3.6
var contact_cooldown: float = 0.0
var flash_timer: float = 0.0
var anim_timer: float = 0.0
var local_time: float = 0.0
var is_dead: bool = false
var pending_slam_land: bool = false
var was_on_floor_last_frame: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	current_health = max_health
	player = get_tree().get_first_node_in_group("players") as Node2D
	add_to_group("enemies")
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	emit_signal("health_changed", current_health, max_health)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as Node2D

	local_time += delta
	anim_timer += delta
	action_cooldown = maxf(action_cooldown - delta, 0.0)
	spawn_cooldown = maxf(spawn_cooldown - delta, 0.0)
	slam_cooldown = maxf(slam_cooldown - delta, 0.0)
	contact_cooldown = maxf(contact_cooldown - delta, 0.0)
	flash_timer = maxf(flash_timer - delta, 0.0)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 980.0 * delta)
		if pending_slam_land and not was_on_floor_last_frame:
			_perform_slam_land()
		if action_cooldown <= 0.0:
			_choose_next_action()

	move_and_slide()
	_update_visuals()
	was_on_floor_last_frame = is_on_floor()


func take_damage(amount: int, direction: Vector2, _is_crit: bool = false) -> void:
	if is_dead:
		return

	current_health -= amount
	flash_timer = 0.16
	var knockback_direction: Vector2 = direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	velocity += knockback_direction * 120.0
	velocity.y = minf(velocity.y, -120.0)
	emit_signal("health_changed", max(current_health, 0), max_health)

	if current_health <= 0:
		_die()


func _choose_next_action() -> void:
	if player == null or not is_instance_valid(player):
		return

	var health_ratio: float = float(current_health) / float(max(max_health, 1))
	if health_ratio <= 0.58 and spawn_cooldown <= 0.0:
		_spawn_minions()
		action_cooldown = 1.3
		spawn_cooldown = 6.0
		return

	if health_ratio <= 0.38 and slam_cooldown <= 0.0:
		_perform_slam_jump()
		action_cooldown = 1.85
		slam_cooldown = 5.4
		return

	_perform_hop_attack()
	action_cooldown = 1.15


func _perform_hop_attack() -> void:
	var direction_sign: float = signf(player.global_position.x - global_position.x) if player != null else 1.0
	if is_zero_approx(direction_sign):
		direction_sign = 1.0
	velocity.x = direction_sign * move_force_x
	velocity.y = hop_force_y
	pending_slam_land = false
	_squash(Vector2(0.6, 0.42), 0.16)


func _perform_slam_jump() -> void:
	var direction_sign: float = signf(player.global_position.x - global_position.x) if player != null else 1.0
	velocity.x = direction_sign * (move_force_x * 0.7)
	velocity.y = hop_force_y * 1.18
	pending_slam_land = true
	_squash(Vector2(0.72, 0.34), 0.2)


func _perform_slam_land() -> void:
	pending_slam_land = false
	_squash(Vector2(0.48, 0.58), 0.22)
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null and camera.has_method("shake"):
		camera.call("shake", 0.24, 12.0)

	if player != null and is_instance_valid(player):
		var close_enough_x: bool = abs(player.global_position.x - global_position.x) <= 128.0
		var close_enough_y: bool = abs(player.global_position.y - global_position.y) <= 84.0
		if close_enough_x and close_enough_y and player.has_method("take_damage"):
			player.call("take_damage", slam_damage, global_position)


func _spawn_minions() -> void:
	if minion_scene == null:
		return

	var spawn_offsets := [Vector2(-72, -12), Vector2(72, -12)]
	for offset: Vector2 in spawn_offsets:
		var minion: Node2D = minion_scene.instantiate() as Node2D
		if minion == null:
			continue
		get_parent().add_child(minion)
		minion.global_position = global_position + offset


func _update_visuals() -> void:
	sprite.flip_h = velocity.x < 0.0
	sprite.modulate = Color(1.0, 0.7, 0.74, 1.0) if flash_timer > 0.0 else Color.WHITE

	if is_dead:
		sprite.frame = 14
	elif not is_on_floor():
		sprite.frame = 8
	elif current_health < int(max_health * 0.45):
		sprite.frame = 10 + int(fposmod(floor(anim_timer * 6.0), 2.0))
	else:
		sprite.frame = 5 + int(fposmod(floor(anim_timer * 5.0), 2.0))


func _squash(target_scale: Vector2, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", target_scale, duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(0.32, 0.32), duration * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


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
	emit_signal("health_changed", 0, max_health)
	emit_signal("defeated")
	var death_tween: Tween = create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	death_tween.tween_property(sprite, "scale", Vector2(0.42, 0.18), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	death_tween.set_parallel(false)
	death_tween.tween_callback(queue_free)
