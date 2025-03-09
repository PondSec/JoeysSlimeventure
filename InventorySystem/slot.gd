extends Panel

@onready var item_visual: Sprite2D = $CenterContainer/Panel/ItemDisplay
@onready var amount_text: Label = $CenterContainer/Panel/Label
var slot_index = -1
signal slot_updated

func update(slot_data: InvSlot) -> void:
	var item_display = get_node("CenterContainer/Panel/ItemDisplay") if has_node("CenterContainer/Panel/ItemDisplay") else null
	var label = get_node("CenterContainer/Panel/Label") if has_node("CenterContainer/Panel/Label") else null

	if item_display:
		item_display.visible = slot_data.item != null
		if slot_data.item:
			item_display.texture = slot_data.item.texture

	if label:
		label.visible = slot_data.item != null
		if slot_data.amount > 1:
			label.text = str(slot_data.amount)
		else:
			label.text = ""
# Handling mouse events for drag
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			emit_signal("slot_pressed", slot_index)
		else:
			emit_signal("slot_released", slot_index)
			emit_signal("slot_updated")  # 🔥 Signal senden, wenn sich der Slot geändert hat!
