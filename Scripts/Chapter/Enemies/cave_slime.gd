extends CharacterBody2D

const LootDropper := preload("res://Scripts/loot_dropper.gd")

signal defeated

const GRAVITY := 1300.0
const CONTACT_COOLDOWN := 0.8
const WORLD_COLLISION_MASK := 2
const BASE_SPRITE_SCALE := Vector2(0.095, 0.095)
const SQUASH_SPRITE_SCALE := Vector2(0.118, 0.074)
const BASE_COLOR := Color(0.42, 0.84, 1.0, 1.0)
const HIT_FLASH_COLOR := Color(3.4, 3.4, 3.4, 1.0)

enum State { PATROL, CHASE, TELEGRAPH, LEAP, EVADE, RECOVER, DEAD }

@export var max_health: int = 32
@export var hop_impulse_y: float = -320.0
@export var hop_impulse_x: float = 155.0
@export var aggro_range: float = 260.0
@export var contact_damage: int = 10

var current_health: int = 32
var player: Node2D
var home_position := Vector2.ZERO
var hop_timer: float = 0.25
var contact_timer: float = 0.0
var anim_timer: float = 0.0
var hit_flash_timer: float = 0.0
var is_dead: bool = false
var state: State = State.PATROL
var state_time := 0.0
var patrol_side := 1.0
var attack_target_x := 0.0
var evade_cooldown := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_light: PointLight2D = $PointLight2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	current_health = max_health
	home_position = global_position
	patrol_side = -1.0 if randf() < 0.5 else 1.0
	hop_timer = randf_range(0.12, 0.66)
	player = get_tree().get_first_node_in_group("players") as Node2D
	add_to_group("enemies")
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	sprite.scale = BASE_SPRITE_SCALE
	if glow_light != null:
		glow_light.visible = false
	_update_animation(0.0)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as Node2D

	hop_timer = maxf(hop_timer - delta, 0.0)
	contact_timer = maxf(contact_timer - delta, 0.0)
	hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)
	evade_cooldown = maxf(evade_cooldown - delta, 0.0)
	state_time += delta
	anim_timer += delta

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)

	match state:
		State.PATROL:
			_process_patrol()
		State.CHASE:
			_process_chase()
		State.TELEGRAPH:
			_process_telegraph()
		State.LEAP, State.EVADE:
			_process_air_action()
		State.RECOVER:
			if state_time >= 0.34:
				_enter_state(State.CHASE if _can_notice_player() else State.PATROL)

	move_and_slide()
	_update_visuals()
	_update_animation(delta)


func take_damage(amount: int, direction: Vector2, _is_crit: bool = false) -> void:
	if is_dead or current_health <= 0:
		return

	current_health -= amount
	hit_flash_timer = 0.16
	var knockback_direction: Vector2 = Vector2(signf(direction.x), 0.0) if absf(direction.x) > 0.01 else Vector2(signf(global_position.x - player.global_position.x), 0.0)
	velocity += knockback_direction * 180.0
	if current_health <= 0:
		call_deferred("_die")
	# A damage reaction must not randomly turn into a second jump.  Besides
	# feeling slippery, that launch could combine with knockback at a wall.


func _process_patrol() -> void:
	if _can_notice_player():
		_enter_state(State.CHASE)
		return
	if hop_timer <= 0.0 and is_on_floor():
		if absf(global_position.x - home_position.x) >= 72.0:
			patrol_side = signf(home_position.x - global_position.x)
		_start_hop(global_position.x + patrol_side * 42.0, 0.72)


func _process_chase() -> void:
	if not _can_notice_player(72.0):
		_enter_state(State.PATROL)
		return
	if player == null or not is_instance_valid(player):
		return
	var horizontal_distance := absf(player.global_position.x - global_position.x)
	if horizontal_distance <= 150.0 and is_on_floor() and hop_timer <= 0.0:
		attack_target_x = player.global_position.x + _player_velocity().x * 0.22
		_enter_state(State.TELEGRAPH)
		return
	if hop_timer <= 0.0 and is_on_floor():
		_start_hop(player.global_position.x + _player_velocity().x * 0.12, 0.9)


func _process_telegraph() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1600.0 * get_physics_process_delta_time())
	if state_time >= 0.27:
		_start_hop(attack_target_x, 1.16)
		_enter_state(State.LEAP)


func _process_air_action() -> void:
	if is_on_floor() and state_time >= 0.08:
		_enter_state(State.RECOVER)
	elif state_time >= 0.96:
		_enter_state(State.RECOVER)


func _start_hop(target_x: float, strength: float) -> void:
	var direction_sign := signf(target_x - global_position.x)
	if is_zero_approx(direction_sign):
		direction_sign = patrol_side
	# A small forward/downward probe prevents blind chase hops into a pit. The
	# slime turns around at unsupported ledges rather than getting stranded.
	if not _has_safe_ground_ahead(direction_sign):
		direction_sign *= -1.0
	patrol_side = direction_sign
	velocity.x = direction_sign * hop_impulse_x * strength
	velocity.y = hop_impulse_y * (1.06 if strength > 1.0 else 1.0)
	hop_timer = randf_range(0.56, 0.78)
	var squash_tween: Tween = create_tween()
	squash_tween.tween_property(sprite, "scale", SQUASH_SPRITE_SCALE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	squash_tween.tween_property(sprite, "scale", BASE_SPRITE_SCALE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _has_safe_ground_ahead(direction_sign: float) -> bool:
	if get_world_2d() == null:
		return true
	var probe := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(direction_sign * 28.0, 4.0),
		global_position + Vector2(direction_sign * 28.0, 46.0),
		WORLD_COLLISION_MASK
	)
	probe.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(probe).is_empty()


func _enter_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_time = 0.0
	if state == State.EVADE:
		var away_x := global_position.x - (player.global_position.x if player and is_instance_valid(player) else global_position.x - patrol_side)
		_start_hop(global_position.x + signf(away_x) * 80.0, 1.05)
		evade_cooldown = 2.2


func _can_notice_player(extra_range: float = 0.0) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var vision_range := aggro_range if bool(player.get("is_glowing")) else aggro_range * 0.46
	if global_position.distance_to(player.global_position) > vision_range + extra_range:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0.0, -14.0), player.global_position)
	query.collision_mask = 2
	query.exclude = [get_rid(), player.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _player_velocity() -> Vector2:
	if player != null and is_instance_valid(player):
		var player_velocity: Variant = player.get("velocity")
		if player_velocity is Vector2:
			return player_velocity as Vector2
	return Vector2.ZERO


func _update_visuals() -> void:
	sprite.flip_h = velocity.x < 0.0
	if hit_flash_timer > 0.0:
		sprite.modulate = HIT_FLASH_COLOR
		return

	var pulse: float = 0.5 + 0.5 * sin(anim_timer * 4.2)
	# The cave slime shares Joey's slime-sheet rhythm, but remains a small,
	# consistently light-blue creature rather than a moving light source.
	sprite.modulate = BASE_COLOR.lerp(Color(0.62, 0.94, 1.0, 1.0), 0.08 + pulse * 0.08)


func _update_animation(_delta: float) -> void:
	if is_dead:
		sprite.frame = 14
		return

	if not is_on_floor():
		sprite.frame = 8
		return

	if state == State.TELEGRAPH:
		sprite.frame = 6
	elif state in [State.LEAP, State.EVADE]:
		sprite.frame = 8
	elif state in [State.CHASE, State.RECOVER]:
		sprite.frame = 2 + int(fposmod(floor(anim_timer * 8.0), 2.0))
	else:
		sprite.frame = int(fposmod(floor(anim_timer * 6.0), 2.0))


func _on_hitbox_body_entered(body: Node2D) -> void:
	# Walking into the slime is pressure, not invisible damage.  Only the
	# committed, telegraphed leap has an active contact hit.
	if is_dead or contact_timer > 0.0 or state != State.LEAP or state_time < 0.075:
		return
	if not body.is_in_group("players"):
		return
	contact_timer = CONTACT_COOLDOWN
	if body.has_method("take_damage"):
		body.call_deferred("take_damage", contact_damage, global_position)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	state = State.DEAD
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	emit_signal("defeated")
	LootDropper.spawn_independent_drops(self, [
		{"item": "health_heart", "chance": 0.56},
		{"item": "copper_nugget", "chance": 0.46},
		{"item": "iron_nugget", "chance": 0.12},
		{"item": "gold_nugget", "chance": 0.008}
	])

	var death_tween: Tween = create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	death_tween.tween_property(sprite, "scale", Vector2(0.2, 0.08), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	death_tween.set_parallel(false)
	death_tween.tween_callback(queue_free)
