extends Control

const FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const ItemRegistry := preload("res://Scripts/item_registry.gd")
const CraftingCatalog := preload("res://Scripts/crafting_catalog.gd")
const UI_ROOT_BG := Color(0.08, 0.1, 0.16, 0.96)
const UI_SECTION_BG := Color(0.05, 0.08, 0.12, 0.94)
const UI_SECTION_BG_ALT := Color(0.08, 0.12, 0.09, 0.94)
const UI_BORDER := Color(0.35, 0.92, 0.7, 1.0)
const UI_BORDER_SOFT := Color(0.2, 0.33, 0.4, 1.0)
const UI_OUTLINE := Color(0.01, 0.02, 0.05, 1.0)
const UI_TEXT := Color(0.9, 0.98, 0.94, 1.0)
const UI_TEXT_MUTED := Color(0.65, 0.8, 0.76, 1.0)
const CAVE_INVENTORY_PANEL := preload("res://Assets/UI/Inventory/cave_panel.png")
const LUSH_INVENTORY_PANEL := preload("res://Assets/UI/Inventory/lush_panel.png")

@export var slot_scene: PackedScene

var inv: Inv = preload("res://InventorySystem/playerinv.tres")
@onready var backdrop: ColorRect = $Backdrop
@onready var root_panel: PanelContainer = $Frame/RootPanel
@onready var preview_panel: PanelContainer = $Frame/RootPanel/ContentMargin/ContentRow/LeftColumn/PreviewPanel
@onready var equipment_panel: PanelContainer = $Frame/RootPanel/ContentMargin/ContentRow/LeftColumn/EquipmentPanel
@onready var bag_panel: PanelContainer = $Frame/RootPanel/ContentMargin/ContentRow/RightColumn/BagPanel
@onready var hotbar_panel: PanelContainer = $Frame/RootPanel/ContentMargin/ContentRow/RightColumn/HotbarPanel
@onready var right_column: VBoxContainer = $Frame/RootPanel/ContentMargin/ContentRow/RightColumn
@onready var bag_grid: GridContainer = $Frame/RootPanel/ContentMargin/ContentRow/RightColumn/BagPanel/BagMargin/BagContent/BagScroll/BagGrid
@onready var hotbar_grid: GridContainer = $Frame/RootPanel/ContentMargin/ContentRow/RightColumn/HotbarPanel/HotbarMargin/HotbarContent/HotbarGrid
@onready var equipment_slots_row: HBoxContainer = $Frame/RootPanel/ContentMargin/ContentRow/LeftColumn/EquipmentPanel/EquipmentMargin/EquipmentContent/EquipmentSlots
@onready var player_preview: Control = $Frame/RootPanel/ContentMargin/ContentRow/LeftColumn/PreviewPanel/PreviewMargin/PreviewContent/PlayerPreview
@onready var tooltip = preload("res://InventorySystem/Tooltip.tscn").instantiate()

var is_open := false
var save_path := "user://inventory.save"
var cached_font: FontFile
var inventory_slot_nodes: Array[Control] = []
var hotbar_slot_nodes: Array[Control] = []
var equipment_slot_nodes: Dictionary = {}
var slot_lookup: Dictionary = {}
var dragging_origin: Dictionary = {}
var dragging_item: Control = null
var dragging_slot_ref: Dictionary = {}
var hovered_slot_ref: Dictionary = {}
var biome_panel_skins: Array[Dictionary] = []
var craft_slots: Array[InvSlot] = []
var craft_slot_nodes: Array[Control] = []
var craft_result_slot := InvSlot.new()
var craft_result_node: Control
var craft_result_label: Label
var craft_button: Button
var crafting_panel: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	if slot_scene == null:
		slot_scene = preload("res://InventorySystem/slot.tscn")

	_apply_styles()
	_build_biome_skin()
	_build_slot_views()
	_build_crafting_panel()
	add_to_group("biome_aware_ui")

	inv.update.connect(update_slots)
	inv.load_inventory(save_path)
	update_slots()
	close()

	add_child(tooltip)
	tooltip.visible = false


func _exit_tree() -> void:
	remove_from_group("biome_aware_ui")


## Receives the exact same eased strength as cave/lush parallax and hotbar.
func set_biome_weight(theme_id: String, weight: float) -> void:
	if theme_id != "lush":
		return
	var blend := clampf(weight, 0.0, 1.0)
	for skin_pair in biome_panel_skins:
		(skin_pair["cave"] as TextureRect).modulate.a = 1.0 - blend
		(skin_pair["lush"] as TextureRect).modulate.a = blend


func _build_biome_skin() -> void:
	# Build each functional region separately.  Unlike the previous backdrop,
	# no pre-composed inventory sheet sits behind the controls: every panel and
	# every slot owns an isolated cave/lush pixel asset.
	var panels: Array[PanelContainer] = [preview_panel, equipment_panel, bag_panel, hotbar_panel]
	for panel: PanelContainer in panels:
		var cave_skin := _create_biome_panel(CAVE_INVENTORY_PANEL, "CaveSkin")
		var lush_skin := _create_biome_panel(LUSH_INVENTORY_PANEL, "LushSkin")
		panel.add_child(cave_skin)
		panel.add_child(lush_skin)
		panel.move_child(cave_skin, 0)
		panel.move_child(lush_skin, 1)
		lush_skin.modulate.a = 0.0
		biome_panel_skins.append({"cave": cave_skin, "lush": lush_skin})


func _create_biome_panel(texture: Texture2D, node_name: String) -> TextureRect:
	var skin := TextureRect.new()
	skin.name = node_name
	skin.texture = texture
	skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skin.stretch_mode = TextureRect.STRETCH_SCALE
	skin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin.z_index = -1
	return skin


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		if is_open:
			close()
		else:
			open()

	if not is_open:
		return

	hovered_slot_ref = _get_slot_ref_under_mouse()
	_update_tooltip()

	if dragging_item:
		dragging_item.position = get_global_mouse_position()

	if Input.is_action_just_pressed("Attack"):
		if dragging_origin.is_empty():
			_start_drag(hovered_slot_ref)
		else:
			_complete_drag(hovered_slot_ref)

	if Input.is_action_just_pressed("mouse_right"):
		_handle_right_click(hovered_slot_ref)


func open() -> void:
	visible = true
	is_open = true
	update_slots()


func close() -> void:
	_return_crafting_ingredients()
	visible = false
	is_open = false
	tooltip.hide_tooltip()
	_cancel_drag()
	inv.save_inventory(save_path)


func update_slots() -> void:
	for i in range(27):
		inventory_slot_nodes[i].call("update", inv.slots[i])

	for i in range(9):
		hotbar_slot_nodes[i].call("update", inv.slots[27 + i])

	for slot_name in inv.get_equipment_slot_names():
		if equipment_slot_nodes.has(slot_name):
			var equip_slot := inv.get_equipped_slot(slot_name)
			equipment_slot_nodes[slot_name].call("update", equip_slot)

	for index in range(craft_slot_nodes.size()):
		craft_slot_nodes[index].call("update", craft_slots[index])
	_update_crafting_result()

	var weapon_item := inv.get_equipped_item("weapon")
	if player_preview and player_preview.has_method("set_preview_item"):
		player_preview.call("set_preview_item", weapon_item if weapon_item else ItemRegistry.get_default_weapon())
		var player := get_tree().get_first_node_in_group("players")
		var hero_form_active := player != null and bool(player.get("is_hero_form_active"))
		if player_preview.has_method("set_hero_form_active"):
			player_preview.call("set_hero_form_active", hero_form_active)


func _build_slot_views() -> void:
	inventory_slot_nodes.clear()
	hotbar_slot_nodes.clear()
	equipment_slot_nodes.clear()
	slot_lookup.clear()

	for child in bag_grid.get_children():
		child.queue_free()
	for child in hotbar_grid.get_children():
		child.queue_free()
	for child in equipment_slots_row.get_children():
		child.queue_free()

	for index in range(27):
		var slot := _create_slot_instance()
		bag_grid.add_child(slot)
		inventory_slot_nodes.append(slot)
		slot_lookup[slot] = {"kind": "inventory", "index": index}

	for hotbar_index in range(9):
		var slot := _create_slot_instance()
		hotbar_grid.add_child(slot)
		hotbar_slot_nodes.append(slot)
		slot_lookup[slot] = {"kind": "inventory", "index": 27 + hotbar_index}

	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 10)
	equipment_slots_row.add_child(sections)

	for layout_group in inv.get_equipment_layout():
		var section := VBoxContainer.new()
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section.add_theme_constant_override("separation", 6)
		sections.add_child(section)

		var label := Label.new()
		label.text = String(layout_group.get("title", "Equipment")).to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_label(label, 12, UI_TEXT_MUTED, 2)
		section.add_child(label)

		var slot_row := HBoxContainer.new()
		slot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		slot_row.add_theme_constant_override("separation", 8)
		section.add_child(slot_row)

		var slot_names: Array = layout_group.get("slots", [])
		for slot_name_variant in slot_names:
			var slot_name := String(slot_name_variant)
			var slot := _create_slot_instance()
			slot_row.add_child(slot)
			equipment_slot_nodes[slot_name] = slot
			slot_lookup[slot] = {"kind": "equipment", "slot_name": slot_name}


func _build_crafting_panel() -> void:
	craft_slots.clear()
	craft_slot_nodes.clear()
	for _index in range(9):
		var crafting_slot := InvSlot.new()
		crafting_slot.amount = 0
		craft_slots.append(crafting_slot)

	crafting_panel = PanelContainer.new()
	crafting_panel.name = "CraftingPanel"
	crafting_panel.add_theme_stylebox_override("panel", _make_flat_style(Color(0.0, 0.0, 0.0, 0.0), Color.TRANSPARENT, 0, 0, 0))
	right_column.add_child(crafting_panel)
	right_column.move_child(crafting_panel, hotbar_panel.get_index())
	var cave_skin := _create_biome_panel(CAVE_INVENTORY_PANEL, "CaveSkin")
	var lush_skin := _create_biome_panel(LUSH_INVENTORY_PANEL, "LushSkin")
	crafting_panel.add_child(cave_skin)
	crafting_panel.add_child(lush_skin)
	crafting_panel.move_child(cave_skin, 0)
	crafting_panel.move_child(lush_skin, 1)
	lush_skin.modulate.a = 0.0
	biome_panel_skins.append({"cave": cave_skin, "lush": lush_skin})

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	crafting_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	var title := Label.new()
	title.text = "3×3 HANDWERK"
	_style_label(title, 15, UI_TEXT, 2)
	content.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	row.add_child(grid)
	for index in range(9):
		var slot := _create_slot_instance()
		slot.custom_minimum_size = Vector2(44.0, 44.0)
		grid.add_child(slot)
		craft_slot_nodes.append(slot)
		slot_lookup[slot] = {"kind": "craft", "index": index}

	var output := VBoxContainer.new()
	output.add_theme_constant_override("separation", 3)
	row.add_child(output)
	var result_title := Label.new()
	result_title.text = "ERGEBNIS"
	_style_label(result_title, 11, UI_TEXT_MUTED, 2)
	output.add_child(result_title)
	craft_result_node = _create_slot_instance()
	craft_result_node.custom_minimum_size = Vector2(52.0, 52.0)
	craft_result_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output.add_child(craft_result_node)
	craft_result_label = Label.new()
	craft_result_label.custom_minimum_size = Vector2(112.0, 20.0)
	craft_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(craft_result_label, 10, UI_TEXT_MUTED, 1)
	output.add_child(craft_result_label)
	craft_button = Button.new()
	craft_button.text = "HERSTELLEN"
	craft_button.disabled = true
	craft_button.pressed.connect(_craft_current_recipe)
	output.add_child(craft_button)


func _update_crafting_result() -> void:
	if craft_result_node == null:
		return
	var recipe := CraftingCatalog.find_recipe(craft_slots)
	var result := CraftingCatalog.get_result(recipe)
	craft_result_slot.item = result
	craft_result_slot.amount = 1 if result else 0
	craft_result_node.call("update", craft_result_slot)
	if result:
		craft_result_label.text = "%s\nKlick: herstellen" % result.get_display_name()
		craft_button.disabled = not inv.can_insert(result)
	else:
		craft_result_label.text = "Muster einsetzen"
		craft_button.disabled = true


func _create_slot_instance() -> Control:
	var slot := slot_scene.instantiate() as Control
	slot.custom_minimum_size = Vector2(56.0, 56.0)
	return slot


func _start_drag(slot_ref: Dictionary) -> void:
	if slot_ref.is_empty():
		return
	var slot := _resolve_slot(slot_ref)
	if slot == null or slot.item == null:
		return

	dragging_origin = slot_ref.duplicate(true)
	dragging_slot_ref = slot_ref.duplicate(true)
	dragging_item = _create_dragging_item(slot.item)
	update_slots()


func _complete_drag(target_ref: Dictionary) -> void:
	if dragging_origin.is_empty():
		return

	if target_ref.is_empty():
		_cancel_drag()
		return

	if not _can_drop_into(dragging_origin, target_ref):
		_cancel_drag()
		return

	var source_kind := String(dragging_origin.get("kind", ""))
	var target_kind := String(target_ref.get("kind", ""))

	if source_kind == "inventory" and target_kind == "inventory":
		inv.swap_slots(int(dragging_origin.get("index", -1)), int(target_ref.get("index", -1)))
	elif source_kind == "inventory" and target_kind == "craft":
		_move_one_from_inventory_to_craft(int(dragging_origin.get("index", -1)), int(target_ref.get("index", -1)))
	elif source_kind == "craft" and target_kind == "inventory":
		_move_one_from_craft_to_inventory(int(dragging_origin.get("index", -1)))
	elif source_kind == "craft" and target_kind == "craft":
		_swap_crafting_slots(int(dragging_origin.get("index", -1)), int(target_ref.get("index", -1)))
	elif source_kind == "inventory" and target_kind == "equipment":
		inv.swap_inventory_with_equipment(int(dragging_origin.get("index", -1)), String(target_ref.get("slot_name", "")))
	elif source_kind == "equipment" and target_kind == "inventory":
		inv.swap_inventory_with_equipment(int(target_ref.get("index", -1)), String(dragging_origin.get("slot_name", "")))

	_cancel_drag()
	update_slots()


func _handle_right_click(slot_ref: Dictionary) -> void:
	if slot_ref.is_empty():
		return

	match String(slot_ref.get("kind", "")):
		"inventory":
			var index := int(slot_ref.get("index", -1))
			if index >= 0 and index < inv.slots.size():
				var item := inv.slots[index].item
				if item and item.equip_slot != "none":
					inv.equip_from_inventory(index)
		"equipment":
			inv.unequip_to_inventory(String(slot_ref.get("slot_name", "")))


func _can_drop_into(source_ref: Dictionary, target_ref: Dictionary) -> bool:
	if source_ref == target_ref:
		return true

	var source_slot := _resolve_slot(source_ref)
	var target_slot := _resolve_slot(target_ref)
	if source_slot == null or source_slot.item == null or target_slot == null:
		return false

	var source_kind := String(source_ref.get("kind", ""))
	var target_kind := String(target_ref.get("kind", ""))

	if source_kind == "inventory" and target_kind == "equipment":
		return inv.can_equip_item(source_slot.item, String(target_ref.get("slot_name", "")))
	if source_kind == "equipment" and target_kind == "inventory":
		return true
	if source_kind == "inventory" and target_kind == "inventory":
		return true
	if source_kind == "inventory" and target_kind == "craft":
		return target_slot.item == null
	if source_kind == "craft" and target_kind == "inventory":
		return inv.can_insert(source_slot.item)
	if source_kind == "craft" and target_kind == "craft":
		return true
	return false


func _resolve_slot(slot_ref: Dictionary) -> InvSlot:
	if slot_ref.is_empty():
		return null

	match String(slot_ref.get("kind", "")):
		"inventory":
			var index := int(slot_ref.get("index", -1))
			if index >= 0 and index < inv.slots.size():
				return inv.slots[index]
		"equipment":
			return inv.get_equipped_slot(String(slot_ref.get("slot_name", "")))
		"craft":
			var index := int(slot_ref.get("index", -1))
			if index >= 0 and index < craft_slots.size():
				return craft_slots[index]
	return null


func _move_one_from_inventory_to_craft(inventory_index: int, craft_index: int) -> void:
	if inventory_index < 0 or inventory_index >= inv.slots.size() or craft_index < 0 or craft_index >= craft_slots.size():
		return
	var source := inv.slots[inventory_index]
	var target := craft_slots[craft_index]
	if source.item == null or target.item != null:
		return
	target.item = source.item
	target.amount = 1
	source.amount -= 1
	if source.amount <= 0:
		source.item = null
		source.amount = 0
	inv.notify_changed()


func _move_one_from_craft_to_inventory(craft_index: int) -> void:
	if craft_index < 0 or craft_index >= craft_slots.size():
		return
	var source := craft_slots[craft_index]
	if source.item == null:
		return
	if inv.Insert(source.item):
		source.item = null
		source.amount = 0


func _swap_crafting_slots(first_index: int, second_index: int) -> void:
	if first_index < 0 or first_index >= craft_slots.size() or second_index < 0 or second_index >= craft_slots.size():
		return
	var first := craft_slots[first_index]
	var second := craft_slots[second_index]
	var item := first.item
	first.item = second.item
	second.item = item
	first.amount = 1 if first.item else 0
	second.amount = 1 if second.item else 0
	update_slots()


func _craft_current_recipe() -> void:
	var recipe := CraftingCatalog.find_recipe(craft_slots)
	var result := CraftingCatalog.get_result(recipe)
	if result == null:
		return
	if not inv.can_insert(result):
		_show_inventory_toast("Kein freier Platz fuer das Ergebnis.", "error")
		return
	for slot in craft_slots:
		slot.item = null
		slot.amount = 0
	if inv.Insert(result):
		_show_inventory_toast("Hergestellt: %s" % result.get_display_name(), "reward")
	update_slots()


func _return_crafting_ingredients() -> void:
	for slot in craft_slots:
		if slot.item and inv.Insert(slot.item):
			slot.item = null
			slot.amount = 0


func _show_inventory_toast(message: String, toast_type: String) -> void:
	var player := get_tree().get_first_node_in_group("players")
	if player and player.has_method("_show_feedback_toast"):
		player.call("_show_feedback_toast", message, toast_type)


func _get_slot_ref_under_mouse() -> Dictionary:
	var pointer := get_global_mouse_position()
	for node in slot_lookup.keys():
		var control := node as Control
		if control and control.get_global_rect().has_point(pointer):
			return (slot_lookup[node] as Dictionary).duplicate(true)
	return {}


func _update_tooltip() -> void:
	if not is_open or dragging_item:
		tooltip.hide_tooltip()
		return
	if hovered_slot_ref.is_empty():
		tooltip.hide_tooltip()
		return

	var slot := _resolve_slot(hovered_slot_ref)
	if slot == null or slot.item == null:
		tooltip.hide_tooltip()
		return
	tooltip.show_tooltip(slot.item, get_global_mouse_position())


func _cancel_drag() -> void:
	if dragging_item:
		dragging_item.queue_free()
	dragging_item = null
	dragging_origin.clear()
	dragging_slot_ref.clear()
	update_slots()


func _create_dragging_item(item: InvItem) -> Control:
	var drag_item := Control.new()
	var sprite := Sprite2D.new()
	var display_texture := _get_item_display_texture(item)
	sprite.texture = display_texture
	var texture_size := display_texture.get_size() if display_texture else Vector2.ONE
	var scale_factor := 44.0 / maxf(texture_size.x, texture_size.y)
	sprite.scale = Vector2.ONE * scale_factor
	drag_item.add_child(sprite)
	get_parent().add_child(drag_item)
	drag_item.position = get_global_mouse_position()
	return drag_item


func _get_item_display_texture(item: InvItem) -> Texture2D:
	if item.world_texture_region.has_area():
		var cropped := AtlasTexture.new()
		cropped.atlas = item.texture
		cropped.region = item.world_texture_region
		return cropped
	return item.texture


func _apply_styles() -> void:
	backdrop.color = Color(0.0, 0.0, 0.0, 0.76)
	# The supplied pixel-art sheets provide the visible frame. Containers keep
	# their layout and interaction behavior, but no longer paint a competing
	# flat card on top of it.
	root_panel.add_theme_stylebox_override("panel", _make_flat_style(Color(0.0, 0.0, 0.0, 0.0), Color.TRANSPARENT, 0, 0, 0))
	preview_panel.add_theme_stylebox_override("panel", _make_flat_style(Color(0.0, 0.0, 0.0, 0.0), Color.TRANSPARENT, 0, 0, 0))
	equipment_panel.add_theme_stylebox_override("panel", _make_flat_style(Color(0.0, 0.0, 0.0, 0.0), Color.TRANSPARENT, 0, 0, 0))
	bag_panel.add_theme_stylebox_override("panel", _make_flat_style(Color(0.0, 0.0, 0.0, 0.0), Color.TRANSPARENT, 0, 0, 0))
	hotbar_panel.add_theme_stylebox_override("panel", _make_flat_style(Color(0.0, 0.0, 0.0, 0.0), Color.TRANSPARENT, 0, 0, 0))


func _style_label(label: Label, font_size: int, color: Color, outline_size: int) -> void:
	label.add_theme_font_override("font", _load_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", UI_OUTLINE)
	label.add_theme_constant_override("outline_size", outline_size)


func _load_font() -> FontFile:
	if cached_font == null:
		cached_font = load(FONT_PATH) as FontFile
	return cached_font


func _make_flat_style(bg: Color, border: Color, border_width: int, radius: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_detail = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = shadow_size
	return style
