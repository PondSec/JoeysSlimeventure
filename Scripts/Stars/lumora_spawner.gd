extends Node2D

@export var lumora_scene: PackedScene
@export var spawn_chance: float = 0.05  # 5% Chance zu spawnen
@export var min_spawn_distance: float = 300.0
@export var max_spawn_distance: float = 500.0

var player: Node2D
var current_lumora: Node2D = null
var can_spawn: bool = true

func _ready():
	# Finde den Spieler
	player = get_tree().get_first_node_in_group("players")
	
	# 🔥 NEU: Prüfe zuerst ob bereits eine permanente Lumora existiert
	if _has_permanent_lumora():
		print("✅ Permanente Lumora gefunden - kein Spawning nötig")
		return
	
	# Starte Spawn-Check nur wenn keine permanente Lumora existiert
	_start_spawn_check()

# 🔥 NEUE METHODE: Prüfe ob permanente Lumora existiert
func _has_permanent_lumora() -> bool:
	# Suche nach bereits existierenden permanenten Lumoras
	var lumoras = get_tree().get_nodes_in_group("lumora")
	for lumora in lumoras:
		if lumora.is_permanent:
			print("🎯 Permanente Lumora bereits in Szene gefunden")
			current_lumora = lumora
			return true
	
	# Prüfe ob Save-Datei existiert
	var save_path = "user://lumora_save_data.save"
	if FileAccess.file_exists(save_path):
		print("📁 Lumora Save-Datei existiert - sollte gespawnt werden")
		# Hier könnten wir die Lumora manuell spawnen
		_spawn_permanent_lumora()
		return true
	
	return false

# 🔥 NEUE METHODE: Spawne permanente Lumora aus Save-Daten
func _spawn_permanent_lumora():
	if lumora_scene == null:
		push_error("Lumora Scene nicht zugewiesen!")
		return
	
	current_lumora = lumora_scene.instantiate()
	
	# Positioniere Lumora beim Spieler
	if player:
		current_lumora.global_position = player.global_position + Vector2(50, 0)
	else:
		current_lumora.global_position = Vector2(500, 300)
	
	# Füge Lumora zur Szene hinzu
	get_parent().add_child(current_lumora)
	
	# Setze permanente Eigenschaften
	current_lumora.is_permanent = true
	current_lumora.is_caught = true
	
	# Weise sofort den Spieler zu
	if player:
		current_lumora.assign_player(player)
	
	print("✨ Permanente Lumora aus Save-Daten gespawnt!")

func _start_spawn_check():
	var check_timer = Timer.new()
	add_child(check_timer)
	check_timer.wait_time = 10.0  # Alle 10 Sekunden prüfen
	check_timer.autostart = true
	check_timer.timeout.connect(_try_spawn_lumora)
	check_timer.start()

func _try_spawn_lumora():
	# 🔥 NEU: Kein Spawning wenn bereits permanente Lumora existiert
	if _has_permanent_lumora() or current_lumora != null:
		return
	
	if not can_spawn or player == null:
		return
	
	# Zufällige Chance prüfen
	if randf() > spawn_chance:
		return
	
	# Spawn-Position berechnen
	var spawn_pos = _calculate_spawn_position()
	if spawn_pos != Vector2.ZERO:
		_spawn_lumora(spawn_pos)

func _calculate_spawn_position() -> Vector2:
	var viewport_rect = get_viewport().get_visible_rect()
	var player_pos = player.global_position
	
	# Mehrere Versuche für eine gute Position
	for i in range(10):
		var angle = randf() * 2 * PI
		var distance = randf_range(min_spawn_distance, max_spawn_distance)
		var spawn_pos = player_pos + Vector2(cos(angle), sin(angle)) * distance
		
		# Prüfe ob Position im Sichtbereich und frei ist
		if viewport_rect.has_point(spawn_pos) and _is_position_valid(spawn_pos):
			return spawn_pos
	
	return Vector2.ZERO

func _is_position_valid(pos: Vector2) -> bool:
	# Raycast um Hindernisse zu prüfen
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(player.global_position, pos)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0b1111
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _spawn_lumora(spawn_pos: Vector2):
	if lumora_scene == null:
		push_error("Lumora Scene nicht zugewiesen!")
		return
	
	current_lumora = lumora_scene.instantiate()
	current_lumora.global_position = spawn_pos
	current_lumora.player_path = NodePath("")  # Kein Player zugewiesen initially
	
	# Füge Lumora zur Szene hinzu
	get_parent().add_child(current_lumora)
	
	# Verbinde das Catch-Signal
	if current_lumora.has_signal("lumora_caught"):
		current_lumora.lumora_caught.connect(_on_lumora_caught)
	
	print("✨ Lumora ist erschienen!")
	
	# Visuellen Effekt für das Erscheinen
	_create_spawn_effect(spawn_pos)

func _create_spawn_effect(pos: Vector2):
	var particles = GPUParticles2D.new()
	add_child(particles)
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 50.0
	mat.spread = 180.0
	mat.gravity = Vector3(0, 0, 0)
	mat.initial_velocity = Vector2(80.0, 80.0)
	mat.scale = Vector2(2.0, 2.0)
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.8, 0.9, 1.0, 1.0))
	gradient.set_color(1, Color(0.6, 0.8, 1.0, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	mat.color_ramp = gradient_texture
	
	particles.process_material = mat
	particles.amount = 60
	particles.lifetime = 1.5
	particles.one_shot = true
	particles.global_position = pos
	particles.emitting = true
	
	# Soundeffekt
	# $SpawnSound.play()
	
	await get_tree().create_timer(2.0).timeout
	particles.queue_free()

func _on_lumora_caught(player_node: Node2D):
	print("🎉 Lumora wurde gefangen!")
	current_lumora = null
	
	# Cooldown bevor nächster Spawn möglich
	can_spawn = false
	await get_tree().create_timer(60.0).timeout  # 1 Minute Cooldown
	can_spawn = true

func _on_player_died():
	# Wenn Spieler stirbt, entferne Lumora
	if current_lumora != null:
		current_lumora.queue_free()
		current_lumora = null
