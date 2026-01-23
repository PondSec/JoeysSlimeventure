extends Resource

class_name Inv

signal update

@export var slots: Array[InvSlot]
@export var equipment_slots: Array[InvSlot] = []

# Speichert das Inventar in eine Datei
func save_inventory(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.WRITE)  # Benutze FileAccess statt File
	if file:
		# Serialisiert die Slots und Items in die Datei
		var data = {
			"version": 1,
			"inventory": _serialize_slots(slots),
			"equipment": _serialize_slots(equipment_slots)
		}
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

		if data == null:
			print("Fehler: Inventardatei enthält ungültige Daten.")
			return

		# Löscht bestehende Slots und lädt neue
		_reset_slots(slots)
		_reset_slots(equipment_slots)

		if data is Dictionary:
			var inventory_data = data.get("inventory", [])
			var equipment_data = data.get("equipment", [])
			_load_slots_from_data(slots, inventory_data)
			_load_slots_from_data(equipment_slots, equipment_data)
		elif data is Array:
			# Legacy-Format: Nur Inventar-Slots
			_load_slots_from_data(slots, data)
		else:
			print("Fehler: Inventardatei enthält ungültige Daten.")
			return

		update.emit()
		print("Inventar geladen von: %s" % file_path)
	else:
		print("Fehler beim Öffnen der Datei zum Lesen.")

# Methode zum Laden eines Items anhand des Namens
func load_item(item_name: String) -> InvItem:
	# Lade das Item dynamisch zur Laufzeit (Verwende 'load()' statt 'preload()')
	var item = load("res://InventorySystem/items/" + item_name + ".tres")  # Angenommener Pfad zu den Items
	return item

func Insert(item: InvItem):
	var itemslots = slots.filter(func(slot): return slot.item == item and slot.amount < 64)
	print("Itemslots: ", itemslots.size())  # Debugging-Log für verfügbare Itemslots
	if !itemslots.is_empty():
		var slot = itemslots[0]
		var amount_to_add = min(64 - slot.amount, 1)
		slot.amount += amount_to_add
		print("Item hinzugefügt zu Slot mit weniger als 64 Items.")
	else:
		var emptyslots = slots.filter(func(slot): return slot.item == null)
		print("Empty Slots: ", emptyslots.size())  # Debugging-Log für leere Slots
		if !emptyslots.is_empty():
			var empty_slot = emptyslots[0]
			empty_slot.item = item
			empty_slot.amount = 1
			print("Item wurde in einen leeren Slot eingefügt.")
		else:
			print("Kein Platz für dieses Item.")


	update.emit()  # Signal senden
	save_inventory("user://inventory.save") 

# Tauschen von zwei Slots
func swap_slots(index1: int, index2: int):
	var temp = slots[index1]
	slots[index1] = slots[index2]
	slots[index2] = temp
	update.emit()

func _serialize_slots(slot_array: Array[InvSlot]) -> Array:
	var data = []
	for slot in slot_array:
		var slot_data = {}
		if slot and slot.item:
			slot_data["item_name"] = slot.item.name
			slot_data["amount"] = slot.amount
		else:
			slot_data["item_name"] = ""
			slot_data["amount"] = 0
		data.append(slot_data)
	return data

func _reset_slots(slot_array: Array[InvSlot]) -> void:
	for slot in slot_array:
		if slot:
			slot.item = null
			slot.amount = 0

func _load_slots_from_data(slot_array: Array[InvSlot], data: Array) -> void:
	for i in range(min(len(data), slot_array.size())):
		var slot_data = data[i]
		if slot_data.get("item_name", "") != "":
			var item = load_item(slot_data["item_name"])
			slot_array[i].item = item
			slot_array[i].amount = slot_data.get("amount", 0)
