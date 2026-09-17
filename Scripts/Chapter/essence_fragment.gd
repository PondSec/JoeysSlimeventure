extends Area2D

@export var toast_text: String = "Essenzsplitter geborgen."

const ItemRegistry := preload("res://Scripts/item_registry.gd")

const COPPER_TEXTURE := preload("res://Assets/Items/copper_nugget.png")
const IRON_TEXTURE := preload("res://Assets/Items/iron_nugget.png")
const GOLD_TEXTURE := preload("res://Assets/Items/gold_nugget.png")
const DISPLAY_SCALE := 0.52

var hover_time: float = 0.0
var base_position: Vector2 = Vector2.ZERO
var collected: bool = false
var item_id: String = "copper_nugget"

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D


func _ready() -> void:
	base_position = sprite.position
	body_entered.connect(_on_body_entered)


func configure_loot_tier(tier: String) -> void:
	match tier:
		"iron":
			item_id = "iron_nugget"
			sprite.texture = IRON_TEXTURE
			light.color = Color(0.72, 0.84, 1.0, 1.0)
		"gold":
			item_id = "gold_nugget"
			sprite.texture = GOLD_TEXTURE
			light.color = Color(1.0, 0.77, 0.28, 1.0)
		_:
			item_id = "copper_nugget"
			sprite.texture = COPPER_TEXTURE
			light.color = Color(1.0, 0.56, 0.27, 1.0)


func _process(delta: float) -> void:
	if collected:
		return
	hover_time += delta
	sprite.position = base_position + Vector2(0.0, sin(hover_time * 2.4) * 4.0)
	sprite.rotation = sin(hover_time * 1.7) * 0.08
	sprite.scale = Vector2.ONE * (DISPLAY_SCALE + max(sin(hover_time * 2.9), 0.0) * 0.035)
	light.energy = 0.58 + max(sin(hover_time * 3.2), 0.0) * 0.12


func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("players"):
		return
	var item := ItemRegistry.get_item(item_id)
	if item == null or not body.has_method("collect") or not body.call("collect", item):
		return

	collected = true
	if body.has_method("_show_feedback_toast"):
		body.call("_show_feedback_toast", toast_text, "reward", sprite.texture)
	if body.has_method("_show_feedback_banner"):
		body.call("_show_feedback_banner", "ERZ +1", Color(0.7, 0.95, 1.0, 1.0), 0.42)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2.ONE * 0.76, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
