extends Node

## Friends co-op is host/client over Steam's relay-capable networking sockets.
## PvP remains a dedicated ENet arena; both use the same replicated arena scene.

signal multiplayer_error(message: String)
signal matchmaking_status_changed(message: String)
signal steam_coop_ready(lobby_id: int)

## A menu state is deliberately separate from the authoritative in-arena match
## state.  The client only requests a mode; the server is the only side that
## accepts a party and starts a round.
enum MatchmakingState { IDLE, MODE_SELECTED, SEARCHING, MATCH_FOUND, JOINING, WAITING_FOR_PLAYERS, STARTING, IN_MATCH, MATCH_ENDING, RESULTS, REMATCH_SEARCH, ERROR }
const MODE_CLASSIC_PVP := "classic_pvp"
const MODE_TEAM_BATTLE := "team_battle"
const MODE_CAVE_SURVIVAL := "cave_survival"

## UDP 443 is relayed by the public reverse proxy to the private arena host.
## Keeping PvP on one dedicated endpoint means public matches never expose the
## game host's high port and do not depend on Steam P2P connectivity.
const DEDICATED_SERVER_HOST := "lobby.joeyslime.com"
const DEDICATED_SERVER_PORT := 443
# Transparent fallback for players testing from the same private network. Some
# routers do not support NAT loopback, so their own public address cannot be
# reached from inside the network even though it works for Internet players.
const LAN_PVP_SERVER_HOST := "192.168.30.50"
const LAN_PVP_SERVER_PORT := 5999
const MAX_COOP_PLAYERS := 4
const PVP_LOBBY_KIND := "joey_pvp_v1"
const PVP_LOBBY_SEARCH_LIMIT := 20

var peer: MultiplayerPeer
var is_multiplayer := false
var is_global_pvp := false
var is_steam_coop := false
var is_steam_coop_host := false
var steam_lobby_id: int = 0
var pvp_lobby_id: int = 0
var _steam_callbacks_connected := false
var _loading_multiplayer_world := false
var _using_lan_pvp_fallback := false
var _pvp_lobby_search_pending := false
var _pvp_lobby_create_pending := false
var _pvp_lobby_join_pending := false
var matchmaking_state: MatchmakingState = MatchmakingState.IDLE
var selected_match_mode := ""


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	SteamManager.initialized.connect(_on_steam_initialized)
	if SteamManager.is_initialized:
		_connect_steam_callbacks()
	_start_command_line_pvp_test_if_requested()


func _on_steam_initialized(_user_name: String) -> void:
	_connect_steam_callbacks()


func join_dedicated_server(host: String = DEDICATED_SERVER_HOST, port: int = DEDICATED_SERVER_PORT) -> void:
	# Keep the requested mode and its already-admitted Steam lobby while changing
	# only the gameplay transport.  Resetting them here silently downgraded Team
	# Battle and Survival to Classic on every client.
	var requested_mode := selected_match_mode
	reset_multiplayer_state(false)
	selected_match_mode = requested_mode
	is_multiplayer = true
	is_global_pvp = true
	_using_lan_pvp_fallback = false
	_connect_to_pvp_endpoint(host, port)


func _connect_to_pvp_endpoint(host: String, port: int) -> void:
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	print("[Network] Connecting to PvP server %s:%d" % [host, port])
	matchmaking_status_changed.emit("Matchsuche läuft …")
	var enet_peer := ENetMultiplayerPeer.new()
	var error := enet_peer.create_client(host, port)
	if error != OK:
		_fail_connection("PvP-Verbindung konnte nicht gestartet werden (%d)." % error)
		return
	peer = enet_peer
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connection_success, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	multiplayer.server_disconnected.connect(_on_server_disconnected, CONNECT_ONE_SHOT)


func host_steam_coop() -> void:
	if not _steam_coop_supported():
		_fail_connection("Steam-Freunde-Koop ist nur in der Steam-Version verfügbar.")
		return
	reset_multiplayer_state()
	is_multiplayer = true
	is_steam_coop = true
	is_steam_coop_host = true
	SteamManager.steam.call("createLobby", 1, MAX_COOP_PLAYERS) # friends-only
	print("[Steam Coop] Creating friends-only lobby")


func start_global_pvp_matchmaking() -> void:
	# PvP is always authoritative on our dedicated server. Steam P2P is reserved
	# for invited co-op games, never for competitive public matches.
	start_global_matchmaking(MODE_CLASSIC_PVP)


func start_global_matchmaking(mode: String) -> void:
	if not mode in [MODE_CLASSIC_PVP, MODE_TEAM_BATTLE, MODE_CAVE_SURVIVAL]:
		_fail_connection("Ungültiger Spielmodus.")
		return
	if matchmaking_state in [MatchmakingState.SEARCHING, MatchmakingState.JOINING, MatchmakingState.WAITING_FOR_PLAYERS, MatchmakingState.STARTING, MatchmakingState.IN_MATCH]:
		print("[MATCHMAKING] Ignored duplicate queue request for %s" % mode)
		return
	reset_multiplayer_state()
	selected_match_mode = mode
	is_multiplayer = true
	is_global_pvp = true
	set_matchmaking_state(MatchmakingState.MODE_SELECTED, _mode_label(mode))
	matchmaking_state = MatchmakingState.SEARCHING
	print("[MATCHMAKING] Searching %s" % mode)
	matchmaking_status_changed.emit("Finding Match…\n%s" % _mode_label(mode))
	if _steam_pvp_lobby_supported():
		_begin_steam_pvp_lobby_search()
	else:
		# LAN, DRM-free and Steam-runtime-failure builds still use the same
		# authoritative dedicated queue. They are deliberately not blocked by a
		# client platform service.
		join_dedicated_server()


func cancel_matchmaking() -> void:
	if is_global_pvp and peer != null and multiplayer.multiplayer_peer.has_method("get_connection_status"):
		# The arena removes a queued peer on disconnect.  Closing the peer is the
		# atomic cancellation path and prevents a stale queue entry.
		peer.close()
	reset_multiplayer_state()
	matchmaking_status_changed.emit("Match search cancelled.")


func join_steam_lobby(lobby_id: int) -> void:
	if not _steam_coop_supported() or lobby_id <= 0:
		_fail_connection("Steam-Lobby konnte nicht geöffnet werden.")
		return
	reset_multiplayer_state()
	is_multiplayer = true
	is_steam_coop = true
	is_steam_coop_host = false
	SteamManager.steam.call("joinLobby", lobby_id)
	print("[Steam Coop] Joining lobby %d" % lobby_id)


func invite_steam_friends() -> void:
	if is_steam_coop and steam_lobby_id > 0 and SteamManager.steam != null:
		SteamManager.steam.call("activateGameOverlayInviteDialog", steam_lobby_id)


func _connect_steam_callbacks() -> void:
	if _steam_callbacks_connected or SteamManager.steam == null:
		return
	var steam := SteamManager.steam
	if steam.has_signal("lobby_created"):
		steam.lobby_created.connect(_on_steam_lobby_created)
	if steam.has_signal("lobby_joined"):
		steam.lobby_joined.connect(_on_steam_lobby_joined)
	if steam.has_signal("lobby_match_list"):
		steam.lobby_match_list.connect(_on_pvp_lobby_match_list)
	if steam.has_signal("join_requested"):
		steam.join_requested.connect(_on_steam_join_requested)
	_steam_callbacks_connected = true


func _on_steam_lobby_created(result: int, lobby_id: int) -> void:
	if _pvp_lobby_create_pending:
		_pvp_lobby_create_pending = false
		if result != 1:
			_fallback_to_dedicated_pvp("Steam konnte keine PvP-Lobby erstellen (Code %d)." % result)
			return
		pvp_lobby_id = lobby_id
		_publish_pvp_lobby(lobby_id)
		print("[Steam PvP] Created lobby %d for %s" % [lobby_id, selected_match_mode])
		_connect_pvp_lobby_to_dedicated_server()
		return
	if not is_steam_coop:
		return
	if result != 1:
		_fail_connection("Steam konnte keine Freunde-Lobby erstellen (Code %d)." % result)
		return
	steam_lobby_id = lobby_id
	var steam_peer := _create_steam_multiplayer_peer()
	if steam_peer == null:
		_fail_connection("Steam-Netzwerkmodul ist in diesem Build nicht verfügbar.")
		return
	var error := int(steam_peer.call("host_with_lobby", lobby_id))
	if error != OK:
		_fail_connection("Steam-Koop-Host konnte nicht gestartet werden (%d)." % error)
		return
	peer = steam_peer
	multiplayer.multiplayer_peer = peer
	SteamManager.steam.call("setLobbyData", lobby_id, "mode", "friends_coop")
	SteamManager.steam.call("setLobbyData", lobby_id, "version", ProjectSettings.get_setting("application/config/version", "dev"))
	steam_coop_ready.emit(lobby_id)
	load_game_world()
	call_deferred("invite_steam_friends")
	print("[Steam Coop] Hosting lobby %d" % lobby_id)


func _on_steam_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if _pvp_lobby_join_pending:
		_pvp_lobby_join_pending = false
		if response != 1:
			_fallback_to_dedicated_pvp("Steam-Lobby konnte nicht betreten werden (Code %d)." % response)
			return
		pvp_lobby_id = lobby_id
		print("[Steam PvP] Joined lobby %d for %s" % [lobby_id, selected_match_mode])
		_connect_pvp_lobby_to_dedicated_server()
		return
	if not is_steam_coop:
		return
	# Steam emits lobby_joined for the lobby creator as well. The creator has
	# already installed its host peer in lobby_created; replacing it with a
	# client peer here would break the host's own invitation session.
	if is_steam_coop_host and peer != null and steam_lobby_id == lobby_id:
		return
	if response != 1:
		_fail_connection("Steam-Lobby konnte nicht betreten werden (Code %d)." % response)
		return
	steam_lobby_id = lobby_id
	var steam_peer := _create_steam_multiplayer_peer()
	if steam_peer == null:
		_fail_connection("Steam-Netzwerkmodul ist in diesem Build nicht verfügbar.")
		return
	var error := int(steam_peer.call("connect_to_lobby", lobby_id))
	if error != OK:
		_fail_connection("Steam-Koop-Verbindung konnte nicht hergestellt werden (%d)." % error)
		return
	peer = steam_peer
	multiplayer.multiplayer_peer = peer
	steam_coop_ready.emit(lobby_id)
	load_game_world()
	print("[Steam Coop] Joined lobby %d" % lobby_id)


func _on_steam_join_requested(lobby_id: int, _friend_id: int) -> void:
	join_steam_lobby(lobby_id)


func _on_connection_success() -> void:
	print("[Network] Connected to PvP server")
	matchmaking_state = MatchmakingState.JOINING
	matchmaking_status_changed.emit("Connected — joining the %s queue…" % _mode_label(selected_match_mode))
	load_game_world()


func _on_connection_failed() -> void:
	if is_global_pvp and not _using_lan_pvp_fallback:
		_using_lan_pvp_fallback = true
		print("[Network] Public PvP endpoint unavailable; trying LAN fallback")
		matchmaking_status_changed.emit("Öffentliche Route nicht erreichbar – lokaler Arena-Server wird versucht …")
		_connect_to_pvp_endpoint(LAN_PVP_SERVER_HOST, LAN_PVP_SERVER_PORT)
		return
	_fail_connection("PvP-Server ist nicht erreichbar.")


func _on_server_disconnected() -> void:
	_fail_connection("Die Verbindung zum PvP-Server wurde getrennt.")


func load_game_world() -> void:
	if _loading_multiplayer_world:
		return
	_loading_multiplayer_world = true
	var multiplayer_scene := "res://Scenes/pvp_arena.tscn" if is_global_pvp else "res://Scenes/world.tscn"
	print("[Network] Loading multiplayer scene %s" % multiplayer_scene)
	get_tree().change_scene_to_file(multiplayer_scene)


func reset_multiplayer_state(release_pvp_lobby: bool = true) -> void:
	_loading_multiplayer_world = false
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_multiplayer = false
	is_global_pvp = false
	is_steam_coop = false
	is_steam_coop_host = false
	steam_lobby_id = 0
	if release_pvp_lobby:
		_leave_pvp_lobby()
		pvp_lobby_id = 0
		_pvp_lobby_search_pending = false
		_pvp_lobby_create_pending = false
		_pvp_lobby_join_pending = false
	_using_lan_pvp_fallback = false
	matchmaking_state = MatchmakingState.IDLE
	selected_match_mode = ""


func _on_scene_changed() -> void:
	_loading_multiplayer_world = false


func _fail_connection(message: String) -> void:
	print("[Network] %s" % message)
	matchmaking_status_changed.emit(message)
	multiplayer_error.emit(message)
	reset_multiplayer_state()
	show_error(message)


func set_matchmaking_state(next_state: MatchmakingState, message: String) -> void:
	matchmaking_state = next_state
	if not message.is_empty():
		matchmaking_status_changed.emit(message)


func leave_match_to_menu() -> void:
	reset_multiplayer_state()
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _mode_label(mode: String) -> String:
	match mode:
		MODE_CLASSIC_PVP: return "Classic PvP • 1 vs 1"
		MODE_TEAM_BATTLE: return "Team Battle • 2 vs 2"
		MODE_CAVE_SURVIVAL: return "Cave Survival • 2 Players"
		_: return "Match"


func _steam_pvp_lobby_supported() -> bool:
	if not SteamManager.is_initialized or SteamManager.steam == null:
		return false
	for method in ["addRequestLobbyListStringFilter", "addRequestLobbyListFilterSlotsAvailable", "addRequestLobbyListResultCountFilter", "requestLobbyList", "createLobby", "joinLobby", "setLobbyData"]:
		if not SteamManager.steam.has_method(method):
			return false
	return SteamManager.steam.has_signal("lobby_match_list")


func _begin_steam_pvp_lobby_search() -> void:
	if not _steam_pvp_lobby_supported():
		join_dedicated_server()
		return
	_pvp_lobby_search_pending = true
	set_matchmaking_state(MatchmakingState.SEARCHING, "Searching Steam lobbies…\n%s" % _mode_label(selected_match_mode))
	var steam := SteamManager.steam
	# Steam clears lobby-list filters after every request; apply all metadata
	# filters immediately before this individual search.
	steam.call("addRequestLobbyListStringFilter", "kind", PVP_LOBBY_KIND, 0) # Steam.LOBBY_COMPARISON_EQUAL
	steam.call("addRequestLobbyListStringFilter", "mode", selected_match_mode, 0)
	steam.call("addRequestLobbyListStringFilter", "version", _build_version(), 0)
	steam.call("addRequestLobbyListFilterSlotsAvailable", 1)
	steam.call("addRequestLobbyListResultCountFilter", PVP_LOBBY_SEARCH_LIMIT)
	steam.call("requestLobbyList")


func _on_pvp_lobby_match_list(lobbies: Array) -> void:
	if not _pvp_lobby_search_pending or selected_match_mode.is_empty():
		return
	_pvp_lobby_search_pending = false
	var lobby_id := _select_pvp_lobby(lobbies)
	if lobby_id <= 0:
		_create_steam_pvp_lobby()
		return
	_pvp_lobby_join_pending = true
	set_matchmaking_state(MatchmakingState.JOINING, "Joining Steam lobby…")
	SteamManager.steam.call("joinLobby", lobby_id)


func _select_pvp_lobby(lobbies: Array) -> int:
	if SteamManager.steam == null:
		return 0
	var capacity := _mode_capacity(selected_match_mode)
	for entry in lobbies:
		var lobby_id := _lobby_id_from_search_result(entry)
		if lobby_id <= 0:
			continue
		# The request filters are primary. Member/limit checks protect a race in
		# which a lobby filled after Steam produced the search result.
		var members := int(SteamManager.steam.call("getNumLobbyMembers", lobby_id)) if SteamManager.steam.has_method("getNumLobbyMembers") else 0
		var limit := int(SteamManager.steam.call("getLobbyMemberLimit", lobby_id)) if SteamManager.steam.has_method("getLobbyMemberLimit") else capacity
		if members < capacity and members < limit:
			return lobby_id
	return 0


func _lobby_id_from_search_result(entry: Variant) -> int:
	if entry is int:
		return int(entry)
	if entry is Dictionary:
		var result := entry as Dictionary
		for key in ["steamIDLobby", "lobby_id", "lobbyID", "id"]:
			if result.has(key):
				return int(result[key])
	return 0


func _create_steam_pvp_lobby() -> void:
	if SteamManager.steam == null:
		_fallback_to_dedicated_pvp("Steam-Lobby-Service ist nicht verfügbar.")
		return
	_pvp_lobby_create_pending = true
	set_matchmaking_state(MatchmakingState.JOINING, "Creating Steam lobby…")
	# ELobbyType public = 2. The capacity makes a full 1v1 lobby unavailable to
	# subsequent searches, which causes Steam to create the next isolated room.
	SteamManager.steam.call("createLobby", 2, _mode_capacity(selected_match_mode))


func _publish_pvp_lobby(lobby_id: int) -> void:
	if SteamManager.steam == null:
		return
	for pair in [["kind", PVP_LOBBY_KIND], ["mode", selected_match_mode], ["version", _build_version()], ["host", DEDICATED_SERVER_HOST], ["port", str(DEDICATED_SERVER_PORT)], ["capacity", str(_mode_capacity(selected_match_mode))]]:
		SteamManager.steam.call("setLobbyData", lobby_id, pair[0], pair[1])


func _connect_pvp_lobby_to_dedicated_server() -> void:
	if pvp_lobby_id <= 0:
		_fallback_to_dedicated_pvp("Steam-Lobby-ID fehlt.")
		return
	join_dedicated_server()


func _fallback_to_dedicated_pvp(reason: String) -> void:
	print("[Steam PvP] %s Falling back to dedicated matchmaking." % reason)
	pvp_lobby_id = 0
	_pvp_lobby_search_pending = false
	_pvp_lobby_create_pending = false
	_pvp_lobby_join_pending = false
	matchmaking_status_changed.emit(reason + " Dedicated matchmaking is used instead.")
	join_dedicated_server()


func _leave_pvp_lobby() -> void:
	if pvp_lobby_id > 0 and SteamManager.steam != null and SteamManager.steam.has_method("leaveLobby"):
		SteamManager.steam.call("leaveLobby", pvp_lobby_id)


func _mode_capacity(mode: String) -> int:
	return 4 if mode == MODE_TEAM_BATTLE else 2


func _build_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "dev"))


func _steam_coop_supported() -> bool:
	return SteamManager.is_initialized and SteamManager.steam != null and ClassDB.class_exists("SteamMultiplayerPeer")


func _create_steam_multiplayer_peer() -> MultiplayerPeer:
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		return null
	var steam_peer := ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	if steam_peer != null:
		steam_peer.set("no_nagle", true)
	return steam_peer


func show_error(message: String) -> void:
	print("NETWORK ERROR: %s" % message)


func _start_command_line_pvp_test_if_requested() -> void:
	var args := OS.get_cmdline_user_args()
	var host_index := args.find("--pvp-test-host")
	if host_index < 0 or host_index + 1 >= args.size():
		return
	var host := String(args[host_index + 1])
	var port := DEDICATED_SERVER_PORT
	var port_index := args.find("--pvp-test-port")
	if port_index >= 0 and port_index + 1 < args.size():
		port = int(args[port_index + 1])
	call_deferred("join_dedicated_server", host, port)
