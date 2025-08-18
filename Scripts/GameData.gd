extends Resource
class_name GameData

# Player state
@export var position: Vector2
@export var is_facing_left: bool
@export var is_stunned: bool
@export var is_glowing: bool
@export var is_glowing_visible: bool
@export var current_health: int
@export var max_health: int
@export var attack_damage: int
@export var heal_rate: float
@export var fall_distance: float

# Security
@export var player_id: String
@export var data_hash: String

func get_exported_properties() -> Dictionary:
	var properties := {}
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE:
			properties[property.name] = get(property.name)
	return properties
