extends Control

@onready var inv: Inv = preload("res://InventorySystem/playerinv.tres")
@onready var slots: Array = $NinePatchRect/GridContainer.get_children()

var is_open = false
var dragging_item = null
var dragging_sprite = null  # Eine separate Variable für das Sprite2D
var dragging_slot_index = -1
var detected_slot_index = -1  # Diese Variable speichert das aktuelle Slot, auf das geklickt wurde

# Skalierungsfaktor
var dragging_item_scale = 0.5  # Reduziert die Größe des gezogenen Items

func _ready() -> void:
	inv.update.connect(update_slots)
	update_slots()
	close()

func update_slots():
	for i in range(min(inv.slots.size(), slots.size())):
		var slot = slots[i]
		slot.update(inv.slots[i])

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		if is_open:
			close()
		else:
			open()

	if dragging_item:
		# Update the position of the dragged item
		var mouse_pos = get_local_mouse_position()  # Mausposition relativ zum UI-Container
		var dragging_item_size = dragging_sprite.texture.get_size()  # Hole die Texturgröße des Sprites
		var scaled_size = dragging_item_size * dragging_item_scale  # Berechnete skalierte Größe des Items

		# Berechnung des exakten Versatzes, um das Sprite zu zentrieren
		var offset = scaled_size / 2  # Berechneter Versatz, um das Sprite zu zentrieren

		# Positioniere das Sprite exakt unter der Maus (keinen weiteren Versatz)
		dragging_sprite.position = mouse_pos - offset  # Verschiebe das Sprite relativ zur Mausposition

	if Input.is_action_just_pressed("Attack"):  # Linksklick erkannt
		if !dragging_item:
			detected_slot_index = get_slot_index_under_mouse()  # Hole das Slot unter der Maus
			_on_slot_pressed(detected_slot_index)  # Beginne mit dem Ziehen des Items
	if Input.is_action_just_released("Attack"):  # Linksklick losgelassen
		if dragging_item:
			detected_slot_index = get_slot_index_under_mouse()  # Hole das Slot unter der Maus
			_on_slot_released(detected_slot_index)  # Setze das Item in das neue Slot

func open():
	visible = true
	is_open = true

func close():
	visible = false
	is_open = false

# Mouse click detection for dragging items
func _on_slot_pressed(slot_index: int):
	if slot_index != -1:  # Stelle sicher, dass der Slot existiert
		var slot = inv.slots[slot_index]
		if slot.item:
			dragging_item = create_dragging_item(slot.item)
			dragging_sprite = dragging_item.get_child(0)  # Holen wir das Sprite2D
			dragging_sprite.scale = Vector2(dragging_item_scale, dragging_item_scale)  # Skalieren des Sprites
			dragging_slot_index = slot_index
			update_slots()

# Mouse release detection to drop item into a new slot
func _on_slot_released(slot_index: int):
	if dragging_item and slot_index != -1:
		var target_slot = inv.slots[slot_index]
		if dragging_slot_index != slot_index:
			inv.swap_slots(dragging_slot_index, slot_index)
		dragging_item.queue_free()  # Entferne das visuelle Element des gezogenen Items
		dragging_item = null
		dragging_sprite = null  # Entferne das Sprite2D
		dragging_slot_index = -1
		update_slots()

# Create a visual representation of the dragged item
func create_dragging_item(item: InvItem) -> Control:
	var drag_item = Control.new()
	var sprite = Sprite2D.new()
	sprite.texture = item.texture
	drag_item.add_child(sprite)
	add_child(drag_item)
	return drag_item

# Hole das Slot unter der Maus
func get_slot_index_under_mouse() -> int:
	for i in range(slots.size()):
		if slots[i].get_global_rect().has_point(get_global_mouse_position()):
			return i
	return -1  # Rückgabe -1, wenn kein Slot unter der Maus ist
