extends SceneTree

const CHAPTER_PROGRESS_PATH := "user://chapter_progress.json"
const COMPLETED_LEVELS_PATH := "user://completed_levels.save"
const LEGACY_SKILLS_PATH := "user://skills.save"
const PLAYER_SKILLS_PATH := "user://player_skills.save"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_write_text_file(CHAPTER_PROGRESS_PATH, JSON.stringify({
		"active_chapter": 0,
		"active_level_index": 0,
		"chapter_progress": {},
		"chapter_rewards": {},
		"completed_chapters": [],
		"pending_hub_banner": "",
		"pending_hub_toast": "",
		"seen_flags": [],
		"unlocked_chapters": 1
	}, "\t"))
	_write_text_file(COMPLETED_LEVELS_PATH, JSON.stringify(["hub_awakening"]))
	_write_text_file(LEGACY_SKILLS_PATH, JSON.stringify({
		"acid_spit": {"unlocked": false},
		"dash": {"unlocked": false},
		"double_jump": {"unlocked": false},
		"glow": {"unlocked": true},
		"gravity_slime": {"unlocked": false},
		"heal_burst": {"unlocked": false},
		"mana_shield": {"unlocked": false},
		"phoenix_slime": {"unlocked": false},
		"regeneration": {"unlocked": false},
		"slime_minion": {"unlocked": false},
		"slime_wings": {"unlocked": false},
		"sticky_form": {"unlocked": false},
		"teleport": {"unlocked": false},
		"thorns": {"unlocked": false},
		"ult": {"unlocked": false},
		"wall_run": {"unlocked": false},
		"wall_slide": {"unlocked": false}
	}))

	var player_skill_data: Dictionary = {
		"has_glow_skill": true,
		"has_wall_slide_skill": false,
		"has_regeneration_skill": false,
		"has_ult_skill": false,
		"has_double_jump_skill": false,
		"has_wall_run_skill": false,
		"has_dash_skill": false,
		"has_teleport_skill": false,
		"has_mana_shield_skill": false,
		"has_heal_burst_skill": false,
		"has_sticky_form_skill": false,
		"has_thorns_skill": false,
		"has_slime_wings_skill": false,
		"player_level": 1
	}
	var player_file: FileAccess = FileAccess.open(PLAYER_SKILLS_PATH, FileAccess.WRITE)
	if player_file != null:
		player_file.store_var(player_skill_data)
		player_file.close()

	quit()


func _write_text_file(path: String, contents: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(contents)
	file.close()
