extends Node

const SAVE_PATH = "user://savegame.tres"  # Pfad für das Spiel

# Speichert das Spiel
func save_game(player):
	var save_data = GameData.new()
	
	# Spielerdaten speichern
	save_data.position = player.global_position
	save_data.is_facing_left = player.is_facing_left
	save_data.is_stunned = player.is_stunned
	save_data.is_glowing = player.is_glowing
	save_data.current_health = player.current_health
	save_data.max_health = player.max_health
	save_data.attack_damage = player.attack_damage
	save_data.heal_rate = player.heal_rate
	save_data.fall_distance = player.fall_distance

	# Spielstand speichern (ohne Inventar)
	var error = ResourceSaver.save(save_data, SAVE_PATH)
	if error == OK:
		print("✅ Spiel erfolgreich gespeichert!")
	else:
		print("❌ Fehler beim Speichern des Spiels: ", error)

# Lädt das Spiel
func load_game(player):
	var save_path = "user://savegame.tres"

	if ResourceLoader.exists(save_path):
		var save_data = ResourceLoader.load(save_path) as GameData
		if save_data:
			# Spieler-Daten laden
			player.global_position = save_data.position
			player.is_facing_left = save_data.is_facing_left
			player.is_stunned = save_data.is_stunned
			player.is_glowing = save_data.is_glowing
			player.current_health = save_data.current_health
			player.max_health = save_data.max_health
			player.attack_damage = save_data.attack_damage
			player.heal_rate = save_data.heal_rate
			player.fall_distance = save_data.fall_distance

			# Inventar wird nicht mehr geladen, da es nicht gespeichert wurde

			print("✅ Spiel erfolgreich geladen!")
		else:
			print("❌ Fehler beim Laden der Spieldaten!")
	else:
		print("❌ Spielstand-Datei wurde nicht gefunden!")
