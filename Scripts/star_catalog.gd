extends RefCounted

class_name StarCatalog

const LUMORA_TEXTURE := preload("res://Assets/Stars/Lumora-sheet.png")
const PYRION_TEXTURE := preload("res://Assets/Stars/Pyrion.png")
const VORTEX_TEXTURE := preload("res://Assets/Stars/Vortex-sheet.png")

const STAR_DEFS := {
	"lumora": {
		"display_name": "Lumora",
		"description": "Ein sanfter Sterngeist, der Joey heilt, staerkt und mit Licht begleitet.",
		"rarity": "legendary",
		"scene_path": "res://Scenes/Stars/lumora.tscn",
		"skill_name": "Luminous Grace",
		"skill_description": "Lumora heilt Joey regelmaessig, verteilt Licht-Buffs und waechst mit deinem Schaden mit.",
		"encounter_texture": LUMORA_TEXTURE,
		"encounter_hframes": 2,
		"encounter_vframes": 1,
		"encounter_frame": Vector2i(0, 0),
		"encounter_color": Color(0.78, 0.92, 1.0, 1.0),
	},
	"pyrion": {
		"display_name": "Pyrion",
		"description": "Ein feuriger Sterngeist fuer aggressive Runs, Combo-Druck und ein bruennendes Schutzschild.",
		"rarity": "legendary",
		"scene_path": "res://Scenes/Stars/Pyrion.tscn",
		"skill_name": "Inferno Pact",
		"skill_description": "Pyrion erhoeht Angriffstempo und Crit-Potenzial und kann einen Feuerschild aktivieren.",
		"encounter_texture": PYRION_TEXTURE,
		"encounter_hframes": 1,
		"encounter_vframes": 1,
		"encounter_frame": Vector2i(0, 0),
		"encounter_color": Color(1.0, 0.58, 0.3, 1.0),
	},
	"vortex": {
		"display_name": "Vortex",
		"description": "Ein kreisender Sterngeist, der Gegner verlangsamt, Joey stabilisiert und den Kampf kontrolliert.",
		"rarity": "legendary",
		"scene_path": "res://Scenes/Stars/Vortex.tscn",
		"skill_name": "Abyssal Spiral",
		"skill_description": "Vortex erzeugt eine Slow-Aura, heilt Joey passiv und staerkt defensive Buff-Loops.",
		"encounter_texture": VORTEX_TEXTURE,
		"encounter_hframes": 2,
		"encounter_vframes": 2,
		"encounter_frame": Vector2i(0, 0),
		"encounter_color": Color(0.62, 0.76, 1.0, 1.0),
	},
}


static func get_all_star_ids() -> Array[String]:
	var star_ids: Array[String] = []
	for star_id in STAR_DEFS.keys():
		star_ids.append(String(star_id))
	return star_ids


static func has_star(star_id: String) -> bool:
	return STAR_DEFS.has(star_id)


static func get_definition(star_id: String) -> Dictionary:
	if not STAR_DEFS.has(star_id):
		return {}
	return (STAR_DEFS[star_id] as Dictionary).duplicate(true)


static func get_scene_path(star_id: String) -> String:
	return String(get_definition(star_id).get("scene_path", ""))


static func get_scene(star_id: String) -> PackedScene:
	var scene_path := get_scene_path(star_id)
	return load(scene_path) as PackedScene if not scene_path.is_empty() else null


static func get_item(star_id: String) -> InvItem:
	if not STAR_DEFS.has(star_id):
		return null

	var definition := STAR_DEFS[star_id] as Dictionary
	var item := InvItem.new()
	item.name = star_id
	item.display_name = String(definition.get("display_name", star_id.capitalize()))
	item.description = String(definition.get("description", "Ein geheimnisvoller Sterngeist."))
	item.texture = _make_encounter_texture(star_id)
	item.item_type = "star"
	item.equip_slot = "star"
	item.rarity = String(definition.get("rarity", "legendary"))
	item.stack_size = 1
	item.skill_name = String(definition.get("skill_name", "Star Skill"))
	item.skill_description = String(definition.get("skill_description", "Dieser Stern besitzt eine einzigartige Begleiterfaehigkeit."))
	return item


static func _make_encounter_texture(star_id: String) -> Texture2D:
	var definition := STAR_DEFS[star_id] as Dictionary
	var source := definition.get("encounter_texture") as Texture2D
	if source == null:
		return null

	var hframes := int(definition.get("encounter_hframes", 1))
	var vframes := int(definition.get("encounter_vframes", 1))
	if hframes <= 1 and vframes <= 1:
		return source

	var frame := definition.get("encounter_frame", Vector2i.ZERO) as Vector2i
	var size := source.get_size()
	if size.x <= 0 or size.y <= 0:
		return source

	var region := Rect2(
		float(frame.x * (size.x / hframes)),
		float(frame.y * (size.y / vframes)),
		float(size.x / hframes),
		float(size.y / vframes)
	)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas
