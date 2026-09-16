extends SceneTree

const CHAPTER_LEVEL_SCENE := preload("res://Scenes/Chapter/chapter_level.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("chapter_qa_mode", true)
	root.size = Vector2i(1600, 900)
	var progress: Node = root.get_node("/root/ChapterProgress")
	progress.reset_progress()
	progress.active_chapter = 1
	progress.active_level_index = 7
	var level := CHAPTER_LEVEL_SCENE.instantiate()
	root.add_child(level)
	for _frame in range(24):
		await process_frame
		await physics_frame
	var enemy_root := level.get_node_or_null("EnemyRoot")
	var boss: Node2D
	if enemy_root != null:
		for enemy: Node in enemy_root.get_children():
			if enemy.name == "Kristallruecken":
				boss = enemy as Node2D
				break
	var gate := level.get("exit_gate") as Node2D
	var player := level.get("player") as CharacterBody2D
	if boss == null or gate == null or player == null or gate.visible:
		push_error("BOSS_ENCOUNTER_FAIL setup")
		quit(1)
		return
	player.set_physics_process(false)
	# This is a visual/integration fixture; disabling its body prevents the real
	# player death/respawn flow from replacing the test scene mid-encounter.
	player.collision_layer = 0
	player.collision_mask = 0
	player.global_position = boss.global_position + Vector2(-132.0, -12.0)
	boss.call("take_damage", 1, Vector2.LEFT, false)
	for _frame in range(4):
		await process_frame
	var health_bar := boss.get_node_or_null("HealthBar") as ProgressBar
	var health_visible := health_bar != null and health_bar.visible
	boss.call("_set_state", 3)
	await create_timer(1.2).timeout
	var veins := _count_named(level, "CrystalVein")
	boss.call("_set_state", 5)
	await create_timer(0.8).timeout
	var orbs := _count_named(level, "CrystalOrb")
	boss.call("take_damage", 9999, Vector2.LEFT, false)
	await create_timer(2.6).timeout
	var trail := level.get("boss_energy_trail") as Node2D
	var portal_ready := gate.visible and not bool(gate.get("is_arriving"))
	var trail_particles := int(trail.get("particles").size()) if trail != null else 0
	var success := health_visible and veins >= 1 and orbs >= 1 and portal_ready and trail_particles > 0
	var result := "BOSS_ENCOUNTER_TEST health_bar=%s veins=%d orbs=%d portal=%s trail_particles=%d" % [str(health_visible), veins, orbs, str(portal_ready), trail_particles]
	FileAccess.open("user://kristallruecken_encounter_result.txt", FileAccess.WRITE).store_string(result)
	print(result)
	level.queue_free()
	await process_frame
	quit(0 if success else 1)


func _count_named(node: Node, expected: String) -> int:
	var count := 1 if node.name == expected else 0
	for child in node.get_children():
		count += _count_named(child, expected)
	return count
