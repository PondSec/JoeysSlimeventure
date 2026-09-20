extends CharacterBody2D

const LootDropper := preload("res://Scripts/loot_dropper.gd")
const SONIC_WAVE_SCENE := preload("res://Scenes/Projectiles/bat_ultrasound_wave.tscn")

signal defeated

const CONTACT_COOLDOWN := 0.85
const EVADE_CHANCE_PER_COMMITTED_ATTACK := 0.22
const EVADE_COOLDOWN_MIN := 1.65
const EVADE_COOLDOWN_MAX := 2.35
const EVADE_WINDUP_DURATION := 0.055
const EVADE_DASH_DURATION := 0.165
const EVADE_DASH_SPEED := 410.0
const WORLD_COLLISION_MASK := 2
const FLIGHT_PROBE_DISTANCE := 54.0
const FLIGHT_DETOUR_DISTANCE := 118.0
const FLIGHT_DETOUR_TIME := 0.52

enum State { PATROL, ORBIT, TELEGRAPH, SWOOP, SONIC_TELEGRAPH, SONIC_FIRE, EVADE, RECOVER, DEAD }

@export var max_health: int = 26
@export var hover_speed: float = 105.0
@export var chase_speed: float = 155.0
@export var swoop_speed: float = 280.0
@export var detection_range: float = 360.0
@export var swoop_trigger_range: float = 115.0
@export var sonic_min_range: float = 136.0
@export var sonic_max_range: float = 290.0
@export var contact_damage: int = 10

var current_health: int = 26
var player: Node2D
var home_position: Vector2 = Vector2.ZERO
var anim_timer: float = 0.0
var attack_cooldown: float = 0.7
var contact_cooldown: float = 0.0
var swoop_timer: float = 0.0
var swoop_direction: Vector2 = Vector2.ZERO
var local_time: float = 0.0
var is_dead: bool = false
var state: State = State.PATROL
var state_time := 0.0
var orbit_side := 1.0
var sonic_direction := Vector2.ZERO
var last_attack_was_sonic := false
var evade_cooldown := 0.0
var evade_direction := Vector2.ZERO
# Exposed for the player hit resolver.  Only the actual dash is invulnerable;
# the short read before it is deliberately hittable.
var is_dodging := false
var detour_target := Vector2.ZERO
var detour_time_left := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	current_health = max_health
	home_position = global_position
	orbit_side = -1.0 if randf() < 0.5 else 1.0
	# Same species should not enter their first attack frame in lockstep.
	attack_cooldown = randf_range(0.35, 1.25)
	player = get_tree().get_first_node_in_group("players") as Node2D
	add_to_group("enemies")
	add_to_group("cave_bats")
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
	evade_cooldown = maxf(evade_cooldown - delta, 0.0)
	state_time += delta

	match state:
		State.PATROL:
			_process_patrol(delta)
		State.ORBIT:
			_process_orbit(delta)
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.SWOOP:
			_process_swoop()
		State.SONIC_TELEGRAPH:
			_process_sonic_telegraph(delta)
		State.SONIC_FIRE:
			_process_sonic_fire()
		State.EVADE:
			_process_evade(delta)
		State.RECOVER:
			_process_recover(delta)

	move_and_slide()
	_note_flight_collision()
	sprite.flip_h = velocity.x < 0.0
	if state == State.SONIC_TELEGRAPH:
		sprite.modulate = Color(0.66, 0.86, 1.0, 1.0)
	else:
		sprite.modulate = Color.WHITE
	sprite.frame = int(fposmod(floor(anim_timer * 12.0), 4.0))


func take_damage(amount: int, direction: Vector2, _is_crit: bool = false) -> void:
	if is_dead or current_health <= 0:
		return

	current_health -= amount
	# Player combat owns the exact feedback order: white silhouette + hitstop,
	# then knockback.  Do not add a second flash or movement before that pause.
	if current_health <= 0:
		call_deferred("_die")


func _process_patrol(delta: float) -> void:
	if _can_notice_player():
		_enter_state(State.ORBIT)
		return
	var idle_target := home_position + Vector2(sin(local_time * 1.8) * 54.0, cos(local_time * 2.6) * 18.0)
	_seek_towards(idle_target, hover_speed, delta)


func _process_orbit(delta: float) -> void:
	if not _can_notice_player(82.0):
		_enter_state(State.PATROL)
		return
	var predicted := player.global_position + _player_velocity() * 0.22
	var target := predicted + Vector2(orbit_side * 68.0, -48.0 + sin(local_time * 5.0) * 16.0)
	_seek_towards(target, chase_speed, delta)
	if _try_evade_committed_player_attack():
		return
	if attack_cooldown <= 0.0:
		var player_distance := global_position.distance_to(player.global_position)
		if player_distance <= swoop_trigger_range and not last_attack_was_sonic:
			_enter_state(State.TELEGRAPH)
		elif player_distance >= sonic_min_range and player_distance <= sonic_max_range and _has_clear_sonic_window():
			_enter_state(State.SONIC_TELEGRAPH)


func _process_telegraph(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, chase_speed * 3.6 * delta)
	if player != null and is_instance_valid(player):
		var target := player.global_position + _player_velocity() * 0.18
		swoop_direction = (target - global_position).normalized()
	if state_time >= 0.26:
		if swoop_direction == Vector2.ZERO:
			swoop_direction = Vector2.RIGHT
		_enter_state(State.SWOOP)


func _process_swoop() -> void:
	velocity = swoop_direction * swoop_speed
	if state_time >= 0.34 or is_on_wall():
		attack_cooldown = 1.18
		last_attack_was_sonic = false
		_enter_state(State.RECOVER)


func _process_sonic_telegraph(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, chase_speed * 4.2 * delta)
	if state_time >= 0.42:
		_enter_state(State.SONIC_FIRE)


func _process_sonic_fire() -> void:
	_spawn_sonic_wave()
	attack_cooldown = randf_range(2.15, 3.15)
	last_attack_was_sonic = true
	_enter_state(State.RECOVER)


func _spawn_sonic_wave() -> void:
	var wave := SONIC_WAVE_SCENE.instantiate() as Area2D
	if wave == null:
		return
	var launch_direction := sonic_direction if sonic_direction.length_squared() > 0.001 else Vector2.RIGHT
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	host.add_child(wave)
	wave.call("configure", global_position + launch_direction * 22.0, launch_direction, 250.0, 13)


func _process_evade(delta: float) -> void:
	if state_time < EVADE_WINDUP_DURATION:
		# A tiny readable gather. Hits during this part still land, so this is not
		# a perfect reaction to a sword swing.
		is_dodging = false
		velocity = velocity.move_toward(Vector2.ZERO, chase_speed * 5.0 * delta)
		return
	is_dodging = true
	velocity = evade_direction * EVADE_DASH_SPEED
	if state_time >= EVADE_WINDUP_DURATION + EVADE_DASH_DURATION:
		is_dodging = false
		attack_cooldown = 0.78
		_enter_state(State.RECOVER)


func _process_recover(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, chase_speed * 2.4 * delta)
	if state_time >= 0.34:
		orbit_side *= -1.0
		_enter_state(State.ORBIT if _can_notice_player() else State.PATROL)


func _enter_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_time = 0.0
	if next_state != State.EVADE:
		is_dodging = false
	if next_state == State.EVADE:
		var away := global_position - (player.global_position if player and is_instance_valid(player) else home_position)
		if away.length_squared() < 0.01:
			away = Vector2.UP
		# Mostly backwards, with a small per-bat lateral variance so packs do not
		# all retreat along the exact same line.
		evade_direction = (away.normalized() + Vector2(-away.y, away.x).normalized() * randf_range(-0.22, 0.22)).normalized()
	if next_state == State.SONIC_TELEGRAPH:
		# Aim once as the blue telegraph starts.  The player can now read the
		# lane and dodge; the launched wave never re-aims or homes.
		if player != null and is_instance_valid(player):
			sonic_direction = (player.global_position + _player_velocity() * 0.16 - global_position).normalized()
		else:
			sonic_direction = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT


func _try_evade_committed_player_attack() -> bool:
	if evade_cooldown > 0.0 or player == null or not is_instance_valid(player):
		return false
	var player_attacking: Variant = player.get("is_attacking")
	if not (player_attacking is bool and player_attacking):
		return false
	if global_position.distance_to(player.global_position) > 112.0:
		return false
	# Consume the attempt whether it succeeds or not. This converts a long
	# swing into one readable chance rather than rerolling every physics frame.
	evade_cooldown = randf_range(EVADE_COOLDOWN_MIN, EVADE_COOLDOWN_MAX)
	if randf() > EVADE_CHANCE_PER_COMMITTED_ATTACK:
		return false
	_enter_state(State.EVADE)
	return true


func _has_clear_sonic_window() -> bool:
	# Nearby bats share a lightweight firing lane.  It avoids identical enemies
	# stacking their telegraphs and makes each projectile readable on its own.
	for other in get_tree().get_nodes_in_group("cave_bats"):
		if other == self or not is_instance_valid(other):
			continue
		var other_state: Variant = other.get("state")
		if other_state in [State.SONIC_TELEGRAPH, State.SONIC_FIRE] and global_position.distance_to((other as Node2D).global_position) < 420.0:
			return false
	return true


func _can_notice_player(extra_range: float = 0.0) -> bool:
	return player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) <= detection_range + extra_range


func _player_velocity() -> Vector2:
	if player != null and is_instance_valid(player):
		var player_velocity: Variant = player.get("velocity")
		if player_velocity is Vector2:
			return player_velocity as Vector2
	return Vector2.ZERO


func _seek_towards(target: Vector2, speed: float, delta: float) -> void:
	detour_time_left = maxf(detour_time_left - delta, 0.0)
	var steering_target := target
	if detour_time_left > 0.0 and detour_target.distance_to(global_position) > 18.0:
		steering_target = detour_target
	var to_target: Vector2 = steering_target - global_position
	var desired: Vector2 = Vector2.ZERO
	if to_target.length() > 1.0:
		var desired_speed: float = minf(speed, to_target.length() * 4.0)
		desired = _steer_around_world(to_target.normalized(), target) * desired_speed
	velocity = velocity.lerp(desired, delta * 4.6)


func _steer_around_world(desired_direction: Vector2, final_target: Vector2) -> Vector2:
	if get_world_2d() == null or desired_direction.length_squared() <= 0.001:
		return desired_direction
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + desired_direction * FLIGHT_PROBE_DISTANCE)
	query.collision_mask = WORLD_COLLISION_MASK
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_direction
	var normal: Vector2 = hit.get("normal", Vector2.UP) as Vector2
	var tangent := Vector2(-normal.y, normal.x).normalized()
	var target_direction := (final_target - global_position).normalized()
	# Prefer the side that still makes progress towards the goal.  When the goal
	# is exactly above/below a ledge, each bat keeps its own orbit side so a pack
	# naturally splits around the obstacle instead of piling up underneath it.
	if absf(tangent.dot(target_direction)) < 0.12:
		tangent *= orbit_side
	elif tangent.dot(target_direction) < 0.0:
		tangent = -tangent
	var detour := (tangent * 0.92 + normal * 0.38).normalized()
	detour_target = global_position + detour * FLIGHT_DETOUR_DISTANCE
	detour_time_left = FLIGHT_DETOUR_TIME
	return detour


func _note_flight_collision() -> void:
	if get_slide_collision_count() <= 0:
		return
	var collision := get_slide_collision(0)
	if collision == null:
		return
	var normal := collision.get_normal()
	var tangent := Vector2(-normal.y, normal.x).normalized()
	if absf(tangent.dot(velocity.normalized())) < 0.15:
		tangent *= orbit_side
	elif tangent.dot(velocity) < 0.0:
		tangent = -tangent
	# Collision feedback wins over the direct goal for a short moment, which is
	# what prevents a flying enemy from pressing against one cave wall forever.
	detour_target = global_position + (tangent * 0.88 + normal * 0.42).normalized() * FLIGHT_DETOUR_DISTANCE
	detour_time_left = FLIGHT_DETOUR_TIME


func _on_hitbox_body_entered(body: Node2D) -> void:
	# Hovering is positioning; only the clearly telegraphed swoop can connect.
	if is_dead or contact_cooldown > 0.0 or state != State.SWOOP or state_time < 0.055:
		return
	if not body.is_in_group("players"):
		return
	contact_cooldown = CONTACT_COOLDOWN
	if body.has_method("take_damage"):
		body.call_deferred("take_damage", contact_damage, global_position)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	state = State.DEAD
	emit_signal("defeated")
	LootDropper.spawn_independent_drops(self, [
		{"item": "health_heart", "chance": 0.52},
		{"item": "bat_claw", "chance": 0.26},
		{"item": "copper_nugget", "chance": 0.42},
		{"item": "iron_nugget", "chance": 0.16},
		{"item": "gold_nugget", "chance": 0.012}
	])
	var death_tween: Tween = create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	death_tween.tween_property(sprite, "scale", Vector2(1.7, 0.45), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	death_tween.set_parallel(false)
	death_tween.tween_callback(queue_free)
