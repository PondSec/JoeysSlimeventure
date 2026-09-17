extends RefCounted

class_name CharacterCatalog

const SLIME_ID := "slime"
const MALE_HERO_ID := "male_hero"
const HERO_DELUXE_SHEETS := "res://Assets/player/hero/individual_sheets/"

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
				"base_walk_speed": 170.0,
				"base_run_speed": 275.0,
				"acceleration": 1780.0,
				"deceleration": 2050.0,
				"air_acceleration": 1280.0,
				"air_deceleration": 850.0,
				"gravity": 1200.0,
				"max_fall_speed": 800.0,
				"jump_velocity": -480.0,
				"air_jump_velocity": -420.0,
				"wall_jump_velocity_x": 370.0,
				"wall_jump_velocity_y": -445.0,
				"wall_slide_speed": 50.0,
				"wall_run_vertical_speed": 150.0,
				"dash_speed": 570.0,
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
		"description": "Ein humanoider Runner mit kontrolliertem, etwas schwererem Platforming und eigenem Animationsset.",
		"accent": Color("F58BD0"),
		"preview": {
			"texture_path": HERO_DELUXE_SHEETS + "male_hero-idle.png",
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
					"base_walk_speed": 158.0,
					"base_run_speed": 260.0,
					"acceleration": 2050.0,
					"deceleration": 2750.0,
					"air_acceleration": 1320.0,
					"air_deceleration": 860.0,
					"gravity": 1280.0,
					"max_fall_speed": 920.0,
					"jump_velocity": -500.0,
					"air_jump_velocity": -425.0,
					"wall_jump_velocity_x": 470.0,
					"wall_jump_velocity_y": -485.0,
					"wall_slide_speed": 76.0,
					"wall_run_vertical_speed": 0.0,
					"dash_speed": 570.0,
					"dash_duration": 0.15,
					"dash_cooldown": 1.08,
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
					"wall_slide": true,
					"wall_jump_without_slide": false,
					"ledge_grab": true,
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
					# These match the authored Deluxe sheets exactly: every frame is shown
					# before the corresponding recovery sheet is allowed to take over.
					"combo_active": [0.15, 0.273, 0.5],
					"combo_recovery": [0.222, 0.222, 0.3],
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
				"design": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-design.png",
					"hframes": 1,
					"vframes": 1,
					"fps": 1.0,
					"loop": true,
				},
				"idle": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-idle.png",
					"hframes": 10,
					"vframes": 1,
					"fps": 9.0,
					"loop": true,
				},
				"walk": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-walk.png",
					"hframes": 10,
					"vframes": 1,
					"fps": 11.0,
					"loop": true,
				},
				"run": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-run.png",
					"hframes": 10,
					"vframes": 1,
					"fps": 14.0,
					"loop": true,
				},
				"run_to_idle": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-run_to_idle.png",
					"hframes": 7,
					"vframes": 1,
					"fps": 16.0,
					"loop": false,
				},
				"idle_turn": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-idle_turn.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"walk_turn": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-walk_turn.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"run_turn": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-run_turn.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"jump": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-jump.png",
					"hframes": 6,
					"vframes": 1,
					"fps": 16.0,
					"loop": false,
				},
				"fall": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-fall.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 16.0,
					"loop": false,
				},
				"fall_loop": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-fall_loop.png",
					"hframes": 3,
					"vframes": 1,
					"fps": 8.0,
					"loop": true,
				},
				"slide": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-slide.png",
					"hframes": 8,
					"vframes": 1,
					"fps": 22.0,
					"loop": true,
				},
				"wall_slide": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-wall_slide.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 8.0,
					"loop": true,
				},
				"wall_jump": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-wall_jump.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 16.0,
					"loop": false,
				},
				"dash": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-dash.png",
					"hframes": 5,
					"vframes": 1,
					"fps": 20.0,
					"loop": false,
				},
				"combo_1": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-combo_1.png",
					"hframes": 3,
					"vframes": 1,
					"fps": 20.0,
					"loop": false,
				},
				"combo_1_end": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-combo_1_end.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"combo_2": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-combo_2.png",
					"hframes": 6,
					"vframes": 1,
					"fps": 22.0,
					"loop": false,
				},
				"combo_2_end": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-combo_2_end.png",
					"hframes": 4,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"combo_3": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-combo_3.png",
					"hframes": 12,
					"vframes": 1,
					"fps": 24.0,
					"loop": false,
				},
				"combo_3_end": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-combo_3_end.png",
					"hframes": 6,
					"vframes": 1,
					"fps": 20.0,
					"loop": false,
				},
				"hurt": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-hurt.png",
					"hframes": 6,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
				"death": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-death.png",
					"hframes": 23,
					"vframes": 1,
					"fps": 20.0,
					"loop": false,
				},
				"ledge_hang": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-ledge_hang.png",
					"hframes": 7,
					"vframes": 1,
					"fps": 5.0,
					"loop": true,
					# Frame analysis: frames 1–4 are a settling descent (their visual
					# centers shift every frame). Frames 5–7 share the steady hang pose
					# and are the only frames valid for a seamless idle loop.
					"frame_sequence": [4, 5, 6],
				},
				"ledge_grab": {
					# The same sheet's arrival sequence: play once as the hero catches
					# the lip, then hand over to ledge_hang's stable loop.
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-ledge_hang.png",
					"hframes": 7,
					"vframes": 1,
					"fps": 14.0,
					"loop": false,
					"frame_sequence": [0, 1, 2, 3],
				},
				"ledge_reach": {
					# A blocked pull-up briefly reaches toward the lip, then returns to
					# the hang pose. The reverse frames avoid a visible hard cut.
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-ledge_climb.png",
					"hframes": 11,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
					"frame_sequence": [0, 1, 2, 3, 2, 1, 0],
				},
				"ledge_climb": {
					"texture_path": HERO_DELUXE_SHEETS + "male_hero-ledge_climb.png",
					"hframes": 11,
					"vframes": 1,
					"fps": 18.0,
					"loop": false,
				},
			},
		},
	}
