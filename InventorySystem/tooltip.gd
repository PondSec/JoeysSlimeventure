extends Control

const FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const MIN_TOOLTIP_WIDTH := 320.0
const MAX_TOOLTIP_WIDTH := 520.0

@onready var panel: Panel = $Panel
@onready var margin_container: MarginContainer = $Panel/MarginContainer
@onready var content_box: VBoxContainer = $Panel/MarginContainer/VBoxContainer
@onready var item_name_label: Label = $Panel/MarginContainer/VBoxContainer/ItemName
@onready var description_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/Description
@onready var separator: HSeparator = $Panel/MarginContainer/VBoxContainer/HSeparator
@onready var stats_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/StatsLabel
@onready var skill_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/SkillLabel

var cached_font: FontFile


func _ready() -> void:
	visible = false
	z_index = 100
	_apply_theme()


func show_tooltip(item: InvItem, pointer_position: Vector2) -> void:
	if item == null:
		hide_tooltip()
		return

	item_name_label.text = item.get_display_name()
	item_name_label.modulate = _determine_rarity_color(item.rarity)

	if item.description.is_empty():
		description_label.text = "[color=#a9b7b4]Keine Beschreibung vorhanden.[/color]"
	else:
		description_label.text = "[color=#d9efe5]%s[/color]" % item.description

	var target_width := _compute_tooltip_width(item)
	_apply_tooltip_width(target_width)

	var stat_lines: Array[String] = []
	if item.item_type != "resource":
		stat_lines.append("[color=#86f7bf]Typ:[/color] %s" % item.item_type.capitalize())
	if item.attack_power_bonus != 0:
		stat_lines.append("[color=#ffd76e]Angriff:[/color] %+d" % item.attack_power_bonus)
	if item.damage_bonus != 0.0:
		stat_lines.append("[color=#ffd76e]Schaden:[/color] %+d%%" % int(round(item.damage_bonus * 100.0)))
	if item.attack_speed_bonus != 0.0:
		stat_lines.append("[color=#8fe6ff]Tempo:[/color] %+d%%" % int(round(item.attack_speed_bonus * 100.0)))
	if item.attack_reach_bonus != 0.0:
		stat_lines.append("[color=#8fe6ff]Reichweite:[/color] %+d%%" % int(round(item.attack_reach_bonus * 100.0)))
	if item.knockback_bonus != 0.0:
		stat_lines.append("[color=#8fe6ff]Rueckstoss:[/color] %+d" % int(round(item.knockback_bonus)))
	if item.move_speed_bonus != 0.0:
		stat_lines.append("[color=#8fe6ff]Lauftempo:[/color] %+d%%" % int(round(item.move_speed_bonus * 100.0)))
	if item.health_bonus != 0.0:
		stat_lines.append("[color=#7ff59c]Leben:[/color] %+d%%" % int(round(item.health_bonus * 100.0)))
	if item.crit_chance_bonus != 0.0:
		stat_lines.append("[color=#f9dd7d]Crit-Chance:[/color] %+d%%" % int(round(item.crit_chance_bonus * 100.0)))
	if item.crit_damage_bonus != 0.0:
		stat_lines.append("[color=#f9dd7d]Crit-Schaden:[/color] %+d%%" % int(round(item.crit_damage_bonus * 100.0)))
	if item.throw_damage != 0.0:
		stat_lines.append("[color=#ffb97a]Wurfschaden:[/color] %d" % int(round(item.throw_damage)))
	if item.drop_chance > 0.0:
		stat_lines.append("[color=#c1cfd2]Drop-Chance:[/color] %.1f%%" % (item.drop_chance * 100.0))

	if stat_lines.is_empty():
		stats_label.text = "[color=#8ca19f]Keine passiven Werte.[/color]"
		separator.visible = false
	else:
		stats_label.text = "\n".join(stat_lines)
		separator.visible = true

	if item.skill_name.is_empty() and item.skill_description.is_empty():
		skill_label.text = ""
		skill_label.visible = false
	else:
		skill_label.text = "[color=#86f7bf]%s[/color]\n[color=#d8eadf]%s[/color]" % [
			item.skill_name if not item.skill_name.is_empty() else "Waffenskill",
			item.skill_description if not item.skill_description.is_empty() else "Diese Waffe besitzt einen besonderen Effekt.",
		]
		skill_label.visible = true

	await get_tree().process_frame
	await get_tree().process_frame
	_resize_tooltip_to_content()
	global_position = pointer_position + Vector2(20.0, 18.0)
	_clamp_to_viewport()
	visible = true


func hide_tooltip() -> void:
	visible = false


func _apply_theme() -> void:
	var font := _load_font()
	item_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label in [item_name_label]:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)

	for rich_label in [description_label, stats_label, skill_label]:
		rich_label.add_theme_font_override("normal_font", font)
		rich_label.add_theme_font_size_override("normal_font_size", 14)
		rich_label.fit_content = true
		rich_label.scroll_active = false
		rich_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	panel.add_theme_stylebox_override("panel", _make_panel_style())


func _load_font() -> FontFile:
	if cached_font == null:
		cached_font = load(FONT_PATH) as FontFile
	return cached_font


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.07, 0.96)
	style.border_color = Color(0.18, 0.86, 0.57, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	return style


func _determine_rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return Color("ff8c66")
		"epic":
			return Color("f59fff")
		"rare":
			return Color("86d0ff")
		"uncommon":
			return Color("7ff59c")
		_:
			return Color("f0f6f0")


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var tooltip_size := size

	if global_position.x + tooltip_size.x > viewport_size.x - 8.0:
		global_position.x = viewport_size.x - tooltip_size.x - 8.0
	if global_position.y + tooltip_size.y > viewport_size.y - 8.0:
		global_position.y = viewport_size.y - tooltip_size.y - 8.0
	if global_position.x < 8.0:
		global_position.x = 8.0
	if global_position.y < 8.0:
		global_position.y = 8.0


func _compute_tooltip_width(item: InvItem) -> float:
	var font := _load_font()
	var width := MIN_TOOLTIP_WIDTH
	width = max(width, font.get_string_size(item.get_display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 34.0)
	if not item.skill_name.is_empty():
		width = max(width, font.get_string_size(item.skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 34.0)
	var longest_body_line := maxi(item.description.length(), item.skill_description.length())
	if longest_body_line > 0:
		width = max(width, 290.0 + min(float(longest_body_line) * 1.1, 170.0))
	return clampf(width, MIN_TOOLTIP_WIDTH, MAX_TOOLTIP_WIDTH)


func _apply_tooltip_width(target_width: float) -> void:
	item_name_label.custom_minimum_size = Vector2(target_width, 0.0)
	description_label.custom_minimum_size = Vector2(target_width, 0.0)
	stats_label.custom_minimum_size = Vector2(target_width, 0.0)
	skill_label.custom_minimum_size = Vector2(target_width, 0.0)


func _resize_tooltip_to_content() -> void:
	var content_size := content_box.get_combined_minimum_size()
	var panel_size := content_size + Vector2(20.0, 20.0)
	panel.size = panel_size
	size = panel_size
	custom_minimum_size = panel_size
	margin_container.offset_right = panel_size.x - 10.0
	margin_container.offset_bottom = panel_size.y - 10.0
