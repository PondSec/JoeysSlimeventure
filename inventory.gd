extends Resource

class_name Inv

signal update

@export var slots: Array[InvSlot]

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

# Swap items between two slots
func swap_slots(index1: int, index2: int):
	var temp = slots[index1]
	slots[index1] = slots[index2]
	slots[index2] = temp
	update.emit()
