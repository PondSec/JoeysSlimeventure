extends Resource
class_name GameData

@export var position: Vector2
@export var is_facing_left: bool
@export var is_stunned: bool
@export var is_glowing: bool
@export var current_health: int
@export var max_health: int
@export var inventory: Inv   # ⚠️ Jetzt ein Resource-Typ, nicht Dictionary
@export var attack_damage: int
@export var heal_rate: float
@export var fall_distance: float
