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
var _host := "127.0.0.1"
var _port := 5999


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
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(_host, _port)
	if error != OK:
		_fail("Could not create client: %d" % error)
		return
	multiplayer.multiplayer_peer = _peer
	multiplayer.connected_to_server.connect(_on_connected, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(func() -> void: _fail("Connection failed"), CONNECT_ONE_SHOT)
	get_tree().create_timer(12.0).timeout.connect(_finish, CONNECT_ONE_SHOT)


func _on_connected() -> void:
	_connected = true
	get_tree().root.get_node("GameManager").is_multiplayer = true
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
	if ids.size() < 2:
		_fail("Expected two replicated players, got %d" % ids.size())
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
	if _arena.get_node_or_null("ArenaBackdropLayer/Backdrop") == null:
		_fail("Arena backdrop was not created")
		return
	_ground_verified = true
	_replication_verified = true
	# This makes the server-side hit validation exercise the same RPC path as a
	# real melee swing without relying on map-specific spawn distances. Only
	# alpha moves: moving both avatars at the same time made the test itself race
	# the unreliable position channel instead of testing combat deterministically.
	target_player = _arena.get_node_or_null(str(target_id)) as Node2D
	if target_player == null:
		_fail("Target avatar missing")
		return
	if _label == "alpha":
		own_player.global_position = target_player.global_position - Vector2(48.0, 0.0)
		# Position replication is deliberately unreliable in the game. Send a few
		# short-spaced samples here so the integration test validates combat rather
		# than failing because its single synthetic movement datagram was dropped.
		for sample in 4:
			get_tree().create_timer(0.12 * sample).timeout.connect(func() -> void:
				own_player.update_position.rpc(own_player.position, Vector2.ZERO)
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
			own_player.sync_multiplayer_visual_state.rpc(true, str(own_player.get("current_character_id")), true, false, false, "attack")
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
	var chat_log := _arena.get("_chat_log") as RichTextLabel
	var received_messages := _arena.get("_received_chat_messages") as Array
	if chat_log == null or received_messages == null or not received_messages.any(func(message: String) -> bool: return "AlphaSteam:[/color] smoke-chat" in message):
		_fail("Remote chat was not displayed")
		return
	_chat_verified = true
	var remote_player := _arena.get_node_or_null(str(_arena.call("_player_ids").filter(func(id: int) -> bool: return id != multiplayer.get_unique_id())[0]))
	if remote_player == null or not bool(remote_player.get("is_attacking")) or not bool(remote_player.get("is_facing_left")):
		_fail("Remote combat animation state was not replicated")
		return
	_visual_verified = true
	print("[SMOKE beta] PASS: floor, chat, combat, and animation replication")


func _finish() -> void:
	if not _connected:
		_fail("Timed out before connecting")
		return
	if not _replication_verified:
		_fail("Replication verification did not run")
		return
	if _label == "alpha" and not _combat_submitted:
		_fail("Combat request was not submitted")
		return
	if _label == "beta" and (not _ground_verified or not _chat_verified or not _visual_verified):
		_fail("Remote arena checks were incomplete")
		return
	print("[SMOKE %s] PASS: integration complete" % _label)
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("[SMOKE %s] FAIL: %s" % [_label, message])
	get_tree().quit(1)
