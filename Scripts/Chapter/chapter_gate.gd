extends Node2D

const FEEDBACK_FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const ChapterContent := preload("res://Scripts/Chapter/chapter_content.gd")

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

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D
@onready var title_label: Label = $TitleLabel
@onready var status_label: Label = $StatusLabel
@onready var prompt_label: Label = $PromptLabel
@onready var area: Area2D = $Area2D


func _ready() -> void:
	feedback_font = load(FEEDBACK_FONT_PATH) as FontFile
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
	sprite.position.y = sprite_base_position.y + sin(local_time * 1.8) * (4.0 if not is_locked else 2.0)
	light.energy = lerpf(light.energy, _target_light_energy(), delta * 4.0)
	var base_scale: float = 0.92 if not player_in_range else 0.98
	light.texture_scale = lerpf(light.texture_scale, base_scale + sin(local_time * 2.1) * 0.02, delta * 3.0)

	if player_in_range and interact_cooldown <= 0.0 and Input.is_action_just_pressed("Interact"):
		_activate_gate()


func _apply_theme() -> void:
	if feedback_font:
		title_label.add_theme_font_override("font", feedback_font)
		status_label.add_theme_font_override("font", feedback_font)
		prompt_label.add_theme_font_override("font", feedback_font)

	title_label.text = gate_title
	title_label.visible = player_in_range
	title_label.position = Vector2(-110.0, -112.0)
	title_label.size = Vector2(220.0, 22.0)
	title_label.add_theme_color_override("font_color", accent_color.lightened(0.32) if not is_locked else Color(0.62, 0.62, 0.68, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	title_label.add_theme_constant_override("outline_size", 5)
	title_label.add_theme_font_size_override("font_size", 14)

	if is_exit_gate:
		status_label.text = gate_subtitle
	elif is_completed:
		status_label.text = "ABGESCHLOSSEN"
	elif is_locked:
		status_label.text = "VERSIEGELT"
	else:
		status_label.text = gate_subtitle

	status_label.visible = player_in_range
	status_label.position = Vector2(-120.0, -88.0)
	status_label.size = Vector2(240.0, 20.0)
	status_label.add_theme_color_override("font_color", accent_color if not is_locked else Color(0.48, 0.48, 0.54, 1.0))
	status_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.add_theme_font_size_override("font_size", 11)

	prompt_label.visible = false
	prompt_label.text = "[E] weiter" if is_exit_gate else "[E] betreten"
	prompt_label.position = Vector2(-78.0, 26.0)
	prompt_label.size = Vector2(156.0, 20.0)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	prompt_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	prompt_label.add_theme_constant_override("outline_size", 4)
	prompt_label.add_theme_font_size_override("font_size", 10)

	sprite.modulate = accent_color.lightened(0.08) if not is_locked else Color(0.3, 0.32, 0.38, 0.96)
	sprite.scale = Vector2(1.08, 1.28) if not is_exit_gate else Vector2(0.98, 1.16)
	light.color = accent_color.lerp(Color(0.94, 0.92, 0.84, 1.0), 0.84)
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
		_notify_player("Diese Tuere ist noch versiegelt.", "info")
		return

	if is_exit_gate and interaction_handler.is_valid():
		interaction_handler.call()
		return

	if interaction_handler.is_valid():
		interaction_handler.call()
		return

	var started: bool = get_node("/root/ChapterProgress").start_chapter(chapter_index)
	if not started:
		var meta: Dictionary = ChapterContent.get_chapter_meta(chapter_index)
		_notify_player("%s folgt als naechstes Kapitel." % str(meta.get("short_title", "Dieses Kapitel")), "info")


func _on_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players"):
		return
	player_in_range = true
	occupying_player = body
	title_label.visible = true
	status_label.visible = true
	prompt_label.visible = not is_locked
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


func _notify_player(message: String, toast_type: String) -> void:
	if occupying_player == null:
		return

	if occupying_player.has_method("_show_feedback_toast"):
		occupying_player.call("_show_feedback_toast", message, toast_type, null)
	elif occupying_player.has_method("show_toast"):
		occupying_player.call("show_toast", message)
