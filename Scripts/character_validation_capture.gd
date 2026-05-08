extends SceneTree

const LEVEL_SCENE := preload("res://Scenes/Game.tscn")
const CharacterCatalog := preload("res://Scripts/character_catalog.gd")

const OUTPUT_DIR := "res://.codex_tmp/screens"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_ensure_output_directory()
	_write_transform_skill_state()
	await _capture_hero_transform_flow()
	print("Hero transform validation screenshots saved to %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _capture_hero_transform_flow() -> void:
	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)
	await _settle_frames(24)

	var player := level.get_node_or_null("PlayerModel") as CharacterBody2D
	if player == null:
		push_error("PlayerModel konnte fuer die Hero-Transform-Validierung nicht gefunden werden.")
		quit(1)
		return

	if not bool(player.get("has_hero_form_skill")):
		push_error("Hero Form Debug-Freischaltung wurde nicht aktiviert.")
		quit(1)
		return

	if String(player.call("get_current_character_id")) != CharacterCatalog.SLIME_ID:
		push_error("Player startet nicht als Joey/Slime.")
		quit(1)
		return

	_save_viewport_png("transform_joey_start.png")

	player.call("toggle_hero_form")
	await _settle_frames(18)
	_save_viewport_png("transform_morph_mid.png")
	await _settle_frames(42)

	if String(player.call("get_current_character_id")) != CharacterCatalog.MALE_HERO_ID:
		push_error("Transformation hat nicht in die Hero-Form gewechselt.")
		quit(1)
		return

	var collision_shape := player.get_node_or_null("ColisionArea") as CollisionShape2D
	if collision_shape == null or not (collision_shape.shape is RectangleShape2D):
		push_error("Hero CollisionShape2D wurde nicht gefunden.")
		quit(1)
		return

	var standing_size := (collision_shape.shape as RectangleShape2D).size
	if standing_size.y <= standing_size.x:
		push_error("Hero-Hitbox ist nicht humanoid/hoch genug.")
		quit(1)
		return

	_save_viewport_png("transform_hero_idle.png")
	player.set("direction", Vector2.RIGHT)
	player.set("velocity", Vector2(float(player.get("RUN_SPEED")), 0.0))
	player.call("update_facing_direction")
	player.call("update_animations")
	player.call("_update_runtime_character_animation", 0.18)
	await _settle_frames(4)
	_save_viewport_png("transform_hero_run.png")

	var slide_started := bool(player.call("_start_hero_ground_slide", 1.0, true))
	if not slide_started:
		push_error("Hero Ground-Slide konnte nicht gestartet werden.")
		quit(1)
		return
	var slide_size_immediate := (collision_shape.shape as RectangleShape2D).size
	if slide_size_immediate.y >= standing_size.y:
		push_error("Hero Ground-Slide senkt die Hitbox nicht ab.")
		quit(1)
		return
	await _settle_frames(2)
	_save_viewport_png("transform_hero_slide.png")
	await _settle_frames(40)

	await _capture_hero_effect_previews(player)

	player.call("toggle_hero_form")
	await _settle_frames(60)
	if String(player.call("get_current_character_id")) != CharacterCatalog.SLIME_ID:
		push_error("Rueckverwandlung hat nicht zur Joey-Form gewechselt.")
		quit(1)
		return
	_save_viewport_png("transform_back_to_joey.png")

	level.queue_free()
	await _settle_frames(2)


func _capture_hero_effect_previews(player: CharacterBody2D) -> void:
	var preview_anchor := player.global_position
	player.set("velocity", Vector2.ZERO)
	player.set("direction", Vector2.RIGHT)
	player.set("is_facing_left", false)
	player.call("update_facing_direction")

	player.global_position = preview_anchor + Vector2(0.0, -120.0)
	player.set("velocity", Vector2.ZERO)
	player.set("has_double_jump_skill", true)
	player.set("max_air_jumps", 1)
	player.set("air_jumps_available", 1)
	player.call("perform_air_jump")
	await _settle_frames(2)
	_save_viewport_png("transform_hero_air_jump_vfx.png")
	await _settle_frames(16)

	player.global_position = preview_anchor
	player.set("velocity", Vector2.ZERO)
	player.set("fall_distance", 180.0)
	player.set("is_landing", false)
	player.call("play_landing_animation", "landing")
	await _settle_frames(2)
	_save_viewport_png("transform_hero_landing_vfx.png")
	await _settle_frames(18)

	player.global_position = preview_anchor
	player.set("velocity", Vector2.ZERO)
	player.call("sync_attack", 1)
	await _settle_frames(2)
	_save_viewport_png("transform_hero_slash_vfx.png")
	await _settle_frames(16)
	player.set("is_attacking", false)
	var attack_area := player.get_node_or_null("PlayerSprite/AttackSprite/AttackArea") as Area2D
	if attack_area:
		attack_area.monitoring = false

	player.global_position = preview_anchor
	player.set("velocity", Vector2.ZERO)
	player.call("_perform_profile_wall_jump", Vector2(-1.0, 0.0), true)
	await _settle_frames(4)
	_save_viewport_png("transform_hero_wallkick_vfx.png")
	await _settle_frames(18)

	player.global_position = preview_anchor
	player.set("velocity", Vector2.ZERO)
	player.set("is_dashing", false)
	player.set("can_dash", true)
	player.call("dash", Vector2.RIGHT)
	await _settle_frames(2)
	_save_viewport_png("transform_hero_dash_vfx.png")
	await _settle_frames(18)

	player.global_position = preview_anchor
	player.set("velocity", Vector2.ZERO)
	player.call(
		"_spawn_hero_combat_effect",
		"hit",
		player.global_position + Vector2(46.0, -42.0),
		Color(0.92, 1.0, 0.84, 0.92),
		1.05
	)
	await _settle_frames(3)
	_save_viewport_png("transform_hero_hit_vfx.png")
	await _settle_frames(16)


func _write_transform_skill_state() -> void:
	var player_skill_data: Dictionary = {
		"has_glow_skill": true,
		"has_wall_slide_skill": false,
		"has_regeneration_skill": false,
		"has_ult_skill": false,
		"has_double_jump_skill": false,
		"has_wall_run_skill": false,
		"has_dash_skill": false,
		"has_teleport_skill": false,
		"has_mana_shield_skill": false,
		"has_heal_burst_skill": false,
		"has_sticky_form_skill": false,
		"has_hero_form_skill": false,
		"has_thorns_skill": false,
		"has_slime_wings_skill": false,
		"player_level": 1,
	}

	var player_file := FileAccess.open("user://player_skills.save", FileAccess.WRITE)
	if player_file != null:
		player_file.store_var(player_skill_data)
		player_file.close()

	var legacy_skills := {
		"glow": {"unlocked": true},
		"hero_form": {"unlocked": false},
	}
	var legacy_file := FileAccess.open("user://skills.save", FileAccess.WRITE)
	if legacy_file != null:
		legacy_file.store_string(JSON.stringify(legacy_skills))
		legacy_file.close()


func _save_viewport_png(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("Screenshot skipped in headless renderer: %s" % file_name)
		return

	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		print("Screenshot skipped in headless renderer: %s" % file_name)
		return

	var screenshot: Image = viewport_texture.get_image()
	if screenshot == null:
		print("Screenshot image unavailable: %s" % file_name)
		return

	var output_path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	screenshot.save_png(output_path)
	print("Saved screenshot: %s" % output_path)


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame
		await physics_frame


func _ensure_output_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
