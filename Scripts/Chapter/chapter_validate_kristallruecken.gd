extends SceneTree

const BOSS_SCENE := preload("res://Scenes/Chapter/Enemies/kristallruecken.tscn")


func _initialize() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var mock_player := CharacterBody2D.new()
	mock_player.name = "MockPlayer"
	mock_player.add_to_group("players")
	mock_player.global_position = Vector2(178.0, 0.0)
	world.add_child(mock_player)
	var boss := BOSS_SCENE.instantiate() as CharacterBody2D
	world.add_child(boss)
	boss.global_position = Vector2.ZERO
	await process_frame
	boss.call("take_damage", 1, Vector2.RIGHT, false)
	var life_bar := boss.get_node_or_null("HealthBar") as ProgressBar
	var life_bar_ok := life_bar != null and life_bar.visible
	boss.call("_set_state", 3) # ground telegraph
	await create_timer(1.25).timeout
	var vein_count := _count_named(world, "CrystalVein")
	boss.call("_set_state", 5) # magic charge
	await create_timer(0.75).timeout
	var orb_count := _count_named(world, "CrystalOrb")
	boss.call("_set_state", 1) # back to chase before applying lethal damage
	# The public damage route also asserts attack shutdown and full death animation.
	boss.call("take_damage", 9999, Vector2.LEFT, false)
	await create_timer(1.2).timeout
	var death_done := bool(boss.get("death_complete"))
	print("KRISTALLRUECKEN_TEST life_bar=%s vein=%d orb=%d death=%s" % [str(life_bar_ok), vein_count, orb_count, str(death_done)])
	quit(0 if life_bar_ok and vein_count >= 1 and orb_count >= 1 and death_done else 1)


func _count_named(node: Node, expected: String) -> int:
	var total := 1 if node.name == expected else 0
	for child in node.get_children():
		total += _count_named(child, expected)
	return total
