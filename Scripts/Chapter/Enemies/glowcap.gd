extends CharacterBody2D

signal defeated

enum State {
	IDLE,
	STALK,
	BLOOM_CHARGE,
	BLOOM_BURST,
	RECOIL,
	MELEE,
	DEAD
}

const GRAVITY := 1180.0
const CONTACT_COOLDOWN := 0.75
const FLOOR_ACCELERATION := 920.0
const FLOOR_FRICTION := 1280.0
const SPORE_BUFF_KEY := "temporary_speed_glowcap_spores"

const IDLE_TEXTURE := preload("res://Assets/Enemy/Mushroom/Mushroom without VFX/Mushroom-Idle.png")
const RUN_TEXTURE := preload("res://Assets/Enemy/Mushroom/Mushroom without VFX/Mushroom-Run.png")
const ATTACK_TEXTURE := preload("res://Assets/Enemy/Mushroom/Mushroom without VFX/Mushroom-Attack.png")
const ATTACK_WITH_SPORES_TEXTURE := preload("res://Assets/Enemy/Mushroom/Mushroom with VFX/Mushroom-AttackWithStun.png")
const STUN_TEXTURE := preload("res://Assets/Enemy/Mushroom/Mushroom with VFX/Mushroom-Stun.png")
const DIE_TEXTURE := preload("res://Assets/Enemy/Mushroom/Mushroom without VFX/Mushroom-Die.png")

const BASE_LIGHT_COLOR := Color(0.82, 0.54, 0.32, 1.0)
const BLOOM_LIGHT_COLOR := Color(0.68, 1.0, 0.62, 1.0)
const RECOIL_LIGHT_COLOR := Color(0.78, 0.58, 1.0, 1.0)
const HIT_FLASH_COLOR := Color(1.0, 0.82, 0.82, 1.0)
const BASE_SCALE := Vector2.ONE

@export var enemy_name: String = "Glowcap"
@export var max_health: int = 34
@export var patrol_speed: float = 24.0
@export var stalk_speed: float = 64.0
@export var bloom_speed: float = 96.0
@export var ambush_speed: float = 156.0
@export var glow_detection_range: float = 320.0
@export var dark_detection_range: float = 116.0
@export var bloom_trigger_range: float = 144.0
@export var melee_trigger_range: float = 58.0
@export var contact_damage: int = 7
@export var spore_damage: int = 9
@export var spore_slow_multiplier: float = 0.72
@export var spore_slow_duration: float = 1.9
@export var bloom_charge_duration: float = 0.62
@export var bloom_burst_duration: float = 0.72
@export var recoil_duration: float = 1.0
@export var melee_duration: float = 0.42
@export var patrol_leash: float = 42.0

var current_health: int = 34
var player: Node2D
var home_position: Vector2 = Vector2.ZERO
var state: State = State.IDLE
var state_time: float = 0.0
var anim_time: float = 0.0
var local_time: float = 0.0
var contact_cooldown: float = 0.0
var melee_cooldown: float = 0.35
var spore_cooldown: float = 1.45
var hit_flash_timer: float = 0.0
var is_dead: bool = false
var player_glow_active: bool = false
var spore_area_active: bool = false
var spore_hit_applied: bool = false
var facing_sign: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_light: PointLight2D = $PointLight2D
@onready var hitbox: Area2D = $Hitbox
@onready var spore_area: Area2D = $SporeArea


func _ready() -> void:
	current_health = max_health
	home_position = global_position
	add_to_group("enemies")
	_sync_player_reference()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	spore_area.body_entered.connect(_on_spore_area_body_entered)
	sprite.scale = BASE_SCALE
	_enter_state(State.IDLE, true)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_sync_player_reference()
	var previous_glow: bool = player_glow_active
	player_glow_active = _is_player_glowing()
	if state == State.BLOOM_CHARGE and previous_glow and not player_glow_active:
		_enter_state(State.RECOIL)

	state_time += delta
	anim_time += delta
	local_time += delta
	contact_cooldown = maxf(contact_cooldown - delta, 0.0)
	melee_cooldown = maxf(melee_cooldown - delta, 0.0)
	spore_cooldown = maxf(spore_cooldown - delta, 0.0)
	hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match state:
		State.IDLE:
			_process_idle(delta)
		State.STALK:
			_process_stalk(delta)
		State.BLOOM_CHARGE:
			_process_bloom_charge(delta)
		State.BLOOM_BURST:
			_process_bloom_burst(delta)
		State.RECOIL:
			_process_recoil(delta)
		State.MELEE:
			_process_melee(delta)

	move_and_slide()
	_update_facing()
	_update_visuals()
	_update_animation()


func take_damage(amount: int, direction: Vector2, _is_crit: bool = false) -> void:
	if is_dead:
		return

	var applied_damage: int = amount
	if state == State.RECOIL:
		applied_damage = int(round(float(amount) * 1.35))

	current_health -= applied_damage
	hit_flash_timer = 0.16
	var knockback_direction: Vector2 = direction.normalized() if direction.length() > 0.0 else Vector2(facing_sign, -0.2)
	velocity += knockback_direction * 145.0
	velocity.y = minf(velocity.y, -105.0)

	if current_health <= 0:
		_die()


func _process_idle(delta: float) -> void:
	var should_notice_player: bool = _should_notice_player()
	if should_notice_player:
		_enter_state(State.STALK)
		return

	var offset_from_home: float = global_position.x - home_position.x
	var target_speed: float = 0.0
	if absf(offset_from_home) > patrol_leash:
		target_speed = -signf(offset_from_home) * patrol_speed
	elif is_on_floor():
		target_speed = sin(local_time * 1.15) * patrol_speed * 0.55
	velocity.x = move_toward(velocity.x, target_speed, FLOOR_ACCELERATION * 0.42 * delta)


func _process_stalk(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_enter_state(State.IDLE)
		return

	var distance_to_player: float = global_position.distance_to(player.global_position)
	var active_detection_range: float = glow_detection_range if player_glow_active else dark_detection_range
	if distance_to_player > active_detection_range + 48.0:
		_enter_state(State.IDLE)
		return

	if player_glow_active and spore_cooldown <= 0.0 and distance_to_player <= bloom_trigger_range:
		_enter_state(State.BLOOM_CHARGE)
		return

	if melee_cooldown <= 0.0 and distance_to_player <= melee_trigger_range:
		_enter_state(State.MELEE)
		return

	var direction_sign: float = signf(player.global_position.x - global_position.x)
	if is_zero_approx(direction_sign):
		direction_sign = facing_sign
	var target_speed: float = bloom_speed if player_glow_active else stalk_speed
	velocity.x = move_toward(velocity.x, direction_sign * target_speed, FLOOR_ACCELERATION * delta)


func _process_bloom_charge(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, FLOOR_FRICTION * delta)
	if not player_glow_active:
		_enter_state(State.RECOIL)
		return
	if state_time >= bloom_charge_duration:
		_enter_state(State.BLOOM_BURST)


func _process_bloom_burst(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, FLOOR_FRICTION * delta)
	if not spore_area_active and state_time >= bloom_burst_duration * 0.18:
		_set_spore_area(true)
	if spore_area_active and state_time >= bloom_burst_duration * 0.56:
		_set_spore_area(false)
	if state_time >= bloom_burst_duration:
		_enter_state(State.STALK if _should_notice_player() else State.IDLE)


func _process_recoil(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, FLOOR_FRICTION * delta)
	if state_time >= recoil_duration:
		_enter_state(State.STALK if _should_notice_player() else State.IDLE)


func _process_melee(delta: float) -> void:
	if state_time < melee_duration * 0.45:
		velocity.x = move_toward(velocity.x, facing_sign * ambush_speed, FLOOR_ACCELERATION * 1.1 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FLOOR_FRICTION * delta)

	if state_time >= melee_duration:
		_enter_state(State.STALK if _should_notice_player() else State.IDLE)


func _enter_state(new_state: State, force: bool = false) -> void:
	if state == new_state and not force:
		return

	state = new_state
	state_time = 0.0
	_set_spore_area(false)

	match state:
		State.IDLE:
			pass
		State.STALK:
			pass
		State.BLOOM_CHARGE:
			velocity.x = 0.0
			_pulse_sprite(Vector2(1.08, 0.92), 0.2)
		State.BLOOM_BURST:
			spore_cooldown = randf_range(3.8, 5.0)
			spore_hit_applied = false
			velocity.x = 0.0
			_pulse_sprite(Vector2(1.18, 0.88), 0.16)
		State.RECOIL:
			velocity.x *= 0.16
			spore_hit_applied = false
			_pulse_sprite(Vector2(0.92, 1.06), 0.22)
		State.MELEE:
			melee_cooldown = randf_range(1.2, 1.8)
			var direction_sign: float = _direction_to_player()
			facing_sign = direction_sign
			velocity.x = direction_sign * ambush_speed
			if is_on_floor():
				velocity.y = -96.0 if player_glow_active else -72.0
			_pulse_sprite(Vector2(1.12, 0.9), 0.18)


func _should_notice_player() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var distance_to_player: float = global_position.distance_to(player.global_position)
	if player_glow_active:
		return distance_to_player <= glow_detection_range
	return distance_to_player <= dark_detection_range


func _is_player_glowing() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return bool(player.get("is_glowing"))


func _sync_player_reference() -> void:
	if player != null and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("players") as Node2D


func _direction_to_player() -> float:
	if player == null or not is_instance_valid(player):
		return facing_sign
	var direction_sign: float = signf(player.global_position.x - global_position.x)
	return direction_sign if not is_zero_approx(direction_sign) else facing_sign


func _update_facing() -> void:
	if absf(velocity.x) > 6.0:
		facing_sign = signf(velocity.x)
	elif player != null and is_instance_valid(player):
		var player_direction: float = signf(player.global_position.x - global_position.x)
		if not is_zero_approx(player_direction):
			facing_sign = player_direction
	sprite.flip_h = facing_sign < 0.0


func _update_visuals() -> void:
	if hit_flash_timer > 0.0:
		sprite.modulate = HIT_FLASH_COLOR
	else:
		sprite.modulate = Color.WHITE

	if glow_light == null:
		return

	var target_energy: float = 0.12
	var target_color: Color = BASE_LIGHT_COLOR
	if player_glow_active and _should_notice_player():
		target_energy = 0.38
		target_color = BASE_LIGHT_COLOR.lerp(BLOOM_LIGHT_COLOR, 0.35)
	if state == State.BLOOM_CHARGE:
		target_energy = 0.82 + sin(state_time * 16.0) * 0.08
		target_color = BLOOM_LIGHT_COLOR
	elif state == State.BLOOM_BURST:
		target_energy = 1.1
		target_color = BLOOM_LIGHT_COLOR.lerp(Color(1.0, 0.9, 0.72, 1.0), 0.28)
	elif state == State.RECOIL:
		target_energy = 0.46 + sin(state_time * 12.0) * 0.05
		target_color = RECOIL_LIGHT_COLOR

	glow_light.energy = lerpf(glow_light.energy, target_energy, 0.2)
	glow_light.color = glow_light.color.lerp(target_color, 0.22)


func _update_animation() -> void:
	match state:
		State.IDLE:
			_play_loop_animation(IDLE_TEXTURE, 7, 4.5)
		State.STALK:
			if absf(velocity.x) > 18.0:
				_play_loop_animation(RUN_TEXTURE, 8, 8.0 if player_glow_active else 6.0)
			else:
				_play_loop_animation(IDLE_TEXTURE, 7, 4.5)
		State.BLOOM_CHARGE:
			_play_segment_animation(ATTACK_WITH_SPORES_TEXTURE, 24, 0, 11, bloom_charge_duration)
		State.BLOOM_BURST:
			_play_segment_animation(ATTACK_WITH_SPORES_TEXTURE, 24, 12, 23, bloom_burst_duration)
		State.RECOIL:
			_play_segment_animation(STUN_TEXTURE, 18, 0, 17, recoil_duration)
		State.MELEE:
			_play_segment_animation(ATTACK_TEXTURE, 10, 0, 9, melee_duration)
		State.DEAD:
			pass


func _play_loop_animation(texture: Texture2D, frames: int, fps: float) -> void:
	var frame_index: int = int(fposmod(floor(anim_time * fps), float(frames)))
	_set_sprite_frame(texture, frames, frame_index)


func _play_segment_animation(texture: Texture2D, frames: int, start_frame: int, end_frame: int, duration: float) -> void:
	var progress: float = clampf(state_time / maxf(duration, 0.001), 0.0, 0.999)
	var segment_frames: int = max(1, end_frame - start_frame + 1)
	var frame_index: int = start_frame + mini(segment_frames - 1, int(floor(progress * float(segment_frames))))
	_set_sprite_frame(texture, frames, frame_index)


func _set_sprite_frame(texture: Texture2D, frames: int, frame_index: int) -> void:
	if sprite.texture != texture:
		sprite.texture = texture
		sprite.hframes = frames
		sprite.vframes = 1
	sprite.frame = clampi(frame_index, 0, frames - 1)


func _set_spore_area(active: bool) -> void:
	spore_area_active = active
	spore_area.monitoring = active
	if active:
		_try_apply_spore_hit(player)


func _try_apply_spore_hit(body: Node) -> void:
	if not spore_area_active or spore_hit_applied:
		return
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("players"):
		return

	spore_hit_applied = true
	if body.has_method("take_damage"):
		body.call("take_damage", spore_damage, global_position)
	if body.has_method("apply_timed_buff"):
		body.call("apply_timed_buff", SPORE_BUFF_KEY, spore_slow_multiplier, spore_slow_duration)
	elif body.has_method("apply_buff"):
		body.call("apply_buff", "temporary_speed", spore_slow_multiplier)


func _pulse_sprite(target_scale: Vector2, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", target_scale, duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", BASE_SCALE, duration * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead or contact_cooldown > 0.0:
		return
	if not body.is_in_group("players"):
		return

	contact_cooldown = CONTACT_COOLDOWN
	if body.has_method("take_damage"):
		body.call("take_damage", contact_damage, global_position)


func _on_spore_area_body_entered(body: Node2D) -> void:
	_try_apply_spore_hit(body)


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	state = State.DEAD
	emit_signal("defeated")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	hitbox.monitoring = false
	_set_spore_area(false)

	var death_tween: Tween = create_tween()
	death_tween.tween_method(
		func(frame_value: float) -> void:
			_set_sprite_frame(DIE_TEXTURE, 15, int(round(frame_value))),
		0.0,
		14.0,
		0.54
	)
	death_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.22).set_delay(0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	death_tween.parallel().tween_property(sprite, "scale", Vector2(1.08, 0.82), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	death_tween.tween_callback(queue_free)
