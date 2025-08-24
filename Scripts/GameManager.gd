extends Node

var peer: ENetMultiplayerPeer
var is_multiplayer: bool = false

func join_dedicated_server():
	print("🔗 Verbinde zum Server...")
	is_multiplayer = true
	peer = ENetMultiplayerPeer.new()
	
	var err = peer.create_client("proxy.pondsec.com", 5999)
	if err != OK:
		print("❌ Fehler beim Verbinden: ", err)
		show_error("Verbindung fehlgeschlagen")
		return
	
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connection_success():
	print("✅ Erfolgreich mit Server verbunden!")
	load_game_world()

func _on_connection_failed():
	print("❌ Verbindung zum Server fehlgeschlagen!")
	show_error("Kann nicht zum Server verbinden")

func _on_server_disconnected():
	print("⚠ Vom Server getrennt!")
	show_error("Verbindung zum Server verloren")

func load_game_world():
	print("🌍 Lade Spielwelt...")
	get_tree().change_scene_to_file("res://Scenes/world.tscn")

func show_error(message):
	print("FEHLER: ", message)
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()
