extends CharacterBody2D

# Konstanten für die Fluggeschwindigkeit und den Angriffsbereich
const SPEED = 130.0  # Geschwindigkeit, mit der der Gegner fliegt
const DETECTION_RADIUS = 300.0  # Radius, innerhalb dessen der Gegner den Spieler erkennt
const ATTACK_RANGE = 5.0  # Entfernung, bei der der Gegner angreift
const ATTACK_DAMAGE = 17  # Schaden, den der Gegner beim Angriff zufügt
const ATTACK_COOLDOWN = 1.0  # Zeit, die zwischen den Angriffen vergeht

# Variablen für den Spieler und den Zustand des Gegners
var player: CharacterBody2D = null  # Referenz auf den Spieler
var is_dead := false  # Gibt an, ob der Gegner tot ist
var health := 50  # Lebenspunkte des Gegners
var is_attacking := false  # Status, ob der Gegner gerade angreift
var attack_timer := 0.0  # Timer für den Angriffscooldown

# Referenz auf den AnimationPlayer
@onready var animation_player = $Sprite2D/AnimationPlayer  # Pfad zum AnimationPlayer-Knoten

# Funktion, die beim Laden der Szene aufgerufen wird
func _ready() -> void:
	# Suche den Spieler in der Szene
	player = get_node("/root/Game/PlayerModel")  # Passe den Pfad des Spielers an, wenn nötig
	add_to_group("enemies")  # Füge den Gegner der "enemies"-Gruppe hinzu

func _physics_process(delta: float) -> void:
	if is_dead:
		return  # Wenn der Gegner tot ist, mache nichts

	if player:  # Überprüfe, ob der Spieler existiert
		# Berechne die Entfernung zum Spieler
		var distance_to_player = global_position.distance_to(player.global_position)

		if distance_to_player <= DETECTION_RADIUS:
			# Berechne die Richtung, in die der Gegner fliegen soll
			var direction = (player.global_position - global_position).normalized()

			# Fluggeschwindigkeit mit Berücksichtigung der vertikalen Bewegung des Spielers
			velocity.x = direction.x * SPEED  # Horizontaler Flug
			velocity.y = direction.y * SPEED  # Vertikaler Flug, um auf Sprünge zu reagieren

			# Angreife nur, wenn der Angriffscooldown abgelaufen ist und der Spieler in Reichweite ist
			attack_timer -= delta
			if distance_to_player <= ATTACK_RANGE and attack_timer <= 0.0:
				attack()

		else:
			velocity = Vector2.ZERO  # Bleibe stehen, wenn der Spieler außerhalb des Radius ist

	# Bewege den Gegner basierend auf der Geschwindigkeit
	move_and_slide()

	# Setze die Animation basierend auf dem Zustand des Gegners
	set_animation()

# Funktion, die den Gegner angreifen lässt
func attack() -> void:
	if player and not is_dead:
		is_attacking = true  # Setze den Angriffszustand auf wahr
		animation_player.play("attack")  # Spiele die Angriffsanimation
		# Füge dem Spieler Schaden zu
		player.take_damage(ATTACK_DAMAGE)
		# Setze den Angriffscooldown
		attack_timer = ATTACK_COOLDOWN
		# Danach eine kurze Pause (eine Sekunde) bevor erneut angegriffen wird
		is_attacking = false

# Funktion, um die Animation basierend auf dem Zustand des Gegners zu setzen
func set_animation() -> void:
	if is_dead:
		return  # Wenn der Gegner tot ist, spiele keine Animationen

	if is_attacking:
		animation_player.play("attack")  # Spiele die Angriffsanimation
	elif velocity.length() > 0:
		animation_player.play("flying")  # Spiele die Fluganimation, wenn der Gegner sich bewegt
	else:
		animation_player.play("idle")  # Spiele die Idle-Animation, wenn der Gegner stillsteht

# Funktion, die den Gegner Schaden nehmen lässt
func take_damage(amount: int) -> void:
	if is_dead:
		return  # Mache nichts, wenn der Gegner schon tot ist

	health -= amount  # Verringere die Lebenspunkte
	if health <= 0:
		die()  # Der Gegner stirbt, wenn die Lebenspunkte auf 0 sinken

# Funktion, die den Tod des Gegners behandelt
func die():
	is_dead = true
	animation_player.play("death")  # Spiele die Todesanimation
	velocity = Vector2.ZERO  # Halte die Bewegung an
	$AttackArea/CollisionShape2D2.disabled = true  # Deaktiviere die Kollision, um weitere Interaktionen zu verhindern
	await get_tree().create_timer(1.0).timeout  # Warte, bis die Todesanimation fertig ist
	queue_free()  # Entferne den Gegner aus der Szene
