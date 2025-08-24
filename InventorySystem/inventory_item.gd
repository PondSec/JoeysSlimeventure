extends Resource

class_name InvItem

@export var name: String = ""
@export var texture: Texture2D
@export var health_bonus: float = 0 # in %
@export var damage_bonus: float = 0 # in %
@export var crit_chance_bonus: float = 0  # in % (z.B. 0.05 für +5%)
@export var crit_damage_bonus: float = 0  # in % (z.B. 0.1 für +10% Crit-Schaden)
