extends Area2D

@export var grass_shader : ShaderMaterial

func _on_Player_body_entered(body):
	if body.is_in_group("players"):
		grass_shader.set_shader_param("wave_speed", 2.0)  # Geschwindigkeit der Wellenbewegung erhöhen
		grass_shader.set_shader_param("wave_strength", 0.5)  # Stärke der Wellenbewegung anpassen

func _on_Player_body_exited(body):
	if body.is_in_group("players"):
		grass_shader.set_shader_param("wave_speed", 0.0)  # Wellenbewegung stoppen
		grass_shader.set_shader_param("wave_strength", 0.0)  # Keine Bewegung mehr
