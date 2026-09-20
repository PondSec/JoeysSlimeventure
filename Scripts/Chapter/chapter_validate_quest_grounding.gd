extends SceneTree

# Runtime regression check for quest-object placement.  Semantic quest anchors
# may move during terrain repair; every normal objective must consequently end
# up on a collision-backed floor, not at its original abstract path coordinate.

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")
const TILE_SIZE := 32.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progress := root.get_node("/root/ChapterProgress")
	progress.reset_progress()
	if not progress.start_chapter(1):
		_fail("could not start Chapter 1")
		return
	var level: Node = CHAPTER_LEVEL_SCENE.instantiate()
	root.add_child(level)
	await process_frame

	var runtime: Node = level.get_node_or_null("ChapterQuestRuntime")
	if runtime == null:
		_fail("quest runtime missing")
		return
	var grid: Array = level.get("solid_grid_cache") as Array
	var checked := 0
	for entry_variant: Variant in runtime.get("objects") as Array:
		var entry: Dictionary = entry_variant as Dictionary
		# Traversal/timing substeps intentionally form an aerial pattern.  Level 1
		# has no such substeps, and ordinary objectives are required to be grounded.
		if str(entry.get("kind", "")) in ["motion_sigil", "light_rune"]:
			continue
		var node: Node2D = entry.get("node") as Node2D
		var floor_cell: Vector2i = entry.get("floor_cell", Vector2i(-1, -1)) as Vector2i
		if node == null or not _has_grounded_footprint(grid, floor_cell):
			_fail("ungrounded target %s at %s" % [str(entry.get("anchor_id", "?")), str(node.global_position if node != null else Vector2.ZERO)])
			return
		checked += 1
	print("QUEST_GROUNDING level=1 targets=%d status=PASS" % checked)
	level.queue_free()
	await process_frame
	if not await _validate_resonance_bells(progress):
		return
	quit()


func _has_grounded_footprint(grid: Array, floor_cell: Vector2i) -> bool:
	if floor_cell.y < 3 or floor_cell.y >= grid.size() or floor_cell.x < 1:
		return false
	var support_count := 0
	for offset_x: int in range(-1, 2):
		if _is_solid(grid, floor_cell + Vector2i(offset_x, 0)):
			support_count += 1
		for offset_y: int in range(1, 4):
			if _is_solid(grid, floor_cell + Vector2i(offset_x, -offset_y)):
				return false
	return support_count == 3


func _is_solid(grid: Array, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= grid.size() or cell.x < 0:
		return false
	var row: PackedByteArray = grid[cell.y] as PackedByteArray
	return cell.x < row.size() and row[cell.x] == 1


func _validate_resonance_bells(progress: Node) -> bool:
	progress.active_level_index = 1
	var level: Node = CHAPTER_LEVEL_SCENE.instantiate()
	root.add_child(level)
	for _frame in range(3):
		await process_frame
		await physics_frame
	var runtime: Node = level.get_node_or_null("ChapterQuestRuntime")
	if runtime == null:
		_fail("level 2 quest runtime missing")
		return false
	var positions: Array[Vector2] = []
	var orders: Dictionary = {}
	for entry_variant: Variant in runtime.get("objects") as Array:
		var entry: Dictionary = entry_variant as Dictionary
		if not bool(entry.get("level_two_resonance", false)):
			continue
		var node: Node2D = entry.get("node") as Node2D
		if node == null:
			_fail("level 2 resonance bell missing node")
			return false
		positions.append(node.global_position)
		orders[int(entry.get("sequence_order", 0))] = true
	if positions.size() != 3 or orders.size() != 3 or not (orders.has(1) and orders.has(2) and orders.has(3)):
		_fail("level 2 requires three ordered resonance bells")
		return false
	for first_index: int in range(positions.size()):
		for second_index: int in range(first_index + 1, positions.size()):
			if positions[first_index].distance_to(positions[second_index]) < TILE_SIZE * 2.0:
				_fail("level 2 resonance bells overlap")
				return false
	print("QUEST_RESONANCE bells=%d status=PASS" % positions.size())
	level.queue_free()
	await process_frame
	return true


func _fail(reason: String) -> void:
	push_error("QUEST_GROUNDING status=FAIL reason=%s" % reason)
	quit(1)
