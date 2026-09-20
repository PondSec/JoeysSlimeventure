extends Panel

const CAVE_SLOT_TEXTURE := preload("res://Assets/UI/Inventory/cave_slot.png")
const LUSH_SLOT_TEXTURE := preload("res://Assets/UI/Inventory/lush_slot.png")

var slot_index = -1
signal slot_updated

var lush_background: TextureRect


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("biome_aware_ui")
	var cave_background := get_node_or_null("Background") as TextureRect
	if cave_background == null:
		return
	cave_background.texture = CAVE_SLOT_TEXTURE
	cave_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lush_background = TextureRect.new()
	lush_background.name = "LushBackground"
	lush_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lush_background.texture = LUSH_SLOT_TEXTURE
	lush_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lush_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lush_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lush_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lush_background)
	move_child(lush_background, cave_background.get_index() + 1)


func _exit_tree() -> void:
	remove_from_group("biome_aware_ui")


func set_biome_weight(theme_id: String, weight: float) -> void:
	if theme_id != "lush":
		return
	var blend := clampf(weight, 0.0, 1.0)
	var cave_background := get_node_or_null("Background") as TextureRect
	if cave_background:
		cave_background.modulate.a = 1.0 - blend
	if lush_background:
		lush_background.modulate.a = blend

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
			item_display.texture = _get_display_texture(slot_data.item)

	if label:
		label.visible = slot_data.item != null
		if slot_data.amount > 1:
			label.text = str(slot_data.amount)
		else:
			label.text = ""


func _get_display_texture(item: InvItem) -> Texture2D:
	if item.world_texture_region.has_area():
		var cropped := AtlasTexture.new()
		cropped.atlas = item.texture
		cropped.region = item.world_texture_region
		return cropped
	return item.texture
# Handling mouse events for drag
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			emit_signal("slot_pressed", slot_index)
		else:
			emit_signal("slot_released", slot_index)
			emit_signal("slot_updated")  # 🔥 Signal senden, wenn sich der Slot geändert hat!
