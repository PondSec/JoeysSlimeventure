extends Node2D

@export var boss_path: NodePath
@export var exit_door_path: NodePath
@export var boss_checkpoint_name: String = "boss_checkpoint"
@export_multiline var encounter_message: String = "Ein uralter Wächter erwacht. Nutze den Raum und achte auf seine Wind-Ups."
@export_multiline var victory_message: String = "Der Steinwächter zerfällt – Kapitel 1 ist geschafft."
@export var reward_scenes: Array[PackedScene] = []

@onready var boss = get_node_or_null(boss_path)
@onready var exit_door = get_node_or_null(exit_door_path)
@onready var boss_trigger = $BossTrigger
@onready var reward_spawn = get_node_or_null("RewardSpawn")

var encounter_started := false
var rewards_spawned := false

func _ready() -> void:
	boss_trigger.body_entered.connect(_on_boss_trigger_body_entered)
	if ChapterState.get_flag("chapter_1_boss_defeated", false):
		_set_door_locked(false)
		if boss:
			boss.queue_free()
		return

	_set_door_locked(true)
	if boss and boss.has_signal("defeated"):
		boss.defeated.connect(_on_boss_defeated)

func _on_boss_trigger_body_entered(body: Node2D) -> void:
	if encounter_started or not body.is_in_group("players"):
		return

	encounter_started = true
	ChapterState.save_checkpoint(get_tree().current_scene.scene_file_path, boss_checkpoint_name)
	ChapterState.show_toast(get_tree(), encounter_message, "warning", 4.0)
	if body.has_method("heal"):
		body.heal(int(body.max_health * 0.5))

func _on_boss_defeated(_boss: Node) -> void:
	_set_door_locked(false)
	ChapterState.show_toast(get_tree(), victory_message, "success", 4.0)
	ChapterState.set_flag("chapter_1_boss_defeated", true)
	_spawn_rewards()

func _set_door_locked(locked: bool) -> void:
	if exit_door == null:
		return
	var door_area = exit_door.get_node_or_null("Area2D")
	if door_area:
		door_area.monitoring = not locked
		door_area.monitorable = not locked
	var sprite = exit_door.get_node_or_null("Sprite")
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 0.6, 0.85) if locked else Color.WHITE

func _spawn_rewards() -> void:
	if rewards_spawned:
		return
	rewards_spawned = true
	var base_position := reward_spawn.global_position if reward_spawn else global_position
	for index in range(reward_scenes.size()):
		var scene := reward_scenes[index]
		if scene == null:
			continue
		var reward = scene.instantiate()
		reward.global_position = base_position + Vector2(index * 26, -18)
		get_tree().current_scene.add_child(reward)
