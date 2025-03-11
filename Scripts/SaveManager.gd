extends Node

const SAVE_PATH = "user://player_save.json"

# Speichert den Spielerstatus
static func save_player(player):
	var save_data = {
		"position": player.position,
		"current_health": player.current_health,
		"inventory": player.inventory,
		"is_glowing": player.is_glowing,
		"is_facing_left": player.is_facing_left,
		"attack_damage": player.attack_damage,
		"heal_rate": player.heal_rate
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()
	print("Spieler gespeichert!")

# Lädt den Spielerstatus
static func load_player(player):
	if not FileAccess.file_exists(SAVE_PATH):
		print("Keine gespeicherten Daten gefunden.")
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var save_data = JSON.parse_string(file.get_as_text())
	file.close()

	if save_data:
		player.position = Vector2(save_data["position"]["x"], save_data["position"]["y"])
		player.current_health = save_data["current_health"]
		player.inventory = save_data["inventory"]
		player.is_glowing = save_data["is_glowing"]
		player.is_facing_left = save_data["is_facing_left"]
		player.attack_damage = save_data["attack_damage"]
		player.heal_rate = save_data["heal_rate"]
		print("Spieler geladen!")
