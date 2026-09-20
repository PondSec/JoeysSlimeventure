extends SceneTree

# Fixed UUID/date inputs make the weekly-generation contract testable without
# reading or modifying a real player's local identity or progress save.

const ChapterProgressScript := preload("res://Scripts/Chapter/chapter_progress.gd")
const TEST_UUID := "qa-player-0dca372f"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progress := ChapterProgressScript.new()
	var monday_seed := progress.get_level_generation_seed_for_weekday(1, 1, 1, TEST_UUID)
	var next_monday_seed := progress.get_level_generation_seed_for_weekday(1, 1, 1, TEST_UUID)
	var tuesday_seed := progress.get_level_generation_seed_for_weekday(1, 1, 2, TEST_UUID)
	var valid := monday_seed == next_monday_seed and monday_seed != tuesday_seed
	var previous: Array = []
	for weekday: int in range(7):
		var sequence := progress.get_resonance_sequence_for_weekday(weekday, TEST_UUID)
		valid = valid and sequence.size() == 3 and sequence != previous
		previous = sequence
	var status := "PASS" if valid else "FAIL"
	print("DAILY_GENERATION monday=%d tuesday=%d status=%s" % [monday_seed, tuesday_seed, status])
	quit(0 if valid else 1)
