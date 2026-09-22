extends Control

## One-time thank-you presentation. The saved value records only that this
## account saw the presentation; DLC entitlement remains Steam-authoritative.

const CROWN_TEXTURE := preload("res://Assets/Cosmetics/early_supporter_crown.png")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.045, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330.0
	panel.offset_top = -260.0
	panel.offset_right = 330.0
	panel.offset_bottom = 260.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("101c2b")
	panel_style.border_color = Color("d8b75c")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 42.0
	panel_style.content_margin_right = 42.0
	panel_style.content_margin_top = 34.0
	panel_style.content_margin_bottom = 34.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var title := Label.new()
	title.text = "THANK YOU, EARLY SUPPORTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("fff1bd"))
	content.add_child(title)

	var message := Label.new()
	message.text = "Your early support helps Joey's Slimeventure grow.\nPlease accept this little gift."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 18)
	message.add_theme_color_override("font_color", Color("d8e6f3"))
	content.add_child(message)

	var crown := TextureRect.new()
	crown.texture = CROWN_TEXTURE
	crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown.custom_minimum_size = Vector2(184.0, 184.0)
	crown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(crown)

	var reward := Label.new()
	reward.text = "EARLY SUPPORTER CROWN"
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_font_size_override("font_size", 23)
	reward.add_theme_color_override("font_color", Color("ffd86c"))
	content.add_child(reward)

	var accept := Button.new()
	accept.text = "ACCEPT GIFT"
	accept.custom_minimum_size = Vector2(0.0, 54.0)
	accept.add_theme_font_size_override("font_size", 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("3c7d55")
	normal.border_color = Color("bdfc98")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(5)
	var hover := normal.duplicate()
	hover.bg_color = Color("509d66")
	accept.add_theme_stylebox_override("normal", normal)
	accept.add_theme_stylebox_override("hover", hover)
	accept.pressed.connect(_accept)
	content.add_child(accept)
	accept.grab_focus()


func _accept() -> void:
	SteamEntitlements.accept_early_supporter_crown_presentation()
	queue_free()
