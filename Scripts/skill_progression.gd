class_name SkillProgression
extends RefCounted

const SKILL_MILESTONES := {
	"glow": [],
	"wall_slide": ["chapter1_level_1"],
	"regeneration": ["chapter1_level_3"],
	"double_jump": ["chapter1_level_6"],
	"sticky_form": ["chapter1_complete"],
	"wall_run": ["chapter2_level_3"],
	"heal_burst": ["chapter2_level_5"],
	"dash": ["chapter2_complete"],
	"mana_shield": ["chapter3_level_4"],
	"teleport": ["chapter3_complete"],
	"slime_minion": ["chapter4_level_3"],
	"acid_spit": ["chapter4_complete"],
	"thorns": ["chapter5_level_4"],
	"slime_wings": ["chapter5_complete"],
	"gravity_slime": ["chapter6_complete"],
	"ult": ["chapter7_complete"],
	"phoenix_slime": ["chapter7_complete"]
}

const SKILL_TITLES := {
	"glow": "Glow",
	"wall_slide": "Wall Slide",
	"double_jump": "Double Jump",
	"wall_run": "Wall Run",
	"dash": "Dash",
	"teleport": "Teleport",
	"regeneration": "Regeneration",
	"mana_shield": "Mana Shield",
	"heal_burst": "Heal Burst",
	"thorns": "Thorns",
	"ult": "Ultimate",
	"phoenix_slime": "Phoenix Slime",
	"sticky_form": "Sticky Form",
	"slime_minion": "Slime Minion",
	"acid_spit": "Acid Spit",
	"gravity_slime": "Gravity Slime",
	"slime_wings": "Slime Wings"
}

const BASELINE_SKILLS := {
	"glow": true
}


static func apply_to_skills(skills: Dictionary) -> void:
	for skill_name_variant: Variant in skills.keys():
		var skill_name: String = str(skill_name_variant)
		if not (skills[skill_name] is Dictionary):
			continue
		if not SKILL_MILESTONES.has(skill_name):
			continue

		var skill_data: Dictionary = skills[skill_name]
		skill_data["required_levels"] = get_required_markers(skill_name)
		skills[skill_name] = skill_data


static func get_required_markers(skill_name: String) -> Array[String]:
	var markers: Array[String] = []
	if not SKILL_MILESTONES.has(skill_name):
		return markers

	for marker_variant: Variant in SKILL_MILESTONES[skill_name]:
		markers.append(str(marker_variant))
	return markers


static func get_skill_title(skill_name: String) -> String:
	return str(SKILL_TITLES.get(skill_name, skill_name.replace("_", " ").capitalize()))


static func is_baseline_skill(skill_name: String) -> bool:
	return bool(BASELINE_SKILLS.get(skill_name, false))


static func format_marker_list(markers: Array) -> PackedStringArray:
	var formatted := PackedStringArray()
	for marker_variant: Variant in markers:
		formatted.append(format_marker(str(marker_variant)))
	return formatted


static func format_marker(marker: String) -> String:
	if marker.is_empty():
		return ""

	if marker.ends_with("_complete"):
		var chapter_text: String = _format_chapter_prefix(marker.trim_suffix("_complete"))
		return "%s abgeschlossen" % chapter_text

	var parts: PackedStringArray = marker.split("_")
	if parts.size() == 3 and parts[0].begins_with("chapter") and parts[1] == "level":
		var chapter_index: int = _extract_chapter_index(parts[0])
		var level_index: int = int(parts[2])
		return "Kapitel %s • Level %d" % [_roman_or_number(chapter_index), level_index]

	return marker.replace("_", " ").capitalize()


static func _format_chapter_prefix(raw_value: String) -> String:
	if not raw_value.begins_with("chapter"):
		return raw_value.replace("_", " ").capitalize()
	var chapter_index: int = _extract_chapter_index(raw_value)
	return "Kapitel %s" % _roman_or_number(chapter_index)


static func _extract_chapter_index(raw_value: String) -> int:
	return int(raw_value.trim_prefix("chapter"))


static func _roman_or_number(value: int) -> String:
	match value:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
		5:
			return "V"
		6:
			return "VI"
		7:
			return "VII"
		8:
			return "VIII"
		_:
			return str(value)
