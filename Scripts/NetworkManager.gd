extends Node

#region Configuration & Memory
# --- NETWORK CONFIGURATION ---
var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
const PORT: int = 8080

# NOTE: If you ever need to test locally without the cloud server, 
# temporarily change this back to "ws://localhost:8080"
const SERVER_URL: String = "wss://clashmulti.crushingboredom.uk"

# --- SERVER MEMORY BANKS ---
# Tracks connected player IDs and the file path to their chosen character
var server_players: Dictionary = {}

# Tracks the IDs of players who have finished loading the Arena scene
var players_ready_for_match: Array[int] = []

# Tracks the IDs of players who have finished watching the Clash Animation
var anim_ready_players: Array[int] = []

### --- MATCH STATE GUARDS ---
var _is_match_active: bool = false
var _loading_timeout: SceneTreeTimer = null
var _animation_timeout: SceneTreeTimer = null

#endregion

#region Initialization
var heartbeat_timer: Timer

func _ready() -> void:
	var is_headless: bool = DisplayServer.get_name() == "headless"
	var has_server_arg: bool = OS.get_cmdline_args().has("--server")
	
	if is_headless or has_server_arg:
		print("🤖 SERVER DETECTED (Headless: ", is_headless, ")")
		await get_tree().create_timer(1.0).timeout
		start_server()

	# --- NEW: THE NETWORK HEARTBEAT ---
	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = 3.0 # Pulse every 3 seconds
	heartbeat_timer.autostart = true
	heartbeat_timer.timeout.connect(_send_heartbeat)
	add_child(heartbeat_timer)
#endregion

#region Dedicated Server Logic
# ==========================================
# --- SERVER ONLY LOGIC ---
# ==========================================

## Opens port 8080 and begins listening for incoming client connections.
func start_server() -> void:
	print("🚀 Starting dedicated WebSocket server on port ", PORT)
	var error: int = peer.create_server(PORT)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		# Listen for people connecting and disconnecting
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	else:
		printerr("❌ Failed to start server! Error code: ", error)

## Triggered automatically when a player connects to the server.
func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
		
	print("SERVER: Peer connected. ID: ", id)
	
	if _is_match_active:
		printerr("🚨 [SERVER ALERT] Match in progress. Booting spectator: ", id)
		# Tell the specific late-joiner to leave without affecting P1 and P2
		return_to_lobby.rpc_id(id)
		# Forcefully disconnect them on the server side
		multiplayer.multiplayer_peer.disconnect_peer(id)

## Triggered automatically when a player closes their browser or loses internet.
func _on_peer_disconnected(id: int) -> void:
	printerr("🚨 [SERVER ALERT] Peer ", id, " suddenly disconnected!")
	
	# 1. Erase the ghost player from all server memory lists
	server_players.erase(id)
	players_ready_for_match.erase(id)
	anim_ready_players.erase(id)
	
	# 2. If the match is still running and someone is left behind, abort the match!
	if multiplayer.is_server() and server_players.size() > 0:
		print("Server: Match broken by disconnect. Sending remaining player to lobby.")
		# Force the remaining player to exit
		rpc("return_to_lobby")
		# Completely wipe the server so it is ready for two brand new players
		_wipe_server_memory()
#endregion

#region Client Logic
# ==========================================
# --- CLIENT ONLY LOGIC ---
# ==========================================

## Called by the Client when they click the "Join/Find Match" button.
func join_server() -> void:
	# SAFETY: Check if we are already trying to connect so we don't spam the server.
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		print("⚠️ Connection already in progress. Ignoring duplicate request.")
		return

	print("Connecting to the central server at: ", SERVER_URL)
	var error: int = peer.create_client(SERVER_URL)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		# SAFETY: Only connect the kick signal if it isn't already connected
		if not multiplayer.server_disconnected.is_connected(_on_kicked_by_server):
			multiplayer.server_disconnected.connect(_on_kicked_by_server)
	else:
		printerr("❌ Could not create client. Error code: ", error)

## Triggered if the server crashes or explicitly kicks the client.
func _on_kicked_by_server() -> void:
	printerr("🚨 [CLIENT ALERT] The server closed our connection!")
	_disconnect_local_peer()
	
	# --- THE STRANDED FIX ---
	# If we lose connection, we MUST leave the Arena!
	get_tree().change_scene_to_file("res://Scenes/Multi.tscn")
#endregion

#region Matchmaking Handshake
# ==========================================
# --- IMMORTAL NETWORK HANDSHAKE ---
# ==========================================

## 1. CLIENTS call this to tell the server what character they picked.
## ONLY THE SERVER executes the code inside.
@rpc("any_peer", "call_remote", "reliable")
func register_player_character(preset_path: String) -> void:
	if not multiplayer.is_server(): 
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	
	# Block registration if a match is already running
	if _is_match_active:
		return
		
	server_players[sender_id] = preset_path
	print("Server: Registered player ", sender_id, " with character: ", preset_path)

	if server_players.size() == 2:
		print("Server: Lobby is full! Triggering Match Start...")
		_is_match_active = true
		
		var p_ids: Array = server_players.keys()
		var p1_id: int = p_ids[0]
		var p2_id: int = p_ids[1]
		var p1_path: String = server_players[p1_id]
		var p2_path: String = server_players[p2_id]

		# 1. Start the Match
		start_match.rpc(p1_path, p2_path, p1_id, p2_id)
		
		# 2. Start a 15-second safety timer for scene loading
		_loading_timeout = get_tree().create_timer(15.0)
		_loading_timeout.timeout.connect(_on_handshake_timeout)

## 2. THE SERVER calls this. ALL CLIENTS execute it simultaneously.
@rpc("authority", "call_local", "reliable")
func start_match(p1_path: String, p2_path: String, p1_id: int, p2_id: int) -> void:
	print("Client: Match starting! Loading characters safely...")
	
	# Save network identities so the GameManager knows who is who
	GameManager.p1_network_id = p1_id
	GameManager.p2_network_id = p2_id
	
	# Load the characters from the paths the Server gave us
	var p1_preset: Resource = load(p1_path)
	var p2_preset: Resource = load(p2_path)
	
	# --- THE OVERRIDE: Pass 'true' to completely bypass the 8-card cull limit ---
	GameManager.next_match_p1_data = ClassFactory.create_from_preset(p1_preset, true)
	GameManager.next_match_p2_data = ClassFactory.create_from_preset(p2_preset, true)
	
	# Change the scene to the Arena
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")
#endregion

#region Scene & Animation Syncing
# ==========================================
# --- SCENE & ANIMATION SYNC ---
# ==========================================

## 1. CLIENTS call this when their Arena has fully rendered and is ready.
@rpc("any_peer", "call_remote", "reliable")
func client_finished_loading() -> void:
	if not multiplayer.is_server(): 
		return
		
	var sender_id: int = multiplayer.get_remote_sender_id()

	if not players_ready_for_match.has(sender_id):
		players_ready_for_match.append(sender_id)
		
	print("Server: Player ", sender_id, " is in the arena and ready!")

	if players_ready_for_match.size() == 2:
		# Cancel the safety timer!
		if _loading_timeout:
			_loading_timeout.timeout.disconnect(_on_handshake_timeout)
			_loading_timeout = null
			
		print("Server: Both players are loaded! Starting Combat State...")
		begin_combat_phase.rpc()

## 2. THE SERVER tells the clients to officially start the game.
@rpc("authority", "call_local", "reliable")
func begin_combat_phase() -> void:
	print("Network: Scene Sync complete. Starting combat!")
	GameManager.change_state(GameManager.State.SELECTION)

## 3. CLIENTS call this when they finish watching a combat animation.
@rpc("any_peer", "call_remote", "reliable")
func report_animation_done() -> void:
	if not multiplayer.is_server(): 
		return
		
	var sender_id: int = multiplayer.get_remote_sender_id()

	if not anim_ready_players.has(sender_id):
		anim_ready_players.append(sender_id)
		
	print("Server: Player ", sender_id, " finished watching the clash animation.")

	if anim_ready_players.size() == 2:
		# Cancel the safety timer!
		if _animation_timeout:
			_animation_timeout.timeout.disconnect(_on_handshake_timeout)
			_animation_timeout = null
			
		anim_ready_players.clear()
		approve_state_advance.rpc()

## 4. THE SERVER tells the clients they can unpause and move to the next phase.
@rpc("authority", "call_local", "reliable")
func approve_state_advance() -> void:
	# Flip the safety flag BEFORE emitting the signal to prevent race conditions
	GameManager._is_sync_approved = true
	GameManager.emit_signal("sync_advance_approved")
	
	
func _on_handshake_timeout() -> void:
	printerr("🚨 [SERVER ALERT] Handshake Timeout! A client hung during loading or animation.")
	# Force the remaining connected player back to the menu
	return_to_lobby.rpc()
	_wipe_server_memory()
#endregion

#region Lobby & Cleanup
# ==========================================
# --- SERVER RESET & LOBBY LOGIC ---
# ==========================================

## A CLIENT calls this from the Game Over screen to ask the Server to reset the room.
@rpc("any_peer", "call_remote", "reliable")
func request_server_reset() -> void:
	if not multiplayer.is_server():
		return
		
	print("Server: Match ended normally. Resetting server state and returning players to lobby.")
	# Force everyone to go back to the menu
	rpc("return_to_lobby")
	# Wipe the server clean for the next set of players
	_wipe_server_memory()

## THE SERVER calls this. The CLIENTS execute it to disconnect safely and load the menu.
@rpc("authority", "call_local", "reliable")
func return_to_lobby() -> void:
	# THE SERVER IGNORES THIS PART: It needs to stay online!
	if multiplayer.is_server():
		return
		
	print("Client: Returning to lobby...")
	
	# 1. Safely cut the connection to the server
	_disconnect_local_peer()
	
	# 2. Reset leftover GameManager states so the next match doesn't break
	# 2. Reset leftover GameManager states so the next match starts fresh
	GameManager.state = GameManager.MatchState.new()
	
	# 3. Load the Multiplayer Lobby Scene
	get_tree().change_scene_to_file("res://Scenes/Multi.tscn")

# --- HELPER FUNCTIONS ---

## Safely wipes all server memory tracking variables.
### --- HELPER FUNCTIONS ---

#### Safely wipes all server memory tracking variables and resets match guards.
func _wipe_server_memory() -> void:
	# 1. Clear tracking collections
	server_players.clear()
	players_ready_for_match.clear()
	anim_ready_players.clear()
	
	# 2. Cancel and disconnect any pending handshake timers
	if _loading_timeout and _loading_timeout.timeout.is_connected(_on_handshake_timeout):
		_loading_timeout.timeout.disconnect(_on_handshake_timeout)
	_loading_timeout = null

	if _animation_timeout and _animation_timeout.timeout.is_connected(_on_handshake_timeout):
		_animation_timeout.timeout.disconnect(_on_handshake_timeout)
	_animation_timeout = null

	# 3. Unlock server for the next lobby
	_is_match_active = false
	
	print("Server: Memory wiped and match guards reset. Ready for new match.")

## Safely destroys the local peer connection for a client.
func _disconnect_local_peer() -> void:
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer.close()
	multiplayer.multiplayer_peer = null
#endregion

# ==========================================
# --- ANTI-IDLE HEARTBEAT ---
# ==========================================

func _send_heartbeat() -> void:
	# Only clients need to pulse the server to keep the internet tunnel alive
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			rpc_id(1, "network_keep_alive")

# We use "unreliable" so it doesn't slow down actual game traffic
@rpc("any_peer", "call_remote", "unreliable")
func network_keep_alive() -> void:
	pass # The server does absolutely nothing. Receiving the packet is enough to reset the idle timer!
#test
