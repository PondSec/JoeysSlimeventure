extends CanvasLayer

# Signal für Hauptmenü-Wechsel (falls nötig)
signal go_to_main_menu

func _ready():
	# Standardmäßig ausblenden
	visible = false

func toggle_pause():
	# Pausenmenü anzeigen oder ausblenden
	visible = not visible
	get_tree().paused = visible

func _on_continue_button_pressed() -> void:
	toggle_pause()


func _on_main_menu_button_pressed() -> void:
	emit_signal("go_to_main_menu")
