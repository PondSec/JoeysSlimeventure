extends SceneTree

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")
const CharacterCatalog := preload("res://Scripts/character_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("chapter_qa_mode", true)
	var progress: Node = root.get_node("/root/ChapterProgress")
	progress.reset_progress()
	progress.active_chapter = 1
	progress.active_level_index = 0
	progress.runtime_player_state = {
		"character_id": CharacterCatalog.MALE_HERO_ID,
		"is_glowing": true
	}

	var level: Node = CHAPTER_LEVEL_SCENE.instantiate()
	root.add_child(level)
	for _frame: int in range(3):
		await process_frame
		await physics_frame

	var player: Node = level.get_node_or_null("PlayerModel")
	var expected_morph: String = CharacterCatalog.MALE_HERO_ID
	var restored_morph: String = str(player.get("current_character_id")) if player != null else ""
	var restored_glow: bool = bool(player.get("is_glowing")) if player != null else false
	var status := "PASS" if restored_morph == expected_morph and restored_glow else "FAIL"
	print("PORTAL_STATE morph=%s expected=%s glow=%s status=%s" % [restored_morph, expected_morph, str(restored_glow), status])
	level.queue_free()
	await process_frame
	quit(0 if status == "PASS" else 1)
