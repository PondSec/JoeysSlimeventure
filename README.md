# Joey's Slimeventure

*Depths of the Ooze* is an action-packed platformer game currently in beta, developed using the Godot 4.3 engine. Players take on the role of a daring hero who must navigate through perilous dungeons, conquer various enemies, and defeat powerful mini-bosses.

## Game Description

In *Depths of the Ooze*, you control your character through treacherous dungeons filled with traps, enemies, and platforming challenges. The game combines fast-paced combat with precision movement, where every decision can lead to life or death. With each level, you’ll face tougher enemies and more complex obstacles, pushing your reflexes and combat skills to the limit.

---

## Player Abilities

The player in *Depths of the Ooze* is equipped with a variety of abilities to traverse the dungeon and fight foes:

1. **Running**: Move quickly left or right to dodge enemies, avoid hazards, or engage in combat.
2. **Jumping**: Jump to reach higher platforms, clear gaps, and navigate vertically challenging areas.
3. **Wall-Sliding**: Slide down walls to slow your fall, helping you land safely or set up for a wall jump.
4. **Wall-Jumping**: Jump off walls to reach difficult areas or escape dangerous situations, adding depth and fluidity to vertical movement.
5. **Glowing**: The player has a special ability to toggle glowing, which is useful for illuminating dark areas or triggering certain mechanics.
6. **Attacking**: The player can attack using a sword, which is triggered by pressing a button. The sword has a specific animation and can cause damage to enemies.

---

## Skeleton Enemy

The **Skeleton** is one of the primary enemies in *Depths of the Ooze*. It is a basic enemy that can deal damage to the player when close. It has its own set of behaviors:

### Skeleton Behavior
- **Movement**: The skeleton can walk left and right and may patrol certain areas or chase the player when in range.
- **Attack**: The skeleton has a simple melee attack. When it detects the player nearby, it will move towards them and try to deal damage.
- **Health**: The skeleton has a health bar that decreases when it takes damage from the player or environmental hazards.
- **Death**: When the skeleton's health reaches zero, it will play a death animation and be removed from the scene.

### Skeleton Code Explanation
The Skeleton is implemented as an `Area2D` in Godot and has an `AnimatedSprite2D` for its animation. It checks for the player's attack and reduces its health accordingly.

```gdscript
extends Area2D

var health := 50
var is_alive := true

# Reference to the health bar for visual feedback
onready var health_bar = $HealthBar

# Function to handle damage taken by the skeleton
func take_damage(damage: int):
    if is_alive:
        health -= damage
        health_bar.value = health
        if health <= 0:
            die()

# Function to handle the death of the skeleton
func die():
    is_alive = false
    # Play death animation or effect here
    queue_free()  # Remove the skeleton from the scene
```

---

## Attacking

The player's primary form of combat is through a sword attack. When the player presses the attack button, an animation plays, and if the sword collides with an enemy like the Skeleton, it will take damage. Here’s a breakdown of how the attack works:

1. **Attack Activation**: When the player presses the attack button, the sword becomes visible, and an attack animation is triggered.
2. **Collision Detection**: The sword is an `Area2D` with a collision shape (often a small rectangle or circle) that will detect enemies in range.
3. **Damage Application**: If an enemy is within the attack area, the `take_damage()` function is called on the enemy, reducing its health.
4. **Attack Animation**: The sword has an animation that plays when the player attacks, and it is visible only during the attack.

### Player Attack Code

The player's attack is managed by the following code in the `Player` script:

```gdscript
extends CharacterBody2D

var is_attacking := false
var attack_sprite: AnimatedSprite2D

func _ready():
    attack_sprite = $AttackSprite  # Reference to the AttackSprite node

func attack():
    if Input.is_action_just_pressed("Attack") and not is_attacking:
        is_attacking = true
        attack_sprite.visible = true  # Show the sword during attack
        attack_sprite.play("swing")  # Play attack animation

        # Wait for animation to finish and then hide the sword
        attack_sprite.connect("animation_finished", Callable(self, "_on_attack_animation_finished"))

func _on_attack_animation_finished():
    is_attacking = false
    attack_sprite.visible = false  # Hide the sword after the attack
    attack_sprite.disconnect("animation_finished", Callable(self, "_on_attack_animation_finished"))

# Collision detection for the sword
func _check_attack_collision():
    if is_attacking:
        var attack_area = $AttackSprite.get_node("AttackArea")  # Node for the attack collision
        var enemies = attack_area.get_overlapping_bodies()

        for enemy in enemies:
            if enemy.is_in_group("enemies"):  # Check if the object is an enemy
                enemy.take_damage(25)  # Deal 25 damage to the enemy
```

---

## Technical Details

### 1. **Game Environment**
   - The game currently consists of two main layers:
     - **Background**: Aesthetic graphics that enhance the dungeon atmosphere.
     - **Foreground**: The active layer where the player and interactable objects reside.
   - The **camera** follows the player smoothly, dynamically adjusting to ensure optimal gameplay without abrupt shifts.

### 2. **Player Object**
   - The main character is created using the **"PlayerModel"** node in Godot. Built on the `CharacterBody2D` class, this object provides built-in functionality for movement and collision handling.

### 3. **Skeleton Object**
   - The skeleton is represented by an `Area2D` node that detects the player's presence and reacts accordingly. When attacked, it takes damage, and when its health reaches zero, it dies and disappears.

---

## Installation and Execution

1. Download the latest version of *Depths of the Ooze* from [this repository](#).
2. Open the project using Godot 4.3 or a compatible version.
3. Run the game directly within the Godot editor or export it to your desired platform.

## License and Distribution

The beta version of *Depths of the Ooze* is freely available, but commercial distribution or modification requires explicit permission from **Joshua Pond Studios**. For inquiries regarding distribution or commercial use, please contact us.

---

**Note**: This README is based on the current version of the game and will be updated with each new release. Thank you for supporting *Depths of the Ooze*!
