extends CanvasLayer

# Lade die Hauptmenü-Szene im Voraus
var main_menu_scene = preload("res://Scenes/main_menu.tscn")

# Signal für Hauptmenü-Wechsel
signal go_to_main_menu

func _ready():
	# Verstecke das Pause-Menü beim Start
	visible = false
	# Setze eine hohe Layer-Nummer, damit es über anderen Elementen erscheint
	set_layer(100)
	
	# Pausiere das Spiel nicht beim Start
	get_tree().paused = false

func toggle_pause():
	# Wechsle die Sichtbarkeit
	visible = not visible
	# Pausiere/Entpausiere den Spielbaum
	get_tree().paused = visible
	
	# Wenn sichtbar, bewege es nach vorne
	if visible:
		get_parent().move_child(self, get_parent().get_child_count() - 1)

func _on_continue_button_pressed() -> void:
	toggle_pause()

func _on_main_menu_button_pressed() -> void:
	# Entpausiere das Spiel bevor wir zum Hauptmenü wechseln
	get_tree().paused = false
	var transition = preload("res://Scenes/transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	self.visible = false
	transition.play_transition("res://Scenes/main_menu.tscn", false)
