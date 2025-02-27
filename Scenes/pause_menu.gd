extends CanvasLayer

# Signal für Hauptmenü-Wechsel (falls nötig)
signal go_to_main_menu

func _ready():
	# Standardmäßig ausblenden
	visible = false
	# Sicherstellen, dass das Pausenmenü die höchste Rendering-Priorität hat
	set_layer(100)  

func toggle_pause():
	# Pausenmenü anzeigen oder ausblenden
	visible = not visible
	get_tree().paused = visible

	# Stelle sicher, dass das Pausenmenü beim Öffnen ganz oben gerendert wird
	if visible:
		get_parent().move_child(self, get_parent().get_child_count() - 1)

func _on_continue_button_pressed() -> void:
	toggle_pause()

func _on_main_menu_button_pressed() -> void:
	emit_signal("go_to_main_menu")
