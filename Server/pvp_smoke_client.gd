extends Node

## Headless integration client for the dedicated arena. Run two instances with
## different --test-id values; each must see both replicated avatars.

const ARENA_SCENE := preload("res://Scenes/pvp_arena.tscn")

var _peer: ENetMultiplayerPeer
var _arena: Node
var _label := "client"
var _connected := false
var _replication_verified := false
var _combat_submitted := false
var _ground_verified := false
var _chat_verified := false
var _visual_verified := false
var _typing_verified := false
var _fall_respawn_verified := false
var _host := "127.0.0.1"
var _port := 5999
var _test_mode := "classic_pvp"
var _passive_mode_test := false
var _test_steam_lobby_id := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var label_index := args.find("--test-id")
	if label_index >= 0 and label_index + 1 < args.size():
		_label = args[label_index + 1]
	var host_index := args.find("--test-host")
	if host_index >= 0 and host_index + 1 < args.size():
		_host = args[host_index + 1]
	var port_index := args.find("--test-port")
	if port_index >= 0 and port_index + 1 < args.size():
		_port = int(args[port_index + 1])
	var mode_index := args.find("--test-mode")
	if mode_index >= 0 and mode_index + 1 < args.size():
		_test_mode = args[mode_index + 1]
	var steam_lobby_index := args.find("--test-steam-lobby")
	if steam_lobby_index >= 0 and steam_lobby_index + 1 < args.size():
		_test_steam_lobby_id = int(args[steam_lobby_index + 1])
	_passive_mode_test = "--test-passive" in args
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(_host, _port)
	if error != OK:
		_fail("Could not create client: %d" % error)
		return
	multiplayer.multiplayer_peer = _peer
	multiplayer.connected_to_server.connect(_on_connected, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(func() -> void: _fail("Connection failed"), CONNECT_ONE_SHOT)
	# Includes the three-second arena respawn after a verified fall.  Keep this
	# longer than the combat exchange so the regression test observes the full
	# death/respawn round trip instead of only the initial fall.
	get_tree().create_timer(9.0 if _passive_mode_test else 16.0).timeout.connect(_finish, CONNECT_ONE_SHOT)


func _on_connected() -> void:
	_connected = true
	get_tree().root.get_node("GameManager").is_multiplayer = true
	get_tree().root.get_node("GameManager").selected_match_mode = _test_mode
	get_tree().root.get_node("GameManager").pvp_lobby_id = _test_steam_lobby_id
	_arena = ARENA_SCENE.instantiate()
	get_tree().root.add_child(_arena)
	print("[SMOKE %s] Connected to %s:%d as peer %d" % [_label, _host, _port, multiplayer.get_unique_id()])
	get_tree().create_timer(5.0).timeout.connect(_verify_replication, CONNECT_ONE_SHOT)


func _verify_replication() -> void:
	if _arena == null:
		_fail("Arena was not created")
		return
	var ids: Array[int] = _arena.call("_player_ids")
	print("[SMOKE %s] Replicated player IDs: %s" % [_label, ids])
	var expected_players := 4 if _test_mode == "team_battle" else 2
	if ids.size() < expected_players:
		_fail("Expected %d replicated players, got %d" % [expected_players, ids.size()])
		return
	var own_id: int = multiplayer.get_unique_id()
	var target_id: int = ids.filter(func(id: int) -> bool: return id != own_id)[0]
	var own_player := _arena.get_node_or_null(str(own_id)) as Node2D
	if own_player == null:
		_fail("Own avatar missing")
		return
	if own_player is CharacterBody2D and not (own_player as CharacterBody2D).is_on_floor():
		_fail("Arena spawn has no supporting floor")
		return
	if not bool(own_player.get_node("Camera2D").enabled):
		_fail("Local arena camera was not enabled")
		return
	var target_player := _arena.get_node_or_null(str(target_id)) as Node2D
	if target_player != null and bool(target_player.get_node("Camera2D").enabled):
		_fail("Remote avatar camera hijacked the local view")
		return
	var nameplate := target_player.get_node_or_null("MultiplayerNameplate") if target_player != null else null
	var name_label := nameplate.get_node_or_null("NameText") as Label if nameplate != null else null
	var name_health := nameplate.get_node_or_null("HealthBar") as TextureProgressBar if nameplate != null else null
	if nameplate == null or not nameplate.visible or name_label == null or name_label.text.strip_edges().is_empty():
		_fail("Remote avatar nameplate was not replicated")
		return
	if name_health == null or name_health.texture_under == null or name_health.texture_progress == null:
		_fail("Remote avatar health bar was not built from the pixel assets")
		return
	if _arena.get_node_or_null("ArenaBackdropLayer/CaveBack") == null:
		_fail("Arena backdrop was not created")
		return
	if not _verify_smash_platform_layout():
		return
	_ground_verified = true
	_replication_verified = true
	if _passive_mode_test:
		if _test_mode == "cave_survival" and _arena.get_children().filter(func(node: Node) -> bool: return String(node.name).begins_with("SurvivalEnemy_")).is_empty():
			_fail("Survival wave did not create any room enemy")
			return
		print("[SMOKE %s] PASS: %s room setup" % [_label, _test_mode])
		return
	# This makes the server-side hit validation exercise the same RPC path as a
	# real melee swing without relying on map-specific spawn distances. Only
	# alpha moves: moving both avatars at the same time made the test itself race
	# the unreliable position channel instead of testing combat deterministically.
	target_player = _arena.get_node_or_null(str(target_id)) as Node2D
	if target_player == null:
		_fail("Target avatar missing")
		return
	if _label == "alpha":
		if not _verify_chat_input_keeps_gameplay_hotkeys_quiet(own_player):
			return
		# Keep the real chat field focused while beta verifies the room-wide typing
		# signal. This covers the dot indicator without injecting a fake UI state.
		get_tree().create_timer(3.3).timeout.connect(func() -> void:
			var typing_input := _arena.get("_chat_input") as LineEdit
			if typing_input != null:
				typing_input.grab_focus()
		, CONNECT_ONE_SHOT)
		own_player.global_position = target_player.global_position - Vector2(48.0, 0.0)
		# Position replication is deliberately unreliable in the game. Send a few
		# short-spaced samples here so the integration test validates combat rather
		# than failing because its single synthetic movement datagram was dropped.
		for sample in 4:
			get_tree().create_timer(0.12 * sample).timeout.connect(func() -> void:
				_arena.call("relay_player_position", own_player.position, Vector2.ZERO)
			, CONNECT_ONE_SHOT)
		get_tree().create_timer(1.4).timeout.connect(func() -> void:
			# Register immediately before the reliable chat RPC.  Ordering on the
			# same peer guarantees that the server must apply this display name before
			# formatting the message it broadcasts to the other client.
			_arena.call("_register_local_player_name", "AlphaSteam")
			# Exercise the same client-to-server RPC used by the chat input. Calling
			# the RPC directly keeps this headless test independent of keyboard focus.
			_arena._submit_chat.rpc_id(1, "smoke-chat")
			own_player.set("is_attacking", true)
			own_player.set("is_facing_left", true)
			own_player.call("sync_multiplayer_visual_state", true, str(own_player.get("current_character_id")), true, false, false, "attack")
			_arena.call("relay_player_visual_state", true, str(own_player.get("current_character_id")), true, false, false, "attack")
			_arena.call("request_pvp_hit", target_id, 10, own_player.global_position)
			_combat_submitted = true
			print("[SMOKE alpha] Combat RPC submitted")
		, CONNECT_ONE_SHOT)
	elif _label == "beta":
		get_tree().create_timer(3.0).timeout.connect(_verify_remote_effects, CONNECT_ONE_SHOT)
	print("[SMOKE %s] PASS: peer replication" % _label)


func _verify_remote_effects() -> void:
	var own_player := _arena.get_node_or_null(str(multiplayer.get_unique_id()))
	if own_player == null or not ("current_health" in own_player):
		_fail("Own avatar health was unavailable")
		return
	if int(own_player.get("current_health")) >= int(own_player.get("max_health")):
		_fail("Server-authoritative hit did not reduce target health")
		return
	var own_nameplate := own_player.get_node_or_null("MultiplayerNameplate")
	var own_name_health := own_nameplate.get_node_or_null("HealthBar") as TextureProgressBar if own_nameplate != null else null
	if own_name_health == null or int(own_name_health.value) != int(own_player.get("current_health")):
		_fail("Nameplate health was not synchronized with the approved PvP hit")
		return
	var chat_log := _arena.get("_chat_log") as RichTextLabel
	var received_messages := _arena.get("_received_chat_messages") as Array
	if chat_log == null or received_messages == null or not received_messages.any(func(message: String) -> bool: return "AlphaSteam:[/color] smoke-chat" in message):
		_fail("Remote chat was not displayed")
		return
	if not received_messages.any(func(message: String) -> bool: return "joined the arena" in message):
		_fail("Arena join announcement was not displayed")
		return
	if received_messages.any(func(message: String) -> bool: return "Hit:" in message):
		_fail("Combat hit spam leaked into the arena chat")
		return
	_chat_verified = true
	var remote_player := _arena.get_node_or_null(str(_arena.call("_player_ids").filter(func(id: int) -> bool: return id != multiplayer.get_unique_id())[0]))
	if remote_player == null or not bool(remote_player.get("is_attacking")) or not bool(remote_player.get("is_facing_left")):
		_fail("Remote combat animation state was not replicated")
		return
	var opponent_outline := remote_player.get_node_or_null("PvPOpponentOutline") as Sprite2D
	if opponent_outline == null or not opponent_outline.visible or opponent_outline.texture == null:
		_fail("Remote PvP opponent outline was not rendered")
		return
	_visual_verified = true
	_verify_fall_death_and_respawn(own_player)
	get_tree().create_timer(1.2).timeout.connect(_verify_remote_typing_indicator, CONNECT_ONE_SHOT)
	print("[SMOKE beta] PASS: floor, chat, combat, and animation replication")


func _verify_remote_typing_indicator() -> void:
	var remote_ids: Array[int] = _arena.call("_player_ids").filter(func(id: int) -> bool: return id != multiplayer.get_unique_id())
	if remote_ids.is_empty():
		_fail("Remote player disappeared before typing verification")
		return
	var remote_player := _arena.get_node_or_null(str(remote_ids[0]))
	var typing_indicator := remote_player.get_node_or_null("MultiplayerNameplate/TypingIndicator") as Label if remote_player != null else null
	if typing_indicator == null or not typing_indicator.visible or typing_indicator.text not in [".", "..", "..."]:
		_fail("Remote typing indicator was not visible during chat input")
		return
	_typing_verified = true
	print("[SMOKE beta] PASS: remote typing indicator")


func _verify_fall_death_and_respawn(own_player: Node2D) -> void:
	# A player who leaves every floating island must visibly die and respawn on a
	# real spawn point.  The arena has no invisible safety floor by design.
	own_player.global_position = Vector2(0.0, 700.0)
	get_tree().create_timer(4.2).timeout.connect(func() -> void:
		if not is_instance_valid(own_player):
			_fail("Own avatar disappeared after arena fall")
			return
		if int(own_player.get("current_health")) != int(own_player.get("max_health")):
			_fail("Arena fall did not restore health on respawn")
			return
		if own_player.global_position.y >= 650.0 or not own_player.visible:
			_fail("Arena fall did not return the player to a visible spawn point")
			return
		_fall_respawn_verified = true
		print("[SMOKE beta] PASS: fall death and spawn-point respawn")
	, CONNECT_ONE_SHOT)


func _verify_smash_platform_layout() -> bool:
	var layout := _arena.get_node_or_null("SmashCaveLayout")
	if layout == null:
		_fail("Smash cave platform layout was not created")
		return false
	var cave_tiles := layout.get_node_or_null("CaveTiles") as TileMapLayer
	if cave_tiles == null or cave_tiles.get_used_cells().size() < 50:
		_fail("Arena TileMapLayer did not create the floating cave islands")
		return false
	return true


func _verify_chat_input_keeps_gameplay_hotkeys_quiet(own_player: Node) -> bool:
	var chat_input := _arena.get("_chat_input") as LineEdit
	if chat_input == null:
		_fail("Arena chat input was not created")
		return false
	chat_input.grab_focus()
	var transfer_key := InputEventKey.new()
	transfer_key.keycode = KEY_T
	transfer_key.pressed = true
	own_player.call("_input", transfer_key)
	chat_input.release_focus()
	if get_tree().current_scene.get_node_or_null("Transfer") != null:
		_fail("Typing in arena chat opened the transfer dialog")
		return false
	return true


func _finish() -> void:
	if not _connected:
		_fail("Timed out before connecting")
		return
	if not _replication_verified:
		_fail("Replication verification did not run")
		return
	if _passive_mode_test:
		print("[SMOKE %s] PASS: passive mode integration complete" % _label)
		get_tree().quit(0)
		return
	if _label == "alpha" and not _combat_submitted:
		_fail("Combat request was not submitted")
		return
	if _label == "beta" and (not _ground_verified or not _chat_verified or not _visual_verified or not _typing_verified or not _fall_respawn_verified):
		_fail("Remote arena checks were incomplete")
		return
	print("[SMOKE %s] PASS: integration complete" % _label)
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("[SMOKE %s] FAIL: %s" % [_label, message])
	get_tree().quit(1)
