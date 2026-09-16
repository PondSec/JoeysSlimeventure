extends Node2D

const FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const MARKER_LIGHT_TEXTURE := preload("res://Assets/Light/torch_light.png")
const LOST_MEMORY_DURATION := 1.35

var enemy: Node2D
var player: Node2D
var was_alert := false
var lost_memory := 0.0
var displayed_symbol := ""
var label: Label
var marker_light: PointLight2D


func _ready() -> void:
	enemy = get_parent() as Node2D
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(24.0, 18.0)
	label.position = Vector2(-12.0, -48.0)
	label.visible = false
	label.light_mask = 0
	label.z_index = 20
	# Alerts are UI-like world markers: they must remain readable in caves even
	# when the enemy happens to be outside a player light cone.
	var marker_material := CanvasItemMaterial.new()
	marker_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	label.material = marker_material
	var font := load(FONT_PATH) as FontFile
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.08, 0.95))
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	marker_light = PointLight2D.new()
	marker_light.position = Vector2(0.0, -40.0)
	marker_light.texture = MARKER_LIGHT_TEXTURE
	marker_light.texture_scale = 0.16
	marker_light.energy = 0.0
	marker_light.enabled = false
	marker_light.z_index = 19
	add_child(marker_light)


func _process(delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		queue_free()
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as Node2D
		return

	var sees_player := enemy.global_position.distance_to(player.global_position) <= _notice_distance()
	if sees_player:
		lost_memory = LOST_MEMORY_DURATION
		was_alert = true
		_set_symbol("!", Color(0.76, 0.94, 1.0, 1.0))
	elif was_alert:
		lost_memory = maxf(lost_memory - delta, 0.0)
		if lost_memory > 0.0:
			_set_symbol("?", Color(0.9, 0.82, 1.0, 1.0))
		else:
			was_alert = false
			_set_symbol("")


func _notice_distance() -> float:
	if bool(player.get("is_glowing")) and enemy.get("glow_detection_range") is float:
		return float(enemy.get("glow_detection_range"))
	for property_name in ["detection_range", "aggro_range", "dark_detection_range"]:
		var value: Variant = enemy.get(property_name)
		if value is float or value is int:
			return float(value)
	return 180.0


func _set_symbol(symbol: String, color: Color = Color.WHITE) -> void:
	if label == null:
		return
	if symbol == displayed_symbol:
		return
	displayed_symbol = symbol
	label.text = symbol
	label.visible = not symbol.is_empty()
	if symbol.is_empty():
		marker_light.enabled = false
		marker_light.energy = 0.0
		return
	label.add_theme_color_override("font_color", color)
	marker_light.enabled = true
	marker_light.color = color
	marker_light.energy = 0.26
	label.scale = Vector2(0.35, 0.35)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.18)
	tween.parallel().tween_property(label, "position:y", -53.0, 0.18).from(-44.0)
	tween.tween_property(label, "position:y", -48.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
