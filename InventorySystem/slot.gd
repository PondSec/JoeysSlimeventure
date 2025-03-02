extends Panel

@onready var item_visual: Sprite2D = $CenterContainer/Panel/ItemDisplay
@onready var amount_text: Label = $CenterContainer/Panel/Label
var slot_index = -1

func update(slot: InvSlot):
	if !slot.item:
		item_visual.visible = false
		amount_text.visible = false
	else:
		item_visual.visible = true
		item_visual.texture = slot.item.texture
		if slot.amount > 1:
			amount_text.visible = true
		amount_text.text = str(slot.amount)

# Handling mouse events for drag
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:  # Hier wurde MOUSE_BUTTON_LEFT statt BUTTON_LEFT verwendet
			if event.pressed:
				emit_signal("slot_pressed", slot_index)
			else:
				emit_signal("slot_released", slot_index)
