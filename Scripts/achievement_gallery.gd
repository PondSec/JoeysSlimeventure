extends Control

## Local, read-only achievement gallery.  Steam remains the account authority;
## this screen only mirrors its known state and works gracefully while offline.

const TROPHY := preload("res://Assets/GUI/achievement_trophy.png")
const ACHIEVEMENTS := [
	{"api": "ACH_INTO_THE_DEPTHS", "name": "Into the Depths", "unlocked": TROPHY, "locked": TROPHY},
	{"api": "ACH_FIRST_KILL", "name": "First Kill", "unlocked": TROPHY, "locked": TROPHY},
	{"api": "ACH_WISP_HUNTER", "name": "Wisp Hunter", "unlocked": preload("res://Assets/GUI/Achievements/ach_wisp_hunter_unlocked.png"), "locked": preload("res://Assets/GUI/Achievements/ach_wisp_hunter_locked.png")},
	{"api": "ACH_BELL_RINGER", "name": "Bell Ringer", "unlocked": preload("res://Assets/GUI/Achievements/ach_bell_ringer_unlocked.png"), "locked": preload("res://Assets/GUI/Achievements/ach_bell_ringer_locked.png")},
	{"api": "ACH_MOONFLOWER_BLOOM", "name": "Moonflower Bloom", "unlocked": preload("res://Assets/GUI/Achievements/ach_moonflower_bloom_unlocked.png"), "locked": preload("res://Assets/GUI/Achievements/ach_moonflower_bloom_locked.png")},
	{"api": "ACH_CHAPTER_ONE_CLEAR", "name": "Chapter One Clear", "unlocked": preload("res://Assets/GUI/Achievements/ach_chapter_one_clear_unlocked.png"), "locked": preload("res://Assets/GUI/Achievements/ach_chapter_one_clear_locked.png")},
	{"api": "ACH_ENTER_PVP", "name": "Into the Arena", "unlocked": preload("res://Assets/GUI/Achievements/ach_enter_pvp_unlocked.png"), "locked": preload("res://Assets/GUI/Achievements/ach_enter_pvp_locked.png")},
	{"api": "ACH_ENTER_EMBER_DIMENSION", "name": "Into the Ember Dimension", "unlocked": preload("res://Assets/GUI/Achievements/ach_enter_ember_dimension_unlocked.png"), "locked": preload("res://Assets/GUI/Achievements/ach_enter_ember_dimension_locked.png")},
]

var grid: GridContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	_build()
	var steam_manager := get_node_or_null("/root/SteamManager")
	if steam_manager != null:
		if steam_manager.has_signal("stats_ready"):
			steam_manager.stats_ready.connect(_refresh)
		if steam_manager.has_signal("achievement_unlocked"):
			steam_manager.achievement_unlocked.connect(_refresh)


func _build() -> void:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.015, 0.025, 0.04, 0.91)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-474, -386)
	panel.size = Vector2(948, 772)
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 56)
	root.add_child(header)
	var back := Button.new()
	back.text = "← BACK"
	back.custom_minimum_size = Vector2(130, 42)
	back.add_theme_font_size_override("font_size", 15)
	back.add_theme_stylebox_override("normal", _button_style(Color("213a4d"), Color("82d7e8")))
	back.add_theme_stylebox_override("hover", _button_style(Color("315b70"), Color("d1ffff")))
	back.pressed.connect(queue_free)
	header.add_child(back)
	var title := Label.new()
	title.text = "ACHIEVEMENTS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("f7e5b0"))
	header.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(130, 1)
	header.add_child(spacer)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	_refresh()


func _refresh(_ignored: Variant = null) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	var steam_manager := get_node_or_null("/root/SteamManager")
	for achievement in ACHIEVEMENTS:
		var api_name := String(achievement.api)
		var unlocked := steam_manager != null and steam_manager.has_method("is_achievement_unlocked") and bool(steam_manager.call("is_achievement_unlocked", api_name))
		grid.add_child(_card(achievement, unlocked))


func _card(achievement: Dictionary, unlocked: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(208, 188)
	card.add_theme_stylebox_override("panel", _card_style(unlocked))
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 7)
	card.add_child(content)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(142, 142)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = achievement.unlocked if unlocked else achievement.locked
	icon.self_modulate = Color.WHITE if unlocked else Color(0.72, 0.72, 0.72, 1.0)
	if not unlocked and icon.texture == TROPHY:
		icon.material = _grayscale_material()
	content.add_child(icon)
	var label := Label.new()
	label.text = String(achievement.name)
	label.custom_minimum_size = Vector2(0, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("f4f6f8") if unlocked else Color("a8afb7"))
	content.add_child(label)
	return card


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c28")
	style.border_color = Color("6f9db4")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 24
	return style


func _card_style(unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182a37") if unlocked else Color("171d23")
	style.border_color = Color("5b9873") if unlocked else Color("3b4750")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


func _grayscale_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { vec4 c = texture(TEXTURE, UV) * COLOR; float l = dot(c.rgb, vec3(0.299, 0.587, 0.114)); COLOR = vec4(vec3(l), c.a); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
