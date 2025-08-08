extends CharacterBody2D

const SPEED = 40.0
const DETECTION_RADIUS = 300.0
const ATTACK_RANGE = 50.0
const ATTACK_COOLDOWN = 1.0
const MIN_DISTANCE = 5.0
const RESPAWN_COOLDOWN = 5
const BASE_DETECTION_RADIUS = 150.0
const NAVIGATION_UPDATE_INTERVAL = 0.5
const GRAVITY = 1000.0
const JUMP_VELOCITY = -300.0
const NOTIFICATION_DURATION = 2.0

var navigation_update_timer = 0.0
var is_dead := false
var golem_health := 200
var is_attacking := false
var attack_timer := 0.0
var knockback_velocity := Vector2.ZERO
var is_knocked_back := false
var golem_position: Vector2 = Vector2.ZERO
var save_load = preload("res://Scripts/SaveLoad.gd").new()
var is_immune = false
var is_stone_mantle_active := false
var stone_mantle_cooldown := 15.0
var stone_mantle_cooldown_timer := 0.0
var player_detected := false
var notification_timer := 0.0
var current_notification := ""

var loot_table = [
	{ "scene": preload("res://Scenes/Items/golem_heart.tscn"), "chance": 0.02 },
	{ "scene": preload("res://Scenes/Items/iron_nugget.tscn"), "chance": 0.05 },
	{ "scene": preload("res://Scenes/Items/gold_nugget.tscn"), "chance": 0.01 },
	{ "scene": null, "chance": 0.70 }
]

var player: CharacterBody2D
@export var spawn_zone_container: Node2D
@onready var animation_player = $Sprite2D/AnimationPlayer
@onready var navigation_agent = $NavigationAgent2D
@onready var visibility_notifier = $VisibleOnScreena
@onready var notification_label = $NotificationLabel
var camera: Camera2D

func _ready() -> void:
	randomize()
	add_to_group("enemies")
	add_to_group("golems")
	golem_position = global_position
	find_player()
	notification_label.hide()
	var cameras = get_tree().get_nodes_in_group("main_camera")
	if cameras.size() > 0:
		camera = cameras[0]

func _process(delta: float) -> void:
	if notification_timer > 0:
		notification_timer -= delta
		if notification_timer <= 0:
			notification_label.hide()

func show_notification(text: String) -> void:
	current_notification = text
	notification_label.text = text
	
	# Farbe basierend auf Textinhalt setzen
	if text == "CRITICAL!":
		notification_label.add_theme_color_override("font_color", Color.RED)
		notification_label.add_theme_font_size_override("font_size", 22)  # Größer für kritische Treffer
	else:
		notification_label.add_theme_color_override("font_color", Color.WHITE)
		notification_label.add_theme_font_size_override("font_size", 18)  # Normale Größe
	
	notification_label.show()
	notification_timer = NOTIFICATION_DURATION
	
	# Animation für das Erscheinen
	var tween = get_tree().create_tween()
	notification_label.modulate.a = 0
	notification_label.position.y = -20
	tween.tween_property(notification_label, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(notification_label, "position:y", -40, 0.2).set_trans(Tween.TRANS_BACK)
	
	# Zusätzliche Effekte nur für kritische Treffer
	if text == "CRITICAL!":
		# Pulse-Effekt für kritische Treffer
		var pulse_tween = get_tree().create_tween()
		pulse_tween.tween_property(notification_label, "scale", Vector2(1.3, 1.3), 0.1)
		pulse_tween.tween_property(notification_label, "scale", Vector2(1.0, 1.0), 0.2)
		
		# Kamera-Shake für kritische Treffer
		if camera:
			camera.shake(0.3, 0.4)
func find_player() -> void:
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		player = players[0]
		if not player_detected:
			player_detected = true
			show_notification("!")
	else:
		print("Warnung: Kein Spieler gefunden!")

func _physics_process(delta: float) -> void:
	if stone_mantle_cooldown_timer > 0:
		stone_mantle_cooldown_timer -= delta

	if is_dead or player == null or player.current_health <= 0:
		velocity = Vector2.ZERO
		is_attacking = false
		set_animation()
		if player_detected and player != null and player.current_health <= 0:
			player_detected = false
			show_notification("?")
		return

	# Schwerkraft anwenden
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Steinmantel-Logik
	if is_stone_mantle_active:
		velocity = Vector2.ZERO
		set_animation()
		move_and_slide()
		return

	# Bewegungs- und Angriffslogik
	if is_knocked_back and not is_attacking:
		velocity = knockback_velocity
		knockback_velocity *= 1
		if knockback_velocity.length() < 10:
			is_knocked_back = false
	else:
		var distance_to_player = global_position.distance_to(player.global_position)
		var actual_detection_radius = DETECTION_RADIUS if player.is_glowing else BASE_DETECTION_RADIUS

		# Spieler verloren
		if player_detected and distance_to_player > actual_detection_radius:
			player_detected = false
			show_notification("?")
		
		# Spieler entdeckt
		if not player_detected and distance_to_player <= actual_detection_radius:
			player_detected = true
			show_notification("!")

		if distance_to_player <= ATTACK_RANGE:
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack()
		elif distance_to_player <= actual_detection_radius:
			navigation_update_timer -= delta
			if navigation_update_timer <= 0:
				navigation_agent.target_position = player.global_position
				navigation_update_timer = NAVIGATION_UPDATE_INTERVAL

			var direction = to_local(navigation_agent.get_next_path_position()).normalized()
			if distance_to_player > MIN_DISTANCE:
				velocity.x = direction.x * SPEED
			else:
				velocity.x = 0
				decide_ability()
		else:
			velocity.x = 0
			is_attacking = false

	move_and_slide()
	set_animation()

func activate_stone_mantle():
	if is_stone_mantle_active or stone_mantle_cooldown_timer > 0:
		return
	
	is_stone_mantle_active = true
	is_immune = true

	animation_player.play("stone_mantle")
	await animation_player.animation_finished
	animation_player.stop()
	animation_player.seek(animation_player.current_animation_length, true)

	await get_tree().create_timer(5.0).timeout

	is_stone_mantle_active = false
	is_immune = false
	animation_player.play("idle")
	stone_mantle_cooldown_timer = stone_mantle_cooldown

func decide_ability():
	var ability = randi() % 5
	match ability:
		0,1:
			spit_rock()
		2:
			if not is_stone_mantle_active or stone_mantle_cooldown_timer <= 0:
				activate_stone_mantle()
		3, 4:
			attack()

func spit_rock():
	var rock = preload("res://Scenes/Items/stone.tscn").instantiate()
	rock.global_position = global_position
	var direction = (player.global_position - global_position).normalized()
	rock.apply_impulse(direction * 100)
	get_parent().add_child(rock)

func attack() -> void:
	if player and not is_dead:
		var is_critical = randf() < 0.4
		if is_critical:
			perform_critical_hit()
		animation_player.play("attack")
		attack_timer = ATTACK_COOLDOWN
		is_attacking = true
		camera.shake(5.0, 0.3)
		animation_player.connect("animation_finished", Callable(self, "_on_attack_animation_finished"))

func perform_critical_hit() -> void:
	activate_slow_motion(0.3, 0.5)
	camera.shake(10.0, 0.4)

func activate_slow_motion(duration: float, scale: float) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration).timeout
	Engine.time_scale = 1.0

func _on_attack_animation_finished(anim_name: String) -> void:
	if anim_name == "attack" and player:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= ATTACK_RANGE:
			var random_damage = int(randf_range(10.0, 20.0))
			if randf() < 0.1:
				random_damage *= 2
			
			player.take_damage(random_damage, global_position)

		animation_player.disconnect("animation_finished", Callable(self, "_on_attack_animation_finished"))
		is_attacking = false
		set_animation()

func set_animation() -> void:
	if is_dead:
		return

	if is_stone_mantle_active:
		return

	if velocity.x != 0:
		$Sprite2D.scale.x = -1 if velocity.x < 0 else 1

	if is_attacking:
		animation_player.play("attack")
	elif velocity.length() > 0:
		animation_player.play("walk")
	else:
		animation_player.play("idle")

func take_damage(amount: int) -> void:
	if is_dead or is_stone_mantle_active:
		return
		
	show_notification(str(amount))
	decide_ability()
	golem_health -= amount
	flash_red()

	if not is_attacking:
		apply_knockback()

	if golem_health <= 0:
		die()

func flash_red():
	var sprite = $Sprite2D
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0, 0), 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)

func apply_knockback():
	if player and not is_attacking:
		var direction = (global_position - player.global_position).normalized()
		var knockback_strength = 5
		knockback_velocity = direction * knockback_strength
		is_knocked_back = true

		await get_tree().create_timer(0.3).timeout
		is_knocked_back = false

func die():
	is_dead = true
	animation_player.play("death")
	velocity = Vector2.ZERO
	await animation_player.animation_finished
	hide()

	drop_loot()
	
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)  
	await get_tree().create_timer(RESPAWN_COOLDOWN).timeout
	spawn_near_player()

func drop_loot():
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

func spawn_near_player() -> void:
	if not player:
		return

	var new_position = get_random_spawn_position()
	global_position = new_position
	show()
	set_deferred("collision_layer", 1)
	set_deferred("collision_mask", 1)
	modulate = Color(1, 1, 1, 1)
	is_dead = false
	golem_health = 150
	player_detected = false
