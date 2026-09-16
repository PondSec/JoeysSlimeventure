extends SceneTree

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("chapter_qa_mode", true)
	var progress: Node = root.get_node("/root/ChapterProgress")
	progress.reset_progress()
	progress.active_chapter = 1
	progress.active_level_index = 0
	var level := CHAPTER_LEVEL_SCENE.instantiate()
	root.add_child(level)
	for _frame in range(18):
		await process_frame
		await physics_frame

	var enemy_root := level.get_node_or_null("EnemyRoot")
	var target_count := int(level.get("enemy_population_target"))
	var victim: Node2D
	for enemy: Node in enemy_root.get_children():
		if str(enemy.get_meta("chapter_enemy_type", "")) == "bat":
			victim = enemy as Node2D
			break
	if victim == null:
		push_error("RESPAWN_FAIL no bat available for replacement check")
		quit(1)
		return

	victim.call("take_damage", 999, Vector2.LEFT)
	for _frame in range(20):
		await process_frame
		await physics_frame
	# Exercise the same manager path without waiting through the player-facing
	# 6-10 second delay in an automated check.
	level.set("enemy_respawn_timer", 0.001)
	for _frame in range(10):
		await process_frame
		await physics_frame

	var active_count := int(level.call("_get_active_managed_enemy_count"))
	var status := "PASS" if active_count == target_count else "FAIL"
	print("ENEMY_RESPAWN target=%d active=%d status=%s" % [target_count, active_count, status])
	level.queue_free()
	await process_frame
	quit(0 if status == "PASS" else 1)
