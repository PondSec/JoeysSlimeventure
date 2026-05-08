extends CanvasLayer

const ShopCatalog := preload("res://Scripts/shop_catalog.gd")
const SHOP_API_URL := "https://api.joeyslime.com/shop"
const FONT_PATH := "res://Assets/GUI/Font/PixelatedEleganceRegular-ovyAA.ttf"
const SHOP_SIGN_TEXTURE := preload("res://Assets/Shop/Large sized/shop.png")
const GUI_PANEL_TEXTURE := preload("res://Assets/GUI/Transfer.png")
const GUI_BUTTON_NORMAL_TEXTURE := preload("res://Assets/GUI/Back/button.png")
const GUI_BUTTON_HOVER_TEXTURE := preload("res://Assets/GUI/Back/hover.png")
const GUI_BUTTON_PRESSED_TEXTURE := preload("res://Assets/GUI/Back/pressed.png")

const UI_PANEL_BG := Color(0.07, 0.09, 0.1, 0.98)
const UI_PANEL_BG_ALT := Color(0.1, 0.12, 0.11, 0.98)
const UI_PANEL_BG_INSET := Color(0.05, 0.07, 0.06, 0.98)
const UI_BORDER := Color(0.14, 0.86, 0.56, 1.0)
const UI_BORDER_SOFT := Color(0.1, 0.36, 0.24, 1.0)
const UI_TEXT := Color(0.9, 0.98, 0.92, 1.0)
const UI_TEXT_SOFT := Color(0.66, 0.9, 0.73, 1.0)
const UI_TEXT_MUTED := Color(0.44, 0.6, 0.49, 1.0)
const UI_OUTLINE := Color(0.0, 0.0, 0.0, 0.96)
const UI_SUCCESS := Color(0.5, 0.98, 0.66, 1.0)
const UI_WARNING := Color(0.96, 0.85, 0.5, 1.0)
const UI_ERROR := Color(1.0, 0.58, 0.58, 1.0)

@export var player_path: NodePath
@export var inv: Inv

@onready var backdrop: ColorRect = $Backdrop
@onready var root_panel: PanelContainer = $Frame/RootPanel
@onready var content_scroll: ScrollContainer = $Frame/RootPanel/ContentMargin/ContentScroll
@onready var sign_texture: TextureRect = $Frame/RootPanel/ContentMargin/ContentScroll/Content/HeaderRow/TitleStack/SignTexture
@onready var title_label: Label = $Frame/RootPanel/ContentMargin/ContentScroll/Content/HeaderRow/TitleStack/TitleLabel
@onready var subtitle_label: Label = $Frame/RootPanel/ContentMargin/ContentScroll/Content/HeaderRow/TitleStack/SubtitleLabel
@onready var refresh_button: Button = $Frame/RootPanel/ContentMargin/ContentScroll/Content/HeaderRow/RefreshButton
@onready var close_button: Button = $Frame/RootPanel/ContentMargin/ContentScroll/Content/HeaderRow/CloseButton
@onready var status_label: Label = $Frame/RootPanel/ContentMargin/ContentScroll/Content/MetaRow/StatusLabel
@onready var reset_label: Label = $Frame/RootPanel/ContentMargin/ContentScroll/Content/MetaRow/ResetLabel
@onready var wallet_row: HBoxContainer = $Frame/RootPanel/ContentMargin/ContentScroll/Content/WalletSection/WalletRow
@onready var wallet_title: Label = $Frame/RootPanel/ContentMargin/ContentScroll/Content/WalletSection/WalletTitle
@onready var featured_title: Label = $Frame/RootPanel/ContentMargin/ContentScroll/Content/FeaturedSection/FeaturedTitle
@onready var featured_row: HBoxContainer = $Frame/RootPanel/ContentMargin/ContentScroll/Content/FeaturedSection/FeaturedRow
@onready var permanent_title: Label = $Frame/RootPanel/ContentMargin/ContentScroll/Content/PermanentSection/PermanentTitle
@onready var permanent_grid: GridContainer = $Frame/RootPanel/ContentMargin/ContentScroll/Content/PermanentSection/PermanentGrid
@onready var hint_label: Label = $Frame/RootPanel/ContentMargin/ContentScroll/Content/HintLabel
@onready var http_request: HTTPRequest = $HTTPRequest

var player: Node = null
var featured_offers: Array[Dictionary] = []
var permanent_offers: Array[Dictionary] = []
var next_refresh_unix: int = 0
var day_key := ""
var request_in_flight := false
var pause_state_before_open := false
var cached_font: FontFile = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("shop_ui")

	if inv == null:
		inv = preload("res://InventorySystem/playerinv.tres")

	if not player_path.is_empty():
		player = get_node_or_null(player_path)

	if inv and not inv.update.is_connected(_on_inventory_changed):
		inv.update.connect(_on_inventory_changed)

	if http_request and not http_request.request_completed.is_connected(_on_shop_request_completed):
		http_request.request_completed.connect(_on_shop_request_completed)

	_apply_styles()
	_refresh_wallet()
	_set_status("Naehere dich dem Wagen und druecke E.", UI_TEXT_SOFT)


func _process(_delta: float) -> void:
	if visible:
		reset_label.text = "Reset in %s" % _format_remaining_time()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("Pause") or event.is_action_pressed("inventory"):
		close_shop()
		get_viewport().set_input_as_handled()


func open_shop() -> void:
	if visible:
		return

	_close_player_overlays()
	pause_state_before_open = get_tree().paused
	if _can_pause_world():
		get_tree().paused = true

	visible = true
	if content_scroll:
		content_scroll.scroll_vertical = 0
	_refresh_wallet()
	_set_status("Hub-Haendler synchronisiert Tagesangebote...", UI_TEXT_SOFT)
	_request_shop_data()


func close_shop() -> void:
	if not visible:
		return

	visible = false
	if _can_pause_world():
		get_tree().paused = pause_state_before_open


func _on_inventory_changed() -> void:
	_refresh_wallet()
	if visible:
		_rebuild_offer_rows()


func _request_shop_data() -> void:
	if request_in_flight:
		return

	request_in_flight = true
	var error := http_request.request(SHOP_API_URL)
	if error != OK:
		request_in_flight = false
		_use_fallback_catalog("API derzeit nicht erreichbar")


func _on_shop_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	request_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_use_fallback_catalog("Tagesangebote werden lokal angezeigt")
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not (parsed is Dictionary):
		_use_fallback_catalog("Shop-Antwort ungueltig, lokaler Fallback aktiv")
		return

	var response: Dictionary = parsed
	day_key = String(response.get("dayKey", ShopCatalog.get_day_key_from_system()))
	featured_offers.clear()
	permanent_offers.clear()

	for offer in response.get("featuredItems", []):
		featured_offers.append(ShopCatalog.enrich_offer(offer, true))
	for offer in response.get("permanentItems", []):
		permanent_offers.append(ShopCatalog.enrich_offer(offer, false))

	if featured_offers.size() != 3:
		featured_offers = ShopCatalog.get_fallback_featured_offers(day_key)

	_merge_local_permanent_offers()

	next_refresh_unix = _parse_datetime_to_unix(String(response.get("nextRefreshAt", "")))
	_set_status("Tagesangebote von api.joeyslime.com geladen.", UI_SUCCESS)
	_rebuild_offer_rows()


func _use_fallback_catalog(message: String) -> void:
	day_key = ShopCatalog.get_day_key_from_system()
	featured_offers = ShopCatalog.get_fallback_featured_offers(day_key)
	permanent_offers = ShopCatalog.get_permanent_offers()
	next_refresh_unix = _next_midnight_unix()
	_set_status("%s. Lokaler Hub-Katalog aktiv." % message, UI_WARNING)
	_rebuild_offer_rows()


func _merge_local_permanent_offers() -> void:
	var known_items := {}
	for offer in permanent_offers:
		known_items[String(offer.get("item_name", ""))] = true

	for local_offer in ShopCatalog.get_permanent_offers():
		var item_name := String(local_offer.get("item_name", ""))
		if known_items.has(item_name):
			continue
		permanent_offers.append(local_offer)
		known_items[item_name] = true


func _rebuild_offer_rows() -> void:
	_clear_container(featured_row)
	_clear_container(permanent_grid)

	for offer in featured_offers:
		featured_row.add_child(_create_offer_card(offer))

	for offer in permanent_offers:
		permanent_grid.add_child(_create_offer_card(offer))


func _refresh_wallet() -> void:
	_clear_container(wallet_row)
	if inv == null:
		return

	for currency in ["copper", "silver", "gold"]:
		wallet_row.add_child(_create_wallet_chip(currency))


func _create_wallet_chip(currency: String) -> Control:
	var config: Dictionary = ShopCatalog.get_currency_config(currency)
	var total_owned := inv.get_total_amount(ShopCatalog.get_currency_aliases(currency))
	var item_name := String(config.get("icon_item_name", "copper_nugget"))
	var item_texture: Texture2D = ShopCatalog.get_item_texture(item_name)
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(128.0, 44.0)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", _make_flat_style(UI_PANEL_BG_ALT, Color(config.get("accent", UI_BORDER)), 2, 0))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	chip.add_child(row)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(32.0, 32.0)
	icon_panel.add_theme_stylebox_override("panel", _make_flat_style(UI_PANEL_BG_INSET, Color(config.get("accent", UI_BORDER)).lightened(0.1), 1, 0))
	row.add_child(icon_panel)

	var icon := TextureRect.new()
	icon.texture = item_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(20.0, 20.0)
	icon_panel.add_child(icon)

	var label_column := VBoxContainer.new()
	label_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_column)

	var title := Label.new()
	title.text = ShopCatalog.get_currency_display(currency)
	_style_label(title, 11, UI_TEXT_SOFT, 2)
	label_column.add_child(title)

	var amount := Label.new()
	amount.text = "Im Beutel: %d" % total_owned
	_style_label(amount, 14, Color(config.get("accent", UI_BORDER)).lightened(0.08), 3)
	label_column.add_child(amount)

	return chip


func _create_offer_card(offer: Dictionary) -> Control:
	var item_name := String(offer.get("item_name", ""))
	var item: InvItem = ShopCatalog.get_item_resource(item_name)
	var palette: Dictionary = ShopCatalog.get_rarity_palette(String(offer.get("rarity", "common")))
	var price: Dictionary = offer.get("price", {})
	var currency := String(price.get("currency", "copper"))
	var price_amount := int(price.get("amount", 1))
	var can_afford := inv != null and inv.get_total_amount(ShopCatalog.get_currency_aliases(currency)) >= price_amount
	var can_store := inv != null and item != null and inv.can_insert(item)

	var card := PanelContainer.new()
	var is_featured := bool(offer.get("featured", false))
	card.custom_minimum_size = Vector2(188.0, 238.0 if is_featured else 214.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL if is_featured else Control.SIZE_FILL
	var palette_accent := Color(palette.get("accent", UI_BORDER))
	var palette_border := Color(palette.get("border", UI_BORDER_SOFT)).lerp(UI_BORDER_SOFT, 0.25)
	var card_bg := Color(palette.get("bg", UI_PANEL_BG_ALT)).darkened(0.22)
	card.add_theme_stylebox_override("panel", _make_flat_style(card_bg, palette_border, 2, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 6)
	content.add_child(badge_row)

	var rarity_badge := Label.new()
	rarity_badge.text = String(offer.get("rarity", "common")).to_upper()
	_style_label(rarity_badge, 10, palette_accent, 2)
	badge_row.add_child(rarity_badge)

	if bool(offer.get("featured", false)):
		var featured_badge := Label.new()
		featured_badge.text = "HEUTE"
		_style_label(featured_badge, 10, UI_WARNING, 2)
		badge_row.add_child(featured_badge)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(0.0, 72.0)
	icon_frame.add_theme_stylebox_override("panel", _make_flat_style(UI_PANEL_BG_INSET, palette_accent.darkened(0.15), 1, 0))
	content.add_child(icon_frame)

	var icon := TextureRect.new()
	icon.texture = item.texture if item else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(52.0, 52.0)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_frame.add_child(icon)

	var name_label := Label.new()
	name_label.text = String(offer.get("displayName", item_name))
	_style_label(name_label, 15, UI_TEXT, 3)
	content.add_child(name_label)

	var description_label := Label.new()
	description_label.text = String(offer.get("description", ""))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(description_label, 11, UI_TEXT_SOFT, 2)
	description_label.custom_minimum_size = Vector2(0.0, 44.0)
	content.add_child(description_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	content.add_child(footer)

	var price_chip := PanelContainer.new()
	price_chip.add_theme_stylebox_override("panel", _make_flat_style(UI_PANEL_BG_ALT, Color(ShopCatalog.get_currency_config(currency).get("accent", UI_BORDER)), 1, 0))
	footer.add_child(price_chip)

	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 8)
	price_chip.add_child(price_row)

	var currency_icon := TextureRect.new()
	currency_icon.texture = ShopCatalog.get_currency_icon(currency)
	currency_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	currency_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	currency_icon.custom_minimum_size = Vector2(22.0, 22.0)
	price_row.add_child(currency_icon)

	var price_label := Label.new()
	price_label.text = "Gratis" if price_amount <= 0 else "%d %s" % [price_amount, ShopCatalog.get_currency_display(currency)]
	_style_label(price_label, 12, UI_TEXT, 2)
	price_row.add_child(price_label)

	var owned_label := Label.new()
	owned_label.text = "Testangebot fuer Ausruestung." if price_amount <= 0 else ("Vorhanden: %d" % inv.get_total_amount(ShopCatalog.get_currency_aliases(currency)) if inv else "Vorhanden: 0")
	_style_label(owned_label, 10, UI_TEXT_MUTED, 2)
	footer.add_child(owned_label)

	var buy_button := Button.new()
	buy_button.text = "Kaufen"
	buy_button.disabled = not can_afford or not can_store or item == null
	buy_button.custom_minimum_size = Vector2(0.0, 32.0)
	buy_button.focus_mode = Control.FOCUS_NONE
	_style_pixel_button(buy_button, palette_accent.lightened(0.12), palette_accent.lightened(0.2), UI_PANEL_BG_INSET)
	buy_button.add_theme_stylebox_override("disabled", _make_flat_style(UI_PANEL_BG_INSET, UI_BORDER_SOFT.darkened(0.25), 2, 0))
	buy_button.pressed.connect(_purchase_offer.bind(offer))
	footer.add_child(buy_button)

	if not can_afford or not can_store:
		var reason_label := Label.new()
		reason_label.text = "Nicht genug Waehrung." if not can_afford else "Inventar voll."
		_style_label(reason_label, 10, UI_ERROR, 2)
		footer.add_child(reason_label)

	return card


func _purchase_offer(offer: Dictionary) -> void:
	if inv == null:
		return

	var item_name := String(offer.get("item_name", ""))
	var item: InvItem = ShopCatalog.get_item_resource(item_name)
	if item == null:
		_set_status("Item %s fehlt lokal im Projekt." % item_name, UI_ERROR)
		return

	if not inv.can_insert(item):
		_notify_player("Inventar voll", "error", item.texture)
		return

	var price: Dictionary = offer.get("price", {})
	var currency := String(price.get("currency", "copper"))
	var amount := int(price.get("amount", 1))
	var aliases: Array[String] = ShopCatalog.get_currency_aliases(currency)

	if amount > 0 and inv.get_total_amount(aliases) < amount:
		_notify_player("Nicht genug %s" % ShopCatalog.get_currency_display(currency), "error", ShopCatalog.get_currency_icon(currency))
		return

	if amount > 0 and not inv.remove_amount(aliases, amount):
		_notify_player("Waehrung konnte nicht abgebucht werden", "error", ShopCatalog.get_currency_icon(currency))
		return

	if not inv.Insert(item):
		if amount > 0 and not aliases.is_empty():
			var refund_item: InvItem = ShopCatalog.get_item_resource(aliases[0])
			for _index in range(amount):
				if refund_item:
					inv.Insert(refund_item)
		_notify_player("Kauf abgebrochen, Inventar ist jetzt belegt.", "error", item.texture)
		return

	if player and player.has_method("_show_loot_feedback"):
		player.call("_show_loot_feedback", item)
	if player and player.has_method("_show_feedback_banner"):
		player.call("_show_feedback_banner", "KAUF ABGESCHLOSSEN", Color(0.95, 0.84, 0.44, 1.0), 0.42)

	_set_status("%s gekauft fuer %d %s." % [
		String(offer.get("displayName", item_name)),
		amount,
		ShopCatalog.get_currency_display(currency),
	], UI_SUCCESS)
	_notify_player("Hub-Kauf: %s" % String(offer.get("displayName", item_name)), "reward", item.texture)
	_refresh_wallet()
	_rebuild_offer_rows()


func _notify_player(message: String, toast_type: String, icon_texture: Texture2D) -> void:
	if player and player.has_method("_show_feedback_toast"):
		player.call("_show_feedback_toast", message, toast_type, icon_texture)
	else:
		_set_status(message, UI_WARNING)


func _close_player_overlays() -> void:
	if player == null:
		return

	var inv_ui := player.get_node_or_null("CanvasLayer/InvUI")
	if inv_ui and inv_ui.has_method("close"):
		inv_ui.call("close")


func _can_pause_world() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	return gm == null or not gm.is_multiplayer


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _style_label(label: Label, font_size: int, color: Color, outline_size: int = 4) -> void:
	label.add_theme_font_override("font", _load_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", UI_OUTLINE)
	label.add_theme_constant_override("outline_size", outline_size)


func _style_pixel_button(button: Button, font_color: Color, hover_font_color: Color, pressed_font_color: Color) -> void:
	button.add_theme_font_override("font", _load_font())
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", UI_OUTLINE)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", hover_font_color)
	button.add_theme_color_override("font_pressed_color", pressed_font_color)
	button.add_theme_color_override("font_focus_color", hover_font_color)
	button.add_theme_color_override("font_disabled_color", UI_TEXT_MUTED)
	button.add_theme_stylebox_override("normal", _make_texture_style(GUI_BUTTON_NORMAL_TEXTURE, 14.0, 8.0))
	button.add_theme_stylebox_override("hover", _make_texture_style(GUI_BUTTON_HOVER_TEXTURE, 14.0, 8.0))
	button.add_theme_stylebox_override("pressed", _make_texture_style(GUI_BUTTON_PRESSED_TEXTURE, 14.0, 8.0))
	button.add_theme_stylebox_override("focus", _make_texture_style(GUI_BUTTON_HOVER_TEXTURE, 14.0, 8.0))


func _apply_styles() -> void:
	sign_texture.texture = SHOP_SIGN_TEXTURE
	sign_texture.custom_minimum_size = Vector2(156.0, 48.0)
	root_panel.add_theme_stylebox_override("panel", _make_texture_style(GUI_PANEL_TEXTURE, 20.0, 16.0))
	backdrop.color = Color(0.0, 0.0, 0.0, 0.84)

	title_label.text = "Hub-Haendler"
	_style_label(title_label, 18, UI_BORDER.lightened(0.18), 3)

	subtitle_label.text = "Drei Tagesangebote rotieren taeglich. Permanente Ware bleibt fair und planbar."
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(subtitle_label, 11, UI_TEXT_SOFT, 2)

	_style_label(status_label, 11, UI_TEXT_SOFT, 2)
	_style_label(reset_label, 11, UI_WARNING, 2)

	hint_label.text = "Am Wagen mit [E] oeffnen, mit [Esc] oder [I] schliessen. Alle Schwerter sind aktuell gratis zum Testen."
	_style_label(hint_label, 10, UI_TEXT_MUTED, 2)

	wallet_title.text = "WAEHRUNGEN"
	featured_title.text = "HEUTE IM ANGEBOT"
	permanent_title.text = "IMMER VERFUEGBAR"

	for section_label in [wallet_title, featured_title, permanent_title]:
		_style_label(section_label, 15, UI_BORDER.lightened(0.14), 3)

	for button in [refresh_button, close_button]:
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(96.0, 34.0)

	refresh_button.text = "Neu laden"
	_style_pixel_button(refresh_button, UI_TEXT, UI_SUCCESS, UI_PANEL_BG_INSET)
	refresh_button.pressed.connect(_request_shop_data)

	close_button.text = "Schliessen"
	_style_pixel_button(close_button, UI_WARNING, UI_ERROR, UI_PANEL_BG_INSET)
	close_button.pressed.connect(close_shop)


func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


func _format_remaining_time() -> String:
	if next_refresh_unix <= 0:
		return "taeglich um Mitternacht"

	var now := int(Time.get_unix_time_from_system())
	var remaining := maxi(next_refresh_unix - now, 0)
	var hours := remaining / 3600
	var minutes := (remaining % 3600) / 60
	var seconds := remaining % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func _parse_datetime_to_unix(datetime_text: String) -> int:
	if datetime_text.is_empty():
		return _next_midnight_unix()
	return int(Time.get_unix_time_from_datetime_string(datetime_text))


func _next_midnight_unix() -> int:
	var tomorrow_dict := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + 86_400)
	var tomorrow_midnight := "%04d-%02d-%02dT00:00:00" % [
		tomorrow_dict.year,
		tomorrow_dict.month,
		tomorrow_dict.day,
	]
	return int(Time.get_unix_time_from_datetime_string(tomorrow_midnight))


func _make_flat_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_detail = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 6
	return style


func _make_texture_style(texture: Texture2D, margin_x: float = 12.0, margin_y: float = 8.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.content_margin_left = margin_x
	style.content_margin_top = margin_y
	style.content_margin_right = margin_x
	style.content_margin_bottom = margin_y
	style.draw_center = true
	return style


func _load_font() -> FontFile:
	if cached_font == null:
		cached_font = load(FONT_PATH) as FontFile
	return cached_font
