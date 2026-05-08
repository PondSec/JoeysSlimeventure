extends Node2D

class_name StarEncounter

signal captured(star_id: String)

const StarCatalog := preload("res://Scripts/star_catalog.gd")
const FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const GLOW_TEXTURE := preload("res://Assets/Light/torch_light.png")
const CATCH_RADIUS := 110.0
const CATCH_TIME_REQUIRED := 1.35

var star_id := ""
var player: CharacterBody2D
var bob_time := 0.0
var catch_progress := 0.0
var base_position := Vector2.ZERO
var encounter_color := Color(1.0, 1.0, 1.0, 1.0)
var cached_font: FontFile

var star_sprite: Sprite2D
var glow_light: PointLight2D
var prompt_label: Label
var progress_bar: ProgressBar


func configure(new_star_id: String, player_node: CharacterBody2D) -> void:
	star_id = new_star_id
	player = player_node
	if is_inside_tree():
		_apply_definition()


func _ready() -> void:
	top_level = true
	base_position = global_position
	_create_nodes()
	_apply_definition()


func _process(delta: float) -> void:
	if star_id.is_empty():
		return

	bob_time += delta
	global_position = base_position + Vector2(0.0, sin(bob_time * 2.4) * 10.0)
	if glow_light:
		glow_light.energy = 0.72 + sin(bob_time * 3.2) * 0.14

	if player == null or not is_instance_valid(player):
		_hide_capture_ui()
		return

	var blocked := player.has_method("_is_gameplay_input_blocked") and bool(player.call("_is_gameplay_input_blocked"))
	var in_range := global_position.distance_to(player.global_position) <= CATCH_RADIUS
	if not in_range or blocked:
		catch_progress = 0.0
		_hide_capture_ui()
		return

	_show_capture_ui()
	if Input.is_action_pressed("Interact"):
		catch_progress = min(catch_progress + delta, CATCH_TIME_REQUIRED)
		progress_bar.value = catch_progress
		prompt_label.text = "[E] %s..." % StarCatalog.get_item(star_id).get_display_name()
		if catch_progress >= CATCH_TIME_REQUIRED:
			emit_signal("captured", star_id)
			queue_free()
	else:
		catch_progress = max(catch_progress - delta * 1.6, 0.0)
		progress_bar.value = catch_progress
		prompt_label.text = "[E] %s" % StarCatalog.get_item(star_id).get_display_name()


func _create_nodes() -> void:
	star_sprite = Sprite2D.new()
	add_child(star_sprite)

	glow_light = PointLight2D.new()
	glow_light.texture = GLOW_TEXTURE
	glow_light.texture_scale = 1.2
	glow_light.energy = 0.8
	add_child(glow_light)

	prompt_label = Label.new()
	prompt_label.position = Vector2(-96.0, -78.0)
	prompt_label.size = Vector2(192.0, 24.0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false
	prompt_label.add_theme_font_override("font", _load_font())
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.add_theme_color_override("font_color", Color(0.92, 0.99, 0.97, 1.0))
	prompt_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.08, 1.0))
	prompt_label.add_theme_constant_override("outline_size", 3)
	add_child(prompt_label)

	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(-52.0, -52.0)
	progress_bar.size = Vector2(104.0, 8.0)
	progress_bar.min_value = 0.0
	progress_bar.max_value = CATCH_TIME_REQUIRED
	progress_bar.show_percentage = false
	progress_bar.visible = false
	add_child(progress_bar)


func _apply_definition() -> void:
	if star_sprite == null or star_id.is_empty():
		return

	var definition := StarCatalog.get_definition(star_id)
	encounter_color = definition.get("encounter_color", Color(1.0, 1.0, 1.0, 1.0)) as Color
	star_sprite.texture = StarCatalog.get_item(star_id).texture
	star_sprite.scale = Vector2(3.2, 3.2)
	star_sprite.modulate = Color(1.0, 1.0, 1.0, 0.98)
	star_sprite.centered = true

	if glow_light:
		glow_light.color = encounter_color

	if progress_bar:
		progress_bar.modulate = encounter_color.lightened(0.2)

	if prompt_label:
		prompt_label.text = "[E] %s" % StarCatalog.get_item(star_id).get_display_name()


func _show_capture_ui() -> void:
	if prompt_label:
		prompt_label.visible = true
	if progress_bar:
		progress_bar.visible = true


func _hide_capture_ui() -> void:
	if prompt_label:
		prompt_label.visible = false
	if progress_bar:
		progress_bar.visible = false
		progress_bar.value = 0.0


func _load_font() -> FontFile:
	if cached_font == null:
		cached_font = load(FONT_PATH) as FontFile
	return cached_font
