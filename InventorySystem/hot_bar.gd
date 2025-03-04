extends Control

@onready var inv: Inv = preload("res://InventorySystem/playerinv.tres")
@onready var hotbar_slots: Array = $NinePatchRect2/HotBarSlots.get_children()

var selected_slot_index = 0  # Welcher Hotbar-Slot aktiv ist

func _ready():
	inv.update.connect(update_hotbar)
	update_hotbar()

func update_hotbar():
	var inv_size = inv.slots.size()
	if inv_size < 9:
		print("WARNUNG: Inventar hat weniger als 9 Slots!")
		return

	# Die letzten 9 Slots des Inventars in die Hotbar spiegeln
	for i in range(9):
		var inventory_index = inv_size - 9 + i  # Letzte 9 Slots
		hotbar_slots[i].update(inv.slots[inventory_index])
		
	# Auswahl hervorheben
	highlight_selected_slot()

func _process(delta):
	# Hotbar per 1-9 auswählen
	for i in range(9):  
		if Input.is_action_just_pressed("hotbar_%d" % (i+1)):
			selected_slot_index = i
			highlight_selected_slot()

	# Benutze das Item aus dem ausgewählten Slot
	if Input.is_action_just_pressed("use_item"):
		use_item(selected_slot_index)
	update_hotbar()

func highlight_selected_slot():
	for i in range(hotbar_slots.size()):
		hotbar_slots[i].modulate = Color(1, 1, 1, 1) if i == selected_slot_index else Color(0.7, 0.7, 0.7, 1)

func use_item(hotbar_index):
	var inv_index = inv.slots.size() - 9 + hotbar_index  # Zugehöriger Inventarslot
	var slot = inv.slots[inv_index]

	if slot.item:
		print("Benutze", slot.item.name)
		# Hier eigene Logik für die Item-Nutzung einfügen (Essen, Trinken, Waffe, etc.)
