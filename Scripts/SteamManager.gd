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
# This is the achievement API name configured in Steamworks. Despite the STAT
# prefix, Steamworks currently defines it as a client-triggered achievement.
const ACH_WISP_BEETLES_KILLED := "STAT_WISP_BEETLES_KILLED"
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
	_initialize_steam()
	CombatEvents.enemy_defeated.connect(_on_enemy_defeated)


func _process(_delta: float) -> void:
	if is_initialized and steam != null and steam.has_method("runCallbacks"):
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
		response = steam.call("steamInitEx", APP_ID, true)
	elif steam.has_method("steamInit"):
		response = steam.call("steamInit", APP_ID, true)
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
	if wisp_beetles_defeated >= WISP_BEETLE_KILL_TARGET:
		unlock(ACH_WISP_BEETLES_KILLED)


func _request_stats() -> void:
	if steam != null and steam.has_method("requestCurrentStats"):
		if not bool(steam.call("requestCurrentStats")):
			_log_failure_once("stats", "[Steam] Failed to request current stats.")


func _flush_pending_achievements() -> void:
	if not is_initialized:
		return
	for api_name: String in SaveService.get_pending_achievements():
		unlock(api_name)


func _connect_stats_signal() -> void:
	if steam == null or not steam.has_signal("current_stats_received"):
		return
	var callback := Callable(self, "_on_current_stats_received")
	if not steam.is_connected("current_stats_received", callback):
		steam.connect("current_stats_received", callback)


func _on_current_stats_received(_game_id: Variant = null, result: Variant = true, _user_id: Variant = null) -> void:
	if result is bool and not result:
		_log_failure_once("stats_received", "[Steam] Failed to receive current stats.")
		return
	if result is int and result != 1:
		_log_failure_once("stats_received", "[Steam] Failed to receive current stats (result %s)." % result)
		return
	are_stats_ready = true
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
