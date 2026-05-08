extends SceneTree

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progress: Node = root.get_node("/root/ChapterProgress")
	progress.reset_progress()
	progress.active_chapter = 1
	progress.active_level_index = 0
	progress.save_progress()

	root.size = Vector2i(1600, 900)

	var level_scene: Node = CHAPTER_LEVEL_SCENE.instantiate()
	root.add_child(level_scene)

	for _frame: int in range(8):
		await process_frame
		await physics_frame

	var screenshot: Image = root.get_texture().get_image()
	screenshot.save_png("user://chapter_level1_preview.png")
	level_scene.queue_free()
	await process_frame
	quit()
