# Kapitel-Generator: QA-Workflow

`ChapterLayoutBuilder` erzeugt aus Leveldaten und einem deterministischen Seed Räume, Plattformen, Gegner und Sammelobjekte. `ChapterTraversalValidator` prüft die Pflichtprogression mit einem Bewegungsprofil, das direkt aus den Konstanten und der Collider-Größe von `player.gd` / `player.tscn` berechnet wird. Kandidaten mit unerreichbaren Räumen, Rewards oder Sprüngen werden nicht akzeptiert.

Für reproduzierbare Prüfung stehen diese Skripte zur Verfügung:

- `chapter_validate_all_levels.gd`: Laufzeitprüfung aller acht Kapitel-1-Level mit dem realen Player-Body.
- `chapter_validate_multiseed.gd`: Regression über die Seeds `101, 237, 404, 777, 1337, 2024`.
- `chapter_stress_validate.gd`: 10, 100 und 1.000 Layouts; schreibt Zeiten, Versuche, Qualitätswerte und Ablehnungsgründe nach `user://chapter_generation_stress_report.json`.
- `chapter_capture_preview.gd -- --seed=<seed>`: GPU-Render der Spawn-Ansicht.
- `chapter_capture_layout_overview.gd -- --seed=<seed>`: GPU-Render der kompletten Karte samt Traversierungs-/Kollisionsdebugansicht.

Die Capture-Skripte müssen mit einem echten Renderer laufen, beispielsweise:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver opengl3 --audio-driver Dummy --script res://Scripts/Chapter/chapter_capture_preview.gd -- --seed=101
```

Sie aktivieren `chapter_qa_mode`: Joeys reale Physik und Kollisionsform bleiben aktiv, Persistenz, Netzwerk/API-Aufrufe und lokale Spielstände werden aber nicht verändert. Die PNGs liegen unter `user://` und sind manuell auf Kachelversatz, Nähte, Kollision/Visual-Ausrichtung, Spawn, Belohnungen und Raumübergänge zu prüfen.
