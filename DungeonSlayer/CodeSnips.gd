extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -600.0

# Variable für die Laufrichtung
var direction := Vector2.ZERO

func _physics_process(delta: float) -> void:
	# Gravitation anwenden, wenn nicht auf dem Boden
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Sprung ausführen, wenn die Taste gedrückt wird und auf dem Boden
	if Input.is_action_just_pressed("up") and is_on_floor():
		velocity.y = JUMP_VELOCITY

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
	return is_on_floor() == false
