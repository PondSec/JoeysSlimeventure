extends Node

const SAVE_PATH = "user://savegame.tres"
const PLAYER_ID_PATH = "user://player_id.save"  # Speichert die UUID des Spielers

func generate_unique_id() -> String:
	# UUID erzeugen (hier wird die eingebaute UUID-Klasse von Godot verwendet)
	var uuid = OS.get_unique_id()  # Diese Methode gibt einen eindeutigen String zurück
	return uuid

func save_game(player = null, bats: Array = []):  
	var save_data = GameData.new()

	# Wenn keine UUID existiert, generiere eine neue
	if not FileAccess.file_exists(PLAYER_ID_PATH):
		var player_id = generate_unique_id()
		var file = FileAccess.open(PLAYER_ID_PATH, FileAccess.WRITE)
		if file:
			file.store_string(player_id)  # Speichert die UUID
			file.close()
		else:
			print("❌ Fehler beim Speichern der Spieler-ID.")

	# Lade die UUID (falls sie existiert)
	var player_id = ""
	if FileAccess.file_exists(PLAYER_ID_PATH):
		var file = FileAccess.open(PLAYER_ID_PATH, FileAccess.READ)
		if file:
			player_id = file.get_line()
			file.close()
		else:
			print("❌ Fehler beim Laden der Spieler-ID.")
	
	save_data.player_id = player_id  # Füge die UUID dem Spielstand hinzu

	# 🎮 Spieler speichern (falls vorhanden)
	if player:
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

func load_game(player = null, bat_scene: PackedScene = null):  
	var save_data = ResourceLoader.load(SAVE_PATH) as GameData
	if not save_data:
		print("❌ Fehler beim Laden des Spiels!")
		return

	# 🎮 Spieler laden (falls vorhanden)
	if player:
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
	print("UUID: " + save_data.player_id)
	print("✅ Spiel erfolgreich geladen!")
