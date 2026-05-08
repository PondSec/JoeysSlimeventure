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

	root.size = Vector2i(1920, 1080)

	var level_scene: Node = CHAPTER_LEVEL_SCENE.instantiate()
	level_scene.set("debug_overlay_enabled", true)
	root.add_child(level_scene)

	for _frame: int in range(10):
		await process_frame
		await physics_frame

	var overview_camera := Camera2D.new()
	level_scene.add_child(overview_camera)
	overview_camera.make_current()

	var level_size_pixels: Vector2 = level_scene.get("level_size_pixels") as Vector2
	overview_camera.position = level_size_pixels * 0.5

	var viewport_size: Vector2 = Vector2(root.size)
	var padded_width: float = maxf(320.0, viewport_size.x - 120.0)
	var padded_height: float = maxf(240.0, viewport_size.y - 120.0)
	var zoom_factor: float = maxf(level_size_pixels.x / padded_width, level_size_pixels.y / padded_height)
	zoom_factor = maxf(1.0, zoom_factor)
	overview_camera.zoom = Vector2(zoom_factor, zoom_factor)

	for _frame: int in range(5):
		await process_frame
		await physics_frame

	var screenshot: Image = root.get_texture().get_image()
	screenshot.save_png("user://chapter_level1_overview.png")

	level_scene.queue_free()
	await process_frame
	quit()
