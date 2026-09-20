class_name LootDropper
extends RefCounted

## Rolls every entry independently. A monster can therefore drop several
## rewards at once, one reward, or none at all.

const ItemRegistry := preload("res://Scripts/item_registry.gd")


static func spawn_independent_drops(source: Node2D, definitions: Array[Dictionary]) -> void:
	if source == null or not is_instance_valid(source):
		return
	var parent := source.get_parent()
	if parent == null:
		return

	for definition: Dictionary in definitions:
		var chance := clampf(float(definition.get("chance", 0.0)), 0.0, 1.0)
		if randf() > chance:
			continue
		var item := ItemRegistry.get_item(str(definition.get("item", "")))
		if item == null:
			continue
		var minimum := maxi(1, int(definition.get("min_count", 1)))
		var maximum := maxi(minimum, int(definition.get("max_count", minimum)))
		for index: int in range(randi_range(minimum, maximum)):
			_spawn_pickup(parent, source.global_position, item, index)


static func _spawn_pickup(parent: Node, source_position: Vector2, item: InvItem, index: int) -> void:
	var pickup := ItemRegistry.create_pickup_for_item(item)
	if pickup == null:
		return
	var world_position := source_position + Vector2(randf_range(-9.0, 9.0), -4.0 * index)
	if parent is Node2D:
		pickup.position = (parent as Node2D).to_local(world_position)
	else:
		pickup.position = world_position
	# Death often originates from an Area2D body_entered signal.  Adding a
	# RigidBody there mutates the physics space while it is being queried and
	# caused the visible hitch/error during combat.  Queue both tree insertion
	# and the launch for the next safe frame, preserving the exact drop motion.
	parent.call_deferred("add_child", pickup)
	pickup.call_deferred("apply_impulse", Vector2(randf_range(-54.0, 54.0), randf_range(-142.0, -86.0)))
	pickup.call_deferred("apply_torque_impulse", randf_range(-12.0, 12.0))
