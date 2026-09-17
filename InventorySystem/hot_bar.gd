extends Control

## Pixel-art hotbar with biome-aware skins. A world biome only has to call
## `set_biome_weight("lush", value)` on the `biome_aware_ui` group; further
## themes can be registered in BIOME_THEMES without touching item-slot logic.

const SLOT_COUNT := 9
const HOTBAR_SIZE := Vector2(1055.0, 192.0)
const SLOT_FACE_SCALE := 1.12
const BIOME_THEMES := {
	"cave": {
		"bar": preload("res://Assets/UI/Hotbar/cave_frame.png"),
		"inactive": preload("res://Assets/UI/Hotbar/cave_slot_inactive.png"),
		"active": preload("res://Assets/UI/Hotbar/cave_slot_active.png"),
		# These are measured from the assembled cave source, not distributed
		# mathematically. The latter made the selected face drift farther right
		# with every slot.
		"slot_centers": [
			Vector2(200.0, 100.0), Vector2(285.0, 100.0), Vector2(370.0, 100.0),
			Vector2(455.0, 100.0), Vector2(540.0, 100.0), Vector2(625.0, 100.0),
			Vector2(710.0, 100.0), Vector2(795.0, 100.0), Vector2(880.0, 100.0),
		],
	},
	"lush": {
		"bar": preload("res://Assets/UI/Hotbar/lush_frame.png"),
		"inactive": preload("res://Assets/UI/Hotbar/lush_slot_inactive.png"),
		"active": preload("res://Assets/UI/Hotbar/lush_slot_active.png"),
		"slot_centers": [
			Vector2(200.0, 100.0), Vector2(285.0, 100.0), Vector2(370.0, 100.0),
			Vector2(455.0, 100.0), Vector2(540.0, 100.0), Vector2(625.0, 100.0),
			Vector2(710.0, 100.0), Vector2(795.0, 100.0), Vector2(880.0, 100.0),
		],
	},
}

@onready var inv: Inv = preload("res://InventorySystem/playerinv.tres")

var selected_slot_index := 0
var _theme_nodes: Dictionary = {}
var _item_icons: Array[Sprite2D] = []
var _amount_labels: Array[Label] = []
var _biome_weights := {"cave": 1.0, "lush": 0.0}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("biome_aware_ui")
	# Kept only as a scene compatibility anchor; rendering is now layered below.
	$NinePatchRect2.visible = false
	_build_theme_layers()
	_build_item_layers()
	inv.update.connect(update_hotbar)
	update_hotbar()
	_apply_biome_weights()


func _exit_tree() -> void:
	remove_from_group("biome_aware_ui")


func _build_theme_layers() -> void:
	for theme_id_variant in BIOME_THEMES.keys():
		var theme_id := String(theme_id_variant)
		var definition: Dictionary = BIOME_THEMES[theme_id]
		var slot_centers: Array = definition["slot_centers"]
		var theme_root := Control.new()
		theme_root.name = "%sTheme" % theme_id.capitalize()
		theme_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		theme_root.size = HOTBAR_SIZE
		theme_root.z_index = 1
		add_child(theme_root)

		var bar := _create_texture_rect(definition["bar"] as Texture2D, HOTBAR_SIZE, TextureRect.STRETCH_SCALE)
		bar.name = "Frame"
		theme_root.add_child(bar)

		var inactive_slots: Array[TextureRect] = []
		var active_slots: Array[TextureRect] = []
		for slot_index in range(SLOT_COUNT):
			var inactive := _create_slot_face(definition["inactive"] as Texture2D, slot_centers[slot_index] as Vector2)
			inactive.name = "Inactive%d" % (slot_index + 1)
			theme_root.add_child(inactive)
			inactive_slots.append(inactive)

			var active := _create_slot_face(definition["active"] as Texture2D, slot_centers[slot_index] as Vector2)
			active.name = "Active%d" % (slot_index + 1)
			theme_root.add_child(active)
			active_slots.append(active)

		_theme_nodes[theme_id] = {
			"bar": bar,
			"inactive": inactive_slots,
			"active": active_slots,
		}


func _build_item_layers() -> void:
	# Item contents follow the common visual grid. Theme faces may differ by a
	# few source pixels at their decorative edges, but never shift an item icon.
	var item_slot_centers: Array = BIOME_THEMES["cave"]["slot_centers"]
	for slot_index in range(SLOT_COUNT):
		var icon := Sprite2D.new()
		icon.name = "Item%d" % (slot_index + 1)
		icon.position = item_slot_centers[slot_index] + Vector2(0.0, -3.0)
		icon.scale = Vector2(0.50, 0.50)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.z_index = 5
		add_child(icon)
		_item_icons.append(icon)

		var amount := Label.new()
		amount.name = "Amount%d" % (slot_index + 1)
		amount.position = item_slot_centers[slot_index] + Vector2(11.0, 13.0)
		amount.size = Vector2(23.0, 22.0)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		amount.add_theme_font_size_override("font_size", 20)
		amount.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84, 1.0))
		amount.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 1.0))
		amount.add_theme_constant_override("outline_size", 3)
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount.z_index = 6
		add_child(amount)
		_amount_labels.append(amount)


func _create_texture_rect(
	texture: Texture2D,
	texture_size: Vector2,
	stretch_mode: TextureRect.StretchMode = TextureRect.STRETCH_KEEP,
) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.size = texture_size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch_mode
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _create_slot_face(texture: Texture2D, center: Vector2) -> TextureRect:
	var face_size := texture.get_size() * SLOT_FACE_SCALE
	var rect := _create_texture_rect(texture, face_size, TextureRect.STRETCH_SCALE)
	rect.position = center - face_size * 0.5
	return rect


## The ChapterLevel drives this with exactly its parallax `lush_biome_strength`.
func set_biome_weight(theme_id: String, weight: float) -> void:
	if not BIOME_THEMES.has(theme_id):
		return
	_biome_weights[theme_id] = clampf(weight, 0.0, 1.0)
	if theme_id == "lush":
		_biome_weights["cave"] = 1.0 - _biome_weights[theme_id]
	_apply_biome_weights()


func _apply_biome_weights() -> void:
	for theme_id_variant in _theme_nodes.keys():
		var theme_id := String(theme_id_variant)
		var nodes: Dictionary = _theme_nodes[theme_id]
		var weight := float(_biome_weights.get(theme_id, 0.0))
		(nodes["bar"] as TextureRect).modulate.a = weight
		var inactive_slots: Array = nodes["inactive"]
		var active_slots: Array = nodes["active"]
		for slot_index in range(SLOT_COUNT):
			(inactive_slots[slot_index] as TextureRect).modulate.a = weight if slot_index != selected_slot_index else 0.0
			(active_slots[slot_index] as TextureRect).modulate.a = weight if slot_index == selected_slot_index else 0.0


func update_hotbar() -> void:
	if inv.slots.size() < SLOT_COUNT:
		push_warning("Inventar hat weniger als neun Slots; Hotbar wird nicht aktualisiert.")
		return
	for slot_index in range(SLOT_COUNT):
		var inventory_index := inv.slots.size() - SLOT_COUNT + slot_index
		var slot: InvSlot = inv.slots[inventory_index]
		var has_item := slot != null and slot.item != null
		var icon := _item_icons[slot_index]
		icon.visible = has_item
		icon.texture = slot.item.texture if has_item else null
		var amount := _amount_labels[slot_index]
		amount.text = str(slot.amount) if has_item and slot.amount > 1 else ""
	highlight_selected_slot()


func _process(_delta: float) -> void:
	for slot_index in range(SLOT_COUNT):
		if Input.is_action_just_pressed("hotbar_%d" % (slot_index + 1)):
			set_selected_slot(slot_index)
	var player := get_parent().get_parent()
	if player != null and player.has_method("get_selected_hotbar_index"):
		var player_selection := int(player.get_selected_hotbar_index())
		if player_selection >= 0 and player_selection < SLOT_COUNT and player_selection != selected_slot_index:
			set_selected_slot(player_selection)
	if Input.is_action_just_pressed("use_item"):
		use_item(selected_slot_index)


func set_selected_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT or selected_slot_index == slot_index:
		return
	selected_slot_index = slot_index
	highlight_selected_slot()


func highlight_selected_slot() -> void:
	_apply_biome_weights()


func use_item(hotbar_index: int) -> void:
	var inv_index := inv.slots.size() - SLOT_COUNT + hotbar_index
	if inv_index < 0 or inv_index >= inv.slots.size():
		return
	var slot: InvSlot = inv.slots[inv_index]
	if slot != null and slot.item:
		print("Benutze", slot.item.name)
		# Item effects remain owned by the existing player/inventory systems.
