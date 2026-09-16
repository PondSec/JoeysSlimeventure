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
const MOSS_TILE_PATHS := [
	"res://Assets/Deko/moss/moss_0.png",
	"res://Assets/Deko/moss/moss_1.png",
	"res://Assets/Deko/moss/moss_2.png"
]
const LUSH_LANDMARK_PATHS := [
	"res://Assets/Deko/lush/lush_landmark_00.png",
	"res://Assets/Deko/lush/lush_landmark_01.png",
	"res://Assets/Deko/lush/lush_landmark_02.png"
]
const LUSH_CANOPY_PATHS := [
	"res://Assets/Deko/lush/lush_canopy_00.png",
	"res://Assets/Deko/lush/lush_canopy_01.png"
]
const WIND_BROADLEAF_PATHS := [
	"res://Assets/Deko/lush/wind_broadleaf_00.png",
	"res://Assets/Deko/lush/wind_broadleaf_01.png",
	"res://Assets/Deko/lush/wind_broadleaf_02.png",
	"res://Assets/Deko/lush/wind_broadleaf_03.png"
]
const WIND_GLOW_FLOWER_PATHS := [
	"res://Assets/Deko/lush/wind_glow_flower_00.png",
	"res://Assets/Deko/lush/wind_glow_flower_01.png",
	"res://Assets/Deko/lush/wind_glow_flower_02.png",
	"res://Assets/Deko/lush/wind_glow_flower_03.png"
]
const PLANT_GLOW_TEXTURE_PATH := "res://Assets/Light/torch_light.png"
const PLAYER_WORLD_COLLISION_LAYER := 2
const DEFAULT_CAVE_TILE_SOURCE_ID := 0
const CAVE_TILE_SIZE := Vector2i(32, 32)
const CAVE_TEXTURE_PATH := "res://Assets/Tiles/platformertiles.png"
const DEBUG_OVERLAY_TOGGLE_KEY := KEY_F2
const TILE_DEBUG_TOGGLE_KEY := KEY_F3
const GENERATED_PLANT_LIGHTS_ENABLED := false

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
const LUSH_BIOME_DEEP_BACKDROP_PATH := "res://Assets/Parallax Cave/Lush/lush_biome_deep_backdrop.png"
const LUSH_BIOME_MID_FRAME_PATH := "res://Assets/Parallax Cave/Lush/lush_biome_mid_frame.png"
const LUSH_BIOME_FOREGROUND_FRAME_PATH := "res://Assets/Parallax Cave/Lush/lush_biome_foreground_frame.png"
const LUSH_BIOME_TRANSITION_SHADER_PATH := "res://Shaders/lush_biome_transition.gdshader"
const NORMAL_CAVE_FOREGROUND_FRAME_PATH := "res://Assets/Parallax Cave/normal_cave_foreground_frame.png"
const NORMAL_CAVE_FOREGROUND_SHADER_PATH := "res://Shaders/normal_cave_foreground_transition.gdshader"
const LUSH_BIOME_TRANSITION_DISTANCE := 280.0
const LUSH_BIOME_SPAWN_EXCLUSION_DISTANCE := 640.0
const MIN_LUSH_BIOME_DENSITY := 4.6

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
var parallax_foreground_layer: Node2D
var normal_cave_foreground_root: Node2D
var normal_cave_foreground_material: ShaderMaterial
var lush_biome_backdrop_layer: CanvasLayer
var lush_biome_sprites: Array[Sprite2D] = []
var lush_biome_regions: Array[Rect2] = []
var lush_biome_density: Array[float] = []
var lush_biome_strength: float = 0.0
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
var cave_moss_textures: Array = []
var cave_flora_textures: Array = []
var lush_landmark_textures: Array = []
var lush_canopy_textures: Array = []
var wind_broadleaf_textures: Array = []
var wind_glow_flower_textures: Array = []
var decoration_alpha_bounds: Dictionary = {}

@onready var shadow: CanvasModulate = $Shadow


func _ready() -> void:
	add_to_group("chapter_runtime")
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
	# Keep the established normal cave depth. The retired lush overlay was a
	# separate CanvasLayer and is intentionally not recreated here outside of a
	# genuinely dense, registered lush biome.
	_build_parallax_background()
	_build_normal_cave_foreground()
	_build_lush_biome_parallax(runtime_play_bounds)
	_configure_runtime_view()
	await get_tree().process_frame
	_position_player_at_spawn()
	_grant_level_one_mobility()
	_show_level_intro()


func _process(delta: float) -> void:
	if player == null:
		return
	# The ordinary foreground is always present, independent of whether this
	# seed contains a lush biome.  Keeping it moving here also gives the normal
	# cave the same depth response as the lush frame.
	if normal_cave_foreground_root != null:
		_update_overlay_parallax(normal_cave_foreground_root, player.global_position)
	if lush_biome_sprites.is_empty():
		return
	var target_strength := _get_lush_biome_strength(player.global_position)
	lush_biome_strength = move_toward(lush_biome_strength, target_strength, delta * 0.72)
	var should_be_visible: bool = lush_biome_strength > 0.003 or target_strength > 0.003
	if lush_biome_backdrop_layer != null:
		lush_biome_backdrop_layer.visible = should_be_visible
	if normal_cave_foreground_material != null:
		normal_cave_foreground_material.set_shader_parameter("lush_strength", lush_biome_strength)
	for sprite_index: int in range(lush_biome_sprites.size()):
		var sprite: Sprite2D = lush_biome_sprites[sprite_index]
		# The first two sprites live in the hidden backdrop CanvasLayer. The
		# foreground frame sits on the normal foreground canvas and must be
		# explicitly culled when the player is outside this biome.
		if sprite_index == lush_biome_sprites.size() - 1:
			sprite.visible = should_be_visible
		var material := sprite.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("biome_strength", lush_biome_strength)
		_update_overlay_parallax(sprite, player.global_position)


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


func _prewarm_next_level() -> void:
	if generator_seed_override >= 0:
		return
	var chapter_index := int(active_level.get("chapter_index", 0))
	var next_index := int(active_level.get("level_index", 0)) + 1
	var next_level := ChapterContent.get_level_data(chapter_index, next_index)
	if next_level.is_empty():
		return
	var next_size := next_level.get("size", Vector2i(100, 40)) as Vector2i
	var next_seed := int(hash("%s_%s_%d_%d" % [str(next_level.get("title", "")), str(next_level.get("level_label", "")), chapter_index, next_index]))
	ChapterLayoutBuilder.build_level_layout(next_level, next_size, next_seed)


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

		# The renderer culls each Sprite2D outside the camera. Four copies retain
		# the seamless existing horizontal loop without a per-frame script.
		for index: int in range(4):
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.position = Vector2(float(index) * float(texture.get_width()), 0.0)
			sprite.modulate = Color(1.0, 1.0, 1.0, float(texture_setting.get("alpha", 1.0)))
			sprite.light_mask = 0
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
					fx_sprite.light_mask = 0
					layer.add_child(fx_sprite)

		parallax_layer_entries.append({"layer": layer, "texture": texture})

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
	for layer_index: int in range(parallax_layer_entries.size()):
		var entry: Dictionary = parallax_layer_entries[layer_index] as Dictionary
		var layer: ParallaxLayer = entry.get("layer", null) as ParallaxLayer
		var texture: Texture2D = entry.get("texture", null) as Texture2D
		if layer == null or texture == null:
			continue
		var anchor_ratio: float = vertical_anchor_ratios[min(layer_index, vertical_anchor_ratios.size() - 1)]
		var start_x: float = bounds.position.x - float(texture.get_width()) * 0.22
		var anchor_y: float = bounds.position.y + bounds.size.y * anchor_ratio - float(texture.get_height()) * 0.08
		layer.position = Vector2(start_x, anchor_y)
		layer.motion_mirroring = Vector2(float(texture.get_width()), 0.0)

	_rebuild_backdrop_shapes(bounds)


func _build_normal_cave_foreground() -> void:
	if parallax_foreground_layer != null:
		parallax_foreground_layer.queue_free()
	normal_cave_foreground_root = null
	normal_cave_foreground_material = null
	# This is deliberately a world-space overlay, not a CanvasLayer.  The old
	# screen-space layer was glued to the camera and could never show parallax.
	parallax_foreground_layer = Node2D.new()
	parallax_foreground_layer.name = "NormalCaveForeground"
	# Above Joey, his weapon and ordinary decoration, below the HUD.
	parallax_foreground_layer.z_as_relative = false
	parallax_foreground_layer.z_index = 8
	add_child(parallax_foreground_layer)

	var texture := load(NORMAL_CAVE_FOREGROUND_FRAME_PATH) as Texture2D
	var shader := load(NORMAL_CAVE_FOREGROUND_SHADER_PATH) as Shader
	if texture == null or shader == null:
		return
	# The normal foreground always stays locked to the top/bottom screen edges.
	# Its modest horizontal drift has generous overscan, so it never exposes a
	# gap while Joey moves through a room or drops down a shaft.
	# The artwork is given real pixel overscan instead of an arbitrary scale.
	# That guarantees every visible screen edge stays covered, including while
	# the close frame moves faster than the distant cave layers.
	normal_cave_foreground_root = _create_overlay_root(texture, 184.0, Vector2(-0.16, 0.0))
	normal_cave_foreground_material = ShaderMaterial.new()
	normal_cave_foreground_material.shader = shader
	normal_cave_foreground_material.set_shader_parameter("lush_strength", 0.0)
	# The middle of this source art is fully transparent.  Draw the four visible
	# edge strips only; it preserves the exact frame while avoiding a costly
	# fullscreen transparent quad in every normal cave room.
	var texture_size := Vector2(texture.get_size())
	var top_height := 190.0
	var bottom_height := 220.0
	var side_width := 170.0
	var middle_height := texture_size.y - top_height - bottom_height
	var regions: Array[Rect2] = [
		Rect2(0.0, 0.0, texture_size.x, top_height),
		Rect2(0.0, texture_size.y - bottom_height, texture_size.x, bottom_height),
		Rect2(0.0, top_height, side_width, middle_height),
		Rect2(texture_size.x - side_width, top_height, side_width, middle_height)
	]
	for region: Rect2 in regions:
		var segment := Sprite2D.new()
		segment.texture = texture
		segment.centered = true
		segment.region_enabled = true
		segment.region_rect = region
		segment.position = region.get_center() - texture_size * 0.5
		segment.light_mask = 0
		segment.material = normal_cave_foreground_material
		normal_cave_foreground_root.add_child(segment)
	parallax_foreground_layer.add_child(normal_cave_foreground_root)


func _register_lush_biome_span(start_x: int, span: int, density_weight: float) -> void:
	# Only broad, connected moss/canopy runs feed the biome selector. Isolated
	# plants must never accidentally turn a normal cave passage into a lush room.
	for grid_x: int in range(maxi(0, start_x - 2), mini(level_size_tiles.x, start_x + span + 2)):
		if grid_x < 0 or grid_x >= lush_biome_density.size():
			continue
		var distance_from_span: float = absf(float(grid_x - (start_x + span / 2)))
		var local_weight: float = maxf(0.35, 1.0 - distance_from_span / maxf(1.0, float(span)))
		lush_biome_density[grid_x] += density_weight * local_weight


func _register_lush_biome_decor_density() -> void:
	# Flora is created in long rooted patches. Sampling those completed patches
	# makes the backdrop follow visible lush growth rather than an arbitrary
	# level coordinate, even on seeds without a perfectly flat canopy shelf.
	if decor_root == null or lush_biome_density.is_empty():
		return
	for child: Node in decor_root.get_children():
		if not child is CanvasItem:
			continue
		var weight: float = 0.0
		match child.name:
			"GeneratedFlora":
				weight = 1.15
			"GeneratedWindBroadleaf":
				weight = 2.8
			"GeneratedWindGlowFlower":
				weight = 2.4
			"GeneratedLushCanopy":
				weight = 3.4
			"GeneratedLushLandmark":
				weight = 2.6
			_:
				continue
		var grid_x: int = clampi(int(floor(child.global_position.x / TILE_SIZE)), 0, lush_biome_density.size() - 1)
		for offset_x: int in range(-3, 4):
			var sample_x: int = grid_x + offset_x
			if sample_x < 0 or sample_x >= lush_biome_density.size():
				continue
			lush_biome_density[sample_x] += weight * maxf(0.2, 1.0 - absf(float(offset_x)) / 4.0)


func _build_lush_biome_parallax(bounds: Rect2) -> void:
	if lush_biome_backdrop_layer != null:
		lush_biome_backdrop_layer.queue_free()
	lush_biome_sprites.clear()
	lush_biome_regions.clear()
	lush_biome_strength = 0.0
	if lush_biome_density.is_empty():
		return

	var spawn_tile := active_level.get("spawn", Vector2i(level_size_tiles.x / 2, level_size_tiles.y / 2)) as Vector2i
	var spawn_x: float = float(spawn_tile.x) * TILE_SIZE + TILE_SIZE * 0.5
	var best_score: float = 0.0
	var best_grid_x: int = -1
	for grid_x: int in range(lush_biome_density.size()):
		var candidate_x: float = float(grid_x) * TILE_SIZE + TILE_SIZE * 0.5
		# The initial room must remain normal cave.  A lush biome is a destination
		# inside the generated network, not a full-level filter at spawn.
		if absf(candidate_x - spawn_x) < LUSH_BIOME_SPAWN_EXCLUSION_DISTANCE:
			continue
		var score: float = lush_biome_density[grid_x]
		if score > best_score:
			best_score = score
			best_grid_x = grid_x
	# A decorative patch alone is not a biome. This threshold selects only the
	# dense, overlapping carpet/canopy areas created by the generator.
	if best_grid_x < 0 or best_score < MIN_LUSH_BIOME_DENSITY:
		return

	# Keep this deliberately local: a dense lush pocket, not an all-map skin.
	var core_width: float = clampf(bounds.size.x * 0.15, 420.0, 620.0)
	var center_x: float = float(best_grid_x) * TILE_SIZE + TILE_SIZE * 0.5
	var region := Rect2(
		Vector2(center_x - core_width * 0.5, bounds.position.y - 1024.0),
		Vector2(core_width, bounds.size.y + 2048.0)
	)
	lush_biome_regions.append(region)

	var shader := load(LUSH_BIOME_TRANSITION_SHADER_PATH) as Shader
	var deep_texture := load(LUSH_BIOME_DEEP_BACKDROP_PATH) as Texture2D
	var mid_texture := load(LUSH_BIOME_MID_FRAME_PATH) as Texture2D
	var foreground_texture := load(LUSH_BIOME_FOREGROUND_FRAME_PATH) as Texture2D
	if shader == null or deep_texture == null or mid_texture == null or foreground_texture == null:
		return

	# These canvases are separate from the lit world canvas. They therefore keep
	# their authored colours and cannot be brightened by Joey, torches or bloom.
	lush_biome_backdrop_layer = CanvasLayer.new()
	lush_biome_backdrop_layer.name = "LushBiomeBackdrop"
	lush_biome_backdrop_layer.layer = -2
	lush_biome_backdrop_layer.visible = false
	add_child(lush_biome_backdrop_layer)

	# Back to front: increasingly stronger motion.  Each source is scaled from
	# the actual viewport plus a safe overscan margin, never to a fraction of the
	# viewport.  This keeps all four borders fully attached to the screen while
	# retaining parallax movement.
	var deep_sprite := _create_lush_biome_sprite(deep_texture, shader, 0, 72.0, Vector2(-0.009, -0.004))
	var mid_sprite := _create_lush_biome_sprite(mid_texture, shader, 1, 136.0, Vector2(-0.030, -0.012))
	var foreground_sprite := _create_lush_biome_sprite(foreground_texture, shader, 0, 184.0, Vector2(-0.11, -0.022), true)
	foreground_sprite.visible = false
	lush_biome_backdrop_layer.add_child(deep_sprite)
	lush_biome_backdrop_layer.add_child(mid_sprite)
	if parallax_foreground_layer == null:
		foreground_sprite.queue_free()
		return
	parallax_foreground_layer.add_child(foreground_sprite)
	lush_biome_sprites = [deep_sprite, mid_sprite, foreground_sprite]
	print("LUSH_BIOME seed=%d center_x=%.0f score=%.1f" % [active_level_seed, center_x, best_score])


func _create_lush_biome_sprite(texture: Texture2D, shader: Shader, z_order: int, edge_overscan: float = 0.0, parallax_factor: Vector2 = Vector2.ZERO, world_space: bool = false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = _get_overlay_camera_center() if world_space else get_viewport_rect().size * 0.5
	sprite.scale = Vector2.ONE * _get_overlay_scale(texture, edge_overscan, world_space)
	sprite.set_meta("parallax_factor", parallax_factor)
	sprite.set_meta("world_space_overlay", world_space)
	sprite.z_index = z_order
	sprite.light_mask = 0
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("biome_strength", 0.0)
	sprite.material = material
	return sprite


func _create_overlay_root(texture: Texture2D, edge_overscan: float, parallax_factor: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = _get_overlay_camera_center()
	root.scale = Vector2.ONE * _get_overlay_scale(texture, edge_overscan, true)
	root.set_meta("parallax_factor", parallax_factor)
	root.set_meta("world_space_overlay", true)
	return root


func _get_overlay_scale(texture: Texture2D, edge_overscan: float, world_space: bool) -> float:
	# Scale from the visible viewport plus an explicit margin on every side.
	# This is resolution/zoom independent and avoids the half-screen frames that
	# occurred when an art-specific multiplier was used.
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1920.0, 1080.0)
	var texture_size := Vector2(texture.get_size())
	var covered_size := viewport_size + Vector2.ONE * maxf(0.0, edge_overscan) * 2.0
	var scale_factor: float = maxf(covered_size.x / texture_size.x, covered_size.y / texture_size.y)
	if world_space:
		scale_factor /= _get_overlay_camera_zoom()
	return scale_factor


func _update_overlay_parallax(sprite: Node2D, world_position: Vector2) -> void:
	# CanvasLayer sprites are screen-space.  Offset them from the screen centre
	# by a small fraction of the world position, mirroring the existing cave
	# ParallaxLayer setup: close foreground shifts fastest, distant art slowest.
	var factor: Vector2 = sprite.get_meta("parallax_factor", Vector2.ZERO) as Vector2
	var world_space: bool = bool(sprite.get_meta("world_space_overlay", false))
	var motion_position: Vector2 = _get_overlay_camera_center() if world_space else world_position
	if not sprite.has_meta("parallax_anchor"):
		sprite.set_meta("parallax_anchor", motion_position)
	var anchor: Vector2 = sprite.get_meta("parallax_anchor", motion_position) as Vector2
	# Work from the local camera journey rather than absolute map coordinates.
	# This retains a clear foreground/deep-background speed difference without
	# ever pushing a framed texture past its safe overscan at map extremes.
	var offset := (motion_position - anchor) * factor
	# World overlays are viewed through the camera zoom.  Limit their final
	# on-screen shift rather than their raw world units, so their overscan stays
	# valid at every zoom level and no edge can ever slip inward.
	var screen_limit := Vector2(108.0, 38.0) if world_space else Vector2(96.0, 34.0)
	var world_limit := screen_limit / _get_overlay_camera_zoom() if world_space else screen_limit
	offset.x = clampf(offset.x, -world_limit.x, world_limit.x)
	offset.y = clampf(offset.y, -world_limit.y, world_limit.y)
	sprite.position = (motion_position if world_space else get_viewport_rect().size * 0.5) + offset


func _get_overlay_camera_center() -> Vector2:
	if player == null:
		return Vector2.ZERO
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		return camera.get_screen_center_position()
	return player.global_position


func _get_overlay_camera_zoom() -> float:
	if player == null:
		return 1.0
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		return maxf(0.01, camera.zoom.x)
	return 1.0


func _get_lush_biome_strength(world_position: Vector2) -> float:
	var strongest: float = 0.0
	for region: Rect2 in lush_biome_regions:
		var from_left: float = smoothstep(region.position.x - LUSH_BIOME_TRANSITION_DISTANCE, region.position.x, world_position.x)
		var from_right: float = 1.0 - smoothstep(region.end.x, region.end.x + LUSH_BIOME_TRANSITION_DISTANCE, world_position.x)
		strongest = maxf(strongest, from_left * from_right)
	return strongest


func _rebuild_backdrop_shapes(bounds: Rect2) -> void:
	for child: Node in backdrop_root.get_children():
		child.free()

	for index: int in range(20):
		var stalactite := Polygon2D.new()
		var start_x: float = lerpf(bounds.position.x - 120.0, bounds.end.x + 120.0, float(index) / 19.0)
		var width: float = rng.randf_range(60.0, 130.0)
		var height: float = rng.randf_range(90.0, 210.0)
		stalactite.color = Color(0.08, 0.12, 0.16, 0.28)
		stalactite.light_mask = 0
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
		stalagmite.light_mask = 0
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
	var portal_state: Dictionary = _progress().consume_runtime_player_state()
	if not portal_state.is_empty() and player.has_method("restore_portal_state"):
		player.call("restore_portal_state", portal_state)


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
	var level_index: int = int(active_level.get("level_index", -1))
	# Glow ist eine Grundfaehigkeit und wird fuer die Lesbarkeit der ersten
	# Hoehlen garantiert. Bewegungsskills entsprechen exakt dem Profil, mit dem
	# der Layout-Validator dieses Level gebaut hat.
	player.call("grant_skill", "glow", false)
	var enabled_skills: Dictionary = active_level.get("mobility_skills", {}) as Dictionary
	for skill_name_variant: Variant in enabled_skills.keys():
		var skill_name: String = str(skill_name_variant)
		if not bool(enabled_skills[skill_name]):
			continue
		var show_feedback: bool = level_index == 0 and skill_name == "wall_slide"
		player.call("grant_skill", skill_name, show_feedback)


func _build_level() -> void:
	var platforms: Array = active_level.get("platforms", []) as Array
	lush_biome_density.clear()
	lush_biome_density.resize(level_size_tiles.x)
	for density_index: int in range(lush_biome_density.size()):
		lush_biome_density[density_index] = 0.0
	solid_grid_cache = active_level.get("grid", []) as Array
	if solid_grid_cache.is_empty():
		solid_grid_cache = _build_cave_solid_grid(platforms)
	logical_terrain_map = TerrainResolver.build_logical_map(solid_grid_cache, level_size_tiles)
	solid_grid_cache = TerrainResolver.duplicate_cells(logical_terrain_map)
	_draw_cave_wall_tiles(logical_terrain_map)
	_spawn_cave_collision_mesh(solid_grid_cache)
	_spawn_world_bounds()
	_spawn_generated_overgrowth(solid_grid_cache)
	_spawn_generated_moss(solid_grid_cache)
	_spawn_lush_ground_carpet_zones(solid_grid_cache)
	_spawn_lush_canopy_zones(solid_grid_cache)
	_spawn_generated_flora(solid_grid_cache)
	_spawn_lush_flower_landmarks(solid_grid_cache)
	_spawn_wind_broadleaf_plants(solid_grid_cache)
	_spawn_wind_glow_flowers(solid_grid_cache)
	_register_lush_biome_decor_density()

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
			if not _has_cave_atlas_tile(atlas_coords):
				# A logical edge may legitimately classify to a corner that is
				# absent from a swapped tileset. Never emit a shifted/missing cell.
				atlas_coords = Vector2i(1, 1)
			var alternative_tile: int = int(resolved_tile.get("alternative", 0))
			wall_tiles.set_cell(cell, cave_tile_source_id, atlas_coords, alternative_tile)


func _has_cave_atlas_tile(atlas_coords: Vector2i) -> bool:
	if cave_tileset == null:
		return false
	var source: TileSetAtlasSource = cave_tileset.get_source(cave_tile_source_id) as TileSetAtlasSource
	return source != null and source.has_tile(atlas_coords)


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
	# Ranken wachsen als kleine, zusammenhaengende Bueschel an natuerlichen
	# Decken- und Schachtkanten. Einzelne, gleich lange Rasterlinien wirkten wie
	# Markierungen; unterschiedliche Laengen und versetzte Begleittriebe geben
	# den Hoehlen das dichte, gemuetliche Dschungel-Gefuehl der Referenz.
	var cluster_count: int = 0
	var previous_cluster_x: int = -99
	for grid_x: int in range(3, level_size_tiles.x - 4):
		if grid_x - previous_cluster_x < 2:
			continue
		for grid_y: int in range(2, level_size_tiles.y - 9):
			if not _is_vine_anchor(grid, grid_x, grid_y) or rng.randf() > 0.51:
				continue
			var primary_length: int = rng.randi_range(4, 12)
			if not _has_vine_clearance(grid, grid_x, grid_y, primary_length):
				continue
			_spawn_vine_trail(grid_x, grid_y + 1, primary_length, rng.randf_range(-0.34, 0.34), 0.38)

			var companion_offset: int = -1 if rng.randf() < 0.5 else 1
			var companion_x: int = grid_x + companion_offset
			var companion_length: int = maxi(3, primary_length - rng.randi_range(1, 4))
			if _has_vine_clearance(grid, companion_x, grid_y, companion_length):
				_spawn_vine_trail(companion_x, grid_y + 1 + rng.randi_range(0, 1), companion_length, float(companion_offset) * 0.42, 0.28)

			# Ein dritter, kurzer Trieb bricht die Symmetrie und verbindet die
			# Saeulen optisch zu einem einzelnen organischen Bueschel.
			if rng.randf() < 0.84:
				var tendril_x: int = grid_x - companion_offset
				var tendril_length: int = rng.randi_range(2, 4)
				if _has_vine_clearance(grid, tendril_x, grid_y, tendril_length):
					_spawn_vine_trail(tendril_x, grid_y + 2, tendril_length, float(-companion_offset) * 0.62, 0.22)
			previous_cluster_x = grid_x
			cluster_count += 1
			if cluster_count >= 90:
				return
			break


func _spawn_generated_moss(grid: Array) -> void:
	# Moss grows in coherent wet patches, not as evenly spaced stickers.  Each
	# patch follows a real exposed rock face and uses the three hand-supplied
	# 32px variants; the same tiles are flipped/turned for floors, ceilings and
	# both wall directions.
	var moss_rng := RandomNumberGenerator.new()
	moss_rng.seed = active_level_seed * 173 + 401
	var claimed: Dictionary = {}
	var spawned: int = 0
	var patch_types: Array = [
		{"outward": Vector2i.UP, "tangent": Vector2i.RIGHT, "rotation": 0.0, "flip_v": false, "chance": 0.58, "budget": 420},
		{"outward": Vector2i.DOWN, "tangent": Vector2i.RIGHT, "rotation": 0.0, "flip_v": false, "chance": 0.54, "budget": 390},
		{"outward": Vector2i.RIGHT, "tangent": Vector2i.DOWN, "rotation": PI * 0.5, "flip_v": false, "chance": 0.39, "budget": 260},
		{"outward": Vector2i.LEFT, "tangent": Vector2i.DOWN, "rotation": -PI * 0.5, "flip_v": false, "chance": 0.39, "budget": 260}
	]
	for patch_variant: Variant in patch_types:
		var patch: Dictionary = patch_variant as Dictionary
		var outward: Vector2i = patch.get("outward", Vector2i.UP) as Vector2i
		var tangent: Vector2i = patch.get("tangent", Vector2i.RIGHT) as Vector2i
		var spawned_on_face: int = 0
		var face_budget: int = int(patch.get("budget", 0))
		for grid_y: int in range(2, level_size_tiles.y - 2):
			if spawned_on_face >= face_budget:
				break
			for grid_x: int in range(2, level_size_tiles.x - 2):
				if spawned_on_face >= face_budget:
					break
				var start := Vector2i(grid_x, grid_y)
				var start_key := "%d:%d:%d:%d" % [start.x, start.y, outward.x, outward.y]
				if claimed.has(start_key) or _is_torch_column(start.x):
					continue
				if outward == Vector2i.UP and not _has_ground_moss_shoulders(grid, start):
					continue
				if not _is_exposed_moss_face(grid, start, outward) or moss_rng.randf() > float(patch.get("chance", 0.0)):
					continue
				# A patch is deliberately long.  Short independent strips made the
				# cave read as scattered stickers instead of one damp ecosystem.
				var patch_length: int = moss_rng.randi_range(10, 22)
				for patch_step: int in range(patch_length):
					var cell: Vector2i = start + tangent * patch_step
					var key := "%d:%d:%d:%d" % [cell.x, cell.y, outward.x, outward.y]
					if not _is_exposed_moss_face(grid, cell, outward) or _is_torch_column(cell.x):
						break
					if outward == Vector2i.UP and not _has_ground_moss_shoulders(grid, cell):
						break
					claimed[key] = true
					_spawn_moss_tile(cell, patch, moss_rng)
					spawned += 1
					spawned_on_face += 1


func _is_exposed_moss_face(grid: Array, cell: Vector2i, outward: Vector2i) -> bool:
	return _is_solid(grid, cell.x, cell.y) and not _is_solid(grid, cell.x + outward.x, cell.y + outward.y)


func _has_ground_moss_shoulders(grid: Array, cell: Vector2i) -> bool:
	# Keep the tile-set's exposed corner pieces visible.  Moss starts one cell
	# inside a supported floor run and never wraps awkwardly around a cliff edge.
	return _is_solid(grid, cell.x - 1, cell.y) and _is_solid(grid, cell.x + 1, cell.y)


func _spawn_moss_tile(cell: Vector2i, patch: Dictionary, moss_rng: RandomNumberGenerator) -> void:
	var textures: Array = _get_cave_moss_textures()
	if decor_root == null or textures.is_empty():
		return
	var moss := Sprite2D.new()
	moss.name = "GeneratedMoss"
	var moss_texture := textures[moss_rng.randi_range(0, textures.size() - 1)] as Texture2D
	moss.texture = moss_texture
	var outward: Vector2i = patch.get("outward", Vector2i.UP) as Vector2i
	var moss_scale: float = float(patch.get("scale", 1.0))
	moss.scale = Vector2.ONE * moss_scale
	# Every moss piece is pinned to the exposed *outside* of its supporting
	# rock tile.  Placing all four cases in the tile centre made ceiling and wall
	# growth appear buried, detached, or visually one cell too high.
	if outward == Vector2i.UP:
		# Align the first non-transparent row to the actual top of this rock cell,
		# not to the centre of the PNG.  This lets adjacent moss tiles meet with no
		# black seam and covers the upper edge of the floor cleanly.
		# The artwork's visible moss reaches almost to the bottom of its PNG.
		# Lift a floor carpet slightly over the lip so it visibly blankets the
		# stone's top layer instead of reading as a decal buried in the wall.
		moss.position = _surface_moss_position(moss_texture, cell, moss.scale, float(cell.y) * TILE_SIZE - 6.0)
	elif outward == Vector2i.DOWN:
		moss.position = _surface_moss_position(moss_texture, cell, moss.scale, float(cell.y + 1) * TILE_SIZE)
	elif outward == Vector2i.RIGHT:
		moss.position = _right_wall_moss_position(moss_texture, cell, moss.scale)
	else:
		moss.position = _left_wall_moss_position(moss_texture, cell, moss.scale)
	moss.rotation = float(patch.get("rotation", 0.0))
	moss.flip_v = bool(patch.get("flip_v", false))
	# Horizontal flips shift an asymmetric alpha border by one or two pixels and
	# made seams visible in long carpets.  Surface strips keep a stable edge;
	# wall pieces can still vary organically through their source variant.
	moss.flip_h = outward != Vector2i.UP and outward != Vector2i.DOWN and moss_rng.randf() < 0.34
	# Most growth lives behind Joey; a controlled minority overlaps him so dense
	# fern and moss pockets feel traversed rather than painted on the backdrop.
	# A foreground patch must cover Joey and the equipped weapon together.
	# Player weapon visuals use z=4, so front vegetation deliberately sits above.
	moss.z_index = 6 if moss_rng.randf() < 0.35 else 0
	moss.modulate = Color(0.82, 1.0, 0.74, 1.0)
	decor_root.add_child(moss)


func _surface_moss_position(texture: Texture2D, cell: Vector2i, sprite_scale: Vector2, surface_y: float) -> Vector2:
	var alpha_bounds := _get_decoration_alpha_bounds(texture)
	var half_width: float = float(texture.get_width()) * 0.5
	var half_height: float = float(texture.get_height()) * 0.5
	# The alpha bounds, rather than the transparent PNG frame, define both the
	# horizontal tile seam and the visible top edge of a moss carpet.
	var x: float = float(cell.x) * TILE_SIZE - (float(alpha_bounds.position.x) - half_width) * sprite_scale.x
	var y: float = surface_y - (float(alpha_bounds.position.y) - half_height) * sprite_scale.y
	return Vector2(x, y)


func _ground_flora_position(texture: Texture2D, cell: Vector2i, sprite_scale: Vector2) -> Vector2:
	var alpha_bounds := _get_decoration_alpha_bounds(texture)
	var half_height: float = float(texture.get_height()) * 0.5
	# Plant roots use the final visible pixel, so source images with transparent
	# bottom padding cannot appear to float above a platform.
	# Sink roots by a few pixels into the moss carpet. This avoids a one-pixel
	# daylight gap from anti-aliased source sprites while keeping plants grounded.
	var root_y: float = float(cell.y) * TILE_SIZE + 4.0
	var y: float = root_y - (float(alpha_bounds.end.y) - half_height) * sprite_scale.y
	return Vector2(float(cell.x) * TILE_SIZE + TILE_SIZE * 0.5, y)


func _right_wall_moss_position(texture: Texture2D, cell: Vector2i, sprite_scale: Vector2) -> Vector2:
	var alpha_bounds := _get_decoration_alpha_bounds(texture)
	var half_width: float = float(texture.get_width()) * 0.5
	var half_height: float = float(texture.get_height()) * 0.5
	var visible_right_source: float = float(alpha_bounds.end.y - 1) - half_height
	var visible_top_source: float = float(alpha_bounds.position.x) - half_width
	var wall_x: float = float(cell.x + 1) * TILE_SIZE
	return Vector2(wall_x + visible_right_source * sprite_scale.y, float(cell.y) * TILE_SIZE - visible_top_source * sprite_scale.x)


func _left_wall_moss_position(texture: Texture2D, cell: Vector2i, sprite_scale: Vector2) -> Vector2:
	var alpha_bounds := _get_decoration_alpha_bounds(texture)
	var half_width: float = float(texture.get_width()) * 0.5
	var half_height: float = float(texture.get_height()) * 0.5
	var visible_right_source: float = float(alpha_bounds.end.y - 1) - half_height
	var visible_top_source: float = -float(alpha_bounds.end.x - 1) + half_width
	var wall_x: float = float(cell.x) * TILE_SIZE
	return Vector2(wall_x - visible_right_source * sprite_scale.y, float(cell.y) * TILE_SIZE - visible_top_source * sprite_scale.x)


func _get_decoration_alpha_bounds(texture: Texture2D) -> Rect2i:
	if texture == null:
		return Rect2i(Vector2i.ZERO, Vector2i(int(TILE_SIZE), int(TILE_SIZE)))
	var cache_key: String = texture.resource_path
	if cache_key.is_empty():
		cache_key = str(texture.get_instance_id())
	if decoration_alpha_bounds.has(cache_key):
		return decoration_alpha_bounds[cache_key] as Rect2i
	var image := texture.get_image()
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(texture.get_width(), texture.get_height()))
	if image != null:
		var min_x: int = image.get_width()
		var min_y: int = image.get_height()
		var max_x: int = -1
		var max_y: int = -1
		for pixel_y: int in range(image.get_height()):
			for pixel_x: int in range(image.get_width()):
				if image.get_pixel(pixel_x, pixel_y).a > 0.02:
					min_x = mini(min_x, pixel_x)
					min_y = mini(min_y, pixel_y)
					max_x = maxi(max_x, pixel_x)
					max_y = maxi(max_y, pixel_y)
		if max_x >= min_x and max_y >= min_y:
			bounds = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	decoration_alpha_bounds[cache_key] = bounds
	return bounds


func _get_cave_moss_textures() -> Array:
	if not cave_moss_textures.is_empty():
		return cave_moss_textures
	for texture_path: String in MOSS_TILE_PATHS:
		var texture := load(texture_path) as Texture2D
		if texture != null:
			cave_moss_textures.append(texture)
	return cave_moss_textures


func _spawn_lush_ground_carpet_zones(grid: Array) -> void:
	# Large, continuous moss carpets provide a real substrate for flora.  They
	# are generated from complete exposed floor runs, never as free-floating
	# pieces, and deliberately use overlapping long zones rather than a spray of
	# isolated 32px decals.
	var carpet_rng := RandomNumberGenerator.new()
	carpet_rng.seed = active_level_seed * 587 + 1103
	var claimed: Dictionary = {}
	var placed: int = 0
	for grid_y: int in range(3, level_size_tiles.y - 3):
		if placed >= 620:
			return
		for grid_x: int in range(3, level_size_tiles.x - 3):
			if placed >= 620:
				return
			var start := Vector2i(grid_x, grid_y)
			if _is_torch_column(grid_x) or not _is_exposed_moss_face(grid, start, Vector2i.UP) or not _has_ground_moss_shoulders(grid, start):
				continue
			if _is_exposed_moss_face(grid, start + Vector2i.LEFT, Vector2i.UP):
				continue
			var available: int = _exposed_face_run_length(grid, start, Vector2i.UP, Vector2i.RIGHT, 20)
			if available < 4 or carpet_rng.randf() > 0.90:
				continue
			var span: int = mini(available, carpet_rng.randi_range(10, 20))
			for offset: int in range(span):
				var cell := start + Vector2i.RIGHT * offset
				var key := "%d:%d" % [cell.x, cell.y]
				if claimed.has(key) or _is_torch_column(cell.x) or not _has_ground_moss_shoulders(grid, cell):
					continue
				claimed[key] = true
				_spawn_moss_tile(cell, {"outward": Vector2i.UP, "rotation": 0.0, "flip_v": false, "scale": 1.18}, carpet_rng)
				placed += 1
			_register_lush_biome_span(start.x, span, 1.0)


func _spawn_lush_canopy_zones(grid: Array) -> void:
	# Large seamless overhangs are the visual backbone of a lush cave.  A zone
	# starts at the beginning of a *real* ceiling shelf and fills a long run with
	# overlapping canopy modules.  This creates large connected vegetation areas,
	# rather than isolated decorations separated by black gaps.
	var canopy_rng := RandomNumberGenerator.new()
	canopy_rng.seed = active_level_seed * 421 + 2719
	var placed: int = 0
	var reserved: Dictionary = {}
	for grid_y: int in range(2, level_size_tiles.y - 5):
		if placed >= 10:
			break
		for grid_x: int in range(2, level_size_tiles.x - 9):
			if placed >= 10:
				break
			var start := Vector2i(grid_x, grid_y)
			if _is_lush_canopy_reserved(reserved, start) or _is_torch_column(grid_x) or not _is_exposed_moss_face(grid, start, Vector2i.DOWN):
				continue
			# Never start halfway through a shelf: that was the source of clipped,
			# isolated hanging chunks between otherwise empty ceiling cells.
			if _is_exposed_moss_face(grid, start + Vector2i.LEFT, Vector2i.DOWN):
				continue
			var available: int = _exposed_face_run_length(grid, start, Vector2i.DOWN, Vector2i.RIGHT, 16)
			# Organic cave ceilings are intentionally uneven, so four attached tiles
			# are enough to seed a large overgrown curtain.  Requiring long perfect
			# horizontal ceilings made whole seeds miss the landmark vegetation.
			if available < 4 or canopy_rng.randf() > 0.90:
				continue
			var span: int = mini(available, canopy_rng.randi_range(4, 14))
			_reserve_lush_canopy_zone(reserved, start, span)
			for offset: int in range(span):
				var moss_cell := start + Vector2i.RIGHT * offset
				if not _is_exposed_moss_face(grid, moss_cell, Vector2i.DOWN) or _is_torch_column(moss_cell.x):
					break
				_spawn_moss_tile(moss_cell, {"outward": Vector2i.DOWN, "rotation": 0.0, "flip_v": false}, canopy_rng)
			# Each wide source image covers roughly five tiles at this scale.  The
			# four-tile stride intentionally overlaps the transparent edges, so the
			# whole shelf becomes one continuous living canopy.
			for canopy_offset: int in range(0, span, 3):
				_spawn_lush_canopy(start + Vector2i.RIGHT * canopy_offset, 5, canopy_rng)
			_register_lush_biome_span(start.x, span, 2.6)
			placed += 1


func _is_lush_canopy_reserved(reserved: Dictionary, center: Vector2i) -> bool:
	for offset_y: int in range(-5, 6):
		for offset_x: int in range(-7, 8):
			if reserved.has("%d:%d" % [center.x + offset_x, center.y + offset_y]):
				return true
	return false


func _exposed_face_run_length(grid: Array, start: Vector2i, outward: Vector2i, tangent: Vector2i, maximum: int) -> int:
	var length: int = 0
	for offset: int in range(maximum):
		if not _is_exposed_moss_face(grid, start + tangent * offset, outward):
			break
		length += 1
	return length


func _reserve_lush_canopy_zone(reserved: Dictionary, start: Vector2i, span: int) -> void:
	for offset_y: int in range(-5, 6):
		for offset_x: int in range(-5, span + 6):
			reserved["%d:%d" % [start.x + offset_x, start.y + offset_y]] = true


func _get_lush_canopy_textures() -> Array:
	if not lush_canopy_textures.is_empty():
		return lush_canopy_textures
	for texture_path: String in LUSH_CANOPY_PATHS:
		var texture := load(texture_path) as Texture2D
		if texture != null:
			lush_canopy_textures.append(texture)
	return lush_canopy_textures


func _spawn_lush_canopy(start: Vector2i, span: int, canopy_rng: RandomNumberGenerator) -> void:
	var textures: Array = _get_lush_canopy_textures()
	if decor_root == null or textures.is_empty():
		return
	var sprite := Sprite2D.new()
	sprite.name = "GeneratedLushCanopy"
	sprite.texture = textures[canopy_rng.randi_range(0, textures.size() - 1)] as Texture2D
	var scale_amount: float = canopy_rng.randf_range(0.58, 0.72)
	sprite.scale = Vector2.ONE * scale_amount
	var rendered_height: float = float(sprite.texture.get_height()) * scale_amount
	# With Sprite2D centred, this pins the first opaque foliage directly below
	# the ceiling moss rather than leaving a black separation seam.
	sprite.position = _grid_to_world(start) + Vector2(float(span) * TILE_SIZE * 0.5, TILE_SIZE + rendered_height * 0.5 - 5.0)
	sprite.flip_h = canopy_rng.randf() < 0.5
	sprite.z_index = 6 if canopy_rng.randf() < 0.35 else 0
	sprite.modulate = Color(0.86 + canopy_rng.randf() * 0.14, 0.94 + canopy_rng.randf() * 0.06, 0.76 + canopy_rng.randf() * 0.16, 1.0)
	if canopy_rng.randf() < 0.42:
		_add_lush_plant_glow(sprite, canopy_rng, 0.11, 0.18)
	decor_root.add_child(sprite)


func _spawn_generated_flora(grid: Array) -> void:
	# Kleine Flora wird bewusst auf die bereits feuchten Kanten konzentriert.
	# Dadurch entstehen lesbare, ueppige Nischen statt gleichmaessig verteilter
	# Dekoration.  Die Hängepflanzen sind eigene Varianten; Bodenpflanzen werden
	# nur bei realer Auflageflaeche gesetzt.
	var flora_rng := RandomNumberGenerator.new()
	flora_rng.seed = active_level_seed * 233 + 907
	var placed: int = 0
	var claimed_ground: Dictionary = {}
	for grid_y: int in range(2, level_size_tiles.y - 2):
		if placed >= 320:
			break
		for grid_x: int in range(2, level_size_tiles.x - 2):
			if placed >= 320:
				break
			var cell := Vector2i(grid_x, grid_y)
			if not _is_exposed_moss_face(grid, cell, Vector2i.UP) or not _has_ground_moss_shoulders(grid, cell) or _is_torch_column(grid_x) or flora_rng.randf() > 0.78:
				continue
			var patch_length: int = flora_rng.randi_range(6, 12)
			for patch_step: int in range(patch_length):
				var patch_cell := cell + Vector2i.RIGHT * patch_step
				var key := "%d:%d" % [patch_cell.x, patch_cell.y]
				if claimed_ground.has(key) or not _is_exposed_moss_face(grid, patch_cell, Vector2i.UP) or not _has_ground_moss_shoulders(grid, patch_cell) or _is_torch_column(patch_cell.x):
					break
				claimed_ground[key] = true
				_spawn_flora_tile(patch_cell, Vector2i.UP, flora_rng, false)
				placed += 1

	# Long foliage only hangs from ceilings.  Rotating ground plants onto a wall
	# made a few variants look detached; walls instead receive their correctly
	# anchored moss and the dedicated vine clusters above.
	for grid_y: int in range(2, level_size_tiles.y - 2):
		for grid_x: int in range(2, level_size_tiles.x - 2):
			if placed >= 480:
				return
			var cell := Vector2i(grid_x, grid_y)
			for outward: Vector2i in [Vector2i.DOWN]:
				if not _is_exposed_moss_face(grid, cell, outward) or _is_torch_column(grid_x) or flora_rng.randf() > 0.19:
					continue
				_spawn_flora_tile(cell, outward, flora_rng, outward == Vector2i.DOWN)
				placed += 1
				break


func _get_cave_flora_textures() -> Array:
	if not cave_flora_textures.is_empty():
		return cave_flora_textures
	for texture_index: int in range(20):
		var texture := load("res://Assets/Deko/flora/flora_%02d.png" % texture_index) as Texture2D
		if texture != null:
			cave_flora_textures.append(texture)
	return cave_flora_textures


func _spawn_flora_tile(cell: Vector2i, outward: Vector2i, flora_rng: RandomNumberGenerator, hanging: bool) -> void:
	var textures: Array = _get_cave_flora_textures()
	if decor_root == null or textures.is_empty():
		return
	var hanging_indices: Array[int] = [5, 7, 17, 19]
	var ground_indices: Array[int] = [0, 1, 2, 3, 4, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18]
	var selected_indices: Array[int] = hanging_indices if hanging else ground_indices
	var sprite := Sprite2D.new()
	sprite.name = "GeneratedFlora"
	sprite.texture = textures[selected_indices[flora_rng.randi_range(0, selected_indices.size() - 1)]] as Texture2D
	# 35% foreground foliage deliberately crosses the player silhouette.
	sprite.z_index = 6 if flora_rng.randf() < 0.35 else 0
	sprite.modulate = Color(0.78 + flora_rng.randf() * 0.18, 0.95 + flora_rng.randf() * 0.05, 0.68 + flora_rng.randf() * 0.17, 1.0)
	if outward == Vector2i.UP:
		sprite.position = _ground_flora_position(sprite.texture, cell, sprite.scale)
	elif outward == Vector2i.DOWN:
		sprite.position = _grid_to_world(cell) + Vector2(16.0, 48.0)
	elif outward == Vector2i.RIGHT:
		sprite.position = _grid_to_world(cell) + Vector2(48.0, 16.0)
		sprite.rotation = PI * 0.5
	else:
		sprite.position = _grid_to_world(cell) + Vector2(-16.0, 16.0)
		sprite.rotation = -PI * 0.5
	sprite.flip_h = flora_rng.randf() < 0.38
	if flora_rng.randf() < 0.30:
		_add_lush_plant_glow(sprite, flora_rng, 0.15, 0.25)
	decor_root.add_child(sprite)


func _spawn_lush_flower_landmarks(grid: Array) -> void:
	# The three large hand-supplied flowers are sparse enough to act as little
	# colour landmarks, but numerous enough that lush pockets feel genuinely
	# inhabited. They only root on solid ground and never touch torch columns.
	var landmark_rng := RandomNumberGenerator.new()
	landmark_rng.seed = active_level_seed * 313 + 1709
	var placed: int = 0
	var claimed: Dictionary = {}
	for grid_y: int in range(3, level_size_tiles.y - 3):
		if placed >= 38:
			break
		for grid_x: int in range(3, level_size_tiles.x - 3):
			if placed >= 38:
				break
			var cell := Vector2i(grid_x, grid_y)
			var key := "%d:%d" % [cell.x, cell.y]
			if claimed.has(key) or _is_torch_column(grid_x) or not _is_exposed_moss_face(grid, cell, Vector2i.UP) or not _has_ground_moss_shoulders(grid, cell) or landmark_rng.randf() > 0.082:
				continue
			# A small run of exposed ground is required so these read as rooted
			# plants, rather than as a one-tile decal on a corner.
			if not _is_exposed_moss_face(grid, cell + Vector2i.RIGHT, Vector2i.UP):
				continue
			claimed[key] = true
			_spawn_lush_landmark(cell, landmark_rng)
			placed += 1


func _get_lush_landmark_textures() -> Array:
	if not lush_landmark_textures.is_empty():
		return lush_landmark_textures
	for texture_path: String in LUSH_LANDMARK_PATHS:
		var texture := load(texture_path) as Texture2D
		if texture != null:
			lush_landmark_textures.append(texture)
	return lush_landmark_textures


func _get_wind_broadleaf_textures() -> Array:
	if not wind_broadleaf_textures.is_empty():
		return wind_broadleaf_textures
	for texture_path: String in WIND_BROADLEAF_PATHS:
		var texture := load(texture_path) as Texture2D
		if texture != null:
			wind_broadleaf_textures.append(texture)
	return wind_broadleaf_textures


func _get_wind_glow_flower_textures() -> Array:
	if not wind_glow_flower_textures.is_empty():
		return wind_glow_flower_textures
	for texture_path: String in WIND_GLOW_FLOWER_PATHS:
		var texture := load(texture_path) as Texture2D
		if texture != null:
			wind_glow_flower_textures.append(texture)
	return wind_glow_flower_textures


func _spawn_wind_broadleaf_plants(grid: Array) -> void:
	# The supplied four images are consecutive wind frames.  They stay rooted on
	# the same moss-covered floor while the leaves gently sway, so the generator
	# gains motion without a single hard-coded level placement.
	if decor_root == null:
		return
	var textures: Array = _get_wind_broadleaf_textures()
	if textures.size() != WIND_BROADLEAF_PATHS.size():
		return
	var plant_rng := RandomNumberGenerator.new()
	plant_rng.seed = active_level_seed * 719 + 4177
	var placed: int = 0
	var claimed: Dictionary = {}
	for grid_y: int in range(3, level_size_tiles.y - 3):
		if placed >= 24:
			return
		for grid_x: int in range(4, level_size_tiles.x - 4):
			if placed >= 24:
				return
			var cell := Vector2i(grid_x, grid_y)
			var key := "%d:%d" % [cell.x, cell.y]
			if claimed.has(key) or _is_torch_column(grid_x) or not _is_exposed_moss_face(grid, cell, Vector2i.UP) or not _has_ground_moss_shoulders(grid, cell):
				continue
			if plant_rng.randf() > 0.045:
				continue
			# Reserve shoulders so these wide leaves never stack into a rigid wall.
			for offset_x: int in range(-2, 3):
				claimed["%d:%d" % [cell.x + offset_x, cell.y]] = true
			var frames := SpriteFrames.new()
			frames.remove_animation(&"default")
			frames.add_animation(&"wind")
			frames.set_animation_speed(&"wind", plant_rng.randf_range(1.25, 1.75))
			frames.set_animation_loop(&"wind", true)
			for texture: Texture2D in textures:
				frames.add_frame(&"wind", texture)
			var plant := AnimatedSprite2D.new()
			plant.name = "GeneratedWindBroadleaf"
			plant.sprite_frames = frames
			plant.animation = &"wind"
			plant.frame = plant_rng.randi_range(0, textures.size() - 1)
			plant.frame_progress = plant_rng.randf()
			plant.scale = Vector2.ONE * plant_rng.randf_range(0.105, 0.135)
			plant.position = _ground_flora_position(textures[0] as Texture2D, cell, plant.scale)
			plant.flip_h = plant_rng.randf() < 0.5
			plant.z_index = 6 if plant_rng.randf() < 0.35 else 0
			plant.modulate = Color(0.72, 0.92, 0.78, 1.0)
			plant.play(&"wind")
			decor_root.add_child(plant)
			placed += 1


func _spawn_wind_glow_flowers(grid: Array) -> void:
	# The yellow buds use their supplied four wind frames. Their visible roots
	# are aligned to the moss surface, and the authored bright buds get only a
	# restrained HDR tint — no gameplay light is spawned for each flower.
	if decor_root == null:
		return
	var textures: Array = _get_wind_glow_flower_textures()
	if textures.size() != WIND_GLOW_FLOWER_PATHS.size():
		return
	var flower_rng := RandomNumberGenerator.new()
	flower_rng.seed = active_level_seed * 911 + 6029
	var placed: int = 0
	var claimed: Dictionary = {}
	for grid_y: int in range(3, level_size_tiles.y - 3):
		if placed >= 18:
			return
		for grid_x: int in range(4, level_size_tiles.x - 4):
			if placed >= 18:
				return
			var cell := Vector2i(grid_x, grid_y)
			var key := "%d:%d" % [cell.x, cell.y]
			if claimed.has(key) or _is_torch_column(grid_x) or not _is_exposed_moss_face(grid, cell, Vector2i.UP) or not _has_ground_moss_shoulders(grid, cell):
				continue
			if flower_rng.randf() > 0.032:
				continue
			for offset_x: int in range(-2, 3):
				claimed["%d:%d" % [cell.x + offset_x, cell.y]] = true
			var frames := SpriteFrames.new()
			frames.remove_animation(&"default")
			frames.add_animation(&"wind")
			frames.set_animation_speed(&"wind", flower_rng.randf_range(0.95, 1.30))
			frames.set_animation_loop(&"wind", true)
			for texture: Texture2D in textures:
				frames.add_frame(&"wind", texture)
			var flower := AnimatedSprite2D.new()
			flower.name = "GeneratedWindGlowFlower"
			flower.sprite_frames = frames
			flower.animation = &"wind"
			flower.frame = flower_rng.randi_range(0, textures.size() - 1)
			flower.frame_progress = flower_rng.randf()
			flower.scale = Vector2.ONE * flower_rng.randf_range(0.092, 0.118)
			flower.position = _ground_flora_position(textures[0] as Texture2D, cell, flower.scale)
			flower.flip_h = flower_rng.randf() < 0.5
			flower.z_index = 6 if flower_rng.randf() < 0.35 else 0
			flower.modulate = Color(0.82, 0.98, 0.66, 1.0)
			flower.self_modulate = Color(1.10, 1.04, 0.82, 1.0)
			flower.play(&"wind")
			decor_root.add_child(flower)
			placed += 1


func _spawn_lush_landmark(cell: Vector2i, landmark_rng: RandomNumberGenerator) -> void:
	var textures: Array = _get_lush_landmark_textures()
	if decor_root == null or textures.is_empty():
		return
	var sprite := Sprite2D.new()
	sprite.name = "GeneratedLushLandmark"
	sprite.texture = textures[landmark_rng.randi_range(0, textures.size() - 1)] as Texture2D
	sprite.flip_h = landmark_rng.randf() < 0.5
	sprite.scale = Vector2.ONE * landmark_rng.randf_range(1.18, 1.42)
	sprite.position = _ground_flora_position(sprite.texture, cell, sprite.scale)
	sprite.z_index = 6 if landmark_rng.randf() < 0.35 else 0
	sprite.modulate = Color(0.92 + landmark_rng.randf() * 0.08, 0.92 + landmark_rng.randf() * 0.08, 1.0, 1.0)
	if landmark_rng.randf() < 0.82:
		_add_lush_plant_glow(sprite, landmark_rng, 0.22, 0.34)
	decor_root.add_child(sprite)


func _add_lush_plant_glow(sprite: Sprite2D, glow_rng: RandomNumberGenerator, min_energy: float, max_energy: float) -> void:
	# Keep the soft bioluminescent tint in the sprite itself. Hundreds of tiny
	# PointLight2D nodes add little to this dark palette but scale poorly with a
	# dense procedural cave, especially on high-refresh displays.
	sprite.self_modulate = Color(0.92, glow_rng.randf_range(1.02, 1.12), glow_rng.randf_range(0.84, 0.96), 1.0)
	if not GENERATED_PLANT_LIGHTS_ENABLED:
		return
	var glow_texture := load(PLANT_GLOW_TEXTURE_PATH) as Texture2D
	if glow_texture == null:
		return
	var glow := PointLight2D.new()
	glow.name = "LushPlantGlow"
	glow.texture = glow_texture
	glow.position = Vector2(0.0, -8.0)
	glow.texture_scale = glow_rng.randf_range(0.30, 0.42)
	glow.energy = glow_rng.randf_range(min_energy * 0.52, max_energy * 0.52)
	glow.color = Color(0.56 + glow_rng.randf() * 0.16, 1.0, 0.48 + glow_rng.randf() * 0.16, 1.0)
	glow.shadow_enabled = false
	sprite.add_child(glow)


func _spawn_lush_glimmer(world_position: Vector2, glimmer_rng: RandomNumberGenerator, z_order: int) -> void:
	if decor_root == null:
		return
	var texture := load(PLANT_GLOW_TEXTURE_PATH) as Texture2D
	if texture == null:
		return
	var glimmer := Sprite2D.new()
	glimmer.name = "LushGlimmer"
	glimmer.texture = texture
	glimmer.global_position = world_position + Vector2(glimmer_rng.randf_range(-8.0, 8.0), glimmer_rng.randf_range(-5.0, 5.0))
	# Slight HDR modulation intentionally crosses the Environment glow threshold.
	# This yields a gentle bloom halo without creating a real light source.
	glimmer.scale = Vector2.ONE * glimmer_rng.randf_range(0.035, 0.060)
	glimmer.modulate = Color(0.46, 1.0, 0.42, glimmer_rng.randf_range(0.45, 0.72))
	glimmer.self_modulate = Color(1.25, 1.65, 1.10, 1.0)
	glimmer.light_mask = 0
	glimmer.z_index = z_order
	decor_root.add_child(glimmer)


func _is_vine_anchor(grid: Array, grid_x: int, grid_y: int) -> bool:
	return _is_solid(grid, grid_x, grid_y) and not _is_solid(grid, grid_x, grid_y + 1) and not _is_torch_column(grid_x)


func _has_vine_clearance(grid: Array, grid_x: int, anchor_y: int, length: int) -> bool:
	# The visual is roughly one tile wide after scaling. Check its shoulders as
	# well as the stem so a vine cannot be spawned half inside a side wall.
	if grid_x < 3 or grid_x >= level_size_tiles.x - 3:
		return false
	for offset_x: int in range(-1, 2):
		for offset_y: int in range(1, length + 2):
			if _is_solid(grid, grid_x + offset_x, anchor_y + offset_y):
				return false
	return true


func _spawn_vine_trail(grid_x: int, grid_y: int, segment_count: int, rotation: float, light_energy: float) -> void:
	# Anchor exactly below the supporting tile, with a small visual overlap so
	# the first sprig never appears to float away from the cave ceiling.
	var start_position := _grid_to_world(Vector2i(grid_x, grid_y)) + Vector2(16.0, 5.0)
	var horizontal_drift: float = clampf(rotation * 34.0, -18.0, 18.0)
	var foreground_vine: bool = rng.randf() < 0.35
	for segment_index: int in range(segment_count):
		var vine: Node2D = VINE_SCENE.instantiate() as Node2D
		if vine == null:
			continue
		# Generated vines are decorative. They retain their shader movement, but
		# never start one timer/physics-leaf chain per segment.
		vine.set("ambient_leaf_spawning_enabled", false)
		decor_root.add_child(vine)
		# Die vorbereitete Hub-Ranke wird mit deren dichter 22px-Formation
		# gesetzt: überlappende Sprigs, seitlicher Drift und Wellen statt einer
		# klinisch geraden Tile-Spalte.
		var progress: float = float(segment_index) / maxf(1.0, float(segment_count - 1))
		var sway_x: float = sin(float(segment_index) * 1.27 + rotation * 4.0) * 8.0
		var hook_x: float = sin(progress * PI * 1.35 + rotation * 3.0) * 8.0 * progress
		vine.global_position = start_position + Vector2(horizontal_drift * progress + sway_x + hook_x, float(segment_index) * 22.0)
		# Die Hub-Szene haengt dieselbe Ranken-Szene um 180 Grad gedreht an
		# Decken. Das bewahrt ihre vorbereitete Blatt-/Licht-Ausrichtung auch
		# in prozeduralen Hoehlen; nur die kleinen Winkelabweichungen kommen
		# vom Generator.
		vine.rotation = PI + rotation + sin(float(segment_index) * 0.9) * 0.10
		vine.z_index = 6 if foreground_vine else 0
		vine.modulate = Color(0.5, 0.9, 0.46, 1.0)
		if segment_index % 3 == 0:
			vine.self_modulate = Color(0.72, 1.04, 0.68, 1.0)
		var vine_light: PointLight2D = vine.get_node_or_null("PointLight2D") as PointLight2D
		if vine_light != null:
			# A dense cluster can contain hundreds of segments. Their separate
			# shadow-casting lights were invisible at normal camera distance while
			# dominating the 2D light pass.
			vine_light.visible = false
			vine_light.shadow_enabled = false
	# A few large hanging clusters carry small magical specks.  They are unlit
	# sprites (not PointLight2D nodes), so they receive the project bloom without
	# adding hundreds of dynamic lighting passes.
	if segment_count >= 6 and rng.randf() < 0.62:
		var glimmer_count: int = rng.randi_range(2, 4)
		for glimmer_index: int in range(glimmer_count):
			var progress: float = float(glimmer_index + 1) / float(glimmer_count + 1)
			var glimmer_y: float = progress * float(segment_count - 1) * 22.0
			var glimmer_x: float = horizontal_drift * progress + sin(progress * 8.0 + rotation) * 10.0
			_spawn_lush_glimmer(start_position + Vector2(glimmer_x, glimmer_y), rng, 6 if foreground_vine else 0)


func _is_torch_column(grid_x: int) -> bool:
	for torch_variant: Variant in active_level.get("torches", []) as Array:
		if abs(grid_x - int((torch_variant as Dictionary).get("x", -999))) <= 3:
			return true
	return false


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
	var anchor := _resolve_torch_anchor(Vector2i(int(torch_data.get("x", 0)), int(torch_data.get("y", 0))))
	if anchor == Vector2i.ZERO:
		return
	var torch: Node2D = TORCH_SCENE.instantiate() as Node2D
	if torch == null:
		return

	torch.visible = true
	var torch_position: Vector2 = _grid_to_world(anchor + Vector2i(0, 1)) + Vector2(16.0, 8.0)
	torch.global_position = torch_position
	decor_root.add_child(torch)

	var brightness: float = float(torch_data.get("brightness", 1.0))
	var light_node: PointLight2D = torch.get_node_or_null("Light") as PointLight2D
	if light_node != null:
		light_node.energy *= brightness * 0.92
		# Torch light remains for navigation, but dynamic shadows from every torch
		# are not distinguishable in the cave and are substantially more expensive.
		light_node.shadow_enabled = false


func _resolve_torch_anchor(requested: Vector2i) -> Vector2i:
	var x_offsets := [0, -1, 1, -2, 2]
	var y_offsets := [0, -1, 1, -2, 2, -3, 3, -4, 4]
	for y_offset: int in y_offsets:
		for x_offset: int in x_offsets:
			var candidate := requested + Vector2i(x_offset, y_offset)
			if _is_solid(solid_grid_cache, candidate.x, candidate.y) and not _is_solid(solid_grid_cache, candidate.x, candidate.y + 1):
				return candidate
	return Vector2i.ZERO


func _spawn_crystal(_crystal_data: Dictionary) -> void:
	return


func _spawn_pickup(pickup_data: Dictionary) -> void:
	var pickup: Area2D = ESSENCE_FRAGMENT_SCENE.instantiate() as Area2D
	if pickup == null:
		return

	pickup_root.add_child(pickup)
	pickup.global_position = _grid_to_world(Vector2i(int(pickup_data.get("x", 0)), int(pickup_data.get("y", 0)))) + Vector2(16.0, -6.0)
	pickup.set("toast_text", str(pickup_data.get("message", "Essenzsplitter geborgen.")))
	pickup.call("configure_loot_tier", str(pickup_data.get("loot_tier", "copper")))


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
	enemy.set_meta("chapter_enemy_type", enemy_type)
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
	# Die komplette Logik-Karte ist von Fels umschlossen. Sie als Kameraquelle zu
	# verwenden, zeigt deshalb bei schmalen Hoehlen grosse, leere Randflaechen.
	# Die Generator-Raeume und ihre Plattformen beschreiben dagegen genau den
	# bespielbaren Korridor und bleiben auch bei ungewoehnlich tiefen Seeds stabil.
	var authored_bounds: Rect2 = _generated_play_bounds_rect()
	if authored_bounds.size != Vector2.ZERO:
		authored_bounds = _expand_rect_to_include_point(authored_bounds, _grid_to_world(active_level.get("spawn", Vector2i(4, 28)) as Vector2i) + Vector2(16.0, -48.0), Vector2(128.0, 160.0))
		var authored_exit_tile: Vector2i = resolved_exit_tile if resolved_exit_tile != Vector2i.ZERO else active_level.get("exit", Vector2i(96, 24)) as Vector2i
		authored_bounds = _expand_rect_to_include_point(authored_bounds, _grid_to_world(authored_exit_tile) + Vector2(18.0, -18.0), EXIT_VIEW_MARGIN)
		if exit_gate != null:
			authored_bounds = _expand_rect_to_include_point(authored_bounds, exit_gate.global_position + Vector2(0.0, -42.0), EXIT_VIEW_MARGIN)
		return _clamp_rect_to_envelope(authored_bounds, _camera_envelope_rect())

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


func _generated_play_bounds_rect() -> Rect2:
	var bounds := Rect2()
	var has_geometry: bool = false
	for room_variant: Variant in active_level.get("debug_rooms", []) as Array:
		var room: Dictionary = room_variant as Dictionary
		var room_rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
		if room_rect.size.x <= 0 or room_rect.size.y <= 0:
			continue
		var world_rect := Rect2(
			_grid_to_world(room_rect.position),
			Vector2(room_rect.size) * TILE_SIZE
		)
		bounds = world_rect if not has_geometry else bounds.merge(world_rect)
		has_geometry = true

	for platform_variant: Variant in active_level.get("platforms", []) as Array:
		var platform: Dictionary = platform_variant as Dictionary
		var width: int = int(platform.get("w", 0))
		var height: int = int(platform.get("h", 1))
		if width <= 0 or height <= 0:
			continue
		var world_rect := Rect2(
			_grid_to_world(Vector2i(int(platform.get("x", 0)), int(platform.get("y", 0)) - 4)),
			Vector2(width, height + 5) * TILE_SIZE
		)
		bounds = world_rect if not has_geometry else bounds.merge(world_rect)
		has_geometry = true

	return bounds.grow(TILE_SIZE * 2.0) if has_geometry else Rect2()


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
		return fallback_tile + Vector2i.UP

	# Layout anchors are floor cells. The previous search treated the authored
	# floor coordinate as an air cell and could fall back to a solid tile in a
	# dense network. Resolve a broad, three-tile-clear landing first.
	var roots: Array[Vector2i] = [fallback_tile]
	var critical_path: Array = active_level.get("critical_path_nodes", []) as Array
	if not critical_path.is_empty():
		var route_start: Vector2i = critical_path.front() as Vector2i
		if route_start != fallback_tile:
			roots.append(route_start)
	var y_offsets: Array[int] = [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7, 8]
	var x_offsets: Array[int] = [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5]
	for root: Vector2i in roots:
		for y_offset: int in y_offsets:
			var floor_y: int = clampi(root.y + y_offset, 4, level_size_tiles.y - 3)
			for x_offset: int in x_offsets:
				var grid_x: int = clampi(root.x + x_offset, 3, level_size_tiles.x - 4)
				if _is_valid_spawn_floor(grid_x, floor_y):
					return Vector2i(grid_x, floor_y - 1)

	# This fallback is still an air coordinate, never the solid authored floor.
	return Vector2i(clampi(fallback_tile.x, 2, level_size_tiles.x - 3), clampi(fallback_tile.y - 1, 2, level_size_tiles.y - 3))


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


func _is_valid_spawn_floor(grid_x: int, floor_y: int) -> bool:
	if not _is_solid(solid_grid_cache, grid_x, floor_y):
		return false
	var supporting_cells := 0
	for offset_x: int in range(-1, 2):
		if _is_solid(solid_grid_cache, grid_x + offset_x, floor_y):
			supporting_cells += 1
		for offset_y: int in range(1, 4):
			if _is_solid(solid_grid_cache, grid_x + offset_x, floor_y - offset_y):
				return false
	return supporting_cells >= 2


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
