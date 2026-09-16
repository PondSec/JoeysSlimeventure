extends SceneTree

## Captures an actual playable Lush biome location rather than a debug camera.
## It is intentionally kept as a QA utility so future biome art changes can be
## visually checked on the same deterministic seeds.

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")
const TILE_SIZE := 32.0


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
	for _frame: int in range(12):
		await process_frame
		await physics_frame

	var regions: Array = level.get("lush_biome_regions") as Array
	if regions.is_empty():
		push_error("CAPTURE_FAIL lush biome: selected seed has no dense biome")
		quit()
		return
	var player := level.get_node_or_null("PlayerModel") as CharacterBody2D
	var landing_cell := _find_landing_cell(level, regions.front() as Rect2)
	if player == null or landing_cell == Vector2i(-1, -1):
		push_error("CAPTURE_FAIL lush biome: no safe player landing")
		quit()
		return
	var clearance: float = float(level.call("_player_spawn_clearance"))
	player.global_position = Vector2(float(landing_cell.x) * TILE_SIZE + TILE_SIZE * 0.5, float(landing_cell.y + 1) * TILE_SIZE - clearance)
	player.velocity = Vector2.ZERO
	for _frame: int in range(20):
		await process_frame
		await physics_frame
	print("CAPTURE_LUSH_QA player=%s strength=%.3f" % [str(player.global_position), float(level.call("_get_lush_biome_strength", player.global_position))])
	_capture("lush_biome", level)

	level.queue_free()
	await process_frame
	quit()


func _find_landing_cell(level: Node, region: Rect2) -> Vector2i:
	var level_size: Vector2i = level.get("level_size_tiles") as Vector2i
	var centre_x: int = clampi(int(round(region.get_center().x / TILE_SIZE)), 3, level_size.x - 4)
	for distance: int in range(0, 22):
		for direction: int in [-1, 1]:
			var grid_x: int = clampi(centre_x + distance * direction, 3, level_size.x - 4)
			for grid_y: int in range(3, level_size.y - 3):
				if bool(level.call("_is_valid_spawn_tile", grid_x, grid_y)):
					return Vector2i(grid_x, grid_y)
	return Vector2i(-1, -1)


func _capture(label: String, level: Node) -> void:
	var screenshot: Image = root.get_texture().get_image()
	var path := "user://chapter_level2_%s_seed_%d.png" % [label, int(level.get("active_level_seed"))]
	print("CAPTURE lush=%s path=%s result=%d" % [label, path, screenshot.save_png(path)])


func _read_seed_override() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return int(argument.trim_prefix("--seed="))
	return 3456
