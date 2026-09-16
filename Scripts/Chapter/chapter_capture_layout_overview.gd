extends SceneTree

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("chapter_qa_mode", true)
	var progress: Node = root.get_node("/root/ChapterProgress")
	progress.reset_progress()
	progress.active_chapter = 1
	var level_index := _read_level_index()
	progress.active_level_index = level_index
	progress.save_progress()

	root.size = Vector2i(1920, 1080)

	var level_scene: Node = CHAPTER_LEVEL_SCENE.instantiate()
	var seed_override := _read_seed_override()
	if seed_override >= 0:
		level_scene.set("generator_seed_override", seed_override)
	level_scene.set("debug_overlay_enabled", OS.get_cmdline_user_args().has("--debug"))
	root.add_child(level_scene)

	for _frame: int in range(10):
		await process_frame
		await physics_frame

	var overview_camera := Camera2D.new()
	level_scene.add_child(overview_camera)
	overview_camera.make_current()

	var play_bounds: Rect2 = level_scene.get("runtime_play_bounds") as Rect2
	if play_bounds.size == Vector2.ZERO:
		play_bounds = Rect2(Vector2.ZERO, level_scene.get("level_size_pixels") as Vector2)
	overview_camera.position = play_bounds.get_center()

	var viewport_size: Vector2 = Vector2(root.size)
	var padded_width: float = maxf(320.0, viewport_size.x - 120.0)
	var padded_height: float = maxf(240.0, viewport_size.y - 120.0)
	var zoom_factor: float = maxf(play_bounds.size.x / padded_width, play_bounds.size.y / padded_height)
	zoom_factor = maxf(1.0, zoom_factor)
	# Camera2D zoom values below 1 show more world space. The reciprocal keeps
	# the entire generated play bounds in frame instead of cropping the exit.
	overview_camera.zoom = Vector2.ONE / zoom_factor

	for _frame: int in range(5):
		await process_frame
		await physics_frame

	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("CAPTURE_FAIL overview: no rendered viewport texture; run without --headless.")
	else:
		var screenshot: Image = viewport_texture.get_image()
		if screenshot == null or screenshot.is_empty():
			push_error("CAPTURE_FAIL overview: renderer returned no image; run without --headless.")
		else:
			var output_path := "user://chapter_level%d_overview_seed_%d.png" % [level_index + 1, int(level_scene.get("active_level_seed"))]
			var result := screenshot.save_png(output_path)
			print("CAPTURE overview seed=%d path=%s result=%d" % [int(level_scene.get("active_level_seed")), output_path, result])

	level_scene.queue_free()
	await process_frame
	quit()


func _read_seed_override() -> int:
	var arguments := OS.get_cmdline_user_args()
	for argument: String in arguments:
		if argument.begins_with("--seed="):
			return int(argument.trim_prefix("--seed="))
		if argument.begins_with("seed="):
			return int(argument.trim_prefix("seed="))
	return -1


func _read_level_index() -> int:
	var arguments := OS.get_cmdline_user_args()
	for argument: String in arguments:
		if argument.begins_with("--level="):
			return maxi(0, int(argument.trim_prefix("--level=")) - 1)
		if argument.begins_with("level="):
			return maxi(0, int(argument.trim_prefix("level=")) - 1)
	return 0
