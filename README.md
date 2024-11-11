# Dungeon Slayer

*Dungeon Slayer* is a beta project developed using the Godot 4.3 engine. It is an exciting platformer where players must conquer levels, defeat various enemies, and face off against powerful mini-bosses.

## Game Description

In *Dungeon Slayer*, you control your character through challenging dungeons, master complex platforming sections, and fight against a variety of foes. Each dungeon offers a mix of quick reflexes, clever maneuvering, and intense combat.

---

## Player Abilities

The player in *Dungeon Slayer* has a variety of movement and interaction abilities to navigate the dungeon's challenges:

1. **Running**: The player can move quickly left or right to dodge obstacles, reach platforms, or fight enemies.
2. **Jumping**: The player can jump to cross gaps and reach higher platforms. The jumping mechanic allows for precise control.
3. **Wall-Sliding**: The player can slide down walls, slowing their fall when touching a wall. This is useful for safer landings or setting up a wall jump.
4. **Wall-Jumping**: The player can jump off walls to reach difficult platforming areas or escape tricky situations. This adds a dynamic and fluid movement element to vertical sections of the game.

---

## Technical Details

### 1. **Game Environment**
   - The game currently consists of two layers: **Background** and **Foreground**.
     - **Background**: Static or slowly moving graphics that enhance the depth and atmosphere of the dungeons.
     - **Foreground**: The layer where the player and all interactive objects exist. This is where the action happens.
   - The **camera** is configured to follow the player smoothly and dynamically, ensuring a pleasant experience by avoiding abrupt cuts.

### 2. **Player Object**
   - The main character is implemented as the **"PlayerModel"** object in the Godot engine. This object is based on the `CharacterBody2D` class, meaning it has built-in functionality for handling movement and collision.

---

## Detailed Code Explanation

The player object code manages all movement and interaction mechanics using Godot's `CharacterBody2D` class. Here's a detailed breakdown:

### 1. **Movement Constants and Variables**
   - **Constants**: These values define how the player behaves.
     - `SPEED = 300.0`: The speed at which the player moves horizontally.
     - `GRAVITY = 1200.0`: The force that pulls the player downward when in the air.
     - `JUMP_VELOCITY = -550.0`: The speed at which the player is launched upward when jumping.
     - `WALL_JUMP_VELOCITY_X = 200.0`: The horizontal speed when jumping off a wall.
     - `WALL_JUMP_VELOCITY_Y = -500.0`: The vertical speed when wall jumping.
     - `WALL_SLIDE_SPEED = 500.0`: The maximum speed at which the player can slide down a wall.
   - **Variables**:
     - `direction`: A `Vector2` that stores the player's current movement direction.
     - `is_wall_sliding`: A boolean that checks if the player is sliding down a wall.
     - `can_wall_jump`: A boolean that tracks if the player can perform a wall jump.
     - `last_wall_normal`: Stores the normal of the wall to check if the player is on a new wall.

### 2. **Gravity and Wall Logic**
   - The player is pulled down by gravity when not on the ground:
     ```gdscript
     if not is_on_floor():
         velocity.y += GRAVITY * delta
     ```
   - **Wall-Sliding**: The player's fall speed is reduced when touching a wall in the air:
     ```gdscript
     if is_on_wall() and not is_on_floor() and velocity.y > 0:
         is_wall_sliding = true
         if velocity.y > WALL_SLIDE_SPEED:
             velocity.y = WALL_SLIDE_SPEED
     ```
   - **Wall Detection**: Checks if the player is on a new wall to reset the wall jump:
     ```gdscript
     var current_wall_normal = get_wall_normal()
     if current_wall_normal != last_wall_normal:
         can_wall_jump = true
         last_wall_normal = current_wall_normal
     ```

### 3. **Jump Mechanics**
   - The player can jump normally when on the ground or perform a wall jump when sliding down a wall:
     ```gdscript
     if Input.is_action_just_pressed("up"):
         if is_on_floor():
             velocity.y = JUMP_VELOCITY
         elif is_wall_sliding and can_wall_jump:
             velocity.y = WALL_JUMP_VELOCITY_Y
             velocity.x = direction.x * -WALL_JUMP_VELOCITY_X
             can_wall_jump = false
     ```

### 4. **Horizontal Movement**
   - The player's movement is controlled based on input:
     ```gdscript
     direction.x = Input.get_axis("left", "right")
     if direction.x != 0:
         velocity.x = direction.x * SPEED
     else:
         velocity.x = move_toward(velocity.x, 0, SPEED)
     ```

### 5. **Movement and Collision**
   - The player is moved using the `move_and_slide()` method, which handles collisions:
     ```gdscript
     move_and_slide()
     ```

### 6. **Animations**
   - The code updates the player's animations based on movement:
     ```gdscript
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
     ```

### 7. **Helper Functions**
   - **`is_in_air()`**: Checks if the player is in the air:
     ```gdscript
     func is_in_air():
         return not is_on_floor()
     ```

---

## Installation and Execution

1. Download the latest version of *Dungeon Slayer* from [this repository](#).
2. Open the project with Godot 4.3 or a compatible version.
3. Run the game in the Godot editor or export it to your desired platform.

## License and Distribution

The beta version of the game is freely available but may not be modified or distributed commercially without explicit permission from **Joshua Pond Studios**. For distribution or commercial usage inquiries, please contact us.

---

**Note**: This README provides an overview of the current version of the game's mechanics and will be updated with future releases.
