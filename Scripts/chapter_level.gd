extends Node2D

@export var spawn_point_name: String = "player_spawn"
@export var show_intro_dialog: bool = false
@export var dialog_flag: String = ""
@export var intro_lines: PackedStringArray = []

@onready var pause_menu = get_node_or_null("PauseMenu")
@onready var player = get_node_or_null("PlayerModel")
@onready var dialog_box = get_node_or_null("DialogBox")
@onready var dialog_text = get_node_or_null("DialogBox/Panel/MarginContainer/Text")
@onready var dialog_anim = get_node_or_null("DialogBox/Panel/AnimationPlayer")

var current_line := 0
var dialog_active := false

func _ready() -> void:
	_apply_scene_defaults()
	_position_player_from_checkpoint()
	_save_current_level()
	_handle_intro_state()
	_ensure_permanent_lumora()

func _apply_scene_defaults() -> void:
	var scene_path := get_tree().current_scene.scene_file_path
	if scene_path.ends_with("Scenes/Game.tscn") or scene_path.ends_with("Scenes/chapter1_level1.tscn"):
		show_intro_dialog = true
		if dialog_flag.is_empty():
			dialog_flag = "chapter_1_intro_completed"
		if intro_lines.is_empty():
			intro_lines = PackedStringArray([
				"...Wo bin ich?",
				"Das letzte was ich sah... der modrige Schatten... mein fallender Körper...",
				"*glibber* Ich... ich kann mich nicht spüren... nicht wie früher...",
				"Etwas ist anders... ganz anders...",
				"Dieser Körper fühlt sich fremd an, aber voller Möglichkeiten.",
				"Die Höhle antwortet auf mein Leuchten. Ich sollte vorsichtig weitergehen.",
				"Wenn ich den Ausgang finde, finde ich vielleicht auch Antworten."
			])

func _position_player_from_checkpoint() -> void:
	if player == null:
		push_warning("PlayerModel fehlt in %s" % get_tree().current_scene.scene_file_path)
		return

	var target_marker_name := spawn_point_name
	var checkpoint_marker := ChapterState.get_checkpoint(get_tree().current_scene.scene_file_path, "")
	if not checkpoint_marker.is_empty() and has_node(checkpoint_marker):
		target_marker_name = checkpoint_marker

	var spawn = get_node_or_null(target_marker_name)
	if spawn:
		player.global_position = spawn.global_position
	else:
		push_warning("Spawnpoint nicht gefunden: %s" % target_marker_name)

func _handle_intro_state() -> void:
	if not show_intro_dialog or dialog_box == null or dialog_text == null or intro_lines.is_empty():
		if dialog_box:
			dialog_box.visible = false
		return

	if dialog_flag.is_empty():
		dialog_flag = "%s_intro" % name.to_lower()

	if ChapterState.get_flag(dialog_flag, false):
		dialog_box.visible = false
		return

	dialog_box.visible = true
	dialog_active = true
	show_next_line()

func _save_current_level() -> void:
	var level_resource := LevelResource.new()
	level_resource.unlocked_level = get_tree().current_scene.scene_file_path
	var error := ResourceSaver.save(level_resource, "user://current_level.res")
	if error != OK:
		push_error("Fehler beim Speichern des Levels: %s" % error)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Pause") and pause_menu and pause_menu.has_method("toggle_pause"):
		pause_menu.toggle_pause()

	if event.is_action_pressed("UI") and player and player.has_node("CanvasLayer"):
		player.get_node("CanvasLayer").visible = !player.get_node("CanvasLayer").visible

	if dialog_active and event.is_action_pressed("Interact"):
		show_next_line()

func show_next_line() -> void:
	if current_line < intro_lines.size():
		dialog_text.text = intro_lines[current_line]
		if dialog_anim:
			dialog_anim.play("text_appear")
		current_line += 1
	else:
		end_intro()

func end_intro() -> void:
	dialog_active = false
	if dialog_box:
		dialog_box.visible = false
	if not dialog_flag.is_empty():
		ChapterState.set_flag(dialog_flag, true)

func _on_pause_menu_go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _ensure_permanent_lumora() -> void:
	var save_path := "user://lumora_save_data.save"
	if not FileAccess.file_exists(save_path):
		return

	var lumoras = get_tree().get_nodes_in_group("lumora")
	for lumora in lumoras:
		if lumora.get("is_permanent"):
			return

	var lumora_scene := load("res://Scenes/Stars/lumora.tscn")
	if lumora_scene == null:
		return

	var lumora = lumora_scene.instantiate()
	add_child(lumora)
	if player:
		lumora.global_position = player.global_position + Vector2(50, 0)
		if lumora.has_method("assign_player"):
			lumora.assign_player(player)
	lumora.set("is_permanent", true)
	lumora.set("is_caught", true)
