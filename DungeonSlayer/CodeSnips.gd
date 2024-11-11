extends CharacterBody2D

# Konstanten für die Bewegung und Sprünge
const SPEED = 300.0
const GRAVITY = 1200.0  # Erhöhte Schwerkraft für schnelleres Fallen
const JUMP_VELOCITY = -550.0  # Weniger starkes normales Springen
const WALL_JUMP_VELOCITY_X = 200.0  # Weniger starkes seitliches Abspringen von der Wand
const WALL_JUMP_VELOCITY_Y = -500.0  # Weniger starkes vertikales Abspringen
const WALL_SLIDE_SPEED = 500.0  # Minimal langsamer als das normale Fallen

# Variablen für die Laufrichtung und den Wall-Jump-Status
var direction := Vector2.ZERO
var is_wall_sliding := false
var can_wall_jump := true
var last_wall_normal := Vector2.ZERO

func _physics_process(delta: float) -> void:
	# Gravitation anwenden, wenn nicht auf dem Boden
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Überprüfen, ob der Charakter an einer Wand ist
	if is_on_wall() and not is_on_floor() and velocity.y > 0:
		is_wall_sliding = true
		# Geschwindigkeit beim Rutschen an der Wand minimal begrenzen
		if velocity.y > WALL_SLIDE_SPEED:
			velocity.y = WALL_SLIDE_SPEED
		# Überprüfen, ob der Spieler sich auf einer neuen Wand befindet
		var current_wall_normal = get_wall_normal()
		if current_wall_normal != last_wall_normal:
			can_wall_jump = true  # Wall Jump zurücksetzen, wenn die Wand anders ist
			last_wall_normal = current_wall_normal
	else:
		is_wall_sliding = false
		if is_on_floor():
			can_wall_jump = true  # Wall Jump zurücksetzen, wenn auf dem Boden

	# Sprung ausführen
	if Input.is_action_just_pressed("up"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_wall_sliding and can_wall_jump:
			# Wall Jump ausführen
			velocity.y = WALL_JUMP_VELOCITY_Y
			velocity.x = direction.x * -WALL_JUMP_VELOCITY_X
			can_wall_jump = false  # Wall Jump deaktivieren, bis zurückgesetzt

	# Horizontale Bewegung basierend auf der Eingabe
	direction.x = Input.get_axis("left", "right")
	if direction.x != 0:
		velocity.x = direction.x * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Bewegen und gleiten lassen
	move_and_slide()

	# Animation einstellen
	set_animation()

# Funktion zum Einstellen der Animation
func set_animation():
	if direction.x < 0:
		$PlayerSprite.flip_h = true
		$AnimationPlayer.play("walk")
	elif direction.x > 0:
		$PlayerSprite.flip_h = false
		$AnimationPlayer.play("walk")

	if direction.x == 0:
		$AnimationPlayer.play("idle")

	if is_in_air():
		$AnimationPlayer.play("jump")

func is_in_air():
	return not is_on_floor()
