extends Control

@onready var tube_client = $TubeClient
@onready var host_button = $HostButton
@onready var room_code_label = $RoomCodeLabel
@onready var join_code_input = $JoinCodeInput
@onready var join_button = $JoinButton

func _ready():
	# 1. Connect our UI buttons
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	
	# 2. Connect Tube's built-in signals (straight from the docs)
	tube_client.session_created.connect(_on_session_created)
	tube_client.session_joined.connect(_on_session_joined)
	tube_client.peer_connected.connect(_on_peer_connected)
	tube_client.error_raised.connect(_on_error_raised)

func _on_host_pressed():
	print("Attempting to host...")
	# Tell Tube to create the server
	tube_client.create_session()

func _on_join_pressed():
	var friend_code = join_code_input.text.strip_edges()
	if friend_code == "":
		print("Please enter a code first!")
		return
		
	print("Attempting to join code: ", friend_code)
	# Tell Tube to connect using the friend's code
	tube_client.join_session(friend_code)

# --- TUBE SIGNAL RESPONSES ---

func _on_session_created():
	# The server was successfully created! 
	# Now we can grab the ID and show it to the host.
	var my_code = tube_client.session_id 
	room_code_label.text = "Your Room Code: " + my_code
	print("Hosting! Send this code to your friend: ", my_code)

func _on_session_joined():
	# This triggers for the CLIENT when they successfully connect to the Host
	print("Boom! We successfully joined the session!")
	# TODO: Hide the Lobby UI and load the combat scene!

func _on_peer_connected(peer_id):
	print("A friend joined our game! Their peer ID is: ", peer_id)
	
	# Hide the lobby UI so they can't click it again
	host_button.hide()
	join_button.hide()
	join_code_input.hide()
	room_code_label.hide()

	# Only the Host (Server) dictates when the game starts.
	# We use an RPC call to trigger the 'start_match' function on BOTH computers.
	if multiplayer.is_server():
		rpc("start_match")

# The @rpc tag allows this function to be triggered over the internet.
# "authority" means only the Host can call it. "call_local" means the Host also runs it on their own machine.
@rpc("authority", "call_local", "reliable")


func start_match():
	print("Loading presets and starting the match!")
	
	# 1. Load your Preset blueprints
	var p1_preset = load("res://Data/Presets/Kaiji_Akagi_Lv6.tres")
	var p2_preset = load("res://Data/Presets/Crash_Johnson_Lv6.tres")
	
	# 2. Use your ClassFactory to turn the blueprints into real CharacterData!
	# IMPORTANT: Change "create_from_preset" to whatever the actual function 
	# name is inside your ClassFactory.gd script! 
	var p1_data = ClassFactory.create_from_preset(p1_preset)
	var p2_data = ClassFactory.create_from_preset(p2_preset)
	
	# 3. Assign the fully-built characters to the GameManager
	GameManager.next_match_p1_data = p1_data
	GameManager.next_match_p2_data = p2_data
	
	# 4. Jump into the arena
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")
	
func _on_error_raised(code, message):
	# If anything goes wrong (bad code, no internet), it prints here
	print("Tube Error! Code: ", code, " Message: ", message)
