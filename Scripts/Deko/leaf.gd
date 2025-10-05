extends RigidBody2D

@export var player_force: float = 100.0
@export var torque_force: float = 100.0
@export var upward_force_min: float = 100.0
@export var upward_force_max: float = 200.0
@export var wind_force_min: float = 15.0
@export var wind_force_max: float = 35.0
@export var turbulence_force: float = 20.0
@export var direction_change_time: float = 1.0  # Weniger häufige Richtungswechsel
@export var lifetime: float = 10.0  # Lebenszeit in Sekunden
@export var fade_duration: float = 2.0  # Dauer des Ausblend-Effekts

var wind_direction: Vector2 = Vector2.ZERO
var wind_timer: float = 0.0
var current_wind_force: float = 0.0
var is_airborne: bool = true
var sleep_timer: float = 0.0
var lifetime_timer: float = 0.0
var is_fading: bool = false

func _ready():
	# Zufällige Startwerte
	randomize()
	current_wind_force = randf_range(wind_force_min, wind_force_max)
	update_wind_direction()
	
	# Leichte zufällige Startrotation
	angular_velocity = randf_range(-1.0, 1.0)
	
	# Lebenszeit-Timer starten
	lifetime_timer = lifetime

func _physics_process(delta):
	# Lebenszeit verwalten
	if not is_fading:
		lifetime_timer -= delta
		if lifetime_timer <= fade_duration and lifetime_timer > 0:
			start_fade_out()
		elif lifetime_timer <= 0:
			queue_free()
	
	# Prüfen ob das Objekt zur Ruhe kommt
	check_airborne_status()
	
	if is_airborne:
		# Nur Wind und Turbulenzen anwenden, wenn in der Luft
		wind_timer -= delta
		if wind_timer <= 0:
			update_wind_direction()
			wind_timer = randf_range(direction_change_time * 0.8, direction_change_time * 1.2)
		
		# Sanftere Windkraft anwenden
		apply_central_force(wind_direction * current_wind_force)
		
		# Weniger häufige und sanftere Turbulenzen
		if randf() < 0.15:  # Nur 15% Chance für Turbulenz
			apply_turbulence()
	else:
		# Am Boden: Rotation stoppen und stabilisieren
		stabilize_on_ground()

func start_fade_out():
	if is_fading:
		return
	
	is_fading = true
	var sprite = $Sprite2D  # Annahme: Der Sprite-Node heißt "Sprite2D"
	var tween = create_tween()
	
	# Transparenz-Effekt mit lerp über fade_duration Sekunden
	tween.tween_method(set_alpha, 1.0, 0.0, fade_duration)
	tween.tween_callback(queue_free)

func set_alpha(alpha: float):
	var sprite = $Sprite2D
	if sprite:
		sprite.modulate.a = alpha

func check_airborne_status():
	# Prüfen ob das Objekt sich kaum noch bewegt
	if linear_velocity.length() < 10.0 and abs(angular_velocity) < 0.5:
		sleep_timer += get_physics_process_delta_time()
		if sleep_timer > 0.5:  # Nach 0.5 Sekunden Stillstand als "am Boden" betrachten
			is_airborne = false
	else:
		sleep_timer = 0.0
		is_airborne = true

func stabilize_on_ground():
	# Dämpfung erhöhen um Objekt zur Ruhe kommen zu lassen
	linear_damp = 5.0
	angular_damp = 8.0
	
	# Sanft Rotation auf 0 bringen
	if abs(rotation) > 0.01:
		angular_velocity = -rotation * 2.0  # Sanft zurück zur 0-Rotation
	else:
		rotation = 0.0
		angular_velocity = 0.0

func update_wind_direction():
	# Sanftere Windrichtung mit weniger Extremen
	var angle = randf_range(-PI * 0.2, PI * 0.2)  # Nur ±36 Grad um die Horizontale
	wind_direction = Vector2(cos(angle), sin(angle)).normalized()
	
	# Weniger Variation in der Windstärke
	current_wind_force = randf_range(wind_force_min, wind_force_max)

func apply_turbulence():
	# Sanftere Turbulenzen
	var turbulence = Vector2(
		randf_range(-turbulence_force, turbulence_force) * 0.7,
		randf_range(-turbulence_force * 0.3, turbulence_force * 0.5)
	)
	apply_central_impulse(turbulence)
	
	# Sehr leichten Drehimpuls hinzufügen
	apply_torque_impulse(randf_range(-torque_force * 0.1, torque_force * 0.1))

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") or is_in_group("enemies") or is_in_group("minions"):
		interact_with_player(body)

func interact_with_player(player):
	# Zurück in den "in der Luft" Zustand
	is_airborne = true
	sleep_timer = 0.0
	linear_damp = 0.0  # Dämpfung zurücksetzen
	angular_damp = 0.0
	
	var direction = (global_position - player.global_position).normalized()
	var actual_force = player_force * randf_range(0.8, 1.2)
	var actual_torque = torque_force * randf_range(0.7, 1.5)
	var upward_force = randf_range(upward_force_min, upward_force_max)
	
	# Etwas mehr Zufälligkeit in der Flugbahn
	var horizontal_variation = randf_range(-0.3, 0.3)
	var vertical_variation = randf_range(-0.2, 0.1)
	
	var force_vector = Vector2(
		(direction.x + horizontal_variation) * actual_force, 
		-upward_force + vertical_variation * actual_force
	)
	apply_central_impulse(force_vector)
	
	# Drehrichtung mit Variation
	var torque_direction = 1.0 if direction.x > 0 else -1.0
	torque_direction *= randf_range(0.8, 1.2)  # Weniger extreme Variation
	apply_torque_impulse(torque_direction * actual_torque)
	
	# Wind zurücksetzen
	update_wind_direction()
	wind_timer = direction_change_time
