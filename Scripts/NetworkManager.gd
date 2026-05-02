extends Node

var peer = WebSocketMultiplayerPeer.new()
const PORT = 8080
# --- FIX 1: POINT TO YOUR ORACLE IP ---
const SERVER_URL = "ws://84.8.149.50:8080" 

# Server Memory
var server_players: Dictionary = {}
var players_ready_for_match: Dictionary = {}

func _ready():
	# --- FIX 2: AUTO-DETECTION FOR CLOUD ENVIRONMENT ---
	var is_headless = DisplayServer.get_name() == "headless"
	var has_server_arg = OS.get_cmdline_args().has("--server")
	
	if is_headless or has_server_arg:
		print("🤖 SERVER DETECTED (Headless: ", is_headless, ")")
		# We wait 1 second to ensure the engine has fully initialized 
		# before opening the network socket.
		await get_tree().create_timer(1.0).timeout
		start_server()

# --- SERVER LOGIC ---
func start_server():
	print("🚀 Starting dedicated WebSocket server on port ", PORT)
	var error = peer.create_server(PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	else:
		print("Failed to start server!")

func _on_peer_connected(id):
	print("SERVER: A new fighter joined! Their ID is: ", id)

func _on_peer_disconnected(id):
	printerr("🚨 [SERVER ALERT] Peer ", id, " suddenly disconnected from the WebSocket!")
	if server_players.has(id):
		server_players.erase(id)

# --- CLIENT LOGIC ---
func join_server():
	# 1. SAFETY: Check if we are already connected or connecting
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		print("⚠️ Connection already in progress. Ignoring duplicate request.")
		return

	print("Connecting to the central server at: ", SERVER_URL)
	var error = peer.create_client(SERVER_URL)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		
		# 2. SAFETY: Only connect the signal if it's not already connected
		if not multiplayer.server_disconnected.is_connected(_on_kicked_by_server):
			multiplayer.server_disconnected.connect(_on_kicked_by_server)
	else:
		printerr("❌ Could not create client. Error code: ", error)

func _on_kicked_by_server():
	printerr("🚨 [CLIENT ALERT] The server closed our connection! We were dropped.")

# ==========================================
# --- IMMORTAL NETWORK HANDSHAKE ---
# ==========================================

# 1. Clients call this function, but ONLY the Server executes it.
@rpc("any_peer", "call_remote", "reliable")
func register_player_character(char_file_path: String):
	if not multiplayer.is_server():
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	server_players[sender_id] = char_file_path
	print("Server: Player ", sender_id, " locked in: ", char_file_path)
	
	if server_players.size() == 2:
		var peer_ids = server_players.keys()
		var p1_id = peer_ids[0]
		var p2_id = peer_ids[1]
		
		var p1_path = server_players[p1_id]
		var p2_path = server_players[p2_id]
		
		# Tell EVERYONE to start the match, passing the exact file paths!
		rpc("start_match", p1_path, p2_path, p1_id, p2_id)

# 2. The Server triggers this on all connected machines simultaneously
@rpc("authority", "call_local", "reliable")
func start_match(p1_path: String, p2_path: String, p1_id: int, p2_id: int):
	print("Match starting! Loading characters safely...")
	
	# Save identities
	GameManager.p1_network_id = p1_id
	GameManager.p2_network_id = p2_id
	
	# Load directly from the file path sent by the server
	var p1_preset = load(p1_path)
	var p2_preset = load(p2_path)
	
	GameManager.next_match_p1_data = ClassFactory.create_from_preset(p1_preset)
	GameManager.next_match_p2_data = ClassFactory.create_from_preset(p2_preset)
	
	# Change the scene safely because NetworkManager won't be deleted!
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")
	
	
	# ==========================================
# --- SCENE LOAD SYNC ---
# ==========================================

# 1. Clients call this when their Arena finishes loading
@rpc("any_peer", "call_remote", "reliable")
func client_finished_loading():
	if not multiplayer.is_server():
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	players_ready_for_match[sender_id] = true
	print("Server: Player ", sender_id, " is in the arena and ready!")
	
	# If both players have loaded the scene, tell them to draw their cards!
	if players_ready_for_match.size() == 2:
		print("Server: Both players are loaded! Starting Combat State...")
		rpc("begin_combat_phase")

# 2. The Server tells the clients to officially start the game
@rpc("authority", "call_local", "reliable")
func begin_combat_phase():
	print("Network: Sync complete. Starting combat!")
	GameManager.change_state(GameManager.State.SELECTION)
