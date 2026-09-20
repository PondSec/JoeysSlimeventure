extends Node

const ChapterContent := preload("res://Scripts/Chapter/chapter_content.gd")

signal chapter_unlocked(chapter_index: int)
signal chapter_completed(chapter_index: int)

const SAVE_PATH := "user://saves/chapter_progress.json"
const PLAYER_ID_PATH := "user://saves/player_id.txt"
const HUB_SCENE := "res://Scenes/Game.tscn"
const CHAPTER_LEVEL_SCENE := "res://Scenes/Chapter/chapter_level.tscn"
const CHAPTER_TWO_PREVIEW_SCENE := "res://Scenes/Chapter/chapter_two_preview.tscn"
const RESONANCE_PERMUTATIONS := [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
# Godot weekdays run Sunday (0) through Saturday (6). Six permutations cannot
# cover seven days uniquely, so Saturday reuses Tuesday's pattern; no adjacent
# days share a pattern, and every weekday repeats exactly the following week.
const WEEKDAY_PATTERN_OFFSETS := [0, 1, 2, 3, 4, 5, 2]

var unlocked_chapters: int = 1
var completed_chapters: Array[int] = []
var active_chapter: int = 0
var active_level_index: int = 0
var chapter_progress: Dictionary = {}
var quest_progress: Dictionary = {}
var seen_flags: Array[String] = []
var chapter_rewards: Dictionary = {}
var runtime_player_state: Dictionary = {}
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

	var parsed: Variant = SaveService.read_json(SAVE_PATH, null)
	if parsed is not Dictionary:
		save_progress()
		return

	var data: Dictionary = parsed
	unlocked_chapters = maxi(1, int(data.get("unlocked_chapters", 1)))
	completed_chapters = _variant_to_int_array(data.get("completed_chapters", []))
	active_chapter = int(data.get("active_chapter", 0))
	active_level_index = int(data.get("active_level_index", 0))
	chapter_progress = _variant_to_progress_map(data.get("chapter_progress", {}))
	quest_progress = _variant_to_dictionary(data.get("quest_progress", {}))
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
		"quest_progress": quest_progress,
		"seen_flags": seen_flags,
		"chapter_rewards": chapter_rewards,
		"pending_hub_banner": pending_hub_banner,
		"pending_hub_toast": pending_hub_toast
	}

	if not SaveService.write_json(SAVE_PATH, payload):
		push_warning("Kapitelstand konnte nicht gespeichert werden.")


func reset_progress() -> void:
	_set_defaults()
	save_progress()
	_sync_resume_scene(HUB_SCENE)


func get_resume_scene_path() -> String:
	return _get_resume_scene_path()


func preserve_chapter_resume() -> void:
	# A chapter resume deliberately stores only the active level index. The
	# weekly seed may change while the player is away, so world coordinates and
	# generated collision positions must never be restored across sessions.
	if active_chapter > 0:
		save_progress()
		_sync_resume_scene(_get_chapter_scene_path(active_chapter))


func resume_from_main_menu() -> void:
	# If a chapter was active, re-enter that same level at its normal spawn.
	# If the player last came from the Overworld, active_chapter is zero and the
	# hub remains the natural resume destination.
	transition_to(_get_resume_scene_path())


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
	var chapter_scene := _get_chapter_scene_path(chapter_index)
	_sync_resume_scene(chapter_scene)
	transition_to(chapter_scene)
	return true


func get_active_level_data() -> Dictionary:
	if active_chapter <= 0:
		return {}
	return ChapterContent.get_level_data(active_chapter, active_level_index)


func get_active_level_generation_seed() -> int:
	if active_chapter <= 0:
		return 0
	return get_level_generation_seed_for_weekday(active_chapter, active_level_index, _weekday(), _player_uuid())


func get_active_resonance_sequence() -> Array:
	return get_resonance_sequence_for_weekday(_weekday(), _player_uuid())


func get_level_generation_seed_for_weekday(chapter_index: int, level_index: int, weekday: int, player_uuid: String) -> int:
	var safe_weekday := clampi(weekday, 0, 6)
	return _stable_seed("%s|chapter:%d|level:%d|weekday:%d|layout-v1" % [player_uuid, chapter_index, level_index, safe_weekday])


func get_resonance_sequence_for_weekday(weekday: int, player_uuid: String) -> Array:
	var player_offset := posmod(_stable_seed("%s|resonance-order" % player_uuid), RESONANCE_PERMUTATIONS.size())
	var weekday_offset: int = WEEKDAY_PATTERN_OFFSETS[clampi(weekday, 0, 6)]
	var pattern_index := posmod(player_offset + weekday_offset, RESONANCE_PERMUTATIONS.size())
	return (RESONANCE_PERMUTATIONS[pattern_index] as Array).duplicate()


func complete_active_level() -> void:
	if active_chapter <= 0:
		return

	var completed_marker: String = "chapter%d_level_%d" % [active_chapter, active_level_index + 1]
	clear_level_quest_state(active_chapter, active_level_index)
	register_completion_marker(completed_marker)

	var total_levels: int = ChapterContent.get_level_count(active_chapter)
	var next_level_index: int = active_level_index + 1
	if next_level_index >= total_levels:
		_complete_active_chapter()
		return

	chapter_progress[str(active_chapter)] = next_level_index
	active_level_index = next_level_index
	save_progress()
	var chapter_scene := _get_chapter_scene_path(active_chapter)
	_sync_resume_scene(chapter_scene)
	transition_to(chapter_scene)


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
	_capture_runtime_player_state()

	_sync_resume_scene(scene_path)
	var transition_scene: PackedScene = load("res://Scenes/transition.tscn") as PackedScene
	if transition_scene == null:
		get_tree().change_scene_to_file(scene_path)
		return

	var transition: CanvasLayer = transition_scene.instantiate() as CanvasLayer
	get_tree().root.add_child(transition)
	transition.call("play_transition", scene_path, skip_fade_in)


func _capture_runtime_player_state() -> void:
	var player := get_tree().get_first_node_in_group("players")
	if player != null and player.has_method("get_portal_state"):
		runtime_player_state = player.call("get_portal_state") as Dictionary


func consume_runtime_player_state() -> Dictionary:
	var state := runtime_player_state.duplicate(true)
	runtime_player_state.clear()
	return state


func register_completion_marker(marker: String) -> void:
	if marker.is_empty():
		return

	var completed_levels: Array[String] = []
	var completed_levels_path := SaveService.path_for("completed_levels")
	if FileAccess.file_exists(completed_levels_path):
		var file: FileAccess = FileAccess.open(completed_levels_path, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			completed_levels = _variant_to_string_array(parsed)

	if not completed_levels.has(marker):
		completed_levels.append(marker)

	SaveService.write_json(completed_levels_path, completed_levels)


func has_reward(reward_key: String) -> bool:
	return bool(chapter_rewards.get(reward_key, false))


func get_level_quest_state(chapter_index: int, level_index: int) -> Dictionary:
	return (quest_progress.get(_daily_level_key(chapter_index, level_index), {}) as Dictionary).duplicate(true)


func set_level_quest_state(chapter_index: int, level_index: int, state: Dictionary) -> void:
	quest_progress[_daily_level_key(chapter_index, level_index)] = state.duplicate(true)
	save_progress()


func clear_level_quest_state(chapter_index: int, level_index: int) -> void:
	quest_progress.erase(_daily_level_key(chapter_index, level_index))


func award_reward(reward_key: String) -> void:
	if reward_key.is_empty() or has_reward(reward_key):
		return
	chapter_rewards[reward_key] = true
	save_progress()


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
		return _get_chapter_scene_path(active_chapter)
	return HUB_SCENE


func _get_chapter_scene_path(chapter_index: int) -> String:
	return CHAPTER_TWO_PREVIEW_SCENE if chapter_index == 2 else CHAPTER_LEVEL_SCENE


func _sync_resume_scene(scene_path: String) -> void:
	var level_resource := LevelResource.new()
	level_resource.unlocked_level = scene_path
	var save_error: int = SaveService.save_resource(SaveService.path_for("resume"), level_resource)
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
	quest_progress.clear()
	seen_flags.clear()
	chapter_rewards.clear()
	pending_hub_banner = ""
	pending_hub_toast = ""


func _daily_level_key(chapter_index: int, level_index: int) -> String:
	return "%d:%d:weekday:%d" % [chapter_index, level_index, _weekday()]


func _weekday() -> int:
	return clampi(int(Time.get_datetime_dict_from_system().get("weekday", 0)), 0, 6)


func _player_uuid() -> String:
	if FileAccess.file_exists(PLAYER_ID_PATH):
		var reader := FileAccess.open(PLAYER_ID_PATH, FileAccess.READ)
		if reader != null:
			var existing := reader.get_line().strip_edges()
			if not existing.is_empty():
				return existing
	var uuid_rng := RandomNumberGenerator.new()
	uuid_rng.seed = Time.get_ticks_usec() ^ int(Time.get_unix_time_from_system())
	var generated := "%08x-%08x-%08x-%08x" % [uuid_rng.randi(), uuid_rng.randi(), uuid_rng.randi(), uuid_rng.randi()]
	SaveService.write_text(PLAYER_ID_PATH, generated + "\n")
	return generated


func _stable_seed(value: String) -> int:
	var result := 146959810
	for byte: int in value.to_utf8_buffer():
		result = posmod(result * 16777619 + byte, 2147483647)
	return maxi(1, result)


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
