extends Node2D

## Shared arena replication for ENet PvP and SteamMultiplayerPeer friends co-op.

const PLAYER_SCENE := preload("res://Scenes/player.tscn")
const PVP_MAX_HIT_RANGE := 240.0
const PVP_HIT_COOLDOWN_MSEC := 180
const PVP_FALL_DEATH_Y := 650.0

@onready var pause_menu: Node = get_node_or_null("PauseMenu")
var _last_hit_at: Dictionary = {}
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _chat_message_count := 0
var _received_chat_messages: Array[String] = []
var _player_names: Dictionary = {}
var _join_announced: Dictionary = {}
var _local_player_name := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_local_player_name = _resolve_local_player_name()
	_connect_steam_name_updates()
	if multiplayer.is_server() and _is_dedicated_server_runtime():
		# A dedicated authority is not a playable combatant. Spawning a fake
		# server avatar caused it to load local saves/API state and made it a
		# target in public matches.
		return
	_spawn_player(multiplayer.get_unique_id(), _spawn_position(multiplayer.get_unique_id()))
	if not multiplayer.is_server():
		_request_existing_players.rpc_id(1)
		_register_local_player_name()
	_create_chat_overlay()


@rpc("any_peer", "reliable")
func _request_existing_players() -> void:
	if not multiplayer.is_server():
		return
	var joining_peer := multiplayer.get_remote_sender_id()
	for player_id in _player_ids():
		var player := get_node_or_null(str(player_id)) as Node2D
		if player != null:
			_spawn_player_for_peer.rpc_id(joining_peer, player_id, player.global_position)
	_sync_player_names.rpc_id(joining_peer, _player_names)
	# This arrives after all reliable spawn messages from this server. Until then
	# the joining player's avatar is deliberately unable to publish movement or
	# animation RPCs to peers which may not have its node path yet.
	_grant_replication_ready.rpc_id(joining_peer)


@rpc("authority", "reliable")
func _spawn_player_for_peer(player_id: int, spawn_position: Vector2) -> void:
	_spawn_player(player_id, spawn_position)


@rpc("authority", "reliable")
func _grant_replication_ready() -> void:
	var local_player := get_node_or_null(str(multiplayer.get_unique_id()))
	if local_player != null:
		local_player.set("multiplayer_replication_ready", true)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_player_names[peer_id] = _fallback_player_name(peer_id)
		# The joining peer must receive all existing paths first. Reliable RPCs
		# preserve this ordering, so old clients get the new avatar before it can
		# publish state and the new client gets every old avatar before its own
		# state publishing is enabled.
		for player_id in _player_ids():
			var existing_player := get_node_or_null(str(player_id)) as Node2D
			if existing_player != null:
				_spawn_player_for_peer.rpc_id(peer_id, player_id, existing_player.global_position)
		var spawn_position := _spawn_position(peer_id)
		_spawn_player(peer_id, spawn_position)
		_spawn_player_for_peer.rpc(peer_id, spawn_position)
		_grant_replication_ready.rpc_id(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	var departed_name := _player_label(peer_id)
	_player_names.erase(peer_id)
	_join_announced.erase(peer_id)
	var player := get_node_or_null(str(peer_id))
	if player != null:
		player.queue_free()
	if multiplayer.is_server():
		_broadcast_chat.rpc("[color=#ffc978]%s left the arena.[/color]" % departed_name)


func _spawn_player(peer_id: int, spawn_position: Vector2) -> void:
	if has_node(str(peer_id)):
		return
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	if player.has_method("configure_pvp_arena_camera"):
		player.call("configure_pvp_arena_camera")
	if not multiplayer.is_server() and peer_id == multiplayer.get_unique_id():
		player.set("multiplayer_replication_ready", false)
	add_child(player)
	player.global_position = spawn_position
	if player.has_method("set_world_fall_death_y"):
		player.call("set_world_fall_death_y", PVP_FALL_DEATH_Y)


func _register_local_player_name(registered_name: String = "") -> void:
	_local_player_name = _sanitize_player_name(registered_name, multiplayer.get_unique_id()) if not registered_name.strip_edges().is_empty() else _resolve_local_player_name()
	if multiplayer.is_server():
		_player_names[multiplayer.get_unique_id()] = _local_player_name
		_sync_player_names.rpc(_player_names)
	else:
		_register_player_name.rpc_id(1, _local_player_name)


@rpc("any_peer", "reliable")
func _register_player_name(requested_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_player_names[peer_id] = _sanitize_player_name(requested_name, peer_id)
	_sync_player_names.rpc(_player_names)
	if not _join_announced.has(peer_id):
		_join_announced[peer_id] = true
		_broadcast_chat.rpc("[color=#9dffb1]%s joined the arena.[/color]" % _player_label(peer_id))


@rpc("authority", "reliable")
func _sync_player_names(names: Dictionary) -> void:
	_player_names = names.duplicate()


func _connect_steam_name_updates() -> void:
	var steam_manager := get_node_or_null("/root/SteamManager")
	if steam_manager != null and steam_manager.has_signal("initialized"):
		var callback := Callable(self, "_on_steam_initialized")
		if not steam_manager.is_connected("initialized", callback):
			steam_manager.connect("initialized", callback)


func _on_steam_initialized(persona_name: String) -> void:
	if not persona_name.strip_edges().is_empty():
		_local_player_name = _sanitize_player_name(persona_name, multiplayer.get_unique_id())
		_register_local_player_name()


func _resolve_local_player_name() -> String:
	var steam_manager := get_node_or_null("/root/SteamManager")
	if steam_manager != null:
		var persona_name := String(steam_manager.get("user_name"))
		if not persona_name.strip_edges().is_empty():
			return _sanitize_player_name(persona_name, multiplayer.get_unique_id())
	return _fallback_player_name(multiplayer.get_unique_id())


func _sanitize_player_name(value: String, peer_id: int) -> String:
	var sanitized := value.strip_edges().replace("[", "(").replace("]", ")").replace("\n", " ").replace("\r", " ")
	sanitized = sanitized.substr(0, 32)
	return sanitized if not sanitized.is_empty() else _fallback_player_name(peer_id)


func _fallback_player_name(peer_id: int) -> String:
	return "Player %d" % peer_id


func request_pvp_hit(target_peer_id: int, damage: int, attack_origin: Vector2) -> void:
	if multiplayer.is_server():
		_validate_and_apply_pvp_hit(multiplayer.get_unique_id(), target_peer_id, damage, attack_origin)
	else:
		_submit_pvp_hit.rpc_id(1, target_peer_id, damage, attack_origin)


@rpc("any_peer", "reliable")
func _submit_pvp_hit(target_peer_id: int, damage: int, attack_origin: Vector2) -> void:
	if not multiplayer.is_server():
		return
	_validate_and_apply_pvp_hit(multiplayer.get_remote_sender_id(), target_peer_id, damage, attack_origin)


func _validate_and_apply_pvp_hit(attacker_peer_id: int, target_peer_id: int, damage: int, attack_origin: Vector2) -> void:
	if attacker_peer_id == target_peer_id:
		_debug_rejected_hit("self", attacker_peer_id, target_peer_id)
		return
	var attacker := get_node_or_null(str(attacker_peer_id)) as Node2D
	var target := get_node_or_null(str(target_peer_id)) as Node2D
	if attacker == null or target == null:
		_debug_rejected_hit("missing avatar", attacker_peer_id, target_peer_id)
		return
	# Clients may report an animation-origin, but never a position outside their
	# actual authoritative avatar. This prevents remote melee damage spoofing.
	if attacker.global_position.distance_to(attack_origin) > 100.0:
		_debug_rejected_hit("invalid origin", attacker_peer_id, target_peer_id)
		return
	if attacker.global_position.distance_to(target.global_position) > PVP_MAX_HIT_RANGE:
		_debug_rejected_hit("out of range", attacker_peer_id, target_peer_id)
		return
	var now := Time.get_ticks_msec()
	var last_hit := int(_last_hit_at.get(attacker_peer_id, 0))
	if now - last_hit < PVP_HIT_COOLDOWN_MSEC:
		_debug_rejected_hit("cooldown", attacker_peer_id, target_peer_id)
		return
	_last_hit_at[attacker_peer_id] = now
	var safe_damage := clampi(damage, 1, 45)
	# Damage is invoked only by the authoritative match host/server, but executes
	# on the victim's authority so local UI, animation and death flow stay intact.
	target.take_damage.rpc_id(target_peer_id, safe_damage, attacker.global_position)
	# Combat feedback stays visual/audio only. The shared chat is reserved for
	# players and match events, never a noisy entry for every single hit.
	if OS.is_debug_build():
		print("[PvP] Accepted hit %d -> %d for %d" % [attacker_peer_id, target_peer_id, safe_damage])


@rpc("any_peer", "reliable")
func report_pvp_death(fell_from_arena: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 0:
		return
	var event_text := "%s fell from the arena." if fell_from_arena else "%s was eliminated."
	_broadcast_chat.rpc("[color=#ff9a86]" + event_text % _player_label(peer_id) + "[/color]")


func _debug_rejected_hit(reason: String, attacker_peer_id: int, target_peer_id: int) -> void:
	if OS.is_debug_build():
		print("[PvP] Rejected hit (%s) %d -> %d" % [reason, attacker_peer_id, target_peer_id])


func send_chat(text: String) -> void:
	var message := _sanitize_chat_message(text)
	if message.is_empty():
		return
	if multiplayer.is_server():
		_broadcast_chat.rpc("[color=#93dcff]%s:[/color] %s" % [_player_label(multiplayer.get_unique_id()), message])
	else:
		if OS.is_debug_build():
			print("[PvP Chat] Sending message to server")
		_submit_chat.rpc_id(1, message)


@rpc("any_peer", "reliable")
func _submit_chat(message: String) -> void:
	if multiplayer.is_server():
		var sender := multiplayer.get_remote_sender_id()
		var safe_message := _sanitize_chat_message(message)
		if safe_message.is_empty():
			return
		if OS.is_debug_build():
			print("[PvP Chat] Relaying message from %d" % sender)
		_broadcast_chat.rpc("[color=#93dcff]%s:[/color] %s" % [_player_label(sender), safe_message])


@rpc("authority", "reliable")
func _broadcast_chat(message: String) -> void:
	if OS.is_debug_build():
		print("[PvP Chat] Received message: %s" % message)
	if _chat_log != null:
		_chat_message_count += 1
		_received_chat_messages.append(message)
		_chat_log.append_text(message + "\n")
		_chat_log.scroll_to_line(_chat_log.get_line_count())


func _create_chat_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	panel.offset_left = 24.0
	panel.offset_top = -270.0
	panel.offset_right = 470.0
	panel.offset_bottom = -24.0
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.fit_content = false
	_chat_log.custom_minimum_size = Vector2(420, 184)
	_chat_log.scroll_active = true
	box.add_child(_chat_log)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Enter: Chat  •  Team up, fight hard"
	_chat_input.max_length = 180
	_chat_input.text_submitted.connect(_on_chat_submitted)
	box.add_child(_chat_input)
	_broadcast_chat("[color=#9dffb1]Arena chat ready — good luck, have fun![/color]") if multiplayer.is_server() else _chat_log.append_text("[color=#9dffb1]Arena chat ready — good luck, have fun![/color]\n")


func _on_chat_submitted(text: String) -> void:
	send_chat(text)
	if _chat_input != null:
		_chat_input.clear()


func _player_label(peer_id: int) -> String:
	return String(_player_names.get(peer_id, _fallback_player_name(peer_id)))


func _sanitize_chat_message(value: String) -> String:
	# Chat is displayed through RichTextLabel. Keep player-entered text literal so
	# it cannot inject BBCode into the arena UI.
	return value.strip_edges().replace("[", "(").replace("]", ")").replace("\n", " ").replace("\r", " ").substr(0, 180)


func _player_ids() -> Array[int]:
	var result: Array[int] = []
	for child in get_children():
		if child is CharacterBody2D and String(child.name).is_valid_int():
			result.append(int(child.name))
	return result


func _spawn_position(peer_id: int) -> Vector2:
	var spawn_points := get_tree().get_nodes_in_group("spawn_points")
	if spawn_points.is_empty():
		return Vector2(100.0 + 140.0 * (peer_id % 5), 300.0)
	return (spawn_points[peer_id % spawn_points.size()] as Node2D).global_position


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Pause") and pause_menu != null and pause_menu.has_method("toggle_pause"):
		pause_menu.call("toggle_pause")


func _is_dedicated_server_runtime() -> bool:
	return "--dedicated-server" in OS.get_cmdline_args() or "--dedicated-server" in OS.get_cmdline_user_args()
