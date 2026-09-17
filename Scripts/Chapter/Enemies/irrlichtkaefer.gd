extends CharacterBody2D

signal defeated

enum State {
	PATROL,
	STALK,
	TELEGRAPH,
	DART,
	RECOVER,
	DEAD
}

const LIGHT_TEXTURE := preload("res://Assets/Light/torch_light.png")
const IDLE_FRAMES := [
	preload("res://Assets/Enemies/Irrlichtkaefer/individual/idle_00.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/idle_01.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/idle_02.png"),
	preload("res://Assets/Enemies/Irrlichtkaefer/individual/idle_03.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/idle_04.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/idle_05.png")
]
const WALK_FRAMES := [
	preload("res://Assets/Enemies/Irrlichtkaefer/individual/walk_00.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/walk_01.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/walk_02.png"),
	preload("res://Assets/Enemies/Irrlichtkaefer/individual/walk_03.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/walk_04.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/walk_05.png"),
	preload("res://Assets/Enemies/Irrlichtkaefer/individual/walk_06.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/walk_07.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/walk_08.png")
]
const ATTACK_FRAMES := [
	preload("res://Assets/Enemies/Irrlichtkaefer/individual/attack_00.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/attack_01.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/attack_02.png"),
	preload("res://Assets/Enemies/Irrlichtkaefer/individual/attack_03.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/attack_04.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/attack_05.png")
]
const DEATH_FRAMES := [
	preload("res://Assets/Enemies/Irrlichtkaefer/individual/death_00.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/death_01.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/death_02.png"),
	preload("res://Assets/Enemies/Irrlichtkaefer/individual/death_03.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/death_04.png"), preload("res://Assets/Enemies/Irrlichtkaefer/individual/death_05.png")
]
const CONTACT_COOLDOWN := 0.85
const BASE_SCALE := Vector2(0.18, 0.18)
const GRAVITY := 980.0
const SMALL_OBSTACLE_JUMP_VELOCITY := -278.0
const OBSTACLE_JUMP_COOLDOWN := 0.42

@export var enemy_name := "Irrlichtkaefer"
@export var max_health := 52
@export var patrol_speed := 54.0
@export var stalk_speed := 142.0
@export var dart_speed := 330.0
@export var glow_detection_range := 430.0
@export var dark_detection_range := 126.0
@export var dark_close_attack_range := 82.0
@export var contact_damage := 14

var current_health := 52
var player: Node2D
var home_position := Vector2.ZERO
var state: State = State.PATROL
var state_time := 0.0
var local_time := 0.0
var contact_cooldown := 0.0
var attack_cooldown := 0.7
var dark_ambush_cooldown := 1.8
var dart_direction := Vector2.RIGHT
var facing_sign := 1.0
var is_dead := false
var hit_flash_timer := 0.0
var orbit_side := 1.0
var obstacle_jump_cooldown := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var glow_light: PointLight2D = $PointLight2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	current_health = max_health
	home_position = global_position
	orbit_side = -1.0 if randf() < 0.5 else 1.0
	_build_sprite_frames()
	add_to_group("enemies")
	_sync_player_reference()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	sprite.scale = BASE_SCALE
	sprite.play(&"walk")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_sync_player_reference()
	state_time += delta
	local_time += delta
	contact_cooldown = maxf(contact_cooldown - delta, 0.0)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	dark_ambush_cooldown = maxf(dark_ambush_cooldown - delta, 0.0)
	hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)
	obstacle_jump_cooldown = maxf(obstacle_jump_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 720.0)
	else:
		velocity.y = maxf(velocity.y, 0.0)

	match state:
		State.PATROL:
			_process_patrol(delta)
		State.STALK:
			_process_stalk(delta)
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.DART:
			_process_dart(delta)
		State.RECOVER:
			_process_recover(delta)

	_try_jump_small_obstacle()
	move_and_slide()
	_update_visuals()


func take_damage(amount: int, direction: Vector2, _is_crit: bool = false) -> void:
	if is_dead:
		return
	current_health -= amount
	hit_flash_timer = 0.14
	var push := direction.normalized() if direction.length_squared() > 0.01 else Vector2(-facing_sign, -0.2)
	velocity += push * 145.0
	if current_health <= 0:
		_die()


func _process_patrol(delta: float) -> void:
	var idle_target := home_position.x + sin(local_time * 0.82 + orbit_side) * 46.0
	_seek_horizontal(idle_target, patrol_speed, delta, 3.2)
	if _should_notice_player():
		_enter_state(State.STALK)


func _process_stalk(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_enter_state(State.PATROL)
		return

	var distance := global_position.distance_to(player.global_position)
	if distance > _active_detection_range() + 72.0:
		_enter_state(State.PATROL)
		return

	var flank_distance := 102.0 if _player_is_glowing() else 74.0
	var flank_target_x := player.global_position.x + orbit_side * flank_distance
	_seek_horizontal(flank_target_x, stalk_speed if _player_is_glowing() else stalk_speed * 0.72, delta, 5.4)

	var can_attack := attack_cooldown <= 0.0 and distance <= (164.0 if _player_is_glowing() else dark_close_attack_range)
	if not can_attack:
		return
	if _player_is_glowing() or (dark_ambush_cooldown <= 0.0 and randf() < 0.36):
		_enter_state(State.TELEGRAPH)


func _process_telegraph(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 860.0 * delta)
	if player != null and is_instance_valid(player):
		var predicted_position := player.global_position + _player_velocity() * (0.20 if _player_is_glowing() else 0.12)
		var horizontal_distance := predicted_position.x - global_position.x
		if not is_zero_approx(horizontal_distance):
			dart_direction = Vector2(signf(horizontal_distance), 0.0)
			facing_sign = dart_direction.x
	if state_time >= (0.34 if _player_is_glowing() else 0.48):
		_enter_state(State.DART)


func _process_dart(_delta: float) -> void:
	velocity.x = dart_direction.x * dart_speed
	if state_time >= (0.34 if _player_is_glowing() else 0.27) or is_on_wall():
		_enter_state(State.RECOVER)


func _process_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 720.0 * delta)
	if state_time >= 0.42:
		_enter_state(State.STALK if _should_notice_player() else State.PATROL)


func _enter_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_time = 0.0
	match state:
		State.TELEGRAPH:
			attack_cooldown = 1.25 if _player_is_glowing() else 2.5
			dark_ambush_cooldown = 3.4
			sprite.play(&"attack")
		State.DART:
			sprite.play(&"attack")
		State.RECOVER:
			orbit_side *= -1.0
			sprite.play(&"walk")
		State.PATROL, State.STALK:
			sprite.play(&"walk")


func _should_notice_player() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) <= _active_detection_range()


func _active_detection_range() -> float:
	return glow_detection_range if _player_is_glowing() else dark_detection_range


func _player_is_glowing() -> bool:
	return player != null and is_instance_valid(player) and bool(player.get("is_glowing"))


func _player_velocity() -> Vector2:
	if player != null and is_instance_valid(player):
		var value: Variant = player.get("velocity")
		if value is Vector2:
			return value as Vector2
	return Vector2.ZERO


func _sync_player_reference() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as Node2D


func _seek_horizontal(target_x: float, speed: float, delta: float, responsiveness: float) -> void:
	var horizontal_offset := target_x - global_position.x
	var desired_x := 0.0
	if absf(horizontal_offset) > 3.0:
		desired_x = signf(horizontal_offset) * minf(speed, absf(horizontal_offset) * 4.0)
		facing_sign = signf(desired_x)
	velocity.x = lerpf(velocity.x, desired_x, clampf(responsiveness * delta, 0.0, 1.0))


func _try_jump_small_obstacle() -> void:
	# The beetle never hovers: this is only a short, grounded hop to clear
	# one-tile ledges while it is actively walking into them.
	if not is_on_floor() or obstacle_jump_cooldown > 0.0:
		return
	if not is_on_wall() or absf(velocity.x) < 18.0:
		return
	velocity.y = SMALL_OBSTACLE_JUMP_VELOCITY
	obstacle_jump_cooldown = OBSTACLE_JUMP_COOLDOWN


func _update_visuals() -> void:
	sprite.flip_h = facing_sign < 0.0
	if hit_flash_timer > 0.0:
		sprite.modulate = Color(1.0, 0.82, 1.0, 1.0)
	else:
		sprite.modulate = Color.WHITE

	var target_energy := 0.18
	var target_color := Color(0.18, 0.52, 1.0, 1.0)
	if _player_is_glowing() and state != State.PATROL:
		target_energy = 0.42
		target_color = Color(0.34, 0.84, 1.0, 1.0)
	if state == State.TELEGRAPH:
		target_energy = 0.74 + sin(state_time * 22.0) * 0.08
	elif state == State.DART:
		target_energy = 0.92
		glow_light.position = Vector2(-facing_sign * 8.0, -20.0)
	else:
		glow_light.position = Vector2(0.0, -22.0)
	glow_light.energy = lerpf(glow_light.energy, target_energy, 0.18)
	glow_light.color = glow_light.color.lerp(target_color, 0.18)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead or contact_cooldown > 0.0 or not body.is_in_group("players"):
		return
	contact_cooldown = CONTACT_COOLDOWN
	if body.has_method("take_damage"):
		body.call("take_damage", contact_damage, global_position)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	state = State.DEAD
	emit_signal("defeated")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	hitbox.monitoring = false
	velocity = Vector2.ZERO
	glow_light.energy = 0.0
	sprite.play(&"death")
	await sprite.animation_finished
	queue_free()


func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	_add_frames(frames, &"idle", IDLE_FRAMES, 6.0, true)
	_add_frames(frames, &"walk", WALK_FRAMES, 9.0, true)
	_add_frames(frames, &"attack", ATTACK_FRAMES, 13.0, false)
	_add_frames(frames, &"death", DEATH_FRAMES, 9.0, false)
	sprite.sprite_frames = frames
	sprite.animation = &"walk"


func _add_frames(frames: SpriteFrames, animation_name: StringName, textures: Array, fps: float, loop: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)
	for texture: Texture2D in textures:
		frames.add_frame(animation_name, texture)
