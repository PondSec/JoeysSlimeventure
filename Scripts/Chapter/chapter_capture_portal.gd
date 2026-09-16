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
	for _frame in range(12):
		await process_frame
		await physics_frame

	var player := level.get_node_or_null("PlayerModel") as CharacterBody2D
	var gate_root := level.get_node_or_null("GateRoot")
	var gate := gate_root.get_child(0) if gate_root != null and gate_root.get_child_count() > 0 else null
	if player == null or gate == null:
		push_error("CAPTURE_FAIL portal: player or gate missing")
		quit(1)
		return

	player.set_physics_process(false)
	player.global_position = gate.global_position + Vector2(-48.0, -48.0)
	gate.call("_on_area_body_entered", player)
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()
		camera.force_update_scroll()
	for _frame in range(4):
		await process_frame
	await _capture("portal_idle")

	# Start the exact entry path. The capture is made well before its one-shot
	# completion callback can transition the level.
	gate.call("_begin_entry")
	for _frame in range(8):
		await process_frame
	await _capture("portal_entry")

	level.queue_free()
	await process_frame
	quit()


func _capture(label: String) -> void:
	for _frame in range(3):
		await process_frame
	var screenshot: Image = root.get_texture().get_image()
	var path := "user://%s.png" % label
	print("CAPTURE portal=%s path=%s result=%d" % [label, path, screenshot.save_png(path)])
