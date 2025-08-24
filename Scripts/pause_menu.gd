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
	
	# Menü soll auch bei pausiertem Tree weiterlaufen
	process_mode = Node.PROCESS_MODE_ALWAYS


func toggle_pause():
	var gm = get_node("/root/GameManager")
	
	# Sichtbarkeit des Menüs toggeln
	visible = not visible
	
	if not gm.is_multiplayer:
		# Singleplayer → echten Pause-State setzen
		get_tree().paused = visible
	else:
		# Multiplayer → niemals pausieren, nur Menü sichtbar machen
		get_tree().paused = false
	
	# Menü in den Vordergrund holen, wenn sichtbar
	if visible:
		get_parent().move_child(self, get_parent().get_child_count() - 1)


func _on_continue_button_pressed() -> void:
	toggle_pause()


func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	
	# WICHTIG: Multiplayer-Verbindung trennen, falls vorhanden
	var gm = get_node("/root/GameManager")
	if gm.is_multiplayer:
		# Multiplayer-Verbindung ordnungsgemäß trennen
		var multiplayer_peer = get_multiplayer().get_multiplayer_peer()
		if multiplayer_peer:
			multiplayer_peer.close()
			get_multiplayer().set_multiplayer_peer(null)
		
		# GameManager zurücksetzen
		gm.is_multiplayer = false
		if gm.has_method("reset_multiplayer_state"):
			gm.reset_multiplayer_state()
	
	var transition = preload("res://Scenes/transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	self.visible = false
	transition.play_transition("res://Scenes/main_menu.tscn", false)
	queue_free()
