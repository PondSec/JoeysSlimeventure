extends CharacterBody2D

signal glow_changed(is_glowing: bool)
const ItemRegistry := preload("res://Scripts/item_registry.gd")
const SwordCatalog := preload("res://Scripts/sword_catalog.gd")
const StarManager := preload("res://Scripts/Stars/star_manager.gd")
const CharacterCatalog := preload("res://Scripts/character_catalog.gd")
const HeroTransformEffectScene := preload("res://Scripts/hero_transform_effect.gd")
const HeroCombatEffectScene := preload("res://Scripts/hero_combat_effect.gd")
const DEBUG_UNLOCK_HERO_FORM := true

var controls_inverted: bool = false
const SkillProgression := preload("res://Scripts/skill_progression.gd")
const DEFAULT_WALK_SPEED := 140.0
const DEFAULT_RUN_SPEED := 220.0

var active_buffs := {}
var timed_buff_timers := {}
var base_walk_speed := DEFAULT_WALK_SPEED
var base_run_speed := DEFAULT_RUN_SPEED
var base_attack_damage := 15
var damage_reduction := 0.0
@export var lumora: CharacterBody2D
var star_manager: Node

var touch_controls: CanvasLayer
var joystick: Control
var jump_button: Button
var attack_button: Button
var dash_button: Button
var glow_button: Button
var joystick_active := false
var joystick_position := Vector2.ZERO
var joystick_radius := 100.0
var joystick_output := Vector2.ZERO

var public_key: CryptoKey
const FEEDBACK_FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const DASH_SFX_PATH := "res://Assets/Sounds/Polish/phase_jump_2.ogg"
const CRIT_SFX_PATH := "res://Assets/Sounds/Polish/impact_bell_heavy_001.ogg"
const MELEE_IMPACT_PATH := "res://Assets/Sounds/Polish/impact_punch_medium_002.ogg"
const HERO_DEFAULT_FOOTSTEP_PATHS := [
	"res://Assets/Sounds/Polish/footstep_concrete_001.ogg",
	"res://Assets/Sounds/Polish/footstep_concrete_003.ogg"
]
const HERO_DEFAULT_JUMP_SFX_PATH := "res://Assets/Sounds/Polish/phase_jump_2.ogg"
const HERO_DEFAULT_LAND_SFX_PATH := "res://Assets/Sounds/Polish/impact_punch_medium_002.ogg"
const HERO_DEFAULT_SLIDE_SFX_PATH := "res://Assets/Sounds/Polish/footstep_concrete_003.ogg"
const SLIME_MOVE_SFX_PATHS := [
	"res://Assets/Sounds/walk.mp3"
]

const SLIME_WINGS_GLIDE_SPEED = 200.0  # Sehr schnelles horizontales Gleiten
const SLIME_WINGS_GRAVITY_REDUCTION = 0.08  # Sehr wenig Schwerkraft
const SLIME_WINGS_MIN_FALL_SPEED = 20.0  # Extrem langsames Fallen

# Bewegungseinstellungen
var WALK_SPEED = DEFAULT_WALK_SPEED
var RUN_SPEED = DEFAULT_RUN_SPEED
var ACCELERATION = 1800.0
var DECELERATION = 2400.0
var AIR_ACCELERATION = 1200.0  # Vorher vielleicht 900.0
var AIR_DECELERATION = 800.0   # Vorher vielleicht 600.0
var gravity_force := 1200.0
var max_fall_speed_value := 800.0
var jump_velocity_force := -430.0
var air_jump_velocity_force := -380.0
var wall_jump_velocity_x_value := 320.0
var wall_jump_velocity_y_value := -400.0
var base_wall_slide_speed := 50.0
var base_wall_run_vertical_speed := 150.0

# Wall Run Variablen
var is_wall_running := false
var wall_run_direction := 0
var wall_run_vertical_speed := 150.0  # Reduzierte Geschwindigkeit
var wall_run_timer: float = 0.0
var wall_run_active: bool = false
var current_wall_normal: Vector2
var wall_run_cooldown: float = 0.0
var was_on_wall: bool = false

var base_crit_chance: float = 0.15  # 15% base crit chance
var crit_damage_multiplier: float = 1.5  # 50% extra damage on crit

#var base_attack_damage: int = 15
var attack_damage: int = 15
var damage_multiplier: float = 1.0
var current_crit_chance: float = 0.15
var base_crit_multiplier: float = 1.5   # Basis-Crit-Multiplikator (50% Bonus)
var current_crit_multiplier: float = 1.5

# Sprung- und Gravitationseinstellungen
const GRAVITY = 1200.0
const MAX_FALL_SPEED = 800.0
const JUMP_VELOCITY = -430.0
const AIR_JUMP_VELOCITY = -380.0
const SHORT_JUMP_MULTIPLIER = 0.6  # Für kürzere Sprünge bei losgelassener Taste
const JUMP_CUT_MULTIPLIER = 0.4    # Für sofortige Sprungabbremsung

# Wall-Jump und Slide
const WALL_JUMP_VELOCITY_X = 320.0  # Stärkerer horizontaler Impuls
const WALL_JUMP_VELOCITY_Y = -400.0  # Etwas geringere vertikale Geschwindigkeit
const WALL_JUMP_PUSH_AWAY = 200.0  # Zusätzlicher Abstoß-Effekt
const WALL_SLIDE_SPEED = 50.0
const WALL_STICK_TIME = 0.15       # Zeit, in der man sich noch vom Wand abstoßen kann
const COYOTE_TIME_MAX = 0.12
const JUMP_BUFFER_MAX = 0.14
const APEX_GRAVITY_MULTIPLIER = 0.7
const FALL_GRAVITY_MULTIPLIER = 1.35
const FAST_FALL_GRAVITY_MULTIPLIER = 1.8
const APEX_VELOCITY_THRESHOLD = 60.0

var mana_shield_active := false
var mana_shield_health := 0
var max_mana_shield_health := 100
var mana_shield_regen_rate := 5.0
var mana_shield_regen_timer := 0.0
var shield_particles_initial_params = {}
var original_particle_settings: Dictionary = {}

# Dash-Einstellungen
const DASH_SPEED = 350.0
const DASH_DURATION = 0.15
const DASH_COOLDOWN = 3.0
const DASH_INVULNERABILITY_TIME = 0.2
const BASE_DASH_SPEED = 540.0
const BASE_DASH_DURATION = 0.13
const BASE_DASH_COOLDOWN = 1.15

# Teleportation Variablen
var is_teleporting: bool = false
const TELEPORT_COOLDOWN = 5.0  # Cooldown in Sekunden
const TELEPORT_DISTANCE = 300.0  # Maximale Teleportdistanz
var can_teleport := true
var teleport_cooldown_timer: Timer
var teleport_particles: GPUParticles2D

# Bewegung und Status
var current_speed = WALK_SPEED
var direction := Vector2.ZERO
var is_wall_sliding := false
var can_wall_jump := true
var last_wall_normal := Vector2.ZERO
var wall_stick_timer := 0.0
var coyote_time := 0.0
var jump_buffer_time := 0.0
var air_jumps_available := 0  # Zähler für verfügbare Luftsprünge
var max_air_jumps := 1
var is_dashing := false
var can_dash := true
var dash_direction := Vector2.ZERO
var is_facing_left := false
var was_on_floor := true
var base_dash_speed := BASE_DASH_SPEED
var base_dash_duration := BASE_DASH_DURATION
var base_dash_cooldown := BASE_DASH_COOLDOWN
var dash_speed := BASE_DASH_SPEED
var dash_duration := BASE_DASH_DURATION
var dash_cooldown := BASE_DASH_COOLDOWN
var dash_elapsed := 0.0
var dash_invulnerability_timer := 0.0
var dash_attack_bonus_timer := 0.0
const DASH_ATTACK_BONUS_DURATION := 0.55
const DASH_ATTACK_BONUS_MULTIPLIER := 1.25

# Konstanten für Bewegung und Sprung
const SPEED = 220.0
const LANDING_DROP_DISTANCE_THRESHOLD = 72.0
const LANDING_FALL_SPEED_THRESHOLD = 235.0
var last_charge_time: float = -300.0  # Initialwert (sofort nutzbar)
var charge_cooldown: float = 300.0     # 5 Minuten in Sekunden
var is_charging: bool = false

# Variablen für Bewegung und Status
var is_glowing := true
var is_gliding := false
var is_attacking := false  # Angriffszustand
var was_in_air := false  # Variable, um zu überprüfen, ob der Spieler gerade in der Luft war
var is_landing := false  # Variable, um die Landeanimation zu verfolgen
var airtime_started_with_jump := false
var airtime_peak_fall_speed := 0.0
var fall_start_y := 0.0  # Y-Position, bei der der Spieler zu fallen begann
var fall_distance := 10.0  # Berechnete Fallhöhe
var heal_rate: float = 15.0  # Anfangsheilrate
var min_heal_rate: float = 1  # Mindestheilrate, die nie unterschritten werden soll
var heal_decay: float = 0.7  # Heilrate sinkt um diesen Betrag nach jeder Heilung
var heal_interval: float = 2  # Intervall, in dem der Spieler geheilt wird (in Sekunden)
var heal_timer: Timer = Timer.new()  # Timer für regelmäßige Heilung
var is_healing_active: bool = false  # Flag, ob Heilung aktiv ist
var healed_to_full: bool = false  # Flag, ob der Spieler voll geheilt wurde
var damage_timer: Timer = Timer.new()  # Timer für den Schadensabstand
var is_stunned: bool = false  # Spieler kann sich während des Stuns nicht bewegen
var inventory = {}  # Ein Dictionary für das Inventar
var dropped_items = []  # Liste für persistente Speicherung
var selected_hotbar_index: int = 0  # Standardmäßig der erste Slot

var is_sticky_form_active := false
var sticky_form_timer := 0.0
const STICKY_FORM_DURATION := 2.0  # 2 Sekunden Haftzeit
const STICKY_FORM_COOLDOWN := 5.0  # 5 Sekunden Cooldown
var sticky_form_cooldown_timer := 0.0

# Timer Nodes
var dash_timer: Timer
var dash_cooldown_timer: Timer

var transfer_dialog_scene = preload("res://Scenes/transfer.tscn")

# Konstanten für den Fall-Schaden
const FALL_DAMAGE_THRESHOLD = 1580  # Y-Position, ab der Schaden verursacht wird
const FALL_DAMAGE = 30  # Schaden, der beim Fallen verursacht wird

# Referenzen zu Knoten
var attack_sprite: AnimatedSprite2D
var attack_area: Area2D
var attack_collision_shape: CollisionShape2D
var attack_area_base_position := Vector2.ZERO
var attack_shape_base_scale := Vector2.ONE
var equipped_weapon: InvItem
var equipped_weapon_name := ""
var weapon_attack_reach_bonus := 0.0
var weapon_speed_burst_bonus := 0.0
var weapon_speed_burst_timer := 0.0
var weapon_hit_counter := 0
var last_weapon_skill_time := {}
var weapon_afterimage_sprites: Array[Sprite2D] = []
var weapon_transform_history: Array[Dictionary] = []
var weapon_visual_anim_time := 0.0
var weapon_visual_anim_duration := 0.0
var weapon_visual_step := 0
var weapon_idle_position := Vector2(38.0, 24.0)
var weapon_idle_rotation := 18.0
var weapon_base_scale := 10.8
var weapon_grip_offset_runtime := Vector2(8.0, -8.0)
var show_equipped_weapon_visual := true
var glow_effect: PointLight2D
@onready var damage_label: Label = $PlayerSprite/CanvasLayer2/DamageLabel# Referenz zum Schadens-Label
@onready var equipped_weapon_sprite: Sprite2D = $PlayerSprite/EquippedWeaponSprite

var current_character_id := CharacterCatalog.SLIME_ID
var current_character_meta: Dictionary = {}
var current_character_profile: Dictionary = {}
var current_character_capabilities: Dictionary = {}
var current_collision_profiles: Dictionary = {}
var uses_runtime_character_animation := false
var runtime_animation_state := ""
var runtime_animation_elapsed := 0.0
var runtime_landing_animation := "landing"
var runtime_attack_elapsed := 0.0
var runtime_turn_timer := 0.0
var runtime_turn_animation := ""
var runtime_stop_timer := 0.0
var runtime_fall_transition_timer := 0.0
var runtime_wall_jump_timer := 0.0
var runtime_hurt_timer := 0.0
var runtime_dash_timer := 0.0
var runtime_death_active := false
var was_descending := false
var last_floor_velocity := 0.0
var runtime_body_sprite: Sprite2D
var runtime_body_base_scale := Vector2.ONE
var default_player_sprite_texture: Texture2D
var default_player_sprite_hframes := 1
var default_player_sprite_vframes := 1
var default_player_sprite_position := Vector2.ZERO
var default_player_sprite_scale := Vector2.ONE
var default_player_sprite_self_modulate := Color.WHITE
var default_collision_shape_size := Vector2.ZERO
var default_collision_shape_position := Vector2.ZERO
var default_collision_shape_rotation := 0.0
var default_collision_shape_scale := Vector2.ONE
var hero_slide_config: Dictionary = {}
var hero_combat_config: Dictionary = {}
var is_hero_ground_sliding := false
var hero_slide_timer := 0.0
var hero_slide_cooldown_timer := 0.0
var hero_slide_floor_grace := 0.0
var hero_slide_direction := 1.0
var hero_momentum_attack_timer := 0.0
var hero_current_attack_had_momentum := false
var hero_hitstop_active := false

# Variablen für das Lebenssystem
var max_health: int = 100
var current_health: int = 100
var base_max_health = 100
# Definiert die Originalfarbe und die Farbe, die bei Schaden angezeigt werden soll
const COLOR_NORMAL = Color(0.62, 1.0, 0.58)  # Originalfarbe (9fff94 in Hex)
const COLOR_DAMAGE = Color(1.0, 0.29, 0.29)  # Schadenfarbe (ff4a4a in Hex)

var attack_cooldown := 0.1  # Cooldown zwischen Angriffen
var last_attack_time := 0.0
var attack_combo_count := 0
const MAX_COMBO = 11
var combo_reset_timer := 0.0
const COMBO_RESET_TIME := 1.0
var queued_attack_timer := 0.0
const ATTACK_QUEUE_TIME := 0.2
var current_attack_step := 0
var current_attack_damage_multiplier := 1.0
var current_attack_knockback_strength := 220.0
var current_attack_lunge_strength := 90.0
var attack_targets_hit := {}
var combo_damage_multipliers: Array[float] = []
var combo_knockback_strengths: Array[float] = []
var combo_lunge_strengths: Array[float] = []
var combo_active_times := [0.10, 0.11, 0.13]
var combo_recovery_times := [0.10, 0.10, 0.13]
const ATTACK_REACH_SCALES := [2.1, 2.3, 2.5]
const ATTACK_FORWARD_OFFSETS := [200.0, 230.0, 260.0]
const WEAPON_IDLE_POSITION := Vector2(38.0, 24.0)
const WEAPON_IDLE_ROTATION := 18.0
const WEAPON_BASE_SCALE := 10.8
const WEAPON_GRIP_OFFSET := Vector2(8.0, -8.0)
const WEAPON_AFTERIMAGE_COUNT := 2
const WEAPON_ATTACK_PROFILES := [
	{
		"windup_pos": Vector2(18.0, 34.0),
		"strike_pos": Vector2(58.0, -2.0),
		"recover_pos": Vector2(44.0, 14.0),
		"windup_rot": 126.0,
		"strike_rot": -42.0,
		"recover_rot": 10.0,
		"scale": 11.6,
	},
	{
		"windup_pos": Vector2(16.0, 2.0),
		"strike_pos": Vector2(62.0, 30.0),
		"recover_pos": Vector2(46.0, 18.0),
		"windup_rot": -82.0,
		"strike_rot": 92.0,
		"recover_rot": 26.0,
		"scale": 12.0,
	},
	{
		"windup_pos": Vector2(10.0, -12.0),
		"strike_pos": Vector2(66.0, 12.0),
		"recover_pos": Vector2(48.0, -2.0),
		"windup_rot": -116.0,
		"strike_rot": 20.0,
		"recover_rot": -18.0,
		"scale": 12.4,
	},
]
var wall_slide_speed_cap := WALL_SLIDE_SPEED

var wall_jump_buffer = 0.0
const WALL_JUMP_BUFFER_TIME = 0.1
const WALL_JUMP_FORGIVENESS = 0.15

var has_glow_skill := false
var has_wall_slide_skill := false
var has_regeneration_skill := false
var has_ult_skill := false
var has_double_jump_skill := false
var has_wall_run_skill := false
var has_dash_skill := false
var has_teleport_skill := false
var has_mana_shield_skill := false
var has_heal_burst_skill := false
var has_sticky_form_skill := false
var has_hero_form_skill := DEBUG_UNLOCK_HERO_FORM
var has_thorns_skill := false
var has_slime_wings_skill := false
var player_level := 1
@onready var skill_tree = $SkillTreeUI/SkillTree

var url = "https://api.joeyslime.com/"
@onready var http_request = $HTTPRequest

# Referenz zur Lebensanzeige (ProgressBar)
@onready var health_bar: TextureProgressBar = $CanvasLayer/TextureProgressBar
@onready var canvas_layer: CanvasLayer = $CanvasLayer  # Referenz zum CanvasLayer für die Tween-Animationen
@onready var death_screen: Control = get_node("CanvasLayer/GameOver")
@export var inv: Inv
@onready var health_label = $CanvasLayer/HealthLabel
@onready var api_script = preload("res://Scenes/api.tscn").instantiate()
@onready var shield_sprite = $ShieldSprite  # Ein Sprite2D-Node
@onready var shield_light = $ShieldSprite/ShieldLight  # Dein vorhandener Light2D-Node
@onready var particles: GPUParticles2D = $GPUParticles2D
@export var slimeball_scene: PackedScene
@export var throw_force: float = 300.0

var is_walking := false
const WALK_STEP_INTERVAL := 0.2
var last_sound_time = 0.
var sound_cooldown = 0.28
var feedback_font: FontFile
var slime_move_streams: Array[AudioStream] = []
var character_footstep_streams: Array[AudioStream] = []
var character_jump_stream: AudioStream
var character_land_stream: AudioStream
var character_dash_stream: AudioStream
var hero_slide_stream: AudioStream
var hero_wall_jump_stream: AudioStream
var dash_stream: AudioStream
var crit_stream: AudioStream
var melee_impact_stream: AudioStream
var dash_sound_player: AudioStreamPlayer2D
var crit_sound_player: AudioStreamPlayer2D
var melee_impact_player: AudioStreamPlayer2D
var hero_slide_sound_player: AudioStreamPlayer2D
var hero_wall_jump_sound_player: AudioStreamPlayer2D
var is_hero_form_active := false
var is_transforming_hero_form := false
var hero_transform_target_id := CharacterCatalog.SLIME_ID
var hero_transform_timer := 0.0
const HERO_TRANSFORM_DURATION := 0.72
const HERO_TRANSFORM_SWAP_TIME := 0.32

var stun_timer: Timer = Timer.new()
var save_load = preload("res://Scripts/SaveLoad.gd").new()

# Wasser-Einstellungen (am Anfang des Skripts hinzufügen)
const WATER_DRAG := 0.85  # Widerstand im Wasser (0.0 - 1.0, höher = mehr Widerstand)
const WATER_GRAVITY_SCALE := 0.5  # Schwerkraftreduktion im Wasser
const WATER_ACCELERATION := 800.0  # Beschleunigung im Wasser
const WATER_MAX_SPEED := 180.0  # Maximalgeschwindigkeit im Wasser
const WATER_BUOYANCY := 300.0  # Auftriebskraft
const WATER_SWIM_IMPULSE := 250.0  # Schwimmkraft beim Drücken der Sprungtaste
const WATER_SINK_SPEED := 100.0  # Geschwindigkeit beim Absinken
const WATER_SURFACE_TENSION := 50.0  # Kraft die den Spieler an der Oberfläche hält
const WATER_SPLASH_FORCE := 200.0  # Kraft beim Eintauchen
const WATER_MIN_SPLASH_VELOCITY := 300.0  # Mindestgeschwindigkeit für Spritzeffekt

# Wasser-Statusvariablen
var is_in_water = false
var water_area: Area2D
var is_submerged := false  # Ganz unter Wasser
var water_surface_y := 0.0  # Y-Position der Wasseroberfläche
var last_out_of_water_time := 0.0
var water_enter_velocity := 0.0
var is_swimming := false

func _ready() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		setup_touch_controls()
	var gm = get_node("/root/GameManager")
	if gm.is_multiplayer:
		$GPUParticles2D.emitting = false
	if is_multiplayer_authority():
		$Camera2D.enabled = true
		set_process_input(true)
		set_process(true)
		set_physics_process(true)
		
		# Initialisiere nur für autoritativen Spieler
		public_key = CryptoKey.new()
		public_key.load("res://Keys/public.pem")
	else:
		$Camera2D.enabled = true
		set_process_input(true)
		set_process(true)
		set_physics_process(true)
	public_key = CryptoKey.new()
	# Lade den öffentlichen Schlüssel des Servers
	public_key.load("res://Keys/public.pem")
	
	load_charge_cooldown()
	glow_effect = $PlayerGlow
	glow_effect.visible = false
	# Initialisiere Angriffsknoten
	attack_sprite = $PlayerSprite/AttackSprite
	attack_area = $PlayerSprite/AttackSprite/AttackArea
	attack_collision_shape = attack_area.get_node_or_null("CollisionShape2D")
	attack_area_base_position = attack_area.position
	if attack_collision_shape:
		attack_shape_base_scale = attack_collision_shape.scale
	default_player_sprite_texture = $PlayerSprite.texture
	default_player_sprite_hframes = $PlayerSprite.hframes
	default_player_sprite_vframes = $PlayerSprite.vframes
	default_player_sprite_position = $PlayerSprite.position
	default_player_sprite_scale = $PlayerSprite.scale
	default_player_sprite_self_modulate = $PlayerSprite.self_modulate
	if $ColisionArea and $ColisionArea.shape is RectangleShape2D:
		default_collision_shape_size = ($ColisionArea.shape as RectangleShape2D).size
		default_collision_shape_position = $ColisionArea.position
		default_collision_shape_rotation = $ColisionArea.rotation
		default_collision_shape_scale = $ColisionArea.scale
	_apply_default_character_profile()
	_configure_attack_sprite_visual()
	_configure_equipped_weapon_sprite()
	_setup_weapon_afterimages()
	
	# Deaktiviere das Angriffskollisionsgebiet anfänglich
	attack_area.monitoring = false
	attack_area.connect("body_entered", Callable(self, "_on_attack_area_body_entered"))
	
	death_screen.visible = false
	
	add_to_group("players")
	glow_effect.set("custom_range", 300.0)
	glow_effect.add_to_group("lights")
	update_health_bar()
	damage_label.visible = false
	
	# Füge den Heil-Timer als Kind hinzu und starte ihn
	add_child(heal_timer)
	heal_timer.wait_time = heal_interval
	heal_timer.autostart = true
	heal_timer.start()
	heal_timer.connect("timeout", Callable(self, "_on_heal_timer_timeout"))
	
	add_child(damage_timer)
	damage_timer.wait_time = 0.5
	damage_timer.one_shot = true
	damage_timer.autostart = false
	damage_timer.connect("timeout", Callable(self, "_on_damage_timer_timeout"))
	
	# Stun-Timer initialisieren
	add_child(stun_timer)
	stun_timer.wait_time = 0.5
	stun_timer.one_shot = true
	stun_timer.connect("timeout", Callable(self, "_on_stun_timer_timeout"))
	load_dropped_items()
	update_health_bar()
	damage_timer.start()
	inv.update.connect(update_health_bonus)
	inv.update.connect(update_damage_bonus)
	inv.update.connect(update_crit_bonuses)
	inv.update.connect(_on_inventory_equipment_changed)
	add_child(api_script)
	
	# Timer für regelmäßige API-Abfragen (alle 3 Sekunden)
	var api_timer = Timer.new()
	add_child(api_timer)
	api_timer.wait_time = 3.0  # Alle 3 Sekunden
	api_timer.autostart = true
	api_timer.timeout.connect(_on_api_timer_timeout)
	api_timer.start()
	
	# Sofortige erste Abfrage
	api_script.send_request()
	_on_inventory_equipment_changed()
	_setup_star_manager()
	update_damage_bonus()

	# Timer für Dash initialisieren
	dash_timer = Timer.new()
	dash_timer.one_shot = true
	dash_timer.wait_time = dash_duration
	dash_timer.connect("timeout", Callable(self, "_on_dash_timer_timeout"))
	add_child(dash_timer)
	
	dash_cooldown_timer = Timer.new()
	dash_cooldown_timer.one_shot = true
	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.connect("timeout", Callable(self, "_on_dash_cooldown_timer_timeout"))
	add_child(dash_cooldown_timer)
	
	water_area = $WaterDetector
	water_area.connect("body_entered", Callable(self, "_on_water_entered"))
	water_area.connect("body_exited", Callable(self, "_on_water_exited"))
	load_game()
	# Verbinde das Signal, wenn ein Skill freigeschaltet wird
	if skill_tree:
		var unlock_callable := Callable(self, "_on_skill_unlocked")
		if not skill_tree.is_connected("skill_unlocked", unlock_callable):
			skill_tree.connect("skill_unlocked", unlock_callable)
		print("Wall Slide Skill status: ", has_wall_slide_skill)
		load_skills()
		_refresh_player_tuning_from_skills()
		glow_effect.visible = has_glow_skill and is_glowing
		check_level_completion()
	
	# Teleportation Timer initialisieren
	teleport_cooldown_timer = Timer.new()
	teleport_cooldown_timer.one_shot = true
	teleport_cooldown_timer.wait_time = TELEPORT_COOLDOWN
	teleport_cooldown_timer.connect("timeout", Callable(self, "_on_teleport_cooldown_timeout"))
	add_child(teleport_cooldown_timer)

	# Teleport Partikel-Effekt (optional)
	teleport_particles = GPUParticles2D.new()
	teleport_particles.emitting = false
	teleport_particles.one_shot = true
	teleport_particles.explosiveness = 0.8
	add_child(teleport_particles)
	
	save_initial_particle_settings()
	
	base_attack_damage = 15  # Dein Basis-Schadenswert
	feedback_font = load(FEEDBACK_FONT_PATH) as FontFile
	_setup_polish_audio()
	_sync_feedback_ui(false)


func save_initial_particle_settings():
	# Speichere die ursprünglichen Partikeleinstellungen
	if particles and particles.process_material:
		var material = particles.process_material.duplicate()
		shield_particles_initial_params = {
			"process_material": material,
			"amount": particles.amount,
			"emitting": particles.emitting,
			"one_shot": particles.one_shot,
			"explosiveness": particles.explosiveness,
			"position": particles.position,
			"global_position": particles.global_position
		}


func _setup_polish_audio() -> void:
	slime_move_streams.clear()
	for path in SLIME_MOVE_SFX_PATHS:
		var stream = load(path)
		if stream:
			slime_move_streams.append(stream)

	dash_stream = load(DASH_SFX_PATH)
	crit_stream = load(CRIT_SFX_PATH)
	melee_impact_stream = load(MELEE_IMPACT_PATH)

	dash_sound_player = _create_sfx_player("DashSoundPolish", -10.0)
	crit_sound_player = _create_sfx_player("CritSoundPolish", -8.5)
	melee_impact_player = _create_sfx_player("MeleeImpactPolish", -6.5)
	hero_slide_sound_player = _create_sfx_player("HeroSlideSoundPolish", -8.0)
	hero_wall_jump_sound_player = _create_sfx_player("HeroWallJumpSoundPolish", -8.0)
	_configure_character_audio()


func _create_sfx_player(name: String, volume_db: float) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.name = name
	player.volume_db = volume_db
	add_child(player)
	return player


func _load_stream_or_default(path: String, fallback_path: String = "") -> AudioStream:
	var stream: AudioStream = null
	if not path.is_empty():
		stream = load(path) as AudioStream
	if stream == null and not fallback_path.is_empty():
		stream = load(fallback_path) as AudioStream
	return stream


func _configure_character_audio() -> void:
	character_footstep_streams.clear()
	var audio_profile: Dictionary = current_character_profile.get("audio", {}) as Dictionary
	var footstep_paths: Array = audio_profile.get("footsteps", SLIME_MOVE_SFX_PATHS if not _is_hero_form_active() else HERO_DEFAULT_FOOTSTEP_PATHS)
	for path_variant in footstep_paths:
		var stream := _load_stream_or_default(str(path_variant))
		if stream:
			character_footstep_streams.append(stream)

	if character_footstep_streams.is_empty():
		character_footstep_streams = slime_move_streams.duplicate()

	character_jump_stream = _load_stream_or_default(str(audio_profile.get("jump", "")), HERO_DEFAULT_JUMP_SFX_PATH if _is_hero_form_active() else "res://Assets/Sounds/jump_slime.mp3")
	character_land_stream = _load_stream_or_default(str(audio_profile.get("land", "")), HERO_DEFAULT_LAND_SFX_PATH if _is_hero_form_active() else "res://Assets/Sounds/land.mp3")
	character_dash_stream = _load_stream_or_default(str(audio_profile.get("dash", "")), DASH_SFX_PATH)
	hero_slide_stream = _load_stream_or_default(str(audio_profile.get("slide", "")), HERO_DEFAULT_SLIDE_SFX_PATH)
	hero_wall_jump_stream = _load_stream_or_default(str(audio_profile.get("wall_jump", "")), HERO_DEFAULT_JUMP_SFX_PATH)


func _sync_feedback_ui(animate: bool = true) -> void:
	if canvas_layer and canvas_layer.has_method("sync_health"):
		canvas_layer.sync_health(current_health, max_health, animate)
	if health_label:
		health_label.text = "HP %d / %d" % [current_health, max_health]


func _show_feedback_banner(text: String, accent: Color, duration: float = 0.4) -> void:
	if canvas_layer and canvas_layer.has_method("show_banner"):
		canvas_layer.show_banner(text, accent, duration)


func _show_feedback_toast(message: String, toast_type: String = "info", icon_texture: Texture2D = null) -> void:
	if canvas_layer and canvas_layer.has_method("show_toast"):
		canvas_layer.show_toast(message, toast_type, icon_texture)


func _show_loot_feedback(item: InvItem) -> void:
	if item == null:
		return

	var pretty_name := _format_item_name(item.name)
	if canvas_layer and canvas_layer.has_method("show_loot_toast"):
		canvas_layer.show_loot_toast(pretty_name, item.texture, 1)
	else:
		_show_feedback_toast("+1 " + pretty_name, "reward", item.texture)

	if item.name in ["golem_heart", "bat_artefact"]:
		_show_feedback_banner("RARE DROP", Color(1.0, 0.84, 0.35), 0.55)


func _format_item_name(item_name: String) -> String:
	return item_name.replace("_", " ").capitalize()


func _world_to_screen(world_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_position


func _spawn_feedback_text(text: String, color: Color, emphasis: float = 1.0) -> void:
	if not canvas_layer:
		return

	var label := Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0)
	label.position = _world_to_screen(global_position + Vector2(randf_range(-20.0, 20.0), -76.0 + randf_range(-8.0, 4.0)))
	label.scale = Vector2.ONE * (0.9 + emphasis * 0.08)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", int(round(18 + emphasis * 4.0)))
	if feedback_font:
		label.add_theme_font_override("font", feedback_font)
	canvas_layer.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - (30.0 + emphasis * 10.0), 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE * (1.04 + emphasis * 0.06), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.16)
	tween.tween_property(label, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)


func _play_dash_sfx() -> void:
	if dash_sound_player:
		dash_sound_player.stream = character_dash_stream if character_dash_stream else dash_stream
		dash_sound_player.volume_db = -8.5 if _is_hero_form_active() else -10.0
		dash_sound_player.pitch_scale = randf_range(1.08, 1.22) if _is_hero_form_active() else randf_range(0.92, 1.06)
		dash_sound_player.play()


func _play_jump_sfx(air_jump: bool = false) -> void:
	if character_jump_stream:
		$JumpSound.stream = character_jump_stream
	$JumpSound.volume_db = -7.5 if _is_hero_form_active() else 0.0
	if _is_hero_form_active():
		$JumpSound.pitch_scale = randf_range(1.04, 1.18) if not air_jump else randf_range(1.18, 1.34)
	else:
		$JumpSound.pitch_scale = randf_range(1.3, 1.75) if not air_jump else randf_range(1.5, 1.8)
	$JumpSound.play()


func _play_land_sfx(hard_landing: bool = false) -> void:
	if character_land_stream:
		$LandSound.stream = character_land_stream
	if _is_hero_form_active():
		$LandSound.pitch_scale = randf_range(0.82, 0.94) if hard_landing else randf_range(0.98, 1.08)
		$LandSound.volume_db = -5.5 if hard_landing else -9.0
	else:
		$LandSound.pitch_scale = 0.8 if hard_landing else 1.2
		$LandSound.volume_db = 0.0 if hard_landing else -20.0
	$LandSound.play()


func _play_hero_slide_sfx() -> void:
	if not hero_slide_sound_player:
		return
	hero_slide_sound_player.stream = hero_slide_stream
	hero_slide_sound_player.pitch_scale = randf_range(0.72, 0.88)
	hero_slide_sound_player.volume_db = -7.0
	hero_slide_sound_player.play()


func _play_hero_wall_jump_sfx() -> void:
	if not hero_wall_jump_sound_player:
		return
	hero_wall_jump_sound_player.stream = hero_wall_jump_stream
	hero_wall_jump_sound_player.pitch_scale = randf_range(1.18, 1.34)
	hero_wall_jump_sound_player.volume_db = -7.5
	hero_wall_jump_sound_player.play()


func _play_crit_sfx() -> void:
	if crit_sound_player and crit_stream:
		crit_sound_player.stream = crit_stream
		crit_sound_player.pitch_scale = randf_range(0.96, 1.05)
		crit_sound_player.play()


func _play_melee_impact(is_crit: bool) -> void:
	if not melee_impact_player:
		return
	if melee_impact_stream:
		melee_impact_player.stream = melee_impact_stream
	if _is_hero_form_active():
		melee_impact_player.pitch_scale = randf_range(1.04, 1.14) if is_crit else randf_range(0.96, 1.08)
		melee_impact_player.volume_db = -4.0 if is_crit else -5.4
	else:
		melee_impact_player.pitch_scale = randf_range(0.95, 1.05) if is_crit else randf_range(0.88, 1.02)
		melee_impact_player.volume_db = -5.5 if is_crit else -7.0
	melee_impact_player.play()


func _set_optional_particle_emission(node_path: NodePath, emitting: bool, restart: bool = false) -> void:
	var particle_node: Node = get_node_or_null(node_path)
	if particle_node == null:
		return

	particle_node.set("emitting", emitting)
	if restart and particle_node.has_method("restart"):
		particle_node.call("restart")


func _play_hit_particles(effect_color: Color) -> void:
	var particle_node: Node = get_node_or_null("PlayerSprite/HitParticles")
	if particle_node == null:
		return

	particle_node.set("modulate", effect_color)
	particle_node.set("emitting", false)
	if particle_node.has_method("restart"):
		particle_node.call("restart")


func _squash_player_sprite(peak_scale: Vector2, duration: float = 0.14) -> void:
	if not $PlayerSprite:
		return

	var tween := create_tween()
	tween.tween_property($PlayerSprite, "scale", peak_scale, duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property($PlayerSprite, "scale", Vector2.ONE, duration * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _update_footsteps() -> void:
	if not is_on_floor() or is_landing or is_dashing or is_attacking or is_hero_ground_sliding:
		return

	if abs(velocity.x) < 55.0:
		return

	var now := Time.get_ticks_usec() / 1_000_000.0
	if now - last_sound_time < sound_cooldown:
		return

	play_walk_sound()
	var speed_factor: float = clampf(abs(velocity.x) / maxf(RUN_SPEED, 1.0), 0.0, 1.0)
	sound_cooldown = lerpf(0.34, 0.23, speed_factor)

func _on_api_timer_timeout():
	api_script.send_request()

func _on_water_entered(body: Node):
	if body.is_in_group("water"):  # Stelle sicher, dass dein Wasser diese Gruppe hat
		is_in_water = true
		#$SplashSound.play()

func _on_water_exited(body: Node):
	if body.is_in_group("water"):
		is_in_water = false
		#$SplashSound.play()

func update_crit_bonuses():
	var total_crit_chance = base_crit_chance
	var total_crit_damage = base_crit_multiplier
	
	for item in _get_equipped_items():
		total_crit_chance += item.crit_chance_bonus
		total_crit_damage += item.crit_damage_bonus
	
	current_crit_chance = clamp(total_crit_chance, 0.0, 0.8)  # Maximal 80% Crit-Chance
	current_crit_multiplier = max(total_crit_damage, 1.0)     # Mindestens 100% Schaden

func update_damage_bonus():
	var bonus := 1.0
	var flat_bonus := 0

	for item in _get_equipped_items():
		bonus += item.damage_bonus
		flat_bonus += item.attack_power_bonus

	damage_multiplier = bonus
	attack_damage = int((base_attack_damage + flat_bonus) * damage_multiplier)

func update_health_bonus():
	var bonus = 1.0
	for item in _get_equipped_items():
		bonus += item.health_bonus

	max_health = int(base_max_health * bonus)
	current_health = min(current_health, max_health)
	sync_max_health.rpc()
	update_health_bar()


func _get_equipped_items() -> Array[InvItem]:
	var equipped_items: Array[InvItem] = []
	if inv == null:
		return equipped_items

	var has_weapon := false
	for item in inv.get_equipped_items():
		if item:
			if item.equip_slot == "weapon":
				has_weapon = true
			equipped_items.append(item)
	if not has_weapon:
		var default_weapon := ItemRegistry.get_default_weapon()
		if default_weapon:
			equipped_items.append(default_weapon)
	return equipped_items


func _get_equipped_weapon_or_default() -> InvItem:
	if inv:
		var weapon := inv.get_equipped_item("weapon")
		if weapon:
			return weapon
	return ItemRegistry.get_default_weapon()


func _on_inventory_equipment_changed() -> void:
	equipped_weapon = _get_equipped_weapon_or_default()
	equipped_weapon_name = equipped_weapon.name if equipped_weapon else ""
	_refresh_player_tuning_from_skills()
	_update_equipped_weapon_visual(true)


func _setup_star_manager() -> void:
	if star_manager != null and is_instance_valid(star_manager):
		return
	star_manager = get_node_or_null("StarManager")
	if star_manager == null:
		star_manager = StarManager.new()
		star_manager.name = "StarManager"
		add_child(star_manager)
	if star_manager.has_method("setup"):
		star_manager.call("setup", self, inv)


func _get_active_star_companions() -> Array[Node]:
	var stars: Array[Node] = []
	for node in get_tree().get_nodes_in_group("active_star_companion"):
		if node is Node:
			stars.append(node)
	return stars


func _notify_star_damage(player_damage: float) -> void:
	for star in _get_active_star_companions():
		if star.has_method("add_skill_points_from_player_damage"):
			star.call("add_skill_points_from_player_damage", player_damage)


func _notify_star_finisher() -> void:
	for star in _get_active_star_companions():
		if star.has_method("notify_player_kill"):
			star.call("notify_player_kill")


func _configure_attack_sprite_visual() -> void:
	if attack_sprite == null:
		return
	attack_sprite.self_modulate = Color(1.0, 1.0, 1.0, 0.0)


func _configure_equipped_weapon_sprite() -> void:
	if equipped_weapon_sprite == null:
		return
	equipped_weapon_sprite.centered = true
	equipped_weapon_sprite.offset = weapon_grip_offset_runtime
	equipped_weapon_sprite.z_index = 4


func _setup_weapon_afterimages() -> void:
	for ghost in weapon_afterimage_sprites:
		if is_instance_valid(ghost):
			ghost.queue_free()
	weapon_afterimage_sprites.clear()
	weapon_transform_history.clear()

	if equipped_weapon_sprite == null:
		return

	var parent := equipped_weapon_sprite.get_parent()
	if parent == null:
		return

	for index in range(WEAPON_AFTERIMAGE_COUNT):
		var ghost := Sprite2D.new()
		ghost.centered = equipped_weapon_sprite.centered
		ghost.offset = equipped_weapon_sprite.offset
		ghost.z_index = equipped_weapon_sprite.z_index - 1 - index
		ghost.visible = false
		ghost.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		parent.add_child(ghost)
		weapon_afterimage_sprites.append(ghost)


func _ensure_runtime_body_sprite() -> void:
	if runtime_body_sprite != null and is_instance_valid(runtime_body_sprite):
		return

	runtime_body_sprite = Sprite2D.new()
	runtime_body_sprite.name = "RuntimeBodySprite"
	runtime_body_sprite.centered = true
	runtime_body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	runtime_body_sprite.visible = false
	runtime_body_sprite.z_index = $PlayerSprite.z_index
	add_child(runtime_body_sprite)
	move_child(runtime_body_sprite, $PlayerSprite.get_index())


func _sync_runtime_body_visual() -> void:
	if runtime_body_sprite == null or not is_instance_valid(runtime_body_sprite):
		return

	if not uses_runtime_character_animation:
		runtime_body_sprite.visible = false
		return

	runtime_body_sprite.visible = true
	runtime_body_sprite.position = $PlayerSprite.position
	runtime_body_sprite.rotation = $PlayerSprite.rotation
	runtime_body_sprite.flip_h = $PlayerSprite.flip_h
	runtime_body_sprite.modulate = $PlayerSprite.modulate
	runtime_body_sprite.self_modulate = Color.WHITE
	runtime_body_sprite.scale = Vector2(
		runtime_body_base_scale.x * $PlayerSprite.scale.x,
		runtime_body_base_scale.y * $PlayerSprite.scale.y
	)


func _get_active_body_sprite() -> Sprite2D:
	if uses_runtime_character_animation and runtime_body_sprite != null and is_instance_valid(runtime_body_sprite):
		return runtime_body_sprite
	return $PlayerSprite


func _snapshot_body_sprite(target: Sprite2D, source: Sprite2D) -> void:
	target.texture = source.texture
	target.region_enabled = source.region_enabled
	target.region_rect = source.region_rect
	target.hframes = source.hframes
	target.vframes = source.vframes
	target.frame = source.frame
	target.centered = source.centered
	target.offset = source.offset
	target.flip_h = source.flip_h
	target.texture_filter = source.texture_filter
	target.global_position = source.global_position
	target.global_rotation = source.global_rotation
	target.global_scale = source.global_scale


func get_current_character_id() -> String:
	return current_character_id


func _is_hero_form_active() -> bool:
	return current_character_id == CharacterCatalog.MALE_HERO_ID


func _character_can(capability_name: String, default_value: bool = false) -> bool:
	return bool(current_character_capabilities.get(capability_name, default_value))


func _get_profile_dictionary(profile_name: String) -> Dictionary:
	return current_character_profile.get(profile_name, {}) as Dictionary


func _apply_collision_profile(profile_name: String = "standing") -> void:
	var collision_shape := get_node_or_null("ColisionArea") as CollisionShape2D
	if collision_shape == null or not (collision_shape.shape is RectangleShape2D):
		return

	var profile: Dictionary = current_collision_profiles.get(profile_name, {}) as Dictionary
	if profile.is_empty():
		profile = {
			"position": default_collision_shape_position,
			"rotation": default_collision_shape_rotation,
			"scale": default_collision_shape_scale,
			"size": default_collision_shape_size,
		}

	collision_shape.position = profile.get("position", default_collision_shape_position)
	collision_shape.rotation = float(profile.get("rotation", default_collision_shape_rotation))
	collision_shape.scale = profile.get("scale", default_collision_shape_scale)
	(collision_shape.shape as RectangleShape2D).size = profile.get("size", default_collision_shape_size)


func _spawn_hero_combat_effect(effect_kind: String, effect_position: Vector2, effect_color: Color, effect_intensity: float = 1.0, effect_rotation: float = 0.0, facing_override: Variant = null) -> void:
	if get_parent() == null:
		return
	var effect := HeroCombatEffectScene.new()
	effect.global_position = effect_position
	effect.z_index = 18
	var effect_facing_left := is_facing_left if facing_override == null else bool(facing_override)
	effect.configure(effect_kind, effect_facing_left, effect_color, effect_intensity, effect_rotation)
	get_parent().add_child(effect)


func _get_mobility_effect_color(effect_kind: String) -> Color:
	if _is_hero_form_active():
		match effect_kind:
			"air_jump":
				return Color(0.76, 1.0, 0.9, 0.94)
			"landing":
				return Color(0.84, 1.0, 0.9, 0.96)
			_:
				return Color(0.72, 1.0, 0.92, 0.92)

	match effect_kind:
		"air_jump":
			return Color(0.78, 1.0, 0.74, 0.88)
		"landing":
			return Color(0.9, 1.0, 0.82, 0.92)
		_:
			return Color(0.84, 1.0, 0.84, 0.9)


func _spawn_air_jump_effect() -> void:
	var effect_position := global_position + Vector2(clampf(velocity.x * 0.03, -8.0, 8.0), 14.0 if _is_hero_form_active() else 18.0)
	var intensity := 1.12 if _is_hero_form_active() else 0.98
	_spawn_hero_combat_effect("air_jump", effect_position, _get_mobility_effect_color("air_jump"), intensity)


func _spawn_landing_effect(landing_strength: float) -> void:
	var ground_offset := _get_collision_ground_offset_world() if _is_hero_form_active() else 30.0
	var effect_position := global_position + Vector2(0.0, ground_offset)
	var intensity := clampf(0.92 + landing_strength * (0.24 if _is_hero_form_active() else 0.18), 0.9, 1.36)
	_spawn_hero_combat_effect("landing", effect_position, _get_mobility_effect_color("landing"), intensity)


func _get_collision_ground_offset_world() -> float:
	var collision_shape := get_node_or_null("ColisionArea") as CollisionShape2D
	if collision_shape == null or not (collision_shape.shape is RectangleShape2D):
		return 40.0
	var rect := collision_shape.shape as RectangleShape2D
	var bottom_local := collision_shape.position.y + rect.size.y * collision_shape.scale.y * 0.5
	return bottom_local * absf(global_scale.y)


func _get_collision_half_width_world() -> float:
	var collision_shape := get_node_or_null("ColisionArea") as CollisionShape2D
	if collision_shape == null or not (collision_shape.shape is RectangleShape2D):
		return 34.0
	var rect := collision_shape.shape as RectangleShape2D
	return rect.size.x * collision_shape.scale.x * absf(global_scale.x) * 0.5


func _apply_default_character_profile() -> void:
	_apply_character_profile(CharacterCatalog.SLIME_ID)


func _apply_character_profile(character_id: String) -> void:
	_ensure_runtime_body_sprite()
	if is_hero_ground_sliding:
		_end_hero_ground_slide(false)
	current_character_id = character_id
	is_hero_form_active = current_character_id == CharacterCatalog.MALE_HERO_ID
	current_character_meta = CharacterCatalog.get_character_meta(current_character_id)
	current_character_profile = CharacterCatalog.get_runtime_profile(current_character_id)
	current_character_capabilities = current_character_profile.get("capabilities", {}) as Dictionary
	current_collision_profiles = current_character_profile.get("collision", {}) as Dictionary
	hero_slide_config = current_character_profile.get("ground_slide", {}) as Dictionary
	hero_combat_config = current_character_profile.get("combat", {}) as Dictionary
	uses_runtime_character_animation = String(current_character_profile.get("animation_mode", "legacy")) == "runtime"

	var movement: Dictionary = current_character_profile.get("movement", {}) as Dictionary
	base_walk_speed = float(movement.get("base_walk_speed", DEFAULT_WALK_SPEED))
	base_run_speed = float(movement.get("base_run_speed", DEFAULT_RUN_SPEED))
	ACCELERATION = float(movement.get("acceleration", 1800.0))
	DECELERATION = float(movement.get("deceleration", 2400.0))
	AIR_ACCELERATION = float(movement.get("air_acceleration", 1200.0))
	AIR_DECELERATION = float(movement.get("air_deceleration", 800.0))
	gravity_force = float(movement.get("gravity", GRAVITY))
	max_fall_speed_value = float(movement.get("max_fall_speed", MAX_FALL_SPEED))
	jump_velocity_force = float(movement.get("jump_velocity", JUMP_VELOCITY))
	air_jump_velocity_force = float(movement.get("air_jump_velocity", AIR_JUMP_VELOCITY))
	wall_jump_velocity_x_value = float(movement.get("wall_jump_velocity_x", WALL_JUMP_VELOCITY_X))
	wall_jump_velocity_y_value = float(movement.get("wall_jump_velocity_y", WALL_JUMP_VELOCITY_Y))
	base_wall_slide_speed = float(movement.get("wall_slide_speed", WALL_SLIDE_SPEED))
	base_wall_run_vertical_speed = float(movement.get("wall_run_vertical_speed", 150.0))
	base_dash_speed = float(movement.get("dash_speed", BASE_DASH_SPEED))
	base_dash_duration = float(movement.get("dash_duration", BASE_DASH_DURATION))
	base_dash_cooldown = float(movement.get("dash_cooldown", BASE_DASH_COOLDOWN))

	var weapon_visual: Dictionary = current_character_profile.get("weapon_visual", {}) as Dictionary
	show_equipped_weapon_visual = bool(weapon_visual.get("show_equipped_weapon", true))
	weapon_idle_position = weapon_visual.get("idle_position", WEAPON_IDLE_POSITION)
	weapon_idle_rotation = float(weapon_visual.get("idle_rotation", WEAPON_IDLE_ROTATION))
	weapon_base_scale = float(weapon_visual.get("base_scale", WEAPON_BASE_SCALE))
	weapon_grip_offset_runtime = weapon_visual.get("grip_offset", WEAPON_GRIP_OFFSET)
	_configure_character_audio()
	_apply_collision_profile("standing")
	is_wall_sliding = false
	is_wall_running = false
	wall_run_active = false

	if $PlayerSprite:
		$PlayerSprite.scale = default_player_sprite_scale
		if uses_runtime_character_animation:
			var sprite_settings: Dictionary = current_character_profile.get("sprite", {}) as Dictionary
			runtime_body_base_scale = sprite_settings.get("scale", Vector2.ONE)
			$AnimationPlayer.stop()
			$PlayerSprite.texture = null
			$PlayerSprite.region_enabled = false
			$PlayerSprite.region_rect = Rect2()
			$PlayerSprite.hframes = default_player_sprite_hframes
			$PlayerSprite.vframes = default_player_sprite_vframes
			$PlayerSprite.position = sprite_settings.get("position", default_player_sprite_position)
			$PlayerSprite.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
			if runtime_body_sprite:
				runtime_body_sprite.texture = null
				runtime_body_sprite.region_enabled = false
				runtime_body_sprite.region_rect = Rect2()
				runtime_body_sprite.position = $PlayerSprite.position
				runtime_body_sprite.scale = runtime_body_base_scale
				runtime_body_sprite.modulate = $PlayerSprite.modulate
				runtime_body_sprite.visible = true
		else:
			runtime_body_base_scale = Vector2.ONE
			$PlayerSprite.region_enabled = false
			$PlayerSprite.region_rect = Rect2()
			$PlayerSprite.texture = default_player_sprite_texture
			$PlayerSprite.hframes = default_player_sprite_hframes
			$PlayerSprite.vframes = default_player_sprite_vframes
			$PlayerSprite.frame = 0
			$PlayerSprite.position = default_player_sprite_position
			$PlayerSprite.self_modulate = default_player_sprite_self_modulate
			if $AnimationPlayer.current_animation.is_empty():
				$AnimationPlayer.play("idle")
			if runtime_body_sprite:
				runtime_body_sprite.texture = null
				runtime_body_sprite.region_enabled = false
				runtime_body_sprite.region_rect = Rect2()
				runtime_body_sprite.scale = Vector2.ONE
				runtime_body_sprite.visible = false

	runtime_animation_state = ""
	runtime_animation_elapsed = 0.0
	runtime_landing_animation = "landing"
	runtime_attack_elapsed = 0.0
	runtime_turn_timer = 0.0
	runtime_turn_animation = ""
	runtime_stop_timer = 0.0
	runtime_fall_transition_timer = 0.0
	runtime_wall_jump_timer = 0.0
	runtime_hurt_timer = 0.0
	runtime_dash_timer = 0.0
	runtime_death_active = false
	was_descending = false
	last_floor_velocity = 0.0

	if uses_runtime_character_animation:
		_set_runtime_animation("idle", true)
		_sync_runtime_body_visual()


func _get_runtime_character_animation_descriptor(animation_name: String) -> Dictionary:
	if not uses_runtime_character_animation:
		return {}
	var animations: Dictionary = current_character_profile.get("animations", {}) as Dictionary
	if animations.has(animation_name):
		return (animations[animation_name] as Dictionary).duplicate(true)
	if animations.has("idle"):
		return (animations["idle"] as Dictionary).duplicate(true)
	return {}


func _get_runtime_animation_frame_count(descriptor: Dictionary) -> int:
	var hframes := maxi(int(descriptor.get("hframes", 1)), 1)
	var vframes := maxi(int(descriptor.get("vframes", 1)), 1)
	return maxi(int(descriptor.get("frame_count", hframes * vframes)), 1)


func _get_runtime_animation_length(animation_name: String) -> float:
	var descriptor := _get_runtime_character_animation_descriptor(animation_name)
	if descriptor.is_empty():
		return 0.0
	var frame_count := _get_runtime_animation_frame_count(descriptor)
	var fps := maxf(float(descriptor.get("fps", 1.0)), 0.01)
	return float(frame_count) / fps


func _set_runtime_animation(animation_name: String, force: bool = false) -> void:
	if not uses_runtime_character_animation:
		return
	if not force and runtime_animation_state == animation_name:
		return
	runtime_animation_state = animation_name
	runtime_animation_elapsed = 0.0
	_apply_runtime_animation_frame(animation_name, 0)


func _apply_runtime_animation_frame(animation_name: String, frame_index: int) -> void:
	var descriptor := _get_runtime_character_animation_descriptor(animation_name)
	if descriptor.is_empty():
		return

	var texture_path := String(descriptor.get("texture_path", ""))
	var texture := CharacterCatalog.load_texture(texture_path)
	if texture == null:
		return

	var hframes := maxi(int(descriptor.get("hframes", 1)), 1)
	var vframes := maxi(int(descriptor.get("vframes", 1)), 1)
	var frame_count := _get_runtime_animation_frame_count(descriptor)
	var clamped_frame := clampi(frame_index, 0, frame_count - 1)
	var frame_size := Vector2(
		float(texture.get_width()) / float(hframes),
		float(texture.get_height()) / float(vframes)
	)
	var frame_position := Vector2(
		float(clamped_frame % hframes) * frame_size.x,
		float(int(clamped_frame / hframes)) * frame_size.y
	)
	var target_sprite := runtime_body_sprite if uses_runtime_character_animation else $PlayerSprite
	if target_sprite == null:
		return
	target_sprite.texture = texture
	target_sprite.region_enabled = true
	target_sprite.hframes = 1
	target_sprite.vframes = 1
	target_sprite.region_rect = Rect2(frame_position, frame_size)
	_sync_runtime_body_visual()


func _spawn_transform_echo(source: Sprite2D, tint: Color, drift: Vector2, duration: float) -> void:
	if source == null or source.texture == null or get_parent() == null:
		return

	var echo := Sprite2D.new()
	_snapshot_body_sprite(echo, source)
	echo.z_index = source.z_index + 3
	echo.modulate = tint
	echo.self_modulate = Color.WHITE
	get_parent().add_child(echo)

	var tween := create_tween()
	tween.tween_property(echo, "global_position", echo.global_position + drift, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(echo, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(echo.queue_free)


func _spawn_transform_effect(to_hero: bool) -> void:
	var effect := HeroTransformEffectScene.new()
	effect.z_index = 12
	effect.configure(to_hero, 118.0)
	add_child(effect)


func toggle_hero_form() -> void:
	if not has_hero_form_skill:
		_show_feedback_toast("Hero Form ist noch nicht freigeschaltet.", "warning", null)
		return
	if runtime_death_active or is_transforming_hero_form or is_stunned or is_charging:
		return

	var transform_to_hero := current_character_id != CharacterCatalog.MALE_HERO_ID
	_start_hero_form_transform(transform_to_hero)


func _start_hero_form_transform(transform_to_hero: bool) -> void:
	is_transforming_hero_form = true
	hero_transform_timer = HERO_TRANSFORM_DURATION
	hero_transform_target_id = CharacterCatalog.MALE_HERO_ID if transform_to_hero else CharacterCatalog.SLIME_ID
	queued_attack_timer = 0.0
	is_attacking = false
	is_dashing = false
	if is_hero_ground_sliding:
		_end_hero_ground_slide(false)
	is_landing = false
	velocity = Vector2.ZERO
	runtime_animation_state = ""
	_update_equipped_weapon_visual()

	var outgoing := _get_active_body_sprite()
	_spawn_transform_effect(transform_to_hero)
	_spawn_transform_echo(outgoing, Color(0.48, 1.0, 0.64, 0.62), Vector2(-10.0 if is_facing_left else 10.0, -10.0), 0.34)
	$Camera2D.shake(1.2, 0.22)
	_squash_player_sprite(Vector2(1.08, 0.9), 0.18)
	_play_dash_sfx()
	_show_feedback_banner("HERO FORM" if transform_to_hero else "JOEY FORM", Color(0.96, 0.54, 0.9, 1.0) if transform_to_hero else Color(0.58, 1.0, 0.64, 1.0), 0.32)

	await get_tree().create_timer(HERO_TRANSFORM_SWAP_TIME).timeout
	if not is_instance_valid(self):
		return

	_apply_character_profile(hero_transform_target_id)
	is_hero_form_active = transform_to_hero
	_refresh_player_tuning_from_skills()
	update_facing_direction()
	_update_runtime_character_animation(0.0)
	_update_equipped_weapon_visual(true)
	var incoming := _get_active_body_sprite()
	_spawn_transform_echo(incoming, Color(1.0, 0.78, 0.98, 0.5) if transform_to_hero else Color(0.62, 1.0, 0.68, 0.5), Vector2.ZERO, 0.26)

	await get_tree().create_timer(maxf(HERO_TRANSFORM_DURATION - HERO_TRANSFORM_SWAP_TIME, 0.05)).timeout
	if not is_instance_valid(self):
		return
	is_transforming_hero_form = false
	hero_transform_timer = 0.0
	_squash_player_sprite(Vector2(0.96, 1.06), 0.16)


func _resolve_runtime_animation_name() -> String:
	if runtime_death_active:
		return "death"
	if runtime_hurt_timer > 0.0:
		return "hurt"
	if is_attacking:
		var attack_name := "attack_%d" % (current_attack_step + 1)
		var active_window: float = float(combo_active_times[current_attack_step])
		if runtime_attack_elapsed > active_window and not _get_runtime_character_animation_descriptor("%s_end" % attack_name).is_empty():
			return "%s_end" % attack_name
		return attack_name
	if is_hero_ground_sliding:
		return "ground_slide"
	if is_landing:
		if not _get_runtime_character_animation_descriptor(runtime_landing_animation).is_empty():
			return runtime_landing_animation
		return "landing"
	if runtime_dash_timer > 0.0 or is_dashing:
		return "dash"
	if runtime_wall_jump_timer > 0.0:
		return "wall_jump"
	if runtime_turn_timer > 0.0 and not runtime_turn_animation.is_empty():
		return runtime_turn_animation
	if runtime_stop_timer > 0.0:
		return "run_to_idle"
	if is_wall_sliding:
		return "wall_slide"
	if not is_on_floor():
		if velocity.y < -28.0:
			return "jump"
		if runtime_fall_transition_timer > 0.0:
			return "fall"
		return "fall_loop"
	if abs(velocity.x) > maxf(RUN_SPEED * 0.72, 120.0):
		return "run"
	if abs(velocity.x) > 14.0:
		return "walk"
	return "idle"


func _update_runtime_character_animation(delta: float) -> void:
	if not uses_runtime_character_animation:
		return

	if not is_on_floor() and velocity.y > 22.0:
		if not was_descending:
			runtime_fall_transition_timer = _get_runtime_animation_length("fall")
			runtime_animation_state = ""
		was_descending = true
	elif is_on_floor() or velocity.y <= 0.0:
		was_descending = false

	if is_on_floor():
		if abs(velocity.x) < 10.0 and last_floor_velocity > RUN_SPEED * 0.72 and runtime_stop_timer <= 0.0 and runtime_turn_timer <= 0.0 and not is_landing and not is_attacking:
			runtime_stop_timer = _get_runtime_animation_length("run_to_idle")
			runtime_animation_state = ""
		last_floor_velocity = abs(velocity.x)
	else:
		last_floor_velocity = 0.0

	var target_animation := _resolve_runtime_animation_name()
	if target_animation != runtime_animation_state:
		_set_runtime_animation(target_animation, true)
	else:
		runtime_animation_elapsed += delta

	var descriptor := _get_runtime_character_animation_descriptor(runtime_animation_state)
	if descriptor.is_empty():
		return

	var frame_count := _get_runtime_animation_frame_count(descriptor)
	var fps := maxf(float(descriptor.get("fps", 1.0)), 0.01)
	var frame_index := int(floor(runtime_animation_elapsed * fps))
	if bool(descriptor.get("loop", false)):
		frame_index %= frame_count
	else:
		frame_index = mini(frame_index, frame_count - 1)

	_apply_runtime_animation_frame(runtime_animation_state, frame_index)


func _start_weapon_attack_animation(step: int) -> void:
	weapon_visual_step = clampi(step, 0, WEAPON_ATTACK_PROFILES.size() - 1)
	weapon_visual_anim_time = 0.0
	weapon_visual_anim_duration = combo_active_times[weapon_visual_step] + combo_recovery_times[weapon_visual_step]
	weapon_transform_history.clear()


func _is_gameplay_input_blocked() -> bool:
	var inv_ui := get_node_or_null("CanvasLayer/InvUI")
	return inv_ui is Control and inv_ui.visible


func _weapon_visual_phase() -> float:
	if weapon_visual_anim_duration <= 0.0:
		return 1.0
	return clampf(weapon_visual_anim_time / weapon_visual_anim_duration, 0.0, 1.0)


func _ease_out_cubic(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)


func _ease_in_out(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _mirror_weapon_vector(vector: Vector2, facing_sign: float) -> Vector2:
	return Vector2(vector.x * facing_sign, vector.y)


func _get_weapon_afterimage_color(weapon: InvItem) -> Color:
	if weapon == null:
		return Color(0.92, 0.98, 1.0, 0.26)
	match weapon.rarity:
		"legendary":
			return Color(1.0, 0.72, 0.48, 0.28)
		"epic":
			return Color(0.88, 0.62, 1.0, 0.28)
		"rare":
			return Color(0.62, 0.86, 1.0, 0.28)
		"uncommon":
			return Color(0.64, 1.0, 0.78, 0.24)
		_:
			return Color(0.92, 0.98, 1.0, 0.2)


func _update_weapon_afterimages(weapon: InvItem, active_visual: bool) -> void:
	if weapon_afterimage_sprites.is_empty():
		return

	if not active_visual or weapon == null:
		weapon_transform_history.clear()
		for ghost in weapon_afterimage_sprites:
			ghost.visible = false
		return

	weapon_transform_history.push_front({
		"position": equipped_weapon_sprite.position,
		"rotation": equipped_weapon_sprite.rotation,
		"scale": equipped_weapon_sprite.scale,
	})
	while weapon_transform_history.size() > 10:
		weapon_transform_history.pop_back()

	var base_color := _get_weapon_afterimage_color(weapon)
	for index in range(weapon_afterimage_sprites.size()):
		var ghost := weapon_afterimage_sprites[index]
		var sample_index := (index + 1) * 2
		if sample_index >= weapon_transform_history.size():
			ghost.visible = false
			continue

		var sample: Dictionary = weapon_transform_history[sample_index]
		ghost.texture = weapon.texture
		ghost.position = sample.get("position", Vector2.ZERO)
		ghost.rotation = sample.get("rotation", 0.0)
		ghost.scale = sample.get("scale", Vector2.ONE)
		ghost.offset = equipped_weapon_sprite.offset
		ghost.visible = true
		var alpha: float = max(base_color.a - float(index) * 0.09, 0.08)
		ghost.self_modulate = Color(base_color.r, base_color.g, base_color.b, alpha)


func _get_weapon_visual_state(facing_sign: float, idle_bob: float) -> Dictionary:
	var idle_position := Vector2(weapon_idle_position.x * facing_sign, weapon_idle_position.y + idle_bob * 0.35)
	var idle_rotation := weapon_idle_rotation * facing_sign + idle_bob * 0.35
	var scale_amount := weapon_base_scale

	if weapon_visual_anim_duration <= 0.0 or weapon_visual_anim_time >= weapon_visual_anim_duration:
		return {
			"position": idle_position,
			"rotation": idle_rotation,
			"scale": scale_amount,
		}

	var profile: Dictionary = WEAPON_ATTACK_PROFILES[weapon_visual_step]
	var windup_pos := _mirror_weapon_vector(profile.get("windup_pos", weapon_idle_position), facing_sign)
	var strike_pos := _mirror_weapon_vector(profile.get("strike_pos", weapon_idle_position), facing_sign)
	var recover_pos := _mirror_weapon_vector(profile.get("recover_pos", weapon_idle_position), facing_sign)
	var windup_rot := float(profile.get("windup_rot", idle_rotation)) * facing_sign
	var strike_rot := float(profile.get("strike_rot", idle_rotation)) * facing_sign
	var recover_rot := float(profile.get("recover_rot", idle_rotation)) * facing_sign
	var attack_scale := float(profile.get("scale", weapon_base_scale))

	var phase := _weapon_visual_phase()
	var position := idle_position
	var rotation := idle_rotation

	if phase < 0.18:
		var t := _ease_out_cubic(phase / 0.18)
		position = idle_position.lerp(windup_pos, t)
		rotation = lerpf(idle_rotation, windup_rot, t)
		scale_amount = lerpf(weapon_base_scale, attack_scale * 0.96, t)
	elif phase < 0.58:
		var t := _ease_out_cubic((phase - 0.18) / 0.40)
		position = windup_pos.lerp(strike_pos, t)
		rotation = lerpf(windup_rot, strike_rot, t)
		scale_amount = lerpf(attack_scale * 0.96, attack_scale, t)
	else:
		var t := _ease_in_out((phase - 0.58) / 0.42)
		position = strike_pos.lerp(recover_pos, t)
		rotation = lerpf(strike_rot, recover_rot, t)
		scale_amount = lerpf(attack_scale, weapon_base_scale, t)

	return {
		"position": position,
		"rotation": rotation,
		"scale": scale_amount,
	}


func _update_equipped_weapon_visual(force_texture_refresh: bool = false) -> void:
	if equipped_weapon_sprite == null:
		return

	if not show_equipped_weapon_visual:
		equipped_weapon_sprite.visible = false
		_update_weapon_afterimages(null, false)
		return

	var weapon := equipped_weapon if equipped_weapon != null else _get_equipped_weapon_or_default()
	if weapon == null:
		equipped_weapon_sprite.visible = false
		_update_weapon_afterimages(null, false)
		return

	if force_texture_refresh or equipped_weapon_sprite.texture != weapon.texture:
		equipped_weapon_sprite.texture = weapon.texture

	equipped_weapon_sprite.visible = true
	var facing_sign := -1.0 if is_facing_left else 1.0
	var idle_bob := sin(Time.get_ticks_msec() / 180.0) * 2.0
	var visual_state := _get_weapon_visual_state(facing_sign, idle_bob)
	var scale_amount := float(visual_state.get("scale", weapon_base_scale))
	equipped_weapon_sprite.position = visual_state.get("position", Vector2.ZERO)
	equipped_weapon_sprite.rotation_degrees = float(visual_state.get("rotation", 0.0))
	equipped_weapon_sprite.scale = Vector2(scale_amount * facing_sign, scale_amount)
	_update_weapon_afterimages(weapon, weapon_visual_anim_time < weapon_visual_anim_duration)

# Lebensanzeige aktualisieren
@rpc("reliable", "call_remote")
func update_health_bar():
	health_bar.value = current_health
	health_bar.max_value = max_health
	_sync_feedback_ui()
	
func update_facing_direction():
	if !is_multiplayer_authority():
		return

	var previous_facing := is_facing_left
	
	if abs(direction.x) > 0.0:
		is_facing_left = direction.x < 0
	elif Input.is_action_pressed("left"):
		is_facing_left = true
	elif Input.is_action_pressed("right"):
		is_facing_left = false
	else:
		var mouse_pos = get_global_mouse_position()
		is_facing_left = mouse_pos.x < global_position.x

	if uses_runtime_character_animation and previous_facing != is_facing_left and is_on_floor() and not is_attacking and not is_landing and not is_dashing and not is_hero_ground_sliding:
		var speed: float = absf(velocity.x)
		if speed > maxf(RUN_SPEED * 0.72, 120.0):
			runtime_turn_animation = "run_turn"
		elif speed > 40.0:
			runtime_turn_animation = "walk_turn"
		else:
			runtime_turn_animation = "idle_turn"
		runtime_turn_timer = _get_runtime_animation_length(runtime_turn_animation)
		runtime_animation_state = ""

	$PlayerSprite.flip_h = is_facing_left
	$PlayerSprite/AttackSprite.flip_h = is_facing_left
	_update_equipped_weapon_visual()
	
	# Blickrichtung an alle Clients synchronisieren
	sync_facing_direction.rpc(is_facing_left)

@rpc("any_peer", "call_local", "unreliable")
func sync_facing_direction(new_facing: bool):
	if !is_multiplayer_authority():
		is_facing_left = new_facing
		$PlayerSprite.flip_h = is_facing_left
		$PlayerSprite/AttackSprite.flip_h = is_facing_left
		_update_equipped_weapon_visual()

func _process(delta: float) -> void:
	_sync_runtime_body_visual()

	if !is_multiplayer_authority():
		return

	if runtime_death_active:
		_update_equipped_weapon_visual()
		return
		
	if is_landing and !Input.is_action_just_pressed("Attack") and !Input.is_action_just_pressed("Glow"):
		return
	
	if global_position.y > 2000:
		current_health = 0
		update_health_bar()
		stop_healing()
		die()

	if _is_gameplay_input_blocked():
		queued_attack_timer = 0.0
		_update_equipped_weapon_visual()
		return

	if Input.is_action_just_pressed("hero_transform") or (has_hero_form_skill and Input.is_action_just_pressed("sticky_form")):
		toggle_hero_form()
		return
	
	# Angriff ausführen oder für Combo puffern
	if Input.is_action_just_pressed("Attack"):
		perform_attack()
	
	if Input.is_action_just_pressed("throw_slimeball") and slimeball_scene and not _is_hero_form_active():
		throw_slimeball()

	# Leuchteffekt umschalten
	if Input.is_action_just_pressed("Glow"):
		is_glowing = !is_glowing
		update_glow_state()
		sync_glow_state.rpc(is_glowing)

	if Input.is_action_just_pressed("drop_item"):  
		drop_hotbar_item()
	if Input.is_action_just_pressed("ult"):
		charge()
		print("Charge completed!")

	_update_equipped_weapon_visual()

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		if runtime_death_active:
			_update_runtime_character_animation(delta)
			return
		if is_transforming_hero_form:
			hero_transform_timer = maxf(hero_transform_timer - delta, 0.0)
			velocity = velocity.move_toward(Vector2.ZERO, 3600.0 * delta)
			_process_combat_timers(delta)
			move_and_slide()
			_update_runtime_character_animation(delta)
			_sync_runtime_body_visual()
			update_position.rpc(position, velocity)
			return
		handle_input()
		_check_lumora_interaction()
		_process_combat_timers(delta)
		handle_sticky_form_timers(delta)
		
		if is_in_water:
			apply_water_physics(delta)
		else:
			handle_jump_mechanics(delta)
			handle_wall_mechanics(delta)
			handle_dash(delta)
			handle_wall_run(delta)
			handle_slime_wings(delta)
			
			if not is_gliding and not is_dashing and not is_sticky_form_active and not is_hero_ground_sliding:
				apply_gravity(delta)
			
			handle_sticky_form_mechanics(delta)
		
			move_and_slide()
			_process_active_attack_overlaps()
			update_facing_direction()
			update_animations()
			_update_runtime_character_animation(delta)
			_update_footsteps()
			update_position.rpc(position, velocity)

	_sync_runtime_body_visual()
	
	# Mana-Schild Regeneration
	if mana_shield_active and mana_shield_health < max_mana_shield_health:
		mana_shield_regen_timer += delta
		if mana_shield_regen_timer >= 1.0:  # Jede Sekunde regenerieren
			mana_shield_health = min(mana_shield_health + mana_shield_regen_rate, max_mana_shield_health)
			mana_shield_regen_timer = 0.0

func _process_combat_timers(delta: float) -> void:
	if weapon_visual_anim_time < weapon_visual_anim_duration:
		weapon_visual_anim_time = min(weapon_visual_anim_time + delta, weapon_visual_anim_duration)

	if is_attacking:
		runtime_attack_elapsed += delta
	else:
		runtime_attack_elapsed = 0.0

	if runtime_turn_timer > 0.0:
		runtime_turn_timer = max(runtime_turn_timer - delta, 0.0)

	if runtime_stop_timer > 0.0:
		runtime_stop_timer = max(runtime_stop_timer - delta, 0.0)

	if runtime_fall_transition_timer > 0.0:
		runtime_fall_transition_timer = max(runtime_fall_transition_timer - delta, 0.0)

	if runtime_wall_jump_timer > 0.0:
		runtime_wall_jump_timer = max(runtime_wall_jump_timer - delta, 0.0)

	if runtime_hurt_timer > 0.0:
		runtime_hurt_timer = max(runtime_hurt_timer - delta, 0.0)

	if runtime_dash_timer > 0.0:
		runtime_dash_timer = max(runtime_dash_timer - delta, 0.0)

	if hero_slide_cooldown_timer > 0.0:
		hero_slide_cooldown_timer = maxf(hero_slide_cooldown_timer - delta, 0.0)

	if hero_momentum_attack_timer > 0.0:
		hero_momentum_attack_timer = maxf(hero_momentum_attack_timer - delta, 0.0)

	if weapon_speed_burst_timer > 0.0:
		weapon_speed_burst_timer = max(weapon_speed_burst_timer - delta, 0.0)
		if weapon_speed_burst_timer == 0.0 and weapon_speed_burst_bonus != 0.0:
			weapon_speed_burst_bonus = 0.0
			_refresh_player_tuning_from_skills()

	if combo_reset_timer > 0.0:
		combo_reset_timer = max(combo_reset_timer - delta, 0.0)
		if combo_reset_timer == 0.0 and not is_attacking:
			attack_combo_count = 0
			current_attack_step = 0

	if queued_attack_timer > 0.0:
		queued_attack_timer = max(queued_attack_timer - delta, 0.0)
		if queued_attack_timer > 0.0 and not is_attacking:
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_attack_time >= attack_cooldown:
				perform_attack()

	if dash_invulnerability_timer > 0.0:
		dash_invulnerability_timer = max(dash_invulnerability_timer - delta, 0.0)

	if dash_attack_bonus_timer > 0.0:
		dash_attack_bonus_timer = max(dash_attack_bonus_timer - delta, 0.0)

@rpc("unreliable")  
func update_position(new_pos: Vector2, new_vel: Vector2):
	if !is_multiplayer_authority():
		position = new_pos
		velocity = new_vel

func apply_water_physics(delta: float) -> void:
	# --- Wasserwiderstand (Drag) ---
	# Y-Komponente nur leicht dämpfen, X stärker
	var drag_x = -velocity.x * abs(velocity.x) * WATER_DRAG * 0.5 * delta
	var drag_y = -velocity.y * abs(velocity.y) * WATER_DRAG * 0.5 * delta
	velocity.x += drag_x
	velocity.y += drag_y
	
	# --- Dynamischer Auftrieb ---
	var depth_factor = clamp((water_surface_y - global_position.y) / 50.0, 0.0, 1.0)
	depth_factor = smoothstep(0.0, 1.0, depth_factor) # weicher Übergang
	var buoyancy = WATER_BUOYANCY * depth_factor
	
	# --- Oberflächen-Übergang ---
	if global_position.y < water_surface_y and global_position.y > water_surface_y - 30:
		var surface_proximity = 1.0 - (water_surface_y - global_position.y) / 30.0
		buoyancy += WATER_SURFACE_TENSION * surface_proximity
	
	# --- Kräfte anwenden ---
	velocity.y += (gravity_force * WATER_GRAVITY_SCALE - buoyancy) * delta
	
	# --- Input für Schwimmen ---
	handle_swimming_input(delta)
	
	# --- Stabilisierung (kein hartes Nullsetzen mehr) ---
	if abs(velocity.y) < 0.05:
		velocity.y = lerp(velocity.y, 0.0, 0.1)
	
	# --- Geschwindigkeitslimits ---
	velocity.x = clamp(velocity.x, -WATER_MAX_SPEED, WATER_MAX_SPEED)
	velocity.y = clamp(velocity.y, -WATER_MAX_SPEED, WATER_MAX_SPEED * 1.5)


func handle_swimming_input(delta: float) -> void:
	var swim_direction = Input.get_axis("left", "right")
	
	# --- Horizontal bewegen ---
	if swim_direction != 0:
		velocity.x = move_toward(
			velocity.x,
			swim_direction * WATER_MAX_SPEED,
			WATER_ACCELERATION * delta
		)
	
	# --- Vertikale Bewegung ---
	is_swimming = false
	if Input.is_action_pressed("up"):
		velocity.y = lerp(velocity.y, -WATER_SWIM_IMPULSE, 0.3)
		is_swimming = true
	elif Input.is_action_pressed("down"):
		# weiches Absenken, nicht instant überschreiben
		velocity.y = move_toward(velocity.y, WATER_SINK_SPEED, WATER_ACCELERATION * delta)
		is_swimming = true


func handle_input():
	if !is_multiplayer_authority():
		return
	if _is_gameplay_input_blocked():
		direction.x = 0.0
		return
	
	var touch_direction := Vector2.ZERO
	
	if joystick_active:
		var joystick_x = joystick_output.x
		# INVERTIERE JOYSTICK-EINGABE
		if controls_inverted:
			joystick_x = -joystick_x
		touch_direction.x = joystick_x
	else:
		var left_input = Input.is_action_pressed("left")
		var right_input = Input.is_action_pressed("right")
		
		# INVERTIERE TASTEN-EINGABE
		if controls_inverted:
			left_input = Input.is_action_pressed("right")
			right_input = Input.is_action_pressed("left")
		
		# Verwende die (möglicherweise invertierten) Eingaben
		if left_input:
			touch_direction.x = -1
		elif right_input:
			touch_direction.x = 1
		else:
			touch_direction.x = 0
	
	# Nur Eingaben verarbeiten, wenn nicht in Landeanimation
	if not is_landing:
		if Input.is_action_pressed("sprint") or (joystick_active and joystick_output.length() > 0.7):
			current_speed = RUN_SPEED
		else:
			current_speed = WALK_SPEED
	
	if abs(touch_direction.x) < 0.08:
		touch_direction.x = 0.0
	
	if !is_charging:
		direction.x = touch_direction.x
	
	if is_attacking and !is_dashing:
		direction.x *= 0.45
	
	# Blickrichtung aktualisieren
	if direction.x != 0:
		is_facing_left = direction.x < 0

func charge():
	if not has_ult_skill:
		print("Ultimate Fähigkeit noch nicht freigeschaltet!")
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_charge_time < charge_cooldown:
		var remaining = charge_cooldown - (current_time - last_charge_time)
		print("Cooldown aktiv! Noch ", remaining, " Sekunden")
		return
	
	if is_on_floor() and !is_charging:
		last_charge_time = current_time
		save_charge_cooldown()
		is_charging = true
		direction.x = 0
		
		if is_multiplayer_authority():
			var material: ParticleProcessMaterial = particles.process_material
			if not material:
				push_error("Kein ParticleProcessMaterial gefunden!")
				is_charging = false
				return
			# -------------------
			# PHASE 1: SOG (2 Sek.) – Blätter werden sanft angezogen
			# -------------------
			var pull_duration = 2.0
			var elapsed = 0.0
			material.radial_velocity = Vector2(-300, -300)
			
			while elapsed < pull_duration:
				var leaves = get_tree().get_nodes_in_group("leaves")
				for leaf in leaves:
					var dist = global_position.distance_to(leaf.global_position)
					if dist < 400:
						# Richtung Blatt -> Spieler, dann negiert für Sog
						var dir = (leaf.global_position - global_position).normalized()
						var power = clamp(1.0 - (dist / 400.0), 0.0, 1.0)
						leaf.react_to_air_pressure(-dir, power * 0.06) # kleiner Impuls pro Frame
				elapsed += get_process_delta_time()
				await get_tree().process_frame

			# -------------------
			# PHASE 2: EXPLOSION (1 Sek.) – Blätter wegblasen
			# -------------------
			material.radial_velocity = Vector2(800, 800)
			is_charging = false

			# Spieler heilen
			current_health = max_health
			update_health_bar()
			show_damage_text(max_health - current_health, true)
			flash_heal_effect()

			var explosion_radius = 300.0
			var explosion_damage = 130
			var knockback_force = 1000.0
			
			_notify_star_damage(explosion_damage)
			

			# Gegner Schaden
			var enemies = get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				var distance = global_position.distance_to(enemy.global_position)
				if distance <= explosion_radius:
					var knockback_dir = (enemy.global_position - global_position).normalized()
					var is_crit = randf() < base_crit_chance
					var final_damage = explosion_damage * (crit_damage_multiplier if is_crit else 1.0)
					if enemy.has_method("take_damage"):
						enemy.take_damage(final_damage, knockback_dir * knockback_force, is_crit)

			# Andere Spieler
			var players = get_tree().get_nodes_in_group("players")
			for player in players:
				if player == self:
					continue
				var distance = global_position.distance_to(player.global_position)
				if distance <= explosion_radius:
					var knockback_dir = (player.global_position - global_position).normalized()
					var is_crit = randf() < base_crit_chance
					var final_damage = explosion_damage * (crit_damage_multiplier if is_crit else 1.0)
					player.take_damage.rpc(final_damage, knockback_dir * knockback_force)

			# Blätter wegblasen
			var leaves = get_tree().get_nodes_in_group("leaves")
			for leaf in leaves:
				var dist = global_position.distance_to(leaf.global_position)
				if dist < 550.0:
					var dir = (leaf.global_position - global_position).normalized() # Richtung weg vom Spieler
					var power = pow(1.0 - (dist / 550.0), 2.0)
					leaf.react_to_air_pressure(dir, power * 4.0) # starker Stoß

			# Kamera- und visuelle Effekte
			$Camera2D.shake(0.3, 15)
			await get_tree().create_timer(1.0).timeout

			# -------------------
			# PHASE 3: AUSKLINGEN (3 Sek.)
			# -------------------
			var fade_time = 3.0
			var fade_elapsed = 0.0
			while fade_elapsed < fade_time:
				var progress = fade_elapsed / fade_time
				material.radial_velocity = Vector2.ONE * lerp(500, 0, progress * progress)
				fade_elapsed += get_process_delta_time()
				await get_tree().process_frame
			material.radial_velocity = Vector2.ZERO

		else:
			await get_tree().create_timer(6.0).timeout

		is_charging = false

# Speicher/Lade-Funktionen
func save_charge_cooldown():
	var save_data = {
		"last_charge_time": last_charge_time,
		"saved_at": Time.get_ticks_msec() / 1000.0  # Aktuelle Zeit in Sekunden
	}
	
	var file = FileAccess.open("user://charge_cooldown.dat", FileAccess.WRITE)
	file.store_var(save_data)
	file.close()	

func load_charge_cooldown():
	if not FileAccess.file_exists("user://charge_cooldown.dat"):
		last_charge_time = -300.0  # Cooldown abgelaufen
		return
	
	var file = FileAccess.open("user://charge_cooldown.dat", FileAccess.READ)
	var save_data = file.get_var()
	
	# Berechne wie viel Zeit seit dem Speichern vergangen ist
	var time_since_save = Time.get_ticks_msec() / 1000.0 - save_data["saved_at"]
	
	# Wenn seit dem Speichern mehr Zeit vergangen ist als der Cooldown,
	# dann ist der Cooldown abgelaufen
	if time_since_save >= charge_cooldown:
		last_charge_time = -300.0  # Cooldown abgelaufen
	else:
		# Ansonsten setze die last_charge_time so, dass der verbleibende
		# Cooldown korrekt berechnet wird
		last_charge_time = save_data["last_charge_time"] + time_since_save
	
	file.close()

func clear_cooldown():
	last_charge_time = -300.0
	if FileAccess.file_exists("user://charge_cooldown.dat"):
		DirAccess.remove_absolute("user://charge_cooldown.dat")

func flash_heal_effect():
	var heal_tween = create_tween()
	var was_glow_visible := glow_effect.visible
	# Glow-Effekt vergrößern und heller machen
	glow_effect.visible = true
	glow_effect.color = Color(0.2, 1.0, 0.2)  # Hellgrün
	glow_effect.energy = 2.0  # Intensiver
	$PlayerSprite.modulate = Color(0.82, 1.0, 0.86, 1.0)
	_squash_player_sprite(Vector2(1.06, 0.94), 0.16)
	
	heal_tween.tween_property(glow_effect, "energy", 1.0, 0.5)
	heal_tween.parallel().tween_property(glow_effect, "color", COLOR_NORMAL, 0.5)
	heal_tween.parallel().tween_property($PlayerSprite, "modulate", Color.WHITE, 0.24)
	await heal_tween.finished
	if not was_glow_visible and not is_glowing:
		glow_effect.visible = false

func apply_gravity(delta):
	if is_on_floor():
		return

	var gravity_multiplier := 1.0

	if velocity.y < -APEX_VELOCITY_THRESHOLD:
		gravity_multiplier = 0.95
	elif abs(velocity.y) <= APEX_VELOCITY_THRESHOLD:
		gravity_multiplier = APEX_GRAVITY_MULTIPLIER
	else:
		gravity_multiplier = FALL_GRAVITY_MULTIPLIER

	if Input.is_action_pressed("down") and velocity.y > 0.0:
		gravity_multiplier = FAST_FALL_GRAVITY_MULTIPLIER

	velocity.y += gravity_force * gravity_multiplier * delta
	velocity.y = min(velocity.y, max_fall_speed_value * 1.2)

func handle_jump_mechanics(delta):
	if is_in_water:
		# Wasser-Sprünge sind schwächer aber öfter möglich
		if Input.is_action_just_pressed("up"):
			airtime_started_with_jump = true
			velocity.y = jump_velocity_force * 0.7
			#$WaterJumpSound.play()
	else:
		if is_charging or is_stunned:
			return
		
		# Coyote Time (Sprung nach Verlassen der Plattform)
		if is_on_floor():
			coyote_time = COYOTE_TIME_MAX
			air_jumps_available = max_air_jumps  # Setze Luftsprünge zurück, wenn am Boden
		else:
			coyote_time = max(coyote_time - delta, 0.0)
		
		# Jump Buffer (Sprung vor dem Landen)
		if Input.is_action_just_pressed("up"):
			jump_buffer_time = JUMP_BUFFER_MAX
		else:
			jump_buffer_time = max(jump_buffer_time - delta, 0.0)
		
		# Normalsprung vom Boden
		if (coyote_time > 0 and jump_buffer_time > 0) or (is_on_floor() and Input.is_action_just_pressed("up")):
			if is_hero_ground_sliding:
				_end_hero_ground_slide(true)
			airtime_started_with_jump = true
			velocity.y = jump_velocity_force
			coyote_time = 0
			jump_buffer_time = 0
			if abs(direction.x) > 0.0:
				velocity.x += direction.x * 20.0
			_play_jump_sfx(false)
			$Camera2D.shake(0.7, 0.06)
			_squash_player_sprite(Vector2(0.86, 1.12), 0.14)
			$AnimationPlayer.play("jump")
		# Luftsprung, wenn verfügbar
		elif jump_buffer_time > 0 and air_jumps_available > 0 and not is_on_floor():
			perform_air_jump()
			jump_buffer_time = 0.0
		
		# Kurzer Sprung (wenn Taste losgelassen)
		if Input.is_action_just_released("up") and velocity.y < 0:
			velocity.y *= SHORT_JUMP_MULTIPLIER
		
		# Sofortige Sprungabbremsung
		if Input.is_action_just_pressed("down") and velocity.y < 0:
			velocity.y *= JUMP_CUT_MULTIPLIER

# Führe einen Luftsprung aus
func perform_air_jump():
	if !has_double_jump_skill:
		return
	if air_jumps_available <= 0:
		return
	
	velocity.y = air_jump_velocity_force * 1.05
	air_jumps_available -= 1
	
	# Effekte für den Luftsprung
	_play_jump_sfx(true)
	$Camera2D.shake(0.9, 0.07)
	_squash_player_sprite(Vector2(0.84, 1.16), 0.16)
	_spawn_air_jump_effect()
	
	# Partikeleffekt für Luftsprung
	_set_optional_particle_emission("AirJumpParticles", true, true)
	
	# Animation für Luftsprung
	$AnimationPlayer.play("jump")


func _get_hero_slide_config_value(key: String, fallback: float) -> float:
	return float(hero_slide_config.get(key, fallback))


func _can_use_hero_ground_slide() -> bool:
	return _is_hero_form_active() and _character_can("ground_slide", false) and is_on_floor() and not is_hero_ground_sliding and hero_slide_cooldown_timer <= 0.0 and not is_attacking and not is_dashing and not is_stunned and not is_charging


func _start_hero_ground_slide(forced_direction: float = 0.0, ignore_speed_requirement: bool = false) -> bool:
	if not _can_use_hero_ground_slide():
		return false

	var min_speed := _get_hero_slide_config_value("min_trigger_speed", 185.0)
	var input_direction := forced_direction
	if absf(input_direction) < 0.1:
		input_direction = direction.x
	if absf(input_direction) < 0.1:
		input_direction = -1.0 if is_facing_left else 1.0

	var current_abs_speed := absf(velocity.x)
	var sprint_slide := Input.is_action_pressed("sprint") and absf(direction.x) > 0.0
	if not ignore_speed_requirement and not sprint_slide and current_abs_speed < min_speed:
		return false

	hero_slide_direction = sign(input_direction)
	if hero_slide_direction == 0.0:
		hero_slide_direction = -1.0 if is_facing_left else 1.0

	is_hero_ground_sliding = true
	hero_slide_timer = _get_hero_slide_config_value("duration", 0.42)
	hero_slide_cooldown_timer = _get_hero_slide_config_value("cooldown", 0.34)
	hero_slide_floor_grace = 0.32
	hero_momentum_attack_timer = maxf(hero_momentum_attack_timer, _get_hero_slide_config_value("momentum_window", 0.7))
	velocity.x = hero_slide_direction * maxf(current_abs_speed, _get_hero_slide_config_value("speed", 470.0))
	velocity.y = minf(velocity.y, 0.0)
	is_landing = false
	runtime_stop_timer = 0.0
	runtime_turn_timer = 0.0
	runtime_animation_state = ""
	_apply_collision_profile("ground_slide")
	_play_hero_slide_sfx()
	var slide_smoke_position := global_position + Vector2(-hero_slide_direction * 22.0, _get_collision_ground_offset_world())
	_spawn_hero_combat_effect("slide", slide_smoke_position, Color(0.62, 1.0, 0.86, 0.9), 1.14, 0.0, hero_slide_direction < 0.0)
	$Camera2D.shake(0.85, 0.08)
	_squash_player_sprite(Vector2(1.12, 0.82), 0.12)
	return true


func _update_hero_ground_slide(delta: float) -> void:
	if not is_hero_ground_sliding:
		return

	hero_slide_timer = maxf(hero_slide_timer - delta, 0.0)
	if not is_on_floor():
		hero_slide_floor_grace = maxf(hero_slide_floor_grace - delta, 0.0)
		if hero_slide_floor_grace <= 0.0:
			_end_hero_ground_slide(true)
			return
	else:
		hero_slide_floor_grace = 0.32

	var steer_strength := _get_hero_slide_config_value("steer_strength", 210.0)
	var deceleration := _get_hero_slide_config_value("deceleration", 560.0)
	var target_speed := hero_slide_direction * _get_hero_slide_config_value("speed", 470.0) * 0.62
	if absf(direction.x) > 0.1 and sign(direction.x) == hero_slide_direction:
		target_speed = hero_slide_direction * _get_hero_slide_config_value("speed", 470.0) * 0.78
		velocity.x = move_toward(velocity.x, target_speed, steer_strength * delta)
	else:
		velocity.x = move_toward(velocity.x, target_speed, deceleration * delta)

	if Input.is_action_just_pressed("up"):
		velocity.y = jump_velocity_force * 0.82
		_end_hero_ground_slide(true)
		_play_jump_sfx(false)
		return

	if hero_slide_timer <= 0.0 or absf(velocity.x) < 80.0:
		_end_hero_ground_slide(true)


func _end_hero_ground_slide(preserve_momentum: bool = true) -> void:
	if not is_hero_ground_sliding:
		return
	is_hero_ground_sliding = false
	_apply_collision_profile("standing")
	if preserve_momentum:
		velocity.x *= _get_hero_slide_config_value("exit_speed_multiplier", 0.62)
	runtime_animation_state = ""


func _should_start_hero_slide_from_input() -> bool:
	return _can_use_hero_ground_slide() and Input.is_action_just_pressed("down") and (Input.is_action_pressed("sprint") or absf(velocity.x) >= _get_hero_slide_config_value("min_trigger_speed", 185.0))


func handle_wall_mechanics(delta):
	var on_air_wall := is_on_wall() and not is_on_floor()
	var can_slime_wall_slide := has_wall_slide_skill and _character_can("wall_slide", true)
	var can_hero_wall_jump := _character_can("wall_jump_without_slide", false)

	if not on_air_wall:
		is_wall_sliding = false
		if is_on_floor():
			can_wall_jump = true
		if wall_stick_timer > 0:
			wall_stick_timer -= delta
		return

	var current_wall_normal = get_wall_normal()
	if current_wall_normal != last_wall_normal:
		can_wall_jump = true
		last_wall_normal = current_wall_normal

	if can_slime_wall_slide:
		is_wall_sliding = true
		velocity.y = min(velocity.y, wall_slide_speed_cap)
		wall_stick_timer = WALL_STICK_TIME
		if Input.is_action_just_pressed("up") and can_wall_jump:
			_perform_profile_wall_jump(current_wall_normal, false)
	elif can_hero_wall_jump:
		is_wall_sliding = false
		if Input.is_action_just_pressed("up") and can_wall_jump:
			_perform_profile_wall_jump(current_wall_normal, true)
	else:
		is_wall_sliding = false


func _perform_profile_wall_jump(wall_normal: Vector2, hero_kick: bool) -> void:
	airtime_started_with_jump = true
	velocity.y = wall_jump_velocity_y_value
	velocity.x = -wall_normal.x * wall_jump_velocity_x_value
	position.x += -wall_normal.x * (7.0 if hero_kick else 5.0)
	can_wall_jump = false
	runtime_wall_jump_timer = _get_runtime_animation_length("wall_jump")
	runtime_animation_state = ""

	if hero_kick:
		hero_momentum_attack_timer = maxf(hero_momentum_attack_timer, 0.62)
		_play_hero_wall_jump_sfx()
		var contact_sign: float = -sign(velocity.x)
		if contact_sign == 0.0:
			contact_sign = wall_normal.x
		var contact_offset := _get_collision_half_width_world() + 4.0
		_spawn_hero_combat_effect(
			"wall_jump",
			global_position + Vector2(contact_sign * contact_offset, -32.0),
			Color(0.66, 1.0, 0.94, 0.9),
			1.16,
			deg_to_rad(90.0 * contact_sign),
			contact_sign < 0.0
		)
		$Camera2D.shake(1.05, 0.08)
		_squash_player_sprite(Vector2(0.88, 1.14), 0.12)
	else:
		$Camera2D.shake(0.12, 0.04)
		if Input.is_action_pressed("left") or Input.is_action_pressed("right"):
			velocity.x = 0

func handle_dash(delta: float):
	if is_hero_ground_sliding:
		_update_hero_ground_slide(delta)
		return

	if _should_start_hero_slide_from_input():
		_start_hero_ground_slide()
		_update_hero_ground_slide(delta)
		return

	if Input.is_action_just_pressed("dash_left") and can_dash:
		dash(Vector2.LEFT)
	elif Input.is_action_just_pressed("dash_right") and can_dash:
		dash(Vector2.RIGHT)
	elif Input.is_action_just_pressed("dash_up") and can_dash:
		dash(Vector2.UP)

	if is_dashing:
		dash_elapsed += delta
		velocity = dash_direction * dash_speed
		return

	# Horizontale Bewegung mit unterschiedlicher Beschleunigung in Luft/Boden
	var target_speed = direction.x * current_speed
	var acceleration = ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var deceleration = DECELERATION if is_on_floor() else AIR_DECELERATION

	if direction.x != 0 and sign(direction.x) != sign(velocity.x) and abs(velocity.x) > 10.0:
		acceleration *= 1.25

	if direction.x != 0:
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)

func _get_preferred_dash_direction() -> Vector2:
	if abs(direction.x) > 0.0:
		return Vector2(direction.x, 0).normalized()
	return Vector2.LEFT if is_facing_left else Vector2.RIGHT

func dash(dir: Vector2):
	if !has_dash_skill:
		return
	if is_dashing or is_hero_ground_sliding or not can_dash or is_stunned or is_charging:
		return

	if dir == Vector2.ZERO:
		dir = _get_preferred_dash_direction()
	
	is_dashing = true
	can_dash = false
	dash_direction = dir.normalized()
	dash_elapsed = 0.0
	dash_invulnerability_timer = DASH_INVULNERABILITY_TIME
	runtime_dash_timer = dash_duration
	runtime_animation_state = ""
	dash_timer.wait_time = dash_duration
	dash_cooldown_timer.wait_time = dash_cooldown
	velocity = dash_direction * dash_speed
	
	# Effekte
	$Camera2D.shake(2.5, 0.12)
	_squash_player_sprite(Vector2(1.12, 0.84), 0.16)
	_play_dash_sfx()
	if _is_hero_form_active():
		_spawn_hero_combat_effect("slash", global_position + Vector2(dash_direction.x * 20.0, -24.0), Color(0.72, 0.94, 1.0, 0.78), 1.18, deg_to_rad(-8.0 * dash_direction.x))
	
	# Timer starten
	dash_timer.start()
	
	# Nachbilder erstellen
	create_afterimages()

func _on_dash_timer_timeout():
	is_dashing = false
	velocity.x *= 0.55
	dash_attack_bonus_timer = DASH_ATTACK_BONUS_DURATION
	dash_cooldown_timer.start()

func _on_dash_cooldown_timer_timeout():
	can_dash = has_dash_skill

func create_afterimages():
	var source_sprite := _get_active_body_sprite()
	if source_sprite == null or source_sprite.texture == null:
		return

	for i in range(3):
		var afterimage = Sprite2D.new()
		_snapshot_body_sprite(afterimage, source_sprite)
		afterimage.modulate = Color(1, 1, 1, 0.5)  # Halbtransparent
		afterimage.z_index = -1  # Hinter dem Haupt-Sprite
		
		# Leicht zufällige Skalierung für dynamischeren Effekt
		afterimage.scale *= randf_range(0.9, 1.1)
		
		get_parent().add_child(afterimage)
		
		# Tween für das Ausblenden
		var tween = create_tween()
		tween.tween_property(afterimage, "modulate:a", 0.0, 0.2)
		tween.parallel().tween_property(afterimage, "scale", Vector2.ONE * 1.2, 0.2)
		tween.tween_callback(afterimage.queue_free)
		
		await get_tree().create_timer(dash_duration / 3.0).timeout

func update_animations():
	if uses_runtime_character_animation:
		return

	if is_landing:
		$AnimationPlayer.speed_scale = 1.0
		return

	if is_attacking:
		$AnimationPlayer.speed_scale = 1.0
		if $AnimationPlayer.current_animation != "idle":
			$AnimationPlayer.play("idle")
		return

	if is_wall_sliding:
		$AnimationPlayer.speed_scale = 1.0
		$AnimationPlayer.play("wall_slide")
		var slide_wall_normal := get_wall_normal() if is_on_wall() else last_wall_normal
		# Beim Wall-Slide soll der Spieler weg von der Wand schauen.
		$PlayerSprite.flip_h = slide_wall_normal.x < 0
		return

	if not is_on_floor():
		$AnimationPlayer.speed_scale = 1.0
		if not was_in_air:
			fall_start_y = global_position.y
			airtime_peak_fall_speed = max(velocity.y, 0.0)
		else:
			airtime_peak_fall_speed = max(airtime_peak_fall_speed, velocity.y)
		$AnimationPlayer.play("jump")
		was_in_air = true
		return

	if was_in_air:
		fall_distance = max(global_position.y - fall_start_y, 0.0)
		var should_play_landing := not airtime_started_with_jump \
			and fall_distance >= LANDING_DROP_DISTANCE_THRESHOLD \
			and airtime_peak_fall_speed >= LANDING_FALL_SPEED_THRESHOLD
		was_in_air = false
		airtime_started_with_jump = false
		airtime_peak_fall_speed = 0.0
		fall_start_y = global_position.y
		if should_play_landing:
			play_landing_animation("landing")
			return

	if abs(velocity.x) > 14:
		$AnimationPlayer.play("walk")
		$AnimationPlayer.speed_scale = clamp(abs(velocity.x) / max(RUN_SPEED, 1.0), 0.8, 1.8)
		$PlayerSprite.flip_h = velocity.x < 0
	else:
		$AnimationPlayer.speed_scale = 1.0
		$AnimationPlayer.play("idle")

func play_walk_sound():
	var speed_factor: float = clampf(abs(velocity.x) / 260.0, 0.18, 1.0)
	var streams := character_footstep_streams if not character_footstep_streams.is_empty() else slime_move_streams
	if not streams.is_empty():
		$WalkSound.stream = streams[randi() % streams.size()]
	if _is_hero_form_active():
		$WalkSound.volume_db = lerpf(-22.0, -13.0, speed_factor)
		$WalkSound.pitch_scale = randf_range(0.88, 1.08)
	else:
		$WalkSound.volume_db = lerpf(-24.0, -16.0, speed_factor)
		$WalkSound.pitch_scale = randf_range(0.82, 0.94)
	$WalkSound.play()
	last_sound_time = Time.get_ticks_usec() / 1_000_000.0  # Präziser
	
# Verbesserte Kollisionserkennung
func _on_floor_entered():
	_set_optional_particle_emission("LandingParticles", true, true)
	_play_land_sfx(false)
	play_landing_animation()
	if is_wall_running:
		end_wall_run()

func _on_wall_entered():
	_set_optional_particle_emission("WallSlideParticles", true, true)
	var wall_slide_sound := get_node_or_null("WallSlideSound") as AudioStreamPlayer2D
	if wall_slide_sound:
		wall_slide_sound.play()

func _create_afterimages_during_dash() -> void:
	if is_dashing:
		create_afterimage()
		# Erstelle einen neuen Timer für das nächste Nachbild
		var afterimage_timer = get_tree().create_timer(0.05)
		afterimage_timer.timeout.connect(_create_afterimages_during_dash)

func create_afterimage() -> void:
	var source_sprite := _get_active_body_sprite()
	if source_sprite == null or source_sprite.texture == null:
		return

	var afterimage = Sprite2D.new()
	_snapshot_body_sprite(afterimage, source_sprite)
	afterimage.modulate = Color(0.5, 0.5, 1, 0.5)  # Blauer Schimmer
	afterimage.scale *= 0.1  # Etwas kleiner
	afterimage.rotation = randf_range(-0.1, 0.1)  # Leichte Rotation
	
	get_parent().add_child(afterimage)
	
	var tween = create_tween()
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.5)
	tween.tween_callback(afterimage.queue_free)

func _on_heal_timer_timeout() -> void:
	# Nur heilen, wenn Heilung aktiv ist und der Spieler nicht voll geheilt ist
	if is_healing_active and current_health < max_health:
		var missing_health = max_health - current_health
		var heal_amount = max(5, ceil(missing_health * 0.15))  # Mindestens 5 HP oder 15 % des fehlenden Lebens
		heal_amount = min(heal_amount, 25)  # Maximal 25 HP pro Tick
		heal(heal_amount)

func play_landing_animation(anim_name: String = "landing") -> void:
	if is_landing:
		return
	
	is_landing = true
	runtime_landing_animation = anim_name
	runtime_animation_state = ""
	$AnimationPlayer.stop()
	var landing_strength: float = clampf(fall_distance / 220.0, 0.3, 1.35)
	
	# Spiel entsprechende Animation ab
	if uses_runtime_character_animation:
		$AnimationPlayer.stop()
	else:
		if $AnimationPlayer.has_animation(anim_name):
			$AnimationPlayer.play(anim_name)
		else:
			$AnimationPlayer.play("landing")
	
	# Soundeffekte basierend auf Landestärke
	_set_optional_particle_emission("LandingParticles", true, true)
	_spawn_landing_effect(landing_strength)
	$Camera2D.shake(1.4 + landing_strength * 1.8, 0.08 + landing_strength * 0.03)
	_squash_player_sprite(Vector2(1.14 + landing_strength * 0.04, 0.84 - landing_strength * 0.06), 0.18)
	_play_land_sfx(anim_name == "hard_landing")
	
	if uses_runtime_character_animation:
		await get_tree().create_timer(maxf(_get_runtime_animation_length(anim_name), 0.12)).timeout
	else:
		await $AnimationPlayer.animation_finished
	is_landing = false

func set_animation() -> void:
	if is_attacking or is_landing:
		return

	if direction.x != 0:
		$PlayerSprite.flip_h = is_facing_left
		$AnimationPlayer.play("walk")
	else:
		$AnimationPlayer.play("idle")

	if is_in_air():
		$AnimationPlayer.play("jump")

func is_in_air() -> bool:
	return not is_on_floor()

func _on_attack_area_body_entered(body):
	_try_attack_hit(body)
	
	# **Luftdruck auf Blätter anwenden**
	apply_sword_air_pressure()

func _process_active_attack_overlaps() -> void:
	if not is_attacking or not attack_area or not attack_area.monitoring:
		return

	for body in attack_area.get_overlapping_bodies():
		_try_attack_hit(body)

func _try_attack_hit(body: Node) -> void:
	if not is_attacking or not is_multiplayer_authority():
		return
	if not (body is Node2D):
		return

	var target_body := body as Node2D
	if target_body == self:
		return
	if not (target_body.is_in_group("enemies") or target_body.is_in_group("players")):
		return

	var body_id: int = target_body.get_instance_id()
	if attack_targets_hit.has(body_id):
		return
	attack_targets_hit[body_id] = true

	var is_crit := randf() < current_crit_chance
	var dash_bonus := DASH_ATTACK_BONUS_MULTIPLIER if dash_attack_bonus_timer > 0.0 else 1.0
	var damage := attack_damage * current_attack_damage_multiplier * dash_bonus
	if is_crit:
		damage *= current_crit_multiplier
	var knockback_direction := (target_body.global_position - global_position).normalized()

	_notify_star_damage(damage)

	var landed_finisher := false
	if target_body.is_in_group("players"):
		target_body.take_damage.rpc(int(damage), global_position)
	else:
		_apply_damage_to_enemy(target_body, int(damage), knockback_direction, is_crit)
		landed_finisher = target_body.is_in_group("enemies") and _is_target_defeated(target_body)

	if _is_hero_form_active():
		_apply_hero_hit_feedback(target_body, is_crit, landed_finisher)

	weapon_hit_counter += 1
	_apply_weapon_hit_effects(target_body, int(damage), knockback_direction, is_crit, landed_finisher)

	var shake_intensity := 1.4 + current_attack_knockback_strength * 0.002
	$Camera2D.shake(shake_intensity, 0.08)
	_play_hit_particles(Color(1.0, 0.82, 0.45, 1.0) if is_crit else Color(1.0, 0.34, 0.34, 1.0))
	_play_melee_impact(is_crit)
	if landed_finisher:
		_show_feedback_banner("FINISHER", Color(1.0, 0.72, 0.3), 0.42)
		_notify_star_finisher()
	if is_crit:
		_play_crit_sfx()
		if not landed_finisher:
			_show_feedback_banner("CRITICAL!", Color(1.0, 0.82, 0.35), 0.34)
		_spawn_feedback_text("CRIT %d" % int(damage), Color(1.0, 0.84, 0.38), 1.35)
	else:
		_spawn_feedback_text(str(int(damage)), Color(1.0, 0.62, 0.5), 1.0)


func _apply_hero_hit_feedback(target_body: Node2D, is_crit: bool, landed_finisher: bool) -> void:
	var target_position := target_body.global_position if is_instance_valid(target_body) else global_position + Vector2((-1.0 if is_facing_left else 1.0) * 56.0, -28.0)
	var effect_color := Color(1.0, 0.9, 0.5, 1.0) if is_crit or landed_finisher else Color(0.7, 0.96, 1.0, 1.0)
	_spawn_hero_combat_effect("hit", target_position, effect_color, 1.1 if is_crit or landed_finisher else 0.92)
	$Camera2D.shake(2.0 if is_crit or landed_finisher else 1.25, 0.07)

	if not is_on_floor() and Input.is_action_pressed("down"):
		velocity.y = minf(velocity.y, -360.0)
		hero_momentum_attack_timer = maxf(hero_momentum_attack_timer, 0.42)
		_show_feedback_banner("POGO", Color(0.75, 1.0, 0.92, 1.0), 0.22)

	_run_hero_hitstop(float(hero_combat_config.get("hitstop", 0.042)) * (1.4 if is_crit or landed_finisher else 1.0))


func _run_hero_hitstop(duration: float) -> void:
	if hero_hitstop_active or duration <= 0.0:
		return
	hero_hitstop_active = true
	var previous_scale := Engine.time_scale
	Engine.time_scale = minf(previous_scale, 0.22)
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = previous_scale
	hero_hitstop_active = false


func _apply_damage_to_enemy(target: Node, damage_amount: int, knockback_direction: Vector2, is_crit: bool) -> void:
	if not target or not target.has_method("take_damage"):
		return

	var take_damage_arg_count := 0
	for method_data in target.get_method_list():
		if method_data.get("name", "") == "take_damage":
			take_damage_arg_count = method_data.get("args", []).size()
			break

	match take_damage_arg_count:
		0:
			return
		1:
			target.take_damage(damage_amount)
		2:
			target.take_damage(damage_amount, knockback_direction)
		_:
			target.take_damage(damage_amount, knockback_direction, is_crit)


func _is_target_defeated(target: Node) -> bool:
	if not is_instance_valid(target):
		return true

	for flag_name in ["is_dead", "dead"]:
		var flag_value = target.get(flag_name)
		if flag_value is bool and flag_value:
			return true

	for health_name in ["current_health", "health", "bat_health", "golem_health"]:
		var health_value = target.get(health_name)
		if health_value is int or health_value is float:
			if float(health_value) <= 0.0:
				return true

	return false


func _apply_weapon_hit_effects(target: Node2D, base_damage: int, knockback_direction: Vector2, is_crit: bool, landed_finisher: bool) -> void:
	var weapon := _get_equipped_weapon_or_default()
	if weapon == null:
		return

	var bonus_damage := 0
	match weapon.skill_id:
		"starter_spark":
			if weapon_hit_counter % 3 == 0:
				bonus_damage = int(round(base_damage * 0.2))
				_deal_weapon_bonus_damage(target, bonus_damage, knockback_direction, Color(0.76, 0.98, 0.82), "SPARK")
		"fire_burn":
			_apply_periodic_weapon_damage(target, int(round(base_damage * 0.36)), 3, 0.28, knockback_direction, Color(1.0, 0.56, 0.24))
		"ice_shatter":
			bonus_damage = int(round(base_damage * 0.28))
			_deal_weapon_bonus_damage(target, bonus_damage, knockback_direction, Color(0.58, 0.86, 1.0), "FROST")
			if target.has_method("set"):
				target.set("velocity", target.get("velocity") * 0.6 if target.get("velocity") is Vector2 else target.get("velocity"))
		"poison_bloom":
			_apply_periodic_weapon_damage(target, int(round(base_damage * 0.32)), 4, 0.22, knockback_direction, Color(0.58, 0.92, 0.46))
		"duel_focus":
			if _get_nearby_enemies(target.global_position, 180.0, target).is_empty():
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.4)), knockback_direction, Color(0.9, 0.92, 1.0), "DUEL")
		"solar_flare":
			_restore_health(1)
			if is_crit:
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.32)), knockback_direction, Color(1.0, 0.82, 0.36), "SUN")
		"moonstep":
			if current_health >= max_health * 0.75:
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.22)), knockback_direction, Color(0.66, 0.74, 1.0), "MOON")
			_set_weapon_speed_burst(0.06, 1.8)
		"starfall":
			if weapon_hit_counter % 3 == 0:
				for extra_target in _get_nearby_enemies(target.global_position, 170.0, target):
					_deal_weapon_bonus_damage(extra_target, int(round(base_damage * 0.24)), knockback_direction, Color(0.96, 0.94, 1.0), "STAR")
		"blood_price":
			_deal_weapon_bonus_damage(target, int(round(base_damage * 0.35)), knockback_direction, Color(0.9, 0.2, 0.32), "CURSE")
			if current_health > 1:
				current_health = max(current_health - 1, 1)
				show_damage_text(1, false)
				update_health_bar()
		"divine_smite":
			if is_crit or weapon_hit_counter % 4 == 0:
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.34)), knockback_direction, Color(1.0, 0.95, 0.62), "SMITE")
				_restore_health(2)
		"rose_bleed":
			_apply_periodic_weapon_damage(target, int(round(base_damage * 0.26)), 3, 0.24, knockback_direction, Color(1.0, 0.56, 0.72))
			if landed_finisher:
				_restore_health(2)
		"elegant_riposte":
			if attack_combo_count >= 2:
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.22)), knockback_direction, Color(0.94, 0.88, 0.72), "RIPOSTE")
			_set_weapon_speed_burst(0.04, 1.2)
		"impact_drive":
			_deal_weapon_bonus_damage(target, int(round(base_damage * 0.26)), knockback_direction * 1.2, Color(1.0, 0.64, 0.28), "CRUSH")
		"chain_arc":
			for extra_target in _get_nearby_enemies(target.global_position, 190.0, target).slice(0, 2):
				_deal_weapon_bonus_damage(extra_target, int(round(base_damage * 0.3)), knockback_direction, Color(0.44, 0.88, 1.0), "ARC")
		"guard_counter":
			_grant_guardian_barrier(8.0)
			if _skill_ready("guard_counter", 1.4):
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.2)), knockback_direction, Color(0.76, 0.92, 1.0), "GUARD")
		"aerial_drift":
			if not is_on_floor():
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.35)), knockback_direction, Color(0.76, 0.92, 1.0), "WINGS")
		"arcane_echo":
			var arcane_targets := _get_nearby_enemies(target.global_position, 170.0, null)
			if arcane_targets.is_empty():
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.22)), knockback_direction, Color(0.84, 0.62, 1.0), "ECHO")
			else:
				for extra_target in arcane_targets.slice(0, 3):
					_deal_weapon_bonus_damage(extra_target, int(round(base_damage * 0.22)), knockback_direction, Color(0.84, 0.62, 1.0), "ARCANE")
		"shardburst":
			_deal_weapon_bonus_damage(target, int(round(base_damage * 0.12)), knockback_direction, Color(0.9, 0.96, 1.0), "SHARD")
			_deal_weapon_bonus_damage(target, int(round(base_damage * 0.1)), knockback_direction, Color(0.9, 0.96, 1.0), "")
		"verdant_renewal":
			_restore_health(1)
			if weapon_hit_counter % 4 == 0:
				for extra_target in _get_nearby_enemies(target.global_position, 160.0, target):
					_deal_weapon_bonus_damage(extra_target, int(round(base_damage * 0.18)), knockback_direction, Color(0.58, 0.92, 0.48), "THORN")
		"judgement":
			if _get_target_health_ratio(target) > 0.7:
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.35)), knockback_direction, Color(1.0, 0.82, 0.46), "JUDGE")
			elif landed_finisher:
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.22)), knockback_direction, Color(1.0, 0.82, 0.46), "FINISH")
		"mirror_strike":
			_deal_weapon_bonus_damage(target, int(round(base_damage * 0.18)), knockback_direction, Color(0.88, 0.92, 1.0), "MIRROR")
			var echo_targets := _get_nearby_enemies(target.global_position, 150.0, target)
			if not echo_targets.is_empty():
				_deal_weapon_bonus_damage(echo_targets[0], int(round(base_damage * 0.18)), knockback_direction, Color(0.88, 0.92, 1.0), "")
		"radiant_pulse":
			var pulse_ratio := 0.35 if is_glowing else 0.15
			_deal_weapon_bonus_damage(target, int(round(base_damage * pulse_ratio)), knockback_direction, Color(0.74, 1.0, 0.58), "PULSE")
			if is_glowing:
				for extra_target in _get_nearby_enemies(target.global_position, 155.0, target):
					_deal_weapon_bonus_damage(extra_target, int(round(base_damage * 0.18)), knockback_direction, Color(0.74, 1.0, 0.58), "")
		"slayer_mark":
			if _get_target_max_health(target) >= 100.0 or _get_target_health_ratio(target) > 0.9:
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.45)), knockback_direction, Color(1.0, 0.52, 0.34), "SLAY")
		"warding_edge":
			_grant_guardian_barrier(12.0)
			if landed_finisher:
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.2)), knockback_direction, Color(0.8, 0.92, 1.0), "WARD")
		"shadow_fang":
			if attack_combo_count == 1 and _skill_ready("shadow_fang", 1.1):
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.45)), knockback_direction, Color(0.72, 0.56, 1.0), "SHADOW")
		"gem_burst":
			if is_crit:
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.28)), knockback_direction, Color(0.86, 0.96, 1.0), "GEM")
		"tidal_cut":
			if is_in_water:
				_restore_health(2)
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.28)), knockback_direction, Color(0.5, 0.84, 1.0), "TIDE")
			else:
				var splash_targets := _get_nearby_enemies(target.global_position, 170.0, target)
				if not splash_targets.is_empty():
					_deal_weapon_bonus_damage(splash_targets[0], int(round(base_damage * 0.2)), knockback_direction, Color(0.5, 0.84, 1.0), "")
		"petal_dance":
			_apply_periodic_weapon_damage(target, int(round(base_damage * 0.2)), 2, 0.22, knockback_direction, Color(1.0, 0.7, 0.8))
			if weapon_hit_counter % 4 == 0:
				_restore_health(2)
		"royal_decree":
			if landed_finisher:
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.45)), knockback_direction, Color(1.0, 0.88, 0.56), "ROYAL")
			elif weapon_hit_counter % 5 == 0:
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.22)), knockback_direction, Color(1.0, 0.88, 0.56), "")
		"ritual_flow":
			_set_weapon_speed_burst(0.08, 1.2)
			_deal_weapon_bonus_damage(target, int(round(base_damage * 0.12)), knockback_direction, Color(0.94, 0.92, 0.82), "FLOW")
		"ancient_echo":
			if _skill_ready("ancient_echo", 1.6):
				_deal_weapon_bonus_damage(target, int(round(base_damage * 0.22)), knockback_direction, Color(0.92, 0.84, 0.62), "ANCIENT")
				for extra_target in _get_nearby_enemies(target.global_position, 190.0, target):
					_deal_weapon_bonus_damage(extra_target, int(round(base_damage * 0.28)), knockback_direction, Color(0.92, 0.84, 0.62), "")


func _deal_weapon_bonus_damage(target: Node2D, amount: int, knockback_direction: Vector2, color: Color, label: String) -> void:
	if amount <= 0 or not is_instance_valid(target):
		return

	if target.is_in_group("players"):
		target.take_damage.rpc(amount, global_position)
	else:
		_apply_damage_to_enemy(target, amount, knockback_direction * 0.55, false)

	_spawn_feedback_text(label if not label.is_empty() else str(amount), color, 0.88)


func _apply_periodic_weapon_damage(target: Node2D, total_damage: int, ticks: int, delay: float, knockback_direction: Vector2, color: Color) -> void:
	if total_damage <= 0 or ticks <= 0:
		return
	_run_periodic_weapon_damage(target, max(1, int(round(float(total_damage) / float(ticks)))), ticks, delay, knockback_direction, color)


func _run_periodic_weapon_damage(target: Node2D, damage_per_tick: int, ticks: int, delay: float, knockback_direction: Vector2, color: Color) -> void:
	for _tick in range(ticks):
		await get_tree().create_timer(delay).timeout
		if not is_instance_valid(target):
			return
		if target.is_in_group("players"):
			target.take_damage.rpc(damage_per_tick, global_position)
		else:
			_apply_damage_to_enemy(target, damage_per_tick, knockback_direction * 0.25, false)
		_spawn_feedback_text(str(damage_per_tick), color, 0.72)


func _get_nearby_enemies(origin: Vector2, radius: float, exclude: Node = null) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Node2D):
			continue
		var body := node as Node2D
		if body == exclude or not is_instance_valid(body):
			continue
		if origin.distance_to(body.global_position) <= radius:
			targets.append(body)
	return targets


func _restore_health(amount: int) -> void:
	if amount <= 0:
		return
	current_health = min(current_health + amount, max_health)
	show_damage_text(amount, true)
	if canvas_layer and canvas_layer.has_method("notify_player_heal"):
		canvas_layer.notify_player_heal(amount, current_health, max_health)
	update_health_bar()


func _grant_guardian_barrier(amount: float) -> void:
	mana_shield_active = true
	mana_shield_health = clamp(mana_shield_health + amount, 0.0, max_mana_shield_health)
	shield_sprite.visible = true
	shield_light.enabled = true
	shield_sprite.scale = Vector2.ONE
	shield_sprite.modulate.a = 0.7
	shield_light.energy = max(shield_light.energy, 0.6)


func _set_weapon_speed_burst(bonus: float, duration: float) -> void:
	weapon_speed_burst_bonus = max(weapon_speed_burst_bonus, bonus)
	weapon_speed_burst_timer = max(weapon_speed_burst_timer, duration)
	_refresh_player_tuning_from_skills()


func _skill_ready(skill_key: String, cooldown: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var last_time := float(last_weapon_skill_time.get(skill_key, -999.0))
	if now - last_time < cooldown:
		return false
	last_weapon_skill_time[skill_key] = now
	return true


func _get_target_health_ratio(target: Node) -> float:
	var current := 0.0
	var maximum := _get_target_max_health(target)
	for name in ["current_health", "health", "bat_health", "golem_health"]:
		var value = target.get(name)
		if value is int or value is float:
			current = float(value)
			break
	if maximum <= 0.0:
		return 0.0
	return current / maximum


func _get_target_max_health(target: Node) -> float:
	for name in ["max_health", "base_max_health", "golem_max_health", "bat_max_health"]:
		var value = target.get(name)
		if value is int or value is float:
			return float(value)

	var fallback_current: Variant = target.get("current_health")
	if fallback_current is int or fallback_current is float:
		return float(fallback_current)
	return 0.0

func apply_sword_air_pressure():
	var leaves = get_tree().get_nodes_in_group("leaves")
	for leaf in leaves:
		var dist = global_position.distance_to(leaf.global_position)

		# geringere Reichweite – realistischer für ein Schwertschwingen
		var max_range = 120.0
		if dist > max_range:
			continue

		# Richtung vom Spieler zum Blatt
		var dir = (leaf.global_position - global_position).normalized()

		# Nahbereich kräftiger, aber mit glatter Kurve
		# power fällt exponentiell statt linear ab
		var normalized = dist / max_range
		var power = pow(1.0 - normalized, 2.2)  # nah = stark, weit = schwach

		# Option: bei sehr nahen Blättern (unter 30px) etwas Extra-Boost
		if dist < 30.0:
			power *= 1.8

		leaf.react_to_air_pressure(dir, power)

@rpc("call_local", "reliable")
func die() -> void:
	print("Der Spieler ist gestorben!")
	runtime_death_active = uses_runtime_character_animation
	runtime_animation_state = ""
	runtime_hurt_timer = 0.0
	runtime_dash_timer = 0.0
	runtime_wall_jump_timer = 0.0
	is_attacking = false
	is_dashing = false
	velocity = Vector2.ZERO

	if runtime_death_active:
		var death_wait := clampf(_get_runtime_animation_length("death"), 0.35, 0.85)
		await get_tree().create_timer(death_wait).timeout

	# Kollisionsabfrage deaktivieren, damit Items nicht aufgesammelt werden
	$ColisionArea.set_deferred("disabled", true) 
	# Inventar droppen
	var gm = get_node("/root/GameManager")
	if gm.is_multiplayer == false:
		print("⚠ Multiplayer inaktiv → drop erlaubt")
		drop_inventory_items()
	save_game()
	# Spieler unsichtbar machen
	var save_file = FileAccess.open("user://inventory.save", FileAccess.WRITE)
	if FileAccess.file_exists("user://inventory.save"):
		DirAccess.remove_absolute("user://inventory.save")
		DirAccess.remove_absolute("user://charge_cooldown.dat")
		print("❌ Inventory-Datei gelöscht – Items werden nicht erneut geladen!")
	
	self.visible = false  
	# Prozesse stoppen
	set_process(false)
	set_physics_process(false)
	player_died.rpc(name.to_int())
	# Death Screen anzeigen
	if !gm.is_multiplayer:
		death_screen.show_death_screen()
	await get_tree().create_timer(3.0).timeout
	respawn()

@rpc("any_peer", "reliable")
func player_died(player_id: int):
	# Wird auf allen Clients aufgerufen, wenn ein Spieler stirbt
	if has_node(str(player_id)):
		var player = get_node(str(player_id))
		player.visible = false
		player.set_process(false)
		player.set_physics_process(false)

@rpc("call_local", "reliable")
func respawn() -> void:
	# Setze Gesundheit zurück
	current_health = max_health
	update_health_bar()
	runtime_death_active = false
	runtime_hurt_timer = 0.0
	runtime_animation_state = ""
	runtime_landing_animation = "landing"
	
	# Setze Position zurück
	var spawn_points = get_tree().get_nodes_in_group("spawn_points")
	if spawn_points.size() > 0:
		global_position = spawn_points[randi() % spawn_points.size()].global_position
	else:
		global_position = Vector2(randf_range(100, 900), randf_range(100, 500))
	
	# Aktiviere Kollision und Sichtbarkeit
	$ColisionArea.set_deferred("disabled", false)
	self.visible = true
	
	# Aktiviere Prozesse wieder
	set_process(true)
	set_physics_process(true)
	
	# Verstecke Death Screen
	death_screen.hide()
	if uses_runtime_character_animation:
		_set_runtime_animation("idle", true)
	update_position.rpc(global_position, Vector2.ZERO)

func drop_inventory_items() -> void:
	if not inv or inv.slots.size() == 0:
		return

	for slot in inv.slots:
		if slot.item and slot.amount > 0:
			for i in range(slot.amount): 
				var dropped_item = _create_world_pickup(slot.item)
				if dropped_item == null:
					continue
				dropped_item.global_position = global_position  
				get_tree().current_scene.add_child(dropped_item)
				
				# Speichern der Position und des Item-Namens
				dropped_items.append({
					"name": slot.item.name,
					"position": dropped_item.global_position
				})
		
		slot.item = null
		slot.amount = 0

	inv.notify_changed()
	save_dropped_items()  # Speichere die Items


func save_dropped_items():
	var save_file = FileAccess.open("user://dropped_items.save", FileAccess.WRITE)
	
	var formatted_data = []
	for item in dropped_items:
		formatted_data.append({
			"name": item["name"],
			"position": [item["position"].x, item["position"].y]  # Speichern als Array
		})
	
	save_file.store_string(JSON.stringify(formatted_data))
	save_file.close()

func load_dropped_items():
	print("Lade gespeicherte Items...")  # Debugging

	if not FileAccess.file_exists("user://dropped_items.save"):
		print("Keine gespeicherte Datei gefunden!")
		return

	var save_file = FileAccess.open("user://dropped_items.save", FileAccess.READ)
	var json_data = save_file.get_as_text()
	save_file.close()

	var parsed_data = JSON.parse_string(json_data)
	if parsed_data is Array:
		for item_data in parsed_data:
			var dropped_item = _create_world_pickup(String(item_data["name"]))
			if dropped_item == null:
				continue

			# Position setzen und zufälligen Offset hinzufügen
			dropped_item.global_position = Vector2(item_data["position"][0], item_data["position"][1])
			var random_offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
			dropped_item.global_position += random_offset

			# Sichtbarkeit setzen und Item zur Szene hinzufügen
			dropped_item.visible = true
			get_tree().current_scene.add_child(dropped_item)

			# Leichte Verzögerung, um Lag zu vermeiden
			await get_tree().create_timer(0.02).timeout

	# ✅ Nach dem Laden die Speicherdatei löschen, damit Items nicht erneut gespawnt werden
	if FileAccess.file_exists("user://dropped_items.save"):
		DirAccess.remove_absolute("user://dropped_items.save")
		print("❌ Drop-Datei gelöscht – Items werden nicht erneut geladen!")


func _create_world_pickup(item_or_name: Variant) -> RigidBody2D:
	return ItemRegistry.create_pickup_for_item(item_or_name)

# Angriff ausführen
@rpc("call_local", "reliable")
func perform_attack() -> void:
	if _is_gameplay_input_blocked() or is_stunned or is_charging or is_teleporting:
		return

	if is_attacking:
		queued_attack_timer = ATTACK_QUEUE_TIME
		return

	var now = Time.get_ticks_msec() / 1000.0
	if now - last_attack_time < attack_cooldown:
		queued_attack_timer = ATTACK_QUEUE_TIME
		return

	if is_dashing:
		is_dashing = false
		dash_timer.stop()
		dash_cooldown_timer.start()
		dash_attack_bonus_timer = DASH_ATTACK_BONUS_DURATION
	if is_hero_ground_sliding:
		_end_hero_ground_slide(false)

	stop_healing()
	is_attacking = true
	attack_targets_hit.clear()
	last_attack_time = now
	
	if combo_reset_timer > 0.0:
		attack_combo_count = min(attack_combo_count + 1, MAX_COMBO)
	else:
		attack_combo_count = 1

	var combo_index: int = clampi(attack_combo_count - 1, 0, MAX_COMBO - 1)
	current_attack_step = combo_index % 3
	current_attack_damage_multiplier = combo_damage_multipliers[combo_index]
	current_attack_knockback_strength = combo_knockback_strengths[combo_index]
	current_attack_lunge_strength = combo_lunge_strengths[combo_index]
	hero_current_attack_had_momentum = _is_hero_form_active() and hero_momentum_attack_timer > 0.0
	if hero_current_attack_had_momentum:
		current_attack_damage_multiplier *= float(hero_combat_config.get("momentum_damage_multiplier", 1.24))
		current_attack_lunge_strength += float(hero_combat_config.get("momentum_lunge_bonus", 85.0))
		hero_momentum_attack_timer = 0.0
		_show_feedback_banner("MOMENTUM EDGE", Color(0.68, 1.0, 0.92, 1.0), 0.28)
	combo_reset_timer = COMBO_RESET_TIME

	var facing_sign = -1.0 if is_facing_left else 1.0
	velocity.x = facing_sign * max(abs(velocity.x), current_attack_lunge_strength)
	_squash_player_sprite(Vector2(1.08, 0.93), 0.12)

	if attack_combo_count > 1:
		_show_feedback_banner("COMBO x%d" % attack_combo_count, Color(0.4, 0.9, 1.0), 0.28)

	sync_attack.rpc(current_attack_step)  # Synchronisiere den Angriff mit allen Clients

	await get_tree().create_timer(combo_active_times[current_attack_step]).timeout
	attack_area.monitoring = false

	await get_tree().create_timer(combo_recovery_times[current_attack_step]).timeout
	is_attacking = false
	damage_timer.start()

	if queued_attack_timer > 0.0:
		queued_attack_timer = 0.0
		perform_attack()


func _spawn_hero_slash_effect(combo_index: int, facing_sign: float) -> void:
	var slash_offsets := [
		Vector2(20.0, -22.0),
		Vector2(16.0, -12.0),
		Vector2(24.0, -16.0),
	]
	var slash_rotations := [-8.0, 7.0, -3.0]
	var slash_intensities := [1.08, 1.18, 1.28]
	var index := clampi(combo_index, 0, slash_offsets.size() - 1)
	var offset: Vector2 = slash_offsets[index]
	var rotation := deg_to_rad(float(slash_rotations[index]) * facing_sign)
	_spawn_hero_combat_effect(
		"slash",
		global_position + Vector2(facing_sign * offset.x, offset.y),
		Color(0.72, 0.96, 1.0, 0.82),
		float(slash_intensities[index]),
		rotation
	)


func _update_attack_hitbox(step: int) -> void:
	if not attack_area:
		return

	var active_step: int = clampi(step, 0, ATTACK_REACH_SCALES.size() - 1)
	var reach_scale: float = float(ATTACK_REACH_SCALES[active_step]) * (1.0 + weapon_attack_reach_bonus)
	var forward_offset: float = float(ATTACK_FORWARD_OFFSETS[active_step])
	var facing_sign = -1.0 if is_facing_left else 1.0
	attack_area.position = Vector2((abs(attack_area_base_position.x) + forward_offset) * facing_sign, attack_area_base_position.y)

	if attack_collision_shape:
		attack_collision_shape.scale = Vector2(
			attack_shape_base_scale.x * reach_scale,
			attack_shape_base_scale.y
		)

# Leuchteffekt aktualisieren
func update_glow_state() -> void:
	if not has_glow_skill:
		is_glowing = false
		return
		
	glow_effect.visible = is_glowing
	_refresh_player_tuning_from_skills()
	# EMITTIERE DAS SIGNAL HIER:
	glow_changed.emit(is_glowing)
	get_tree().call_group("spikes", "_on_player_glow_changed", is_glowing)
	sync_glow_state.rpc(is_glowing)

func set_controls_inverted(inverted: bool):
	controls_inverted = inverted
	print("Steuerung invertiert: ", inverted)

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int, hit_source: Vector2):
	if !is_multiplayer_authority():
		return
	if dash_invulnerability_timer > 0.0:
		return
	# Schadensreduktion anwenden
	var reduced_damage = amount * (1.0 - damage_reduction)
	reduced_damage = max(1, int(reduced_damage))  # Mindestens 1 Schaden
	amount = reduced_damage
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	
	query.position = hit_source
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFF
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		if result.collider.is_in_group("enemies") and has_thorns_skill:
			var return_damage = int(amount * 0.15)
			_apply_damage_to_enemy(result.collider, return_damage, Vector2.ZERO, false)
			
			_notify_star_damage(return_damage)
			
			break
	
	# Mana-Schild absorbiert Schaden
	if mana_shield_active and mana_shield_health > 0:
		var absorbed_damage = min(amount, mana_shield_health)
		mana_shield_health -= absorbed_damage
		amount -= absorbed_damage
		
		# Schild-Effekt bei Treffer
		shield_hit_effect()
		
		# Schild deaktivieren wenn leer
		if mana_shield_health <= 0:
			deactivate_mana_shield()
		
		if amount <= 0:
			return  # Aller Schaden absorbiert
	
	# Restlicher Schaden geht an Lebenspunkte
	current_health -= amount
	runtime_hurt_timer = max(runtime_hurt_timer, _get_runtime_animation_length("hurt"))
	runtime_animation_state = ""
	show_damage_text(amount, false)
	flash_damage_color()
	if canvas_layer and canvas_layer.has_method("notify_player_hit"):
		canvas_layer.notify_player_hit(amount, current_health, max_health)
	
	# Soundeffekt
	$HitSound.pitch_scale = randf_range(0.8, 1.2)
	$HitSound.play()

	# Knockback
	var knockback_dir = (global_position - hit_source).normalized()
	velocity = knockback_dir * 220

	# Stun-Effekt
	is_stunned = true
	stun_timer.start()
	
	# Heilung zurücksetzen
	stop_healing()
	
	# Tod prüfen
	if current_health <= 0:
		current_health = 0
		die()
	
	update_health_bar()

func _on_stun_timer_timeout() -> void:
	is_stunned = false  # Spieler kann sich wieder bewegen

func stop_healing() -> void:
	is_healing_active = false
	damage_timer.stop()


func _on_damage_timer_timeout() -> void:
	# Heilung starten, wenn 3 Sekunden ohne Schaden vergangen sind
	is_healing_active = true
	print("Heilung beginnt!")

# Funktion, um die Farbe des Leuchteffekts bei Schaden zu ändern
func flash_damage_color() -> void:
	var was_glow_visible := glow_effect.visible
	glow_effect.visible = true
	glow_effect.color = COLOR_DAMAGE
	$PlayerSprite.modulate = Color(1.0, 0.72, 0.72, 1.0)
	var tween := create_tween()
	tween.tween_property(glow_effect, "color", COLOR_NORMAL, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property($PlayerSprite, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	if not was_glow_visible and not is_glowing:
		glow_effect.visible = false

# Zeigt den Schadens-Text an
func show_damage_text(amount: int, is_heal: bool) -> void:
	if is_heal:
		_spawn_feedback_text("+" + str(amount), Color(0.56, 1.0, 0.64), 1.0)
	else:
		_spawn_feedback_text("-" + str(amount), COLOR_DAMAGE, 1.08)


@rpc("any_peer", "call_local", "reliable")
func heal(amount: int):
	if !has_regeneration_skill:
		return
		
	if !is_multiplayer_authority():
		return
	
	current_health += amount
	show_damage_text(amount, true)
	if current_health > max_health:
		current_health = max_health
	if canvas_layer and canvas_layer.has_method("notify_player_heal"):
		canvas_layer.notify_player_heal(amount, current_health, max_health)
	update_health_bar()

func collect(item) -> bool:
	var inserted := inv.Insert(item)
	if inserted:
		_show_loot_feedback(item)
	else:
		_show_feedback_toast("Inventar voll", "error", item.texture if item else null)
	return inserted
		

func save_game():
	var gm = get_node("/root/GameManager")
	if gm.is_multiplayer:
		print("⚠ Multiplayer aktiv → kein Speichern erlaubt")
		return
	var bats = get_tree().get_nodes_in_group("bats")
	save_load.save_game(self, bats)
	save_skills()  # Speichere auch die Skills

func load_game():
	var gm = get_node("/root/GameManager")
	if gm.is_multiplayer:
		print("⚠ Multiplayer aktiv → kein Laden erlaubt")
		return
	var bat_scene = preload("res://Scenes/bat.tscn")
	save_load.load_game(self, bat_scene)
	load_skills()  # Lade auch die Skills

func _exit_tree():
	save_game()  # Speichert das Spiel, wenn das Spiel beendet wird

func drop_hotbar_item():
	# Stelle sicher, dass ein Hotbar-Slot aktiv ist
	if selected_hotbar_index < 0 or selected_hotbar_index > 8:
		return
	
	# Berechne den tatsächlichen Inventar-Slot
	var inv_index = inv.slots.size() - 9 + selected_hotbar_index  
	var slot = inv.slots[inv_index]

	# Überprüfen, ob ein Item im Slot vorhanden ist
	if slot.item and slot.amount > 0:
		print("Dropping:", slot.item.name)  # Debugging-Info

		# Item in die Welt spawnen
		var dropped_item = _create_world_pickup(slot.item)
		if dropped_item == null:
			return

		# Stelle sicher, dass das Item eine RigidBody2D ist
		if dropped_item is RigidBody2D:
			# Spieler-Blickrichtung berechnen (Wurf-Richtung)
			var direction = (get_global_mouse_position() - global_position).normalized()

			# Setze die Startposition etwas vor den Spieler
			var drop_offset = direction * 25  # Item etwas nach vorne setzen
			dropped_item.global_position = global_position + drop_offset

			# **Hier kommt der Wurf-Impuls!**
			var throw_force = direction * 400 + Vector2(0, -200)  # Starke Wurfkraft + Auftrieb
			dropped_item.apply_central_impulse(throw_force)

			# **Drehung für realistisches Fliegen**
			dropped_item.angular_velocity = randf_range(-8, 8)  

		# Item zur Szene hinzufügen
		get_tree().current_scene.add_child(dropped_item)

		# Ein Item entfernen, nicht den ganzen Stack
		slot.amount -= 1
		if slot.amount == 0:
			slot.item = null  # Slot leeren

		inv.notify_changed()  # UI sofort aktualisieren

func get_selected_hotbar_index() -> int:
	# Falls du eine Variable hast, die den aktiven Hotbar-Slot speichert:
	return selected_hotbar_index  

func _input(event):
	if !is_multiplayer_authority():
		return
	if not joystick_active:
		if event is InputEventKey and event.pressed:
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				selected_hotbar_index = event.keycode - KEY_1
	
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			selected_hotbar_index = event.keycode - KEY_1  # 1 = Index 0, 2 = Index 1, etc.
			print("Hotbar Slot gewechselt zu:", selected_hotbar_index)  # Debugging
	if event.is_action_pressed("open_transfer"):
		open_transfer_dialog()
	
	if event.is_action_pressed("teleport"):  # Du musst diese Action in den Input Map settings hinzufügen
		perform_teleport()
	
	if event.is_action_pressed("mana_shield"):  # Füge diese Action in Input Map hinzu
		if mana_shield_active:
			deactivate_mana_shield()
		else:
			activate_mana_shield()
	if event.is_action_pressed("heal"):
		perform_heal_burst()
	if event.is_action_pressed("sticky_form") and not has_hero_form_skill:
		perform_sticky_form()

func open_transfer_dialog():
	var dialog = transfer_dialog_scene.instantiate()
	dialog.player_node = self  # Wichtig: Spieler-Referenz setzen
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()
	dialog.refresh_item_list()  # Liste beim Öffnen aktualisieren

func send_item_to_player(receiver_id: String, item_name: String) -> void:
	var data = {
		"senderId": str(get_instance_id()),
		"receiverId": receiver_id,
		"itemId": item_name
	}

	var payload_string = JSON.stringify(data).replace(" ", "")
	
	var headers = [
		"Content-Type: application/json"
	]

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_item_sent.bind(item_name))
	var error = http_request.request(url + "transfer-item", headers, HTTPClient.METHOD_POST, payload_string)

	if error != OK:
		push_error("Fehler beim Senden des Items: " + str(error))

func verify_signature(payload: String, signature: String) -> bool:
	var crypto = Crypto.new()
	var sig_bytes = Marshalls.base64_to_raw(signature)
	return crypto.verify(HashingContext.HASH_SHA256, payload.to_utf8_buffer(), sig_bytes, public_key)
	
func _on_item_sent(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, item_name: String) -> void:
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200:
		print("Item erfolgreich gesendet: ", response)
		show_notification("Item erfolgreich gesendet!")
	else:
		push_error("Fehler beim Senden: ", response)
		
		# Falls der Transfer fehlschlägt, das Item wieder hinzufügen
		for slot in inv.slots:
			if slot.item and slot.item.name == item_name:
				slot.amount += 1
				break
		
		inv.notify_changed()
		save_game()
		show_notification("Fehler beim Senden: " + str(response.get("error", "Unbekannter Fehler")))

func _on_water_area_body_entered(body: Node2D) -> void:
	if body == self:
		is_in_water = true
		water_surface_y = body.global_position.y
		water_enter_velocity = abs(velocity.y)
		last_out_of_water_time = Time.get_ticks_msec() / 1000.0


func _on_water_area_body_shape_exited(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body == self:
		is_in_water = false
		is_submerged = false
		last_out_of_water_time = Time.get_ticks_msec() / 1000.0


func show_notification(message: String) -> void:
	var toast_type := "info"
	if message.to_lower().contains("fehler") or message.to_lower().contains("voll"):
		toast_type = "error"
	elif message.to_lower().contains("erfolgreich"):
		toast_type = "reward"
	_show_feedback_toast(message, toast_type)

func _enter_tree():
	if is_multiplayer_authority():
		# Nur für den eigenen Spieler Input aktivieren
		set_process_input(true)
		set_process(true)
		set_physics_process(true)
	else:
		# Für andere Spieler nur die notwendigen Prozesse
		set_process_input(false)
		set_process(true)  # Für Animationen etc.
		set_physics_process(true)  # Für Bewegungsupdates

@rpc("call_local", "reliable")
func sync_attack(combo_step: int = 0):
	is_attacking = true
	current_attack_step = combo_step
	runtime_attack_elapsed = 0.0
	runtime_animation_state = ""
	_start_weapon_attack_animation(combo_step)
	if _is_hero_form_active():
		var facing_sign := -1.0 if is_facing_left else 1.0
		_spawn_hero_slash_effect(combo_step, facing_sign)
	$PlayerSprite/AttackSprite.flip_h = is_facing_left
	_update_attack_hitbox(combo_step)
	$PlayerSprite/AttackSprite.play("swing")
	$PlayerSprite/AttackSprite.speed_scale = 1.8 + float(combo_step) * 0.18
	attack_area.monitoring = true
	_update_equipped_weapon_visual()

@rpc("any_peer", "call_local", "reliable")
func sync_glow_state(new_state: bool):
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return  # Ignoriere Nachrichten von nicht-autoritativen Clients
		
	is_glowing = new_state
	glow_effect.visible = is_glowing

@rpc("reliable", "call_remote")
func sync_max_health():
	var bonus := 1.0
	for item in _get_equipped_items():
		bonus += item.health_bonus
	max_health = int(base_max_health * bonus)
	update_health_bar()


func setup_touch_controls():
	# Erstelle das CanvasLayer für Touch-Steuerung
	touch_controls = CanvasLayer.new()
	touch_controls.layer = 10  # Höhere Ebene, damit es über anderen UI-Elementen liegt
	add_child(touch_controls)
	
	# Viewport-Größe für responsive Positionierung
	var screen_size = get_viewport().get_visible_rect().size
	
	# Joystick für Bewegung (links unten)
	joystick = Control.new()
	joystick.set_script(preload("res://Scripts/virtual_joystick.gd"))
	joystick.position = Vector2(80, screen_size.y - 220)
	joystick.custom_minimum_size = Vector2(200, 200)
	touch_controls.add_child(joystick)
	
	# Action-Buttons (rechts unten)
	var button_size = Vector2(100, 100)
	var button_margin = 20
	var bottom_row_y = screen_size.y - button_size.y - 80
	var right_start_x = screen_size.x - button_size.x - 80
	
	# Jump Button (rechts unten)
	jump_button = Button.new()
	jump_button.text = "Jump"
	jump_button.size = button_size
	jump_button.position = Vector2(right_start_x, bottom_row_y)
	jump_button.pressed.connect(_on_jump_button_pressed)
	touch_controls.add_child(jump_button)
	
	# Attack Button (links vom Jump Button)
	attack_button = Button.new()
	attack_button.text = "Attack"
	attack_button.size = button_size
	attack_button.position = Vector2(right_start_x - button_size.x - button_margin, bottom_row_y)
	attack_button.pressed.connect(_on_attack_button_pressed)
	touch_controls.add_child(attack_button)
	
	# Dash Button (über dem Jump Button)
	dash_button = Button.new()
	dash_button.text = "Dash"
	dash_button.size = button_size
	dash_button.position = Vector2(right_start_x, bottom_row_y - button_size.y - button_margin)
	dash_button.pressed.connect(_on_dash_button_pressed)
	touch_controls.add_child(dash_button)
	
	# Glow Button (links vom Dash Button)
	glow_button = Button.new()
	glow_button.text = "Glow"
	glow_button.size = button_size
	glow_button.position = Vector2(right_start_x - button_size.x - button_margin, 
								  bottom_row_y - button_size.y - button_margin)
	glow_button.pressed.connect(_on_glow_button_pressed)
	touch_controls.add_child(glow_button)
	
	# Verbinde Input-Events für den Joystick
	joystick.gui_input.connect(_on_joystick_input)
	
	# Style die Buttons für bessere Sichtbarkeit
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.2, 0.7)
	button_style.border_color = Color(1, 1, 1, 0.5)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.corner_radius_top_left = 20
	button_style.corner_radius_top_right = 20
	button_style.corner_radius_bottom_right = 20
	button_style.corner_radius_bottom_left = 20
	
	# Style auf alle Buttons anwenden
	for button in [jump_button, attack_button, dash_button, glow_button]:
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_stylebox_override("pressed", button_style)
		button.add_theme_stylebox_override("hover", button_style)
		button.add_theme_color_override("font_color", Color(1, 1, 1))
		button.add_theme_font_size_override("font_size", 20)

func _on_joystick_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			joystick_active = true
			joystick_position = event.position
		else:
			joystick_active = false
			direction.x = 0
	
	if event is InputEventScreenDrag and joystick_active:
		var drag_vector = event.position - joystick_position
		var strength = min(drag_vector.length() / joystick_radius, 1.0)
		
		if strength > 0.1:  # Deadzone
			direction.x = drag_vector.normalized().x
		else:
			direction.x = 0

func _on_jump_button_pressed():
	# Simuliere die Jump-Eingabe
	jump_buffer_time = 0.1

func _on_attack_button_pressed():
	if _is_gameplay_input_blocked():
		return
	perform_attack()

func _on_dash_button_pressed():
	# Bestimme die Dash-Richtung basierend auf der aktuellen Blickrichtung
	var dash_dir = Vector2.LEFT if is_facing_left else Vector2.RIGHT
	if _start_hero_ground_slide(dash_dir.x, true):
		return
	dash(dash_dir)

func _on_glow_button_pressed():
	is_glowing = !is_glowing
	update_glow_state()
	sync_glow_state.rpc(is_glowing)

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# Pausiere das Spiel oder zeige eine Pause-Meldung
		pass
		
	if what == NOTIFICATION_WM_SIZE_CHANGED and touch_controls:
		# Passe die Position der Touch-Elemente an
		jump_button.position = Vector2(get_viewport().size.x - 200, get_viewport().size.y - 200)
		attack_button.position = Vector2(get_viewport().size.x - 320, get_viewport().size.y - 200)
		dash_button.position = Vector2(get_viewport().size.x - 200, get_viewport().size.y - 320)
		glow_button.position = Vector2(get_viewport().size.x - 320, get_viewport().size.y - 320)

func set_joystick_output(value: Vector2):
	joystick_output = value


func _is_skill_flag_enabled(skill_name: String) -> bool:
	match skill_name:
		"glow":
			return has_glow_skill
		"wall_slide":
			return has_wall_slide_skill
		"regeneration":
			return has_regeneration_skill
		"ult":
			return has_ult_skill
		"double_jump":
			return has_double_jump_skill
		"wall_run":
			return has_wall_run_skill
		"dash":
			return has_dash_skill
		"teleport":
			return has_teleport_skill
		"mana_shield":
			return has_mana_shield_skill
		"heal_burst":
			return has_heal_burst_skill
		"sticky_form":
			return has_sticky_form_skill
		"hero_form":
			return has_hero_form_skill or DEBUG_UNLOCK_HERO_FORM
		"thorns":
			return has_thorns_skill
		"slime_wings":
			return has_slime_wings_skill
		_:
			return false


func _set_skill_flag_state(skill_name: String, unlocked: bool) -> void:
	match skill_name:
		"glow":
			has_glow_skill = unlocked
		"wall_slide":
			has_wall_slide_skill = unlocked
		"regeneration":
			has_regeneration_skill = unlocked
		"ult":
			has_ult_skill = unlocked
		"double_jump":
			has_double_jump_skill = unlocked
		"wall_run":
			has_wall_run_skill = unlocked
		"dash":
			has_dash_skill = unlocked
		"teleport":
			has_teleport_skill = unlocked
		"mana_shield":
			has_mana_shield_skill = unlocked
		"heal_burst":
			has_heal_burst_skill = unlocked
		"sticky_form":
			has_sticky_form_skill = unlocked
		"hero_form":
			has_hero_form_skill = unlocked or DEBUG_UNLOCK_HERO_FORM
		"thorns":
			has_thorns_skill = unlocked
		"slime_wings":
			has_slime_wings_skill = unlocked


func _sync_skill_tree_from_flags() -> void:
	if not skill_tree:
		return

	var sync_names: Array[String] = [
		"glow",
		"wall_slide",
		"regeneration",
		"ult",
		"double_jump",
		"wall_run",
		"dash",
		"teleport",
		"mana_shield",
		"heal_burst",
		"sticky_form",
		"hero_form",
		"thorns",
		"slime_wings"
	]

	for skill_name: String in sync_names:
		if skill_tree.skills.has(skill_name):
			skill_tree.skills[skill_name].unlocked = _is_skill_flag_enabled(skill_name)

	skill_tree.queue_redraw()


func _enforce_skill_progression() -> void:
	if not skill_tree:
		return

	var progression_changed := false
	var gated_skills: Array[String] = [
		"wall_slide",
		"regeneration",
		"double_jump",
		"wall_run",
		"dash",
		"teleport",
		"mana_shield",
		"heal_burst",
		"sticky_form",
		"hero_form",
		"thorns",
		"ult",
		"slime_wings"
	]

	for skill_name: String in gated_skills:
		if skill_name == "hero_form" and DEBUG_UNLOCK_HERO_FORM:
			continue
		if not _is_skill_flag_enabled(skill_name):
			continue
		if skill_tree.skills.has(skill_name) and not skill_tree.can_unlock_skill(skill_name):
			_set_skill_flag_state(skill_name, false)
			skill_tree.skills[skill_name].unlocked = false
			progression_changed = true

	if progression_changed:
		if skill_tree.has_method("save_skills"):
			skill_tree.save_skills()
		save_skills()


func grant_skill(skill_name: String, show_feedback: bool = true) -> void:
	if _is_skill_flag_enabled(skill_name):
		return

	if skill_tree and skill_tree.skills.has(skill_name):
		skill_tree.skills[skill_name].unlocked = true
		if skill_tree.has_method("save_skills"):
			skill_tree.save_skills()
		skill_tree.queue_redraw()

	_on_skill_unlocked(skill_name)

	if skill_name == "glow":
		is_glowing = true
		update_glow_state()

	if show_feedback:
		_show_feedback_banner("%s ERWACHT" % SkillProgression.get_skill_title(skill_name).to_upper(), Color(0.62, 0.96, 1.0, 1.0), 0.56)
		_show_feedback_toast("Neuer Skill verfuegbar: %s" % SkillProgression.get_skill_title(skill_name), "reward", null)


# Funktion, die aufgerufen wird, wenn ein Skill freigeschaltet wird
func _on_skill_unlocked(skill_name: String):
	match skill_name:
		"glow":
			has_glow_skill = true
			print("Glow freigeschaltet!")
		"wall_slide":
			has_wall_slide_skill = true
			print("Wall Slide freigeschaltet!")
		"regeneration":
			has_regeneration_skill = true
			print("Regeneration freigeschaltet!")
		"ult":
			has_ult_skill = true
			print("Ultimate Fähigkeit freigeschaltet!")
		"double_jump":
			has_double_jump_skill = true
			print("Double Jump Fähigkeit freigeschaltet!")
		"wall_run":
			has_wall_run_skill = true
			print("Wall Run Fähigkeit freigeschaltet!")
		"dash":
			has_dash_skill = true
			print("Dash Fähigkeit freigeschaltet!")
		"teleport":
			has_teleport_skill = true
			print("Teleport Fähigkeit freigeschaltet!")
		"mana_shield":
			has_mana_shield_skill = true
			print("Mana Shield Fähigkeit freigeschaltet!")
		"heal_burst":
			has_heal_burst_skill = true
			print("Heal Burst Fähigkeit freigeschaltet!")
		"sticky_form":
			has_sticky_form_skill = true
			print("Sticky Form freigeschaltet!")
		"hero_form":
			has_hero_form_skill = true
			print("Hero Form freigeschaltet!")
		"thorns":
			has_thorns_skill = true
			print("Thorns freigeschaltet!")
		"slime_wings":
			has_slime_wings_skill = true
			print("Slime Wings freigeschaltet!")
	
	_refresh_player_tuning_from_skills()
	save_skills()  # Speichere die Skills nach dem Freischalten

# Überprüfe Level-Anforderungen für Skills
func can_unlock_skill(skill_name: String) -> bool:
	var skill_data = skill_tree.skills.get(skill_name)
	if skill_data and player_level >= skill_data.level_required:
		return true
	return false

# Erhöhe das Level (wird aufgerufen, wenn der Spieler ein Level aufsteigt)
func level_up():
	player_level += 1
	print("Level up! Neues Level: ", player_level)

func check_level_completion():
	var completed_levels = load_completed_levels()
	print("Abgeschlossene Level: ", completed_levels)

func load_completed_levels() -> Array:
	if FileAccess.file_exists("user://completed_levels.save"):
		var file = FileAccess.open("user://completed_levels.save", FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if data is Array:
			return data
	return []

func save_skills():
	var save_data = {
		"has_glow_skill": has_glow_skill,
		"has_wall_slide_skill": has_wall_slide_skill,
		"has_regeneration_skill": has_regeneration_skill,
		"has_ult_skill": has_ult_skill,
		"has_double_jump_skill": has_double_jump_skill,
		"has_wall_run_skill": has_wall_run_skill,
		"has_dash_skill": has_dash_skill,
		"has_teleport_skill": has_teleport_skill,
		"has_mana_shield_skill": has_mana_shield_skill,
		"has_heal_burst_skill": has_heal_burst_skill,
		"has_sticky_form_skill": has_sticky_form_skill,
		"has_hero_form_skill": has_hero_form_skill,
		"has_thorns_skill": has_thorns_skill,
		"has_slime_wings_skill": has_slime_wings_skill,
		"player_level": player_level
	}
	
	var file = FileAccess.open("user://player_skills.save", FileAccess.WRITE)
	file.store_var(save_data)
	file.close()

func _load_legacy_skill_unlocks() -> Dictionary:
	var legacy_unlocks := {}
	var legacy_path := "user://skills.save"
	if not FileAccess.file_exists(legacy_path):
		return legacy_unlocks

	var file := FileAccess.open(legacy_path, FileAccess.READ)
	if file == null:
		return legacy_unlocks

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return legacy_unlocks

	for skill_name in parsed.keys():
		var skill_entry = parsed[skill_name]
		if skill_entry is Dictionary:
			legacy_unlocks[skill_name] = bool(skill_entry.get("unlocked", false))

	return legacy_unlocks

func load_skills():
	var legacy_unlocks := _load_legacy_skill_unlocks()
	var should_resave := false

	if not FileAccess.file_exists("user://player_skills.save"):
		var legacy_glow := bool(legacy_unlocks.get("glow", has_glow_skill))
		if legacy_glow != has_glow_skill:
			has_glow_skill = legacy_glow
			should_resave = true
		if DEBUG_UNLOCK_HERO_FORM and not has_hero_form_skill:
			has_hero_form_skill = true
			should_resave = true
		if is_glowing and not has_glow_skill:
			is_glowing = false
		if should_resave:
			save_skills()
		_sync_skill_tree_from_flags()
		_enforce_skill_progression()
		_sync_skill_tree_from_flags()
		_refresh_player_tuning_from_skills()
		return
	
	var file = FileAccess.open("user://player_skills.save", FileAccess.READ)
	var save_data = file.get_var()
	file.close()
	
	has_glow_skill = save_data.get("has_glow_skill", false)
	has_wall_slide_skill = save_data.get("has_wall_slide_skill", false)
	has_regeneration_skill = save_data.get("has_regeneration_skill", false)
	has_ult_skill = save_data.get("has_ult_skill", false)
	has_double_jump_skill = save_data.get("has_double_jump_skill", false)
	has_wall_run_skill = save_data.get("has_wall_run_skill", false)
	has_dash_skill = save_data.get("has_dash_skill", false)
	has_teleport_skill = save_data.get("has_teleport_skill", false)
	has_mana_shield_skill = save_data.get("has_mana_shield_skill", false)
	has_heal_burst_skill = save_data.get("has_heal_burst_skill", false)
	has_sticky_form_skill = save_data.get("has_sticky_form_skill", false)
	has_hero_form_skill = save_data.get("has_hero_form_skill", false)
	has_thorns_skill = save_data.get("has_thorns_skill", false)
	has_slime_wings_skill = save_data.get("has_slime_wings_skill", false)
	player_level = save_data.get("player_level", 1)

	var legacy_glow := bool(legacy_unlocks.get("glow", false))
	if legacy_glow and not has_glow_skill:
		has_glow_skill = true
		should_resave = true

	if DEBUG_UNLOCK_HERO_FORM and not has_hero_form_skill:
		has_hero_form_skill = true
		should_resave = true

	if is_glowing and not has_glow_skill:
		is_glowing = false
	
	_sync_skill_tree_from_flags()
	_enforce_skill_progression()
	_sync_skill_tree_from_flags()

	if should_resave:
		save_skills()

	_refresh_player_tuning_from_skills()

func _refresh_player_tuning_from_skills() -> void:
	if not has_hero_form_skill and current_character_id == CharacterCatalog.MALE_HERO_ID:
		_apply_character_profile(CharacterCatalog.SLIME_ID)

	max_air_jumps = 1 if has_double_jump_skill else 0
	wall_slide_speed_cap = 40.0 if has_wall_slide_skill else base_wall_slide_speed
	wall_run_vertical_speed = 190.0 if has_wall_run_skill else base_wall_run_vertical_speed

	dash_speed = base_dash_speed
	dash_duration = base_dash_duration
	dash_cooldown = base_dash_cooldown
	attack_cooldown = 0.10
	WALK_SPEED = base_walk_speed
	RUN_SPEED = base_run_speed
	combo_damage_multipliers.clear()
	combo_knockback_strengths.clear()
	combo_lunge_strengths.clear()
	for i in range(MAX_COMBO):
		var combo_t := float(i) / float(MAX_COMBO - 1)
		var profile_damage: Array = hero_combat_config.get("combo_damage", [])
		var profile_knockback: Array = hero_combat_config.get("combo_knockback", [])
		var profile_lunge: Array = hero_combat_config.get("combo_lunge", [])
		combo_damage_multipliers.append(float(profile_damage[i]) if i < profile_damage.size() else 1.0 + combo_t * 0.78 + combo_t * combo_t * 0.2)
		combo_knockback_strengths.append(float(profile_knockback[i]) if i < profile_knockback.size() else 220.0 + combo_t * 190.0 + combo_t * combo_t * 40.0)
		combo_lunge_strengths.append(float(profile_lunge[i]) if i < profile_lunge.size() else 90.0 + combo_t * 72.0 + sin(combo_t * PI) * 10.0)

	if hero_combat_config.has("attack_cooldown"):
		attack_cooldown = float(hero_combat_config.get("attack_cooldown", attack_cooldown))

	if has_dash_skill:
		dash_speed *= 1.12
		dash_duration *= 0.95
		dash_cooldown *= 0.82
		attack_cooldown = 0.08
		for i in range(MAX_COMBO):
			var combo_t := float(i) / float(MAX_COMBO - 1)
			combo_lunge_strengths[i] += lerpf(8.0, 26.0, combo_t)
		if dash_cooldown_timer and dash_cooldown_timer.time_left <= 0.0:
			can_dash = true
	else:
		is_dashing = false
		can_dash = false

	if not has_teleport_skill:
		can_teleport = false
		is_teleporting = false
	elif teleport_cooldown_timer == null or teleport_cooldown_timer.time_left <= 0.0:
		can_teleport = true

	if not has_slime_wings_skill:
		is_gliding = false

	if has_thorns_skill:
		for i in range(MAX_COMBO):
			var combo_t := float(i) / float(MAX_COMBO - 1)
			combo_knockback_strengths[i] *= lerpf(1.02, 1.12, combo_t)

	if has_glow_skill and is_glowing:
		for i in range(MAX_COMBO):
			var combo_t := float(i) / float(MAX_COMBO - 1)
			combo_damage_multipliers[i] *= lerpf(1.03, 1.12, combo_t)

	var move_bonus := 0.0
	for item in _get_equipped_items():
		move_bonus += item.move_speed_bonus

	WALK_SPEED *= 1.0 + move_bonus
	RUN_SPEED *= 1.0 + move_bonus

	var weapon := _get_equipped_weapon_or_default()
	weapon_attack_reach_bonus = weapon.attack_reach_bonus if weapon else 0.0
	if weapon:
		attack_cooldown = max(attack_cooldown * (1.0 - weapon.attack_speed_bonus - weapon_speed_burst_bonus), 0.04)
		for i in range(MAX_COMBO):
			combo_knockback_strengths[i] += weapon.knockback_bonus
	else:
		attack_cooldown = max(attack_cooldown * (1.0 - weapon_speed_burst_bonus), 0.04)

	if dash_timer:
		dash_timer.wait_time = dash_duration
	if dash_cooldown_timer:
		dash_cooldown_timer.wait_time = dash_cooldown

func handle_wall_run(delta: float) -> void:
	if _is_hero_form_active():
		if is_wall_running:
			end_wall_run()
		return
	if !has_wall_run_skill:
		return
	# Cooldown Timer aktualisieren
	if wall_run_cooldown > 0.0:
		wall_run_cooldown -= delta
	
	# Prüfen ob Wand gerade verlassen wurde
	if was_on_wall and not is_on_wall():
		# Wand wurde verlassen, starte Cooldown
		wall_run_cooldown = 2.0  # 1 Sekunde Cooldown
		print("Wand verlassen - Cooldown gestartet: 1s")
	
	# Aktuellen Wand-Status speichern
	was_on_wall = is_on_wall()
	
	if can_wall_run() and is_on_wall() and not is_on_floor():
		start_wall_run()
	
	if is_wall_running:
		update_wall_run(delta)
		
		# Timer überprüfen und Wall Run beenden wenn abgelaufen
		if wall_run_timer <= 0.0:
			end_wall_run()
	
	# Wall Run beenden wenn Bedingungen nicht mehr erfüllt
	if is_wall_running and should_end_wall_run():
		end_wall_run()

func can_wall_run() -> bool:
	# Prüfe ob Sprint gedrückt wird während up/down Bewegung
	var vertical_input = Input.get_axis("up_walk", "down")
	var sprint_pressed = Input.is_action_pressed("sprint")
	
	return (not is_wall_running and 
			wall_run_timer <= 0.0 and
			wall_run_cooldown <= 0.0 and  # Cooldown muss abgelaufen sein
			vertical_input != 0 and
			sprint_pressed)

func should_end_wall_run() -> bool:
	return (not is_on_wall() or 
			is_on_floor() or 
			not Input.is_action_pressed("sprint") or
			Input.get_axis("up_walk", "down") == 0)

func start_wall_run() -> void:
	is_wall_running = true
	wall_run_active = true
	wall_run_timer = 1.5  # 3 Sekunden Timer
	wall_run_cooldown = 0.0  # Cooldown zurücksetzen
	current_wall_normal = get_wall_normal()
	wall_run_direction = -current_wall_normal.x
	
	# Starte an der Wand zu laufen
	velocity.y = 0  # Stoppe Fallgeschwindigkeit
	#$AnimationPlayer.play("wall_run")
	print("Wall Run gestartet! Timer: ", wall_run_timer, "s")

func update_wall_run(delta: float) -> void:
	if wall_run_active:
		# Timer aktualisieren
		wall_run_timer -= delta
		
		# Wall Run Bewegung basierend auf Input
		var vertical_input = Input.get_axis("up_walk", "down")
		velocity.y = vertical_input * wall_run_vertical_speed
		
		# Sanft an der Wand halten
		velocity.x = current_wall_normal.x * -30
		
		#print("Wall Run Timer: ", wall_run_timer)  # Debug

func end_wall_run() -> void:
	if is_wall_running:
		is_wall_running = false
		wall_run_active = false
		
		# Leichten Schub von der Wand geben
		if is_on_wall():
			velocity.x = -wall_run_direction * 100
		
		# Timer zurücksetzen
		wall_run_timer = 0.0
		#$AnimationPlayer.stop()
		print("Wall Run beendet!")

# Cooldown Status für UI anzeigen (optional)
func get_wall_run_cooldown_percentage() -> float:
	return clamp(wall_run_cooldown / 1.0, 0.0, 1.0) if wall_run_cooldown > 0.0 else 0.0

func perform_teleport() -> void:
	if not has_teleport_skill:
		return
	if not can_teleport or is_dashing or is_attacking or is_stunned or is_teleporting:
		return
	
	# Hole die exakte Mausposition in der Welt
	var mouse_pos = get_global_mouse_position()
	
	# Berechne die Distanz zur Maus
	var distance_to_mouse = global_position.distance_to(mouse_pos)
	
	# Begrenze die Teleport-Distanz auf das Maximum
	var actual_distance = min(distance_to_mouse, TELEPORT_DISTANCE)
	
	# Wenn die Distanz begrenzt wird, berechne die begrenzte Position
	var target_position = mouse_pos
	if distance_to_mouse > TELEPORT_DISTANCE:
		var direction = (mouse_pos - global_position).normalized()
		target_position = global_position + (direction * TELEPORT_DISTANCE)
	
	# Prüfe nur ob die ZIELPOSITION frei ist (ignoriere den Weg)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = target_position
	query.collision_mask = collision_mask
	query.exclude = [self]
	query.collide_with_areas = false  # Nur mit Bodies kollidieren
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	
	if results.size() > 0:
		# Zielposition ist blockiert, suche nahegelegene freie Position
		print("Zielposition blockiert, suche alternative Position...")
		var free_position = find_nearby_free_position(target_position)
		if free_position:
			target_position = free_position
		else:
			print("Teleport abgebrochen: Keine freie Position in der Nähe gefunden")
			return
	
	# Starte den Teleportationsprozess
	start_teleport_sequence(target_position)

func start_teleport_sequence(target_position: Vector2) -> void:
	is_teleporting = true
	
	# Erste Phase: Auflösen
	var dissolve_tween = create_tween()
	dissolve_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	dissolve_tween.tween_callback(finish_dissolve.bind(target_position))

func finish_dissolve(target_position: Vector2) -> void:
	# Teleport-Effekte am Ausgangspunkt
	create_teleport_effects(global_position, false)
	
	# Zur (möglicherweise angepassten) Zielposition teleportieren
	global_position = target_position
	
	# Zweite Phase: Wiedererscheinen
	var appear_tween = create_tween()
	appear_tween.tween_property(self, "modulate:a", 1.0, 0.5)
	appear_tween.tween_callback(finish_teleport)
	
	# Teleport-Effekte am Zielpunkt
	create_teleport_effects(global_position, true)
	
	# Blickrichtung zur Maus aktualisieren
	is_facing_left = get_global_mouse_position().x < global_position.x
	$PlayerSprite.flip_h = is_facing_left
	$PlayerSprite/AttackSprite.flip_h = is_facing_left

func finish_teleport() -> void:
	is_teleporting = false
	
	# Cooldown starten
	can_teleport = false
	teleport_cooldown_timer.start()
	
	# Synchronisiere den Teleport mit anderen Clients (Multiplayer)
	if is_multiplayer_authority():
		sync_teleport.rpc(global_position, is_facing_left)
	
	print("Teleportiert zu: ", global_position)

# Hilfsfunktion um freie Position in der Nähe zu finden
func find_nearby_free_position(target_pos: Vector2, search_radius: float = 100.0) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	
	# Prüfe zuerst die exakte Position (falls doch frei)
	var query = PhysicsPointQueryParameters2D.new()
	query.position = target_pos
	query.collision_mask = collision_mask
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	if space_state.intersect_point(query).size() == 0:
		return target_pos
	
	# Suche in konzentrischen Kreisen um die Zielposition
	for radius in range(20, int(search_radius) + 1, 20):
		for angle in range(0, 360, 30):  # Alle 30 Grad prüfen
			var check_pos = target_pos + Vector2(radius, 0).rotated(deg_to_rad(angle))
			
			query.position = check_pos
			if space_state.intersect_point(query).size() == 0:
				return check_pos
	
	return Vector2.ZERO  # Keine freie Position gefunden

func _on_teleport_cooldown_timeout() -> void:
	can_teleport = has_teleport_skill
	# Optional: Sound oder visuelles Feedback dass Teleport wieder verfügbar ist

func create_teleport_effects(position: Vector2, is_arrival: bool) -> void:
	# Partikel-Effekt
	teleport_particles.global_position = position
	teleport_particles.emitting = true

	# Bildschirm-Shake
	$Camera2D.shake(0.2, 10)

@rpc("any_peer", "call_local", "reliable")
func sync_teleport(target_pos: Vector2, facing_left: bool) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	
	global_position = target_pos
	is_facing_left = facing_left
	$PlayerSprite.flip_h = is_facing_left
	$PlayerSprite/AttackSprite.flip_h = is_facing_left
	create_teleport_effects(target_pos, true)

func activate_mana_shield():
	if !has_mana_shield_skill:
		return
	if mana_shield_active:
		return
	
	mana_shield_active = true
	mana_shield_health = max_mana_shield_health
	
	# Sprite und Licht aktivieren
	shield_sprite.visible = true
	shield_light.enabled = true
	
	# Animation für das Erscheinen des Schildes
	var tween = create_tween()
	tween.tween_property(shield_sprite, "scale", Vector2(1, 1), 0.3).from(Vector2(0.5, 0.5))
	tween.parallel().tween_property(shield_sprite, "modulate:a", 1.0, 0.3).from(0.0)
	tween.parallel().tween_property(shield_light, "energy", 1.0, 0.3).from(0.0)
	
	# Synchronisiere mit anderen Clients
	sync_mana_shield_state.rpc(true, max_mana_shield_health)

func deactivate_mana_shield():
	if not mana_shield_active:
		return
	
	mana_shield_active = false
	mana_shield_health = 0
	
	# Animation für das Verschwinden des Schildes
	var tween = create_tween()
	tween.tween_property(shield_sprite, "scale", Vector2(0.5, 0.5), 0.3)
	tween.parallel().tween_property(shield_sprite, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(shield_light, "energy", 0.0, 0.3)
	tween.tween_callback(finalize_deactivation)
	
	# Synchronisiere mit anderen Clients
	sync_mana_shield_state.rpc(false, 0)

func finalize_deactivation():
	shield_sprite.visible = false
	shield_light.enabled = false

func shield_hit_effect():
	# Kamera-Shake für Feedback
	$Camera2D.shake(0.1, 8)
	
	# Schild-Treffer-Sound
	#$ShieldHitSound.play()
	
	# Blitz-Effekt bei Treffer
	var tween = create_tween()
	tween.tween_property(shield_sprite, "modulate", Color(2, 2, 2, 1), 0.05)
	tween.tween_property(shield_sprite, "modulate", Color(1, 1, 1, 1), 0.15)
	tween.parallel().tween_property(shield_light, "energy", 2.0, 0.05)
	tween.tween_property(shield_light, "energy", 1.0, 0.15)

@rpc("any_peer", "call_local", "reliable")
func sync_mana_shield_state(active: bool, health: float):
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
		
	mana_shield_active = active
	mana_shield_health = health
	
	if active:
		shield_sprite.visible = true
		shield_light.enabled = true
		shield_sprite.scale = Vector2(1, 1)
		shield_sprite.modulate.a = 1.0
		shield_light.energy = 1.0
	else:
		shield_sprite.visible = false
		shield_light.enabled = false

func perform_heal_burst():
	if !has_heal_burst_skill:
		return
	if current_health < 100:
		heal(max_health/2)
		update_health_bar()


# Neue Funktionen für Sticky Form
func handle_sticky_form_timers(delta: float):
	if sticky_form_timer > 0.0:
		sticky_form_timer -= delta
		if sticky_form_timer <= 0.0:
			end_sticky_form()
	
	if sticky_form_cooldown_timer > 0.0:
		sticky_form_cooldown_timer -= delta

func handle_sticky_form_mechanics(delta: float):
	if is_sticky_form_active and is_on_wall():
		# Spieler haftet an der Wand - keine Schwerkraft und kein Herunterrutschen
		velocity.y = 0
		velocity.x = 0
		
		# Sanft an der Wand halten
		var wall_normal = get_wall_normal()
		position += wall_normal * -2 * delta  # Leicht von der Wand wegdrücken für bessere Kollision

func perform_sticky_form():
	if !has_sticky_form_skill:
		print("Sticky Form Fähigkeit nicht freigeschaltet!")
		return
	
	if sticky_form_cooldown_timer > 0.0:
		print("Sticky Form ist im Cooldown! Noch ", sticky_form_cooldown_timer, " Sekunden")
		return
	
	if not is_on_wall():
		print("Kann Sticky Form nur an einer Wand aktivieren!")
		return
	
	if is_sticky_form_active:
		end_sticky_form()
		return
	
	start_sticky_form()

func start_sticky_form():
	is_sticky_form_active = true
	sticky_form_timer = STICKY_FORM_DURATION
	sticky_form_cooldown_timer = STICKY_FORM_COOLDOWN
	
	# Effekte für Sticky Form Start
	$Camera2D.shake(0.1, 5)
	
	# Visueller Effekt - Spieler wird etwas durchsichtig
	var tween = create_tween()
	tween.tween_property($PlayerSprite, "modulate", Color(1, 1, 1, 0.7), 0.3)
	
	# Soundeffekt
	# $StickyFormSound.play()
	
	print("Sticky Form aktiviert! Haftet für ", STICKY_FORM_DURATION, " Sekunden an der Wand")
	
	# Synchronisiere mit anderen Clients
	sync_sticky_form_state.rpc(true, STICKY_FORM_DURATION)

func end_sticky_form():
	if not is_sticky_form_active:
		return
	
	is_sticky_form_active = false
	
	# Effekte zurücksetzen
	var tween = create_tween()
	tween.tween_property($PlayerSprite, "modulate", Color(1, 1, 1, 1), 0.3)
	
	print("Sticky Form beendet")
	
	# Synchronisiere mit anderen Clients
	sync_sticky_form_state.rpc(false, 0.0)

# RPC für Synchronisation
@rpc("any_peer", "call_local", "reliable")
func sync_sticky_form_state(active: bool, duration: float):
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
		
	is_sticky_form_active = active
	if active:
		sticky_form_timer = duration
		var tween = create_tween()
		tween.tween_property($PlayerSprite, "modulate", Color(1, 1, 1, 0.7), 0.3)
	else:
		var tween = create_tween()
		tween.tween_property($PlayerSprite, "modulate", Color(1, 1, 1, 1), 0.3)

func throw_slimeball():
	if slimeball_scene:
		var slimeball = slimeball_scene.instantiate()
		get_parent().add_child(slimeball)
		
		# Positioniere den Slimeball vor dem Spieler
		var throw_direction = Vector2.RIGHT if not is_facing_left else Vector2.LEFT
		slimeball.global_position = global_position + throw_direction * 20
		
		# Werfe den Slimeball
		if slimeball.has_method("throw"):
			slimeball.throw(throw_direction * throw_force)
			print("Slimeball geworfen!")


func handle_slime_wings(delta: float) -> void:
	if not has_slime_wings_skill or not _character_can("slime_wings", true):
		if is_gliding:
			end_gliding()
		return

	# Prüfe ob Gleiten möglich ist und aktiviert wird
	if can_glide() and Input.is_action_pressed("up_walk"):
		start_gliding()
	elif is_gliding and (not Input.is_action_pressed("up_walk") or should_end_glide()):
		end_gliding()
	
	# Gleit-Mechanik anwenden (auch wenn bereits gleitend)
	if is_gliding:
		apply_glide_physics(delta)

func can_glide() -> bool:
	# Einfachere Bedingung: Kann gleiten wenn in der Luft und nicht in anderen Aktionen
	return (not is_on_floor() and 
			not is_wall_sliding and 
			not is_dashing and 
			not is_attacking and 
			not is_gliding)

func start_gliding() -> void:
	print("GLIDING STARTED!")
	is_gliding = true
	
	print("Slime Wings aktiviert - Gleiten!")
	
	# Synchronisiere mit anderen Clients
	sync_glide_state.rpc(true)

func end_gliding() -> void:
	is_gliding = false
	
	print("Gleiten beendet")
	
	# Synchronisiere mit anderen Clients
	sync_glide_state.rpc(false)

func apply_glide_physics(delta: float) -> void:
	# Reduzierte Schwerkraft beim Gleiten
	velocity.y += gravity_force * SLIME_WINGS_GRAVITY_REDUCTION * delta
	
	# Minimale Fallgeschwindigkeit begrenzen
	velocity.y = max(velocity.y, SLIME_WINGS_MIN_FALL_SPEED)
	
	# Horizontale Kontrolle beim Gleiten
	var horizontal_input = Input.get_axis("left", "right")
	if horizontal_input != 0:
		velocity.x = move_toward(
			velocity.x, 
			horizontal_input * SLIME_WINGS_GLIDE_SPEED, 
			AIR_ACCELERATION * delta
		)

func should_end_glide() -> bool:
	# Beende Gleiten wenn: am Boden, an der Wand, oder andere Aktionen
	return is_on_floor() or is_on_wall() or is_dashing or is_attacking

# RPC für Synchronisation des Gleitzustands
@rpc("any_peer", "call_local", "reliable")
func sync_glide_state(gliding: bool):
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
		
	is_gliding = gliding



# Füge diese Methoden zur Player-Klasse hinzu:
func get_health_percentage() -> float:
	return float(current_health) / float(max_health)

func apply_buff(buff_type: String, value: float) -> void:
	active_buffs[buff_type] = value
	_update_stats_from_buffs()  # Diese Zeile sollte bereits da sein, aber prüfe ob sie funktioniert
	print("Buff angewendet: ", buff_type, " Wert: ", value)  # Debug-Ausgabe

func apply_timed_buff(buff_type: String, value: float, duration: float) -> void:
	apply_buff(buff_type, value)
	if timed_buff_timers.has(buff_type):
		var existing_timer: Timer = timed_buff_timers[buff_type] as Timer
		if existing_timer and is_instance_valid(existing_timer):
			existing_timer.stop()
			existing_timer.queue_free()

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(duration, 0.05)
	add_child(timer)
	timed_buff_timers[buff_type] = timer
	timer.timeout.connect(_on_timed_buff_expired.bind(buff_type, timer))
	timer.start()

func remove_buff(buff_type: String) -> void:
	if active_buffs.has(buff_type):
		active_buffs.erase(buff_type)
		_update_stats_from_buffs()  # Diese Zeile sollte bereits da sein
	if timed_buff_timers.has(buff_type):
		var timer: Timer = timed_buff_timers[buff_type] as Timer
		timed_buff_timers.erase(buff_type)
		if timer and is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	print("Buff entfernt: ", buff_type)  # Debug-Ausgabe

func has_buff(buff_type: String) -> bool:
	return active_buffs.has(buff_type)

func _on_timed_buff_expired(buff_type: String, timer: Timer) -> void:
	if timed_buff_timers.get(buff_type, null) == timer:
		timed_buff_timers.erase(buff_type)
	if timer and is_instance_valid(timer):
		timer.queue_free()
	if active_buffs.has(buff_type):
		active_buffs.erase(buff_type)
		_update_stats_from_buffs()

func _update_stats_from_buffs() -> void:
	_refresh_player_tuning_from_skills()
	# RESET auf Basiswerte zuerst
	WALK_SPEED = base_walk_speed
	RUN_SPEED = base_run_speed
	var final_damage_multiplier = damage_multiplier  # Item-Multiplikator behalten
	damage_reduction = 0.0
	
	# JEDEN Buff-Typ verarbeiten
	for buff_type in active_buffs:
		var value = active_buffs[buff_type]
		if buff_type == "speed_boost" or buff_type == "temporary_speed" or String(buff_type).begins_with("temporary_speed_"):
			WALK_SPEED *= value
			RUN_SPEED *= value
			print("✅ ", buff_type, " angewendet: ", value, " -> Walk: ", WALK_SPEED, " Run: ", RUN_SPEED)
			continue
		
		match buff_type:
			"damage_boost":
				final_damage_multiplier *= value
				print("✅ ", buff_type, " angewendet: ", value, " -> Multiplier: ", final_damage_multiplier)
			
			"damage_reduction", "constant_damage_reduction":
				damage_reduction += value
				print("✅ ", buff_type, " angewendet: ", value, " -> Reduction: ", damage_reduction)
			
			"healing_boost":
				# Wird separat im Heal-Timer gehandled
				pass
	
	# Schadensreduktion begrenzen
	damage_reduction = clamp(damage_reduction, 0.0, 0.8)
	
	# Endgültigen Schaden berechnen
	attack_damage = int(base_attack_damage * final_damage_multiplier)
	
	print("🎯 FINAL - Walk: ", WALK_SPEED, " Run: ", RUN_SPEED, " Damage: ", attack_damage, " Reduction: ", damage_reduction)



func _check_lumora_interaction():
	if Engine.get_frames_drawn() % 180 != 0:
		return
	var lumoras = get_tree().get_nodes_in_group("lumora")
	for lumora_node in lumoras:
		if lumora_node.has_method("_update_catch_system") and not bool(lumora_node.get("is_caught")):
			var distance = global_position.distance_to(lumora_node.global_position)
			var catch_radius = float(lumora_node.get("catch_radius"))
			if distance <= catch_radius:
				print("💫 Ein Stern ist in Reichweite - halte [E] zum Einfangen!")
				return

func _show_interact_prompt():
	# UI Element für Interact-Prompt anzeigen
	# Beispiel: 
	if has_node("InteractPrompt"):
		$InteractPrompt.visible = true
	else:
		# Erstelle ein temporäres Label für Debugging
		print("🔼 Drücke und halte [E] um Lumora zu fangen")

func _hide_interact_prompt():
	# UI Element für Interact-Prompt verstecken
	if has_node("InteractPrompt"):
		$InteractPrompt.visible = false
