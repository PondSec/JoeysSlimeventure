class_name CraftingCatalog
extends RefCounted

const ItemRegistry := preload("res://Scripts/item_registry.gd")

## Recipes intentionally use the whole 3x3 pattern. Empty cells matter, which
## makes recipes readable and prevents accidental crafts from loose materials.
const RECIPES: Array[Dictionary] = [
	{
		"id": "irrlicht_chestplate",
		"name": "Irrlichtbrustplatte",
		"result": "irrlicht_chestplate",
		"pattern": [
			"iron_nugget", "irrlicht_carapace", "iron_nugget",
			"", "irrlicht_eye", "",
			"", "iron_nugget", ""
		]
	},
	{
		"id": "bat_artefact",
		"name": "Fledermausartefakt",
		"result": "bat_artefact",
		"pattern": [
			"bat_claw", "copper_nugget", "bat_claw",
			"", "gold_nugget", "",
			"", "", ""
		]
	},
	{
		"id": "golem_heart",
		"name": "Golemherz",
		"result": "golem_heart",
		"pattern": [
			"stone", "stone", "stone",
			"stone", "gold_nugget", "stone",
			"", "", ""
		]
	}
]


static func find_recipe(crafting_slots: Array[InvSlot]) -> Dictionary:
	if crafting_slots.size() != 9:
		return {}
	var contents: Array[String] = []
	for slot in crafting_slots:
		contents.append(slot.item.name if slot and slot.item else "")
	for recipe: Dictionary in RECIPES:
		if contents == recipe.get("pattern", []):
			return recipe.duplicate(true)
	return {}


static func get_result(recipe: Dictionary) -> InvItem:
	return ItemRegistry.get_item(str(recipe.get("result", "")))
