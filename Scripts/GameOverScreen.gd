extends Control

@onready var winner_label = $Panel/VBoxContainer/WinnerLabel
@onready var main_panel = $Panel
@onready var vbox = $Panel/VBoxContainer
@onready var background_rect = $Background

var view_board_btn: Button
var stats_panel: RichTextLabel

func _ready():
	# 1. Get Existing References
	var btn_rematch = $Panel/VBoxContainer/RematchButton
	var btn_menu = $Panel/VBoxContainer/MenuButton
	
	# 2. Connect Logic
	btn_rematch.pressed.connect(_on_rematch_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)
	_attach_sfx(btn_rematch)
	_attach_sfx(btn_menu)
	
	# 3. Add "VIEW BOARD" Button (Dynamically created)
	view_board_btn = Button.new()
	view_board_btn.text = "Hide Screen (View Board)"
	view_board_btn.pressed.connect(_on_view_board_pressed)
	_attach_sfx(view_board_btn)
	
	# Add it to the top right of the screen
	add_child(view_board_btn)
	view_board_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	view_board_btn.position -= Vector2(20, -20)
	
	# 4. Create Run Stats Container (Hidden by default)
	stats_panel = RichTextLabel.new()
	stats_panel.bbcode_enabled = true
	stats_panel.fit_content = true
	stats_panel.custom_minimum_size.y = 100
	stats_panel.visible = false
	vbox.add_child(stats_panel)
	vbox.move_child(stats_panel, 1) # Put it under the Winner Label

func setup(winner_id: int):
	# --- STANDARD SETUP ---
	if winner_id == 1:
		winner_label.text = "PLAYER 1 WINS!"
		winner_label.modulate = Color("#ff9999")
	elif winner_id == 2:
		winner_label.text = "PLAYER 2 WINS!"
		winner_label.modulate = Color("#99ccff")
	else:
		winner_label.text = "DRAW!"

	# --- ARCADE LOGIC & STATS ---
	if RunManager.is_arcade_mode:
		if winner_id == 1:
			# Player Won: Proceed to next level
			$Panel/VBoxContainer/RematchButton.text = "CLAIM REWARD"
			$Panel/VBoxContainer/RematchButton.pressed.disconnect(_on_rematch_pressed)
			$Panel/VBoxContainer/RematchButton.pressed.connect(_on_claim_reward_pressed)
			
		else:
			# Player Lost: SHOW RUN SUMMARY
			$Panel/VBoxContainer/RematchButton.visible = false 
			$Panel/VBoxContainer/MenuButton.text = "MAIN MENU"
			
			_populate_run_stats()

func _populate_run_stats():
	stats_panel.visible = true
	
	# 1. Basic Stats
	var levels_beat = RunManager.current_level - 1
	var txt = "[center][b]--- ARCADE RUN SUMMARY ---[/b][/center]\n\n"
	txt += "[color=yellow]Enemies Defeated:[/color] " + str(levels_beat) + "\n"
	
	# 2. Deck Summary
	txt += "[color=yellow]Final Deck:[/color] "
	var deck_names = []
	for card in RunManager.player_run_data.deck:
		deck_names.append(card.display_name)
	txt += ", ".join(deck_names) + "\n"
	
	# 3. Placeholder for Future Stats
	txt += "\n[color=gray][i]Total Damage Dealt: (Coming Soon)[/i][/color]"
	txt += "\n[color=gray][i]Total SP Spent: (Coming Soon)[/i][/color]"
	
	stats_panel.text = txt

# --- UI INTERACTION ---

func _on_view_board_pressed():
	# Toggle visibility of the visuals
	main_panel.visible = not main_panel.visible
	background_rect.visible = not background_rect.visible 
	
	if main_panel.visible:
		view_board_btn.text = "Hide Screen (View Board)"
		# --- FIX: Block clicks from passing through ---
		mouse_filter = Control.MOUSE_FILTER_STOP 
	else:
		view_board_btn.text = "Show Game Over Screen"
		# --- FIX: Let clicks pass through the invisible root node ---
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_rematch_pressed():
	# --- FIX: Unpause before reloading ---
	get_tree().paused = false 
	# -------------------------------------
	GameManager.reset_combat() 
	get_tree().reload_current_scene()

func _on_menu_pressed():
	# --- FIX: Unpause before leaving ---
	get_tree().paused = false 
	# -----------------------------------
	GameManager.reset_combat() 
	SceneLoader.change_scene("res://Scenes/MainMenu.tscn")
	
func _attach_sfx(btn: BaseButton):
	btn.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", 0.2))
	btn.pressed.connect(func(): AudioManager.play_sfx("ui_click"))

func _on_claim_reward_pressed():
	# 1. Unpause the game safely
	get_tree().paused = false
	
	# 2. Tell the RunManager to load the Action Tree
	RunManager.handle_win()
