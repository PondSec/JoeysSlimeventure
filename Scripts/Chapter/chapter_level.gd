extends Node2D

const TILE_SIZE := 32.0
const FEEDBACK_FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const ChapterContent := preload("res://Scripts/Chapter/chapter_content.gd")
const ChapterLayoutBuilder := preload("res://Scripts/Chapter/chapter_layout_builder.gd")
const TerrainResolver := preload("res://Scripts/Chapter/terrain_resolver.gd")
const TileClassifier := preload("res://Scripts/Chapter/tile_classifier.gd")
const ChapterQuestRuntime := preload("res://Scripts/Chapter/chapter_quest_runtime.gd")
const ItemRegistry := preload("res://Scripts/item_registry.gd")

const HUB_SCENE := preload("res://Scenes/Game.tscn")
const PLAYER_SCENE := preload("res://Scenes/player.tscn")
const PAUSE_MENU_SCENE := preload("res://Scenes/PauseMenu.tscn")
const CHAPTER_GATE_SCENE := preload("res://Scenes/Chapter/chapter_gate.tscn")
const CAVE_SLIME_SCENE := preload("res://Scenes/Chapter/Enemies/cave_slime.tscn")
const CAVE_BAT_SCENE := preload("res://Scenes/Chapter/Enemies/cave_bat.tscn")
const GLOWCAP_SCENE := preload("res://Scenes/Chapter/Enemies/glowcap.tscn")
const IRRLICHTKAEFER_SCENE := preload("res://Scenes/Chapter/Enemies/irrlichtkaefer.tscn")
const GLUTKAEFER_SCENE := preload("res://Scenes/Chapter/Enemies/glutkaefer.tscn")
const GLUEHWUERMCHEN_SCENE := preload("res://Scenes/Chapter/Creatures/gluehwuermchen.tscn")
const GLUT_DIMENSION_DOOR_SCENE := preload("res://Scenes/Chapter/glut_dimension_door.tscn")
const ENEMY_AWARENESS_INDICATOR := preload("res://Scripts/Chapter/Enemies/enemy_awareness_indicator.gd")
const KRISTALLRUECKEN_SCENE := preload("res://Scenes/Chapter/Enemies/kristallruecken.tscn")
const MAGIC_ENERGY_TRAIL := preload("res://Scripts/Chapter/Boss/magic_energy_trail.gd")
const ESSENCE_FRAGMENT_SCENE := preload("res://Scenes/Chapter/Pickups/essence_fragment.tscn")
const TORCH_SCENE := preload("res://Scenes/torch.tscn")
const SPIKE_SCENE := preload("res://Scenes/Spike.tscn")
const WORM_SCENE := preload("res://Scenes/worm.tscn")
const VINE_SCENE := preload("res://Scenes/vine.tscn")
const FALLING_LEAF_SCENE := preload("res://Scenes/Deko/leaf.tscn")
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
const LUSH_SUNBUD_PATH := "res://Assets/Deko/lush/lush_sunbud.png"
const LUSH_MOONBELL_PATH := "res://Assets/Deko/lush/lush_moonbell.png"
const LUSH_OASIS_LIGHT_TEXTURE_PATH := "res://Assets/Light/light_white.png"
const VEGETATION_WIND_SHADER_PATH := "res://Shaders/vegetation_wind.gdshader"
const PLAYER_WORLD_COLLISION_LAYER := 2
const DEFAULT_CAVE_TILE_SOURCE_ID := 0
const CAVE_TILE_SIZE := Vector2i(32, 32)
const CAVE_TEXTURE_PATH := "res://Assets/Tiles/platformertiles.png"
const DEBUG_OVERLAY_TOGGLE_KEY := KEY_F2
const TILE_DEBUG_TOGGLE_KEY := KEY_F3
const GENERATED_PLANT_LIGHTS_ENABLED := true
const MAX_GENERATED_PLANT_LIGHTS := 8
const MAX_AMBIENT_LUSH_LEAVES := 12
const AMBIENT_LUSH_LEAF_MIN_INTERVAL := 1.25
const AMBIENT_LUSH_LEAF_MAX_INTERVAL := 3.4
const AMBIENT_LUSH_LEAF_MAX_SOURCE_DISTANCE := 720.0
const LUSH_MOONBELL_HEAL_RADIUS := 42.0
const LUSH_MOONBELL_HEAL_INTERVAL := 1.0
const ENEMY_RESPAWN_DELAY_MIN := 6.0
const ENEMY_RESPAWN_DELAY_MAX := 10.0
const ENEMY_RESPAWN_MIN_PLAYER_DISTANCE := 520.0

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
const LANDMARK_DEPTH_SHADER_PATH := "res://Shaders/landmark_depth.gdshader"
const CHAPTER_LUSH_LANDMARK_PATHS := [
	"res://Assets/Deko/landmarks/lush/lush_landmark_00.png",
	"res://Assets/Deko/landmarks/lush/lush_landmark_01.png",
	"res://Assets/Deko/landmarks/lush/lush_landmark_02.png",
	"res://Assets/Deko/landmarks/lush/lush_landmark_03.png",
	"res://Assets/Deko/landmarks/lush/lush_landmark_04.png",
	"res://Assets/Deko/landmarks/lush/lush_landmark_05.png",
	"res://Assets/Deko/landmarks/lush/lush_landmark_06.png",
	"res://Assets/Deko/landmarks/lush/lush_landmark_07.png",
]
const CHAPTER_CAVE_LANDMARK_PATHS := [
	"res://Assets/Deko/landmarks/cave/cave_landmark_00.png",
	"res://Assets/Deko/landmarks/cave/cave_landmark_01.png",
	"res://Assets/Deko/landmarks/cave/cave_landmark_02.png",
	"res://Assets/Deko/landmarks/cave/cave_landmark_03.png",
	"res://Assets/Deko/landmarks/cave/cave_landmark_04.png",
	"res://Assets/Deko/landmarks/cave/cave_landmark_05.png",
	"res://Assets/Deko/landmarks/cave/cave_landmark_06.png",
	"res://Assets/Deko/landmarks/cave/cave_landmark_07.png",
]
# A shuffled chapter deck, rather than level 1 -> landmark 1.  Each entry is
# used once across the eight Chapter-1 levels, and cave/lush do not mirror one
# another inside a level.
const CHAPTER_LUSH_LANDMARK_ORDER := [5, 2, 7, 0, 6, 3, 1, 4]
const CHAPTER_CAVE_LANDMARK_ORDER := [1, 6, 3, 7, 0, 4, 2, 5]
const NORMAL_CAVE_FOREGROUND_FRAME_PATH := "res://Assets/Parallax Cave/normal_cave_foreground_frame.png"
const NORMAL_CAVE_FOREGROUND_SHADER_PATH := "res://Shaders/normal_cave_foreground_transition.gdshader"
const LUSH_BIOME_TRANSITION_DISTANCE := 460.0
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
var boss_portal_source := Vector2.ZERO
var boss_energy_trail: Node2D
var backdrop_root: Node2D
var landmark_backdrop_root: Node2D
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
var quest_runtime: ChapterQuestRuntime
var parallax_background: ParallaxBackground
var parallax_base_fill: Polygon2D
var parallax_layer_entries: Array = []
var parallax_foreground_layer: Node2D
var normal_cave_foreground_root: Node2D
var normal_cave_foreground_material: ShaderMaterial
var lush_biome_backdrop_layer: CanvasLayer
var lush_biome_foreground_layer: CanvasLayer
var lush_biome_sprites: Array[Sprite2D] = []
var lush_biome_regions: Array[Rect2] = []
var lush_biome_density: Array[float] = []
var lush_biome_strength: float = 0.0
var feedback_font: FontFile
var cave_tiles_texture: Texture2D
var cave_tileset: TileSet
var cave_tile_source_id: int = DEFAULT_CAVE_TILE_SOURCE_ID
var solid_grid_cache: Array = []
var flying_path_grid: AStarGrid2D
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
var lush_sunbud_texture: Texture2D
var lush_moonbell_texture: Texture2D
var decoration_alpha_bounds: Dictionary = {}
var vegetation_motion_nodes: Array[CanvasItem] = []
var vegetation_motion_shader: Shader
var generated_plant_light_count: int = 0
var ceiling_leaf_sources: Array[Dictionary] = []
var ambient_lush_leaf_count: int = 0
var ambient_lush_leaf_timer: float = 0.0
var ambient_lush_leaf_rng := RandomNumberGenerator.new()
var lush_moonbell_sources: Array[WeakRef] = []
var lush_moonbell_heal_timer: float = 0.0
var enemy_population_target: int = 0
var enemy_respawn_types: Array[String] = []
var enemy_respawn_timer: float = -1.0

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
	_spawn_lush_irrlichtkaefer()
	_spawn_lush_gluehwuermchen()
	_configure_runtime_view()
	await get_tree().process_frame
	_position_player_at_spawn()
	# This scene is only entered after ChapterProgress has selected a playable
	# chapter level. Chapter I / Level 1 is the first real cave entry, not a menu
	# or biome preview, so it is the authoritative Into the Depths trigger.
	if int(active_level.get("chapter_index", 0)) == 1 and int(active_level.get("level_index", -1)) == 0:
		SteamManager.unlock("ACH_INTO_THE_DEPTHS")
	_grant_level_one_mobility()
	_show_level_intro()


func _process(delta: float) -> void:
	if player == null:
		return
	_update_enemy_population(delta)
	_update_vegetation_motion(delta)
	_update_ambient_lush_leaves(delta)
	_update_lush_moonbell_healing(delta)
	# The ordinary foreground is always present, independent of whether this
	# seed contains a lush biome.  Keeping it moving here also gives the normal
	# cave the same depth response as the lush frame.
	if normal_cave_foreground_root != null:
		_update_overlay_parallax(normal_cave_foreground_root, player.global_position)
	# UI skins deliberately share the same eased strength as the parallax,
	# rather than evaluating their own biome boundaries.  This keeps every
	# visual transition perfectly synchronized and lets future biome UIs join
	# through the biome_aware_ui group.
	var target_strength := _get_lush_biome_strength(player.global_position) if not lush_biome_sprites.is_empty() else 0.0
	lush_biome_strength = move_toward(lush_biome_strength, target_strength, delta * 0.72)
	get_tree().call_group("biome_aware_ui", "set_biome_weight", "lush", lush_biome_strength)
	if lush_biome_sprites.is_empty():
		if normal_cave_foreground_material != null:
			normal_cave_foreground_material.set_shader_parameter("lush_strength", lush_biome_strength)
		return
	var should_be_visible: bool = lush_biome_strength > 0.003 or target_strength > 0.003
	if lush_biome_backdrop_layer != null:
		lush_biome_backdrop_layer.visible = should_be_visible
	if lush_biome_foreground_layer != null:
		lush_biome_foreground_layer.visible = should_be_visible
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
	var progress := _progress()
	if progress != null and progress.has_method("get_active_level_generation_seed"):
		return int(progress.call("get_active_level_generation_seed"))
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
	_apply_daily_quest_variants(level_copy)

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


func _apply_daily_quest_variants(level_copy: Dictionary) -> void:
	if int(level_copy.get("level_index", -1)) != 1:
		return
	var progress := _progress()
	if progress == null or not progress.has_method("get_active_resonance_sequence"):
		return
	var quest: Dictionary = level_copy.get("quest", {}) as Dictionary
	var objectives: Array = quest.get("objectives", []) as Array
	for objective_variant: Variant in objectives:
		var objective: Dictionary = objective_variant as Dictionary
		if str(objective.get("type", "")) == "sequence":
			objective["sequence"] = progress.call("get_active_resonance_sequence") as Array
	quest["objectives"] = objectives
	level_copy["quest"] = quest


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

	# Landmark art is its own world-space depth layer. It is deliberately not a
	# child of BackdropRoot because that root is rebuilt when the play bounds are
	# recalculated.
	landmark_backdrop_root = Node2D.new()
	landmark_backdrop_root.name = "LandmarkBackdrop"
	landmark_backdrop_root.z_as_relative = false
	# Share the normal world depth: sibling ordering draws this root after the
	# ParallaxBackground but before Level/Terrain, so the landmark is visible
	# through an alcove while terrain and Joey still cover its embedded base.
	landmark_backdrop_root.z_index = 0
	add_child(landmark_backdrop_root)
	move_child(landmark_backdrop_root, 1)

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
	ui_layer.layer = 10
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


func _spawn_chapter_landmarks(grid: Array) -> void:
	# Chapter 1 has eight authored variants of each biome. Indexing directly by
	# level deliberately avoids reuse: a landmark can become a memory of that
	# one level instead of a repeated procedural prop.
	if landmark_backdrop_root == null or int(active_level.get("chapter_index", 0)) != 1:
		return
	var level_index: int = int(active_level.get("level_index", -1))
	if level_index < 0 or level_index >= CHAPTER_LUSH_LANDMARK_ORDER.size() or level_index >= CHAPTER_CAVE_LANDMARK_ORDER.size():
		return
	var lush_asset_index: int = CHAPTER_LUSH_LANDMARK_ORDER[level_index]
	var cave_asset_index: int = CHAPTER_CAVE_LANDMARK_ORDER[level_index]

	var landmark_rng := RandomNumberGenerator.new()
	landmark_rng.seed = active_level_seed * 4729 + 131
	_spawn_chapter_landmark(
		load(CHAPTER_CAVE_LANDMARK_PATHS[cave_asset_index]) as Texture2D,
		grid,
		false,
		level_index,
		landmark_rng
	)
	_spawn_chapter_landmark(
		load(CHAPTER_LUSH_LANDMARK_PATHS[lush_asset_index]) as Texture2D,
		grid,
		true,
		level_index,
		landmark_rng
	)


func _spawn_chapter_landmark(texture: Texture2D, grid: Array, prefer_lush: bool, level_index: int, landmark_rng: RandomNumberGenerator) -> void:
	if texture == null:
		return
	var anchor: Vector2i = _find_chapter_landmark_anchor(grid, prefer_lush, landmark_rng)
	if anchor.x < 0:
		return
	var sprite := Sprite2D.new()
	sprite.name = "%sLandmark_L%d" % ["Lush" if prefer_lush else "Cave", level_index + 1]
	sprite.texture = texture
	# These are background landmarks, not set pieces the player can collide with.
	# Full content-aware crops are larger than the old, accidentally quartered
	# source textures, so the authored silhouettes stay restrained at this scale.
	# Landmarks should read as a small set-piece behind Joey, not a decorative icon.
	# Keep them visibly present without competing with terrain or foreground props.
	var scale_amount: float = 0.24 if prefer_lush else 0.17
	sprite.scale = Vector2.ONE * scale_amount
	sprite.position = _ground_flora_position(texture, anchor, sprite.scale)
	sprite.light_mask = 0
	sprite.modulate = Color(0.94, 0.98, 0.95, 1.0) if prefer_lush else Color(0.94, 0.90, 0.85, 1.0)
	var shader := load(LANDMARK_DEPTH_SHADER_PATH) as Shader
	if shader != null:
		var material := ShaderMaterial.new()
		material.shader = shader
		# Subtler than the mid parallax: recognisable environment landmarks,
		# never a sharp foreground object competing with Joey.
		material.set_shader_parameter("softness", 0.18)
		material.set_shader_parameter("blur_radius", 0.55)
		material.set_shader_parameter("opacity", 1.0)
		sprite.material = material
	landmark_backdrop_root.add_child(sprite)


func _find_chapter_landmark_anchor(grid: Array, prefer_lush: bool, landmark_rng: RandomNumberGenerator) -> Vector2i:
	var strict_candidates: Array[Vector2i] = []
	var fallback_candidates: Array[Vector2i] = []
	var spawn: Vector2i = active_level.get("spawn", Vector2i.ZERO) as Vector2i
	var exit: Vector2i = active_level.get("exit", Vector2i(level_size_tiles.x - 2, level_size_tiles.y - 2)) as Vector2i
	for grid_y: int in range(6, level_size_tiles.y - 2):
		for grid_x: int in range(3, level_size_tiles.x - 3):
			var floor_cell := Vector2i(grid_x, grid_y)
			if _is_torch_column(grid_x) or not _is_exposed_moss_face(grid, floor_cell, Vector2i.UP) or not _has_ground_moss_shoulders(grid, floor_cell):
				continue
			if floor_cell.distance_to(spawn) < 9.0 or floor_cell.distance_to(exit) < 7.0:
				continue
			if not _has_landmark_clearance(grid, floor_cell):
				continue
			var density: float = lush_biome_density[grid_x] if grid_x < lush_biome_density.size() else 0.0
			var matches_biome: bool = density >= MIN_LUSH_BIOME_DENSITY if prefer_lush else density < 2.2
			var usable_fallback: bool = density >= 2.2 if prefer_lush else density < MIN_LUSH_BIOME_DENSITY
			if matches_biome:
				strict_candidates.append(floor_cell)
			elif usable_fallback:
				fallback_candidates.append(floor_cell)
	var candidates: Array[Vector2i] = strict_candidates if not strict_candidates.is_empty() else fallback_candidates
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[landmark_rng.randi_range(0, candidates.size() - 1)]


func _has_landmark_clearance(grid: Array, floor_cell: Vector2i) -> bool:
	# Require a real open alcove above a three-tile floor. This prevents the art
	# from reading as a sticker inside a wall, while terrain remains in front of
	# it for a naturally embedded base.
	for offset_x: int in range(-1, 2):
		for offset_y: int in range(1, 6):
			if _is_solid(grid, floor_cell.x + offset_x, floor_cell.y - offset_y):
				return false
	return true


func _build_lush_biome_parallax(bounds: Rect2) -> void:
	if lush_biome_backdrop_layer != null:
		lush_biome_backdrop_layer.queue_free()
	if lush_biome_foreground_layer != null:
		lush_biome_foreground_layer.queue_free()
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

	# A lush biome is a real explorable territory rather than a narrow backdrop
	# strip. It still leaves normal stone cave on both sides, but has enough
	# width for continuous moss, large plants and a distinct route identity.
	var core_width: float = clampf(bounds.size.x * 0.28, 720.0, 1180.0)
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
	lush_biome_foreground_layer = CanvasLayer.new()
	lush_biome_foreground_layer.name = "LushBiomeForeground"
	# The close foliage covers Joey and terrain, but remains beneath the HUD.
	lush_biome_foreground_layer.layer = 5
	lush_biome_foreground_layer.visible = false
	add_child(lush_biome_foreground_layer)

	# Back to front: increasingly stronger motion.  Each source is scaled from
	# the actual viewport plus a safe overscan margin, never to a fraction of the
	# viewport.  This keeps all four borders fully attached to the screen while
	# retaining parallax movement.
	# Preserve the complete frame with a smaller, resolution-independent margin.
	# The previous margins made the art read noticeably zoomed-in.
	var deep_sprite := _create_lush_biome_sprite(deep_texture, shader, 0, 28.0, Vector2(-0.009, -0.004))
	# The distant cave is visibly defocused, while remaining readable as the
	# farthest depth plane behind the gameplay silhouette.
	var deep_material := deep_sprite.material as ShaderMaterial
	if deep_material != null:
		deep_material.set_shader_parameter("depth_blur", 0.58)
		deep_material.set_shader_parameter("blur_radius", 1.45)
	var mid_sprite := _create_lush_biome_sprite(mid_texture, shader, 1, 76.0, Vector2(-0.030, -0.012))
	# The middle depth is intentionally more defocused than the landmark layer;
	# it keeps the camera focus on Joey and the playable foreground.
	var mid_material := mid_sprite.material as ShaderMaterial
	if mid_material != null:
		mid_material.set_shader_parameter("depth_blur", 0.46)
		mid_material.set_shader_parameter("blur_radius", 1.22)
	# The close frame follows the same smooth screen-space parallax model as the
	# deep and mid art, only with a stronger offset.  It is intentionally still
	# subtle enough that its corners remain attached to the view during jumps.
	var foreground_sprite := _create_lush_biome_sprite(foreground_texture, shader, 0, 120.0, Vector2(-0.062, -0.020))
	var foreground_material := foreground_sprite.material as ShaderMaterial
	if foreground_material != null:
		foreground_material.set_shader_parameter("alpha_gain", 1.22)
		foreground_material.set_shader_parameter("edge_feather", 0.06)
	foreground_sprite.visible = false
	lush_biome_backdrop_layer.add_child(deep_sprite)
	lush_biome_backdrop_layer.add_child(mid_sprite)
	lush_biome_foreground_layer.add_child(foreground_sprite)
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
	var default_screen_limit := Vector2(108.0, 38.0) if world_space else Vector2(96.0, 34.0)
	var screen_limit: Vector2 = sprite.get_meta("parallax_screen_limit", default_screen_limit) as Vector2
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
	# Falling is fatal only beyond the physical bottom of this generated world.
	# The old global Y=2000 threshold cut off valid deep rooms in larger levels.
	if player.has_method("set_world_fall_death_y"):
		player.call("set_world_fall_death_y", level_size_pixels.y + WORLD_BOUND_BOTTOM_PADDING)
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
	vegetation_motion_nodes.clear()
	generated_plant_light_count = 0
	ceiling_leaf_sources.clear()
	ambient_lush_leaf_count = 0
	ambient_lush_leaf_rng.seed = active_level_seed * 193 + 6221
	ambient_lush_leaf_timer = ambient_lush_leaf_rng.randf_range(AMBIENT_LUSH_LEAF_MIN_INTERVAL, AMBIENT_LUSH_LEAF_MAX_INTERVAL)
	lush_moonbell_sources.clear()
	lush_moonbell_heal_timer = 0.0
	lush_biome_density.clear()
	lush_biome_density.resize(level_size_tiles.x)
	for density_index: int in range(lush_biome_density.size()):
		lush_biome_density[density_index] = 0.0
	solid_grid_cache = active_level.get("grid", []) as Array
	if solid_grid_cache.is_empty():
		solid_grid_cache = _build_cave_solid_grid(platforms)
	logical_terrain_map = TerrainResolver.build_logical_map(solid_grid_cache, level_size_tiles)
	solid_grid_cache = TerrainResolver.duplicate_cells(logical_terrain_map)
	_build_flying_path_grid()
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
	_spawn_lush_special_blooms(solid_grid_cache)
	_spawn_lush_light_oases(solid_grid_cache)
	_register_lush_biome_decor_density()
	_spawn_chapter_landmarks(solid_grid_cache)

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

	_spawn_glut_dimension_door_if_needed()
	_spawn_missing_glut_guardian_rewards_if_needed()

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
	_spawn_quest_runtime()
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
		if enemy_type == "bat" or enemy_type == "irrlichtkaefer" or enemy_type == "glutkaefer":
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
	# Quest anchors are only visible in the existing F2 debug overlay. They make
	# seed placement reviewable without turning the shipping game into a marker
	# hunt.
	for anchor_variant: Variant in active_level.get("quest_anchors", []) as Array:
		var anchor: Dictionary = anchor_variant as Dictionary
		_spawn_debug_dot(overlay_root, anchor.get("position", Vector2i.ZERO) as Vector2i, Color(1.0, 0.34, 0.92, 0.96), 9.0)

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
		"Questziele: %d, unerreichbar: %d, Reihenfolge: %s" % [(active_level.get("quest_anchors", []) as Array).size(), int(validation.get("unreachable_quest_target_count", 0)), "OK" if bool(validation.get("quest_sequence_valid", true)) else "CHECK"],
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
	# 32px variants. The source art is a floor strip, so it is deliberately
	# never rotated onto ceilings, walls, or their corner transitions.
	var moss_rng := RandomNumberGenerator.new()
	moss_rng.seed = active_level_seed * 173 + 401
	var claimed: Dictionary = {}
	var spawned: int = 0
	var patch_types: Array = [
		{"outward": Vector2i.UP, "tangent": Vector2i.RIGHT, "rotation": 0.0, "flip_v": false, "chance": 0.58, "budget": 420}
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
	var outward: Vector2i = patch.get("outward", Vector2i.UP) as Vector2i
	# Guard this at the low-level spawn point as well as in the callers: these
	# assets are authored only for an upward-facing floor lip. Decken, walls and
	# corners must use their dedicated hanging-canopy/vine decoration instead.
	if outward != Vector2i.UP:
		return
	var moss := Sprite2D.new()
	moss.name = "GeneratedMoss"
	var texture_index := moss_rng.randi_range(0, textures.size() - 1)
	var moss_texture := textures[clampi(texture_index, 0, textures.size() - 1)] as Texture2D
	moss.texture = moss_texture
	var moss_scale: float = float(patch.get("scale", 1.0))
	moss.scale = Vector2.ONE * moss_scale
	# Align the first opaque row to the top of its supporting floor cell.  The
	# asset remains unrotated because it is an authored horizontal moss strip.
	moss.position = _surface_moss_position(moss_texture, cell, moss.scale, float(cell.y) * TILE_SIZE - 6.0)
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


func _get_vegetation_motion_shader() -> Shader:
	if vegetation_motion_shader == null:
		vegetation_motion_shader = load(VEGETATION_WIND_SHADER_PATH) as Shader
	return vegetation_motion_shader


func _register_vegetation_motion(plant: CanvasItem, texture: Texture2D, motion_rng: RandomNumberGenerator, root_at_bottom: bool) -> void:
	# Every procedural plant receives a private material: this is what lets the
	# wind ripple through a group instead of animating all sprites identically.
	if plant == null or texture == null:
		return
	var shader := _get_vegetation_motion_shader()
	if shader == null:
		return
	var alpha_bounds := _get_decoration_alpha_bounds(texture)
	var texture_height: float = maxf(1.0, float(texture.get_height()))
	var root_y: float = float(alpha_bounds.end.y) / texture_height if root_at_bottom else float(alpha_bounds.position.y) / texture_height
	var displayed_scale: float = maxf(0.02, absf(plant.scale.x))
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("wind_phase", motion_rng.randf_range(0.0, TAU))
	material.set_shader_parameter("wind_world_x", plant.global_position.x)
	material.set_shader_parameter("sway_pixels", clampf(motion_rng.randf_range(1.35, 2.65) / displayed_scale, 2.0, 72.0))
	material.set_shader_parameter("press_pixels", clampf(motion_rng.randf_range(5.5, 8.5) / displayed_scale, 4.0, 110.0))
	material.set_shader_parameter("root_uv_y", clampf(root_y, 0.001, 0.999))
	material.set_shader_parameter("root_at_bottom", 1.0 if root_at_bottom else 0.0)
	material.set_shader_parameter("interaction_strength", 0.0)
	material.set_shader_parameter("interaction_direction", 1.0)
	material.set_shader_parameter("tint_variation", motion_rng.randf_range(-0.025, 0.025))
	plant.material = material
	plant.set_meta("vegetation_interaction", 0.0)
	plant.set_meta("vegetation_direction", 1.0)
	plant.set_meta("vegetation_interaction_enabled", true)
	plant.set_meta("vegetation_interaction_radius", clampf(maxf(42.0, float(texture.get_width()) * displayed_scale * 0.48), 42.0, 112.0))
	vegetation_motion_nodes.append(plant)


func _update_vegetation_motion(delta: float) -> void:
	# A plant reacts individually only inside the nearby simulation range. The
	# shader continues its cheap GPU-only idle wind everywhere else.
	for node_index: int in range(vegetation_motion_nodes.size() - 1, -1, -1):
		var plant: CanvasItem = vegetation_motion_nodes[node_index]
		if not is_instance_valid(plant):
			vegetation_motion_nodes.remove_at(node_index)
			continue
		if plant.global_position.distance_to(player.global_position) > 760.0:
			continue
		var material := plant.material as ShaderMaterial
		if material == null:
			continue
		if not bool(plant.get_meta("vegetation_interaction_enabled", true)):
			# Long hanging trails are allowed to keep their independent, rope-like
			# wind movement, but the player must not yank every segment sideways.
			material.set_shader_parameter("interaction_strength", 0.0)
			continue
		var radius: float = float(plant.get_meta("vegetation_interaction_radius", 48.0))
		var offset: Vector2 = player.global_position - plant.global_position
		var horizontal_contact: float = 1.0 - smoothstep(radius * 0.28, radius, absf(offset.x))
		var vertical_contact: float = 1.0 - smoothstep(radius * 0.45, radius * 1.28, absf(offset.y))
		var target_strength: float = clampf(horizontal_contact * vertical_contact, 0.0, 1.0)
		var current_strength: float = float(plant.get_meta("vegetation_interaction", 0.0))
		# The push is quick, recovery is slow and springy-looking without needing
		# a physics body on every decorative leaf.
		var response_rate: float = 15.0 if target_strength > current_strength else 4.8
		current_strength = lerpf(current_strength, target_strength, 1.0 - exp(-response_rate * delta))
		var current_direction: float = float(plant.get_meta("vegetation_direction", 1.0))
		if target_strength > 0.02:
			var target_direction: float = signf(plant.global_position.x - player.global_position.x)
			if is_zero_approx(target_direction):
				target_direction = signf(player.velocity.x)
			if is_zero_approx(target_direction):
				target_direction = current_direction
			current_direction = lerpf(current_direction, target_direction, 1.0 - exp(-10.0 * delta))
		plant.set_meta("vegetation_interaction", current_strength)
		plant.set_meta("vegetation_direction", current_direction)
		material.set_shader_parameter("interaction_strength", current_strength)
		material.set_shader_parameter("interaction_direction", current_direction)


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
			if available < 4 or carpet_rng.randf() > 0.82:
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
		if placed >= 18:
			break
		for grid_x: int in range(2, level_size_tiles.x - 9):
			if placed >= 18:
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
			if available < 4 or canopy_rng.randf() > 0.84:
				continue
			var span: int = mini(available, canopy_rng.randi_range(4, 14))
			_reserve_lush_canopy_zone(reserved, start, span)
			# Ceiling shelves use only the dedicated hanging-canopy artwork. The
			# 32px ground-moss tiles have no ceiling/corner variants and previously
			# produced the misplaced wedge-shaped pieces from the screenshots.
			# Each wide source image covers roughly five tiles at this scale. The
			# four-tile stride intentionally overlaps its transparent edges, so the
			# shelf remains one continuous living canopy.
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
	_register_vegetation_motion(sprite, sprite.texture, canopy_rng, false)
	decor_root.add_child(sprite)
	# Hand-placed vines retain their own leaf emitters. Procedural canopy plants
	# feed one shared ambience system, avoiding a timer/physics chain per plant.
	_register_ceiling_leaf_source(sprite, minf(float(span) * TILE_SIZE * 0.36, 58.0), rendered_height * 0.18)


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
			if not _is_exposed_moss_face(grid, cell, Vector2i.UP) or not _has_ground_moss_shoulders(grid, cell) or _is_torch_column(grid_x) or flora_rng.randf() > 0.68:
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
				if not _is_exposed_moss_face(grid, cell, outward) or _is_torch_column(grid_x) or flora_rng.randf() > 0.25:
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
		# Hang the foliage from the ceiling lip, rather than one tile's visual
		# centre below it. This keeps the attachment readable without clipping.
		sprite.position = _grid_to_world(cell) + Vector2(16.0, 40.0)
	elif outward == Vector2i.RIGHT:
		sprite.position = _grid_to_world(cell) + Vector2(48.0, 16.0)
		sprite.rotation = PI * 0.5
	else:
		sprite.position = _grid_to_world(cell) + Vector2(-16.0, 16.0)
		sprite.rotation = -PI * 0.5
	sprite.flip_h = flora_rng.randf() < 0.38
	if flora_rng.randf() < 0.30:
		_add_lush_plant_glow(sprite, flora_rng, 0.15, 0.25)
	_register_vegetation_motion(sprite, sprite.texture, flora_rng, not hanging)
	decor_root.add_child(sprite)
	if hanging:
		var texture_height := float(sprite.texture.get_height()) * absf(sprite.scale.y)
		_register_ceiling_leaf_source(sprite, maxf(8.0, float(sprite.texture.get_width()) * absf(sprite.scale.x) * 0.24), texture_height * 0.16)


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


func _get_lush_sunbud_texture() -> Texture2D:
	if lush_sunbud_texture == null:
		lush_sunbud_texture = load(LUSH_SUNBUD_PATH) as Texture2D
	return lush_sunbud_texture


func _get_lush_moonbell_texture() -> Texture2D:
	if lush_moonbell_texture == null:
		lush_moonbell_texture = load(LUSH_MOONBELL_PATH) as Texture2D
	return lush_moonbell_texture


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
			# Keep one of the supplied frames as a visual variant. The common shader
			# below supplies the continuous movement, avoiding a choppy four-frame loop.
			var plant := Sprite2D.new()
			plant.name = "GeneratedWindBroadleaf"
			plant.texture = textures[plant_rng.randi_range(0, textures.size() - 1)] as Texture2D
			plant.scale = Vector2.ONE * plant_rng.randf_range(0.030, 0.044)
			plant.position = _ground_flora_position(plant.texture, cell, plant.scale)
			plant.flip_h = plant_rng.randf() < 0.5
			plant.z_index = 6 if plant_rng.randf() < 0.35 else 0
			plant.modulate = Color(0.72, 0.92, 0.78, 1.0)
			_register_vegetation_motion(plant, plant.texture, plant_rng, true)
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
			var flower := Sprite2D.new()
			flower.name = "GeneratedWindGlowFlower"
			flower.texture = textures[flower_rng.randi_range(0, textures.size() - 1)] as Texture2D
			flower.scale = Vector2.ONE * flower_rng.randf_range(0.058, 0.078)
			flower.position = _ground_flora_position(flower.texture, cell, flower.scale)
			flower.flip_h = flower_rng.randf() < 0.5
			flower.z_index = 6 if flower_rng.randf() < 0.35 else 0
			flower.modulate = Color(0.82, 0.98, 0.66, 1.0)
			flower.self_modulate = Color(1.10, 1.04, 0.82, 1.0)
			_register_vegetation_motion(flower, flower.texture, flower_rng, true)
			decor_root.add_child(flower)
			placed += 1


func _spawn_lush_special_blooms(grid: Array) -> void:
	# The supplied warm and cool blooms are deliberately restricted to the
	# strongest lush pockets.  They become recognisable biome accents rather than
	# random decoration distributed through an ordinary cave.
	if decor_root == null:
		return
	var sunbud := _get_lush_sunbud_texture()
	var moonbell := _get_lush_moonbell_texture()
	if sunbud == null or moonbell == null:
		return
	var bloom_rng := RandomNumberGenerator.new()
	bloom_rng.seed = active_level_seed * 1237 + 8453
	var placed: int = 0
	var claimed: Dictionary = {}
	for grid_y: int in range(3, level_size_tiles.y - 3):
		if placed >= 18:
			return
		for grid_x: int in range(4, level_size_tiles.x - 4):
			if placed >= 18:
				return
			if grid_x >= lush_biome_density.size() or lush_biome_density[grid_x] < 1.4:
				continue
			var cell := Vector2i(grid_x, grid_y)
			var key := "%d:%d" % [cell.x, cell.y]
			if claimed.has(key) or _is_torch_column(grid_x) or not _is_exposed_moss_face(grid, cell, Vector2i.UP) or not _has_ground_moss_shoulders(grid, cell):
				continue
			if bloom_rng.randf() > 0.078:
				continue
			# Wide shoulders preserve readable silhouettes and stop special plants
			# from merging into accidental walls of leaves.
			for offset_x: int in range(-2, 3):
				claimed["%d:%d" % [cell.x + offset_x, cell.y]] = true
			var is_moonbell: bool = bloom_rng.randf() < 0.48
			var bloom := Sprite2D.new()
			bloom.name = "GeneratedLushMoonbell" if is_moonbell else "GeneratedLushSunbud"
			bloom.texture = moonbell if is_moonbell else sunbud
			bloom.scale = Vector2.ONE * bloom_rng.randf_range(0.042, 0.058)
			bloom.position = _ground_flora_position(bloom.texture, cell, bloom.scale)
			bloom.flip_h = bloom_rng.randf() < 0.5
			bloom.z_index = 6 if bloom_rng.randf() < 0.35 else 0
			bloom.modulate = Color(0.78, 0.88, 1.0, 1.0) if is_moonbell else Color(1.0, 0.90, 0.66, 1.0)
			# A restrained authored highlight keeps the buds magical without adding
			# a per-plant gameplay light or washing out the cave.
			bloom.self_modulate = Color(0.84, 0.94, 1.08, 1.0) if is_moonbell else Color(1.07, 0.98, 0.76, 1.0)
			_register_vegetation_motion(bloom, bloom.texture, bloom_rng, true)
			decor_root.add_child(bloom)
			if is_moonbell:
				_register_lush_moonbell(bloom)
			placed += 1


func _spawn_lush_light_oases(grid: Array) -> void:
	# A light oasis is deliberately a rare, authored-looking composition instead
	# of a light attached to every plant: one luminous bloom, a clear ceiling
	# opening, a soft angled shaft, and one real local light for Joey and the
	# moss-covered floor.  It only appears inside already dense lush pockets.
	if decor_root == null or lush_biome_density.is_empty():
		return
	var moonbell := _get_lush_moonbell_texture()
	var light_texture := load(LUSH_OASIS_LIGHT_TEXTURE_PATH) as Texture2D
	if moonbell == null or light_texture == null:
		return

	var oasis_rng := RandomNumberGenerator.new()
	oasis_rng.seed = active_level_seed * 1489 + 9239
	var candidates: Array[Dictionary] = []
	for grid_y: int in range(6, level_size_tiles.y - 3):
		for grid_x: int in range(4, level_size_tiles.x - 4):
			if grid_x >= lush_biome_density.size() or lush_biome_density[grid_x] < 2.15:
				continue
			var floor_cell := Vector2i(grid_x, grid_y)
			if _is_torch_column(grid_x) or not _is_exposed_moss_face(grid, floor_cell, Vector2i.UP) or not _has_ground_moss_shoulders(grid, floor_cell):
				continue
			var ceiling_cell := _find_lush_light_oasis_ceiling(grid, floor_cell)
			if ceiling_cell == Vector2i(-1, -1):
				continue
			var slant: float = oasis_rng.randf_range(-18.0, 18.0)
			if not _has_lush_light_beam_clearance(grid, ceiling_cell, floor_cell, slant):
				continue
			candidates.append({"floor": floor_cell, "ceiling": ceiling_cell, "slant": slant})

	if candidates.is_empty():
		return
	# One or two compositional focal points are enough for a whole generated
	# level.  Keep them horizontally separated so neither the lights nor their
	# bloom can stack with Joey's personal glow in one passage.
	var target_count: int = 1 if candidates.size() < 16 else 2
	var selected_xs: Array[float] = []
	for placement_index: int in range(target_count):
		var best_candidate: Dictionary = {}
		var best_score: float = -INF
		for candidate_variant: Variant in candidates:
			var candidate: Dictionary = candidate_variant as Dictionary
			var candidate_floor: Vector2i = candidate.get("floor", Vector2i.ZERO) as Vector2i
			var nearest_distance: float = 9999.0
			for selected_x: float in selected_xs:
				nearest_distance = minf(nearest_distance, absf(float(candidate_floor.x) - selected_x))
			var score: float = nearest_distance + oasis_rng.randf_range(-2.0, 2.0)
			if score > best_score:
				best_score = score
				best_candidate = candidate
		if best_candidate.is_empty():
			break
		var selected_floor: Vector2i = best_candidate.get("floor", Vector2i.ZERO) as Vector2i
		selected_xs.append(float(selected_floor.x))
		_spawn_lush_light_oasis(
			selected_floor,
			best_candidate.get("ceiling", Vector2i.ZERO) as Vector2i,
			float(best_candidate.get("slant", 0.0)),
			moonbell,
			light_texture,
			oasis_rng
		)


func _find_lush_light_oasis_ceiling(grid: Array, floor_cell: Vector2i) -> Vector2i:
	# The shaft can only exist in a genuinely clear vertical pocket.  This avoids
	# projecting light through generated rock and makes its end always land on
	# the exact moss surface that roots the luminous plant.
	for ceiling_y: int in range(floor_cell.y - 4, maxi(1, floor_cell.y - 11), -1):
		var ceiling_cell := Vector2i(floor_cell.x, ceiling_y)
		if not _is_exposed_moss_face(grid, ceiling_cell, Vector2i.DOWN):
			continue
		var clear: bool = true
		for open_y: int in range(ceiling_y + 1, floor_cell.y):
			if _is_solid(grid, floor_cell.x, open_y):
				clear = false
				break
		if clear:
			return ceiling_cell
	return Vector2i(-1, -1)


func _has_lush_light_beam_clearance(grid: Array, ceiling_cell: Vector2i, floor_cell: Vector2i, slant: float) -> bool:
	var cell_offset: int = int(round(slant / TILE_SIZE))
	for step_y: int in range(ceiling_cell.y + 1, floor_cell.y):
		var progress: float = inverse_lerp(float(ceiling_cell.y + 1), float(floor_cell.y), float(step_y))
		var sample_x: int = ceiling_cell.x + int(round(float(cell_offset) * (1.0 - progress)))
		if _is_solid(grid, sample_x, step_y):
			return false
	return true


func _spawn_lush_light_oasis(floor_cell: Vector2i, ceiling_cell: Vector2i, slant: float, plant_texture: Texture2D, light_texture: Texture2D, oasis_rng: RandomNumberGenerator) -> void:
	var root_y: float = float(floor_cell.y) * TILE_SIZE + 2.0
	var target := Vector2(float(floor_cell.x) * TILE_SIZE + TILE_SIZE * 0.5, root_y)
	var source := Vector2(float(ceiling_cell.x) * TILE_SIZE + TILE_SIZE * 0.5 + slant, float(ceiling_cell.y + 1) * TILE_SIZE + 4.0)

	# The translucent cone belongs behind the solid terrain and plants.  It reads
	# as a background shaft, while the real PointLight2D below performs the
	# gameplay illumination on Joey, the bloom and the floor.
	var beam := Polygon2D.new()
	beam.name = "LushLightOasisBeam"
	beam.polygon = PackedVector2Array([
		source + Vector2(-8.0, 0.0),
		source + Vector2(8.0, 0.0),
		target + Vector2(38.0, 0.0),
		target + Vector2(-38.0, 0.0)
	])
	beam.vertex_colors = PackedColorArray([
		Color(1.6, 4.4, 2.4, 0.08),
		Color(1.6, 4.4, 2.4, 0.08),
		Color(1.9, 4.9, 2.7, 0.22),
		Color(1.9, 4.9, 2.7, 0.22)
	])
	beam.z_as_relative = false
	# One step behind terrain/decor keeps the shaft inside open cave space while
	# ensuring it remains visible over the distant parallax layers.
	beam.z_index = -1
	beam.light_mask = 0
	decor_root.add_child(beam)

	var bloom := Sprite2D.new()
	bloom.name = "GeneratedLushLightOasisPlant"
	bloom.texture = plant_texture
	bloom.scale = Vector2.ONE * oasis_rng.randf_range(0.040, 0.048)
	bloom.global_position = _ground_flora_position(plant_texture, floor_cell, bloom.scale)
	bloom.flip_h = oasis_rng.randf() < 0.5
	bloom.z_index = 6 if oasis_rng.randf() < 0.35 else 0
	bloom.modulate = Color(0.70, 0.88, 1.0, 1.0)
	bloom.self_modulate = Color(0.92, 1.22, 1.32, 1.0)
	_register_vegetation_motion(bloom, bloom.texture, oasis_rng, true)
	decor_root.add_child(bloom)
	_register_lush_moonbell(bloom)

	# One modest real light per oasis is enough to illuminate Joey as he walks
	# through it.  It is intentionally much smaller and weaker than his skill
	# glow, so the two lights never wash each other out or create a white core.
	var light := PointLight2D.new()
	light.name = "LushLightOasisGlow"
	light.texture = light_texture
	light.global_position = target + Vector2(0.0, -26.0)
	light.texture_scale = 0.095
	light.energy = oasis_rng.randf_range(0.48, 0.56)
	light.color = Color(0.50, 1.0, 0.66, 1.0)
	light.shadow_enabled = false
	light.add_to_group("lights")
	decor_root.add_child(light)


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
	_register_vegetation_motion(sprite, sprite.texture, landmark_rng, true)
	decor_root.add_child(sprite)


func _add_lush_plant_glow(sprite: Sprite2D, glow_rng: RandomNumberGenerator, min_energy: float, max_energy: float) -> void:
	# Keep the soft bioluminescent tint in the sprite itself, then grant only a
	# tiny capped subset a real local light.  This makes a few plants genuinely
	# illuminate Joey and nearby moss without turning a dense level into dozens
	# of overlapping light passes.
	sprite.self_modulate = Color(0.92, glow_rng.randf_range(1.02, 1.12), glow_rng.randf_range(0.84, 0.96), 1.0)
	if not GENERATED_PLANT_LIGHTS_ENABLED or generated_plant_light_count >= MAX_GENERATED_PLANT_LIGHTS or glow_rng.randf() > 0.16:
		return
	var glow_texture := load(LUSH_OASIS_LIGHT_TEXTURE_PATH) as Texture2D
	if glow_texture == null:
		return
	var glow := PointLight2D.new()
	glow.name = "LushPlantGlow"
	glow.texture = glow_texture
	glow.position = Vector2(0.0, -8.0)
	glow.texture_scale = glow_rng.randf_range(0.030, 0.045)
	glow.energy = glow_rng.randf_range(min_energy * 0.78, max_energy * 0.78)
	glow.color = Color(0.56 + glow_rng.randf() * 0.16, 1.0, 0.48 + glow_rng.randf() * 0.16, 1.0)
	glow.shadow_enabled = false
	glow.add_to_group("lights")
	sprite.add_child(glow)
	generated_plant_light_count += 1


func _spawn_lush_glimmer(world_position: Vector2, glimmer_rng: RandomNumberGenerator, z_order: int) -> void:
	if decor_root == null:
		return
	# Do not use the old light PNG as a Sprite2D here: its opaque black border
	# is fine for a light mask, but appears as a dark rectangle in the game.
	# These tiny alpha-only diamonds keep the magical specks while having no
	# rectangular texture footprint at all.
	var glimmer := Polygon2D.new()
	glimmer.name = "LushGlimmer"
	glimmer.global_position = world_position + Vector2(glimmer_rng.randf_range(-8.0, 8.0), glimmer_rng.randf_range(-5.0, 5.0))
	var radius: float = glimmer_rng.randf_range(1.2, 2.4)
	glimmer.polygon = PackedVector2Array([
		Vector2(0.0, -radius), Vector2(radius, 0.0),
		Vector2(0.0, radius), Vector2(-radius, 0.0)
	])
	# Slight HDR colour crosses the Environment glow threshold without becoming
	# a gameplay light or placing a transparent texture rectangle over the cave.
	glimmer.color = Color(0.62, 1.45, 0.56, glimmer_rng.randf_range(0.52, 0.76))
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
	# One phase per trail, with a tiny offset down the length, makes the
	# hanging parts swing like a single supple rope instead of unrelated leaves.
	var trail_wind_phase: float = rng.randf_range(0.0, TAU)
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
		var vine_sprite := vine as Sprite2D
		if vine_sprite != null:
			# The ceiling anchor stays visually stable; only the lower leaves gain
			# a very subdued, shared rope sway from the root-to-tip shader.  Unlike
			# ground flora, vines deliberately ignore player-contact displacement.
			_register_vegetation_motion(vine_sprite, vine_sprite.texture, rng, false)
			var vine_material := vine_sprite.material as ShaderMaterial
			if vine_material != null:
				var vine_display_scale: float = maxf(0.02, absf(vine_sprite.scale.x))
				vine_material.set_shader_parameter("wind_phase", trail_wind_phase + float(segment_index) * 0.18)
				vine_material.set_shader_parameter("sway_pixels", clampf(rng.randf_range(0.38, 0.72) / vine_display_scale, 2.0, 44.0))
				vine_material.set_shader_parameter("press_pixels", 0.0)
			vine_sprite.set_meta("vegetation_interaction_enabled", false)
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


func _register_ceiling_leaf_source(source: Sprite2D, horizontal_spread: float, vertical_offset: float) -> void:
	if source == null:
		return
	ceiling_leaf_sources.append({
		"source": weakref(source),
		"horizontal_spread": maxf(4.0, horizontal_spread),
		"vertical_offset": maxf(0.0, vertical_offset),
	})


func _update_ambient_lush_leaves(delta: float) -> void:
	# This deliberately supplements only generated ceiling plants. Regular vine
	# scenes already own their authored leaf behaviour, so they are not doubled.
	if decor_root == null or ceiling_leaf_sources.is_empty() or ambient_lush_leaf_count >= MAX_AMBIENT_LUSH_LEAVES:
		return
	if _get_lush_biome_strength(player.global_position) <= 0.04:
		return
	ambient_lush_leaf_timer -= delta
	if ambient_lush_leaf_timer > 0.0:
		return

	var nearby_sources: Array[Dictionary] = []
	for source_data: Dictionary in ceiling_leaf_sources:
		var source_ref := source_data.get("source") as WeakRef
		var source := source_ref.get_ref() as Sprite2D if source_ref != null else null
		if source != null and is_instance_valid(source) and source.global_position.distance_to(player.global_position) <= AMBIENT_LUSH_LEAF_MAX_SOURCE_DISTANCE:
			nearby_sources.append(source_data)
	if nearby_sources.is_empty():
		ambient_lush_leaf_timer = 0.55
		return

	var selected: Dictionary = nearby_sources[ambient_lush_leaf_rng.randi_range(0, nearby_sources.size() - 1)]
	var selected_ref := selected.get("source") as WeakRef
	var selected_source := selected_ref.get_ref() as Sprite2D if selected_ref != null else null
	if selected_source == null or not is_instance_valid(selected_source):
		ambient_lush_leaf_timer = 0.2
		return

	var leaf := FALLING_LEAF_SCENE.instantiate() as RigidBody2D
	if leaf == null:
		return
	decor_root.add_child(leaf)
	var spread := float(selected.get("horizontal_spread", 10.0))
	var vertical_offset := float(selected.get("vertical_offset", 0.0))
	leaf.global_position = selected_source.global_position + Vector2(
		ambient_lush_leaf_rng.randf_range(-spread, spread),
		vertical_offset + ambient_lush_leaf_rng.randf_range(-3.0, 5.0)
	)
	leaf.apply_central_impulse(Vector2(
		ambient_lush_leaf_rng.randf_range(-9.0, 9.0),
		ambient_lush_leaf_rng.randf_range(-7.0, -1.0)
	))
	leaf.z_index = selected_source.z_index + 1
	ambient_lush_leaf_count += 1
	leaf.tree_exiting.connect(_on_ambient_lush_leaf_removed)
	ambient_lush_leaf_timer = ambient_lush_leaf_rng.randf_range(AMBIENT_LUSH_LEAF_MIN_INTERVAL, AMBIENT_LUSH_LEAF_MAX_INTERVAL)


func _on_ambient_lush_leaf_removed() -> void:
	ambient_lush_leaf_count = maxi(0, ambient_lush_leaf_count - 1)


func _register_lush_moonbell(bloom: Sprite2D) -> void:
	if bloom != null:
		lush_moonbell_sources.append(weakref(bloom))


func _update_lush_moonbell_healing(delta: float) -> void:
	# Moonbells are a quiet sanctuary, not a regeneration-skill proc: standing
	# in the rare blue bloom restores exactly one HP per full second.
	if player == null or not player.has_method("restore_environmental_health"):
		return
	var is_touching_moonbell := false
	for moonbell_ref: WeakRef in lush_moonbell_sources:
		var moonbell := moonbell_ref.get_ref() as Sprite2D
		if moonbell != null and is_instance_valid(moonbell) and moonbell.global_position.distance_to(player.global_position) <= LUSH_MOONBELL_HEAL_RADIUS:
			is_touching_moonbell = true
			break
	if not is_touching_moonbell:
		lush_moonbell_heal_timer = 0.0
		return

	lush_moonbell_heal_timer += delta
	while lush_moonbell_heal_timer >= LUSH_MOONBELL_HEAL_INTERVAL:
		lush_moonbell_heal_timer -= LUSH_MOONBELL_HEAL_INTERVAL
		player.call("restore_environmental_health", 1)


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
		Vector2i(2, 2),
		Vector2i(7, 0)
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
		var floor_cell := _resolve_safe_spike_floor(Vector2i(base_x + offset_index, base_y))
		if floor_cell == Vector2i.ZERO:
			# A hazard is never allowed to become a floating trap just because its
			# authored tile disappeared during terrain resolution.
			continue
		var spike: Node2D = SPIKE_SCENE.instantiate() as Node2D
		if spike == null:
			continue
		hazard_root.add_child(spike)
		# Spike is a centered Sprite2D. Offset its origin by half a tile so its
		# opaque bottom edge meets the surface; assigning the raw floor cell would
		# leave its lower half embedded in the terrain.
		spike.global_position = _grid_to_world(floor_cell) + Vector2(16.0, -16.0)
		if player != null:
			spike.call("_on_player_glow_changed", bool(player.get("is_glowing")))


func _resolve_safe_spike_floor(requested: Vector2i) -> Vector2i:
	# Hazards are authored before final terrain carving.  Resolve them again on
	# the finished solid grid: a solid floor, two free cells of headroom and no
	# foreground plant are all mandatory.  The compact search keeps a trap near
	# its designed encounter instead of relocating it across the room.
	if solid_grid_cache.is_empty():
		return Vector2i.ZERO
	var x_offsets: Array[int] = [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6]
	var y_offsets: Array[int] = [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6, -7, 7, -8, 8]
	for y_offset: int in y_offsets:
		var floor_y := requested.y + y_offset
		for x_offset: int in x_offsets:
			var floor_x := requested.x + x_offset
			if not _is_valid_spike_floor(floor_x, floor_y):
				continue
			var cell := Vector2i(floor_x, floor_y)
			if _foreground_plant_blocks_spike(cell):
				continue
			return cell
	return Vector2i.ZERO


func _is_valid_spike_floor(grid_x: int, floor_y: int) -> bool:
	if grid_x < 1 or grid_x >= level_size_tiles.x - 1 or floor_y < 2 or floor_y >= level_size_tiles.y - 1:
		return false
	if not _is_solid(solid_grid_cache, grid_x, floor_y):
		return false
	# Never bury a spike in a wall/ceiling or put it into a one-pixel crack.
	return not _is_solid(solid_grid_cache, grid_x, floor_y - 1) and not _is_solid(solid_grid_cache, grid_x, floor_y - 2)


func _foreground_plant_blocks_spike(floor_cell: Vector2i) -> bool:
	if decor_root == null:
		return false
	var spike_position := _grid_to_world(floor_cell) + Vector2(16.0, -12.0)
	for child: Node in decor_root.get_children():
		if not (child is Sprite2D):
			continue
		var plant_name := String(child.name)
		var is_foreground_plant := plant_name.begins_with("GeneratedFlora") \
			or plant_name.begins_with("GeneratedLushCanopy") \
			or plant_name.begins_with("GeneratedLushLandmark") \
			or plant_name.begins_with("GeneratedWind") \
			or plant_name.begins_with("GeneratedLushMoonbell") \
			or plant_name.begins_with("GeneratedLushSunbud") \
			or plant_name.begins_with("GeneratedLushLightOasisPlant")
		if not is_foreground_plant:
			continue
		var plant := child as Sprite2D
		if absf(plant.global_position.x - spike_position.x) <= 36.0 and absf(plant.global_position.y - spike_position.y) <= 48.0:
			return true
	return false


func _spawn_torch(torch_data: Dictionary) -> void:
	var placement := _resolve_torch_placement(Vector2i(int(torch_data.get("x", 0)), int(torch_data.get("y", 0))))
	if placement.is_empty():
		return
	var torch: Node2D = TORCH_SCENE.instantiate() as Node2D
	if torch == null:
		return

	torch.visible = true
	var anchor: Vector2i = placement.get("anchor", Vector2i.ZERO) as Vector2i
	var style: String = str(placement.get("style", "floor"))
	if style == "floor":
		torch.global_position = _grid_to_world(anchor) + Vector2(16.0, -14.0)
	else:
		var side: int = int(placement.get("side", 1))
		torch.global_position = _grid_to_world(anchor) + Vector2(32.0 if side > 0 else 0.0, 14.0)
		torch.rotation = deg_to_rad(-34.0 * side)
	decor_root.add_child(torch)

	var brightness: float = float(torch_data.get("brightness", 1.0))
	var light_node: PointLight2D = torch.get_node_or_null("Light") as PointLight2D
	if light_node != null:
		light_node.energy *= brightness * 0.92
		# Torch light remains for navigation, but dynamic shadows from every torch
		# are not distinguishable in the cave and are substantially more expensive.
		light_node.shadow_enabled = false


func _resolve_torch_placement(requested: Vector2i) -> Dictionary:
	var x_offsets := [0, -1, 1, -2, 2]
	var y_offsets := [0, -1, 1, -2, 2, -3, 3, -4, 4]
	var floor_candidates: Array[Vector2i] = []
	var wall_candidates: Array[Dictionary] = []
	for y_offset: int in y_offsets:
		for x_offset: int in x_offsets:
			var candidate := requested + Vector2i(x_offset, y_offset)
			if not _is_solid(solid_grid_cache, candidate.x, candidate.y):
				continue
			if not _is_solid(solid_grid_cache, candidate.x, candidate.y - 1) and not _is_solid(solid_grid_cache, candidate.x, candidate.y - 2):
				floor_candidates.append(candidate)
			for side: int in [-1, 1]:
				if not _is_solid(solid_grid_cache, candidate.x + side, candidate.y) and not _is_solid(solid_grid_cache, candidate.x + side, candidate.y - 1):
					wall_candidates.append({"anchor": candidate, "style": "wall", "side": side})
	if not wall_candidates.is_empty() and (floor_candidates.is_empty() or randf() < 0.66):
		return wall_candidates[randi() % wall_candidates.size()] as Dictionary
	if not floor_candidates.is_empty():
		return {"anchor": floor_candidates.front(), "style": "floor", "side": 0}
	return {}


func _spawn_crystal(_crystal_data: Dictionary) -> void:
	return


func _spawn_pickup(pickup_data: Dictionary) -> void:
	var pickup: Area2D = ESSENCE_FRAGMENT_SCENE.instantiate() as Area2D
	if pickup == null:
		return

	var requested_cell := Vector2i(int(pickup_data.get("x", 0)), int(pickup_data.get("y", 0)))
	var floor_cell := _resolve_safe_ground_cell(requested_cell)
	pickup_root.add_child(pickup)
	pickup.global_position = _grid_to_world(floor_cell) + Vector2(16.0, -18.0)
	pickup.set("toast_text", str(pickup_data.get("message", "Essenzsplitter geborgen.")))
	pickup.call("configure_loot_tier", str(pickup_data.get("loot_tier", "copper")))


func _spawn_enemy(enemy_data: Dictionary, track_population: bool = true) -> void:
	var enemy_type: String = str(enemy_data.get("type", "slime"))
	var is_glut_guardian := enemy_type == "glutkaefer" and bool(enemy_data.get("drop_glut_schluessel", false))
	if is_glut_guardian and _has_resolved_glut_guardian():
		return
	var requested_cell := Vector2i(int(enemy_data.get("x", 0)), int(enemy_data.get("y", 0)))
	# Only bats are airborne. The Irrlichtkäfer and Glutkäfer use grounded
	# CharacterBody physics and must be placed on a verified floor tile.
	var flying_enemy := enemy_type == "bat"
	var spawn_cell := _resolve_safe_air_cell(requested_cell) if flying_enemy else _resolve_safe_ground_cell(requested_cell)
	var spawn_position: Vector2 = _grid_to_world(spawn_cell) + (Vector2(16.0, 16.0) if flying_enemy else Vector2(16.0, -12.0))
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
		"irrlichtkaefer":
			enemy_scene = IRRLICHTKAEFER_SCENE
			# Its body circle is centred 16 px above the root. Put its feet on
			# the floor instead of spawning the root in the ground cell.
			spawn_position.y += 18.0
		"glutkaefer":
			enemy_scene = GLUTKAEFER_SCENE
		_:
			return

	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	if enemy == null:
		return
	if enemy_type == "glutkaefer":
		enemy.set("drops_glut_schluessel", bool(enemy_data.get("drop_glut_schluessel", false)))
	if enemy_type == "bat":
		_configure_chapter_bat(enemy, spawn_cell)
	enemy.set_meta("chapter_enemy_type", enemy_type)
	enemy.set_meta("glut_story_guardian", is_glut_guardian)
	# Both authored and replenished enemies count toward the same density cap;
	# only authored spawns increase that cap.
	var respawn_managed := not bool(enemy_data.get("no_respawn", false))
	enemy.set_meta("respawn_managed", respawn_managed)
	enemy_root.add_child(enemy)
	enemy.global_position = spawn_position
	# Character scenes enter the tree before their generated world coordinate is
	# assigned. Grounded patrol enemies must capture their home only afterwards;
	# otherwise an Irrlichtkäfer tries to return to (0, 0) and can walk into the
	# cave mesh far away from its actual spawn.
	if enemy.has_method("set_spawn_home"):
		enemy.call("set_spawn_home", spawn_position)
	if enemy.has_signal("defeated"):
		enemy.connect("defeated", Callable(self, "_on_chapter_enemy_defeated").bind(enemy), CONNECT_ONE_SHOT)
	if enemy.has_signal("defeated") and respawn_managed:
		enemy.connect("defeated", Callable(self, "_on_managed_enemy_defeated").bind(enemy_type), CONNECT_ONE_SHOT)
	_attach_enemy_awareness_indicator(enemy)
	if track_population and respawn_managed:
		enemy_population_target += 1
		if not enemy_respawn_types.has(enemy_type):
			enemy_respawn_types.append(enemy_type)


func spawn_quest_enemy(enemy_type: String, world_position: Vector2, anchor_id: String) -> void:
	var cell := Vector2i(int(floor(world_position.x / TILE_SIZE)), int(floor(world_position.y / TILE_SIZE)))
	_spawn_enemy({"type": enemy_type, "x": cell.x, "y": cell.y, "no_respawn": true}, false)
	if enemy_root.get_child_count() > 0:
		var enemy := enemy_root.get_child(enemy_root.get_child_count() - 1) as Node2D
		if enemy != null:
			enemy.set_meta("chapter_quest_enemy", true)
			enemy.set_meta("chapter_quest_anchor", anchor_id)


func _on_chapter_enemy_defeated(enemy: Node2D) -> void:
	if bool(enemy.get_meta("glut_story_guardian", false)):
		var progress := _progress()
		if progress != null and progress.has_method("award_reward"):
			progress.call("award_reward", "glutkaefer_defeated")
	if quest_runtime != null and is_instance_valid(quest_runtime):
		quest_runtime.report_enemy_defeated(enemy.global_position, enemy)


func _has_resolved_glut_guardian() -> bool:
	if _has_glut_guardian_victory():
		return true
	# Compatibility with older saves which already hold the reward but predate
	# the persistent guardian marker.
	if player != null:
		var inventory: Variant = player.get("inv")
		if inventory != null and inventory.has_method("contains_item") and bool(inventory.call("contains_item", "glut_schluessel")):
			return true
	# Also avoid duplicating a reward that is currently waiting in the world.
	for pickup: Node in get_tree().get_nodes_in_group("world_pickups"):
		var item: Variant = pickup.get("item")
		if item != null and str(item.get("name")) == "glut_schluessel":
			return true
	return false


func _has_glut_guardian_victory() -> bool:
	var progress := _progress()
	return progress != null and progress.has_method("has_reward") and bool(progress.call("has_reward", "glutkaefer_defeated"))


func _resolve_safe_ground_cell(requested: Vector2i) -> Vector2i:
	if solid_grid_cache.is_empty():
		return requested
	var offsets: Array[int] = [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6, -7, 7, -8, 8]
	for radius in range(0, 9):
		for y_offset in offsets:
			if abs(y_offset) > radius:
				continue
			for x_offset in offsets:
				if abs(x_offset) > radius:
					continue
				var cell := requested + Vector2i(x_offset, y_offset)
				if _is_valid_spawn_floor(cell.x, cell.y):
					return cell
	return requested


func resolve_quest_ground_cell(requested: Vector2i) -> Vector2i:
	# A quest anchor may be a semantic traversal point rather than the exact
	# floor cell that survived the final cave/carving pass.  Resolve it against
	# the collision grid, requiring a broad landing and headroom so collectible
	# objectives cannot appear suspended in a ceiling pocket or inside terrain.
	if solid_grid_cache.is_empty():
		return Vector2i(-1, -1)
	# Quest anchors are generated from the validated critical route. Prefer the
	# closest route node before widening the search, otherwise a nearby but
	# disconnected cave pocket can win the geometric floor search.
	var critical_path: Array = active_level.get("critical_path_nodes", []) as Array
	if not critical_path.is_empty():
		var closest_node: Vector2i = critical_path.front() as Vector2i
		var closest_distance := closest_node.distance_squared_to(requested)
		for path_variant: Variant in critical_path:
			var candidate: Vector2i = path_variant as Vector2i
			var distance := candidate.distance_squared_to(requested)
			if distance < closest_distance:
				closest_node = candidate
				closest_distance = distance
		var route_floor := _find_quest_floor_near(closest_node, 5)
		if route_floor != Vector2i(-1, -1):
			return route_floor
	return _find_quest_floor_near(requested, 18)


func _find_quest_floor_near(requested: Vector2i, max_radius: int) -> Vector2i:
	var offsets: Array[int] = []
	for distance: int in range(0, max_radius + 1):
		if distance == 0:
			offsets.append(0)
		else:
			offsets.append(-distance)
			offsets.append(distance)
	for radius: int in range(0, max_radius + 1):
		for y_offset: int in offsets:
			if abs(y_offset) > radius:
				continue
			for x_offset: int in offsets:
				if abs(x_offset) > radius:
					continue
				var cell := requested + Vector2i(x_offset, y_offset)
				if _is_valid_quest_floor(cell.x, cell.y):
					return cell
	return Vector2i(-1, -1)


func _is_valid_quest_floor(grid_x: int, floor_y: int) -> bool:
	if grid_x < 2 or floor_y < 4 or grid_x >= level_size_tiles.x - 2 or floor_y >= level_size_tiles.y - 1:
		return false
	if not _is_solid(solid_grid_cache, grid_x, floor_y):
		return false
	# The target is centred over this cell.  Three solid cells keep it from
	# balancing on a single spike-like tile, while three empty rows prevent
	# ceiling/terrain overlap for the draft sprite and its interaction area.
	var support_count := 0
	for offset_x: int in range(-1, 2):
		if _is_solid(solid_grid_cache, grid_x + offset_x, floor_y):
			support_count += 1
		for offset_y: int in range(1, 4):
			if _is_solid(solid_grid_cache, grid_x + offset_x, floor_y - offset_y):
				return false
	return support_count >= 3


func _resolve_safe_air_cell(requested: Vector2i) -> Vector2i:
	if solid_grid_cache.is_empty():
		return requested
	var offsets: Array[int] = [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6, -7, 7, -8, 8]
	for radius in range(0, 9):
		for y_offset in offsets:
			if abs(y_offset) > radius:
				continue
			for x_offset in offsets:
				if abs(x_offset) > radius:
					continue
				var cell := requested + Vector2i(x_offset, y_offset)
				if _is_clear_flying_cell(cell):
					return cell
	return requested


func _is_clear_flying_cell(cell: Vector2i) -> bool:
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if _is_solid(solid_grid_cache, cell.x + offset_x, cell.y + offset_y):
				return false
	return true


func _configure_chapter_bat(enemy: Node2D, spawn_cell: Vector2i) -> void:
	var level_number := int(active_level.get("level_index", 0)) + 1
	# Health, speed and contact damage rise steadily per level. The opening bat
	# no longer evaporates in one hit, while later levels become stricter without
	# abruptly changing the species' readable attack rhythm.
	enemy.set("max_health", 38 + level_number * 6)
	enemy.set("hover_speed", 100.0 + level_number * 5.0)
	enemy.set("chase_speed", 145.0 + level_number * 7.0)
	enemy.set("contact_damage", 8 + int(floor(float(level_number - 1) * 0.85)))
	# Albinos remain a recognizable variant, but are uncommon enough to keep
	# their higher-pressure melee pattern special: roughly one in four early on.
	enemy.set("is_albino", randf() < minf(0.27 + float(level_number - 1) * 0.010, 0.34))
	enemy.set("patrol_route", _build_bat_patrol_route(spawn_cell))


func _build_bat_patrol_route(start_cell: Vector2i) -> PackedVector2Array:
	var route := PackedVector2Array()
	var start_world := _grid_to_world(start_cell) + Vector2(16.0, 16.0)
	var preferred_offsets := [Vector2i(7, -2), Vector2i(-6, -3), Vector2i(5, 3), Vector2i(-4, 2)]
	for offset: Vector2i in preferred_offsets:
		var destination := _resolve_safe_air_cell(start_cell + offset)
		var segment := request_flying_path(start_world if route.is_empty() else route[route.size() - 1], _grid_to_world(destination) + Vector2(16.0, 16.0))
		if segment.is_empty():
			continue
		for point_index in range(0, segment.size(), 3):
			route.append(segment[point_index])
	return route


func _spawn_glut_dimension_door_if_needed() -> void:
	if not active_level.has("glut_door") or gate_root == null:
		return
	var door_cell: Vector2i = active_level.get("glut_door", Vector2i.ZERO) as Vector2i
	if door_cell == Vector2i.ZERO:
		return
	var floor_cell := _resolve_safe_ground_cell(door_cell)
	if not _is_valid_spawn_floor(floor_cell.x, floor_cell.y):
		push_error("Glutdimension door has no valid floor near %s." % door_cell)
		return
	var door := GLUT_DIMENSION_DOOR_SCENE.instantiate() as Node2D
	if door == null:
		return
	gate_root.add_child(door)
	# The door root belongs exactly on the top edge of a real floor tile. Using
	# the authored semantic coordinate placed it inside regenerated cave rock.
	door.global_position = _grid_to_world(floor_cell) + Vector2(16.0, 0.0)


func _spawn_missing_glut_guardian_rewards_if_needed() -> void:
	if not active_level.has("glut_door") or not _has_glut_guardian_victory():
		return
	var door_cell: Vector2i = active_level.get("glut_door", Vector2i.ZERO) as Vector2i
	var floor_cell := _resolve_safe_ground_cell(door_cell)
	if not _is_valid_spawn_floor(floor_cell.x, floor_cell.y):
		return
	var reward_origin := _grid_to_world(floor_cell) + Vector2(16.0, -34.0)
	_ensure_glut_guardian_reward("glut_schluessel", reward_origin + Vector2(-18.0, 0.0))
	_ensure_glut_guardian_reward("lumora", reward_origin + Vector2(18.0, 0.0))


func _ensure_glut_guardian_reward(item_name: String, world_position: Vector2) -> void:
	if _player_or_world_has_item(item_name):
		return
	var pickup := ItemRegistry.create_pickup_for_item(item_name)
	if pickup == null:
		push_error("Could not restore Glutkaefer reward: %s" % item_name)
		return
	pickup.set("is_persistent_reward", true)
	gate_root.add_child(pickup)
	pickup.global_position = world_position


func _player_or_world_has_item(item_name: String) -> bool:
	if player != null:
		var inventory: Variant = player.get("inv")
		if inventory != null and inventory.has_method("contains_item") and bool(inventory.call("contains_item", item_name)):
			return true
	for pickup: Node in get_tree().get_nodes_in_group("world_pickups"):
		var item: Variant = pickup.get("item")
		if item != null and str(item.get("name")) == item_name:
			return true
	return false


func _attach_enemy_awareness_indicator(enemy: Node2D) -> void:
	var indicator := Node2D.new()
	indicator.name = "EnemyAwarenessIndicator"
	indicator.set_script(ENEMY_AWARENESS_INDICATOR)
	enemy.add_child(indicator)


func _on_managed_enemy_defeated(_enemy_type: String) -> void:
	if transition_locked or enemy_root == null:
		return
	if enemy_respawn_timer < 0.0:
		enemy_respawn_timer = rng.randf_range(ENEMY_RESPAWN_DELAY_MIN, ENEMY_RESPAWN_DELAY_MAX)


func _update_enemy_population(delta: float) -> void:
	if transition_locked or enemy_population_target <= 0 or enemy_root == null:
		return
	if _get_active_managed_enemy_count() >= enemy_population_target:
		enemy_respawn_timer = -1.0
		return
	if enemy_respawn_timer < 0.0:
		enemy_respawn_timer = rng.randf_range(ENEMY_RESPAWN_DELAY_MIN, ENEMY_RESPAWN_DELAY_MAX)
		return
	enemy_respawn_timer -= delta
	if enemy_respawn_timer > 0.0:
		return

	var shuffled_types: Array[String] = enemy_respawn_types.duplicate()
	shuffled_types.shuffle()
	for enemy_type: String in shuffled_types:
		var respawn_data := _find_random_enemy_respawn(enemy_type)
		if not respawn_data.is_empty():
			_spawn_enemy(respawn_data, false)
			enemy_respawn_timer = rng.randf_range(ENEMY_RESPAWN_DELAY_MIN, ENEMY_RESPAWN_DELAY_MAX)
			return
	enemy_respawn_timer = 2.5


func _get_active_managed_enemy_count() -> int:
	var count := 0
	for enemy: Node in enemy_root.get_children():
		if bool(enemy.get_meta("respawn_managed", false)):
			count += 1
	return count


func _find_random_enemy_respawn(enemy_type: String) -> Dictionary:
	if solid_grid_cache.is_empty():
		return {}
	for _attempt in range(54):
		var grid_x := rng.randi_range(4, level_size_tiles.x - 5)
		var floor_y := -1
		for grid_y in range(4, level_size_tiles.y - 3):
			if not _is_solid(solid_grid_cache, grid_x, grid_y) and not _is_solid(solid_grid_cache, grid_x, grid_y - 1) and _is_solid(solid_grid_cache, grid_x, grid_y + 1):
				floor_y = grid_y
				break
		if floor_y < 0:
			continue
		var world_position := _grid_to_world(Vector2i(grid_x, floor_y)) + Vector2(16.0, -12.0)
		if player != null and world_position.distance_to(player.global_position) < ENEMY_RESPAWN_MIN_PLAYER_DISTANCE:
			continue
		if not _is_enemy_biome_match(enemy_type, world_position):
			continue
		return {"type": enemy_type, "x": grid_x, "y": floor_y}
	return {}


func _is_enemy_biome_match(enemy_type: String, world_position: Vector2) -> bool:
	var lush_strength := _get_lush_biome_strength(world_position)
	match enemy_type:
		"irrlichtkaefer":
			return lush_strength >= 0.70
		"mushroom":
			return lush_strength >= 0.18
		"gluehwuermchen":
			return lush_strength >= 0.55
		"slime":
			return lush_strength <= 0.82
		_:
			return true


func _spawn_lush_irrlichtkaefer() -> void:
	if lush_biome_regions.is_empty():
		return
	var beetle_count := mini(2, lush_biome_regions.size())
	for _index in range(beetle_count):
		var beetle_data := _find_random_enemy_respawn("irrlichtkaefer")
		if not beetle_data.is_empty():
			_spawn_enemy(beetle_data)


func _spawn_lush_gluehwuermchen() -> void:
	if lush_biome_regions.is_empty() or decor_root == null:
		return
	# Ambient creatures intentionally live under decor_root: they are never
	# counted, targeted or respawned by the enemy-population manager.
	var count := clampi(lush_biome_regions.size() * 2, 2, 6)
	for _index in range(count):
		var perch_data := _find_random_enemy_respawn("gluehwuermchen")
		if perch_data.is_empty():
			continue
		var creature := GLUEHWUERMCHEN_SCENE.instantiate() as Node2D
		if creature == null:
			continue
		decor_root.add_child(creature)
		creature.global_position = _grid_to_world(Vector2i(int(perch_data.get("x", 0)), int(perch_data.get("y", 0)))) + Vector2(16.0, -58.0)


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
	# The Glutdimension is a real chapter objective rather than optional loot:
	# this ordinary exit stays visibly sealed until its quest gate advances Joey.
	if bool(active_level.get("requires_glut_quest", false)) and not _progress().has_reward("glut_dimension_cleared"):
		exit_gate.set("is_locked", true)
		exit_gate.call("_apply_theme")

	if active_level.has("boss"):
		exit_gate.visible = false
		boss_gate_revealed = false


func _spawn_quest_runtime() -> void:
	if not active_level.has("quest"):
		return
	quest_runtime = ChapterQuestRuntime.new()
	quest_runtime.name = "ChapterQuestRuntime"
	add_child(quest_runtime)
	quest_runtime.configure(active_level, player, exit_gate, self, ui_layer)


func _spawn_boss_if_needed() -> void:
	if not active_level.has("boss"):
		return

	var boss_data: Dictionary = active_level.get("boss", {}) as Dictionary
	var boss: Node2D = KRISTALLRUECKEN_SCENE.instantiate() as Node2D
	if boss == null:
		return

	enemy_root.add_child(boss)
	boss.global_position = _grid_to_world(Vector2i(int(boss_data.get("x", 58)), int(boss_data.get("y", 26)))) + Vector2(16.0, -14.0)
	boss.connect("health_changed", Callable(self, "_on_boss_health_changed"))
	boss.connect("death_animation_finished", Callable(self, "_on_boss_death_animation_finished").bind(boss))
	boss_bar.visible = false
	boss_name.visible = false


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
	# Kristallruecken owns the intentionally small world-space life bar above
	# its head. Keep the legacy screen-wide bar disabled.
	boss_bar.visible = false
	boss_name.visible = false


func _on_boss_death_animation_finished(boss: Node2D) -> void:
	if quest_runtime != null and is_instance_valid(quest_runtime) and not quest_runtime.can_reveal_boss_gate():
		return
	if boss_gate_revealed:
		return
	boss_gate_revealed = true
	boss_portal_source = boss.global_position + Vector2(0.0, -26.0)
	if exit_gate != null:
		exit_gate.visible = true
		exit_gate.call("configure_exit_gate", "Zurueck zum Hub", "Kapitel I abgeschlossen", Color(0.92, 0.96, 0.58, 1.0), Callable(self, "_complete_level"))
		exit_gate.connect("arrival_finished", Callable(self, "_on_boss_portal_arrival_finished"), CONNECT_ONE_SHOT)
		exit_gate.call("begin_boss_arrival")

	boss_name.visible = false
	boss_bar.visible = false

	var exit_message: String = str(active_level.get("boss_exit_message", "Kristallruecken zerfaellt. Eine blaue Spur weist den Weg."))
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
		pickup.set("toast_text", "Kristallessenz geborgen.")


func _on_boss_portal_arrival_finished() -> void:
	if exit_gate == null:
		return
	if boss_energy_trail != null and is_instance_valid(boss_energy_trail):
		boss_energy_trail.queue_free()
	boss_energy_trail = MAGIC_ENERGY_TRAIL.new() as Node2D
	if boss_energy_trail == null:
		return
	add_child(boss_energy_trail)
	boss_energy_trail.call("configure", boss_portal_source, exit_gate.global_position + Vector2(0.0, -24.0))


func _complete_level() -> void:
	if transition_locked:
		return
	transition_locked = true
	_progress().complete_active_level()


func _on_pause_menu_go_to_main_menu() -> void:
	get_tree().paused = false
	var progress := _progress()
	if progress != null and progress.has_method("preserve_chapter_resume"):
		progress.call("preserve_chapter_resume")
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


func _build_flying_path_grid() -> void:
	# One navigation raster is shared by every flying enemy in this generated
	# level. Solid cave cells are forbidden, so a path can only travel through
	# genuinely open space and never cuts through a wall.
	if solid_grid_cache.is_empty():
		flying_path_grid = null
		return
	flying_path_grid = AStarGrid2D.new()
	flying_path_grid.region = Rect2i(Vector2i.ZERO, level_size_tiles)
	flying_path_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	flying_path_grid.update()
	for grid_y in range(level_size_tiles.y):
		for grid_x in range(level_size_tiles.x):
			flying_path_grid.set_point_solid(Vector2i(grid_x, grid_y), _is_solid(solid_grid_cache, grid_x, grid_y))


func request_flying_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	if flying_path_grid == null:
		return PackedVector2Array()
	var start := _nearest_open_flying_cell(Vector2i(floori(from_world.x / TILE_SIZE), floori(from_world.y / TILE_SIZE)))
	var destination := _nearest_open_flying_cell(Vector2i(floori(to_world.x / TILE_SIZE), floori(to_world.y / TILE_SIZE)))
	if start == Vector2i(-1, -1) or destination == Vector2i(-1, -1):
		return PackedVector2Array()
	var cells: Array[Vector2i] = flying_path_grid.get_id_path(start, destination)
	if cells.size() < 2:
		return PackedVector2Array()
	var points := PackedVector2Array()
	# The first point is the bat's own cell; omitting it avoids a pause before
	# it starts moving. The remaining points are centres of free cells.
	for cell_index in range(1, cells.size()):
		var cell: Vector2i = cells[cell_index]
		points.append(_grid_to_world(cell) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5))
	return points


func _nearest_open_flying_cell(requested: Vector2i) -> Vector2i:
	var x_offsets: Array[int] = [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6, -7, 7, -8, 8]
	var y_offsets: Array[int] = [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6, -7, 7, -8, 8]
	for radius in range(0, 9):
		for y_offset in y_offsets:
			if abs(y_offset) > radius:
				continue
			for x_offset in x_offsets:
				if abs(x_offset) > radius:
					continue
				var cell := requested + Vector2i(x_offset, y_offset)
				if cell.x < 1 or cell.y < 1 or cell.x >= level_size_tiles.x - 1 or cell.y >= level_size_tiles.y - 1:
					continue
				if not _is_solid(solid_grid_cache, cell.x, cell.y):
					return cell
	return Vector2i(-1, -1)


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
