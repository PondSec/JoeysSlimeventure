extends Node2D

# Klassendefinition für die Level-Resource
class CurrentLevelResource extends Resource:
	@export var unlocked_level: String

@onready var pause_menu = $PauseMenu
@onready var player = get_node("PlayerModel")
@onready var timer = $Timer
@export var spawn_point_name: String = "player_spawn"

func _ready() -> void:
	# Aktuelles Level speichern
	save_current_level()
	call_deferred("_place_player_at_safe_level_spawn")


func _place_player_at_safe_level_spawn() -> void:
	var spawn := get_node_or_null(spawn_point_name) as Marker2D
	if spawn == null:
		push_warning("Spawnpoint nicht gefunden: " + spawn_point_name)
		return
	# Player._ready() restores the old save position.  Wait until the TileMap
	# colliders are registered, then replace that cross-level coordinate with a
	# validated floor spawn every time this scene is entered.
	await get_tree().physics_frame
	if player != null and player.has_method("place_at_safe_spawn"):
		player.call("place_at_safe_spawn", spawn.global_position, true)
	elif player != null:
		player.global_position = spawn.global_position
		player.velocity = Vector2.ZERO

func save_current_level():
	var current_level = get_tree().current_scene.scene_file_path
	var level_resource = LevelResource.new()
	level_resource.unlocked_level = current_level
	
	# Speichern der .res Datei
	var error = SaveService.save_resource("user://saves/current_level.res", level_resource)
	if error != OK:
		push_error("Fehler beim Speichern des Levels: " + str(error))

func savegame_exists() -> bool:
	return FileAccess.file_exists("user://saves/player_state.tres") and FileAccess.file_exists("user://saves/inventory.save")

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
