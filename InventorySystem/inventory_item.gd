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
@export_enum("none", "weapon", "armor", "relic", "charm", "star") var equip_slot: String = "none"
@export var rarity: String = "common"
@export var stack_size: int = 64
# Different legacy resources may intentionally represent the same currency.
# Leave this empty for the item's own name to remain its stack identity.
@export var stack_key: String = ""
# World drops can use a tightly cropped part of a supplied transparent canvas.
# This keeps externally authored pixel art at its intended in-game size without
# destructively rewriting the original asset.
@export var world_texture_region: Rect2 = Rect2()
@export_range(0.01, 2.0, 0.01) var world_scale: float = 1.0
# Pickup effects are intentionally separate from equipment modifiers: these
# items are consumed directly in the world and never occupy an inventory slot.
@export var pickup_heal: int = 0
@export var permanent_max_health_bonus: int = 0
@export var permanent_crit_chance_bonus: float = 0.0
@export_range(0.0, 0.8, 0.001) var damage_reduction_bonus: float = 0.0
@export_range(0.1, 1.0, 0.01) var glow_range_multiplier: float = 1.0
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


func get_stack_key() -> String:
	return stack_key if not stack_key.is_empty() else name


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
