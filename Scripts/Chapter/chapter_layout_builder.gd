class_name ChapterLayoutBuilder
extends RefCounted

const TerrainResolver := preload("res://Scripts/Chapter/terrain_resolver.gd")
const ChapterMobilityProfile := preload("res://Scripts/Chapter/chapter_mobility_profile.gd")
const ChapterTraversalValidator := preload("res://Scripts/Chapter/chapter_traversal_validator.gd")

const ROOM_ROLE_START := "start"
const ROOM_ROLE_INTRO := "intro"
const ROOM_ROLE_TRAVERSAL := "traversal"
const ROOM_ROLE_COMBAT := "combat"
const ROOM_ROLE_VERTICAL := "vertical"
const ROOM_ROLE_LANDMARK := "landmark"
const ROOM_ROLE_CHOKE := "choke"
const ROOM_ROLE_BRANCH := "branch"
const ROOM_ROLE_EXIT := "exit"
const ROOM_ROLE_BOSS := "boss"

const MAX_GENERATION_ATTEMPTS := 14
const ROOM_OVERLAP_TILES := 4
const ROOM_PADDING_TILES := 2
const CONNECTION_PLATFORM_WIDTH := 4
const BRANCH_CONNECTION_WIDTH := 5

var level_data: Dictionary = {}
var level_size: Vector2i = Vector2i.ZERO
var mobility_profile: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var layout_style: String = "horizontal"
var layout_signature: String = "sweeping"
var branch_signature: String = "alcove"
var vertical_signature: String = "alternating"
var path_tilt: float = 0.0
var main_rooms: Array = []
var side_rooms: Array = []
var generated_platforms: Array = []
var connection_platforms: Array = []
var critical_path_nodes: Array = []
var side_path_lines: Array = []


static func build_level_layout(source_level_data: Dictionary, source_level_size: Vector2i, seed: int) -> Dictionary:
	var builder := new()
	return builder._build(source_level_data, source_level_size, seed)


func _build(source_level_data: Dictionary, source_level_size: Vector2i, seed: int) -> Dictionary:
	level_data = source_level_data.duplicate(true)
	level_size = source_level_size
	layout_style = _resolve_layout_style()
	mobility_profile = ChapterMobilityProfile.build_for_level(level_data)

	var best_candidate: Dictionary = {}
	var best_score: float = -INF
	for attempt_index: int in range(MAX_GENERATION_ATTEMPTS):
		rng.seed = int(seed) + attempt_index * 7919 + int(level_data.get("level_index", 0)) * 131
		_reset_generation_state()
		_select_generation_profiles()
		main_rooms = _build_main_rooms()
		side_rooms = _build_side_rooms(main_rooms, _pickup_budget())
		_generate_main_room_geometry()
		_generate_side_room_geometry()
		_build_connection_platforms()

		var grid: Array = _build_solid_grid()
		var pickups: Array = _place_pickups()
		var hazards: Array = _place_hazards(grid)
		var enemies: Array = _place_enemies()
		var torches: Array = _place_torches()
		var triggers: Array = _place_triggers()
		var boss: Dictionary = _place_boss()

		var validation: Dictionary = ChapterTraversalValidator.validate_layout({
			"grid": grid,
			"level_size": level_size,
			"mobility_profile": mobility_profile,
			"rooms": _build_debug_rooms(),
			"critical_path_nodes": critical_path_nodes.duplicate(true),
			"side_path_lines": side_path_lines.duplicate(true),
			"pickups": pickups,
			"spawn": _first_path_node(),
			"exit": _last_path_node()
		})
		var repair_applied: bool = false
		var repair_passes: int = 0
		while repair_passes < 4:
			var repaired_any: bool = false
			if _repair_invalid_edges(validation):
				repaired_any = true
			if _repair_softlock_routes(validation):
				repaired_any = true
			if not repaired_any:
				break
			repair_applied = true
			repair_passes += 1
			grid = _build_solid_grid()
			validation = ChapterTraversalValidator.validate_layout({
				"grid": grid,
				"level_size": level_size,
				"mobility_profile": mobility_profile,
				"rooms": _build_debug_rooms(),
				"critical_path_nodes": critical_path_nodes.duplicate(true),
				"side_path_lines": side_path_lines.duplicate(true),
				"pickups": pickups,
				"spawn": _first_path_node(),
				"exit": _last_path_node()
			})
		validation["repair_applied"] = repair_applied
		validation["repair_pass_count"] = repair_passes
		validation["attempt_index"] = attempt_index
		validation["enemy_budget"] = enemies.size()
		validation["pickup_budget"] = pickups.size()
		validation["hazard_budget"] = hazards.size()
		validation["threat_budget_total"] = _count_room_threat_budget()
		validation["layout_signature"] = layout_signature
		validation["branch_signature"] = branch_signature
		validation["vertical_signature"] = vertical_signature
		validation["room_variety_score"] = _room_variety_score()

		var candidate: Dictionary = _assemble_result(grid, pickups, enemies, hazards, torches, triggers, boss, validation)
		var score: float = _score_validation(validation)
		if best_candidate.is_empty() or score > best_score:
			best_candidate = candidate
			best_score = score

		if bool(validation.get("path_valid", false)) \
		and int(validation.get("invalid_jump_count", 0)) == 0 \
		and int(validation.get("unreachable_reward_count", 0)) == 0 \
		and int(validation.get("unreachable_room_count", 0)) == 0:
			return candidate

	var best_validation: Dictionary = best_candidate.get("layout_validation", {}) as Dictionary if not best_candidate.is_empty() else {}
	if bool(best_validation.get("path_valid", false)) \
	and int(best_validation.get("invalid_jump_count", 0)) == 0 \
	and int(best_validation.get("unreachable_reward_count", 0)) == 0 \
	and int(best_validation.get("unreachable_room_count", 0)) == 0:
		return best_candidate
	var fallback_result: Dictionary = _build_curated_fallback_result()
	fallback_result["generator_best_validation"] = best_validation.duplicate(true)
	return fallback_result


func _reset_generation_state() -> void:
	main_rooms.clear()
	side_rooms.clear()
	generated_platforms.clear()
	connection_platforms.clear()
	critical_path_nodes.clear()
	side_path_lines.clear()


func _select_generation_profiles() -> void:
	var horizontal_profiles: Array = ["sweeping", "gauntlet", "terraces", "pockets"]
	var vertical_profiles: Array = ["spire", "switchback", "cathedral"]
	var branch_profiles: Array = ["alcove", "hook", "stepwell"]
	var vertical_patterns: Array = ["alternating", "spine", "zigzag"]
	if layout_style == "vertical":
		layout_signature = str(vertical_profiles[rng.randi_range(0, vertical_profiles.size() - 1)])
	else:
		layout_signature = str(horizontal_profiles[rng.randi_range(0, horizontal_profiles.size() - 1)])
	branch_signature = str(branch_profiles[rng.randi_range(0, branch_profiles.size() - 1)])
	vertical_signature = str(vertical_patterns[rng.randi_range(0, vertical_patterns.size() - 1)])
	path_tilt = rng.randf_range(-0.9, 0.9)


func _resolve_layout_style() -> String:
	if level_data.has("layout_style"):
		return str(level_data.get("layout_style", "horizontal"))
	var spawn_tile: Vector2i = level_data.get("spawn", Vector2i(4, 28)) as Vector2i
	var exit_tile: Vector2i = level_data.get("exit", Vector2i(level_size.x - 8, level_size.y - 10)) as Vector2i
	if level_size.y >= 50:
		return "vertical"
	if abs(exit_tile.y - spawn_tile.y) >= 16:
		return "vertical"
	return "horizontal"


func _build_main_rooms() -> Array:
	var room_count: int = _target_room_count()
	var role_sequence: Array = _build_role_sequence(room_count)
	var room_dimensions: Array = _resolve_main_room_dimensions(role_sequence)
	var rooms: Array = []
	var spawn_tile: Vector2i = level_data.get("spawn", Vector2i(4, 28)) as Vector2i
	var exit_tile: Vector2i = level_data.get("exit", Vector2i(level_size.x - 8, level_size.y - 10)) as Vector2i
	var cursor_x: int = ROOM_PADDING_TILES
	var previous_floor_y: int = spawn_tile.y

	for room_index: int in range(role_sequence.size()):
		var role: String = str(role_sequence[room_index])
		var difficulty: float = float(room_index) / maxf(1.0, float(role_sequence.size() - 1))
		var dimensions: Vector2i = room_dimensions[room_index] as Vector2i
		var desired_exit_y: int = int(round(lerpf(float(spawn_tile.y), float(exit_tile.y), float(room_index + 1) / maxf(1.0, float(role_sequence.size() - 1)))))
		desired_exit_y += _room_floor_bias(role, difficulty)
		desired_exit_y = _clamp_floor_transition(previous_floor_y, desired_exit_y, difficulty, role)
		if room_index == role_sequence.size() - 1:
			desired_exit_y = exit_tile.y
		var rect_y: int = _room_rect_y(dimensions.y, previous_floor_y, desired_exit_y, role)
		var rect := Rect2i(cursor_x, rect_y, dimensions.x, dimensions.y)
		var room: Dictionary = {
			"id": "room_%d" % room_index,
			"index": room_index,
			"role": role,
			"difficulty": difficulty,
			"rect": rect,
			"entry_floor_y": previous_floor_y,
			"exit_floor_y": desired_exit_y,
			"carve_style": "vertical" if role == ROOM_ROLE_VERTICAL else "horizontal",
			"platforms": [],
			"secondary_platforms": [],
			"pickup_slots": [],
			"ground_slots": [],
			"air_slots": [],
			"hazard_slots": [],
			"torch_slots": [],
			"entry_node": Vector2i.ZERO,
			"exit_node": Vector2i.ZERO,
			"branch_portal": Vector2i.ZERO,
			"path_nodes": [],
			"threat_budget": _room_threat_budget(role, difficulty)
		}
		rooms.append(room)
		cursor_x = rect.position.x + rect.size.x - ROOM_OVERLAP_TILES
		previous_floor_y = desired_exit_y
	return rooms


func _target_room_count() -> int:
	var progress: float = _level_progress()
	var base_count: int = 8 + int(progress >= 0.08) + int(progress >= 0.26) + int(progress >= 0.48) + int(progress >= 0.72) + int(progress >= 0.9)
	if layout_signature == "pockets" or layout_signature == "gauntlet" or layout_signature == "terraces" or layout_signature == "cathedral":
		base_count += 1
	if layout_style == "vertical":
		base_count = 8 + int(progress >= 0.18) + int(progress >= 0.42) + int(progress >= 0.66) + int(progress >= 0.84) + int(level_size.y >= 52)
		if layout_signature == "spire" or layout_signature == "switchback":
			base_count += 1
	if level_data.has("boss"):
		base_count = max(base_count, 9)
	var max_feasible: int = clampi(int(floor(float(level_size.x) / (13.2 if layout_style == "vertical" else 11.6))), 8, 12)
	if layout_style == "vertical":
		max_feasible = clampi(max_feasible, 8, 10)
	return clampi(min(base_count, max_feasible), 8, 12)


func _build_role_sequence(room_count: int) -> Array:
	var roles: Array = [ROOM_ROLE_START]
	if room_count >= 6:
		roles.append(ROOM_ROLE_INTRO)

	var wants_combat: bool = _enemy_budget() > 0
	var wants_extra_combat: bool = wants_combat and _level_progress() >= 0.58 and layout_signature == "gauntlet"
	var wants_choke: bool = _hazard_budget() > 0 or layout_signature == "gauntlet"
	var wants_vertical: bool = layout_style == "vertical" or _level_progress() >= 0.45 or layout_signature == "terraces" or layout_signature == "spire"
	var wants_landmark: bool = room_count >= 5
	var wants_extra_landmark: bool = room_count >= 7 and (layout_signature == "cathedral" or layout_signature == "pockets")

	while roles.size() < room_count - 1:
		var slot_progress: float = float(roles.size()) / maxf(1.0, float(room_count - 2))
		var remaining: int = room_count - 1 - roles.size()
		if wants_vertical and slot_progress >= (0.22 if layout_style == "vertical" or layout_signature == "spire" else 0.48):
			roles.append(ROOM_ROLE_VERTICAL)
			wants_vertical = false
			continue
		if wants_combat and slot_progress >= (0.18 if layout_signature == "gauntlet" else 0.28):
			roles.append(ROOM_ROLE_COMBAT)
			wants_combat = false
			continue
		if wants_extra_combat and slot_progress >= 0.52 and remaining >= 2:
			roles.append(ROOM_ROLE_COMBAT)
			wants_extra_combat = false
			continue
		if wants_landmark and (remaining <= 2 or (layout_signature == "cathedral" and slot_progress >= 0.42)):
			roles.append(ROOM_ROLE_LANDMARK)
			wants_landmark = false
			continue
		if wants_extra_landmark and slot_progress >= 0.68 and remaining >= 2:
			roles.append(ROOM_ROLE_LANDMARK)
			wants_extra_landmark = false
			continue
		if wants_choke and slot_progress >= (0.42 if layout_signature == "gauntlet" else 0.58):
			roles.append(ROOM_ROLE_CHOKE)
			wants_choke = false
			continue
		roles.append(ROOM_ROLE_TRAVERSAL)

	if roles.size() > room_count - 1:
		roles.resize(room_count - 1)
	if not wants_landmark and not roles.has(ROOM_ROLE_LANDMARK) and roles.size() >= 3:
		roles[roles.size() - 2] = ROOM_ROLE_LANDMARK

	roles.append(ROOM_ROLE_BOSS if level_data.has("boss") else ROOM_ROLE_EXIT)
	return roles


func _room_dimensions(role: String, difficulty: float) -> Vector2i:
	var size: Vector2i
	match role:
		ROOM_ROLE_START:
			size = Vector2i(18, 13)
		ROOM_ROLE_INTRO:
			size = Vector2i(20, 13)
		ROOM_ROLE_COMBAT:
			size = Vector2i(22 + int(difficulty >= 0.45), 15)
		ROOM_ROLE_VERTICAL:
			size = Vector2i(19, 22 + int(difficulty >= 0.55) * 2)
		ROOM_ROLE_LANDMARK:
			size = Vector2i(24, 16)
		ROOM_ROLE_CHOKE:
			size = Vector2i(18, 14)
		ROOM_ROLE_EXIT:
			size = Vector2i(20, 14)
		ROOM_ROLE_BOSS:
			size = Vector2i(34, 16)
		_:
			size = Vector2i(20 + int(difficulty >= 0.45), 14)

	match layout_signature:
		"gauntlet":
			if role == ROOM_ROLE_COMBAT or role == ROOM_ROLE_CHOKE:
				size.x += 1
				size.y += 1
			elif role == ROOM_ROLE_TRAVERSAL:
				size.x = max(size.x - 1, _min_room_width(role))
		"terraces":
			if role == ROOM_ROLE_TRAVERSAL or role == ROOM_ROLE_LANDMARK:
				size.y += 1
			if role == ROOM_ROLE_VERTICAL:
				size.y += 2
		"pockets":
			if role == ROOM_ROLE_TRAVERSAL:
				size.x += 2
			elif role == ROOM_ROLE_LANDMARK:
				size.x += 2
				size.y += 1
		"spire":
			if role == ROOM_ROLE_VERTICAL:
				size.x = max(size.x - 1, 17)
				size.y += 3
		"cathedral":
			if role == ROOM_ROLE_LANDMARK:
				size.x += 3
				size.y += 2
			elif role == ROOM_ROLE_TRAVERSAL:
				size.y += 1
		"switchback":
			if role == ROOM_ROLE_VERTICAL:
				size.y += 1
			elif role == ROOM_ROLE_TRAVERSAL:
				size.x += 1
		_:
			pass
	return size


func _min_room_width(role: String) -> int:
	match role:
		ROOM_ROLE_START:
			return 15
		ROOM_ROLE_INTRO:
			return 16
		ROOM_ROLE_COMBAT:
			return 18
		ROOM_ROLE_LANDMARK:
			return 20
		ROOM_ROLE_BOSS:
			return 30
		_:
			return 14


func _resolve_main_room_dimensions(role_sequence: Array) -> Array:
	var dimensions: Array = []
	var widths_total: int = 0
	var available_total: int = level_size.x - (ROOM_PADDING_TILES * 2) + ROOM_OVERLAP_TILES * maxi(role_sequence.size() - 1, 0)
	for room_index: int in range(role_sequence.size()):
		var role: String = str(role_sequence[room_index])
		var difficulty: float = float(room_index) / maxf(1.0, float(role_sequence.size() - 1))
		var size_hint: Vector2i = _room_dimensions(role, difficulty)
		dimensions.append(size_hint)
		widths_total += size_hint.x

	var delta: int = available_total - widths_total
	while delta != 0:
		var changed: bool = false
		for room_index: int in range(dimensions.size()):
			var role: String = str(role_sequence[room_index])
			var size_hint: Vector2i = dimensions[room_index] as Vector2i
			if delta < 0:
				if size_hint.x <= _min_room_width(role):
					continue
				size_hint.x -= 1
				delta += 1
				changed = true
			else:
				if role == ROOM_ROLE_START or role == ROOM_ROLE_EXIT or role == ROOM_ROLE_BOSS:
					continue
				size_hint.x += 1
				delta -= 1
				changed = true
			dimensions[room_index] = size_hint
			if delta == 0:
				break
		if not changed:
			break
	return dimensions


func _room_floor_bias(role: String, difficulty: float) -> int:
	match role:
		ROOM_ROLE_INTRO:
			return -1 + int(round(path_tilt * 0.5))
		ROOM_ROLE_COMBAT:
			return clampi(rng.randi_range(-1, 1) + int(round(path_tilt * 0.5)), -2, 2)
		ROOM_ROLE_VERTICAL:
			var vertical_bias: int = -rng.randi_range(2, 4 + int(difficulty >= 0.55))
			if layout_signature == "spire":
				vertical_bias -= 1
			return vertical_bias
		ROOM_ROLE_LANDMARK:
			return -rng.randi_range(1, 2) + int(round(path_tilt))
		ROOM_ROLE_CHOKE:
			return clampi(rng.randi_range(-1, 1) + int(sign(path_tilt)), -2, 2)
		ROOM_ROLE_EXIT:
			return 0
		_:
			var base_bias: int = rng.randi_range(-1, 1 + int(layout_style == "vertical"))
			match layout_signature:
				"sweeping":
					base_bias += int(round(path_tilt))
				"terraces":
					base_bias -= 1
				"pockets":
					if difficulty > 0.45:
						base_bias += 1 if rng.randf() > 0.45 else 0
				"gauntlet":
					base_bias = clampi(base_bias, -1, 1)
				_:
					pass
			return clampi(base_bias, -2, 2)


func _room_rect_y(height_tiles: int, entry_y: int, exit_y: int, role: String) -> int:
	var ceiling_padding: int = 7
	if role == ROOM_ROLE_VERTICAL:
		ceiling_padding = 9
	elif role == ROOM_ROLE_LANDMARK:
		ceiling_padding = 8
	elif role == ROOM_ROLE_START:
		ceiling_padding = 6
	var floor_padding: int = 4
	var min_floor: int = mini(entry_y, exit_y)
	var max_floor: int = maxi(entry_y, exit_y)
	var rect_y: int = min_floor - ceiling_padding
	var desired_bottom: int = max_floor + floor_padding
	if rect_y + height_tiles < desired_bottom:
		rect_y = desired_bottom - height_tiles
	return clampi(rect_y, ROOM_PADDING_TILES, level_size.y - height_tiles - ROOM_PADDING_TILES)


func _main_climb_budget(difficulty: float, role: String) -> int:
	var budget: int = int(mobility_profile.get("max_jump_up_tiles", 4))
	if role == ROOM_ROLE_START or role == ROOM_ROLE_INTRO:
		budget = max(2, budget - 1)
	elif role == ROOM_ROLE_VERTICAL:
		budget = min(budget, int(mobility_profile.get("wall_jump_up_tiles", budget + 1)))
	if difficulty <= 0.15:
		budget = max(2, budget - 1)
	return budget


func _main_drop_budget(difficulty: float, role: String) -> int:
	var budget: int = int(mobility_profile.get("readable_drop_tiles", 6))
	if role == ROOM_ROLE_START or role == ROOM_ROLE_INTRO:
		budget = max(3, budget - 2)
	elif role == ROOM_ROLE_VERTICAL:
		budget = min(int(mobility_profile.get("safe_drop_tiles", budget + 1)), budget + 1)
	elif difficulty >= 0.6:
		budget = min(int(mobility_profile.get("safe_drop_tiles", budget + 1)), budget + 1)
	return budget


func _clamp_floor_transition(previous_y: int, desired_y: int, difficulty: float, role: String) -> int:
	var max_climb: int = _main_climb_budget(difficulty, role)
	var max_drop: int = _main_drop_budget(difficulty, role)
	var delta_y: int = desired_y - previous_y
	if delta_y < -max_climb:
		return previous_y - max_climb
	if delta_y > max_drop:
		return previous_y + max_drop
	return desired_y


func _build_side_rooms(host_rooms: Array, pickup_budget: int) -> Array:
	var branches: Array = []
	var candidates: Array = []
	for room_variant: Variant in host_rooms:
		var room: Dictionary = room_variant as Dictionary
		var role: String = str(room.get("role", ""))
		if role == ROOM_ROLE_TRAVERSAL or role == ROOM_ROLE_VERTICAL or role == ROOM_ROLE_LANDMARK or role == ROOM_ROLE_CHOKE:
			candidates.append(room)
	if candidates.is_empty():
		return branches

	var progress: float = _level_progress()
	var desired_branches: int = 4 + int(progress >= 0.12) + int(progress >= 0.34) + int(progress >= 0.56) + int(progress >= 0.78)
	if layout_signature == "pockets" or branch_signature == "stepwell":
		desired_branches += 1
	if host_rooms.size() >= 8:
		desired_branches += 1
	if pickup_budget > 0:
		desired_branches = max(desired_branches, mini(candidates.size(), pickup_budget + 2 + int(progress >= 0.58)))
	desired_branches = mini(desired_branches, candidates.size())
	var used_candidate_indices: Dictionary = {}
	for branch_index: int in range(desired_branches):
		var spread_t: float = float(branch_index + 1) / float(desired_branches + 1)
		var candidate_index: int = clampi(int(round(spread_t * float(maxi(0, candidates.size() - 1)))), 0, candidates.size() - 1)
		while used_candidate_indices.has(candidate_index) and candidate_index < candidates.size() - 1:
			candidate_index += 1
		while used_candidate_indices.has(candidate_index) and candidate_index > 0:
			candidate_index -= 1
		used_candidate_indices[candidate_index] = true
		var host_room: Dictionary = candidates[candidate_index] as Dictionary
		var host_rect: Rect2i = host_room.get("rect", Rect2i()) as Rect2i
		var branch_width: int = 13 + rng.randi_range(0, 2) + int(progress >= 0.4)
		var branch_height: int = 8 + rng.randi_range(0, 2) + int(progress >= 0.55)
		if branch_signature == "hook":
			branch_width += 2
		elif branch_signature == "stepwell":
			branch_height += 2
		var host_anchor_y: int = int(round((float(host_room.get("entry_floor_y", 0)) + float(host_room.get("exit_floor_y", 0))) * 0.5))
		var upward: bool = host_rect.position.y > branch_height + 2
		if not upward and host_rect.position.y + host_rect.size.y + branch_height > level_size.y - ROOM_PADDING_TILES:
			upward = true
		var horizontal_bias: float = 0.28 if branch_index % 2 == 0 else 0.62
		if layout_signature == "pockets":
			horizontal_bias = 0.22 + rng.randf_range(0.0, 0.5)
		var branch_x: int = clampi(
			host_rect.position.x + int(host_rect.size.x * horizontal_bias) - int(branch_width * 0.5) + rng.randi_range(-2, 2),
			ROOM_PADDING_TILES,
			level_size.x - branch_width - ROOM_PADDING_TILES
		)
		var branch_climb_budget: int = int(mobility_profile.get("max_jump_up_tiles", 4)) + int(bool((mobility_profile.get("skill_flags", {}) as Dictionary).get("wall_slide", false)))
		var branch_entry_delta: int = clampi(2 + int(progress >= 0.55) + int(progress >= 0.8), 2, max(3, branch_climb_budget - 1))
		var branch_y: int
		if upward:
			var entry_target_y: int = host_anchor_y - branch_entry_delta
			branch_y = entry_target_y - (branch_height - 4)
		else:
			var entry_target_y: int = host_anchor_y + min(branch_entry_delta, int(mobility_profile.get("readable_drop_tiles", 6)))
			branch_y = entry_target_y - 3
		branch_y = clampi(branch_y, ROOM_PADDING_TILES, level_size.y - branch_height - ROOM_PADDING_TILES)
		branches.append({
			"id": "branch_%d" % branch_index,
			"index": host_rooms.size() + branch_index,
			"role": ROOM_ROLE_BRANCH,
			"difficulty": min(1.0, float(host_room.get("difficulty", 0.0)) + 0.08),
			"rect": Rect2i(branch_x, branch_y, branch_width, branch_height),
			"entry_floor_y": host_rect.position.y + int(host_rect.size.y * 0.58),
			"exit_floor_y": host_rect.position.y + int(host_rect.size.y * 0.44),
			"carve_style": "horizontal",
			"platforms": [],
			"secondary_platforms": [],
			"pickup_slots": [],
			"ground_slots": [],
			"air_slots": [],
			"hazard_slots": [],
			"torch_slots": [],
			"entry_node": Vector2i.ZERO,
			"exit_node": Vector2i.ZERO,
			"host_room_id": str(host_room.get("id", "")),
			"host_anchor_x": clampi(host_rect.position.x + int(host_rect.size.x * horizontal_bias), branch_x + 2, branch_x + branch_width - 3),
			"branch_upward": upward,
			"branch_shape": branch_signature,
			"path_nodes": [],
			"threat_budget": 1.0 + int(_level_progress() >= 0.55)
		})
	return branches


func _generate_main_room_geometry() -> void:
	for room_index: int in range(main_rooms.size()):
		var room: Dictionary = main_rooms[room_index] as Dictionary
		var entry_y: int = int(room.get("entry_floor_y", 0))
		var exit_y: int = int(room.get("exit_floor_y", 0))
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
		var host_room: Dictionary = _find_room_by_id(main_rooms, str(branch_room.get("host_room_id", "")))
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
		end_y = start_y
	elif role == ROOM_ROLE_INTRO:
		start_y = clampi(start_y, max_y - 1, max_y)
		end_y = clampi(end_y, max_y - 2, max_y)
	elif role == ROOM_ROLE_EXIT:
		end_y = clampi(end_y, max_y - 1, max_y)

	var path_nodes: Array = _compose_horizontal_path_nodes(room, left_x, right_x, start_y, end_y, min_y, max_y)
	var primary_platforms: Array = _platforms_from_path_nodes(path_nodes, role)
	var secondary_platforms: Array = _secondary_platforms_for_room(room, path_nodes, min_y, max_y)
	var pickup_slots: Array = []
	var air_slots: Array = []
	var hazard_slots: Array = []

	match role:
		ROOM_ROLE_START:
			primary_platforms[0] = _make_platform(maxi(rect.position.x + 2, left_x - 2), start_y, 10, 1, "floor")
		ROOM_ROLE_COMBAT:
			var combat_floor_y: int = clampi(max(start_y, end_y), min_y, max_y)
			primary_platforms = [_make_platform(rect.position.x + 2, combat_floor_y, rect.size.x - 4, 1, "ledge")]
			path_nodes = _densify_path_nodes([
				Vector2i(rect.position.x + 4, combat_floor_y),
				Vector2i(rect.position.x + int(rect.size.x * 0.52), combat_floor_y),
				Vector2i(rect.position.x + rect.size.x - 5, combat_floor_y)
			])
			air_slots = _room_air_slots(rect, path_nodes, role)
		ROOM_ROLE_LANDMARK:
			if not secondary_platforms.is_empty():
				var shelf: Dictionary = secondary_platforms.back() as Dictionary
				pickup_slots.append(Vector2i(int(shelf.get("x", 0)) + int(int(shelf.get("w", 1)) / 2), int(shelf.get("y", 0)) - 1))
		ROOM_ROLE_CHOKE:
			for node_index: int in range(path_nodes.size() - 1):
				var from_node: Vector2i = path_nodes[node_index] as Vector2i
				var to_node: Vector2i = path_nodes[node_index + 1] as Vector2i
				if to_node.x - from_node.x >= max(4, int(mobility_profile.get("main_gap_tiles", 5)) - 1):
					hazard_slots.append(Vector2i(from_node.x + int((to_node.x - from_node.x) / 2), rect.position.y + rect.size.y - 2))
					break
		ROOM_ROLE_EXIT:
			primary_platforms[primary_platforms.size() - 1] = _make_platform(rect.position.x + rect.size.x - 10, end_y, 8, 1, "ledge")
		_:
			pass

	room["path_nodes"] = path_nodes
	room["motif"] = str(room.get("motif", "plain"))
	room["platforms"] = primary_platforms
	room["secondary_platforms"] = secondary_platforms
	room["carve_style"] = "horizontal"
	room["entry_node"] = path_nodes.front()
	room["exit_node"] = path_nodes.back()
	room["ground_slots"] = _room_ground_slots(primary_platforms, secondary_platforms, role)
	room["air_slots"] = air_slots if not air_slots.is_empty() else _room_air_slots(rect, path_nodes, role)
	room["pickup_slots"] = pickup_slots
	room["torch_slots"] = _room_torch_slots(rect, path_nodes, role)
	room["hazard_slots"] = hazard_slots if not hazard_slots.is_empty() else _room_hazard_slots(rect, path_nodes, role)
	room["cavern_windows"] = _build_cavern_windows(rect, role, path_nodes, int(room.get("index", 0)))
	room["branch_portal"] = _mid_path_anchor(path_nodes)


func _horizontal_floor_range(rect: Rect2i, role: String) -> Vector2i:
	var top_ratio: float = 0.58
	match role:
		ROOM_ROLE_START:
			top_ratio = 0.68
		ROOM_ROLE_INTRO:
			top_ratio = 0.64
		ROOM_ROLE_COMBAT:
			top_ratio = 0.56
		ROOM_ROLE_LANDMARK:
			top_ratio = 0.52
		ROOM_ROLE_CHOKE:
			top_ratio = 0.6
		ROOM_ROLE_EXIT:
			top_ratio = 0.62
	var min_y: int = clampi(rect.position.y + int(round(rect.size.y * top_ratio)), rect.position.y + 4, rect.position.y + rect.size.y - 6)
	var max_y: int = clampi(rect.position.y + rect.size.y - 4, min_y + 1, rect.position.y + rect.size.y - 3)
	return Vector2i(min_y, max_y)


func _compose_horizontal_path_nodes(room: Dictionary, left_x: int, right_x: int, start_y: int, end_y: int, min_y: int, max_y: int) -> Array:
	var role: String = str(room.get("role", ROOM_ROLE_TRAVERSAL))
	var motif: String = _pick_horizontal_motif(role, int(room.get("index", 0)))
	room["motif"] = motif
	var path_nodes: Array = []
	var difficulty: float = float(room.get("difficulty", 0.0))

	if role == ROOM_ROLE_START:
		path_nodes = [
			Vector2i(left_x, start_y),
			Vector2i(left_x + 6, start_y),
			Vector2i(left_x + 10, max(min_y, start_y - 1)),
			Vector2i(right_x, end_y)
		]
	elif role == ROOM_ROLE_INTRO:
		path_nodes = [
			Vector2i(left_x, start_y),
			Vector2i(rect_lerp_x(left_x, right_x, 0.32), start_y),
			Vector2i(rect_lerp_x(left_x, right_x, 0.56), clampi(start_y - 1, min_y, max_y)),
			Vector2i(right_x, end_y)
		]
	elif role == ROOM_ROLE_EXIT:
		path_nodes = [
			Vector2i(left_x, start_y),
			Vector2i(rect_lerp_x(left_x, right_x, 0.45), clampi((start_y + end_y) / 2, min_y, max_y)),
			Vector2i(right_x, end_y)
		]
	else:
		var segment_count: int = max(5, int(ceil(float(right_x - left_x) / 5.2)))
		segment_count += int(difficulty >= 0.35) + int(difficulty >= 0.65)
		if layout_signature == "terraces" or layout_signature == "pockets" or layout_signature == "cathedral":
			segment_count += 1
		path_nodes.append(Vector2i(left_x, start_y))
		var previous_y: int = start_y
		var pattern: Array = _horizontal_motif_pattern(motif)
		var variation_scale: int = 1 + int(difficulty >= 0.42 and role != ROOM_ROLE_START and role != ROOM_ROLE_INTRO and role != ROOM_ROLE_EXIT)
		for segment_index: int in range(1, segment_count):
			var t: float = float(segment_index) / float(segment_count)
			var node_x: int = int(round(lerpf(float(left_x + 2), float(right_x - 2), t)))
			var baseline_y: int = int(round(lerpf(float(start_y), float(end_y), t)))
			var variation: int = int(pattern[(segment_index - 1) % pattern.size()])
			if motif == "arena":
				variation = 0
				baseline_y = maxi(start_y, end_y)
			elif motif == "choke_gap" and segment_index == 2:
				node_x += max(1, int(mobility_profile.get("main_gap_tiles", 5)) - 2)
				variation = -1
			elif motif == "bridge_dip" and segment_index == int(segment_count * 0.5):
				variation += 1
			elif motif == "drop_run" and segment_index <= 2:
				variation += 1
			var desired_y: int = clampi(baseline_y + variation * variation_scale, min_y, max_y)
			var node_y: int = _clamp_path_step(previous_y, desired_y, role, difficulty)
			path_nodes.append(Vector2i(clampi(node_x, left_x + 2, right_x - 2), node_y))
			previous_y = node_y
		path_nodes.append(Vector2i(right_x, end_y))
	var challenge_path: bool = role == ROOM_ROLE_BRANCH or role == ROOM_ROLE_CHOKE or (difficulty >= 0.62 and role != ROOM_ROLE_START and role != ROOM_ROLE_INTRO and role != ROOM_ROLE_EXIT)
	path_nodes = _densify_path_nodes(path_nodes, challenge_path)
	return path_nodes


func _pick_horizontal_motif(role: String, room_index: int) -> String:
	match role:
		ROOM_ROLE_COMBAT:
			return "arena" if layout_signature != "gauntlet" or room_index % 2 == 0 else "sawtooth"
		ROOM_ROLE_LANDMARK:
			return "cathedral_gallery" if layout_signature == "cathedral" else "gallery"
		ROOM_ROLE_CHOKE:
			return "choke_gap"
		ROOM_ROLE_EXIT:
			return "runout"
		ROOM_ROLE_START:
			return "start"
		ROOM_ROLE_INTRO:
			return "tutorial"
		_:
			var motifs: Array = ["wave", "stagger", "shelf"]
			match layout_signature:
				"sweeping":
					motifs = ["wave", "bridge_dip", "shelf"]
				"gauntlet":
					motifs = ["sawtooth", "stagger", "drop_run"]
				"terraces":
					motifs = ["terrace_run", "shelf", "wave"]
				"pockets":
					motifs = ["pocket_hop", "bridge_dip", "shelf"]
				"cathedral":
					motifs = ["gallery", "terrace_run", "wave"]
				_:
					pass
			return str(motifs[room_index % motifs.size()])


func _horizontal_motif_pattern(motif: String) -> Array:
	match motif:
		"tutorial":
			return [0, -1, 0]
		"wave":
			return [0, -1, 0, -2, -1, 0, 1]
		"stagger":
			return [0, -1, -2, -1, 0, -1]
		"shelf":
			return [-1, 0, -1, -2, -1, 0]
		"terrace_run":
			return [0, -1, -1, -2, -2, -1, 0]
		"bridge_dip":
			return [0, 0, -1, -2, -1, 0, 1]
		"pocket_hop":
			return [-1, 0, -2, 0, -1, 0]
		"sawtooth":
			return [0, -2, 0, -2, -1, 0]
		"drop_run":
			return [1, 0, -1, 0, 1, -1]
		"gallery":
			return [-1, -2, -1, 0, -1]
		"cathedral_gallery":
			return [-1, -2, -2, -1, 0, -1]
		"arena":
			return [0, 0, 0]
		"choke_gap":
			return [0, 0, -1, 0]
		"runout":
			return [0, -1, 0]
		_:
			return [0, -1, 0]


func _secondary_platforms_for_room(room: Dictionary, path_nodes: Array, min_y: int, max_y: int) -> Array:
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var role: String = str(room.get("role", ROOM_ROLE_TRAVERSAL))
	var secondary_platforms: Array = []
	var mid_node: Vector2i = path_nodes[int(path_nodes.size() / 2)] as Vector2i
	var difficulty: float = float(room.get("difficulty", 0.0))
	match role:
		ROOM_ROLE_INTRO:
			secondary_platforms.append(_make_wall_ledge(rect, false, clampi(mid_node.y - 3, rect.position.y + 4, max_y - 1), 4))
		ROOM_ROLE_TRAVERSAL:
			if rect.size.x >= 18:
				secondary_platforms.append(_make_wall_ledge(rect, (int(room.get("index", 0)) % 2) == 0, clampi(mid_node.y - 3, rect.position.y + 4, max_y - 1), 4))
				if difficulty >= 0.24 or layout_signature == "pockets":
					secondary_platforms.append(_make_platform(rect.position.x + int(rect.size.x * 0.36), clampi(mid_node.y - 2 - int(difficulty >= 0.6), rect.position.y + 4, max_y - 2), 4, 1, "ledge"))
				if difficulty >= 0.58:
					secondary_platforms.append(_make_wall_ledge(rect, (int(room.get("index", 0)) % 2) != 0, clampi(mid_node.y - 1, rect.position.y + 4, max_y - 1), 4))
		ROOM_ROLE_COMBAT:
			secondary_platforms.append(_make_platform(mid_node.x - 3, clampi(mid_node.y - 4, rect.position.y + 4, max_y - 2), 6, 1, "ledge"))
			secondary_platforms.append(_make_wall_ledge(rect, true, clampi(mid_node.y - 2, rect.position.y + 4, max_y - 1), 4))
			secondary_platforms.append(_make_wall_ledge(rect, false, clampi(mid_node.y - 1, rect.position.y + 4, max_y - 1), 4))
		ROOM_ROLE_LANDMARK:
			secondary_platforms.append(_make_wall_ledge(rect, false, clampi(mid_node.y - 4, rect.position.y + 4, max_y - 2), 5))
			secondary_platforms.append(_make_platform(rect.position.x + int(rect.size.x * 0.38), clampi(mid_node.y - 5, rect.position.y + 4, max_y - 2), 5, 1, "ledge"))
			if difficulty >= 0.4:
				secondary_platforms.append(_make_wall_ledge(rect, true, clampi(mid_node.y - 2, rect.position.y + 4, max_y - 1), 4))
		ROOM_ROLE_CHOKE:
			secondary_platforms.append(_make_platform(rect.position.x + int(rect.size.x * 0.62), clampi(mid_node.y - 3, rect.position.y + 4, max_y - 2), 4, 1, "ledge"))
			secondary_platforms.append(_make_wall_ledge(rect, true, clampi(mid_node.y - 1, rect.position.y + 4, max_y - 1), 4))
		ROOM_ROLE_EXIT:
			secondary_platforms.append(_make_wall_ledge(rect, false, clampi(path_nodes.back().y - 2, rect.position.y + 4, max_y - 1), 4))
		_:
			pass

	var deepest_path_y: int = mid_node.y
	for path_variant: Variant in path_nodes:
		var path_node: Vector2i = path_variant as Vector2i
		deepest_path_y = maxi(deepest_path_y, path_node.y)
	var floor_depth: int = rect.position.y + rect.size.y - 4 - deepest_path_y
	if floor_depth >= int(mobility_profile.get("readable_drop_tiles", 6)) + 2:
		var recovery_side_left: bool = (int(room.get("index", 0)) % 2) != 0
		var recovery_y: int = clampi(deepest_path_y + 2, rect.position.y + 5, max_y)
		secondary_platforms.append(_make_wall_ledge(rect, recovery_side_left, recovery_y, 4))
	return secondary_platforms


func _clamp_path_step(previous_y: int, desired_y: int, role: String, difficulty: float) -> int:
	var max_climb: int = _main_climb_budget(difficulty, role)
	var max_drop: int = _main_drop_budget(difficulty, role)
	var delta_y: int = desired_y - previous_y
	if delta_y < -max_climb:
		return previous_y - max_climb
	if delta_y > max_drop:
		return previous_y + max_drop
	return desired_y


func _horizontal_budget_for_step(vertical_delta: int, challenge_path: bool) -> int:
	var base_gap: int = int(mobility_profile.get("challenge_gap_tiles", 6)) if challenge_path else int(mobility_profile.get("main_gap_tiles", 5))
	var climb_tiles: int = max(0, -vertical_delta)
	var drop_tiles: int = max(0, vertical_delta)
	if climb_tiles > 0:
		var max_jump_up: int = int(mobility_profile.get("max_jump_up_tiles", 4))
		var budget: int = base_gap - climb_tiles - int(climb_tiles >= max_jump_up)
		return clampi(budget, 2, base_gap)
	if drop_tiles >= int(mobility_profile.get("readable_drop_tiles", 6)):
		return max(2, base_gap - 1)
	return base_gap


func _segment_within_traversal_budget(from_node: Vector2i, to_node: Vector2i, challenge_path: bool) -> bool:
	var delta_x: int = abs(to_node.x - from_node.x)
	var delta_y: int = to_node.y - from_node.y
	var max_climb: int = int(mobility_profile.get("max_jump_up_tiles", 4))
	var max_drop: int = int(mobility_profile.get("readable_drop_tiles", 6))
	var climb_tiles: int = max(0, -delta_y)
	var drop_tiles: int = max(0, delta_y)
	if climb_tiles > max_climb or drop_tiles > max_drop:
		return false
	if delta_x > _horizontal_budget_for_step(delta_y, challenge_path):
		return false
	if climb_tiles > 0 and delta_x < 2:
		return false
	return _synthetic_traversal_valid(from_node, to_node)


func _synthetic_traversal_valid(from_node: Vector2i, to_node: Vector2i) -> bool:
	var padding_x: int = 8
	var padding_y: int = 8 + int(mobility_profile.get("max_jump_up_tiles", 4))
	var origin_x: int = mini(from_node.x, to_node.x) - padding_x
	var origin_y: int = mini(from_node.y, to_node.y) - padding_y
	var size := Vector2i(
		max(24, abs(to_node.x - from_node.x) + padding_x * 2 + 8),
		max(18, maxi(from_node.y, to_node.y) - origin_y + padding_y + 6)
	)
	var grid: Array = []
	for _row_index: int in range(size.y):
		var row := PackedByteArray()
		row.resize(size.x)
		for grid_x: int in range(size.x):
			row[grid_x] = 0
		grid.append(row)

	var local_from := Vector2i(from_node.x - origin_x, from_node.y - origin_y)
	var local_to := Vector2i(to_node.x - origin_x, to_node.y - origin_y)
	_stamp_test_platform(grid, size, local_from.x - 2, local_from.y, 6)
	_stamp_test_platform(grid, size, local_to.x - 2, local_to.y, 6)
	return ChapterTraversalValidator._can_traverse_between(grid, size, local_from, local_to, mobility_profile)


func _stamp_test_platform(grid: Array, size: Vector2i, start_x: int, y: int, width_tiles: int) -> void:
	var clamped_y: int = clampi(y, 0, size.y - 1)
	var clamped_start_x: int = clampi(start_x, 0, size.x - 1)
	var clamped_end_x: int = clampi(start_x + width_tiles - 1, clamped_start_x, size.x - 1)
	var row: PackedByteArray = grid[clamped_y] as PackedByteArray
	for grid_x: int in range(clamped_start_x, clamped_end_x + 1):
		row[grid_x] = 1
	grid[clamped_y] = row


func _next_traversal_step(current: Vector2i, target: Vector2i, challenge_path: bool, guard: int) -> Vector2i:
	var delta_x: int = target.x - current.x
	var delta_y: int = target.y - current.y
	var max_climb: int = int(mobility_profile.get("max_jump_up_tiles", 4))
	var max_drop: int = int(mobility_profile.get("readable_drop_tiles", 6))
	var step_y: int = clampi(delta_y, -max_climb, max_drop)
	var step_x_budget: int = _horizontal_budget_for_step(step_y, challenge_path)
	var step_x: int = clampi(delta_x, -step_x_budget, step_x_budget)
	if step_y < 0 and abs(step_x) < 2:
		if delta_x == 0:
			step_x = 2 if guard % 2 == 0 else -2
		else:
			step_x = 2 if delta_x > 0 else -2
	elif step_y > 0 and abs(step_x) < 1 and challenge_path:
		step_x = 1 if delta_x >= 0 else -1
	elif step_y == 0 and step_x == 0:
		if delta_x != 0:
			step_x = 1 if delta_x > 0 else -1
		elif delta_y != 0:
			step_x = 1 if guard % 2 == 0 else -1
	var next_step := Vector2i(current.x + step_x, current.y + step_y)
	next_step.x = clampi(next_step.x, ROOM_PADDING_TILES + 1, level_size.x - ROOM_PADDING_TILES - 2)
	next_step.y = clampi(next_step.y, ROOM_PADDING_TILES + 2, level_size.y - ROOM_PADDING_TILES - 3)
	return next_step


func _densify_path_nodes(path_nodes: Array, challenge_path: bool = false) -> Array:
	if path_nodes.size() <= 1:
		return path_nodes
	var densified: Array = [path_nodes.front()]
	for node_index: int in range(1, path_nodes.size()):
		var target: Vector2i = path_nodes[node_index] as Vector2i
		var current: Vector2i = densified.back() as Vector2i
		var guard: int = 0
		while not _segment_within_traversal_budget(current, target, challenge_path) and guard < 24:
			current = _next_traversal_step(current, target, challenge_path, guard)
			if current == densified.back():
				break
			densified.append(current)
			guard += 1
		if densified.back() != target:
			densified.append(target)
	return densified


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
			if next_node.x - end_node.x > int(mobility_profile.get("main_gap_tiles", 5)):
				break
			cursor += 1
			end_node = next_node
		var platform_start_x: int = start_node.x - 1
		var platform_end_x: int = end_node.x + 1
		var minimum_width: int = 4 if role == ROOM_ROLE_BRANCH else 3
		var width_tiles: int = max(minimum_width, (platform_end_x - platform_start_x) + 1)
		var style: String = "floor" if role == ROOM_ROLE_START and platforms.is_empty() else "ledge"
		platforms.append(_make_platform(platform_start_x, start_node.y, width_tiles, 1, style))
		cursor += 1
	return platforms


func _populate_vertical_room(room: Dictionary, entry_y: int, exit_y: int) -> void:
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var top_y: int = rect.position.y + 4
	var bottom_y: int = rect.position.y + rect.size.y - 4
	var left_x: int = rect.position.x + 2
	var right_x: int = rect.position.x + rect.size.x - 7
	var center_x: int = rect.position.x + int(rect.size.x * 0.5) - 2
	var start_y: int = clampi(entry_y, top_y + 3, bottom_y)
	var target_y: int = clampi(exit_y, top_y + 2, bottom_y - 1)
	var descending: bool = target_y >= start_y
	var current_y: int = start_y
	var current_x: int = left_x if (int(room.get("index", 0)) % 2) == 0 else right_x
	var raw_path_nodes: Array = []

	raw_path_nodes.append(Vector2i(current_x + 2, start_y))

	var guard: int = 0
	var max_climb: int = _main_climb_budget(float(room.get("difficulty", 0.0)), ROOM_ROLE_VERTICAL)
	var max_drop: int = _main_drop_budget(float(room.get("difficulty", 0.0)), ROOM_ROLE_VERTICAL)
	while abs(target_y - current_y) > 3 and guard < 14:
		var delta_y: int = target_y - current_y
		var step_y: int = clampi(delta_y, -max_climb, max_drop)
		if step_y == 0:
			step_y = 1 if descending else -1
		current_y = clampi(current_y + step_y, top_y, bottom_y)
		if guard % 3 == 1:
			current_x = clampi(center_x, rect.position.x + 2, rect.position.x + rect.size.x - 8)
			raw_path_nodes.append(Vector2i(current_x + 3, current_y))
		else:
			current_x = right_x if current_x == left_x else left_x
			raw_path_nodes.append(Vector2i(current_x + 2, current_y))
		guard += 1

	raw_path_nodes.append(Vector2i(clampi(center_x + 4, rect.position.x + 5, rect.position.x + rect.size.x - 5), target_y))
	var path_nodes: Array = _densify_path_nodes(raw_path_nodes)
	var platforms: Array = _platforms_from_path_nodes(path_nodes, ROOM_ROLE_VERTICAL)
	var secondary_platforms: Array = []
	if not platforms.is_empty():
		var start_node: Vector2i = path_nodes.front() as Vector2i
		var first_platform: Dictionary = platforms[0] as Dictionary
		var desired_start_x: int = clampi(start_node.x - 2, rect.position.x + 2, rect.position.x + rect.size.x - 8)
		var first_start_x: int = min(int(first_platform.get("x", desired_start_x)), desired_start_x)
		var first_end_x: int = max(int(first_platform.get("x", desired_start_x)) + int(first_platform.get("w", 1)) - 1, desired_start_x + 5)
		platforms[0] = _make_platform(first_start_x, start_node.y, (first_end_x - first_start_x) + 1, 1, "ledge")
		var end_node: Vector2i = path_nodes.back() as Vector2i
		var last_index: int = platforms.size() - 1
		var last_platform: Dictionary = platforms[last_index] as Dictionary
		var desired_exit_x: int = clampi(end_node.x - 3, rect.position.x + 2, rect.position.x + rect.size.x - 9)
		var last_start_x: int = min(int(last_platform.get("x", desired_exit_x)), desired_exit_x)
		var last_end_x: int = max(int(last_platform.get("x", desired_exit_x)) + int(last_platform.get("w", 1)) - 1, desired_exit_x + 6)
		platforms[last_index] = _make_platform(last_start_x, end_node.y, (last_end_x - last_start_x) + 1, 1, "ledge")
		secondary_platforms.append(_make_wall_ledge(rect, true, clampi(start_y - 4, top_y + 2, bottom_y - 4), 4))
		if float(room.get("difficulty", 0.0)) >= 0.38:
			secondary_platforms.append(_make_wall_ledge(rect, false, clampi(int(lerpf(float(start_y), float(target_y), 0.45)), top_y + 2, bottom_y - 4), 4))
		if float(room.get("difficulty", 0.0)) >= 0.68:
			secondary_platforms.append(_make_wall_ledge(rect, true, clampi(target_y + 3, top_y + 2, bottom_y - 4), 4))

	var pickup_y: int = clampi(int(lerpf(float(start_y), float(target_y), 0.55)), top_y + 2, bottom_y - 2)
	room["path_nodes"] = path_nodes
	room["platforms"] = platforms
	room["secondary_platforms"] = secondary_platforms
	room["carve_style"] = "vertical"
	room["entry_node"] = path_nodes.front()
	room["exit_node"] = path_nodes.back()
	room["ground_slots"] = _room_ground_slots(platforms, secondary_platforms, ROOM_ROLE_VERTICAL)
	room["air_slots"] = []
	room["pickup_slots"] = [Vector2i(clampi(center_x + 3, rect.position.x + 3, rect.position.x + rect.size.x - 4), pickup_y)]
	room["torch_slots"] = [
		Vector2i(rect.position.x + 2, clampi(start_y - 3, rect.position.y + 2, rect.position.y + rect.size.y - 5)),
		Vector2i(rect.position.x + rect.size.x - 3, clampi(target_y - 2, rect.position.y + 2, rect.position.y + rect.size.y - 5))
	]
	room["hazard_slots"] = []
	room["cavern_windows"] = _build_cavern_windows(rect, ROOM_ROLE_VERTICAL, path_nodes, int(room.get("index", 0)))
	room["branch_portal"] = _mid_path_anchor(path_nodes)


func _populate_branch_room(branch_room: Dictionary, host_room: Dictionary) -> void:
	var rect: Rect2i = branch_room.get("rect", Rect2i()) as Rect2i
	var upward: bool = bool(branch_room.get("branch_upward", true))
	var left_x: int = rect.position.x + 2
	var right_x: int = rect.position.x + rect.size.x - 3
	var entry_y: int = rect.position.y + rect.size.y - 4 if upward else rect.position.y + 3
	var reward_y: int = rect.position.y + 3 if upward else rect.position.y + rect.size.y - 4
	var mid_y: int = clampi(int(lerpf(float(entry_y), float(reward_y), 0.55)), rect.position.y + 3, rect.position.y + rect.size.y - 4)
	var host_portal: Vector2i = host_room.get("branch_portal", Vector2i.ZERO) as Vector2i
	var entry_x: int = clampi(
		host_portal.x if host_portal != Vector2i.ZERO else int(branch_room.get("host_anchor_x", rect.position.x + int(rect.size.x * 0.5))),
		rect.position.x + 3,
		rect.position.x + rect.size.x - 4
	)
	var reward_x_target: int = right_x if entry_x <= rect.position.x + int(rect.size.x * 0.5) else left_x
	var pivot_x: int = clampi(int(lerpf(float(entry_x), float(reward_x_target), 0.55)), rect.position.x + 3, rect.position.x + rect.size.x - 4)
	var path_nodes: Array = _densify_path_nodes([
		Vector2i(entry_x, entry_y),
		Vector2i(pivot_x, mid_y),
		Vector2i(reward_x_target, reward_y)
	], false)
	var platforms: Array = _platforms_from_path_nodes(path_nodes, ROOM_ROLE_BRANCH)
	var secondary_platforms: Array = []
	var branch_shape: String = str(branch_room.get("branch_shape", "alcove"))
	secondary_platforms.append(_make_wall_ledge(rect, upward, clampi(mid_y, rect.position.y + 3, rect.position.y + rect.size.y - 4), 4))
	if branch_shape == "stepwell":
		var stepwell_y: int = clampi(int(round((float(mid_y) + float(reward_y)) * 0.5)), rect.position.y + 3, rect.position.y + rect.size.y - 4)
		secondary_platforms.append(_make_wall_ledge(rect, not upward, stepwell_y, 4))
	elif branch_shape == "hook":
		secondary_platforms.append(_make_platform(rect.position.x + int(rect.size.x * 0.42), clampi(mid_y - 2 if upward else mid_y + 2, rect.position.y + 3, rect.position.y + rect.size.y - 4), 4, 1, "ledge"))
	var reward_x: int = clampi(reward_x_target, rect.position.x + 3, rect.position.x + rect.size.x - 3)
	branch_room["path_nodes"] = path_nodes
	branch_room["platforms"] = platforms
	branch_room["secondary_platforms"] = secondary_platforms
	branch_room["entry_node"] = path_nodes.front()
	branch_room["exit_node"] = path_nodes.back()
	branch_room["ground_slots"] = _room_ground_slots(platforms, secondary_platforms, ROOM_ROLE_BRANCH)
	branch_room["air_slots"] = []
	branch_room["pickup_slots"] = [Vector2i(reward_x, reward_y - 1)]
	branch_room["torch_slots"] = [Vector2i(rect.position.x + 2, clampi(mid_y - 2, rect.position.y + 2, rect.position.y + rect.size.y - 5))]
	branch_room["hazard_slots"] = []
	branch_room["cavern_windows"] = _build_cavern_windows(rect, ROOM_ROLE_BRANCH, path_nodes, int(branch_room.get("index", 0)))
	branch_room["branch_portal"] = Vector2i.ZERO
	branch_room["host_portal"] = host_room.get("branch_portal", Vector2i.ZERO)


func _mid_path_anchor(path_nodes: Array) -> Vector2i:
	if path_nodes.is_empty():
		return Vector2i.ZERO
	return path_nodes[int(path_nodes.size() / 2)] as Vector2i


func _populate_boss_room(room: Dictionary) -> void:
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var floor_y: int = rect.position.y + rect.size.y - 4
	var arena_floor := _make_platform(rect.position.x + 2, floor_y, rect.size.x - 4, 3, "floor")
	var left_pillar := _make_platform(rect.position.x + 7, floor_y - 6, 7, 1, "ledge")
	var right_pillar := _make_platform(rect.position.x + rect.size.x - 14, floor_y - 6, 7, 1, "ledge")
	var path_nodes: Array = _densify_path_nodes([
		Vector2i(rect.position.x + 6, floor_y),
		Vector2i(rect.position.x + int(rect.size.x / 2), floor_y),
		Vector2i(rect.position.x + rect.size.x - 7, floor_y)
	])
	room["path_nodes"] = path_nodes
	room["platforms"] = [arena_floor, left_pillar, right_pillar]
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
		Vector2i(rect.position.x + 16, floor_y - 1),
		Vector2i(rect.position.x + rect.size.x - 19, floor_y - 1)
	]
	room["cavern_windows"] = []
	room["branch_portal"] = Vector2i.ZERO


func _make_wall_ledge(rect: Rect2i, attach_left: bool, y: int, width_tiles: int) -> Dictionary:
	var ledge_x: int = rect.position.x + 2 if attach_left else rect.position.x + rect.size.x - width_tiles - 2
	return _make_platform(ledge_x, y, width_tiles, 1, "ledge")


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
		slots.append(Vector2i(rect.position.x + int(rect.size.x * 0.28), clampi(high_y - 1, rect.position.y + 3, high_y)))
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
	else:
		slots.append(Vector2i(rect.position.x + rect.size.x - 3, clampi(last_node.y - 3, rect.position.y + 2, rect.position.y + rect.size.y - 5)))
	if role == ROOM_ROLE_LANDMARK or role == ROOM_ROLE_COMBAT:
		slots.append(Vector2i(rect.position.x + int(rect.size.x * 0.58), clampi(int((first_node.y + last_node.y) / 2) - 4, rect.position.y + 2, rect.position.y + rect.size.y - 5)))
	return slots


func _room_hazard_slots(rect: Rect2i, path_nodes: Array, role: String) -> Array:
	var slots: Array = []
	if role == ROOM_ROLE_START or role == ROOM_ROLE_INTRO or role == ROOM_ROLE_BOSS or path_nodes.size() < 2:
		return slots
	for node_index: int in range(path_nodes.size() - 1):
		var from_node: Vector2i = path_nodes[node_index] as Vector2i
		var to_node: Vector2i = path_nodes[node_index + 1] as Vector2i
		var gap: int = to_node.x - from_node.x
		if gap < 6:
			continue
		slots.append(Vector2i(from_node.x + int(gap / 2), rect.position.y + rect.size.y - 2))
	return slots


func _build_cavern_windows(rect: Rect2i, role: String, path_nodes: Array, room_index: int) -> Array:
	var windows: Array = []
	if rect.size.x < 14 or path_nodes.is_empty():
		return windows
	var progress: float = _level_progress()
	if role == ROOM_ROLE_TRAVERSAL and room_index >= 1:
		windows.append(_make_cavern_window(rect, 0.18, 0.4, 3 + int(progress >= 0.38), (room_index % 2) == 0))
		windows.append(_make_cavern_window(rect, 0.56, 0.82, 3 + int(progress >= 0.55), (room_index % 2) != 0))
		if progress >= 0.68 or layout_signature == "pockets":
			windows.append(_make_cavern_window(rect, 0.36, 0.58, 2 + int(progress >= 0.78), room_index % 3 == 0))
	elif role == ROOM_ROLE_COMBAT:
		windows.append(_make_cavern_window(rect, 0.28, 0.58, 4, (room_index % 2) == 0))
		if progress >= 0.48:
			windows.append(_make_cavern_window(rect, 0.62, 0.84, 3, false))
	elif role == ROOM_ROLE_LANDMARK:
		windows.append(_make_cavern_window(rect, 0.18, 0.36, 4, true))
		windows.append(_make_cavern_window(rect, 0.58, 0.8, 5, false))
		if progress >= 0.62:
			windows.append(_make_cavern_window(rect, 0.38, 0.56, 3, room_index % 2 == 0))
	elif role == ROOM_ROLE_VERTICAL:
		windows.append(_make_cavern_window(rect, 0.18, 0.42, 4 + int(progress >= 0.42), true))
		windows.append(_make_cavern_window(rect, 0.56, 0.82, 4 + int(progress >= 0.58), false))
	elif role == ROOM_ROLE_CHOKE:
		windows.append(_make_cavern_window(rect, 0.22, 0.42, 3, true))
		if progress >= 0.54:
			windows.append(_make_cavern_window(rect, 0.62, 0.8, 3, false))
	elif role == ROOM_ROLE_BRANCH:
		windows.append(_make_cavern_window(rect, 0.18, 0.46, 3 + int(progress >= 0.4), true))
		if progress >= 0.45 or branch_signature == "hook":
			windows.append(_make_cavern_window(rect, 0.52, 0.82, 3 + int(progress >= 0.7), false))
	return windows


func _make_cavern_window(rect: Rect2i, start_ratio: float, end_ratio: float, depth: int, entry_from_left: bool) -> Dictionary:
	var start_x: int = rect.position.x + int(round(rect.size.x * start_ratio))
	var end_x: int = rect.position.x + int(round(rect.size.x * end_ratio))
	start_x = clampi(start_x, rect.position.x + 3, rect.position.x + rect.size.x - 7)
	end_x = clampi(end_x, start_x + 3, rect.position.x + rect.size.x - 4)
	var entry_width: int = 2
	var entry_x: int = start_x + 1 if entry_from_left else end_x - entry_width
	entry_x = clampi(entry_x, start_x + 1, end_x - entry_width)
	return {
		"start_x": start_x,
		"end_x": end_x,
		"depth": depth,
		"entry_x": entry_x,
		"entry_width": entry_width
	}


func _build_connection_platforms() -> void:
	connection_platforms.clear()
	critical_path_nodes.clear()
	side_path_lines.clear()

	for room_index: int in range(main_rooms.size()):
		var room: Dictionary = main_rooms[room_index] as Dictionary
		for point_variant: Variant in room.get("path_nodes", []) as Array:
			_append_path_point(critical_path_nodes, point_variant as Vector2i)
		if room_index >= main_rooms.size() - 1:
			continue
		var next_room: Dictionary = main_rooms[room_index + 1] as Dictionary
		var from_node: Vector2i = room.get("exit_node", Vector2i.ZERO) as Vector2i
		var to_node: Vector2i = next_room.get("entry_node", Vector2i.ZERO) as Vector2i
		var bridge_nodes: Array = _build_bridge_nodes(from_node, to_node, false)
		for bridge_variant: Variant in bridge_nodes:
			var bridge_node: Vector2i = bridge_variant as Vector2i
			connection_platforms.append(_make_platform(bridge_node.x - int(CONNECTION_PLATFORM_WIDTH / 2), bridge_node.y, CONNECTION_PLATFORM_WIDTH, 1, "ledge"))
			_append_path_point(critical_path_nodes, bridge_node)

	for branch_variant: Variant in side_rooms:
		var branch_room: Dictionary = branch_variant as Dictionary
		var host_room: Dictionary = _find_room_by_id(main_rooms, str(branch_room.get("host_room_id", "")))
		if host_room.is_empty():
			continue
		var side_line: Array = []
		var from_node: Vector2i = host_room.get("branch_portal", Vector2i.ZERO) as Vector2i
		_append_path_point(side_line, from_node)
		var bridge_nodes: Array = _build_bridge_nodes(from_node, branch_room.get("entry_node", Vector2i.ZERO) as Vector2i, false)
		for bridge_variant: Variant in bridge_nodes:
			var bridge_node: Vector2i = bridge_variant as Vector2i
			connection_platforms.append(_make_platform(bridge_node.x - int(BRANCH_CONNECTION_WIDTH / 2), bridge_node.y, BRANCH_CONNECTION_WIDTH, 1, "ledge"))
			_append_path_point(side_line, bridge_node)
		var branch_path_nodes: Array = branch_room.get("path_nodes", []) as Array
		for branch_path_variant: Variant in _sample_optional_path_nodes(branch_path_nodes):
			_append_path_point(side_line, branch_path_variant as Vector2i)
		side_path_lines.append(side_line)

	_build_loop_connectors()


func _build_loop_connectors() -> void:
	if main_rooms.size() < 4:
		return
	var progress: float = _level_progress()
	var loop_budget: int = 1 + int(progress >= 0.28) + int(progress >= 0.52) + int(progress >= 0.76)
	if main_rooms.size() >= 8 and progress >= 0.46:
		loop_budget += 1
	if layout_style == "vertical" or layout_signature == "cathedral":
		loop_budget += 1
	loop_budget = clampi(loop_budget, 0, 5)
	if loop_budget <= 0:
		return

	var used_pairs: Dictionary = {}
	for line_variant: Variant in side_path_lines:
		var line: Array = line_variant as Array
		if line.size() < 2:
			continue
		used_pairs[_optional_route_key(line.front() as Vector2i, line.back() as Vector2i)] = true

	for branch_variant: Variant in side_rooms:
		if loop_budget <= 0:
			break
		var branch_room: Dictionary = branch_variant as Dictionary
		var host_index: int = _room_index_by_id(main_rooms, str(branch_room.get("host_room_id", "")))
		if host_index < 0 or host_index >= main_rooms.size() - 2:
			continue
		var target_index: int = mini(main_rooms.size() - 2, host_index + 1 + int(progress >= 0.6 and bool(branch_room.get("branch_upward", false))))
		if target_index <= host_index:
			continue
		var target_room: Dictionary = main_rooms[target_index] as Dictionary
		var branch_exit: Vector2i = branch_room.get("exit_node", Vector2i.ZERO) as Vector2i
		var rejoin_target: Vector2i = target_room.get("branch_portal", Vector2i.ZERO) as Vector2i
		if rejoin_target == Vector2i.ZERO:
			rejoin_target = target_room.get("entry_node", Vector2i.ZERO) as Vector2i
		if branch_exit == Vector2i.ZERO or rejoin_target == Vector2i.ZERO:
			continue
		if abs(branch_exit.x - rejoin_target.x) < 8:
			continue
		if _register_optional_route(_build_loop_route(branch_exit, rejoin_target, int(branch_room.get("index", 0)) % 2 == 0), used_pairs, BRANCH_CONNECTION_WIDTH):
			loop_budget -= 1

	for room_index: int in range(1, main_rooms.size() - 2):
		if loop_budget <= 0:
			break
		var from_room: Dictionary = main_rooms[room_index] as Dictionary
		var to_room: Dictionary = main_rooms[min(room_index + 2, main_rooms.size() - 1)] as Dictionary
		var from_node: Vector2i = from_room.get("branch_portal", Vector2i.ZERO) as Vector2i
		if from_node == Vector2i.ZERO:
			from_node = from_room.get("exit_node", Vector2i.ZERO) as Vector2i
		var to_node: Vector2i = to_room.get("branch_portal", Vector2i.ZERO) as Vector2i
		if to_node == Vector2i.ZERO:
			to_node = to_room.get("entry_node", Vector2i.ZERO) as Vector2i
		if from_node == Vector2i.ZERO or to_node == Vector2i.ZERO:
			continue
		if abs(from_node.x - to_node.x) < 10:
			continue
		if _register_optional_route(_build_loop_route(from_node, to_node, room_index % 2 == 0), used_pairs, BRANCH_CONNECTION_WIDTH):
			loop_budget -= 1


func _build_loop_route(from_node: Vector2i, to_node: Vector2i, arc_upward: bool) -> Array:
	var midpoint_x: int = clampi(
		int(round((float(from_node.x) + float(to_node.x)) * 0.5)) + rng.randi_range(-2, 2),
		ROOM_PADDING_TILES + 2,
		level_size.x - ROOM_PADDING_TILES - 3
	)
	var midpoint_y: int = int(round((float(from_node.y) + float(to_node.y)) * 0.5))
	var offset: int = 2 + int(_level_progress() >= 0.48) + int(abs(to_node.x - from_node.x) >= 18)
	if arc_upward:
		midpoint_y -= offset
	else:
		midpoint_y += offset
	midpoint_y = clampi(midpoint_y, ROOM_PADDING_TILES + 3, level_size.y - ROOM_PADDING_TILES - 4)
	return _densify_path_nodes([
		from_node,
		Vector2i(midpoint_x, midpoint_y),
		to_node
	], false)


func _sample_optional_path_nodes(path_nodes: Array) -> Array:
	var sampled: Array = []
	for point_variant: Variant in path_nodes:
		_append_path_point(sampled, point_variant as Vector2i)
	return sampled


func _register_optional_route(route_points: Array, used_pairs: Dictionary, width_tiles: int) -> bool:
	if route_points.size() < 2:
		return false
	var compact_route: Array = []
	for point_variant: Variant in route_points:
		_append_path_point(compact_route, point_variant as Vector2i)
	if compact_route.size() < 2:
		return false
	var route_key: String = _optional_route_key(compact_route.front() as Vector2i, compact_route.back() as Vector2i)
	if used_pairs.has(route_key):
		return false
	used_pairs[route_key] = true
	side_path_lines.append(compact_route)
	for point_index: int in range(1, compact_route.size() - 1):
		var point: Vector2i = compact_route[point_index] as Vector2i
		connection_platforms.append(_make_platform(point.x - int(width_tiles / 2), point.y, width_tiles, 1, "ledge"))
	return true


func _optional_route_key(from_node: Vector2i, to_node: Vector2i) -> String:
	var left_node: Vector2i = from_node
	var right_node: Vector2i = to_node
	if from_node.x > to_node.x or (from_node.x == to_node.x and from_node.y > to_node.y):
		left_node = to_node
		right_node = from_node
	return "%d:%d<->%d:%d" % [left_node.x, left_node.y, right_node.x, right_node.y]


func _append_path_point(target: Array, point: Vector2i) -> void:
	if target.is_empty() or target.back() != point:
		target.append(point)


func _build_bridge_nodes(from_node: Vector2i, to_node: Vector2i, challenge_path: bool) -> Array:
	var nodes: Array = []
	var current: Vector2i = from_node
	var guard: int = 0
	while not _segment_within_traversal_budget(current, to_node, challenge_path) and guard < 24:
		current = _next_traversal_step(current, to_node, challenge_path, guard)
		nodes.append(current)
		guard += 1
	return nodes


func _build_solid_grid() -> Array:
	var grid: Array = _create_solid_grid()
	_carve_room_bodies(grid, main_rooms)
	_carve_room_bodies(grid, side_rooms)
	_carve_path_corridors(grid)
	_stamp_all_platforms(grid)
	_carve_cavern_access_shafts(grid)
	_carve_platform_headroom(grid)
	_ensure_exit_landing(grid)
	_carve_pickup_pockets(grid)
	var logical_map: Dictionary = TerrainResolver.build_logical_map(grid, level_size)
	var final_grid: Array = TerrainResolver.duplicate_cells(logical_map)
	_reinforce_traversal_geometry(final_grid)
	return final_grid


func _reinforce_traversal_geometry(grid: Array) -> void:
	_carve_polyline_corridor(grid, critical_path_nodes, 4)
	for branch_variant: Variant in side_path_lines:
		_carve_polyline_corridor(grid, branch_variant as Array, 5)
	for room_variant: Variant in main_rooms:
		_stamp_room_platforms_without_recording(grid, room_variant as Dictionary)
	for room_variant: Variant in side_rooms:
		_stamp_room_platforms_without_recording(grid, room_variant as Dictionary)
	for platform_variant: Variant in connection_platforms:
		var platform: Dictionary = platform_variant as Dictionary
		_stamp_rect(grid, int(platform.get("x", 0)), int(platform.get("y", 0)), max(1, int(platform.get("w", 1))), max(1, int(platform.get("h", 1))))
	_carve_platform_headroom_from_rooms(grid, main_rooms)
	_carve_platform_headroom_from_rooms(grid, side_rooms)
	_carve_platform_headroom_from_collection(grid, connection_platforms)
	_ensure_exit_landing(grid)


func _stamp_room_platforms_without_recording(grid: Array, room: Dictionary) -> void:
	for platform_variant: Variant in room.get("platforms", []) as Array:
		var platform: Dictionary = platform_variant as Dictionary
		_stamp_rect(grid, int(platform.get("x", 0)), int(platform.get("y", 0)), max(1, int(platform.get("w", 1))), max(1, int(platform.get("h", 1))))
	for platform_variant: Variant in room.get("secondary_platforms", []) as Array:
		var platform: Dictionary = platform_variant as Dictionary
		_stamp_rect(grid, int(platform.get("x", 0)), int(platform.get("y", 0)), max(1, int(platform.get("w", 1))), max(1, int(platform.get("h", 1))))


func _carve_platform_headroom_from_rooms(grid: Array, rooms: Array) -> void:
	for room_variant: Variant in rooms:
		var room: Dictionary = room_variant as Dictionary
		_carve_platform_headroom_from_collection(grid, room.get("platforms", []) as Array)
		_carve_platform_headroom_from_collection(grid, room.get("secondary_platforms", []) as Array)


func _carve_platform_headroom_from_collection(grid: Array, platforms: Array) -> void:
	for platform_variant: Variant in platforms:
		var platform: Dictionary = platform_variant as Dictionary
		var style: String = str(platform.get("style", "ledge"))
		var headroom: int = 5 if style == "floor" else 4
		_carve_rect(grid, int(platform.get("x", 0)) - 1, int(platform.get("y", 0)) - headroom, int(platform.get("w", 1)) + 2, headroom)


func _create_solid_grid() -> Array:
	var grid: Array = []
	for _row_index: int in range(level_size.y):
		var row := PackedByteArray()
		row.resize(level_size.x)
		for grid_x: int in range(level_size.x):
			row[grid_x] = 1
		grid.append(row)
	return grid


func _carve_room_bodies(grid: Array, rooms: Array) -> void:
	for room_variant: Variant in rooms:
		var room: Dictionary = room_variant as Dictionary
		if str(room.get("carve_style", "horizontal")) == "vertical":
			_carve_vertical_body(grid, room)
		else:
			_carve_horizontal_body(grid, room)


func _carve_horizontal_body(grid: Array, room: Dictionary) -> void:
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var role: String = str(room.get("role", ROOM_ROLE_TRAVERSAL))
	var path_nodes: Array = room.get("path_nodes", []) as Array
	if path_nodes.is_empty():
		return
	var cavern_windows: Array = room.get("cavern_windows", []) as Array
	var difficulty: float = float(room.get("difficulty", 0.0))
	var fallback_path_y: int = rect.position.y + rect.size.y - 4
	for local_x: int in range(rect.size.x):
		var world_x: int = rect.position.x + local_x
		var path_y: int = _path_height_at_x(path_nodes, world_x, fallback_path_y)
		var normalized: float = float(local_x) / maxf(1.0, float(rect.size.x - 1))
		var dome_factor: float = 1.0 - minf(1.0, absf(normalized - 0.5) * 2.0)
		var ceiling_wave: float = sin(normalized * PI * 2.1 + 0.35 + difficulty * 0.7) * 1.1
		ceiling_wave += sin(normalized * PI * 4.3 + 0.8 + difficulty * 1.2) * 0.42
		var ceiling_clearance: int = 5
		if role == ROOM_ROLE_START or role == ROOM_ROLE_INTRO:
			ceiling_clearance = 4
		elif role == ROOM_ROLE_LANDMARK:
			ceiling_clearance = 6
		elif role == ROOM_ROLE_VERTICAL:
			ceiling_clearance = 6
		var top: int = path_y - ceiling_clearance - int(round(ceiling_wave))
		if role == ROOM_ROLE_COMBAT or role == ROOM_ROLE_LANDMARK:
			top -= int(round(dome_factor * (2.0 + difficulty * 1.3)))
		elif role == ROOM_ROLE_CHOKE:
			top += int(round((1.0 - dome_factor) * 1.4))
		var shoulder_depth: int = 0
		if local_x <= 2 or local_x >= rect.size.x - 3:
			shoulder_depth = 2
		elif local_x <= 4 or local_x >= rect.size.x - 5:
			shoulder_depth = 1
		top += shoulder_depth
		var bottom: int = path_y + 1
		var cavern_depth: int = _cavern_depth_at_x(cavern_windows, world_x)
		if cavern_depth > 0:
			var center_distance: float = _cavern_window_center_distance(cavern_windows, world_x)
			bottom += cavern_depth + int(round(center_distance))
		elif role == ROOM_ROLE_LANDMARK and dome_factor > 0.72:
			bottom += 1
		top = clampi(top, rect.position.y + 1, rect.position.y + rect.size.y - 6)
		bottom = clampi(bottom, top + 5, rect.position.y + rect.size.y - 2)
		_carve_column(grid, world_x, top, bottom)

	_carve_rect(grid, rect.position.x + 1, path_nodes.front().y - 3, 4, 4)
	_carve_rect(grid, rect.position.x + rect.size.x - 5, path_nodes.back().y - 3, 4, 4)
	if role == ROOM_ROLE_TRAVERSAL or role == ROOM_ROLE_COMBAT or role == ROOM_ROLE_LANDMARK or role == ROOM_ROLE_CHOKE:
		_carve_horizontal_wall_bites(grid, room, path_nodes, fallback_path_y)


func _cavern_depth_at_x(cavern_windows: Array, world_x: int) -> int:
	for window_variant: Variant in cavern_windows:
		var window: Dictionary = window_variant as Dictionary
		if world_x < int(window.get("start_x", 0)) or world_x > int(window.get("end_x", -1)):
			continue
		return max(0, int(window.get("depth", 0)))
	return 0


func _cavern_window_center_distance(cavern_windows: Array, world_x: int) -> float:
	for window_variant: Variant in cavern_windows:
		var window: Dictionary = window_variant as Dictionary
		var start_x: int = int(window.get("start_x", 0))
		var end_x: int = int(window.get("end_x", -1))
		if world_x < start_x or world_x > end_x:
			continue
		var center_x: float = float(start_x + end_x) * 0.5
		var half_span: float = maxf(1.0, float(end_x - start_x) * 0.5)
		return 1.0 - minf(1.0, absf(float(world_x) - center_x) / half_span)
	return 0.0


func _carve_vertical_body(grid: Array, room: Dictionary) -> void:
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var path_nodes: Array = room.get("path_nodes", []) as Array
	if path_nodes.is_empty():
		return
	var difficulty: float = float(room.get("difficulty", 0.0))
	var fallback_center_x: int = rect.position.x + int(rect.size.x / 2)
	for local_y: int in range(rect.size.y):
		var world_y: int = rect.position.y + local_y
		var normalized: float = float(local_y) / maxf(1.0, float(rect.size.y - 1))
		var shaft_center_x: int = _vertical_path_center_x(path_nodes, world_y, fallback_center_x)
		var nearest_path_distance: int = 999
		for path_node_variant: Variant in path_nodes:
			var path_node: Vector2i = path_node_variant as Vector2i
			nearest_path_distance = mini(nearest_path_distance, abs(path_node.y - world_y))
		var node_proximity: float = 1.0 - minf(1.0, float(nearest_path_distance) / 6.0)
		var half_width: int = 2 + int(round(node_proximity * 2.0)) + int(absf(sin(normalized * PI * 2.0 + difficulty * 0.8)) * 1.0)
		var left_x: int = clampi(shaft_center_x - half_width, rect.position.x + 2, rect.position.x + rect.size.x - 8)
		var right_x: int = clampi(shaft_center_x + half_width, left_x + 6, rect.position.x + rect.size.x - 2)
		_carve_rect(grid, left_x, world_y, right_x - left_x + 1, 1)

	for path_node_variant: Variant in path_nodes:
		var path_node: Vector2i = path_node_variant as Vector2i
		var pocket_width: int = 6
		var pocket_height: int = 4
		if path_node == path_nodes.front() or path_node == path_nodes.back():
			pocket_width = 7
			pocket_height = 3
		_carve_rect(grid, path_node.x - int(pocket_width / 2), path_node.y - 2, pocket_width, pocket_height)


func _carve_main_connections(grid: Array) -> void:
	for room_index: int in range(main_rooms.size() - 1):
		var from_room: Dictionary = main_rooms[room_index] as Dictionary
		var to_room: Dictionary = main_rooms[room_index + 1] as Dictionary
		_carve_tunnel(grid, from_room.get("exit_node", Vector2i.ZERO) as Vector2i, to_room.get("entry_node", Vector2i.ZERO) as Vector2i, 3)


func _carve_branch_connections(grid: Array) -> void:
	for branch_variant: Variant in side_rooms:
		var branch_room: Dictionary = branch_variant as Dictionary
		var host_room: Dictionary = _find_room_by_id(main_rooms, str(branch_room.get("host_room_id", "")))
		if host_room.is_empty():
			continue
		_carve_tunnel(grid, host_room.get("branch_portal", Vector2i.ZERO) as Vector2i, branch_room.get("entry_node", Vector2i.ZERO) as Vector2i, 3)


func _carve_path_corridors(grid: Array) -> void:
	_carve_polyline_corridor(grid, critical_path_nodes, 4)
	for branch_variant: Variant in side_path_lines:
		_carve_polyline_corridor(grid, branch_variant as Array, 5)


func _carve_polyline_corridor(grid: Array, points: Array, width_tiles: int) -> void:
	if points.size() < 2:
		return
	for point_index: int in range(points.size() - 1):
		var from_point: Vector2i = points[point_index] as Vector2i
		var to_point: Vector2i = points[point_index + 1] as Vector2i
		_carve_tunnel(grid, from_point, to_point, width_tiles)


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
		_stamp_room_platforms(grid, room_variant as Dictionary)
	for room_variant: Variant in side_rooms:
		_stamp_room_platforms(grid, room_variant as Dictionary)
	for platform_variant: Variant in connection_platforms:
		var platform: Dictionary = platform_variant as Dictionary
		generated_platforms.append(platform.duplicate(true))
		_stamp_rect(grid, int(platform.get("x", 0)), int(platform.get("y", 0)), max(1, int(platform.get("w", 1))), max(1, int(platform.get("h", 1))))


func _carve_cavern_access_shafts(grid: Array) -> void:
	for room_variant: Variant in main_rooms:
		_carve_room_cavern_accesses(grid, room_variant as Dictionary)
	for room_variant: Variant in side_rooms:
		_carve_room_cavern_accesses(grid, room_variant as Dictionary)


func _carve_room_cavern_accesses(grid: Array, room: Dictionary) -> void:
	var cavern_windows: Array = room.get("cavern_windows", []) as Array
	if cavern_windows.is_empty():
		return
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var path_nodes: Array = room.get("path_nodes", []) as Array
	var fallback_path_y: int = rect.position.y + rect.size.y - 4
	for window_variant: Variant in cavern_windows:
		var window: Dictionary = window_variant as Dictionary
		var entry_x: int = int(window.get("entry_x", int(window.get("start_x", rect.position.x + 4)) + 1))
		var entry_width: int = max(2, int(window.get("entry_width", 2)) + int(_level_progress() >= 0.45))
		var depth: int = max(3, int(window.get("depth", 3)) + 1)
		var path_y: int = _path_height_at_x(path_nodes, entry_x, fallback_path_y)
		var start_x: int = int(window.get("start_x", entry_x - 1))
		var end_x: int = int(window.get("end_x", entry_x + entry_width + 1))
		_carve_rect(grid, entry_x - 1, path_y - 1, entry_width + 2, depth + 3)
		_carve_rect(grid, start_x, path_y + depth - 1, max(4, end_x - start_x + 1), 3)
		_carve_rect(grid, entry_x - 2, path_y + depth, entry_width + 4, 3)


func _ensure_exit_landing(grid: Array) -> void:
	var exit_node: Vector2i = _last_path_node()
	_stamp_rect(grid, exit_node.x - 4, exit_node.y, 10, 4)
	_stamp_rect(grid, exit_node.x + 4, exit_node.y - 1, 2, 3)
	_carve_rect(grid, exit_node.x - 5, exit_node.y - 5, 12, 5)


func _carve_horizontal_wall_bites(grid: Array, room: Dictionary, path_nodes: Array, fallback_path_y: int) -> void:
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var role: String = str(room.get("role", ROOM_ROLE_TRAVERSAL))
	if role == ROOM_ROLE_START:
		return
	var difficulty: float = float(room.get("difficulty", 0.0))
	var left_path_y: int = _path_height_at_x(path_nodes, rect.position.x + 4, fallback_path_y)
	var right_path_y: int = _path_height_at_x(path_nodes, rect.position.x + rect.size.x - 5, fallback_path_y)
	_carve_rect(grid, rect.position.x + 1, clampi(left_path_y - 6, rect.position.y + 2, rect.position.y + rect.size.y - 7), 3, 4)
	_carve_rect(grid, rect.position.x + rect.size.x - 4, clampi(right_path_y - 5, rect.position.y + 2, rect.position.y + rect.size.y - 6), 3, 3)
	if role == ROOM_ROLE_TRAVERSAL and difficulty < 0.25:
		return
	_carve_rect(grid, rect.position.x + 1, clampi(left_path_y + 2, rect.position.y + 5, rect.position.y + rect.size.y - 5), 2, 3 + int(difficulty >= 0.45))
	_carve_rect(grid, rect.position.x + rect.size.x - 3, clampi(right_path_y + 2, rect.position.y + 5, rect.position.y + rect.size.y - 5), 2, 2 + int(difficulty >= 0.6))


func _stamp_room_platforms(grid: Array, room: Dictionary) -> void:
	for platform_variant: Variant in room.get("platforms", []) as Array:
		var platform: Dictionary = platform_variant as Dictionary
		generated_platforms.append(platform.duplicate(true))
		_stamp_rect(grid, int(platform.get("x", 0)), int(platform.get("y", 0)), max(1, int(platform.get("w", 1))), max(1, int(platform.get("h", 1))))
	for platform_variant: Variant in room.get("secondary_platforms", []) as Array:
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
		for slot_variant: Variant in room.get("pickup_slots", []) as Array:
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


func _grid_is_solid(grid: Array, grid_x: int, grid_y: int) -> bool:
	if grid_x < 0 or grid_y < 0 or grid_x >= level_size.x or grid_y >= level_size.y:
		return false
	if grid_y >= grid.size():
		return false
	var row: PackedByteArray = grid[grid_y] as PackedByteArray
	if grid_x >= row.size():
		return false
	return row[grid_x] != 0


func _place_pickups() -> Array:
	var source_pickups: Array = level_data.get("pickups", []) as Array
	var normalized_pickups: Array = []
	for pickup_variant: Variant in source_pickups:
		normalized_pickups.append((pickup_variant as Dictionary).duplicate(true))
	var slots: Array = []
	for room_variant: Variant in main_rooms:
		for slot_variant: Variant in (room_variant as Dictionary).get("pickup_slots", []) as Array:
			slots.append(slot_variant)
	for room_variant: Variant in side_rooms:
		for slot_variant: Variant in (room_variant as Dictionary).get("pickup_slots", []) as Array:
			slots.append(slot_variant)
	var placed: Array = []
	for pickup_index: int in range(mini(normalized_pickups.size(), slots.size())):
		var pickup_data: Dictionary = normalized_pickups[pickup_index] as Dictionary
		var slot: Vector2i = slots[pickup_index] as Vector2i
		pickup_data["x"] = slot.x
		pickup_data["y"] = slot.y
		placed.append(pickup_data)
	return placed


func _place_enemies() -> Array:
	var source_enemies: Array = level_data.get("enemies", []) as Array
	var room_candidates: Array = []
	for room_variant: Variant in main_rooms:
		var room: Dictionary = room_variant as Dictionary
		var role: String = str(room.get("role", ""))
		if role == ROOM_ROLE_START or role == ROOM_ROLE_INTRO or role == ROOM_ROLE_EXIT or role == ROOM_ROLE_BOSS:
			continue
		room_candidates.append(room)
	for room_variant: Variant in side_rooms:
		room_candidates.append(room_variant)

	var placed: Array = []
	var occupied_room_ids: Dictionary = {}
	var room_cursor: int = 0
	var mushroom_count: int = 0
	for enemy_index: int in range(source_enemies.size()):
		var enemy_variant: Variant = source_enemies[enemy_index]
		if room_candidates.is_empty():
			break
		var enemy_data: Dictionary = (enemy_variant as Dictionary).duplicate(true)
		var room: Dictionary = room_candidates[min(room_cursor, room_candidates.size() - 1)] as Dictionary
		var enemy_type: String = _resolve_enemy_spawn_type(
			str(enemy_data.get("type", "bat")),
			room,
			enemy_index,
			source_enemies.size(),
			mushroom_count
		)
		enemy_data["type"] = enemy_type
		var slots: Array = room.get("air_slots", []) as Array if enemy_type == "bat" else room.get("ground_slots", []) as Array
		if slots.is_empty():
			slots = room.get("ground_slots", []) as Array
		if slots.is_empty():
			room_cursor += 1
			continue
		var selected_slot: Variant = null
		for slot_variant: Variant in slots:
			if not _slot_near_path(room, slot_variant as Vector2i, 2):
				selected_slot = slot_variant
				break
		if selected_slot == null:
			selected_slot = slots[0]
		var slot: Vector2i = selected_slot as Vector2i
		enemy_data["x"] = slot.x
		enemy_data["y"] = slot.y
		enemy_data["room_id"] = str(room.get("id", ""))
		placed.append(enemy_data)
		if enemy_type == "mushroom":
			mushroom_count += 1
		occupied_room_ids[str(room.get("id", ""))] = true
		room_cursor = mini(room_cursor + 1, room_candidates.size() - 1)

	var bonus_enemy_budget: int = int(_level_progress() >= 0.34) + int(_level_progress() >= 0.58) + int(_level_progress() >= 0.84)
	for room_variant: Variant in room_candidates:
		if bonus_enemy_budget <= 0:
			break
		var room: Dictionary = room_variant as Dictionary
		var room_id: String = str(room.get("id", ""))
		if occupied_room_ids.has(room_id) and str(room.get("role", "")) != ROOM_ROLE_COMBAT:
			continue
		var ground_slots: Array = room.get("ground_slots", []) as Array
		if ground_slots.is_empty():
			continue
		var chosen_slot: Vector2i = ground_slots.back() as Vector2i
		if _slot_near_path(room, chosen_slot, 1) and str(room.get("role", "")) == ROOM_ROLE_TRAVERSAL:
			continue
		var bonus_enemy_type: String = _resolve_enemy_spawn_type("slime", room, placed.size(), source_enemies.size(), mushroom_count, true)
		placed.append({
			"type": bonus_enemy_type,
			"x": chosen_slot.x,
			"y": chosen_slot.y,
			"room_id": room_id,
			"bonus_spawn": true
		})
		if bonus_enemy_type == "mushroom":
			mushroom_count += 1
		occupied_room_ids[room_id] = true
		bonus_enemy_budget -= 1
	return placed


func _resolve_enemy_spawn_type(base_type: String, room: Dictionary, enemy_index: int, total_source_enemies: int, mushroom_count: int, is_bonus_spawn: bool = false) -> String:
	if base_type != "slime":
		return base_type

	var progress: float = _level_progress()
	var room_role: String = str(room.get("role", ROOM_ROLE_TRAVERSAL))
	var mushroom_cap: int = 1 + int(progress >= 0.36) + int(progress >= 0.72)
	if is_bonus_spawn and progress >= 0.58:
		mushroom_cap += 1
	if mushroom_count >= mushroom_cap:
		return base_type

	var should_force_intro_mushroom: bool = (
		not is_bonus_spawn
		and progress <= 0.02
		and total_source_enemies >= 2
		and enemy_index == total_source_enemies - 1
		and mushroom_count == 0
	)
	if should_force_intro_mushroom:
		return "mushroom"

	var spawn_chance: float = 0.1 + progress * 0.24
	match room_role:
		ROOM_ROLE_COMBAT, ROOM_ROLE_CHOKE:
			spawn_chance += 0.16
		ROOM_ROLE_LANDMARK, ROOM_ROLE_BRANCH:
			spawn_chance += 0.08
		ROOM_ROLE_TRAVERSAL:
			spawn_chance -= 0.02
	if is_bonus_spawn:
		spawn_chance += 0.08
	if mushroom_count == 0:
		spawn_chance += 0.05

	return "mushroom" if rng.randf() <= clampf(spawn_chance, 0.0, 0.46) else base_type


func _place_hazards(grid: Array) -> Array:
	var source_hazards: Array = level_data.get("hazards", []) as Array
	var total_budget: int = 0
	for hazard_variant: Variant in source_hazards:
		total_budget += max(1, int((hazard_variant as Dictionary).get("count", 1)))
	if total_budget <= 0:
		return []
	var slots: Array = []
	for room_variant: Variant in main_rooms:
		var room: Dictionary = room_variant as Dictionary
		for slot_variant: Variant in room.get("hazard_slots", []) as Array:
			slots.append(slot_variant)
	var placed: Array = []
	var remaining: int = total_budget
	for slot_variant: Variant in slots:
		if remaining <= 0:
			break
		var slot: Vector2i = slot_variant as Vector2i
		var count: int = min(2, remaining)
		var requested_origin := Vector2i(slot.x - int(floor(float(count - 1) * 0.5)), slot.y)
		var resolved_origin: Vector2i = _resolve_hazard_origin(grid, requested_origin, count)
		if resolved_origin == Vector2i.ZERO:
			continue
		placed.append({
			"type": "spikes",
			"x": resolved_origin.x,
			"y": resolved_origin.y,
			"count": count
		})
		remaining -= count
	return placed


func _resolve_hazard_origin(grid: Array, requested_origin: Vector2i, count: int) -> Vector2i:
	var best_origin := Vector2i.ZERO
	var best_score: float = INF
	var y_offsets: Array[int] = [0, -1, 1, -2, 2, 3, 4, 5, -3]
	var x_offsets: Array[int] = [0, -1, 1, -2, 2, -3, 3]
	for y_offset: int in y_offsets:
		var candidate_y: int = clampi(requested_origin.y + y_offset, ROOM_PADDING_TILES + 2, level_size.y - ROOM_PADDING_TILES - 2)
		for x_offset: int in x_offsets:
			var candidate_x: int = clampi(requested_origin.x + x_offset, ROOM_PADDING_TILES + 2, level_size.x - ROOM_PADDING_TILES - count - 1)
			var candidate := Vector2i(candidate_x, candidate_y)
			if not _is_valid_hazard_origin(grid, candidate, count):
				continue
			var score: float = absf(float(candidate.x - requested_origin.x)) + absf(float(candidate.y - requested_origin.y)) * 1.45
			if score < best_score:
				best_score = score
				best_origin = candidate
	if best_score < INF:
		return best_origin
	return Vector2i.ZERO


func _is_valid_hazard_origin(grid: Array, origin: Vector2i, count: int) -> bool:
	var spawn_node: Vector2i = _first_path_node()
	var exit_node: Vector2i = _last_path_node()
	for offset_x: int in range(count):
		var grid_x: int = origin.x + offset_x
		var floor_cell := Vector2i(grid_x, origin.y)
		if not _grid_is_solid(grid, grid_x, origin.y):
			return false
		if _grid_is_solid(grid, grid_x, origin.y - 1):
			return false
		if _grid_is_solid(grid, grid_x, origin.y - 2):
			return false
		if floor_cell.distance_to(spawn_node) <= 7.0 or floor_cell.distance_to(exit_node) <= 8.0:
			return false
	for shoulder_x: int in [origin.x - 1, origin.x + count]:
		if _grid_is_solid(grid, shoulder_x, origin.y):
			return true
	return count >= 2


func _place_torches() -> Array:
	var source_torches: Array = level_data.get("torches", []) as Array
	var brightness_values: Array = []
	for torch_variant: Variant in source_torches:
		brightness_values.append(float((torch_variant as Dictionary).get("brightness", 1.0)))
	if brightness_values.is_empty():
		brightness_values.append(1.0)
	var slots: Array = []
	for room_variant: Variant in main_rooms:
		for slot_variant: Variant in (room_variant as Dictionary).get("torch_slots", []) as Array:
			slots.append(slot_variant)
	for room_variant: Variant in side_rooms:
		for slot_variant: Variant in (room_variant as Dictionary).get("torch_slots", []) as Array:
			slots.append(slot_variant)
	var torches: Array = []
	for slot_index: int in range(slots.size()):
		var slot: Vector2i = slots[slot_index] as Vector2i
		torches.append({
			"x": slot.x,
			"y": slot.y,
			"brightness": brightness_values[slot_index % brightness_values.size()]
		})
	return torches


func _place_triggers() -> Array:
	var source_triggers: Array = level_data.get("triggers", []) as Array
	var trigger_rooms: Array = []
	if not main_rooms.is_empty():
		trigger_rooms.append(main_rooms.front())
	if main_rooms.size() > 2:
		trigger_rooms.append(main_rooms[int(main_rooms.size() / 2)])
	if main_rooms.size() > 1:
		trigger_rooms.append(main_rooms.back())
	var placed: Array = []
	for trigger_index: int in range(mini(source_triggers.size(), trigger_rooms.size())):
		var trigger_data: Dictionary = (source_triggers[trigger_index] as Dictionary).duplicate(true)
		var room: Dictionary = trigger_rooms[trigger_index] as Dictionary
		var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
		var width_tiles: int = max(5, int(trigger_data.get("w", 1)))
		var height_tiles: int = max(4, int(trigger_data.get("h", 1)))
		var trigger_x: int = rect.position.x + 2
		var trigger_y: int = rect.position.y + rect.size.y - height_tiles - 2
		if str(room.get("role", "")) == ROOM_ROLE_BOSS:
			trigger_x = rect.position.x + 4
		elif str(room.get("role", "")) == ROOM_ROLE_EXIT:
			trigger_x = rect.position.x + rect.size.x - width_tiles - 3
		elif trigger_index == 1:
			trigger_x = rect.position.x + int(rect.size.x * 0.35)
		trigger_data["x"] = trigger_x
		trigger_data["y"] = trigger_y
		trigger_data["w"] = width_tiles
		trigger_data["h"] = height_tiles
		placed.append(trigger_data)
	return placed


func _place_boss() -> Dictionary:
	if not level_data.has("boss"):
		return {}
	var boss_data: Dictionary = (level_data.get("boss", {}) as Dictionary).duplicate(true)
	for room_variant: Variant in main_rooms:
		var room: Dictionary = room_variant as Dictionary
		if str(room.get("role", "")) != ROOM_ROLE_BOSS:
			continue
		var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
		var floor_y: int = int((room.get("entry_node", Vector2i.ZERO) as Vector2i).y)
		boss_data["x"] = rect.position.x + int(rect.size.x / 2)
		boss_data["y"] = floor_y
		return boss_data
	return boss_data


func _slot_near_path(room: Dictionary, slot: Vector2i, distance_limit: int) -> bool:
	for path_variant: Variant in room.get("path_nodes", []) as Array:
		var path_node: Vector2i = path_variant as Vector2i
		if slot.distance_to(Vector2i(path_node.x, path_node.y - 1)) <= distance_limit:
			return true
	return false


func _assemble_result(grid: Array, pickups: Array, enemies: Array, hazards: Array, torches: Array, triggers: Array, boss: Dictionary, validation: Dictionary) -> Dictionary:
	return {
		"grid": grid,
		"spawn": _first_path_node(),
		"exit": _last_path_node(),
		"platforms": generated_platforms.duplicate(true),
		"pickups": pickups,
		"enemies": enemies,
		"hazards": hazards,
		"torches": torches,
		"triggers": triggers,
		"boss": boss,
		"worm_count": int(level_data.get("worm_count", 0)),
		"layout_validation": validation,
		"debug_rooms": _build_debug_rooms(),
		"critical_path_nodes": critical_path_nodes.duplicate(true),
		"side_path_lines": side_path_lines.duplicate(true),
		"mobility_profile": mobility_profile.duplicate(true)
	}


func _build_curated_fallback_result() -> Dictionary:
	var fallback_platforms: Array = []
	for platform_variant: Variant in level_data.get("platforms", []) as Array:
		fallback_platforms.append((platform_variant as Dictionary).duplicate(true))
	var critical_nodes: Array = _fallback_route_nodes(fallback_platforms)
	var fallback_pickups: Array = (level_data.get("pickups", []) as Array).duplicate(true)
	var validation: Dictionary = {
		"path_valid": true,
		"optional_path_valid": true,
		"required_path_reachable": true,
		"room_count": 0,
		"branch_count": 0,
		"critical_path_length_tiles": float(max(0, critical_nodes.size() - 1)),
		"reachable_reward_count": fallback_pickups.size(),
		"unreachable_reward_count": 0,
		"invalid_jump_count": 0,
		"optional_invalid_jump_count": 0,
		"surface_node_count": 0,
		"softlock_surface_count": 0,
		"trap_pit_count": 0,
		"dead_end_count": 0,
		"unreachable_room_count": 0,
		"unreachable_optional_room_count": 0,
		"exit_anchor": level_data.get("exit", Vector2i.ZERO) as Vector2i,
		"exit_anchor_valid": true,
		"exit_margin_ok": true,
		"room_role_counts": {},
		"notes": PackedStringArray(["Fallback auf kuratierte Plattformroute aktiviert."]),
		"unreachable_rewards": [],
		"invalid_jump_edges": [],
		"softlock_nodes": [],
		"trap_pit_nodes": [],
		"unreachable_room_ids": [],
		"unreachable_optional_room_ids": [],
		"generator_fallback": true,
		"layout_signature": "fallback_curated",
		"branch_signature": "fallback_curated",
		"vertical_signature": "fallback_curated",
		"room_variety_score": 0.0
	}
	return {
		"platforms": fallback_platforms,
		"pickups": fallback_pickups,
		"enemies": (level_data.get("enemies", []) as Array).duplicate(true),
		"hazards": (level_data.get("hazards", []) as Array).duplicate(true),
		"torches": (level_data.get("torches", []) as Array).duplicate(true),
		"triggers": (level_data.get("triggers", []) as Array).duplicate(true),
		"boss": (level_data.get("boss", {}) as Dictionary).duplicate(true),
		"worm_count": int(level_data.get("worm_count", 0)),
		"layout_validation": validation,
		"debug_rooms": [],
		"critical_path_nodes": critical_nodes,
		"side_path_lines": [],
		"mobility_profile": mobility_profile.duplicate(true),
		"generator_fallback": true
	}


func _fallback_route_nodes(platforms: Array) -> Array:
	var nodes: Array = []
	_append_path_point(nodes, level_data.get("spawn", Vector2i.ZERO) as Vector2i)
	for platform_variant: Variant in platforms:
		var platform: Dictionary = platform_variant as Dictionary
		var platform_x: int = int(platform.get("x", 0))
		var platform_y: int = int(platform.get("y", 0))
		var platform_w: int = max(1, int(platform.get("w", 1)))
		_append_path_point(nodes, Vector2i(platform_x + int(platform_w / 2), platform_y))
	_append_path_point(nodes, level_data.get("exit", Vector2i.ZERO) as Vector2i)
	return _densify_path_nodes(nodes)


func _build_debug_rooms() -> Array:
	var debug_rooms: Array = []
	for room_variant: Variant in main_rooms:
		debug_rooms.append((room_variant as Dictionary).duplicate(true))
	for room_variant: Variant in side_rooms:
		debug_rooms.append((room_variant as Dictionary).duplicate(true))
	return debug_rooms


func _repair_invalid_edges(validation: Dictionary) -> bool:
	var invalid_edges: Array = validation.get("invalid_jump_edges", []) as Array
	if invalid_edges.is_empty():
		return false

	var critical_repairs: Dictionary = {}
	var branch_repairs: Dictionary = {}
	for edge_variant: Variant in invalid_edges:
		var edge: Dictionary = edge_variant as Dictionary
		var from_anchor: Vector2i = edge.get("from", Vector2i.ZERO) as Vector2i
		var to_anchor: Vector2i = edge.get("to", Vector2i.ZERO) as Vector2i
		var from_node: Vector2i = edge.get("from_source", from_anchor) as Vector2i
		var to_node: Vector2i = edge.get("to_source", to_anchor) as Vector2i
		var repair_nodes: Array = _repair_nodes_for_edge(from_node, to_node)
		if repair_nodes.is_empty():
			continue
		var edge_key: String = _edge_key(from_node, to_node)
		if str(edge.get("kind", "critical")) == "branch":
			branch_repairs[edge_key] = repair_nodes
		else:
			critical_repairs[edge_key] = repair_nodes
		for repair_variant: Variant in repair_nodes:
			var repair_node: Vector2i = repair_variant as Vector2i
			connection_platforms.append(_make_platform(repair_node.x - int(CONNECTION_PLATFORM_WIDTH / 2), repair_node.y, CONNECTION_PLATFORM_WIDTH, 1, "ledge"))

	if critical_repairs.is_empty() and branch_repairs.is_empty():
		return false

	critical_path_nodes = _repair_edges_in_line(critical_path_nodes, critical_repairs)
	for line_index: int in range(side_path_lines.size()):
		side_path_lines[line_index] = _repair_edges_in_line(side_path_lines[line_index] as Array, branch_repairs)
	return true


func _repair_softlock_routes(validation: Dictionary) -> bool:
	if critical_path_nodes.is_empty():
		return false
	var candidates: Array = validation.get("trap_pit_nodes", []) as Array
	if candidates.is_empty():
		candidates = validation.get("softlock_nodes", []) as Array
	if candidates.is_empty():
		return false

	var used_pairs: Dictionary = {}
	for line_variant: Variant in side_path_lines:
		var line: Array = line_variant as Array
		if line.size() < 2:
			continue
		used_pairs[_optional_route_key(line.front() as Vector2i, line.back() as Vector2i)] = true

	var repaired_any: bool = false
	var repair_budget: int = min(4, candidates.size())
	for node_variant: Variant in candidates:
		if repair_budget <= 0:
			break
		var trapped_node: Vector2i = node_variant as Vector2i
		var escape_target: Vector2i = _nearest_escape_anchor(trapped_node)
		if escape_target == Vector2i.ZERO or escape_target == trapped_node:
			continue
		if _register_optional_route(_build_loop_route(trapped_node, escape_target, escape_target.y <= trapped_node.y), used_pairs, max(BRANCH_CONNECTION_WIDTH, 5)):
			repaired_any = true
			repair_budget -= 1
	return repaired_any


func _nearest_escape_anchor(source: Vector2i) -> Vector2i:
	var best_node: Vector2i = Vector2i.ZERO
	var best_score: float = INF
	for node_variant: Variant in critical_path_nodes:
		var candidate: Vector2i = node_variant as Vector2i
		if candidate == source:
			continue
		var score: float = absf(float(candidate.x - source.x)) + absf(float(candidate.y - source.y)) * 1.65
		if candidate.y > source.y:
			score += 6.0
		if score < best_score:
			best_score = score
			best_node = candidate
	return best_node


func _repair_edges_in_line(points: Array, repairs: Dictionary) -> Array:
	if points.size() < 2 or repairs.is_empty():
		return points
	var repaired_points: Array = []
	for point_index: int in range(points.size() - 1):
		var from_point: Vector2i = points[point_index] as Vector2i
		var to_point: Vector2i = points[point_index + 1] as Vector2i
		_append_path_point(repaired_points, from_point)
		var edge_key: String = _edge_key(from_point, to_point)
		if repairs.has(edge_key):
			var repair_points: Array = repairs[edge_key] as Array
			for repair_variant: Variant in repair_points:
				_append_path_point(repaired_points, repair_variant as Vector2i)
	_append_path_point(repaired_points, points.back() as Vector2i)
	return repaired_points


func _repair_nodes_for_edge(from_node: Vector2i, to_node: Vector2i) -> Array:
	var repair_nodes: Array = []
	var current: Vector2i = from_node
	var guard: int = 0
	while not _segment_within_traversal_budget(current, to_node, false) and guard < 12:
		var next_step: Vector2i = _next_traversal_step(current, to_node, false, guard)
		if next_step == current or next_step == to_node:
			break
		repair_nodes.append(next_step)
		current = next_step
		guard += 1

	if repair_nodes.is_empty():
		var midpoint_x: int = int(round((float(from_node.x) + float(to_node.x)) * 0.5))
		var midpoint_y: int = int(round((float(from_node.y) + float(to_node.y)) * 0.5))
		var climb_tiles: int = from_node.y - to_node.y
		if climb_tiles > 0:
			midpoint_y = max(to_node.y + 1, from_node.y - max(2, int(ceil(float(climb_tiles) * 0.5))))
		elif climb_tiles < 0:
			midpoint_y = min(to_node.y - 1, from_node.y + max(2, int(ceil(float(abs(climb_tiles)) * 0.5))))
		var fallback_node := Vector2i(midpoint_x, midpoint_y)
		fallback_node.x = clampi(fallback_node.x, ROOM_PADDING_TILES + 1, level_size.x - ROOM_PADDING_TILES - 2)
		fallback_node.y = clampi(fallback_node.y, ROOM_PADDING_TILES + 2, level_size.y - ROOM_PADDING_TILES - 3)
		if fallback_node != from_node and fallback_node != to_node:
			repair_nodes.append(fallback_node)

	return repair_nodes


func _edge_key(from_node: Vector2i, to_node: Vector2i) -> String:
	return "%d:%d>%d:%d" % [from_node.x, from_node.y, to_node.x, to_node.y]


func _score_validation(validation: Dictionary) -> float:
	var score: float = 0.0
	if bool(validation.get("path_valid", false)):
		score += 1000.0
	if bool(validation.get("required_path_reachable", false)):
		score += 250.0
	if bool(validation.get("optional_path_valid", false)):
		score += 110.0
	if bool(validation.get("exit_anchor_valid", false)):
		score += 80.0
	if bool(validation.get("exit_margin_ok", false)):
		score += 40.0
	score -= float(validation.get("invalid_jump_count", 0)) * 220.0
	score -= float(validation.get("unreachable_reward_count", 0)) * 140.0
	score -= float(validation.get("unreachable_room_count", 0)) * 180.0
	score -= float(validation.get("softlock_surface_count", 0)) * 200.0
	score -= float(validation.get("trap_pit_count", 0)) * 260.0
	score -= float(validation.get("dead_end_count", 0)) * 40.0
	score += float(validation.get("reachable_reward_count", 0)) * 60.0
	score += float(validation.get("room_variety_score", 0.0)) * 220.0
	score += minf(4.0, float(validation.get("branch_count", 0))) * 34.0
	score += float(validation.get("critical_path_length_tiles", 0.0)) * 0.62
	return score


func _room_variety_score() -> float:
	var total_rooms: int = main_rooms.size() + side_rooms.size()
	if total_rooms == 0:
		return 0.0

	var unique_roles: Dictionary = {}
	var unique_motifs: Dictionary = {}
	var has_branch: bool = false
	var has_vertical: bool = false
	var total_secondary_platforms: int = 0

	for room_variant: Variant in main_rooms:
		var room: Dictionary = room_variant as Dictionary
		var role: String = str(room.get("role", ""))
		if not role.is_empty():
			unique_roles[role] = true
		var motif: String = str(room.get("motif", ""))
		if not motif.is_empty():
			unique_motifs[motif] = true
		if role == ROOM_ROLE_VERTICAL:
			has_vertical = true
		total_secondary_platforms += (room.get("secondary_platforms", []) as Array).size()

	for room_variant: Variant in side_rooms:
		var room: Dictionary = room_variant as Dictionary
		var role: String = str(room.get("role", ""))
		if not role.is_empty():
			unique_roles[role] = true
		var motif: String = str(room.get("motif", ""))
		if not motif.is_empty():
			unique_motifs[motif] = true
		if role == ROOM_ROLE_BRANCH:
			has_branch = true
		total_secondary_platforms += (room.get("secondary_platforms", []) as Array).size()

	var role_score: float = minf(1.0, float(unique_roles.size()) / 5.0)
	var motif_score: float = minf(1.0, float(unique_motifs.size()) / 4.0)
	var branch_score: float = 1.0 if has_branch else 0.0
	var vertical_score: float = 1.0 if has_vertical else 0.0
	var platform_score: float = minf(1.0, float(total_secondary_platforms) / maxf(1.0, float(total_rooms)))
	return role_score * 0.35 + motif_score * 0.3 + branch_score * 0.15 + vertical_score * 0.1 + platform_score * 0.1


func _count_room_threat_budget() -> float:
	var total: float = 0.0
	for room_variant: Variant in main_rooms:
		total += float((room_variant as Dictionary).get("threat_budget", 0.0))
	for room_variant: Variant in side_rooms:
		total += float((room_variant as Dictionary).get("threat_budget", 0.0))
	return total


func _room_threat_budget(role: String, difficulty: float) -> float:
	match role:
		ROOM_ROLE_START, ROOM_ROLE_INTRO, ROOM_ROLE_EXIT, ROOM_ROLE_BOSS:
			return 0.0
		ROOM_ROLE_COMBAT:
			return 1.5 + difficulty * 1.5
		ROOM_ROLE_CHOKE:
			return 1.0 + difficulty
		ROOM_ROLE_LANDMARK:
			return 0.8 + difficulty * 0.5
		ROOM_ROLE_VERTICAL:
			return 1.0 + difficulty
		ROOM_ROLE_BRANCH:
			return 0.6 + difficulty * 0.6
		_:
			return 0.75 + difficulty * 0.75


func _enemy_budget() -> int:
	return (level_data.get("enemies", []) as Array).size()


func _pickup_budget() -> int:
	return (level_data.get("pickups", []) as Array).size()


func _hazard_budget() -> int:
	var total: int = 0
	for hazard_variant: Variant in level_data.get("hazards", []) as Array:
		total += max(1, int((hazard_variant as Dictionary).get("count", 1)))
	return total


func _level_progress() -> float:
	return clampf(float(level_data.get("level_index", 0)) / 7.0, 0.0, 1.0)


func _first_path_node() -> Vector2i:
	if critical_path_nodes.is_empty():
		return level_data.get("spawn", Vector2i(4, 28)) as Vector2i
	return critical_path_nodes.front() as Vector2i


func _last_path_node() -> Vector2i:
	if critical_path_nodes.is_empty():
		return level_data.get("exit", Vector2i(level_size.x - 8, level_size.y - 10)) as Vector2i
	return critical_path_nodes.back() as Vector2i


func _find_room_by_id(rooms: Array, room_id: String) -> Dictionary:
	for room_variant: Variant in rooms:
		var room: Dictionary = room_variant as Dictionary
		if str(room.get("id", "")) == room_id:
			return room
	return {}


func _room_index_by_id(rooms: Array, room_id: String) -> int:
	for room_index: int in range(rooms.size()):
		var room: Dictionary = rooms[room_index] as Dictionary
		if str(room.get("id", "")) == room_id:
			return room_index
	return -1


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
		var t: float = clampf(float(world_x - from_node.x) / maxf(1.0, float(to_node.x - from_node.x)), 0.0, 1.0)
		return int(round(lerpf(float(from_node.y), float(to_node.y), t)))
	return (path_nodes.back() as Vector2i).y


func _vertical_path_center_x(path_nodes: Array, world_y: int, fallback_x: int) -> int:
	if path_nodes.is_empty():
		return fallback_x
	var first_node: Vector2i = path_nodes.front() as Vector2i
	if world_y <= first_node.y:
		return first_node.x
	for node_index: int in range(path_nodes.size() - 1):
		var from_node: Vector2i = path_nodes[node_index] as Vector2i
		var to_node: Vector2i = path_nodes[node_index + 1] as Vector2i
		var min_y: int = mini(from_node.y, to_node.y)
		var max_y: int = maxi(from_node.y, to_node.y)
		if world_y < min_y or world_y > max_y:
			continue
		if from_node.y == to_node.y:
			return mini(from_node.x, to_node.x)
		var t: float = clampf(float(world_y - from_node.y) / maxf(1.0, float(to_node.y - from_node.y)), 0.0, 1.0)
		return int(round(lerpf(float(from_node.x), float(to_node.x), t)))
	return (path_nodes.back() as Vector2i).x


func _make_platform(x: int, y: int, width_tiles: int, height_tiles: int, style: String) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"w": width_tiles,
		"h": height_tiles,
		"style": style
	}


func rect_lerp_x(left_x: int, right_x: int, ratio: float) -> int:
	return int(round(lerpf(float(left_x), float(right_x), ratio)))
