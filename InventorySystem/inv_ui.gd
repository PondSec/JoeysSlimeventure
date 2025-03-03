extends Control

@onready var inv: Inv = preload("res://InventorySystem/playerinv.tres")
@onready var slots: Array = $NinePatchRect/GridContainer.get_children()

var is_open = false
var dragging_item = null
var dragging_sprite = null
var dragging_slot_index = -1
var detected_slot_index = -1
var dragging_item_scale = 0.5  # Skalierungsfaktor

# Speicherpfad
var save_path = "user://inventory.save"

func _ready() -> void:
	inv.update.connect(update_slots)
	update_slots()
	close()

	# Lade das Inventar, wenn die UI bereit ist
	inv.load_inventory(save_path)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		if is_open:
			close()
			inv.save_inventory(save_path)  # Speichere das Inventar beim Schließen
		else:
			open()

	# Nur wenn ein Item "gezogen" wird, folge der Maus
	if dragging_item:
		dragging_item.position = get_global_mouse_position()

	if Input.is_action_just_pressed("Attack"):
		if !dragging_item:
			# Klicken auf einen Slot, um das Item zu ziehen
			detected_slot_index = get_slot_index_under_mouse()
			if detected_slot_index != -1:
				_on_slot_pressed(detected_slot_index)
		else:
			# Wenn ein Item bereits gezogen wird, dann wird es abgelegt
			detected_slot_index = get_slot_index_under_mouse()
			_on_slot_released(detected_slot_index)

	# Verwende "mouse_right" für den Rechtsklick
	if Input.is_action_just_pressed("mouse_right"):
		detected_slot_index = get_slot_index_under_mouse()
		if detected_slot_index != -1:
			_on_right_click(detected_slot_index)

# Öffne das Inventar
func open():
	visible = true
	is_open = true

# Schließe das Inventar
func close():
	visible = false
	is_open = false

func update_slots():
	for i in range(min(inv.slots.size(), slots.size())):
		var slot = slots[i]
		var item_display = slot.get_node("CenterContainer/Panel/ItemDisplay") if slot.has_node("CenterContainer/Panel/ItemDisplay") else null

		# Verstecke das Item im ursprünglichen Slot, wenn es gezogen wird
		if i == dragging_slot_index and dragging_item:
			if item_display:
				item_display.visible = false  # Verstecke das Item im Slot
		else:
			# Zeige das Item an, wenn es im Slot vorhanden ist
			if item_display:
				item_display.visible = inv.slots[i].item != null

		# Aktualisiere den Slot, wenn es nicht der gezogene Slot ist
		if i != dragging_slot_index:
			slot.update(inv.slots[i])
			
func _on_slot_pressed(slot_index: int):
	if !is_open:  # Prüfe, ob das Inventar geschlossen ist
		return
	if slot_index != -1:
		var slot = inv.slots[slot_index]
		if slot.item:
			# Verstecke das ItemDisplay (Sprite2D) im Slot sofort
			var item_display = slots[slot_index].get_node("CenterContainer/Panel/ItemDisplay") if slots[slot_index].has_node("CenterContainer/Panel/ItemDisplay") else null
			if item_display:
				item_display.visible = false
				print("DEBUG: ItemDisplay in Slot ", slot_index, " unsichtbar gemacht")
			else:
				print("DEBUG: ItemDisplay nicht gefunden in Slot ", slot_index)

			# Verstecke das Label im Slot sofort
			var label = slots[slot_index].get_node("CenterContainer/Panel/Label") if slots[slot_index].has_node("CenterContainer/Panel/Label") else null
			if label:
				label.visible = false
				print("DEBUG: Label in Slot ", slot_index, " unsichtbar gemacht")
			else:
				print("DEBUG: Label nicht gefunden in Slot ", slot_index)

			# Erstelle das draggende Item
			dragging_item = create_dragging_item(slot.item)
			dragging_sprite = dragging_item.get_child(0)

			# Skaliere das Item für die Mausdarstellung
			if dragging_sprite.texture:
				var texture_size = dragging_sprite.texture.get_size()
				dragging_sprite.scale = Vector2(64.0 / texture_size.x, 64.0 / texture_size.y)

			dragging_slot_index = slot_index

			# Aktualisiere die Slots sofort
			update_slots()  # Stelle sicher, dass das Inventar UI sofort aktualisiert wird
			
func _on_slot_released(slot_index: int):
	if !is_open:  # Prüfe, ob das Inventar geschlossen ist
		return
	if dragging_item:
		if slot_index != -1:
			# Wenn der Slot unter der Maus existiert, lege das Item dort ab
			var target_slot = inv.slots[slot_index]
			var source_slot = inv.slots[dragging_slot_index]

			if target_slot != source_slot:
				# Tausch der Slots oder Stapeln der Items, wenn die Bedingungen zutreffen
				if target_slot.item == source_slot.item and target_slot.amount < 64:
					# Stapeln des Items, wenn der Ziel-Slot das gleiche Item enthält und Platz hat
					var remaining_space = 64 - target_slot.amount
					var amount_to_stack = min(remaining_space, source_slot.amount)
					target_slot.amount += amount_to_stack
					source_slot.amount -= amount_to_stack

					# Wenn die Menge im Quell-Slot jetzt 0 ist, setze das Item auf null
					if source_slot.amount == 0:
						source_slot.item = null
				else:
					# Items werden einfach getauscht
					inv.swap_slots(dragging_slot_index, slot_index)

		# Entferne das draggende Item, nachdem es abgelegt wurde
		dragging_item.queue_free()
		dragging_item = null
		dragging_sprite = null
		dragging_slot_index = -1

		update_slots()

		# Stelle sicher, dass das Item im Quell-Slot wieder angezeigt wird, wenn es abgelegt wurde
		var source_slot_ui = slots[dragging_slot_index].get_node("CenterContainer/Panel/ItemDisplay") if slots[dragging_slot_index].has_node("ItemTexture") else null
		if source_slot_ui:
			source_slot_ui.visible = true  # Stelle das ItemTexture im Quell-Slot wieder her

func _on_right_click(slot_index: int):
	if dragging_item:
		var source_slot = inv.slots[dragging_slot_index]
		var target_slot = inv.slots[slot_index]

		if source_slot.amount > 0:
			if source_slot.amount > 1:
				# Übertrage nur ein Item
				source_slot.amount -= 1
				# Wenn der Ziel-Slot das gleiche Item enthält, stapel es
				if target_slot.item == source_slot.item:
					target_slot.amount += 1
				else:
					# Falls der Ziel-Slot leer ist, das Item setzen
					target_slot.item = source_slot.item
					target_slot.amount = 1

				# Restlichen Stapel an der Maus behalten (immer noch das gleiche Item-Objekt)
				dragging_item.position = get_global_mouse_position()  # Stelle sicher, dass das verbleibende Item weiterhin folgt
			else:
				# Wenn nur noch ein Item übrig ist, lege es ab
				if target_slot.item == null:
					target_slot.item = source_slot.item
					target_slot.amount = 1
				else:
					# Wenn das Ziel-Slot das gleiche Item enthält, dann stapeln
					target_slot.amount += 1

				# Das letzte Item ablegen
				source_slot.item = null
				source_slot.amount = 0
				dragging_item.queue_free()  # Entferne das Objekt
				dragging_item = null  # Setze die Hand auf null

				# Aktualisiere UI sofort
				# Manuell das ItemTexture des Quell-Slots ausblenden
				var source_slot_ui = slots[dragging_slot_index].get_node("CenterContainer/Panel/ItemDisplay") if slots[dragging_slot_index].has_node("ItemTexture") else null
				if source_slot_ui:
					source_slot_ui.visible = false

				update_slots()
				return  # Ende des Rechtsklicks, keine weiteren Items in der Hand
		update_slots()

# Item für das Ziehen erstellen
func create_dragging_item(item: InvItem) -> Control:
	var drag_item = Control.new()
	var sprite = Sprite2D.new()
	sprite.texture = item.texture

	if sprite.texture:
		var texture_size = sprite.texture.get_size()
		sprite.scale = Vector2(64.0 / texture_size.x, 64.0 / texture_size.y)

	drag_item.add_child(sprite)

	var ui_parent = self.get_parent()
	if ui_parent:
		ui_parent.add_child(drag_item)

	drag_item.position = get_global_mouse_position()

	return drag_item
	
# Slot unter der Maus ermitteln
func get_slot_index_under_mouse() -> int:
	for i in range(slots.size()):
		if slots[i].get_global_rect().has_point(get_global_mouse_position()):
			return i
	return -1
