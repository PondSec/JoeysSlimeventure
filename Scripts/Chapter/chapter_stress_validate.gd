extends SceneTree

const ChapterContent := preload("res://Scripts/Chapter/chapter_content.gd")
const ChapterLayoutBuilder := preload("res://Scripts/Chapter/chapter_layout_builder.gd")

const BATCH_SIZES := [10, 100, 1000]
const BASE_SEED := 101
const SEED_STEP := 7919


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level_index := _requested_level_index()
	var level_data := ChapterContent.get_level_data(1, level_index)
	var level_size := level_data.get("size", Vector2i(100, 42)) as Vector2i
	var report: Dictionary = {"level": level_data.get("title", ""), "level_index": level_index, "batches": []}
	for sample_count: int in _requested_batch_sizes():
		var batch := _validate_batch(level_data, level_size, sample_count)
		report["batches"].append(batch)
		print("STRESS seeds=%d accepted=%d rejected=%d hard_failures=%d quest_targets=%d quest_unreachable=%d quest_sequence_failures=%d avg_ms=%.2f p95_ms=%.2f p99_ms=%.2f max_ms=%.2f attempts_avg=%.2f attempts_max=%d quality_avg=%.2f quality_min=%.2f" % [sample_count, int(batch.accepted), int(batch.rejected), int(batch.hard_failures), int(batch.quest_targets), int(batch.unreachable_quest_targets), int(batch.quest_sequence_failures), float(batch.average_ms), float(batch.p95_ms), float(batch.p99_ms), float(batch.max_ms), float(batch.average_attempts), int(batch.max_attempts), float(batch.average_quality), float(batch.minimum_quality)])
	var file := FileAccess.open("user://chapter_generation_stress_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	quit()


func _requested_batch_sizes() -> Array[int]:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--samples="):
			var requested := int(argument.trim_prefix("--samples="))
			if requested > 0 and requested <= 1000:
				return [requested]
			push_error("STRESS_FAIL --samples must be between 1 and 1000.")
			return []
	return BATCH_SIZES


func _requested_level_index() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			return clampi(int(argument.trim_prefix("--level=")), 0, ChapterContent.get_level_count(1) - 1)
	return 0


func _requested_base_seed() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return int(argument.trim_prefix("--seed="))
	return BASE_SEED


func _validate_batch(level_data: Dictionary, level_size: Vector2i, sample_count: int) -> Dictionary:
	var timings: Array[float] = []
	var attempts: Array[int] = []
	var qualities: Array[float] = []
	var accepted := 0
	var rejected := 0
	var hard_failures := 0
	var failures: Dictionary = {}
	var quest_targets := 0
	var unreachable_quest_targets := 0
	var quest_sequence_failures := 0
	for index: int in sample_count:
		var seed := _requested_base_seed() + index * SEED_STEP
		var started_usec := Time.get_ticks_usec()
		var result := ChapterLayoutBuilder.build_level_layout(level_data, level_size, seed)
		var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
		timings.append(elapsed_ms)
		var validation: Dictionary = result.get("layout_validation", {}) as Dictionary
		attempts.append(int(validation.get("attempt_index", 0)) + 1)
		qualities.append(float(validation.get("quality_score", 0.0)))
		quest_targets += (result.get("quest_anchors", []) as Array).size()
		unreachable_quest_targets += int(validation.get("unreachable_quest_target_count", 0))
		quest_sequence_failures += int(not bool(validation.get("quest_sequence_valid", true)))
		if _is_accepted(validation):
			accepted += 1
		else:
			if OS.get_cmdline_user_args().has("--diagnose-generation"):
				print("GEN_RESULT path=%s invalid=%d rewards=%d rooms=%d quest_unreachable=%d quest_sequence=%s notes=%s" % [str(validation.get("path_valid", false)), int(validation.get("invalid_jump_count", 0)), int(validation.get("unreachable_reward_count", 0)), int(validation.get("unreachable_room_count", 0)), int(validation.get("unreachable_quest_target_count", 0)), str(validation.get("quest_sequence_valid", true)), str(validation.get("notes", PackedStringArray()))])
			rejected += 1
			var category := _failure_category(validation)
			failures[category] = int(failures.get(category, 0)) + 1
			if bool(validation.get("path_valid", false)):
				hard_failures += 1
	return {
		"sample_count": sample_count,
		"accepted": accepted,
		"rejected": rejected,
		"hard_failures": hard_failures,
		"quest_targets": quest_targets,
		"unreachable_quest_targets": unreachable_quest_targets,
		"quest_sequence_failures": quest_sequence_failures,
		"failure_categories": failures,
		"average_ms": _average(timings),
		"p50_ms": _percentile(timings, 0.50),
		"p95_ms": _percentile(timings, 0.95),
		"p99_ms": _percentile(timings, 0.99),
		"max_ms": _maximum(timings),
		"average_attempts": _average_int(attempts),
		"max_attempts": _maximum_int(attempts),
		"average_quality": _average(qualities),
		"minimum_quality": _minimum(qualities)
	}


func _is_accepted(validation: Dictionary) -> bool:
	return bool(validation.get("path_valid", false)) \
		and int(validation.get("invalid_jump_count", 0)) == 0 \
		and int(validation.get("unreachable_reward_count", 0)) == 0 \
		and int(validation.get("unreachable_room_count", 0)) == 0 \
		and int(validation.get("unreachable_quest_target_count", 0)) == 0 \
		and bool(validation.get("quest_sequence_valid", true))


func _failure_category(validation: Dictionary) -> String:
	if not bool(validation.get("path_valid", false)):
		return "path"
	if int(validation.get("invalid_jump_count", 0)) > 0:
		return "jump"
	if int(validation.get("unreachable_reward_count", 0)) > 0:
		return "reward"
	if int(validation.get("unreachable_quest_target_count", 0)) > 0:
		return "quest_target"
	if not bool(validation.get("quest_sequence_valid", true)):
		return "quest_sequence"
	return "room"


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value: float in values:
		total += value
	return total / values.size()


func _average_int(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0
	for value: int in values:
		total += value
	return float(total) / values.size()


func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(ceil((sorted.size() - 1) * fraction)), 0, sorted.size() - 1)]


func _maximum(values: Array[float]) -> float:
	var value := 0.0
	for entry: float in values:
		value = maxf(value, entry)
	return value


func _minimum(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var value := values[0]
	for entry: float in values:
		value = minf(value, entry)
	return value


func _maximum_int(values: Array[int]) -> int:
	var value := 0
	for entry: int in values:
		value = maxi(value, entry)
	return value
