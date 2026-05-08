extends Node

class_name StarManager

const StarCatalog := preload("res://Scripts/star_catalog.gd")
const StarEncounter := preload("res://Scripts/Stars/star_encounter.gd")

const LEGACY_LUMORA_SAVE_PATH := "user://lumora_save_data.save"
const LUMORA_RUNTIME_SAVE_PATH := "user://lumora_runtime_equipped.save"
const STAR_ENCOUNTER_MIN_DISTANCE := 260.0
const STAR_ENCOUNTER_MAX_DISTANCE := 520.0
const STAR_ENCOUNTER_HEIGHT := 82.0
const STAR_SPAWN_INTERVAL := 18.0

var player: CharacterBody2D
var inv: Inv
var active_encounter: StarEncounter
var active_companions: Dictionary = {}
var spawn_timer: Timer
var is_initialized := false


func setup(player_node: CharacterBody2D, inventory: Inv) -> void:
	player = player_node
	inv = inventory
	if is_inside_tree():
		_initialize()


func _ready() -> void:
	if player == null and get_parent() is CharacterBody2D:
		player = get_parent() as CharacterBody2D
	_initialize()


func _exit_tree() -> void:
	_clear_active_encounter()
	for star_id in active_companions.keys():
		_despawn_companion(String(star_id))


func _initialize() -> void:
	if is_initialized or player == null or inv == null:
		return
	is_initialized = true
	randomize()
	inv.update.connect(_refresh_from_inventory)
	_migrate_legacy_lumora_unlock()
	_setup_spawn_timer()
	_refresh_from_inventory()


func _setup_spawn_timer() -> void:
	if spawn_timer != null and is_instance_valid(spawn_timer):
		return
	spawn_timer = Timer.new()
	spawn_timer.name = "StarSpawnTimer"
	spawn_timer.wait_time = STAR_SPAWN_INTERVAL
	spawn_timer.autostart = true
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_try_spawn_random_star_encounter)
	add_child(spawn_timer)
	spawn_timer.start()


func _refresh_from_inventory() -> void:
	_refresh_active_companions()
	if active_encounter != null and is_instance_valid(active_encounter) and inv.contains_item(active_encounter.star_id):
		_clear_active_encounter()


func _refresh_active_companions() -> void:
	if player == null or inv == null:
		return

	var desired_star_ids: Array[String] = []
	for slot_name in inv.get_equipment_slot_names():
		if not slot_name.begins_with("star_"):
			continue
		var item := inv.get_equipped_item(slot_name)
		if item and StarCatalog.has_star(item.name) and not desired_star_ids.has(item.name):
			desired_star_ids.append(item.name)

	for star_id in active_companions.keys():
		var existing_id := String(star_id)
		if not desired_star_ids.has(existing_id):
			_despawn_companion(existing_id)

	for star_id in desired_star_ids:
		if not active_companions.has(star_id):
			_spawn_companion(star_id)

	player.lumora = active_companions.get("lumora", null) as CharacterBody2D


func _spawn_companion(star_id: String) -> void:
	var scene := StarCatalog.get_scene(star_id)
	if scene == null or player == null:
		return

	var companion := scene.instantiate() as Node2D
	if companion == null:
		return

	if star_id == "lumora":
		companion.set("save_path", LUMORA_RUNTIME_SAVE_PATH)
		companion.set("is_permanent", true)
		companion.set("is_caught", true)
		companion.set("player_path", player.get_path())
	else:
		companion.set("player_path", player.get_path())

	var spawn_position := player.global_position + Vector2(64.0 + active_companions.size() * 18.0, -72.0)
	_attach_companion(companion, spawn_position)
	active_companions[star_id] = companion


func _despawn_companion(star_id: String) -> void:
	if not active_companions.has(star_id):
		return
	var companion := active_companions[star_id] as Node
	active_companions.erase(star_id)
	if companion != null and is_instance_valid(companion):
		companion.queue_free()


func _try_spawn_random_star_encounter() -> void:
	if player == null or inv == null:
		return
	if active_encounter != null and is_instance_valid(active_encounter):
		return
	if player.has_method("_is_gameplay_input_blocked") and bool(player.call("_is_gameplay_input_blocked")):
		return

	var missing_star_ids := _get_missing_star_ids()
	if missing_star_ids.is_empty():
		return

	var spawn_position := _find_spawn_position()
	if spawn_position == Vector2.ZERO:
		return

	var star_id := missing_star_ids[randi() % missing_star_ids.size()]
	active_encounter = StarEncounter.new()
	active_encounter.name = "StarEncounter_%s" % star_id
	active_encounter.global_position = spawn_position
	active_encounter.configure(star_id, player)
	active_encounter.captured.connect(_on_star_captured)
	_get_scene_root().add_child(active_encounter)

	if player.has_method("_show_feedback_toast"):
		player.call("_show_feedback_toast", "Ein Stern wurde in der Naehe gesichtet.", "reward", null)


func _find_spawn_position() -> Vector2:
	if player == null:
		return Vector2.ZERO

	var space_state := player.get_world_2d().direct_space_state
	for _attempt in range(16):
		var direction := -1.0 if randf() < 0.5 else 1.0
		var horizontal_distance := randf_range(STAR_ENCOUNTER_MIN_DISTANCE, STAR_ENCOUNTER_MAX_DISTANCE) * direction
		var x_position := player.global_position.x + horizontal_distance
		var ray_from := Vector2(x_position, player.global_position.y - 260.0)
		var ray_to := Vector2(x_position, player.global_position.y + 340.0)
		var query := PhysicsRayQueryParameters2D.create(ray_from, ray_to)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			continue
		var spawn_position: Vector2 = result.position + Vector2(0.0, -STAR_ENCOUNTER_HEIGHT)
		if spawn_position.distance_to(player.global_position) < STAR_ENCOUNTER_MIN_DISTANCE * 0.8:
			continue
		return spawn_position

	return Vector2.ZERO


func _on_star_captured(star_id: String) -> void:
	_clear_active_encounter()
	if inv.contains_item(star_id):
		return

	var item := StarCatalog.get_item(star_id)
	if item == null:
		return

	var inserted := inv.Insert(item)
	if not inserted:
		var fallback_slot_name := _find_empty_star_slot()
		if not fallback_slot_name.is_empty():
			var slot := inv.get_equipped_slot(fallback_slot_name)
			slot.item = item
			slot.amount = 1
			inv.notify_changed()
			inserted = true

	if player.has_method("_show_feedback_banner"):
		player.call("_show_feedback_banner", "%s GEFANGEN" % item.get_display_name().to_upper(), Color(1.0, 0.92, 0.52, 1.0), 0.55)
	if player.has_method("_show_feedback_toast"):
		var toast_text := "%s kann jetzt in den Stars-Slots ausgeruestet werden." % item.get_display_name()
		if not inserted:
			toast_text = "%s wurde entdeckt, aber dein Inventar war voll." % item.get_display_name()
		player.call("_show_feedback_toast", toast_text, "reward", null)


func _get_missing_star_ids() -> Array[String]:
	var missing_star_ids: Array[String] = []
	for star_id in StarCatalog.get_all_star_ids():
		if not inv.contains_item(star_id):
			missing_star_ids.append(star_id)
	return missing_star_ids


func _find_empty_star_slot() -> String:
	for slot_name in inv.get_equipment_slot_names():
		if slot_name.begins_with("star_") and inv.get_equipped_item(slot_name) == null:
			return slot_name
	return ""


func _clear_active_encounter() -> void:
	if active_encounter != null and is_instance_valid(active_encounter):
		active_encounter.queue_free()
	active_encounter = null


func _migrate_legacy_lumora_unlock() -> void:
	if inv == null or inv.contains_item("lumora"):
		return
	if not FileAccess.file_exists(LEGACY_LUMORA_SAVE_PATH):
		return

	var inserted := inv.Insert(StarCatalog.get_item("lumora"))
	if not inserted:
		var slot_name := _find_empty_star_slot()
		if not slot_name.is_empty():
			var slot := inv.get_equipped_slot(slot_name)
			slot.item = StarCatalog.get_item("lumora")
			slot.amount = 1
			inv.notify_changed()


func _get_scene_root() -> Node:
	if player != null and player.get_parent() != null:
		return player.get_parent()
	return get_tree().current_scene if get_tree() != null else self


func _attach_companion(companion: Node2D, spawn_position: Vector2) -> void:
	var scene_root := _get_scene_root()
	if scene_root == null:
		return

	companion.global_position = spawn_position
	scene_root.call_deferred("add_child", companion)
	companion.call_deferred("add_to_group", "active_star_companion")
	if companion.has_method("assign_player"):
		companion.call_deferred("assign_player", player)
