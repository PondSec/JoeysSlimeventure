extends CharacterBody2D

const SPEED = 140.0
const DETECTION_RADIUS = 300.0
const ATTACK_RANGE = 50.0
const ATTACK_COOLDOWN = 1.5
const MIN_DISTANCE = 40.0
const RESPAWN_COOLDOWN = 5.0

var is_dead := false
var health := 50
var is_attacking := false
var attack_timer := 0.0

@export var player: CharacterBody2D
@onready var animation_player = $Sprite2D/AnimationPlayer
@onready var navigation_agent = $NavigationAgent2D
@onready var camera: Camera2D = $Camera2D  # Kamera für Effekte

func _ready() -> void:
	randomize()
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= ATTACK_RANGE:
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack()
	elif player and player.is_glowing and distance_to_player <= DETECTION_RADIUS:
		navigation_agent.target_position = player.global_position
		var direction = to_local(navigation_agent.get_next_path_position()).normalized()
		if distance_to_player > MIN_DISTANCE:
			velocity = direction * SPEED
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
		is_attacking = false
	
	move_and_slide()
	set_animation()

func attack() -> void:
	if player and not is_dead:
		var is_critical = randf() < 0.1  # 10% Chance für einen kritischen Treffer
		if is_critical:
			perform_critical_hit()

		animation_player.play("attack")
		attack_timer = ATTACK_COOLDOWN
		is_attacking = true
		animation_player.connect("animation_finished", Callable(self, "_on_attack_animation_finished"))

func perform_critical_hit() -> void:
	activate_slow_motion(0.3, 0.5)
	screen_shake(0.5, 30.0)

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
			if randf() < 0.1:
				random_damage *= 2  # Kritischer Treffer macht doppelten Schaden
			
			player.take_damage(random_damage)

	animation_player.disconnect("animation_finished", Callable(self, "_on_attack_animation_finished"))
	is_attacking = false
	set_animation()  # Stelle sicher, dass die Animation aktualisiert wird

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
	hide()  # Fledermaus unsichtbar machen
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)  
	await get_tree().create_timer(1.0).timeout  # Warte für die Sterbeanimation
	await get_tree().create_timer(RESPAWN_COOLDOWN).timeout  # Respawn-Delay
	spawn_near_player()

func is_in_player_view(position: Vector2) -> bool:
	if not player or not camera:
		return false

	var viewport_rect = camera.get_viewport_rect()
	var screen_position = camera.get_camera_transform().affine_inverse().xform(position)

	return viewport_rect.has_point(screen_position)

func spawn_near_player() -> void:
	if not player:
		print("FEHLER: Kein Spieler gefunden!")
		return

	var valid_position_found = false
	var new_position = global_position  # Fallback

	for i in range(10):  # Maximal 10 Versuche, eine passende Position zu finden
		var random_offset = Vector2(
			randf_range(-DETECTION_RADIUS, DETECTION_RADIUS),
			randf_range(-DETECTION_RADIUS, DETECTION_RADIUS)
		)
		var candidate_position = player.global_position + random_offset

		# Stelle sicher, dass die Position sichtbar ist
		if candidate_position.distance_to(player.global_position) >= MIN_DISTANCE and is_in_player_view(candidate_position):
			navigation_agent.target_position = candidate_position
			await get_tree().physics_frame
			if navigation_agent.is_navigation_finished():
				new_position = candidate_position
				valid_position_found = true
				break

	if not valid_position_found:
		print("WARNUNG: Keine ideale Spawn-Position gefunden, Respawn abgebrochen.")
		return  # Fledermaus wird nicht gespawnt, wenn keine gültige Position gefunden wird

	global_position = new_position
	show()
	set_deferred("collision_layer", 1)
	set_deferred("collision_mask", 1)
	is_dead = false
	health = 50
	print("Fledermaus respawned bei:", global_position)
