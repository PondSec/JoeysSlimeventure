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
	for _frame: int in range(12):
		await process_frame
		await physics_frame

	# This is intentionally the live PlayerModel and its normal Camera2D.  It
	# records a short, conservative run rather than moving a debug camera.
	var player: CharacterBody2D = level.get_node_or_null("PlayerModel") as CharacterBody2D
	if player == null:
		push_error("CAPTURE_FAIL playthrough: PlayerModel missing")
		quit()
		return
	_capture("spawn", level)

	for checkpoint: int in range(1, 5):
		await _run_player_segment(110)
		_capture("run_%d" % checkpoint, level)

	Input.action_release("right")
	Input.action_release("up")
	level.queue_free()
	await process_frame
	quit()


func _run_player_segment(frame_count: int) -> void:
	Input.action_press("right")
	for frame: int in range(frame_count):
		# Repeat safe normal jumps while running. The player controller, collision
		# and its camera decide the actual resulting route and landing.
		if frame % 30 == 4:
			Input.action_press("up")
		elif frame % 30 == 8:
			Input.action_release("up")
		await process_frame
		await physics_frame
	Input.action_release("up")


func _capture(label: String, level: Node) -> void:
	for _frame: int in range(3):
		await process_frame
		await physics_frame
	var screenshot: Image = root.get_texture().get_image()
	var path := "user://chapter_level2_played_%s_seed_%d.png" % [label, int(level.get("active_level_seed"))]
	print("CAPTURE playthrough=%s path=%s result=%d" % [label, path, screenshot.save_png(path)])


func _read_seed_override() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return int(argument.trim_prefix("--seed="))
	return 404
