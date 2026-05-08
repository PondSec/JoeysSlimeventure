extends Node2D

@onready var cart_sprite: Sprite2D = $VisualRoot/CartSprite
@onready var shadow_sprite: Polygon2D = $VisualRoot/ShadowShadow
@onready var prompt_panel: PanelContainer = $PromptRoot/PromptPanel
@onready var prompt_label: Label = $PromptRoot/PromptPanel/PromptLabel
@onready var interaction_area: Area2D = $InteractionArea

var current_player: Node2D = null
var base_cart_position := Vector2.ZERO
var base_shadow_position := Vector2.ZERO
var base_shadow_scale := Vector2.ONE
var hover_time := 0.0


func _ready() -> void:
	base_cart_position = cart_sprite.position
	base_shadow_position = shadow_sprite.position
	base_shadow_scale = shadow_sprite.scale
	prompt_panel.visible = false
	prompt_label.text = "[E] Shop oeffnen"
	prompt_panel.add_theme_stylebox_override("panel", _make_prompt_style())
	prompt_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	prompt_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	prompt_label.add_theme_constant_override("outline_size", 4)
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	hover_time += delta
	cart_sprite.position = base_cart_position + Vector2(0.0, sin(hover_time * 1.6) * 2.0)
	shadow_sprite.scale.x = base_shadow_scale.x + sin(hover_time * 1.6) * 0.04
	var shadow_color := shadow_sprite.color
	shadow_color.a = 0.4 + maxf(sin(hover_time * 1.6), -0.3) * 0.08
	shadow_sprite.color = shadow_color

	if not _can_interact():
		prompt_panel.visible = false
		return

	prompt_panel.visible = not _shop_is_open()
	if Input.is_action_just_pressed("Interact"):
		_open_shop()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		current_player = body


func _on_body_exited(body: Node2D) -> void:
	if body == current_player:
		current_player = null
		prompt_panel.visible = false


func _can_interact() -> bool:
	return current_player != null and is_instance_valid(current_player)


func _shop_is_open() -> bool:
	var shop_ui := get_tree().get_first_node_in_group("shop_ui")
	return shop_ui != null and bool(shop_ui.get("visible"))


func _open_shop() -> void:
	var shop_ui := get_tree().get_first_node_in_group("shop_ui")
	if shop_ui and shop_ui.has_method("open_shop"):
		shop_ui.call("open_shop")


func _make_prompt_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	style.border_color = Color(0.97, 0.79, 0.51, 0.95)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style
