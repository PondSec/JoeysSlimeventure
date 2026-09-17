# Repository structure

The project is organised by runtime responsibility. Godot content stays in its
existing, stable runtime roots; support material is excluded from Godot import
with `.gdignore` files.

- `Assets/` – game-ready art, audio and data. Enemy art lives in
  `Assets/Enemies/<enemy_name>/`.
- `Scenes/` – reusable gameplay scenes and level composition.
- `Scripts/` – gameplay, UI and world logic, grouped with their scene feature.
- `Shaders/`, `Resource/`, `InventorySystem/` – focused runtime systems.
- `Docs/` – project documentation, release notes and the offline wiki.
- `marketing/` – brand, press and Steam materials; never imported by Godot.
- `tools/` – deterministic local maintenance/build utilities; never imported by
  Godot.
- `joeyslime.com/` – website source; never imported by Godot.

## Conventions

- New paths use lowercase `snake_case`; preserve established asset filenames
  only when third-party source material or existing Godot resources require it.
- Add a new enemy as one feature folder under `Assets/Enemies/` and its scene
  and script under `Scenes/Chapter/Enemies/` and `Scripts/Chapter/Enemies/`.
- Keep source assets and their runtime `.import` metadata in version control.
  Never commit `.godot/` or other generated editor cache directories.
- Generated release builds, local preview exports and OS/editor clutter are
  ignored. Source archives are retained only when they are the licence-bearing
  original for a runtime asset.
