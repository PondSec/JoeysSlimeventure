class_name ChapterTraversalValidator
extends RefCounted

const ChapterMobilityProfile := preload("res://Scripts/Chapter/chapter_mobility_profile.gd")

const SAMPLE_DT := 1.0 / 60.0
const MAX_SIMULATION_TIME := 1.95


static func validate_layout(input: Dictionary) -> Dictionary:
	var grid: Array = input.get("grid", []) as Array
	var level_size: Vector2i = input.get("level_size", Vector2i.ZERO) as Vector2i
	var mobility: Dictionary = input.get("mobility_profile", {}) as Dictionary
	var rooms: Array = input.get("rooms", []) as Array
	var critical_path_nodes: Array = input.get("critical_path_nodes", []) as Array
	var side_path_lines: Array = input.get("side_path_lines", []) as Array
	var pickups: Array = input.get("pickups", []) as Array
	var spawn: Vector2i = input.get("spawn", Vector2i.ZERO) as Vector2i
	var exit: Vector2i = input.get("exit", Vector2i.ZERO) as Vector2i

	var notes := PackedStringArray()
	var room_role_counts: Dictionary = {}
	for room_variant: Variant in rooms:
		var room: Dictionary = room_variant as Dictionary
		var role: String = str(room.get("role", "unknown"))
		room_role_counts[role] = int(room_role_counts.get(role, 0)) + 1

	var validation_nodes: Array = _build_validation_nodes(critical_path_nodes, side_path_lines, pickups)
	_extend_with_surface_nodes(validation_nodes, grid, level_size, mobility)
	var nodes: Array = _anchor_validation_nodes(
		grid,
		level_size,
		validation_nodes,
		mobility
	)

	var graph: Dictionary = {}
	for node_variant: Variant in nodes:
		var node: Dictionary = node_variant as Dictionary
		var node_id: String = str(node.get("id", ""))
		graph[node_id] = PackedStringArray()

	for from_index: int in range(nodes.size()):
		var from_node: Dictionary = nodes[from_index] as Dictionary
		for to_index: int in range(nodes.size()):
			if from_index == to_index:
				continue
			var to_node: Dictionary = nodes[to_index] as Dictionary
			if not _should_probe_edge(from_node, to_node, mobility):
				continue
			if _can_traverse_between(
				grid,
				level_size,
				from_node.get("pos", Vector2i.ZERO) as Vector2i,
				to_node.get("pos", Vector2i.ZERO) as Vector2i,
				mobility
			):
				var edges: PackedStringArray = graph[str(from_node.get("id", ""))] as PackedStringArray
				edges.append(str(to_node.get("id", "")))
				graph[str(from_node.get("id", ""))] = edges

	var reverse_graph: Dictionary = _reverse_graph(graph)
	var start_anchor: Vector2i = _resolve_anchor(grid, level_size, spawn, mobility, "critical")
	var exit_anchor: Vector2i = _resolve_anchor(grid, level_size, exit, mobility, "exit")
	var start_id: String = _nearest_node_id(nodes, start_anchor)
	var exit_id: String = _nearest_node_id(nodes, exit_anchor)
	var reachable_ids: Dictionary = _flood_fill_graph(graph, start_id)
	var exit_reachable_ids: Dictionary = _flood_fill_graph(reverse_graph, exit_id)
	var traversal_edges: Array = _edge_array_from_graph(graph, nodes, reachable_ids, exit_reachable_ids)

	var invalid_jump_edges: Array = []
	var invalid_jump_count: int = 0
	var optional_invalid_jump_count: int = 0
	for node_index: int in range(maxi(critical_path_nodes.size() - 1, 0)):
		var from_source: Vector2i = critical_path_nodes[node_index] as Vector2i
		var to_source: Vector2i = critical_path_nodes[node_index + 1] as Vector2i
		var from_node: Vector2i = _resolve_anchor(grid, level_size, from_source, mobility, "critical")
		var to_node: Vector2i = _resolve_anchor(grid, level_size, to_source, mobility, "critical")
		if not _can_traverse_between(grid, level_size, from_node, to_node, mobility):
			invalid_jump_count += 1
			invalid_jump_edges.append({
				"kind": "critical",
				"from": from_node,
				"to": to_node,
				"from_source": from_source,
				"to_source": to_source
			})
			notes.append("Kritischer Sprung ungueltig %s -> %s" % [str(from_node), str(to_node)])

	for branch_variant: Variant in side_path_lines:
		var branch_line: Array = branch_variant as Array
		for point_index: int in range(maxi(branch_line.size() - 1, 0)):
			var from_source: Vector2i = branch_line[point_index] as Vector2i
			var to_source: Vector2i = branch_line[point_index + 1] as Vector2i
			var from_point: Vector2i = _resolve_anchor(grid, level_size, from_source, mobility, "branch")
			var to_point: Vector2i = _resolve_anchor(grid, level_size, to_source, mobility, "branch")
			if not _can_traverse_between(grid, level_size, from_point, to_point, mobility):
				optional_invalid_jump_count += 1
				invalid_jump_edges.append({
					"kind": "branch",
					"from": from_point,
					"to": to_point,
					"from_source": from_source,
					"to_source": to_source
				})
				notes.append("Nebenpfad-Sprung ungueltig %s -> %s" % [str(from_point), str(to_point)])

	var unreachable_rewards: Array = []
	for node_variant: Variant in nodes:
		var node: Dictionary = node_variant as Dictionary
		if str(node.get("kind", "")) != "reward":
			continue
		var node_id: String = str(node.get("id", ""))
		if not reachable_ids.has(node_id):
			unreachable_rewards.append(node.get("pos", Vector2i.ZERO))
			notes.append("Reward unerreichbar bei %s" % str(node.get("pos", Vector2i.ZERO)))

	var softlock_nodes: Array = []
	for node_variant: Variant in nodes:
		var node: Dictionary = node_variant as Dictionary
		if str(node.get("kind", "")) != "surface":
			continue
		var node_id: String = str(node.get("id", ""))
		if not reachable_ids.has(node_id):
			continue
		if exit_id.is_empty() or not exit_reachable_ids.has(node_id):
			softlock_nodes.append(node.get("pos", Vector2i.ZERO))

	var trap_pit_nodes: Array = []
	var trap_threshold: int = max(3, int(mobility.get("readable_drop_tiles", 5)) - 1)
	for trap_variant: Variant in softlock_nodes:
		var trap_node: Vector2i = trap_variant as Vector2i
		if _vertical_distance_to_path(trap_node, critical_path_nodes) >= trap_threshold:
			trap_pit_nodes.append(trap_node)

	if not softlock_nodes.is_empty():
		notes.append("Softlock-Risiko auf %d begehbaren Flaechen." % softlock_nodes.size())
	if not trap_pit_nodes.is_empty():
		notes.append("Tiefe Gruben ohne Rueckweg: %d" % trap_pit_nodes.size())

	var unreachable_room_ids: Array = []
	var unreachable_optional_room_ids: Array = []
	for room_variant: Variant in rooms:
		var room: Dictionary = room_variant as Dictionary
		var entry_node: Vector2i = _resolve_anchor(grid, level_size, room.get("entry_node", Vector2i.ZERO) as Vector2i, mobility, "critical")
		var exit_node: Vector2i = _resolve_anchor(grid, level_size, room.get("exit_node", Vector2i.ZERO) as Vector2i, mobility, "critical")
		var entry_id: String = _nearest_node_id(nodes, entry_node)
		var room_exit_id: String = _nearest_node_id(nodes, exit_node)
		if not reachable_ids.has(entry_id) or not reachable_ids.has(room_exit_id):
			if str(room.get("role", "")) == "branch":
				unreachable_optional_room_ids.append(str(room.get("id", "")))
			else:
				unreachable_room_ids.append(str(room.get("id", "")))

	var dead_end_count: int = 0
	for node_variant: Variant in nodes:
		var node: Dictionary = node_variant as Dictionary
		var node_id: String = str(node.get("id", ""))
		if not reachable_ids.has(node_id):
			continue
		if node_id == start_id or node_id == exit_id:
			continue
		var node_kind: String = str(node.get("kind", ""))
		if node_kind == "reward" or node_kind == "surface":
			continue
		var edges: PackedStringArray = graph.get(node_id, PackedStringArray()) as PackedStringArray
		if edges.size() <= 1:
			dead_end_count += 1

	var exit_anchor_valid: bool = _is_valid_exit_anchor(grid, level_size, exit_anchor, mobility)
	var exit_margin_ok: bool = exit_anchor.x >= 4 and exit_anchor.x <= level_size.x - 5 and exit_anchor.y >= 4 and exit_anchor.y <= level_size.y - 4
	if not exit_anchor_valid:
		notes.append("Exit-Zone ungueltig bei %s." % str(exit_anchor))
	if not exit_margin_ok:
		notes.append("Exit liegt zu nah am Levelrand bei %s." % str(exit_anchor))

	var critical_path_length_tiles: float = _polyline_length(critical_path_nodes)
	var reachable_reward_count: int = max(0, pickups.size() - unreachable_rewards.size())
	var path_valid: bool = invalid_jump_count == 0 \
	and unreachable_room_ids.is_empty() \
	and trap_pit_nodes.is_empty() \
	and not exit_id.is_empty() \
	and reachable_ids.has(exit_id)
	if exit_id.is_empty():
		notes.append("Kein Exit-Knoten fuer die Validierung gefunden.")

	return {
		"path_valid": path_valid,
		"optional_path_valid": optional_invalid_jump_count == 0 and unreachable_optional_room_ids.is_empty(),
		"required_path_reachable": not exit_id.is_empty() and reachable_ids.has(exit_id),
		"room_count": rooms.size(),
		"branch_count": side_path_lines.size(),
		"critical_path_length_tiles": critical_path_length_tiles,
		"reachable_reward_count": reachable_reward_count,
		"unreachable_reward_count": unreachable_rewards.size(),
		"invalid_jump_count": invalid_jump_count,
		"optional_invalid_jump_count": optional_invalid_jump_count,
		"surface_node_count": _node_count_for_kind(nodes, "surface"),
		"softlock_surface_count": softlock_nodes.size(),
		"trap_pit_count": trap_pit_nodes.size(),
		"dead_end_count": dead_end_count,
		"unreachable_room_count": unreachable_room_ids.size(),
		"unreachable_optional_room_count": unreachable_optional_room_ids.size(),
		"exit_anchor": exit_anchor,
		"exit_anchor_valid": exit_anchor_valid,
		"exit_margin_ok": exit_margin_ok,
		"room_role_counts": room_role_counts,
		"notes": notes,
		"unreachable_rewards": unreachable_rewards,
		"invalid_jump_edges": invalid_jump_edges,
		"softlock_nodes": softlock_nodes,
		"trap_pit_nodes": trap_pit_nodes,
		"unreachable_room_ids": unreachable_room_ids,
		"unreachable_optional_room_ids": unreachable_optional_room_ids,
		"traversal_nodes": nodes.duplicate(true),
		"traversal_edges": traversal_edges,
		"reachable_node_ids": _dictionary_keys_as_packed_string_array(reachable_ids),
		"exit_return_node_ids": _dictionary_keys_as_packed_string_array(exit_reachable_ids),
		"start_node_id": start_id,
		"exit_node_id": exit_id
	}


static func _build_validation_nodes(critical_path_nodes: Array, side_path_lines: Array, pickups: Array) -> Array:
	var nodes: Array = []
	var seen: Dictionary = {}
	var index: int = 0
	for point_variant: Variant in critical_path_nodes:
		var point: Vector2i = point_variant as Vector2i
		var key: String = "%d:%d" % [point.x, point.y]
		if seen.has(key):
			continue
		seen[key] = true
		nodes.append({
			"id": "critical_%d" % index,
			"pos": point,
			"kind": "critical"
		})
		index += 1

	for line_index: int in range(side_path_lines.size()):
		var branch_line: Array = side_path_lines[line_index] as Array
		for point_index: int in range(branch_line.size()):
			var point: Vector2i = branch_line[point_index] as Vector2i
			var key: String = "%d:%d" % [point.x, point.y]
			if seen.has(key):
				continue
			seen[key] = true
			nodes.append({
				"id": "branch_%d_%d" % [line_index, point_index],
				"pos": point,
				"kind": "branch"
			})

	for reward_index: int in range(pickups.size()):
		var pickup: Dictionary = pickups[reward_index] as Dictionary
		var reward_pos := Vector2i(int(pickup.get("x", 0)), int(pickup.get("y", 0)) + 1)
		var key: String = "%d:%d" % [reward_pos.x, reward_pos.y]
		if seen.has(key):
			continue
		seen[key] = true
		nodes.append({
			"id": "reward_%d" % reward_index,
			"pos": reward_pos,
			"kind": "reward"
			})
	return nodes


static func _extend_with_surface_nodes(nodes: Array, grid: Array, size: Vector2i, mobility: Dictionary) -> void:
	var seen: Dictionary = {}
	for node_variant: Variant in nodes:
		var node: Dictionary = node_variant as Dictionary
		var node_pos: Vector2i = node.get("pos", Vector2i.ZERO) as Vector2i
		seen["%d:%d" % [node_pos.x, node_pos.y]] = true

	var sample_step: int = max(3, int(mobility.get("main_gap_tiles", 5)))
	var max_surface_nodes: int = clampi(size.x + int(size.y * 0.5), 96, 160)
	var surface_index: int = 0
	for grid_y: int in range(1, size.y - 1):
		var grid_x: int = 1
		while grid_x < size.x - 1:
			var cell := Vector2i(grid_x, grid_y)
			if not _is_valid_surface_for_mobility(grid, size, cell, mobility):
				grid_x += 1
				continue

			var span_start: int = grid_x
			while grid_x + 1 < size.x - 1 and _is_valid_surface_for_mobility(grid, size, Vector2i(grid_x + 1, grid_y), mobility):
				grid_x += 1
			var span_end: int = grid_x

			var sample_positions: Array = [span_start, span_end, int(round((float(span_start) + float(span_end)) * 0.5))]
			var cursor: int = span_start + sample_step
			while cursor < span_end:
				sample_positions.append(cursor)
				cursor += sample_step

			var span_seen: Dictionary = {}
			for sample_variant: Variant in sample_positions:
				var sample_x: int = clampi(int(sample_variant), span_start, span_end)
				var key: String = "%d:%d" % [sample_x, grid_y]
				if span_seen.has(key) or seen.has(key):
					continue
				span_seen[key] = true
				seen[key] = true
				nodes.append({
					"id": "surface_%d" % surface_index,
					"pos": Vector2i(sample_x, grid_y),
					"kind": "surface"
				})
				surface_index += 1
				if surface_index >= max_surface_nodes:
					return
			grid_x += 1


static func _anchor_validation_nodes(grid: Array, size: Vector2i, nodes: Array, mobility: Dictionary) -> Array:
	var anchored_nodes: Array = []
	for node_variant: Variant in nodes:
		var node: Dictionary = (node_variant as Dictionary).duplicate(true)
		var source_pos: Vector2i = node.get("pos", Vector2i.ZERO) as Vector2i
		node["source_pos"] = source_pos
		node["pos"] = _resolve_anchor(grid, size, source_pos, mobility, str(node.get("kind", "critical")))
		anchored_nodes.append(node)
	return anchored_nodes


static func _resolve_anchor(grid: Array, size: Vector2i, target: Vector2i, mobility: Dictionary, kind: String = "critical") -> Vector2i:
	if _is_valid_surface_for_mobility(grid, size, target, mobility):
		return target

	var best_cell: Vector2i = target
	var best_score: float = INF
	var horizontal_radius: int = 4 if kind == "branch" else 3
	var upward_radius: int = 3
	var downward_radius: int = 5 if kind == "reward" else 4
	for offset_y: int in range(-upward_radius, downward_radius + 1):
		for offset_x: int in range(-horizontal_radius, horizontal_radius + 1):
			var candidate := Vector2i(target.x + offset_x, target.y + offset_y)
			if not _is_valid_surface_for_mobility(grid, size, candidate, mobility):
				continue
			var score: float = absf(float(offset_x)) + absf(float(offset_y)) * 1.15
			if kind == "reward" and offset_y > 0:
				score -= 0.25
			elif kind != "reward" and offset_y < 0:
				score += 1.5
			if score < best_score:
				best_score = score
				best_cell = candidate
	if best_score < INF:
		return best_cell
	return target


static func _reverse_graph(graph: Dictionary) -> Dictionary:
	var reversed_graph: Dictionary = {}
	for node_id_variant: Variant in graph.keys():
		reversed_graph[str(node_id_variant)] = PackedStringArray()
	for node_id_variant: Variant in graph.keys():
		var from_id: String = str(node_id_variant)
		var neighbors: PackedStringArray = graph.get(from_id, PackedStringArray()) as PackedStringArray
		for neighbor_id: String in neighbors:
			var reversed_edges: PackedStringArray = reversed_graph.get(neighbor_id, PackedStringArray()) as PackedStringArray
			reversed_edges.append(from_id)
			reversed_graph[neighbor_id] = reversed_edges
	return reversed_graph


static func _edge_array_from_graph(graph: Dictionary, nodes: Array, reachable_ids: Dictionary, exit_reachable_ids: Dictionary) -> Array:
	var node_lookup: Dictionary = {}
	for node_variant: Variant in nodes:
		var node: Dictionary = node_variant as Dictionary
		node_lookup[str(node.get("id", ""))] = node

	var edges: Array = []
	for node_id_variant: Variant in graph.keys():
		var from_id: String = str(node_id_variant)
		var from_node: Dictionary = node_lookup.get(from_id, {}) as Dictionary
		var neighbors: PackedStringArray = graph.get(from_id, PackedStringArray()) as PackedStringArray
		for to_id: String in neighbors:
			var to_node: Dictionary = node_lookup.get(to_id, {}) as Dictionary
			if from_node.is_empty() or to_node.is_empty():
				continue
			edges.append({
				"from_id": from_id,
				"to_id": to_id,
				"from_pos": from_node.get("pos", Vector2i.ZERO),
				"to_pos": to_node.get("pos", Vector2i.ZERO),
				"from_kind": str(from_node.get("kind", "")),
				"to_kind": str(to_node.get("kind", "")),
				"reachable": reachable_ids.has(from_id) and reachable_ids.has(to_id),
				"returnable": exit_reachable_ids.has(from_id) and exit_reachable_ids.has(to_id)
			})
	return edges


static func _dictionary_keys_as_packed_string_array(values: Dictionary) -> PackedStringArray:
	var packed := PackedStringArray()
	for key_variant: Variant in values.keys():
		packed.append(str(key_variant))
	return packed


static func _is_valid_surface_for_mobility(grid: Array, size: Vector2i, cell: Vector2i, mobility: Dictionary) -> bool:
	if not _grid_is_solid(grid, size, cell.x, cell.y):
		return false
	return not _body_collides(grid, size, Vector2(float(cell.x) + 0.5, float(cell.y)), mobility)


static func _nearest_node_id(nodes: Array, target: Vector2i) -> String:
	var best_id: String = ""
	var best_distance: float = INF
	for node_variant: Variant in nodes:
		var node: Dictionary = node_variant as Dictionary
		var node_pos: Vector2i = node.get("pos", Vector2i.ZERO) as Vector2i
		var distance: float = node_pos.distance_to(target)
		if distance < best_distance:
			best_distance = distance
			best_id = str(node.get("id", ""))
	return best_id


static func _flood_fill_graph(graph: Dictionary, start_id: String) -> Dictionary:
	var reachable: Dictionary = {}
	if start_id.is_empty():
		return reachable
	var queue: Array = [start_id]
	reachable[start_id] = true
	while not queue.is_empty():
		var current_id: String = str(queue.pop_front())
		var neighbors: PackedStringArray = graph.get(current_id, PackedStringArray()) as PackedStringArray
		for neighbor_id: String in neighbors:
			if reachable.has(neighbor_id):
				continue
			reachable[neighbor_id] = true
			queue.append(neighbor_id)
	return reachable


static func _should_probe_edge(from_node: Dictionary, to_node: Dictionary, mobility: Dictionary) -> bool:
	var from_pos: Vector2i = from_node.get("pos", Vector2i.ZERO) as Vector2i
	var to_pos: Vector2i = to_node.get("pos", Vector2i.ZERO) as Vector2i
	var delta_x: int = abs(to_pos.x - from_pos.x)
	var delta_y: int = abs(to_pos.y - from_pos.y)
	var max_horizontal_probe: int = max(
		max(
			int(mobility.get("main_gap_tiles", 5)),
			int(mobility.get("challenge_gap_tiles", mobility.get("main_gap_tiles", 5)))
		),
		max(
			int(mobility.get("wall_jump_gap_tiles", mobility.get("main_gap_tiles", 5))),
			int(mobility.get("teleport_gap_tiles", 0))
		)
	) + 4
	var max_vertical_probe: int = max(
		int(mobility.get("safe_drop_tiles", 7)) + 3,
		int(mobility.get("wall_jump_up_tiles", mobility.get("max_jump_up_tiles", 4))) + 1
	)
	if delta_x > max_horizontal_probe:
		return false
	if delta_y > max_vertical_probe:
		return false
	return true


static func _polyline_length(points: Array) -> float:
	var length_tiles: float = 0.0
	for point_index: int in range(maxi(points.size() - 1, 0)):
		var from_point: Vector2i = points[point_index] as Vector2i
		var to_point: Vector2i = points[point_index + 1] as Vector2i
		length_tiles += from_point.distance_to(to_point)
	return length_tiles


static func _vertical_distance_to_path(cell: Vector2i, path_points: Array) -> int:
	var best_distance: int = 0
	var has_best: bool = false
	for path_variant: Variant in path_points:
		var path_point: Vector2i = path_variant as Vector2i
		var distance_y: int = abs(cell.y - path_point.y)
		if not has_best or distance_y < best_distance:
			best_distance = distance_y
			has_best = true
	if not has_best:
		return 0
	return best_distance


static func _node_count_for_kind(nodes: Array, kind: String) -> int:
	var count: int = 0
	for node_variant: Variant in nodes:
		if str((node_variant as Dictionary).get("kind", "")) == kind:
			count += 1
	return count


static func _can_traverse_between(grid: Array, size: Vector2i, from_node: Vector2i, to_node: Vector2i, mobility: Dictionary) -> bool:
	if from_node == to_node:
		return true

	var skill_flags: Dictionary = mobility.get("skill_flags", {}) as Dictionary
	if not _is_valid_surface_for_mobility(grid, size, from_node, mobility):
		return false
	if not _is_valid_surface_for_mobility(grid, size, to_node, mobility):
		return false

	var from_span: Vector2i = _surface_span_at(grid, size, from_node, mobility)
	var to_span: Vector2i = _surface_span_at(grid, size, to_node, mobility)
	var effective_delta_x: int = _surface_gap_tiles(from_span, to_span)

	var delta_y: int = to_node.y - from_node.y
	var max_jump_up_tiles: int = int(mobility.get("max_jump_up_tiles", 4))
	var safe_drop_tiles: int = int(mobility.get("safe_drop_tiles", 7))
	var horizontal_limit: int = max(
		int(mobility.get("main_gap_tiles", 5)),
		int(mobility.get("wall_jump_gap_tiles", 6)),
		int(mobility.get("teleport_gap_tiles", 0))
	)
	if effective_delta_x > horizontal_limit + 2:
		return false
	var can_chain_wall_climb: bool = bool(skill_flags.get("wall_slide", false)) and _can_chain_wall_climb_between(grid, size, from_node, to_node, mobility)
	if delta_y < -max_jump_up_tiles - 1 and not can_chain_wall_climb:
		return false
	if delta_y > safe_drop_tiles + 3:
		return false

	if _can_walk_between(grid, size, from_node, to_node, mobility):
		return true
	if _can_drop_between(grid, size, from_node, to_node, mobility):
		return true
	if _simulate_jump_arc(grid, size, from_node, to_node, mobility):
		return true
	if _simulate_wall_jump_arc(grid, size, from_node, to_node, mobility, effective_delta_x):
		return true
	if can_chain_wall_climb:
		return true
	if bool((mobility.get("skill_flags", {}) as Dictionary).get("double_jump", false)) and _simulate_double_jump_arc(grid, size, from_node, to_node, mobility):
		return true
	if _can_dash_between(grid, size, from_node, to_node, mobility):
		return true
	if _can_teleport_between(grid, size, from_node, to_node, mobility):
		return true
	return false


static func _fits_mobility_budget(from_node: Vector2i, to_node: Vector2i, mobility: Dictionary, effective_gap_tiles: int = -1) -> bool:
	var delta_x: int = effective_gap_tiles if effective_gap_tiles >= 0 else abs(to_node.x - from_node.x)
	var climb_tiles: int = max(0, from_node.y - to_node.y)
	var drop_tiles: int = max(0, to_node.y - from_node.y)
	var horizontal_budget: int = int(mobility.get("challenge_gap_tiles", mobility.get("main_gap_tiles", 5))) + 1
	if delta_x > horizontal_budget:
		return false
	if climb_tiles > int(mobility.get("max_jump_up_tiles", 4)):
		return false
	if drop_tiles > int(mobility.get("safe_drop_tiles", 7)):
		return false
	return true


static func _can_drop_between(grid: Array, size: Vector2i, from_node: Vector2i, to_node: Vector2i, mobility: Dictionary) -> bool:
	var drop_tiles: int = to_node.y - from_node.y
	if drop_tiles <= 0:
		return false
	if drop_tiles > int(mobility.get("safe_drop_tiles", 7)) + 1:
		return false
	var direction: float = signf(float(to_node.x - from_node.x))
	var walk_speed: float = float(mobility.get("walk_speed_tiles_per_second", 4.5)) * direction
	var run_speed: float = float(mobility.get("run_speed_tiles_per_second", 6.5)) * direction
	var launch_speeds: Array = [0.0, walk_speed, run_speed]
	var from_span: Vector2i = _surface_span_at(grid, size, from_node, mobility)
	var to_span: Vector2i = _surface_span_at(grid, size, to_node, mobility)
	var launch_positions: Array = _sample_launch_positions(from_span, direction)
	for launch_speed_variant: Variant in launch_speeds:
		for launch_position_variant: Variant in launch_positions:
			if _simulate_arc_with_launch(
				grid,
				size,
				Vector2(float(launch_position_variant), float(from_node.y)),
				to_span,
				to_node.y,
				mobility,
				float(launch_speed_variant),
				0.0
			):
				return true
	return false


static func _simulate_wall_jump_arc(grid: Array, size: Vector2i, from_node: Vector2i, to_node: Vector2i, mobility: Dictionary, effective_gap_tiles: int) -> bool:
	var skill_flags: Dictionary = mobility.get("skill_flags", {}) as Dictionary
	if not bool(skill_flags.get("wall_slide", false)):
		return false
	var climb_tiles: int = max(0, from_node.y - to_node.y)
	if climb_tiles <= int(mobility.get("max_jump_up_tiles", 4)):
		return false
	if climb_tiles > int(mobility.get("wall_jump_up_tiles", mobility.get("max_jump_up_tiles", 4) + 1)):
		return false
	if effective_gap_tiles > int(mobility.get("wall_jump_gap_tiles", mobility.get("challenge_gap_tiles", 5))):
		return false
	var launch_directions: Array = []
	if _has_adjacent_wall_on_side(grid, size, from_node, -1):
		launch_directions.append(1.0)
	if _has_adjacent_wall_on_side(grid, size, from_node, 1):
		launch_directions.append(-1.0)
	if launch_directions.is_empty():
		return false
	var preferred_direction: float = signf(float(to_node.x - from_node.x))
	var target_span: Vector2i = _surface_span_at(grid, size, to_node, mobility)
	for launch_direction_variant: Variant in launch_directions:
		var launch_direction: float = float(launch_direction_variant)
		if not is_zero_approx(preferred_direction) and preferred_direction != launch_direction and abs(to_node.x - from_node.x) > 1:
			continue
		var launch_x: float = float(from_node.x) + 0.5
		if launch_direction > 0.0:
			launch_x = float(from_node.x) + 0.85
		elif launch_direction < 0.0:
			launch_x = float(from_node.x) + 0.15
		if _simulate_arc_with_launch(
			grid,
			size,
			Vector2(launch_x, float(from_node.y)),
			target_span,
			to_node.y,
			mobility,
			float(mobility.get("wall_jump_horizontal_tiles_per_second", 8.0)) * launch_direction,
			float(mobility.get("wall_jump_velocity_tiles_per_second", -12.5))
		):
			return true
	return false


static func _has_adjacent_wall_on_side(grid: Array, size: Vector2i, cell: Vector2i, side: int) -> bool:
	if _grid_is_solid(grid, size, cell.x + side, cell.y):
		return true
	if _grid_is_solid(grid, size, cell.x + side, cell.y - 1):
		return true
	return false


static func _has_adjacent_wall(grid: Array, size: Vector2i, cell: Vector2i) -> bool:
	for offset_x: int in [-1, 1]:
		if _grid_is_solid(grid, size, cell.x + offset_x, cell.y):
			return true
		if _grid_is_solid(grid, size, cell.x + offset_x, cell.y - 1):
			return true
	return false


static func _can_chain_wall_climb_between(grid: Array, size: Vector2i, from_node: Vector2i, to_node: Vector2i, mobility: Dictionary) -> bool:
	if to_node.y >= from_node.y:
		return false
	if abs(to_node.x - from_node.x) > max(4, int(mobility.get("wall_jump_gap_tiles", 6)) - 1):
		return false

	var center_x: int = int(round((float(from_node.x) + float(to_node.x)) * 0.5))
	var max_wall_distance: int = 3
	var max_open_width: int = max(2, int(mobility.get("wall_jump_gap_tiles", 6)) - 2)
	for sample_y: int in range(from_node.y - 1, to_node.y - 1, -1):
		var left_wall: int = _nearest_wall_x_on_row(grid, size, center_x, sample_y, -1, max_wall_distance)
		var right_wall: int = _nearest_wall_x_on_row(grid, size, center_x, sample_y, 1, max_wall_distance)
		if left_wall == -999 or right_wall == -999:
			return false
		if right_wall - left_wall - 1 > max_open_width:
			return false
		var shaft_center_x: float = (float(left_wall) + float(right_wall)) * 0.5 + 0.5
		if _body_collides(grid, size, Vector2(shaft_center_x, float(sample_y)), mobility):
			return false
	return true


static func _nearest_wall_x_on_row(grid: Array, size: Vector2i, origin_x: int, sample_y: int, direction: int, max_distance: int) -> int:
	for distance: int in range(1, max_distance + 1):
		var candidate_x: int = origin_x + distance * direction
		if _grid_is_solid(grid, size, candidate_x, sample_y) or _grid_is_solid(grid, size, candidate_x, sample_y - 1):
			return candidate_x
	return -999


static func _surface_span_at(grid: Array, size: Vector2i, cell: Vector2i, mobility: Dictionary) -> Vector2i:
	var left_x: int = cell.x
	var right_x: int = cell.x
	while _is_valid_surface_for_mobility(grid, size, Vector2i(left_x - 1, cell.y), mobility):
		left_x -= 1
	while _is_valid_surface_for_mobility(grid, size, Vector2i(right_x + 1, cell.y), mobility):
		right_x += 1
	return Vector2i(left_x, right_x)


static func _surface_gap_tiles(from_span: Vector2i, to_span: Vector2i) -> int:
	if from_span.y < to_span.x:
		return max(0, to_span.x - from_span.y - 1)
	if to_span.y < from_span.x:
		return max(0, from_span.x - to_span.y - 1)
	return 0


static func _has_basic_jump_clearance(grid: Array, size: Vector2i, from_node: Vector2i, to_node: Vector2i, mobility: Dictionary) -> bool:
	var headroom_tiles: int = int(mobility.get("standing_headroom_tiles", 3))
	if not _has_headroom(grid, size, from_node, headroom_tiles):
		return false
	if not _has_headroom(grid, size, to_node, headroom_tiles):
		return false
	var left_x: int = mini(from_node.x, to_node.x)
	var right_x: int = maxi(from_node.x, to_node.x)
	var top_y: int = mini(from_node.y, to_node.y) - int(mobility.get("max_jump_up_tiles", 4)) - 1
	var bottom_y: int = maxi(from_node.y, to_node.y) - 1
	for grid_x: int in range(left_x, right_x + 1):
		var blocked_column: bool = true
		for grid_y: int in range(top_y, bottom_y + 1):
			if not _grid_is_solid(grid, size, grid_x, grid_y):
				blocked_column = false
				break
		if blocked_column:
			return false
	return true


static func _can_walk_between(grid: Array, size: Vector2i, from_node: Vector2i, to_node: Vector2i, mobility: Dictionary) -> bool:
	if from_node.y != to_node.y:
		return false
	var direction: int = 1 if to_node.x >= from_node.x else -1
	var current_x: int = from_node.x
	while current_x != to_node.x + direction:
		if not _is_valid_surface_for_mobility(grid, size, Vector2i(current_x, from_node.y), mobility):
			return false
		current_x += direction
	return true


static func _simulate_jump_arc(grid: Array, size: Vector2i, from_node: Vector2i, to_node: Vector2i, mobility: Dictionary) -> bool:
	var direction: float = signf(float(to_node.x - from_node.x))
	if is_zero_approx(direction):
		direction = 1.0

	var run_speed: float = float(mobility.get("run_speed_tiles_per_second", 6.5))
	var walk_speed: float = float(mobility.get("walk_speed_tiles_per_second", 4.5))
	var launch_speeds: Array = [run_speed, walk_speed]
	var launch_positions: Array = _sample_launch_positions(_surface_span_at(grid, size, from_node, mobility), direction)
	var target_span: Vector2i = _surface_span_at(grid, size, to_node, mobility)
	for launch_speed_variant: Variant in launch_speeds:
		var launch_speed: float = float(launch_speed_variant) * direction
		for launch_position_variant: Variant in launch_positions:
			if _simulate_arc_with_launch(
				grid,
				size,
				Vector2(float(launch_position_variant), float(from_node.y)),
				target_span,
				to_node.y,
				mobility,
				launch_speed,
				float(mobility.get("jump_velocity_tiles_per_second", -13.0))
			):
				return true
	return false


static func _simulate_double_jump_arc(grid: Array, size: Vector2i, from_node: Vector2i, to_node: Vector2i, mobility: Dictionary) -> bool:
	var direction: float = signf(float(to_node.x - from_node.x))
	if is_zero_approx(direction):
		direction = 1.0
	var launch_speed: float = float(mobility.get("run_speed_tiles_per_second", 6.5)) * direction
	var gravity_tiles: float = float(mobility.get("gravity_tiles_per_second_sq", 37.5))
	var max_fall_speed: float = float(mobility.get("max_fall_speed_tiles_per_second", 25.0))
	var target_span: Vector2i = _surface_span_at(grid, size, to_node, mobility)
	for launch_position_variant: Variant in _sample_launch_positions(_surface_span_at(grid, size, from_node, mobility), direction):
		var position := Vector2(float(launch_position_variant), float(from_node.y))
		var velocity := Vector2(launch_speed, float(mobility.get("jump_velocity_tiles_per_second", -13.0)))
		var double_jump_used: bool = false
		for _step: int in range(int(MAX_SIMULATION_TIME / SAMPLE_DT)):
			position += velocity * SAMPLE_DT
			var gravity_multiplier: float = ChapterMobilityProfile.gravity_multiplier_for_velocity(velocity.y)
			velocity.y += gravity_tiles * gravity_multiplier * SAMPLE_DT
			velocity.y = minf(velocity.y, max_fall_speed)
			if not double_jump_used and velocity.y > -1.0:
				velocity.y = float(mobility.get("air_jump_velocity_tiles_per_second", -12.5))
				double_jump_used = true
			if _can_land_on_target_span(grid, size, position, velocity, target_span, to_node.y, mobility):
				return true
			if _body_collides(grid, size, position, mobility):
				break
			if direction > 0.0 and position.x > float(target_span.y) + 2.0 and position.y > float(to_node.y) + 1.0:
				break
			if direction < 0.0 and position.x < float(target_span.x) - 1.0 and position.y > float(to_node.y) + 1.0:
				break
	return false


static func _simulate_arc_with_launch(grid: Array, size: Vector2i, launch_position: Vector2, target_span: Vector2i, target_y: int, mobility: Dictionary, launch_speed_x: float, launch_speed_y: float) -> bool:
	var gravity_tiles: float = float(mobility.get("gravity_tiles_per_second_sq", 37.5))
	var max_fall_speed: float = float(mobility.get("max_fall_speed_tiles_per_second", 25.0))
	var direction: float = signf(launch_speed_x)
	if is_zero_approx(direction):
		direction = signf(float(target_span.x + target_span.y) * 0.5 - launch_position.x)
	if is_zero_approx(direction):
		direction = 1.0
	var position := launch_position
	var velocity := Vector2(launch_speed_x, launch_speed_y)
	for _step: int in range(int(MAX_SIMULATION_TIME / SAMPLE_DT)):
		position += velocity * SAMPLE_DT
		var gravity_multiplier: float = ChapterMobilityProfile.gravity_multiplier_for_velocity(velocity.y)
		velocity.y += gravity_tiles * gravity_multiplier * SAMPLE_DT
		velocity.y = minf(velocity.y, max_fall_speed)
		if _can_land_on_target_span(grid, size, position, velocity, target_span, target_y, mobility):
			return true
		if _body_collides(grid, size, position, mobility):
			return false
		if direction > 0.0 and position.x > float(target_span.y) + 2.0 and position.y > float(target_y) + 1.0:
			break
		if direction < 0.0 and position.x < float(target_span.x) - 1.0 and position.y > float(target_y) + 1.0:
			break
	return false


static func _can_dash_between(grid: Array, size: Vector2i, from_node: Vector2i, to_node: Vector2i, mobility: Dictionary) -> bool:
	var skill_flags: Dictionary = mobility.get("skill_flags", {}) as Dictionary
	if not bool(skill_flags.get("dash", false)):
		return false
	if abs(to_node.y - from_node.y) > 1:
		return false
	var dash_gap_tiles: int = int(mobility.get("dash_gap_tiles", 0))
	if dash_gap_tiles <= 0:
		return false
	var distance_x: int = abs(to_node.x - from_node.x)
	if distance_x > int(mobility.get("main_gap_tiles", 5)) + dash_gap_tiles:
		return false
	return _clear_air_band(grid, size, from_node, to_node, mobility)


static func _can_teleport_between(grid: Array, size: Vector2i, from_node: Vector2i, to_node: Vector2i, mobility: Dictionary) -> bool:
	var skill_flags: Dictionary = mobility.get("skill_flags", {}) as Dictionary
	if not bool(skill_flags.get("teleport", false)):
		return false
	if abs(to_node.x - from_node.x) > int(mobility.get("teleport_gap_tiles", 0)):
		return false
	if abs(to_node.y - from_node.y) > int(mobility.get("max_jump_up_tiles", 4)) + 1:
		return false
	return _clear_air_band(grid, size, from_node, to_node, mobility)


static func _clear_air_band(grid: Array, size: Vector2i, from_node: Vector2i, to_node: Vector2i, mobility: Dictionary) -> bool:
	var headroom_tiles: int = int(mobility.get("standing_headroom_tiles", 3))
	var left_x: int = mini(from_node.x, to_node.x)
	var right_x: int = maxi(from_node.x, to_node.x)
	var floor_y: int = mini(from_node.y, to_node.y)
	for grid_x: int in range(left_x, right_x + 1):
		for grid_y: int in range(floor_y - headroom_tiles, floor_y):
				if _grid_is_solid(grid, size, grid_x, grid_y):
					return false
	return true


static func _sample_launch_positions(span: Vector2i, preferred_direction: float) -> Array:
	var left_x: float = float(span.x) + 0.5
	var right_x: float = float(span.y) + 0.5
	var center_x: float = (left_x + right_x) * 0.5
	var ordered: Array = [center_x]
	if preferred_direction >= 0.0:
		ordered = [right_x, center_x, left_x]
	elif preferred_direction < 0.0:
		ordered = [left_x, center_x, right_x]
	var unique_positions: Array = []
	var seen: Dictionary = {}
	for position_variant: Variant in ordered:
		var launch_x: float = float(position_variant)
		var key: String = "%.2f" % launch_x
		if seen.has(key):
			continue
		seen[key] = true
		unique_positions.append(launch_x)
	return unique_positions


static func _is_valid_exit_anchor(grid: Array, size: Vector2i, cell: Vector2i, mobility: Dictionary) -> bool:
	var headroom_tiles: int = int(mobility.get("standing_headroom_tiles", 2))
	if not _is_valid_surface_for_mobility(grid, size, cell, mobility):
		return false
	if cell.x < 4 or cell.x > size.x - 5 or cell.y < 4 or cell.y > size.y - 4:
		return false

	var contiguous_floor: int = 0
	for offset_x: int in range(-2, 3):
		if _grid_is_solid(grid, size, cell.x + offset_x, cell.y):
			contiguous_floor += 1
	if contiguous_floor < 4:
		return false

	for offset_y: int in range(1, headroom_tiles + 3):
		for offset_x: int in range(-1, 2):
			if _grid_is_solid(grid, size, cell.x + offset_x, cell.y - offset_y):
				return false
	return true


static func _is_valid_stand_surface(grid: Array, size: Vector2i, cell: Vector2i, headroom_tiles: int) -> bool:
	if not _grid_is_solid(grid, size, cell.x, cell.y):
		return false
	return _has_headroom(grid, size, cell, headroom_tiles)


static func _has_headroom(grid: Array, size: Vector2i, cell: Vector2i, headroom_tiles: int) -> bool:
	for offset_y: int in range(1, headroom_tiles + 1):
		if _grid_is_solid(grid, size, cell.x, cell.y - offset_y):
			return false
	return true


static func _can_land_on_target_span(grid: Array, size: Vector2i, position: Vector2, velocity: Vector2, target_span: Vector2i, target_y: int, mobility: Dictionary) -> bool:
	if velocity.y < 0.0:
		return false
	var landing_cell_x: int = int(floor(position.x))
	if landing_cell_x < target_span.x or landing_cell_x > target_span.y:
		return false
	if position.y < float(target_y) - 0.35 or position.y > float(target_y) + 0.9:
		return false
	return _is_valid_surface_for_mobility(grid, size, Vector2i(landing_cell_x, target_y), mobility)


static func _body_collides(grid: Array, size: Vector2i, feet_position: Vector2, mobility: Dictionary) -> bool:
	var half_width: float = float(mobility.get("body_half_width_tiles", 0.36))
	var height_tiles: float = float(mobility.get("body_height_tiles", 1.75))
	var min_x: int = int(floor(feet_position.x - half_width))
	var max_x: int = int(floor(feet_position.x + half_width))
	var min_y: int = int(floor(feet_position.y - height_tiles + 0.08))
	var max_y: int = int(floor(feet_position.y - 0.12))
	for grid_y: int in range(min_y, max_y + 1):
		for grid_x: int in range(min_x, max_x + 1):
			if _grid_blocks_body(grid, size, grid_x, grid_y):
				return true
	return false


static func _grid_blocks_body(grid: Array, size: Vector2i, grid_x: int, grid_y: int) -> bool:
	if grid_x < 0 or grid_x >= size.x:
		return true
	if grid_y < 0:
		return true
	if grid_y >= size.y:
		return false
	return _grid_is_solid(grid, size, grid_x, grid_y)


static func _grid_is_solid(grid: Array, size: Vector2i, grid_x: int, grid_y: int) -> bool:
	if grid_x < 0 or grid_y < 0 or grid_x >= size.x or grid_y >= size.y:
		return false
	if grid_y >= grid.size():
		return false
	var row: PackedByteArray = grid[grid_y] as PackedByteArray
	if grid_x >= row.size():
		return false
	return row[grid_x] != 0
