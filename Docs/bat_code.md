# Joey's Slimeventure - Detaillierte Dokumentation für `bat.gd`

## Einleitung
Die Datei `bat.gd` enthält die Logik für die Fledermaus-Gegner im Spiel. Diese Gegner verfolgen den Spieler, greifen an, können zurückgestoßen werden und respawnen nach dem Tod.

---

## Globale Variablen und Konstanten

### Konstanten
```gdscript
const SPEED = 140.0
const DETECTION_RADIUS = 300.0
const ATTACK_RANGE = 40.0
const ATTACK_COOLDOWN = 1.5
const MIN_DISTANCE = 20.0
const RESPAWN_COOLDOWN = 5
```
- `SPEED`: Bewegungsgeschwindigkeit der Fledermaus.
- `DETECTION_RADIUS`: Maximale Entfernung, aus der die Fledermaus den Spieler sehen kann.
- `ATTACK_RANGE`: Distanz, in der die Fledermaus den Spieler angreifen kann.
- `ATTACK_COOLDOWN`: Zeit zwischen Angriffen.
- `MIN_DISTANCE`: Mindestabstand, den die Fledermaus vom Spieler hält.
- `RESPAWN_COOLDOWN`: Zeit bis zur Wiederbelebung nach dem Tod.

### Variablen
```gdscript
var is_dead := false
var health := 100
var is_attacking := false
var attack_timer := 0.0
var knockback_velocity := Vector2.ZERO
var is_knocked_back := false
var is_stunned := false
```
- `is_dead`: Speichert, ob die Fledermaus tot ist.
- `health`: Lebenspunkte der Fledermaus.
- `is_attacking`: Gibt an, ob die Fledermaus gerade angreift.
- `attack_timer`: Countdown bis zum nächsten Angriff.
- `knockback_velocity`: Geschwindigkeit, die durch Knockback verursacht wird.
- `is_knocked_back`: Ob die Fledermaus durch Knockback zurückgestoßen wird.
- `is_stunned`: Ob die Fledermaus momentan betäubt ist.

### Exporte und Node-Referenzen
```gdscript
@export var player: CharacterBody2D
@onready var animation_player = $Sprite2D/AnimationPlayer
@onready var navigation_agent = $NavigationAgent2D
@onready var camera: Camera2D = $Camera2D
```
- `player`: Referenz zum Spielerobjekt.
- `animation_player`: Steuerung für Animationen.
- `navigation_agent`: Wird für die Navigation zum Spieler verwendet.
- `camera`: Referenz zur Kamera, die für Bildschirm-Effekte genutzt wird.

---

## Methoden

### `_ready()`
```gdscript
func _ready() -> void:
    randomize()
    add_to_group("enemies")
```
- Wird beim Start aufgerufen.
- Mischt den Zufallsgenerator.
- Fügt die Fledermaus zur Gegner-Gruppe hinzu.

### `_physics_process(delta: float)`
```gdscript
func _physics_process(delta: float) -> void:
    if is_dead or is_stunned:
        velocity = Vector2.ZERO
        return
```
- Setzt die Geschwindigkeit auf Null, wenn die Fledermaus tot oder betäubt ist.

```gdscript
    if is_knocked_back:
        velocity = knockback_velocity
        knockback_velocity *= 0.9
        if knockback_velocity.length() < 10:
            is_knocked_back = false
            apply_stun(0.5)
```
- Reduziert Knockback-Geschwindigkeit schrittweise, bis sie minimal ist.
- Nach Knockback wird die Fledermaus für 0,5 Sekunden betäubt.

```gdscript
    else:
        var distance_to_player = global_position.distance_to(player.global_position)
```
- Berechnet die Entfernung zum Spieler.

```gdscript
        if distance_to_player <= ATTACK_RANGE:
            attack_timer -= delta
            if attack_timer <= 0.0:
                attack()
```
- Wenn der Spieler nah genug ist, greift die Fledermaus an.

```gdscript
        elif player and player.is_glowing and distance_to_player <= DETECTION_RADIUS:
            navigation_agent.target_position = player.global_position
            var direction = to_local(navigation_agent.get_next_path_position()).normalized()
            if distance_to_player > MIN_DISTANCE:
                velocity = direction * SPEED
            else:
                velocity = Vector2.ZERO
```
- Verfolgt den Spieler nur, wenn er "glowing" ist.
- Nutzt `NavigationAgent2D`, um die Route zum Spieler zu bestimmen.
- Vermeidet den Spieler, wenn zu nah.

```gdscript
        else:
            velocity = Vector2.ZERO
            is_attacking = false
```
- Falls kein Ziel erkannt wurde, bleibt die Fledermaus stehen.

### `attack()`
```gdscript
func attack() -> void:
    if player and not is_dead:
        var is_critical = randf() < 0.1
        if is_critical:
            perform_critical_hit()
```
- 10 % Chance für einen kritischen Treffer.
- Startet die Angriffsanimation.

### `perform_critical_hit()`
```gdscript
func perform_critical_hit() -> void:
    activate_slow_motion(0.3, 0.5)
    screen_shake(0.5, 30.0)
```
- Verlangsamt das Spiel für kurze Zeit und erzeugt ein Bildschirmwackeln.

### `take_damage(amount: int)`
```gdscript
func take_damage(amount: int) -> void:
    if is_dead:
        return

    health -= amount
    flash_red()
    apply_knockback()

    if health <= 0:
        die()
```
- Reduziert die Lebenspunkte.
- Ruft `flash_red()` und `apply_knockback()` auf.
- Stirbt, wenn `health <= 0`.

### `die()`
```gdscript
func die():
    is_dead = true
    animation_player.play("death")
    velocity = Vector2.ZERO
    await animation_player.animation_finished
    hide()
    set_deferred("collision_layer", 0)
    set_deferred("collision_mask", 0)
    await get_tree().create_timer(RESPAWN_COOLDOWN).timeout
    spawn_near_player()
```
- Spielt Todesanimation.
- Deaktiviert Kollision.
- Wartet, bevor die Fledermaus respawnt.

### `spawn_near_player()`
```gdscript
func spawn_near_player() -> void:
    var new_position = global_position
    for i in range(10):
        var random_offset = Vector2(randf_range(-DETECTION_RADIUS, DETECTION_RADIUS), randf_range(-DETECTION_RADIUS, DETECTION_RADIUS))
        var candidate_position = player.global_position + random_offset
        if candidate_position.distance_to(player.global_position) >= MIN_DISTANCE and is_valid_spawn_position(candidate_position):
            new_position = candidate_position
            break

    global_position = new_position
    show()
    set_deferred("collision_layer", 1)
    set_deferred("collision_mask", 1)
    is_dead = false
    health = 100
```
- Spawnt die Fledermaus in einer zufälligen Position nahe dem Spieler.
- Stellt sicher, dass die Position gültig ist.

---
