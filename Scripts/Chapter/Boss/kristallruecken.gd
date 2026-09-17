extends CharacterBody2D

const LootDropper := preload("res://Scripts/loot_dropper.gd")

signal health_changed(current_health: int, max_health_value: int)
signal first_damage_taken
signal boss_died
signal death_animation_finished
signal portal_spawn_started
signal portal_activated

enum State {
	IDLE,
	CHASE,
	REPOSITION,
	GROUND_ATTACK_TELEGRAPH,
	GROUND_ATTACK,
	MAGIC_CHARGE,
	MAGIC_FIRE,
	SUMMON,
	RECOVERY,
	HURT,
	LUNGE_TELEGRAPH,
	LUNGE,
	DEATH
}

const GRAVITY := 1280.0
const CONTACT_COOLDOWN := 0.82
const CRYSTAL_VEIN_SCENE := preload("res://Scenes/Chapter/Boss/crystal_vein.tscn")
const CRYSTAL_ORB_SCENE := preload("res://Scenes/Chapter/Boss/crystal_orb.tscn")
const IRRLICHTKAEFER_SCENE := preload("res://Scenes/Chapter/Enemies/irrlichtkaefer.tscn")
const IDLE_FRAMES := [
	preload("res://Assets/Enemies/Kristallruecken/frames/idle_00.png"), preload("res://Assets/Enemies/Kristallruecken/frames/idle_01.png"), preload("res://Assets/Enemies/Kristallruecken/frames/idle_02.png"), preload("res://Assets/Enemies/Kristallruecken/frames/idle_03.png"), preload("res://Assets/Enemies/Kristallruecken/frames/idle_04.png")
]
const WALK_FRAMES := [
	preload("res://Assets/Enemies/Kristallruecken/frames/walk_00.png"), preload("res://Assets/Enemies/Kristallruecken/frames/walk_01.png"), preload("res://Assets/Enemies/Kristallruecken/frames/walk_02.png"), preload("res://Assets/Enemies/Kristallruecken/frames/walk_03.png"), preload("res://Assets/Enemies/Kristallruecken/frames/walk_04.png"), preload("res://Assets/Enemies/Kristallruecken/frames/walk_05.png"), preload("res://Assets/Enemies/Kristallruecken/frames/walk_06.png")
]
const LUNGE_FRAMES := [
	preload("res://Assets/Enemies/Kristallruecken/frames/lunge_00.png"), preload("res://Assets/Enemies/Kristallruecken/frames/lunge_01.png"), preload("res://Assets/Enemies/Kristallruecken/frames/lunge_02.png")
]
const GROUND_PREPARE_FRAMES := [preload("res://Assets/Enemies/Kristallruecken/frames/ground_prepare_00.png")]
const MAGIC_PREPARE_FRAMES := [
	preload("res://Assets/Enemies/Kristallruecken/frames/magic_prepare_00.png"), preload("res://Assets/Enemies/Kristallruecken/frames/magic_prepare_01.png"), preload("res://Assets/Enemies/Kristallruecken/frames/magic_prepare_02.png")
]
const MAGIC_FIRE_FRAMES := [preload("res://Assets/Enemies/Kristallruecken/frames/magic_fire_00.png")]
const DEATH_FRAMES := [
	preload("res://Assets/Enemies/Kristallruecken/frames/death_00.png"), preload("res://Assets/Enemies/Kristallruecken/frames/death_01.png"), preload("res://Assets/Enemies/Kristallruecken/frames/death_02.png"), preload("res://Assets/Enemies/Kristallruecken/frames/death_03.png"), preload("res://Assets/Enemies/Kristallruecken/frames/death_04.png"), preload("res://Assets/Enemies/Kristallruecken/frames/death_05.png"), preload("res://Assets/Enemies/Kristallruecken/frames/death_06.png")
]

@export var boss_health: int = 330
@export var contact_damage: int = 13
@export var crystal_damage: int = 24
@export var orb_damage: int = 20
@export var lunge_damage: int = 22
@export var crystal_knockback: float = 280.0
@export var orb_speed: float = 250.0
@export var walk_speed: float = 76.0
@export var summon_cooldown: float = 9.0
@export var ground_attack_cooldown: float = 5.0
@export var magic_attack_cooldown: float = 6.0
@export var max_summons: int = 2
@export var telegraph_time: float = 0.64
@export var recovery_time: float = 0.82
@export var activation_distance: float = 620.0
@export var lunge_speed: float = 360.0

var current_health: int
var player: Node2D
var state: State = State.IDLE
var state_time := 0.0
var local_time := 0.0
var contact_cooldown := 0.0
var ground_cooldown := 1.6
var magic_cooldown := 2.8
var summon_timer := 5.5
var lunge_cooldown := 3.4
var last_attack := ""
var facing_sign := 1.0
var lunge_direction := 1.0
var did_lunge_damage := false
var has_taken_first_damage := false
var death_complete := false
var ground_segments_spawned := 0
var next_ground_segment_time := 0.0
var active_minions: Array[Node2D] = []
var active_effects: Array[Node] = []
var charge_orb: Sprite2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_hitbox: Area2D = $BodyHitbox
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var glow_light: PointLight2D = $PointLight2D


func _ready() -> void:
	current_health = boss_health
	add_to_group("enemies")
	_build_frames()
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	body_hitbox.body_entered.connect(_on_body_hitbox_body_entered)
	_create_health_bar()
	_sync_player()
	sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	if state == State.DEATH:
		return
	_sync_player()
	state_time += delta
	local_time += delta
	contact_cooldown = maxf(contact_cooldown - delta, 0.0)
	ground_cooldown = maxf(ground_cooldown - delta, 0.0)
	magic_cooldown = maxf(magic_cooldown - delta, 0.0)
	summon_timer = maxf(summon_timer - delta, 0.0)
	lunge_cooldown = maxf(lunge_cooldown - delta, 0.0)
	_prune_minions()

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 760.0)
	else:
		velocity.y = maxf(velocity.y, 0.0)

	match state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.REPOSITION:
			_process_reposition(delta)
		State.GROUND_ATTACK_TELEGRAPH:
			_process_ground_telegraph(delta)
		State.GROUND_ATTACK:
			_process_ground_attack(delta)
		State.MAGIC_CHARGE:
			_process_magic_charge(delta)
		State.MAGIC_FIRE:
			_process_magic_fire(delta)
		State.SUMMON:
			_process_summon(delta)
		State.RECOVERY:
			_process_recovery(delta)
		State.HURT:
			_process_hurt(delta)
		State.LUNGE_TELEGRAPH:
			_process_lunge_telegraph(delta)
		State.LUNGE:
			_process_lunge(delta)

	move_and_slide()
	_update_visuals()


func take_damage(amount: int, direction: Vector2, _is_crit: bool = false) -> void:
	if state == State.DEATH:
		return
	current_health = max(0, current_health - amount)
	var health_bar := get_node_or_null("HealthBar") as ProgressBar
	if not has_taken_first_damage:
		has_taken_first_damage = true
		first_damage_taken.emit()
		if health_bar != null:
			health_bar.visible = true
	if health_bar != null:
		health_bar.value = float(current_health)
	velocity += direction.normalized() * 58.0 if direction.length_squared() > 0.01 else Vector2(-facing_sign * 58.0, 0.0)
	health_changed.emit(current_health, boss_health)
	if current_health <= 0:
		_begin_death()
	elif state not in [State.GROUND_ATTACK_TELEGRAPH, State.GROUND_ATTACK, State.MAGIC_CHARGE, State.MAGIC_FIRE, State.SUMMON, State.LUNGE, State.LUNGE_TELEGRAPH]:
		_set_state(State.HURT)


func _process_idle(delta: float) -> void:
	_stop_horizontal(delta)
	if _player_distance() <= activation_distance:
		_set_state(State.CHASE)


func _process_chase(delta: float) -> void:
	if player == null:
		_set_state(State.IDLE)
		return
	var distance := _player_distance()
	if distance > activation_distance * 1.22:
		_set_state(State.IDLE)
		return
	var desired_range := 150.0
	var horizontal_delta := player.global_position.x - global_position.x
	if absf(horizontal_delta) > desired_range:
		_move_toward_x(player.global_position.x, walk_speed, delta)
	else:
		_stop_horizontal(delta)
		_choose_action(distance)


func _process_reposition(delta: float) -> void:
	if player == null:
		_set_state(State.IDLE)
		return
	var desired_x := player.global_position.x - facing_sign * 182.0
	_move_toward_x(desired_x, walk_speed * 0.82, delta)
	if state_time >= 0.68 or absf(global_position.x - desired_x) < 18.0:
		_set_state(State.CHASE)


func _process_ground_telegraph(delta: float) -> void:
	_stop_horizontal(delta)
	if state_time >= telegraph_time:
		_set_state(State.GROUND_ATTACK)


func _process_ground_attack(delta: float) -> void:
	_stop_horizontal(delta)
	if ground_segments_spawned == 0:
		_spawn_ground_segment()
		ground_segments_spawned = 1
		next_ground_segment_time = 0.46
	elif ground_segments_spawned == 1 and state_time >= next_ground_segment_time:
		_spawn_ground_segment()
		ground_segments_spawned = 2
	if state_time >= 1.12:
		_set_state(State.RECOVERY)


func _process_magic_charge(delta: float) -> void:
	_stop_horizontal(delta)
	_update_charge_orb()
	if sprite.frame >= 2:
		_set_state(State.MAGIC_FIRE)


func _process_magic_fire(delta: float) -> void:
	_stop_horizontal(delta)
	if state_time <= delta * 1.5:
		_fire_orb()
	if state_time >= 0.22:
		_set_state(State.RECOVERY)


func _process_summon(delta: float) -> void:
	_stop_horizontal(delta)
	if state_time >= 0.38 and active_minions.size() < max_summons:
		_spawn_irrlichtkaefer()
		if active_minions.size() < max_summons:
			_spawn_irrlichtkaefer()
		_set_state(State.RECOVERY)


func _process_recovery(delta: float) -> void:
	_stop_horizontal(delta)
	if state_time >= recovery_time:
		_set_state(State.CHASE)


func _process_hurt(delta: float) -> void:
	_stop_horizontal(delta)
	if state_time >= 0.14:
		_set_state(State.CHASE)


func _process_lunge_telegraph(delta: float) -> void:
	_stop_horizontal(delta)
	if state_time >= 0.30:
		_set_state(State.LUNGE)


func _process_lunge(delta: float) -> void:
	velocity.x = lunge_direction * lunge_speed
	if state_time >= 0.36 or is_on_wall():
		_set_state(State.RECOVERY)


func _choose_action(distance: float) -> void:
	var available: Array[String] = []
	if ground_cooldown <= 0.0 and last_attack != "ground":
		available.append("ground")
	if magic_cooldown <= 0.0 and last_attack != "magic":
		available.append("magic")
	if active_minions.size() < max_summons and summon_timer <= 0.0 and last_attack != "summon" and float(current_health) / float(max(1, boss_health)) <= 0.78:
		available.append("summon")
	if lunge_cooldown <= 0.0 and distance >= 112.0 and distance <= 276.0 and last_attack != "lunge":
		available.append("lunge")
	if available.is_empty():
		_set_state(State.REPOSITION)
		return
	# Alternating deterministic selection makes patterns learnable and prevents
	# random repeated damage spikes.
	var choice := available[0]
	if available.size() > 1:
		choice = available[int(fposmod(float(local_time * 3.0), float(available.size())))]
	match choice:
		"ground":
			last_attack = "ground"
			ground_cooldown = ground_attack_cooldown
			_set_state(State.GROUND_ATTACK_TELEGRAPH)
		"magic":
			last_attack = "magic"
			magic_cooldown = magic_attack_cooldown
			_set_state(State.MAGIC_CHARGE)
		"summon":
			last_attack = "summon"
			summon_timer = summon_cooldown
			_set_state(State.SUMMON)
		"lunge":
			last_attack = "lunge"
			lunge_cooldown = 4.4
			lunge_direction = facing_sign
			did_lunge_damage = false
			_set_state(State.LUNGE_TELEGRAPH)


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	_cleanup_charge_orb()
	state = next_state
	state_time = 0.0
	match state:
		State.IDLE:
			sprite.play(&"idle")
		State.CHASE, State.REPOSITION:
			sprite.play(&"walk")
		State.GROUND_ATTACK_TELEGRAPH:
			ground_segments_spawned = 0
			sprite.play(&"ground_attack_prepare")
		State.GROUND_ATTACK:
			sprite.play(&"ground_attack_prepare")
		State.MAGIC_CHARGE:
			sprite.play(&"magic_prepare")
			_create_charge_orb()
		State.MAGIC_FIRE:
			sprite.play(&"magic_fire")
		State.SUMMON:
			sprite.play(&"ground_attack_prepare")
		State.RECOVERY, State.HURT:
			sprite.play(&"idle")
		State.LUNGE_TELEGRAPH, State.LUNGE:
			sprite.play(&"lunge")


func _spawn_ground_segment() -> void:
	if player == null:
		return
	var start := global_position + Vector2(facing_sign * 30.0, 0.0)
	var target_x := player.global_position.x
	# Segment 2 gets exactly one later player-position correction. It never
	# re-targets continuously, so a jump/dodge always has a fair escape.
	var target_probe := Vector2(target_x, player.global_position.y)
	var target_y := _ground_y(target_probe)
	if target_y == -INF:
		target_y = global_position.y
	var target := Vector2(target_x, target_y)
	var vein := CRYSTAL_VEIN_SCENE.instantiate() as Area2D
	if vein == null:
		return
	get_parent().add_child(vein)
	vein.call("configure", start, target, crystal_damage, crystal_knockback)
	vein.finished.connect(_on_effect_finished.bind(vein))
	active_effects.append(vein)


func _create_charge_orb() -> void:
	charge_orb = Sprite2D.new()
	charge_orb.texture = MAGIC_FIRE_FRAMES[0]
	charge_orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	charge_orb.scale = Vector2(0.26, 0.26)
	charge_orb.modulate = Color(0.65, 1.0, 0.78, 0.90)
	charge_orb.z_index = 2
	add_child(charge_orb)


func _update_charge_orb() -> void:
	if charge_orb == null:
		return
	charge_orb.position = Vector2(facing_sign * 34.0, -56.0)
	var pulse := 0.92 + sin(state_time * 17.0) * 0.10
	charge_orb.scale = Vector2.ONE * 0.26 * pulse


func _cleanup_charge_orb() -> void:
	if is_instance_valid(charge_orb):
		charge_orb.queue_free()
	charge_orb = null


func _fire_orb() -> void:
	if player == null:
		return
	var source := global_position + Vector2(facing_sign * 43.0, -55.0)
	var predicted := player.global_position + _player_velocity() * 0.18
	var aim := predicted - source
	var orb := CRYSTAL_ORB_SCENE.instantiate() as Area2D
	if orb == null:
		return
	get_parent().add_child(orb)
	orb.call("configure", source, aim, orb_speed, orb_damage, crystal_knockback * 0.66)
	orb.finished.connect(_on_effect_finished.bind(orb))
	active_effects.append(orb)


func _spawn_irrlichtkaefer() -> void:
	if active_minions.size() >= max_summons:
		return
	var minion := IRRLICHTKAEFER_SCENE.instantiate() as Node2D
	if minion == null:
		return
	get_parent().add_child(minion)
	var offset := (-58.0 if active_minions.size() == 0 else 58.0) * facing_sign
	var spawn_probe := global_position + Vector2(offset, 0.0)
	var spawn_y := _ground_y(spawn_probe)
	minion.global_position = Vector2(spawn_probe.x, spawn_y if spawn_y > -INF else global_position.y)
	minion.set_meta("boss_summon", true)
	active_minions.append(minion)
	minion.tree_exited.connect(_on_minion_exited.bind(minion))


func _on_minion_exited(minion: Node2D) -> void:
	active_minions.erase(minion)


func _prune_minions() -> void:
	for index: int in range(active_minions.size() - 1, -1, -1):
		if not is_instance_valid(active_minions[index]):
			active_minions.remove_at(index)


func _on_effect_finished(effect: Node) -> void:
	active_effects.erase(effect)


func _on_body_hitbox_body_entered(body: Node2D) -> void:
	if state == State.DEATH or contact_cooldown > 0.0 or not body.is_in_group("players"):
		return
	if state == State.LUNGE and not did_lunge_damage:
		did_lunge_damage = true
		contact_cooldown = CONTACT_COOLDOWN
		if body.has_method("take_damage"):
			body.call("take_damage", lunge_damage, global_position)
		return
	if state not in [State.GROUND_ATTACK_TELEGRAPH, State.GROUND_ATTACK, State.MAGIC_CHARGE, State.MAGIC_FIRE, State.SUMMON, State.LUNGE_TELEGRAPH]:
		contact_cooldown = CONTACT_COOLDOWN
		if body.has_method("take_damage"):
			body.call("take_damage", contact_damage, global_position)


func _begin_death() -> void:
	state = State.DEATH
	velocity = Vector2.ZERO
	body_collision.set_deferred("disabled", true)
	body_hitbox.monitoring = false
	glow_light.energy = 0.0
	_cleanup_charge_orb()
	for effect: Node in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	active_effects.clear()
	for minion: Node2D in active_minions:
		if is_instance_valid(minion):
			minion.queue_free()
	active_minions.clear()
	health_changed.emit(0, boss_health)
	boss_died.emit()
	LootDropper.spawn_independent_drops(self, [
		{"item": "health_heart", "chance": 1.0, "min_count": 3, "max_count": 4},
		{"item": "copper_nugget", "chance": 1.0, "min_count": 2, "max_count": 3},
		{"item": "silver_nugget", "chance": 1.0, "min_count": 2, "max_count": 3},
		{"item": "irrlicht_eye", "chance": 0.18},
		{"item": "gold_nugget", "chance": 0.38, "min_count": 1, "max_count": 2}
	])
	sprite.play(&"death")


func _on_sprite_animation_finished() -> void:
	if state == State.DEATH and not death_complete:
		death_complete = true
		death_animation_finished.emit()


func _move_toward_x(target_x: float, speed: float, delta: float) -> void:
	var offset := target_x - global_position.x
	if absf(offset) > 2.0:
		facing_sign = signf(offset)
	var target_velocity := signf(offset) * minf(speed, absf(offset) * 4.2)
	velocity.x = move_toward(velocity.x, target_velocity, 540.0 * delta)


func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 680.0 * delta)


func _player_distance() -> float:
	return global_position.distance_to(player.global_position) if is_instance_valid(player) else INF


func _player_velocity() -> Vector2:
	var value: Variant = player.get("velocity") if is_instance_valid(player) else Vector2.ZERO
	return value as Vector2 if value is Vector2 else Vector2.ZERO


func _sync_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as Node2D


func _ground_y(probe: Vector2) -> float:
	var level := get_tree().get_first_node_in_group("chapter_runtime")
	if level != null and level.has_method("_surface_world_y_from_point"):
		return float(level.call("_surface_world_y_from_point", probe))
	return global_position.y


func _update_visuals() -> void:
	sprite.flip_h = facing_sign < 0.0
	if state == State.MAGIC_CHARGE:
		glow_light.energy = 0.34 + sin(local_time * 13.0) * 0.08
	elif state in [State.GROUND_ATTACK_TELEGRAPH, State.GROUND_ATTACK]:
		glow_light.energy = 0.22 + sin(local_time * 10.0) * 0.05
	else:
		glow_light.energy = 0.10


func _create_health_bar() -> void:
	var bar := ProgressBar.new()
	bar.name = "HealthBar"
	bar.position = Vector2(-44.0, -122.0)
	bar.size = Vector2(88.0, 8.0)
	bar.min_value = 0.0
	bar.max_value = float(boss_health)
	bar.value = float(boss_health)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.015, 0.05, 0.07, 0.96)
	background.border_color = Color(0.38, 0.95, 0.78, 0.85)
	background.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.24, 0.92, 0.64, 1.0)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	_add_frames(frames, &"idle", IDLE_FRAMES, 6.0, true)
	_add_frames(frames, &"walk", WALK_FRAMES, 9.0, true)
	_add_frames(frames, &"lunge", LUNGE_FRAMES, 10.0, true)
	_add_frames(frames, &"ground_attack_prepare", GROUND_PREPARE_FRAMES, 1.0, true)
	_add_frames(frames, &"magic_prepare", MAGIC_PREPARE_FRAMES, 7.0, false)
	_add_frames(frames, &"magic_fire", MAGIC_FIRE_FRAMES, 1.0, false)
	_add_frames(frames, &"death", DEATH_FRAMES, 7.0, false)
	sprite.sprite_frames = frames


func _add_frames(frames: SpriteFrames, animation_name: StringName, textures: Array, fps: float, loop: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)
	for texture: Texture2D in textures:
		frames.add_frame(animation_name, texture)
