extends Control

## Pixel-art hotbar with biome-aware skins. A world biome only has to call
## `set_biome_weight("lush", value)` on the `biome_aware_ui` group; further
## themes can be registered in BIOME_THEMES without touching item-slot logic.

const SLOT_COUNT := 9
const HOTBAR_SIZE := Vector2(680.0, 132.0)
# The source frames are deliberately very large.  The HUD uses a compact
# presentation frame, while slot faces retain their own authored size.
const SLOT_FACE_SCALE := 0.76
const SLOT_PITCH := 57.0
const SLOT_CENTER_Y := 52.0
const FRAME_SIZE := Vector2(590.0, 116.0)
const FRAME_POSITION := Vector2((HOTBAR_SIZE.x - FRAME_SIZE.x) * 0.5, 7.0)
const ITEM_ICON_MAX_SIZE := 39.0
const HOTBAR_FONT := preload("res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf")
const BIOME_THEMES := {
	"cave": {
		"bar": preload("res://Assets/UI/Hotbar/cave_frame.png"),
		"inactive": preload("res://Assets/UI/Hotbar/cave_slot_inactive.png"),
		"active": preload("res://Assets/UI/Hotbar/cave_slot_active.png"),
	},
	"lush": {
		"bar": preload("res://Assets/UI/Hotbar/lush_frame.png"),
		"inactive": preload("res://Assets/UI/Hotbar/lush_slot_inactive.png"),
		"active": preload("res://Assets/UI/Hotbar/lush_slot_active.png"),
	},
}

@onready var inv: Inv = preload("res://InventorySystem/playerinv.tres")

var selected_slot_index := 0
var _theme_nodes: Dictionary = {}
var _item_icons: Array[Sprite2D] = []
var _amount_labels: Array[Label] = []
var _icon_content_rect_cache: Dictionary = {}
var _biome_weights := {"cave": 1.0, "lush": 0.0}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("biome_aware_ui")
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
		var theme_root := Control.new()
		theme_root.name = "%sTheme" % theme_id.capitalize()
		theme_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		theme_root.size = HOTBAR_SIZE
		theme_root.z_index = 1
		add_child(theme_root)

		var bar := _create_frame(definition["bar"] as Texture2D)
		bar.name = "Frame"
		theme_root.add_child(bar)

		var inactive_slots: Array[TextureRect] = []
		var active_slots: Array[TextureRect] = []
		var slot_numbers: Array[Label] = []
		for slot_index in range(SLOT_COUNT):
			var slot_center := _slot_center(slot_index)
			var inactive := _create_slot_face(definition["inactive"] as Texture2D, slot_center)
			inactive.name = "Inactive%d" % (slot_index + 1)
			theme_root.add_child(inactive)
			inactive_slots.append(inactive)

			var active := _create_slot_face(definition["active"] as Texture2D, slot_center)
			active.name = "Active%d" % (slot_index + 1)
			theme_root.add_child(active)
			active_slots.append(active)

			var number := _create_slot_number(slot_index + 1, slot_center, theme_id)
			number.name = "Number%d" % (slot_index + 1)
			theme_root.add_child(number)
			slot_numbers.append(number)

		_theme_nodes[theme_id] = {
			"bar": bar,
			"inactive": inactive_slots,
			"active": active_slots,
			"numbers": slot_numbers,
		}


func _build_item_layers() -> void:
	# Item contents follow the common visual grid. Theme faces may differ by a
	# few source pixels at their decorative edges, but never shift an item icon.
	for slot_index in range(SLOT_COUNT):
		var item_center := _slot_center(slot_index)
		var icon := Sprite2D.new()
		icon.name = "Item%d" % (slot_index + 1)
		# Keep the opaque item centered on the exact center of its slot face.
		icon.position = item_center
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.z_index = 5
		add_child(icon)
		_item_icons.append(icon)

		var amount := Label.new()
		amount.name = "Amount%d" % (slot_index + 1)
		amount.position = item_center + Vector2(1.0, 4.0)
		amount.size = Vector2(24.0, 20.0)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		amount.add_theme_font_size_override("font_size", 17)
		amount.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84, 1.0))
		amount.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 1.0))
		amount.add_theme_constant_override("outline_size", 2)
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


func _create_frame(texture: Texture2D) -> Sprite2D:
	# TextureRect keeps a texture's minimum size in some control-layout paths.
	# A Sprite2D gives the supplied decorative frame one exact on-screen size.
	var frame := Sprite2D.new()
	frame.texture = texture
	frame.position = FRAME_POSITION
	frame.centered = false
	frame.scale = FRAME_SIZE / texture.get_size()
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return frame


func _create_slot_face(texture: Texture2D, center: Vector2) -> TextureRect:
	var face_size := texture.get_size() * SLOT_FACE_SCALE
	var rect := _create_texture_rect(texture, face_size, TextureRect.STRETCH_SCALE)
	rect.position = center - face_size * 0.5
	return rect


func _slot_center(slot_index: int) -> Vector2:
	# Slots deliberately do not inherit the frame scale.  Their fixed grid makes
	# the selected face sit exactly on every inactive face and keeps all nine
	# touch targets comfortably wide.
	var first_center_x := (FRAME_SIZE.x - SLOT_PITCH * float(SLOT_COUNT - 1)) * 0.5
	return FRAME_POSITION + Vector2(first_center_x + SLOT_PITCH * slot_index, SLOT_CENTER_Y)


func _create_slot_number(slot_number: int, center: Vector2, theme_id: String) -> Label:
	var number := Label.new()
	number.text = str(slot_number)
	number.position = center + Vector2(-12.0, 21.0)
	number.size = Vector2(24.0, 17.0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_override("font", HOTBAR_FONT)
	number.add_theme_font_size_override("font_size", 14)
	number.add_theme_color_override("font_color", Color(0.96, 0.93, 0.83, 1.0) if theme_id == "cave" else Color(0.88, 1.0, 0.76, 1.0))
	number.add_theme_color_override("font_outline_color", Color(0.025, 0.035, 0.05, 1.0))
	number.add_theme_constant_override("outline_size", 2)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.z_index = 4
	return number


func _apply_item_icon(icon: Sprite2D, texture: Texture2D) -> void:
	# Several item files contain asymmetric transparent padding. Rendering only
	# their opaque rectangle keeps the visible pixels centered in every slot.
	icon.texture = texture
	if texture == null:
		icon.region_enabled = false
		return

	var content_rect := _get_icon_content_rect(texture)
	icon.region_enabled = true
	icon.region_rect = content_rect
	var longest_side := maxf(content_rect.size.x, content_rect.size.y)
	var icon_scale := ITEM_ICON_MAX_SIZE / longest_side if longest_side > 0.0 else 1.0
	icon.scale = Vector2(icon_scale, icon_scale)


func _get_icon_content_rect(texture: Texture2D) -> Rect2:
	if _icon_content_rect_cache.has(texture):
		return _icon_content_rect_cache[texture] as Rect2

	var fallback := Rect2(Vector2.ZERO, texture.get_size())
	var image := texture.get_image()
	if image == null or image.is_empty():
		_icon_content_rect_cache[texture] = fallback
		return fallback

	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.01:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)

	var content_rect := fallback
	if max_x >= min_x and max_y >= min_y:
		content_rect = Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	_icon_content_rect_cache[texture] = content_rect
	return content_rect


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
		(nodes["bar"] as CanvasItem).modulate.a = weight
		var inactive_slots: Array = nodes["inactive"]
		var active_slots: Array = nodes["active"]
		var slot_numbers: Array = nodes["numbers"]
		for slot_index in range(SLOT_COUNT):
			(inactive_slots[slot_index] as TextureRect).modulate.a = weight if slot_index != selected_slot_index else 0.0
			(active_slots[slot_index] as TextureRect).modulate.a = weight if slot_index == selected_slot_index else 0.0
			(slot_numbers[slot_index] as Label).modulate.a = weight


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
		_apply_item_icon(icon, slot.item.texture if has_item else null)
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
