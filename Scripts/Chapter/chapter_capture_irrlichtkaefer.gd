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
	root.size = Vector2i(1600, 900)
	var level := CHAPTER_LEVEL_SCENE.instantiate()
	root.add_child(level)
	for _frame in range(20):
		await process_frame
		await physics_frame

	var player := level.get_node_or_null("PlayerModel") as CharacterBody2D
	var beetle: Node2D
	for enemy: Node in level.get_node("EnemyRoot").get_children():
		if str(enemy.get_meta("chapter_enemy_type", "")) == "irrlichtkaefer":
			beetle = enemy as Node2D
			break
	if player == null or beetle == null:
		push_error("CAPTURE_FAIL irrlichtkaefer missing from generated lush biome")
		quit(1)
		return

	player.set_physics_process(false)
	player.global_position = beetle.global_position + Vector2(-126.0, -18.0)
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()
		camera.force_update_scroll()
	for _frame in range(22):
		await process_frame
		await physics_frame
	var screenshot: Image = root.get_texture().get_image()
	var path := "user://irrlichtkaefer_lush_alert.png"
	print("CAPTURE irrlichtkaefer path=%s result=%d" % [path, screenshot.save_png(path)])
	level.queue_free()
	await process_frame
	quit()
