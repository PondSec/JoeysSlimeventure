extends Area2D

@export_multiline var message: String = ""
@export var message_type: String = "info"
@export var duration: float = 3.0
@export var one_shot: bool = true

var triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if triggered and one_shot:
		return
	if not body.is_in_group("players"):
		return

	ChapterState.show_toast(get_tree(), message, message_type, duration)
	triggered = true

	if one_shot:
		set_deferred("monitoring", false)
