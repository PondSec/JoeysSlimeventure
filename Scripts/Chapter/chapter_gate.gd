extends Node2D

const FEEDBACK_FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const ChapterContent := preload("res://Scripts/Chapter/chapter_content.gd")
const PORTAL_SHEET := preload("res://Assets/Door/portal_entry_sheet.png")
const PORTAL_COLUMNS := 8
const PORTAL_ROWS := 2
const PORTAL_ENTRY_FPS := 12.0
const PORTAL_TOP_REGION_HEIGHT := 294.0
const PORTAL_BOTTOM_REGION_Y := 350.0
const PORTAL_BOTTOM_REGION_HEIGHT := 294.0

var chapter_index: int = 0
var gate_title: String = ""
var gate_subtitle: String = ""
var accent_color: Color = Color(0.82, 0.88, 1.0, 1.0)
var is_locked: bool = false
var is_completed: bool = false
var is_exit_gate: bool = false
var interaction_handler: Callable = Callable()
var player_in_range: bool = false
var interact_cooldown: float = 0.0
var local_time: float = 0.0
var feedback_font: FontFile
var occupying_player: Node2D
var sprite_base_position: Vector2 = Vector2.ZERO
var is_activating: bool = false

@onready var sprite: AnimatedSprite2D = $PortalSprite
@onready var light: PointLight2D = $PointLight2D
@onready var title_label: Label = $TitleLabel
@onready var status_label: Label = $StatusLabel
@onready var prompt_label: Label = $PromptLabel
@onready var area: Area2D = $Area2D


func _ready() -> void:
	feedback_font = load(FEEDBACK_FONT_PATH) as FontFile
	_configure_portal_frames()
	sprite_base_position = sprite.position
	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)
	_apply_theme()


func configure_chapter_gate(new_chapter_index: int, meta: Dictionary, unlocked: bool, completed: bool) -> void:
	chapter_index = new_chapter_index
	gate_title = str(meta.get("door_suffix", "Kapitel"))
	gate_subtitle = str(meta.get("short_title", ""))
	accent_color = meta.get("accent", Color(0.82, 0.88, 1.0, 1.0)) as Color
	is_locked = not unlocked
	is_completed = completed
	is_exit_gate = false
	interaction_handler = Callable()
	_apply_theme()


func configure_exit_gate(title: String, subtitle: String, accent: Color, callback: Callable) -> void:
	chapter_index = 0
	gate_title = title
	gate_subtitle = subtitle
	accent_color = accent
	is_locked = false
	is_completed = false
	is_exit_gate = true
	interaction_handler = callback
	_apply_theme()


func _process(delta: float) -> void:
	local_time += delta
	interact_cooldown = maxf(interact_cooldown - delta, 0.0)
	# The portal deliberately stays still while idle. Its full animation is a
	# one-shot entry response, rather than ambient visual noise.
	sprite.position = sprite_base_position
	light.energy = lerpf(light.energy, _target_light_energy(), delta * 4.0)
	var base_scale: float = 0.92 if not player_in_range else 0.98
	light.texture_scale = lerpf(light.texture_scale, base_scale + sin(local_time * 2.1) * 0.02, delta * 3.0)

	if player_in_range and not is_activating and interact_cooldown <= 0.0 and Input.is_action_just_pressed("Interact"):
		_activate_gate()


func _apply_theme() -> void:
	if feedback_font:
		title_label.add_theme_font_override("font", feedback_font)
		status_label.add_theme_font_override("font", feedback_font)
		prompt_label.add_theme_font_override("font", feedback_font)

	# Chapter names and status copy used to cover the portal. Keep the interaction
	# language intentionally quiet: the only contextual text is the E prompt.
	title_label.text = ""
	title_label.visible = false
	title_label.position = Vector2(-110.0, -112.0)
	title_label.size = Vector2(220.0, 22.0)
	title_label.add_theme_color_override("font_color", accent_color.lightened(0.32) if not is_locked else Color(0.62, 0.62, 0.68, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	title_label.add_theme_constant_override("outline_size", 5)
	title_label.add_theme_font_size_override("font_size", 14)

	status_label.text = ""
	status_label.visible = false
	status_label.position = Vector2(-120.0, -88.0)
	status_label.size = Vector2(240.0, 20.0)
	status_label.add_theme_color_override("font_color", accent_color if not is_locked else Color(0.48, 0.48, 0.54, 1.0))
	status_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.add_theme_font_size_override("font_size", 11)

	prompt_label.visible = false
	prompt_label.text = "E eintreten"
	prompt_label.position = Vector2(-78.0, 26.0)
	prompt_label.size = Vector2(156.0, 20.0)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	prompt_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	prompt_label.add_theme_constant_override("outline_size", 4)
	prompt_label.add_theme_font_size_override("font_size", 10)

	sprite.modulate = Color.WHITE if not is_locked else Color(0.38, 0.42, 0.56, 0.82)
	light.color = Color(0.44, 0.64, 1.0, 1.0)
	light.energy = _target_light_energy()
	light.enabled = true


func _target_light_energy() -> float:
	if is_locked:
		return 0.02 if not player_in_range else 0.05
	if is_completed:
		return 0.08 if not player_in_range else 0.16
	return (0.05 if not player_in_range else 0.11) if not is_exit_gate else (0.06 if not player_in_range else 0.13)


func _activate_gate() -> void:
	interact_cooldown = 0.35
	if is_locked:
		return
	if is_activating:
		return
	_begin_entry()


func _begin_entry() -> void:
	is_activating = true
	prompt_label.visible = false
	area.set_deferred("monitoring", false)
	sprite.frame = 0
	sprite.play(&"enter")
	await sprite.animation_finished
	_complete_entry()


func _complete_entry() -> void:
	if not is_inside_tree():
		return

	if is_exit_gate and interaction_handler.is_valid():
		interaction_handler.call()
		return

	if interaction_handler.is_valid():
		interaction_handler.call()
		return

	var started: bool = get_node("/root/ChapterProgress").start_chapter(chapter_index)
	if not started:
		is_activating = false
		area.set_deferred("monitoring", true)
		if player_in_range:
			prompt_label.visible = true
		sprite.stop()
		sprite.frame = 0


func _on_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players"):
		return
	player_in_range = true
	occupying_player = body
	title_label.visible = false
	status_label.visible = false
	prompt_label.visible = not is_locked and not is_activating
	if is_locked:
		prompt_label.visible = false


func _on_area_body_exited(body: Node2D) -> void:
	if body != occupying_player:
		return
	player_in_range = false
	occupying_player = null
	title_label.visible = false
	status_label.visible = false
	prompt_label.visible = false


func _configure_portal_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"enter")
	frames.set_animation_speed(&"enter", PORTAL_ENTRY_FPS)
	frames.set_animation_loop(&"enter", false)

	var sheet_size := PORTAL_SHEET.get_size()
	for frame_index in range(PORTAL_COLUMNS * PORTAL_ROWS):
		var column := frame_index % PORTAL_COLUMNS
		var row := frame_index / PORTAL_COLUMNS
		var x_start := roundf(float(column) * sheet_size.x / float(PORTAL_COLUMNS))
		var x_end := roundf(float(column + 1) * sheet_size.x / float(PORTAL_COLUMNS))
		var region_y := 0.0 if row == 0 else PORTAL_BOTTOM_REGION_Y
		var region_height := PORTAL_TOP_REGION_HEIGHT if row == 0 else PORTAL_BOTTOM_REGION_HEIGHT
		var atlas := AtlasTexture.new()
		atlas.atlas = PORTAL_SHEET
		atlas.region = Rect2(x_start, region_y, x_end - x_start, region_height)
		frames.add_frame(&"enter", atlas)

	sprite.sprite_frames = frames
	sprite.animation = &"enter"
	sprite.frame = 0
	sprite.pause()


func _notify_player(message: String, toast_type: String) -> void:
	if occupying_player == null:
		return

	if occupying_player.has_method("_show_feedback_toast"):
		occupying_player.call("_show_feedback_toast", message, toast_type, null)
	elif occupying_player.has_method("show_toast"):
		occupying_player.call("show_toast", message)
