extends CharacterBody2D

@onready var anim_player = $AnimationPlayer

func _process(delta: float) -> void:
	anim_player.play("walk")
