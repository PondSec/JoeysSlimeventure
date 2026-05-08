extends Node

const ChapterContent := preload("res://Scripts/Chapter/chapter_content.gd")

signal chapter_unlocked(chapter_index: int)
signal chapter_completed(chapter_index: int)

const SAVE_PATH := "user://chapter_progress.json"
const HUB_SCENE := "res://Scenes/Game.tscn"
const CHAPTER_LEVEL_SCENE := "res://Scenes/Chapter/chapter_level.tscn"

var unlocked_chapters: int = 1
var completed_chapters: Array[int] = []
var active_chapter: int = 0
var active_level_index: int = 0
var chapter_progress: Dictionary = {}
var seen_flags: Array[String] = []
var chapter_rewards: Dictionary = {}
var pending_hub_banner: String = ""
var pending_hub_toast: String = ""


func _ready() -> void:
	load_progress()
	_sync_resume_scene(_get_resume_scene_path())


func load_progress() -> void:
	_set_defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		save_progress()
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		save_progress()
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		save_progress()
		return

	var data: Dictionary = parsed
	unlocked_chapters = maxi(1, int(data.get("unlocked_chapters", 1)))
	completed_chapters = _variant_to_int_array(data.get("completed_chapters", []))
	active_chapter = int(data.get("active_chapter", 0))
	active_level_index = int(data.get("active_level_index", 0))
	chapter_progress = _variant_to_progress_map(data.get("chapter_progress", {}))
	seen_flags = _variant_to_string_array(data.get("seen_flags", []))
	chapter_rewards = _variant_to_dictionary(data.get("chapter_rewards", {}))
	pending_hub_banner = str(data.get("pending_hub_banner", ""))
	pending_hub_toast = str(data.get("pending_hub_toast", ""))

	if active_chapter > 0 and not ChapterContent.is_chapter_playable(active_chapter):
		active_chapter = 0
		active_level_index = 0

	if active_chapter > 0:
		var level_count: int = ChapterContent.get_level_count(active_chapter)
		if level_count <= 0:
			active_chapter = 0
			active_level_index = 0
		else:
			active_level_index = clampi(active_level_index, 0, level_count - 1)


func save_progress() -> void:
	var payload: Dictionary = {
		"unlocked_chapters": unlocked_chapters,
		"completed_chapters": completed_chapters,
		"active_chapter": active_chapter,
		"active_level_index": active_level_index,
		"chapter_progress": chapter_progress,
		"seen_flags": seen_flags,
		"chapter_rewards": chapter_rewards,
		"pending_hub_banner": pending_hub_banner,
		"pending_hub_toast": pending_hub_toast
	}

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Kapitelstand konnte nicht gespeichert werden.")
		return
	file.store_string(JSON.stringify(payload, "\t"))


func reset_progress() -> void:
	_set_defaults()
	save_progress()
	_sync_resume_scene(HUB_SCENE)


func get_resume_scene_path() -> String:
	return _get_resume_scene_path()


func enter_hub() -> void:
	active_chapter = 0
	active_level_index = 0
	save_progress()
	_sync_resume_scene(HUB_SCENE)


func get_unlocked_chapter_count() -> int:
	return unlocked_chapters


func is_chapter_unlocked(chapter_index: int) -> bool:
	return chapter_index > 0 and chapter_index <= unlocked_chapters


func is_chapter_completed(chapter_index: int) -> bool:
	return completed_chapters.has(chapter_index)


func can_start_chapter(chapter_index: int) -> bool:
	return is_chapter_unlocked(chapter_index) and ChapterContent.is_chapter_playable(chapter_index)


func start_chapter(chapter_index: int) -> bool:
	if not is_chapter_unlocked(chapter_index):
		return false

	if not ChapterContent.is_chapter_playable(chapter_index):
		pending_hub_toast = "%s ist noch nicht gebaut, aber die Tuere ist jetzt freigelegt." % ChapterContent.get_chapter_meta(chapter_index).get("short_title", "Dieses Kapitel")
		save_progress()
		return false

	active_chapter = chapter_index
	var default_index: int = _get_next_level_index_for_chapter(chapter_index)
	if is_chapter_completed(chapter_index):
		default_index = 0
	active_level_index = clampi(default_index, 0, maxi(ChapterContent.get_level_count(chapter_index) - 1, 0))
	save_progress()
	_sync_resume_scene(CHAPTER_LEVEL_SCENE)
	transition_to(CHAPTER_LEVEL_SCENE)
	return true


func get_active_level_data() -> Dictionary:
	if active_chapter <= 0:
		return {}
	return ChapterContent.get_level_data(active_chapter, active_level_index)


func complete_active_level() -> void:
	if active_chapter <= 0:
		return

	var completed_marker: String = "chapter%d_level_%d" % [active_chapter, active_level_index + 1]
	register_completion_marker(completed_marker)

	var total_levels: int = ChapterContent.get_level_count(active_chapter)
	var next_level_index: int = active_level_index + 1
	if next_level_index >= total_levels:
		_complete_active_chapter()
		return

	chapter_progress[str(active_chapter)] = next_level_index
	active_level_index = next_level_index
	save_progress()
	_sync_resume_scene(CHAPTER_LEVEL_SCENE)
	transition_to(CHAPTER_LEVEL_SCENE)


func mark_seen(flag: String) -> void:
	if flag.is_empty() or seen_flags.has(flag):
		return
	seen_flags.append(flag)
	save_progress()


func has_seen(flag: String) -> bool:
	return seen_flags.has(flag)


func consume_hub_banner() -> String:
	var banner: String = pending_hub_banner
	pending_hub_banner = ""
	save_progress()
	return banner


func consume_hub_toast() -> String:
	var toast: String = pending_hub_toast
	pending_hub_toast = ""
	save_progress()
	return toast


func transition_to(scene_path: String, skip_fade_in: bool = false) -> void:
	if scene_path.is_empty():
		return

	_sync_resume_scene(scene_path)
	var transition_scene: PackedScene = load("res://Scenes/transition.tscn") as PackedScene
	if transition_scene == null:
		get_tree().change_scene_to_file(scene_path)
		return

	var transition: CanvasLayer = transition_scene.instantiate() as CanvasLayer
	get_tree().root.add_child(transition)
	transition.call("play_transition", scene_path, skip_fade_in)


func register_completion_marker(marker: String) -> void:
	if marker.is_empty():
		return

	var completed_levels: Array[String] = []
	if FileAccess.file_exists("user://completed_levels.save"):
		var file: FileAccess = FileAccess.open("user://completed_levels.save", FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			completed_levels = _variant_to_string_array(parsed)

	if not completed_levels.has(marker):
		completed_levels.append(marker)

	var writer: FileAccess = FileAccess.open("user://completed_levels.save", FileAccess.WRITE)
	if writer:
		writer.store_string(JSON.stringify(completed_levels))


func has_reward(reward_key: String) -> bool:
	return bool(chapter_rewards.get(reward_key, false))


func _complete_active_chapter() -> void:
	var finished_chapter: int = active_chapter
	if not completed_chapters.has(finished_chapter):
		completed_chapters.append(finished_chapter)

	register_completion_marker("chapter%d_complete" % finished_chapter)

	var next_chapter: int = min(finished_chapter + 1, ChapterContent.get_chapter_count())
	var unlocked_now := false
	if next_chapter > unlocked_chapters:
		unlocked_chapters = next_chapter
		unlocked_now = true

	chapter_progress[str(finished_chapter)] = 0
	active_chapter = 0
	active_level_index = 0

	if finished_chapter == 1:
		chapter_rewards["chapter_1_split"] = true
		pending_hub_banner = "Kapitel I gemeistert"
		pending_hub_toast = "Die Tuere zu Kapitel II ist jetzt aktiv. Sticky Form ist nun im Skill Tree verfuegbar."
	else:
		pending_hub_banner = "Kapitel %d vollendet" % finished_chapter
		pending_hub_toast = "Ein neues Tor reagiert auf Joeys Essenz."

	save_progress()
	_sync_resume_scene(HUB_SCENE)
	chapter_completed.emit(finished_chapter)
	if unlocked_now:
		chapter_unlocked.emit(next_chapter)
	transition_to(HUB_SCENE)


func _get_resume_scene_path() -> String:
	if active_chapter > 0 and ChapterContent.is_chapter_playable(active_chapter):
		return CHAPTER_LEVEL_SCENE
	return HUB_SCENE


func _sync_resume_scene(scene_path: String) -> void:
	var level_resource := LevelResource.new()
	level_resource.unlocked_level = scene_path
	var save_error: int = ResourceSaver.save(level_resource, "user://current_level.res")
	if save_error != OK:
		push_warning("Konnte Resume-Szene nicht speichern: %s" % scene_path)


func _get_next_level_index_for_chapter(chapter_index: int) -> int:
	var raw_value: Variant = chapter_progress.get(str(chapter_index), 0)
	return int(raw_value)


func _set_defaults() -> void:
	unlocked_chapters = 1
	completed_chapters.clear()
	active_chapter = 0
	active_level_index = 0
	chapter_progress.clear()
	seen_flags.clear()
	chapter_rewards.clear()
	pending_hub_banner = ""
	pending_hub_toast = ""


func _variant_to_int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is not Array:
		return result

	var source: Array = value
	for entry: Variant in source:
		result.append(int(entry))
	return result


func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is not Array:
		return result

	var source: Array = value
	for entry: Variant in source:
		result.append(str(entry))
	return result


func _variant_to_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _variant_to_progress_map(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is not Dictionary:
		return result

	var source: Dictionary = value
	for key: Variant in source.keys():
		result[str(key)] = int(source[key])
	return result
