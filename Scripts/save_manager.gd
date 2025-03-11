extends Node

const SAVE_FILE := "user://savegame.json"

var save_data := {
	"player_position": Vector2.ZERO,
	"player_health": 100,
	"player_is_stunned": false,
	"enemy_positions": [],
	"enemy_health": [],
	"is_enemy_stunned": []
}

func _ready():
	load_game()  # Automatisches Laden beim Start

func save_game():
	var player = get_node("Game/PlayerModel")  # Pfad anpassen, falls anders!
	if player:
		save_data["player_position"] = player.global_position
		save_data["player_health"] = player.current_health
		save_data["player_is_stunned"] = player.is_stunned

	var enemies = get_tree().get_nodes_in_group("enemies")
	save_data["enemy_positions"] = []
	save_data["enemy_health"] = []
	save_data["is_enemy_stunned"] = []

	for enemy in enemies:
		if not enemy.is_dead:  # Tote Gegner nicht speichern
			save_data["enemy_positions"].append(enemy.global_position)
			save_data["enemy_health"].append(enemy.health)
			save_data["is_enemy_stunned"].append(enemy.is_stunned)

	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("Spiel gespeichert")

func load_game():
	if not FileAccess.file_exists(SAVE_FILE):
		print("Keine gespeicherte Datei gefunden")
		return
	
	var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(content)
		
		if parse_result == OK:
			save_data = json.data
			apply_loaded_data()
			print("Spiel geladen:", save_data)
		else:
			print("Fehler beim Laden:", parse_result)

		file.close()

func apply_loaded_data():
	var player = get_node("Game/PlayerModel")  # Pfad anpassen
	if player:
		player.global_position = save_data.get("player_position", Vector2.ZERO)
		player.current_health = save_data.get("player_health", 100)
		player.is_stunned = save_data.get("player_is_stunned", false)

	var enemies = get_tree().get_nodes_in_group("enemies")
	var enemy_positions = save_data.get("enemy_positions", [])
	var enemy_health = save_data.get("enemy_health", [])
	var is_enemy_stunned = save_data.get("is_enemy_stunned", [])

	for i in range(min(enemies.size(), enemy_positions.size())):
		enemies[i].global_position = enemy_positions[i]
		enemies[i].health = enemy_health[i]
		enemies[i].is_stunned = is_enemy_stunned[i]

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
