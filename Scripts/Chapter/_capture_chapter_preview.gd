extends SceneTree


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var chapter := load("res://Scenes/Chapter/chapter_level.tscn") as PackedScene
	viewport.add_child(chapter.instantiate())
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png("/tmp/joeys-chapter-corner-preview.png")
	quit()
