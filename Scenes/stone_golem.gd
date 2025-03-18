extends CharacterBody2D

const SPEED = 40.0  # Langsamer als die Fledermaus
const DETECTION_RADIUS = 300.0
const ATTACK_RANGE = 50.0
const ATTACK_COOLDOWN = 1.0  # Längere Angriffscooldown
const MIN_DISTANCE = 5.0
const RESPAWN_COOLDOWN = 5
const BASE_DETECTION_RADIUS = 150.0  # Kleinerer Radius für nicht-glühenden Spieler
const NAVIGATION_UPDATE_INTERVAL = 0.5  # Alle 0.5 Sekunden aktualisieren
const GRAVITY = 1000.0  # Schwerkraft
const JUMP_VELOCITY = -300.0  # Fallback für Sprung, falls benötigt

var navigation_update_timer = 0.0  # Timer für die Navigation
var is_dead := false
var golem_health := 200  # Mehr Gesundheit als die Fledermaus
var is_attacking := false
var attack_timer := 0.0
var knockback_velocity := Vector2.ZERO
var is_knocked_back := false
var golem_position: Vector2 = Vector2.ZERO  # Standardwert setzen
var save_load = preload("res://Scripts/SaveLoad.gd").new()
var is_immune = false
var is_stone_mantle_active := false  # Neue Variable, um den Zustand des Steinmantels zu verfolgen
var stone_mantle_cooldown := 15.0  # Cooldown für den Steinmantel in Sekunden
var stone_mantle_cooldown_timer := 0.0  # Timer für den Cooldown

var loot_table = [
	{ "scene": preload("res://Scenes/Items/golem_heart.tscn"), "chance": 0.02 },  # 2% (weniger häufig)
	{ "scene": preload("res://Scenes/Items/iron_nugget.tscn"), "chance": 0.05 },  # 5% (selten)
	{ "scene": preload("res://Scenes/Items/gold_nugget.tscn"), "chance": 0.01 },  # 1% (sehr selten)
	#{ "scene": preload("res://Scenes/Items/golem_core.tscn"), "chance": 0.005 }, # 0.5% (extrem selten)
	{ "scene": null, "chance": 0.70 }  # 70% Chance, dass nichts droppt (erschwert Farming)
]

var player: CharacterBody2D  # Spieler-Referenz
@export var spawn_zone_container: Node2D
@onready var animation_player = $Sprite2D/AnimationPlayer
@onready var navigation_agent = $NavigationAgent2D
@onready var visibility_notifier = $VisibleOnScreena
var camera: Camera2D

func _ready() -> void:
	randomize()
	add_to_group("enemies")
	add_to_group("golems")
	golem_position = global_position
	find_player()  # Spieler beim Start suchen
	var cameras = get_tree().get_nodes_in_group("main_camera")
	if cameras.size() > 0:
		camera = cameras[0]

func find_player() -> void:
	# Spieler im Szenenbaum suchen
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		player = players[0]  # Nehme den ersten gefundenen Spieler
	else:
		print("Warnung: Kein Spieler gefunden! Stelle sicher, dass der Spieler in der Gruppe 'player' ist.")

func _physics_process(delta: float) -> void:
	# Cooldown-Timer für den Steinmantel aktualisieren
	if stone_mantle_cooldown_timer > 0:
		stone_mantle_cooldown_timer -= delta

	if is_dead or player == null or player.current_health <= 0:
		velocity = Vector2.ZERO
		is_attacking = false
		set_animation()
		return

	# Schwerkraft anwenden
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Wenn der Steinmantel aktiv ist, keine Bewegungen oder Angriffe ausführen
	if is_stone_mantle_active:
		velocity = Vector2.ZERO  # Golem unbeweglich machen
		set_animation()
		move_and_slide()
		return  # Beende die Funktion, um weitere Logik zu überspringen

	# Normale Bewegungs- und Angriffslogik
	if is_knocked_back and not is_attacking:
		velocity = knockback_velocity
		knockback_velocity *= 1
		if knockback_velocity.length() < 10:
			is_knocked_back = false
	else:
		var distance_to_player = global_position.distance_to(player.global_position)
		var actual_detection_radius = DETECTION_RADIUS if player.is_glowing else BASE_DETECTION_RADIUS

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
				decide_ability()  # Zufällige Fähigkeit ausführen
		else:
			velocity.x = 0
			is_attacking = false

	move_and_slide()
	set_animation()

func activate_stone_mantle():
	if is_stone_mantle_active or stone_mantle_cooldown_timer > 0:
		return

	print("Steinmantel aktiviert")
	is_stone_mantle_active = true
	is_immune = true

	# Animation einmal abspielen und auf dem letzten Frame halten
	animation_player.play("stone_mantle")
	await animation_player.animation_finished  # Warte, bis die Animation fertig ist
	animation_player.stop()  # Stoppe die Animation
	animation_player.seek(animation_player.current_animation_length, true)  # Gehe zum letzten Frame

	# Warte 3 Sekunden, bis der Steinmantel endet
	await get_tree().create_timer(5.0).timeout

	# Steinmantel deaktivieren
	print("Steinmantel deaktiviert")
	is_stone_mantle_active = false
	is_immune = false
	animation_player.play("idle")  # Zurück zur Idle-Animation

func decide_ability():
	var ability = randi() % 5  # Erhöhe die Anzahl der Möglichkeiten auf 4
	match ability:
		0,1 :  # 25% Chance, einen Stein zu werfen
			spit_rock()
		2:  # 25% Chance, den Steinmantel zu aktivieren
			if not is_stone_mantle_active or stone_mantle_cooldown_timer <= 0:
				activate_stone_mantle()
		3, 4:  # 50% Chance, anzugreifen
			attack()

func spit_rock():
	var rock = preload("res://Scenes/Items/stone.tscn").instantiate()
	rock.global_position = global_position

	# Richtung berechnen
	var direction = (player.global_position - global_position).normalized()

	# Impuls auf den Stein anwenden
	rock.apply_impulse(direction * 100)  # Multipliziere mit einer Geschwindigkeit (z. B. 100)

	get_parent().add_child(rock)

func attack() -> void:
	if player and not is_dead:
		var is_critical = randf() < 0.4  # 10% Chance für einen kritischen Treffer
		if is_critical:
			perform_critical_hit()

		animation_player.play("attack")
		attack_timer = ATTACK_COOLDOWN
		is_attacking = true
		camera.shake(5.0, 0.3)  # Intensität und Dauer anpassen
		animation_player.connect("animation_finished", Callable(self, "_on_attack_animation_finished"))

func perform_critical_hit() -> void:
	activate_slow_motion(0.3, 0.5)
	camera.shake(10.0, 0.4)  # Intensität und Dauer anpassen

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
			var random_damage = int(randf_range(10.0, 20.0))  # Mehr Schaden als die Fledermaus
			if randf() < 0.1:
				random_damage *= 2  # Kritischer Treffer macht doppelten Schaden
			
			player.take_damage(random_damage, global_position)

		animation_player.disconnect("animation_finished", Callable(self, "_on_attack_animation_finished"))
		is_attacking = false
		set_animation()  # Stelle sicher, dass die Animation aktualisiert wird

func set_animation() -> void:
	if is_dead:
		return

	# Wenn der Steinmantel aktiv ist, keine andere Animation abspielen
	if is_stone_mantle_active:
		return  # Die Animation bleibt auf dem letzten Frame stehen

	# Normale Animationen
	if velocity.x != 0:
		$Sprite2D.scale.x = -1 if velocity.x < 0 else 1

	if is_attacking:
		animation_player.play("attack")
	elif velocity.length() > 0:
		animation_player.play("walk")  # Gehen statt Fliegen
	else:
		animation_player.play("idle")

func take_damage(amount: int) -> void:
	if is_dead or is_stone_mantle_active:
		return  # Kein Schaden, wenn der Golem tot ist oder der Steinmantel aktiv ist
		
	decide_ability()
	# Normaler Schaden, wenn der Steinmantel nicht aktiviert wurde
	golem_health -= amount
	flash_red()  # Blink-Effekt hinzufügen

	if not is_attacking:  # Nur Knockback anwenden, wenn der Golem nicht angreift
		apply_knockback()

	if golem_health <= 0:
		die()

func flash_red():
	var sprite = $Sprite2D
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0, 0), 0.2)  # Rote Farbe für 0.1 Sek.
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)  # Zurück zur normalen Farbe

func apply_knockback():
	if player and not is_attacking:  # Nur Knockback anwenden, wenn der Golem nicht angreift
		var direction = (global_position - player.global_position).normalized()
		var knockback_strength = 5
		knockback_velocity = direction * knockback_strength
		is_knocked_back = true

		await get_tree().create_timer(0.3).timeout  # Knockback-Dauer
		is_knocked_back = false

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
	print("Golem spawnt bei:", new_position)

	# Setze die Position und aktiviere den Golem
	global_position = new_position
	show()
	set_deferred("collision_layer", 1)
	set_deferred("collision_mask", 1)
	modulate = Color(1, 1, 1, 1)
	is_dead = false
	golem_health = 150
