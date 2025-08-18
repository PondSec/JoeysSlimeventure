extends Node

func host_game(port):
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port)
	if err != OK:
		print("Fehler beim Erstellen des Servers: ", err)
		return
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	load_game_world()

func join_game(ip, port):
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		print("Fehler beim Verbinden: ", err)
		return
	
	multiplayer.multiplayer_peer = peer
	# Warte auf Verbindung bevor die Welt geladen wird
	peer.connection_succeeded.connect(_on_connection_success.bind(ip, port))

func _on_connection_success(ip, port):
	print("Erfolgreich verbunden mit ", ip, ":", port)
	load_game_world()

func _on_peer_connected(peer_id):
	print("Neuer Spieler verbunden: ", peer_id)

func load_game_world():
	# Lade die Welt für alle Spieler
	get_tree().change_scene_to_file("res://Scenes/world.tscn")
