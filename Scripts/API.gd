extends Node2D

var url = "https://api.pondsec.com"
@onready var http_request = $HTTPRequest
@export var inv: Inv  # Referenz zum Inventar des Spielers
@onready var player: CharacterBody2D  # Referenz auf den Spieler (ändere dies je nach Struktur)

# Definiere PLAYER_ID_PATH hier
const PLAYER_ID_PATH = "user://player_id.save"

func _ready() -> void:
	# Hole den ersten Spieler aus der Gruppe "players"
	var players = get_tree().get_nodes_in_group("players")
	
	if players.size() > 0:
		player = players[0]  # Nehme den ersten Spieler in der Liste
		print("Spieler gefunden:", player.name)
	else:
		print("Fehler: Kein Spieler in der Gruppe 'players' gefunden.")
		return  # Verhindere, dass der Rest des Codes weiter ausgeführt wird, wenn kein Spieler gefunden wurde
	
	http_request.request_completed.connect(_on_request_completed)
	send_request()

func send_request():
	var headers = ["Content-Type: application/json"]
	
	# UUID aus der Datei laden
	var player_id = ""
	if FileAccess.file_exists(PLAYER_ID_PATH):
		var file = FileAccess.open(PLAYER_ID_PATH, FileAccess.READ)
		if file:
			player_id = file.get_line()
			file.close()
		else:
			print("❌ Fehler beim Laden der Spieler-ID.")
	
	var json_body = {"player_id": player_id}
	
	# JSON-Body in einen String umwandeln
	var json_string = JSON.stringify(json_body)
	
	# Sende die Anfrage an den Server mit der UUID als Parameter
	http_request.request(url, headers, HTTPClient.METHOD_GET, json_string)

func _on_request_completed(results, response_code, headers, body):
	if response_code != 200:
		print("Fehler: API-Antwort ungültig. Code: ", response_code)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and "items" in json:
		var items_list = json["items"]  # Die Liste der Items
		for item_data in items_list:
			if "item_name" in item_data:
				var item_name = item_data["item_name"]
				
				# Überprüfen, ob der Item-Name 'null' ist oder leer
				if item_name == null or item_name == "":
					print("Kein Item erhalten (null oder leer).")
					continue  # Weiter mit dem nächsten Item

				var item = load_item(item_name)
				if item:
					# Die Items sollen vor dem Spieler abgelegt werden
					drop_item_before_player(item)
					print("Item von API erhalten und auf dem Boden abgelegt:", item_name)
				else:
					print("Fehler: Item konnte nicht geladen werden:", item_name)
	else:
		print("Fehler: Ungültige API-Daten. Inhalt:", json)

# Methode, um das Item vor dem Spieler abzulegen
func drop_item_before_player(item: InvItem) -> void:
	# Instanziiere das Item
	var item_scene = load("res://Scenes/Items/" + item.name + ".tscn")
	var dropped_item = item_scene.instantiate()

	# Vergewissere dich, dass du die richtige Position des Spielers erhältst
	if player:
		# Setze die Position des Items direkt vor dem Spieler
		dropped_item.global_position = player.global_position + Vector2(0, -50)  # Z.B. 50 Einheiten vor dem Spieler

		# Füge das Item zur Szene hinzu
		get_tree().current_scene.add_child(dropped_item)

		# Optional: Du könntest die Position und den Namen des Items auch speichern
		print("Item abgelegt: ", item.name, " bei Position: ", dropped_item.global_position)
	else:
		print("Fehler: Spieler-Referenz fehlt!")

# Methode zum Laden eines Items anhand des Namens
func load_item(item_name: String) -> InvItem:
	var path = "res://InventorySystem/items/" + item_name + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as InvItem
	return null
