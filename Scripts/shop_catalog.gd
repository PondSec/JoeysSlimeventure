extends RefCounted

class_name ShopCatalog

const ITEM_RESOURCE_DIR := "res://InventorySystem/items/"
const ItemRegistry := preload("res://Scripts/item_registry.gd")
const SwordCatalog := preload("res://Scripts/sword_catalog.gd")

const ITEM_META := {
	"stone": {
		"display_name": "Stone Chunk",
		"description": "Verlaesslicher Wurfbrocken fuer guenstige Versorgung im Hub.",
		"rarity": "common",
		"legendary": false,
	},
	"bat_claw": {
		"display_name": "Bat Claw",
		"description": "Leichter Jagd-Drop fuer Wurf- und Material-Builds.",
		"rarity": "common",
		"legendary": false,
	},
	"silver_nugget": {
		"display_name": "Silver Nugget",
		"description": "Poliertes Metall fuer staerkere Deals. Legacy-Iron zaehlt ebenfalls als Silber.",
		"rarity": "uncommon",
		"legendary": false,
	},
	"iron_nugget": {
		"display_name": "Iron Nugget",
		"description": "Aelteres Metall aus bestehenden Saves. Im Shop wird es als Silber anerkannt.",
		"rarity": "uncommon",
		"legendary": false,
	},
	"gold_nugget": {
		"display_name": "Gold Nugget",
		"description": "Seltener Kern fuer Premium-Kaeufe im Hub.",
		"rarity": "rare",
		"legendary": false,
	},
	"golem_heart": {
		"display_name": "Golem Heart",
		"description": "Legendres Relikt mit massivem Vitalitaetsbonus.",
		"rarity": "legendary",
		"legendary": true,
	},
	"bat_artefact": {
		"display_name": "Bat Artefact",
		"description": "Legendres Artefakt fuer aggressive Crit- und Schadens-Builds.",
		"rarity": "legendary",
		"legendary": true,
	},
	"copper_nugget": {
		"display_name": "Copper Nugget",
		"description": "Hauefige Grundwaehrung fuer kleine Einkaeufe.",
		"rarity": "common",
		"legendary": false,
	},
}

const RARITY_PALETTES := {
	"common": {
		"accent": Color("7fd0ae"),
		"bg": Color("182126"),
		"border": Color("2f4b48"),
	},
	"uncommon": {
		"accent": Color("87c1ff"),
		"bg": Color("18212b"),
		"border": Color("31516d"),
	},
	"rare": {
		"accent": Color("f5c96b"),
		"bg": Color("241f18"),
		"border": Color("6b5230"),
	},
	"epic": {
		"accent": Color("e09cff"),
		"bg": Color("231628"),
		"border": Color("6b3e84"),
	},
	"legendary": {
		"accent": Color("ff8670"),
		"bg": Color("2a1818"),
		"border": Color("7c3b34"),
	},
}

const CURRENCIES := {
	"copper": {
		"display_name": "Kupfer",
		"accepted_item_names": ["copper_nugget"],
		"icon_item_name": "copper_nugget",
		"accent": Color("cf8a5a"),
	},
	"silver": {
		"display_name": "Silber",
		"accepted_item_names": ["silver_nugget", "iron_nugget"],
		"icon_item_name": "silver_nugget",
		"accent": Color("b8cee8"),
	},
	"gold": {
		"display_name": "Gold",
		"accepted_item_names": ["gold_nugget"],
		"icon_item_name": "gold_nugget",
		"accent": Color("f3d36c"),
	},
}

const PERMANENT_OFFERS := [
	{"item_name": "stone", "price": {"currency": "copper", "amount": 5}},
	{"item_name": "bat_claw", "price": {"currency": "copper", "amount": 8}},
	{"item_name": "silver_nugget", "price": {"currency": "copper", "amount": 15}},
]

const FEATURED_POOL := [
	{"item_name": "iron_nugget", "price": {"currency": "silver", "amount": 2}},
	{"item_name": "gold_nugget", "price": {"currency": "silver", "amount": 4}},
	{"item_name": "golem_heart", "price": {"currency": "gold", "amount": 2}},
	{"item_name": "bat_artefact", "price": {"currency": "gold", "amount": 3}},
]


static func get_item_resource(item_name: String) -> InvItem:
	return ItemRegistry.get_item(item_name)


static func get_item_texture(item_name: String) -> Texture2D:
	var item := get_item_resource(item_name)
	return item.texture if item else null


static func get_currency_config(currency: String) -> Dictionary:
	return (CURRENCIES.get(currency, CURRENCIES["copper"]) as Dictionary).duplicate(true)


static func get_currency_aliases(currency: String) -> Array[String]:
	var aliases: Array[String] = []
	var config := get_currency_config(currency)
	for item_name in config.get("accepted_item_names", []):
		aliases.append(String(item_name))
	return aliases


static func get_currency_display(currency: String) -> String:
	var config := get_currency_config(currency)
	return String(config.get("display_name", currency.capitalize()))


static func get_currency_icon(currency: String) -> Texture2D:
	var config := get_currency_config(currency)
	return get_item_texture(String(config.get("icon_item_name", "copper_nugget")))


static func get_rarity_palette(rarity: String) -> Dictionary:
	return (RARITY_PALETTES.get(rarity, RARITY_PALETTES["common"]) as Dictionary).duplicate(true)


static func get_permanent_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for offer in PERMANENT_OFFERS:
		offers.append(enrich_offer(offer, false))
	for offer in SwordCatalog.get_shop_offers():
		offers.append(enrich_offer(offer, false))
	return offers


static func get_fallback_featured_offers(day_key: String = "") -> Array[Dictionary]:
	var effective_day_key := day_key if not day_key.is_empty() else get_day_key_from_system()
	var scored_offers: Array[Dictionary] = []

	for offer in FEATURED_POOL:
		scored_offers.append({
			"score": hash("%s:%s" % [effective_day_key, offer["item_name"]]),
			"offer": offer,
		})

	scored_offers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["score"]) < int(b["score"])
	)

	var featured: Array[Dictionary] = []
	for index in range(min(3, scored_offers.size())):
		featured.append(enrich_offer(scored_offers[index]["offer"], true))
	return featured


static func enrich_offer(offer: Dictionary, is_featured: bool) -> Dictionary:
	var enriched := offer.duplicate(true)
	var item_name := String(enriched.get("item_name", ""))
	var meta: Dictionary = ITEM_META.get(item_name, {})
	var item := get_item_resource(item_name)
	var price: Dictionary = enriched.get("price", {"currency": "copper", "amount": 1})
	var currency := String(price.get("currency", "copper"))
	var item_display_name := item.get_display_name() if item else ""
	var item_description := item.description if item else ""
	var item_rarity := item.rarity if item else ""
	var is_legendary := item_rarity == "legendary"

	enriched["item_name"] = item_name
	enriched["displayName"] = enriched.get("displayName", meta.get("display_name", item_display_name if not item_display_name.is_empty() else _prettify_item_name(item_name)))
	enriched["description"] = enriched.get("description", meta.get("description", item_description if not item_description.is_empty() else "Handverlesener Hub-Handel fuer Joeys Abenteuer."))
	enriched["rarity"] = enriched.get("rarity", meta.get("rarity", item_rarity if not item_rarity.is_empty() else "common"))
	enriched["legendary"] = bool(enriched.get("legendary", meta.get("legendary", is_legendary)))
	enriched["featured"] = is_featured
	enriched["price"] = {
		"currency": currency,
		"amount": int(price.get("amount", 1)),
	}
	return enriched


static func get_day_key_from_system() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [datetime.year, datetime.month, datetime.day]


static func _prettify_item_name(item_name: String) -> String:
	return item_name.replace("_", " ").capitalize()
