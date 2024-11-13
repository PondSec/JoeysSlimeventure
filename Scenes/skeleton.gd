extends CharacterBody2D

# Constants for AI movement and physics
const SPEED = 150.0  # Speed of the enemy
const GRAVITY = 1200.0  # Gravity applied to the enemy
const DETECTION_RADIUS = 200.0  # The radius in which the enemy will detect the player

# Reference to the player
var player: CharacterBody2D
var is_dead := false  # State of the enemy (alive or dead)
var health := 50  # Health of the enemy

# Direction of the enemy
var direction := Vector2.ZERO

# Whether the enemy is attacking
var is_attacking := false

# Attack range
const ATTACK_RANGE = 50.0  # Distance at which the enemy will attack the player

func _ready() -> void:
	# Get reference to the player
	player = get_node("/root/Game/PlayerModel")  # Corrected player node path

func _physics_process(delta: float) -> void:
	if is_dead:
		return  # If the enemy is dead, do nothing
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if player:  # Check if the player exists
		# Calculate distance to the player
		var distance_to_player = global_position.distance_to(player.global_position)
		
		# Move towards the player if within detection range
		if distance_to_player <= DETECTION_RADIUS:
			# Move toward the player
			direction = (player.global_position - global_position).normalized()
			velocity.x = direction.x * SPEED

			# If the enemy is close enough, attack
			if distance_to_player <= ATTACK_RANGE and not is_attacking:
				attack()
		else:
			velocity.x = 0  # Stop moving if the player is out of detection range

	# Handle movement and collision
	move_and_slide()

	# Set the animation based on the state
	set_animation()

	# Check if the enemy is hit by the player's attack
	check_for_damage()

# Function to check if the player attacks the enemy
func check_for_damage():
	# Assume the player causes damage via an attack area (like an "AttackArea" node)
	if player and player.is_attacking:
		var attack_area = player.get_node("AttackSprite/AttackArea")  # Attack area of the player
		if attack_area and attack_area.get_overlapping_bodies().has(self):
			take_damage(25)  # Deal damage

# Function to deal damage to the enemy
func take_damage(amount: int):
	if is_dead:
		return  # Do nothing if the enemy is already dead

	health -= amount  # Decrease health
	if health <= 0:
		die()  # If health is 0 or less, the enemy dies

# Function to make the enemy die
func die():
	is_dead = true
	$AnimatedSprite.play("death")  # Play the death animation
	velocity = Vector2.ZERO  # Stop the movement
	$CollisionShape2D.disabled = true  # Disable collision
	await get_tree().create_timer(1.0).timeout  # Wait for the death animation to finish
	queue_free()  # Remove the enemy from the scene

# Function to set the enemy's animation
func set_animation():
	if is_attacking:
		$AnimatedSprite.play("attack")  # Play the attack animation if attacking
	elif direction.x != 0:
		$AnimatedSprite.flip_h = direction.x < 0  # Flip the sprite based on direction
		$AnimatedSprite.play("walk")  # Play walk animation
	else:
		$AnimatedSprite.play("idle")  # Play idle animation if the enemy is not moving

# Function to make the enemy attack
func attack():
	is_attacking = true
	$AnimatedSprite.play("attack")  # Play the attack animation
	# Here you can also deal damage to the player, check for collision with the player, etc.
	# For now, it's just the animation that gets triggered
	await get_tree().create_timer(1.0).timeout  # Wait for the attack animation to finish
	is_attacking = false  # Reset attack state after animation is finished
