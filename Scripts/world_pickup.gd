extends RigidBody2D

@export var lifetime: float = 120.0
@export var item: InvItem
@export var is_critical: bool = false

var damage_amount: float = 0.0
var hover_phase := 0.0
var sprite: Sprite2D
var sprite_base_position := Vector2.ZERO
var sprite_base_scale := Vector2.ONE


func _ready() -> void:
	if item:
		damage_amount = item.throw_damage

	sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.texture = item.texture if item else sprite.texture
		sprite_base_position = sprite.position
		sprite_base_scale = sprite.scale
		sprite.scale = sprite_base_scale * 0.85
		var spawn_tween := create_tween()
		spawn_tween.tween_property(sprite, "scale", sprite_base_scale * 1.08, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		spawn_tween.tween_property(sprite, "scale", sprite_base_scale, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	hover_phase = randf() * TAU
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()


func _process(delta: float) -> void:
	if not sprite:
		return

	hover_phase += delta * 2.6
	sprite.position = sprite_base_position + Vector2(0.0, sin(hover_phase) * 1.8)
	sprite.rotation = sin(hover_phase * 0.55) * 0.05
	sprite.modulate = Color(1, 1, 1, 0.92 + max(sin(hover_phase * 1.7), 0.0) * 0.08)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		var picked_up := true
		if body.has_method("collect"):
			picked_up = body.collect(item)
		if picked_up:
			queue_free()
		return

	if body.is_in_group("enemies"):
		var direction := (body.global_position - global_position).normalized()
		body.take_damage(damage_amount, direction, is_critical)
		queue_free()
