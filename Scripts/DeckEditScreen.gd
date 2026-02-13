extends Control

@onready var card_grid = $ScrollContainer/CardGrid
@onready var count_label = $CountLabel
@onready var fight_btn = $FightBtn

var card_display_scene = preload("res://Scenes/CardDisplay.tscn")
var overlay_scene = preload("res://Scenes/RunStatusOverlay.tscn")

func _ready():
	AudioManager.play_music("menu_theme")
	# 1. Add Status Overlay
	var overlay = overlay_scene.instantiate()
	add_child(overlay)
	
	# 2. Connect Button
	fight_btn.pressed.connect(_on_fight_pressed)
	# NEW: Update text to reflect new flow
	fight_btn.text = "CONTINUE"
	# 3. Draw Grid
	_refresh_grid()

func _refresh_grid():
	# Clear old
	for c in card_grid.get_children():
		c.queue_free()
	
	var deck = RunManager.player_run_data.deck
	var unlocked = RunManager.player_run_data.unlocked_actions
	
	# Update Label
	count_label.text = "HAND: " + str(deck.size()) + " / " + str(ClassFactory.HAND_LIMIT)
	count_label.modulate = Color.GREEN if deck.size() == ClassFactory.HAND_LIMIT else Color.WHITE

	# Draw all unlocked cards
	for action in unlocked:
		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(180, 240) 
		wrapper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var disp = card_display_scene.instantiate()
		# Add child FIRST (Safety fix we learned earlier)
		wrapper.add_child(disp)
		disp.set_card_data(action)
		disp.scale = Vector2(0.75, 0.75)
		disp.position = Vector2(10, 10)
		disp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Check if Equipped
		if _is_in_deck(action):
			disp.modulate = Color(1, 1, 1, 1) # Bright
			_add_equipped_badge(wrapper)
		else:
			disp.modulate = Color(0.5, 0.5, 0.5, 0.8) # Dim
		
		# Click Handling
		wrapper.gui_input.connect(func(ev): 
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_toggle_card(action)
		)
		
		card_grid.add_child(wrapper)

func _toggle_card(action):
	var deck = RunManager.player_run_data.deck
	
	if _is_in_deck(action):
		# Remove
		for i in range(deck.size()):
			if deck[i].display_name == action.display_name:
				deck.remove_at(i)
				AudioManager.play_sfx("ui_back")
				break
	else:
		# Add
		if deck.size() < ClassFactory.HAND_LIMIT:
			deck.append(action)
			AudioManager.play_sfx("ui_click")
		else:
			AudioManager.play_sfx("error")
			
	_refresh_grid()

func _is_in_deck(action):
	for c in RunManager.player_run_data.deck:
		if c.display_name == action.display_name: return true
	return false

func _add_equipped_badge(parent):
	var lbl = Label.new()
	lbl.text = "EQUIPPED"
	lbl.add_theme_color_override("font_color", Color.GREEN)
	lbl.position = Vector2(30, -5)
	lbl.z_index = 5
	parent.add_child(lbl)

func _on_fight_pressed():
	if RunManager.player_run_data.deck.size() < 1: return
	
	AudioManager.play_sfx("ui_confirm")
	
	# NEW LINE: Advance the bracket index and load the Map
	RunManager.advance_map()
