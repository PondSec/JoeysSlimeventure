extends RefCounted

class_name CharacterCatalog

const SLIME_ID := "slime"
const MALE_HERO_ID := "male_hero"

static var _texture_cache: Dictionary = {}


static func get_character_ids() -> Array[String]:
	return [SLIME_ID, MALE_HERO_ID]


static func get_character_meta(character_id: String) -> Dictionary:
	match character_id:
		MALE_HERO_ID:
			return _build_male_hero_meta()
		_:
			return _build_slime_meta()


static func get_all_characters() -> Array[Dictionary]:
	var characters: Array[Dictionary] = []
	for character_id in get_character_ids():
		characters.append(get_character_meta(character_id))
	return characters


static func get_preview_descriptor(character_id: String) -> Dictionary:
	return (get_character_meta(character_id).get("preview", {}) as Dictionary).duplicate(true)


static func get_runtime_profile(character_id: String) -> Dictionary:
	return (get_character_meta(character_id).get("runtime_profile", {}) as Dictionary).duplicate(true)


static func load_texture(texture_path: String) -> Texture2D:
	if _texture_cache.has(texture_path):
		return _texture_cache[texture_path] as Texture2D

	var texture: Texture2D = null
	if ResourceLoader.exists(texture_path):
		texture = load(texture_path) as Texture2D

	if texture == null:
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(texture_path))
		if error == OK:
			texture = ImageTexture.create_from_image(image)

	_texture_cache[texture_path] = texture
	return texture


static func _build_slime_meta() -> Dictionary:
	return {
		"id": SLIME_ID,
		"display_name": "Joey Slime",
		"description": "Der klassische Schleim mit dem gewohnten, federnden Movement.",
		"accent": Color("7FEF86"),
		"preview": {
			"texture_path": "res://Assets/slime-sprite2.png",
			"hframes": 4,
			"vframes": 4,
			"frame_sequence": [0, 1],
			"fps": 3.0,
			"loop": true,
		},
		"runtime_profile": {
			"animation_mode": "legacy",
			"movement": {
				"base_walk_speed": 140.0,
				"base_run_speed": 220.0,
				"acceleration": 1800.0,
				"deceleration": 2400.0,
				"air_acceleration": 1200.0,
				"air_deceleration": 800.0,
				"gravity": 1200.0,
				"max_fall_speed": 800.0,
				"jump_velocity": -430.0,
				"air_jump_velocity": -380.0,
				"wall_jump_velocity_x": 320.0,
				"wall_jump_velocity_y": -400.0,
				"wall_slide_speed": 50.0,
				"wall_run_vertical_speed": 150.0,
				"dash_speed": 540.0,
				"dash_duration": 0.13,
				"dash_cooldown": 1.15,
			},
			"collision": {
				"standing": {
					"position": Vector2(0.0, 7.14551),
					"rotation": 1.5708,
					"scale": Vector2.ONE,
					"size": Vector2(242.855, 386.667),
				},
			},
			"capabilities": {
				"wall_slide": true,
				"wall_jump_without_slide": false,
				"ground_slide": false,
				"sticky_form": true,
				"slime_wings": true,
			},
			"weapon_visual": {
				"idle_position": Vector2(38.0, 24.0),
				"idle_rotation": 18.0,
				"base_scale": 10.8,
				"grip_offset": Vector2(8.0, -8.0),
			},
			"audio": {
				"footsteps": ["res://Assets/Sounds/walk.mp3"],
				"jump": "res://Assets/Sounds/jump_slime.mp3",
				"land": "res://Assets/Sounds/land.mp3",
				"dash": "res://Assets/Sounds/Polish/phase_jump_2.ogg",
			},
		},
	}


static func _build_male_hero_meta() -> Dictionary:
	return {
		"id": MALE_HERO_ID,
		"display_name": "Cave Hero",
		"description": "Ein humanoider Runner mit schnellerem, praeziserem Platforming und eigenem Animationsset.",
		"accent": Color("F58BD0"),
		"preview": {
			"texture_path": "res://Assets/Heros/male/male_hero-idle.png",
			"hframes": 10,
			"vframes": 1,
			"fps": 9.0,
			"loop": true,
		},
			"runtime_profile": {
				"animation_mode": "runtime",
				"sprite": {
					"position": Vector2(0.000183105, -114.0),
					"scale": Vector2(15.625, 15.625),
				},
				"movement": {
					"base_walk_speed": 170.0,
					"base_run_speed": 285.0,
					"acceleration": 2400.0,
					"deceleration": 3200.0,
					"air_acceleration": 1500.0,
					"air_deceleration": 980.0,
					"gravity": 1280.0,
					"max_fall_speed": 920.0,
					"jump_velocity": -500.0,
					"air_jump_velocity": -425.0,
					"wall_jump_velocity_x": 470.0,
					"wall_jump_velocity_y": -485.0,
					"wall_slide_speed": 0.0,
					"wall_run_vertical_speed": 0.0,
					"dash_speed": 620.0,
					"dash_duration": 0.15,
					"dash_cooldown": 0.98,
				},
				"collision": {
					"standing": {
						"position": Vector2(0.0, -124.0),
						"rotation": 0.0,
						"scale": Vector2.ONE,
						"size": Vector2(220.0, 520.0),
					},
					"ground_slide": {
						"position": Vector2(0.0, -14.0),
						"rotation": 0.0,
						"scale": Vector2.ONE,
						"size": Vector2(360.0, 300.0),
					},
				},
				"capabilities": {
					"wall_slide": false,
					"wall_jump_without_slide": true,
					"ground_slide": true,
					"sticky_form": false,
					"slime_wings": false,
				},
				"ground_slide": {
					"speed": 470.0,
					"min_trigger_speed": 185.0,
					"duration": 0.42,
					"cooldown": 0.34,
					"deceleration": 560.0,
					"steer_strength": 210.0,
					"exit_speed_multiplier": 0.62,
					"momentum_window": 0.7,
				},
				"combat": {
					"attack_cooldown": 0.075,
					"combo_damage": [1.04, 1.38, 1.86],
					"combo_knockback": [185.0, 270.0, 390.0],
					"combo_lunge": [145.0, 205.0, 285.0],
					"momentum_damage_multiplier": 1.24,
					"momentum_lunge_bonus": 85.0,
					"hitstop": 0.042,
				},
				"weapon_visual": {
					"show_equipped_weapon": false,
					"idle_position": Vector2(42.0, 8.0),
					"idle_rotation": 10.0,
					"base_scale": 8.8,
					"grip_offset": Vector2(6.0, -6.0),
				},
				"audio": {
					"footsteps": [
						"res://Assets/Sounds/Polish/footstep_concrete_001.ogg",
						"res://Assets/Sounds/Polish/footstep_concrete_003.ogg"
					],
					"jump": "res://Assets/Sounds/Polish/phase_jump_2.ogg",
					"land": "res://Assets/Sounds/Polish/impact_punch_medium_002.ogg",
					"dash": "res://Assets/Sounds/Polish/phase_jump_2.ogg",
					"slide": "res://Assets/Sounds/Polish/footstep_concrete_003.ogg",
					"wall_jump": "res://Assets/Sounds/Polish/phase_jump_2.ogg",
				},
			"animations": {
				"idle": {
					"texture_path": "res://Assets/Heros/male/male_hero-idle.png",
					"hframes": 10,
					"vframes": 1,
					"fps": 9.0,
					"loop": true,
				},
				"walk": {
					"texture_path": "res://Assets/Heros/male/male_hero-walk.png",
					"hframes": 10,
					"vframes": 1,
					"fps": 11.0,
					"loop": true,
				},
				"run": {
					"texture_path": "res://Assets/Heros/male/male_hero-run.png",
					"hframes": 10,
					"vframes": 1,
					"fps": 14.0,
					"loop": true,
				},
				"run_to_idle": {
					"texture_path": "res://Assets/Heros/male/male_hero-run_to_idle.png",
					"hframes": 7,
					"vframes": 1,
					"fps": 16.0,
					"loop": false,
				},
				"idle_turn": {
					"texture_path": "res://Assets/Heros/male/male_hero-idle_turn.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"walk_turn": {
					"texture_path": "res://Assets/Heros/male/male_hero-walk_turn.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"run_turn": {
					"texture_path": "res://Assets/Heros/male/male_hero-run_turn.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"jump": {
					"texture_path": "res://Assets/Heros/male/male_hero-jump.png",
					"hframes": 6,
					"vframes": 1,
					"fps": 16.0,
					"loop": false,
				},
				"fall": {
					"texture_path": "res://Assets/Heros/male/male_hero-fall.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 16.0,
					"loop": false,
				},
				"fall_loop": {
					"texture_path": "res://Assets/Heros/male/male_hero-fall_loop.png",
					"hframes": 3,
					"vframes": 1,
					"fps": 8.0,
					"loop": true,
				},
				"landing": {
					"texture_path": "res://Assets/Heros/male/male_hero-run_to_idle.png",
					"hframes": 7,
					"vframes": 1,
					"fps": 16.0,
					"loop": false,
				},
				"hard_landing": {
					"texture_path": "res://Assets/Heros/male/male_hero-slide.png",
					"hframes": 8,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"ground_slide": {
					"texture_path": "res://Assets/Heros/male/male_hero-slide.png",
					"hframes": 8,
					"vframes": 1,
					"fps": 22.0,
					"loop": true,
				},
				"wall_slide": {
					"texture_path": "res://Assets/Heros/male/male_hero-wall_slide.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 8.0,
					"loop": true,
				},
				"wall_jump": {
					"texture_path": "res://Assets/Heros/male/male_hero-wall_jump.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 16.0,
					"loop": false,
				},
				"dash": {
					"texture_path": "res://Assets/Heros/male/male_hero-dash.png",
					"hframes": 5,
					"vframes": 1,
					"fps": 20.0,
					"loop": false,
				},
				"attack_1": {
					"texture_path": "res://Assets/Heros/male/male_hero-combo_1.png",
					"hframes": 3,
					"vframes": 1,
					"fps": 20.0,
					"loop": false,
				},
				"attack_1_end": {
					"texture_path": "res://Assets/Heros/male/male_hero-combo_1_end.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"attack_2": {
					"texture_path": "res://Assets/Heros/male/male_hero-combo_2.png",
					"hframes": 6,
					"vframes": 1,
					"fps": 22.0,
					"loop": false,
				},
				"attack_2_end": {
					"texture_path": "res://Assets/Heros/male/male_hero-combo_2_end.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"attack_3": {
					"texture_path": "res://Assets/Heros/male/male_hero-combo_3.png",
					"hframes": 12,
					"vframes": 1,
					"fps": 24.0,
					"loop": false,
				},
				"attack_3_end": {
					"texture_path": "res://Assets/Heros/male/male_hero-combo_3_end.png",
					"hframes": 6,
					"vframes": 1,
					"fps": 20.0,
					"loop": false,
				},
				"hurt": {
					"texture_path": "res://Assets/Heros/male/male_hero-hurt.png",
					"hframes": 6,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"death": {
					"texture_path": "res://Assets/Heros/male/male_hero-death.png",
					"hframes": 23,
					"vframes": 1,
					"fps": 20.0,
					"loop": false,
				},
			},
		},
	}
