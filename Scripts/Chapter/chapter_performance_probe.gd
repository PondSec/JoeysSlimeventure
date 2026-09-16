extends SceneTree

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")
const WARMUP_FRAMES := 180
const SAMPLE_FRAMES := 720


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("chapter_qa_mode", true)
	root.size = Vector2i(1600, 900)
	var progress: Node = root.get_node("/root/ChapterProgress")
	progress.reset_progress()
	progress.active_chapter = 1
	progress.active_level_index = 1
	progress.save_progress()

	var level := CHAPTER_LEVEL_SCENE.instantiate()
	level.set("generator_seed_override", _read_seed_override())
	root.add_child(level)
	if "--hide-parallax-foreground" in OS.get_cmdline_user_args():
		# Diagnostic switch: isolates the cost of the screen-edge foreground
		# without changing the normal shipped runtime path.
		var foreground: CanvasLayer = level.get("parallax_foreground_layer") as CanvasLayer
		if foreground != null:
			foreground.visible = false
	for _frame: int in range(WARMUP_FRAMES):
		await process_frame

	var elapsed_start_usec: int = Time.get_ticks_usec()
	for _frame: int in range(SAMPLE_FRAMES):
		await process_frame
	var elapsed_usec: int = Time.get_ticks_usec() - elapsed_start_usec
	var average_fps: float = float(SAMPLE_FRAMES) * 1000000.0 / maxf(1.0, float(elapsed_usec))
	var engine_fps: float = Engine.get_frames_per_second()
	print("PERF seed=%d avg_fps=%.1f engine_fps=%.1f" % [int(level.get("active_level_seed")), average_fps, engine_fps])
	level.queue_free()
	await process_frame
	quit()


func _read_seed_override() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return int(argument.trim_prefix("--seed="))
	return 404
