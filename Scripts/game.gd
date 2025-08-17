extends Node2D

@onready var pause_menu = $PauseMenu
@onready var player = get_node("PlayerModel")
@onready var timer = $Timer
@onready var tutorial_overlay = $TutorialOverlay
@onready var tutorial_label = $TutorialOverlay/Panel/Label
@onready var inventory_ui = $PlayerModel/CanvasLayer/InvUI

var tutorial_steps = [
	{"text": "Bewege dich mit A nach links", "input": "left"},
	{"text": "Bewege dich mit D nach rechts", "input": "right"},
	{"text": "Springe mit Leertaste", "input": "up"},
	{"text": "Greif mit links Klick an", "input": "Attack"},
	{"text": "Drücke F, um leuchten aus zu machen", "input": "Glow"},
	{"text": "Drücke F, um leuchten an zu machen", "input": "Glow"},
	{"text": "Öffne das Inventar mit TAB", "input": "inventory"},
	{"text": "Schließe das Inventar mit TAB", "input": "inventory"}
]
var current_step = 0

@export var player_scene: PackedScene
@export var spawn_point_name: String = "player_spawn"

func _ready():
	if not savegame_exists():
		show_tutorial()
	else:
		tutorial_overlay.hide()
	
	# SpawnPoint im aktuellen Level suchen
	var spawn = get_node(spawn_point_name)
	if spawn:
		add_child(player)
		var level_resource = load("user://current_level.res")
	
		if level_resource:
			var level_scene_path = level_resource.unlocked_level
			print("Freigeschaltetes Level:", level_scene_path)
			
			# Nur Position setzen, wenn das gespeicherte Level NICHT level1.tscn ist
			if level_scene_path != "res://Scenes/Game.tscn":
				player.global_position = spawn.global_position
		else:
			# Falls keine level_resource geladen werden konnte, Position trotzdem setzen
			player.global_position = spawn.global_position
			save_current_level()
	else:
		push_warning("Spawnpoint nicht gefunden: " + spawn_point_name)
	
	# Aktuelles Level speichern
	save_current_level()

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

func show_tutorial():
	tutorial_overlay.show()
	update_tutorial_text()

func update_tutorial_text():
	if current_step < tutorial_steps.size():
		tutorial_label.text = tutorial_steps[current_step]["text"]
	else:
		tutorial_overlay.hide()

func _input(event):
	# Pausensteuerung
	if event.is_action_pressed("Pause"):  # Standardmäßig ESC
		pause_menu.toggle_pause()
	
	# Tutorial-Steuerung (nur wenn Overlay sichtbar ist)
	if tutorial_overlay.visible:
		if event.is_action_pressed(tutorial_steps[current_step]["input"]):
			current_step += 1
			update_tutorial_text()
	
	if event.is_action_pressed("UI"):
		$PlayerModel/CanvasLayer.visible = !$PlayerModel/CanvasLayer.visible

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
