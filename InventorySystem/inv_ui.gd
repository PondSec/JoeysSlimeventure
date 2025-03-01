extends Control

@onready var inv: Inv = preload("res://InventorySystem/playerinv.tres")
@onready var slots: Array = $NinePatchRect/GridContainer.get_children()

var is_open = false
var dragging_item = null
var dragging_sprite = null
var dragging_slot_index = -1
var detected_slot_index = -1

var dragging_item_scale = 0.5  # Skalierungsfaktor

func _ready() -> void:
	inv.update.connect(update_slots)
	update_slots()
	close()

func update_slots():
	for i in range(min(inv.slots.size(), slots.size())):
		var slot = slots[i]
		var item_texture = slot.get_node("ItemTexture") if slot.has_node("ItemTexture") else null
		
		# Falls das Item gezogen wird, verstecke das Bild nur im ursprünglichen Slot
		if i == dragging_slot_index and dragging_item:
			if item_texture:
				item_texture.visible = false
		else:
			if item_texture:
				item_texture.visible = inv.slots[i].item != null
		
		# Verhindere doppelte Anzeige des Items während des Draggens
		if i != dragging_slot_index:
			slot.update(inv.slots[i])

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		if is_open:
			close()
		else:
			open()

	if dragging_item:
		dragging_item.position = get_global_mouse_position()

	if Input.is_action_just_pressed("Attack"):
		if !dragging_item:
			detected_slot_index = get_slot_index_under_mouse()
			_on_slot_pressed(detected_slot_index)

	if Input.is_action_just_released("Attack"):
		if dragging_item:
			detected_slot_index = get_slot_index_under_mouse()
			_on_slot_released(detected_slot_index)

func open():
	visible = true
	is_open = true

func close():
	visible = false
	is_open = false

func _on_slot_pressed(slot_index: int):
	if slot_index != -1:
		var slot = inv.slots[slot_index]
		if slot.item:
			dragging_item = create_dragging_item(slot.item)
			dragging_sprite = dragging_item.get_child(0)

			# Skaliere das Item für die Mausdarstellung
			if dragging_sprite.texture:
				var texture_size = dragging_sprite.texture.get_size()
				dragging_sprite.scale = Vector2(64.0 / texture_size.x, 64.0 / texture_size.y)

			dragging_slot_index = slot_index

			# Verstecke das Item im ursprünglichen Slot
			var item_texture = slots[slot_index].get_node("ItemTexture") if slots[slot_index].has_node("ItemTexture") else null
			if item_texture:
				item_texture.visible = false

			update_slots()

func _on_slot_released(slot_index: int):
	if dragging_item:
		if slot_index != -1 and dragging_slot_index != slot_index:
			inv.swap_slots(dragging_slot_index, slot_index)

		dragging_item.queue_free()
		dragging_item = null
		dragging_sprite = null
		dragging_slot_index = -1

		update_slots()

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

func get_slot_index_under_mouse() -> int:
	for i in range(slots.size()):
		if slots[i].get_global_rect().has_point(get_global_mouse_position()):
			return i
	return -1
