extends RefCounted

## Runtime menu kept separate from the large legacy main-menu scene.  It uses
## only Godot controls and the game's cave palette, so it stays resolution
## independent and can be opened again after every completed match.

const MODE_DATA := {
	"classic_pvp": {"title": "CLASSIC PvP", "players": "1 vs 1", "description": "Fight another slime. First to 3 points wins.", "accent": Color("82d9ff")},
	"team_battle": {"title": "TEAM BATTLE", "players": "2 vs 2", "description": "Fight together with another slime against an enemy team.", "accent": Color("ff8d7a")},
	"cave_survival": {"title": "CAVE SURVIVAL", "players": "2 Players Co-op", "description": "Survive increasingly dangerous enemy waves together.", "accent": Color("d3b4ff")},
}

static func open(host: Control, preselected_mode: String = "") -> void:
	var existing := host.get_node_or_null("MatchmakingOverlay")
	if existing != null:
		existing.queue_free()
	var overlay := ColorRect.new()
	overlay.name = "MatchmakingOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.025, 0.05, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1420, 650)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("14202b"), Color("607990"), 3, 18))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	margin.add_child(content)
	var heading := Label.new()
	heading.text = "CHOOSE YOUR BATTLE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", Color("f6e7c1"))
	content.add_child(heading)
	var subheading := Label.new()
	subheading.name = "ModeInfo"
	subheading.text = "Choose a mode, then find a compatible party."
	subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subheading.add_theme_font_size_override("font_size", 18)
	subheading.add_theme_color_override("font_color", Color("b7c6d2"))
	content.add_child(subheading)
	var cards := HBoxContainer.new()
	cards.name = "ModeCards"
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	content.add_child(cards)
	var selected := preselected_mode
	for mode: String in MODE_DATA:
		var card := _make_card(mode, MODE_DATA[mode], selected == mode)
		card.pressed.connect(func() -> void:
			selected = mode
			for other in cards.get_children():
				other.set_meta("selected", other.get_meta("mode", "") == mode)
				_refresh_card(other)
			var data: Dictionary = MODE_DATA[mode]
			subheading.text = "%s  •  %s" % [data.title, data.description]
		)
		cards.add_child(card)
	var status := Label.new()
	status.name = "QueueStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 17)
	status.add_theme_color_override("font_color", Color("b7c6d2"))
	content.add_child(status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	content.add_child(buttons)
	var find := Button.new()
	find.name = "FindMatch"
	find.text = "FIND MATCH"
	find.custom_minimum_size = Vector2(260, 58)
	find.add_theme_font_size_override("font_size", 20)
	find.add_theme_stylebox_override("normal", _panel_style(Color("284b55"), Color("94e4e7"), 2, 10))
	buttons.add_child(find)
	find.pressed.connect(func() -> void:
		if selected.is_empty():
			status.text = "Choose a battle first."
			return
		find.disabled = true
		status.text = "Finding Match…\n%s" % String(MODE_DATA[selected].title)
		GameManager.start_global_matchmaking(selected)
	)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(170, 58)
	back.add_theme_font_size_override("font_size", 18)
	back.add_theme_stylebox_override("normal", _panel_style(Color("202b34"), Color("718496"), 2, 10))
	buttons.add_child(back)
	back.pressed.connect(func() -> void: overlay.queue_free())
	var status_callback := func(message: String) -> void:
		if not is_instance_valid(status):
			return
		status.text = message
		if "error" in message.to_lower() or "nicht" in message.to_lower():
			find.disabled = false
	if not GameManager.matchmaking_status_changed.is_connected(status_callback):
		GameManager.matchmaking_status_changed.connect(status_callback)

static func _make_card(mode: String, data: Dictionary, is_selected: bool) -> Button:
	var card := Button.new()
	card.flat = true
	card.custom_minimum_size = Vector2(405, 340)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta("mode", mode)
	card.set_meta("selected", is_selected)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	var preview := ColorRect.new()
	preview.custom_minimum_size = Vector2(0, 150)
	preview.color = Color(data.accent, 0.24)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(preview)
	var glyph := Label.new()
	glyph.text = "✦  FLOATING CAVES  ✦"
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 18)
	glyph.add_theme_color_override("font_color", data.accent)
	preview.add_child(glyph)
	var title := Label.new()
	title.text = data.title
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("f6e7c1"))
	content.add_child(title)
	var players := Label.new()
	players.text = data.players
	players.add_theme_font_size_override("font_size", 17)
	players.add_theme_color_override("font_color", data.accent)
	content.add_child(players)
	var description := Label.new()
	description.text = data.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", Color("c4d0d6"))
	content.add_child(description)
	_refresh_card(card)
	return card

static func _refresh_card(card: Button) -> void:
	var selected := bool(card.get_meta("selected", false))
	var mode := String(card.get_meta("mode", "classic_pvp"))
	var accent: Color = MODE_DATA[mode].accent
	card.add_theme_stylebox_override("normal", _panel_style(Color("233340") if selected else Color("18232d"), accent if selected else Color("526575"), 3 if selected else 2, 14))
	card.add_theme_stylebox_override("hover", _panel_style(Color("293b48"), accent, 3, 14))

static func _panel_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 10
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
