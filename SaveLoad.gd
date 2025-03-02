extends Node

const SAVE_PATH = "user://savegame.tres"  # Speicherpfad für das Spiel

func save_game(player):
	var save_data = GameData.new()

	# 🎮 Spielerdaten speichern
	save_data.position = player.global_position
	save_data.is_facing_left = player.is_facing_left
	save_data.is_stunned = player.is_stunned
	save_data.is_glowing = player.is_glowing
	save_data.is_glowing_visible = player.glow_effect.visible
	save_data.current_health = player.current_health
	save_data.max_health = player.max_health
	save_data.attack_damage = player.attack_damage
	save_data.heal_rate = player.heal_rate
	save_data.fall_distance = player.fall_distance

	# 🛠 Spielstand speichern
	var error = ResourceSaver.save(save_data, SAVE_PATH)
	if error == OK:
		print("✅ Spiel erfolgreich gespeichert!")
	else:
		print("❌ Fehler beim Speichern des Spiels: ", error)

func load_game(player):
	var save_path = SAVE_PATH
	var save_data = ResourceLoader.load(save_path) as GameData
	if not save_data:
		print("❌ Fehler beim Laden des Spiels!")
		return
	
	# 🎮 Spieler-Daten wiederherstellen
	player.global_position = save_data.position
	player.is_facing_left = save_data.is_facing_left
	player.is_stunned = save_data.is_stunned
	player.is_glowing = save_data.is_glowing
	player.glow_effect.visible = save_data.is_glowing_visible
	player.current_health = save_data.current_health
	player.max_health = save_data.max_health
	player.attack_damage = save_data.attack_damage
	player.heal_rate = save_data.heal_rate
	player.fall_distance = save_data.fall_distance

	print("✅ Spiel erfolgreich geladen!")
