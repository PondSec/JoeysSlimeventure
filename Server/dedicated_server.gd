extends Node

var peer: ENetMultiplayerPeer
var active_games: Dictionary = {}
var next_game_id: int = 1
var max_players_per_game: int = 4

func _ready():
	print("🚀 Starte dedizierten Server...")
	start_server(5999)

func start_server(port):
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port)
	
	if err != OK:
		print("❌ FEHLER: Port ", port, " ist belegt: ", err)
		get_tree().quit()
		return
	
	print("✅ Dedizierter Server gestartet auf Port ", port)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	print("🔄 Server bereit für Verbindungen")

func _on_peer_connected(id):
	print("👤 Client verbunden: ", id)
	
	# Informiere alle anderen Spieler über den neuen Spieler
	for game_id in active_games:
		for player_id in active_games[game_id].players:
			if player_id != id:
				player_connected_to_game.rpc_id(player_id, id)
	
	# Sofort ein Spiel für den einzelnen Spieler erstellen
	create_solo_game(id)

@rpc("authority", "reliable")
func player_connected_to_game(player_id: int):
	# Wird auf Clients aufgerufen, wenn ein neuer Spieler beitritt
	pass

@rpc("authority", "reliable")
func player_respawned(player_id: int, position: Vector2):
	# Wird auf Clients aufgerufen, wenn ein Spieler respawnt
	pass

func _on_peer_disconnected(id):
	print("❌ Client getrennt: ", id)
	
	# Spieler aus allen Spielen entfernen
	for game_id in active_games.keys():
		var game = active_games[game_id]
		if game.players.has(id):
			game.players.erase(id)
			print("🎮 Spieler ", id, " aus Spiel ", game_id, " entfernt")
			
			# Informiere andere Spieler im Spiel
			for player_id in game.players:
				if player_id != id:  # Nicht an den disconnected Spieler senden
					player_disconnected_from_game.rpc_id(player_id, id)
			
			# Wenn Spiel leer ist, entfernen
			if game.players.is_empty():
				active_games.erase(game_id)
				print("🎮 Spiel ", game_id, " beendet (keine Spieler mehr)")
			break

func create_solo_game(player_id):
	var game_id = next_game_id
	next_game_id += 1
	
	active_games[game_id] = {
		"players": [player_id],
		"state": "playing"
	}
	
	print("🎮 Einzelspieler-Spiel ", game_id, " für Spieler ", player_id, " gestartet")
	game_started.rpc_id(player_id, game_id, [player_id])

@rpc("authority", "reliable")
func game_started(game_id: int, players: Array):
	# Wird auf dem Client aufgerufen
	pass

@rpc("authority", "reliable")
func player_disconnected_from_game(player_id: int):
	# Wird auf dem Client aufgerufen
	pass

@rpc("any_peer", "reliable")
func receive_player_data(data):
	var sender_id = multiplayer.get_remote_sender_id()
	print("📨 Daten von Client ", sender_id, ": ", data)
