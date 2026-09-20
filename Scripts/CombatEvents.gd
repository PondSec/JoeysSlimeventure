extends Node

## Single combat outcome boundary for account-wide achievements and future stats.
signal enemy_defeated(enemy: Node, enemy_type: String, total_defeats: int)

const PLAYER_DAMAGE_META := "player_damage_pending"
const PLAYER_DAMAGE_TIME_META := "player_damage_time_msec"

var reported_enemy_ids: Dictionary = {}


func mark_player_damage(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.set_meta(PLAYER_DAMAGE_META, true)
	target.set_meta(PLAYER_DAMAGE_TIME_META, Time.get_ticks_msec())


func report_enemy_defeated(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_in_group("enemies"):
		return
	var id := enemy.get_instance_id()
	if reported_enemy_ids.has(id):
		return
	# Enemy damage APIs currently do not take an attacker parameter. Every
	# player-owned attack marks its target before applying damage, so only a
	# death following player damage enters achievements/statistics.
	if not bool(enemy.get_meta(PLAYER_DAMAGE_META, false)):
		return
	reported_enemy_ids[id] = true
	var enemy_type := String(enemy.get_meta("chapter_enemy_type", enemy.name))
	var total_defeats := SaveService.increment_stat("enemies_defeated")
	enemy_defeated.emit(enemy, enemy_type, total_defeats)


func _process(_delta: float) -> void:
	# The dictionary only deduplicates living instances; clean stale IDs without
	# retaining every enemy ever spawned during a long session.
	if reported_enemy_ids.size() > 256:
		reported_enemy_ids.clear()
