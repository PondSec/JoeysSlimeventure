extends Control

@onready var restart_button: TextureButton = $CanvasLayer/Label/TextureButton  # Der Button ist ein Kind von Label
@onready var death_label: Label = $Label  # Referenz zum Label (falls du das Label auch benötigst)
var player: Node2D  # Referenz zum Spieler

func _ready() -> void:
	# Überprüfen, ob der Button tatsächlich im Szenenbaum ist
	if restart_button == null:
		print("Fehler: Restart-Button konnte nicht gefunden werden!")
		return  # Verhindert Fehler, falls der Button nicht vorhanden ist

	# Verbinde den Restart-Button mit der Funktion
	restart_button.connect("pressed", Callable(self, "_on_RestartButton_pressed"))

	# Hole den Spieler (Achtung: überprüfe, dass der Spieler korrekt referenziert wird)
	player = get_node("PlayerModel")

# Funktion, um den Death Screen anzuzeigen, wenn der Spieler stirbt
func show_death_screen() -> void:
	$CanvasLayer.visible = true

func _on_RestartButton_pressed():
	# Death Screen verstecken
	var death_screen = get_tree().get_first_node_in_group("death_screen")
	if death_screen:
		death_screen.visible = false  # Blendet den Death Screen aus
	$CanvasLayer.visible = false
	# Spielerposition und Leben zurücksetzen
	var player = get_tree().get_first_node_in_group("players")
	if player:
		player.set_process(true)  # Prozess wieder aktivieren
		player.set_physics_process(true)  # Physikprozess wieder aktivieren
		player.global_position = Vector2(271, 770)  # Position zurücksetzen
		player.current_health = 100  # Leben auf 100 setzen
		if player.has_method("update_health_bar"):  # Falls der Spieler eine Lebensanzeige hat
			player.update_health_bar()
	get_tree().reload_current_scene()
