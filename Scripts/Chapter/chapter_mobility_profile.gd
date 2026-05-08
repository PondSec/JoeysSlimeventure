class_name ChapterMobilityProfile
extends RefCounted

const PlayerController := preload("res://Scripts/player.gd")
const PLAYER_SCENE := preload("res://Scenes/player.tscn")

const TILE_SIZE := 32.0
const SAMPLE_DT := 1.0 / 60.0
const MAX_AIR_TIME := 1.9

static var _cached_body_metrics: Dictionary = {}


static func build_for_level(level_data: Dictionary) -> Dictionary:
	var skill_flags: Dictionary = skill_flags_for_level(level_data)
	return build_from_skill_flags(skill_flags)


static func skill_flags_for_level(level_data: Dictionary) -> Dictionary:
	var skill_flags: Dictionary = {
		"wall_slide": int(level_data.get("chapter_index", 0)) >= 1,
		"double_jump": false,
		"wall_run": false,
		"dash": false,
		"teleport": false
	}

	var explicit_flags: Dictionary = level_data.get("mobility_skills", {}) as Dictionary
	for key_variant: Variant in explicit_flags.keys():
		skill_flags[str(key_variant)] = bool(explicit_flags[key_variant])

	return skill_flags


static func build_from_skill_flags(skill_flags: Dictionary) -> Dictionary:
	var body_metrics: Dictionary = _player_body_metrics()
	var run_speed_tiles: float = PlayerController.DEFAULT_RUN_SPEED / TILE_SIZE
	var walk_speed_tiles: float = PlayerController.DEFAULT_WALK_SPEED / TILE_SIZE
	var jump_launch_speed_tiles: float = (PlayerController.DEFAULT_RUN_SPEED + 20.0) / TILE_SIZE
	var jump_velocity_tiles: float = PlayerController.JUMP_VELOCITY / TILE_SIZE
	var air_jump_velocity_tiles: float = (PlayerController.AIR_JUMP_VELOCITY * 1.05) / TILE_SIZE
	var wall_jump_velocity_tiles: float = PlayerController.WALL_JUMP_VELOCITY_Y / TILE_SIZE
	var wall_jump_horizontal_tiles: float = PlayerController.WALL_JUMP_VELOCITY_X / TILE_SIZE
	var dash_speed_tiles: float = PlayerController.BASE_DASH_SPEED / TILE_SIZE
	var dash_duration: float = PlayerController.BASE_DASH_DURATION
	var wall_slide_speed_tiles: float = 40.0 / TILE_SIZE if bool(skill_flags.get("wall_slide", false)) else PlayerController.WALL_SLIDE_SPEED / TILE_SIZE
	if bool(skill_flags.get("dash", false)):
		dash_speed_tiles *= 1.12
		dash_duration *= 0.95

	var jump_stats: Dictionary = _simulate_airborne_arc(jump_velocity_tiles, jump_launch_speed_tiles)
	var air_jump_stats: Dictionary = _simulate_airborne_arc(air_jump_velocity_tiles, run_speed_tiles)
	var wall_jump_stats: Dictionary = _simulate_airborne_arc(wall_jump_velocity_tiles, wall_jump_horizontal_tiles)
	var dash_distance_tiles: float = dash_speed_tiles * dash_duration
	var teleport_distance_tiles: float = float(PlayerController.TELEPORT_DISTANCE) / TILE_SIZE

	var jump_height_tiles: int = max(2, int(round(float(jump_stats.get("peak_height_tiles", 0.0)) * 0.9)))
	var jump_gap_tiles: int = max(3, int(round(float(jump_stats.get("horizontal_distance_tiles", 0.0)) * 0.82)))
	var air_jump_height_tiles: int = max(jump_height_tiles, int(round(float(air_jump_stats.get("peak_height_tiles", 0.0)) * 0.9)))
	var wall_jump_height_tiles: int = max(jump_height_tiles, int(round(float(wall_jump_stats.get("peak_height_tiles", 0.0)) * 0.9)))
	var wall_jump_gap_tiles: int = max(jump_gap_tiles, int(round(float(wall_jump_stats.get("horizontal_distance_tiles", 0.0)) * 0.84)))
	var dash_gap_tiles: int = int(floor(dash_distance_tiles * 0.95)) if bool(skill_flags.get("dash", false)) else 0
	var teleport_gap_tiles: int = int(floor(teleport_distance_tiles * 0.92)) if bool(skill_flags.get("teleport", false)) else 0
	var body_half_width_tiles: float = float(body_metrics.get("half_width_tiles", 0.42))
	var body_height_tiles: float = float(body_metrics.get("height_tiles", 0.98))
	var standing_headroom_tiles: int = max(2, int(ceil(body_height_tiles + 0.25)))

	return {
		"tile_size": TILE_SIZE,
		"skill_flags": skill_flags.duplicate(true),
		"walk_speed_tiles_per_second": walk_speed_tiles,
		"run_speed_tiles_per_second": run_speed_tiles,
		"jump_launch_horizontal_tiles_per_second": jump_launch_speed_tiles,
		"jump_velocity_tiles_per_second": jump_velocity_tiles,
		"air_jump_velocity_tiles_per_second": air_jump_velocity_tiles,
		"wall_jump_velocity_tiles_per_second": wall_jump_velocity_tiles,
		"wall_jump_horizontal_tiles_per_second": wall_jump_horizontal_tiles,
		"gravity_tiles_per_second_sq": float(PlayerController.GRAVITY) / TILE_SIZE,
		"max_fall_speed_tiles_per_second": float(PlayerController.MAX_FALL_SPEED) / TILE_SIZE,
		"wall_slide_speed_tiles_per_second": wall_slide_speed_tiles,
		"body_half_width_tiles": body_half_width_tiles,
		"body_height_tiles": body_height_tiles,
		"standing_headroom_tiles": standing_headroom_tiles,
		"max_jump_up_tiles": jump_height_tiles,
		"main_gap_tiles": jump_gap_tiles,
		"challenge_gap_tiles": jump_gap_tiles + int(bool(skill_flags.get("double_jump", false))) + int(bool(skill_flags.get("dash", false))),
		"air_jump_up_tiles": air_jump_height_tiles,
		"wall_jump_up_tiles": wall_jump_height_tiles,
		"wall_jump_gap_tiles": wall_jump_gap_tiles,
		"dash_gap_tiles": dash_gap_tiles,
		"teleport_gap_tiles": teleport_gap_tiles,
		"readable_drop_tiles": 5 + int(bool(skill_flags.get("wall_slide", false))) + int(bool(skill_flags.get("double_jump", false))),
		"safe_drop_tiles": 7 + int(bool(skill_flags.get("wall_slide", false))) + int(bool(skill_flags.get("double_jump", false))),
		"jump_air_time": float(jump_stats.get("air_time", 0.0)),
		"jump_peak_height_tiles": float(jump_stats.get("peak_height_tiles", 0.0)),
		"jump_peak_distance_tiles": float(jump_stats.get("horizontal_distance_tiles", 0.0))
	}


static func gravity_multiplier_for_velocity(velocity_y_tiles: float) -> float:
	var velocity_y_px: float = velocity_y_tiles * TILE_SIZE
	if velocity_y_px < -float(PlayerController.APEX_VELOCITY_THRESHOLD):
		return 0.95
	if absf(velocity_y_px) <= float(PlayerController.APEX_VELOCITY_THRESHOLD):
		return float(PlayerController.APEX_GRAVITY_MULTIPLIER)
	return float(PlayerController.FALL_GRAVITY_MULTIPLIER)


static func _simulate_airborne_arc(initial_velocity_y_tiles: float, horizontal_speed_tiles: float) -> Dictionary:
	var position_y: float = 0.0
	var velocity_y: float = initial_velocity_y_tiles
	var max_height_tiles: float = 0.0
	var elapsed: float = 0.0
	var highest_sample: float = 0.0
	while elapsed < MAX_AIR_TIME:
		var gravity_tiles: float = (float(PlayerController.GRAVITY) * gravity_multiplier_for_velocity(velocity_y)) / TILE_SIZE
		position_y += velocity_y * SAMPLE_DT
		velocity_y += gravity_tiles * SAMPLE_DT
		highest_sample = minf(highest_sample, position_y)
		if position_y > 0.0 and velocity_y >= 0.0 and elapsed > 0.12:
			break
		elapsed += SAMPLE_DT
	max_height_tiles = absf(highest_sample)
	return {
		"peak_height_tiles": max_height_tiles,
		"air_time": elapsed,
		"horizontal_distance_tiles": horizontal_speed_tiles * elapsed
	}


static func _player_body_metrics() -> Dictionary:
	if not _cached_body_metrics.is_empty():
		return _cached_body_metrics

	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	if player == null:
		_cached_body_metrics = {
			"half_width_tiles": 0.42,
			"height_tiles": 0.98
		}
		return _cached_body_metrics

	var collision_shape: CollisionShape2D = player.get_node_or_null("ColisionArea") as CollisionShape2D
	var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D if collision_shape != null else null
	if collision_shape == null or rect_shape == null:
		player.free()
		_cached_body_metrics = {
			"half_width_tiles": 0.42,
			"height_tiles": 0.98
		}
		return _cached_body_metrics

	var root_scale := Vector2(absf(player.scale.x), absf(player.scale.y))
	var local_scale := Vector2(absf(collision_shape.scale.x), absf(collision_shape.scale.y))
	var size_px := rect_shape.size * root_scale * local_scale
	var half_size_px := size_px * 0.5
	var angle: float = collision_shape.rotation
	var extent_x_px: float = absf(cos(angle)) * half_size_px.x + absf(sin(angle)) * half_size_px.y
	var extent_y_px: float = absf(sin(angle)) * half_size_px.x + absf(cos(angle)) * half_size_px.y
	player.free()

	_cached_body_metrics = {
		"half_width_tiles": (extent_x_px + 1.0) / TILE_SIZE,
		"height_tiles": ((extent_y_px * 2.0) + 2.0) / TILE_SIZE
	}
	return _cached_body_metrics
