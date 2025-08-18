extends Node

# Netzwerk-Funktionen
var current_player_scene = preload("res://Scenes/player.tscn")

func host_game(port):
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	load_game_world()

func join_game(ip, port):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	# Welt wird geladen wenn Verbindung steht

func load_game_world():
	get_tree().change_scene_to_file("res://Scenes/world.tscn")
