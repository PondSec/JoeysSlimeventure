extends Node2D

const PLAYER_SCENE := preload("res://Scenes/player.tscn")
const TILE_LEFT := preload("res://Assets/Chapter2/Tiles/left_corner.png")
const TILE_MIDDLE := preload("res://Assets/Chapter2/Tiles/middle_tile.png")
const TILE_MIDDLE_VARIANT := preload("res://Assets/Chapter2/Tiles/middle_variant.png")
const TILE_RIGHT := preload("res://Assets/Chapter2/Tiles/right_corner.png")
const PARALLAX_TEXTURE_PATHS := [
	"res://Assets/Chapter2/Parallax/layer4.png",
	"res://Assets/Chapter2/Parallax/layer3.png",
	"res://Assets/Chapter2/Parallax/layer2.png",
	"res://Assets/Chapter2/Parallax/layer1.png"
]
# This is the second wide cave vista supplied for chapter two.  It deliberately
# alternates with layer 4, rather than replacing it, so the journey keeps changing.
const FAR_VISTA_VARIANT_PATH := "res://Assets/Chapter2/Parallax/katakomben_fernansicht_2.png"
const PARALLAX_PANEL_OVERLAP := 24.0

const FLOOR_Y := 720.0
const FLOOR_WIDTH := 92
# A middle distance: clearly farther than the native-size close-up, while the
# bones still frame the play space rather than shrinking to a full-window card.
const CHAPTER_TWO_PARALLAX_SCALE := Vector2(0.25, 0.25)
# The chapter-two frame needs to sit lower in the camera view so its upper and
# lower bone edges line up with the already visible left/right framing.
const CHAPTER_TWO_PARALLAX_VERTICAL_OFFSET := 180.0
const FAR_VISTA_OFFSET := Vector2(-150.0, -195.0)
const MIDDLE_VISTA_OFFSET := Vector2(-40.0, -150.0)
const NEAR_VISTA_OFFSET := Vector2(90.0, -80.0)
const FOREGROUND_CEILING_HEIGHT := 230.0
const FOREGROUND_FLOOR_START := 330.0

var player: CharacterBody2D
var player_at_exit := false


func _ready() -> void:
	add_to_group("chapter_runtime")
	_build_parallax_background()
	_build_tile_preview_floor()
	_build_preview_exit()
	_spawn_player()
	_build_foreground_parallax()
	_build_preview_ui()


func _build_parallax_background() -> void:
	# Same ParallaxBackground/ParallaxLayer pattern as the normal stone cave:
	# the layers are camera-relative, repeat seamlessly and move at distinct rates.
	var background := ParallaxBackground.new()
	background.name = "KatakombenParallax"
	background.scale = CHAPTER_TWO_PARALLAX_SCALE
	add_child(background)
	move_child(background, 0)

	var base_layer := ParallaxLayer.new()
	base_layer.motion_scale = Vector2.ZERO
	background.add_child(base_layer)
	var base_fill := Polygon2D.new()
	base_fill.color = Color(0.025, 0.024, 0.035, 1.0)
	base_fill.polygon = PackedVector2Array([Vector2(-2400, -2400), Vector2(7200, -2400), Vector2(7200, 3600), Vector2(-2400, 3600)])
	base_layer.add_child(base_fill)

	# Back to front: a quiet, wide vista; hazy middle shapes; then the closer
	# cave structure.  Their separate offsets stop the silhouettes from sitting
	# exactly on top of one another and leave a readable, open stage for Joey.
	var settings := [
		{"path": PARALLAX_TEXTURE_PATHS[0], "alternate_path": FAR_VISTA_VARIANT_PATH, "motion": Vector2(0.12, 0.0), "alpha": 0.90, "offset": FAR_VISTA_OFFSET},
		{"path": PARALLAX_TEXTURE_PATHS[1], "motion": Vector2(0.27, 0.0), "alpha": 0.32, "offset": MIDDLE_VISTA_OFFSET},
		{"path": PARALLAX_TEXTURE_PATHS[2], "motion": Vector2(0.46, 0.0), "alpha": 0.42, "offset": NEAR_VISTA_OFFSET}
	]
	for setting_variant: Variant in settings:
		var setting: Dictionary = setting_variant as Dictionary
		var texture := load(str(setting["path"])) as Texture2D
		if texture == null:
			continue
		var alternate_texture := load(str(setting.get("alternate_path", setting["path"]))) as Texture2D
		if alternate_texture == null:
			alternate_texture = texture
		var layer := ParallaxLayer.new()
		layer.motion_scale = setting["motion"] as Vector2
		# The two panels overlap a little, hiding the edge even when the source
		# motifs differ.  The complete A/B pair is what repeats seamlessly.
		var panel_step := float(texture.get_width()) - PARALLAX_PANEL_OVERLAP
		layer.motion_mirroring = Vector2(panel_step * 2.0, 0.0)
		layer.position = Vector2(-float(texture.get_width()) * 0.4, CHAPTER_TWO_PARALLAX_VERTICAL_OFFSET) + setting["offset"] as Vector2
		background.add_child(layer)
		for copy_index in range(6):
			var sprite := Sprite2D.new()
			sprite.texture = texture if copy_index % 2 == 0 else alternate_texture
			sprite.centered = false
			sprite.position = Vector2(float(copy_index) * panel_step, 0.0)
			sprite.modulate = Color(1.0, 1.0, 1.0, float(setting["alpha"]))
			sprite.light_mask = 0
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			layer.add_child(sprite)


func _build_foreground_parallax() -> void:
	# Layer 1 contains both a ceiling and ground decoration.  Drawing those two
	# parts independently keeps them fixed to their natural screen edges instead
	# of turning the whole image into a floating frame in the middle of the room.
	var texture := load(PARALLAX_TEXTURE_PATHS[3]) as Texture2D
	if texture == null:
		return
	var foreground := ParallaxBackground.new()
	foreground.name = "KatakombenForegroundParallax"
	foreground.layer = 1
	foreground.scale = CHAPTER_TWO_PARALLAX_SCALE
	add_child(foreground)
	_add_foreground_strip(
		foreground,
		texture,
		"KatakombenDecke",
		Rect2(0.0, 0.0, float(texture.get_width()), FOREGROUND_CEILING_HEIGHT),
		Vector2(-float(texture.get_width()) * 0.4, 28.0)
	)
	_add_foreground_strip(
		foreground,
		texture,
		"KatakombenBoden",
		Rect2(0.0, FOREGROUND_FLOOR_START, float(texture.get_width()), float(texture.get_height()) - FOREGROUND_FLOOR_START),
		Vector2(-float(texture.get_width()) * 0.4, CHAPTER_TWO_PARALLAX_VERTICAL_OFFSET + 225.0 + FOREGROUND_FLOOR_START)
	)


func _add_foreground_strip(parent: ParallaxBackground, texture: Texture2D, strip_name: String, region: Rect2, strip_position: Vector2) -> void:
	var layer := ParallaxLayer.new()
	layer.name = strip_name
	layer.motion_scale = Vector2(0.68, 0.0)
	layer.motion_mirroring = Vector2(float(texture.get_width()), 0.0)
	layer.position = strip_position
	parent.add_child(layer)
	for copy_index in range(4):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.region_rect = region
		sprite.centered = false
		sprite.position = Vector2(float(copy_index) * float(texture.get_width()), 0.0)
		sprite.light_mask = 0
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.add_child(sprite)


func _build_tile_preview_floor() -> void:
	var floor_tiles := Node2D.new()
	floor_tiles.name = "KatakombenTiles"
	add_child(floor_tiles)
	for tile_index in range(FLOOR_WIDTH):
		var tile := Sprite2D.new()
		if tile_index == 0:
			tile.texture = TILE_LEFT
		elif tile_index == FLOOR_WIDTH - 1:
			tile.texture = TILE_RIGHT
		else:
			tile.texture = TILE_MIDDLE_VARIANT if tile_index % 5 == 0 else TILE_MIDDLE
		tile.centered = false
		tile.position = Vector2(float(tile_index) * 32.0, FLOOR_Y)
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		floor_tiles.add_child(tile)

	# Joey's collision mask listens on layer 2.  Each visible 32px tile gets a
	# matching solid cell, so the floor is physical rather than decoration only.
	var floor_collision := StaticBody2D.new()
	floor_collision.collision_layer = 2
	floor_collision.collision_mask = 0
	for tile_index in range(FLOOR_WIDTH):
		var collision := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(32.0, 32.0)
		collision.shape = rectangle
		collision.position = Vector2(float(tile_index) * 32.0 + 16.0, FLOOR_Y + 16.0)
		floor_collision.add_child(collision)
	add_child(floor_collision)


func _build_preview_exit() -> void:
	var exit_area := Area2D.new()
	exit_area.position = Vector2(float(FLOOR_WIDTH) * 32.0 - 116.0, FLOOR_Y - 34.0)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(84.0, 112.0)
	collision.shape = rectangle
	exit_area.add_child(collision)
	exit_area.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("players"):
			player_at_exit = true
			body.call("_show_feedback_toast", "Vorschauende – E zum Hub", "info", null)
	)
	exit_area.body_exited.connect(func(body: Node2D) -> void:
		if body.is_in_group("players"):
			player_at_exit = false
	)
	add_child(exit_area)

	var marker := Polygon2D.new()
	marker.position = exit_area.position
	marker.color = Color(0.78, 0.84, 0.98, 0.88)
	marker.polygon = PackedVector2Array([Vector2(-20, 26), Vector2(-20, -44), Vector2(0, -64), Vector2(20, -44), Vector2(20, 26)])
	add_child(marker)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as CharacterBody2D
	if player == null:
		return
	player.name = "PlayerModel"
	add_child(player)
	player.global_position = Vector2(170.0, FLOOR_Y - 128.0)
	player.set_world_fall_death_y(FLOOR_Y + 340.0)
	var progress := get_node_or_null("/root/ChapterProgress")
	if progress != null and progress.has_method("consume_runtime_player_state"):
		var state: Dictionary = progress.call("consume_runtime_player_state") as Dictionary
		if not state.is_empty():
			player.call("restore_portal_state", state)
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = FLOOR_WIDTH * 32
		camera.limit_bottom = int(FLOOR_Y + 300.0)


func _build_preview_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 8
	add_child(ui)
	var title := Label.new()
	title.position = Vector2(28, 118)
	title.text = "KAPITEL II  •  KNOCHENKATAKOMBEN\nVORSCHAU – weitere Räume folgen"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.92, 0.89, 0.78, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	ui.add_child(title)


func _process(_delta: float) -> void:
	if not player_at_exit or not Input.is_action_just_pressed("Interact"):
		return
	var progress := get_node_or_null("/root/ChapterProgress")
	if progress != null:
		progress.call("enter_hub")
		progress.call("transition_to", "res://Scenes/Game.tscn")
