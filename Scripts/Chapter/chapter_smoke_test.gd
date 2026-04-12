extends SceneTree

const HUB_SCENE := preload("res://Scenes/Game.tscn")
const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")
const ChapterContent := preload("res://Scripts/Chapter/chapter_content.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_progress().reset_progress()
	await process_frame

	var initial_hub: Node = HUB_SCENE.instantiate()
	root.add_child(initial_hub)
	await process_frame

	var initial_gate_root: Node = initial_hub.get_node("HubRuntime/Gates")
	print("SMOKE initial_gates=", initial_gate_root.get_child_count())
	initial_hub.queue_free()
	await process_frame

	var chapter_started: bool = _progress().start_chapter(1)
	print("SMOKE chapter_started=", chapter_started)
	print("SMOKE active_level_title=", str(_progress().get_active_level_data().get("title", "")))

	var generated_level: Node = CHAPTER_LEVEL_SCENE.instantiate()
	root.add_child(generated_level)
	await process_frame
	print("SMOKE generated_terrain_nodes=", generated_level.get_node("TerrainRoot").get_child_count())
	print("SMOKE generated_enemy_nodes=", generated_level.get_node("EnemyRoot").get_child_count())
	print("SMOKE generated_gate_nodes=", generated_level.get_node("GateRoot").get_child_count())
	generated_level.queue_free()
	await process_frame

	var level_count: int = ChapterContent.get_level_count(1)
	for _step: int in range(level_count):
		if _progress().active_chapter != 1:
			break
		_progress().complete_active_level()

	print("SMOKE chapter1_completed=", _progress().is_chapter_completed(1))
	print("SMOKE unlocked_chapters=", _progress().get_unlocked_chapter_count())
	print("SMOKE active_chapter=", _progress().active_chapter)

	var completed_hub: Node = HUB_SCENE.instantiate()
	root.add_child(completed_hub)
	await process_frame

	var completed_gate_root: Node = completed_hub.get_node("HubRuntime/Gates")
	print("SMOKE post_chapter_gates=", completed_gate_root.get_child_count())
	completed_hub.queue_free()
	await process_frame

	quit()


func _progress() -> Node:
	return root.get_node("/root/ChapterProgress")
