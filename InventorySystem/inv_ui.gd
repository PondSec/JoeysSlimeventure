extends Control

const FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const ItemRegistry := preload("res://Scripts/item_registry.gd")
const UI_ROOT_BG := Color(0.08, 0.1, 0.16, 0.96)
const UI_SECTION_BG := Color(0.05, 0.08, 0.12, 0.94)
const UI_SECTION_BG_ALT := Color(0.08, 0.12, 0.09, 0.94)
const UI_BORDER := Color(0.35, 0.92, 0.7, 1.0)
const UI_BORDER_SOFT := Color(0.2, 0.33, 0.4, 1.0)
const UI_OUTLINE := Color(0.01, 0.02, 0.05, 1.0)
const UI_TEXT := Color(0.9, 0.98, 0.94, 1.0)
const UI_TEXT_MUTED := Color(0.65, 0.8, 0.76, 1.0)

@export var slot_scene: PackedScene

var inv: Inv = preload("res://InventorySystem/playerinv.tres")
@onready var backdrop: ColorRect = $Backdrop
@onready var root_panel: PanelContainer = $Frame/RootPanel
@onready var preview_panel: PanelContainer = $Frame/RootPanel/ContentMargin/ContentRow/LeftColumn/PreviewPanel
@onready var equipment_panel: PanelContainer = $Frame/RootPanel/ContentMargin/ContentRow/LeftColumn/EquipmentPanel
@onready var bag_panel: PanelContainer = $Frame/RootPanel/ContentMargin/ContentRow/RightColumn/BagPanel
@onready var hotbar_panel: PanelContainer = $Frame/RootPanel/ContentMargin/ContentRow/RightColumn/HotbarPanel
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	if slot_scene == null:
		slot_scene = preload("res://InventorySystem/slot.tscn")

	_apply_styles()
	_build_slot_views()

	inv.update.connect(update_slots)
	inv.load_inventory(save_path)
	update_slots()
	close()

	add_child(tooltip)
	tooltip.visible = false


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

	var weapon_item := inv.get_equipped_item("weapon")
	if player_preview and player_preview.has_method("set_preview_item"):
		player_preview.call("set_preview_item", weapon_item if weapon_item else ItemRegistry.get_default_weapon())


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
	return null


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
	sprite.texture = item.texture
	sprite.scale = Vector2(1.75, 1.75)
	drag_item.add_child(sprite)
	get_parent().add_child(drag_item)
	drag_item.position = get_global_mouse_position()
	return drag_item


func _apply_styles() -> void:
	backdrop.color = Color(0.0, 0.0, 0.0, 0.76)
	root_panel.add_theme_stylebox_override("panel", _make_flat_style(UI_ROOT_BG, UI_BORDER_SOFT.lightened(0.15), 4, 8, 14))
	preview_panel.add_theme_stylebox_override("panel", _make_flat_style(UI_SECTION_BG, UI_BORDER, 2, 6, 6))
	equipment_panel.add_theme_stylebox_override("panel", _make_flat_style(UI_SECTION_BG_ALT, UI_BORDER_SOFT.lightened(0.08), 2, 6, 6))
	bag_panel.add_theme_stylebox_override("panel", _make_flat_style(UI_SECTION_BG, UI_BORDER_SOFT, 2, 6, 6))
	hotbar_panel.add_theme_stylebox_override("panel", _make_flat_style(UI_SECTION_BG_ALT, UI_BORDER_SOFT, 2, 6, 6))


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
