extends Node

## Central, read-only Steam ownership boundary for cosmetics.  Steam is the
## only source of ownership truth; this node deliberately never writes DLC
## ownership to SaveService.

signal entitlement_refreshed(owns_early_supporter_crown: bool)
signal early_supporter_crown_equipped_changed(equipped: bool)

const EARLY_SUPPORTER_CROWN_DLC_APP_ID := 5313030
const EARLY_SUPPORTER_CROWN_PRESENTATION_ID := "early_supporter_crown"

@export var debug_force_early_supporter_crown := false

var owns_early_supporter_crown := false
var early_supporter_crown_equipped := true
var _presentation_open := false


func _ready() -> void:
	if OS.is_debug_build() and "--force-early-supporter-crown" in OS.get_cmdline_user_args():
		debug_force_early_supporter_crown = true
	if SteamManager.initialized.is_connected(_on_steam_initialized) == false:
		SteamManager.initialized.connect(_on_steam_initialized)
	if SteamManager.initialization_failed.is_connected(_on_steam_initialization_failed) == false:
		SteamManager.initialization_failed.connect(_on_steam_initialization_failed)
	call_deferred("refresh_ownership")


func _process(_delta: float) -> void:
	_present_claim_screen_when_ready()


func _on_steam_initialized(_user_name: String) -> void:
	refresh_ownership()


func _on_steam_initialization_failed(_reason: String) -> void:
	_set_ownership(false)


func refresh_ownership() -> bool:
	var owned := false
	if SteamManager.is_initialized and SteamManager.steam != null:
		# GodotSteam 4.22.1 exposes ISteamApps::BIsSubscribedApp as
		# Steam.isSubscribedApp(app_id). The installed template was inspected
		# before using this exact method name.
		if SteamManager.steam.has_method("isSubscribedApp"):
			owned = bool(SteamManager.steam.call("isSubscribedApp", EARLY_SUPPORTER_CROWN_DLC_APP_ID))
		else:
			push_warning("[Entitlements] GodotSteam has no isSubscribedApp API; crown remains unavailable.")
	_set_ownership(owned)
	_refresh_early_supporter_crown_preference()
	return owns_early_supporter_crown


func has_early_supporter_crown() -> bool:
	return debug_force_early_supporter_crown if OS.is_debug_build() else owns_early_supporter_crown


func is_early_supporter_crown_equipped() -> bool:
	return has_early_supporter_crown() and early_supporter_crown_equipped


func debug_set_early_supporter_crown(enabled: bool) -> void:
	if not OS.is_debug_build():
		return
	debug_force_early_supporter_crown = enabled
	entitlement_refreshed.emit(has_early_supporter_crown())
	early_supporter_crown_equipped_changed.emit(is_early_supporter_crown_equipped())


func set_early_supporter_crown_equipped(equipped: bool) -> void:
	if not has_early_supporter_crown():
		return
	var steam_identity := SteamManager.get_player_identity("")
	if not steam_identity.is_empty():
		SaveService.set_cosmetic_preference(EARLY_SUPPORTER_CROWN_PRESENTATION_ID, steam_identity, equipped)
	_set_early_supporter_crown_equipped(equipped)


func should_present_early_supporter_crown() -> bool:
	if not has_early_supporter_crown() or not SteamManager.is_initialized:
		return false
	var steam_identity := SteamManager.get_player_identity("")
	return not steam_identity.is_empty() and not SaveService.has_cosmetic_presentation_claimed(EARLY_SUPPORTER_CROWN_PRESENTATION_ID, steam_identity)


func accept_early_supporter_crown_presentation() -> void:
	var steam_identity := SteamManager.get_player_identity("")
	if steam_identity.is_empty():
		return
	SaveService.mark_cosmetic_presentation_claimed(EARLY_SUPPORTER_CROWN_PRESENTATION_ID, steam_identity)
	_presentation_open = false


func _set_ownership(owned: bool) -> void:
	var changed := owns_early_supporter_crown != owned
	owns_early_supporter_crown = owned
	if changed:
		print("[Entitlements] Early Supporter Crown ownership: %s" % owned)
		entitlement_refreshed.emit(has_early_supporter_crown())


func _refresh_early_supporter_crown_preference() -> void:
	var steam_identity := SteamManager.get_player_identity("")
	if not has_early_supporter_crown() or steam_identity.is_empty():
		_set_early_supporter_crown_equipped(true)
		return
	_set_early_supporter_crown_equipped(SaveService.get_cosmetic_preference(EARLY_SUPPORTER_CROWN_PRESENTATION_ID, steam_identity, true))


func _set_early_supporter_crown_equipped(equipped: bool) -> void:
	if early_supporter_crown_equipped == equipped:
		return
	early_supporter_crown_equipped = equipped
	early_supporter_crown_equipped_changed.emit(is_early_supporter_crown_equipped())


func _present_claim_screen_when_ready() -> void:
	if _presentation_open or not should_present_early_supporter_crown():
		return
	var scene := get_tree().current_scene
	if scene == null or not String(scene.scene_file_path).ends_with("Scenes/main_menu.tscn"):
		return
	_presentation_open = true
	var presentation := preload("res://Scripts/early_supporter_crown_claim.gd").new()
	presentation.name = "EarlySupporterCrownClaim"
	scene.add_child(presentation)
