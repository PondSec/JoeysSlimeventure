extends Sprite2D

func _ready():
	if material is ShaderMaterial:
		material.set_shader_parameter("random_offset", randf() * 100.0)
