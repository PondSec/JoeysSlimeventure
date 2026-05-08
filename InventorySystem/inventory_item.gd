extends Resource

class_name InvItem

@export var name: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var texture: Texture2D
@export var health_bonus: float = 0 # in %
@export var damage_bonus: float = 0 # in %
@export var crit_chance_bonus: float = 0  # in % (z.B. 0.05 für +5%)
@export var crit_damage_bonus: float = 0  # in % (z.B. 0.1 für +10% Crit-Schaden)
@export var throw_damage: float = 0
@export var drop_chance: float = 0
@export_enum("resource", "weapon", "relic", "charm", "star") var item_type: String = "resource"
@export_enum("none", "weapon", "relic", "charm", "star") var equip_slot: String = "none"
@export var rarity: String = "common"
@export var stack_size: int = 64
@export var attack_power_bonus: int = 0
@export var attack_speed_bonus: float = 0.0
@export var attack_reach_bonus: float = 0.0
@export var knockback_bonus: float = 0.0
@export var move_speed_bonus: float = 0.0
@export var skill_id: String = ""
@export var skill_name: String = ""
@export_multiline var skill_description: String = ""


func get_display_name() -> String:
	return display_name if not display_name.is_empty() else name.replace("_", " ").capitalize()


func is_stackable() -> bool:
	return stack_size > 1


func can_equip_to(slot_name: String) -> bool:
	if equip_slot == "none":
		return false
	if equip_slot == slot_name:
		return true
	if equip_slot == "relic" and slot_name.begins_with("relic_"):
		return true
	if equip_slot == "star" and slot_name.begins_with("star_"):
		return true
	return false
