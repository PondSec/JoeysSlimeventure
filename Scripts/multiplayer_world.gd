extends Node2D

## Dedicated-arena authority.  A room is an isolated match: its players,
## round ids, scores and state never interact with another room on this server.

const PLAYER_SCENE = preload("res://Scenes/player.tscn")
const BAT_SCENE = preload("res://Scenes/bat.tscn")
const ALBINO_BAT_SCENE = preload("res://Scenes/albino_bat.tscn")
const WISP_SCENE = preload("res://Scenes/Chapter/Enemies/irrlichtkaefer.tscn")
const BOSS_SCENE = preload("res://Scenes/Chapter/Enemies/kristallruecken.tscn")
const VERSION = "0.0.4.2"
const FIRST_TO_THREE = 3
const HIT_RANGE = 240.0

enum State { WAITING, COUNTDOWN, PLAYING, ROUND_END, RESULTS, WAVE_COUNTDOWN, WAVE_ACTIVE, WAVE_COMPLETE }

var player_names = {}
var player_queue_mode = {}
var queues = {"classic_pvp": [], "team_battle": [], "cave_survival": []}
var rooms = {}
var player_room = {}
var next_room_id = 1
var hit_time = {}
var chat_log: RichTextLabel
var chat_input: LineEdit
var received_chat_messages: Array[String] = []
# Compatibility aliases used by the existing smoke client and debug tooling.
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _received_chat_messages: Array[String] = []
var hud: CanvasLayer
var hud_title: Label
var hud_score: Label
var hud_countdown: Label
var results: Control
var loaded_mode_layout := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.is_server():
		_register_player_name.rpc_id(1, _local_name())
		call_deferred("_request_selected_mode")
	_create_ui()


func _process(_delta: float) -> void:
	if not multiplayer.is_server(): return
	for room_id in rooms.keys():
		var room: Dictionary = rooms[room_id]
		if int(room.state) == State.WAVE_ACTIVE:
			_check_wave(room_id)


func _request_selected_mode() -> void:
	_request_queue.rpc_id(1, GameManager.selected_match_mode if not GameManager.selected_match_mode.is_empty() else "classic_pvp", VERSION)


@rpc("any_peer", "reliable")
func _request_existing_players() -> void:
	if not multiplayer.is_server(): return
	# Kept as a compatibility endpoint for older clients.  Players are spawned
	# only after their room is complete so no lobby or other-room avatar leaks
	# into this client's scene tree.
	pass


@rpc("authority", "reliable")
func _spawn_player_for_peer(id: int, position: Vector2) -> void:
	_spawn_player(id, position)


@rpc("authority", "reliable")
func _grant_replication_ready() -> void:
	var me = get_node_or_null(str(multiplayer.get_unique_id()))
	if me != null: me.multiplayer_replication_ready = true


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server(): return
	player_names[id] = _fallback_name(id)


func _on_peer_disconnected(id: int) -> void:
	_remove_from_queue(id)
	var room_id = int(player_room.get(id, 0))
	player_names.erase(id)
	var player = get_node_or_null(str(id))
	if player != null: player.queue_free()
	if room_id > 0 and rooms.has(room_id):
		var room: Dictionary = rooms[room_id]
		if not bool(room.finished):
			_finish_room(room_id, "OPPONENT LEFT", _opposing_team(room, id))


func _register_local_player_name(registered_name: String = "") -> void:
	var name = registered_name if not registered_name.strip_edges().is_empty() else _local_name()
	if multiplayer.is_server(): player_names[multiplayer.get_unique_id()] = _safe_name(name, multiplayer.get_unique_id())
	else: _register_player_name.rpc_id(1, name)


func _spawn_player(id: int, position: Vector2) -> void:
	if has_node(str(id)): return
	var player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	if player.has_method("configure_pvp_arena_camera"): player.configure_pvp_arena_camera()
	if not multiplayer.is_server() and id == multiplayer.get_unique_id(): player.multiplayer_replication_ready = false
	add_child(player)
	player.global_position = position
	if player.has_method("set_world_fall_death_y"): player.set_world_fall_death_y(650.0)


@rpc("any_peer", "reliable")
func _register_player_name(value: String) -> void:
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()
	player_names[id] = _safe_name(value, id)


@rpc("any_peer", "reliable")
func _request_queue(mode: String, version: String) -> void:
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()
	if version != VERSION or not queues.has(mode):
		_queue_status.rpc_id(id, "Matchmaking error: incompatible game version.")
		return
	if player_room.has(id): return
	_remove_from_queue(id)
	player_queue_mode[id] = mode
	queues[mode].append(id)
	print("[MATCHMAKING] Searching %s for peer %d" % [mode, id])
	_queue_status.rpc_id(id, "Finding Match…\n%s" % _mode_label(mode))
	_try_create_rooms()


func _remove_from_queue(id: int) -> void:
	var old = String(player_queue_mode.get(id, ""))
	if queues.has(old): queues[old].erase(id)
	player_queue_mode.erase(id)


func _try_create_rooms() -> void:
	for mode in queues.keys():
		var required = 4 if mode == "team_battle" else 2
		while queues[mode].size() >= required:
			var members: Array[int] = []
			for _n in range(required):
				var id = int(queues[mode].pop_front())
				members.append(id)
				player_queue_mode.erase(id)
			_create_room(mode, members)


func _create_room(mode: String, members: Array[int]) -> void:
	var room_id = next_room_id
	next_room_id += 1
	var teams = {}
	var alive = {}
	for index in range(members.size()):
		var id = members[index]
		# Survival is one shared team; Classic assigns the two rivals to opposite
		# teams, while Team Battle assigns the first pair and second pair.
		teams[id] = "A" if mode == "cave_survival" or (mode == "team_battle" and index < 2) or (mode == "classic_pvp" and index == 0) else "B"
		alive[id] = true
		player_room[id] = room_id
	rooms[room_id] = {"id": room_id, "mode": mode, "members": members, "teams": teams, "alive": alive, "scores": {"A": 0, "B": 0}, "state": State.WAITING, "round": 0, "wave": 0, "kills": 0, "bosses": 0, "finished": false, "transitioning": false, "rematch_votes": {}}
	print("[MATCH] Created room %d (%s): %s" % [room_id, mode, members])
	# The authoritative avatars also belong to a room before any client gets a
	# node-RPC path for them.  They deliberately do not exist during queueing.
	for id in members:
		_spawn_player(id, _room_spawn(rooms[room_id], id))
	# Add each room-mate to each client only now.  Every match is isolated even
	# though the UDP server hosts several rooms on one process.
	for receiver in members:
		for visible_id in members:
			var avatar = get_node_or_null(str(visible_id)) as Node2D
			if avatar != null: _spawn_player_for_peer.rpc_id(receiver, visible_id, avatar.global_position)
		_grant_replication_ready.rpc_id(receiver)
		_queue_status.rpc_id(receiver, "MATCH FOUND\n%s" % _mode_label(mode))
	for visible_id in members:
		_broadcast_room_chat(room_id, "[color=#9dffb1]%s joined the arena.[/color]" % player_names.get(visible_id, _fallback_name(visible_id)))
	# RPC node paths for every room mate must exist on every participant before
	# a player-node RPC (reset/freeze) is sent.  The short barrier also avoids
	# a fast client receiving a round packet before its opponent spawn packet.
	call_deferred("_begin_room_after_replication", room_id)


func _begin_room_after_replication(room_id: int) -> void:
	await get_tree().create_timer(0.25).timeout
	if not rooms.has(room_id): return
	if String(rooms[room_id].mode) == "cave_survival": _start_wave(room_id)
	else: _start_round(room_id)


func _start_round(room_id: int) -> void:
	if not rooms.has(room_id): return
	var room: Dictionary = rooms[room_id]
	room.round = int(room.round) + 1
	room.state = State.COUNTDOWN
	room.transitioning = true
	for id in room.members:
		room.alive[id] = true
		_reset_room_avatar.rpc_id(id, id, _room_spawn(room, id), true)
	rooms[room_id] = room
	_sync_room(room_id, "ROUND %d" % int(room.round), "3")
	_countdown(room_id, false)


func _start_wave(room_id: int) -> void:
	if not rooms.has(room_id): return
	var room: Dictionary = rooms[room_id]
	room.wave = int(room.wave) + 1
	room.state = State.WAVE_COUNTDOWN
	room.transitioning = true
	for id in room.members:
		room.alive[id] = true
		_reset_room_avatar.rpc_id(id, id, _room_spawn(room, id), true)
	rooms[room_id] = room
	_sync_room(room_id, "BOSS WAVE %d" % int(room.wave) if int(room.wave) % 5 == 0 else "WAVE %d" % int(room.wave), "3")
	_countdown(room_id, true)


func _countdown(room_id: int, survival: bool) -> void:
	await get_tree().create_timer(1.0).timeout
	if not rooms.has(room_id) or bool(rooms[room_id].finished): return
	_sync_room(room_id, _mode_label(rooms[room_id].mode), "2")
	await get_tree().create_timer(1.0).timeout
	if not rooms.has(room_id) or bool(rooms[room_id].finished): return
	_sync_room(room_id, _mode_label(rooms[room_id].mode), "1")
	await get_tree().create_timer(1.0).timeout
	if not rooms.has(room_id) or bool(rooms[room_id].finished): return
	var room: Dictionary = rooms[room_id]
	room.state = State.WAVE_ACTIVE if survival else State.PLAYING
	room.transitioning = false
	for id in room.members:
		_set_room_avatar_state.rpc_id(id, id, false, true)
	rooms[room_id] = room
	_sync_room(room_id, _mode_label(room.mode), "WAVE %d" % int(room.wave) if survival else "FIGHT!")
	if survival: _spawn_wave_enemies(room_id)


func _room_spawn(room: Dictionary, id: int) -> Vector2:
	var points = get_tree().get_nodes_in_group("spawn_points")
	if points.is_empty(): return Vector2.ZERO
	var index = (room.members as Array).find(id)
	var order = [0, 2, 1, 3] if room.mode == "team_battle" else [0, 1]
	return (points[order[index % order.size()] % points.size()] as Node2D).global_position


# Gameplay RPCs are routed through the always-present arena root.  Sending an
# RPC directly from Player/<peer id> makes Godot resolve that node path before
# it can reject an unrelated room; isolated clients deliberately lack it.
@rpc("authority", "reliable")
func _reset_room_avatar(player_id: int, spawn_position: Vector2, locked: bool) -> void:
	var avatar = get_node_or_null(str(player_id))
	if avatar != null: avatar.reset_for_match_round(spawn_position, locked)


@rpc("authority", "reliable")
func _set_room_avatar_state(player_id: int, locked: bool, managed_life: bool) -> void:
	var avatar = get_node_or_null(str(player_id))
	if avatar != null: avatar.set_match_round_state(locked, managed_life)


@rpc("authority", "reliable")
func _apply_room_player_damage(player_id: int, damage: int, origin: Vector2) -> void:
	var avatar = get_node_or_null(str(player_id))
	if avatar != null: avatar.take_damage(damage, origin)


@rpc("authority", "reliable")
func _eliminate_room_avatar(player_id: int) -> void:
	var avatar = get_node_or_null(str(player_id))
	if avatar != null: avatar.eliminate_for_match()


@rpc("authority", "reliable")
func _receive_room_replication(player_id: int, kind: String, payload: Array) -> void:
	var avatar = get_node_or_null(str(player_id))
	if avatar == null: return
	match kind:
		"position": avatar.update_position(payload[0], payload[1])
		"facing": avatar.sync_facing_direction(payload[0])
		"visual": avatar.sync_multiplayer_visual_state(payload[0], payload[1], payload[2], payload[3], payload[4], payload[5])
		"attack": avatar.sync_attack(payload[0])


func request_pvp_hit(target_id: int, damage: int, origin: Vector2) -> void:
	if multiplayer.is_server(): _validate_hit(multiplayer.get_unique_id(), target_id, damage, origin)
	else: _submit_pvp_hit.rpc_id(1, target_id, damage, origin)


func relay_player_position(position: Vector2, velocity: Vector2) -> void:
	if not multiplayer.is_server(): _submit_player_position.rpc_id(1, position, velocity)


@rpc("any_peer", "unreliable")
func _submit_player_position(position: Vector2, velocity: Vector2) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	# The dedicated avatar is the authoritative combat snapshot.  It must track
	# accepted client movement before range validation or a valid swing would be
	# measured against the original spawn point.
	var avatar := get_node_or_null(str(sender)) as CharacterBody2D
	if avatar != null:
		avatar.position = position
		avatar.velocity = velocity
	_relay_player_rpc(sender, "position", [position, velocity])


func relay_player_facing(facing_left: bool) -> void:
	if not multiplayer.is_server(): _submit_player_facing.rpc_id(1, facing_left)


@rpc("any_peer", "unreliable")
func _submit_player_facing(facing_left: bool) -> void:
	if multiplayer.is_server(): _relay_player_rpc(multiplayer.get_remote_sender_id(), "facing", [facing_left])


func relay_player_visual_state(facing_left: bool, character_id: String, attacking: bool, dashing: bool, transforming: bool, animation_state: String) -> void:
	if not multiplayer.is_server(): _submit_player_visual.rpc_id(1, facing_left, character_id, attacking, dashing, transforming, animation_state)


@rpc("any_peer", "reliable")
func _submit_player_visual(facing_left: bool, character_id: String, attacking: bool, dashing: bool, transforming: bool, animation_state: String) -> void:
	if multiplayer.is_server(): _relay_player_rpc(multiplayer.get_remote_sender_id(), "visual", [facing_left, character_id, attacking, dashing, transforming, animation_state])


func relay_player_attack(combo_step: int) -> void:
	if not multiplayer.is_server(): _submit_player_attack.rpc_id(1, combo_step)


@rpc("any_peer", "reliable")
func _submit_player_attack(combo_step: int) -> void:
	if multiplayer.is_server(): _relay_player_rpc(multiplayer.get_remote_sender_id(), "attack", [combo_step])


func _relay_player_rpc(sender: int, kind: String, payload: Array) -> void:
	var room_id := int(player_room.get(sender, 0))
	if room_id == 0 or not rooms.has(room_id): return
	var avatar := get_node_or_null(str(sender))
	if avatar == null: return
	for receiver in rooms[room_id].members:
		if receiver == sender: continue
		_receive_room_replication.rpc_id(receiver, sender, kind, payload)


@rpc("any_peer", "reliable")
func _submit_pvp_hit(target_id: int, damage: int, origin: Vector2) -> void:
	if multiplayer.is_server(): _validate_hit(multiplayer.get_remote_sender_id(), target_id, damage, origin)


func _validate_hit(attacker_id: int, target_id: int, damage: int, origin: Vector2) -> void:
	var room_id = int(player_room.get(attacker_id, 0))
	if room_id == 0 or room_id != int(player_room.get(target_id, -1)) or not rooms.has(room_id):
		print("[MATCH] Rejected hit: players are not in the same room")
		return
	var room: Dictionary = rooms[room_id]
	if room.mode == "cave_survival" or int(room.state) != State.PLAYING or room.teams.get(attacker_id) == room.teams.get(target_id):
		print("[MATCH] Rejected hit: state=%s mode=%s" % [room.state, room.mode])
		return
	if not bool(room.alive.get(attacker_id, false)) or not bool(room.alive.get(target_id, false)):
		print("[MATCH] Rejected hit: eliminated player")
		return
	var attacker = get_node_or_null(str(attacker_id)) as Node2D
	var target = get_node_or_null(str(target_id)) as Node2D
	if attacker == null or target == null or attacker.global_position.distance_to(origin) > 100.0 or attacker.global_position.distance_to(target.global_position) > HIT_RANGE:
		print("[MATCH] Rejected hit: invalid position")
		return
	var key = "%d:%d" % [attacker_id, target_id]
	if Time.get_ticks_msec() - int(hit_time.get(key, 0)) < 180: return
	hit_time[key] = Time.get_ticks_msec()
	var approved_damage := clampi(damage, 1, 45)
	# Apply the health change on the dedicated node first, then send only the
	# resulting approved hit to the target's room client.
	target.current_health = max(0, int(target.current_health) - approved_damage)
	print("[MATCH] Accepted hit %d -> %d" % [attacker_id, target_id])
	_apply_room_player_damage.rpc_id(target_id, target_id, approved_damage, attacker.global_position)


@rpc("any_peer", "reliable")
func report_pvp_death(_fell: bool) -> void:
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()
	var room_id = int(player_room.get(id, 0))
	if room_id == 0 or not rooms.has(room_id): return
	var room: Dictionary = rooms[room_id]
	if int(room.state) not in [State.PLAYING, State.WAVE_ACTIVE] or not bool(room.alive.get(id, false)): return
	room.alive[id] = false
	rooms[room_id] = room
	_eliminate_room_avatar.rpc_id(id, id)
	if room.mode == "cave_survival":
		for value in room.alive.values():
			if bool(value): return
		_finish_room(room_id, "RUN OVER", "")
		return
	var winner = _round_winner(room)
	if not winner.is_empty(): _end_round(room_id, winner)


func _round_winner(room: Dictionary) -> String:
	for team in ["A", "B"]:
		var has_member = false
		var alive_member = false
		for id in room.members:
			if room.teams[id] == team:
				has_member = true
				alive_member = alive_member or bool(room.alive[id])
		if has_member and not alive_member: return "B" if team == "A" else "A"
	return ""


func _end_round(room_id: int, winner: String) -> void:
	if not rooms.has(room_id): return
	var room: Dictionary = rooms[room_id]
	if bool(room.transitioning): return
	room.transitioning = true
	room.state = State.ROUND_END
	room.scores[winner] = int(room.scores[winner]) + 1
	rooms[room_id] = room
	_sync_room(room_id, "ROUND WON — %s" % _team_label(winner), "%d : %d" % [room.scores.A, room.scores.B])
	for id in room.members:
		_set_room_avatar_state.rpc_id(id, id, true, true)
	await get_tree().create_timer(2.2).timeout
	if not rooms.has(room_id): return
	room = rooms[room_id]
	if int(room.scores[winner]) >= FIRST_TO_THREE: _finish_room(room_id, "VICTORY", winner)
	else: _start_round(room_id)


func _spawn_wave_enemies(room_id: int) -> void:
	var room: Dictionary = rooms[room_id]
	var plan = _wave_plan(int(room.wave))
	for kind in plan.keys():
		for index in range(int(plan[kind])):
			var enemy_name := "SurvivalEnemy_r%d_w%d_%s_%d" % [room_id, int(room.wave), str(kind), index]
			var position := _enemy_spawn(room_id, index + int(room.wave))
			_spawn_enemy_local(room_id, enemy_name, str(kind), position)
			for member_id in room.members:
				_spawn_enemy.rpc_id(member_id, room_id, enemy_name, str(kind), position)
	_sync_room(room_id, "WAVE %d" % int(room.wave), "Enemies Remaining: %d" % _room_enemy_count(room_id))


func _wave_plan(wave: int) -> Dictionary:
	if wave == 1: return {"bat": 2}
	if wave == 2: return {"bat": 3}
	if wave == 3: return {"bat": 2, "wisp": 1}
	if wave == 4: return {"bat": 2, "albino": 1, "wisp": 1}
	if wave % 5 == 0: return {"boss": 1, "bat": 1 + wave / 10, "wisp": 1 + wave / 10}
	return {"bat": 2 + wave / 4, "albino": 1 + wave / 6, "wisp": 1 + wave / 5}


@rpc("authority", "reliable")
func _spawn_enemy(room_id: int, enemy_name: String, kind: String, position: Vector2) -> void:
	_spawn_enemy_local(room_id, enemy_name, kind, position)


func _spawn_enemy_local(room_id: int, enemy_name: String, kind: String, position: Vector2) -> void:
	if has_node(enemy_name): return
	var scene = BAT_SCENE
	if kind == "albino": scene = ALBINO_BAT_SCENE
	elif kind == "wisp": scene = WISP_SCENE
	elif kind == "boss": scene = BOSS_SCENE
	var enemy = scene.instantiate()
	enemy.set_meta("survival_enemy", true)
	enemy.set_meta("survival_room_id", room_id)
	enemy.name = enemy_name
	add_child(enemy)
	enemy.global_position = position


func _enemy_spawn(room_id: int, index: int) -> Vector2:
	var positions = [Vector2(-430, 200), Vector2(430, 200), Vector2(-270, -40), Vector2(270, -40), Vector2(0, -160)]
	return positions[(room_id + index) % positions.size()]


func _check_wave(room_id: int) -> void:
	if _room_enemy_count(room_id) > 0: return
	var room: Dictionary = rooms[room_id]
	if bool(room.transitioning): return
	room.transitioning = true
	room.state = State.WAVE_COMPLETE
	var plan = _wave_plan(int(room.wave))
	for count in plan.values(): room.kills = int(room.kills) + int(count)
	if int(room.wave) % 5 == 0: room.bosses = int(room.bosses) + 1
	rooms[room_id] = room
	_sync_room(room_id, "WAVE COMPLETE", "Next wave incoming…")
	await get_tree().create_timer(2.5).timeout
	if rooms.has(room_id): _start_wave(room_id)


func _room_enemy_count(room_id: int) -> int:
	var count = 0
	for node in get_children():
		if node.is_in_group("enemies") and bool(node.get_meta("survival_enemy", false)) and int(node.get_meta("survival_room_id", -1)) == room_id:
			var dead = node.get("is_dead")
			if not (dead is bool and dead): count += 1
	return count


func request_survival_enemy_hit(enemy_name: String, damage: int, origin: Vector2, is_crit: bool) -> void:
	if multiplayer.is_server():
		_validate_survival_enemy_hit(multiplayer.get_unique_id(), enemy_name, damage, origin, is_crit)
	else:
		_submit_survival_enemy_hit.rpc_id(1, enemy_name, damage, origin, is_crit)


@rpc("any_peer", "reliable")
func _submit_survival_enemy_hit(enemy_name: String, damage: int, origin: Vector2, is_crit: bool) -> void:
	if multiplayer.is_server():
		_validate_survival_enemy_hit(multiplayer.get_remote_sender_id(), enemy_name, damage, origin, is_crit)


func _validate_survival_enemy_hit(attacker_id: int, enemy_name: String, damage: int, origin: Vector2, is_crit: bool) -> void:
	var room_id := int(player_room.get(attacker_id, 0))
	if room_id == 0 or not rooms.has(room_id): return
	var room: Dictionary = rooms[room_id]
	if room.mode != "cave_survival" or int(room.state) != State.WAVE_ACTIVE or not bool(room.alive.get(attacker_id, false)): return
	var attacker := get_node_or_null(str(attacker_id)) as Node2D
	var enemy := get_node_or_null(enemy_name) as Node2D
	if attacker == null or enemy == null or int(enemy.get_meta("survival_room_id", -1)) != room_id: return
	if attacker.global_position.distance_to(origin) > 100.0 or attacker.global_position.distance_to(enemy.global_position) > HIT_RANGE: return
	var approved_damage := clampi(damage, 1, 60)
	_apply_survival_enemy_damage_local(enemy_name, approved_damage, attacker.global_position, is_crit)
	for member_id in room.members:
		_apply_survival_enemy_damage.rpc_id(member_id, enemy_name, approved_damage, attacker.global_position, is_crit)


@rpc("authority", "reliable")
func _apply_survival_enemy_damage(enemy_name: String, damage: int, source: Vector2, is_crit: bool) -> void:
	_apply_survival_enemy_damage_local(enemy_name, damage, source, is_crit)


func _apply_survival_enemy_damage_local(enemy_name: String, damage: int, source: Vector2, is_crit: bool) -> void:
	var enemy := get_node_or_null(enemy_name)
	if enemy != null and enemy.has_method("take_damage"):
		enemy.call("take_damage", damage, (enemy.global_position - source).normalized(), is_crit)


func _finish_room(room_id: int, headline: String, winner: String) -> void:
	if not rooms.has(room_id): return
	var room: Dictionary = rooms[room_id]
	if bool(room.finished): return
	room.finished = true
	room.state = State.RESULTS
	rooms[room_id] = room
	for id in room.members:
		_set_room_avatar_state.rpc_id(id, id, true, true)
	var detail = "Wave Reached: %d\nEnemies Defeated: %d\nBosses Defeated: %d" % [room.wave, room.kills, room.bosses] if room.mode == "cave_survival" else "%s\n%d : %d" % [_team_winner_name(room, winner), room.scores.A, room.scores.B]
	_sync_room(room_id, headline, detail)
	print("[MATCH] Room %d finished" % room_id)


func request_rematch() -> void:
	if multiplayer.is_server(): _register_rematch_vote(multiplayer.get_unique_id())
	else: _submit_rematch_vote.rpc_id(1)


@rpc("any_peer", "reliable")
func _submit_rematch_vote() -> void:
	if multiplayer.is_server(): _register_rematch_vote(multiplayer.get_remote_sender_id())


func _register_rematch_vote(player_id: int) -> void:
	var room_id := int(player_room.get(player_id, 0))
	if room_id == 0 or not rooms.has(room_id): return
	var room: Dictionary = rooms[room_id]
	if not bool(room.finished): return
	room.rematch_votes[player_id] = true
	rooms[room_id] = room
	for member_id in room.members:
		_queue_status.rpc_id(member_id, "Rematch ready: %d / %d" % [room.rematch_votes.size(), room.members.size()])
	if room.rematch_votes.size() < room.members.size(): return
	var members: Array[int] = room.members.duplicate()
	var mode := String(room.mode)
	for member_id in members: player_room.erase(member_id)
	rooms.erase(room_id)
	_create_room(mode, members)


func _opposing_team(room: Dictionary, id: int) -> String:
	return "B" if room.teams.get(id, "A") == "A" else "A"


func _team_winner_name(room: Dictionary, winner: String) -> String:
	for id in room.members:
		if room.teams[id] == winner: return String(player_names.get(id, _fallback_name(id)))
	return ""


func _sync_room(room_id: int, title: String, emphasis: String) -> void:
	if not rooms.has(room_id): return
	var room: Dictionary = rooms[room_id]
	for id in room.members:
		_sync_room_ui.rpc_id(id, room_id, room.teams, room.scores, room.mode, room.state, title, emphasis)


@rpc("authority", "reliable")
func _sync_room_ui(_room_id: int, teams: Dictionary, scores: Dictionary, mode: String, state: int, title: String, emphasis: String) -> void:
	if hud_title == null: return
	if state != State.RESULTS and results != null:
		results.queue_free()
		results = null
	hud_title.text = title
	hud_score.text = emphasis if state == State.RESULTS else ("WAVE" if mode == "cave_survival" else "%d : %d" % [scores.get("A", 0), scores.get("B", 0)])
	hud_countdown.text = "" if state == State.RESULTS else emphasis
	_apply_team_tint(teams, mode)
	_ensure_mode_layout(mode)
	if state == State.RESULTS: _show_results(title, emphasis, mode)


func _apply_team_tint(teams: Dictionary, mode: String) -> void:
	if mode != "team_battle": return
	var own_team = teams.get(multiplayer.get_unique_id(), "")
	for id in teams.keys():
		var avatar = get_node_or_null(str(id))
		if avatar != null and avatar.has_node("PlayerSprite"):
			avatar.get_node("PlayerSprite").self_modulate = Color.WHITE if teams[id] == own_team else Color(1.0, 0.42, 0.42)


func _ensure_mode_layout(mode: String) -> void:
	if loaded_mode_layout == mode: return
	loaded_mode_layout = mode
	var old_layout := get_node_or_null("ModeArenaLayout")
	if old_layout != null: old_layout.queue_free()
	if mode == "classic_pvp": return
	var layout := Node2D.new()
	layout.name = "ModeArenaLayout"
	add_child(layout)
	var points := [Vector2(-340, 230), Vector2(340, 230), Vector2(-205, 72), Vector2(205, 72)]
	if mode == "cave_survival": points.append_array([Vector2(-405, 115), Vector2(405, 115)])
	for point in points:
		var platform := StaticBody2D.new()
		platform.position = point
		platform.collision_layer = 2
		layout.add_child(platform)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(184, 30)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		platform.add_child(collision)
		var island := Polygon2D.new()
		island.polygon = PackedVector2Array([Vector2(-92, -15), Vector2(92, -15), Vector2(74, 26), Vector2(-74, 26)])
		island.color = Color("476a62") if mode == "cave_survival" else Color("596478")
		platform.add_child(island)


@rpc("authority", "reliable")
func _queue_status(message: String) -> void:
	GameManager.set_matchmaking_state(GameManager.MatchmakingState.WAITING_FOR_PLAYERS, message)
	if hud_title != null: hud_title.text = message


func send_chat(text: String) -> void:
	if text.strip_edges().is_empty(): return
	if multiplayer.is_server():
		var server_room := int(player_room.get(multiplayer.get_unique_id(), 0))
		if server_room > 0: _broadcast_room_chat(server_room, "[color=#93dcff]%s:[/color] %s" % [_local_name(), _sanitize_chat(text)])
	else: _submit_chat.rpc_id(1, _sanitize_chat(text))


@rpc("any_peer", "reliable")
func _submit_chat(text: String) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	var room_id := int(player_room.get(sender, 0))
	if room_id > 0: _broadcast_room_chat(room_id, "[color=#93dcff]%s:[/color] %s" % [player_names.get(sender, "Player"), _sanitize_chat(text)])


func _broadcast_room_chat(room_id: int, text: String) -> void:
	if not rooms.has(room_id): return
	for member_id in rooms[room_id].members:
		_broadcast_chat.rpc_id(member_id, text)


@rpc("authority", "reliable")
func _broadcast_chat(text: String) -> void:
	if chat_log != null:
		received_chat_messages.append(text); _received_chat_messages.append(text); chat_log.append_text(text + "\n")


func _create_ui() -> void:
	hud = CanvasLayer.new(); hud.layer = 90; add_child(hud)
	var box = VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 24); box.offset_left = 420; box.offset_right = -420; hud.add_child(box)
	hud_title = Label.new(); hud_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hud_title.add_theme_font_size_override("font_size", 28); box.add_child(hud_title)
	hud_score = Label.new(); hud_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hud_score.add_theme_font_size_override("font_size", 32); box.add_child(hud_score)
	hud_countdown = Label.new(); hud_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hud_countdown.add_theme_font_size_override("font_size", 42); box.add_child(hud_countdown)
	var panel = PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 18); panel.offset_left = 20; panel.offset_top = -220; panel.offset_right = 430; panel.offset_bottom = -20; hud.add_child(panel)
	var chat_box = VBoxContainer.new(); panel.add_child(chat_box)
	chat_log = RichTextLabel.new(); chat_log.bbcode_enabled = true; chat_log.custom_minimum_size = Vector2(390, 145); chat_box.add_child(chat_log); _chat_log = chat_log
	chat_input = LineEdit.new(); chat_input.placeholder_text = "Enter: Chat"; chat_input.text_submitted.connect(func(value): send_chat(value); chat_input.clear()); chat_box.add_child(chat_input); _chat_input = chat_input


func _show_results(title: String, detail: String, _mode: String) -> void:
	if results != null: results.queue_free()
	results = ColorRect.new(); results.color = Color(0.02, 0.03, 0.07, 0.7); results.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); results.mouse_filter = Control.MOUSE_FILTER_STOP; hud.add_child(results)
	var center = CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); results.add_child(center)
	var panel = PanelContainer.new(); panel.custom_minimum_size = Vector2(600, 410); center.add_child(panel)
	var box = VBoxContainer.new(); box.alignment = BoxContainer.ALIGNMENT_CENTER; panel.add_child(box)
	var heading = Label.new(); heading.text = title; heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; heading.add_theme_font_size_override("font_size", 42); box.add_child(heading)
	var body = Label.new(); body.text = detail; body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; body.add_theme_font_size_override("font_size", 22); box.add_child(body)
	for caption in ["BATTLE AGAIN", "OTHER MODES", "MAIN MENU"]:
		var button = Button.new(); button.text = caption; button.custom_minimum_size = Vector2(300, 48); box.add_child(button)
		if caption == "BATTLE AGAIN": button.pressed.connect(func(): request_rematch())
		else: button.pressed.connect(func(): GameManager.leave_match_to_menu())


func _mode_label(mode: String) -> String:
	if mode == "classic_pvp": return "CLASSIC PvP • 1 vs 1"
	if mode == "team_battle": return "TEAM BATTLE • 2 vs 2"
	return "CAVE SURVIVAL • 2 Players"

func _team_label(team: String) -> String: return "BLUE TEAM" if team == "A" else "RED TEAM"
func _local_name() -> String: return SteamManager.user_name if not SteamManager.user_name.strip_edges().is_empty() else _fallback_name(multiplayer.get_unique_id())
func _safe_name(value: String, id: int) -> String: return value.strip_edges().replace("[", "(").replace("]", ")").substr(0, 32) if not value.strip_edges().is_empty() else _fallback_name(id)
func _fallback_name(id: int) -> String: return "Player %d" % id
func _sanitize_chat(value: String) -> String: return value.strip_edges().replace("[", "(").replace("]", ")").replace("\n", " ").substr(0, 180)
func _spawn_position(id: int) -> Vector2:
	var points = get_tree().get_nodes_in_group("spawn_points")
	return (points[id % points.size()] as Node2D).global_position if not points.is_empty() else Vector2(120 + 120 * (id % 4), 300)
func _player_ids() -> Array[int]:
	var ids: Array[int] = []
	for child in get_children():
		if child is CharacterBody2D and String(child.name).is_valid_int(): ids.append(int(child.name))
	return ids
func _is_dedicated_server() -> bool: return "--dedicated-server" in OS.get_cmdline_args() or "--dedicated-server" in OS.get_cmdline_user_args()
