extends Node

## Optional Steamworks boundary. The project keeps working when the custom
## GodotSteam editor/export template is not installed or Steam is unavailable.

signal initialized(user_name: String)
signal initialization_failed(reason: String)
signal stats_ready
signal achievement_unlocked(api_name: String)
signal achievement_failed(api_name: String, reason: String)

const APP_ID := 4536840
const ACH_FIRST_KILL := "ACH_FIRST_KILL"
const ACH_WISP_HUNTER := "ACH_WISP_HUNTER"
const ACH_BELL_RINGER := "ACH_BELL_RINGER"
const ACH_MOONFLOWER_BLOOM := "ACH_MOONFLOWER_BLOOM"
const ACH_CHAPTER_ONE_CLEAR := "ACH_CHAPTER_ONE_CLEAR"
const ACH_ENTER_PVP := "ACH_ENTER_PVP"
const STAT_WISP_BEETLES_KILLED := "STAT_WISP_BEETLES_KILLED"
const WISP_BEETLE_KILL_STAT := "wisp_beetles_defeated"
const WISP_BEETLE_KILL_TARGET := 10

var steam: Object
var is_available := false
var is_initialized := false
var are_stats_ready := false
var user_name := ""
var _known_unlocked: Dictionary = {}
var _logged_failures: Dictionary = {}


func _ready() -> void:
	if "--dedicated-server" in OS.get_cmdline_args() or "--dedicated-server" in OS.get_cmdline_user_args():
		# Competitive ENet matches do not require a logged-in Steam client on the
		# Linux host. Avoid loading the desktop Steam runtime in the service.
		return
	_initialize_steam()
	CombatEvents.enemy_defeated.connect(_on_enemy_defeated)


func _process(_delta: float) -> void:
	if not is_initialized or steam == null:
		return
	# GodotSteam 4.22 exposes run_callbacks(). We initialize with embedded
	# callbacks disabled below so Steam callbacks are pumped exactly once from
	# this node; mixing both mechanisms can dispatch a completed lobby call
	# twice and crashed the macOS template during CreateLobby.
	if steam.has_method("run_callbacks"):
		steam.call("run_callbacks")
	elif steam.has_method("runCallbacks"):
		# Compatibility with older project templates.
		steam.call("runCallbacks")


func _initialize_steam() -> void:
	if not Engine.has_singleton("Steam"):
		_fail_initialization("GodotSteam runtime is not installed; continuing without Steam.")
		return
	steam = Engine.get_singleton("Steam")
	if steam == null:
		_fail_initialization("GodotSteam singleton was unavailable; continuing without Steam.")
		return
	var response: Variant
	if steam.has_method("steamInitEx"):
		response = steam.call("steamInitEx", APP_ID, false)
	elif steam.has_method("steamInit"):
		response = steam.call("steamInit", APP_ID, false)
	else:
		_fail_initialization("GodotSteam build has no Steam initialization API.")
		return
	if not _init_succeeded(response):
		_fail_initialization("steamInit failed: %s" % str(response))
		return
	is_available = true
	is_initialized = true
	user_name = String(steam.call("getPersonaName")) if steam.has_method("getPersonaName") else "Steam user"
	print("[Steam] Initialized successfully")
	print("[Steam] Logged in as: %s" % user_name)
	_connect_stats_signal()
	_request_stats()
	_flush_pending_achievements()
	initialized.emit(user_name)


func unlock(api_name: String) -> bool:
	if api_name.is_empty():
		return false
	if not is_initialized or steam == null:
		SaveService.queue_pending_achievement(api_name)
		_log_failure_once("unlock:" + api_name, "[Steam] Failed to unlock achievement: %s (Steam unavailable)" % api_name)
		return false
	if not are_stats_ready:
		SaveService.queue_pending_achievement(api_name)
		_log_failure_once("stats_pending:" + api_name, "[Steam] Delayed achievement unlock until Steam stats are ready: %s" % api_name)
		return false
	if _is_achievement_unlocked(api_name):
		SaveService.clear_pending_achievement(api_name)
		return true
	if not steam.has_method("setAchievement") or not bool(steam.call("setAchievement", api_name)):
		var reason := "setAchievement returned false"
		print("[Steam] Failed to unlock achievement: %s" % api_name)
		achievement_failed.emit(api_name, reason)
		return false
	_known_unlocked[api_name] = true
	SaveService.clear_pending_achievement(api_name)
	print("[Steam] Achievement unlocked: %s" % api_name)
	achievement_unlocked.emit(api_name)
	if steam.has_method("storeStats") and bool(steam.call("storeStats")):
		print("[Steam] Stats stored successfully")
		return true
	var store_reason := "storeStats returned false"
	print("[Steam] Failed to unlock achievement: %s (%s)" % [api_name, store_reason])
	achievement_failed.emit(api_name, store_reason)
	return false


func is_achievement_unlocked(api_name: String) -> bool:
	return _is_achievement_unlocked(api_name)


func get_player_identity(fallback_identity: String = "") -> String:
	if is_initialized and steam != null and steam.has_method("getSteamID"):
		return "steam:%s" % str(steam.call("getSteamID"))
	return fallback_identity


func resolve_friend_identity(friend_name_or_steam_id: String) -> String:
	if not is_initialized or steam == null:
		return ""
	var requested := friend_name_or_steam_id.strip_edges()
	if requested.begins_with("steam:"):
		requested = requested.trim_prefix("steam:")
	var friend_count := int(steam.call("getFriendCount", 4)) if steam.has_method("getFriendCount") else 0
	for index in range(maxi(friend_count, 0)):
		var friend_id := str(steam.call("getFriendByIndex", index, 4))
		var friend_name := str(steam.call("getFriendPersonaName", int(friend_id))) if steam.has_method("getFriendPersonaName") else ""
		if requested == friend_id or requested.to_lower() == friend_name.to_lower():
			return "steam:%s" % friend_id
	return ""


func debug_status() -> Dictionary:
	if not OS.is_debug_build():
		return {}
	return {
		"app_id": APP_ID,
		"available": is_available,
		"initialized": is_initialized,
		"stats_ready": are_stats_ready,
		"user": user_name,
		"wisp_beetles_defeated": SaveService.get_stat(WISP_BEETLE_KILL_STAT),
		"save_path": SaveService.get_save_directory_for_debug(),
	}


func debug_unlock(api_name: String) -> bool:
	return unlock(api_name) if OS.is_debug_build() else false


func debug_reset_achievement(api_name: String) -> bool:
	if not OS.is_debug_build() or not is_initialized or steam == null or not steam.has_method("clearAchievement"):
		return false
	if not bool(steam.call("clearAchievement", api_name)):
		return false
	_known_unlocked.erase(api_name)
	return bool(steam.call("storeStats")) if steam.has_method("storeStats") else false


func debug_save() -> bool:
	return SaveService.debug_save_manifest() if OS.is_debug_build() else false


func debug_load() -> Dictionary:
	return SaveService.debug_reload_manifest() if OS.is_debug_build() else {}


func _on_enemy_defeated(_enemy: Node, enemy_type: String, _total_defeats: int) -> void:
	unlock(ACH_FIRST_KILL)
	# CombatEvents only emits this after a hostile enemy actually died from
	# player-owned damage, and it deduplicates every enemy instance. Friendly
	# fireflies, NPCs and repeated death callbacks therefore cannot add progress.
	if enemy_type != "irrlichtkaefer":
		return
	var wisp_beetles_defeated := SaveService.increment_stat(WISP_BEETLE_KILL_STAT)
	_sync_int_stat(STAT_WISP_BEETLES_KILLED, wisp_beetles_defeated)
	if wisp_beetles_defeated >= WISP_BEETLE_KILL_TARGET:
		unlock(ACH_WISP_HUNTER)


func _sync_int_stat(api_name: String, value: int) -> void:
	if not is_initialized or not are_stats_ready or steam == null:
		return
	if not steam.has_method("setStat"):
		_log_failure_once("set_stat:" + api_name, "[Steam] This GodotSteam build has no setStat API for %s." % api_name)
		return
	if not bool(steam.call("setStat", api_name, maxi(0, value))):
		_log_failure_once("set_stat_failed:" + api_name, "[Steam] Failed to sync stat: %s" % api_name)
		return
	if steam.has_method("storeStats"):
		steam.call("storeStats")


func _request_stats() -> void:
	if steam != null and steam.has_method("requestCurrentStats"):
		if not bool(steam.call("requestCurrentStats")):
			_log_failure_once("stats", "[Steam] Failed to request current stats.")
		return
	# Steamworks SDK 1.61 removed RequestCurrentStats. Current GodotSteam
	# versions load the local account through RequestUserStats instead.
	if steam != null and steam.has_method("requestUserStats") and steam.has_method("getSteamID"):
		steam.call("requestUserStats", steam.call("getSteamID"))
		return
	_log_failure_once("stats", "[Steam] This GodotSteam build has no user-stats request API.")


func _flush_pending_achievements() -> void:
	if not is_initialized:
		return
	for api_name: String in SaveService.get_pending_achievements():
		unlock(api_name)


func _connect_stats_signal() -> void:
	if steam == null:
		return
	if steam.has_signal("current_stats_received"):
		var legacy_callback := Callable(self, "_on_current_stats_received")
		if not steam.is_connected("current_stats_received", legacy_callback):
			steam.connect("current_stats_received", legacy_callback)
	if steam.has_signal("user_stats_received"):
		var callback := Callable(self, "_on_user_stats_received")
		if not steam.is_connected("user_stats_received", callback):
			steam.connect("user_stats_received", callback)


func _on_current_stats_received(_game_id: Variant = null, result: Variant = true, _user_id: Variant = null) -> void:
	if result is bool and not result:
		_log_failure_once("stats_received", "[Steam] Failed to receive current stats.")
		return
	if result is int and result != 1:
		_log_failure_once("stats_received", "[Steam] Failed to receive current stats (result %s)." % result)
		return
	_mark_stats_ready()


func _on_user_stats_received(game_id: Variant = null, result: Variant = 1, _user_id: Variant = null) -> void:
	if game_id is int and int(game_id) != APP_ID:
		return
	if result is int and result != 1:
		_log_failure_once("stats_received", "[Steam] Failed to receive user stats (result %s)." % result)
		return
	if result is bool and not result:
		_log_failure_once("stats_received", "[Steam] Failed to receive user stats.")
		return
	_mark_stats_ready()


func _mark_stats_ready() -> void:
	if are_stats_ready:
		return
	are_stats_ready = true
	print("[Steam] Stats ready")
	_sync_int_stat(STAT_WISP_BEETLES_KILLED, SaveService.get_stat(WISP_BEETLE_KILL_STAT))
	_flush_pending_achievements()
	stats_ready.emit()


func _is_achievement_unlocked(api_name: String) -> bool:
	if bool(_known_unlocked.get(api_name, false)):
		return true
	if not is_initialized or steam == null or not steam.has_method("getAchievement"):
		return false
	var result: Variant = steam.call("getAchievement", api_name)
	var unlocked := false
	if result is Dictionary:
		unlocked = bool((result as Dictionary).get("achieved", (result as Dictionary).get("ret", false)))
	elif result is bool:
		unlocked = result
	if unlocked:
		_known_unlocked[api_name] = true
	return unlocked


func _init_succeeded(response: Variant) -> bool:
	if response is Dictionary:
		# GodotSteam's steamInitEx() reports status 0 for a successful
		# initialization. Treating 1 as success marked every healthy Steam
		# session as unavailable, so no achievement API calls ever reached Steam.
		return int((response as Dictionary).get("status", 1)) == 0
	if response is bool:
		return response
	if response is int:
		return response == 1
	return false


func _fail_initialization(reason: String) -> void:
	is_available = false
	is_initialized = false
	print("[Steam] %s" % reason)
	initialization_failed.emit(reason)


func _log_failure_once(key: String, message: String) -> void:
	if _logged_failures.has(key):
		return
	_logged_failures[key] = true
	print(message)
