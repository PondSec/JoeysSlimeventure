extends RefCounted

class_name ItemRegistry

const ITEM_RESOURCE_DIR := "res://InventorySystem/items/"
const PICKUP_SCENE_PATH := "res://Scenes/Items/item_pickup_base.tscn"
const SwordCatalog := preload("res://Scripts/sword_catalog.gd")
const StarCatalog := preload("res://Scripts/star_catalog.gd")


static func get_item(item_name: String) -> InvItem:
	var resource_path := ITEM_RESOURCE_DIR + item_name + ".tres"
	if ResourceLoader.exists(resource_path):
		return load(resource_path) as InvItem
	if SwordCatalog.has_weapon(item_name):
		return SwordCatalog.get_item(item_name)
	if StarCatalog.has_star(item_name):
		return StarCatalog.get_item(item_name)
	return null


static func get_default_weapon() -> InvItem:
	return SwordCatalog.get_default_weapon()


static func create_pickup_for_item(item_or_name: Variant) -> RigidBody2D:
	var item: InvItem = item_or_name if item_or_name is InvItem else get_item(String(item_or_name))
	if item == null:
		return null

	var item_scene_path := "res://Scenes/Items/%s.tscn" % item.name
	var scene: PackedScene = null
	if ResourceLoader.exists(item_scene_path):
		scene = load(item_scene_path) as PackedScene
	else:
		scene = load(PICKUP_SCENE_PATH) as PackedScene

	if scene == null:
		return null

	var pickup := scene.instantiate() as RigidBody2D
	if pickup:
		pickup.name = item.name
		pickup.set("item", item)
	return pickup
