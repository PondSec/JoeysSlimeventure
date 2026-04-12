extends Node2D

const CONFIG_PATH := "user://game_config.cfg"
const HUB_INTRO_SECTION := "dialogs"
const HUB_INTRO_KEY := "hub_intro_completed"
const FEEDBACK_FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const CHAPTER_GATE_SCENE := preload("res://Scenes/Chapter/chapter_gate.tscn")
const ChapterContent := preload("res://Scripts/Chapter/chapter_content.gd")
const SkillProgression := preload("res://Scripts/skill_progression.gd")

const DOOR_POSITIONS := [
	Vector2(500.0, 1034.0),
	Vector2(820.0, 1034.0),
	Vector2(1140.0, 1034.0),
	Vector2(1460.0, 1034.0),
	Vector2(1780.0, 1034.0),
	Vector2(2100.0, 1034.0),
	Vector2(2420.0, 1034.0)
]
const HUB_WALKWAY_TOP_Y := 1042.0
const HUB_WALKWAY_HEIGHT := 56.0
const HUB_WALKWAY_MARGIN := 158.0
const PLAYER_WORLD_COLLISION_LAYER := 2

const LEGACY_NODE_PATHS := [
	"Background/Door",
	"Background/Spike",
	"Background/Spike2",
	"Background/Spike3",
	"Background/Spike4",
	"Background/Spike5",
	"Background/Spike6",
	"Deko/Spike",
	"Deko/Spike2",
	"SpawnArea",
	"worm"
]

var intro_lines: Array[String] = [
	"...Wo bin ich?",
	"Das letzte, was Joey spueren kann, ist kaltes Gestein und das Echo eines verlorenen Kampfes.",
	"Doch in diesem Schleimkern flackert etwas Neues: anpassungsfaehig, zaeh und seltsam maechtig.",
	"Vor jedem Tor wartet eine andere Pruefung. Die Tropfsteinhoehle oeffnet sich zuerst.",
	"Wenn Joey waechst, antwortet der Hub mit weiteren Tueren."
]

var current_line: int = 0
var dialog_active: bool = false
var hub_runtime: Node2D
var bridge_root: Node2D
var pedestal_root: Node2D
var gate_root: Node2D
var feedback_font: FontFile

@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var player: CharacterBody2D = $PlayerModel
@onready var player_spawn: Marker2D = $player_spawn
@onready var shadow: CanvasModulate = $Shadow
@onready var dialog_box: CanvasLayer = $DialogBox
@onready var dialog_text: Label = $DialogBox/Panel/MarginContainer/Text
@onready var dialog_animation: AnimationPlayer = $DialogBox/Panel/AnimationPlayer


func _ready() -> void:
	feedback_font = load(FEEDBACK_FONT_PATH) as FontFile
	shadow.color = Color(0.07, 0.09, 0.13, 1.0)

	_clear_legacy_hub_content()
	_prepare_runtime_roots()
	_prepare_player()
	_progress().enter_hub()
	_ensure_baseline_progression()
	_build_chapter_hub()
	await get_tree().process_frame
	_show_pending_hub_feedback()
	_begin_intro_if_needed()
	ensure_permanent_lumora()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Pause") and pause_menu != null and pause_menu.has_method("toggle_pause"):
		pause_menu.call("toggle_pause")
		return

	if dialog_active and event.is_action_pressed("Interact"):
		_show_next_intro_line()


func _prepare_player() -> void:
	if player == null:
		return
	player.global_position = player_spawn.global_position
	player.velocity = Vector2.ZERO


func _prepare_runtime_roots() -> void:
	var existing_runtime: Node = get_node_or_null("HubRuntime")
	if existing_runtime != null:
		existing_runtime.queue_free()

	hub_runtime = Node2D.new()
	hub_runtime.name = "HubRuntime"
	add_child(hub_runtime)

	bridge_root = Node2D.new()
	bridge_root.name = "Bridge"
	hub_runtime.add_child(bridge_root)

	pedestal_root = Node2D.new()
	pedestal_root.name = "Pedestals"
	hub_runtime.add_child(pedestal_root)

	gate_root = Node2D.new()
	gate_root.name = "Gates"
	hub_runtime.add_child(gate_root)


func _clear_legacy_hub_content() -> void:
	for legacy_path: String in LEGACY_NODE_PATHS:
		var node: Node = get_node_or_null(legacy_path)
		if node != null:
			node.queue_free()


func _build_chapter_hub() -> void:
	var progress: Node = _progress()
	var unlocked_count: int = progress.get_unlocked_chapter_count()
	var visible_anchors: Array[Vector2] = []
	for chapter_index: int in range(1, ChapterContent.get_chapter_count() + 1):
		var slot_index: int = chapter_index - 1
		if slot_index >= DOOR_POSITIONS.size():
			break

		var is_visible: bool = chapter_index <= unlocked_count
		if not is_visible:
			continue

		var anchor: Vector2 = DOOR_POSITIONS[slot_index]
		var meta: Dictionary = ChapterContent.get_chapter_meta(chapter_index)
		var accent: Color = meta.get("accent", Color(0.7, 0.86, 1.0, 1.0)) as Color
		var is_completed: bool = progress.is_chapter_completed(chapter_index)
		visible_anchors.append(anchor)
		_spawn_gate_pedestal(anchor, accent, is_visible, is_completed, chapter_index)
		_spawn_chapter_gate(anchor, meta, chapter_index, is_completed)

	if not visible_anchors.is_empty():
		var first_anchor: Vector2 = visible_anchors[0]
		var last_anchor: Vector2 = visible_anchors[visible_anchors.size() - 1]
		_spawn_hub_walkway(player_spawn.global_position.x - 96.0, first_anchor.x + 12.0, true)
		_spawn_hub_walkway(first_anchor.x - HUB_WALKWAY_MARGIN, last_anchor.x + HUB_WALKWAY_MARGIN, false)

	_spawn_hub_focus_banner(unlocked_count)


func _spawn_gate_pedestal(anchor: Vector2, accent: Color, is_active: bool, is_completed: bool, chapter_index: int) -> void:
	var pedestal := Node2D.new()
	pedestal.position = anchor
	pedestal_root.add_child(pedestal)

	var shadow_poly := Polygon2D.new()
	shadow_poly.position = Vector2(10.0, 46.0)
	shadow_poly.color = Color(0.0, 0.0, 0.0, 0.18 if is_active else 0.12)
	shadow_poly.polygon = PackedVector2Array([
		Vector2(-132.0, -20.0),
		Vector2(132.0, -20.0),
		Vector2(164.0, 24.0),
		Vector2(-164.0, 24.0)
	])
	pedestal.add_child(shadow_poly)

	var base_poly := Polygon2D.new()
	base_poly.color = Color(0.14, 0.18, 0.22, 1.0) if is_active else Color(0.09, 0.11, 0.14, 1.0)
	base_poly.polygon = PackedVector2Array([
		Vector2(-124.0, 8.0),
		Vector2(124.0, 8.0),
		Vector2(146.0, 54.0),
		Vector2(-146.0, 54.0)
	])
	pedestal.add_child(base_poly)

	if is_active:
		var collider_body := StaticBody2D.new()
		collider_body.position = Vector2(-140.0, 8.0)
		collider_body.collision_layer = PLAYER_WORLD_COLLISION_LAYER
		pedestal.add_child(collider_body)

		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(280.0, 40.0)
		collider.shape = shape
		collider.position = Vector2(shape.size.x * 0.5, shape.size.y * 0.5)
		collider_body.add_child(collider)

	var top_line := Line2D.new()
	top_line.width = 5.0
	top_line.default_color = accent.darkened(0.18).lerp(Color(0.42, 0.46, 0.44, 1.0), 0.52) if is_active else Color(0.24, 0.28, 0.34, 0.95)
	top_line.points = PackedVector2Array([Vector2(-112.0, 10.0), Vector2(112.0, 10.0)])
	pedestal.add_child(top_line)

	var rune_glow := PointLight2D.new()
	rune_glow.position = Vector2(0.0, -34.0)
	rune_glow.texture = load("res://Assets/Light/torch_light.png") as Texture2D
	rune_glow.texture_scale = 0.72 if is_active else 0.48
	rune_glow.energy = 0.12 if is_active else 0.04
	rune_glow.color = accent.lerp(Color(0.78, 0.82, 0.72, 1.0), 0.64) if is_active else Color(0.22, 0.24, 0.28, 1.0)
	pedestal.add_child(rune_glow)

	var rune := Label.new()
	rune.position = Vector2(-70.0, -92.0)
	rune.size = Vector2(140.0, 24.0)
	rune.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rune.text = "TOR %s" % SkillProgression._roman_or_number(chapter_index)
	rune.add_theme_font_size_override("font_size", 13)
	rune.add_theme_color_override("font_color", accent.lightened(0.18) if is_active else Color(0.32, 0.34, 0.38, 0.92))
	rune.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	rune.add_theme_constant_override("outline_size", 4)
	if feedback_font != null:
		rune.add_theme_font_override("font", feedback_font)
	pedestal.add_child(rune)

	if is_completed:
		var crown := Label.new()
		crown.position = Vector2(-68.0, -118.0)
		crown.size = Vector2(136.0, 22.0)
		crown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		crown.text = "GEMEISTERT"
		crown.add_theme_font_size_override("font_size", 11)
		crown.add_theme_color_override("font_color", Color(1.0, 0.9, 0.46, 0.96))
		crown.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
		crown.add_theme_constant_override("outline_size", 4)
		if feedback_font != null:
			crown.add_theme_font_override("font", feedback_font)
		pedestal.add_child(crown)


func _spawn_chapter_gate(anchor: Vector2, meta: Dictionary, chapter_index: int, is_completed: bool) -> void:
	var gate: Node2D = CHAPTER_GATE_SCENE.instantiate() as Node2D
	if gate == null:
		return

	gate_root.add_child(gate)
	gate.global_position = anchor + Vector2(0.0, -34.0)
	gate.call("configure_chapter_gate", chapter_index, meta, true, is_completed)


func _spawn_hub_walkway(from_x: float, to_x: float, is_entry_span: bool) -> void:
	var left_x: float = minf(from_x, to_x)
	var right_x: float = maxf(from_x, to_x)
	var width: float = maxf(right_x - left_x, 96.0)
	var walkway := Node2D.new()
	bridge_root.add_child(walkway)

	var body := StaticBody2D.new()
	body.position = Vector2(left_x, HUB_WALKWAY_TOP_Y)
	body.collision_layer = PLAYER_WORLD_COLLISION_LAYER
	walkway.add_child(body)

	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, HUB_WALKWAY_HEIGHT)
	collider.shape = shape
	collider.position = Vector2(width * 0.5, HUB_WALKWAY_HEIGHT * 0.5)
	body.add_child(collider)

	var fill := Polygon2D.new()
	fill.position = Vector2(left_x, HUB_WALKWAY_TOP_Y)
	fill.color = Color(0.12, 0.15, 0.19, 0.96) if not is_entry_span else Color(0.12, 0.16, 0.18, 0.98)
	fill.polygon = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(width, 0.0),
		Vector2(width + 30.0, HUB_WALKWAY_HEIGHT),
		Vector2(-30.0, HUB_WALKWAY_HEIGHT)
	])
	walkway.add_child(fill)

	var glow_line := Line2D.new()
	glow_line.position = Vector2(left_x, HUB_WALKWAY_TOP_Y + 3.0)
	glow_line.width = 6.0
	glow_line.default_color = Color(0.34, 0.4, 0.38, 0.18) if not is_entry_span else Color(0.38, 0.46, 0.38, 0.16)
	glow_line.points = PackedVector2Array([Vector2(0.0, 0.0), Vector2(width, 0.0)])
	walkway.add_child(glow_line)

	var under_shadow := Polygon2D.new()
	under_shadow.position = Vector2(left_x, HUB_WALKWAY_TOP_Y + HUB_WALKWAY_HEIGHT - 4.0)
	under_shadow.color = Color(0.0, 0.0, 0.0, 0.18)
	under_shadow.polygon = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(width, 0.0),
		Vector2(width - 18.0, 14.0),
		Vector2(18.0, 14.0)
	])
	walkway.add_child(under_shadow)


func _spawn_hub_focus_banner(unlocked_count: int) -> void:
	if player == null or not player.has_method("_show_feedback_banner"):
		return
	if unlocked_count <= 1 and not _progress().has_seen("hub_chapter_one_banner"):
		_progress().mark_seen("hub_chapter_one_banner")
		var chapter_one_meta: Dictionary = ChapterContent.get_chapter_meta(1)
		var accent: Color = chapter_one_meta.get("accent", Color(0.52, 0.84, 0.74, 1.0)) as Color
		player.call("_show_feedback_banner", "Kapitel I ist bereit", accent, 0.55)


func _ensure_baseline_progression() -> void:
	if player == null or not player.has_method("grant_skill"):
		return

	var progress: Node = _progress()
	var already_marked: bool = progress.has_seen("hub_baseline_glow")
	var has_glow: bool = bool(player.get("has_glow_skill"))
	if not has_glow:
		player.call("grant_skill", "glow", false)

	if already_marked:
		return

	progress.mark_seen("hub_baseline_glow")
	progress.register_completion_marker("hub_awakening")

	if player.has_method("_show_feedback_banner"):
		player.call("_show_feedback_banner", "GLOW ERWACHT", Color(0.62, 0.96, 1.0, 1.0), 0.58)
	if player.has_method("_show_feedback_toast"):
		player.call("_show_feedback_toast", "Joeys Kern leuchtet jetzt. Mit F steuerst du das Licht der Hoehle.", "reward", null)


func _show_pending_hub_feedback() -> void:
	if player == null:
		return

	var progress: Node = _progress()
	var banner: String = progress.consume_hub_banner()
	if not banner.is_empty() and player.has_method("_show_feedback_banner"):
		player.call("_show_feedback_banner", banner, Color(1.0, 0.88, 0.44, 1.0), 0.68)

	var toast: String = progress.consume_hub_toast()
	if not toast.is_empty() and player.has_method("_show_feedback_toast"):
		player.call("_show_feedback_toast", toast, "reward", null)


func _begin_intro_if_needed() -> void:
	if dialog_box == null:
		return

	if _load_intro_state():
		dialog_box.visible = false
		return

	dialog_box.visible = true
	dialog_active = true
	current_line = 0
	_show_next_intro_line()


func _show_next_intro_line() -> void:
	if dialog_box == null or dialog_text == null:
		return

	if current_line >= intro_lines.size():
		_finish_intro()
		return

	dialog_text.text = intro_lines[current_line]
	if dialog_animation != null:
		dialog_animation.play("text_appear")
	current_line += 1


func _finish_intro() -> void:
	dialog_active = false
	if dialog_box != null:
		dialog_box.visible = false
	_save_intro_state(true)


func _save_intro_state(completed: bool) -> void:
	var config := ConfigFile.new()
	config.set_value(HUB_INTRO_SECTION, HUB_INTRO_KEY, completed)
	config.save(CONFIG_PATH)


func _load_intro_state() -> bool:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return false
	return bool(config.get_value(HUB_INTRO_SECTION, HUB_INTRO_KEY, false))


func _on_pause_menu_go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _on_canvas_layer_go_to_main_menu() -> void:
	_on_pause_menu_go_to_main_menu()


func ensure_permanent_lumora() -> void:
	var save_path := "user://lumora_save_data.save"
	if not FileAccess.file_exists(save_path):
		return

	var lumoras: Array[Node] = get_tree().get_nodes_in_group("lumora")
	for lumora_node: Node in lumoras:
		if bool(lumora_node.get("is_permanent")):
			return

	_spawn_permanent_lumora_from_save()


func _spawn_permanent_lumora_from_save() -> void:
	var lumora_scene: PackedScene = load("res://Scenes/Stars/lumora.tscn") as PackedScene
	if lumora_scene == null:
		return

	var lumora: Node2D = lumora_scene.instantiate() as Node2D
	if lumora == null:
		return

	add_child(lumora)
	if player != null:
		lumora.global_position = player.global_position + Vector2(50.0, 0.0)
		if lumora.has_method("assign_player"):
			lumora.call("assign_player", player)

	lumora.set("is_permanent", true)
	lumora.set("is_caught", true)


func _progress() -> Node:
	return get_node("/root/ChapterProgress")
