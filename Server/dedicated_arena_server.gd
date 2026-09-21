extends Node

## The arena scene owns player replication. Running it on the authority fixes
## the old per-player solo game stub and gives every client a shared match.

const SERVER_PORT := 5999
const ARENA_SCENE := preload("res://Scenes/world.tscn")


func _ready() -> void:
	print("[PvP Server] Starting dedicated arena on UDP %d" % SERVER_PORT)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(SERVER_PORT, 32)
	if error != OK:
		push_error("[PvP Server] Could not listen on %d: %d" % [SERVER_PORT, error])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	get_tree().root.add_child.call_deferred(ARENA_SCENE.instantiate())
	print("[PvP Server] Ready for players")
