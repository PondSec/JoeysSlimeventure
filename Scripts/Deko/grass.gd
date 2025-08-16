extends Area2D

@export_category("Grass Settings")
@export var pressure_strength := 0.6
@export var pressure_radius := 0.15
@export var texture_scale_correction := 1.0  # Adjust if your texture is scaled

@onready var shader_material: ShaderMaterial = $GrassTexture.material
var overlapping_bodies := []

func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _process(_delta):
	if overlapping_bodies.size() > 0:
		var closest_body = overlapping_bodies[0]
		var local_pos = to_local(closest_body.global_position)
		var tex_size = $GrassTexture.texture.get_size() * texture_scale_correction
		
		# Convert to UV space (0-1)
		var uv_pos = (local_pos / tex_size) + Vector2(0.5, 0.0)
		
		shader_material.set_shader_parameter("player_pressure", pressure_strength)
		shader_material.set_shader_parameter("pressure_position", uv_pos.x)
		shader_material.set_shader_parameter("pressure_width", pressure_radius)
	else:
		shader_material.set_shader_parameter("player_pressure", 0.0)

func _on_body_entered(body: Node2D):
	if body.is_in_group("players"):
		if not overlapping_bodies.has(body):
			overlapping_bodies.append(body)
		_process(0)  # Immediate update

func _on_body_exited(body: Node2D):
	if overlapping_bodies.has(body):
		overlapping_bodies.erase(body)
	if overlapping_bodies.is_empty():
		shader_material.set_shader_parameter("player_pressure", 0.0)
