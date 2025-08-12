extends CharacterBody2D

# Einstellungen
const SPEED = 140.0
const FAST_SPEED = 220.0
const DETECTION_RADIUS = 300.0
const ATTACK_RANGE = 35.0
const ATTACK_COOLDOWN = 1
const MIN_DISTANCE = 10.0
const RESPAWN_COOLDOWN = 10
const BASE_DETECTION_RADIUS = 150.0
const NAVIGATION_UPDATE_INTERVAL = 0.5
const CRITICAL_HIT_CHANCE = 0.3
const DODGE_CHANCE = 0.25
const MAX_HEALTH = 50
const ACCELERATION = 8.0
const DECELERATION = 10.0

# Variablen
var navigation_update_timer = 0.0
var is_dead := false
var bat_health := MAX_HEALTH
var is_attacking := false
var attack_timer := 0.0
var knockback_velocity := Vector2.ZERO
var is_knocked_back := false
var is_stunned := false
var is_dodging := false
var last_dodge_time := 0.0
var bat_position: Vector2 = Vector2.ZERO
var player_last_seen_position: Vector2 = Vector2.ZERO
var time_since_last_seen := 0.0
var patrol_points := []
var current_patrol_index := 0
var should_attack := false

# Einstellungen
const PATROL_CHANCE = 0.9  # 30% Chance zu patrouillieren, wenn der Spieler nicht in Sicht ist
const PATROL_DURATION = 20.0  # Wie lange patrouilliert wird
const IDLE_DURATION = 0.1  # Wie lange sie ruhig bleibt

const CALL_COOLDOWN = 15.0  # Wie oft die Fledermaus rufen kann
const CALL_RANGE = 200.0    # In welchem Radius nach anderen Fledermäusen gesucht wird
var call_timer := 0.0
var can_call_for_help := true
const CALL_PROBABILITY = 0.1
var was_called = true  # True, wenn diese Fledermaus durch einen Ruf erstellt wurde

# Variablen
var is_patrolling := false
var patrol_timer := 0.0
var idle_timer := 0.0
var current_state = "patrol"  # Kann "idle", "patrol" oder "chase" sein

var normal_hit_streak := 0
var streak_reset_time := 2.0 # Sekunden ohne Treffer bis Reset
var streak_timer := 0.0

@export var player: CharacterBody2D
@export var spawn_zone_container: Node2D
@onready var animation_player = $Sprite2D/AnimationPlayer
@onready var navigation_agent = $NavigationAgent2D
@onready var hit_particles = $HitParticles
@onready var death_particles = $DeathParticles
@onready var sound_player = $SoundPlayer
@onready var health_bar = $HealthBar
@onready var detection_area = $DetectionArea
@onready var alert_icon = $AlertIcon
@onready var sprite = $Sprite2D
@export var current_speed := SPEED  # Standardwert ist SPEED

# Sound-Effekte
#var attack_sound = preload("res://Assets/Sounds/Bat_idle1.ogg")
var death_sound = preload("res://Assets/Sounds/Bat_death.ogg")
var hurt_sound = preload("res://Assets/Sounds/Bat_hurt2.ogg.mp3")
var dodge_sound = preload("res://Assets/Sounds/Bat_takeoff.ogg")

# Loot-Tabelle
var loot_table = [
	{ "scene": preload("res://Scenes/Items/bat_claw.tscn"), "chance": 0.08 },
	{ "scene": preload("res://Scenes/Items/copper_nugget.tscn"), "chance": 0.15 },
	{ "scene": preload("res://Scenes/Items/iron_nugget.tscn"), "chance": 0.05 },
	{ "scene": preload("res://Scenes/Items/gold_nugget.tscn"), "chance": 0.01 },
	{ "scene": preload("res://Scenes/Items/bat_artefact.tscn"), "chance": 0.005 }, #0.005
	{ "scene": null, "chance": 0.70 }
]

func _ready() -> void:
	randomize()
	add_to_group("enemies")
	add_to_group("bats")
	bat_position = global_position
	health_bar.visible = false
	alert_icon.visible = false
	alert_icon.text = "!"  # Stelle sicher, dass das Symbol ein ! ist
	generate_patrol_points()
	
	# Verbinde Area-Signale
	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_lost)
	
	# AudioStreamPlayer dynamisch erstellen
	sound_player = AudioStreamPlayer.new()
	sound_player.name = "SoundPlayer"  # Optional: Name für Debugging
	add_child(sound_player)  # WICHTIG: Node hinzufügen

func _physics_process(delta: float) -> void:
	
	if normal_hit_streak > 0:
		streak_timer += delta
		if streak_timer >= streak_reset_time:
			normal_hit_streak = 0
			streak_timer = 0.0
	
	if not can_call_for_help:
		call_timer -= delta
		if call_timer <= 0:
			can_call_for_help = true
	var can_attack_now = can_attack()
	if can_attack_now:
		if attack_timer <= 0.0:
			handle_attack(delta)  # Execute attack immediately when in range
			attack_timer = ATTACK_COOLDOWN  # Reset cooldown
		else:
			attack_timer -= delta  # Count down cooldown
	else:
		attack_timer = 0.0  # Reset timer when not in attack range
	if is_dead or player == null:
		return
		should_attack = can_attack()  # Zustand speichern
	
	if should_attack:
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack()
			
	update_health_bar()
	update_stealth()
	
	if is_stunned or player.current_health <= 0:
		velocity = Vector2.ZERO
		is_attacking = false
		set_animation()
		return
	
	if is_knocked_back:
		handle_knockback(delta)
	else:
		handle_state_machine(delta)  # Ersetzt handle_movement
	
	move_and_slide()
	set_animation()

func handle_state_machine(delta: float) -> void:
	var distance_to_player = global_position.distance_to(player.global_position)
	var actual_detection_radius = DETECTION_RADIUS if player.is_glowing else BASE_DETECTION_RADIUS
	
	if bat_health < MAX_HEALTH * 0.3 && can_call_for_help && current_state == "chase":
		if randf() < CALL_PROBABILITY:  # Zufallsprüfung
			call_for_help()
	
	# Nur verfolgen, wenn der Spieler im Detektionsradius ist
	if distance_to_player <= actual_detection_radius:
		current_state = "chase"
		player_last_seen_position = player.global_position
		time_since_last_seen = 0
	elif current_state == "chase":
		time_since_last_seen += delta
		# Nach 2 Sekunden ohne Sichtkontakt aufhören zu verfolgen
		if time_since_last_seen > 2.0:
			decide_next_state()
	
	# Zustandsausführung
	match current_state:
		"chase":
			# Nur verfolgen, wenn der Spieler noch im Radius ist
			if distance_to_player <= actual_detection_radius:
				handle_chase(delta, distance_to_player)
			else:
				velocity = Vector2.ZERO
				decide_next_state()
		"patrol":
			handle_patrol_state(delta)
		"idle":
			handle_idle_state(delta)

func decide_next_state() -> void:
	if randf() < PATROL_CHANCE:
		current_state = "patrol"
		patrol_timer = randf_range(PATROL_DURATION * 0.7, PATROL_DURATION * 1.3)  # Variation
		generate_patrol_points()
		current_patrol_index = 0
		
		# Manchmal zuerst kurz ruhig bleiben
		if randf() < 0.4:
			current_state = "idle"
			idle_timer = randf_range(0.5, 1.5)
	else:
		current_state = "idle"
		idle_timer = randf_range(IDLE_DURATION * 0.5, IDLE_DURATION * 2)  # Mehr Variation

func handle_patrol_state(delta: float) -> void:
	patrol_timer -= delta
	if patrol_timer <= 0:
		decide_next_state()
		return
	
	if patrol_points.size() > 0:
		var target_point = patrol_points[current_patrol_index]
		var distance_to_target = global_position.distance_to(target_point)
		
		# Punkt erreicht oder fast erreicht
		if distance_to_target < 15:
			# Kurze Pause machen (30% Chance)
			if randf() < 0.3 and idle_timer <= 0:
				idle_timer = randf_range(0.3, 1.0)
				return
			
			# Zum nächsten Punkt wechseln
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
			target_point = patrol_points[current_patrol_index]
		
		# Geschwindigkeit natürlich variieren
		var speed_variation = SPEED * randf_range(0.7, 1.3) * 0.6
		
		# Sanftere Bewegungen mit Navigation
		navigation_agent.target_position = target_point
		var next_path_pos = navigation_agent.get_next_path_position()
		var direction = (next_path_pos - global_position).normalized()
		
		# Flüssigere Beschleunigung/Verlangsamung
		var target_velocity = direction * speed_variation
		velocity = velocity.lerp(target_velocity, delta * 5)
		
		# Manchmal kleine Kursabweichungen
		if randf() < 0.02:
			velocity = velocity.rotated(randf_range(-0.2, 0.2))

func handle_idle_state(delta: float) -> void:
	idle_timer -= delta
	
	# Sanfte zufällige Bewegungen im Idle
	if randf() < 0.05:
		velocity = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	else:
		velocity = velocity.lerp(Vector2.ZERO, delta * 3)
	
	if idle_timer <= 0:
		decide_next_state()
		return

func handle_knockback(delta: float) -> void:
	velocity = knockback_velocity
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 5)
	if knockback_velocity.length() < 10:
		is_knocked_back = false
		apply_stun(0.7)

func handle_movement(delta: float) -> void:
	var distance_to_player = global_position.distance_to(player.global_position)
	var actual_detection_radius = DETECTION_RADIUS if player.is_glowing else BASE_DETECTION_RADIUS
	
	if distance_to_player <= ATTACK_RANGE:
		handle_attack(delta)
	elif distance_to_player <= actual_detection_radius:
		handle_chase(delta, distance_to_player)
	else:
		handle_patrol(delta)

func handle_attack(delta: float) -> void:
	if can_attack():  # Neue Hilfsfunktion
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack()

func can_attack() -> bool:
	return (player != null 
			and not is_dead 
			and not is_stunned 
			and not is_dodging 
			and global_position.distance_to(player.global_position) <= ATTACK_RANGE)

func handle_chase(delta: float, distance: float) -> void:
	if should_attack:
		return
	var actual_detection_radius = DETECTION_RADIUS if player.is_glowing else BASE_DETECTION_RADIUS
	
	# Nicht weiter verfolgen, wenn der Spieler außerhalb des Radius ist
	if distance > actual_detection_radius * 1.2:  # 20% Puffer
		velocity = Vector2.ZERO
		decide_next_state()
		return
	
	navigation_update_timer -= delta
	if navigation_update_timer <= 0:
		navigation_agent.target_position = player.global_position
		navigation_update_timer = NAVIGATION_UPDATE_INTERVAL
		player_last_seen_position = player.global_position
		time_since_last_seen = 0
	
	var direction = to_local(navigation_agent.get_next_path_position()).normalized()
	if distance > MIN_DISTANCE:
		var target_velocity = direction * SPEED
		velocity = velocity.lerp(target_velocity, delta * 10)  # Glättung hier
	else:
		velocity = velocity.lerp(Vector2.ZERO, delta * 10)  # Auch beim Stoppen glätten

func handle_patrol(delta: float) -> void:
	time_since_last_seen += delta
	if time_since_last_seen > 3.0 and patrol_points.size() > 0:
		# Patrouillieren
		if global_position.distance_to(patrol_points[current_patrol_index]) < 10:
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		
		navigation_agent.target_position = patrol_points[current_patrol_index]
		var direction = to_local(navigation_agent.get_next_path_position()).normalized()
		var target_velocity = direction * SPEED * 0.6
		velocity = velocity.lerp(target_velocity, delta * 10)  # Glättung hier
	else:
		# Zum letzten gesehenen Ort gehen
		if player_last_seen_position != Vector2.ZERO:
			navigation_agent.target_position = player_last_seen_position
			var direction = to_local(navigation_agent.get_next_path_position()).normalized()
			velocity = direction * SPEED * 0.8
			if global_position.distance_to(player_last_seen_position) < 10:
				player_last_seen_position = Vector2.ZERO

func generate_patrol_points() -> void:
	patrol_points.clear()
	var center = global_position
	var radius = randf_range(80, 180)  # Zufälliger Radius
	
	# Erstelle 3-5 Punkte in einer unregelmäßigen "Rundreise"
	var point_count = randi() % 3 + 3  # 3-5 Punkte
	for i in range(point_count):
		# Winkel mit zufälliger Variation
		var angle = (TAU / point_count) * i + randf_range(-0.3, 0.3)
		# Leichte Unregelmäßigkeit im Radius
		var point_radius = radius * randf_range(0.8, 1.2)
		var point = center + Vector2(cos(angle), sin(angle)) * point_radius
		
		# Stelle sicher, dass der Punkt nicht zu nah an anderen ist
		if patrol_points.size() > 0:
			while point.distance_to(patrol_points[-1]) < 50:
				angle += 0.2
				point = center + Vector2(cos(angle), sin(angle)) * point_radius
		
		patrol_points.append(point)
	
	# Manchmal einen zufälligen zusätzlichen Punkt hinzufügen
	if randf() < 0.3:
		patrol_points.append(center + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(50, 120))

func attack() -> void:
	if player and not is_dead:
		var is_critical = randf() < CRITICAL_HIT_CHANCE
		
		if is_critical:
			perform_critical_hit()
		else:
			#sound_player.stream = attack_sound
			sound_player.play()
		
		animation_player.play("attack")
		attack_timer = ATTACK_COOLDOWN  # Wird hier zurückgesetzt
		is_attacking = true
		animation_player.connect("animation_finished", Callable(self, "_on_attack_animation_finished"))
		print("Attack Timer: ", attack_timer, " | Dodging: ", is_dodging)

func dodge() -> void:
	is_dodging = true
	last_dodge_time = Time.get_ticks_msec()
	sound_player.stream = dodge_sound
	sound_player.play()
	
	var dodge_direction = Vector2.RIGHT if randi() % 2 == 0 else Vector2.LEFT
	dodge_direction = dodge_direction.rotated(randf_range(-PI/4, PI/4))
	knockback_velocity = dodge_direction * 200
	is_knocked_back = true
	
	var dodge_tween = create_tween()
	dodge_tween.tween_property(sprite, "modulate:a", 0.5, 0.1)
	dodge_tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	
	await get_tree().create_timer(0.4).timeout
	is_dodging = false

func perform_critical_hit() -> void:
	#sound_player.stream = attack_sound
	sound_player.pitch_scale = 1.5
	sound_player.play()
	
	# Screen Shake
	var shake_intensity = 15.0
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(0.5, shake_intensity)
	
	# Blitz-Effekt
	var flash_tween = create_tween()

func _on_attack_animation_finished(anim_name: String) -> void:
	if anim_name == "attack" and player:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= ATTACK_RANGE:
			var random_damage = int(randf_range(7.0, 17.0))
			if randf() < CRITICAL_HIT_CHANCE:
				random_damage *= 2
				show_damage_number(random_damage, true)
			else:
				show_damage_number(random_damage)
			
			player.take_damage(random_damage, global_position)
	
	animation_player.disconnect("animation_finished", Callable(self, "_on_attack_animation_finished"))
	is_attacking = false
	set_animation()

func show_damage_number(amount: int, is_critical: bool = false) -> void:
	var damage_text = str(amount)
	
	# Hitstreak erhöhen
	normal_hit_streak += 1
	streak_timer = 0.0
	
	var damage_label = RichTextLabel.new()
	damage_label.bbcode_enabled = true
	damage_label.fit_content = true
	damage_label.scroll_active = false
	damage_label.custom_minimum_size = Vector2(100, 100)
	
	if is_critical:
		damage_label.text = "[center][shake rate=30.0 level=15][tornado radius=5.0 freq=2.0][color=#FF2222][font_size=8]CRIT![/font_size][font_size=10] %s[/font_size][/color][/tornado][/shake][/center]" % damage_text
		
		var crit_sound = AudioStreamPlayer.new()
		crit_sound.stream = preload("res://Assets/Sounds/crit.mp3")
		crit_sound.pitch_scale = randf_range(2, 2.2)
		add_child(crit_sound)
		crit_sound.play()
		crit_sound.finished.connect(crit_sound.queue_free)
	else:
		var color := "#AAAAAA" # Standard Grau
		
		if normal_hit_streak == 2:
			color = "#04d9ff" # Blau
		elif normal_hit_streak == 3:
			color = "#FFFF00" # Gelb
		elif normal_hit_streak >= 5:
			color = "#FFA500" # Orange
		
		if normal_hit_streak > 5:
			# Schaden orange, Multiplier pink
			damage_label.text = "[center][font_size=10][wave amp=10.0 freq=3.0][color=%s]%s[/color][color=#FF00FF] x%s[/color][/wave][/font_size][/center]" % [color, damage_text, normal_hit_streak]
		else:
			damage_label.text = "[center][font_size=10][wave amp=10.0 freq=3.0][color=%s]%s[/color][/wave][/font_size][/center]" % [color, damage_text]
		
		var hit_sound = AudioStreamPlayer.new()
		hit_sound.stream = preload("res://Assets/Sounds/test.mp3")
		hit_sound.pitch_scale = randf_range(15, 15.5)
		add_child(hit_sound)
		hit_sound.play()
		hit_sound.finished.connect(hit_sound.queue_free)
	
	var x_offset = randf_range(-25, 25)
	damage_label.position = global_position + Vector2(x_offset, -40)
	damage_label.size = Vector2(40, 20)
	get_parent().add_child(damage_label)
	
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	var jump_height = -60 if is_critical else -40
	var jump_distance = x_offset * 1.5
	var jump_duration = 0.9 if is_critical else 0.7
	
	tween.tween_property(damage_label, "position:y", damage_label.position.y + jump_height, jump_duration)
	tween.tween_property(damage_label, "position:x", damage_label.position.x + jump_distance, jump_duration)
	
	if is_critical:
		var camera = get_viewport().get_camera_2d()
		if camera and camera.has_method("shake"):
			camera.shake(0.5, 25)
	
	if is_critical:
		damage_label.scale = Vector2(0.5, 0.5)
		tween.tween_property(damage_label, "scale", Vector2(1.2, 1.2), 0.2)
		tween.chain().tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.3)
	else:
		damage_label.scale = Vector2(0.6, 0.6)
		tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.2)
		tween.chain().tween_property(damage_label, "scale", Vector2(0.8, 0.8), 0.3)
	
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.6).set_delay(0.4)
	
	await tween.finished
	damage_label.queue_free()
	
	if is_critical:
		Engine.time_scale = 0.1
		await get_tree().create_timer(0.1).timeout
		Engine.time_scale = 1.0


func set_animation() -> void:
	if is_dead:
		return
	
	var flip_threshold = 5.0  # Mindestgeschwindigkeit, bevor geflippt wird
	if abs(velocity.x) > flip_threshold:
		sprite.scale.x = -1 if velocity.x < 0 else 1
	
	if is_attacking:
		animation_player.play("attack")
	elif is_stunned:
		animation_player.play("stunned")
	elif is_dodging:
		animation_player.play("dodge")
	elif current_state == "chase" and velocity.length() > 0:
		animation_player.play("flying")
	elif current_state == "patrol" and velocity.length() > 0:
		animation_player.play("idle")
	else:
		animation_player.play("idle")

func take_damage(amount: int, direction: Vector2, is_crit: bool = false) -> void:
	if is_dead or is_dodging:
		return
	
	# Apply crit multiplier if it's a crit
	var final_damage = amount
	if is_crit:
		final_damage = ceil(amount * 1.5)  # 50% more damage on crit
		# Play special crit effects
		perform_critical_hit_effects()
	
	# Schadensreduktion basierend auf der Entfernung
	var distance_factor = clamp(global_position.distance_to(player.global_position) / 100.0, 0.5, 1.0)
	final_damage = ceil(final_damage * distance_factor)
	
	bat_health -= final_damage
	show_damage_number(final_damage, is_crit)  # Pass is_crit to show different damage numbers
	
	sound_player.stream = hurt_sound
	sound_player.pitch_scale = randf_range(0.9, 1.1)
	sound_player.play()
	flash_red()
	apply_knockback()
	
	if bat_health <= 0:
		die()
	else:
		health_bar.visible = true
		get_tree().create_timer(2.0).timeout.connect(func(): health_bar.visible = false)

func perform_critical_hit_effects():
	# Screen Shake
	var shake_intensity = 15.0
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(0.5, shake_intensity)
	
	# Flash white
	var flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color(2, 2, 2), 0.1)
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	# Play crit sound
	var crit_sound = AudioStreamPlayer.new()
	crit_sound.stream = preload("res://Assets/Sounds/crit.mp3")
	add_child(crit_sound)
	crit_sound.play()
	crit_sound.finished.connect(crit_sound.queue_free)

func flash_red() -> void:
	var flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3), 0.1)
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func apply_knockback() -> void:
	if player:
		var direction = (global_position - player.global_position).normalized()
		var knockback_strength = 350
		knockback_velocity = direction * knockback_strength
		is_knocked_back = true

		await get_tree().create_timer(0.3).timeout
		is_knocked_back = false
		apply_stun(0.5)

func apply_stun(duration: float) -> void:
	is_stunned = true
	await get_tree().create_timer(duration).timeout
	is_stunned = false
	set_animation()

func die() -> void:
	is_dead = true
	animation_player.play("death")
	sound_player.stream = death_sound
	sound_player.volume_db = -20.0
	sound_player.play()
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	await animation_player.animation_finished
	hide()
	
	drop_loot()
	await get_tree().create_timer(RESPAWN_COOLDOWN).timeout
	respawn()

func drop_loot() -> void:
	var roll = randf()
	var cumulative_chance = 0.0
	
	for item in loot_table:
		cumulative_chance += item["chance"]
		if roll < cumulative_chance:
			if item["scene"] == null:
				return
			
			var dropped_item = item["scene"].instantiate()
			dropped_item.global_position = global_position
			dropped_item.apply_impulse(Vector2(randf_range(-50, 50), -100))
			dropped_item.apply_torque_impulse(randf_range(-10, 10))
			get_parent().add_child(dropped_item)
			return

func respawn() -> void:
	if was_called:  # Gerufene Fledermäuse respawnen nicht
		queue_free()  # Entferne sie komplett
		return
	bat_health = MAX_HEALTH
	is_dead = false
	is_stunned = false
	is_knocked_back = false
	global_position = get_random_spawn_position()
	show()
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	health_bar.visible = false

func get_random_spawn_position() -> Vector2:
	if not spawn_zone_container or spawn_zone_container.get_child_count() == 0:
		return global_position
	
	var spawn_areas = spawn_zone_container.get_children().filter(func(node): return node is Area2D)
	
	if spawn_areas.is_empty():
		return global_position

	var selected_area = spawn_areas[randi() % spawn_areas.size()]
	var shape = selected_area.get_node_or_null("CollisionShape2D")

	if shape and shape.shape is RectangleShape2D:
		var rect = shape.shape.extents * 2
		var top_left = selected_area.global_position - shape.shape.extents
		var random_pos = top_left + Vector2(randf_range(0, rect.x), randf_range(0, rect.y))
		return random_pos
	
	elif shape and shape.shape is CircleShape2D:
		var radius = shape.shape.radius
		var angle = randf_range(0, TAU)
		var distance = sqrt(randf()) * radius
		return selected_area.global_position + Vector2(cos(angle), sin(angle)) * distance

	return global_position

func update_health_bar() -> void:
	health_bar.value = bat_health
	health_bar.max_value = MAX_HEALTH
	health_bar.position = position + Vector2(0, -40)

func _on_player_detected(body: Node2D) -> void:
	if body == player:
		alert_icon.text = "!"
		alert_icon.visible = true
		var alert_tween = create_tween()
		alert_tween.tween_property(alert_icon, "scale", Vector2(1.5, 1.5), 0.2)
		alert_tween.tween_property(alert_icon, "scale", Vector2(1.0, 1.0), 0.1)
		# Nach 1 Sekunde unsichtbar machen
		await get_tree().create_timer(1.0).timeout
		if alert_icon.text == "!":  # Nur ausblenden, wenn es noch ein "!" ist
			alert_icon.visible = false

func _on_player_lost(body: Node2D) -> void:
	if body == player:
		# Ändere das Icon zu einem Fragezeichen
		alert_icon.text = "?"
		alert_icon.visible = true
		
		# Animation für das Fragezeichen
		var alert_tween = create_tween()
		alert_tween.tween_property(alert_icon, "scale", Vector2(1.5, 1.5), 0.2)
		alert_tween.tween_property(alert_icon, "scale", Vector2(1.0, 1.0), 0.1)
		
		# Nach 0.5 Sekunden unsichtbar machen
		await get_tree().create_timer(0.5).timeout
		alert_icon.visible = false
		alert_icon.text = "!"  # Zurück zum Ausrufezeichen für das nächste Mal

func call_for_help() -> void:
	if not can_call_for_help or is_dead:
		return
	
	# Überprüfe, ob bereits genug Fledermäuse in der Nähe sind
	var nearby_bats = 0
	for bat in get_tree().get_nodes_in_group("bats"):
		if bat != self and global_position.distance_to(bat.global_position) < CALL_RANGE:
			nearby_bats += 1
	
	# Wenn nicht genug Fledermäuse in der Nähe sind, spawne eine neue
	if nearby_bats < 2:  # Maximal 2 Fledermäuse in der Nähe
		spawn_new_bat()
	
	# Ruf-Cooldown setzen
	can_call_for_help = false
	call_timer = CALL_COOLDOWN
	show_call_icon()

func spawn_new_bat() -> void:
	var bat_scene = load("res://Scenes/albino_bat.tscn")  # Pfad anpassen
	var new_bat = bat_scene.instantiate()
	
	# Wichtige Variablen setzen
	new_bat.player = player
	new_bat.spawn_zone_container = spawn_zone_container
	
	new_bat.current_speed = FAST_SPEED
	# Position relativ zur aktuellen Fledermaus setzen
	new_bat.was_called = true
	var spawn_offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
	new_bat.global_position = global_position + spawn_offset
	
	# Zur Szene hinzufügen
	get_parent().add_child(new_bat)

func show_call_icon() -> void:
	alert_icon.text = "!?"
	alert_icon.visible = true
	
	# Animation für das Ruf-Icon
	var call_tween = create_tween()
	call_tween.tween_property(alert_icon, "scale", Vector2(1.8, 1.8), 0.2)
	call_tween.tween_property(alert_icon, "scale", Vector2(1.0, 1.0), 0.2)
	
	# Nach 1 Sekunde unsichtbar machen
	await get_tree().create_timer(1.0).timeout
	alert_icon.visible = false
	alert_icon.text = "!"  # Zurück zum normalen Alert-Icon


func update_stealth():
	var light_influence = get_light_influence_at_position(global_position)
	# Smooth transition between transparency levels
	# Fully visible (1.0) when in bright light, semi-transparent (0.2) in darkness
	modulate.a = lerp(0.2, 1.0, light_influence)

func get_light_influence_at_position(pos: Vector2) -> float:
	var total_light = 0.0
	var max_light_influence = 0.0
	
	# Check all light sources in the scene
	for light in get_tree().get_nodes_in_group("lights"):
		if light.is_visible_in_tree() and light.enabled:  # Use 'enabled' instead of 'is_on'
			var distance = pos.distance_to(light.global_position)
			# Get light radius - different methods for different light types
			var light_radius = 0.0
			if light is PointLight2D:
				light_radius = light.texture_scale * light.texture.get_size().length() / 2.0
			elif light.has_method("get_radius"):  # Fallback for custom light types
				light_radius = light.get_radius()
			
			if distance <= light_radius:
				# Smooth light falloff using inverse square law
				var normalized_distance = distance / light_radius
				var falloff = 1.0 / (1.0 + 10.0 * normalized_distance * normalized_distance)
				total_light += light.energy * falloff
				max_light_influence = max(max_light_influence, light.energy)
	
	if max_light_influence > 0:
		return clamp(total_light / max_light_influence, 0.0, 1.0)
	return 0.0  # No light influence
