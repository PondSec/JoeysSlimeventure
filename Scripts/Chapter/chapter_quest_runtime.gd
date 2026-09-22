class_name ChapterQuestRuntime
extends Node

# A deliberately small event-driven quest layer.  It owns only Chapter-quest
# state and presentation; combat, movement, portals and saving remain in their
# established systems.

signal objective_progressed(objective_id: String, current: int, required: int)
signal quest_completed

const TILE_SIZE := 32.0
const DRAFT_ROOT := "res://Assets/Chapter/QuestDraft/QuestObjects/"
const RESONANCE_BELL_FRAMES := [
	"res://Assets/Chapter/QuestDraft/QuestObjects/resonance/frame1_bell_pixel_128x128.png",
	"res://Assets/Chapter/QuestDraft/QuestObjects/resonance/frame2_bell_pixel_128x128.png",
	"res://Assets/Chapter/QuestDraft/QuestObjects/resonance/frame3_bell_pixel_128x128.png",
	"res://Assets/Chapter/QuestDraft/QuestObjects/resonance/frame4_bell_pixel_128x128.png",
	"res://Assets/Chapter/QuestDraft/QuestObjects/resonance/frame5_bell_pixel_128x128.png",
	"res://Assets/Chapter/QuestDraft/QuestObjects/resonance/frame6_bell_pixel_128x128.png",
	"res://Assets/Chapter/QuestDraft/QuestObjects/resonance/frame7_bell_pixel_128x128.png"
]
const RESONANCE_HIT_ANIMATION_FPS := 3.5
const RESONANCE_CAMERA_PAN_SECONDS := 2.2
const RESONANCE_CAMERA_HOLD_SECONDS := 2.0

var level: Dictionary = {}
var quest: Dictionary = {}
var player: Node2D
var gate: Node2D
var host: Node
var objective_state: Dictionary = {}
var objects: Array[Dictionary] = []
var wisp: Sprite2D
var wisp_checkpoint := Vector2.ZERO
var tracker: Label
var draft_badge: Label
var local_time := 0.0
var boss: Node2D
var resonance_preview_active := false


func configure(new_level: Dictionary, new_player: Node2D, new_gate: Node2D, new_host: Node, ui_layer: CanvasLayer) -> void:
	level = new_level
	quest = level.get("quest", {}) as Dictionary
	player = new_player
	gate = new_gate
	host = new_host
	if quest.is_empty() or player == null:
		return
	_setup_objective_state()
	_restore_persisted_state()
	_setup_tracker(ui_layer)
	_spawn_quest_objects()
	_lock_exit()
	_connect_boss()
	if _has_combat_condensers():
		_show_feedback("Kristallkondensatoren laden sich auf, wenn du Gegner in ihrem orangenen Bereich besiegst.", "info")
	if _has_level_two_resonance():
		# This first preview is deliberately user-led: the level transition and
		# title finish first, then Joey's first intentional movement starts it.
		call_deferred("_play_resonance_sequence_preview", true)
	if _all_objectives_complete():
		_unlock_exit()


func _setup_objective_state() -> void:
	for objective_variant: Variant in quest.get("objectives", []) as Array:
		var objective: Dictionary = objective_variant as Dictionary
		objective_state[str(objective.get("id", ""))] = {"current": 0, "required": int(objective.get("required", 1)), "events": {}}


func _setup_tracker(ui_layer: CanvasLayer) -> void:
	if ui_layer == null:
		return
	tracker = Label.new()
	tracker.name = "QuestTracker"
	# Player vitals, glow meter and the combat banner intentionally own the
	# upper-left/centre.  Keep quests in an anchored safe area on the opposite
	# side so every target resolution has a stable, non-overlapping layout.
	tracker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tracker.anchor_left = 1.0
	tracker.anchor_right = 1.0
	tracker.offset_left = -454.0
	tracker.offset_top = 30.0
	tracker.offset_right = -28.0
	tracker.offset_bottom = 146.0
	tracker.size = Vector2(426.0, 116.0)
	tracker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tracker.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_theme_font_size_override("font_size", 18)
	tracker.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0, 0.96))
	tracker.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.94))
	tracker.add_theme_constant_override("outline_size", 5)
	ui_layer.add_child(tracker)
	draft_badge = Label.new()
	draft_badge.name = "QuestDraftAssetBadge"
	draft_badge.text = "QUEST-ASSETS · DRAFT / NICHT FINAL"
	draft_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	draft_badge.anchor_left = 1.0
	draft_badge.anchor_right = 1.0
	draft_badge.offset_left = -454.0
	draft_badge.offset_top = 150.0
	draft_badge.offset_right = -28.0
	draft_badge.offset_bottom = 168.0
	draft_badge.size = Vector2(426.0, 18.0)
	draft_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draft_badge.add_theme_font_size_override("font_size", 10)
	draft_badge.add_theme_color_override("font_color", Color(1.0, 0.78, 0.34, 0.82))
	draft_badge.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.9))
	draft_badge.add_theme_constant_override("outline_size", 3)
	ui_layer.add_child(draft_badge)
	_refresh_tracker()


func _spawn_quest_objects() -> void:
	var anchors: Array = level.get("quest_anchors", []) as Array
	for anchor_variant: Variant in anchors:
		var anchor: Dictionary = anchor_variant as Dictionary
		var objective := _objective_by_id(str(anchor.get("objective_id", "")))
		if objective.is_empty():
			continue
		_spawn_object(anchor, objective)
	# Trials have compact sub-steps without inflating the data-model objective
	# count.  They intentionally reuse the already validated parent anchor.
	for objective_variant: Variant in quest.get("objectives", []) as Array:
		var objective: Dictionary = objective_variant as Dictionary
		var kind := str(objective.get("type", ""))
		if kind == "traversal":
			_spawn_substeps(str(objective.get("id", "")), "motion_sigil", int(objective.get("chain_count", 4)))
		elif kind == "timing":
			_spawn_substeps(str(objective.get("id", "")), "light_rune", int(objective.get("rune_count", 3)))
	_refresh_tracker()


func _spawn_object(anchor: Dictionary, objective: Dictionary) -> void:
	var kind := str(objective.get("type", ""))
	var visual_kind := _visual_for_type(kind)
	var node := Area2D.new()
	node.name = "QuestDraft_%s" % str(anchor.get("id", "target"))
	node.collision_layer = 0
	node.collision_mask = 1
	node.monitoring = true
	var sprite := Sprite2D.new()
	var level_two_resonance := _is_level_two_resonance(kind)
	sprite.texture = _resonance_bell_texture(0) if level_two_resonance else load(DRAFT_ROOT + _texture_for_visual(visual_kind)) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var level_one_vein := _is_level_one_vein(kind)
	# The replacement Tropfenader art is a 128 px sprite, unlike the 64 px
	# draft objects used elsewhere. Keep only this first-level asset compact.
	sprite.scale = Vector2(0.54, 0.54) if level_one_vein else (Vector2(0.46, 0.46) if level_two_resonance else Vector2(0.72, 0.72))
	sprite.name = "DraftAsset_NotFinal"
	node.add_child(sprite)
	if kind == "combat_zone":
		var combat_label := Label.new()
		combat_label.name = "CombatCondenserInstruction"
		combat_label.text = "BESIEGE GEGNER\nIN DIESEM BEREICH"
		combat_label.position = Vector2(-88.0, -82.0)
		combat_label.size = Vector2(176.0, 36.0)
		combat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		combat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		combat_label.add_theme_font_size_override("font_size", 12)
		combat_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.55, 1.0))
		combat_label.add_theme_color_override("font_outline_color", Color(0.18, 0.05, 0.02, 1.0))
		combat_label.add_theme_constant_override("outline_size", 4)
		node.add_child(combat_label)
	var sequence_order := 0
	if level_two_resonance:
		sequence_order = _sequence_display_order(objective, _anchor_index(anchor))
	var glow := PointLight2D.new()
	glow.texture = load("res://Assets/Light/light.webp") as Texture2D
	if level_one_vein:
		# The lamp sits visibly over the vein rather than bleaching its centre.
		# It remains white in both states and expands slightly when awakened.
		glow.position = Vector2(0.0, -42.0)
		glow.energy = 0.46
		glow.texture_scale = 0.13
		glow.color = Color.WHITE
	elif level_two_resonance:
		glow.position = Vector2(0.0, -30.0)
		glow.energy = 0.26
		glow.texture_scale = 0.11
		glow.color = Color(0.72, 0.90, 1.0, 1.0)
	else:
		glow.energy = 0.34
		glow.texture_scale = 0.09
		glow.color = _color_for_type(kind)
	node.add_child(glow)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = _radius_for_type(kind)
	collision.shape = shape
	node.add_child(collision)
	add_child(node)
	var requested_cell: Vector2i = anchor.get("position", Vector2i.ZERO) as Vector2i
	var floor_cell := _resolve_grounded_anchor_cell(requested_cell)
	if floor_cell == Vector2i(-1, -1):
		# Never render a quest target at an unverified semantic/path anchor.  A
		# missing target is preferable to one floating in inaccessible space; the
		# layout validation will surface the malformed level during development.
		node.queue_free()
		push_error("Quest target '%s' has no safe ground near %s." % [str(anchor.get("id", "target")), requested_cell])
		return
	# The generator yields a solid floor cell.  Position the visual by its real
	# footprint, not a fixed magic offset: draft sprites vary from 64 to 128 px
	# and otherwise their lower half can end up inside the cave collision mesh.
	var visual_half_height := _sprite_half_height(sprite)
	node.global_position = Vector2(floor_cell.x * TILE_SIZE + 16.0, floor_cell.y * TILE_SIZE - visual_half_height - 7.0)
	objects.append({"node": node, "sprite": sprite, "glow": glow, "floor_cell": floor_cell, "level_one_vein": level_one_vein, "level_two_resonance": level_two_resonance, "sequence_order": sequence_order, "base_scale": sprite.scale, "objective_id": str(objective.get("id", "")), "kind": kind, "anchor_id": str(anchor.get("id", "")), "index": _anchor_index(anchor), "charge": 0.0, "latch": false, "completed": false, "position": node.global_position})
	if kind == "search":
		_spawn_wisp(node.global_position)
	if kind == "redirect":
		_request_quest_bat(node.global_position, str(anchor.get("id", "")))
	if kind == "combat_zone":
		_request_quest_enemy(node.global_position, str(anchor.get("id", "")))


func _resolve_grounded_anchor_cell(requested_cell: Vector2i) -> Vector2i:
	# Quest anchors describe progression order, not guaranteed collision-safe
	# coordinates.  ChapterLevel owns the final collision grid, so it resolves
	# the nearest broad, walkable floor after all generator repairs have run.
	if host != null and host.has_method("resolve_quest_ground_cell"):
		return host.call("resolve_quest_ground_cell", requested_cell) as Vector2i
	# Kept only for isolated runtime previews without a ChapterLevel host.
	return requested_cell


func _sprite_half_height(sprite: Sprite2D) -> float:
	if sprite == null or sprite.texture == null:
		return 20.0
	return float(sprite.texture.get_height()) * absf(sprite.scale.y) * 0.5


func _spawn_substeps(objective_id: String, kind: String, count: int) -> void:
	var parent := _first_object_for(objective_id)
	if parent.is_empty():
		return
	var base: Vector2 = parent.position as Vector2
	for index: int in range(count):
		var node := Area2D.new()
		node.name = "QuestDraft_%s_%d" % [kind, index]
		node.collision_layer = 0
		node.collision_mask = 1
		var sprite := Sprite2D.new()
		sprite.texture = load(DRAFT_ROOT + _texture_for_visual(kind)) as Texture2D
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(0.48, 0.48)
		node.add_child(sprite)
		var shape := CircleShape2D.new()
		shape.radius = 24.0
		var collision := CollisionShape2D.new()
		collision.shape = shape
		node.add_child(collision)
		add_child(node)
		node.global_position = base + Vector2((index - count * 0.5) * 54.0, -42.0 - absf(float(index - count * 0.5)) * 18.0)
		objects.append({"node": node, "sprite": sprite, "objective_id": objective_id, "kind": kind, "anchor_id": "%s_%d" % [kind, index], "index": index, "charge": 0.0, "latch": false, "completed": false, "position": node.global_position})


func _spawn_wisp(position: Vector2) -> void:
	wisp = Sprite2D.new()
	wisp.name = "FriendlyQuestWisp"
	wisp.texture = load(DRAFT_ROOT + "lure_firefly_beacon.png") as Texture2D
	wisp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wisp.scale = Vector2(0.45, 0.45)
	wisp.global_position = position + Vector2(20.0, -18.0)
	add_child(wisp)
	wisp_checkpoint = wisp.global_position


func _process(delta: float) -> void:
	if quest.is_empty() or player == null:
		return
	local_time += delta
	_update_wisp(delta)
	_update_active_updrafts()
	for object_index: int in range(objects.size()):
		var entry: Dictionary = objects[object_index] as Dictionary
		if bool(entry.get("completed", false)):
			if bool(entry.get("level_two_resonance", false)):
				_animate_resonance_bell(entry)
			objects[object_index] = entry
			continue
		_process_object(entry, delta)
		objects[object_index] = entry


func _process_object(entry: Dictionary, delta: float) -> void:
	var node := entry.get("node") as Area2D
	if node == null or not is_instance_valid(node):
		return
	var in_range: bool = player.global_position.distance_to(node.global_position) <= _radius_for_type(str(entry.get("kind", "")))
	var glowing: bool = bool(player.get("is_glowing"))
	var kind := str(entry.get("kind", ""))
	if bool(entry.get("level_two_resonance", false)):
		_animate_resonance_bell(entry)
	match kind:
		"glow_charge":
			if in_range and glowing:
				entry["charge"] = float(entry.get("charge", 0.0)) + delta
				if float(entry.get("charge", 0.0)) >= 1.25: _complete_entry(entry)
			elif float(entry.get("charge", 0.0)) > 0.0:
				entry["charge"] = maxf(0.0, float(entry.get("charge", 0.0)) - delta * 0.35)
		"sequence":
			var attacking := bool(player.get("is_attacking"))
			if in_range and attacking and not bool(entry.get("latch", false)):
				entry["latch"] = true
				_handle_sequence_hit(entry)
			elif not attacking:
				entry["latch"] = false
		"redirect":
			for wave: Node in get_tree().get_nodes_in_group("chapter_ultrasound"):
				if is_instance_valid(wave) and (wave as Node2D).global_position.distance_to(node.global_position) < 46.0:
					_complete_entry(entry)
					break
		"search":
			if in_range and glowing: _complete_entry(entry)
		"escort":
			if _objective_current("find_firefly") > 0 and wisp != null and wisp.global_position.distance_to(node.global_position) < 52.0 and glowing:
				_complete_entry(entry)
		"combat_zone":
			pass # Progress arrives from the existing enemy defeated signal.
		"traversal_chain", "interact":
			if in_range and Input.is_action_pressed("Interact"):
				entry["charge"] = float(entry.get("charge", 0.0)) + delta
				var hold := 1.0 if kind == "interact" else 0.75
				if float(entry.get("charge", 0.0)) >= hold: _complete_entry(entry)
			else:
				entry["charge"] = 0.0
		"motion_sigil":
			if in_range: _handle_motion_sigil(entry)
		"light_rune":
			if in_range and glowing and sin(local_time * 2.0 + float(entry.get("index", 0))) > 0.35: _handle_light_rune(entry)
		"boss_mechanic":
			pass


func _update_wisp(delta: float) -> void:
	if wisp == null or not is_instance_valid(wisp) or _objective_current("find_firefly") <= 0:
		return
	if bool(player.get("is_glowing")):
		var desired := player.global_position + Vector2(-26.0, -28.0)
		wisp.global_position = wisp.global_position.lerp(desired, minf(1.0, delta * 3.4))
	elif wisp.global_position.distance_to(player.global_position) > 520.0:
		wisp.global_position = wisp_checkpoint


func _update_active_updrafts() -> void:
	# Vents are short-lived world state, not a permanent flight ability.  The
	# player retains control while the active column gently supplies lift.
	for entry_variant: Variant in objects:
		var entry: Dictionary = entry_variant as Dictionary
		if str(entry.get("kind", "")) != "traversal_chain" or float(entry.get("active_until", 0.0)) <= local_time:
			continue
		var node := entry.get("node") as Node2D
		if node != null and player.global_position.distance_to(node.global_position) <= 84.0:
			player.velocity.y = minf(player.velocity.y, -360.0)


func _handle_sequence_hit(entry: Dictionary) -> void:
	var objective := _objective_by_id(str(entry.get("objective_id", "")))
	var expected: Array = objective.get("sequence", []) as Array
	var state: Dictionary = objective_state.get(str(entry.get("objective_id", "")), {}) as Dictionary
	var current := int(state.get("current", 0))
	if current < expected.size() and int(expected[current]) == int(entry.get("index", 0)):
		_complete_entry(entry)
	else:
		_reset_sequence_entries(str(entry.get("objective_id", "")))
		state["current"] = 0
		state["events"] = {}
		objective_state[str(entry.get("objective_id", ""))] = state
		_show_feedback("Falscher Klang – die Resonanz beginnt erneut.", "info")
		_refresh_tracker()
		# Repeat the world-space lesson after a mistake, so the player never has
		# to remember the route or infer the next bell from a failed attempt.
		if not resonance_preview_active:
			call_deferred("_play_resonance_sequence_preview", false)


func _reset_sequence_entries(objective_id: String) -> void:
	for object_index: int in range(objects.size()):
		var candidate: Dictionary = objects[object_index] as Dictionary
		if str(candidate.get("objective_id", "")) != objective_id or not bool(candidate.get("level_two_resonance", false)):
			continue
		candidate["completed"] = false
		candidate.erase("resonance_hit_started")
		var sprite := candidate.get("sprite") as Sprite2D
		if sprite != null:
			sprite.modulate = Color.WHITE
			sprite.scale = candidate.get("base_scale", sprite.scale) as Vector2
			sprite.texture = _resonance_bell_texture(0)
		objects[object_index] = candidate


func _handle_motion_sigil(entry: Dictionary) -> void:
	var state: Dictionary = objective_state.get(str(entry.get("objective_id", "")), {}) as Dictionary
	if int(entry.get("index", 0)) != int(state.get("current", 0)):
		state["current"] = 0
		state["events"] = {}
		state["subprogress"] = 0
		objective_state[str(entry.get("objective_id", ""))] = state
		_reset_trial_substeps(str(entry.get("objective_id", "")))
		_refresh_tracker()
		return
	_complete_trial_substep(entry, int(_objective_by_id(str(entry.get("objective_id", ""))).get("chain_count", 4)))


func _handle_light_rune(entry: Dictionary) -> void:
	_complete_trial_substep(entry, int(_objective_by_id(str(entry.get("objective_id", ""))).get("rune_count", 3)))


func _complete_trial_substep(entry: Dictionary, needed: int) -> void:
	if bool(entry.get("completed", false)):
		return
	entry["completed"] = true
	var sprite := entry.get("sprite") as Sprite2D
	if sprite != null:
		sprite.modulate = Color(0.55, 1.0, 0.72, 1.0)
	var objective_id := str(entry.get("objective_id", ""))
	var state: Dictionary = objective_state.get(objective_id, {}) as Dictionary
	state["subprogress"] = int(state.get("subprogress", 0)) + 1
	objective_state[objective_id] = state
	_persist_state()
	if int(state.get("subprogress", 0)) >= needed:
		_record_event(objective_id, "trial_complete")


func _reset_trial_substeps(objective_id: String) -> void:
	for index: int in range(objects.size()):
		var candidate: Dictionary = objects[index] as Dictionary
		if str(candidate.get("objective_id", "")) != objective_id or str(candidate.get("kind", "")) != "motion_sigil":
			continue
		candidate["completed"] = false
		var sprite := candidate.get("sprite") as Sprite2D
		if sprite != null: sprite.modulate = Color.WHITE
		objects[index] = candidate


func report_enemy_defeated(position: Vector2, enemy: Node2D) -> void:
	for object_index: int in range(objects.size()):
		var entry: Dictionary = objects[object_index] as Dictionary
		if str(entry.get("kind", "")) != "combat_zone" or bool(entry.get("completed", false)):
			continue
		var node := entry.get("node") as Node2D
		if node != null and node.global_position.distance_to(position) <= 150.0:
			_complete_entry(entry)
			objects[object_index] = entry
			return
	# The level can never be softlocked by killing a marked enemy outside a field.
	if enemy != null and bool(enemy.get_meta("chapter_quest_enemy", false)):
		var enemy_type := str(enemy.get_meta("chapter_enemy_type", "slime"))
		if enemy_type == "bat":
			_request_quest_bat(position, str(enemy.get_meta("chapter_quest_anchor", "replenish")))
		else:
			_request_quest_enemy(position, "replenish")


func report_boss_slam(position: Vector2) -> void:
	for object_index: int in range(objects.size()):
		var entry: Dictionary = objects[object_index] as Dictionary
		if str(entry.get("kind", "")) == "boss_mechanic" and not bool(entry.get("completed", false)):
			var node := entry.get("node") as Node2D
			if node != null and node.global_position.distance_to(position) <= 165.0:
				_complete_entry(entry)
				objects[object_index] = entry
	if _objective_is_complete("shatter_arena_anchors") and boss != null and boss.has_method("set_quest_anchor_phase"):
		boss.call("set_quest_anchor_phase", true)


func report_boss_defeated() -> void:
	_force_objective_complete("defeat_kristallruecken")


func can_reveal_boss_gate() -> bool:
	return _all_objectives_complete()


func _complete_entry(entry: Dictionary) -> void:
	if bool(entry.get("completed", false)):
		return
	entry["completed"] = true
	var sprite := entry.get("sprite") as Sprite2D
	if sprite != null:
		sprite.modulate = Color(0.55, 1.0, 0.72, 1.0)
		sprite.scale *= 1.16
		if bool(entry.get("level_two_resonance", false)):
			# Unhit bells rest visibly on frame 1. Start their once-only, slower
			# animation only after Joey has struck the correct bell.
			entry["resonance_hit_started"] = local_time
			sprite.texture = _resonance_bell_texture(0)
	var glow := entry.get("glow") as PointLight2D
	if glow != null:
		if bool(entry.get("level_one_vein", false)):
			glow.energy = 0.82
			glow.texture_scale = 0.16
			glow.color = Color.WHITE
		else:
			glow.energy = 0.72
	if str(entry.get("kind", "")) == "traversal_chain":
		entry["active_until"] = local_time + 9.0
	if bool(entry.get("level_two_resonance", false)):
		SteamManager.unlock(SteamManager.ACH_BELL_RINGER)
	if str(entry.get("kind", "")) == "escort":
		if wisp != null:
			wisp_checkpoint = (entry.get("node") as Node2D).global_position
		# The only escort objective is the Chapter I moonbloom pollination
		# sequence. Unlock at the first opened bloom so this reflects the player
		# action, not merely the later level transition.
		if str(entry.get("objective_id", "")) == "pollinate_moonblooms":
			SteamManager.unlock(SteamManager.ACH_MOONFLOWER_BLOOM)
	_record_event(str(entry.get("objective_id", "")), str(entry.get("anchor_id", "")))


func _record_event(objective_id: String, event_id: String) -> void:
	var state: Dictionary = objective_state.get(objective_id, {}) as Dictionary
	if state.is_empty() or (state.get("events", {}) as Dictionary).has(event_id):
		return
	var events: Dictionary = state.get("events", {}) as Dictionary
	events[event_id] = true
	state["events"] = events
	state["current"] = mini(int(state.get("required", 1)), int(state.get("current", 0)) + 1)
	objective_state[objective_id] = state
	_persist_state()
	objective_progressed.emit(objective_id, int(state.get("current", 0)), int(state.get("required", 1)))
	_show_feedback("%s %d / %d" % [_objective_by_id(objective_id).get("title", "Fortschritt"), int(state.get("current", 0)), int(state.get("required", 1))], "reward")
	if _objective_is_complete(objective_id):
		var reward := str(_objective_by_id(objective_id).get("reward", ""))
		if reward == "double_jump" and player.has_method("grant_skill"):
			player.call("grant_skill", reward, true)
	_refresh_tracker()
	if _all_objectives_complete():
		_unlock_exit()


func _force_objective_complete(objective_id: String) -> void:
	var state: Dictionary = objective_state.get(objective_id, {}) as Dictionary
	if state.is_empty() or _objective_is_complete(objective_id): return
	state["current"] = int(state.get("required", 1))
	objective_state[objective_id] = state
	_persist_state()
	_refresh_tracker()
	if _all_objectives_complete(): _unlock_exit()


func _lock_exit() -> void:
	if gate != null:
		gate.set("is_locked", true)
		gate.call("_apply_theme")


func _unlock_exit() -> void:
	if gate != null:
		gate.set("is_locked", false)
		gate.call("_apply_theme")
	_show_feedback("Die Höhle antwortet – der Ausgang erwacht.", "reward")
	quest_completed.emit()


func _connect_boss() -> void:
	for candidate: Node in get_tree().get_nodes_in_group("bosses"):
		boss = candidate as Node2D
		if boss != null:
			if boss.has_signal("ground_slam"): boss.connect("ground_slam", Callable(self, "report_boss_slam"))
			if boss.has_signal("boss_died"): boss.connect("boss_died", Callable(self, "report_boss_defeated"))
			if boss.has_method("set_quest_anchor_phase"): boss.call("set_quest_anchor_phase", false)
			break


func _request_quest_bat(position: Vector2, anchor_id: String) -> void:
	if host != null and host.has_method("spawn_quest_enemy"):
		host.call("spawn_quest_enemy", "bat", position + Vector2(0.0, -68.0), anchor_id)


func _request_quest_enemy(position: Vector2, anchor_id: String) -> void:
	if host != null and host.has_method("spawn_quest_enemy"):
		host.call("spawn_quest_enemy", "slime", position + Vector2(36.0, -16.0), anchor_id)


func _objective_by_id(objective_id: String) -> Dictionary:
	for objective_variant: Variant in quest.get("objectives", []) as Array:
		var objective: Dictionary = objective_variant as Dictionary
		if str(objective.get("id", "")) == objective_id: return objective
	return {}


func _first_object_for(objective_id: String) -> Dictionary:
	for entry_variant: Variant in objects:
		var entry: Dictionary = entry_variant as Dictionary
		if str(entry.get("objective_id", "")) == objective_id: return entry
	return {}


func _objective_current(objective_id: String) -> int:
	return int((objective_state.get(objective_id, {}) as Dictionary).get("current", 0))


func _objective_is_complete(objective_id: String) -> bool:
	var state: Dictionary = objective_state.get(objective_id, {}) as Dictionary
	return not state.is_empty() and int(state.get("current", 0)) >= int(state.get("required", 1))


func _all_objectives_complete() -> bool:
	for objective_id_variant: Variant in objective_state.keys():
		if not _objective_is_complete(str(objective_id_variant)): return false
	return not objective_state.is_empty()


func _anchor_index(anchor: Dictionary) -> int:
	var anchor_id := str(anchor.get("id", ""))
	# String.get_slice() does not support a negative slice index here. Quest IDs
	# such as echo_sequence_0 were therefore all parsed as index zero, making
	# every resonance bell appear to be the first one.
	var suffix := anchor_id.get_slice("_", anchor_id.count("_"))
	return int(suffix) if suffix.is_valid_int() else 0


func _is_level_one_vein(kind: String) -> bool:
	return int(level.get("level_index", -1)) == 0 and kind == "glow_charge"


func _is_level_two_resonance(kind: String) -> bool:
	return int(level.get("level_index", -1)) == 1 and kind == "sequence"


func _resonance_bell_texture(frame_index: int) -> Texture2D:
	var path: String = RESONANCE_BELL_FRAMES[clampi(frame_index, 0, RESONANCE_BELL_FRAMES.size() - 1)]
	return load(path) as Texture2D


func _animate_resonance_bell(entry: Dictionary) -> void:
	var sprite := entry.get("sprite") as Sprite2D
	if sprite == null:
		return
	# Before activation all bells stay on the authored first frame. The ringing
	# motion is a one-shot acknowledgement, never a distracting idle loop.
	if not bool(entry.get("completed", false)):
		sprite.texture = _resonance_bell_texture(0)
		return
	var hit_started := float(entry.get("resonance_hit_started", local_time))
	var frame_index := mini(
		int(floor(maxf(0.0, local_time - hit_started) * RESONANCE_HIT_ANIMATION_FPS)),
		RESONANCE_BELL_FRAMES.size() - 1
	)
	sprite.texture = _resonance_bell_texture(frame_index)


func _sequence_display_order(objective: Dictionary, anchor_index: int) -> int:
	var sequence: Array = objective.get("sequence", []) as Array
	var sequence_index := sequence.find(anchor_index)
	return sequence_index + 1 if sequence_index >= 0 else anchor_index + 1


func _has_level_two_resonance() -> bool:
	return int(level.get("level_index", -1)) == 1 and not _first_object_for("echo_sequence").is_empty()


func _play_resonance_sequence_preview(wait_for_first_player_movement: bool) -> void:
	# Teach the melody through a slow, deliberate camera tour: 1 → 2 → 3. The
	# initial tour waits for Joey's first movement, which keeps it out of the
	# scene transition and lets the player settle into the level first.
	if resonance_preview_active:
		return
	resonance_preview_active = true
	if wait_for_first_player_movement:
		await _wait_for_first_resonance_movement()
	if player == null or not is_instance_valid(player) or _objective_current("echo_sequence") > 0:
		resonance_preview_active = false
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		resonance_preview_active = false
		return
	var ordered_bells := _ordered_resonance_bells()
	if ordered_bells.size() != 3:
		push_error("Resonance preview requires exactly three valid bells.")
		resonance_preview_active = false
		return
	# The tour takes control of the view for several seconds. Joey cannot move
	# or trigger actions while the camera is away from the player.
	var protected_player := player
	_set_resonance_cinematic_protection(protected_player, true)
	var was_smoothed := camera.position_smoothing_enabled
	camera.position_smoothing_enabled = false
	for bell: Dictionary in ordered_bells:
		var bell_node := bell.get("node") as Node2D
		if bell_node == null or not is_instance_valid(bell_node):
			break
		var pan_tween := create_tween()
		pan_tween.tween_property(camera, "global_position", bell_node.global_position + Vector2(0.0, -18.0), RESONANCE_CAMERA_PAN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await pan_tween.finished
		_pulse_resonance_bell(bell)
		await get_tree().create_timer(RESONANCE_CAMERA_HOLD_SECONDS).timeout
	if player != null and is_instance_valid(player) and is_instance_valid(camera):
		var return_tween := create_tween()
		return_tween.tween_property(camera, "global_position", player.global_position, RESONANCE_CAMERA_PAN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await return_tween.finished
	if is_instance_valid(camera):
		camera.position_smoothing_enabled = was_smoothed
	_set_resonance_cinematic_protection(protected_player, false)
	resonance_preview_active = false


func _wait_for_first_resonance_movement() -> void:
	# The fade-out transition lives above the new scene for a short time. Do
	# not accept held input from the old scene as the cue for a camera takeover.
	while _is_scene_transition_running():
		await get_tree().process_frame
	while player != null and is_instance_valid(player):
		await get_tree().physics_frame
		# Horizontal input or a jump is intentional movement; passive settling
		# after spawn does not trigger the camera tour.
		if absf(Input.get_axis("left", "right")) > 0.01 or Input.is_action_just_pressed("up"):
			return


func _is_scene_transition_running() -> bool:
	for node: Node in get_tree().root.get_children():
		if node.name == "Transition" and bool(node.get("transition_running")):
			return true
	return false


func _ordered_resonance_bells() -> Array[Dictionary]:
	var ordered_bells: Array[Dictionary] = []
	for sequence_order: int in range(1, 4):
		var bell := _resonance_bell_for_order(sequence_order)
		var bell_node := bell.get("node") as Node2D
		if bell.is_empty() or bell_node == null or not is_instance_valid(bell_node):
			return []
		ordered_bells.append(bell)
	return ordered_bells


func _set_resonance_cinematic_protection(target_player: Node2D, enabled: bool) -> void:
	if target_player != null and is_instance_valid(target_player) and target_player.has_method("set_quest_cinematic_invulnerable"):
		target_player.call("set_quest_cinematic_invulnerable", enabled)
	if target_player != null and is_instance_valid(target_player) and target_player.has_method("set_quest_cinematic_input_locked"):
		target_player.call("set_quest_cinematic_input_locked", enabled)


func _resonance_bell_for_order(sequence_order: int) -> Dictionary:
	for entry_variant: Variant in objects:
		var entry: Dictionary = entry_variant as Dictionary
		if bool(entry.get("level_two_resonance", false)) and int(entry.get("sequence_order", 0)) == sequence_order:
			return entry
	return {}


func _pulse_resonance_bell(entry: Dictionary) -> void:
	var sprite := entry.get("sprite") as Sprite2D
	var glow := entry.get("glow") as PointLight2D
	var base_scale: Vector2 = entry.get("base_scale", Vector2.ONE) as Vector2
	if sprite != null:
		sprite.modulate = Color.WHITE
	if glow != null:
		glow.color = Color.WHITE
	var pulse := create_tween()
	pulse.set_parallel(true)
	if sprite != null:
		pulse.tween_property(sprite, "scale", base_scale * 1.22, 0.32)
		pulse.tween_property(sprite, "modulate", Color(1.35, 1.55, 1.72, 1.0), 0.32)
	if glow != null:
		glow.color = Color(0.82, 0.96, 1.0, 1.0)
		pulse.tween_property(glow, "energy", 1.9, 0.32)
		pulse.tween_property(glow, "texture_scale", 0.42, 0.32)
	pulse.set_parallel(false)
	pulse.tween_interval(0.86)
	pulse.set_parallel(true)
	if sprite != null:
		pulse.tween_property(sprite, "scale", base_scale, 0.56)
		pulse.tween_property(sprite, "modulate", Color.WHITE, 0.56)
	if glow != null:
		pulse.tween_property(glow, "energy", 0.26, 0.56)
		pulse.tween_property(glow, "texture_scale", 0.11, 0.56)
		pulse.tween_property(glow, "color", Color(0.72, 0.90, 1.0, 1.0), 0.56)


func _visual_for_type(kind: String) -> String:
	return {"glow_charge":"root_heart_idle.png","sequence":"echo_chime_idle.png","redirect":"resonance_lock_intact.png","search":"lure_firefly_beacon.png","escort":"moonbloom_closed.png","combat_zone":"combat_condenser_empty.png","traversal_chain":"wind_vent_idle.png","interact":"breath_core.png","boss_mechanic":"boss_anchor_idle.png"}.get(kind, "sanctuary_sigil_movement.png")


func _texture_for_visual(visual: String) -> String:
	if visual == "motion_sigil": return "sanctuary_sigil_movement.png"
	if visual == "light_rune": return "sanctuary_sigil_light.png"
	return visual


func _color_for_type(kind: String) -> Color:
	return Color(0.58, 0.92, 1.0, 1.0) if kind != "combat_zone" else Color(1.0, 0.62, 0.32, 1.0)


func _radius_for_type(kind: String) -> float:
	return 138.0 if kind == "combat_zone" else 54.0


func _refresh_tracker() -> void:
	if tracker == null: return
	var lines := [str(quest.get("title", "QUEST")).to_upper()]
	for objective_variant: Variant in quest.get("objectives", []) as Array:
		var objective: Dictionary = objective_variant as Dictionary
		var state: Dictionary = objective_state.get(str(objective.get("id", "")), {}) as Dictionary
		lines.append("%s  %d / %d" % [str(objective.get("title", "")), int(state.get("current", 0)), int(state.get("required", 1))])
		if _is_level_two_resonance(str(objective.get("type", ""))):
			lines.append("Schlagfolge: Zahlen 1 → 2 → 3")
		if str(objective.get("type", "")) == "combat_zone":
			lines.append("Besiege Gegner im orangenen Kondensatorbereich")
	tracker.text = "\n".join(lines)


func _has_combat_condensers() -> bool:
	for objective_variant: Variant in quest.get("objectives", []) as Array:
		if str((objective_variant as Dictionary).get("type", "")) == "combat_zone":
			return true
	return false


func _show_feedback(message: String, toast_type: String) -> void:
	if player != null and player.has_method("_show_feedback_toast"):
		player.call("_show_feedback_toast", message, toast_type, null)


func _restore_persisted_state() -> void:
	var progress := get_node_or_null("/root/ChapterProgress")
	if progress == null or not progress.has_method("get_level_quest_state"):
		return
	var saved: Dictionary = progress.call("get_level_quest_state", int(level.get("chapter_index", 0)), int(level.get("level_index", 0))) as Dictionary
	if str(saved.get("quest_id", "")) != str(quest.get("id", "")):
		return
	var saved_objectives: Dictionary = saved.get("objectives", {}) as Dictionary
	for objective_id_variant: Variant in saved_objectives.keys():
		var objective_id := str(objective_id_variant)
		if objective_state.has(objective_id):
			objective_state[objective_id] = (saved_objectives[objective_id_variant] as Dictionary).duplicate(true)


func _persist_state() -> void:
	var progress := get_node_or_null("/root/ChapterProgress")
	if progress != null and progress.has_method("set_level_quest_state"):
		progress.call("set_level_quest_state", int(level.get("chapter_index", 0)), int(level.get("level_index", 0)), {"quest_id": str(quest.get("id", "")), "objectives": objective_state})
