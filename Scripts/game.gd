extends Node2D

@onready var pause_menu = $PauseMenu
@onready var player = get_node("PlayerModel")

# Dialog Variablen
const CONFIG_PATH = "user://game_config.cfg"
var intro_lines = [
	"...Wo bin ich?",
	"Das letzte was ich sah... der modrige Schatten... mein fallender Körper...",
	"*glibber* Ich... ich kann mich nicht spüren... nicht wie früher...",
	"Etwas ist anders... ganz anders...",
	"Dieser... Körper? Er fühlt sich fremd an... und doch...",
	"Da ist etwas... ein Pulsieren... ein seltsames Kribbeln in mir...",
	"Als ob... als ob etwas in mir schlummert... etwas Unbekanntes...",
	"Etwas, das ich noch nicht verstehe... aber es fühlt sich... mächtig an.",
	"Diese Höhle... sie strahlt eine seltsame Energie aus...",
	"Ich spüre... hier liegt ein Geheimnis verborgen...",
	"Vielleicht... vielleicht bin ich genau deshalb hier...",
	"Ich werde Antworten finden... egal was ich jetzt bin!"
]
var current_line = 0
var dialog_active = true

@export var player_scene: PackedScene
@export var spawn_point_name: String = "player_spawn"

func _ready():
	# SpawnPoint im aktuellen Level suchen
	var spawn = get_node(spawn_point_name)
	if spawn:
		add_child(player)
		var level_resource = load("user://current_level.res")
	
		if level_resource:
			var level_scene_path = level_resource.unlocked_level
			print("Freigeschaltetes Level:", level_scene_path)
			
			# Nur Position setzen, wenn das gespeicherte Level existiert und NICHT level1.tscn ist
			if level_scene_path != "res://Scenes/Game.tscn":
				player.global_position = spawn.global_position
		# Wenn keine level_resource existiert, wird die Position NICHT geändert
	else:
		push_warning("Spawnpoint nicht gefunden: " + spawn_point_name)
	
	# Aktuelles Level speichern
	save_current_level()
	
	# Nur Dialog starten, wenn er noch nicht abgeschlossen wurde
	if not load_dialog_state():
		show_next_line()
	else:
		# Wenn Dialog bereits abgeschlossen, direkt beenden
		end_intro()

func save_dialog_state(completed: bool):
	var config = ConfigFile.new()
	config.set_value("dialogs", "intro_completed", completed)
	config.save(CONFIG_PATH)

func load_dialog_state() -> bool:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		return config.get_value("dialogs", "intro_completed", false)
	return false

func save_current_level():
	var current_level = get_tree().current_scene.scene_file_path
	var level_resource = LevelResource.new()
	level_resource.unlocked_level = current_level
	
	# Speichern der .res Datei
	var error = ResourceSaver.save(level_resource, "user://current_level.res")
	if error != OK:
		push_error("Fehler beim Speichern des Levels: " + str(error))

func savegame_exists() -> bool:
	return FileAccess.file_exists("user://savegame.tres") and FileAccess.file_exists("user://inventory.save")

func _input(event):
	# Pausensteuerung
	if event.is_action_pressed("Pause"):  # Standardmäßig ESC
		pause_menu.toggle_pause()
	
	if event.is_action_pressed("UI"):
		$PlayerModel/CanvasLayer.visible = !$PlayerModel/CanvasLayer.visible
	
	# Dialogsteuerung
	if dialog_active and event.is_action_pressed("Interact"):
		show_next_line()

func show_next_line():
	if current_line < intro_lines.size():
		$DialogBox/Panel/MarginContainer/Text.text = intro_lines[current_line]
		$DialogBox/Panel/AnimationPlayer.play("text_appear")
		current_line += 1
	else:
		end_intro()

func end_intro():
	dialog_active = false
	$DialogBox.queue_free()
	# Speichern, dass der Dialog abgeschlossen wurde
	save_dialog_state(true)
	# Spielersteuerung freigeben oder andere Startaktionen hier

func _on_pause_menu_go_to_main_menu() -> void:
	# Pausierung aufheben, bevor wir Szenen entfernen
	get_tree().paused = false

	# Entferne alle Szenen und stoppe den Prozess
	var current_scene = get_tree().current_scene
	if current_scene != null:
		current_scene.queue_free()  # Entferne die aktuelle Szene sicher aus dem Szenenbaum

	# Stelle sicher, dass das Pausenmenü auch entfernt wird
	var pause_menu_instance = pause_menu.get_parent()  # Hole den übergeordneten Node des Pausenmenüs
	if pause_menu_instance != null:
		pause_menu_instance.queue_free()  # Entferne das Pausenmenü ebenfalls

	# Lade die "MainMenu"-Szene
	var main_menu_scene = load("res://Scenes/main_menu.tscn")

	# Überprüfe, ob die MainMenu-Szene erfolgreich geladen wurde
	if main_menu_scene == null:
		print("Fehler: Die MainMenu-Szene konnte nicht geladen werden.")
		return  # Beende die Funktion, wenn die Szene nicht geladen werden konnte

	# Instanziiere die MainMenu-Szene
	var scene_instance = main_menu_scene.instantiate()

	# Füge die instanzierte MainMenu-Szene zur Root-Node des Szenenbaums hinzu
	get_tree().root.add_child(scene_instance)  # Füge die neue Szene zur Root-Node hinzu
	get_tree().current_scene = scene_instance  # Setze die neue Szene als aktuelle Szene
