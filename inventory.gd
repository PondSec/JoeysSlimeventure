extends Resource

class_name Inv

signal update

@export var slots: Array[InvSlot]

# Speichert das Inventar in eine Datei
func save_inventory(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.WRITE)  # Benutze FileAccess statt File
	if file:
		# Serialisiert die Slots und Items in die Datei
		var data = []
		for slot in slots:
			var slot_data = {}
			if slot.item:
				slot_data["item_name"] = slot.item.name
				slot_data["amount"] = slot.amount
			else:
				slot_data["item_name"] = ""
				slot_data["amount"] = 0
			data.append(slot_data)
		file.store_var(data)
		file.close()
		print("Inventar gespeichert in: %s" % file_path)
	else:
		print("Fehler beim Öffnen der Datei zum Schreiben.")

# Lädt das Inventar aus einer Datei
func load_inventory(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		print("Datei existiert nicht, Inventar wird nicht geladen.")
		return  # Verhindert das Laden von nicht vorhandenen Daten

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()

		if data == null or not data is Array:  # Überprüfung, ob `data` gültig ist
			print("Fehler: Inventardatei enthält ungültige Daten.")
			return

		# Löscht bestehende Slots und lädt neue
		for slot in slots:
			slot.item = null
			slot.amount = 0

		for i in range(min(len(data), slots.size())):
			var slot_data = data[i]
			if slot_data["item_name"] != "":
				var item = load_item(slot_data["item_name"])
				slots[i].item = item
				slots[i].amount = slot_data["amount"]

		update.emit()
		print("Inventar geladen von: %s" % file_path)
	else:
		print("Fehler beim Öffnen der Datei zum Lesen.")

# Methode zum Laden eines Items anhand des Namens
func load_item(item_name: String) -> InvItem:
	# Lade das Item dynamisch zur Laufzeit (Verwende 'load()' statt 'preload()')
	var item = load("res://InventorySystem/items/" + item_name + ".tres")  # Angenommener Pfad zu den Items
	return item

# Einfügen eines Items in das Inventar
func Insert(item: InvItem):
	# Suche nach einem Slot mit dem gleichen Item und einer Menge von weniger als 64
	var itemslots = slots.filter(func(slot): return slot.item == item and slot.amount < 64)
	if !itemslots.is_empty():
		# Füge das Item zu einem Slot hinzu, der weniger als 64 Items enthält
		var slot = itemslots[0]
		var amount_to_add = min(64 - slot.amount, 1)  # Hinzufügen von 1 Item, solange der Slot noch Platz hat
		slot.amount += amount_to_add
		print("Item hinzugefügt zu Slot mit weniger als 64 Items.")
	else:
		# Wenn kein passender Slot gefunden wurde, suche nach einem leeren Slot
		var emptyslots = slots.filter(func(slot): return slot.item == null)
		if !emptyslots.is_empty():
			var empty_slot = emptyslots[0]
			empty_slot.item = item
			empty_slot.amount = 1  # Setze die Menge des neuen Items auf 1
			print("Item wurde in einen leeren Slot eingefügt.")
		else:
			print("Es gibt keinen Platz für dieses Item.")

	update.emit()

# Tauschen von zwei Slots
func swap_slots(index1: int, index2: int):
	var temp = slots[index1]
	slots[index1] = slots[index2]
	slots[index2] = temp
	update.emit()
