extends Node

@export var inventory : Inv  # Verweist auf das Inventar

signal reward_collected(item_name : String)

const API_URL = "http://192.168.10.6:5598"  # Ersetze mit deiner echten API-URL

var reward_collected_today : bool = false  # Muss persistent gespeichert werden

func check_and_collect_daily_reward() -> void:
	if reward_collected_today:
		print("Du hast die tägliche Belohnung bereits abgeholt.")
		return

	# HTTPRequest-Node erstellen
	var request = HTTPRequest.new()
	self.add_child(request)  # Zum Baum hinzufügen
	
	# Verbinde das Signal request_completed
	request.connect("request_completed", Callable(self, "_on_reward_received"))

	# Anfrage ohne Header oder zusätzliche Parameter senden
	var err = request.request(API_URL)
	if err != OK:
		print("Fehler beim Abrufen der Belohnung: Fehler bei der Anfrage. Fehlercode: %d" % err)
		return

	print("API-Anfrage gesendet. Warten auf Antwort...")
	
# Callback, wenn die Antwort zurückkommt
func _on_reward_received(result: int, response_code: int, headers: Array, body: String) -> void:
	print("API-Antwort erhalten. Resultat: %d, HTTP Statuscode: %d" % [result, response_code])

	if result != OK:
		print("Fehler bei der Anfrage. Fehlercode: %d" % result)
		return
	
	if response_code == 200:
		print("Erfolgreiche Antwort: %s" % body)
		var json = JSON.new()
		var parse_result = json.parse(body)
		if parse_result != OK:
			print("Fehler beim Parsen der API-Antwort: %s" % json.get_error_message())
			return
		
		var items = json.get_data()["items"]
		if items.size() > 0:
			var item_data = items[0]  # Holen des ersten Items
			var item_name = item_data["name"]
			var item = load_item(item_name)
			if item != null:
				inventory.Insert(item)  # Item ins Inventar einfügen
				reward_collected_today = true  # Markiere, dass die Belohnung abgeholt wurde
				print("Tägliche Belohnung erhalten: " + item_name)
				reward_collected.emit(item_name)  # Signal auslösen, dass die Belohnung abgeholt wurde
			else:
				print("Fehler beim Laden des Items: " + item_name)
		else:
			print("Keine Items in der Antwort.")
	else:
		print("Fehler bei der API-Anfrage. HTTP Statuscode: %d" % response_code)

# Lädt das Item basierend auf dem Namen
func load_item(item_name: String) -> InvItem:
	var item = load("res://InventorySystem/items/" + item_name + ".tres")  # Angenommener Pfad
	return item
