extends CharacterBody2D

const GRAVITY = 5
const SPEED = 500

func _process(delta):
	var move = Vector2(0, GRAVITY)
	
	if Input.is_action_pressed("left"):
		move.x = -1
	
	if Input.is_action_pressed("right"):
		move.x = 1
		
	if Input.is_action_pressed("up"):
		move.y = -8

	velocity = move * SPEED
	move_and_slide()
