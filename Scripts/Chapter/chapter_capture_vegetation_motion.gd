extends SceneTree

## QA capture: three live frames around one generated plant. This verifies the
## idle sway, near-player bend and gradual recovery without a debug-only scene.

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")


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
	await _settle(16)

	var player := level.get_node_or_null("PlayerModel") as CharacterBody2D
	var plant := _find_test_plant(level)
	if player == null or plant == null:
		push_error("CAPTURE_FAIL vegetation: no generated ground plant")
		quit()
		return
	# Freeze only the player controller; the camera still follows its transform
	# and ChapterLevel keeps updating the per-plant interaction uniforms.
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.position_smoothing_enabled = false
		camera.make_current()

	player.global_position = plant.global_position + Vector2(-76.0, -18.0)
	player.velocity = Vector2.ZERO
	await _settle(8)
	_capture("vegetation_approach", level)

	player.global_position = plant.global_position + Vector2(-8.0, -16.0)
	player.velocity = Vector2.ZERO
	await _settle(8)
	_capture("vegetation_contact", level)

	player.global_position = plant.global_position + Vector2(92.0, -18.0)
	player.velocity = Vector2.ZERO
	await _settle(18)
	_capture("vegetation_recovery", level)
	level.queue_free()
	await process_frame
	quit()


func _settle(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await process_frame


func _find_test_plant(level: Node) -> Sprite2D:
	var decor := level.get_node_or_null("DecorRoot")
	if decor == null:
		return null
	for preferred_name: String in ["GeneratedWindBroadleaf", "GeneratedWindGlowFlower", "GeneratedLushLandmark", "GeneratedFlora"]:
		for child: Node in decor.get_children():
			if child.name == preferred_name and child is Sprite2D:
				return child as Sprite2D
	return null


func _capture(label: String, level: Node) -> void:
	var screenshot: Image = root.get_texture().get_image()
	var path := "user://chapter_level2_%s_seed_%d.png" % [label, int(level.get("active_level_seed"))]
	print("CAPTURE vegetation=%s path=%s result=%d" % [label, path, screenshot.save_png(path)])


func _read_seed_override() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return int(argument.trim_prefix("--seed="))
	return 404
