extends SceneTree

## Visual regression capture for all linked cave/lush UI surfaces.
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
	level.set("generator_seed_override", 3456)
	root.add_child(level)
	for _frame in range(14):
		await process_frame
		await physics_frame

	# Freeze the world visual driver so each deliberately selected blend value is
	# captured exactly rather than being replaced by the player's current biome.
	level.set_process(false)
	call_group("biome_aware_ui", "set_biome_weight", "lush", 0.0)
	await process_frame
	var player := level.get_node_or_null("PlayerModel")
	var hotbar := player.get_node_or_null("CanvasLayer/HotBar") if player else null
	if hotbar and hotbar.has_method("set_selected_slot"):
		print("UI_HOTBAR_GEOMETRY rect=%s active_1=%s" % [str(hotbar.get_global_rect()), str((hotbar.get_node_or_null("CaveTheme/Active1") as Control).global_position)])
		hotbar.call("set_selected_slot", 4)
		var active_slot := hotbar.get_node_or_null("CaveTheme/Active5") as TextureRect
		print("UI_HOTBAR_TEST selected_slot_5_visible=%s" % str(active_slot != null and active_slot.modulate.a > 0.99))
		hotbar.call("set_selected_slot", 0)
	_capture("ui_cave")

	var inventory := player.get_node_or_null("CanvasLayer/InvUI") if player else null
	if inventory and inventory.has_method("open"):
		inventory.call("open")
	call_group("biome_aware_ui", "set_biome_weight", "lush", 1.0)
	await process_frame
	_capture("ui_lush_inventory")

	level.queue_free()
	await process_frame
	quit()


func _capture(label: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("CAPTURE_FAIL biome UI: renderer returned no frame")
		return
	var output_path := "user://%s.png" % label
	print("CAPTURE biome_ui=%s path=%s result=%d" % [label, output_path, image.save_png(output_path)])
