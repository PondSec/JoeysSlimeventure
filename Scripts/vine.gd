extends Sprite2D

@export var leaf_scene: PackedScene
@export var spawn_interval_min: float = 1.5
@export var spawn_interval_max: float = 4.0
@export var max_leaves: int = 15  # Maximale Blätter gleichzeitig

var current_leaf_count: int = 0

func _ready():
	if material is ShaderMaterial:
		material.set_shader_parameter("random_offset", randf() * 100.0)
	start_spawn_timer()

func start_spawn_timer():
	# Warte zufällige Zeit
	var timer = get_tree().create_timer(randf_range(spawn_interval_min, spawn_interval_max))
	await timer.timeout
	
	# Spawne Blatt wenn unter Maximum
	if current_leaf_count < max_leaves:
		spawn_leaf()
	
	# Nächsten Timer starten
	start_spawn_timer()

func spawn_leaf():
	if leaf_scene:
		var new_leaf = leaf_scene.instantiate()
		
		# Position mit leichtem Zufall
		var spawn_offset = Vector2(randf_range(-8, 8), randf_range(-5, 5))
		new_leaf.global_position = global_position + spawn_offset
		
		# Leichten initialen Impuls geben für natürlichen Fall
		var initial_force = Vector2(randf_range(-10, 10), randf_range(-5, 0))
		new_leaf.apply_central_impulse(initial_force)
		
		# Zur Szene hinzufügen
		get_parent().call_deferred("add_child", new_leaf)
		
		# Blatt-Zähler erhöhen
		current_leaf_count += 1
		
		# Cleanup-Signal verbinden wenn vorhanden
		if new_leaf.has_signal("tree_exiting"):
			new_leaf.tree_exiting.connect(_on_leaf_removed)

func _on_leaf_removed():
	current_leaf_count = max(0, current_leaf_count - 1)
