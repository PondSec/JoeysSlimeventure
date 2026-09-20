extends CharacterBody2D

const LootDropper := preload("res://Scripts/loot_dropper.gd")
const SONIC_WAVE_SCENE := preload("res://Scenes/Projectiles/bat_ultrasound_wave.tscn")

# ============================================================
# CORE TUNING
# ============================================================

const SPEED := 145.0
const FAST_SPEED := 220.0
const DETECTION_RADIUS := 300.0
const BASE_DETECTION_RADIUS := 150.0
const RESPAWN_COOLDOWN := 10.0
const NAVIGATION_UPDATE_INTERVAL := 0.18
const MAX_HEALTH := 60

# The bat is a skirmisher now: it wants space instead of face-tanking Joey.
const COMBAT_DISTANCE_MIN := 118.0
const COMBAT_DISTANCE_IDEAL := 158.0
const COMBAT_DISTANCE_MAX := 205.0
const ORBIT_VERTICAL_RATIO := 0.60
const ORBIT_SPEED := 0.42
const SEPARATION_RADIUS := 58.0
const SEPARATION_STRENGTH := 0.95

# Deterministic evade. No random 22% coin flip anymore.
const EVADE_TRIGGER_RANGE := 88.0
const EVADE_COOLDOWN := 2.40
const EVADE_DASH_SPEED := 430.0
const EVADE_DASH_DURATION := 0.17

# Sonic attack.
const SONIC_MIN_RANGE := 125.0
const SONIC_MAX_RANGE := 255.0
const SONIC_COOLDOWN := 3.40
const SONIC_TELEGRAPH_DURATION := 0.52
const SONIC_TRACK_TIME := 0.25
const SONIC_RECOVERY := 0.65
const SONIC_DAMAGE := 12
const SONIC_SPEED := 245.0

# Dive attack.
const DIVE_MIN_RANGE := 82.0
const DIVE_MAX_RANGE := 205.0
const DIVE_COOLDOWN := 4.20
const DIVE_TELEGRAPH_DURATION := 0.35
const DIVE_DASH_DURATION := 0.22
const DIVE_SPEED := 385.0
const DIVE_DAMAGE := 9
const DIVE_HIT_RANGE := 30.0
const DIVE_RECOVERY := 0.70
const DIVE_WALL_RECOVERY := 0.85

# Panic bite. Only used when Joey successfully gets on top of the bat and
# its evade is unavailable.
const BITE_TRIGGER_RANGE := 42.0
const BITE_HIT_RANGE := 48.0
const BITE_TELEGRAPH_DURATION := 0.22
const BITE_COOLDOWN := 1.15
const BITE_DAMAGE := 7
const BITE_RECOVERY := 0.48

# Stagger / punish system.
const STAGGER_MAX := 3.0
const STAGGER_DURATION := 0.75
const STAGGER_IMMUNITY_AFTER := 0.45
const RECOVERY_STAGGER_MULTIPLIER := 1.35

# Group coordination. Only one nearby bat may be in a committed attack at a
# time. Others keep moving and positioning, so groups create pressure without
# becoming projectile soup.
const GROUP_ATTACK_RADIUS := 360.0
const ATTACK_TOKEN_SAFETY_TIME := 1.50

# Patrol.
const PATROL_CHANCE := 0.90
const PATROL_DURATION := 20.0
const IDLE_DURATION := 0.10

# Legacy call-for-help support stays available, but normal bats default to off.
const CALL_COOLDOWN := 15.0
const CALL_RANGE := 200.0


# ============================================================
# RUNTIME STATE
# ============================================================

var original_speed := SPEED
@export var current_speed := SPEED
var current_slow_multiplier := 1.0
var slow_timer := 0.0
var is_slowed := false

var navigation_update_timer := 0.0
var is_dead := false
var bat_health := MAX_HEALTH
var is_attacking := false
var attack_timer := 0.0

var knockback_velocity := Vector2.ZERO
var is_knocked_back := false
var is_stunned := false
var is_dodging := false
var dodge_cooldown := 0.0
var dodge_direction := Vector2.ZERO

var bat_position := Vector2.ZERO
var player_last_seen_position := Vector2.ZERO
var time_since_last_seen := 0.0
var patrol_points: Array[Vector2] = []
var current_patrol_index := 0
var patrol_timer := 0.0
var idle_timer := 0.0
var current_state := "patrol"

var normal_hit_streak := 0
var streak_reset_time := 2.0
var streak_timer := 0.0

# Combat action state.
# normal / sonic_charge / dive_telegraph / dive_dash / bite_telegraph /
# recovery / evade / stagger
var combat_action := "normal"
var action_timer := 0.0
var action_elapsed := 0.0
var recovery_source := ""

var sonic_cooldown := 1.25
var sonic_charge := 0.0
var sonic_direction := Vector2.RIGHT

var dive_cooldown := 1.75
var dive_direction := Vector2.RIGHT
var dive_has_hit := false

var bite_cooldown := 0.0
var next_attack_preference := "sonic"

var stagger_meter := 0.0
var stagger_immunity_timer := 0.0

# Group attack token.
var has_attack_token := false
var attack_token_timer := 0.0
var last_committed_attack_msec := -1000000

# Legacy reinforcement support.
var call_timer := 0.0
var can_call_for_help := true
var was_called := false


# ============================================================
# SCENE REFERENCES
# ============================================================

@export var player: CharacterBody2D
@export var spawn_zone_container: Node2D
@export var want_call: bool = false

@onready var animation_player: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var hit_particles: CPUParticles2D = get_node_or_null("HitParticles") as CPUParticles2D
@onready var death_particles: CPUParticles2D = get_node_or_null("DeathParticles") as CPUParticles2D
@onready var sound_player: AudioStreamPlayer2D = _resolve_sound_player()
@onready var health_bar = $HealthBar
@onready var detection_area = $DetectionArea
@onready var alert_icon = $AlertIcon
@onready var sprite: Sprite2D = $Sprite2D
@onready var item = InvItem

var death_sound = preload("res://Assets/Sounds/Bat_death.ogg")
var hurt_sound = preload("res://Assets/Sounds/Bat_hurt2.ogg.mp3")
var dodge_sound = preload("res://Assets/Sounds/Bat_takeoff.ogg")


# ============================================================
# SETUP
# ============================================================

func _resolve_sound_player() -> AudioStreamPlayer2D:
	var existing_player := get_node_or_null("SoundPlayer") as AudioStreamPlayer2D
	if existing_player != null:
		return existing_player
	return get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D


func _ready() -> void:
	randomize()

	sonic_cooldown = randf_range(0.65, 1.35)
	dive_cooldown = randf_range(1.25, 2.10)

	add_to_group("enemies")
	add_to_group("bats")

	find_target()

	bat_position = get_random_spawn_position()
	health_bar.visible = false
	alert_icon.visible = false
	alert_icon.text = "!"
	generate_patrol_points()

	if not detection_area.body_entered.is_connected(_on_target_detected):
		detection_area.body_entered.connect(_on_target_detected)
	if not detection_area.body_exited.is_connected(_on_target_lost):
		detection_area.body_exited.connect(_on_target_lost)

	if sound_player == null:
		sound_player = AudioStreamPlayer2D.new()
		sound_player.name = "SoundPlayer"
		add_child(sound_player)
	else:
		sound_player.name = "SoundPlayer"

	original_speed = SPEED
	current_speed = SPEED


# ============================================================
# TARGETING
# ============================================================

func _on_target_detected(body: Node2D) -> void:
	if not body.is_in_group("players") and not body.is_in_group("minions"):
		return

	if player == null or not is_instance_valid(player):
		player = body as CharacterBody2D
	elif global_position.distance_to(body.global_position) < global_position.distance_to(player.global_position):
		player = body as CharacterBody2D

	if body == player:
		_show_alert("!", 1.0)


func _on_target_lost(body: Node2D) -> void:
	if body != player:
		return

	var new_target := find_nearest_target()
	if new_target != null:
		player = new_target as CharacterBody2D
		return

	_show_alert("?", 0.5)


func _show_alert(text: String, duration: float) -> void:
	alert_icon.text = text
	alert_icon.visible = true

	var alert_tween := create_tween()
	alert_tween.tween_property(alert_icon, "scale", Vector2(1.5, 1.5), 0.2)
	alert_tween.tween_property(alert_icon, "scale", Vector2.ONE, 0.1)

	await get_tree().create_timer(duration).timeout
	if is_instance_valid(alert_icon) and alert_icon.text == text:
		alert_icon.visible = false
		alert_icon.text = "!"


func find_nearest_target() -> Node2D:
	var players := get_tree().get_nodes_in_group("players")
	var minions := get_tree().get_nodes_in_group("minions")

	var nearest_target: Node2D = null
	var nearest_distance := INF

	# Players have priority over minions.
	for target in players:
		if target is Node2D and is_instance_valid(target):
			var distance := global_position.distance_to((target as Node2D).global_position)
			if distance < nearest_distance and distance <= DETECTION_RADIUS:
				nearest_distance = distance
				nearest_target = target as Node2D

	if nearest_target != null:
		return nearest_target

	nearest_distance = INF
	for target in minions:
		if target is Node2D and is_instance_valid(target):
			var distance := global_position.distance_to((target as Node2D).global_position)
			if distance < nearest_distance and distance <= DETECTION_RADIUS:
				nearest_distance = distance
				nearest_target = target as Node2D

	return nearest_target


func find_target() -> void:
	var target := find_nearest_target()
	player = target as CharacterBody2D


func _target_is_valid() -> bool:
	return player != null and is_instance_valid(player)


func _player_is_glowing() -> bool:
	if not _target_is_valid() or not player.is_in_group("players"):
		return false
	var glowing: Variant = player.get("is_glowing")
	return glowing is bool and glowing


func _get_detection_radius() -> float:
	return DETECTION_RADIUS if _player_is_glowing() else BASE_DETECTION_RADIUS


# ============================================================
# MAIN LOOP
# ============================================================

func _physics_process(delta: float) -> void:
	_update_common_timers(delta)
	_update_slow(delta)
	_update_hit_streak(delta)
	update_health_bar()
	update_stealth()

	if is_dead:
		return

	if not _target_is_valid():
		find_target()
		if not _target_is_valid():
			_handle_no_target(delta)
			move_and_slide()
			set_animation()
			return

	if is_knocked_back:
		handle_knockback(delta)
		move_and_slide()
		set_animation()
		return

	if _process_combat_action(delta):
		move_and_slide()
		_post_move_combat_checks()
		set_animation()
		return

	handle_state_machine(delta)
	move_and_slide()
	_post_move_combat_checks()
	set_animation()


func _update_common_timers(delta: float) -> void:
	sonic_cooldown = maxf(sonic_cooldown - delta, 0.0)
	dive_cooldown = maxf(dive_cooldown - delta, 0.0)
	bite_cooldown = maxf(bite_cooldown - delta, 0.0)
	dodge_cooldown = maxf(dodge_cooldown - delta, 0.0)
	stagger_immunity_timer = maxf(stagger_immunity_timer - delta, 0.0)

	if has_attack_token:
		attack_token_timer -= delta
		if attack_token_timer <= 0.0:
			_release_attack_token()

	if not can_call_for_help:
		call_timer -= delta
		if call_timer <= 0.0:
			can_call_for_help = true


func _update_slow(delta: float) -> void:
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			_reset_speed()

	current_speed = original_speed * current_slow_multiplier if is_slowed else original_speed


func _update_hit_streak(delta: float) -> void:
	if normal_hit_streak <= 0:
		return

	streak_timer += delta
	if streak_timer >= streak_reset_time:
		normal_hit_streak = 0
		streak_timer = 0.0


func _handle_no_target(delta: float) -> void:
	if current_state == "idle":
		handle_idle_state(delta)
	else:
		if current_state != "patrol":
			current_state = "patrol"
			patrol_timer = PATROL_DURATION
		handle_patrol_state(delta)


# ============================================================
# COMBAT ACTION STATE MACHINE
# ============================================================

func _process_combat_action(delta: float) -> bool:
	match combat_action:
		"sonic_charge":
			_process_sonic_charge(delta)
			return true

		"dive_telegraph":
			_process_dive_telegraph(delta)
			return true

		"dive_dash":
			_process_dive_dash(delta)
			return true

		"bite_telegraph":
			_process_bite_telegraph(delta)
			return true

		"recovery":
			_process_recovery(delta)
			return true

		"evade":
			_process_evade(delta)
			return true

		"stagger":
			_process_stagger(delta)
			return true

	return false


func _reset_action_visuals() -> void:
	sprite.self_modulate = Color.WHITE


func _enter_recovery(duration: float, source: String) -> void:
	combat_action = "recovery"
	action_timer = duration
	action_elapsed = 0.0
	recovery_source = source
	is_attacking = false
	sonic_charge = 0.0
	_reset_action_visuals()


func _process_recovery(delta: float) -> void:
	action_timer -= delta

	# The bat is vulnerable here. It only drifts away gently, so the player can
	# actually cash in the punish window they earned.
	if _target_is_valid():
		var away := (global_position - player.global_position).normalized()
		if away.length_squared() < 0.001:
			away = Vector2.UP
		var recovery_speed := current_speed * 0.22
		velocity = velocity.lerp(away * recovery_speed, clampf(delta * 5.0, 0.0, 1.0))
	else:
		velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 5.0, 0.0, 1.0))

	if action_timer <= 0.0:
		combat_action = "normal"
		recovery_source = ""
		velocity *= 0.75


func _enter_stagger(duration: float = STAGGER_DURATION) -> void:
	_release_attack_token()

	combat_action = "stagger"
	action_timer = maxf(duration, 0.05)
	action_elapsed = 0.0
	is_stunned = true
	is_dodging = false
	is_attacking = false
	sonic_charge = 0.0
	stagger_meter = 0.0
	velocity *= 0.18
	_reset_action_visuals()


func _process_stagger(delta: float) -> void:
	action_timer -= delta
	velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 10.0, 0.0, 1.0))

	if action_timer <= 0.0:
		is_stunned = false
		combat_action = "normal"
		stagger_immunity_timer = STAGGER_IMMUNITY_AFTER
		dodge_cooldown = maxf(dodge_cooldown, 0.35)


# ============================================================
# SONIC ATTACK
# ============================================================

func _can_start_sonic(distance: float) -> bool:
	return (
		sonic_cooldown <= 0.0
		and distance >= SONIC_MIN_RANGE
		and distance <= SONIC_MAX_RANGE
	)


func _start_sonic() -> void:
	combat_action = "sonic_charge"
	action_timer = SONIC_TELEGRAPH_DURATION
	action_elapsed = 0.0
	sonic_charge = SONIC_TELEGRAPH_DURATION
	is_attacking = true
	velocity *= 0.35

	if _target_is_valid():
		sonic_direction = (player.global_position - global_position).normalized()
	else:
		sonic_direction = Vector2.RIGHT


func _process_sonic_charge(delta: float) -> void:
	action_timer -= delta
	action_elapsed += delta
	sonic_charge = maxf(action_timer, 0.0)

	velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))

	# Track during the early tell, then hard-lock so the player can dodge on read.
	if action_elapsed <= SONIC_TRACK_TIME and _target_is_valid():
		var to_target := player.global_position - global_position
		if to_target.length_squared() > 0.001:
			sonic_direction = to_target.normalized()

	var charge_ratio := clampf(action_elapsed / SONIC_TELEGRAPH_DURATION, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(action_elapsed * 62.0)
	sprite.self_modulate = Color(
		lerpf(0.82, 0.64, charge_ratio),
		lerpf(0.92, 0.82, charge_ratio),
		1.0,
		1.0
	) * lerpf(0.95, 1.08, pulse * charge_ratio)

	if action_timer > 0.0:
		return

	_spawn_sonic_wave()
	sonic_cooldown = SONIC_COOLDOWN
	next_attack_preference = "dive"
	_release_attack_token()
	_enter_recovery(SONIC_RECOVERY, "sonic")


func _spawn_sonic_wave() -> void:
	var wave := SONIC_WAVE_SCENE.instantiate() as Area2D
	if wave == null:
		return

	var launch_direction := sonic_direction
	if launch_direction.length_squared() <= 0.001:
		launch_direction = Vector2.RIGHT
	launch_direction = launch_direction.normalized()

	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	if host == null:
		return

	host.add_child(wave)

	# One bat may create richer ricochets. Groups deliberately reduce battlefield
	# clutter so 3-4 bats stay demanding instead of unreadable.
	if wave.get("max_wall_bounces") != null:
		wave.set("max_wall_bounces", _sonic_bounce_limit_for_group())

	wave.call(
		"configure",
		global_position + launch_direction * 22.0,
		launch_direction,
		SONIC_SPEED,
		SONIC_DAMAGE
	)


func _sonic_bounce_limit_for_group() -> int:
	return 2 if _nearby_group_count() <= 1 else 1


# ============================================================
# DIVE ATTACK
# ============================================================

func _can_start_dive(distance: float) -> bool:
	return (
		dive_cooldown <= 0.0
		and distance >= DIVE_MIN_RANGE
		and distance <= DIVE_MAX_RANGE
	)


func _start_dive() -> void:
	combat_action = "dive_telegraph"
	action_timer = DIVE_TELEGRAPH_DURATION
	action_elapsed = 0.0
	is_attacking = true
	dive_has_hit = false
	velocity *= 0.28

	if _target_is_valid():
		dive_direction = (player.global_position - global_position).normalized()
	else:
		dive_direction = Vector2.RIGHT


func _process_dive_telegraph(delta: float) -> void:
	action_timer -= delta
	action_elapsed += delta
	velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 11.0, 0.0, 1.0))

	if _target_is_valid():
		var to_target := player.global_position - global_position
		if to_target.length_squared() > 0.001:
			dive_direction = to_target.normalized()

	var ratio := clampf(action_elapsed / DIVE_TELEGRAPH_DURATION, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(action_elapsed * 48.0)
	sprite.self_modulate = Color(
		1.0,
		lerpf(0.92, 0.67, ratio),
		lerpf(0.92, 0.64, ratio),
		1.0
	) * lerpf(0.96, 1.08, pulse * ratio)

	if action_timer > 0.0:
		return

	combat_action = "dive_dash"
	action_timer = DIVE_DASH_DURATION
	action_elapsed = 0.0
	velocity = dive_direction * DIVE_SPEED
	dive_has_hit = false
	_reset_action_visuals()


func _process_dive_dash(delta: float) -> void:
	action_timer -= delta
	action_elapsed += delta
	velocity = dive_direction * DIVE_SPEED

	if not dive_has_hit and _target_is_valid():
		if global_position.distance_to(player.global_position) <= DIVE_HIT_RANGE:
			_damage_target(DIVE_DAMAGE)
			dive_has_hit = true

	if action_timer > 0.0:
		return

	_finish_dive(false)


func _finish_dive(hit_wall: bool) -> void:
	dive_cooldown = DIVE_COOLDOWN
	next_attack_preference = "sonic"
	_release_attack_token()
	_enter_recovery(DIVE_WALL_RECOVERY if hit_wall else DIVE_RECOVERY, "dive")


# ============================================================
# PANIC BITE
# ============================================================

func _can_start_bite(distance: float) -> bool:
	return (
		bite_cooldown <= 0.0
		and distance <= BITE_TRIGGER_RANGE
		and dodge_cooldown > 0.0
	)


func _start_bite() -> void:
	combat_action = "bite_telegraph"
	action_timer = BITE_TELEGRAPH_DURATION
	action_elapsed = 0.0
	is_attacking = true
	velocity *= 0.20
	sprite.self_modulate = Color(1.0, 0.82, 0.78, 1.0)


func _process_bite_telegraph(delta: float) -> void:
	action_timer -= delta
	action_elapsed += delta
	velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 12.0, 0.0, 1.0))

	if action_timer > 0.0:
		return

	if _target_is_valid() and global_position.distance_to(player.global_position) <= BITE_HIT_RANGE:
		_damage_target(BITE_DAMAGE)

	bite_cooldown = BITE_COOLDOWN
	_release_attack_token()
	_enter_recovery(BITE_RECOVERY, "bite")


# ============================================================
# EVADE
# ============================================================

func _try_dodge_committed_player_attack(distance: float) -> bool:
	if combat_action != "normal":
		return false
	if dodge_cooldown > 0.0 or distance > EVADE_TRIGGER_RANGE:
		return false
	if not _target_is_valid():
		return false

	var player_attacking: Variant = player.get("is_attacking")
	if not (player_attacking is bool and player_attacking):
		return false

	dodge()
	return true


func dodge() -> void:
	if is_dead or is_dodging or dodge_cooldown > 0.0 or combat_action != "normal":
		return

	combat_action = "evade"
	action_timer = EVADE_DASH_DURATION
	action_elapsed = 0.0
	is_dodging = true
	is_attacking = false
	dodge_cooldown = EVADE_COOLDOWN

	if sound_player != null and dodge_sound != null:
		sound_player.stream = dodge_sound
		sound_player.pitch_scale = randf_range(0.96, 1.06)
		sound_player.play()

	var away := Vector2.UP
	if _target_is_valid():
		away = global_position - player.global_position
	if away.length_squared() < 0.001:
		away = Vector2.UP
	away = away.normalized()

	# Deterministic little sideways bias based on instance id. No RNG outcome;
	# just enough shape so every evade is not a perfectly straight retreat.
	var side := Vector2(-away.y, away.x)
	var side_sign := 1.0 if (get_instance_id() % 2) == 0 else -1.0
	dodge_direction = (away + side * 0.18 * side_sign).normalized()
	velocity = dodge_direction * EVADE_DASH_SPEED


func _process_evade(delta: float) -> void:
	action_timer -= delta
	velocity = dodge_direction * EVADE_DASH_SPEED

	if action_timer <= 0.0:
		is_dodging = false
		combat_action = "normal"
		velocity *= 0.55


# ============================================================
# GROUP ATTACK COORDINATION
# ============================================================

func _nearby_group_count() -> int:
	if not _target_is_valid():
		return 1

	var count := 1
	for bat in get_tree().get_nodes_in_group("bats"):
		if bat == self or not _is_same_combat_group(bat):
			continue
		count += 1
	return count


func _is_same_combat_group(bat: Node) -> bool:
	if bat == null or not is_instance_valid(bat) or not (bat is Node2D):
		return false

	var other_dead: Variant = bat.get("is_dead")
	if other_dead is bool and other_dead:
		return false

	var other_target: Variant = bat.get("player")
	if other_target != player:
		return false

	if not _target_is_valid():
		return false

	return (bat as Node2D).global_position.distance_to(player.global_position) <= GROUP_ATTACK_RADIUS


func _required_group_attack_gap(group_count: int) -> float:
	if group_count <= 1:
		return 0.0
	if group_count == 2:
		return 1.20
	if group_count == 3:
		return 0.98
	return 0.82


func _try_acquire_attack_token(expected_duration: float) -> bool:
	if has_attack_token:
		attack_token_timer = maxf(attack_token_timer, expected_duration)
		return true

	if not _target_is_valid():
		return false

	var now_msec := Time.get_ticks_msec()
	var group_count := 1
	var latest_commit_msec := last_committed_attack_msec

	for bat in get_tree().get_nodes_in_group("bats"):
		if bat == self or not _is_same_combat_group(bat):
			continue

		group_count += 1

		var other_has_token: Variant = bat.get("has_attack_token")
		if other_has_token is bool and other_has_token:
			return false

		var other_commit: Variant = bat.get("last_committed_attack_msec")
		if other_commit is int:
			latest_commit_msec = maxi(latest_commit_msec, int(other_commit))

	var required_gap := _required_group_attack_gap(group_count)
	if required_gap > 0.0:
		var elapsed_since_group_attack := float(now_msec - latest_commit_msec) / 1000.0
		if elapsed_since_group_attack < required_gap:
			return false

	has_attack_token = true
	attack_token_timer = maxf(expected_duration, ATTACK_TOKEN_SAFETY_TIME)
	last_committed_attack_msec = now_msec
	return true


func _release_attack_token() -> void:
	has_attack_token = false
	attack_token_timer = 0.0


func _try_start_combat_attack(distance: float) -> bool:
	if combat_action != "normal" or is_stunned or is_dodging or is_knocked_back:
		return false

	var chosen := ""

	if next_attack_preference == "sonic":
		if _can_start_sonic(distance):
			chosen = "sonic"
		elif _can_start_dive(distance):
			chosen = "dive"
	else:
		if _can_start_dive(distance):
			chosen = "dive"
		elif _can_start_sonic(distance):
			chosen = "sonic"

	if chosen.is_empty() and _can_start_bite(distance):
		chosen = "bite"

	if chosen.is_empty():
		return false

	var token_duration := 0.5
	match chosen:
		"sonic":
			token_duration = SONIC_TELEGRAPH_DURATION + 0.25
		"dive":
			token_duration = DIVE_TELEGRAPH_DURATION + DIVE_DASH_DURATION + 0.25
		"bite":
			token_duration = BITE_TELEGRAPH_DURATION + 0.25

	if not _try_acquire_attack_token(token_duration):
		return false

	match chosen:
		"sonic":
			_start_sonic()
		"dive":
			_start_dive()
		"bite":
			_start_bite()

	return true


# ============================================================
# CHASE / POSITIONING
# ============================================================

func handle_state_machine(delta: float) -> void:
	if not _target_is_valid():
		return

	var distance_to_player := global_position.distance_to(player.global_position)
	var actual_detection_radius := _get_detection_radius()

	if distance_to_player <= actual_detection_radius:
		current_state = "chase"
		player_last_seen_position = player.global_position
		time_since_last_seen = 0.0
	elif current_state == "chase":
		time_since_last_seen += delta
		if time_since_last_seen > 2.0:
			decide_next_state()

	match current_state:
		"chase":
			if distance_to_player <= actual_detection_radius * 1.20:
				handle_chase(delta, distance_to_player)
			else:
				velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 5.0, 0.0, 1.0))
				decide_next_state()
		"patrol":
			handle_patrol_state(delta)
		"idle":
			handle_idle_state(delta)


func handle_chase(delta: float, distance: float) -> void:
	if not _target_is_valid():
		find_target()
		return

	if _try_dodge_committed_player_attack(distance):
		return

	if _try_start_combat_attack(distance):
		return

	# If Joey gets too close while the evade is cooling down, retreat hard.
	if distance < COMBAT_DISTANCE_MIN:
		var away := global_position - player.global_position
		if away.length_squared() < 0.001:
			away = Vector2.UP
		away = away.normalized()

		var separation := _get_bat_separation_vector()
		var retreat_velocity := away * current_speed * 1.12 + separation * current_speed * 0.55
		velocity = velocity.lerp(retreat_velocity.limit_length(current_speed * 1.18), clampf(delta * 9.0, 0.0, 1.0))
		return

	# If Joey is far away, close the gap until the skirmish band is reached.
	if distance > COMBAT_DISTANCE_MAX:
		_move_toward_combat_point(player.global_position, current_speed, delta)
		return

	# Inside the preferred band the bat orbits instead of flying directly into
	# melee range. Group members automatically occupy different orbit slots.
	var orbit_target := _calculate_orbit_target()
	_move_toward_combat_point(orbit_target, current_speed * 0.78, delta)


func _calculate_orbit_target() -> Vector2:
	if not _target_is_valid():
		return global_position

	var group_count := 1
	var group_index := 0
	var my_id := get_instance_id()

	for bat in get_tree().get_nodes_in_group("bats"):
		if bat == self or not _is_same_combat_group(bat):
			continue

		group_count += 1
		if bat.get_instance_id() < my_id:
			group_index += 1

	var time_seconds := float(Time.get_ticks_msec()) / 1000.0
	var group_direction := 1.0 if (player.get_instance_id() % 2) == 0 else -1.0
	var phase := time_seconds * ORBIT_SPEED * group_direction
	var slot_angle := phase + TAU * float(group_index) / float(group_count)

	var offset := Vector2(
		cos(slot_angle) * COMBAT_DISTANCE_IDEAL,
		sin(slot_angle) * COMBAT_DISTANCE_IDEAL * ORBIT_VERTICAL_RATIO
	)

	return player.global_position + offset


func _get_bat_separation_vector() -> Vector2:
	var separation := Vector2.ZERO

	for bat in get_tree().get_nodes_in_group("bats"):
		if bat == self or not (bat is Node2D) or not is_instance_valid(bat):
			continue

		var offset := global_position - (bat as Node2D).global_position
		var distance := offset.length()
		if distance <= 0.001 or distance >= SEPARATION_RADIUS:
			continue

		var weight := 1.0 - distance / SEPARATION_RADIUS
		separation += offset.normalized() * weight

	return separation * SEPARATION_STRENGTH


func _move_toward_combat_point(target_position: Vector2, desired_speed: float, delta: float) -> void:
	navigation_update_timer -= delta
	if navigation_update_timer <= 0.0:
		navigation_agent.target_position = target_position
		navigation_update_timer = NAVIGATION_UPDATE_INTERVAL

	var next_path_pos := navigation_agent.get_next_path_position()
	var move_direction := next_path_pos - global_position

	# Fallback for cases where the navigation agent has no useful next point.
	if move_direction.length_squared() < 0.001:
		move_direction = target_position - global_position

	if move_direction.length_squared() > 0.001:
		move_direction = move_direction.normalized()

	var separation := _get_bat_separation_vector()
	var target_velocity := move_direction * desired_speed + separation * current_speed * 0.40
	target_velocity = target_velocity.limit_length(maxf(desired_speed, current_speed * 0.85) * 1.12)

	velocity = velocity.lerp(target_velocity, clampf(delta * 7.5, 0.0, 1.0))


# ============================================================
# PATROL / IDLE
# ============================================================

func decide_next_state() -> void:
	if randf() < PATROL_CHANCE:
		current_state = "patrol"
		patrol_timer = randf_range(PATROL_DURATION * 0.7, PATROL_DURATION * 1.3)
		generate_patrol_points()
		current_patrol_index = 0

		if randf() < 0.4:
			current_state = "idle"
			idle_timer = randf_range(0.5, 1.5)
	else:
		current_state = "idle"
		idle_timer = randf_range(IDLE_DURATION * 0.5, IDLE_DURATION * 2.0)


func handle_patrol_state(delta: float) -> void:
	patrol_timer -= delta
	if patrol_timer <= 0.0:
		decide_next_state()
		return

	if patrol_points.is_empty():
		generate_patrol_points()
		if patrol_points.is_empty():
			velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 3.0, 0.0, 1.0))
			return

	current_patrol_index = clampi(current_patrol_index, 0, patrol_points.size() - 1)
	var target_point := patrol_points[current_patrol_index]
	var distance_to_target := global_position.distance_to(target_point)

	if distance_to_target < 15.0:
		if randf() < 0.3 and idle_timer <= 0.0:
			idle_timer = randf_range(0.3, 1.0)
			velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 4.0, 0.0, 1.0))
			return

		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		target_point = patrol_points[current_patrol_index]

	var speed_variation := current_speed * randf_range(0.78, 1.08) * 0.60
	navigation_agent.target_position = target_point
	var next_path_pos := navigation_agent.get_next_path_position()
	var move_direction := next_path_pos - global_position
	if move_direction.length_squared() < 0.001:
		move_direction = target_point - global_position
	if move_direction.length_squared() > 0.001:
		move_direction = move_direction.normalized()

	var target_velocity := move_direction * speed_variation
	velocity = velocity.lerp(target_velocity, clampf(delta * 5.0, 0.0, 1.0))


func handle_idle_state(delta: float) -> void:
	idle_timer -= delta
	velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 3.0, 0.0, 1.0))

	if idle_timer <= 0.0:
		decide_next_state()


func handle_patrol(delta: float) -> void:
	handle_patrol_state(delta)


func generate_patrol_points() -> void:
	patrol_points.clear()

	var center := global_position
	var radius := randf_range(80.0, 180.0)
	var point_count := randi_range(3, 5)

	for i in range(point_count):
		var angle := (TAU / float(point_count)) * float(i) + randf_range(-0.3, 0.3)
		var point_radius := radius * randf_range(0.8, 1.2)
		var point := center + Vector2(cos(angle), sin(angle)) * point_radius

		if not patrol_points.is_empty():
			var attempts := 0
			while point.distance_to(patrol_points[-1]) < 50.0 and attempts < 12:
				angle += 0.2
				point = center + Vector2(cos(angle), sin(angle)) * point_radius
				attempts += 1

		patrol_points.append(point)

	if randf() < 0.3:
		patrol_points.append(
			center + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(50.0, 120.0)
		)


# ============================================================
# LEGACY ATTACK API COMPATIBILITY
# ============================================================

func handle_movement(delta: float) -> void:
	if not _target_is_valid():
		return
	handle_chase(delta, global_position.distance_to(player.global_position))


func handle_attack(_delta: float) -> void:
	if can_attack():
		attack()


func can_attack() -> bool:
	return (
		_target_is_valid()
		and not is_dead
		and not is_stunned
		and not is_dodging
		and combat_action == "normal"
		and global_position.distance_to(player.global_position) <= BITE_TRIGGER_RANGE
	)


func attack() -> void:
	if not can_attack():
		return

	var distance := global_position.distance_to(player.global_position)
	if not _can_start_bite(distance):
		return
	if not _try_acquire_attack_token(BITE_TELEGRAPH_DURATION + 0.25):
		return
	_start_bite()


# ============================================================
# DAMAGE / STAGGER / KNOCKBACK
# ============================================================

func take_damage(amount: int, _direction: Vector2, is_crit: bool = false) -> void:
	if is_dead or bat_health <= 0:
		return

	# Evade has a short, readable invulnerability window. Unlike the old version,
	# whether the evade happens is deterministic; only the player's timing matters.
	if combat_action == "evade" or is_dodging:
		return

	var final_damage := amount
	if is_crit:
		final_damage = ceili(float(amount) * 1.5)

	# No hidden close-range damage resistance anymore. If Joey gets the opening,
	# the displayed damage is the damage that actually happens.
	bat_health -= final_damage
	show_damage_number(final_damage, is_crit)

	if sound_player != null and hurt_sound != null:
		sound_player.stream = hurt_sound
		sound_player.pitch_scale = randf_range(0.9, 1.1)
		sound_player.play()

	# Committed telegraphs can be interrupted. This is the aggressive answer to
	# Sonic/Dive/Bite and creates a real risk/reward decision for the player.
	if combat_action == "sonic_charge" or combat_action == "dive_telegraph" or combat_action == "bite_telegraph":
		if bat_health <= 0:
			call_deferred("die")
			return

		# An interrupt is rewarding, but the same move must not restart immediately
		# after the stagger ends. Give the interrupted attack a partial cooldown.
		if combat_action == "sonic_charge":
			sonic_cooldown = maxf(sonic_cooldown, 1.45)
		elif combat_action == "dive_telegraph":
			dive_cooldown = maxf(dive_cooldown, 1.65)
		else:
			bite_cooldown = maxf(bite_cooldown, 0.80)

		_enter_stagger(STAGGER_DURATION)
		_show_health_temporarily()
		return

	if bat_health <= 0:
		call_deferred("die")
		return

	if stagger_immunity_timer <= 0.0 and combat_action != "stagger":
		var stagger_gain := 1.5 if is_crit else 1.0
		if combat_action == "recovery":
			stagger_gain *= RECOVERY_STAGGER_MULTIPLIER
		stagger_meter += stagger_gain

		if stagger_meter >= STAGGER_MAX:
			_enter_stagger(STAGGER_DURATION)

	_show_health_temporarily()


func _show_health_temporarily() -> void:
	health_bar.visible = true
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(health_bar):
			health_bar.visible = false
	)


func _damage_target(amount: int) -> void:
	if not _target_is_valid() or not player.has_method("take_damage"):
		return

	if player.is_in_group("players"):
		player.call("take_damage", amount, global_position)
	else:
		player.call("take_damage", amount)


func handle_knockback(delta: float) -> void:
	velocity = knockback_velocity
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, clampf(delta * 5.0, 0.0, 1.0))

	if knockback_velocity.length() < 10.0:
		is_knocked_back = false
		_enter_stagger(0.50)


func apply_knockback() -> void:
	if not _target_is_valid() or is_dead:
		return

	_release_attack_token()
	combat_action = "normal"
	is_attacking = false
	sonic_charge = 0.0

	var knock_direction := global_position - player.global_position
	if knock_direction.length_squared() < 0.001:
		knock_direction = Vector2.UP
	knock_direction = knock_direction.normalized()

	knockback_velocity = knock_direction * 350.0
	is_knocked_back = true


func apply_stun(duration: float) -> void:
	if is_dead:
		return
	_enter_stagger(duration)


func flash_red() -> void:
	var flash_tween := create_tween()
	flash_tween.tween_property(sprite, "self_modulate", Color(3.4, 3.4, 3.4, 1.0), 0.06)
	flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.20)


func perform_critical_hit_effects() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.has_method("shake"):
		camera.call("shake", 0.35, 15.0)

	var flash_tween := create_tween()
	flash_tween.tween_property(sprite, "self_modulate", Color(2.0, 2.0, 2.0, 1.0), 0.08)
	flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.18)


func show_damage_number(amount: int, is_critical: bool = false) -> void:
	var damage_text := str(amount)

	normal_hit_streak += 1
	streak_timer = 0.0

	var damage_label := RichTextLabel.new()
	damage_label.bbcode_enabled = true
	damage_label.fit_content = true
	damage_label.scroll_active = false
	damage_label.custom_minimum_size = Vector2(100.0, 100.0)

	if is_critical:
		damage_label.text = "[center][shake rate=30.0 level=15][color=#FF7777][font_size=8]CRIT[/font_size] [font_size=10]%s[/font_size][/color][/shake][/center]" % damage_text
	else:
		var color := "#AAAAAA"
		if normal_hit_streak == 2:
			color = "#04d9ff"
		elif normal_hit_streak == 3:
			color = "#FFFF00"
		elif normal_hit_streak >= 5:
			color = "#FFA500"

		if normal_hit_streak > 5:
			damage_label.text = "[center][font_size=10][wave amp=10.0 freq=3.0][color=%s]%s[/color][color=#FF00FF] x%s[/color][/wave][/font_size][/center]" % [color, damage_text, normal_hit_streak]
		else:
			damage_label.text = "[center][font_size=10][wave amp=10.0 freq=3.0][color=%s]%s[/color][/wave][/font_size][/center]" % [color, damage_text]

	var x_offset := randf_range(-25.0, 25.0)
	damage_label.position = global_position + Vector2(x_offset, -40.0)
	damage_label.size = Vector2(40.0, 20.0)

	var parent := get_parent()
	if parent == null:
		damage_label.queue_free()
		return
	parent.add_child(damage_label)

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	var jump_height := -60.0 if is_critical else -40.0
	var jump_distance := x_offset * 1.5
	var jump_duration := 0.9 if is_critical else 0.7

	tween.tween_property(damage_label, "position:y", damage_label.position.y + jump_height, jump_duration)
	tween.tween_property(damage_label, "position:x", damage_label.position.x + jump_distance, jump_duration)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.6).set_delay(0.4)

	await tween.finished
	if is_instance_valid(damage_label):
		damage_label.queue_free()


# ============================================================
# POST-MOVE CHECKS
# ============================================================

func _post_move_combat_checks() -> void:
	if combat_action != "dive_dash":
		return

	if not dive_has_hit and _target_is_valid():
		if global_position.distance_to(player.global_position) <= DIVE_HIT_RANGE:
			_damage_target(DIVE_DAMAGE)
			dive_has_hit = true

	if get_slide_collision_count() > 0:
		_finish_dive(true)


# ============================================================
# ANIMATION
# ============================================================

func set_animation() -> void:
	if is_dead:
		return

	var flip_threshold := 5.0
	if absf(velocity.x) > flip_threshold:
		var abs_scale_x := absf(sprite.scale.x)
		if abs_scale_x < 0.001:
			abs_scale_x = 1.0
		sprite.scale.x = -abs_scale_x if velocity.x < 0.0 else abs_scale_x

	if combat_action == "stagger" or is_stunned:
		_play_animation_if_exists("stunned")
	elif combat_action == "evade" or is_dodging or combat_action == "dive_dash":
		_play_animation_if_exists("dodge")
	elif combat_action == "bite_telegraph":
		_play_animation_if_exists("attack")
	elif current_state == "chase" and velocity.length_squared() > 4.0:
		_play_animation_if_exists("flying")
	elif current_state == "patrol" and velocity.length_squared() > 4.0:
		_play_animation_if_exists("idle")
	else:
		_play_animation_if_exists("idle")


func _play_animation_if_exists(animation_name: StringName) -> void:
	if animation_player == null:
		return
	if not animation_player.has_animation(animation_name):
		return
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name)


# ============================================================
# LEGACY SIGNAL / METHOD COMPATIBILITY
# ============================================================

func _on_player_detected(body: Node2D) -> void:
	_on_target_detected(body)


func _on_player_lost(body: Node2D) -> void:
	_on_target_lost(body)


func perform_critical_hit() -> void:
	# Enemy crits were intentionally removed from the new combat design.
	# Keep the method so old animation tracks / calls do not break.
	perform_critical_hit_effects()


func _on_attack_animation_finished(_anim_name: String) -> void:
	# Damage is timer-driven now so combat timing is independent of animation
	# clip length. Kept as a compatibility hook for old scene connections.
	pass


# ============================================================
# DEATH / RESPAWN / LOOT
# ============================================================

func die() -> void:
	if is_dead:
		return

	is_dead = true
	CombatEvents.report_enemy_defeated(self)
	_release_attack_token()
	combat_action = "normal"
	is_attacking = false
	is_dodging = false
	is_stunned = false
	is_knocked_back = false
	velocity = Vector2.ZERO
	_reset_action_visuals()

	_play_animation_if_exists("death")

	if sound_player != null and death_sound != null:
		sound_player.stream = death_sound
		sound_player.volume_db = -20.0
		sound_player.pitch_scale = 1.0
		sound_player.play()

	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	if animation_player != null and animation_player.has_animation("death"):
		await animation_player.animation_finished

	hide()
	drop_loot()

	await get_tree().create_timer(RESPAWN_COOLDOWN).timeout
	respawn()


func drop_loot() -> void:
	LootDropper.spawn_independent_drops(self, [
		{"item": "health_heart", "chance": 0.54},
		{"item": "bat_claw", "chance": 0.25},
		{"item": "copper_nugget", "chance": 0.46},
		{"item": "iron_nugget", "chance": 0.16},
		{"item": "iron_nugget", "chance": 0.09},
		{"item": "gold_nugget", "chance": 0.018},
		{"item": "bat_artefact", "chance": 0.008}
	])


func get_loot_table() -> Array:
	var bat_claw_data: InvItem = preload("res://InventorySystem/items/bat_claw.tres")
	var copper_nugget_data: InvItem = preload("res://InventorySystem/items/copper_nugget.tres")
	var iron_nugget_data: InvItem = preload("res://InventorySystem/items/iron_nugget.tres")
	var gold_nugget_data: InvItem = preload("res://InventorySystem/items/gold_nugget.tres")
	var bat_artefact_data: InvItem = preload("res://InventorySystem/items/bat_artefact.tres")

	return [
		{"scene": preload("res://Scenes/Items/bat_claw.tscn"), "chance": bat_claw_data.drop_chance},
		{"scene": preload("res://Scenes/Items/copper_nugget.tscn"), "chance": copper_nugget_data.drop_chance},
		{"scene": preload("res://Scenes/Items/iron_nugget.tscn"), "chance": iron_nugget_data.drop_chance},
		{"scene": preload("res://Scenes/Items/gold_nugget.tscn"), "chance": gold_nugget_data.drop_chance},
		{"scene": preload("res://Scenes/Items/bat_artefact.tscn"), "chance": bat_artefact_data.drop_chance},
		{"scene": null, "chance": 0.70}
	]


func respawn() -> void:
	if was_called:
		queue_free()
		return

	bat_health = MAX_HEALTH
	is_dead = false
	is_stunned = false
	is_dodging = false
	is_knocked_back = false
	is_attacking = false
	combat_action = "normal"
	action_timer = 0.0
	action_elapsed = 0.0
	recovery_source = ""
	stagger_meter = 0.0
	stagger_immunity_timer = 0.0
	dodge_cooldown = 0.0
	bite_cooldown = 0.0
	sonic_cooldown = randf_range(0.65, 1.35)
	dive_cooldown = randf_range(1.25, 2.10)
	next_attack_preference = "sonic"
	_release_attack_token()

	global_position = get_random_spawn_position()
	show()
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	health_bar.visible = false
	_reset_action_visuals()


func get_random_spawn_position(max_attempts: int = 20) -> Vector2:
	var shape := spawn_zone_container as CollisionShape2D
	if shape == null or shape.shape == null:
		return global_position

	var space_state := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.collision_mask = 0b1

	for _i in range(max_attempts):
		var random_pos := global_position

		if shape.shape is RectangleShape2D:
			var rectangle := shape.shape as RectangleShape2D
			var half_size := rectangle.size * 0.5
			random_pos = shape.global_position + Vector2(
				randf_range(-half_size.x, half_size.x),
				randf_range(-half_size.y, half_size.y)
			)
		elif shape.shape is CircleShape2D:
			var circle := shape.shape as CircleShape2D
			var angle := randf_range(0.0, TAU)
			var distance := sqrt(randf()) * circle.radius
			random_pos = shape.global_position + Vector2(cos(angle), sin(angle)) * distance
		else:
			return global_position

		params.position = random_pos
		if space_state.intersect_point(params).is_empty():
			return random_pos

	return global_position


func update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.value = bat_health
	health_bar.max_value = MAX_HEALTH


# ============================================================
# OPTIONAL LEGACY CALL-FOR-HELP
# ============================================================

func call_for_help() -> void:
	if not want_call or not can_call_for_help or is_dead:
		return

	var nearby_bats := 0
	for bat in get_tree().get_nodes_in_group("bats"):
		if bat == self or not (bat is Node2D):
			continue
		if global_position.distance_to((bat as Node2D).global_position) < CALL_RANGE:
			nearby_bats += 1

	if nearby_bats < 2:
		spawn_new_bat()

	can_call_for_help = false
	call_timer = CALL_COOLDOWN
	show_call_icon()


func spawn_new_bat() -> void:
	var bat_scene := load("res://Scenes/albino_bat.tscn") as PackedScene
	if bat_scene == null:
		return

	var new_bat := bat_scene.instantiate()
	if new_bat == null:
		return

	new_bat.set("player", player)
	new_bat.set("spawn_zone_container", spawn_zone_container)
	new_bat.set("was_called", true)

	var parent := get_parent()
	if parent == null:
		return

	parent.add_child(new_bat)
	new_bat.set("original_speed", FAST_SPEED)
	new_bat.set("current_speed", FAST_SPEED)
	if new_bat is Node2D:
		(new_bat as Node2D).global_position = get_random_spawn_position()


func show_call_icon() -> void:
	alert_icon.text = "!?"
	alert_icon.visible = true

	var call_tween := create_tween()
	call_tween.tween_property(alert_icon, "scale", Vector2(1.8, 1.8), 0.2)
	call_tween.tween_property(alert_icon, "scale", Vector2.ONE, 0.2)

	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(alert_icon):
		alert_icon.visible = false
		alert_icon.text = "!"


# ============================================================
# STEALTH / LIGHT
# ============================================================

func update_stealth() -> void:
	var light_influence := get_light_influence_at_position(global_position)
	modulate.a = lerpf(0.20, 1.0, light_influence)


func get_light_influence_at_position(pos: Vector2) -> float:
	var total_light := 0.0
	var max_light_influence := 0.0

	for light in get_tree().get_nodes_in_group("lights"):
		if not is_instance_valid(light):
			continue
		if not (light is PointLight2D):
			continue

		var point_light := light as PointLight2D
		if not point_light.is_visible_in_tree() or not point_light.enabled:
			continue
		if point_light.texture == null:
			continue

		var light_radius := point_light.texture_scale * point_light.texture.get_size().length() * 0.5
		if light_radius <= 0.001:
			continue

		var distance := pos.distance_to(point_light.global_position)
		if distance > light_radius:
			continue

		var normalized_distance := distance / light_radius
		var falloff := 1.0 / (1.0 + 10.0 * normalized_distance * normalized_distance)
		total_light += point_light.energy * falloff
		max_light_influence = maxf(max_light_influence, point_light.energy)

	if max_light_influence > 0.0:
		return clampf(total_light / max_light_influence, 0.0, 1.0)
	return 0.0


# ============================================================
# SLOW SYSTEM
# ============================================================

func get_speed() -> float:
	return original_speed


func set_speed(new_speed: float) -> void:
	original_speed = maxf(new_speed, 0.0)
	current_speed = original_speed * current_slow_multiplier


func apply_slow(slow_multiplier: float, duration: float) -> void:
	current_slow_multiplier = clampf(slow_multiplier, 0.05, 1.0)
	current_speed = original_speed * current_slow_multiplier
	slow_timer = maxf(duration, 0.0)
	is_slowed = slow_timer > 0.0
	_show_slow_effect()


func _reset_speed() -> void:
	current_slow_multiplier = 1.0
	current_speed = original_speed
	slow_timer = 0.0
	is_slowed = false
	_hide_slow_effect()


func _show_slow_effect() -> void:
	var slow_tween := create_tween()
	slow_tween.tween_property(sprite, "modulate", Color(0.7, 0.7, 1.0, 0.8), 0.3)

	var slow_particles := GPUParticles2D.new()
	add_child(slow_particles)

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 25.0
	mat.gravity = Vector3(0.0, -20.0, 0.0)
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 45.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 35.0
	mat.scale_min = 0.6
	mat.scale_max = 1.0
	mat.color_ramp = _create_slow_color_ramp()

	slow_particles.process_material = mat
	slow_particles.amount = 20
	slow_particles.lifetime = 1.0
	slow_particles.one_shot = false
	slow_particles.emitting = true

	var effect_duration := slow_timer
	if effect_duration > 0.0:
		await get_tree().create_timer(effect_duration).timeout

	if is_instance_valid(slow_particles):
		slow_particles.emitting = false
		slow_particles.queue_free()


func _hide_slow_effect() -> void:
	var normal_tween := create_tween()
	normal_tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)


func _create_slow_color_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.3, 0.5, 0.9, 0.8))
	gradient.set_color(1, Color(0.3, 0.5, 0.9, 0.0))

	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture
