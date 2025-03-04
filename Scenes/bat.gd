extends CharacterBody2D

const SPEED = 140.0
const DETECTION_RADIUS = 500.0
const ATTACK_RANGE = 40.0
const ATTACK_COOLDOWN = 1.5
const MIN_DISTANCE = 5.0
const RESPAWN_COOLDOWN = 5
const BASE_DETECTION_RADIUS = 150.0  # Kleinerer Radius für nicht-glühenden Spieler
const NAVIGATION_UPDATE_INTERVAL = 0.5  # Alle 0.5 Sekunden aktualisieren

var navigation_update_timer = 0.0  # Timer für die Navigation
var is_dead := false
var bat_health := 50
var is_attacking := false
var attack_timer := 0.0
var knockback_velocity := Vector2.ZERO
var is_knocked_back := false
var is_stunned := false  # Neue Variable für Stun-Zustand
var bat_position: Vector2 = Vector2.ZERO  # Standardwert setzen
var save_load = preload("res://SaveLoad.gd").new()

var loot_table = [
	{ "scene": preload("res://Scenes/Items/bat_claw.tscn"), "chance": 0.12 },  # 12% Chance (seltener)
	{ "scene": preload("res://Scenes/Items/copper_nugget.tscn"), "chance": 0.22 },  # 22% Chance (häufiger)
	{ "scene": preload("res://Scenes/Items/iron_nugget.tscn"), "chance": 0.08 },  # 8% Chance (seltener)
	{ "scene": preload("res://Scenes/Items/gold_nugget.tscn"), "chance": 0.02 },  # 2% Chance (deutlich seltener)
	{ "scene": preload("res://Scenes/Items/bat_artefact.tscn"), "chance": 0.005}, #0.5% Chance (extrem selten)
	{ "scene": null, "chance": 0.535 }  # 54% Chance, dass nichts droppt (erschwert Loot-Farming)
]



@export var player: CharacterBody2D
@export var spawn_zone_container: Node2D
@onready var animation_player = $Sprite2D/AnimationPlayer
@onready var navigation_agent = $NavigationAgent2D
@onready var camera: Camera2D = $Camera2D  # Kamera für Effekte
@onready var visibility_notifier = $VisibleOnScreena

func _ready() -> void:
	randomize()
	add_to_group("enemies")
	add_to_group("bats")
	bat_position = global_position

func _physics_process(delta: float) -> void:
	if is_dead or is_stunned or player == null or player.current_health <= 0:
		velocity = Vector2.ZERO
		is_attacking = false
		set_animation()
		return

	if is_knocked_back:
		velocity = knockback_velocity
		knockback_velocity *= 0.9
		if knockback_velocity.length() < 10:
			is_knocked_back = false
			apply_stun(0.5)
	else:
		var distance_to_player = global_position.distance_to(player.global_position)
		var actual_detection_radius = DETECTION_RADIUS if player.is_glowing else BASE_DETECTION_RADIUS
		
		if distance_to_player <= ATTACK_RANGE:
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack()
		elif distance_to_player <= actual_detection_radius:
			# Aktualisiere Navigation nur alle NAVIGATION_UPDATE_INTERVAL Sekunden
			navigation_update_timer -= delta
			if navigation_update_timer <= 0:
				navigation_agent.target_position = player.global_position
				navigation_update_timer = NAVIGATION_UPDATE_INTERVAL  # Timer zurücksetzen
			
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
			
			player.take_damage(random_damage, global_position)

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

	bat_health -= amount
	flash_red()  # Blink-Effekt hinzufügen
	apply_knockback()  # Rückstoß hinzufügen

	if bat_health <= 0:
		die()

func flash_red():
	var sprite = $Sprite2D
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0, 0), 0.2)  # Rote Farbe für 0.1 Sek.
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)  # Zurück zur normalen Farbe

func apply_knockback():
	if player:
		var direction = (global_position - player.global_position).normalized()
		var knockback_strength = 350
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

	drop_loot()
	
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)  
	# Respawn-Delay
	await get_tree().create_timer(RESPAWN_COOLDOWN).timeout  
	spawn_near_player()

func drop_loot():
	var roll = randf()  # Zufallszahl zwischen 0.0 und 1.0
	var cumulative_chance = 0.0
	
	for item in loot_table:
		cumulative_chance += item["chance"]
		if roll < cumulative_chance:
			if item["scene"] == null:
				return  # Kein Loot droppt
			
			var dropped_item = item["scene"].instantiate()
			dropped_item.global_position = global_position
			dropped_item.apply_impulse(Vector2(randf_range(-50, 50), -100))  
			dropped_item.apply_torque_impulse(randf_range(-10, 10))  
			get_parent().add_child(dropped_item)
			return  # Stoppt die Funktion, sobald ein Item gedroppt wurde

func get_random_spawn_position() -> Vector2:
	if not spawn_zone_container or spawn_zone_container.get_child_count() == 0:
		print("FEHLER: Keine gültigen Spawn-Zonen gefunden!")
		return global_position  # Fallback auf aktuelle Position

	var spawn_areas = spawn_zone_container.get_children().filter(func(node): return node is Area2D)
	
	if spawn_areas.is_empty():
		print("FEHLER: Keine Area2D-Zonen gefunden!")
		return global_position

	var selected_area = spawn_areas[randi() % spawn_areas.size()]
	var shape = selected_area.get_node_or_null("CollisionShape2D")

	if shape and shape.shape is RectangleShape2D:
		var rect = shape.shape.extents * 2  # Volle Größe des Rechtecks
		var top_left = selected_area.global_position - shape.shape.extents
		var random_pos = top_left + Vector2(randf_range(0, rect.x), randf_range(0, rect.y))
		return random_pos
	
	elif shape and shape.shape is CircleShape2D:
		var radius = shape.shape.radius
		var angle = randf_range(0, TAU)
		var distance = sqrt(randf()) * radius  # Gleichmäßige Verteilung im Kreis
		return selected_area.global_position + Vector2(cos(angle), sin(angle)) * distance

	print("WARNUNG: Area2D hat keine gültige CollisionShape2D!")
	return global_position  # Fallback

func spawn_near_player() -> void:
	if not player:
		print("FEHLER: Kein Spieler gefunden!")
		return

	var new_position = get_random_spawn_position()

	# Debugging
	print("Fledermaus spawnt bei:", new_position)

	# Setze die Position und aktiviere die Fledermaus
	global_position = new_position
	show()
	set_deferred("collision_layer", 1)
	set_deferred("collision_mask", 1)
	modulate = Color(1, 1, 1, 1)
	is_dead = false
	bat_health = 50
