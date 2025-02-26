# Dokumentation: Spieler-Skript

## Überblick
Dieses Skript steuert die Bewegung, Interaktion und das Kampfsystem eines Spielers in einer 2D-Umgebung. Es verwaltet die Animationen, Angriffe, Heilung und verschiedene Zustände wie das Gleiten an Wänden oder das Landen nach einem Sprung.

---

## Konstanten für Bewegung und Physik

```gdscript
const SPEED = 220.0
const GRAVITY = 1200.0
const JUMP_VELOCITY = -430.0
const WALL_JUMP_VELOCITY_X = 300.0
const WALL_JUMP_VELOCITY_Y = -400.0
const WALL_SLIDE_SPEED = 50.0
const MIN_FALL_HEIGHT = 10.0
```

- **SPEED**: Maximale Laufgeschwindigkeit des Spielers.
- **GRAVITY**: Schwerkraft, die auf den Spieler wirkt.
- **JUMP_VELOCITY**: Geschwindigkeit beim normalen Sprung.
- **WALL_JUMP_VELOCITY_X/Y**: Geschwindigkeit für den Wandsprung.
- **WALL_SLIDE_SPEED**: Geschwindigkeit des Spielers beim Gleiten an einer Wand.
- **MIN_FALL_HEIGHT**: Mindesthöhe für die Landeanimation.

---

## Status-Variablen
Diese Variablen halten den Zustand des Spielers fest.

```gdscript
var direction := Vector2.ZERO
var is_wall_sliding := false
var can_wall_jump := true
var last_wall_normal := Vector2.ZERO
var is_attacking := false
var is_facing_left := false
var was_in_air := false
var is_landing := false
var fall_start_y := 0.0
var fall_distance := 10.0
```

- **direction**: Speichert die Bewegungsrichtung.
- **is_wall_sliding**: Zeigt an, ob der Spieler an einer Wand gleitet.
- **can_wall_jump**: Gibt an, ob der Spieler aktuell einen Wandsprung ausführen kann.
- **is_attacking**: Zustand für Angriffsaktionen.
- **is_facing_left**: Gibt die Blickrichtung des Spielers an.
- **was_in_air**: Prüft, ob sich der Spieler vorher in der Luft befand.
- **is_landing**: Gibt an, ob die Landeanimation abgespielt wird.
- **fall_start_y**: Y-Koordinate, bei der der Spieler zu fallen begann.
- **fall_distance**: Berechnete Fallhöhe.

---

## Lebenssystem

```gdscript
var max_health: int = 100
var current_health: int = 100

const COLOR_NORMAL = Color(0.62, 1.0, 0.58)
const COLOR_DAMAGE = Color(1.0, 0.29, 0.29)

@onready var health_bar: TextureProgressBar = $CanvasLayer/TextureProgressBar
```

- **max_health**: Maximale Gesundheit des Spielers.
- **current_health**: Aktuelle Lebenspunkte des Spielers.
- **COLOR_NORMAL**: Standardfarbe für die Darstellung der Gesundheit.
- **COLOR_DAMAGE**: Farbe, die angezeigt wird, wenn der Spieler Schaden nimmt.
- **health_bar**: UI-Element zur Anzeige der aktuellen Gesundheit.

### Gesundheit aktualisieren

```gdscript
func update_health_bar() -> void:
    health_bar.value = current_health
```

Diese Funktion setzt den Wert der Lebensanzeige basierend auf der aktuellen Gesundheit.

---

## Bewegung & Physik

Die Bewegung und Physik des Spielers wird in `_physics_process` verarbeitet.

```gdscript
func _physics_process(delta: float) -> void:
    if is_landing:
        return  # Keine Bewegung während der Landeanimation

    if not is_on_floor():
        if not was_in_air:
            fall_start_y = global_position.y
            fall_distance = 0.0
        
        was_in_air = true
        velocity.y += GRAVITY * delta
        fall_distance = fall_start_y - global_position.y
    else:
        if was_in_air:
            if fall_distance >= MIN_FALL_HEIGHT and velocity.y > 0:
                play_landing_animation()
            was_in_air = false

    direction.x = Input.get_axis("left", "right")
    if direction.x != 0:
        velocity.x = direction.x * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)

    move_and_slide()
```

- Überprüft, ob der Spieler auf dem Boden oder in der Luft ist.
- Berechnet die Fallhöhe und startet gegebenenfalls die Landeanimation.
- Setzt die horizontale Bewegung des Spielers um.

### Wandsprung

```gdscript
if Input.is_action_just_pressed("up"):
    if is_on_floor():
        velocity.y = JUMP_VELOCITY
    elif is_wall_sliding and can_wall_jump:
        var wall_normal = get_wall_normal()
        velocity.y = WALL_JUMP_VELOCITY_Y
        if wall_normal.x != 0:
            velocity.x = -wall_normal.x * WALL_JUMP_VELOCITY_X
        can_wall_jump = false
```

- Prüft, ob der Spieler springt.
- Führt entweder einen normalen Sprung oder einen Wandsprung aus.

---

## Angriff

Der Angriff erfolgt, wenn die entsprechende Taste gedrückt wird.

```gdscript
func perform_attack() -> void:
    is_attacking = true
    $PlayerSprite/AttackSprite.flip_h = is_facing_left
    $PlayerSprite/AttackSprite.play("swing")
    attack_area.monitoring = true
    await get_tree().create_timer(0.5).timeout
    is_attacking = false
    attack_area.monitoring = false
```

- Setzt den Spieler in den Angriffsmodus.
- Spielt eine Animation ab und aktiviert das Kollisionsgebiet für den Angriff.
- Nach einer kurzen Verzögerung wird der Angriff beendet.

---

## Schaden & Heilung

Wenn der Spieler Schaden nimmt:

```gdscript
func take_damage(amount: int) -> void:
    current_health -= amount
    show_damage_text(amount, false)
    flash_damage_color()
    if current_health <= 0:
        current_health = 0
        die()
    update_health_bar()
```

- Reduziert die Gesundheit des Spielers.
- Zeigt eine Schadensanzeige an.
- Falls die Gesundheit auf 0 fällt, stirbt der Spieler.

Heilung erfolgt über einen Timer:

```gdscript
func _on_heal_timer_timeout() -> void:
    if is_healing_active and current_health < max_health:
        var missing_health = max_health - current_health
        var heal_amount = ceil(missing_health * 0.1)
        heal(heal_amount)
```

- Heilt den Spieler regelmäßig um 10% des fehlenden Lebens.
- Die Heilung stoppt, wenn der Spieler Schaden nimmt.

---

## Fazit
Dieses Skript implementiert eine vollständige Spielmechanik für einen 2D-Spieler mit Bewegung, Sprüngen, Angriffen und einem Heilungssystem. Es nutzt verschiedene Mechaniken wie Animationen, Timer und Partikel-Effekte, um das Gameplay dynamisch und ansprechend zu gestalten.

