extends Node2D

const TILE_SIZE := 32.0
const FEEDBACK_FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const ChapterContent := preload("res://Scripts/Chapter/chapter_content.gd")
const ChapterLayoutBuilder := preload("res://Scripts/Chapter/chapter_layout_builder.gd")
const TerrainResolver := preload("res://Scripts/Chapter/terrain_resolver.gd")
const TileClassifier := preload("res://Scripts/Chapter/tile_classifier.gd")

const HUB_SCENE := preload("res://Scenes/Game.tscn")
const PLAYER_SCENE := preload("res://Scenes/player.tscn")
const PAUSE_MENU_SCENE := preload("res://Scenes/PauseMenu.tscn")
const CHAPTER_GATE_SCENE := preload("res://Scenes/Chapter/chapter_gate.tscn")
const CAVE_SLIME_SCENE := preload("res://Scenes/Chapter/Enemies/cave_slime.tscn")
const CAVE_BAT_SCENE := preload("res://Scenes/Chapter/Enemies/cave_bat.tscn")
const GLOWCAP_SCENE := preload("res://Scenes/Chapter/Enemies/glowcap.tscn")
const SLIME_KING_SCENE := preload("res://Scenes/Chapter/Enemies/slime_king.tscn")
const ESSENCE_FRAGMENT_SCENE := preload("res://Scenes/Chapter/Pickups/essence_fragment.tscn")
const TORCH_SCENE := preload("res://Scenes/torch.tscn")
const SPIKE_SCENE := preload("res://Scenes/SpikeNormal.tscn")
const WORM_SCENE := preload("res://Scenes/worm.tscn")
const VINE_SCENE := preload("res://Scenes/vine.tscn")
const PLAYER_WORLD_COLLISION_LAYER := 2
const DEFAULT_CAVE_TILE_SOURCE_ID := 0
const CAVE_TILE_SIZE := Vector2i(32, 32)
const CAVE_TEXTURE_PATH := "res://Assets/Tiles/platformertiles.png"
const DEBUG_OVERLAY_TOGGLE_KEY := KEY_F2
const TILE_DEBUG_TOGGLE_KEY := KEY_F3

const PARALLAX_TEXTURE_PATHS := [
	"res://Assets/Parallax Cave/1.png",
	"res://Assets/Parallax Cave/2.png",
	"res://Assets/Parallax Cave/4.png",
	"res://Assets/Parallax Cave/5.png",
	"res://Assets/Parallax Cave/7.png",
	"res://Assets/Parallax Cave/9.png"
]

const PARALLAX_FX_TEXTURE_PATHS := [
	"res://Assets/Parallax Cave/8fx.png",
	"res://Assets/Parallax Cave/6fx.png",
	"res://Assets/Parallax Cave/3fx.png"
]

const WORLD_BOUND_LEFT_PADDING := 128.0
const WORLD_BOUND_RIGHT_PADDING := 128.0
const WORLD_BOUND_TOP_PADDING := 160.0
const WORLD_BOUND_BOTTOM_PADDING := 160.0
const CAMERA_MARGIN := Vector2(160.0, 128.0)
const EXIT_VIEW_MARGIN := Vector2(220.0, 180.0)

var active_level: Dictionary = {}
var runtime_level: Dictionary = {}
var level_size_tiles: Vector2i = Vector2i(100, 40)
var level_size_pixels: Vector2 = Vector2(3200.0, 1280.0)
var generator_seed_override: int = -1
var active_level_seed: int = 0
var player: CharacterBody2D
var pause_menu: CanvasLayer
var transition_locked: bool = false
var boss_gate_revealed: bool = false
var backdrop_root: Node2D
var level_root: Node2D
var wall_tiles: TileMapLayer
var terrain_root: Node2D
var hazard_root: Node2D
var decor_root: Node2D
var enemy_root: Node2D
var pickup_root: Node2D
var trigger_root: Node2D
var gate_root: Node2D
var ui_layer: CanvasLayer
var intro_panel: PanelContainer
var intro_title: Label
var intro_subtitle: Label
var intro_objective: Label
var tutorial_panel: PanelContainer
var tutorial_kicker: Label
var tutorial_title: Label
var tutorial_body: Label
var tutorial_controls: Label
var tutorial_tween: Tween
var boss_bar: ProgressBar
var boss_name: Label
var exit_gate: Node2D
var parallax_background: ParallaxBackground
var parallax_base_fill: Polygon2D
var parallax_layer_entries: Array = []
var feedback_font: FontFile
var cave_tiles_texture: Texture2D
var cave_tileset: TileSet
var cave_tile_source_id: int = DEFAULT_CAVE_TILE_SOURCE_ID
var solid_grid_cache: Array = []
var debug_overlay_enabled: bool = false
var logical_terrain_map: Dictionary = {}
var tile_debug_overlay_enabled: bool = false
var runtime_play_bounds: Rect2 = Rect2()
var resolved_exit_tile: Vector2i = Vector2i.ZERO
var rng := RandomNumberGenerator.new()

@onready var shadow: CanvasModulate = $Shadow


func _ready() -> void:
	feedback_font = load(FEEDBACK_FONT_PATH) as FontFile
	cave_tiles_texture = load(CAVE_TEXTURE_PATH) as Texture2D

	active_level = _progress().get_active_level_data()
	if active_level.is_empty():
		_progress().enter_hub()
		call_deferred("_return_to_hub")
		return

	level_size_tiles = active_level.get("size", Vector2i(100, 40)) as Vector2i
	active_level_seed = _resolve_level_seed()
	rng.seed = active_level_seed
	runtime_level = _build_runtime_level_data()
	if not runtime_level.is_empty():
		active_level = runtime_level
	level_size_tiles = active_level.get("size", level_size_tiles) as Vector2i
	level_size_pixels = Vector2(level_size_tiles.x * TILE_SIZE, level_size_tiles.y * TILE_SIZE)
	shadow.color = Color(0.11, 0.13, 0.18, 1.0)

	_build_runtime_nodes()
	_spawn_player()
	_spawn_pause_menu()
	_build_level()
	runtime_play_bounds = _calculate_play_bounds_rect()
	_build_parallax_background()
	_configure_runtime_view()
	await get_tree().process_frame
	_position_player_at_spawn()
	_grant_level_one_mobility()
	_show_level_intro()


func _resolve_level_seed() -> int:
	if generator_seed_override >= 0:
		return generator_seed_override
	if active_level.has("seed_override"):
		return int(active_level.get("seed_override", 0))
	return int(hash("%s_%s_%d_%d" % [
		str(active_level.get("title", "")),
		str(active_level.get("level_label", "")),
		int(active_level.get("chapter_index", 0)),
		int(active_level.get("level_index", 0))
	]))


func _build_runtime_level_data() -> Dictionary:
	var level_copy: Dictionary = active_level.duplicate(true)
	if level_copy.is_empty():
		return {}

	var generated_layout: Dictionary = ChapterLayoutBuilder.build_level_layout(level_copy, level_size_tiles, active_level_seed)
	if generated_layout.is_empty():
		return level_copy

	for key_variant: Variant in generated_layout.keys():
		var key: String = str(key_variant)
		if key == "boss":
			var boss_data: Dictionary = generated_layout.get("boss", {}) as Dictionary
			if not boss_data.is_empty():
				level_copy["boss"] = boss_data
			elif level_copy.has("boss"):
				level_copy.erase("boss")
			continue
		level_copy[key] = generated_layout[key_variant]

	return level_copy


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Pause") and pause_menu != null and pause_menu.has_method("toggle_pause"):
		pause_menu.call("toggle_pause")
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == DEBUG_OVERLAY_TOGGLE_KEY:
				debug_overlay_enabled = not debug_overlay_enabled
				_refresh_debug_overlays()
			elif key_event.keycode == TILE_DEBUG_TOGGLE_KEY:
				tile_debug_overlay_enabled = not tile_debug_overlay_enabled
				_refresh_debug_overlays()


func _build_runtime_nodes() -> void:
	backdrop_root = Node2D.new()
	backdrop_root.name = "BackdropRoot"
	add_child(backdrop_root)
	move_child(backdrop_root, 0)

	level_root = Node2D.new()
	level_root.name = "Level"
	add_child(level_root)

	wall_tiles = TileMapLayer.new()
	wall_tiles.name = "wall"
	wall_tiles.tile_set = _build_cave_tileset()
	level_root.add_child(wall_tiles)

	terrain_root = Node2D.new()
	terrain_root.name = "TerrainRoot"
	add_child(terrain_root)

	hazard_root = Node2D.new()
	hazard_root.name = "HazardRoot"
	add_child(hazard_root)

	decor_root = Node2D.new()
	decor_root.name = "DecorRoot"
	add_child(decor_root)

	enemy_root = Node2D.new()
	enemy_root.name = "EnemyRoot"
	add_child(enemy_root)

	pickup_root = Node2D.new()
	pickup_root.name = "PickupRoot"
	add_child(pickup_root)

	trigger_root = Node2D.new()
	trigger_root.name = "TriggerRoot"
	add_child(trigger_root)

	gate_root = Node2D.new()
	gate_root.name = "GateRoot"
	add_child(gate_root)

	ui_layer = CanvasLayer.new()
	ui_layer.name = "ChapterUI"
	add_child(ui_layer)
	_setup_ui()


func _build_parallax_background() -> void:
	if parallax_background != null:
		parallax_background.queue_free()
	parallax_layer_entries.clear()

	parallax_background = ParallaxBackground.new()
	parallax_background.name = "ParallaxBackground"
	parallax_background.scale = Vector2(0.3, 0.3)
	add_child(parallax_background)
	move_child(parallax_background, 0)

	var base_layer := ParallaxLayer.new()
	base_layer.motion_scale = Vector2.ZERO
	parallax_background.add_child(base_layer)

	parallax_base_fill = Polygon2D.new()
	parallax_base_fill.color = Color(0.08, 0.11, 0.17, 1.0)
	base_layer.add_child(parallax_base_fill)

	var texture_settings := [
		{"path": PARALLAX_TEXTURE_PATHS[0], "motion": Vector2(0.2, 0.0), "alpha": 1.0},
		{"path": PARALLAX_TEXTURE_PATHS[1], "motion": Vector2(0.3, 0.0), "alpha": 1.0, "fx_path": PARALLAX_FX_TEXTURE_PATHS[0], "fx_alpha": 0.082},
		{"path": PARALLAX_TEXTURE_PATHS[2], "motion": Vector2(0.4, 0.0), "alpha": 1.0},
		{"path": PARALLAX_TEXTURE_PATHS[3], "motion": Vector2(0.5, 0.0), "alpha": 1.0, "fx_path": PARALLAX_FX_TEXTURE_PATHS[1], "fx_alpha": 0.079},
		{"path": PARALLAX_TEXTURE_PATHS[4], "motion": Vector2(0.6, 0.0), "alpha": 1.0, "fx_path": PARALLAX_FX_TEXTURE_PATHS[2], "fx_alpha": 0.159},
		{"path": PARALLAX_TEXTURE_PATHS[5], "motion": Vector2(0.7, 0.0), "alpha": 1.0}
	]

	for texture_setting_variant: Variant in texture_settings:
		var texture_setting: Dictionary = texture_setting_variant
		var texture: Texture2D = load(str(texture_setting["path"])) as Texture2D
		if texture == null:
			continue

		var layer := ParallaxLayer.new()
		layer.motion_scale = texture_setting["motion"] as Vector2
		layer.motion_mirroring = Vector2(float(texture.get_width()), 0.0)
		parallax_background.add_child(layer)

		for index: int in range(4):
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.position = Vector2(float(index) * float(texture.get_width()), 0.0)
			sprite.modulate = Color(1.0, 1.0, 1.0, float(texture_setting.get("alpha", 1.0)))
			layer.add_child(sprite)

		var fx_path: String = str(texture_setting.get("fx_path", ""))
		if not fx_path.is_empty():
			var fx_texture: Texture2D = load(fx_path) as Texture2D
			if fx_texture != null:
				for index: int in range(4):
					var fx_sprite := Sprite2D.new()
					fx_sprite.texture = fx_texture
					fx_sprite.centered = false
					fx_sprite.position = Vector2(float(index) * float(texture.get_width()), 0.0)
					fx_sprite.modulate = Color(1.0, 1.0, 1.0, float(texture_setting.get("fx_alpha", 0.1)))
					layer.add_child(fx_sprite)

		parallax_layer_entries.append({
			"layer": layer,
			"texture": texture
		})

	_update_parallax_background_layout(runtime_play_bounds if runtime_play_bounds.size != Vector2.ZERO else Rect2(Vector2.ZERO, level_size_pixels))


func _update_parallax_background_layout(play_bounds: Rect2) -> void:
	if parallax_background == null:
		return

	var bounds: Rect2 = play_bounds
	if bounds.size == Vector2.ZERO:
		bounds = Rect2(Vector2.ZERO, level_size_pixels)

	if parallax_base_fill != null:
		parallax_base_fill.polygon = PackedVector2Array([
			Vector2(bounds.position.x - 2200.0, bounds.position.y - 2200.0),
			Vector2(bounds.end.x + 2200.0, bounds.position.y - 2200.0),
			Vector2(bounds.end.x + 2200.0, bounds.end.y + 2200.0),
			Vector2(bounds.position.x - 2200.0, bounds.end.y + 2200.0)
		])

	var vertical_anchor_ratios: Array[float] = [0.06, 0.09, 0.13, 0.18, 0.24, 0.31]
	var horizontal_start_ratio: float = 0.22
	for layer_index: int in range(parallax_layer_entries.size()):
		var entry: Dictionary = parallax_layer_entries[layer_index] as Dictionary
		var layer: ParallaxLayer = entry.get("layer", null) as ParallaxLayer
		var texture: Texture2D = entry.get("texture", null) as Texture2D
		if layer == null or texture == null:
			continue
		var anchor_ratio: float = vertical_anchor_ratios[min(layer_index, vertical_anchor_ratios.size() - 1)]
		var start_x: float = bounds.position.x - float(texture.get_width()) * horizontal_start_ratio
		var anchor_y: float = bounds.position.y + bounds.size.y * anchor_ratio - float(texture.get_height()) * 0.08
		layer.position = Vector2(start_x, anchor_y)
		layer.motion_mirroring = Vector2(float(texture.get_width()), 0.0)

	_rebuild_backdrop_shapes(bounds)


func _rebuild_backdrop_shapes(bounds: Rect2) -> void:
	for child: Node in backdrop_root.get_children():
		child.free()

	for index: int in range(20):
		var stalactite := Polygon2D.new()
		var start_x: float = lerpf(bounds.position.x - 120.0, bounds.end.x + 120.0, float(index) / 19.0)
		var width: float = rng.randf_range(60.0, 130.0)
		var height: float = rng.randf_range(90.0, 210.0)
		stalactite.color = Color(0.08, 0.12, 0.16, 0.28)
		stalactite.polygon = PackedVector2Array([
			Vector2(start_x, bounds.position.y - 40.0),
			Vector2(start_x + width, bounds.position.y - 40.0),
			Vector2(start_x + width * 0.46, bounds.position.y + height)
		])
		backdrop_root.add_child(stalactite)

	for index: int in range(16):
		var stalagmite := Polygon2D.new()
		var start_x: float = lerpf(bounds.position.x - 60.0, bounds.end.x + 60.0, float(index) / 15.0)
		var width: float = rng.randf_range(70.0, 150.0)
		var height: float = rng.randf_range(70.0, 180.0)
		stalagmite.color = Color(0.1, 0.14, 0.19, 0.24)
		stalagmite.polygon = PackedVector2Array([
			Vector2(start_x, bounds.end.y + 30.0),
			Vector2(start_x + width, bounds.end.y + 30.0),
			Vector2(start_x + width * 0.52, bounds.end.y - height)
		])
		backdrop_root.add_child(stalagmite)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as CharacterBody2D
	player.name = "PlayerModel"
	add_child(player)


func _spawn_pause_menu() -> void:
	pause_menu = PAUSE_MENU_SCENE.instantiate() as CanvasLayer
	pause_menu.visible = false
	add_child(pause_menu)
	if pause_menu.has_signal("go_to_main_menu"):
		pause_menu.connect("go_to_main_menu", Callable(self, "_on_pause_menu_go_to_main_menu"))


func _grant_level_one_mobility() -> void:
	if player == null or not player.has_method("grant_skill"):
		return
	var chapter_index: int = int(active_level.get("chapter_index", 0))
	if chapter_index < 1:
		return
	var show_feedback: bool = chapter_index == 1 and int(active_level.get("level_index", -1)) == 0
	player.call("grant_skill", "wall_slide", show_feedback)


func _build_level() -> void:
	var platforms: Array = active_level.get("platforms", []) as Array
	solid_grid_cache = active_level.get("grid", []) as Array
	if solid_grid_cache.is_empty():
		solid_grid_cache = _build_cave_solid_grid(platforms)
	logical_terrain_map = TerrainResolver.build_logical_map(solid_grid_cache, level_size_tiles)
	solid_grid_cache = TerrainResolver.duplicate_cells(logical_terrain_map)
	_draw_cave_wall_tiles(logical_terrain_map)
	_spawn_cave_collision_mesh(solid_grid_cache)
	_spawn_world_bounds()
	_spawn_generated_overgrowth(solid_grid_cache)

	var hazards: Array = active_level.get("hazards", []) as Array
	for hazard_variant: Variant in hazards:
		_spawn_hazard(hazard_variant as Dictionary)

	var torches: Array = active_level.get("torches", []) as Array
	for torch_variant: Variant in torches:
		_spawn_torch(torch_variant as Dictionary)

	var crystals: Array = active_level.get("crystals", []) as Array
	for crystal_variant: Variant in crystals:
		_spawn_crystal(crystal_variant as Dictionary)

	var pickups: Array = active_level.get("pickups", []) as Array
	for pickup_variant: Variant in pickups:
		_spawn_pickup(pickup_variant as Dictionary)

	var enemies: Array = active_level.get("enemies", []) as Array
	for enemy_variant: Variant in enemies:
		_spawn_enemy(enemy_variant as Dictionary)

	var worm_count: int = int(active_level.get("worm_count", 0))
	for _index: int in range(worm_count):
		var worm: Node2D = WORM_SCENE.instantiate() as Node2D
		if worm != null:
			enemy_root.add_child(worm)

	var trigger_entries: Array = active_level.get("triggers", []) as Array
	for trigger_variant: Variant in trigger_entries:
		_spawn_story_trigger(trigger_variant as Dictionary)

	_spawn_exit_gate()
	_spawn_boss_if_needed()
	_refresh_debug_overlays()


func _build_cave_solid_grid(platforms: Array) -> Array:
	var grid: Array = _create_solid_grid()
	var spawn_tile: Vector2i = active_level.get("spawn", Vector2i(4, 28)) as Vector2i
	var exit_tile: Vector2i = active_level.get("exit", Vector2i(96, 24)) as Vector2i
	var route_points: Array[Vector2i] = _collect_route_points(platforms, spawn_tile, exit_tile)
	var layout_style: String = _infer_layout_style(route_points)
	if layout_style == "vertical":
		_carve_vertical_layout(grid, route_points)
	else:
		_carve_horizontal_layout(grid, route_points, platforms)

	var pickups: Array = active_level.get("pickups", []) as Array
	for pickup_variant: Variant in pickups:
		var pickup_data: Dictionary = pickup_variant as Dictionary
		_carve_rect(grid, int(pickup_data.get("x", 0)) - 2, int(pickup_data.get("y", 0)) - 4, 5, 5)

	var enemies: Array = active_level.get("enemies", []) as Array
	for enemy_variant: Variant in enemies:
		var enemy_data: Dictionary = enemy_variant as Dictionary
		var enemy_type: String = str(enemy_data.get("type", "slime"))
		var enemy_x: int = int(enemy_data.get("x", 0))
		var enemy_y: int = int(enemy_data.get("y", 0))
		if enemy_type == "bat":
			_carve_rect(grid, enemy_x - 3, enemy_y - 3, 7, 5)
		else:
			_carve_rect(grid, enemy_x - 2, enemy_y - 3, 5, 4)

	var hazards: Array = active_level.get("hazards", []) as Array
	for hazard_variant: Variant in hazards:
		var hazard_data: Dictionary = hazard_variant as Dictionary
		var hazard_x: int = int(hazard_data.get("x", 0))
		var hazard_y: int = int(hazard_data.get("y", 0))
		var hazard_count: int = max(1, int(hazard_data.get("count", 1)))
		_carve_rect(grid, hazard_x - 1, hazard_y - 5, hazard_count + 2, 5)

	_roughen_ceiling_edges(grid, route_points)
	_stamp_start_mass(grid, spawn_tile)
	_stamp_exit_mass(grid, exit_tile)
	for platform_variant: Variant in platforms:
		_stamp_platform_mass(grid, platform_variant as Dictionary)

	return grid


func _create_solid_grid() -> Array:
	var grid: Array = []
	for _row_index: int in range(level_size_tiles.y):
		var row := PackedByteArray()
		row.resize(level_size_tiles.x)
		for cell_index: int in range(level_size_tiles.x):
			row[cell_index] = 1
		grid.append(row)
	return grid


func _collect_route_points(platforms: Array, spawn_tile: Vector2i, exit_tile: Vector2i) -> Array[Vector2i]:
	var route_points: Array[Vector2i] = []
	route_points.append(spawn_tile)
	for platform_variant: Variant in platforms:
		var platform: Dictionary = platform_variant as Dictionary
		route_points.append(_platform_anchor(platform))

	if active_level.has("boss"):
		var boss_data: Dictionary = active_level.get("boss", {}) as Dictionary
		route_points.append(Vector2i(int(boss_data.get("x", exit_tile.x - 10)), int(boss_data.get("y", exit_tile.y))))

	route_points.append(exit_tile)
	return route_points


func _infer_layout_style(route_points: Array[Vector2i]) -> String:
	if active_level.has("layout_style"):
		return str(active_level.get("layout_style", "horizontal"))
	if route_points.is_empty():
		return "horizontal"
	var first_point: Vector2i = route_points[0]
	var last_point: Vector2i = route_points[route_points.size() - 1]
	var vertical_span: int = abs(last_point.y - first_point.y)
	if level_size_tiles.y >= 50 or vertical_span >= 18:
		return "vertical"
	return "horizontal"


func _carve_horizontal_layout(grid: Array, route_points: Array[Vector2i], platforms: Array) -> void:
	for route_index: int in range(route_points.size()):
		var point: Vector2i = route_points[route_index]
		var prev_point: Vector2i = route_points[maxi(route_index - 1, 0)]
		var next_point: Vector2i = route_points[mini(route_index + 1, route_points.size() - 1)]
		var route_width: int = _route_width_for_index(route_index, platforms)
		_carve_route_chamber(
			grid,
			prev_point,
			point,
			next_point,
			route_width,
			route_index == 0,
			route_index == route_points.size() - 1
		)

	for route_index: int in range(route_points.size() - 1):
		_carve_connection(grid, route_points[route_index], route_points[route_index + 1])


func _carve_vertical_layout(grid: Array, route_points: Array[Vector2i]) -> void:
	if route_points.is_empty():
		return

	var min_x: int = route_points[0].x
	var max_x: int = route_points[0].x
	var min_y: int = route_points[0].y
	var max_y: int = route_points[0].y
	for point: Vector2i in route_points:
		min_x = mini(min_x, point.x)
		max_x = maxi(max_x, point.x)
		min_y = mini(min_y, point.y)
		max_y = maxi(max_y, point.y)

	_carve_rect(grid, min_x - 10, min_y - 8, max_x - min_x + 21, max_y - min_y + 14)

	for route_index: int in range(route_points.size()):
		var point: Vector2i = route_points[route_index]
		var prev_point: Vector2i = route_points[maxi(route_index - 1, 0)]
		var next_point: Vector2i = route_points[mini(route_index + 1, route_points.size() - 1)]
		_carve_route_chamber(
			grid,
			prev_point,
			point,
			next_point,
			9,
			route_index == 0,
			route_index == route_points.size() - 1
		)

	for route_index: int in range(route_points.size() - 1):
		_carve_connection(grid, route_points[route_index], route_points[route_index + 1])


func _carve_route_chamber(grid: Array, prev_point: Vector2i, point: Vector2i, next_point: Vector2i, route_width: int, is_terminal: bool, is_exit: bool) -> void:
	var left: int = _min3(prev_point.x, point.x, next_point.x) - 5 - route_width / 3
	var right: int = _max3(prev_point.x, point.x, next_point.x) + 6 + route_width / 3
	var top_padding: int = 5 if not is_terminal else 6
	var bottom_padding: int = 4 if not is_exit else 5
	var top: int = _min3(prev_point.y, point.y, next_point.y) - top_padding
	var bottom: int = _max3(prev_point.y, point.y, next_point.y) + bottom_padding
	_carve_rect(grid, left, top, right - left + 1, bottom - top + 1)

	var alcove_height: int = 4 + int(route_width >= 8)
	if point.x > prev_point.x + 4 and point.x < next_point.x - 4:
		var alcove_direction: int = -1 if point.y <= next_point.y else 1
		var alcove_x: int = point.x - 7 if alcove_direction < 0 else point.x + 2
		var alcove_y: int = point.y - 4
		_carve_rect(grid, alcove_x, alcove_y, 6, alcove_height)


func _route_width_for_index(route_index: int, platforms: Array) -> int:
	if route_index <= 0:
		return 10
	if route_index > platforms.size():
		return 12
	var platform: Dictionary = platforms[route_index - 1] as Dictionary
	return max(6, int(platform.get("w", 6)))


func _roughen_ceiling_edges(grid: Array, route_points: Array[Vector2i]) -> void:
	for grid_x: int in range(2, level_size_tiles.x - 2):
		for grid_y: int in range(2, level_size_tiles.y - 3):
			if _is_solid(grid, grid_x, grid_y):
				continue
			if not _is_solid(grid, grid_x, grid_y - 1):
				continue
			if _point_is_near_route(route_points, grid_x, grid_y, 4, 3):
				break
			var seed_value: int = abs((grid_x * 31) + (grid_y * 17) + int(rng.seed % 97))
			if seed_value % 5 > 1:
				break
			var drip_length: int = 1 + (seed_value % 2)
			_stamp_rect(grid, grid_x, grid_y, 1, drip_length)
			break


func _point_is_near_route(route_points: Array[Vector2i], grid_x: int, grid_y: int, horizontal_margin: int, vertical_margin: int) -> bool:
	for point: Vector2i in route_points:
		if abs(point.x - grid_x) <= horizontal_margin and abs(point.y - grid_y) <= vertical_margin:
			return true
	return false


func _carve_platform_air(grid: Array, platform: Dictionary) -> void:
	var x: int = int(platform.get("x", 0))
	var y: int = int(platform.get("y", 0))
	var width_tiles: int = max(1, int(platform.get("w", 1)))
	var style: String = str(platform.get("style", "stone"))
	if style == "floor" and width_tiles >= 24:
		return
	var headroom: int = 4 if style == "floor" else (5 if width_tiles >= 7 else 4)
	var side_margin: int = 2 if style == "floor" else (3 if width_tiles >= 6 else 2)
	_carve_rect(grid, x - side_margin, y - headroom, width_tiles + side_margin * 2, headroom)


func _carve_connection(grid: Array, from_point: Vector2i, to_point: Vector2i) -> void:
	_carve_rect(grid, from_point.x - 2, from_point.y - 5, 6, 6)
	_carve_rect(grid, to_point.x - 2, to_point.y - 5, 6, 6)

	if abs(to_point.x - from_point.x) <= 4:
		var shaft_left: int = mini(from_point.x, to_point.x) - 2
		var shaft_top: int = mini(from_point.y, to_point.y) - 5
		var shaft_height: int = abs(to_point.y - from_point.y) + 8
		_carve_rect(grid, shaft_left, shaft_top, 6, shaft_height)
		return

	var bend_x: int = from_point.x + int(round(float(to_point.x - from_point.x) * 0.56))
	var first_left: int = mini(from_point.x, bend_x) - 1
	var first_width: int = abs(bend_x - from_point.x) + 4
	_carve_rect(grid, first_left, from_point.y - 4, first_width, 4)

	var shaft_top: int = mini(from_point.y, to_point.y) - 4
	var shaft_height: int = abs(to_point.y - from_point.y) + 6
	_carve_rect(grid, bend_x - 2, shaft_top, 5, shaft_height)

	var second_left: int = mini(bend_x, to_point.x) - 1
	var second_width: int = abs(to_point.x - bend_x) + 4
	_carve_rect(grid, second_left, to_point.y - 4, second_width, 4)


func _carve_rect(grid: Array, x: int, y: int, width_tiles: int, height_tiles: int) -> void:
	if width_tiles <= 0 or height_tiles <= 0:
		return
	var start_x: int = maxi(0, x)
	var end_x: int = mini(level_size_tiles.x, x + width_tiles)
	var start_y: int = maxi(0, y)
	var end_y: int = mini(level_size_tiles.y, y + height_tiles)
	for grid_y: int in range(start_y, end_y):
		var row: PackedByteArray = grid[grid_y] as PackedByteArray
		for grid_x: int in range(start_x, end_x):
			row[grid_x] = 0
		grid[grid_y] = row


func _stamp_rect(grid: Array, x: int, y: int, width_tiles: int, height_tiles: int) -> void:
	if width_tiles <= 0 or height_tiles <= 0:
		return
	var start_x: int = maxi(0, x)
	var end_x: int = mini(level_size_tiles.x, x + width_tiles)
	var start_y: int = maxi(0, y)
	var end_y: int = mini(level_size_tiles.y, y + height_tiles)
	for grid_y: int in range(start_y, end_y):
		var row: PackedByteArray = grid[grid_y] as PackedByteArray
		for grid_x: int in range(start_x, end_x):
			row[grid_x] = 1
		grid[grid_y] = row


func _stamp_start_mass(grid: Array, spawn_tile: Vector2i) -> void:
	_stamp_rect(grid, spawn_tile.x - 5, spawn_tile.y + 1, 8, 5)
	_stamp_rect(grid, spawn_tile.x - 5, spawn_tile.y - 1, 2, 3)


func _stamp_exit_mass(grid: Array, exit_tile: Vector2i) -> void:
	_stamp_rect(grid, exit_tile.x - 1, exit_tile.y + 1, 7, 5)
	_stamp_rect(grid, exit_tile.x + 4, exit_tile.y - 1, 2, 3)


func _stamp_platform_mass(grid: Array, platform: Dictionary) -> void:
	var x: int = int(platform.get("x", 0))
	var y: int = int(platform.get("y", 0))
	var width_tiles: int = max(1, int(platform.get("w", 1)))
	var height_tiles: int = max(1, int(platform.get("h", 1)))
	var style: String = str(platform.get("style", "stone"))
	var thickness: int = height_tiles
	if style == "floor":
		thickness = max(height_tiles, 4)
	_stamp_rect(grid, x, y, width_tiles, thickness)


func _stamp_route_roof(grid: Array, from_point: Vector2i, to_point: Vector2i) -> void:
	var left: int = mini(from_point.x, to_point.x)
	var right: int = maxi(from_point.x, to_point.x)
	if right - left < 4:
		return
	var roof_y: int = mini(from_point.y, to_point.y) - 3
	_stamp_rect(grid, left, roof_y, right - left + 1, 2)


func _platform_anchor(platform: Dictionary) -> Vector2i:
	var x: int = int(platform.get("x", 0))
	var y: int = int(platform.get("y", 0))
	var width_tiles: int = max(1, int(platform.get("w", 1)))
	return Vector2i(x + width_tiles / 2, y)


func _draw_cave_wall_tiles(logical_map: Dictionary) -> void:
	if wall_tiles == null:
		return
	wall_tiles.clear()
	for grid_y: int in range(level_size_tiles.y):
		for grid_x: int in range(level_size_tiles.x):
			var cell: Vector2i = Vector2i(grid_x, grid_y)
			if not TerrainResolver.is_solid(logical_map, cell):
				continue
			var resolved_tile: Dictionary = TileClassifier.resolve_solid_cell(logical_map, cell)
			var atlas_coords: Vector2i = resolved_tile.get("atlas_coords", Vector2i(1, 1)) as Vector2i
			var alternative_tile: int = int(resolved_tile.get("alternative", 0))
			wall_tiles.set_cell(cell, cave_tile_source_id, atlas_coords, alternative_tile)


func _draw_debug_overlay() -> void:
	var overlay_root := Node2D.new()
	overlay_root.name = "DebugOverlay"
	add_child(overlay_root)

	var room_colors := {
		"start": Color(0.58, 0.95, 0.7, 0.7),
		"intro": Color(0.56, 0.8, 1.0, 0.7),
		"traversal": Color(0.86, 0.9, 1.0, 0.55),
		"combat": Color(1.0, 0.56, 0.42, 0.72),
		"landmark": Color(0.88, 0.72, 1.0, 0.72),
		"vertical": Color(1.0, 0.86, 0.42, 0.72),
		"choke": Color(1.0, 0.38, 0.22, 0.8),
		"branch": Color(0.72, 1.0, 0.88, 0.55),
		"exit": Color(0.98, 1.0, 0.62, 0.72),
		"boss": Color(1.0, 0.4, 0.46, 0.78)
	}
	var validation: Dictionary = active_level.get("layout_validation", {}) as Dictionary
	var debug_rooms: Array = active_level.get("debug_rooms", []) as Array
	for room_variant: Variant in debug_rooms:
		var room: Dictionary = room_variant as Dictionary
		var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
		var outline := Line2D.new()
		outline.width = 3.0
		outline.default_color = room_colors.get(str(room.get("role", "traversal")), Color(1.0, 1.0, 1.0, 0.6)) as Color
		var top_left: Vector2 = _grid_to_world(rect.position)
		var top_right: Vector2 = _grid_to_world(Vector2i(rect.position.x + rect.size.x, rect.position.y))
		var bottom_right: Vector2 = _grid_to_world(rect.position + rect.size)
		var bottom_left: Vector2 = _grid_to_world(Vector2i(rect.position.x, rect.position.y + rect.size.y))
		outline.points = PackedVector2Array([top_left, top_right, bottom_right, bottom_left, top_left])
		overlay_root.add_child(outline)
		_create_room_debug_label(overlay_root, room, top_left, rect)

	var reachable_ids: PackedStringArray = validation.get("reachable_node_ids", PackedStringArray()) as PackedStringArray
	var returnable_ids: PackedStringArray = validation.get("exit_return_node_ids", PackedStringArray()) as PackedStringArray
	var reachable_lookup: Dictionary = {}
	for node_id: String in reachable_ids:
		reachable_lookup[node_id] = true
	var returnable_lookup: Dictionary = {}
	for node_id: String in returnable_ids:
		returnable_lookup[node_id] = true

	for edge_variant: Variant in validation.get("traversal_edges", []) as Array:
		var edge: Dictionary = edge_variant as Dictionary
		var edge_line := Line2D.new()
		edge_line.width = 3.0 if bool(edge.get("reachable", false)) else 2.0
		if bool(edge.get("reachable", false)) and bool(edge.get("returnable", false)):
			edge_line.default_color = Color(0.46, 1.0, 0.64, 0.48)
		elif bool(edge.get("reachable", false)):
			edge_line.default_color = Color(0.42, 0.9, 1.0, 0.34)
		else:
			edge_line.default_color = Color(0.62, 0.7, 0.9, 0.16)
		edge_line.points = PackedVector2Array([
			_grid_to_world(edge.get("from_pos", Vector2i.ZERO) as Vector2i) + Vector2(16.0, 0.0),
			_grid_to_world(edge.get("to_pos", Vector2i.ZERO) as Vector2i) + Vector2(16.0, 0.0)
		])
		overlay_root.add_child(edge_line)

	var traversal_node_colors := {
		"critical": Color(0.96, 1.0, 0.7, 0.9),
		"branch": Color(0.68, 0.98, 1.0, 0.9),
		"reward": Color(1.0, 0.72, 0.4, 0.95),
		"surface": Color(0.72, 0.82, 1.0, 0.44)
	}
	for node_variant: Variant in validation.get("traversal_nodes", []) as Array:
		var node: Dictionary = node_variant as Dictionary
		var node_id: String = str(node.get("id", ""))
		var node_kind: String = str(node.get("kind", "surface"))
		var node_color: Color = traversal_node_colors.get(node_kind, Color(0.84, 0.9, 1.0, 0.7)) as Color
		if not reachable_lookup.has(node_id):
			node_color = node_color.darkened(0.28)
			node_color.a *= 0.52
		elif not returnable_lookup.has(node_id):
			node_color = node_color.lerp(Color(1.0, 0.54, 0.2, 1.0), 0.22)
		var radius: float = 5.5 if node_kind != "surface" else 3.8
		if node_id == str(validation.get("start_node_id", "")) or node_id == str(validation.get("exit_node_id", "")):
			radius = 7.4
		_spawn_debug_dot(overlay_root, node.get("pos", Vector2i.ZERO) as Vector2i, node_color, radius)

	for edge_variant: Variant in validation.get("invalid_jump_edges", []) as Array:
		var edge: Dictionary = edge_variant as Dictionary
		var from_point: Vector2i = edge.get("from", Vector2i.ZERO) as Vector2i
		var to_point: Vector2i = edge.get("to", Vector2i.ZERO) as Vector2i
		var invalid_line := Line2D.new()
		invalid_line.width = 6.0
		invalid_line.default_color = Color(1.0, 0.18, 0.22, 0.84)
		invalid_line.points = PackedVector2Array([
			_grid_to_world(from_point) + Vector2(16.0, 0.0),
			_grid_to_world(to_point) + Vector2(16.0, 0.0)
		])
		overlay_root.add_child(invalid_line)

	for reward_variant: Variant in validation.get("unreachable_rewards", []) as Array:
		_spawn_debug_dot(overlay_root, reward_variant as Vector2i, Color(1.0, 0.18, 0.22, 0.88), 10.0)
	for softlock_variant: Variant in validation.get("softlock_nodes", []) as Array:
		_spawn_debug_dot(overlay_root, softlock_variant as Vector2i, Color(1.0, 0.34, 0.12, 0.78), 7.0)
	for pit_variant: Variant in validation.get("trap_pit_nodes", []) as Array:
		_spawn_debug_dot(overlay_root, pit_variant as Vector2i, Color(1.0, 0.56, 0.18, 0.9), 11.0)

	_draw_layout_debug_panel(validation)


func _create_room_debug_label(overlay_root: Node2D, room: Dictionary, top_left: Vector2, rect: Rect2i) -> void:
	var label := Label.new()
	label.position = top_left + Vector2(8.0, 6.0)
	label.scale = Vector2.ONE * 0.72
	label.text = "%s D%.2f T%.1f" % [
		str(room.get("role", "room")).to_upper(),
		float(room.get("difficulty", 0.0)),
		float(room.get("threat_budget", 0.0))
	]
	label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	if feedback_font != null:
		label.add_theme_font_override("font", feedback_font)
	overlay_root.add_child(label)


func _spawn_debug_dot(overlay_root: Node2D, cell: Vector2i, color: Color, radius: float) -> void:
	var dot := Polygon2D.new()
	dot.color = color
	var center: Vector2 = _grid_to_world(cell) + Vector2(16.0, -8.0)
	var points := PackedVector2Array()
	for step: int in range(10):
		var angle: float = (TAU * float(step)) / 10.0
		points.append(center + Vector2.RIGHT.rotated(angle) * radius)
	dot.polygon = points
	overlay_root.add_child(dot)


func _draw_layout_debug_panel(validation: Dictionary) -> void:
	if ui_layer == null:
		return
	var panel := PanelContainer.new()
	panel.name = "LayoutDebugPanel"
	panel.position = Vector2(18.0, 220.0)
	ui_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var lines: PackedStringArray = PackedStringArray([
		"Traversal Debug (F2)",
		"Graph: validierte Traversal-Kanten",
		"Knoten/Kanten: %d / %d" % [
			(validation.get("traversal_nodes", []) as Array).size(),
			(validation.get("traversal_edges", []) as Array).size()
		],
		"Pfadlaenge: %.1f" % float(validation.get("critical_path_length_tiles", 0.0)),
		"Optionale Routen: %s" % ("OK" if bool(validation.get("optional_path_valid", false)) and int(validation.get("optional_invalid_jump_count", 0)) == 0 else "CHECK"),
		"Jump Budget: up %d / gap %d / wall %d" % [
			int((active_level.get("mobility_profile", {}) as Dictionary).get("max_jump_up_tiles", 0)),
			int((active_level.get("mobility_profile", {}) as Dictionary).get("main_gap_tiles", 0)),
			int((active_level.get("mobility_profile", {}) as Dictionary).get("wall_jump_gap_tiles", 0))
		],
		"Rewards: %d/%d" % [int(validation.get("reachable_reward_count", 0)), int(validation.get("pickup_budget", 0))],
		"Invalid Jumps: %d" % int(validation.get("invalid_jump_count", 0)),
		"Softlocks: %d" % int(validation.get("softlock_surface_count", 0)),
		"Trap Pits: %d" % int(validation.get("trap_pit_count", 0)),
		"Dead Ends: %d" % int(validation.get("dead_end_count", 0)),
		"Unreachable Rooms: %d" % int(validation.get("unreachable_room_count", 0)),
		"Exit Zone: %s" % ("OK" if bool(validation.get("exit_anchor_valid", false)) and bool(validation.get("exit_margin_ok", false)) else "CHECK"),
		"Threat Budget: %.1f" % float(validation.get("threat_budget_total", 0.0)),
		"Fallback: %s" % ("JA" if bool(active_level.get("generator_fallback", false)) else "NEIN"),
		"Attempt: %d" % (int(validation.get("attempt_index", 0)) + 1)
	])
	for line: String in lines:
		var label := Label.new()
		label.text = line
		label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 0.96))
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
		label.add_theme_constant_override("outline_size", 4)
		if feedback_font != null:
			label.add_theme_font_override("font", feedback_font)
		column.add_child(label)


func _refresh_debug_overlays() -> void:
	var room_overlay: Node = get_node_or_null("DebugOverlay")
	if room_overlay != null:
		room_overlay.queue_free()
	var tile_overlay: Node = get_node_or_null("TileDebugOverlay")
	if tile_overlay != null:
		tile_overlay.queue_free()
	var layout_debug_panel: Node = ui_layer.get_node_or_null("LayoutDebugPanel") if ui_layer != null else null
	if layout_debug_panel != null:
		layout_debug_panel.queue_free()
	var tile_legend: Node = ui_layer.get_node_or_null("TileDebugLegend") if ui_layer != null else null
	if tile_legend != null:
		tile_legend.queue_free()

	if debug_overlay_enabled:
		_draw_debug_overlay()
	if tile_debug_overlay_enabled:
		_draw_tile_debug_overlay()


func _draw_tile_debug_overlay() -> void:
	if logical_terrain_map.is_empty():
		return

	var overlay_root := Node2D.new()
	overlay_root.name = "TileDebugOverlay"
	add_child(overlay_root)

	for grid_y: int in range(level_size_tiles.y):
		for grid_x: int in range(level_size_tiles.x):
			var cell: Vector2i = Vector2i(grid_x, grid_y)
			if not TerrainResolver.is_solid(logical_terrain_map, cell):
				continue
			var resolved_tile: Dictionary = TileClassifier.resolve_solid_cell(logical_terrain_map, cell)
			var classification: String = str(resolved_tile.get("classification", "center"))
			var overlay := Polygon2D.new()
			overlay.color = TileClassifier.debug_color(classification)
			var top_left: Vector2 = _grid_to_world(cell)
			overlay.polygon = PackedVector2Array([
				top_left,
				top_left + Vector2(TILE_SIZE, 0.0),
				top_left + Vector2(TILE_SIZE, TILE_SIZE),
				top_left + Vector2(0.0, TILE_SIZE)
			])
			overlay_root.add_child(overlay)

	_draw_tile_debug_legend()


func _draw_tile_debug_legend() -> void:
	if ui_layer == null:
		return

	var legend := PanelContainer.new()
	legend.name = "TileDebugLegend"
	legend.position = Vector2(18.0, 18.0)
	ui_layer.add_child(legend)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	legend.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	margin.add_child(rows)

	var heading := Label.new()
	heading.text = "Tile Debug (F3)"
	if feedback_font != null:
		heading.add_theme_font_override("font", feedback_font)
	rows.add_child(heading)

	var legend_entries: Array[String] = [
		"floor_top",
		"left_wall",
		"right_wall",
		"outer_corner_top_left",
		"outer_corner_top_right",
		"ceiling_bottom",
		"center",
		"thin_support"
	]
	for entry: String in legend_entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		rows.add_child(row)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(18.0, 18.0)
		swatch.color = TileClassifier.debug_color(entry)
		row.add_child(swatch)

		var label := Label.new()
		label.text = entry
		if feedback_font != null:
			label.add_theme_font_override("font", feedback_font)
		row.add_child(label)


func _is_solid(grid: Array, grid_x: int, grid_y: int) -> bool:
	if grid_x < 0 or grid_y < 0 or grid_x >= level_size_tiles.x or grid_y >= level_size_tiles.y:
		return false
	var row: PackedByteArray = grid[grid_y] as PackedByteArray
	return row[grid_x] == 1


func _spawn_cave_collision_mesh(grid: Array) -> void:
	var processed: Array = []
	for _row_index: int in range(level_size_tiles.y):
		var row := PackedByteArray()
		row.resize(level_size_tiles.x)
		for cell_index: int in range(level_size_tiles.x):
			row[cell_index] = 0
		processed.append(row)

	for grid_y: int in range(level_size_tiles.y):
		for grid_x: int in range(level_size_tiles.x):
			if not _is_solid(grid, grid_x, grid_y):
				continue
			var processed_row: PackedByteArray = processed[grid_y] as PackedByteArray
			if processed_row[grid_x] == 1:
				continue

			var width_tiles: int = 1
			while grid_x + width_tiles < level_size_tiles.x and _is_solid(grid, grid_x + width_tiles, grid_y):
				var scan_row: PackedByteArray = processed[grid_y] as PackedByteArray
				if scan_row[grid_x + width_tiles] == 1:
					break
				width_tiles += 1

			var height_tiles: int = 1
			var can_grow: bool = true
			while can_grow and grid_y + height_tiles < level_size_tiles.y:
				for check_x: int in range(grid_x, grid_x + width_tiles):
					if not _is_solid(grid, check_x, grid_y + height_tiles):
						can_grow = false
						break
					var next_row: PackedByteArray = processed[grid_y + height_tiles] as PackedByteArray
					if next_row[check_x] == 1:
						can_grow = false
						break
				if can_grow:
					height_tiles += 1

			for mark_y: int in range(grid_y, grid_y + height_tiles):
				var mark_row: PackedByteArray = processed[mark_y] as PackedByteArray
				for mark_x: int in range(grid_x, grid_x + width_tiles):
					mark_row[mark_x] = 1
				processed[mark_y] = mark_row

			var top_left: Vector2 = _grid_to_world(Vector2i(grid_x, grid_y))
			var size: Vector2 = Vector2(width_tiles * TILE_SIZE, height_tiles * TILE_SIZE)
			_spawn_boundary(top_left, size)


func _spawn_generated_overgrowth(grid: Array) -> void:
	var vine_columns: int = 0
	for grid_x: int in range(2, level_size_tiles.x - 2):
		for grid_y: int in range(1, level_size_tiles.y - 6):
			if not _is_solid(grid, grid_x, grid_y):
				continue
			if _is_solid(grid, grid_x, grid_y + 1):
				continue
			if rng.randf() > 0.035:
				continue
			var segment_count: int = rng.randi_range(2, 4)
			for segment_index: int in range(segment_count):
				var vine: Node2D = VINE_SCENE.instantiate() as Node2D
				if vine == null:
					continue
				decor_root.add_child(vine)
				vine.global_position = _grid_to_world(Vector2i(grid_x, grid_y + 1 + segment_index)) + Vector2(16.0, 0.0)
			vine_columns += 1
			if vine_columns >= 10:
				return
			break


func _build_cave_tileset() -> TileSet:
	if cave_tileset != null:
		return cave_tileset

	var hub_root: Node = HUB_SCENE.instantiate()
	if hub_root != null:
		var reference_wall: TileMapLayer = hub_root.get_node_or_null("Background/wall") as TileMapLayer
		if reference_wall != null and reference_wall.tile_set != null:
			cave_tileset = reference_wall.tile_set.duplicate(true)
			cave_tile_source_id = _resolve_cave_tile_source_id(cave_tileset)
			hub_root.free()
			return cave_tileset
		hub_root.free()

	var fallback_tileset := TileSet.new()
	fallback_tileset.tile_size = CAVE_TILE_SIZE
	if cave_tiles_texture == null:
		cave_tileset = fallback_tileset
		return cave_tileset

	var source := TileSetAtlasSource.new()
	source.texture = cave_tiles_texture
	source.texture_region_size = CAVE_TILE_SIZE
	var required_tiles: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(0, 2),
		Vector2i(1, 2),
		Vector2i(2, 2)
	]
	for atlas_coords: Vector2i in required_tiles:
		if not source.has_tile(atlas_coords):
			source.create_tile(atlas_coords)

	cave_tile_source_id = DEFAULT_CAVE_TILE_SOURCE_ID
	fallback_tileset.add_source(source, cave_tile_source_id)
	cave_tileset = fallback_tileset
	return cave_tileset


func _resolve_cave_tile_source_id(tileset: TileSet) -> int:
	if tileset == null:
		return DEFAULT_CAVE_TILE_SOURCE_ID
	var source_count: int = tileset.get_source_count()
	for source_index: int in range(source_count):
		var source_id: int = tileset.get_source_id(source_index)
		var atlas_source: TileSetAtlasSource = tileset.get_source(source_id) as TileSetAtlasSource
		if atlas_source == null or atlas_source.texture == null:
			continue
		if atlas_source.texture.resource_path == CAVE_TEXTURE_PATH:
			return source_id
	if source_count > 0:
		return tileset.get_source_id(0)
	return DEFAULT_CAVE_TILE_SOURCE_ID


func _spawn_world_bounds() -> void:
	var left_wall_top_left: Vector2 = Vector2(-96.0, -160.0)
	var right_wall_top_left: Vector2 = Vector2(level_size_pixels.x + 32.0, -160.0)
	var bound_size: Vector2 = Vector2(96.0, level_size_pixels.y + 320.0)
	var floor_size: Vector2 = Vector2(level_size_pixels.x + 256.0, 96.0)
	_spawn_boundary(left_wall_top_left, bound_size)
	_spawn_boundary(right_wall_top_left, bound_size)
	_spawn_boundary(Vector2(-128.0, level_size_pixels.y + 24.0), floor_size)


func _spawn_boundary(top_left: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = top_left
	body.collision_layer = PLAYER_WORLD_COLLISION_LAYER
	terrain_root.add_child(body)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	collider.position = size * 0.5
	body.add_child(collider)


func _spawn_hazard(hazard: Dictionary) -> void:
	var hazard_type: String = str(hazard.get("type", "spikes"))
	if hazard_type != "spikes":
		return

	var base_x: int = int(hazard.get("x", 0))
	var base_y: int = int(hazard.get("y", 0))
	var count: int = max(1, int(hazard.get("count", 1)))
	for offset_index: int in range(count):
		var spike: Node2D = SPIKE_SCENE.instantiate() as Node2D
		if spike == null:
			continue
		hazard_root.add_child(spike)
		spike.global_position = _grid_to_world(Vector2i(base_x + offset_index, base_y)) + Vector2(16.0, -16.0)


func _spawn_torch(torch_data: Dictionary) -> void:
	var torch: Node2D = TORCH_SCENE.instantiate() as Node2D
	if torch == null:
		return

	torch.visible = true
	var torch_position: Vector2 = _grid_to_world(Vector2i(int(torch_data.get("x", 0)), int(torch_data.get("y", 0)))) + Vector2(16.0, 8.0)
	torch.global_position = torch_position
	decor_root.add_child(torch)

	var brightness: float = float(torch_data.get("brightness", 1.0))
	var light_node: PointLight2D = torch.get_node_or_null("Light") as PointLight2D
	if light_node != null:
		light_node.energy *= brightness * 1.08


func _spawn_crystal(_crystal_data: Dictionary) -> void:
	return


func _spawn_pickup(pickup_data: Dictionary) -> void:
	var pickup: Area2D = ESSENCE_FRAGMENT_SCENE.instantiate() as Area2D
	if pickup == null:
		return

	pickup_root.add_child(pickup)
	pickup.global_position = _grid_to_world(Vector2i(int(pickup_data.get("x", 0)), int(pickup_data.get("y", 0)))) + Vector2(16.0, -6.0)
	pickup.set("toast_text", str(pickup_data.get("message", "Essenzsplitter geborgen.")))


func _spawn_enemy(enemy_data: Dictionary) -> void:
	var enemy_type: String = str(enemy_data.get("type", "slime"))
	var spawn_position: Vector2 = _grid_to_world(Vector2i(int(enemy_data.get("x", 0)), int(enemy_data.get("y", 0)))) + Vector2(16.0, -12.0)
	var enemy_scene: PackedScene = null

	match enemy_type:
		"slime":
			enemy_scene = CAVE_SLIME_SCENE
			spawn_position.y += 4.0
		"bat":
			enemy_scene = CAVE_BAT_SCENE
		"mushroom":
			enemy_scene = GLOWCAP_SCENE
			spawn_position.y += 4.0
		_:
			return

	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	if enemy == null:
		return
	enemy_root.add_child(enemy)
	enemy.global_position = spawn_position


func _spawn_story_trigger(trigger_data: Dictionary) -> void:
	var area := Area2D.new()
	trigger_root.add_child(area)
	area.monitoring = true
	area.position = _grid_to_world(Vector2i(int(trigger_data.get("x", 0)), int(trigger_data.get("y", 0))))

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	var width: int = max(1, int(trigger_data.get("w", 1)))
	var height: int = max(1, int(trigger_data.get("h", 1)))
	shape.size = Vector2(width * TILE_SIZE, height * TILE_SIZE)
	collision.shape = shape
	collision.position = shape.size * 0.5
	area.add_child(collision)

	var trigger_id: String = "chapter_%d_level_%d_%s" % [int(active_level.get("chapter_index", 0)), int(active_level.get("level_index", 0)) + 1, str(trigger_data.get("id", "trigger"))]
	var message: String = str(trigger_data.get("message", ""))
	var toast_type: String = str(trigger_data.get("toast_type", "info"))
	var banner: String = str(trigger_data.get("banner", ""))
	var tutorial: Dictionary = (trigger_data.get("tutorial", {}) as Dictionary).duplicate(true)
	area.body_entered.connect(_on_story_trigger_entered.bind(trigger_id, message, toast_type, banner, tutorial))


func _spawn_exit_gate() -> void:
	var chapter_meta: Dictionary = ChapterContent.get_chapter_meta(int(active_level.get("chapter_index", 1)))
	resolved_exit_tile = _resolve_exit_gate_tile()
	exit_gate = CHAPTER_GATE_SCENE.instantiate() as Node2D
	if exit_gate == null:
		return

	gate_root.add_child(exit_gate)
	exit_gate.global_position = _grid_to_world(resolved_exit_tile) + Vector2(18.0, 22.0)
	var exit_title := "Weiter"
	var exit_subtitle := str(active_level.get("level_label", ""))
	var callback := Callable(self, "_complete_level")
	exit_gate.call("configure_exit_gate", exit_title, exit_subtitle, chapter_meta.get("accent", Color(0.72, 0.92, 1.0, 1.0)) as Color, callback)

	if active_level.has("boss"):
		exit_gate.visible = false
		boss_gate_revealed = false


func _spawn_boss_if_needed() -> void:
	if not active_level.has("boss"):
		return

	var boss_data: Dictionary = active_level.get("boss", {}) as Dictionary
	var boss: Node2D = SLIME_KING_SCENE.instantiate() as Node2D
	if boss == null:
		return

	enemy_root.add_child(boss)
	boss.global_position = _grid_to_world(Vector2i(int(boss_data.get("x", 58)), int(boss_data.get("y", 26)))) + Vector2(16.0, -14.0)
	boss.connect("health_changed", Callable(self, "_on_boss_health_changed"))
	boss.connect("defeated", Callable(self, "_on_boss_defeated"))
	boss_bar.visible = true
	boss_name.visible = true
	boss_name.text = "KOENIG DER HOEHLENSCHLEIME"


func _position_player_at_spawn() -> void:
	var spawn_tile: Vector2i = _find_spawn_air_tile()
	var target_position: Vector2 = _grid_to_world(spawn_tile) + Vector2(16.0, -36.0)
	var floor_y: float = _surface_world_y_from_point(target_position)
	if floor_y > -INF:
		target_position.y = floor_y - _player_spawn_clearance()
	player.global_position = target_position
	player.velocity = Vector2.ZERO


func _setup_ui() -> void:
	intro_panel = PanelContainer.new()
	intro_panel.visible = false
	intro_panel.anchor_left = 0.5
	intro_panel.anchor_top = 0.0
	intro_panel.anchor_right = 0.5
	intro_panel.anchor_bottom = 0.0
	intro_panel.offset_left = -320.0
	intro_panel.offset_top = 28.0
	intro_panel.offset_right = 320.0
	intro_panel.offset_bottom = 152.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.08, 0.12, 0.92)
	panel_style.border_color = Color(0.55, 0.9, 1.0, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	panel_style.shadow_size = 14
	panel_style.content_margin_left = 18
	panel_style.content_margin_top = 16
	panel_style.content_margin_right = 18
	panel_style.content_margin_bottom = 16
	intro_panel.add_theme_stylebox_override("panel", panel_style)

	var intro_column := VBoxContainer.new()
	intro_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	intro_column.add_theme_constant_override("separation", 6)
	intro_panel.add_child(intro_column)

	intro_title = Label.new()
	intro_title.add_theme_font_size_override("font_size", 28)
	intro_title.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
	intro_title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	intro_title.add_theme_constant_override("outline_size", 5)
	if feedback_font:
		intro_title.add_theme_font_override("font", feedback_font)
	intro_column.add_child(intro_title)

	intro_subtitle = Label.new()
	intro_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_subtitle.add_theme_font_size_override("font_size", 16)
	intro_subtitle.add_theme_color_override("font_color", Color(0.74, 0.88, 0.97, 0.96))
	intro_subtitle.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	intro_subtitle.add_theme_constant_override("outline_size", 4)
	if feedback_font:
		intro_subtitle.add_theme_font_override("font", feedback_font)
	intro_column.add_child(intro_subtitle)

	intro_objective = Label.new()
	intro_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_objective.add_theme_font_size_override("font_size", 15)
	intro_objective.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.94))
	intro_objective.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	intro_objective.add_theme_constant_override("outline_size", 4)
	if feedback_font:
		intro_objective.add_theme_font_override("font", feedback_font)
	intro_column.add_child(intro_objective)

	ui_layer.add_child(intro_panel)

	tutorial_panel = PanelContainer.new()
	tutorial_panel.visible = false
	tutorial_panel.anchor_left = 1.0
	tutorial_panel.anchor_top = 0.0
	tutorial_panel.anchor_right = 1.0
	tutorial_panel.anchor_bottom = 0.0
	tutorial_panel.offset_left = -432.0
	tutorial_panel.offset_top = 26.0
	tutorial_panel.offset_right = -24.0
	tutorial_panel.offset_bottom = 246.0

	var tutorial_style := StyleBoxFlat.new()
	tutorial_style.bg_color = Color(0.03, 0.07, 0.11, 0.95)
	tutorial_style.border_color = Color(0.6, 0.92, 1.0, 0.95)
	tutorial_style.set_border_width_all(2)
	tutorial_style.corner_radius_top_left = 18
	tutorial_style.corner_radius_top_right = 18
	tutorial_style.corner_radius_bottom_left = 18
	tutorial_style.corner_radius_bottom_right = 18
	tutorial_style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	tutorial_style.shadow_size = 14
	tutorial_style.content_margin_left = 18
	tutorial_style.content_margin_top = 16
	tutorial_style.content_margin_right = 18
	tutorial_style.content_margin_bottom = 16
	tutorial_panel.add_theme_stylebox_override("panel", tutorial_style)

	var tutorial_column := VBoxContainer.new()
	tutorial_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tutorial_column.add_theme_constant_override("separation", 8)
	tutorial_panel.add_child(tutorial_column)

	tutorial_kicker = Label.new()
	tutorial_kicker.text = "TUTORIAL"
	tutorial_kicker.add_theme_font_size_override("font_size", 13)
	tutorial_kicker.add_theme_color_override("font_color", Color(0.62, 0.96, 1.0, 0.96))
	tutorial_kicker.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	tutorial_kicker.add_theme_constant_override("outline_size", 4)
	if feedback_font:
		tutorial_kicker.add_theme_font_override("font", feedback_font)
	tutorial_column.add_child(tutorial_kicker)

	tutorial_title = Label.new()
	tutorial_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_title.add_theme_font_size_override("font_size", 24)
	tutorial_title.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	tutorial_title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	tutorial_title.add_theme_constant_override("outline_size", 5)
	if feedback_font:
		tutorial_title.add_theme_font_override("font", feedback_font)
	tutorial_column.add_child(tutorial_title)

	tutorial_body = Label.new()
	tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_body.add_theme_font_size_override("font_size", 15)
	tutorial_body.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.96))
	tutorial_body.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	tutorial_body.add_theme_constant_override("outline_size", 4)
	if feedback_font:
		tutorial_body.add_theme_font_override("font", feedback_font)
	tutorial_column.add_child(tutorial_body)

	tutorial_controls = Label.new()
	tutorial_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_controls.add_theme_font_size_override("font_size", 14)
	tutorial_controls.add_theme_color_override("font_color", Color(0.7, 0.93, 1.0, 0.98))
	tutorial_controls.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	tutorial_controls.add_theme_constant_override("outline_size", 4)
	if feedback_font:
		tutorial_controls.add_theme_font_override("font", feedback_font)
	tutorial_column.add_child(tutorial_controls)

	ui_layer.add_child(tutorial_panel)

	boss_name = Label.new()
	boss_name.visible = false
	boss_name.anchor_left = 0.5
	boss_name.anchor_top = 0.0
	boss_name.anchor_right = 0.5
	boss_name.anchor_bottom = 0.0
	boss_name.offset_left = -240.0
	boss_name.offset_top = 20.0
	boss_name.offset_right = 240.0
	boss_name.offset_bottom = 48.0
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_font_size_override("font_size", 20)
	boss_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.44, 1.0))
	boss_name.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	boss_name.add_theme_constant_override("outline_size", 5)
	if feedback_font:
		boss_name.add_theme_font_override("font", feedback_font)
	ui_layer.add_child(boss_name)

	boss_bar = ProgressBar.new()
	boss_bar.visible = false
	boss_bar.anchor_left = 0.5
	boss_bar.anchor_top = 0.0
	boss_bar.anchor_right = 0.5
	boss_bar.anchor_bottom = 0.0
	boss_bar.offset_left = -260.0
	boss_bar.offset_top = 54.0
	boss_bar.offset_right = 260.0
	boss_bar.offset_bottom = 78.0
	boss_bar.min_value = 0.0
	boss_bar.max_value = 100.0
	boss_bar.value = 100.0
	var boss_bg := StyleBoxFlat.new()
	boss_bg.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	boss_bg.border_color = Color(0.22, 0.28, 0.34, 0.96)
	boss_bg.set_border_width_all(2)
	boss_bg.corner_radius_top_left = 10
	boss_bg.corner_radius_top_right = 10
	boss_bg.corner_radius_bottom_left = 10
	boss_bg.corner_radius_bottom_right = 10
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color(0.63, 0.96, 0.54, 0.95)
	boss_fill.corner_radius_top_left = 9
	boss_fill.corner_radius_top_right = 9
	boss_fill.corner_radius_bottom_left = 9
	boss_fill.corner_radius_bottom_right = 9
	boss_bar.add_theme_stylebox_override("background", boss_bg)
	boss_bar.add_theme_stylebox_override("fill", boss_fill)
	ui_layer.add_child(boss_bar)


func _show_level_intro() -> void:
	var chapter_meta: Dictionary = ChapterContent.get_chapter_meta(int(active_level.get("chapter_index", 1)))
	intro_title.text = "%s  •  %s" % [str(chapter_meta.get("door_suffix", "Kapitel I")), str(active_level.get("title", ""))]
	intro_subtitle.text = str(active_level.get("subtitle", ""))
	intro_objective.text = str(active_level.get("objective", ""))
	intro_panel.visible = true
	intro_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	intro_panel.scale = Vector2(0.94, 0.94)

	if player != null and player.has_method("_show_feedback_banner"):
		player.call("_show_feedback_banner", str(active_level.get("level_label", "")), chapter_meta.get("accent", Color(0.72, 0.92, 1.0, 1.0)) as Color, 0.55)

	var intro_tween: Tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(intro_panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(intro_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro_tween.set_parallel(false)
	intro_tween.tween_interval(2.8)
	intro_tween.set_parallel(true)
	intro_tween.tween_property(intro_panel, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	intro_tween.tween_property(intro_panel, "scale", Vector2(0.98, 0.98), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	intro_tween.set_parallel(false)
	intro_tween.tween_callback(func() -> void:
		intro_panel.visible = false
	)


func _show_tutorial_card(tutorial_data: Dictionary) -> void:
	if tutorial_panel == null or tutorial_data.is_empty():
		return

	var accent: Color = tutorial_data.get("accent", Color(0.62, 0.96, 1.0, 1.0)) as Color
	var duration: float = float(tutorial_data.get("duration", 5.2))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.07, 0.11, 0.95)
	panel_style.border_color = accent.lightened(0.08)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	panel_style.shadow_size = 14
	panel_style.content_margin_left = 18
	panel_style.content_margin_top = 16
	panel_style.content_margin_right = 18
	panel_style.content_margin_bottom = 16
	tutorial_panel.add_theme_stylebox_override("panel", panel_style)

	tutorial_kicker.text = str(tutorial_data.get("kicker", "TUTORIAL"))
	tutorial_kicker.add_theme_color_override("font_color", accent.lightened(0.1))
	tutorial_title.text = str(tutorial_data.get("title", "Neuer Hinweis"))
	tutorial_body.text = str(tutorial_data.get("body", ""))
	tutorial_controls.text = str(tutorial_data.get("controls", ""))
	tutorial_controls.visible = not tutorial_controls.text.is_empty()

	if tutorial_tween != null:
		tutorial_tween.kill()
	tutorial_panel.visible = true
	tutorial_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	tutorial_panel.scale = Vector2(0.96, 0.96)

	tutorial_tween = create_tween()
	tutorial_tween.set_parallel(true)
	tutorial_tween.tween_property(tutorial_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tutorial_tween.tween_property(tutorial_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tutorial_tween.set_parallel(false)
	tutorial_tween.tween_interval(duration)
	tutorial_tween.set_parallel(true)
	tutorial_tween.tween_property(tutorial_panel, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tutorial_tween.tween_property(tutorial_panel, "scale", Vector2(0.98, 0.98), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tutorial_tween.set_parallel(false)
	tutorial_tween.tween_callback(func() -> void:
		tutorial_panel.visible = false
	)


func _on_story_trigger_entered(body: Node2D, trigger_id: String, message: String, toast_type: String, banner: String, tutorial_data: Dictionary) -> void:
	if not body.is_in_group("players"):
		return
	if _progress().has_seen(trigger_id):
		return
	_progress().mark_seen(trigger_id)
	if not tutorial_data.is_empty():
		var merged_tutorial: Dictionary = tutorial_data.duplicate(true)
		if str(merged_tutorial.get("body", "")).is_empty():
			merged_tutorial["body"] = message
		_show_tutorial_card(merged_tutorial)
	elif body.has_method("_show_feedback_toast"):
		body.call("_show_feedback_toast", message, toast_type, null)
	if not banner.is_empty() and body.has_method("_show_feedback_banner"):
		body.call("_show_feedback_banner", banner, Color(0.72, 0.92, 1.0, 1.0), 0.42)


func _on_boss_health_changed(current_health_value: int, max_health_value: int) -> void:
	boss_bar.max_value = float(max_health_value)
	boss_bar.value = float(current_health_value)


func _on_boss_defeated() -> void:
	boss_gate_revealed = true
	if exit_gate != null:
		exit_gate.visible = true
		exit_gate.call("configure_exit_gate", "Zurueck zum Hub", "Kapitel I abgeschlossen", Color(0.92, 0.96, 0.58, 1.0), Callable(self, "_complete_level"))

	boss_name.visible = false
	boss_bar.visible = false

	var exit_message: String = str(active_level.get("boss_exit_message", "Die Hoehle wird still."))
	if player != null and player.has_method("_show_feedback_toast"):
		player.call("_show_feedback_toast", exit_message, "reward", null)
	if player != null and player.has_method("_show_feedback_banner"):
		player.call("_show_feedback_banner", "MINI-BOSS BESIEGT", Color(1.0, 0.88, 0.46, 1.0), 0.7)

	for drop_index: int in range(3):
		var pickup: Area2D = ESSENCE_FRAGMENT_SCENE.instantiate() as Area2D
		if pickup == null:
			continue
		pickup_root.add_child(pickup)
		var boss_data: Dictionary = active_level.get("boss", {}) as Dictionary
		var boss_tile := Vector2i(int(boss_data.get("x", 58)), int(boss_data.get("y", 26)))
		var reward_origin: Vector2 = _grid_to_world(boss_tile) + Vector2(16.0, -18.0)
		var spread_x: float = (-24.0 + float(drop_index) * 24.0) + rng.randf_range(-8.0, 8.0)
		var spread_y: float = rng.randf_range(-18.0, 8.0)
		pickup.global_position = reward_origin + Vector2(spread_x, spread_y)
		pickup.set("toast_text", "Koenigliche Essenz geborgen.")


func _complete_level() -> void:
	if transition_locked:
		return
	transition_locked = true
	_progress().complete_active_level()


func _on_pause_menu_go_to_main_menu() -> void:
	get_tree().paused = false
	var main_menu_scene: PackedScene = load("res://Scenes/main_menu.tscn") as PackedScene
	if main_menu_scene == null:
		return
	get_tree().change_scene_to_packed(main_menu_scene)


func _return_to_hub() -> void:
	var progress: Node = _progress()
	progress.transition_to(progress.HUB_SCENE, true)


func _configure_runtime_view() -> void:
	if runtime_play_bounds.size == Vector2.ZERO:
		runtime_play_bounds = _calculate_play_bounds_rect()
	_configure_player_camera(runtime_play_bounds)
	_update_parallax_background_layout(runtime_play_bounds)


func _configure_player_camera(bounds: Rect2) -> void:
	if player == null:
		return
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	var padded_bounds: Rect2 = bounds.grow_individual(CAMERA_MARGIN.x, CAMERA_MARGIN.y, CAMERA_MARGIN.x, CAMERA_MARGIN.y)
	var envelope: Rect2 = _camera_envelope_rect()
	padded_bounds = _clamp_rect_to_envelope(padded_bounds, envelope)
	camera.limit_left = int(floor(padded_bounds.position.x))
	camera.limit_top = int(floor(padded_bounds.position.y))
	camera.limit_right = int(ceil(padded_bounds.end.x))
	camera.limit_bottom = int(ceil(padded_bounds.end.y))


func _camera_envelope_rect() -> Rect2:
	return Rect2(
		Vector2(-WORLD_BOUND_LEFT_PADDING, -WORLD_BOUND_TOP_PADDING),
		Vector2(level_size_pixels.x + WORLD_BOUND_LEFT_PADDING + WORLD_BOUND_RIGHT_PADDING, level_size_pixels.y + WORLD_BOUND_TOP_PADDING + WORLD_BOUND_BOTTOM_PADDING)
	)


func _calculate_play_bounds_rect() -> Rect2:
	var has_solid: bool = false
	var min_x: int = level_size_tiles.x
	var min_y: int = level_size_tiles.y
	var max_x: int = 0
	var max_y: int = 0

	for grid_y: int in range(level_size_tiles.y):
		for grid_x: int in range(level_size_tiles.x):
			if not _is_solid(solid_grid_cache, grid_x, grid_y):
				continue
			has_solid = true
			min_x = mini(min_x, grid_x)
			min_y = mini(min_y, grid_y)
			max_x = maxi(max_x, grid_x)
			max_y = maxi(max_y, grid_y)

	var bounds: Rect2
	if has_solid:
		bounds = Rect2(
			Vector2(float(min_x) * TILE_SIZE, float(min_y) * TILE_SIZE),
			Vector2(float(max_x - min_x + 1) * TILE_SIZE, float(max_y - min_y + 1) * TILE_SIZE)
		)
	else:
		bounds = Rect2(Vector2.ZERO, level_size_pixels)

	bounds = _expand_rect_to_include_point(bounds, _grid_to_world(active_level.get("spawn", Vector2i(4, 28)) as Vector2i) + Vector2(16.0, -48.0), Vector2(128.0, 160.0))
	var exit_tile: Vector2i = resolved_exit_tile if resolved_exit_tile != Vector2i.ZERO else active_level.get("exit", Vector2i(96, 24)) as Vector2i
	bounds = _expand_rect_to_include_point(bounds, _grid_to_world(exit_tile) + Vector2(18.0, -18.0), EXIT_VIEW_MARGIN)
	if exit_gate != null:
		bounds = _expand_rect_to_include_point(bounds, exit_gate.global_position + Vector2(0.0, -42.0), EXIT_VIEW_MARGIN)
	return _clamp_rect_to_envelope(bounds, _camera_envelope_rect())


func _expand_rect_to_include_point(rect: Rect2, point: Vector2, padding: Vector2) -> Rect2:
	var expanded: Rect2 = rect
	if expanded.size == Vector2.ZERO:
		return Rect2(point - padding, padding * 2.0)
	expanded = expanded.expand(point + padding)
	expanded = expanded.expand(point - padding)
	return expanded


func _clamp_rect_to_envelope(rect: Rect2, envelope: Rect2) -> Rect2:
	var clamped: Rect2 = rect
	clamped.size.x = minf(clamped.size.x, envelope.size.x)
	clamped.size.y = minf(clamped.size.y, envelope.size.y)
	clamped.position.x = clampf(clamped.position.x, envelope.position.x, envelope.end.x - clamped.size.x)
	clamped.position.y = clampf(clamped.position.y, envelope.position.y, envelope.end.y - clamped.size.y)
	return clamped


func _grid_to_world(tile_position: Vector2i) -> Vector2:
	return Vector2(tile_position.x * TILE_SIZE, tile_position.y * TILE_SIZE)


func _resolve_exit_gate_tile() -> Vector2i:
	var validation: Dictionary = active_level.get("layout_validation", {}) as Dictionary
	var fallback_tile: Vector2i = validation.get("exit_anchor", active_level.get("exit", Vector2i(96, 24))) as Vector2i
	if solid_grid_cache.is_empty():
		return fallback_tile

	var candidate_roots: Array = []
	var seen_roots: Dictionary = {}
	var exit_anchor: Vector2i = validation.get("exit_anchor", Vector2i.ZERO) as Vector2i
	if exit_anchor != Vector2i.ZERO:
		var exit_key: String = "%d:%d" % [exit_anchor.x, exit_anchor.y]
		seen_roots[exit_key] = true
		candidate_roots.append(exit_anchor)
	var path_points: Array = active_level.get("critical_path_nodes", []) as Array
	for point_index: int in range(path_points.size() - 1, maxi(-1, path_points.size() - 9), -1):
		var path_point: Vector2i = path_points[point_index] as Vector2i
		var key: String = "%d:%d" % [path_point.x, path_point.y]
		if seen_roots.has(key):
			continue
		seen_roots[key] = true
		candidate_roots.append(path_point)
	var fallback_key: String = "%d:%d" % [fallback_tile.x, fallback_tile.y]
	if not seen_roots.has(fallback_key):
		candidate_roots.append(fallback_tile)

	var y_offsets: Array[int] = [0, -1, 1, -2, 2, 3, -3, 4]
	var x_offsets: Array[int] = [0, -1, 1, -2, 2, -3, 3, -4, 4]
	for root_variant: Variant in candidate_roots:
		var root: Vector2i = root_variant as Vector2i
		for y_offset: int in y_offsets:
			var grid_y: int = clampi(root.y + y_offset, 4, level_size_tiles.y - 4)
			for x_offset: int in x_offsets:
				var grid_x: int = clampi(root.x + x_offset, 3, level_size_tiles.x - 4)
				if _is_valid_exit_tile(grid_x, grid_y):
					return Vector2i(grid_x, grid_y)
	return fallback_tile


func _find_spawn_air_tile() -> Vector2i:
	var fallback_tile: Vector2i = active_level.get("spawn", Vector2i(4, 28)) as Vector2i
	if solid_grid_cache.is_empty():
		return fallback_tile

	var y_offsets: Array[int] = [0, 1, 2, -1, 3, -2, 4, -3, 5, -4, 6, -5, 7, -6, 8]
	var x_offsets: Array[int] = [0, 1, -1, 2, -2, 3, -3]
	for y_offset: int in y_offsets:
		var grid_y: int = clampi(fallback_tile.y + y_offset, 2, level_size_tiles.y - 3)
		for x_offset: int in x_offsets:
			var grid_x: int = clampi(fallback_tile.x + x_offset, 1, level_size_tiles.x - 2)
			if _is_valid_spawn_tile(grid_x, grid_y):
				return Vector2i(grid_x, grid_y)

	return fallback_tile


func _surface_world_y_from_point(target_position: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(target_position + Vector2(0.0, -96.0), target_position + Vector2(0.0, 160.0))
	query.collision_mask = PLAYER_WORLD_COLLISION_LAYER
	query.exclude = [player]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -INF
	var hit_position: Vector2 = hit.get("position", target_position) as Vector2
	return hit_position.y


func _is_valid_spawn_tile(grid_x: int, grid_y: int) -> bool:
	if _is_solid(solid_grid_cache, grid_x, grid_y):
		return false
	if _is_solid(solid_grid_cache, grid_x, grid_y - 1):
		return false
	if _is_solid(solid_grid_cache, grid_x, grid_y - 2):
		return false
	if not _is_solid(solid_grid_cache, grid_x, grid_y + 1):
		return false
	return true


func _is_valid_exit_tile(grid_x: int, grid_y: int) -> bool:
	if not _is_solid(solid_grid_cache, grid_x, grid_y):
		return false
	for offset_y: int in range(1, 6):
		for offset_x: int in range(-1, 2):
			if _is_solid(solid_grid_cache, grid_x + offset_x, grid_y - offset_y):
				return false
	var floor_tiles: int = 0
	for offset_x: int in range(-2, 3):
		if _is_solid(solid_grid_cache, grid_x + offset_x, grid_y):
			floor_tiles += 1
	return floor_tiles >= 4


func _player_spawn_clearance() -> float:
	if player == null:
		return 14.0
	var collision_shape: CollisionShape2D = player.get_node_or_null("ColisionArea") as CollisionShape2D
	if collision_shape == null:
		return 14.0
	var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rect_shape == null:
		return 14.0
	var root_scale := Vector2(absf(player.scale.x), absf(player.scale.y))
	var local_scale := Vector2(absf(collision_shape.scale.x), absf(collision_shape.scale.y))
	var size_px := rect_shape.size * root_scale * local_scale
	var half_size_px := size_px * 0.5
	var angle: float = collision_shape.rotation
	var vertical_extent_px: float = absf(sin(angle)) * half_size_px.x + absf(cos(angle)) * half_size_px.y
	return vertical_extent_px + 2.0


func _min3(a: int, b: int, c: int) -> int:
	return mini(mini(a, b), c)


func _max3(a: int, b: int, c: int) -> int:
	return maxi(maxi(a, b), c)


func _progress() -> Node:
	return get_node("/root/ChapterProgress")


func _platform_colors(style: String) -> Dictionary:
	match style:
		"floor":
			return {
				"fill": Color(0.24, 0.31, 0.36, 1.0),
				"top": Color(0.72, 0.86, 0.92, 1.0),
				"under": Color(0.12, 0.16, 0.2, 0.84),
				"shadow": Color(0.0, 0.0, 0.0, 0.16),
				"accent": Color(0.82, 0.92, 0.98, 1.0)
			}
		"ledge":
			return {
				"fill": Color(0.22, 0.28, 0.34, 1.0),
				"top": Color(0.8, 0.9, 0.96, 1.0),
				"under": Color(0.1, 0.14, 0.18, 0.82),
				"shadow": Color(0.0, 0.0, 0.0, 0.16),
				"accent": Color(0.88, 0.95, 1.0, 1.0)
			}
		_:
			return {
				"fill": Color(0.23, 0.3, 0.35, 1.0),
				"top": Color(0.74, 0.88, 0.95, 1.0),
				"under": Color(0.1, 0.14, 0.19, 0.84),
				"shadow": Color(0.0, 0.0, 0.0, 0.16),
				"accent": Color(0.84, 0.93, 1.0, 1.0)
			}
