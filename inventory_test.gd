extends Control

@onready var grid = $NinePatchRect/GridContainer  # Referenz auf das Grid
@onready var nine_patch = $NinePatchRect  # Referenz auf NinePatchRect

const SLOT_SIZE = Vector2(80, 80)  # Größe eines Slots
const COLUMNS = 9  # Anzahl der Spalten
const ROWS = 4  # Anzahl der Reihen
const SLOT_TEXTURE = preload("res://Assets/Inventory/slot.png")  # Slot-Hintergrundtextur
const PADDING = 50  # Abstand um das Inventar
const GRID_OFFSET = Vector2(-15, 10)  # Feinanpassung der Position des Grids

var inventory = []  # Speichert Items als Liste (Array)
var dragging_item = null  # Das Item, das gezogen wird (Kopie des Icons)
var dragging_from_index = -1  # Welcher Slot gezogen wird

func _ready():
    generate_empty_slots()
    update_inventory()

func _input(event):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                start_drag()
            else:
                stop_drag()

    if dragging_item:
        dragging_item.global_position = get_global_mouse_position() - (dragging_item.size / 2)

# --- Startet das Ziehen eines Items ---
func start_drag():
    var mouse_pos = get_global_mouse_position()

    for i in range(COLUMNS * ROWS):
        var slot = grid.get_child(i)
        if slot.get_global_rect().has_point(mouse_pos) and inventory[i] != null:
            dragging_item = TextureRect.new()
            dragging_item.texture = slot.texture
            dragging_item.custom_minimum_size = slot.custom_minimum_size
            dragging_item.stretch_mode = slot.stretch_mode
            add_child(dragging_item)
            dragging_from_index = i
            return

# --- Stoppt das Ziehen und setzt das Item in den neuen Slot ---
func stop_drag():
    if dragging_item:
        var mouse_pos = get_global_mouse_position()

        for i in range(COLUMNS * ROWS):
            var slot = grid.get_child(i)
            if slot.get_global_rect().has_point(mouse_pos):
                swap_items(dragging_from_index, i)
                break

        dragging_item.queue_free()
        dragging_item = null
        dragging_from_index = -1

# --- Tauscht zwei Slots im Inventar ---
func swap_items(from_index: int, to_index: int):
    if from_index != to_index:
        var temp = inventory[from_index]
        inventory[from_index] = inventory[to_index]
        inventory[to_index] = temp
        update_inventory()

# --- Erstelle die leeren Slots im Grid ---
func generate_empty_slots():
    inventory.resize(COLUMNS * ROWS)  # Setzt die Inventargröße fest

    for child in grid.get_children():
        child.queue_free()

    for i in range(COLUMNS * ROWS):
        var slot = TextureRect.new()
        slot.texture = SLOT_TEXTURE
        slot.custom_minimum_size = SLOT_SIZE
        slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        grid.add_child(slot)

# --- Aktualisiert die Slots mit den Items ---
func update_inventory():
    for i in range(COLUMNS * ROWS):
        var slot = grid.get_child(i) as TextureRect
        if inventory[i] != null:
            var texture_path = "res://Assets/Items/" + inventory[i] + ".png"
            if ResourceLoader.exists(texture_path):
                slot.texture = load(texture_path)
        else:
            slot.texture = SLOT_TEXTURE
