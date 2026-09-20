extends Node2D

const DOOR_SHEET := preload("res://Assets/Items/Glutdimension/glut_door_sheet.png")

var unlocked := false
var opening := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area: Area2D = $Area2D
@onready var blocker: CollisionShape2D = $StaticBody2D/CollisionShape2D


func _ready() -> void:
	_build_frames()
	sprite.play(&"sealed")


func set_unlocked(value: bool) -> void:
	unlocked = value
	if unlocked:
		blocker.set_deferred("disabled", true)
		sprite.play(&"ready")


func _physics_process(_delta: float) -> void:
	if opening or not Input.is_action_just_pressed("Interact"):
		return
	for body: Node2D in area.get_overlapping_bodies():
		if not body.is_in_group("players"):
			continue
		if not unlocked:
			if body.has_method("_show_feedback_toast"):
				body.call("_show_feedback_toast", "Das Tor reagiert erst, wenn alle Glutkaefer besiegt sind.", "warning", null)
			return
		_finish_quest(body)
		return


func _finish_quest(player: Node2D) -> void:
	opening = true
	sprite.play(&"open")
	if player.has_method("_show_feedback_banner"):
		player.call("_show_feedback_banner", "GLUTQUEST ERFUELLT", Color(1.0, 0.55, 0.18, 1.0), 0.62)
	await sprite.animation_finished
	var progress := get_node_or_null("/root/ChapterProgress")
	if progress != null:
		if progress.has_method("award_reward"):
			progress.call("award_reward", "glut_dimension_cleared")
		if progress.has_method("complete_active_level"):
			progress.call("complete_active_level")


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	for animation_name: StringName in [&"sealed", &"ready", &"open"]:
		frames.add_animation(animation_name)
	frames.set_animation_speed(&"sealed", 2.0)
	frames.set_animation_loop(&"sealed", true)
	frames.set_animation_speed(&"ready", 4.0)
	frames.set_animation_loop(&"ready", true)
	frames.set_animation_speed(&"open", 10.0)
	frames.set_animation_loop(&"open", false)
	for frame_index in range(7):
		var frame := AtlasTexture.new()
		frame.atlas = DOOR_SHEET
		frame.region = Rect2(frame_index * 128, 0, 128, 128)
		frames.add_frame(&"open", frame)
		if frame_index < 2:
			frames.add_frame(&"sealed", frame)
		if frame_index >= 5:
			frames.add_frame(&"ready", frame)
	sprite.sprite_frames = frames
