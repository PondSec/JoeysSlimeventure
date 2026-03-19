class_name ChapterState
extends RefCounted

const CHECKPOINT_PATH := "user://chapter1_progress.cfg"
const TOAST_SCENE := preload("res://Scenes/MessageToast.tscn")

static func _load_config() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(CHECKPOINT_PATH)
	return config

static func _save_config(config: ConfigFile) -> void:
	config.save(CHECKPOINT_PATH)

static func _section_key(scene_path: String) -> String:
	return scene_path.replace("res://", "").replace("/", "_").replace(".", "_")

static func save_checkpoint(scene_path: String, marker_name: String) -> void:
	if scene_path.is_empty() or marker_name.is_empty():
		return
	var config := _load_config()
	config.set_value("checkpoints", _section_key(scene_path), marker_name)
	_save_config(config)

static func get_checkpoint(scene_path: String, fallback: String = "") -> String:
	if scene_path.is_empty():
		return fallback
	var config := _load_config()
	return str(config.get_value("checkpoints", _section_key(scene_path), fallback))

static func clear_checkpoint(scene_path: String = "") -> void:
	var config := _load_config()
	if scene_path.is_empty():
		config.erase_section("checkpoints")
	else:
		config.set_value("checkpoints", _section_key(scene_path), "")
	_save_config(config)

static func set_flag(flag_name: String, value: bool = true) -> void:
	var config := _load_config()
	config.set_value("flags", flag_name, value)
	_save_config(config)

static func get_flag(flag_name: String, default_value: bool = false) -> bool:
	var config := _load_config()
	return bool(config.get_value("flags", flag_name, default_value))

static func show_toast(tree: SceneTree, text: String, message_type: String = "info", duration: float = 3.0) -> void:
	if tree == null or text.is_empty():
		return
	var toast := TOAST_SCENE.instantiate()
	toast.set_message(text, message_type)
	toast.duration = duration
	var current_scene := tree.current_scene if tree.current_scene else tree.root
	current_scene.add_child(toast)
