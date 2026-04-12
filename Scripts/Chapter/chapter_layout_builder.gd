class_name ChapterLayoutBuilder
extends RefCounted

const ROOM_ROLE_START := "start"
const ROOM_ROLE_INTRO := "intro"
const ROOM_ROLE_TRAVERSAL := "traversal"
const ROOM_ROLE_COMBAT := "combat"
const ROOM_ROLE_LANDMARK := "landmark"
const ROOM_ROLE_VERTICAL := "vertical"
const ROOM_ROLE_BRANCH := "branch"
const ROOM_ROLE_EXIT := "exit"
const ROOM_ROLE_BOSS := "boss"

const MAIN_JUMP_MAX_X_TILES := 6
const MAIN_JUMP_MAX_UP_TILES := 4
const MAIN_DROP_MAX_TILES := 6
const ROOM_MIN_WIDTH := 16
const ROOM_MAX_WIDTH := 28
const ROOM_MIN_HEIGHT := 12
const ROOM_MAX_HEIGHT := 20
const ROOM_OVERLAP_TILES := 4
const SHAFT_LEDGE_STEP_MIN := 3
const SHAFT_LEDGE_STEP_MAX := 4
const SHAFT_LEDGE_WIDTH := 5

var level_data: Dictionary = {}
var level_size: Vector2i = Vector2i.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var layout_style: String = "horizontal"
var main_rooms: Array = []
var side_rooms: Array = []
var generated_platforms: Array = []
var connection_platforms: Array = []
var critical_path_nodes: Array = []


static func build_level_layout(source_level_data: Dictionary, source_level_size: Vector2i, seed: int) -> Dictionary:
	var builder := new()
	return builder._build(source_level_data, source_level_size, seed)


func _build(source_level_data: Dictionary, source_level_size: Vector2i, seed: int) -> Dictionary:
	level_data = source_level_data.duplicate(true)
	level_size = source_level_size
	rng.seed = seed
	layout_style = _resolve_layout_style()
	main_rooms = _build_main_rooms(_collect_critical_nodes())
	side_rooms = _build_side_rooms(main_rooms, _pickup_budget())
	_generate_main_room_geometry()
	_generate_side_room_geometry()
	_build_connection_platforms()

	var grid: Array = _create_solid_grid()
	_carve_room_bodies(grid, main_rooms)
	_carve_room_bodies(grid, side_rooms)
	_carve_main_connections(grid)
	_carve_branch_connections(grid)
	_stamp_all_platforms(grid)
	_carve_platform_headroom(grid)
	_carve_pickup_pockets(grid)

	var normalized_pickups: Array = _place_pickups()
	var normalized_enemies: Array = _place_enemies()
	var normalized_hazards: Array = _place_hazards()
	var normalized_torches: Array = _place_torches()
	var normalized_triggers: Array = _place_triggers()
	var normalized_boss: Dictionary = _place_boss()
	var validation: Dictionary = _validate_layout(grid, normalized_pickups, normalized_enemies, normalized_hazards)

	var debug_rooms: Array = []
	for room_variant: Variant in main_rooms:
		debug_rooms.append((room_variant as Dictionary).duplicate(true))
	for room_variant: Variant in side_rooms:
		debug_rooms.append((room_variant as Dictionary).duplicate(true))

	return {
		"grid": grid,
		"spawn": _first_path_node(),
		"exit": _last_path_node(),
		"platforms": generated_platforms.duplicate(true),
		"pickups": normalized_pickups,
		"enemies": normalized_enemies,
		"hazards": normalized_hazards,
		"torches": normalized_torches,
		"triggers": normalized_triggers,
		"boss": normalized_boss,
		"worm_count": int(level_data.get("worm_count", 0)),
		"layout_validation": validation,
		"debug_rooms": debug_rooms,
		"critical_path_nodes": critical_path_nodes.duplicate(true)
	}


func _resolve_layout_style() -> String:
	if level_data.has("layout_style"):
		return str(level_data.get("layout_style", "horizontal"))
	if level_size.y >= 50:
		return "vertical"
	var spawn_tile: Vector2i = level_data.get("spawn", Vector2i(4, 28)) as Vector2i
	var exit_tile: Vector2i = level_data.get("exit", Vector2i(level_size.x - 8, level_size.y - 10)) as Vector2i
	if abs(exit_tile.y - spawn_tile.y) >= 18:
		return "vertical"
	return "horizontal"


func _collect_critical_nodes() -> Array:
	var nodes: Array = []
	var spawn_tile: Vector2i = level_data.get("spawn", Vector2i(4, 28)) as Vector2i
	nodes.append({
		"x": spawn_tile.x,
		"y": spawn_tile.y,
		"w": 8,
		"kind": "spawn"
	})

	var platforms: Array = level_data.get("platforms", []) as Array
	for platform_variant: Variant in platforms:
		var platform: Dictionary = platform_variant as Dictionary
		var style: String = str(platform.get("style", "stone"))
		var width_tiles: int = max(1, int(platform.get("w", 1)))
		if style == "floor" and width_tiles >= maxi(18, int(level_size.x * 0.3)):
			continue
		nodes.append({
			"x": int(platform.get("x", 0)) + int(width_tiles / 2),
			"y": int(platform.get("y", 0)),
			"w": width_tiles,
			"kind": style
		})

	var exit_tile: Vector2i = level_data.get("exit", Vector2i(level_size.x - 8, level_size.y - 10)) as Vector2i
	nodes.append({
		"x": exit_tile.x,
		"y": exit_tile.y,
		"w": 8,
		"kind": "exit"
	})
	return nodes


func _build_main_rooms(route_nodes: Array) -> Array:
	var clusters: Array = _cluster_route_nodes(route_nodes)
	var rooms: Array = []
	var room_count: int = clusters.size()
	var previous_end_x: int = 1
	for cluster_index: int in range(room_count):
		var cluster: Array = clusters[cluster_index] as Array
		var role: String = _pick_room_role(cluster_index, room_count, cluster)
		var room: Dictionary = _create_room_from_cluster(cluster, role, cluster_index, room_count, previous_end_x)
		rooms.append(room)
		var room_rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
		previous_end_x = room_rect.position.x + room_rect.size.x - ROOM_OVERLAP_TILES
	return rooms


func _cluster_route_nodes(route_nodes: Array) -> Array:
	var clusters: Array = []
	var current_cluster: Array = []
	var max_cluster_size: int = 1 if layout_style == "vertical" else 2
	var level_index: int = int(level_data.get("level_index", 0))
	for node_index: int in range(route_nodes.size()):
		var node: Dictionary = route_nodes[node_index] as Dictionary
		current_cluster.append(node)
		var desired_cluster_size: int = max_cluster_size
		if clusters.is_empty():
			desired_cluster_size = 1
		elif clusters.size() == 1 and level_index <= 1:
			desired_cluster_size = 1

		var close_cluster: bool = false
		if node_index == route_nodes.size() - 1:
			close_cluster = true
		else:
			var next_node: Dictionary = route_nodes[node_index + 1] as Dictionary
			var delta_x: int = abs(int(next_node.get("x", 0)) - int(node.get("x", 0)))
			var delta_y: int = abs(int(next_node.get("y", 0)) - int(node.get("y", 0)))
			if layout_style == "vertical":
				close_cluster = current_cluster.size() >= desired_cluster_size or delta_y >= 5 or delta_x >= 10
			else:
				close_cluster = current_cluster.size() >= desired_cluster_size or delta_x >= 14 or delta_y >= 5

		if close_cluster:
			clusters.append(current_cluster.duplicate(true))
			current_cluster.clear()

	if current_cluster.size() > 0:
		clusters.append(current_cluster.duplicate(true))
	return clusters


func _pick_room_role(cluster_index: int, room_count: int, cluster: Array) -> String:
	var level_index: int = int(level_data.get("level_index", 0))
	if cluster_index == 0:
		return ROOM_ROLE_START
	if cluster_index == room_count - 1:
		if level_data.has("boss"):
			return ROOM_ROLE_BOSS
		return ROOM_ROLE_EXIT

	var first_node: Dictionary = cluster.front() as Dictionary
	var last_node: Dictionary = cluster.back() as Dictionary
	var delta_y: int = abs(int(last_node.get("y", 0)) - int(first_node.get("y", 0)))
	if layout_style == "vertical" or delta_y >= 6:
		return ROOM_ROLE_VERTICAL
	if cluster_index == 1 and level_index <= 1:
		return ROOM_ROLE_INTRO
	if _enemy_budget() > 0 and cluster_index >= max(2, int(room_count / 3)) and (cluster_index % 2) == 1:
		return ROOM_ROLE_COMBAT
	if cluster_index == room_count - 2 or (cluster_index % 3) == 0:
		return ROOM_ROLE_LANDMARK
	return ROOM_ROLE_TRAVERSAL


func _create_room_from_cluster(cluster: Array, role: String, cluster_index: int, room_count: int, previous_end_x: int) -> Dictionary:
	var min_x: int = int((cluster.front() as Dictionary).get("x", 0))
	var max_x: int = min_x
	var min_y: int = int((cluster.front() as Dictionary).get("y", 0))
	var max_y: int = min_y
	for node_variant: Variant in cluster:
		var node: Dictionary = node_variant as Dictionary
		min_x = mini(min_x, int(node.get("x", 0)))
		max_x = maxi(max_x, int(node.get("x", 0)))
		min_y = mini(min_y, int(node.get("y", 0)))
		max_y = maxi(max_y, int(node.get("y", 0)))

	var width_tiles: int = clampi((max_x - min_x) + 14, ROOM_MIN_WIDTH, ROOM_MAX_WIDTH)
	var height_tiles: int = clampi((max_y - min_y) + 12, ROOM_MIN_HEIGHT, ROOM_MAX_HEIGHT)
	if role == ROOM_ROLE_LANDMARK:
		width_tiles = clampi(width_tiles + 1, ROOM_MIN_WIDTH + 2, ROOM_MAX_WIDTH)
		height_tiles = clampi(height_tiles + 1, 13, 17)
	elif role == ROOM_ROLE_COMBAT:
		width_tiles = clampi(width_tiles + 1, 18, ROOM_MAX_WIDTH)
		height_tiles = clampi(height_tiles, 13, 16)
	elif role == ROOM_ROLE_BOSS:
		width_tiles = maxi(32, width_tiles + 8)
		height_tiles = maxi(14, height_tiles)
	elif role == ROOM_ROLE_VERTICAL:
		width_tiles = clampi(maxi(14, width_tiles - 2), 14, 20)
		height_tiles = clampi(maxi(18, height_tiles + 4), 18, 28)
	elif role == ROOM_ROLE_START:
		width_tiles = clampi(width_tiles, 15, 18)
		height_tiles = clampi(height_tiles, 10, 12)
	elif role == ROOM_ROLE_INTRO:
		width_tiles = clampi(width_tiles, 17, 20)
		height_tiles = clampi(height_tiles, 11, 13)
	else:
		height_tiles = clampi(height_tiles, 11, 15)

	var avg_y: int = int(round(float(min_y + max_y) * 0.5))
	var rect_x: int = clampi(min_x - 6, previous_end_x, maxi(previous_end_x, level_size.x - width_tiles - 2))
	if cluster_index == room_count - 1:
		rect_x = mini(rect_x, level_size.x - width_tiles - 2)
	var rect_y: int = clampi(avg_y - int(height_tiles / 2), 2, level_size.y - height_tiles - 2)
	var room_rect := Rect2i(rect_x, rect_y, width_tiles, height_tiles)

	return {
		"id": "room_%d" % cluster_index,
		"index": cluster_index,
		"role": role,
		"rect": room_rect,
		"anchors": cluster.duplicate(true),
		"difficulty": float(cluster_index) / maxf(1.0, float(room_count - 1)),
		"platforms": [],
		"secondary_platforms": [],
		"air_slots": [],
		"ground_slots": [],
		"pickup_slots": [],
		"torch_slots": [],
		"hazard_slots": [],
		"entry_node": Vector2i.ZERO,
		"exit_node": Vector2i.ZERO,
		"branch_portal": Vector2i.ZERO
	}


func _build_side_rooms(host_rooms: Array, pickup_budget: int) -> Array:
	var branches: Array = []
	if pickup_budget <= 0 or host_rooms.size() < 3:
		return branches

	var branch_candidates: Array = []
	for room_variant: Variant in host_rooms:
		var room: Dictionary = room_variant as Dictionary
		var role: String = str(room.get("role", ""))
		if role == ROOM_ROLE_TRAVERSAL or role == ROOM_ROLE_COMBAT or role == ROOM_ROLE_LANDMARK:
			branch_candidates.append(room)

	var branch_count: int = mini(2, mini(pickup_budget, branch_candidates.size()))
	for branch_index: int in range(branch_count):
		var host_room: Dictionary = branch_candidates[branch_index] as Dictionary
		var host_rect: Rect2i = host_room.get("rect", Rect2i()) as Rect2i
		var branch_upward: bool = (branch_index % 2) == 0
		var branch_width: int = 11 + rng.randi_range(0, 2)
		var branch_height: int = 8 + rng.randi_range(0, 2)
		var branch_x: int = clampi(host_rect.position.x + int(host_rect.size.x * 0.55), 2, level_size.x - branch_width - 2)
		var branch_y: int = 2
		if branch_upward:
			branch_y = clampi(host_rect.position.y - branch_height - 3, 2, host_rect.position.y - 2)
		else:
			branch_y = clampi(host_rect.position.y + host_rect.size.y + 3, host_rect.position.y + 2, level_size.y - branch_height - 2)

		var branch_rect := Rect2i(branch_x, branch_y, branch_width, branch_height)
		branches.append({
			"id": "branch_%d" % branch_index,
			"index": host_rooms.size() + branch_index,
			"role": ROOM_ROLE_BRANCH,
			"rect": branch_rect,
			"difficulty": float(host_room.get("difficulty", 0.0)),
			"host_room_id": str(host_room.get("id", "")),
			"branch_upward": branch_upward,
			"platforms": [],
			"secondary_platforms": [],
			"air_slots": [],
			"ground_slots": [],
			"pickup_slots": [],
			"torch_slots": [],
			"hazard_slots": [],
			"entry_node": Vector2i.ZERO,
			"exit_node": Vector2i.ZERO
		})
	return branches


func _generate_main_room_geometry() -> void:
	var room_count: int = main_rooms.size()
	for room_index: int in range(room_count):
		var room: Dictionary = main_rooms[room_index] as Dictionary
		var previous_room: Dictionary = {}
		var next_room: Dictionary = {}
		if room_index > 0:
			previous_room = main_rooms[room_index - 1] as Dictionary
		if room_index + 1 < room_count:
			next_room = main_rooms[room_index + 1] as Dictionary

		var entry_y: int = int((room.get("anchors", []) as Array).front().get("y", 0))
		var exit_y: int = int((room.get("anchors", []) as Array).back().get("y", 0))
		if not previous_room.is_empty():
			entry_y = int((previous_room.get("exit_node", Vector2i.ZERO) as Vector2i).y)
		if not next_room.is_empty():
			exit_y = int((next_room.get("anchors", []) as Array).front().get("y", exit_y))

		if str(room.get("role", "")) == ROOM_ROLE_VERTICAL:
			_populate_vertical_room(room, entry_y, exit_y)
		elif str(room.get("role", "")) == ROOM_ROLE_BOSS:
			_populate_boss_room(room)
		else:
			_populate_horizontal_room(room, entry_y, exit_y)
		main_rooms[room_index] = room

func _generate_side_room_geometry() -> void:
	for branch_index: int in range(side_rooms.size()):
		var branch_room: Dictionary = side_rooms[branch_index] as Dictionary
		var host_room_id: String = str(branch_room.get("host_room_id", ""))
		var host_room: Dictionary = _find_room_by_id(main_rooms, host_room_id)
		if host_room.is_empty():
			continue
		_populate_branch_room(branch_room, host_room)
		side_rooms[branch_index] = branch_room


func _populate_horizontal_room(room: Dictionary, entry_y: int, exit_y: int) -> void:
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var role: String = str(room.get("role", ROOM_ROLE_TRAVERSAL))
	var left_x: int = rect.position.x + 3
	var right_x: int = rect.position.x + rect.size.x - 4
	var floor_range: Vector2i = _horizontal_floor_range(rect, role)
	var min_y: int = floor_range.x
	var max_y: int = floor_range.y
	var start_y: int = clampi(entry_y, min_y, max_y)
	var end_y: int = clampi(exit_y, min_y, max_y)
	if role == ROOM_ROLE_START:
		start_y = maxi(min_y, max_y - 1)
		end_y = maxi(min_y, max_y - 2)
	elif role == ROOM_ROLE_EXIT:
		start_y = clampi(start_y, max_y - 1, max_y)
		end_y = maxi(min_y, max_y - 1)
	elif role == ROOM_ROLE_INTRO:
		start_y = clampi(start_y, max_y - 1, max_y)
		end_y = clampi(end_y, max_y - 2, max_y - 1)

	var path_nodes: Array = []
	if role == ROOM_ROLE_START:
		path_nodes = _densify_path_nodes([
			Vector2i(left_x, start_y),
			Vector2i(rect.position.x + int(rect.size.x * 0.38), start_y),
			Vector2i(rect.position.x + int(rect.size.x * 0.68), end_y),
			Vector2i(right_x, end_y)
		])
	elif role == ROOM_ROLE_INTRO:
		path_nodes = _densify_path_nodes([
			Vector2i(left_x, start_y),
			Vector2i(rect.position.x + int(rect.size.x * 0.3), start_y),
			Vector2i(rect.position.x + int(rect.size.x * 0.56), maxi(min_y, end_y)),
			Vector2i(right_x - 2, end_y),
			Vector2i(right_x, end_y)
		])
	else:
		var segment_count: int = maxi(3, int(ceil(float(right_x - left_x) / 7.0)))
		path_nodes.append(Vector2i(left_x, start_y))
		var previous_y: int = start_y
		for segment_index: int in range(1, segment_count):
			var t: float = float(segment_index) / float(segment_count)
			var node_x: int = int(round(lerpf(float(left_x + 3), float(right_x - 3), t)))
			var baseline_y: int = int(round(lerpf(float(start_y), float(end_y), t)))
			var y_variation: int = _horizontal_profile_variation(role, segment_index)
			var node_y: int = clampi(baseline_y + y_variation, min_y, max_y)
			node_y = _clamp_step_y(previous_y, node_y, role)
			path_nodes.append(Vector2i(node_x, node_y))
			previous_y = node_y
		path_nodes.append(Vector2i(right_x, end_y))
	path_nodes = _densify_path_nodes(path_nodes)

	var primary_platforms: Array = _platforms_from_path_nodes(path_nodes, role)
	var secondary_platforms: Array = []
	var pickup_slots: Array = []
	var mid_node: Vector2i = path_nodes[int(path_nodes.size() / 2)] as Vector2i
	match role:
		ROOM_ROLE_INTRO:
			secondary_platforms.append(_make_wall_ledge(rect, false, clampi(mid_node.y - 3, rect.position.y + 4, max_y - 2), 4))
		ROOM_ROLE_TRAVERSAL:
			if rect.size.x >= 18:
				var attach_left: bool = (int(room.get("index", 0)) % 2) == 0
				secondary_platforms.append(_make_wall_ledge(rect, attach_left, clampi(mid_node.y - 3, rect.position.y + 4, max_y - 2), 4))
		ROOM_ROLE_COMBAT:
			var center_y: int = clampi(mid_node.y - 4, rect.position.y + 4, max_y - 2)
			secondary_platforms.append(_make_platform(mid_node.x - 3, center_y, 6, 1, "ledge"))
			secondary_platforms.append(_make_wall_ledge(rect, true, clampi(center_y + 1, rect.position.y + 4, max_y - 1), 4))
		ROOM_ROLE_LANDMARK:
			var shelf_y: int = clampi(mid_node.y - 4, rect.position.y + 4, max_y - 2)
			secondary_platforms.append(_make_wall_ledge(rect, false, shelf_y, 5))
			pickup_slots = [Vector2i(rect.position.x + rect.size.x - 5, shelf_y - 1)]
		ROOM_ROLE_EXIT:
			secondary_platforms.append(_make_wall_ledge(rect, false, clampi(path_nodes.back().y - 2, rect.position.y + 4, max_y - 1), 4))
	if role == ROOM_ROLE_START:
		primary_platforms[0] = _make_platform(maxi(rect.position.x + 2, left_x - 2), start_y, 9, 1, "floor")
	elif role == ROOM_ROLE_EXIT:
		var exit_platform_x: int = maxi(rect.position.x + rect.size.x - 10, rect.position.x + 2)
		var exit_platform_y: int = clampi(path_nodes[path_nodes.size() - 1].y, min_y, max_y)
		primary_platforms[primary_platforms.size() - 1] = _make_platform(exit_platform_x, exit_platform_y, 8, 1, "ledge")

	room["path_nodes"] = path_nodes
	room["platforms"] = primary_platforms
	room["secondary_platforms"] = secondary_platforms
	room["entry_node"] = path_nodes.front()
	room["exit_node"] = path_nodes.back()
	room["ground_slots"] = _room_ground_slots(primary_platforms, secondary_platforms, role)
	room["air_slots"] = _room_air_slots(rect, path_nodes, role)
	room["torch_slots"] = _room_torch_slots(rect, path_nodes, role)
	room["hazard_slots"] = _room_hazard_slots(rect, path_nodes, role)
	room["pickup_slots"] = pickup_slots
	room["branch_portal"] = Vector2i(rect.position.x + int(rect.size.x * 0.62), clampi(path_nodes[int(path_nodes.size() / 2)].y - 2, rect.position.y + 2, rect.position.y + rect.size.y - 5))


func _populate_vertical_room(room: Dictionary, entry_y: int, exit_y: int) -> void:
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var bottom_y: int = rect.position.y + rect.size.y - 4
	var top_y: int = rect.position.y + 4
	var path_nodes: Array = []
	var platforms: Array = []

	var base_floor_x: int = rect.position.x + 2
	var base_floor_width: int = rect.size.x - 4
	var clamped_entry_y: int = clampi(entry_y, top_y, bottom_y)
	path_nodes.append(Vector2i(base_floor_x + int(base_floor_width / 2), clamped_entry_y))
	platforms.append(_make_platform(base_floor_x, clamped_entry_y, base_floor_width, 2, "floor"))

	var current_y: int = bottom_y - 4
	var on_left_wall: bool = true
	while current_y > top_y:
		var ledge_x: int = rect.position.x + 2 if on_left_wall else rect.position.x + rect.size.x - SHAFT_LEDGE_WIDTH - 2
		var ledge_y: int = clampi(current_y, top_y, bottom_y)
		platforms.append(_make_platform(ledge_x, ledge_y, SHAFT_LEDGE_WIDTH, 1, "ledge"))
		path_nodes.append(Vector2i(ledge_x + int(SHAFT_LEDGE_WIDTH / 2), ledge_y))
		current_y -= rng.randi_range(SHAFT_LEDGE_STEP_MIN, SHAFT_LEDGE_STEP_MAX)
		on_left_wall = not on_left_wall

	var exit_width: int = 8
	var exit_x: int = rect.position.x + rect.size.x - exit_width - 2
	var exit_y_clamped: int = clampi(exit_y, top_y, rect.position.y + 7)
	platforms.append(_make_platform(exit_x, exit_y_clamped, exit_width, 1, "ledge"))
	path_nodes.append(Vector2i(exit_x + int(exit_width / 2), exit_y_clamped))
	path_nodes = _densify_path_nodes(path_nodes)

	room["path_nodes"] = path_nodes
	room["platforms"] = platforms
	room["secondary_platforms"] = []
	room["entry_node"] = path_nodes.front()
	room["exit_node"] = path_nodes.back()
	room["ground_slots"] = _room_ground_slots(platforms, [], ROOM_ROLE_VERTICAL)
	room["air_slots"] = []
	room["pickup_slots"] = [Vector2i(rect.position.x + int(rect.size.x / 2), rect.position.y + int(rect.size.y * 0.45))]
	room["torch_slots"] = [
		Vector2i(rect.position.x + 2, rect.position.y + 5),
		Vector2i(rect.position.x + rect.size.x - 3, rect.position.y + int(rect.size.y * 0.55))
	]
	room["hazard_slots"] = []
	room["branch_portal"] = Vector2i(rect.position.x + int(rect.size.x * 0.65), rect.position.y + int(rect.size.y * 0.42))


func _populate_branch_room(branch_room: Dictionary, host_room: Dictionary) -> void:
	var rect: Rect2i = branch_room.get("rect", Rect2i()) as Rect2i
	var host_portal: Vector2i = host_room.get("branch_portal", Vector2i.ZERO) as Vector2i
	var entry_x: int = rect.position.x + 3
	var entry_y: int = rect.position.y + rect.size.y - 4
	if bool(branch_room.get("branch_upward", true)):
		entry_y = rect.position.y + rect.size.y - 4
	else:
		entry_y = rect.position.y + 3
	var main_platform_y: int = rect.position.y + rect.size.y - 4
	if not bool(branch_room.get("branch_upward", true)):
		main_platform_y = rect.position.y + 3
	var platforms: Array = [
		_make_platform(rect.position.x + 2, main_platform_y, rect.size.x - 4, 1, "ledge")
	]
	var pickup_x: int = rect.position.x + int(rect.size.x * 0.68)
	var pickup_y: int = main_platform_y - 1 if bool(branch_room.get("branch_upward", true)) else main_platform_y + 1

	branch_room["path_nodes"] = [Vector2i(entry_x, entry_y), Vector2i(rect.position.x + rect.size.x - 3, main_platform_y)]
	branch_room["path_nodes"] = _densify_path_nodes(branch_room["path_nodes"] as Array)
	branch_room["platforms"] = platforms
	branch_room["secondary_platforms"] = []
	branch_room["entry_node"] = Vector2i(entry_x, entry_y)
	branch_room["exit_node"] = branch_room.get("path_nodes", []).back()
	branch_room["ground_slots"] = _room_ground_slots(platforms, [], ROOM_ROLE_BRANCH)
	branch_room["air_slots"] = []
	branch_room["pickup_slots"] = [Vector2i(pickup_x, pickup_y)]
	branch_room["torch_slots"] = [Vector2i(rect.position.x + 2, rect.position.y + int(rect.size.y / 2))]
	branch_room["hazard_slots"] = []
	branch_room["host_portal"] = host_portal


func _populate_boss_room(room: Dictionary) -> void:
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var floor_y: int = rect.position.y + rect.size.y - 4
	var left_platform := _make_platform(rect.position.x + 2, floor_y, rect.size.x - 4, 3, "floor")
	var left_pillar := _make_platform(rect.position.x + 6, floor_y - 6, 8, 1, "ledge")
	var right_pillar := _make_platform(rect.position.x + rect.size.x - 14, floor_y - 6, 8, 1, "ledge")
	var path_nodes: Array = _densify_path_nodes([
		Vector2i(rect.position.x + 6, floor_y),
		Vector2i(rect.position.x + int(rect.size.x / 2), floor_y),
		Vector2i(rect.position.x + rect.size.x - 7, floor_y)
	])

	room["path_nodes"] = path_nodes
	room["platforms"] = [left_platform, left_pillar, right_pillar]
	room["secondary_platforms"] = []
	room["entry_node"] = path_nodes.front()
	room["exit_node"] = path_nodes.back()
	room["ground_slots"] = _room_ground_slots(room.get("platforms", []) as Array, [], ROOM_ROLE_BOSS)
	room["air_slots"] = [Vector2i(rect.position.x + int(rect.size.x / 2), floor_y - 5)]
	room["pickup_slots"] = []
	room["torch_slots"] = [
		Vector2i(rect.position.x + 4, floor_y - 5),
		Vector2i(rect.position.x + rect.size.x - 5, floor_y - 5)
	]
	room["hazard_slots"] = [
		Vector2i(rect.position.x + 15, floor_y - 1),
		Vector2i(rect.position.x + rect.size.x - 18, floor_y - 1)
	]
	room["branch_portal"] = Vector2i.ZERO


func _horizontal_floor_range(rect: Rect2i, role: String) -> Vector2i:
	var top_ratio: float = 0.58
	match role:
		ROOM_ROLE_START:
			top_ratio = 0.68
		ROOM_ROLE_INTRO:
			top_ratio = 0.64
		ROOM_ROLE_COMBAT:
			top_ratio = 0.54
		ROOM_ROLE_LANDMARK:
			top_ratio = 0.52
		ROOM_ROLE_EXIT:
			top_ratio = 0.6
	var min_y: int = clampi(rect.position.y + int(round(rect.size.y * top_ratio)), rect.position.y + 4, rect.position.y + rect.size.y - 6)
	var max_y: int = clampi(rect.position.y + rect.size.y - 4, min_y + 1, rect.position.y + rect.size.y - 3)
	return Vector2i(min_y, max_y)


func _make_wall_ledge(rect: Rect2i, attach_left: bool, y: int, width_tiles: int) -> Dictionary:
	var ledge_x: int = rect.position.x + 2 if attach_left else rect.position.x + rect.size.x - width_tiles - 2
	return _make_platform(ledge_x, y, width_tiles, 1, "ledge")


func _horizontal_profile_variation(role: String, segment_index: int) -> int:
	var pattern: Array = []
	match role:
		ROOM_ROLE_START:
			pattern = [0, 0, -1, 0]
		ROOM_ROLE_INTRO:
			pattern = [0, 0, -1, 0, -1]
		ROOM_ROLE_TRAVERSAL:
			pattern = [0, -1, 0, 1, 0, -1]
		ROOM_ROLE_COMBAT:
			pattern = [0, 0, -1, 0, 1, 0]
		ROOM_ROLE_LANDMARK:
			pattern = [-1, -2, -1, 0, -1]
		ROOM_ROLE_EXIT:
			pattern = [0, 0, 0, -1, 0]
		_:
			pattern = [0, -1, 0, 1, 0]
	if pattern.is_empty():
		return 0
	return int(pattern[segment_index % pattern.size()])


func _clamp_step_y(previous_y: int, desired_y: int, role: String) -> int:
	var allowed_step: int = MAIN_JUMP_MAX_UP_TILES
	if role == ROOM_ROLE_START or role == ROOM_ROLE_INTRO:
		allowed_step = 3
	elif role == ROOM_ROLE_VERTICAL:
		allowed_step = 4
	var delta: int = desired_y - previous_y
	if delta > MAIN_DROP_MAX_TILES:
		return previous_y + MAIN_DROP_MAX_TILES
	if delta < -allowed_step:
		return previous_y - allowed_step
	return desired_y


func _platforms_from_path_nodes(path_nodes: Array, role: String) -> Array:
	var platforms: Array = []
	var cursor: int = 0
	while cursor < path_nodes.size():
		var start_node: Vector2i = path_nodes[cursor] as Vector2i
		var end_node: Vector2i = start_node
		while cursor + 1 < path_nodes.size():
			var next_node: Vector2i = path_nodes[cursor + 1] as Vector2i
			if next_node.y != end_node.y:
				break
			if next_node.x - end_node.x > 7:
				break
			cursor += 1
			end_node = next_node
		var width_tiles: int = maxi(4, (end_node.x - start_node.x) + 4)
		var style: String = "floor" if role == ROOM_ROLE_START and platforms.is_empty() else "ledge"
		platforms.append(_make_platform(start_node.x - 2, start_node.y, width_tiles, 1, style))
		cursor += 1
	return platforms


func _room_ground_slots(primary_platforms: Array, secondary_platforms: Array, role: String) -> Array:
	var slots: Array = []
	for platform_variant: Variant in primary_platforms:
		var platform: Dictionary = platform_variant as Dictionary
		var width_tiles: int = int(platform.get("w", 1))
		if role == ROOM_ROLE_START and str(platform.get("style", "")) == "floor":
			continue
		if width_tiles < 4:
			continue
		slots.append(Vector2i(int(platform.get("x", 0)) + int(width_tiles / 2), int(platform.get("y", 0)) - 1))
	for platform_variant: Variant in secondary_platforms:
		var platform: Dictionary = platform_variant as Dictionary
		slots.append(Vector2i(int(platform.get("x", 0)) + int(int(platform.get("w", 1)) / 2), int(platform.get("y", 0)) - 1))
	return slots


func _room_air_slots(rect: Rect2i, path_nodes: Array, role: String) -> Array:
	var slots: Array = []
	if role != ROOM_ROLE_COMBAT and role != ROOM_ROLE_LANDMARK and role != ROOM_ROLE_BOSS:
		return slots
	if path_nodes.is_empty():
		return slots
	var mid_node: Vector2i = path_nodes[int(path_nodes.size() / 2)] as Vector2i
	var high_y: int = clampi(mid_node.y - 5, rect.position.y + 3, rect.position.y + int(rect.size.y * 0.55))
	slots.append(Vector2i(mid_node.x, high_y))
	if role == ROOM_ROLE_COMBAT:
		slots.append(Vector2i(rect.position.x + int(rect.size.x * 0.72), clampi(high_y - 1, rect.position.y + 3, high_y)))
	return slots


func _room_torch_slots(rect: Rect2i, path_nodes: Array, role: String) -> Array:
	var slots: Array = []
	if path_nodes.is_empty():
		return slots
	var first_node: Vector2i = path_nodes.front() as Vector2i
	var last_node: Vector2i = path_nodes.back() as Vector2i
	slots.append(Vector2i(rect.position.x + 2, clampi(first_node.y - 3, rect.position.y + 2, rect.position.y + rect.size.y - 5)))
	if role == ROOM_ROLE_START or role == ROOM_ROLE_INTRO:
		slots.append(Vector2i(rect.position.x + int(rect.size.x * 0.48), clampi(first_node.y - 4, rect.position.y + 2, rect.position.y + rect.size.y - 5)))
	elif role != ROOM_ROLE_START:
		slots.append(Vector2i(rect.position.x + rect.size.x - 3, clampi(last_node.y - 3, rect.position.y + 2, rect.position.y + rect.size.y - 5)))
	if role == ROOM_ROLE_LANDMARK or role == ROOM_ROLE_COMBAT:
		slots.append(Vector2i(rect.position.x + int(rect.size.x * 0.58), clampi(int((first_node.y + last_node.y) / 2) - 4, rect.position.y + 2, rect.position.y + rect.size.y - 5)))
	return slots


func _room_hazard_slots(rect: Rect2i, path_nodes: Array, role: String) -> Array:
	var slots: Array = []
	if role == ROOM_ROLE_START or role == ROOM_ROLE_INTRO or role == ROOM_ROLE_BOSS:
		return slots
	for node_index: int in range(path_nodes.size() - 1):
		var from_node: Vector2i = path_nodes[node_index] as Vector2i
		var to_node: Vector2i = path_nodes[node_index + 1] as Vector2i
		var gap: int = to_node.x - from_node.x
		if gap < 7:
			continue
		var hazard_x: int = from_node.x + int(gap / 2) - 1
		var hazard_y: int = rect.position.y + rect.size.y - 2
		slots.append(Vector2i(hazard_x, hazard_y))
	return slots


func _make_platform(x: int, y: int, width_tiles: int, height_tiles: int, style: String) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"w": width_tiles,
		"h": height_tiles,
		"style": style
	}


func _create_solid_grid() -> Array:
	var grid: Array = []
	for _row_index: int in range(level_size.y):
		var row := PackedByteArray()
		row.resize(level_size.x)
		for cell_index: int in range(level_size.x):
			row[cell_index] = 1
		grid.append(row)
	return grid


func _carve_room_bodies(grid: Array, rooms: Array) -> void:
	for room_variant: Variant in rooms:
		var room: Dictionary = room_variant as Dictionary
		var role: String = str(room.get("role", ROOM_ROLE_TRAVERSAL))
		if role == ROOM_ROLE_VERTICAL:
			_carve_vertical_body(grid, room)
		else:
			_carve_horizontal_body(grid, room)


func _carve_horizontal_body(grid: Array, room: Dictionary) -> void:
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var role: String = str(room.get("role", ROOM_ROLE_TRAVERSAL))
	var path_nodes: Array = room.get("path_nodes", []) as Array
	var fallback_path_y: int = rect.position.y + rect.size.y - 4
	for local_x: int in range(rect.size.x):
		var world_x: int = rect.position.x + local_x
		var path_y: int = _path_height_at_x(path_nodes, world_x, fallback_path_y)
		var normalized: float = float(local_x) / maxf(1.0, float(rect.size.x - 1))
		var dome_factor: float = 1.0 - minf(1.0, absf(normalized - 0.5) * 2.0)
		var ceiling_wave: float = sin(normalized * PI * 2.1 + 0.35) * 0.9
		var floor_wave: float = sin(normalized * PI * 1.7 + 1.1) * 0.45
		var ceiling_clearance: int = 6
		var floor_padding: int = 1
		if role == ROOM_ROLE_START or role == ROOM_ROLE_INTRO:
			ceiling_clearance = 5
		elif role == ROOM_ROLE_COMBAT:
			ceiling_clearance = 6
			floor_padding = 2
		elif role == ROOM_ROLE_LANDMARK:
			ceiling_clearance = 7
			floor_padding = 2
		elif role == ROOM_ROLE_EXIT:
			ceiling_clearance = 5
		var top: int = path_y - ceiling_clearance - int(round(ceiling_wave))
		if role == ROOM_ROLE_COMBAT or role == ROOM_ROLE_LANDMARK:
			top -= int(round(dome_factor * 2.0))
		elif role == ROOM_ROLE_START or role == ROOM_ROLE_INTRO:
			top += int(round((1.0 - dome_factor) * 1.5))
		var shoulder_depth: int = 0
		if local_x <= 2 or local_x >= rect.size.x - 3:
			shoulder_depth = 2
		elif local_x <= 4 or local_x >= rect.size.x - 5:
			shoulder_depth = 1
		top += shoulder_depth
		var bottom: int = path_y + floor_padding + int(round(maxf(0.0, floor_wave)))
		if role == ROOM_ROLE_LANDMARK and dome_factor > 0.6:
			bottom += 1
		top = clampi(top, rect.position.y + 1, rect.position.y + rect.size.y - 6)
		bottom = clampi(bottom, top + 5, rect.position.y + rect.size.y - 2)
		_carve_column(grid, world_x, top, bottom)

	_carve_rect(grid, rect.position.x + 1, path_nodes.front().y - 3, 4, 4)
	_carve_rect(grid, rect.position.x + rect.size.x - 5, path_nodes.back().y - 3, 4, 4)

	if role == ROOM_ROLE_TRAVERSAL or role == ROOM_ROLE_COMBAT or role == ROOM_ROLE_LANDMARK:
		var alcove_x: int = rect.position.x + int(rect.size.x * 0.28)
		var alcove_y: int = _path_height_at_x(path_nodes, alcove_x, fallback_path_y) - 7
		_carve_rect(grid, alcove_x - 1, alcove_y, 4, 3)
	if role == ROOM_ROLE_LANDMARK:
		var second_alcove_x: int = rect.position.x + int(rect.size.x * 0.72)
		var second_alcove_y: int = _path_height_at_x(path_nodes, second_alcove_x, fallback_path_y) - 8
		_carve_rect(grid, second_alcove_x - 1, second_alcove_y, 4, 4)


func _carve_vertical_body(grid: Array, room: Dictionary) -> void:
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var path_nodes: Array = room.get("path_nodes", []) as Array
	var fallback_center_x: int = rect.position.x + int(rect.size.x / 2)
	for local_y: int in range(rect.size.y):
		var world_y: int = rect.position.y + local_y
		var normalized: float = float(local_y) / maxf(1.0, float(rect.size.y - 1))
		var shaft_center_x: int = _vertical_path_center_x(path_nodes, world_y, fallback_center_x)
		var half_width: int = 4 + int(absf(sin(normalized * PI * 2.1 + 0.2)) * 1.5)
		var left_x: int = clampi(shaft_center_x - half_width, rect.position.x + 2, rect.position.x + rect.size.x - 8)
		var right_x: int = clampi(shaft_center_x + half_width, left_x + 6, rect.position.x + rect.size.x - 2)
		_carve_rect(grid, left_x, world_y, right_x - left_x + 1, 1)

	for recess_index: int in range(2):
		var recess_y: int = rect.position.y + 4 + recess_index * int(rect.size.y * 0.36)
		_carve_rect(grid, rect.position.x + 2, recess_y, 3, 3)
		_carve_rect(grid, rect.position.x + rect.size.x - 5, recess_y + 1, 3, 3)


func _build_connection_platforms() -> void:
	connection_platforms.clear()
	critical_path_nodes.clear()

	for room_index: int in range(main_rooms.size()):
		var room: Dictionary = main_rooms[room_index] as Dictionary
		var room_path_nodes: Array = room.get("path_nodes", []) as Array
		for path_node_variant: Variant in room_path_nodes:
			var path_node: Vector2i = path_node_variant as Vector2i
			if critical_path_nodes.is_empty() or critical_path_nodes.back() != path_node:
				critical_path_nodes.append(path_node)

		if room_index >= main_rooms.size() - 1:
			continue

		var next_room: Dictionary = main_rooms[room_index + 1] as Dictionary
		var from_node: Vector2i = room.get("exit_node", Vector2i.ZERO) as Vector2i
		var to_node: Vector2i = next_room.get("entry_node", Vector2i.ZERO) as Vector2i
		var bridge_nodes: Array = _build_bridge_nodes(from_node, to_node)
		for bridge_variant: Variant in bridge_nodes:
			var bridge_node: Vector2i = bridge_variant as Vector2i
			connection_platforms.append(_make_platform(bridge_node.x - 2, bridge_node.y, 5, 1, "ledge"))
			if critical_path_nodes.is_empty() or critical_path_nodes.back() != bridge_node:
				critical_path_nodes.append(bridge_node)


func _build_bridge_nodes(from_node: Vector2i, to_node: Vector2i) -> Array:
	var nodes: Array = []
	var current: Vector2i = from_node
	var guard: int = 0
	while abs(to_node.x - current.x) > MAIN_JUMP_MAX_X_TILES or abs(to_node.y - current.y) > MAIN_DROP_MAX_TILES:
		var horizontal_step: int = clampi(to_node.x - current.x, -5, 5)
		if abs(horizontal_step) < 3:
			horizontal_step = 3 if to_node.x >= current.x else -3
		var vertical_step: int = clampi(to_node.y - current.y, -3, 4)
		current = Vector2i(current.x + horizontal_step, current.y + vertical_step)
		nodes.append(current)
		guard += 1
		if guard >= 12:
			break
	return nodes


func _densify_path_nodes(path_nodes: Array) -> Array:
	if path_nodes.size() <= 1:
		return path_nodes

	var densified: Array = [path_nodes.front()]
	for node_index: int in range(1, path_nodes.size()):
		var target: Vector2i = path_nodes[node_index] as Vector2i
		var current: Vector2i = densified.back() as Vector2i
		while abs(target.x - current.x) > MAIN_JUMP_MAX_X_TILES or abs(target.y - current.y) > MAIN_DROP_MAX_TILES:
			var horizontal_step: int = clampi(target.x - current.x, -5, 5)
			if abs(horizontal_step) < 3 and target.x != current.x:
				horizontal_step = 3 if target.x > current.x else -3
			var vertical_step: int = clampi(target.y - current.y, -3, 4)
			current = Vector2i(current.x + horizontal_step, current.y + vertical_step)
			densified.append(current)
		if densified.back() != target:
			densified.append(target)
	return densified


func _carve_main_connections(grid: Array) -> void:
	for room_index: int in range(main_rooms.size() - 1):
		var from_room: Dictionary = main_rooms[room_index] as Dictionary
		var to_room: Dictionary = main_rooms[room_index + 1] as Dictionary
		var from_node: Vector2i = from_room.get("exit_node", Vector2i.ZERO) as Vector2i
		var to_node: Vector2i = to_room.get("entry_node", Vector2i.ZERO) as Vector2i
		var tunnel_width: int = 4 if str(from_room.get("role", "")) == ROOM_ROLE_VERTICAL or str(to_room.get("role", "")) == ROOM_ROLE_VERTICAL else 3
		_carve_tunnel(grid, from_node, to_node, tunnel_width)


func _carve_branch_connections(grid: Array) -> void:
	for branch_variant: Variant in side_rooms:
		var branch_room: Dictionary = branch_variant as Dictionary
		var host_room: Dictionary = _find_room_by_id(main_rooms, str(branch_room.get("host_room_id", "")))
		if host_room.is_empty():
			continue
		var from_node: Vector2i = host_room.get("branch_portal", Vector2i.ZERO) as Vector2i
		var to_node: Vector2i = branch_room.get("entry_node", Vector2i.ZERO) as Vector2i
		_carve_tunnel(grid, from_node, to_node, 3)


func _carve_tunnel(grid: Array, from_node: Vector2i, to_node: Vector2i, width_tiles: int) -> void:
	var current_x: int = from_node.x
	var current_y: int = from_node.y
	var step_x: int = 1 if to_node.x >= current_x else -1
	while current_x != to_node.x:
		_carve_rect(grid, current_x - 1, current_y - int(width_tiles / 2), width_tiles, width_tiles)
		current_x += step_x

	var step_y: int = 1 if to_node.y >= current_y else -1
	while current_y != to_node.y:
		_carve_rect(grid, current_x - int(width_tiles / 2), current_y - 1, width_tiles, width_tiles)
		current_y += step_y

	_carve_rect(grid, to_node.x - int(width_tiles / 2), to_node.y - int(width_tiles / 2), width_tiles, width_tiles)


func _stamp_all_platforms(grid: Array) -> void:
	generated_platforms.clear()
	for room_variant: Variant in main_rooms:
		var room: Dictionary = room_variant as Dictionary
		_stamp_room_platforms(grid, room)
	for room_variant: Variant in side_rooms:
		var room: Dictionary = room_variant as Dictionary
		_stamp_room_platforms(grid, room)
	for platform_variant: Variant in connection_platforms:
		var platform: Dictionary = platform_variant as Dictionary
		generated_platforms.append(platform.duplicate(true))
		_stamp_rect(grid, int(platform.get("x", 0)), int(platform.get("y", 0)), max(1, int(platform.get("w", 1))), max(1, int(platform.get("h", 1))))


func _stamp_room_platforms(grid: Array, room: Dictionary) -> void:
	var room_platforms: Array = room.get("platforms", []) as Array
	for platform_variant: Variant in room_platforms:
		var platform: Dictionary = platform_variant as Dictionary
		generated_platforms.append(platform.duplicate(true))
		_stamp_rect(grid, int(platform.get("x", 0)), int(platform.get("y", 0)), max(1, int(platform.get("w", 1))), max(1, int(platform.get("h", 1))))

	var secondary_platforms: Array = room.get("secondary_platforms", []) as Array
	for platform_variant: Variant in secondary_platforms:
		var platform: Dictionary = platform_variant as Dictionary
		generated_platforms.append(platform.duplicate(true))
		_stamp_rect(grid, int(platform.get("x", 0)), int(platform.get("y", 0)), max(1, int(platform.get("w", 1))), max(1, int(platform.get("h", 1))))


func _carve_platform_headroom(grid: Array) -> void:
	for platform_variant: Variant in generated_platforms:
		var platform: Dictionary = platform_variant as Dictionary
		var style: String = str(platform.get("style", "ledge"))
		var headroom: int = 5 if style == "floor" else 4
		_carve_rect(grid, int(platform.get("x", 0)) - 1, int(platform.get("y", 0)) - headroom, int(platform.get("w", 1)) + 2, headroom)


func _carve_pickup_pockets(grid: Array) -> void:
	for room_variant: Variant in side_rooms:
		var room: Dictionary = room_variant as Dictionary
		var pickup_slots: Array = room.get("pickup_slots", []) as Array
		for slot_variant: Variant in pickup_slots:
			var slot: Vector2i = slot_variant as Vector2i
			_carve_rect(grid, slot.x - 2, slot.y - 3, 5, 4)


func _carve_rect(grid: Array, x: int, y: int, width_tiles: int, height_tiles: int) -> void:
	if width_tiles <= 0 or height_tiles <= 0:
		return
	var start_x: int = maxi(0, x)
	var end_x: int = mini(level_size.x, x + width_tiles)
	var start_y: int = maxi(0, y)
	var end_y: int = mini(level_size.y, y + height_tiles)
	for grid_y: int in range(start_y, end_y):
		var row: PackedByteArray = grid[grid_y] as PackedByteArray
		for grid_x: int in range(start_x, end_x):
			row[grid_x] = 0
		grid[grid_y] = row


func _carve_column(grid: Array, x: int, top: int, bottom: int) -> void:
	if x < 0 or x >= level_size.x:
		return
	var start_y: int = maxi(0, mini(top, bottom))
	var end_y: int = mini(level_size.y, maxi(top, bottom))
	for grid_y: int in range(start_y, end_y):
		var row: PackedByteArray = grid[grid_y] as PackedByteArray
		row[x] = 0
		grid[grid_y] = row


func _stamp_rect(grid: Array, x: int, y: int, width_tiles: int, height_tiles: int) -> void:
	if width_tiles <= 0 or height_tiles <= 0:
		return
	var start_x: int = maxi(0, x)
	var end_x: int = mini(level_size.x, x + width_tiles)
	var start_y: int = maxi(0, y)
	var end_y: int = mini(level_size.y, y + height_tiles)
	for grid_y: int in range(start_y, end_y):
		var row: PackedByteArray = grid[grid_y] as PackedByteArray
		for grid_x: int in range(start_x, end_x):
			row[grid_x] = 1
		grid[grid_y] = row


func _place_pickups() -> Array:
	var source_pickups: Array = level_data.get("pickups", []) as Array
	var pickup_messages: Array = []
	for pickup_variant: Variant in source_pickups:
		pickup_messages.append((pickup_variant as Dictionary).duplicate(true))

	var slots: Array = []
	for room_variant: Variant in side_rooms:
		var room: Dictionary = room_variant as Dictionary
		for slot_variant: Variant in room.get("pickup_slots", []) as Array:
			slots.append(slot_variant)
	for room_variant: Variant in main_rooms:
		var room: Dictionary = room_variant as Dictionary
		for slot_variant: Variant in room.get("pickup_slots", []) as Array:
			slots.append(slot_variant)

	var placed_pickups: Array = []
	for pickup_index: int in range(mini(pickup_messages.size(), slots.size())):
		var pickup_data: Dictionary = pickup_messages[pickup_index] as Dictionary
		var slot: Vector2i = slots[pickup_index] as Vector2i
		pickup_data["x"] = slot.x
		pickup_data["y"] = slot.y
		placed_pickups.append(pickup_data)
	return placed_pickups


func _place_enemies() -> Array:
	var source_enemies: Array = level_data.get("enemies", []) as Array
	var enemy_queue: Array = []
	for enemy_variant: Variant in source_enemies:
		var enemy_data: Dictionary = (enemy_variant as Dictionary).duplicate(true)
		var enemy_type: String = str(enemy_data.get("type", "bat"))
		if enemy_type == "slime":
			enemy_type = "bat"
		enemy_data["type"] = enemy_type
		enemy_queue.append(enemy_data)

	var room_candidates: Array = []
	for room_variant: Variant in main_rooms:
		var room: Dictionary = room_variant as Dictionary
		var role: String = str(room.get("role", ""))
		if role == ROOM_ROLE_START or role == ROOM_ROLE_INTRO or role == ROOM_ROLE_EXIT:
			continue
		room_candidates.append(room)

	var placed_enemies: Array = []
	var room_cursor: int = 0
	for enemy_variant: Variant in enemy_queue:
		var enemy_data: Dictionary = enemy_variant as Dictionary
		if room_candidates.is_empty():
			break
		var room: Dictionary = room_candidates[min(room_cursor, room_candidates.size() - 1)] as Dictionary
		var enemy_type: String = str(enemy_data.get("type", "bat"))
		var slots: Array = []
		if enemy_type == "bat":
			slots = room.get("air_slots", []) as Array
		else:
			slots = room.get("ground_slots", []) as Array
		if slots.is_empty():
			slots = room.get("ground_slots", []) as Array
		if slots.is_empty():
			room_cursor += 1
			continue
		var slot: Vector2i = slots[min(placed_enemies.size() % slots.size(), slots.size() - 1)] as Vector2i
		enemy_data["x"] = slot.x
		enemy_data["y"] = slot.y
		placed_enemies.append(enemy_data)
		room_cursor = mini(room_cursor + 1, room_candidates.size() - 1)
	return placed_enemies


func _place_hazards() -> Array:
	var source_hazards: Array = level_data.get("hazards", []) as Array
	var total_hazard_budget: int = 0
	for hazard_variant: Variant in source_hazards:
		var hazard_data: Dictionary = hazard_variant as Dictionary
		total_hazard_budget += max(1, int(hazard_data.get("count", 1)))

	if total_hazard_budget <= 0:
		return []

	var candidate_slots: Array = []
	for room_variant: Variant in main_rooms:
		var room: Dictionary = room_variant as Dictionary
		for slot_variant: Variant in room.get("hazard_slots", []) as Array:
			candidate_slots.append(slot_variant)

	var hazards: Array = []
	var remaining_budget: int = total_hazard_budget
	for slot_variant: Variant in candidate_slots:
		if remaining_budget <= 0:
			break
		var slot: Vector2i = slot_variant as Vector2i
		var count: int = mini(2, remaining_budget)
		hazards.append({
			"type": "spikes",
			"x": slot.x,
			"y": slot.y,
			"count": count
		})
		remaining_budget -= count
	return hazards


func _place_torches() -> Array:
	var source_torches: Array = level_data.get("torches", []) as Array
	var brightness_values: Array = []
	for torch_variant: Variant in source_torches:
		brightness_values.append(float((torch_variant as Dictionary).get("brightness", 1.0)))
	if brightness_values.is_empty():
		brightness_values.append(1.0)

	var torch_slots: Array = []
	for room_variant: Variant in main_rooms:
		var room: Dictionary = room_variant as Dictionary
		for slot_variant: Variant in room.get("torch_slots", []) as Array:
			torch_slots.append(slot_variant)
	for room_variant: Variant in side_rooms:
		var room: Dictionary = room_variant as Dictionary
		for slot_variant: Variant in room.get("torch_slots", []) as Array:
			torch_slots.append(slot_variant)

	var torches: Array = []
	for slot_index: int in range(torch_slots.size()):
		var slot: Vector2i = torch_slots[slot_index] as Vector2i
		var brightness: float = float(brightness_values[slot_index % brightness_values.size()])
		torches.append({
			"x": slot.x,
			"y": slot.y,
			"brightness": brightness
		})
	return torches


func _place_triggers() -> Array:
	var source_triggers: Array = level_data.get("triggers", []) as Array
	var trigger_rooms: Array = []
	if main_rooms.size() > 0:
		trigger_rooms.append(main_rooms[0])
	if main_rooms.size() > 2:
		trigger_rooms.append(main_rooms[int(main_rooms.size() / 2)])
	if main_rooms.size() > 1:
		trigger_rooms.append(main_rooms[main_rooms.size() - 1])

	var placed_triggers: Array = []
	for trigger_index: int in range(mini(source_triggers.size(), trigger_rooms.size())):
		var trigger_data: Dictionary = (source_triggers[trigger_index] as Dictionary).duplicate(true)
		var room: Dictionary = trigger_rooms[trigger_index] as Dictionary
		var room_rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
		var role: String = str(room.get("role", ""))
		var trigger_width: int = max(5, int(trigger_data.get("w", 1)))
		var trigger_height: int = max(4, int(trigger_data.get("h", 1)))
		var trigger_x: int = room_rect.position.x + 2
		var trigger_y: int = room_rect.position.y + room_rect.size.y - trigger_height - 2
		if role == ROOM_ROLE_BOSS:
			trigger_x = room_rect.position.x + 4
		elif role == ROOM_ROLE_EXIT:
			trigger_x = room_rect.position.x + room_rect.size.x - trigger_width - 3
		elif trigger_index == 1:
			trigger_x = room_rect.position.x + int(room_rect.size.x * 0.35)
		trigger_data["x"] = trigger_x
		trigger_data["y"] = trigger_y
		trigger_data["w"] = trigger_width
		trigger_data["h"] = trigger_height
		placed_triggers.append(trigger_data)
	return placed_triggers


func _place_boss() -> Dictionary:
	if not level_data.has("boss"):
		return {}
	var boss_data: Dictionary = (level_data.get("boss", {}) as Dictionary).duplicate(true)
	var boss_room: Dictionary = {}
	for room_variant: Variant in main_rooms:
		var room: Dictionary = room_variant as Dictionary
		if str(room.get("role", "")) == ROOM_ROLE_BOSS:
			boss_room = room
			break
	if boss_room.is_empty():
		return boss_data
	var rect: Rect2i = boss_room.get("rect", Rect2i()) as Rect2i
	var floor_y: int = int((boss_room.get("entry_node", Vector2i.ZERO) as Vector2i).y)
	boss_data["x"] = rect.position.x + int(rect.size.x / 2)
	boss_data["y"] = floor_y
	return boss_data


func _validate_layout(grid: Array, pickups: Array, enemies: Array, hazards: Array) -> Dictionary:
	var notes: PackedStringArray = PackedStringArray()
	var path_valid: bool = true
	for node_index: int in range(critical_path_nodes.size() - 1):
		var from_node: Vector2i = critical_path_nodes[node_index] as Vector2i
		var to_node: Vector2i = critical_path_nodes[node_index + 1] as Vector2i
		var delta_x: int = abs(to_node.x - from_node.x)
		var delta_y: int = to_node.y - from_node.y
		if delta_x > MAIN_JUMP_MAX_X_TILES + 1:
			path_valid = false
			notes.append("Path gap too wide near %s -> %s" % [str(from_node), str(to_node)])
		if delta_y < -MAIN_JUMP_MAX_UP_TILES - 1:
			path_valid = false
			notes.append("Path climb too high near %s -> %s" % [str(from_node), str(to_node)])
		if delta_y > MAIN_DROP_MAX_TILES + 1:
			path_valid = false
			notes.append("Path drop too deep near %s -> %s" % [str(from_node), str(to_node)])

	for pickup_variant: Variant in pickups:
		var pickup_data: Dictionary = pickup_variant as Dictionary
		if _grid_is_solid(grid, int(pickup_data.get("x", 0)), int(pickup_data.get("y", 0))):
			path_valid = false
			notes.append("Pickup inside solid at %s" % str(Vector2i(int(pickup_data.get("x", 0)), int(pickup_data.get("y", 0)))))

	for enemy_variant: Variant in enemies:
		var enemy_data: Dictionary = enemy_variant as Dictionary
		if _grid_is_solid(grid, int(enemy_data.get("x", 0)), int(enemy_data.get("y", 0))):
			path_valid = false
			notes.append("Enemy inside solid at %s" % str(Vector2i(int(enemy_data.get("x", 0)), int(enemy_data.get("y", 0)))))

	for hazard_variant: Variant in hazards:
		var hazard_data: Dictionary = hazard_variant as Dictionary
		var hazard_x: int = int(hazard_data.get("x", 0))
		var hazard_y: int = int(hazard_data.get("y", 0))
		if not _grid_is_solid(grid, hazard_x, hazard_y + 1):
			notes.append("Hazard without floor support at %s" % str(Vector2i(hazard_x, hazard_y)))

	return {
		"path_valid": path_valid,
		"room_count": main_rooms.size(),
		"branch_count": side_rooms.size(),
		"enemy_budget": enemies.size(),
		"pickup_budget": pickups.size(),
		"hazard_budget": hazards.size(),
		"notes": notes
	}


func _find_room_by_id(rooms: Array, room_id: String) -> Dictionary:
	for room_variant: Variant in rooms:
		var room: Dictionary = room_variant as Dictionary
		if str(room.get("id", "")) == room_id:
			return room
	return {}


func _enemy_budget() -> int:
	return (level_data.get("enemies", []) as Array).size()


func _pickup_budget() -> int:
	return (level_data.get("pickups", []) as Array).size()


func _first_path_node() -> Vector2i:
	if critical_path_nodes.is_empty():
		return level_data.get("spawn", Vector2i(4, 28)) as Vector2i
	return critical_path_nodes.front() as Vector2i


func _last_path_node() -> Vector2i:
	if critical_path_nodes.is_empty():
		return level_data.get("exit", Vector2i(level_size.x - 8, level_size.y - 10)) as Vector2i
	return critical_path_nodes.back() as Vector2i


func _grid_is_solid(grid: Array, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= level_size.x or y >= level_size.y:
		return false
	var row: PackedByteArray = grid[y] as PackedByteArray
	return row[x] == 1


func _path_height_at_x(path_nodes: Array, world_x: int, fallback_y: int) -> int:
	if path_nodes.is_empty():
		return fallback_y
	var first_node: Vector2i = path_nodes.front() as Vector2i
	if world_x <= first_node.x:
		return first_node.y
	for node_index: int in range(path_nodes.size() - 1):
		var from_node: Vector2i = path_nodes[node_index] as Vector2i
		var to_node: Vector2i = path_nodes[node_index + 1] as Vector2i
		if world_x < from_node.x or world_x > to_node.x:
			continue
		if from_node.x == to_node.x:
			return mini(from_node.y, to_node.y)
		var distance: float = float(to_node.x - from_node.x)
		var weight: float = clampf(float(world_x - from_node.x) / distance, 0.0, 1.0)
		return int(round(lerpf(float(from_node.y), float(to_node.y), weight)))
	return (path_nodes.back() as Vector2i).y


func _vertical_path_center_x(path_nodes: Array, world_y: int, fallback_x: int) -> int:
	if path_nodes.is_empty():
		return fallback_x
	var nearest_x: int = fallback_x
	var nearest_distance: int = 1_000_000
	for node_variant: Variant in path_nodes:
		var node: Vector2i = node_variant as Vector2i
		var distance: int = abs(node.y - world_y)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_x = node.x
	return nearest_x
