extends Node2D

const LIGHT_TEXTURE := preload("res://Assets/Light/torch_light.png")

@export var particle_limit := 18

var source_position := Vector2.ZERO
var target_position := Vector2.ZERO
var particles: Array[Dictionary] = []
var spawn_accumulator := 0.0
var running := false


func configure(source: Vector2, target: Vector2) -> void:
	source_position = source
	target_position = target
	running = true


func _process(delta: float) -> void:
	if not running:
		return
	spawn_accumulator += delta
	while spawn_accumulator >= 0.10 and particles.size() < particle_limit:
		spawn_accumulator -= 0.10
		_spawn_particle()
	for index: int in range(particles.size() - 1, -1, -1):
		var data := particles[index]
		data.progress = float(data.progress) + delta * float(data.speed)
		if float(data.progress) >= 1.0:
			var node: Node2D = data.node as Node2D
			if is_instance_valid(node):
				node.queue_free()
			particles.remove_at(index)
			continue
		var node: Node2D = data.node as Node2D
		if is_instance_valid(node):
			node.global_position = _route(float(data.progress), float(data.arc))


func _spawn_particle() -> void:
	var particle := Node2D.new()
	particle.z_index = 3
	var dot := Polygon2D.new()
	var radius := randf_range(1.5, 3.0)
	dot.polygon = PackedVector2Array([Vector2(-radius, 0), Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius)])
	dot.color = Color(0.28, randf_range(0.72, 0.96), 1.0, randf_range(0.72, 0.96))
	particle.add_child(dot)
	var glow := PointLight2D.new()
	glow.texture = LIGHT_TEXTURE
	glow.color = Color(0.22, 0.78, 1.0, 1.0)
	glow.energy = 0.10
	glow.texture_scale = 0.18
	particle.add_child(glow)
	add_child(particle)
	particles.append({
		"node": particle,
		"progress": 0.0,
		"speed": randf_range(0.19, 0.35),
		"arc": randf_range(-58.0, -28.0)
	})


func _route(progress: float, arc: float) -> Vector2:
	var midpoint := source_position.lerp(target_position, 0.5) + Vector2(0.0, arc)
	var first := source_position.lerp(midpoint, progress)
	var second := midpoint.lerp(target_position, progress)
	return first.lerp(second, progress)


func _exit_tree() -> void:
	running = false
	for data: Dictionary in particles:
		var node: Node = data.get("node") as Node
		if is_instance_valid(node):
			node.queue_free()
	particles.clear()
