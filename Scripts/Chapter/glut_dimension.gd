extends Node2D

const PLAYER_SCENE := preload("res://Scenes/player.tscn")
const GLUTKAEFER_SCENE := preload("res://Scenes/Chapter/Enemies/glutkaefer.tscn")
const GLUT_QUEST_GATE_SCENE := preload("res://Scenes/Chapter/glut_quest_gate.tscn")
const ItemRegistry := preload("res://Scripts/item_registry.gd")
const QUEST_ENEMY_COUNT := 12

var player: CharacterBody2D
var enemy_root: Node2D
var quest_gate: Node2D
var defeated_count := 0
var quest_label: Label


func _ready() -> void:
	_build_arena()
	_spawn_player()
	_spawn_quest_enemies()
	_build_quest_ui()
	call_deferred("_restore_lumora_reward_if_needed")
	queue_redraw()


func _draw() -> void:
	# The first pass deliberately stays tile-free, but still reads as its own
	# playable space until bespoke Glutdimension tiles arrive.
	draw_rect(Rect2(-320, -300, 3360, 1260), Color(0.09, 0.018, 0.015, 1.0), true)
	draw_circle(Vector2(1520, 280), 480.0, Color(0.55, 0.08, 0.015, 0.15))
	draw_circle(Vector2(1520, 350), 250.0, Color(1.0, 0.20, 0.04, 0.12))
	draw_rect(Rect2(-80, 620, 3160, 180), Color(0.17, 0.035, 0.02, 1.0), true)
	draw_rect(Rect2(-80, 620, 3160, 10), Color(1.0, 0.28, 0.08, 0.94), true)
	for column in range(0, 23):
		var x := 80.0 + column * 132.0
		draw_line(Vector2(x, 630), Vector2(x - 34, 780), Color(0.4, 0.07, 0.025, 0.9), 3.0)


func _build_arena() -> void:
	_add_wall(Vector2(1500, 670), Vector2(3160, 100))
	_add_wall(Vector2(-38, 280), Vector2(76, 780))
	_add_wall(Vector2(3038, 280), Vector2(76, 780))
	enemy_root = Node2D.new()
	enemy_root.name = "GlutkaeferSchwarm"
	add_child(enemy_root)
	quest_gate = GLUT_QUEST_GATE_SCENE.instantiate() as Node2D
	add_child(quest_gate)
	quest_gate.position = Vector2(2880, 620)


func _add_wall(center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	# Player bodies listen on layer 2. The old layer-1 floor was rendered but
	# physically invisible to the player, so every spawn fell through it.
	wall.collision_layer = 2
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = center
	add_child(wall)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as CharacterBody2D
	if player == null:
		return
	add_child(player)
	player.global_position = Vector2(150, 530)
	player.set_world_fall_death_y(920.0)
	var progress := get_node_or_null("/root/ChapterProgress")
	if progress != null and progress.has_method("consume_runtime_player_state") and player.has_method("restore_portal_state"):
		var portal_state: Dictionary = progress.call("consume_runtime_player_state") as Dictionary
		if not portal_state.is_empty():
			player.call("restore_portal_state", portal_state)
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.limit_left = -80
		camera.limit_top = -180
		camera.limit_right = 3040
		camera.limit_bottom = 840


func _spawn_quest_enemies() -> void:
	for index in range(QUEST_ENEMY_COUNT):
		var beetle := GLUTKAEFER_SCENE.instantiate() as Node2D
		if beetle == null:
			continue
		enemy_root.add_child(beetle)
		var lane := index % 4
		var row := index / 4
		beetle.global_position = Vector2(480.0 + lane * 580.0 + row * 70.0, 470.0 - row * 30.0)
		beetle.set("drops_glut_schluessel", false)
		beetle.connect("defeated", Callable(self, "_on_glutkaefer_defeated"), CONNECT_ONE_SHOT)


func _build_quest_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 104)
	panel.size = Vector2(360, 66)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.025, 0.015, 0.9)
	style.border_color = Color(1.0, 0.32, 0.09, 0.96)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	quest_label = Label.new()
	quest_label.add_theme_font_size_override("font_size", 16)
	quest_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.55, 1.0))
	quest_label.add_theme_color_override("font_outline_color", Color(0.03, 0.0, 0.0, 1.0))
	quest_label.add_theme_constant_override("outline_size", 3)
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(quest_label)
	_update_quest_label()


func _on_glutkaefer_defeated() -> void:
	defeated_count += 1
	_update_quest_label()
	if defeated_count < QUEST_ENEMY_COUNT:
		return
	_ensure_lumora_reward()
	quest_gate.call("set_unlocked", true)
	if player != null and player.has_method("_show_feedback_toast"):
		player.call("_show_feedback_toast", "Die Glutkaefer sind besiegt. Lumora ist erschienen – dann oeffnet sich das Tor.", "reward", null)
	if player != null and player.has_method("_show_feedback_banner"):
		player.call("_show_feedback_banner", "LUMORA ERSCHIENEN", Color(0.76, 0.90, 1.0, 1.0), 0.65)


func _ensure_lumora_reward() -> void:
	if _player_or_world_has_lumora():
		return
	var progress := get_node_or_null("/root/ChapterProgress")
	if progress != null and progress.has_method("award_reward"):
		progress.call("award_reward", "glut_dimension_lumora_rewarded")
	var pickup := ItemRegistry.create_pickup_for_item("lumora")
	if pickup == null:
		push_error("Glutdimension could not create Lumora reward.")
		return
	pickup.set("is_persistent_reward", true)
	add_child(pickup)
	pickup.global_position = Vector2(2600.0, 510.0)


func _restore_lumora_reward_if_needed() -> void:
	var progress := get_node_or_null("/root/ChapterProgress")
	if progress != null and progress.has_method("has_reward") and bool(progress.call("has_reward", "glut_dimension_lumora_rewarded")):
		_ensure_lumora_reward()


func _player_or_world_has_lumora() -> bool:
	if player != null:
		var inventory: Variant = player.get("inv")
		if inventory != null and inventory.has_method("contains_item") and bool(inventory.call("contains_item", "lumora")):
			return true
	for pickup: Node in get_tree().get_nodes_in_group("world_pickups"):
		var item: Variant = pickup.get("item")
		if item != null and str(item.get("name")) == "lumora":
			return true
	return false


func _update_quest_label() -> void:
	if quest_label == null:
		return
	if defeated_count >= QUEST_ENEMY_COUNT:
		quest_label.text = "GLUTQUEST\nTor offen – Interagieren"
	else:
		quest_label.text = "GLUTQUEST\nGlutkaefer besiegen: %d / %d" % [defeated_count, QUEST_ENEMY_COUNT]
