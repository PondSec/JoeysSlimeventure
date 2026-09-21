extends Node2D

## Shared arena replication for ENet PvP and SteamMultiplayerPeer friends co-op.

const PLAYER_SCENE := preload("res://Scenes/player.tscn")
const PVP_MAX_HIT_RANGE := 240.0
const PVP_HIT_COOLDOWN_MSEC := 180

@onready var pause_menu: Node = $PauseMenu
var _last_hit_at: Dictionary = {}
var _chat_log: RichTextLabel
var _chat_input: LineEdit


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if multiplayer.is_server() and _is_dedicated_server_runtime():
		# A dedicated authority is not a playable combatant. Spawning a fake
		# server avatar caused it to load local saves/API state and made it a
		# target in public matches.
		return
	_spawn_player(multiplayer.get_unique_id(), _spawn_position(multiplayer.get_unique_id()))
	if not multiplayer.is_server():
		_request_existing_players.rpc_id(1)
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
	var player := get_node_or_null(str(peer_id))
	if player != null:
		player.queue_free()


func _spawn_player(peer_id: int, spawn_position: Vector2) -> void:
	if has_node(str(peer_id)):
		return
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	if not multiplayer.is_server() and peer_id == multiplayer.get_unique_id():
		player.set("multiplayer_replication_ready", false)
	add_child(player)
	player.global_position = spawn_position


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
	_broadcast_chat.rpc("[color=#ffce78]Hit: %s → %s[/color]" % [_player_label(attacker_peer_id), _player_label(target_peer_id)])
	if OS.is_debug_build():
		print("[PvP] Accepted hit %d -> %d for %d" % [attacker_peer_id, target_peer_id, safe_damage])


func _debug_rejected_hit(reason: String, attacker_peer_id: int, target_peer_id: int) -> void:
	if OS.is_debug_build():
		print("[PvP] Rejected hit (%s) %d -> %d" % [reason, attacker_peer_id, target_peer_id])


func send_chat(text: String) -> void:
	var message := text.strip_edges().substr(0, 180)
	if message.is_empty():
		return
	if multiplayer.is_server():
		_broadcast_chat("[color=#93dcff]%s:[/color] %s" % [_player_label(multiplayer.get_unique_id()), message])
	else:
		_submit_chat.rpc_id(1, message)


@rpc("any_peer", "reliable")
func _submit_chat(message: String) -> void:
	if multiplayer.is_server():
		var sender := multiplayer.get_remote_sender_id()
		_broadcast_chat("[color=#93dcff]%s:[/color] %s" % [_player_label(sender), message.strip_edges().substr(0, 180)])


@rpc("authority", "reliable")
func _broadcast_chat(message: String) -> void:
	if _chat_log != null:
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
	return "Player %d" % peer_id


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
