extends Node2D

var url = "https://api.pondsec.com"
@onready var http_request = $HTTPRequest
@export var inventory: Inv  # Referenz zum Inventar

func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)
	send_request()

func send_request():
	var headers = ["Content-Type: application/json"]
	http_request.request(url, headers, HTTPClient.METHOD_GET)

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
					inventory.Insert(item)
					print("Item von API erhalten und ins Inventar gelegt:", item_name)
				else:
					print("Fehler: Item konnte nicht geladen werden:", item_name)
	else:
		print("Fehler: Ungültige API-Daten. Inhalt:", json)



func load_item(item_name: String) -> InvItem:
	var path = "res://InventorySystem/items/" + item_name + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as InvItem
	return null
