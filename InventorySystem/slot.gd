extends Panel

var slot_index = -1
signal slot_updated

func update(slot_data: InvSlot) -> void:
	var item_display := get_node_or_null("CenterContainer/ItemDisplay")
	if item_display == null:
		item_display = get_node_or_null("CenterContainer/Panel/ItemDisplay")

	var label := get_node_or_null("AmountLabel")
	if label == null:
		label = get_node_or_null("CenterContainer/Panel/Label")

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
