extends Control

@onready var inv: Inv = preload("res://InventorySystem/playerinv.tres")
@onready var slots: Array = $NinePatchRect/GridContainer.get_children()
@onready var spind_ui = $SpindUI

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
	inv.load_inventory(save_path)
	close()
	

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
	update_slots()

# Schließe das Inventar
func close():
	visible = false
	is_open = false
	update_slots()
	
	# Wenn ein Item gezogen wird, lege es zurück in den ursprünglichen Slot
	if dragging_item:
		var source_slot = inv.slots[dragging_slot_index]
		if source_slot:
			# Zeige das ursprüngliche Item wieder im Slot
			var item_display = slots[dragging_slot_index].get_node("CenterContainer/Panel/ItemDisplay") if slots[dragging_slot_index].has_node("CenterContainer/Panel/ItemDisplay") else null
			if item_display:
				item_display.visible = true

		# Entferne das gezogene Item und setze die Variablen zurück
		dragging_item.queue_free()
		dragging_item = null
		dragging_sprite = null
		dragging_slot_index = -1
		
		# Aktualisiere die Slots, um die Sichtbarkeit sicherzustellen
		update_slots()


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
	if not dragging_item:
		return
	
	var source_slot = inv.slots[dragging_slot_index]
	var target_slot = inv.slots[slot_index]
	
	# Sicherheitsprüfungen
	if not source_slot.item or source_slot.amount <= 0:
		return
	
	# Fall 1: Ziel-Slot ist leer
	if not target_slot.item:
		target_slot.item = source_slot.item.duplicate()  # Wichtig: Neue Instanz erstellen!
		target_slot.amount = 1
		source_slot.amount -= 1
		
		if source_slot.amount <= 0:
			source_slot.item = null
			cleanup_dragging_item()
		else:
			update_dragging_item(source_slot.item)
	
	# Fall 2: Gleiches Item und Platz zum Stapeln
	elif target_slot.item == source_slot.item and target_slot.amount < 64:
		target_slot.amount += 1
		source_slot.amount -= 1
		
		if source_slot.amount <= 0:
			source_slot.item = null
			cleanup_dragging_item()
		else:
			update_dragging_item(source_slot.item)
	
	# Fall 3: Unterschiedliche Items - Tausche nur ein Item
	else:
		# Temporäre Variablen speichern
		var temp_item = target_slot.item.duplicate()
		var temp_amount = target_slot.amount
		
		# Ein Item vom Quell-Slot in den Ziel-Slot bewegen
		target_slot.item = source_slot.item.duplicate()
		target_slot.amount = 1
		source_slot.amount -= 1
		
		# Ursprüngliches Ziel-Item in den Quell-Slot bewegen
		if source_slot.amount > 0:
			source_slot.item = temp_item
			source_slot.amount = temp_amount
		else:
			source_slot.item = temp_item
			source_slot.amount = temp_amount
		
		update_dragging_item(source_slot.item)
	
	update_slots()

func cleanup_dragging_item():
	if dragging_item:
		dragging_item.queue_free()
		dragging_item = null
	dragging_slot_index = -1

func update_dragging_item(item: InvItem):
	if dragging_item:
		# Altes Sprite entfernen
		var old_sprite = dragging_item.get_child(0)
		dragging_item.remove_child(old_sprite)
		old_sprite.queue_free()
		
		# Neues Sprite erstellen
		var new_sprite = Sprite2D.new()
		new_sprite.texture = item.texture
		if new_sprite.texture:
			var tex_size = new_sprite.texture.get_size()
			new_sprite.scale = Vector2(64/tex_size.x, 64/tex_size.y)
		dragging_item.add_child(new_sprite)

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
