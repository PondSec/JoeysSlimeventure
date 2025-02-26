extends CharacterBody2D

const SPEED = 140.0
const DETECTION_RADIUS = 300.0
const ATTACK_RANGE = 40.0
const ATTACK_COOLDOWN = 1.5
const MIN_DISTANCE = 5.0
const RESPAWN_COOLDOWN = 5
const BASE_DETECTION_RADIUS = 150.0  # Kleinerer Radius für nicht-glühenden Spieler

var is_dead := false
var health := 100
var is_attacking := false
var attack_timer := 0.0
var knockback_velocity := Vector2.ZERO
var is_knocked_back := false
var is_stunned := false  # Neue Variable für Stun-Zustand

@export var player: CharacterBody2D
@onready var animation_player = $Sprite2D/AnimationPlayer
@onready var navigation_agent = $NavigationAgent2D
@onready var camera: Camera2D = $Camera2D  # Kamera für Effekte

func _ready() -> void:
	randomize()
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if is_dead or is_stunned:
		velocity = Vector2.ZERO
		return

	if is_knocked_back:
		velocity = knockback_velocity
		knockback_velocity *= 0.9  # Knockback langsam abschwächen
		if knockback_velocity.length() < 10:
			is_knocked_back = false
			apply_stun(0.5)  # Stun für 0.5 Sekunden nach Knockback
	else:
		var distance_to_player = global_position.distance_to(player.global_position)
		var actual_detection_radius = DETECTION_RADIUS if player.is_glowing else BASE_DETECTION_RADIUS
		
		if distance_to_player <= ATTACK_RANGE:
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack()
		elif player and distance_to_player <= actual_detection_radius:
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
	flash_red()  # Blink-Effekt hinzufügen
	apply_knockback()  # Rückstoß hinzufügen

	if health <= 0:
		die()

func flash_red():
	var sprite = $Sprite2D
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0, 0), 0.2)  # Rote Farbe für 0.1 Sek.
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)  # Zurück zur normalen Farbe

func apply_knockback():
	if player:
		var direction = (global_position - player.global_position).normalized()
		var knockback_strength = 300
		knockback_velocity = direction * knockback_strength
		is_knocked_back = true

		await get_tree().create_timer(0.3).timeout  # Knockback-Dauer
		is_knocked_back = false
		apply_stun(0.3)  # Gegner wird nach Knockback für 0.5 Sekunden betäubt

func apply_stun(duration: float) -> void:
	is_stunned = true
	animation_player.play("stunned")  # Falls eine Stun-Animation existiert
	await get_tree().create_timer(duration).timeout
	is_stunned = false
	set_animation()  # Stellt sicher, dass nach dem Stun die richtige Animation läuft

func die():
	is_dead = true
	animation_player.play("death")
	velocity = Vector2.ZERO
	# Warte, bis die Death-Animation zu Ende ist
	await animation_player.animation_finished  
	hide()  # Jetzt erst verstecken
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)  
	# Respawn-Delay
	await get_tree().create_timer(RESPAWN_COOLDOWN).timeout  
	spawn_near_player()

func is_valid_spawn_position(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = 1  # Stelle sicher, dass nur Wände überprüft werden

	var result = space_state.intersect_point(query)
	return result.is_empty()  # Wenn leer, dann ist die Position frei

func spawn_near_player() -> void:
	if not player:
		print("FEHLER: Kein Spieler gefunden!")
		return

	var valid_position_found = false
	var new_position = global_position  # Fallback

	for i in range(10):
		var random_offset = Vector2(
			randf_range(-DETECTION_RADIUS, DETECTION_RADIUS),
			randf_range(-DETECTION_RADIUS, DETECTION_RADIUS)
		)
		var candidate_position = player.global_position + random_offset

		if candidate_position.distance_to(player.global_position) >= MIN_DISTANCE and is_valid_spawn_position(candidate_position):
			new_position = candidate_position
			valid_position_found = true
			break

	if not valid_position_found:
		print("WARNUNG: Keine ideale Spawn-Position gefunden, Respawn abgebrochen.")
		return  # Fledermaus wird nicht gespawnt, wenn keine gültige Position gefunden wird

	# Debugging: Zeige, wo die Fledermaus gespawnt wird
	print("Fledermaus respawned bei:", new_position)

	# Stelle sicher, dass die Fledermaus sichtbar und aktiv ist
	global_position = new_position
	show()
	set_deferred("collision_layer", 1)
	set_deferred("collision_mask", 1)
	modulate = Color(1, 1, 1, 1)  # Falls sie unsichtbar bleibt
	is_dead = false
	health = 100
