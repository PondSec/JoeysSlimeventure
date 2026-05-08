extends Resource

class_name Inv

signal update

const ItemRegistry := preload("res://Scripts/item_registry.gd")
const EQUIPMENT_SLOT_ORDER := [
	"weapon",
	"relic_1",
	"relic_2",
	"relic_3",
	"star_1",
	"star_2",
	"star_3",
	"charm",
]
const EQUIPMENT_LAYOUT := [
	{"title": "Weapon", "slots": ["weapon"]},
	{"title": "Relics", "slots": ["relic_1", "relic_2", "relic_3"]},
	{"title": "Stars", "slots": ["star_1", "star_2", "star_3"]},
	{"title": "Charm", "slots": ["charm"]},
]
const LEGACY_SLOT_REDIRECTS := {
	"relic": "relic_1",
	"star": "star_1",
}

@export var slots: Array[InvSlot]

var equipment_slots: Dictionary = {}


func _init() -> void:
	_ensure_equipment_slots()


func save_inventory(file_path: String) -> void:
	_ensure_equipment_slots()
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		print("Fehler beim Oeffnen der Datei zum Schreiben.")
		return

	var data := {
		"inventory_slots": _serialize_slots(slots),
		"equipment_slots": _serialize_equipment_slots(),
	}
	file.store_var(data)
	file.close()


func load_inventory(file_path: String) -> void:
	_ensure_equipment_slots()
	if not FileAccess.file_exists(file_path):
		print("Datei existiert nicht, Inventar wird nicht geladen.")
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Fehler beim Oeffnen der Datei zum Lesen.")
		return

	var data = file.get_var()
	file.close()

	_clear_all_slots()

	if data is Array:
		_deserialize_slot_array(data, slots)
	elif data is Dictionary:
		var slot_data = data.get("inventory_slots", data.get("slots", []))
		_deserialize_slot_array(slot_data, slots)

		var equipment_data = data.get("equipment_slots", {})
		if equipment_data is Dictionary:
			for slot_name in EQUIPMENT_SLOT_ORDER:
				if equipment_data.has(slot_name):
					_deserialize_slot_data(equipment_data[slot_name], get_equipped_slot(slot_name))
			for legacy_slot_name in LEGACY_SLOT_REDIRECTS.keys():
				var redirected_slot_name := String(LEGACY_SLOT_REDIRECTS[legacy_slot_name])
				if equipment_data.has(legacy_slot_name) and get_equipped_item(redirected_slot_name) == null:
					_deserialize_slot_data(equipment_data[legacy_slot_name], get_equipped_slot(redirected_slot_name))
	else:
		print("Fehler: Inventardatei enthaelt ungueltige Daten.")
		return

	update.emit()


func load_item(item_name: String) -> InvItem:
	return ItemRegistry.get_item(item_name)


func Insert(item: InvItem) -> bool:
	if item == null:
		return false

	var stack_size: int = maxi(item.stack_size, 1)
	if stack_size > 1:
		for slot in slots:
			if slot.item and slot.item.name == item.name and slot.amount < stack_size:
				slot.amount += 1
				_notify_inventory_changed()
				return true

	for slot in slots:
		if slot.item == null:
			slot.item = item
			slot.amount = 1
			_notify_inventory_changed()
			return true

	return false


func can_insert(item: InvItem, amount: int = 1) -> bool:
	if item == null or amount <= 0:
		return false

	var remaining := amount
	var stack_size: int = maxi(item.stack_size, 1)

	for slot in slots:
		if stack_size > 1 and slot.item and slot.item.name == item.name and slot.amount < stack_size:
			remaining -= min(stack_size - slot.amount, remaining)
		elif slot.item == null:
			remaining -= min(stack_size, remaining)

		if remaining <= 0:
			return true

	return false


func get_total_amount(item_names: Array[String]) -> int:
	var total := 0
	for slot in slots:
		if slot.item and item_names.has(slot.item.name):
			total += slot.amount
	return total


func remove_amount(item_names: Array[String], amount: int) -> bool:
	if amount <= 0:
		return true
	if get_total_amount(item_names) < amount:
		return false

	var remaining := amount
	for slot in slots:
		if remaining <= 0:
			break
		if slot.item and item_names.has(slot.item.name):
			var taken: int = mini(slot.amount, remaining)
			slot.amount -= taken
			remaining -= taken
			if slot.amount <= 0:
				slot.item = null
				slot.amount = 0

	_notify_inventory_changed()
	return remaining == 0


func swap_slots(index1: int, index2: int) -> void:
	if index1 < 0 or index1 >= slots.size() or index2 < 0 or index2 >= slots.size():
		return
	_swap_slot_contents(slots[index1], slots[index2])
	_notify_inventory_changed()


func get_equipped_slot(slot_name: String) -> InvSlot:
	_ensure_equipment_slots()
	return equipment_slots[slot_name] as InvSlot


func get_equipped_item(slot_name: String) -> InvItem:
	var slot := get_equipped_slot(slot_name)
	return slot.item if slot else null


func get_equipment_slot_names() -> Array[String]:
	var slot_names: Array[String] = []
	for slot_name in EQUIPMENT_SLOT_ORDER:
		slot_names.append(String(slot_name))
	return slot_names


func get_equipment_layout() -> Array[Dictionary]:
	var layout: Array[Dictionary] = []
	for layout_group in EQUIPMENT_LAYOUT:
		layout.append((layout_group as Dictionary).duplicate(true))
	return layout


func get_equipped_items() -> Array[InvItem]:
	var items: Array[InvItem] = []
	for slot_name in EQUIPMENT_SLOT_ORDER:
		var item := get_equipped_item(String(slot_name))
		if item:
			items.append(item)
	return items


func get_equipped_items_by_prefix(prefix: String) -> Array[InvItem]:
	var items: Array[InvItem] = []
	for slot_name in EQUIPMENT_SLOT_ORDER:
		var slot_name_string := String(slot_name)
		if slot_name_string == prefix or slot_name_string.begins_with(prefix + "_"):
			var item := get_equipped_item(slot_name_string)
			if item:
				items.append(item)
	return items


func contains_item(item_name: String) -> bool:
	for slot in slots:
		if slot.item and slot.item.name == item_name:
			return true
	for slot_name in EQUIPMENT_SLOT_ORDER:
		var item := get_equipped_item(String(slot_name))
		if item and item.name == item_name:
			return true
	return false


func can_equip_item(item: InvItem, slot_name: String = "") -> bool:
	if item == null:
		return false
	var target_slot := slot_name if not slot_name.is_empty() else _find_best_equipment_slot(item)
	return not target_slot.is_empty() and EQUIPMENT_SLOT_ORDER.has(target_slot) and item.can_equip_to(target_slot)


func equip_from_inventory(index: int, slot_name: String = "") -> bool:
	if index < 0 or index >= slots.size():
		return false
	var source_slot := slots[index]
	if source_slot.item == null:
		return false
	var target_slot_name := slot_name if not slot_name.is_empty() else _find_best_equipment_slot(source_slot.item)
	if not can_equip_item(source_slot.item, target_slot_name):
		return false

	var target_slot := get_equipped_slot(target_slot_name)
	if target_slot == null:
		return false

	_swap_slot_contents(source_slot, target_slot)
	if target_slot.item:
		target_slot.amount = 1
	if source_slot.item and source_slot.item.stack_size <= 1 and source_slot.amount <= 0:
		source_slot.amount = 1

	_normalize_slot(source_slot)
	_normalize_slot(target_slot)
	_notify_inventory_changed()
	return true


func unequip_to_inventory(slot_name: String) -> bool:
	var source_slot := get_equipped_slot(slot_name)
	if source_slot == null or source_slot.item == null:
		return false
	if not can_insert(source_slot.item, 1):
		return false

	var item := source_slot.item
	_clear_slot(source_slot)
	var inserted := Insert(item)
	if not inserted:
		source_slot.item = item
		source_slot.amount = 1
		return false
	_notify_inventory_changed()
	return true


func swap_inventory_with_equipment(index: int, slot_name: String) -> bool:
	if index < 0 or index >= slots.size():
		return false

	var inventory_slot := slots[index]
	var equipment_slot := get_equipped_slot(slot_name)
	if equipment_slot == null:
		return false
	if inventory_slot.item and not can_equip_item(inventory_slot.item, slot_name):
		return false

	_swap_slot_contents(inventory_slot, equipment_slot)
	if equipment_slot.item:
		equipment_slot.amount = 1
	_normalize_slot(inventory_slot)
	_normalize_slot(equipment_slot)
	_notify_inventory_changed()
	return true


func notify_changed() -> void:
	_notify_inventory_changed()


func _notify_inventory_changed() -> void:
	update.emit()
	save_inventory("user://inventory.save")


func _ensure_equipment_slots() -> void:
	for slot_name in EQUIPMENT_SLOT_ORDER:
		if not equipment_slots.has(slot_name) or equipment_slots[slot_name] == null:
			var slot := InvSlot.new()
			slot.amount = 0
			equipment_slots[slot_name] = slot


func _find_best_equipment_slot(item: InvItem) -> String:
	if item == null:
		return ""

	var requested_slot := String(item.equip_slot)
	if requested_slot.is_empty() or requested_slot == "none":
		return ""

	if EQUIPMENT_SLOT_ORDER.has(requested_slot):
		return requested_slot

	var matching_slots: Array[String] = []
	for slot_name in EQUIPMENT_SLOT_ORDER:
		var slot_name_string := String(slot_name)
		if item.can_equip_to(slot_name_string):
			matching_slots.append(slot_name_string)

	if matching_slots.is_empty():
		return ""

	for slot_name in matching_slots:
		if get_equipped_item(slot_name) == null:
			return slot_name

	return matching_slots[0]


func _serialize_slots(slot_array: Array[InvSlot]) -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for slot in slot_array:
		data.append(_serialize_slot(slot))
	return data


func _serialize_equipment_slots() -> Dictionary:
	var data := {}
	for slot_name in EQUIPMENT_SLOT_ORDER:
		data[slot_name] = _serialize_slot(get_equipped_slot(slot_name))
	return data


func _serialize_slot(slot: InvSlot) -> Dictionary:
	if slot == null or slot.item == null:
		return {
			"item_name": "",
			"amount": 0,
		}
	return {
		"item_name": slot.item.name,
		"amount": slot.amount,
	}


func _deserialize_slot_array(data: Variant, target_slots: Array[InvSlot]) -> void:
	if not (data is Array):
		return
	for i in range(min(data.size(), target_slots.size())):
		_deserialize_slot_data(data[i], target_slots[i])


func _deserialize_slot_data(data: Variant, target_slot: InvSlot) -> void:
	if target_slot == null or not (data is Dictionary):
		return

	var item_name := String(data.get("item_name", ""))
	var amount := int(data.get("amount", 0))
	if item_name.is_empty() or amount <= 0:
		_clear_slot(target_slot)
		return

	var item := load_item(item_name)
	target_slot.item = item
	target_slot.amount = amount if item and item.stack_size > 1 else min(amount, 1)
	_normalize_slot(target_slot)


func _clear_all_slots() -> void:
	for slot in slots:
		_clear_slot(slot)
	for slot_name in EQUIPMENT_SLOT_ORDER:
		_clear_slot(get_equipped_slot(slot_name))


func _clear_slot(slot: InvSlot) -> void:
	if slot == null:
		return
	slot.item = null
	slot.amount = 0


func _normalize_slot(slot: InvSlot) -> void:
	if slot == null:
		return
	if slot.item == null or slot.amount <= 0:
		_clear_slot(slot)
		return

	var max_stack: int = maxi(slot.item.stack_size, 1)
	slot.amount = clamp(slot.amount, 1, max_stack)
	if slot.item.stack_size <= 1:
		slot.amount = 1


func _swap_slot_contents(first: InvSlot, second: InvSlot) -> void:
	var first_item := first.item
	var first_amount := first.amount
	first.item = second.item
	first.amount = second.amount
	second.item = first_item
	second.amount = first_amount
