extends CharacterBody2D

@export var crawl_speed: float = 80.0
@export var flee_speed: float = 150.0
@export var flee_jump_force: float = -300.0  # Negative Werte = nach oben
@export var nest_jump_force: float = -150.0  # Sprungkraft beim Einführen
@export var spawn_chance: float = 1 #0.05  # 5% Chance

# Gravitation für den Wurm
const GRAVITY: float = 980.0
const MAX_FALL_SPEED: float = 200.0

var player: Node2D
var is_fleeing: bool = false
var is_nesting: bool = false
var is_retreating: bool = false
var retreat_timer: float = 0.0
var nest_timer: float = 0.0

# Zustände
enum {IDLE, CRAWL_TO_PLAYER, FLEE, RETREAT, NESTING}
var state: int = IDLE

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	# Finde den Spieler
	player = get_tree().get_first_node_in_group("players")
	
	# Starte im Idle-Zustand
	set_physics_process(false)
	visible = false
	
	# Verbinde zum Licht-Signal des Spielers
	if player and player.has_signal("glow_changed"):
		player.connect("glow_changed", _on_player_glow_changed)

func _physics_process(delta):
	# Gravitation immer anwenden
	apply_gravity(delta)
	
	match state:
		CRAWL_TO_PLAYER:
			crawl_to_player(delta)
		FLEE:
			flee_from_player(delta)
		RETREAT:
			handle_retreat(delta)
		NESTING:
			handle_nesting(delta)
	
	move_and_slide()

func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)

func _on_player_glow_changed(is_glowing: bool):
	if is_glowing:
		match state:
			CRAWL_TO_PLAYER:
				# Nur flüchten wenn der Wurm nah genug am Spieler ist
				if player and global_position.distance_to(player.global_position) < 100.0:
					start_fleeing()
				else:
					# Zu weit entfernt - einfach verschwinden
					start_retreat()
			NESTING:
				# Eingegrabener Wurm - flüchten
				start_fleeing()
	elif not is_glowing and state == IDLE:
		# Dunkelheit - Chance zu spawnen
		try_spawn_near_player()

func try_spawn_near_player():
	if player and randf() < spawn_chance:
		spawn_near_player()

func spawn_near_player():
	# Position in der Nähe des Spielers
	var spawn_distance = 150.0
	var angle = randf() * 2 * PI
	var offset = Vector2(cos(angle), sin(angle)) * spawn_distance
	
	global_position = player.global_position + offset
	visible = true
	set_physics_process(true)
	
	# Beginne zum Spieler zu kriechen
	state = CRAWL_TO_PLAYER
	is_nesting = false  # Wichtig: Noch nicht eingenistet!
	
	# Walk-Animation starten
	animation_player.play("walk")
	
	# Blickrichtung zum Spieler
	update_facing_direction()
	
	print("Wurm spawns und kriecht zum Spieler")

func update_facing_direction():
	if not player:
		return
	
	# Sprite drehen basierend auf Bewegungsrichtung
	if player.global_position.x > global_position.x:
		sprite.flip_h = false  # Nach rechts schauen
	else:
		sprite.flip_h = true   # Nach links schauen

func crawl_to_player(delta):
	if not player:
		state = IDLE
		return
	
	# Bewege dich horizontal zum Spieler
	var direction_x = sign(player.global_position.x - global_position.x)
	velocity.x = direction_x * crawl_speed
	
	# Blickrichtung aktualisieren
	update_facing_direction()
	
	# Wenn nah genug am Spieler, beginne einzunisten
	if global_position.distance_to(player.global_position) < 50.0:
		start_nesting()

func start_nesting():
	state = NESTING
	is_nesting = true  # Jetzt erst ist der Wurm eingenistet
	nest_timer = 1.0  # 1-2 Sekunden zum Einführen
	
	# Stoppe horizontale Bewegung, aber springe nach oben
	velocity.x = 0
	velocity.y = nest_jump_force  # Springe nach oben!
	
	# Jump-Animation für das Einführen in den Spieler
	animation_player.play("jump")
	
	print("Wurm beginnt einzunisten - springt nach oben!")

func handle_nesting(delta):
	# Während des Nestings kann der Wurm noch springen/bewegen
	# Gravitation wirkt weiter
	
	nest_timer -= delta
	
	if nest_timer <= 0 and is_on_floor():
		# STEUERUNG INVERTIEREN
		invert_player_controls()
		print("Wurm hat sich eingenistet - Steuerung invertiert!")
		
		# Wurm wird unsichtbar
		visible = false
		self.collision_layer = 0
		animation_player.stop()

func invert_player_controls():
	# Setze invertierte Steuerung beim Spieler
	if player and player.has_method("set_controls_inverted"):
		player.set_controls_inverted(true)

func restore_player_controls():
	# Setze normale Steuerung beim Spieler zurück
	if player and player.has_method("set_controls_inverted"):
		player.set_controls_inverted(false)

func start_fleeing():
	if is_nesting:
		# Eingenisteter Wurm flüchtet
		self.collision_layer = 1
		visible = true
		jump_out_and_flee()
	else:
		# Normaler Flucht-Modus (während des Anschleichens)
		state = FLEE
		is_fleeing = true
		retreat_timer = 3.0
		
		# Springe beim Flüchten nach oben und weg
		var flee_direction = calculate_flee_direction()
		velocity.x = flee_direction.x * flee_speed
		velocity.y = flee_jump_force  # Springe nach oben!
		
		# Walk-Animation für Flucht
		animation_player.play("walk")
		
		print("Wurm flüchtet vor Licht mit Sprung!")

func calculate_flee_direction() -> Vector2:
	if not player:
		return Vector2(-1, 0)
	
	# Berechne Richtung weg vom Spieler
	var direction_away = (global_position - player.global_position).normalized()
	
	# Füge einen vertikalen Offset nach oben hinzu
	direction_away.y = -0.7  # Stärker nach oben
	
	return direction_away.normalized()

func jump_out_and_flee():
	# Positioniere den Wurm über dem Spielerkopf mit Offset
	global_position = player.global_position + Vector2(0, -20)  # Leicht über dem Kopf
	
	# Steuerung zurücksetzen
	restore_player_controls()
	is_nesting = false
	
	# Beginne zu flüchten mit Sprung
	state = FLEE
	is_fleeing = true
	retreat_timer = 3.0
	
	# Springe nach oben und weg
	var flee_direction = calculate_flee_direction()
	velocity.x = flee_direction.x * flee_speed
	velocity.y = flee_jump_force
	
	# Walk-Animation für Flucht
	animation_player.play("walk")
	
	print("Wurm springt aus dem Kopf heraus und flüchtet!")

func flee_from_player(delta):
	if not player:
		state = RETREAT
		return
	
	# Behalte die horizontale Fluchtrichtung bei
	var flee_direction = calculate_flee_direction()
	velocity.x = flee_direction.x * flee_speed
	
	# Blickrichtung aktualisieren (weg vom Spieler)
	update_flee_facing_direction()
	
	# Retreat-Timer
	retreat_timer -= delta
	if retreat_timer <= 0:
		start_retreat()

func update_flee_facing_direction():
	# Beim Fliehen: Sprite in Fluchtrichtung drehen
	if velocity.x > 0:
		sprite.flip_h = false  # Nach rechts fliehen
	else:
		sprite.flip_h = true   # Nach links fliehen

func start_retreat():
	state = RETREAT
	is_retreating = true
	
	# Stoppe Bewegung
	velocity = Vector2.ZERO
	
	# Down-Animation für das Verschwinden in den Boden
	animation_player.play("down")
	
	print("Wurm zieht sich in den Boden zurück")
	
	# Warte bis die Animation fertig ist und verschwinde dann
	await animation_player.animation_finished
	despawn()

func handle_retreat(delta):
	# Während der Retreat-Animation keine Bewegung
	velocity = Vector2.ZERO

func despawn():
	visible = false
	set_physics_process(false)
	state = IDLE
	is_fleeing = false
	is_retreating = false
	is_nesting = false
	velocity = Vector2.ZERO
	animation_player.stop()
	
	print("Wurm verschwindet")

# Debug Funktion
func debug_spawn():
	spawn_near_player()
