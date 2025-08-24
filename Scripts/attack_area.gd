extends Area2D

# Gegner-Variablen
var health := 100  # Gesundheit des Gegners
var damage := 20   # Schaden, den der Gegner verursacht

# Referenzen
var player: CharacterBody2D  # Der Spieler

func _ready() -> void:
	# Hole den Spieler aus der Szene
	player = get_node("/root/Game/PlayerModel")  # Ändere den Pfad, je nach deinem Szenenaufbau
	
	# Verknüpfe das Signal für Kollisionserkennung
	connect("body_entered", Callable(self, "_on_body_entered"))

# Wenn der Spieler den Bereich des Gegners betritt
func _on_body_entered(body: Node) -> void:
	# Überprüfen, ob der Spieler in den Bereich kommt
	if body.is_in_group("player"):  # Stelle sicher, dass der Spieler zur Gruppe "player" gehört
		body.take_damage(damage)  # Schadensfunktion des Spielers aufrufen
		print("Der Gegner hat dem Spieler Schaden zugefügt!")
