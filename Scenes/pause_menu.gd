extends CanvasLayer

# Signal für Hauptmenü-Wechsel
signal go_to_main_menu

func _ready():
	visible = false
	set_layer(100)  

func toggle_pause():
	visible = not visible
	get_tree().paused = visible

	if visible:
		get_parent().move_child(self, get_parent().get_child_count() - 1)

func _on_continue_button_pressed() -> void:
	toggle_pause()

func _on_main_menu_button_pressed() -> void:
	emit_signal("go_to_main_menu")  # Signal senden
