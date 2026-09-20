extends CharacterBody2D

const LootDropper := preload("res://Scripts/loot_dropper.gd")

signal defeated

enum State { PATROL, CHASE, ATTACK, DEAD }

const WALK_FRAMES := [
	preload("res://Assets/Enemies/Glutkaefer/walk/frame_01.png"),
	preload("res://Assets/Enemies/Glutkaefer/walk/frame_02.png"),
	preload("res://Assets/Enemies/Glutkaefer/walk/frame_03.png"),
	preload("res://Assets/Enemies/Glutkaefer/walk/frame_04.png"),
	preload("res://Assets/Enemies/Glutkaefer/walk/frame_05.png"),
	preload("res://Assets/Enemies/Glutkaefer/walk/frame_06.png"),
	preload("res://Assets/Enemies/Glutkaefer/walk/frame_07.png"),
	preload("res://Assets/Enemies/Glutkaefer/walk/frame_08.png")
]
const ATTACK_SHEET := preload("res://Assets/Enemies/Glutkaefer/attack_sheet.png")
const GRAVITY := 980.0
const BASE_SCALE := Vector2(0.48, 0.48)

@export var enemy_name := "Glutkaefer"
@export var max_health := 92
@export var patrol_speed := 44.0
@export var chase_speed := 122.0
@export var contact_damage := 18
@export var drops_glut_schluessel := false

var current_health := 92
var player: Node2D
var home_position := Vector2.ZERO
var state: State = State.PATROL
var state_time := 0.0
var attack_cooldown := 0.0
var attack_hit_delivered := false
var is_dead := false
var facing_sign := 1.0
var hit_flash_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var glow_light: PointLight2D = $PointLight2D


func _ready() -> void:
	current_health = max_health
	home_position = global_position
	attack_cooldown = randf_range(0.25, 0.9)
	_build_sprite_frames()
	sprite.scale = BASE_SCALE
	sprite.play(&"idle")
	add_to_group("enemies")
	_sync_player_reference()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_sync_player_reference()
	state_time += delta
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 760.0)
	else:
		velocity.y = maxf(velocity.y, 0.0)

	match state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)

	move_and_slide()
	_update_visuals()


func take_damage(amount: int, direction: Vector2, _is_crit: bool = false) -> void:
	if is_dead:
		return
	current_health -= amount
	hit_flash_timer = 0.13
	var push := direction.normalized() if direction.length_squared() > 0.01 else Vector2(-facing_sign, -0.2)
	velocity += push * 135.0
	if current_health <= 0:
		call_deferred("_die")


func _process_patrol(delta: float) -> void:
	var target_x := home_position.x + sin(Time.get_ticks_msec() * 0.0014) * 42.0
	_move_toward_x(target_x, patrol_speed, delta)
	if _can_see_player():
		_set_state(State.CHASE)


func _process_chase(delta: float) -> void:
	if player == null:
		_set_state(State.PATROL)
		return
	var distance := _player_distance()
	if distance > _active_detection_range() or not _can_see_player():
		_set_state(State.PATROL)
		return
	_move_toward_x(player.global_position.x, chase_speed, delta)
	if distance <= 72.0 and attack_cooldown <= 0.0:
		_set_state(State.ATTACK)


func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 920.0 * delta)
	if not attack_hit_delivered and state_time >= 0.28:
		attack_hit_delivered = true
		if player != null and _player_distance() <= 94.0 and player.has_method("take_damage"):
			player.call_deferred("take_damage", contact_damage, global_position)
	if state_time >= 0.62:
		attack_cooldown = 1.15
		_set_state(State.CHASE if _player_distance() <= 400.0 else State.PATROL)


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_time = 0.0
	if state == State.ATTACK:
		attack_hit_delivered = false
		sprite.play(&"attack")
	elif state == State.PATROL:
		sprite.play(&"idle")
	else:
		sprite.play(&"walk")


func _move_toward_x(target_x: float, speed: float, delta: float) -> void:
	var offset := target_x - global_position.x
	if absf(offset) > 4.0:
		facing_sign = signf(offset)
	var desired := signf(offset) * minf(speed, absf(offset) * 4.0)
	velocity.x = lerpf(velocity.x, desired, clampf(delta * 6.0, 0.0, 1.0))


func _player_distance() -> float:
	return global_position.distance_to(player.global_position) if player != null and is_instance_valid(player) else INF


func _active_detection_range() -> float:
	return 360.0 if player != null and bool(player.get("is_glowing")) else 156.0


func _can_see_player() -> bool:
	if player == null or not is_instance_valid(player) or _player_distance() > _active_detection_range():
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0.0, -20.0), player.global_position)
	query.collision_mask = 2
	query.exclude = [get_rid(), player.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _sync_player_reference() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as Node2D


func _update_visuals() -> void:
	sprite.flip_h = facing_sign < 0.0
	sprite.modulate = Color(3.2, 2.2, 1.5, 1.0) if hit_flash_timer > 0.0 else Color.WHITE
	var pulse := 0.74 + sin(Time.get_ticks_msec() * 0.007) * 0.12
	glow_light.energy = 1.18 if state == State.ATTACK else pulse


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	CombatEvents.report_enemy_defeated(self)
	state = State.DEAD
	emit_signal("defeated")
	if drops_glut_schluessel:
		LootDropper.spawn_independent_drops(self, [{"item": "glut_schluessel", "chance": 1.0}])
	else:
		LootDropper.spawn_independent_drops(self, [{"item": "copper_nugget", "chance": 0.38}])
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	glow_light.energy = 0.0
	var fade := create_tween()
	fade.tween_property(sprite, "modulate:a", 0.0, 0.34)
	await fade.finished
	queue_free()


func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	_add_frames(frames, &"idle", [WALK_FRAMES[0], WALK_FRAMES[1], WALK_FRAMES[0]], 4.0, true)
	_add_frames(frames, &"walk", WALK_FRAMES, 9.0, true)
	var attack_frames: Array[Texture2D] = []
	for frame_index in range(4):
		var atlas := AtlasTexture.new()
		atlas.atlas = ATTACK_SHEET
		atlas.region = Rect2(frame_index * 128, 0, 128, 128)
		attack_frames.append(atlas)
	_add_frames(frames, &"attack", attack_frames, 8.0, false)
	sprite.sprite_frames = frames


func _add_frames(frames: SpriteFrames, animation_name: StringName, textures: Array, fps: float, loop: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)
	for texture: Texture2D in textures:
		frames.add_frame(animation_name, texture)
