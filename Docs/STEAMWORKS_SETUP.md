# Steamworks integration

## Scope

- Steam AppID: `4536840`
- Godot project: Godot `4.7` (project feature set), validated locally with Godot `4.7.stable`.
- GodotSteam target: `v4.22.1` (Godot 4.7.2-compatible release, Steamworks SDK 1.65).

The repository deliberately contains no GodotSteam binary. GodotSteam is a custom
Godot editor/export-template build, not a GDScript addon. Install the matching
GodotSteam editor and the Windows, Linux and macOS export templates from the
official GodotSteam release before making Steam builds. The game detects the
`Steam` Engine singleton at runtime. A standard Godot editor, an Editor launch,
offline Steam, or an initialization failure therefore leaves gameplay running
without Steam features.

## Runtime architecture

`SaveService`, `CombatEvents`, and `SteamManager` are early autoloads, in that
order.

- `SaveService` owns the versioned, atomic local save layout and old-save
  migration.
- `CombatEvents` is the single player-caused enemy-death boundary. It marks
  player damage immediately before the existing damage calls, reports a real
  death only from an enemy's existing death path, deduplicates the instance,
  and increments `statistics.enemies_defeated`.
- `SteamManager` owns initialization, callbacks, user/stats state, unlocks,
  errors and Steam logging. No scene or enemy calls Steam directly.

The public achievement interface is:

```gdscript
SteamManager.unlock("ACH_FIRST_KILL")
```

Unlock requests are idempotent. When Steam is available, the manager calls
`setAchievement` and then `storeStats`. When it is unavailable, the request is
recorded in the local manifest and retried on a later successful Steam start;
Steam UserStats remains the account authority for unlocked achievements.

Expected log examples:

```text
[Steam] Initialized successfully
[Steam] Logged in as: <persona>
[Steam] Achievement unlocked: ACH_FIRST_KILL
[Steam] Stats stored successfully
```

## Achievements

| Steam API name | Display name | Description | Trigger |
| --- | --- | --- | --- |
| `ACH_INTO_THE_DEPTHS` | Into the Depths | Enter the caves for the first time. | `Scripts/Chapter/chapter_level.gd`, after the player has actually been placed in Chapter 1, Level 1 (the first real cave). |
| `ACH_FIRST_KILL` | First Kill | Defeat your first enemy. | `CombatEvents.enemy_defeated`, emitted only by an existing enemy death routine after player-owned damage. |
| `ACH_WISP_HUNTER` | Wisp Hunter | Defeat 10 Wisp Beetles. | `SteamManager`, after `CombatEvents.enemy_defeated` reports ten player-caused deaths whose `chapter_enemy_type` is `irrlichtkaefer`. It synchronizes `STAT_WISP_BEETLES_KILLED` and unlocks at 10. |
| `ACH_BELL_RINGER` | Bell Ringer | Activate a Resonance Bell. | `ChapterQuestRuntime`, when the player correctly activates a Chapter I Level 2 resonance bell. |
| `ACH_MOONFLOWER_BLOOM` | Moonflower Bloom | Open a Moonflower. | `ChapterQuestRuntime`, when the player pollinates the first Chapter I moonbloom. |
| `ACH_CHAPTER_ONE_CLEAR` | Chapter One Clear | Complete Chapter 1. | `ChapterProgress`, after the final Chapter I level and boss exit complete. |
| `ACH_ENTER_PVP` | Into the Arena | Enter a PvP match for the first time. | `multiplayer_world`, only after room allocation and avatar replication have completed on the joining client. |
| `ACH_ENTER_EMBER_DIMENSION` | Into the Ember Dimension | Enter the Ember Dimension for the first time. | `glut_dimension`, immediately after the player enters the Glutdimension scene. |

All achievement definitions are client-triggered and use the same
`SteamManager.unlock(api_name)` interface. `STAT_WISP_BEETLES_KILLED` is an
**INT Steam statistic**, not an achievement: default/minimum `0`, maximum
`999999`, increment-only, and client-set. `ACH_WISP_HUNTER` references it as
its progress statistic with the range `0`–`10`.

## Save format and migration

All Steam Cloud game state is under `user://saves/`. The manifest is
`save_manifest.json` and currently has `save_version: 2`:

```json
{
  "save_version": 2,
  "components": {},
  "statistics": { "enemies_defeated": 0, "wisp_beetles_defeated": 0 },
  "pending_steam_achievements": []
}
```

Each write uses a temporary sibling file and rename/rollback. JSON and variant
loads validate their basic type and use safe defaults. `SaveService` is the
single place for subsequent `vN -> vN+1` migrations. Existing files are copied
into the new directory on first run without deleting the legacy copy.

The synchronized components include chapter/quest/level progress, inventory,
player state, unlocked skills/skill tree, completed levels, equipped companions
and companion upgrades, world drops, cooldowns, resume state, player identity,
and the statistics/manifest. Device-specific settings such as `settings.cfg`,
`game_config.cfg`, logs, captures, caches and temporary gameplay state remain
outside `user://saves/` and are not synchronized.

## Steam Auto-Cloud configuration

The following three Auto-Cloud paths have been saved as an unpublished
Steamworks configuration draft. Each uses pattern `*`, **recursive enabled**,
and only the `saves` directory. Do not add a rule for the complete Godot
application-data directory.

| OS | Steam Auto-Cloud root | Subdirectory | Resolved Godot location |
| --- | --- | --- | --- |
| Windows | `WinAppDataRoaming` | `Godot/app_userdata/JoeysSlimeventure/saves` | `%USERPROFILE%/AppData/Roaming/Godot/app_userdata/JoeysSlimeventure/saves` |
| Linux / SteamOS | `LinuxXdgDataHome` | `godot/app_userdata/JoeysSlimeventure/saves` | `$XDG_DATA_HOME/godot/app_userdata/JoeysSlimeventure/saves` |
| macOS | `MacAppSupport` | `Godot/app_userdata/JoeysSlimeventure/saves` | `~/Library/Application Support/Godot/app_userdata/JoeysSlimeventure/saves` |

An older, unrelated Auto-Cloud entry for `SavesDir/*.sav` was already present
in Steamworks. It is not used by this project and has intentionally not been
deleted automatically.

Steam Cloud is currently marked “developers only” in Steamworks. Leave that on
while testing; clear it and publish the configuration when Cloud should be
visible to customers. Dynamic Cloud Sync is intentionally off: Auto-Cloud
performs safe startup/shutdown synchronization, while runtime suspend/resume
sync requires the Steam Remote Storage conflict/notification APIs.

## Steamworks and depot checklist

The project has presets for Windows x86_64, macOS universal (Intel + Apple
Silicon), and Linux x86_64/SteamOS. Windows, macOS (Intel + Apple Silicon), and
Linux + SteamOS are selected in the saved Steamworks configuration draft; the
Shop selection has been aligned separately. Native builds and matching depots
must be uploaded before publishing these settings so the Library labels match
actual downloadable content:

1. Install matching GodotSteam custom templates and export each native build.
2. Create/attach a Windows, macOS and Linux/SteamOS depot; upload each build
   with SteamPipe and add every platform depot to the customer package.
3. Confirm **Application → General Application Settings** still has Windows
   (64-bit), macOS (Intel and Apple Silicon as supplied), and Linux + SteamOS
   selected.
4. Confirm **Store Page Admin → Basic Info** has the same three operating
   systems. Steamworks will then report the two lists as synchronized.
5. Publish the pending Steamworks configuration only when the builds and store
   settings are ready. This implementation does not publish a release.

The macOS Steam build must include the matching GodotSteam macOS runtime inside
the `.app`, be codesigned and notarized for distribution. Linux must ship the
GodotSteam Linux runtime with its x86_64 executable. Windows must ship the
matching `steam_api64` dependency provided by the GodotSteam export template.

## Development and tests

`steam_appid.txt` contains `4536840` for local starts outside Steam. It is
gitignored; copy it beside a local debug executable when needed, and do not put
it in the final Steam depot.

Debug-only functions (they return no result in release builds):

```gdscript
SteamManager.debug_status()
SteamManager.debug_unlock("ACH_FIRST_KILL")
SteamManager.debug_reset_achievement("ACH_FIRST_KILL")
SteamManager.debug_save()
SteamManager.debug_load()
SaveService.debug_save_manifest()
SaveService.debug_reload_manifest()
SaveService.get_save_directory_for_debug()
```

Suggested test sequence:

1. Start with a standard Godot editor/no Steam: confirm the game runs and logs
   the one-time unavailable-Steam message.
2. Start using GodotSteam while Steam is signed in: confirm the initialization
   and persona logs, then inspect `debug_status()`.
3. Enter the first Chapter-1 cave and verify `ACH_INTO_THE_DEPTHS` in Steam.
4. Kill a real hostile enemy with a player attack and verify
   `ACH_FIRST_KILL`; repeat to verify idempotence.
5. Kill ten hostile Wisp Beetles with player attacks. Confirm that
   `statistics.wisp_beetles_defeated` reaches 10 in `save_manifest.json` and
   that `STAT_WISP_BEETLES_KILLED` unlocks once; repeat kills to verify that
   the unlock remains idempotent.
6. Save/restart/load, inspect the `user://saves` directory, then repeat on a
   second machine with Steam Cloud enabled. Corrupt one JSON file to confirm
   that the affected system uses defaults rather than crashing.
