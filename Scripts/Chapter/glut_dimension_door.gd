extends Node2D

const GLUT_DIMENSION_SCENE := "res://Scenes/Chapter/glut_dimension.tscn"
const DOOR_SHEET := preload("res://Assets/Items/Glutdimension/glut_door_sheet.png")
const KEY_ID := "glut_schluessel"

var opening := false
var locked_feedback_ready := true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area: Area2D = $Area2D


func _ready() -> void:
	_build_frames()
	sprite.play(&"sealed")


func _physics_process(_delta: float) -> void:
	if opening or not Input.is_action_just_pressed("Interact"):
		return
	for body: Node2D in area.get_overlapping_bodies():
		if not body.is_in_group("players"):
			continue
		if not _has_glut_key(body):
			_show_locked_feedback(body)
			return
		_open_portal(body)
		return


func _has_glut_key(player: Node2D) -> bool:
	var inventory: Variant = player.get("inv")
	return inventory != null and inventory.has_method("contains_item") and bool(inventory.call("contains_item", KEY_ID))


func _show_locked_feedback(player: Node2D) -> void:
	if player.has_method("_show_feedback_toast"):
		player.call("_show_feedback_toast", "Das Gluttor verlangt den Glut-Schluessel.", "warning", null)


func _open_portal(player: Node2D) -> void:
	opening = true
	sprite.play(&"open")
	if player.has_method("_show_feedback_banner"):
		player.call("_show_feedback_banner", "GLUTDIMENSION", Color(1.0, 0.4, 0.12, 1.0), 0.52)
	await sprite.animation_finished
	if not is_inside_tree():
		return
	var progress := get_node_or_null("/root/ChapterProgress")
	if progress != null and progress.has_method("transition_to"):
		progress.call("transition_to", GLUT_DIMENSION_SCENE)
	else:
		get_tree().change_scene_to_file(GLUT_DIMENSION_SCENE)


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"sealed")
	frames.set_animation_speed(&"sealed", 2.0)
	frames.set_animation_loop(&"sealed", true)
	frames.add_animation(&"open")
	frames.set_animation_speed(&"open", 10.0)
	frames.set_animation_loop(&"open", false)
	for frame_index in range(7):
		var frame := AtlasTexture.new()
		frame.atlas = DOOR_SHEET
		frame.region = Rect2(frame_index * 128, 0, 128, 128)
		frames.add_frame(&"open", frame)
		if frame_index < 2:
			frames.add_frame(&"sealed", frame)
	sprite.sprite_frames = frames
