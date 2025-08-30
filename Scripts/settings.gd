extends Control

const CONFIG_PATH = "user://settings.cfg"
var config := ConfigFile.new()

# Input-Actions die konfigurierbar sein sollen
var configurable_actions = ["Interact", "Glow", "inventory", "ult", "left", "right", "up", "skill_tree", "sprint", "Attack", "Pause", "UI", "open_transfer", "down"]
var rebinding_action: String = ""
var rebinding_button: Button = null

# Theme-Variablen für modernen Schwarz-Grün Pixelart Look
var pixel_font = preload("res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf")
var bg_color = Color("0a0a0a")
var panel_color = Color("1a1a1a")
var accent_color = Color("00ff2a")  # Neon Grün
var text_color = Color("e0e0e0")
var hover_color = Color("33ff5c")
var dark_green = Color("007015")

func _ready() -> void:
	load_settings()
	create_settings_ui()

func create_settings_ui() -> void:
	# Dunkler Hintergrund mit Rastereffekt für modernen Pixel-Look
	var background = ColorRect.new()
	background.color = bg_color
	background.size = get_viewport_rect().size
	background.position = Vector2.ZERO
	add_child(background)
	
	# Rastertextur für Pixel-Hintergrund
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.8
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_MANHATTAN
	
	var noise_texture = NoiseTexture2D.new()
	noise_texture.noise = noise
	
	var texture_rect = TextureRect.new()
	texture_rect.texture = noise_texture
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	texture_rect.size = get_viewport_rect().size
	texture_rect.modulate = Color(0.1, 0.1, 0.1, 0.6)
	texture_rect.material = null
	background.add_child(texture_rect)
	
	# Haupt-Container mit modernem Pixel-Rahmen
	var main_container = PanelContainer.new()
	main_container.custom_minimum_size = Vector2(440, 640)
	main_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_container.position = (get_viewport_rect().size - main_container.custom_minimum_size) / 2
	
	# StyleBox für den Panel-Container (moderner Pixel-Rahmen)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = panel_color
	panel_style.border_width_bottom = 3
	panel_style.border_width_top = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_color = accent_color
	panel_style.corner_detail = 0  # Scharfe Ecken für modernen Pixel-Look
	panel_style.shadow_size = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.8)
	panel_style.border_blend = true
	main_container.add_theme_stylebox_override("panel", panel_style)
	
	add_child(main_container)
	
	# Innerer Container mit Padding
	var inner_vbox = VBoxContainer.new()
	inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_vbox.add_theme_constant_override("separation", 20)
	inner_vbox.add_theme_constant_override("margin_left", 20)
	inner_vbox.add_theme_constant_override("margin_right", 20)
	inner_vbox.add_theme_constant_override("margin_top", 20)
	inner_vbox.add_theme_constant_override("margin_bottom", 20)
	main_container.add_child(inner_vbox)
	
	# Titel mit modernem Neon-Effekt
	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", pixel_font)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", accent_color)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", dark_green)
	inner_vbox.add_child(title)
	
	# Trennlinie mit Pixel-Look
	inner_vbox.add_child(create_pixel_separator())
	
	# Audio-Einstellungen
	var audio_label = create_section_label("AUDIO")
	inner_vbox.add_child(audio_label)
	
	# Volume Slider mit modernem Design
	var volume_hbox = HBoxContainer.new()
	volume_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var volume_label = Label.new()
	volume_label.text = "Volume:"
	volume_label.add_theme_font_override("font", pixel_font)
	volume_label.add_theme_font_size_override("font_size", 16)
	volume_label.add_theme_color_override("font_color", text_color)
	volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	volume_slider.connect("value_changed", Callable(self, "_on_volume_value_changed"))
	
	# Slider Styling
	var slider_style = StyleBoxFlat.new()
	slider_style.bg_color = Color(0.15, 0.15, 0.15)
	slider_style.corner_detail = 0
	volume_slider.add_theme_stylebox_override("slider", slider_style)
	
	var grabber_style = StyleBoxFlat.new()
	grabber_style.bg_color = accent_color
	grabber_style.corner_detail = 0
	grabber_style.content_margin_left = 6
	grabber_style.content_margin_right = 6
	volume_slider.add_theme_stylebox_override("grabber", grabber_style)
	
	var grabber_hover_style = grabber_style.duplicate()
	grabber_hover_style.bg_color = hover_color
	volume_slider.add_theme_stylebox_override("grabber_highlight", grabber_hover_style)
	
	volume_hbox.add_child(volume_label)
	volume_hbox.add_child(volume_slider)
	inner_vbox.add_child(volume_hbox)
	
	# Mute Checkbox mit besserem Layout
	var mute_hbox = HBoxContainer.new()
	mute_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var mute_label = Label.new()
	mute_label.text = "Mute:"
	mute_label.add_theme_font_override("font", pixel_font)
	mute_label.add_theme_font_size_override("font_size", 16)
	mute_label.add_theme_color_override("font_color", text_color)
	mute_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mute_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var mute_checkbox = CheckBox.new()
	mute_checkbox.add_theme_font_override("font", pixel_font)
	mute_checkbox.add_theme_font_size_override("font_size", 14)
	mute_checkbox.button_pressed = AudioServer.is_bus_mute(0)
	mute_checkbox.connect("toggled", Callable(self, "_on_mute_toggled"))
	
	# Checkbox Styling
	var checkbox_style = StyleBoxFlat.new()
	checkbox_style.bg_color = Color(0.15, 0.15, 0.15)
	checkbox_style.corner_detail = 0
	checkbox_style.border_width_bottom = 2
	checkbox_style.border_width_top = 2
	checkbox_style.border_width_left = 2
	checkbox_style.border_width_right = 2
	checkbox_style.border_color = Color(0.3, 0.3, 0.3)
	mute_checkbox.add_theme_stylebox_override("unchecked", checkbox_style)
	
	var checked_style = checkbox_style.duplicate()
	checked_style.bg_color = accent_color
	checked_style.border_color = dark_green
	mute_checkbox.add_theme_stylebox_override("checked", checked_style)
	
	mute_hbox.add_child(mute_label)
	mute_hbox.add_child(mute_checkbox)
	inner_vbox.add_child(mute_hbox)
	
	inner_vbox.add_child(create_pixel_separator())
	
	# Graphics-Einstellungen
	var graphics_label = create_section_label("GRAPHICS")
	inner_vbox.add_child(graphics_label)
	
	# Resolution Dropdown
	var resolution_hbox = HBoxContainer.new()
	resolution_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var resolution_label = Label.new()
	resolution_label.text = "Resolution:"
	resolution_label.add_theme_font_override("font", pixel_font)
	resolution_label.add_theme_font_size_override("font_size", 16)
	resolution_label.add_theme_color_override("font_color", text_color)
	resolution_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolution_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var resolution_dropdown = OptionButton.new()
	resolution_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolution_dropdown.add_theme_font_override("font", pixel_font)
	resolution_dropdown.add_theme_font_size_override("font_size", 14)
	resolution_dropdown.custom_minimum_size.y = 28
	
	# Dropdown Styling
	var dropdown_style = StyleBoxFlat.new()
	dropdown_style.bg_color = Color(0.15, 0.15, 0.15)
	dropdown_style.corner_detail = 0
	dropdown_style.border_width_bottom = 2
	dropdown_style.border_width_top = 2
	dropdown_style.border_width_left = 2
	dropdown_style.border_width_right = 2
	dropdown_style.border_color = Color(0.3, 0.3, 0.3)
	resolution_dropdown.add_theme_stylebox_override("normal", dropdown_style)
	
	var hover_dropdown_style = dropdown_style.duplicate()
	hover_dropdown_style.border_color = accent_color
	resolution_dropdown.add_theme_stylebox_override("hover", hover_dropdown_style)
	resolution_dropdown.add_theme_stylebox_override("focus", hover_dropdown_style)
	
	var resolutions = ["3840x2160 (4K)", "2560x1440 (QHD)", "1920x1080 (Full HD)", "1600x900", "1366x768", "1280x720 (HD)"]
	for res in resolutions:
		resolution_dropdown.add_item(res)
	resolution_dropdown.select(2)  # Default: Full HD
	resolution_dropdown.connect("item_selected", Callable(self, "_on_resolution_item_selected"))
	
	resolution_hbox.add_child(resolution_label)
	resolution_hbox.add_child(resolution_dropdown)
	inner_vbox.add_child(resolution_hbox)
	
	inner_vbox.add_child(create_pixel_separator())
	
	# Input-Einstellungen
	var input_label = create_section_label("CONTROLS")
	inner_vbox.add_child(input_label)
	
	# Beschreibungstext für Input-Rebinding
	var input_hint = Label.new()
	input_hint.text = "Click a button and press any key to rebind"
	input_hint.add_theme_font_override("font", pixel_font)
	input_hint.add_theme_font_size_override("font_size", 12)
	input_hint.add_theme_color_override("font_color", text_color.darkened(0.4))
	input_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(input_hint)
	
	# ScrollContainer für viele Input-Einstellungen
	var scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size.y = 220
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(scroll_container)
	
	# Container für Input-Rebinding
	var input_container = VBoxContainer.new()
	input_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_container.add_theme_constant_override("separation", 10)
	scroll_container.add_child(input_container)
	
	# Erstelle UI für jede konfigurierbare Action
	for action in configurable_actions:
		var action_hbox = HBoxContainer.new()
		action_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var action_label = Label.new()
		action_label.text = action.capitalize() + ":"
		action_label.add_theme_font_override("font", pixel_font)
		action_label.add_theme_font_size_override("font_size", 16)
		action_label.add_theme_color_override("font_color", text_color)
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var action_button = Button.new()
		action_button.text = get_action_key_name(action)
		action_button.custom_minimum_size.x = 130
		action_button.custom_minimum_size.y = 30
		action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		action_button.connect("pressed", Callable(self, "_on_input_button_pressed").bind(action, action_button))
		action_button.name = action + "_button"
		
		# Button Styling
		style_pixel_button(action_button)
		
		action_hbox.add_child(action_label)
		action_hbox.add_child(action_button)
		input_container.add_child(action_hbox)
	
	# Reset-Button für Inputs
	var reset_button = Button.new()
	reset_button.text = "RESET TO DEFAULTS"
	reset_button.connect("pressed", Callable(self, "_on_reset_inputs_pressed"))
	style_pixel_button(reset_button)
	reset_button.add_theme_constant_override("margin_top", 10)
	inner_vbox.add_child(reset_button)
	
	inner_vbox.add_child(create_pixel_separator())
	
	# Back Button mit mehr Abstand
	var back_button = Button.new()
	back_button.text = "BACK TO MAIN MENU"
	back_button.connect("pressed", Callable(self, "_on_back_pressed"))
	style_pixel_button(back_button)
	back_button.add_theme_constant_override("margin_top", 10)
	inner_vbox.add_child(back_button)
	
	# Lade gespeicherte Einstellungen in die UI
	apply_loaded_settings(volume_slider, mute_checkbox, resolution_dropdown)

func create_section_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", pixel_font)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", accent_color)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", dark_green)
	return label

func create_pixel_separator() -> HSeparator:
	var separator = HSeparator.new()
	var separator_style = StyleBoxLine.new()
	separator_style.color = dark_green
	separator_style.thickness = 2
	separator_style.grow_begin = 5
	separator_style.grow_end = 5
	separator.add_theme_stylebox_override("separator", separator_style)
	return separator

func style_pixel_button(button: Button) -> void:
	button.add_theme_font_override("font", pixel_font)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.3))
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.15)
	normal_style.border_width_bottom = 2
	normal_style.border_width_top = 2
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_color = Color(0.3, 0.3, 0.3)
	normal_style.corner_detail = 0
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.2, 0.2)
	hover_style.border_color = accent_color
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = accent_color
	pressed_style.border_color = dark_green
	
	var focus_style = normal_style.duplicate()
	focus_style.border_color = accent_color
	
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", focus_style)
	
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", Color.BLACK)
	button.add_theme_color_override("font_focus_color", text_color)

func apply_loaded_settings(volume_slider: HSlider, mute_checkbox: CheckBox, resolution_dropdown: OptionButton) -> void:
	if config.load(CONFIG_PATH) != OK:
		return
	
	# Volume
	var volume = config.get_value("audio", "volume", 0.0)
	volume_slider.value = db_to_linear(volume)
	
	# Mute
	var mute = config.get_value("audio", "mute", false)
	mute_checkbox.button_pressed = mute
	
	# Resolution
	var resolution_index = config.get_value("graphics", "resolution", 2)
	resolution_dropdown.select(resolution_index)
	
	# Input settings werden automatisch durch load_settings() geladen

func get_action_key_name(action: String) -> String:
	# Zuerst prüfen, ob benutzerdefinierte Einstellungen vorhanden sind
	if config.has_section_key("input", action):
		var event_dict = config.get_value("input", action)
		var event = dict_to_input_event(event_dict)
		if event:
			if event is InputEventKey:
				return OS.get_keycode_string(event.keycode)
			elif event is InputEventMouseButton:
				return "Mouse " + str(event.button_index)
			elif event is InputEventJoypadButton:
				return "Gamepad " + str(event.button_index)
	
	# Fallback zu den Standard-Keybindings aus der InputMap
	var events = InputMap.action_get_events(action)
	if events.size() > 0:
		for event in events:
			if event is InputEventKey:
				return OS.get_keycode_string(event.keycode)
			elif event is InputEventMouseButton:
				return "Mouse " + str(event.button_index)
			elif event is InputEventJoypadButton:
				return "Gamepad " + str(event.button_index)
	
	return "Not Set"

func _on_input_button_pressed(action: String, button: Button) -> void:
	rebinding_action = action
	rebinding_button = button
	button.text = "Press any key..."
	button.add_theme_color_override("font_color", accent_color)
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if rebinding_action != "":
		if event is InputEventKey and event.pressed:
			rebind_action(rebinding_action, event)
			rebinding_button.text = OS.get_keycode_string(event.keycode)
			end_rebinding()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			rebind_action(rebinding_action, event)
			rebinding_button.text = "Mouse " + str(event.button_index)
			end_rebinding()
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed:
			rebind_action(rebinding_action, event)
			rebinding_button.text = "Gamepad " + str(event.button_index)
			end_rebinding()
			get_viewport().set_input_as_handled()

func end_rebinding() -> void:
	if rebinding_button:
		rebinding_button.add_theme_color_override("font_color", text_color)
	rebinding_action = ""
	rebinding_button = null
	set_process_input(false)

func rebind_action(action: String, new_event: InputEvent) -> void:
	# Entferne alle bisherigen Events für diese Action
	InputMap.action_erase_events(action)
	# Füge das neue Event hinzu
	InputMap.action_add_event(action, new_event)
	
	# Speichere die Zuordnung in der Config
	config.set_value("input", action, input_event_to_dict(new_event))
	config.save(CONFIG_PATH)

func input_event_to_dict(event: InputEvent) -> Dictionary:
	var dict = {}
	if event is InputEventKey:
		dict["type"] = "key"
		dict["keycode"] = event.keycode
		dict["physical_keycode"] = event.physical_keycode
	elif event is InputEventMouseButton:
		dict["type"] = "mouse"
		dict["button_index"] = event.button_index
	elif event is InputEventJoypadButton:
		dict["type"] = "gamepad"
		dict["button_index"] = event.button_index
	return dict

func dict_to_input_event(dict: Dictionary) -> InputEvent:
	match dict.get("type"):
		"key":
			var event = InputEventKey.new()
			event.keycode = dict.get("keycode", 0)
			event.physical_keycode = dict.get("physical_keycode", 0)
			return event
		"mouse":
			var event = InputEventMouseButton.new()
			event.button_index = dict.get("button_index", 0)
			return event
		"gamepad":
			var event = InputEventJoypadButton.new()
			event.button_index = dict.get("button_index", 0)
			return event
	return null

func _on_reset_inputs_pressed() -> void:
	reset_inputs_to_default()

func reset_inputs_to_default() -> void:
	# Lade die Standard-InputMap zurück
	InputMap.load_from_project_settings()
	
	# Lösche gespeicherte Input-Einstellungen
	for action in configurable_actions:
		if config.has_section_key("input", action):
			config.erase_section_key("input", action)
	config.save(CONFIG_PATH)
	
	# Aktualisiere die UI
	for action in configurable_actions:
		var button = get_node_or_null(action + "_button")
		if button:
			button.text = get_action_key_name(action)

func _on_volume_value_changed(value: float) -> void:
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(0, db_value)
	save_settings("audio", "volume", db_value)

func _on_mute_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(0, toggled_on)
	save_settings("audio", "mute", toggled_on)

func _on_resolution_item_selected(index: int) -> void:
	var resolutions = [
		Vector2i(3840, 2160),
		Vector2i(2560, 1440),
		Vector2i(1920, 1080),
		Vector2i(1600, 900),
		Vector2i(1366, 768),
		Vector2i(1280, 720)
	]
	
	if index >= 0 and index < resolutions.size():
		DisplayServer.window_set_size(resolutions[index])
		save_settings("graphics", "resolution", index)

func save_settings(section: String, key: String, value) -> void:
	config.load(CONFIG_PATH)
	config.set_value(section, key, value)
	config.save(CONFIG_PATH)

func load_settings() -> void:
	if config.load(CONFIG_PATH) != OK:
		return
	
	# Audio-Einstellungen
	var volume = config.get_value("audio", "volume", 0.0)
	AudioServer.set_bus_volume_db(0, volume)
	
	var mute = config.get_value("audio", "mute", false)
	AudioServer.set_bus_mute(0, mute)
	
	# Graphics-Einstellungen
	var resolution_index = config.get_value("graphics", "resolution", 2)
	_on_resolution_item_selected(resolution_index)
	
	# Input-Einstellungen laden
	load_input_settings()

func load_input_settings() -> void:
	for action in configurable_actions:
		if config.has_section_key("input", action):
			var event_dict = config.get_value("input", action)
			var event = dict_to_input_event(event_dict)
			if event:
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
