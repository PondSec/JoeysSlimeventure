extends CanvasLayer

class_name PlayerFeedbackUI

const FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const UI_CLICK_PATH := "res://Assets/Sounds/Polish/click_005.wav"
const UI_CONFIRM_PATH := "res://Assets/Sounds/Polish/confirmation_002.wav"
const UI_REWARD_PATH := "res://Assets/Sounds/Polish/power_up_3.ogg"
const TOAST_INFO_ICON_PATH := "res://Assets/GUI/Icons/Polish/toast_info.png"
const TOAST_REWARD_ICON_PATH := "res://Assets/GUI/Icons/Polish/toast_reward.png"
const TOAST_WARNING_ICON_PATH := "res://Assets/GUI/Icons/Polish/toast_warning.png"
const TOAST_ERROR_ICON_PATH := "res://Assets/GUI/Icons/Polish/toast_error.png"
const MAX_VISIBLE_TOASTS := 4
const TOAST_LABELS := {
	"info": "SYSTEM",
	"reward": "LOOT",
	"warning": "WARNUNG",
	"error": "ALARM"
}

const TOAST_COLORS := {
	"info": {
		"bg": Color(0.07, 0.11, 0.18, 0.9),
		"border": Color(0.4, 0.82, 1.0, 1.0)
	},
	"reward": {
		"bg": Color(0.08, 0.18, 0.12, 0.92),
		"border": Color(0.42, 0.96, 0.66, 1.0)
	},
	"warning": {
		"bg": Color(0.21, 0.11, 0.06, 0.92),
		"border": Color(1.0, 0.78, 0.33, 1.0)
	},
	"error": {
		"bg": Color(0.24, 0.07, 0.09, 0.94),
		"border": Color(1.0, 0.37, 0.41, 1.0)
	}
}

@onready var health_bar: TextureProgressBar = $TextureProgressBar
@onready var health_label: Label = $HealthLabel
@onready var hotbar: Control = $HotBar

var health_bar_chip: TextureProgressBar
var damage_flash: ColorRect
var heal_flash: ColorRect
var low_health_vignette: ColorRect
var toast_container: VBoxContainer
var action_banner: PanelContainer
var action_banner_label: Label
var ui_player: AudioStreamPlayer
var reward_player: AudioStreamPlayer

var feedback_font: FontFile
var click_stream: AudioStream
var confirm_stream: AudioStream
var reward_stream: AudioStream
var info_icon: Texture2D
var reward_icon: Texture2D
var warning_icon: Texture2D
var error_icon: Texture2D

var current_health_value := 0.0
var low_health_warning_cooldown := 0.0
var banner_tween: Tween


func _ready() -> void:
	feedback_font = load(FONT_PATH) as FontFile
	click_stream = load(UI_CLICK_PATH)
	confirm_stream = load(UI_CONFIRM_PATH)
	reward_stream = load(UI_REWARD_PATH)
	info_icon = load(TOAST_INFO_ICON_PATH)
	reward_icon = load(TOAST_REWARD_ICON_PATH)
	warning_icon = load(TOAST_WARNING_ICON_PATH)
	error_icon = load(TOAST_ERROR_ICON_PATH)

	_setup_health_chip_bar()
	_setup_fullscreen_feedback()
	_setup_toasts()
	_setup_action_banner()
	_setup_audio_players()

	current_health_value = health_bar.value
	_apply_health_visuals(_get_health_ratio(current_health_value, health_bar.max_value))
	_sync_label_text(int(current_health_value), int(health_bar.max_value))


func _process(delta: float) -> void:
	low_health_warning_cooldown = max(low_health_warning_cooldown - delta, 0.0)


func sync_health(current: int, max_health: int, animate: bool = true) -> void:
	if not health_bar:
		return

	var previous_value: float = current_health_value
	var previous_max: float = health_bar.max_value
	var effective_max: int = maxi(max_health, 1)

	health_bar.max_value = effective_max
	if health_bar_chip:
		health_bar_chip.max_value = effective_max

	if previous_max <= 0.0:
		previous_max = effective_max

	if previous_value <= 0.0 and current_health_value == 0.0:
		previous_value = float(current)

	current_health_value = current
	_sync_label_text(current, effective_max)

	if not animate:
		health_bar.value = current
		if health_bar_chip:
			health_bar_chip.value = current
		_apply_health_visuals(_get_health_ratio(current, effective_max))
		return

	var ratio: float = _get_health_ratio(current, effective_max)
	_apply_health_visuals(ratio)

	if current < previous_value:
		if health_bar_chip:
			health_bar_chip.value = previous_value
		var damage_tween := create_tween()
		damage_tween.tween_property(health_bar, "value", current, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if health_bar_chip:
			damage_tween.tween_interval(0.08)
			damage_tween.tween_property(health_bar_chip, "value", current, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif current > previous_value:
		if health_bar_chip:
			health_bar_chip.value = current
		var heal_tween := create_tween()
		heal_tween.tween_property(health_bar, "value", current, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		health_bar.value = current
		if health_bar_chip:
			health_bar_chip.value = current


func notify_player_hit(amount: int, current: int, max_health: int) -> void:
	_flash_overlay(damage_flash, clamp(0.12 + float(amount) / max(max_health, 1) * 0.55, 0.12, 0.32))
	_punch_control(health_bar, Vector2(1.06, 1.08), 0.16)
	_punch_control(health_label, Vector2(1.08, 1.08), 0.16)
	_punch_control(hotbar, Vector2(1.03, 1.03), 0.18)

	var ratio := _get_health_ratio(current, max_health)
	if ratio <= 0.25 and low_health_warning_cooldown <= 0.0:
		show_banner("CRITICAL SLIME", Color(1.0, 0.4, 0.36), 0.75)
		show_toast("Dein Schleim kocht. Kurz rausnehmen und resetten.", "warning")
		low_health_warning_cooldown = 5.0


func notify_player_heal(amount: int, current: int, max_health: int) -> void:
	_flash_overlay(heal_flash, clamp(0.08 + float(amount) / max(max_health, 1) * 0.4, 0.08, 0.22))
	_punch_control(health_bar, Vector2(1.04, 1.06), 0.18)
	_punch_control(health_label, Vector2(1.04, 1.04), 0.18)


func show_loot_toast(item_name: String, icon_texture: Texture2D = null, amount: int = 1) -> void:
	var quantity_prefix := "+%d " % amount if amount > 1 else "+1 "
	show_toast(quantity_prefix + item_name, "reward", icon_texture, 3.6)


func show_notification(message: String) -> void:
	show_toast(message, "reward", null, 4.2)


func show_toast(message: String, toast_type: String = "info", icon_texture: Texture2D = null, display_duration: float = -1.0) -> void:
	if not toast_container:
		return
	if toast_container.get_child_count() >= MAX_VISIBLE_TOASTS:
		var oldest_toast: Node = toast_container.get_child(0)
		if oldest_toast:
			oldest_toast.queue_free()

	var effective_icon: Texture2D = icon_texture if icon_texture != null else _get_default_toast_icon(toast_type)
	var is_default_icon := icon_texture == null and effective_icon != null
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.custom_minimum_size = Vector2(320, 56)
	toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toast.clip_contents = true
	toast.modulate = Color(1, 1, 1, 0)
	toast.scale = Vector2(0.96, 0.96)

	var colors = TOAST_COLORS.get(toast_type, TOAST_COLORS["info"])
	var style := StyleBoxFlat.new()
	style.bg_color = colors["bg"]
	style.border_color = colors["border"]
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 12
	toast.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var accent_bar := ColorRect.new()
	accent_bar.color = colors["border"].lightened(0.08)
	accent_bar.custom_minimum_size = Vector2(6, 36)
	accent_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	accent_bar.modulate = Color(1, 1, 1, 0.0)
	row.add_child(accent_bar)

	var icon_frame: PanelContainer
	if effective_icon:
		icon_frame = PanelContainer.new()
		icon_frame.custom_minimum_size = Vector2(42, 42)
		icon_frame.scale = Vector2(0.88, 0.88)
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = colors["bg"].lightened(0.08)
		icon_style.border_color = colors["border"].lightened(0.14)
		icon_style.set_border_width_all(1)
		icon_style.corner_radius_top_left = 12
		icon_style.corner_radius_top_right = 12
		icon_style.corner_radius_bottom_left = 12
		icon_style.corner_radius_bottom_right = 12
		icon_frame.add_theme_stylebox_override("panel", icon_style)

		var icon := TextureRect.new()
		icon.texture = effective_icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(26, 26)
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if is_default_icon:
			icon.modulate = colors["border"].lightened(0.18)
		icon_frame.add_child(icon)
		row.add_child(icon_frame)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 2)

	var category_label := Label.new()
	category_label.text = TOAST_LABELS.get(toast_type, "SYSTEM")
	category_label.add_theme_color_override("font_color", colors["border"].lightened(0.2))
	category_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	category_label.add_theme_constant_override("outline_size", 4)
	category_label.add_theme_font_size_override("font_size", 11)
	if feedback_font:
		category_label.add_theme_font_override("font", feedback_font)
	text_column.add_child(category_label)

	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 16)
	if feedback_font:
		label.add_theme_font_override("font", feedback_font)
	text_column.add_child(label)
	row.add_child(text_column)
	toast.add_child(row)
	toast_container.add_child(toast)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(toast, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(accent_bar, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if icon_frame:
		tween.tween_property(icon_frame, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	var toast_duration: float = display_duration if display_duration > 0.0 else (2.1 if toast_type != "reward" else 2.5)
	tween.tween_interval(toast_duration)
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(toast, "scale", Vector2(0.97, 0.97), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(toast.queue_free)

	if toast_type == "reward":
		_play_reward_sound()
	elif toast_type == "error":
		_play_ui_sound(click_stream, -1.0)
	else:
		_play_ui_sound(confirm_stream if confirm_stream else click_stream)


func show_banner(text: String, accent: Color = Color(1.0, 0.76, 0.32), duration: float = 0.45) -> void:
	if not action_banner or not action_banner_label:
		return

	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()

	var style: StyleBox = action_banner.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.border_color = accent

	action_banner_label.text = text
	action_banner_label.add_theme_color_override("font_color", accent.lightened(0.35))
	action_banner.visible = true
	action_banner.modulate = Color(1, 1, 1, 0)
	action_banner.scale = Vector2(0.9, 0.9)

	banner_tween = create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(action_banner, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	banner_tween.tween_property(action_banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.set_parallel(false)
	banner_tween.tween_interval(duration)
	banner_tween.set_parallel(true)
	banner_tween.tween_property(action_banner, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	banner_tween.tween_property(action_banner, "scale", Vector2(0.95, 0.95), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	banner_tween.set_parallel(false)
	banner_tween.tween_callback(func() -> void:
		action_banner.visible = false
	)

	_play_ui_sound(confirm_stream if confirm_stream else click_stream, randf_range(0.96, 1.05))


func _setup_health_chip_bar() -> void:
	if not health_bar:
		return

	health_bar_chip = health_bar.duplicate()
	health_bar_chip.name = "HealthBarChip"
	health_bar_chip.value = health_bar.value
	health_bar_chip.modulate = Color(1.0, 0.52, 0.4, 0.68)
	health_bar_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar_chip.tint_progress = Color(1.0, 0.62, 0.42, 0.74)
	add_child(health_bar_chip)
	move_child(health_bar_chip, health_bar.get_index())
	health_bar.z_index = 2
	health_bar_chip.z_index = 1


func _setup_fullscreen_feedback() -> void:
	damage_flash = _create_fullscreen_rect(Color(1.0, 0.14, 0.12, 0.0))
	heal_flash = _create_fullscreen_rect(Color(0.32, 1.0, 0.65, 0.0))
	low_health_vignette = _create_fullscreen_rect(Color(0.45, 0.03, 0.05, 0.0))

	low_health_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(low_health_vignette)
	add_child(damage_flash)
	add_child(heal_flash)
	move_child(low_health_vignette, 0)
	move_child(damage_flash, 1)
	move_child(heal_flash, 2)


func _setup_toasts() -> void:
	toast_container = VBoxContainer.new()
	toast_container.name = "GameplayToasts"
	toast_container.anchors_preset = Control.PRESET_TOP_RIGHT
	toast_container.anchor_left = 1.0
	toast_container.anchor_right = 1.0
	toast_container.offset_left = -360.0
	toast_container.offset_top = 28.0
	toast_container.offset_right = -26.0
	toast_container.offset_bottom = 420.0
	toast_container.alignment = BoxContainer.ALIGNMENT_END
	toast_container.add_theme_constant_override("separation", 8)
	toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_container)


func _setup_action_banner() -> void:
	action_banner = PanelContainer.new()
	action_banner.visible = false
	action_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_banner.anchors_preset = Control.PRESET_TOP_WIDE
	action_banner.anchor_left = 0.5
	action_banner.anchor_right = 0.5
	action_banner.offset_left = -160.0
	action_banner.offset_top = 38.0
	action_banner.offset_right = 160.0
	action_banner.offset_bottom = 86.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.17, 0.92)
	style.border_color = Color(1.0, 0.76, 0.32, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	action_banner.add_theme_stylebox_override("panel", style)

	action_banner_label = Label.new()
	action_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_banner_label.anchors_preset = Control.PRESET_FULL_RECT
	action_banner_label.offset_left = 0
	action_banner_label.offset_top = 0
	action_banner_label.offset_right = 0
	action_banner_label.offset_bottom = 0
	action_banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	action_banner_label.add_theme_constant_override("outline_size", 6)
	action_banner_label.add_theme_font_size_override("font_size", 21)
	if feedback_font:
		action_banner_label.add_theme_font_override("font", feedback_font)
	action_banner.add_child(action_banner_label)
	add_child(action_banner)


func _setup_audio_players() -> void:
	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UISfx"
	ui_player.bus = "Master"
	add_child(ui_player)

	reward_player = AudioStreamPlayer.new()
	reward_player.name = "RewardSfx"
	reward_player.bus = "Master"
	add_child(reward_player)


func _create_fullscreen_rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.offset_left = 0.0
	rect.offset_top = 0.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0
	rect.color = color
	return rect


func _sync_label_text(current: int, max_health: int) -> void:
	if not health_label:
		return

	health_label.text = "HP %d / %d" % [current, max_health]
	health_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	health_label.add_theme_constant_override("outline_size", 5)
	health_label.add_theme_font_size_override("font_size", 18)
	if feedback_font:
		health_label.add_theme_font_override("font", feedback_font)


func _apply_health_visuals(health_ratio: float) -> void:
	if not health_bar:
		return

	var good_color := Color(0.33, 1.0, 0.63, 1.0)
	var mid_color := Color(1.0, 0.77, 0.35, 1.0)
	var danger_color := Color(1.0, 0.34, 0.34, 1.0)
	var target_color := good_color

	if health_ratio <= 0.33:
		target_color = danger_color
	elif health_ratio <= 0.65:
		var blend: float = inverse_lerp(0.33, 0.65, health_ratio)
		target_color = danger_color.lerp(mid_color, blend)

	health_bar.tint_progress = target_color
	if health_bar_chip:
		health_bar_chip.tint_progress = danger_color.lerp(mid_color, clamp(health_ratio * 1.6, 0.0, 1.0))

	var overlay_alpha := 0.0
	if health_ratio <= 0.4:
		overlay_alpha = remap(health_ratio, 0.0, 0.4, 0.28, 0.0)
	overlay_alpha = clamp(overlay_alpha, 0.0, 0.28)
	low_health_vignette.color.a = overlay_alpha
	health_label.modulate = Color.WHITE.lerp(target_color.lightened(0.2), clamp(1.0 - health_ratio, 0.0, 0.75))


func _flash_overlay(rect: ColorRect, peak_alpha: float) -> void:
	if not rect:
		return

	rect.color.a = peak_alpha
	var tween := create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _punch_control(control: Control, peak_scale: Vector2, duration: float) -> void:
	if not control:
		return

	var base_scale := control.scale
	control.pivot_offset = control.size * 0.5
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(base_scale.x * peak_scale.x, base_scale.y * peak_scale.y), duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", base_scale, duration * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _play_ui_sound(stream: AudioStream, pitch_scale: float = 1.0) -> void:
	if not ui_player or not stream:
		return

	ui_player.stream = stream
	ui_player.pitch_scale = pitch_scale
	ui_player.volume_db = -10.0
	ui_player.play()


func _play_reward_sound() -> void:
	if not reward_player or not reward_stream:
		return

	reward_player.stream = reward_stream
	reward_player.pitch_scale = randf_range(0.96, 1.05)
	reward_player.volume_db = -8.0
	reward_player.play()


func _get_health_ratio(current: float, max_health: float) -> float:
	return clamp(current / max(max_health, 1.0), 0.0, 1.0)


func _get_default_toast_icon(toast_type: String) -> Texture2D:
	match toast_type:
		"reward":
			return reward_icon
		"warning":
			return warning_icon
		"error":
			return error_icon
		_:
			return info_icon
