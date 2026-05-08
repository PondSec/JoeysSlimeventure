extends SceneTree

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")
const ChapterContent := preload("res://Scripts/Chapter/chapter_content.gd")

const FALL_LIMIT_MARGIN := 220.0
const SIMULATION_FRAMES := 180


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progress: Node = root.get_node("/root/ChapterProgress")
	progress.reset_progress()

	var total_levels: int = ChapterContent.get_level_count(1)
	for level_index: int in range(total_levels):
		progress.active_chapter = 1
		progress.active_level_index = level_index
		progress.save_progress()

		var level_scene: Node = CHAPTER_LEVEL_SCENE.instantiate()
		root.add_child(level_scene)
		await process_frame
		await physics_frame

		var player: CharacterBody2D = level_scene.get_node("PlayerModel") as CharacterBody2D
		var terrain_root: Node = level_scene.get_node("TerrainRoot")
		var decor_root: Node = level_scene.get_node("DecorRoot")
		var enemy_root: Node = level_scene.get_node("EnemyRoot")
		var gate_root: Node = level_scene.get_node("GateRoot")
		var wall_tiles: TileMapLayer = level_scene.get_node("Level/wall") as TileMapLayer
		var level_data: Dictionary = level_scene.get("active_level") as Dictionary
		var validation: Dictionary = level_data.get("layout_validation", {}) as Dictionary
		var title: String = str(level_data.get("title", ""))

		var start_y: float = player.global_position.y
		var touched_floor: bool = false
		for _frame: int in range(SIMULATION_FRAMES):
			await physics_frame
			if player.is_on_floor():
				touched_floor = true

		var end_y: float = player.global_position.y
		var allowed_fall_limit: float = start_y + FALL_LIMIT_MARGIN
		var terrain_count: int = terrain_root.get_child_count()
		var decor_count: int = decor_root.get_child_count()
		var enemy_count: int = enemy_root.get_child_count()
		var gate_count: int = gate_root.get_child_count()
		var invalid_tile_count: int = 0
		for cell: Vector2i in wall_tiles.get_used_cells():
			var atlas_coords: Vector2i = wall_tiles.get_cell_atlas_coords(cell)
			if atlas_coords.x < 0 or atlas_coords.x > 2 or atlas_coords.y < 0 or atlas_coords.y > 2:
				invalid_tile_count += 1
		var path_valid: bool = bool(validation.get("path_valid", false))
		var invalid_jump_count: int = int(validation.get("invalid_jump_count", 0))
		var unreachable_reward_count: int = int(validation.get("unreachable_reward_count", 0))
		var unreachable_room_count: int = int(validation.get("unreachable_room_count", 0))
		var dead_end_count: int = int(validation.get("dead_end_count", 0))
		var path_length: float = float(validation.get("critical_path_length_tiles", 0.0))
		var attempt_index: int = int(validation.get("attempt_index", 0))
		var note_count: int = (validation.get("notes", PackedStringArray()) as PackedStringArray).size()
		var first_body: StaticBody2D = null
		if terrain_count > 0:
			first_body = terrain_root.get_child(0) as StaticBody2D

		var collision_layer: int = -1
		if first_body != null:
			collision_layer = first_body.collision_layer

		var status: String = "PASS"
		if terrain_count == 0 or decor_count == 0 or gate_count == 0:
			status = "FAIL"
		elif collision_layer != 2:
			status = "FAIL"
		elif end_y > allowed_fall_limit:
			status = "FAIL"
		elif not touched_floor:
			status = "FAIL"
		elif not path_valid:
			status = "FAIL"
		elif invalid_jump_count > 0:
			status = "FAIL"
		elif unreachable_room_count > 0:
			status = "FAIL"
		elif invalid_tile_count > 0:
			status = "FAIL"

		print(
			"VALIDATE level=%d title=%s terrain=%d decor=%d enemies=%d gates=%d invalid_tiles=%d path=%s invalid_jumps=%d unreachable_rewards=%d unreachable_rooms=%d dead_ends=%d path_len=%.1f notes=%d attempt=%d start_y=%.1f end_y=%.1f floor=%s layer=%d status=%s"
			% [level_index + 1, title, terrain_count, decor_count, enemy_count, gate_count, invalid_tile_count, str(path_valid), invalid_jump_count, unreachable_reward_count, unreachable_room_count, dead_end_count, path_length, note_count, attempt_index + 1, start_y, end_y, str(touched_floor), collision_layer, status]
		)

		level_scene.queue_free()
		await process_frame

	progress.enter_hub()
	quit()
