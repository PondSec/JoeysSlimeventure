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
	var file = FileAccess.open(file_path, FileAccess.READ)  # Benutze FileAccess statt File
	if file:
		var data = file.get_var()
		file.close()
		
		# Löscht bestehende Slots und lädt neue
		for slot in slots:
			slot.item = null
			slot.amount = 0
		for i in range(min(len(data), slots.size())):
			var slot_data = data[i]
			if slot_data["item_name"] != "":
				var item = load_item(slot_data["item_name"])  # Methode zum Laden von Items anhand des Namens
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
	var itemslots = slots.filter(func(slot): return slot.item == item)
	if !itemslots.is_empty():
		itemslots[0].amount += 1
	else:
		var emptyslots = slots.filter(func(slot): return slot.item == null)
		if !emptyslots.is_empty():
			emptyslots[0].item = item
			emptyslots[0].amount = 1
	update.emit()

# Tauschen von zwei Slots
func swap_slots(index1: int, index2: int):
	var temp = slots[index1]
	slots[index1] = slots[index2]
	slots[index2] = temp
	update.emit()
