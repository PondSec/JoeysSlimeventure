extends CharacterBody2D

signal defeated

const GRAVITY := 1300.0
const CONTACT_COOLDOWN := 0.8
const BASE_SPRITE_SCALE := Vector2(0.14, 0.14)
const SQUASH_SPRITE_SCALE := Vector2(0.18, 0.11)
const BASE_COLOR := Color(0.52, 0.84, 1.0, 1.0)
const GLOW_COLOR := Color(0.28, 0.7, 1.0, 1.0)
const HIT_FLASH_COLOR := Color(1.0, 0.8, 0.84, 1.0)

@export var max_health: int = 32
@export var hop_impulse_y: float = -320.0
@export var hop_impulse_x: float = 155.0
@export var aggro_range: float = 260.0
@export var contact_damage: int = 10

var current_health: int = 32
var player: Node2D
var hop_timer: float = 0.25
var contact_timer: float = 0.0
var anim_timer: float = 0.0
var hit_flash_timer: float = 0.0
var is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_light: PointLight2D = $PointLight2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	current_health = max_health
	player = get_tree().get_first_node_in_group("players") as Node2D
	add_to_group("enemies")
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	sprite.scale = BASE_SPRITE_SCALE
	if glow_light != null:
		glow_light.color = GLOW_COLOR
		glow_light.energy = 0.56
	_update_animation(0.0)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as Node2D

	hop_timer = maxf(hop_timer - delta, 0.0)
	contact_timer = maxf(contact_timer - delta, 0.0)
	hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)
	anim_timer += delta

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		if hop_timer <= 0.0:
			_jump_towards_target()

	move_and_slide()
	_update_visuals()
	_update_animation(delta)


func take_damage(amount: int, direction: Vector2, _is_crit: bool = false) -> void:
	if is_dead:
		return

	current_health -= amount
	hit_flash_timer = 0.16
	var knockback_direction: Vector2 = direction.normalized() if direction.length() > 0.0 else Vector2(signf(global_position.x - player.global_position.x), -0.4)
	velocity += knockback_direction * 180.0
	velocity.y = minf(velocity.y, -180.0)
	if current_health <= 0:
		_die()


func _jump_towards_target() -> void:
	var direction_sign: float = -1.0 if randf() < 0.5 else 1.0
	if player != null and is_instance_valid(player):
		var distance: float = global_position.distance_to(player.global_position)
		if distance <= aggro_range:
			direction_sign = signf(player.global_position.x - global_position.x)
			if is_zero_approx(direction_sign):
				direction_sign = 1.0

	velocity.x = direction_sign * hop_impulse_x
	velocity.y = hop_impulse_y
	hop_timer = randf_range(0.72, 1.02)
	var squash_tween: Tween = create_tween()
	squash_tween.tween_property(sprite, "scale", SQUASH_SPRITE_SCALE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	squash_tween.tween_property(sprite, "scale", BASE_SPRITE_SCALE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _update_visuals() -> void:
	sprite.flip_h = velocity.x < 0.0
	if hit_flash_timer > 0.0:
		sprite.modulate = HIT_FLASH_COLOR
		if glow_light != null:
			glow_light.color = Color(0.92, 0.72, 0.82, 1.0)
			glow_light.energy = 0.44
		return

	var pulse: float = 0.5 + 0.5 * sin(anim_timer * 4.2)
	sprite.modulate = BASE_COLOR.lerp(Color(0.86, 0.95, 1.0, 1.0), 0.14 + pulse * 0.1)
	if glow_light != null:
		glow_light.color = GLOW_COLOR.lerp(Color(0.72, 0.9, 1.0, 1.0), pulse * 0.22)
		glow_light.energy = 0.5 + pulse * 0.12


func _update_animation(_delta: float) -> void:
	if is_dead:
		sprite.frame = 14
		return

	if not is_on_floor():
		sprite.frame = 8
		return

	var chase_target: bool = player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) <= aggro_range
	if chase_target:
		sprite.frame = 2 + int(fposmod(floor(anim_timer * 8.0), 2.0))
	else:
		sprite.frame = int(fposmod(floor(anim_timer * 6.0), 2.0))


func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead or contact_timer > 0.0:
		return
	if not body.is_in_group("players"):
		return
	contact_timer = CONTACT_COOLDOWN
	if body.has_method("take_damage"):
		body.call("take_damage", contact_damage, global_position)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	emit_signal("defeated")

	var death_tween: Tween = create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	death_tween.tween_property(sprite, "scale", Vector2(0.2, 0.08), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	death_tween.set_parallel(false)
	death_tween.tween_callback(queue_free)
