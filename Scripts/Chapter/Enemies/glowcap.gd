extends CharacterBody2D

const LootDropper := preload("res://Scripts/loot_dropper.gd")

## Leuchtmaul is deliberately rooted in place. It lights a dark pocket of
## cave, waits for Joey to pass, then commits to a clearly readable bite.
signal defeated

enum State { IDLE, TELEGRAPH, BITE, RECOIL, DEAD }

const IDLE_FRAMES := [
	preload("res://Assets/Enemies/Leuchtmaul/frames/idle_00.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/idle_01.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/idle_02.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/idle_03.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/idle_04.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/idle_05.png")
]
const BITE_FRAMES := [
	preload("res://Assets/Enemies/Leuchtmaul/frames/bite_00.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/bite_01.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/bite_02.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/bite_03.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/bite_04.png")
]
const RECOIL_FRAME := preload("res://Assets/Enemies/Leuchtmaul/frames/recoil_00.png")
const DEATH_FRAMES := [
	preload("res://Assets/Enemies/Leuchtmaul/frames/death_00.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/death_01.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/death_02.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/death_03.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/death_04.png"),
	preload("res://Assets/Enemies/Leuchtmaul/frames/death_05.png")
]

const GRAVITY := 1180.0
const FRAME_SECONDS := 0.105
const BASE_SPRITE_SCALE := Vector2(0.24, 0.24)
const NORMAL_LIGHT := Color(0.30, 1.0, 0.89, 1.0)
const RECOIL_LIGHT := Color(0.16, 0.42, 0.45, 1.0)

@export var enemy_name := "Leuchtmaul"
@export var max_health := 42
@export var bite_range := 78.0
@export var bite_damage := 12
@export var bite_cooldown := 1.65
@export var telegraph_duration := 0.42
@export var bite_duration := 0.50
@export var death_duration := 0.72
@export var dark_light_energy := 0.055
@export var recoil_light_energy := 0.018

var current_health := 42
var player: Node2D
var state: State = State.IDLE
var state_time := 0.0
var local_time := 0.0
var attack_cooldown_left := 0.35
var hit_cooldown := 0.0
var bite_active := false
var bite_hit_applied := false
var is_dead := false
var facing_sign := 1.0
var hit_flash_timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_light: PointLight2D = $PointLight2D
@onready var bite_area: Area2D = $BiteArea


func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	_sync_player_reference()
	bite_area.body_entered.connect(_on_bite_area_body_entered)
	sprite.scale = BASE_SPRITE_SCALE
	# Joey and his weapon stay visibly in front of rooted enemies. Their attack
	# area remains a separate physical system, so this is presentation only.
	sprite.z_index = -2
	glow_light.z_index = -3
	# Its bioluminescence is authored directly in the sprite and caught by the
	# global bloom. Do not cast a room-sized light from this stationary enemy.
	glow_light.visible = false
	_enter_state(State.IDLE, true)


func _physics_process(delta: float) -> void:
	_sync_player_reference()
	state_time += delta
	local_time += delta
	attack_cooldown_left = maxf(attack_cooldown_left - delta, 0.0)
	hit_cooldown = maxf(hit_cooldown - delta, 0.0)
	hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)

	if not is_on_floor() and not is_dead:
		velocity.y = minf(velocity.y + GRAVITY * delta, 720.0)
	else:
		velocity.y = maxf(velocity.y, 0.0)
	# No horizontal movement: this is an ambush plant, never a walker.
	velocity.x = 0.0

	if is_dead:
		_update_death(delta)
		move_and_slide()
		return

	_update_facing()
	if _player_is_glowing():
		if state != State.RECOIL:
			_enter_state(State.RECOIL)
	else:
		match state:
			State.IDLE:
				_process_idle()
			State.TELEGRAPH:
				if state_time >= telegraph_duration:
					_enter_state(State.BITE)
			State.BITE:
				_process_bite()
			State.RECOIL:
				_enter_state(State.IDLE)

	move_and_slide()
	_update_lighting()
	_update_sprite()


func take_damage(amount: int, direction := Vector2.ZERO, _is_crit: bool = false) -> void:
	if is_dead or current_health <= 0:
		return
	current_health -= maxi(0, amount)
	hit_flash_timer = 0.13
	if direction.length_squared() > 0.01:
		facing_sign = -signf(direction.x)
	if current_health <= 0:
		call_deferred("_die")


func _process_idle() -> void:
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= bite_range and attack_cooldown_left <= 0.0:
		_enter_state(State.TELEGRAPH)


func _process_bite() -> void:
	var active_start := bite_duration * 0.34
	var active_end := bite_duration * 0.74
	_set_bite_active(state_time >= active_start and state_time <= active_end)
	if bite_active:
		for body in bite_area.get_overlapping_bodies():
			_try_bite(body)
	if state_time >= bite_duration:
		attack_cooldown_left = bite_cooldown
		_enter_state(State.IDLE)


func _enter_state(next_state: State, force := false) -> void:
	if state == next_state and not force:
		return
	state = next_state
	state_time = 0.0
	_set_bite_active(false)
	if state == State.BITE:
		bite_hit_applied = false


func _update_death(delta: float) -> void:
	_set_bite_active(false)
	_update_sprite()
	glow_light.energy = move_toward(glow_light.energy, 0.0, 2.8 * delta)
	if state_time >= death_duration:
		queue_free()


func _update_facing() -> void:
	if player != null and is_instance_valid(player):
		var horizontal_offset := player.global_position.x - global_position.x
		if not is_zero_approx(horizontal_offset):
			facing_sign = signf(horizontal_offset)
	sprite.flip_h = facing_sign < 0.0
	bite_area.position = Vector2(31.0 * facing_sign, -29.0)


func _update_lighting() -> void:
	var target_energy := dark_light_energy + sin(local_time * 2.2) * 0.008
	var target_color := NORMAL_LIGHT
	if state == State.RECOIL:
		target_energy = recoil_light_energy
		target_color = RECOIL_LIGHT
	elif state == State.TELEGRAPH:
		target_energy += 0.018 + sin(state_time * 18.0) * 0.008
	glow_light.energy = lerpf(glow_light.energy, target_energy, 0.16)
	glow_light.color = glow_light.color.lerp(target_color, 0.18)


func _update_sprite() -> void:
	if hit_flash_timer > 0.0:
		sprite.modulate = Color(3.4, 3.4, 3.4, 1.0)
	else:
		# The glow lives on the mushroom itself; its point light is deliberately
		# almost imperceptible so it cannot bleach surrounding cave geometry.
		sprite.modulate = Color(0.84, 1.04, 1.08, 1.0)

	match state:
		State.IDLE:
			_set_frame(IDLE_FRAMES[int(fposmod(floor(local_time / FRAME_SECONDS), IDLE_FRAMES.size()))])
		State.TELEGRAPH:
			var index := mini(2, int(floor(state_time / maxf(telegraph_duration, 0.001) * 3.0)))
			_set_frame(BITE_FRAMES[index])
		State.BITE:
			var index := mini(BITE_FRAMES.size() - 1, int(floor(state_time / maxf(bite_duration, 0.001) * BITE_FRAMES.size())))
			_set_frame(BITE_FRAMES[index])
		State.RECOIL:
			_set_frame(RECOIL_FRAME)
		State.DEAD:
			var index := mini(DEATH_FRAMES.size() - 1, int(floor(state_time / maxf(death_duration, 0.001) * DEATH_FRAMES.size())))
			_set_frame(DEATH_FRAMES[index])


func _set_frame(texture: Texture2D) -> void:
	if sprite.texture != texture:
		sprite.texture = texture


func _set_bite_active(active: bool) -> void:
	bite_active = active
	# This function can be reached from a hit signal while physics queries are
	# flushing.  Deferred toggles avoid an invalid collision-state mutation.
	bite_area.set_deferred("monitoring", active)
	bite_area.set_deferred("monitorable", active)


func _try_bite(body: Node) -> void:
	if not bite_active or bite_hit_applied or hit_cooldown > 0.0:
		return
	if body == null or not is_instance_valid(body) or not body.is_in_group("players"):
		return
	bite_hit_applied = true
	hit_cooldown = 0.65
	if body.has_method("take_damage"):
		body.call_deferred("take_damage", bite_damage, global_position)


func _on_bite_area_body_entered(body: Node2D) -> void:
	_try_bite(body)


func _player_is_glowing() -> bool:
	return player != null and is_instance_valid(player) and bool(player.get("is_glowing"))


func _sync_player_reference() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as Node2D


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	state = State.DEAD
	state_time = 0.0
	emit_signal("defeated")
	LootDropper.spawn_independent_drops(self, [
		{"item": "health_heart", "chance": 0.52},
		{"item": "copper_nugget", "chance": 0.34},
		{"item": "iron_nugget", "chance": 0.14},
		{"item": "bat_artefact", "chance": 0.015}
	])
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	_set_bite_active(false)
