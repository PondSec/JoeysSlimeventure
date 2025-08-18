extends Node

var peer: ENetMultiplayerPeer
var is_multiplayer: bool = false

func host_game(port):
	is_multiplayer = true
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port)
	if err != OK:
		print("Fehler beim Erstellen des Servers: ", err)
		return
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	load_game_world()
	print("Server gestartet auf Port", port)

func join_game(ip, port):
	is_multiplayer = true
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		print("Fehler beim Verbinden: ", err)
		return
	
	multiplayer.multiplayer_peer = peer
	
	# Korrekte Signal-Verbindung für Godot 4:
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connection_success():
	print("Erfolgreich mit Server verbunden!")
	load_game_world()

func _on_connection_failed():
	print("Verbindung zum Server fehlgeschlagen!")
	# Hier könnten Sie zum Hauptmenü zurückkehren

func _on_server_disconnected():
	print("Vom Server getrennt!")
	# Hier könnten Sie zum Hauptmenü zurückkehren
	get_tree().reload_current_scene()

func _on_peer_connected(id):
	print("Neuer Client verbunden:", id)

func load_game_world():
	print("Lade Spielwelt...")
	get_tree().change_scene_to_file("res://Scenes/world.tscn")
