# 📦 `inventory_ui` – Inventar-Benutzeroberfläche für Godot

Dieses Skript erzeugt eine **dynamische Inventar-Anzeige** mit einem **GridContainer** und verwaltet die Icons sowie die Anzahl der Items.

---

## 📜 Code mit Zeilenweiser Erklärung

### 🏗 1. Ressourcen & Variablen

```gdscript
resource_name = "inventory_ui"
```
Setzt den Namen des Skripts auf `"inventory_ui"`, um es leichter identifizierbar zu machen.

```gdscript
@onready var grid = $NinePatchRect/GridContainer  
@onready var nine_patch = $NinePatchRect  
```
- `grid`: Referenz auf den `GridContainer`, in dem alle Inventarslots liegen.  
- `nine_patch`: Der Hintergrundrahmen (`NinePatchRect`), der das Inventar visuell umgibt.  
- `@onready`: Variablen werden erst gesetzt, wenn die Szene geladen wurde (verhindert `null`-Fehler).

---

### ⚙ 2. Konstante Einstellungen

```gdscript
const SLOT_SIZE = Vector2(80, 80)  
const COLUMNS = 9  
const ROWS = 4  
```
Definiert ein Grid mit **9 Spalten und 4 Reihen** (insgesamt 36 Slots), wobei jeder Slot **80x80 Pixel** groß ist.

```gdscript
const SLOT_TEXTURE = preload("res://Assets/Inventory/slot.png")
```
Lädt das Standardbild für leere Slots.

```gdscript
const PADDING = 50  
const GRID_OFFSET = Vector2(-15, 10)  
```
- `PADDING`: Zusätzlicher Abstand um das gesamte Inventar.  
- `GRID_OFFSET`: Feinanpassung der Grid-Position (leicht nach links & oben).

---

### 🚀 3. `_ready()` – Initialisierung

```gdscript
func _ready():
```
Diese Funktion wird automatisch aufgerufen, wenn die Szene geladen ist.

```gdscript
var grid_size = Vector2(COLUMNS * SLOT_SIZE.x, ROWS * SLOT_SIZE.y)
```
Berechnet die gesamte Größe des Grids basierend auf der Anzahl der Spalten & Reihen.

```gdscript
nine_patch.custom_minimum_size = grid_size + Vector2(PADDING * 2, PADDING * 2)
```
Setzt die Größe des `NinePatchRect`, sodass es groß genug ist, um das Grid plus Padding zu enthalten.

```gdscript
var screen_size = get_viewport_rect().size
nine_patch.position = (screen_size / 2) - (nine_patch.custom_minimum_size / 2)
```
Zentriert den `NinePatchRect` exakt in der Mitte des Bildschirms.

```gdscript
grid.columns = COLUMNS
grid.custom_minimum_size = grid_size
grid.position = (nine_patch.custom_minimum_size / 2) - (grid_size / 2) + GRID_OFFSET  
```
Konfiguriert die Spaltenanzahl des Grids und positioniert es mittig innerhalb des `NinePatchRect`.

```gdscript
generate_empty_slots()
```
Ruft die Funktion auf, um alle leeren Slots zu erstellen.

---

### 🎲 4. `generate_empty_slots()` – Leere Slots erzeugen

```gdscript
func generate_empty_slots():
```
Erstellt das Grid mit leeren Slots.

```gdscript
for child in grid.get_children():
    grid.remove_child(child)
    child.queue_free()
```
Löscht vorhandene Slots, um doppeltes Erstellen zu verhindern.

```gdscript
for i in range(COLUMNS * ROWS):
    var slot = TextureRect.new()
    slot.texture = SLOT_TEXTURE
    slot.custom_minimum_size = SLOT_SIZE
    slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    grid.add_child(slot)
```
Erstellt genau **COLUMNS × ROWS** Slots und setzt deren Standardbild.

---

### 🔄 5. `update_inventory(inventory)` – Inventar aktualisieren

```gdscript
func update_inventory(inventory: Dictionary):
```
Diese Funktion nimmt ein `Dictionary` mit Items und Mengen entgegen und aktualisiert die UI.

```gdscript
for child in grid.get_children():
    child.texture = SLOT_TEXTURE  
```
Setzt alle Slots zurück auf das Standard-Slot-Icon.

```gdscript
for sub_child in child.get_children():
    child.remove_child(sub_child)
    sub_child.queue_free()
```
Löscht vorherige Icons oder Labels.

```gdscript
var index = 0
for item_name in inventory.keys():
    if index < grid.get_child_count():
```
Iteriert durch alle Items im Inventar, solange noch freie Slots existieren.

```gdscript
var item_icon = grid.get_child(index) as TextureRect
var texture_path = "res://Assets/Items/" + item_name + ".png"
```
Findet den passenden Slot und generiert den Pfad zur Item-Textur.

```gdscript
if ResourceLoader.exists(texture_path):
    item_icon.texture = load(texture_path)  
else:
    print("WARNUNG: Icon für " + item_name + " nicht gefunden!")  
    item_icon.modulate = Color(1, 0, 0, 1)
```
Falls das Icon existiert, wird es geladen, andernfalls wird der Slot rot markiert.

```gdscript
var amount_label = Label.new()
amount_label.text = str(inventory[item_name])
amount_label.add_theme_font_size_override("font_size", 20)
amount_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)  
amount_label.position -= Vector2(15, 25)
amount_label.modulate = Color(1, 1, 1, 1)  
item_icon.add_child(amount_label)
```
Erstellt ein neues `Label`, setzt die Anzahl des Items und positioniert es unten rechts im Slot.

```gdscript
index += 1
```
Springt zum nächsten Slot.

---