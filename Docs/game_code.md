# Dokumentation: game.gd

## Beschreibung
`game.gd` ist ein zentraler Skriptknoten in der Spielszene, der für die Verwaltung des Pausenmenüs und den Szenenwechsel zum Hauptmenü verantwortlich ist.

---

## Variablen

### `@onready var pause_menu = $PauseMenu`
- Referenziert das Pausenmenü-UI in der Szene.
- Wird verwendet, um das Menü zu steuern und anzuzeigen.

---

## Methoden

### `_input(event: InputEvent) -> void`
- Wird bei jeder Eingabe aufgerufen.
- Wenn die "Pause"-Taste gedrückt wird (standardmäßig `ESC`), wird die Methode `toggle_pause()` des `pause_menu`-Nodes aufgerufen.

```gdscript
func _input(event):
    if event.is_action_pressed("Pause"):  # Standardmäßig ESC
        pause_menu.toggle_pause()
```

### `_on_pause_menu_go_to_main_menu() -> void`
- Wird aufgerufen, wenn der Spieler das Hauptmenü über das Pausenmenü auswählt.
- Hebt die Spielpause auf.
- Entfernt die aktuelle Szene und das Pausenmenü.
- Lädt und instanziiert die `main_menu.tscn`-Szene.
- Falls die Szene nicht geladen werden kann, wird eine Fehlermeldung in der Konsole ausgegeben.

```gdscript
func _on_pause_menu_go_to_main_menu() -> void:
    # Pausierung aufheben, bevor wir Szenen entfernen
    get_tree().paused = false

    # Entferne die aktuelle Szene
    var current_scene = get_tree().current_scene
    if current_scene != null:
        current_scene.queue_free()

    # Entferne das Pausenmenü
    var pause_menu_instance = pause_menu.get_parent()
    if pause_menu_instance != null:
        pause_menu_instance.queue_free()

    # Lade das Hauptmenü
    var main_menu_scene = load("res://Scenes/main_menu.tscn")
    if main_menu_scene == null:
        print("Fehler: Die MainMenu-Szene konnte nicht geladen werden.")
        return

    # Instanziiere und setze das Hauptmenü als neue Szene
    var scene_instance = main_menu_scene.instantiate()
    get_tree().root.add_child(scene_instance)
    get_tree().current_scene = scene_instance
```

---

## Zusammenfassung
Dieses Skript ermöglicht eine reibungslose Handhabung des Pausenmenüs und sorgt für einen korrekten Übergang zum Hauptmenü, indem es die aktuellen Szenen entfernt und die Hauptmenüszene lädt. Es stellt sicher, dass die Spielpause ordnungsgemäß aufgehoben wird und verhindert potenzielle Fehler durch eine Prüfung, ob die Szene erfolgreich geladen wurde.

