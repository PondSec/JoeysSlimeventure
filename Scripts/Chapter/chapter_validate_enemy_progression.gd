extends SceneTree

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")

const EXPECTED_BATS := [1, 2, 3]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("chapter_qa_mode", true)
	var progress: Node = root.get_node("/root/ChapterProgress")
	progress.reset_progress()

	var all_valid := true
	for level_index: int in range(EXPECTED_BATS.size()):
		progress.active_chapter = 1
		progress.active_level_index = level_index
		progress.save_progress()
		var level_scene: Node = CHAPTER_LEVEL_SCENE.instantiate()
		root.add_child(level_scene)
		await process_frame
		await physics_frame

		var enemy_root: Node = level_scene.get_node_or_null("EnemyRoot")
		var enemy_count := enemy_root.get_child_count() if enemy_root != null else 0
		var bat_count := 0
		var non_bat_count := 0
		if enemy_root != null:
			for enemy: Node in enemy_root.get_children():
				if str(enemy.get_meta("chapter_enemy_type", "")) == "bat":
					bat_count += 1
				else:
					non_bat_count += 1
		var expected_bats: int = EXPECTED_BATS[level_index]
		var valid := bat_count == expected_bats and non_bat_count == 0 and enemy_count == expected_bats
		all_valid = all_valid and valid
		print("ENEMY_PROGRESSION level=%d bats=%d expected=%d non_bats=%d total=%d status=%s" % [level_index + 1, bat_count, expected_bats, non_bat_count, enemy_count, "PASS" if valid else "FAIL"])
		level_scene.queue_free()
		await process_frame

	quit(0 if all_valid else 1)
