extends Control

const CONFIG_PATH = "user://settings.cfg"  # Speicherort der Datei

var config := ConfigFile.new()

func _ready() -> void:
	load_settings()  # Lade die gespeicherten Einstellungen
	load_keybinds()

func _on_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)
	save_settings("audio", "volume", value)

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
	
	DisplayServer.window_set_size(resolutions[index])
	save_settings("graphics", "resolution", index)

# Speichert eine Einstellung in die Datei
func save_settings(section: String, key: String, value) -> void:
	config.load(CONFIG_PATH)  # Lade bestehende Konfiguration
	config.set_value(section, key, value)
	config.save(CONFIG_PATH)  # Speichere Datei

# Lädt gespeicherte Einstellungen
# Lädt gespeicherte Einstellungen
func load_settings() -> void:
	if config.load(CONFIG_PATH) != OK:
		return  # Datei existiert noch nicht
	
	# Volume
	var volume = config.get_value("audio", "volume", 0.0)
	AudioServer.set_bus_volume_db(0, volume)
	$VBoxContainer/Volume.value = volume  # Slider aktualisieren
	
	# Mute
	var mute = config.get_value("audio", "mute", false)
	AudioServer.set_bus_mute(0, mute)
	$VBoxContainer/Mute.button_pressed = mute  # Falls es ein Button ist
	
	# Resolution
	var resolution_index = config.get_value("graphics", "resolution", 2)
	_on_resolution_item_selected(resolution_index)
	$VBoxContainer/Resolution.select(resolution_index)  # Falls es ein OptionButton ist

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func save_keybind(action: String, event: InputEvent) -> void:
	# Alte Inputs entfernen
	InputMap.action_erase_events(action)
	
	# Neue Taste setzen
	InputMap.action_add_event(action, event)
	
	# Speichern in der Config-Datei
	config.load(CONFIG_PATH)
	config.set_value("keybinds", action, event.as_text())  # Speichern als String
	config.save(CONFIG_PATH)


func load_keybinds() -> void:
	if config.load(CONFIG_PATH) != OK:
		return  # Falls es noch keine Datei gibt
	
	if config.has_section("keybinds"):
		for action in config.get_section_keys("keybinds"):
			var event_string = config.get_value("keybinds", action, "")
			if event_string:
				var event = InputEventKey.new()
				event.from_text(event_string)
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)
