extends Area2D

@export var heal_amount: int = 6
@export var toast_text: String = "Essenzsplitter geborgen."

var hover_time: float = 0.0
var base_position: Vector2 = Vector2.ZERO
var collected: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D


func _ready() -> void:
	base_position = sprite.position
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if collected:
		return
	hover_time += delta
	sprite.position = base_position + Vector2(0.0, sin(hover_time * 2.4) * 4.0)
	sprite.rotation = sin(hover_time * 1.7) * 0.08
	sprite.scale = Vector2.ONE * (0.24 + max(sin(hover_time * 2.9), 0.0) * 0.02)
	light.energy = 0.58 + max(sin(hover_time * 3.2), 0.0) * 0.12


func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("players"):
		return

	collected = true
	if body.has_method("heal"):
		body.call("heal", heal_amount)
	if body.has_method("_show_feedback_toast"):
		body.call("_show_feedback_toast", toast_text, "reward", sprite.texture)
	if body.has_method("_show_feedback_banner"):
		body.call("_show_feedback_banner", "ESSENZ +1", Color(0.7, 0.95, 1.0, 1.0), 0.42)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2.ONE * 0.38, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
