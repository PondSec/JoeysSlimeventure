extends Node

## Owns the durable save-file layout.  Gameplay systems still own their data;
## this service provides versioning, migration and crash-safe file replacement.

const SAVE_VERSION := 2
const SAVE_DIRECTORY := "user://saves"
const MANIFEST_PATH := SAVE_DIRECTORY + "/save_manifest.json"
const DEFAULT_STATISTICS := {
	"enemies_defeated": 0,
	"wisp_beetles_defeated": 0,
}

const COMPONENT_PATHS := {
	"progress": "chapter_progress.json",
	"inventory": "inventory.save",
	"abilities": "player_skills.save",
	"player_state": "player_state.tres",
	"resume": "current_level.res",
	"completed_levels": "completed_levels.json",
	"world_drops": "dropped_items.json",
	"cooldowns": "charge_cooldown.dat",
	"player_identity": "player_id.txt",
	"skill_tree": "skill_tree.json",
	"lumora_runtime": "lumora_runtime_equipped.save",
	"lumora_skills": "lumora_skill_data.save",
	"vortex_skills": "vortex_skill_data.save",
}

const LEGACY_PATHS := {
	"chapter_progress.json": "user://chapter_progress.json",
	"inventory.save": "user://inventory.save",
	"player_skills.save": "user://player_skills.save",
	"player_state.tres": "user://savegame.tres",
	"current_level.res": "user://current_level.res",
	"completed_levels.json": "user://completed_levels.save",
	"dropped_items.json": "user://dropped_items.save",
	"charge_cooldown.dat": "user://charge_cooldown.dat",
	"player_id.txt": "user://player_id.save",
	"skill_tree.json": "user://skills.save",
	"lumora_runtime_equipped.save": "user://lumora_save_data.save",
	"lumora_skill_data.save": "user://lumora_skill_data.save",
	"vortex_skill_data.save": "user://vortex_skill_data.save",
}

var manifest: Dictionary = {}


func _ready() -> void:
	_ensure_save_directory()
	_migrate_legacy_files()
	load_manifest()


func path_for(component: String) -> String:
	var file_name := String(COMPONENT_PATHS.get(component, ""))
	return SAVE_DIRECTORY.path_join(file_name) if not file_name.is_empty() else ""


func load_manifest() -> void:
	var loaded: Variant = read_json(MANIFEST_PATH, {})
	if loaded is Dictionary:
		manifest = _migrate_manifest(loaded as Dictionary)
	else:
		manifest = _default_manifest()
	if int(manifest.get("save_version", SAVE_VERSION)) <= SAVE_VERSION:
		save_manifest()


func save_manifest() -> bool:
	if int(manifest.get("save_version", SAVE_VERSION)) > SAVE_VERSION:
		push_warning("[Save] Refusing to overwrite newer save version %d with build version %d." % [int(manifest.get("save_version", 0)), SAVE_VERSION])
		return false
	manifest["save_version"] = SAVE_VERSION
	manifest["updated_unix"] = int(Time.get_unix_time_from_system())
	return write_json(MANIFEST_PATH, manifest)


func increment_stat(stat_name: String, amount: int = 1) -> int:
	if stat_name.is_empty() or amount == 0:
		return get_stat(stat_name)
	var statistics := _statistics()
	var next_value := maxi(0, int(statistics.get(stat_name, 0)) + amount)
	statistics[stat_name] = next_value
	manifest["statistics"] = statistics
	save_manifest()
	return next_value


func get_stat(stat_name: String) -> int:
	return int(_statistics().get(stat_name, 0))


func queue_pending_achievement(api_name: String) -> void:
	if api_name.is_empty():
		return
	var pending := _pending_achievements()
	if not pending.has(api_name):
		pending.append(api_name)
		manifest["pending_steam_achievements"] = pending
		save_manifest()


func clear_pending_achievement(api_name: String) -> void:
	var pending := _pending_achievements()
	if pending.has(api_name):
		pending.erase(api_name)
		manifest["pending_steam_achievements"] = pending
		save_manifest()


func get_pending_achievements() -> Array[String]:
	var result: Array[String] = []
	for value: Variant in _pending_achievements():
		result.append(String(value))
	return result


func has_cosmetic_presentation_claimed(cosmetic_id: String, account_id: String) -> bool:
	if cosmetic_id.is_empty() or account_id.is_empty():
		return false
	var presentations := _cosmetic_presentations()
	var accounts: Dictionary = presentations.get(cosmetic_id, {}) as Dictionary
	return bool(accounts.get(account_id, false))


func mark_cosmetic_presentation_claimed(cosmetic_id: String, account_id: String) -> bool:
	if cosmetic_id.is_empty() or account_id.is_empty():
		return false
	var presentations := _cosmetic_presentations()
	var accounts: Dictionary = presentations.get(cosmetic_id, {}) as Dictionary
	accounts[account_id] = true
	presentations[cosmetic_id] = accounts
	manifest["cosmetic_presentations"] = presentations
	return save_manifest()


## Cosmetic preferences are allowed to persist per Steam account. They never
## grant ownership: callers must still verify the corresponding entitlement.
func get_cosmetic_preference(cosmetic_id: String, account_id: String, default_value: bool = true) -> bool:
	if cosmetic_id.is_empty() or account_id.is_empty():
		return default_value
	var preferences := _cosmetic_preferences()
	var accounts: Dictionary = preferences.get(cosmetic_id, {}) as Dictionary
	return bool(accounts.get(account_id, default_value))


func set_cosmetic_preference(cosmetic_id: String, account_id: String, value: bool) -> bool:
	if cosmetic_id.is_empty() or account_id.is_empty():
		return false
	var preferences := _cosmetic_preferences()
	var accounts: Dictionary = preferences.get(cosmetic_id, {}) as Dictionary
	accounts[account_id] = value
	preferences[cosmetic_id] = accounts
	manifest["cosmetic_preferences"] = preferences
	return save_manifest()


func write_json(path: String, data: Variant) -> bool:
	return _write_bytes_atomically(path, JSON.stringify(data, "\t").to_utf8_buffer())


func read_json(path: String, fallback: Variant = {}) -> Variant:
	if not FileAccess.file_exists(path):
		return fallback
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[Save] Failed to open %s for reading." % path)
		return fallback
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_warning("[Save] Invalid JSON in %s; defaults will be used." % path)
		return fallback
	return parsed


func write_variant(path: String, value: Variant) -> bool:
	var temp_path := _temporary_path(path)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("[Save] Failed to open temporary file for %s." % path)
		return false
	file.store_var(value)
	file.close()
	return _replace_with_temporary(path, temp_path)


func write_text(path: String, value: String) -> bool:
	return _write_bytes_atomically(path, value.to_utf8_buffer())


func read_variant(path: String, fallback: Variant = null) -> Variant:
	if not FileAccess.file_exists(path):
		return fallback
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[Save] Failed to open %s for reading." % path)
		return fallback
	var value: Variant = file.get_var()
	file.close()
	return value


func save_resource(path: String, resource: Resource) -> int:
	if resource == null:
		return ERR_INVALID_PARAMETER
	# ResourceSaver chooses its saver from the filename extension, so a plain
	# `.res.tmp` path is not writable. Keep the original extension on the temp.
	var temp_path := _resource_temporary_path(path)
	var result := ResourceSaver.save(resource, temp_path)
	if result != OK:
		push_warning("[Save] Failed to write temporary resource %s: %s" % [path, result])
		return result
	return OK if _replace_with_temporary(path, temp_path) else ERR_CANT_CREATE


func get_save_directory_for_debug() -> String:
	return ProjectSettings.globalize_path(SAVE_DIRECTORY)


func debug_save_manifest() -> bool:
	if not OS.is_debug_build():
		return false
	return save_manifest()


func debug_reload_manifest() -> Dictionary:
	if not OS.is_debug_build():
		return {}
	load_manifest()
	return manifest.duplicate(true)


func _default_manifest() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"components": COMPONENT_PATHS.duplicate(true),
		"statistics": DEFAULT_STATISTICS.duplicate(true),
		"pending_steam_achievements": [],
		# This stores only one-time presentation acknowledgements, never DLC
		# ownership. SteamEntitlements remains the entitlement source of truth.
		"cosmetic_presentations": {},
		"cosmetic_preferences": {},
		"created_unix": int(Time.get_unix_time_from_system()),
		"updated_unix": int(Time.get_unix_time_from_system()),
	}


func _migrate_manifest(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	var version := int(migrated.get("save_version", 1))
	if version < 2:
		if not migrated.has("statistics"):
			migrated["statistics"] = DEFAULT_STATISTICS.duplicate(true)
		migrated["components"] = COMPONENT_PATHS.duplicate(true)
		version = 2
	if not migrated.has("pending_steam_achievements"):
		migrated["pending_steam_achievements"] = []
	if not (migrated.get("cosmetic_presentations", {}) is Dictionary):
		migrated["cosmetic_presentations"] = {}
	if not (migrated.get("cosmetic_preferences", {}) is Dictionary):
		migrated["cosmetic_preferences"] = {}
	var migrated_statistics: Dictionary = migrated.get("statistics", {}) as Dictionary
	if not (migrated.get("statistics") is Dictionary):
		migrated_statistics = {}
	for stat_name: String in DEFAULT_STATISTICS:
		migrated_statistics[stat_name] = maxi(0, int(migrated_statistics.get(stat_name, DEFAULT_STATISTICS[stat_name])))
	migrated["statistics"] = migrated_statistics
	if not (migrated.get("pending_steam_achievements") is Array):
		migrated["pending_steam_achievements"] = []
	if not (migrated.get("components") is Dictionary):
		migrated["components"] = COMPONENT_PATHS.duplicate(true)
	migrated["save_version"] = version
	if version > SAVE_VERSION:
		push_warning("[Save] Save version %d is newer than this build (%d)." % [version, SAVE_VERSION])
	return migrated


func _statistics() -> Dictionary:
	var value: Variant = manifest.get("statistics", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _pending_achievements() -> Array:
	var value: Variant = manifest.get("pending_steam_achievements", [])
	return (value as Array).duplicate() if value is Array else []


func _cosmetic_presentations() -> Dictionary:
	var value: Variant = manifest.get("cosmetic_presentations", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _cosmetic_preferences() -> Dictionary:
	var value: Variant = manifest.get("cosmetic_preferences", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _ensure_save_directory() -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("[Save] Could not create save directory: %s" % error)


func _migrate_legacy_files() -> void:
	for file_name_variant: Variant in LEGACY_PATHS.keys():
		var file_name := String(file_name_variant)
		var legacy_path := String(LEGACY_PATHS[file_name])
		var target_path := SAVE_DIRECTORY.path_join(file_name)
		if FileAccess.file_exists(target_path) or not FileAccess.file_exists(legacy_path):
			continue
		var source := FileAccess.open(legacy_path, FileAccess.READ)
		if source == null:
			push_warning("[Save] Could not migrate %s." % legacy_path)
			continue
		var bytes := source.get_buffer(source.get_length())
		source.close()
		if _write_bytes_atomically(target_path, bytes):
			print("[Save] Migrated %s to the versioned save directory." % file_name)


func _write_bytes_atomically(path: String, bytes: PackedByteArray) -> bool:
	var temp_path := _temporary_path(path)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("[Save] Failed to open temporary file for %s." % path)
		return false
	file.store_buffer(bytes)
	file.close()
	return _replace_with_temporary(path, temp_path)


func _temporary_path(path: String) -> String:
	return "%s.tmp" % path


func _resource_temporary_path(path: String) -> String:
	var extension := path.get_extension()
	if extension.is_empty():
		return _temporary_path(path)
	return "%s.tmp.%s" % [path.get_basename(), extension]


func _replace_with_temporary(target_path: String, temp_path: String) -> bool:
	var target_absolute := ProjectSettings.globalize_path(target_path)
	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	var backup_absolute := target_absolute + ".bak"
	if FileAccess.file_exists(backup_absolute):
		DirAccess.remove_absolute(backup_absolute)
	if FileAccess.file_exists(target_absolute):
		var backup_error := DirAccess.rename_absolute(target_absolute, backup_absolute)
		if backup_error != OK:
			push_warning("[Save] Could not rotate existing save %s." % target_path)
			DirAccess.remove_absolute(temp_absolute)
			return false
	var replace_error := DirAccess.rename_absolute(temp_absolute, target_absolute)
	if replace_error != OK:
		push_warning("[Save] Could not replace %s." % target_path)
		if FileAccess.file_exists(backup_absolute):
			DirAccess.rename_absolute(backup_absolute, target_absolute)
		return false
	if FileAccess.file_exists(backup_absolute):
		DirAccess.remove_absolute(backup_absolute)
	return true
