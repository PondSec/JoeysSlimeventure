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

	root.size = Vector2i(1600, 900)

	var level_scene: Node = CHAPTER_LEVEL_SCENE.instantiate()
	var seed_override := _read_seed_override()
	if seed_override >= 0:
		level_scene.set("generator_seed_override", seed_override)
	root.add_child(level_scene)

	for _frame: int in range(8):
		await process_frame
		await physics_frame

	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("CAPTURE_FAIL preview: no rendered viewport texture; run without --headless.")
	else:
		var screenshot: Image = viewport_texture.get_image()
		if screenshot == null or screenshot.is_empty():
			push_error("CAPTURE_FAIL preview: renderer returned no image; run without --headless.")
		else:
			var output_path := "user://chapter_level%d_preview_seed_%d.png" % [level_index + 1, int(level_scene.get("active_level_seed"))]
			var result := screenshot.save_png(output_path)
			print("CAPTURE preview seed=%d path=%s result=%d" % [int(level_scene.get("active_level_seed")), output_path, result])
	level_scene.queue_free()
	await process_frame
	quit()


func _read_seed_override() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return int(argument.trim_prefix("--seed="))
	return -1


func _read_level_index() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			return maxi(0, int(argument.trim_prefix("--level=")) - 1)
	return 0
