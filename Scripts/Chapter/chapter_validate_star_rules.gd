extends SceneTree

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")
const StarCatalog := preload("res://Scripts/star_catalog.gd")
const StarManager := preload("res://Scripts/Stars/star_manager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("chapter_qa_mode", true)
	var progress: Node = root.get_node("/root/ChapterProgress")
	progress.reset_progress()
	progress.active_chapter = 1
	progress.active_level_index = 0
	var level: Node = CHAPTER_LEVEL_SCENE.instantiate()
	root.add_child(level)
	for _frame: int in range(3):
		await process_frame
		await physics_frame

	var player: CharacterBody2D = level.get_node_or_null("PlayerModel") as CharacterBody2D
	var inventory: Inv = player.get("inv") as Inv
	var star_slot: InvSlot = inventory.get_equipped_slot("star_1")
	star_slot.item = StarCatalog.get_item("lumora")
	star_slot.amount = 1
	var manager := StarManager.new()
	level.add_child(manager)
	manager.setup(player, inventory)
	for _frame: int in range(3):
		await process_frame

	var companion_count: int = (manager.get("active_companions") as Dictionary).size()
	var has_lumora_companion: bool = (manager.get("active_companions") as Dictionary).has("lumora")
	var has_encounter_timer: bool = manager.get_node_or_null("StarSpawnTimer") != null
	var status := "PASS" if has_lumora_companion and not has_encounter_timer else "FAIL"
	print("CHAPTER_STAR_RULES companions=%d lumora=%s encounter_timer=%s status=%s" % [companion_count, str(has_lumora_companion), str(has_encounter_timer), status])
	level.queue_free()
	await process_frame
	quit(0 if status == "PASS" else 1)
