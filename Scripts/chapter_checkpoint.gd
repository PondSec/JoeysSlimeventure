extends Area2D

@export var marker_name: String = ""
@export var checkpoint_message: String = "Checkpoint aktiviert"
@export var heal_ratio: float = 0.35
@export var one_shot: bool = false

var activated := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if activated and one_shot:
		return
	if not body.is_in_group("players"):
		return

	var marker := marker_name if not marker_name.is_empty() else name
	ChapterState.save_checkpoint(get_tree().current_scene.scene_file_path, marker)
	_restore_player(body)
	ChapterState.show_toast(get_tree(), checkpoint_message, "success", 2.5)
	activated = true

	if one_shot:
		set_deferred("monitoring", false)

func _restore_player(body: Node2D) -> void:
	if body.has_method("heal"):
		body.heal(int(body.max_health * heal_ratio))
		return

	if body.has_method("update_health_bar"):
		body.current_health = min(body.max_health, body.current_health + int(body.max_health * heal_ratio))
		body.update_health_bar()
