extends Node2D

# Klassendefinition für die Level-Resource
class CurrentLevelResource extends Resource:
	@export var unlocked_level: String

@onready var pause_menu = $PauseMenu
@onready var player = get_node("PlayerModel")
@onready var timer = $Timer

@export var player_scene: PackedScene
@export var spawn_point_name: String = "player_spawn"

func _ready() -> void:
	# Player instanzieren
	var player = player_scene.instantiate()
	
	# SpawnPoint im aktuellen Level suchen
	var spawn = get_node(spawn_point_name)
	if spawn:
		add_child(player)
		var level_resource = load("user://current_level.res")
	
		if level_resource:
			var level_scene_path = level_resource.unlocked_level
			print("Freigeschaltetes Level:", level_scene_path)
			
			# Nur Position setzen, wenn das gespeicherte Level NICHT level1.tscn ist
			if level_scene_path != "res://Scenes/level1.tscn":
				player.global_position = spawn.global_position
		else:
			# Falls keine level_resource geladen werden konnte, Position trotzdem setzen
			player.global_position = spawn.global_position
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

func _input(event):
	# Pausensteuerung
	if event.is_action_pressed("Pause"):  # Standardmäßig ESC
		pause_menu.toggle_pause()
	
	if event.is_action_pressed("UI"):
		$PlayerModel/CanvasLayer.visible = !$PlayerModel/CanvasLayer.visible

func _on_pause_menu_go_to_main_menu() -> void:
	# Pausierung aufheben, bevor wir Szenen entfernen
	get_tree().paused = false

	# Entferne alle Szenen und stoppe den Prozess
	var current_scene = get_tree().current_scene
	if current_scene != null:
		current_scene.queue_free()

	# Stelle sicher, dass das Pausenmenü auch entfernt wird
	var pause_menu_instance = pause_menu.get_parent()
	if pause_menu_instance != null:
		pause_menu_instance.queue_free()

	# Lade die "MainMenu"-Szene
	var main_menu_scene = load("res://Scenes/main_menu.tscn")
	if main_menu_scene == null:
		push_error("Fehler: Die MainMenu-Szene konnte nicht geladen werden.")
		return

	# Instanziiere und wechsle zur MainMenu-Szene
	var scene_instance = main_menu_scene.instantiate()
	get_tree().root.add_child(scene_instance)
	get_tree().current_scene = scene_instance
