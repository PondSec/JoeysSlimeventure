extends CharacterBody2D

# Konstanten für die Bewegungsgeschwindigkeit und den Sprung
const SPEED = 130.0  # Geschwindigkeit, mit der der Gegner geht
const JUMP_VELOCITY = -250.0  # Sprunggeschwindigkeit
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

# Referenz auf den AnimatedSprite
@onready var animated_sprite = $AnimatedSprite  # Pfad zum AnimatedSprite-Knoten

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
			# Berechne die Richtung, in die der Gegner gehen soll
			var direction = (player.global_position - global_position).normalized()

			# Bewege den Gegner basierend auf der Geschwindigkeit
			velocity.x = direction.x * SPEED  # Horizontalbewegung

			# Überprüfe, ob der Gegner auf dem Boden ist und ob er ein Hindernis hat
			if is_on_floor():
				# Wir prüfen, ob der Gegner in der nächsten Bewegung mit einem Hindernis kollidieren wird
				if check_for_collision():
					velocity.y = JUMP_VELOCITY  # Gegner springt, wenn ein Hindernis erkannt wird

			# Angreife nur, wenn der Angriffscooldown abgelaufen ist und der Spieler in Reichweite ist
			attack_timer -= delta
			if distance_to_player <= ATTACK_RANGE and attack_timer <= 0.0:
				attack()

		else:
			velocity = Vector2.ZERO  # Bleibe stehen, wenn der Spieler außerhalb des Radius ist

	# Bewege den Gegner basierend auf der Geschwindigkeit
	move_and_slide()

	# Setze die Animation basierend auf den Bewegungen des Gegners
	set_animation()

# Funktion, die den Gegner angreifen lässt
func attack() -> void:
	if player and not is_dead:
		is_attacking = true  # Setze den Angriffszustand auf wahr
		animated_sprite.play("attack")  # Spiele die Angriffsanimation
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
		animated_sprite.play("attack")  # Spiele die Angriffsanimation
	elif velocity.length() > 0:
		animated_sprite.play("walking")  # Spiele die Geh-Animation, wenn der Gegner sich bewegt
	else:
		animated_sprite.play("idle")  # Spiele die Idle-Animation, wenn der Gegner stillsteht

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
	animated_sprite.play("death")  # Spiele die Todesanimation
	velocity = Vector2.ZERO  # Halte die Bewegung an
	$Area2D/AttackArea.disabled = true  # Deaktiviere die Kollision, um weitere Interaktionen zu verhindern
	await get_tree().create_timer(1.0).timeout  # Warte, bis die Todesanimation fertig ist
	queue_free()  # Entferne den Gegner aus der Szene

func check_for_collision() -> bool:
	# Überprüfen, ob der Gegner eine Kollision in seiner Bewegungsrichtung hat
	var slide_count = get_slide_collision_count()  # Korrigierte Methode hier
	for i in range(slide_count):
		var collision = get_slide_collision(i)
		if collision and collision.get_collider():  # Kollision mit einem Objekt gefunden
			return true  # Kollision erkannt
	return false  # Keine Kollision erkannt
