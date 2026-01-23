extends Control

@onready var inv: Inv = preload("res://InventorySystem/playerinv.tres")
@onready var inventory_slot_nodes: Array = $NinePatchRect/GridContainer.get_children()
@onready var equipment_slot_nodes: Array = _get_equipment_slot_nodes()
@onready var spind_ui = $SpindUI
@onready var tooltip = preload("res://InventorySystem/Tooltip.tscn").instantiate()

var is_open = false
var dragging_item = null
var dragging_sprite = null
var dragging_slot_ref_index = -1
var detected_slot_index = -1
var dragging_item_scale = 0.5
var hovered_slot_index = -1
var is_hovering = false
var slot_refs: Array = []

const EQUIPMENT_SLOT_TYPES = {
	"WeaponSlot": "weapon",
	"HeadSlot": "head",
	"ChestSlot": "chest",
	"BootsSlot": "boots",
	"RingSlot": "ring",
	"AmuletSlot": "amulet"
}

var save_path = "user://inventory.save"

func _ready() -> void:
	inv.update.connect(update_slots)
	_build_slot_refs()
	update_slots()
	inv.load_inventory(save_path)
	close()
	
	# Tooltip als Child hinzufügen
	add_child(tooltip)
	tooltip.visible = false

func _get_equipment_slot_nodes() -> Array:
	if has_node("EquipmentPanel/EquipmentGrid"):
		var nodes = []
		for node in $EquipmentPanel/EquipmentGrid.get_children():
			if node is Panel:
				nodes.append(node)
		return nodes
	return []

func _build_slot_refs() -> void:
	slot_refs.clear()
	for i in range(inventory_slot_nodes.size()):
		slot_refs.append({
			"kind": "inventory",
			"index": i,
			"node": inventory_slot_nodes[i],
			"equip_type": ""
		})
	for i in range(equipment_slot_nodes.size()):
		var slot_node = equipment_slot_nodes[i]
		slot_refs.append({
			"kind": "equipment",
			"index": i,
			"node": slot_node,
			"equip_type": EQUIPMENT_SLOT_TYPES.get(slot_node.name, "")
		})

func _get_slot_ref(index: int) -> Dictionary:
	if index < 0 or index >= slot_refs.size():
		return {}
	return slot_refs[index]

func _get_slot_data(slot_ref: Dictionary) -> InvSlot:
	if slot_ref.get("kind") == "equipment":
		var equip_index = slot_ref.get("index", -1)
		if equip_index >= 0 and equip_index < inv.equipment_slots.size():
			return inv.equipment_slots[equip_index]
		return null
	var inv_index = slot_ref.get("index", -1)
	if inv_index >= 0 and inv_index < inv.slots.size():
		return inv.slots[inv_index]
	return null

func _is_equipment_slot(slot_ref: Dictionary) -> bool:
	return slot_ref.get("kind") == "equipment"

func _can_place_in_equipment(slot_ref: Dictionary, item: InvItem) -> bool:
	if item == null:
		return false
	var expected_slot = slot_ref.get("equip_type", "")
	if not item.is_equipment:
		return false
	if expected_slot == "":
		return false
	return item.equip_slot == expected_slot

func _handle_inventory_drop(source_slot: InvSlot, target_slot: InvSlot) -> void:
	if target_slot.item == source_slot.item and target_slot.amount < 64:
		var remaining_space = 64 - target_slot.amount
		var amount_to_stack = min(remaining_space, source_slot.amount)
		target_slot.amount += amount_to_stack
		source_slot.amount -= amount_to_stack
		if source_slot.amount == 0:
			source_slot.item = null
	else:
		_swap_slot_contents(source_slot, target_slot)

func _handle_drop_to_equipment(source_ref: Dictionary, target_ref: Dictionary, source_slot: InvSlot, target_slot: InvSlot) -> void:
	if not _can_place_in_equipment(target_ref, source_slot.item):
		return

	if source_slot.amount > 1:
		if target_slot.item == null:
			target_slot.item = source_slot.item
			target_slot.amount = 1
			source_slot.amount -= 1
			if source_slot.amount == 0:
				source_slot.item = null
		return

	if target_slot.item == null:
		target_slot.item = source_slot.item
		target_slot.amount = 1
		source_slot.item = null
		source_slot.amount = 0
		return

	if _is_equipment_slot(source_ref) and not _can_place_in_equipment(source_ref, target_slot.item):
		return

	_swap_slot_contents(source_slot, target_slot)
	target_slot.amount = 1
	if _is_equipment_slot(source_ref):
		source_slot.amount = 1

func _handle_drop_from_equipment(source_ref: Dictionary, target_ref: Dictionary, source_slot: InvSlot, target_slot: InvSlot) -> void:
	if target_slot.item == source_slot.item and target_slot.amount < 64:
		target_slot.amount += 1
		source_slot.item = null
		source_slot.amount = 0
	else:
		_swap_slot_contents(source_slot, target_slot)
		if _is_equipment_slot(source_ref):
			source_slot.amount = min(source_slot.amount, 1)

func _swap_slot_contents(slot_a: InvSlot, slot_b: InvSlot) -> void:
	var temp_item = slot_a.item
	var temp_amount = slot_a.amount
	slot_a.item = slot_b.item
	slot_a.amount = slot_b.amount
	slot_b.item = temp_item
	slot_b.amount = temp_amount

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		if is_open:
			close()
			inv.save_inventory(save_path)
		else:
			open()
			
	if dragging_item:
		dragging_item.position = get_global_mouse_position()

	if Input.is_action_just_pressed("Attack"):
		if !dragging_item:
			detected_slot_index = get_slot_index_under_mouse()
			if detected_slot_index != -1:
				_on_slot_pressed(detected_slot_index)
		else:
			detected_slot_index = get_slot_index_under_mouse()
			_on_slot_released(detected_slot_index)

	if Input.is_action_just_pressed("mouse_right"):
		detected_slot_index = get_slot_index_under_mouse()
		if detected_slot_index != -1:
			_on_right_click(detected_slot_index)
	
	# Hover-Erkennung mit Timer für bessere Performance
	if is_open:
		var current_hovered_slot = get_slot_index_under_mouse()
		if current_hovered_slot != hovered_slot_index:
			hovered_slot_index = current_hovered_slot
			_update_tooltip()

func _update_tooltip():
	if hovered_slot_index != -1 and is_open:
		var slot_ref = _get_slot_ref(hovered_slot_index)
		var slot = _get_slot_data(slot_ref)
		if slot and slot.item:
			await get_tree().create_timer(0.3).timeout
			if hovered_slot_index != -1 and is_open:
				tooltip.show_tooltip(slot.item, get_global_mouse_position())
		else:
			tooltip.hide_tooltip()
	else:
		tooltip.hide_tooltip()

func open():
	visible = true
	is_open = true
	update_slots()

func close():
	visible = false
	is_open = false
	update_slots()
	tooltip.hide_tooltip()
	
	if dragging_item:
		var source_slot_ref = _get_slot_ref(dragging_slot_ref_index)
		if source_slot_ref:
			var source_slot = _get_slot_data(source_slot_ref)
			if source_slot:
				var source_node = source_slot_ref["node"]
				var item_display = source_node.get_node("CenterContainer/Panel/ItemDisplay") if source_node.has_node("CenterContainer/Panel/ItemDisplay") else null
				if item_display:
					item_display.visible = true

		dragging_item.queue_free()
		dragging_item = null
		dragging_sprite = null
		dragging_slot_ref_index = -1
		update_slots()

func update_slots():
	for i in range(slot_refs.size()):
		var slot_ref = slot_refs[i]
		var slot_node = slot_ref["node"]
		var slot_data = _get_slot_data(slot_ref)
		if slot_data == null:
			continue

		var item_display = slot_node.get_node("CenterContainer/Panel/ItemDisplay") if slot_node.has_node("CenterContainer/Panel/ItemDisplay") else null

		# Verstecke das Item im ursprünglichen Slot, wenn es gezogen wird
		if i == dragging_slot_ref_index and dragging_item:
			if item_display:
				item_display.visible = false
		else:
			if item_display:
				item_display.visible = slot_data.item != null

		# Aktualisiere den Slot, wenn es nicht der gezogene Slot ist
		if i != dragging_slot_ref_index:
			slot_node.update(slot_data)
			
func _on_slot_pressed(slot_index: int):
	if !is_open:  # Prüfe, ob das Inventar geschlossen ist
		return
	if slot_index != -1:
		var slot_ref = _get_slot_ref(slot_index)
		var slot = _get_slot_data(slot_ref)
		if slot.item:
			# Verstecke das ItemDisplay (Sprite2D) im Slot sofort
			var slot_node = slot_ref.get("node")
			var item_display = slot_node.get_node("CenterContainer/Panel/ItemDisplay") if slot_node and slot_node.has_node("CenterContainer/Panel/ItemDisplay") else null
			if item_display:
				item_display.visible = false
				print("DEBUG: ItemDisplay in Slot ", slot_index, " unsichtbar gemacht")
			else:
				print("DEBUG: ItemDisplay nicht gefunden in Slot ", slot_index)

			# Verstecke das Label im Slot sofort
			var label = slot_node.get_node("CenterContainer/Panel/Label") if slot_node and slot_node.has_node("CenterContainer/Panel/Label") else null
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

			dragging_slot_ref_index = slot_index

			# Aktualisiere die Slots sofort
			update_slots()  # Stelle sicher, dass das Inventar UI sofort aktualisiert wird
			
func _on_slot_released(slot_index: int):
	if !is_open:  # Prüfe, ob das Inventar geschlossen ist
		return
	if dragging_item:
		if slot_index != -1:
			# Wenn der Slot unter der Maus existiert, lege das Item dort ab
			var target_ref = _get_slot_ref(slot_index)
			var source_ref = _get_slot_ref(dragging_slot_ref_index)
			var target_slot = _get_slot_data(target_ref)
			var source_slot = _get_slot_data(source_ref)

			if target_slot and source_slot and target_slot != source_slot:
				if _is_equipment_slot(target_ref):
					_handle_drop_to_equipment(source_ref, target_ref, source_slot, target_slot)
				elif _is_equipment_slot(source_ref):
					_handle_drop_from_equipment(source_ref, target_ref, source_slot, target_slot)
				else:
					_handle_inventory_drop(source_slot, target_slot)

		# Entferne das draggende Item, nachdem es abgelegt wurde
		dragging_item.queue_free()
		dragging_item = null
		dragging_sprite = null
		dragging_slot_ref_index = -1

		update_slots()

		# Slots nach dem Ablegen neu zeichnen

func _on_right_click(slot_index: int):
	if not dragging_item:
		return

	var source_ref = _get_slot_ref(dragging_slot_ref_index)
	var target_ref = _get_slot_ref(slot_index)

	if _is_equipment_slot(source_ref) or _is_equipment_slot(target_ref):
		return

	var source_slot = _get_slot_data(source_ref)
	var target_slot = _get_slot_data(target_ref)
	
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
	dragging_slot_ref_index = -1

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
	for i in range(slot_refs.size()):
		var slot_node = slot_refs[i].get("node")
		if slot_node and slot_node.get_global_rect().has_point(get_global_mouse_position()):
			return i
	return -1
