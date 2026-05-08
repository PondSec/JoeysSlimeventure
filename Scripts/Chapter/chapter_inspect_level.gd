extends SceneTree

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")

const DEFAULT_LEVEL := 6
const DEFAULT_SEED := -1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var target_level: int = int(options.get("level", DEFAULT_LEVEL)) - 1
	var seed_override: int = int(options.get("seed", DEFAULT_SEED))

	var progress: Node = root.get_node("/root/ChapterProgress")
	progress.reset_progress()
	progress.active_chapter = 1
	progress.active_level_index = maxi(0, target_level)
	progress.save_progress()

	var level_scene: Node = CHAPTER_LEVEL_SCENE.instantiate()
	if seed_override >= 0:
		level_scene.set("generator_seed_override", seed_override)
	root.add_child(level_scene)

	for _frame: int in range(3):
		await process_frame
		await physics_frame

	var active_level: Dictionary = level_scene.get("active_level") as Dictionary
	var validation: Dictionary = active_level.get("layout_validation", {}) as Dictionary
	var best_generated_validation: Dictionary = active_level.get("generator_best_validation", {}) as Dictionary
	var debug_rooms: Array = active_level.get("debug_rooms", []) as Array
	var critical_path: Array = active_level.get("critical_path_nodes", []) as Array
	var side_paths: Array = active_level.get("side_path_lines", []) as Array
	var runtime_bounds: Rect2 = level_scene.get("runtime_play_bounds") as Rect2
	var exit_tile: Vector2i = level_scene.get("resolved_exit_tile") as Vector2i
	var seed_value: int = int(level_scene.get("active_level_seed"))

	print("INSPECT level=%d seed=%d title=%s path_valid=%s invalid_jumps=%d unreachable_rewards=%d unreachable_rooms=%d softlocks=%d trap_pits=%d repair=%s attempt=%d exit=%s bounds=%s" % [
		target_level + 1,
		seed_value,
		str(active_level.get("title", "")),
		str(bool(validation.get("path_valid", false))),
		int(validation.get("invalid_jump_count", 0)),
		int(validation.get("unreachable_reward_count", 0)),
		int(validation.get("unreachable_room_count", 0)),
		int(validation.get("softlock_surface_count", 0)),
		int(validation.get("trap_pit_count", 0)),
		str(bool(validation.get("repair_applied", false))),
		int(validation.get("attempt_index", -1)) + 1,
		str(exit_tile),
		str(runtime_bounds)
	])

	var mobility: Dictionary = active_level.get("mobility_profile", {}) as Dictionary
	print("MOBILITY max_jump_up=%d main_gap=%d wall_jump_up=%d wall_jump_gap=%d safe_drop=%d readable_drop=%d wall_slide=%s" % [
		int(mobility.get("max_jump_up_tiles", 0)),
		int(mobility.get("main_gap_tiles", 0)),
		int(mobility.get("wall_jump_up_tiles", 0)),
		int(mobility.get("wall_jump_gap_tiles", 0)),
		int(mobility.get("safe_drop_tiles", 0)),
		int(mobility.get("readable_drop_tiles", 0)),
		str(bool((mobility.get("skill_flags", {}) as Dictionary).get("wall_slide", false)))
	])

	var notes: PackedStringArray = validation.get("notes", PackedStringArray()) as PackedStringArray
	for note: String in notes:
		print("NOTE %s" % note)
	if not best_generated_validation.is_empty():
		print("BEST_GENERATED path=%s invalid_jumps=%d unreachable_rooms=%d trap_pits=%d dead_ends=%d branch_count=%d notes=%s" % [
			str(bool(best_generated_validation.get("path_valid", false))),
			int(best_generated_validation.get("invalid_jump_count", 0)),
			int(best_generated_validation.get("unreachable_room_count", 0)),
			int(best_generated_validation.get("trap_pit_count", 0)),
			int(best_generated_validation.get("dead_end_count", 0)),
			int(best_generated_validation.get("branch_count", 0)),
			str(best_generated_validation.get("notes", PackedStringArray()))
		])

	var invalid_edges: Array = validation.get("invalid_jump_edges", []) as Array
	for edge_variant: Variant in invalid_edges:
		var edge: Dictionary = edge_variant as Dictionary
		print("EDGE kind=%s from=%s to=%s" % [
			str(edge.get("kind", "")),
			str(edge.get("from", Vector2i.ZERO)),
			str(edge.get("to", Vector2i.ZERO))
		])

	print("CRITICAL_PATH %s" % str(critical_path))
	for line_index: int in range(side_paths.size()):
		print("SIDE_PATH[%d] %s" % [line_index, str(side_paths[line_index])])

	for room_variant: Variant in debug_rooms:
		var room: Dictionary = room_variant as Dictionary
		var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
		var entry_node: Vector2i = room.get("entry_node", Vector2i.ZERO) as Vector2i
		var exit_node: Vector2i = room.get("exit_node", Vector2i.ZERO) as Vector2i
		var platforms: Array = room.get("platforms", []) as Array
		var secondary: Array = room.get("secondary_platforms", []) as Array
		print("ROOM id=%s role=%s rect=%s entry=%s exit=%s platforms=%d secondary=%d host=%s path=%s primary=%s secondary_platforms=%s" % [
			str(room.get("id", "")),
			str(room.get("role", "")),
			str(rect),
			str(entry_node),
			str(exit_node),
			platforms.size(),
			secondary.size(),
			str(room.get("host_room_id", "")),
			str(room.get("path_nodes", [])),
			str(platforms),
			str(secondary)
		])

	level_scene.queue_free()
	await process_frame
	quit()


func _parse_args(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {}
	for arg: String in args:
		if not arg.contains("="):
			continue
		var parts: PackedStringArray = arg.split("=", false, 1)
		if parts.size() != 2:
			continue
		var key: String = parts[0].trim_prefix("--")
		options[key] = parts[1]
	return options
