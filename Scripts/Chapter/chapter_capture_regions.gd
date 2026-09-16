extends SceneTree

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("chapter_qa_mode", true)
	var progress: Node = root.get_node("/root/ChapterProgress")
	progress.reset_progress()
	progress.active_chapter = 1
	progress.active_level_index = 1
	progress.save_progress()
	root.size = Vector2i(1600, 900)

	var level := CHAPTER_LEVEL_SCENE.instantiate()
	level.set("generator_seed_override", _read_seed_override())
	root.add_child(level)
	for _frame: int in range(10):
		await process_frame
		await physics_frame

	var camera := Camera2D.new()
	level.add_child(camera)
	camera.make_current()
	var bounds: Rect2 = level.get("runtime_play_bounds") as Rect2
	var regions := [
		{"name": "west", "ratio": Vector2(0.18, 0.42)},
		{"name": "upper", "ratio": Vector2(0.43, 0.27)},
		{"name": "heart", "ratio": Vector2(0.56, 0.57)},
		{"name": "east", "ratio": Vector2(0.82, 0.50)}
	]
	for region_variant: Variant in regions:
		var region: Dictionary = region_variant as Dictionary
		var ratio: Vector2 = region["ratio"] as Vector2
		camera.position = bounds.position + bounds.size * ratio
		for _frame: int in range(3):
			await process_frame
			await physics_frame
		var screenshot: Image = root.get_texture().get_image()
		var path := "user://chapter_level2_lush_%s_seed_%d.png" % [str(region["name"]), int(level.get("active_level_seed"))]
		print("CAPTURE region=%s path=%s result=%d" % [str(region["name"]), path, screenshot.save_png(path)])

	level.queue_free()
	await process_frame
	quit()


func _read_seed_override() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return int(argument.trim_prefix("--seed="))
	return 404
