# BAT.gd

extends CharacterBody2D

const SPEED = 140.0
const DETECTION_RADIUS = 300.0
const ATTACK_RANGE = 50.0
const ATTACK_COOLDOWN = 1.5
const MIN_DISTANCE = 40.0
const SPAWN_RADIUS = 30.0
const RESPAWN_COOLDOWN = 5.0

var is_dead := false
var health := 50
var is_attacking := false
var attack_timer := 0.0
var original_position: Vector2

@export var player: CharacterBody2D
@onready var animation_player = $Sprite2D/AnimationPlayer
@onready var navigation_agent = $NavigationAgent2D
@onready var camera: Camera2D = $Camera2D  # Deine Kamera im Szenenbaum

func _ready() -> void:
	randomize()
	add_to_group("enemies")
	original_position = global_position

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		if distance_to_player <= DETECTION_RADIUS:
			navigation_agent.target_position = player.global_position
			var direction = to_local(navigation_agent.get_next_path_position()).normalized()
			
			if distance_to_player > MIN_DISTANCE:
				velocity = direction * SPEED
			else:
				velocity = Vector2.ZERO

			attack_timer -= delta
			if distance_to_player <= ATTACK_RANGE and attack_timer <= 0.0:
				attack()
		else:
			velocity = Vector2.ZERO

	move_and_slide()
	set_animation()

func attack() -> void:
	if player and not is_dead:
		# Prüfe, ob es sich um einen kritischen Treffer handelt
		var is_critical = randf() < 0.1  # 10% Chance für einen kritischen Treffer
		if is_critical:
			perform_critical_hit()  # Slow-Motion und Kamera-Wackeln sofort starten

		# Spiele die Angriff-Animation ab
		animation_player.play("attack")
		attack_timer = ATTACK_COOLDOWN
		is_attacking = true
		animation_player.connect("animation_finished", Callable(self, "_on_attack_animation_finished"))

func perform_critical_hit() -> void:
	# Aktiviere Slow-Motion-Effekt
	activate_slow_motion(0.3, 0.5)  # Zeitlupe für 0.3 Sekunden mit halber Geschwindigkeit

	# Stärkeres Kamera-Wackeln
	screen_shake(0.5, 30.0)  # Kamera-Wackeln für 0.5 Sekunden mit Intensität 30

func activate_slow_motion(duration: float, scale: float) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration).timeout
	Engine.time_scale = 1.0

func screen_shake(duration: float, intensity: float) -> void:
	var tween = get_tree().create_tween()
	for i in range(int(duration * 10)):
		var random_offset = Vector2(randi_range(-intensity, intensity), randi_range(-intensity, intensity))
		tween.tween_property(camera, "offset", random_offset, 0.05)
		tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

func _on_attack_animation_finished(anim_name: String) -> void:
	if anim_name == "attack" and player:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= ATTACK_RANGE:
			var random_damage = int(randf_range(7.0, 17.0))
			
			# Doppelt so viel Schaden bei einem kritischen Treffer
			var is_critical = randf() < 0.1
			if is_critical:
				random_damage *= 2
			
			player.take_damage(random_damage)

	animation_player.disconnect("animation_finished", Callable(self, "_on_attack_animation_finished"))
	is_attacking = false

func set_animation() -> void:
	if is_dead:
		return

	if velocity.x != 0:
		$Sprite2D.scale.x = -1 if velocity.x < 0 else 1

	if is_attacking:
		animation_player.play("attack")
	elif velocity.length() > 0:
		animation_player.play("flying")
	else:
		animation_player.play("idle")

func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount
	if health <= 0:
		die()

func die():
	is_dead = true
	animation_player.play("death")
	velocity = Vector2.ZERO
	queue_free()
	await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(RESPAWN_COOLDOWN).timeout
	spawn_near_original_position()

func spawn_near_original_position() -> void:
	var random_offset = Vector2(randf_range(-SPAWN_RADIUS, SPAWN_RADIUS), randf_range(-SPAWN_RADIUS, SPAWN_RADIUS))
	global_position = original_position + random_offset
	navigation_agent.target_position = global_position
	show()
	is_dead = false
	health = 50
